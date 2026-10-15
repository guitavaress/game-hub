//! Testes do compositor com um app de mentira que fala Wayland de verdade
//! (o crate `wayland-client`, só nos testes).
//!
//! O compositor (`Core`) e o app rodam na mesma thread: os dois leem sem
//! esperar, e o `pump()` alterna entre eles até a condição do teste valer.
//! Não precisa da Godot nem de socket em disco (um par de sockets liga os dois).

use std::io::Write;
use std::os::fd::AsFd;
use std::os::unix::net::UnixStream;

use wayland_client::protocol::{wl_buffer, wl_callback, wl_compositor, wl_registry, wl_shm, wl_shm_pool, wl_surface};
use wayland_client::{delegate_noop, Connection, Dispatch, EventQueue, QueueHandle, WEnum};
use wayland_protocols::xdg::decoration::zv1::client::{zxdg_decoration_manager_v1, zxdg_toplevel_decoration_v1};
use wayland_protocols::xdg::shell::client::{xdg_surface, xdg_toplevel, xdg_wm_base};

use crate::wayland::{Core, Event, WINDOW_SIZE};

/// O lado do app: o que ele já recebeu do compositor.
#[derive(Default)]
struct App {
    compositor: Option<wl_compositor::WlCompositor>,
    shm: Option<wl_shm::WlShm>,
    wm_base: Option<xdg_wm_base::XdgWmBase>,
    decoration_manager: Option<zxdg_decoration_manager_v1::ZxdgDecorationManagerV1>,
    surface: Option<wl_surface::WlSurface>,
    xdg_surface: Option<xdg_surface::XdgSurface>,
    toplevel: Option<xdg_toplevel::XdgToplevel>,
    /// Tamanho do último configure do toplevel (0 = "você escolhe").
    pending_size: (i32, i32),
    /// Quantos configures completos (xdg_surface) chegaram, e o tamanho do último.
    configures: u32,
    size: (i32, i32),
    states: Vec<xdg_toplevel::State>,
    decoration_mode: Option<zxdg_toplevel_decoration_v1::Mode>,
    close_requested: bool,
    frames_done: u32,
}

/// O compositor, o app e o fio entre eles.
struct Harness {
    core: Core,
    conn: Connection,
    queue: EventQueue<App>,
    qh: QueueHandle<App>,
    app: App,
    /// Uma cópia do socket do app, para "derrubar" o app no teste.
    app_socket: UnixStream,
    /// Os eventos que o compositor mandaria para a Godot.
    events: Vec<Event>,
}

/// Cor de teste, como o app grava: B, G, R, A.
const AZUL_ESCURO: [u8; 4] = [10, 20, 30, 0];
const VERMELHO: [u8; 4] = [0, 0, 200, 0];
const SOMBRA: [u8; 4] = [1, 1, 1, 0];

impl Harness {
    /// Liga o compositor e um app, que já pega os serviços (compositor, shm, xdg).
    fn new() -> Harness {
        let core = Core::new("us", "").expect("o compositor liga");
        let (server_side, app_side) = UnixStream::pair().unwrap();
        let app_socket = app_side.try_clone().unwrap();
        let conn = Connection::from_socket(app_side).unwrap();
        let queue = conn.new_event_queue();
        let qh = queue.handle();
        conn.display().get_registry(&qh, ());
        let mut h = Harness { core, conn, queue, qh, app: App::default(), app_socket, events: Vec::new() };
        h.core.add_client(server_side).unwrap();
        h.pump("os serviços do compositor", |h| {
            h.app.compositor.is_some()
                && h.app.shm.is_some()
                && h.app.wm_base.is_some()
                && h.app.decoration_manager.is_some()
        });
        h
    }

    /// Alterna compositor e app até `done` valer (ou falha depois de ~2 s).
    fn pump(&mut self, what: &str, mut done: impl FnMut(&mut Harness) -> bool) {
        for _ in 0..2000 {
            let _ = self.conn.flush();
            self.core.dispatch().unwrap();
            if let Some(guard) = self.queue.prepare_read() {
                let _ = guard.read(); // sem nada para ler, volta na hora ("WouldBlock")
            }
            self.queue.dispatch_pending(&mut self.app).unwrap();
            let events = self.core.take_events();
            self.events.extend(events);
            if done(self) {
                return;
            }
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        panic!("tempo esgotado esperando: {what}");
    }

    /// Cria a janela (com nome, título e pedido de decoração) e espera o
    /// primeiro configure, como todo app faz.
    fn open_window(&mut self) {
        let qh = self.qh.clone();
        let surface = self.app.compositor.as_ref().unwrap().create_surface(&qh, ());
        let xdg_surface = self.app.wm_base.as_ref().unwrap().get_xdg_surface(&surface, &qh, ());
        let toplevel = xdg_surface.get_toplevel(&qh, ());
        toplevel.set_app_id("teste".into());
        toplevel.set_title("Janela de teste".into());
        self.app.decoration_manager.as_ref().unwrap().get_toplevel_decoration(&toplevel, &qh, ());
        surface.commit();
        self.app.surface = Some(surface);
        self.app.xdg_surface = Some(xdg_surface);
        self.app.toplevel = Some(toplevel);
        let before = self.app.configures;
        self.pump("o primeiro configure", |h| h.app.configures > before);
    }

    /// O app desenha uma imagem `w`×`h`: `color` no meio e, se `margin` > 0,
    /// uma "sombra" dessa largura em volta (declarada com set_window_geometry).
    /// `damage`: só essa faixa de linhas avisada como mudada (None = tudo).
    fn draw(&mut self, w: i32, h: i32, margin: i32, color: [u8; 4], damage: Option<(i32, i32)>) {
        let stride = w * 4;
        let mut bytes = Vec::with_capacity((stride * h) as usize);
        for y in 0..h {
            for x in 0..w {
                let shadow = x < margin || y < margin || x >= w - margin || y >= h - margin;
                bytes.extend_from_slice(if shadow { &SOMBRA } else { &color });
            }
        }
        let mut file = tempfile::tempfile().unwrap();
        file.write_all(&bytes).unwrap();
        let qh = self.qh.clone();
        let pool = self.app.shm.as_ref().unwrap().create_pool(file.as_fd(), stride * h, &qh, ());
        let buffer = pool.create_buffer(0, w, h, stride, wl_shm::Format::Xrgb8888, &qh, ());
        let surface = self.app.surface.clone().unwrap();
        if margin > 0 {
            self.app.xdg_surface.as_ref().unwrap().set_window_geometry(margin, margin, w - 2 * margin, h - 2 * margin);
        }
        surface.attach(Some(&buffer), 0, 0);
        match damage {
            Some((top, bottom)) => surface.damage_buffer(0, top, w, bottom - top),
            None => surface.damage_buffer(0, 0, i32::MAX, i32::MAX),
        }
        surface.commit();
        pool.destroy();
    }

    /// Desenha e espera o compositor processar (a janela fica "suja").
    fn draw_and_wait(&mut self, w: i32, h: i32, margin: i32, color: [u8; 4], damage: Option<(i32, i32)>) {
        let copies = self.core.state.copy_count;
        self.draw(w, h, margin, color, damage);
        self.pump("a imagem nova", |h| h.core.state.copy_count > copies);
    }

    /// O pixel (x, y) da janela 1, em RGBA.
    fn pixel(&self, x: i32, y: i32) -> [u8; 4] {
        let win = self.core.state.window(1).expect("a janela 1 existe");
        let i = ((y * win.width() + x) * 4) as usize;
        win.pixels[i..i + 4].try_into().unwrap()
    }
}

/// Em RGBA, opaco, como a Godot recebe.
fn rgba(bgra: [u8; 4]) -> [u8; 4] {
    [bgra[2], bgra[1], bgra[0], 255]
}

#[test]
fn janela_abre_com_nome_titulo_pid_e_cor() {
    let mut h = Harness::new();
    h.open_window();
    assert_eq!(h.app.size, WINDOW_SIZE, "a janela nasce com o tamanho do telão");
    assert!(h.app.states.contains(&xdg_toplevel::State::Activated));
    assert!(h.app.states.contains(&xdg_toplevel::State::TiledLeft), "encostada: sem sombra");
    assert_eq!(h.app.decoration_mode, Some(zxdg_toplevel_decoration_v1::Mode::ServerSide), "sem barra de título");
    assert!(h.events.is_empty(), "sem imagem ainda, a Godot não fica sabendo");

    let (w, hh) = h.app.size;
    h.draw(w, hh, 0, AZUL_ESCURO, None);
    h.pump("o aviso de janela aberta", |h| !h.events.is_empty());
    assert_eq!(
        h.events,
        vec![Event::Opened(1, "teste".into(), "Janela de teste".into(), std::process::id() as i64)]
    );
    let win = h.core.state.window(1).unwrap();
    assert_eq!((win.width(), win.height()), WINDOW_SIZE);
    assert!(win.dirty);
    assert!(win.pixels.chunks_exact(4).all(|p| p == rgba(AZUL_ESCURO)), "a imagem inteira tem a cor certa");
}

#[test]
fn recorta_a_sombra_pela_geometria() {
    let mut h = Harness::new();
    h.open_window();
    // Como o Brave: pediu 1280×720 e desenhou 1324×764, com 22 px de sombra.
    h.draw_and_wait(1324, 764, 22, AZUL_ESCURO, None);
    let win = h.core.state.window(1).unwrap();
    assert_eq!((win.width(), win.height()), (1280, 720));
    assert!(win.pixels.chunks_exact(4).all(|p| p == rgba(AZUL_ESCURO)), "nenhum pixel de sombra");
}

#[test]
fn copia_so_as_linhas_com_dano() {
    let mut h = Harness::new();
    h.open_window();
    let (w, hh) = h.app.size;
    h.draw_and_wait(w, hh, 0, AZUL_ESCURO, None);
    // A imagem nova é toda vermelha, mas o app só avisa as linhas 100 a 109.
    h.draw_and_wait(w, hh, 0, VERMELHO, Some((100, 110)));
    assert_eq!(h.pixel(5, 99), rgba(AZUL_ESCURO));
    assert_eq!(h.pixel(5, 100), rgba(VERMELHO));
    assert_eq!(h.pixel(w - 1, 109), rgba(VERMELHO));
    assert_eq!(h.pixel(5, 110), rgba(AZUL_ESCURO));
}

#[test]
fn imagem_sem_dano_nao_copia() {
    let mut h = Harness::new();
    h.open_window();
    let (w, hh) = h.app.size;
    h.draw_and_wait(w, hh, 0, AZUL_ESCURO, None);
    let copies = h.core.state.copy_count;
    h.draw(w, hh, 0, VERMELHO, Some((0, 0))); // dano vazio
    h.pump("o commit", |h| h.core.state.copy_count == copies);
    for _ in 0..5 {
        h.pump("mais um pouco", |_| true);
    }
    assert_eq!(h.core.state.copy_count, copies);
    assert_eq!(h.pixel(5, 5), rgba(AZUL_ESCURO));
}

#[test]
fn frame_done_so_para_quem_pediu() {
    let mut h = Harness::new();
    h.open_window();
    let (w, hh) = h.app.size;
    h.draw_and_wait(w, hh, 0, AZUL_ESCURO, None);
    h.core.frame_done();
    h.pump("nada", |_| true);
    assert_eq!(h.app.frames_done, 0, "ninguém pediu, ninguém recebe");

    let qh = h.qh.clone();
    let surface = h.app.surface.clone().unwrap();
    surface.frame(&qh, ());
    surface.commit();
    h.pump("o pedido chegar", |h| h.core.state.window(1).is_some_and(|w| !w.callbacks.is_empty()));
    h.core.frame_done();
    h.pump("o quadro mostrado", |h| h.app.frames_done == 1);
}

#[test]
fn resize_pede_tamanho_novo() {
    let mut h = Harness::new();
    h.open_window();
    let (w, hh) = h.app.size;
    h.draw_and_wait(w, hh, 0, AZUL_ESCURO, None);
    assert!(h.core.resize(1, 640, 360));
    let before = h.app.configures;
    h.pump("o configure novo", |h| h.app.configures > before);
    assert_eq!(h.app.size, (640, 360));
    h.draw_and_wait(640, 360, 0, VERMELHO, None);
    let win = h.core.state.window(1).unwrap();
    assert_eq!((win.width(), win.height()), (640, 360));
    assert_eq!(h.pixel(639, 359), rgba(VERMELHO));
    assert!(!h.core.resize(99, 10, 10), "janela que não existe");
}

#[test]
fn close_pede_e_o_app_fecha() {
    let mut h = Harness::new();
    h.open_window();
    let (w, hh) = h.app.size;
    h.draw_and_wait(w, hh, 0, AZUL_ESCURO, None);
    h.events.clear();
    assert!(h.core.close(1));
    h.pump("o pedido de fechar", |h| h.app.close_requested);
    assert!(h.events.is_empty(), "o app ainda não fechou");
    // O app obedece: destrói a janela.
    h.app.toplevel.take().unwrap().destroy();
    h.app.xdg_surface.take().unwrap().destroy();
    h.app.surface.take().unwrap().destroy();
    h.pump("o aviso de janela fechada", |h| !h.events.is_empty());
    assert_eq!(h.events, vec![Event::Closed(1)]);
    assert!(h.core.state.window(1).is_none());
}

#[test]
fn app_que_cai_fecha_a_janela() {
    let mut h = Harness::new();
    h.open_window();
    let (w, hh) = h.app.size;
    h.draw_and_wait(w, hh, 0, AZUL_ESCURO, None);
    h.events.clear();
    h.app_socket.shutdown(std::net::Shutdown::Both).unwrap();
    for _ in 0..50 {
        h.core.dispatch().unwrap();
        h.events.extend(h.core.take_events());
        if !h.events.is_empty() {
            break;
        }
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    assert_eq!(h.events, vec![Event::Closed(1)]);
}

#[test]
fn titulo_novo_avisa() {
    let mut h = Harness::new();
    h.open_window();
    let (w, hh) = h.app.size;
    h.draw_and_wait(w, hh, 0, AZUL_ESCURO, None);
    h.events.clear();
    h.app.toplevel.as_ref().unwrap().set_title("Outro título".into());
    h.pump("o aviso de título", |h| !h.events.is_empty());
    assert_eq!(h.events, vec![Event::TitleChanged(1, "Outro título".into())]);
}

#[test]
fn esconder_fecha_e_mostrar_abre_de_novo() {
    let mut h = Harness::new();
    h.open_window();
    let (w, hh) = h.app.size;
    h.draw_and_wait(w, hh, 0, AZUL_ESCURO, None);
    h.events.clear();
    // Esconder: commit sem imagem.
    let surface = h.app.surface.clone().unwrap();
    surface.attach(None, 0, 0);
    surface.commit();
    h.pump("o aviso de janela fechada", |h| !h.events.is_empty());
    assert_eq!(h.events, vec![Event::Closed(1)]);
    // Mostrar de novo: commit vazio, configure, imagem.
    h.events.clear();
    let before = h.app.configures;
    surface.commit();
    h.pump("o configure de novo", |h| h.app.configures > before);
    h.draw(w, hh, 0, VERMELHO, None);
    h.pump("o aviso de janela aberta", |h| !h.events.is_empty());
    assert!(matches!(h.events[0], Event::Opened(1, _, _, _)));
    assert_eq!(h.pixel(5, 5), rgba(VERMELHO));
}

// --- O app de teste responde ao compositor ------------------------------------

impl Dispatch<wl_registry::WlRegistry, ()> for App {
    fn event(
        app: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let wl_registry::Event::Global { name, interface, version } = event {
            match interface.as_str() {
                "wl_compositor" => app.compositor = Some(registry.bind(name, version.min(4), qh, ())),
                "wl_shm" => app.shm = Some(registry.bind(name, 1, qh, ())),
                "xdg_wm_base" => app.wm_base = Some(registry.bind(name, version.min(5), qh, ())),
                "zxdg_decoration_manager_v1" => app.decoration_manager = Some(registry.bind(name, 1, qh, ())),
                _ => {}
            }
        }
    }
}

impl Dispatch<xdg_wm_base::XdgWmBase, ()> for App {
    fn event(_: &mut Self, base: &xdg_wm_base::XdgWmBase, event: xdg_wm_base::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        if let xdg_wm_base::Event::Ping { serial } = event {
            base.pong(serial);
        }
    }
}

impl Dispatch<xdg_surface::XdgSurface, ()> for App {
    fn event(app: &mut Self, surface: &xdg_surface::XdgSurface, event: xdg_surface::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        if let xdg_surface::Event::Configure { serial } = event {
            surface.ack_configure(serial);
            app.size = app.pending_size;
            app.configures += 1;
        }
    }
}

impl Dispatch<xdg_toplevel::XdgToplevel, ()> for App {
    fn event(app: &mut Self, _: &xdg_toplevel::XdgToplevel, event: xdg_toplevel::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        match event {
            xdg_toplevel::Event::Configure { width, height, states } => {
                app.pending_size = (width, height);
                // Os estados vêm como uma lista de números de 32 bits.
                app.states = states
                    .chunks_exact(4)
                    .filter_map(|c| xdg_toplevel::State::try_from(u32::from_ne_bytes(c.try_into().unwrap())).ok())
                    .collect();
            }
            xdg_toplevel::Event::Close => app.close_requested = true,
            _ => {}
        }
    }
}

impl Dispatch<zxdg_toplevel_decoration_v1::ZxdgToplevelDecorationV1, ()> for App {
    fn event(
        app: &mut Self,
        _: &zxdg_toplevel_decoration_v1::ZxdgToplevelDecorationV1,
        event: zxdg_toplevel_decoration_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let zxdg_toplevel_decoration_v1::Event::Configure { mode: WEnum::Value(mode) } = event {
            app.decoration_mode = Some(mode);
        }
    }
}

impl Dispatch<wl_callback::WlCallback, ()> for App {
    fn event(app: &mut Self, _: &wl_callback::WlCallback, event: wl_callback::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        if let wl_callback::Event::Done { .. } = event {
            app.frames_done += 1;
        }
    }
}

delegate_noop!(App: wl_compositor::WlCompositor);
delegate_noop!(App: ignore wl_surface::WlSurface);
delegate_noop!(App: ignore wl_shm::WlShm);
delegate_noop!(App: wl_shm_pool::WlShmPool);
delegate_noop!(App: ignore wl_buffer::WlBuffer);
delegate_noop!(App: zxdg_decoration_manager_v1::ZxdgDecorationManagerV1);
