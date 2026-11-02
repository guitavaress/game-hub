//! Testes do compositor com apps de mentira que falam Wayland de verdade
//! (o crate `wayland-client`, só nos testes).
//!
//! O compositor (`Core`) e os apps rodam na mesma thread: todos leem sem
//! esperar, e o `pump()` alterna entre eles até a condição do teste valer.
//! Não precisa da Godot nem de socket em disco (um par de sockets liga cada app).

use std::io::{Read, Write};
use std::ops::{Deref, DerefMut};
use std::os::fd::AsFd;
use std::os::unix::fs::FileExt;
use std::os::unix::net::UnixStream;

use wayland_client::protocol::{
    wl_buffer, wl_callback, wl_compositor, wl_data_device, wl_data_device_manager, wl_data_offer, wl_data_source,
    wl_keyboard, wl_output, wl_pointer, wl_registry, wl_seat, wl_shm, wl_shm_pool, wl_surface,
};
use wayland_client::{delegate_noop, event_created_child, Connection, Dispatch, EventQueue, QueueHandle, WEnum};
use wayland_protocols::xdg::decoration::zv1::client::{zxdg_decoration_manager_v1, zxdg_toplevel_decoration_v1};
use wayland_protocols::xdg::shell::client::{xdg_popup, xdg_positioner, xdg_surface, xdg_toplevel, xdg_wm_base};
use wayland_protocols_wlr::layer_shell::v1::client::{zwlr_layer_shell_v1, zwlr_layer_surface_v1};
use zwlr_layer_surface_v1::{Anchor, KeyboardInteractivity};

use crate::pixels::Rect;
use crate::wayland::{Core, Event, OUTPUT_BACKGROUND, WINDOW_SIZE};

/// O lado do app: o que ele já recebeu do compositor.
#[derive(Default)]
struct App {
    compositor: Option<wl_compositor::WlCompositor>,
    shm: Option<wl_shm::WlShm>,
    wm_base: Option<xdg_wm_base::XdgWmBase>,
    decoration_manager: Option<zxdg_decoration_manager_v1::ZxdgDecorationManagerV1>,
    seat: Option<wl_seat::WlSeat>,
    keyboard: Option<wl_keyboard::WlKeyboard>,
    pointer: Option<wl_pointer::WlPointer>,
    data_manager: Option<wl_data_device_manager::WlDataDeviceManager>,
    data_device: Option<wl_data_device::WlDataDevice>,
    /// O texto do keymap (o layout do teclado) que o compositor mandou.
    keymap: String,
    /// (repetições por segundo, espera em ms) para repetir a tecla segurada.
    repeat: (i32, i32),
    /// O número do último "teclado entrou" (o app precisa dele para copiar).
    keyboard_serial: u32,
    /// Tudo o que chegou do teclado e do mouse, em texto (fácil de conferir).
    input: Vec<String>,
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
    /// Os menus que este app abriu.
    popups: Vec<TestPopup>,
    /// Copiar e colar: o que está oferecido para colar (e os formatos), e se
    /// o app que copiou já mandou o texto.
    selection: Option<wl_data_offer::WlDataOffer>,
    offered: Vec<String>,
    copied_text_sent: bool,
    /// Os monitores (wl_output) que o compositor anuncia (os números dos globais).
    outputs: Vec<u32>,
    /// O compositor anuncia o xdg-output (nome e lugar de cada monitor).
    xdg_output: bool,
    /// Os monitores ligados pelo app (o número do global e o objeto), para
    /// pedir uma camada num monitor certo.
    output_objects: Vec<(u32, wl_output::WlOutput)>,
    layer_shell: Option<zwlr_layer_shell_v1::ZwlrLayerShellV1>,
    /// As camadas que este app criou (barra, fundo, menu).
    layers: Vec<TestLayer>,
}

/// Uma camada do app de teste.
struct TestLayer {
    surface: wl_surface::WlSurface,
    layer: zwlr_layer_surface_v1::ZwlrLayerSurfaceV1,
    /// O tamanho do último configure.
    size: (i32, i32),
    configures: u32,
    /// O compositor mandou fechar (o monitor sumiu).
    closed: bool,
}

/// O que a camada de teste pede.
#[derive(Clone, Copy)]
struct LayerAsk {
    level: zwlr_layer_shell_v1::Layer,
    anchor: Anchor,
    size: (u32, u32),
    zone: i32,
    keyboard: KeyboardInteractivity,
    /// Em qual monitor (None: o compositor escolhe).
    output: Option<usize>,
}

/// A barra do alto, de ponta a ponta: 30 px, reservando o alto.
const BARRA: LayerAsk = LayerAsk {
    level: zwlr_layer_shell_v1::Layer::Top,
    anchor: Anchor::Top.union(Anchor::Left).union(Anchor::Right),
    size: (0, 30),
    zone: 30,
    keyboard: KeyboardInteractivity::None,
    output: None,
};

/// Um menu do app de teste.
struct TestPopup {
    surface: wl_surface::WlSurface,
    xdg_surface: xdg_surface::XdgSurface,
    popup: xdg_popup::XdgPopup,
    /// O lugar e o tamanho que o compositor deu (x, y, largura, altura).
    place: Option<(i32, i32, i32, i32)>,
    configures: u32,
    done: bool,
}

/// Um app conectado: o fio, a fila de mensagens e o que ele sabe.
struct Peer {
    conn: Connection,
    queue: EventQueue<App>,
    qh: QueueHandle<App>,
    app: App,
    /// Uma cópia do socket do app, para "derrubar" o app no teste.
    app_socket: UnixStream,
}

impl Peer {
    fn connect(core: &mut Core) -> Peer {
        let (server_side, app_side) = UnixStream::pair().unwrap();
        let app_socket = app_side.try_clone().unwrap();
        let conn = Connection::from_socket(app_side).unwrap();
        let queue = conn.new_event_queue();
        let qh = queue.handle();
        conn.display().get_registry(&qh, ());
        core.add_client(server_side).unwrap();
        Peer { conn, queue, qh, app: App::default(), app_socket }
    }

    /// Manda o que tem para mandar e lê o que chegou, sem esperar.
    fn sync(&mut self) {
        let _ = self.conn.flush();
        if let Some(guard) = self.queue.prepare_read() {
            let _ = guard.read(); // sem nada para ler, volta na hora ("WouldBlock")
        }
        self.queue.dispatch_pending(&mut self.app).unwrap();
    }

    fn ready(&self) -> bool {
        let a = &self.app;
        a.compositor.is_some()
            && a.shm.is_some()
            && a.wm_base.is_some()
            && a.decoration_manager.is_some()
            && a.keyboard.is_some()
            && a.pointer.is_some()
            && a.data_device.is_some()
            && !a.keymap.is_empty()
    }

    /// Cria a janela (com nome, título e pedido de decoração) e faz o commit vazio.
    fn create_window(&mut self) {
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
    }

    /// Abre um menu ancorado no ponto (x, y) da janela, de `w`×`h`, que cresce
    /// para baixo e para a direita e pode ser empurrado para caber.
    fn create_popup(&mut self, x: i32, y: i32, w: i32, h: i32) -> usize {
        self.create_popup_on(None, x, y, w, h)
    }

    /// Como `create_popup`, mas o pai pode ser uma camada (`layer`: o índice
    /// em `App::layers`), como o menu que desce da barra.
    fn create_popup_on(&mut self, layer: Option<usize>, x: i32, y: i32, w: i32, h: i32) -> usize {
        let qh = self.qh.clone();
        let index = self.app.popups.len();
        let wm_base = self.app.wm_base.as_ref().unwrap();
        let positioner = wm_base.create_positioner(&qh, ());
        positioner.set_size(w, h);
        positioner.set_anchor_rect(x, y, 1, 1);
        positioner.set_anchor(xdg_positioner::Anchor::TopLeft);
        positioner.set_gravity(xdg_positioner::Gravity::BottomRight);
        positioner.set_constraint_adjustment(
            xdg_positioner::ConstraintAdjustment::SlideX | xdg_positioner::ConstraintAdjustment::SlideY,
        );
        let surface = self.app.compositor.as_ref().unwrap().create_surface(&qh, ());
        let xdg_surface = wm_base.get_xdg_surface(&surface, &qh, index);
        let popup = match layer {
            // O menu de uma camada nasce sem pai e é ligado pela camada.
            Some(l) => {
                let popup = xdg_surface.get_popup(None, &positioner, &qh, index);
                self.app.layers[l].layer.get_popup(&popup);
                popup
            }
            None => xdg_surface.get_popup(self.app.xdg_surface.as_ref(), &positioner, &qh, index),
        };
        surface.commit();
        self.app.popups.push(TestPopup { surface, xdg_surface, popup, place: None, configures: 0, done: false });
        index
    }

    /// Desenha uma imagem `w`×`h` na janela (`popup` None) ou num menu:
    /// `color` no meio e, se `margin` > 0, uma "sombra" dessa largura em volta
    /// (declarada com set_window_geometry). `damage`: só essa faixa de linhas
    /// avisada como mudada (None = tudo).
    fn draw_on(&mut self, popup: Option<usize>, w: i32, h: i32, margin: i32, color: [u8; 4], damage: Option<(i32, i32)>) {
        let buffer = self.buffer(w, h, margin, color);
        let (surface, xdg_surface) = match popup {
            Some(i) => (self.app.popups[i].surface.clone(), self.app.popups[i].xdg_surface.clone()),
            None => (self.app.surface.clone().unwrap(), self.app.xdg_surface.clone().unwrap()),
        };
        if margin > 0 {
            xdg_surface.set_window_geometry(margin, margin, w - 2 * margin, h - 2 * margin);
        }
        surface.attach(Some(&buffer), 0, 0);
        match damage {
            Some((top, bottom)) => surface.damage_buffer(0, top, w, bottom - top),
            None => surface.damage_buffer(0, 0, i32::MAX, i32::MAX),
        }
        surface.commit();
    }

    /// Uma imagem `w`×`h` em memória compartilhada (veja `draw_on`).
    fn buffer(&self, w: i32, h: i32, margin: i32, color: [u8; 4]) -> wl_buffer::WlBuffer {
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
        pool.destroy(); // o buffer continua valendo
        buffer
    }

    /// Cria uma camada (como o Quickshell faz) e faz o commit inicial, vazio.
    fn create_layer(&mut self, ask: LayerAsk) -> usize {
        let qh = self.qh.clone();
        let index = self.app.layers.len();
        let surface = self.app.compositor.as_ref().unwrap().create_surface(&qh, ());
        let output = ask.output.map(|i| self.app.output_objects[i].1.clone());
        let shell = self.app.layer_shell.as_ref().unwrap();
        let layer = shell.get_layer_surface(&surface, output.as_ref(), ask.level, "teste".into(), &qh, index);
        layer.set_size(ask.size.0, ask.size.1);
        layer.set_anchor(ask.anchor);
        layer.set_exclusive_zone(ask.zone);
        layer.set_keyboard_interactivity(ask.keyboard);
        surface.commit();
        self.app.layers.push(TestLayer { surface, layer, size: (0, 0), configures: 0, closed: false });
        index
    }

    /// Desenha a camada inteira no tamanho que o compositor deu, na cor `color`.
    fn draw_layer(&mut self, index: usize, color: [u8; 4]) {
        let (w, h) = self.app.layers[index].size;
        let buffer = self.buffer(w, h, 0, color);
        let surface = &self.app.layers[index].surface;
        surface.attach(Some(&buffer), 0, 0);
        surface.damage_buffer(0, 0, i32::MAX, i32::MAX);
        surface.commit();
    }
}

/// O compositor, os apps (o primeiro é "o app" dos testes) e os eventos.
struct Harness {
    core: Core,
    peers: Vec<Peer>,
    /// Os eventos que o compositor mandaria para a Godot.
    events: Vec<Event>,
}

/// `h.app`, `h.qh`... falam do primeiro app (quase todo teste só tem um).
impl Deref for Harness {
    type Target = Peer;
    fn deref(&self) -> &Peer {
        &self.peers[0]
    }
}

impl DerefMut for Harness {
    fn deref_mut(&mut self) -> &mut Peer {
        &mut self.peers[0]
    }
}

/// Cor de teste, como o app grava: B, G, R, A.
const AZUL_ESCURO: [u8; 4] = [10, 20, 30, 0];
const VERMELHO: [u8; 4] = [0, 0, 200, 0];
const SOMBRA: [u8; 4] = [1, 1, 1, 0];

impl Harness {
    /// Liga o compositor e um app, que já pega os serviços (compositor, shm, xdg...).
    fn new() -> Harness {
        Harness::with_layout("us")
    }

    fn with_layout(layout: &str) -> Harness {
        let core = Core::new(layout, "").expect("o compositor liga");
        let mut h = Harness { core, peers: Vec::new(), events: Vec::new() };
        h.add_peer();
        h
    }

    /// Liga mais um app e espera ele pegar os serviços. Devolve o número dele.
    fn add_peer(&mut self) -> usize {
        let peer = Peer::connect(&mut self.core);
        self.peers.push(peer);
        let who = self.peers.len() - 1;
        self.pump("os serviços do compositor", |h| h.peers[who].ready());
        who
    }

    /// Alterna compositor e apps até `done` valer (ou falha depois de ~2 s).
    fn pump(&mut self, what: &str, mut done: impl FnMut(&mut Harness) -> bool) {
        for _ in 0..2000 {
            for peer in &mut self.peers {
                let _ = peer.conn.flush();
            }
            self.core.dispatch().unwrap();
            for peer in &mut self.peers {
                peer.sync();
            }
            let events = self.core.take_events();
            self.events.extend(events);
            if done(self) {
                return;
            }
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        panic!("tempo esgotado esperando: {what} (o app recebeu: {:?})", self.peers[0].app.input);
    }

    /// Cria a janela do app `who` e espera o primeiro configure, como todo app faz.
    fn open_window_of(&mut self, who: usize) {
        self.peers[who].create_window();
        let before = self.peers[who].app.configures;
        self.pump("o primeiro configure", |h| h.peers[who].app.configures > before);
    }

    fn open_window(&mut self) {
        self.open_window_of(0);
    }

    /// Janela aberta com uma imagem (muitos testes começam assim).
    fn open_and_draw(&mut self, margin: i32) {
        self.open_window();
        let (w, h) = self.app.size;
        self.draw_and_wait(w + 2 * margin, h + 2 * margin, margin, AZUL_ESCURO, None);
        self.app.input.clear();
        self.events.clear();
    }

    /// Espera até o app ter recebido `count` coisas do teclado/mouse.
    fn wait_input(&mut self, count: usize) {
        self.pump("o teclado/mouse", |h| h.app.input.len() >= count);
    }

    fn draw(&mut self, w: i32, h: i32, margin: i32, color: [u8; 4], damage: Option<(i32, i32)>) {
        self.peers[0].draw_on(None, w, h, margin, color, damage);
    }

    /// Desenha e espera o compositor processar (a janela fica "suja").
    fn draw_and_wait(&mut self, w: i32, h: i32, margin: i32, color: [u8; 4], damage: Option<(i32, i32)>) {
        let copies = self.core.state.copy_count;
        self.draw(w, h, margin, color, damage);
        self.pump("a imagem nova", |h| h.core.state.copy_count > copies);
    }

    /// Abre um menu e espera o lugar que o compositor deu.
    fn open_popup(&mut self, x: i32, y: i32, w: i32, h: i32) -> usize {
        let i = self.peers[0].create_popup(x, y, w, h);
        self.pump("o configure do menu", |h| h.app.popups[i].configures > 0);
        i
    }

    /// Desenha no menu e espera o compositor pôr na imagem da janela.
    fn draw_popup(&mut self, popup: usize, margin: i32, color: [u8; 4]) {
        let (_, _, w, h) = self.app.popups[popup].place.unwrap();
        let copies = self.core.state.copy_count;
        self.peers[0].draw_on(Some(popup), w + 2 * margin, h + 2 * margin, margin, color, None);
        self.pump("a imagem do menu", |h| h.core.state.copy_count > copies);
    }

    /// Põe a janela `id` (do app `who`) na saída e espera o app receber o
    /// tamanho do lugar e desenhar com ele, na cor `color`.
    fn place_and_draw(&mut self, who: usize, id: i64, output: usize, rect: Rect, color: [u8; 4]) {
        assert!(self.core.place(id, Some(output), rect));
        self.pump("o tamanho do lugar", |h| h.peers[who].app.size == (rect.w, rect.h));
        let copies = self.core.state.copy_count;
        self.peers[who].draw_on(None, rect.w, rect.h, 0, color, None);
        self.pump("a imagem no tamanho do lugar", |h| h.core.state.copy_count > copies);
    }

    /// O app `who` cria a camada e espera o primeiro configure (o tamanho).
    fn open_layer(&mut self, who: usize, ask: LayerAsk) -> usize {
        let i = self.peers[who].create_layer(ask);
        self.pump("o configure da camada", |h| h.peers[who].app.layers[i].configures > 0);
        i
    }

    /// Desenha a camada e espera o compositor copiar a imagem.
    fn draw_layer(&mut self, who: usize, index: usize, color: [u8; 4]) {
        let copies = self.core.state.copy_count;
        self.peers[who].draw_layer(index, color);
        self.pump("a imagem da camada", |h| h.core.state.copy_count > copies);
    }

    /// A camada aberta e desenhada (o id dela no compositor é o último criado).
    fn open_and_draw_layer(&mut self, who: usize, ask: LayerAsk, color: [u8; 4]) -> (usize, i64) {
        let i = self.open_layer(who, ask);
        self.draw_layer(who, i, color);
        let id = self.core.state.windows.iter().filter(|w| w.is_layer()).map(|w| w.id).max().unwrap();
        (i, id)
    }

    /// O pixel (x, y) da saída `output` composta, em RGBA.
    fn output_pixel(&self, output: usize, x: i32, y: i32) -> [u8; 4] {
        let slot = &self.core.state.outputs[output];
        let i = ((y * slot.size.0 + x) * 4) as usize;
        slot.pixels[i..i + 4].try_into().unwrap()
    }

    /// O pixel (x, y) da janela 1 como vai para a textura (com os menus), em RGBA.
    fn pixel(&mut self, x: i32, y: i32) -> [u8; 4] {
        let win = self.core.state.windows.iter_mut().find(|w| w.id == 1).expect("a janela 1 existe");
        let width = win.width();
        let image = win.image();
        let i = ((y * width + x) * 4) as usize;
        image[i..i + 4].try_into().unwrap()
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
    assert!(!h.app.states.contains(&xdg_toplevel::State::Activated), "só fica ativa com o foco do teclado");
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

#[test]
fn teclado_tem_o_layout_e_a_repeticao() {
    let h = Harness::with_layout("br");
    // O cabeçalho do keymap diz as peças usadas (ex.: xkb_symbols "pc_br_inet(evdev)").
    assert!(h.app.keymap.contains("_br_"), "o keymap é o do layout pedido (ABNT2)");
    assert_eq!(h.app.repeat, (30, 400), "o app repete a tecla: 30 por segundo, depois de 400 ms");
    let us = Harness::new();
    assert!(us.app.keymap.contains("_us_"));
}

#[test]
fn tecla_vai_para_a_janela_com_foco() {
    let mut h = Harness::with_layout("br");
    h.open_and_draw(0);
    assert!(!h.app.states.contains(&xdg_toplevel::State::Activated), "sem foco, não está ativa");
    let before = h.app.configures;
    h.core.focus(Some(1));
    h.pump("o foco e o configure", |h| h.app.configures > before && !h.app.input.is_empty());
    assert_eq!(h.app.input[0], "teclado entrou");
    assert!(h.app.states.contains(&xdg_toplevel::State::Activated), "com foco, fica ativa");
    assert_eq!(h.core.focused(), Some(1));
    h.app.input.clear();
    h.core.key(1, 30, true); // A
    h.core.key(1, 30, false);
    h.wait_input(2);
    assert_eq!(h.app.input, vec!["tecla 30 apertou", "tecla 30 soltou"]);
    // Shift muda os modificadores (o app sabe que é maiúscula).
    h.app.input.clear();
    h.core.key(1, 42, true);
    h.wait_input(2);
    assert_eq!(h.app.input, vec!["tecla 42 apertou", "modificadores 1"]);
}

#[test]
fn tecla_sem_foco_da_o_foco() {
    let mut h = Harness::new();
    h.open_and_draw(0);
    h.core.key(1, 30, true);
    h.wait_input(2);
    assert_eq!(h.app.input, vec!["teclado entrou", "tecla 30 apertou"]);
    h.core.key(99, 30, true); // janela que não existe: nada acontece
    h.pump("nada", |_| true);
    assert_eq!(h.app.input.len(), 2);
}

#[test]
fn tirar_o_foco_avisa_o_app() {
    let mut h = Harness::new();
    h.open_and_draw(0);
    h.core.focus(Some(1));
    h.wait_input(1);
    let before = h.app.configures;
    h.core.focus(None);
    h.pump("o teclado sair", |h| h.app.input.len() >= 2 && h.app.configures > before);
    assert_eq!(h.app.input[1], "teclado saiu");
    assert!(!h.app.states.contains(&xdg_toplevel::State::Activated));
    assert_eq!(h.core.focused(), None);
}

#[test]
fn clique_nas_coordenadas_certas_mesmo_com_sombra() {
    let mut h = Harness::new();
    h.open_and_draw(22); // a imagem da Godot começa 22 px para dentro
    h.core.pointer_motion(1, 10.0, 20.0);
    h.wait_input(1);
    assert_eq!(h.app.input[0], "mouse entrou em 32,42");
    h.core.pointer_motion(1, 100.5, 50.0);
    h.core.pointer_button(0x110, true);
    h.core.pointer_button(0x110, false);
    h.wait_input(4);
    assert_eq!(h.app.input[1..], ["mouse em 122.5,72", "botão 272 apertou", "botão 272 soltou"]);
    h.core.pointer_leave();
    h.wait_input(5);
    assert_eq!(h.app.input[4], "mouse saiu");
}

#[test]
fn rodinha_e_touchpad_rolam() {
    let mut h = Harness::new();
    h.open_and_draw(0);
    h.core.pointer_motion(1, 5.0, 5.0);
    h.wait_input(1);
    h.app.input.clear();
    h.core.pointer_axis(0.0, 1.0, true); // um dente para baixo
    h.wait_input(3);
    assert_eq!(h.app.input, vec!["rolagem pela rodinha", "rolagem 120 dentes/120 na vertical", "rolagem 15 na vertical"]);
    h.app.input.clear();
    h.core.pointer_axis(-7.5, 0.0, false); // touchpad, para a esquerda
    h.wait_input(2);
    assert_eq!(h.app.input, vec!["rolagem pelo touchpad", "rolagem -7.5 na horizontal"]);
}

#[test]
fn menu_aparece_por_cima_no_lugar_pedido() {
    let mut h = Harness::new();
    h.open_and_draw(22); // a janela tem sombra: o menu conta a partir do recorte
    let m = h.open_popup(100, 50, 200, 100);
    assert_eq!(h.app.popups[m].place, Some((100, 50, 200, 100)));
    assert_eq!(h.pixel(150, 80), rgba(AZUL_ESCURO), "antes da imagem do menu, só a janela");
    h.core.state.windows[0].dirty = false;
    h.draw_popup(m, 8, VERMELHO); // o menu também tem 8 px de sombra
    assert!(h.core.state.window(1).unwrap().dirty, "a textura da janela precisa subir de novo");
    assert_eq!(h.pixel(100, 50), rgba(VERMELHO), "canto do menu");
    assert_eq!(h.pixel(299, 149), rgba(VERMELHO), "outro canto do menu");
    assert_eq!(h.pixel(99, 50), rgba(AZUL_ESCURO), "a sombra do menu não aparece");
    assert_eq!(h.pixel(300, 149), rgba(AZUL_ESCURO));
    assert_eq!(h.pixel(150, 150), rgba(AZUL_ESCURO));
}

#[test]
fn menu_que_nao_cabe_e_empurrado_para_dentro() {
    let mut h = Harness::new();
    h.open_and_draw(0);
    let m = h.open_popup(1270, 710, 200, 100); // perto do canto de baixo à direita
    let (x, y, w, hh) = h.app.popups[m].place.unwrap();
    assert!(x + w <= WINDOW_SIZE.0 && y + hh <= WINDOW_SIZE.1, "o menu cabe no telão: {:?}", (x, y, w, hh));
}

#[test]
fn mouse_e_clique_vao_para_o_menu() {
    let mut h = Harness::new();
    h.open_and_draw(0);
    let m = h.open_popup(100, 50, 200, 100);
    h.draw_popup(m, 8, VERMELHO);
    h.core.pointer_motion(1, 150.0, 80.0);
    h.core.pointer_button(0x110, true);
    h.core.pointer_button(0x110, false);
    h.wait_input(3);
    // No menu: (150 − 100 + 8, 80 − 50 + 8), contando a sombra do menu.
    assert_eq!(h.app.input, vec!["mouse entrou em 58,38 (menu)", "botão 272 apertou", "botão 272 soltou"]);
    h.app.input.clear();
    // De volta na janela. (Com o botão apertado, o mouse ficaria "preso" ao
    // menu, como num arrastar: é a regra do Wayland.)
    h.core.pointer_motion(1, 50.0, 300.0);
    h.wait_input(2);
    assert_eq!(h.app.input, vec!["mouse saiu", "mouse entrou em 50,300"]);
}

#[test]
fn clique_fora_do_menu_com_grab_fecha_o_menu() {
    let mut h = Harness::new();
    h.open_and_draw(0);
    h.core.focus(Some(1));
    h.wait_input(1);
    let m = h.open_popup(100, 50, 200, 100);
    let seat = h.app.seat.clone().unwrap();
    h.app.popups[m].popup.grab(&seat, h.app.keyboard_serial);
    h.draw_popup(m, 0, VERMELHO);
    h.pump("o teclado ir para o menu", |h| h.app.input.len() >= 3);
    assert_eq!(h.app.input[1..], ["teclado saiu", "teclado entrou (menu)"], "o menu com grab recebe as setas");
    h.app.input.clear();
    h.core.pointer_motion(1, 600.0, 600.0); // fora do menu
    h.core.pointer_button(0x110, true);
    h.core.pointer_button(0x110, false);
    h.pump("o menu fechar", |h| h.app.popups[m].done);
    h.pump("um pouco mais", |_| true);
    assert_eq!(h.app.input, vec!["mouse entrou em 600,600"], "o clique que fechou o menu não vai para a janela");
    // O app obedece e destrói o menu: ele some da imagem e o teclado volta.
    h.app.input.clear();
    let popup = h.app.popups.remove(m);
    popup.popup.destroy();
    popup.xdg_surface.destroy();
    popup.surface.destroy();
    h.pump("o teclado voltar", |h| h.app.input.len() >= 2);
    assert_eq!(h.app.input, vec!["teclado saiu", "teclado entrou"]);
    assert!(h.core.state.window(1).unwrap().popups.is_empty());
    assert_eq!(h.pixel(150, 80), rgba(AZUL_ESCURO), "sem o menu, a imagem volta a ser só a janela");
    h.core.pointer_button(0x110, true); // agora o clique vai para a janela
    h.wait_input(3);
    assert_eq!(h.app.input[2], "botão 272 apertou");
}

#[test]
fn copiar_num_app_e_colar_no_outro() {
    let mut h = Harness::new();
    h.open_and_draw(0);
    let b = h.add_peer();
    h.open_window_of(b);
    let (w, hh) = h.peers[b].app.size;
    h.peers[b].draw_on(None, w, hh, 0, VERMELHO, None);
    h.pump("a janela do segundo app", |h| h.core.state.window(2).is_some_and(|w| w.mapped));

    // O app 1 (com o foco) copia um texto.
    h.core.focus(Some(1));
    h.wait_input(1);
    let qh = h.qh.clone();
    let source = h.app.data_manager.as_ref().unwrap().create_data_source(&qh, ());
    source.offer("text/plain;charset=utf-8".into());
    let serial = h.app.keyboard_serial;
    h.app.data_device.as_ref().unwrap().set_selection(Some(&source), serial);
    h.pump("o compositor guardar a seleção", |_| true);

    // O app 2 ganha o foco e vê o que tem para colar.
    h.core.focus(Some(2));
    h.pump("a oferta chegar no app 2", |h| h.peers[b].app.selection.is_some());
    assert!(h.peers[b].app.offered.contains(&"text/plain;charset=utf-8".to_string()));

    // O app 2 cola: pede o texto por um cano; o app 1 escreve nele.
    let (mut reader, writer) = UnixStream::pair().unwrap();
    let offer = h.peers[b].app.selection.clone().unwrap();
    offer.receive("text/plain;charset=utf-8".into(), writer.as_fd());
    let _ = h.peers[b].conn.flush();
    drop(writer); // só o app 1 fica com a ponta de escrever
    h.pump("o app 1 mandar o texto", |h| h.app.copied_text_sent);
    let mut text = String::new();
    reader.read_to_string(&mut text).unwrap();
    assert_eq!(text, "ação copiada");
}

// --- Saídas: os monitores da mesa (Fase 14.26) ----------------------------------

const VERDE: [u8; 4] = [0, 180, 0, 0];

/// Três monitores; nos testes, pequenos (a mesa usa 1920×1080).
const MONITORES: [(i32, i32); 3] = [(640, 240), (640, 240), (640, 240)];

/// Compositor com três saídas e dois apps, cada um com uma janela aberta
/// (a do app 0 é a 1, a do app 1 é a 2).
fn mesa_com_duas_janelas() -> Harness {
    let mut h = Harness::new();
    assert!(h.core.set_outputs(&MONITORES));
    h.add_peer();
    h.open_window_of(0);
    h.open_window_of(1);
    h
}

#[test]
fn set_outputs_anuncia_tres_monitores_com_xdg_output() {
    let mut h = Harness::new();
    h.pump("o primeiro monitor", |h| h.app.outputs.len() == 1);
    assert!(h.app.xdg_output, "o xdg-output é anunciado");
    assert!(h.core.set_outputs(&MONITORES));
    h.pump("os três monitores (o velho sai)", |h| h.app.outputs.len() == 3);
    assert_eq!(h.core.output_count(), 3);
    let x: Vec<i32> = h.core.state.outputs.iter().map(|o| o.output.current_location().x).collect();
    assert_eq!(x, vec![0, 640, 1280], "lado a lado");
    assert!(!h.core.set_outputs(&[]), "nenhum monitor é recusado");
    assert_eq!(h.core.output_count(), 3);
}

#[test]
fn duas_janelas_lado_a_lado_na_saida_0() {
    let mut h = mesa_com_duas_janelas();
    h.place_and_draw(0, 1, 0, Rect::new(0, 0, 320, 240), AZUL_ESCURO);
    h.place_and_draw(1, 2, 0, Rect::new(320, 0, 320, 240), VERDE);
    let changed = h.core.compose_outputs();
    assert!(changed.contains(&0));
    assert_eq!(h.output_pixel(0, 10, 10), rgba(AZUL_ESCURO), "metade da esquerda");
    assert_eq!(h.output_pixel(0, 319, 239), rgba(AZUL_ESCURO));
    assert_eq!(h.output_pixel(0, 320, 0), rgba(VERDE), "metade da direita");
    assert_eq!(h.output_pixel(0, 639, 120), rgba(VERDE));
    assert_eq!(h.output_pixel(1, 10, 10), OUTPUT_BACKGROUND, "a saída 1 está vazia");
    assert_eq!(h.core.state.window_at(0, 400.0, 100.0), Some(2));
    assert_eq!(h.core.state.window_at(0, 100.0, 100.0), Some(1));
    assert_eq!(h.core.state.window_at(1, 100.0, 100.0), None);
}

#[test]
fn janela_na_saida_2_nao_aparece_na_0() {
    let mut h = mesa_com_duas_janelas();
    h.place_and_draw(0, 1, 0, Rect::new(0, 0, 320, 240), AZUL_ESCURO);
    h.place_and_draw(1, 2, 0, Rect::new(320, 0, 320, 240), VERDE);
    h.core.compose_outputs();
    // A janela 2 vai para a saída 2, no mesmo lugar e tamanho.
    assert!(h.core.place(2, Some(2), Rect::new(320, 0, 320, 240)));
    let changed = h.core.compose_outputs();
    assert_eq!(changed, vec![0, 2], "só as duas saídas que mudaram");
    assert_eq!(h.output_pixel(0, 400, 100), OUTPUT_BACKGROUND, "saiu da 0");
    assert_eq!(h.output_pixel(2, 400, 100), rgba(VERDE), "chegou na 2");
    assert_eq!(h.output_pixel(0, 100, 100), rgba(AZUL_ESCURO), "a outra continua");
    // Tirar a janela das saídas.
    assert!(h.core.place(2, None, Rect::default()));
    assert_eq!(h.core.compose_outputs(), vec![2]);
    assert_eq!(h.output_pixel(2, 400, 100), OUTPUT_BACKGROUND);
    assert!(!h.core.place(2, Some(3), Rect::new(0, 0, 10, 10)), "saída que não existe");
    assert!(!h.core.place(99, Some(0), Rect::new(0, 0, 10, 10)), "janela que não existe");
}

#[test]
fn clique_vai_para_a_janela_da_direita() {
    let mut h = mesa_com_duas_janelas();
    h.place_and_draw(0, 1, 0, Rect::new(0, 0, 320, 240), AZUL_ESCURO);
    h.place_and_draw(1, 2, 0, Rect::new(320, 0, 320, 240), VERDE);
    h.core.pointer_motion_output(0, 400.0, 100.0);
    h.core.pointer_button(0x110, true);
    h.core.pointer_button(0x110, false);
    h.pump("o clique no app da direita", |h| h.peers[1].app.input.len() >= 3);
    assert_eq!(h.peers[1].app.input, vec!["mouse entrou em 80,100", "botão 272 apertou", "botão 272 soltou"]);
    assert!(h.peers[0].app.input.is_empty(), "o app da esquerda não recebe nada");
    // Num canto sem janela (outra saída), o mouse sai dos apps.
    h.core.pointer_motion_output(1, 10.0, 10.0);
    h.pump("o mouse sair", |h| h.peers[1].app.input.len() >= 4);
    assert_eq!(h.peers[1].app.input[3], "mouse saiu");
}

#[test]
fn compoe_so_quando_muda() {
    let mut h = mesa_com_duas_janelas();
    h.place_and_draw(0, 1, 0, Rect::new(0, 0, 320, 240), AZUL_ESCURO);
    h.place_and_draw(1, 2, 1, Rect::new(0, 0, 320, 240), VERDE);
    assert_eq!(h.core.compose_outputs(), vec![0, 1, 2], "a primeira vez, todas");
    assert!(h.core.compose_outputs().is_empty(), "nada mudou, nada compõe");
    let copies = h.core.state.copy_count;
    h.peers[1].draw_on(None, 320, 240, 0, VERMELHO, Some((10, 20)));
    h.pump("a imagem nova", |h| h.core.state.copy_count > copies);
    assert_eq!(h.core.compose_outputs(), vec![1], "só a saída da janela que mudou");
    assert_eq!(h.output_pixel(1, 5, 15), rgba(VERMELHO));
}

#[test]
fn janela_maior_que_o_lugar_nao_invade_a_vizinha() {
    let mut h = mesa_com_duas_janelas();
    h.place_and_draw(1, 2, 0, Rect::new(320, 0, 320, 240), VERDE);
    h.place_and_draw(0, 1, 0, Rect::new(0, 0, 320, 240), AZUL_ESCURO);
    // O app 0 ignora o tamanho e desenha 400 de largura: o que sobra é cortado.
    let copies = h.core.state.copy_count;
    h.peers[0].draw_on(None, 400, 240, 0, AZUL_ESCURO, None);
    h.pump("a imagem grande", |h| h.core.state.copy_count > copies);
    h.core.compose_outputs();
    assert_eq!(h.output_pixel(0, 330, 10), rgba(VERDE));
    assert_eq!(h.core.state.window_at(0, 330.0, 10.0), Some(2));
}

#[test]
fn raise_poe_por_cima() {
    let mut h = mesa_com_duas_janelas();
    h.place_and_draw(0, 1, 0, Rect::new(0, 0, 320, 240), AZUL_ESCURO);
    h.place_and_draw(1, 2, 0, Rect::new(100, 0, 320, 240), VERDE); // por cima, sobrepondo
    h.core.compose_outputs();
    assert_eq!(h.output_pixel(0, 150, 10), rgba(VERDE));
    assert!(h.core.raise(1));
    assert_eq!(h.core.compose_outputs(), vec![0]);
    assert_eq!(h.output_pixel(0, 150, 10), rgba(AZUL_ESCURO));
    assert_eq!(h.core.state.window_at(0, 150.0, 10.0), Some(1));
}

#[test]
fn fechar_a_janela_limpa_a_saida() {
    let mut h = mesa_com_duas_janelas();
    h.place_and_draw(1, 2, 0, Rect::new(320, 0, 320, 240), VERDE);
    h.core.compose_outputs();
    assert!(h.core.close(2));
    h.pump("o app 1 receber o pedido de fechar", |h| h.peers[1].app.close_requested);
    h.peers[1].app.toplevel.take().unwrap().destroy();
    h.peers[1].app.xdg_surface.take().unwrap().destroy();
    h.pump("a janela fechar", |h| h.events.contains(&Event::Closed(2)));
    assert_eq!(h.core.compose_outputs(), vec![0]);
    assert_eq!(h.output_pixel(0, 400, 100), OUTPUT_BACKGROUND);
}

#[test]
fn trocar_as_saidas_tira_o_lugar_de_quem_sobrou() {
    let mut h = mesa_com_duas_janelas();
    h.place_and_draw(1, 2, 2, Rect::new(0, 0, 320, 240), VERDE);
    assert!(h.core.set_outputs(&[(640, 240)]));
    assert!(h.core.state.window(2).unwrap().place.is_none(), "a saída 2 sumiu");
    assert_eq!(h.core.compose_outputs(), vec![0]);
}

// --- Camadas (Fase 14.27) -------------------------------------------------------

const AMARELO: [u8; 4] = [0, 200, 200, 0];
const ROXO: [u8; 4] = [120, 0, 90, 0];

/// Três monitores, e o app 0 já sabe deles e do layer-shell.
fn mesa_com_camadas() -> Harness {
    let mut h = Harness::new();
    assert!(h.core.set_outputs(&MONITORES));
    h.pump("os três monitores e o layer-shell", |h| h.app.output_objects.len() == 3 && h.app.layer_shell.is_some());
    h
}

/// A mesa com um segundo app que tem uma janela (id 1) na saída `output`,
/// ocupando-a toda, em verde. Devolve o número do app da janela.
fn mesa_com_janela(h: &mut Harness, output: usize) -> usize {
    let w = h.add_peer();
    h.open_window_of(w);
    h.place_and_draw(w, 1, output, Rect::new(0, 0, 640, 240), VERDE);
    w
}

/// Fecha a camada `i` do app `who` (como o app faz ao sair).
fn destroy_layer(h: &mut Harness, who: usize, i: usize) {
    let layer = &h.peers[who].app.layers[i];
    layer.layer.destroy();
    layer.surface.destroy();
}

fn input_has(h: &Harness, who: usize, line: &str) -> bool {
    h.peers[who].app.input.iter().any(|s| s == line)
}

#[test]
fn barra_de_30_px_reduz_a_area_util() {
    let mut h = mesa_com_camadas();
    let (i, id) = h.open_and_draw_layer(0, LayerAsk { output: Some(1), ..BARRA }, AMARELO);
    assert_eq!(h.app.layers[i].size, (640, 30), "a largura da saída e a altura pedida");
    assert_eq!(h.core.state.window(id).unwrap().place, Some((1, Rect::new(0, 0, 640, 30))));
    assert_eq!(h.core.usable_area(1), Some(Rect::new(0, 30, 640, 210)), "o alto fica reservado");
    assert_eq!(h.core.usable_area(0), Some(Rect::new(0, 0, 640, 240)), "a outra saída não muda");
    assert!(h.events.contains(&Event::UsableAreaChanged(1, Rect::new(0, 30, 640, 210))));
    assert!(!h.events.iter().any(|e| matches!(e, Event::Opened(..))), "camada não vira janela para a Godot");
    h.core.compose_outputs();
    assert_eq!(h.output_pixel(1, 10, 10), rgba(AMARELO));
    assert_eq!(h.output_pixel(1, 10, 40), OUTPUT_BACKGROUND);
    // A barra fecha: a faixa fica livre de novo.
    h.events.clear();
    destroy_layer(&mut h, 0, i);
    h.pump("a área útil voltar", |h| h.events.contains(&Event::UsableAreaChanged(1, Rect::new(0, 0, 640, 240))));
    assert!(h.events.iter().all(|e| !matches!(e, Event::Closed(_))), "nem aviso de janela fechada");
    assert_eq!(h.core.compose_outputs(), vec![1]);
    assert_eq!(h.output_pixel(1, 10, 10), OUTPUT_BACKGROUND);
}

#[test]
fn overlay_com_teclado_exclusivo_recebe_a_tecla() {
    let mut h = mesa_com_camadas();
    let w = mesa_com_janela(&mut h, 0);
    h.core.focus(Some(1));
    h.pump("o teclado na janela", |h| input_has(h, w, "teclado entrou"));
    let menu = LayerAsk {
        level: zwlr_layer_shell_v1::Layer::Overlay,
        anchor: Anchor::empty(),
        size: (200, 100),
        zone: 0,
        keyboard: KeyboardInteractivity::Exclusive,
        output: Some(0),
    };
    let (i, id) = h.open_and_draw_layer(0, menu, AMARELO);
    assert_eq!(h.core.state.window(id).unwrap().place, Some((0, Rect::new(220, 70, 200, 100))), "no meio");
    h.pump("o teclado no menu", |h| input_has(h, 0, "teclado entrou (camada)"));
    assert_eq!(h.peers[w].app.input.last().unwrap(), "teclado saiu");
    // O hub manda a tecla para a janela, mas quem recebe é o menu.
    h.core.key(1, 30, true);
    h.core.key(1, 30, false);
    // E a tecla "para quem tem o teclado" também.
    h.core.key_focused(28, true);
    h.pump("as teclas no menu", |h| input_has(h, 0, "tecla 28 apertou"));
    let keys: Vec<&String> = h.app.input.iter().filter(|s| s.starts_with("tecla ")).collect();
    assert_eq!(keys, vec!["tecla 30 apertou", "tecla 30 soltou", "tecla 28 apertou"]);
    assert!(!h.peers[w].app.input.iter().any(|s| s.starts_with("tecla ")), "a janela não recebe");
    assert_eq!(h.core.focused(), Some(1), "o foco do hub continua na janela");
    // O menu fecha: o teclado volta para a janela.
    h.peers[w].app.input.clear();
    destroy_layer(&mut h, 0, i);
    h.pump("o teclado de volta na janela", |h| input_has(h, w, "teclado entrou"));
}

#[test]
fn clique_na_barra_nao_vai_para_a_janela() {
    let mut h = mesa_com_camadas();
    let w = mesa_com_janela(&mut h, 0);
    h.open_and_draw_layer(0, LayerAsk { output: Some(0), ..BARRA }, AMARELO);
    h.core.compose_outputs();
    assert_eq!(h.output_pixel(0, 100, 10), rgba(AMARELO), "a barra fica por cima da janela");
    assert_eq!(h.output_pixel(0, 100, 100), rgba(VERDE));
    assert_eq!(h.core.state.window_at(0, 100.0, 10.0), None, "na barra não há janela para focar");
    assert_eq!(h.core.state.window_at(0, 100.0, 100.0), Some(1));
    h.core.pointer_motion_output(0, 100.0, 10.0);
    h.core.pointer_button(0x110, true);
    h.core.pointer_button(0x110, false);
    h.pump("o clique na barra", |h| h.app.input.len() >= 3);
    assert_eq!(h.app.input, vec!["mouse entrou em 100,10 (camada)", "botão 272 apertou", "botão 272 soltou"]);
    assert!(h.peers[w].app.input.is_empty(), "a janela embaixo não recebe nada");
    // Saindo da barra para a janela, o mouse muda de dono.
    h.core.pointer_motion_output(0, 100.0, 100.0);
    h.pump("o mouse na janela", |h| input_has(h, w, "mouse entrou em 100,100"));
}

#[test]
fn fundo_fica_atras_das_janelas() {
    let mut h = mesa_com_camadas();
    let fundo = LayerAsk {
        level: zwlr_layer_shell_v1::Layer::Background,
        anchor: Anchor::Top | Anchor::Bottom | Anchor::Left | Anchor::Right,
        size: (0, 0),
        zone: -1,
        keyboard: KeyboardInteractivity::None,
        output: Some(2),
    };
    let (i, _) = h.open_and_draw_layer(0, fundo, ROXO);
    assert_eq!(h.app.layers[i].size, (640, 240), "estica na saída inteira");
    let w = h.add_peer();
    h.open_window_of(w);
    // A camada nasceu antes: a janela é a de id 2.
    h.place_and_draw(w, 2, 2, Rect::new(0, 0, 320, 240), VERDE);
    h.core.compose_outputs();
    assert_eq!(h.output_pixel(2, 10, 10), rgba(VERDE), "a janela fica na frente do fundo");
    assert_eq!(h.output_pixel(2, 400, 10), rgba(ROXO), "fora da janela, o fundo");
    assert_eq!(h.core.usable_area(2), Some(Rect::new(0, 0, 640, 240)), "o fundo não reserva nada");
    assert_eq!(h.core.state.window_at(2, 400.0, 10.0), None);
    h.core.pointer_motion_output(2, 400.0, 10.0);
    h.pump("o mouse no fundo", |h| input_has(h, 0, "mouse entrou em 400,10 (camada)"));
}

#[test]
fn camada_on_demand_ganha_o_teclado_no_clique() {
    let mut h = mesa_com_camadas();
    let w = mesa_com_janela(&mut h, 0);
    h.core.focus(Some(1));
    let busca = LayerAsk { output: Some(0), keyboard: KeyboardInteractivity::OnDemand, ..BARRA };
    h.open_and_draw_layer(0, busca, AMARELO);
    assert!(!input_has(&h, 0, "teclado entrou (camada)"), "só ganha o teclado no clique");
    h.core.pointer_motion_output(0, 50.0, 10.0);
    h.core.pointer_button(0x110, true);
    h.core.pointer_button(0x110, false);
    h.pump("o teclado na barra", |h| input_has(h, 0, "teclado entrou (camada)"));
    assert!(input_has(&h, w, "teclado saiu"));
    // Clicar na janela devolve o teclado para ela.
    h.peers[w].app.input.clear();
    h.core.pointer_motion_output(0, 50.0, 100.0);
    h.core.pointer_button(0x110, true);
    h.core.pointer_button(0x110, false);
    h.pump("o teclado de volta", |h| input_has(h, w, "teclado entrou"));
    assert!(input_has(&h, 0, "teclado saiu"));
}

#[test]
fn menu_da_barra_desce_para_fora_dela() {
    let mut h = mesa_com_camadas();
    let (i, _) = h.open_and_draw_layer(0, LayerAsk { output: Some(0), ..BARRA }, AMARELO);
    let p = h.peers[0].create_popup_on(Some(i), 10, 30, 100, 80);
    h.pump("o configure do menu", |h| h.app.popups[p].configures > 0);
    assert_eq!(h.app.popups[p].place, Some((10, 30, 100, 80)), "embaixo da barra, sem ser empurrado para dentro dela");
    h.draw_popup(p, 0, VERMELHO);
    h.core.compose_outputs();
    assert_eq!(h.output_pixel(0, 20, 60), rgba(VERMELHO), "o menu aparece fora da faixa da barra");
    assert_eq!(h.output_pixel(0, 200, 60), OUTPUT_BACKGROUND);
    h.core.pointer_motion_output(0, 20.0, 60.0);
    h.pump("o mouse no menu", |h| input_has(h, 0, "mouse entrou em 10,30 (menu)"));
}

#[test]
fn camada_sem_monitor_vai_para_o_da_janela_com_foco() {
    let mut h = mesa_com_camadas();
    mesa_com_janela(&mut h, 2);
    h.core.focus(Some(1));
    let (_, id) = h.open_and_draw_layer(0, BARRA, AMARELO);
    assert_eq!(h.core.state.window(id).unwrap().place.map(|(o, _)| o), Some(2));
    assert_eq!(h.core.usable_area(2), Some(Rect::new(0, 30, 640, 210)));
}

#[test]
fn esconder_a_camada_solta_a_faixa_e_pede_configure_de_novo() {
    let mut h = mesa_com_camadas();
    let (i, _) = h.open_and_draw_layer(0, LayerAsk { output: Some(0), ..BARRA }, AMARELO);
    assert_eq!(h.core.usable_area(0).unwrap().y, 30);
    let surface = h.app.layers[i].surface.clone();
    surface.attach(None, 0, 0);
    surface.commit();
    h.pump("a faixa ficar livre", |h| h.core.usable_area(0) == Some(Rect::new(0, 0, 640, 240)));
    // Para voltar: commit vazio, configure novo, imagem.
    let before = h.app.layers[i].configures;
    surface.commit();
    h.pump("o configure de novo", |h| h.app.layers[i].configures > before);
    assert_eq!(h.app.layers[i].size, (640, 30));
    h.draw_layer(0, i, AMARELO);
    assert_eq!(h.core.usable_area(0).unwrap().y, 30, "reservou de novo");
}

#[test]
fn trocar_as_saidas_fecha_as_camadas() {
    let mut h = mesa_com_camadas();
    let (i, id) = h.open_and_draw_layer(0, LayerAsk { output: Some(0), ..BARRA }, AMARELO);
    assert!(h.core.set_outputs(&MONITORES));
    h.pump("o aviso de fechar a camada", |h| h.app.layers[i].closed);
    assert!(h.core.state.window(id).unwrap().place.is_none());
    assert_eq!(h.core.usable_area(0), Some(Rect::new(0, 0, 640, 240)), "os monitores novos nascem livres");
    assert!(!h.core.place(id, Some(0), Rect::new(0, 0, 10, 10)), "o hub não muda o lugar de uma camada");
}

#[test]
fn fechar_a_camada_e_dar_commit_na_superficie_nao_derruba_o_app() {
    // O Quickshell faz assim ao fechar o menu: destrói a camada e depois
    // esvazia a superfície (attach nil + commit) antes de destruí-la.
    let mut h = mesa_com_camadas();
    let (i, _) = h.open_and_draw_layer(0, LayerAsk { output: Some(0), ..BARRA }, AMARELO);
    let surface = h.app.layers[i].surface.clone();
    h.app.layers[i].layer.destroy();
    surface.attach(None, 0, 0);
    surface.commit();
    h.pump("a faixa ficar livre", |h| h.core.usable_area(0) == Some(Rect::new(0, 0, 640, 240)));
    for _ in 0..5 {
        h.pump("mais um pouco", |_| true);
    }
    assert!(h.conn.protocol_error().is_none(), "erro de protocolo: {:?}", h.conn.protocol_error());
    // O app continua vivo: cria outra camada e ela aparece.
    h.open_and_draw_layer(0, LayerAsk { output: Some(0), ..BARRA }, AMARELO);
    assert_eq!(h.core.usable_area(0).unwrap().y, 30);
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
        if let wl_registry::Event::GlobalRemove { name } = event {
            app.outputs.retain(|&n| n != name);
            app.output_objects.retain(|(n, _)| *n != name);
            return;
        }
        if let wl_registry::Event::Global { name, interface, version } = event {
            match interface.as_str() {
                "wl_output" => {
                    app.outputs.push(name);
                    app.output_objects.push((name, registry.bind(name, version.min(4), qh, ())));
                }
                "zwlr_layer_shell_v1" => app.layer_shell = Some(registry.bind(name, version.min(4), qh, ())),
                "zxdg_output_manager_v1" => app.xdg_output = true,
                "wl_compositor" => app.compositor = Some(registry.bind(name, version.min(4), qh, ())),
                "wl_shm" => app.shm = Some(registry.bind(name, 1, qh, ())),
                "xdg_wm_base" => app.wm_base = Some(registry.bind(name, version.min(5), qh, ())),
                "zxdg_decoration_manager_v1" => app.decoration_manager = Some(registry.bind(name, 1, qh, ())),
                "wl_seat" => app.seat = Some(registry.bind(name, version.min(8), qh, ())),
                "wl_data_device_manager" => app.data_manager = Some(registry.bind(name, version.min(3), qh, ())),
                _ => {}
            }
            // O "data device" (copiar e colar) precisa do seat e do gerente.
            if let (Some(manager), Some(seat), None) = (&app.data_manager, &app.seat, &app.data_device) {
                app.data_device = Some(manager.get_data_device(seat, qh, ()));
            }
        }
    }
}

impl Dispatch<wl_seat::WlSeat, ()> for App {
    fn event(app: &mut Self, seat: &wl_seat::WlSeat, event: wl_seat::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        if let wl_seat::Event::Capabilities { capabilities: WEnum::Value(caps) } = event {
            if caps.contains(wl_seat::Capability::Keyboard) && app.keyboard.is_none() {
                app.keyboard = Some(seat.get_keyboard(qh, ()));
            }
            if caps.contains(wl_seat::Capability::Pointer) && app.pointer.is_none() {
                app.pointer = Some(seat.get_pointer(qh, ()));
            }
        }
    }
}

impl Dispatch<wl_keyboard::WlKeyboard, ()> for App {
    fn event(app: &mut Self, _: &wl_keyboard::WlKeyboard, event: wl_keyboard::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        match event {
            wl_keyboard::Event::Keymap { fd, size, .. } => {
                let mut text = vec![0u8; size as usize];
                std::fs::File::from(fd).read_exact_at(&mut text, 0).unwrap();
                app.keymap = String::from_utf8_lossy(&text).into_owned();
            }
            wl_keyboard::Event::RepeatInfo { rate, delay } => app.repeat = (rate, delay),
            wl_keyboard::Event::Enter { serial, surface, .. } => {
                app.keyboard_serial = serial;
                app.input.push(format!("teclado entrou{}", app.popup_mark(&surface)));
            }
            wl_keyboard::Event::Leave { .. } => app.input.push("teclado saiu".into()),
            wl_keyboard::Event::Key { key, state, .. } => {
                let pressed = state == WEnum::Value(wl_keyboard::KeyState::Pressed);
                app.input.push(format!("tecla {key} {}", if pressed { "apertou" } else { "soltou" }));
            }
            wl_keyboard::Event::Modifiers { mods_depressed, .. } if mods_depressed != 0 => {
                app.input.push(format!("modificadores {mods_depressed}"));
            }
            _ => {}
        }
    }
}

impl Dispatch<wl_pointer::WlPointer, ()> for App {
    fn event(app: &mut Self, _: &wl_pointer::WlPointer, event: wl_pointer::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        let axis_name = |axis: WEnum<wl_pointer::Axis>| {
            if axis == WEnum::Value(wl_pointer::Axis::VerticalScroll) { "vertical" } else { "horizontal" }
        };
        match event {
            wl_pointer::Event::Enter { surface_x, surface_y, surface, .. } => {
                app.input.push(format!("mouse entrou em {surface_x},{surface_y}{}", app.popup_mark(&surface)))
            }
            wl_pointer::Event::Leave { .. } => app.input.push("mouse saiu".into()),
            wl_pointer::Event::Motion { surface_x, surface_y, .. } => {
                app.input.push(format!("mouse em {surface_x},{surface_y}"))
            }
            wl_pointer::Event::Button { button, state, .. } => {
                let pressed = state == WEnum::Value(wl_pointer::ButtonState::Pressed);
                app.input.push(format!("botão {button} {}", if pressed { "apertou" } else { "soltou" }));
            }
            wl_pointer::Event::AxisSource { axis_source } => {
                let wheel = axis_source == WEnum::Value(wl_pointer::AxisSource::Wheel);
                app.input.push(format!("rolagem pel{}", if wheel { "a rodinha" } else { "o touchpad" }));
            }
            wl_pointer::Event::AxisValue120 { axis, value120 } => {
                app.input.push(format!("rolagem {value120} dentes/120 na {}", axis_name(axis)))
            }
            wl_pointer::Event::Axis { axis, value, .. } => app.input.push(format!("rolagem {value} na {}", axis_name(axis))),
            _ => {}
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

impl App {
    /// " (menu)" se a superfície for de um menu deste app, " (camada)" se
    /// for de uma camada (para os testes saberem onde caiu).
    fn popup_mark(&self, surface: &wl_surface::WlSurface) -> &'static str {
        if self.popups.iter().any(|p| &p.surface == surface) {
            " (menu)"
        } else if self.layers.iter().any(|l| &l.surface == surface) {
            " (camada)"
        } else {
            ""
        }
    }
}

/// O xdg_surface de um menu (o número é o índice em `App::popups`).
impl Dispatch<xdg_surface::XdgSurface, usize> for App {
    fn event(app: &mut Self, surface: &xdg_surface::XdgSurface, event: xdg_surface::Event, index: &usize, _: &Connection, _: &QueueHandle<Self>) {
        if let xdg_surface::Event::Configure { serial } = event {
            surface.ack_configure(serial);
            if let Some(p) = app.popups.get_mut(*index) {
                p.configures += 1;
            }
        }
    }
}

impl Dispatch<xdg_popup::XdgPopup, usize> for App {
    fn event(app: &mut Self, _: &xdg_popup::XdgPopup, event: xdg_popup::Event, index: &usize, _: &Connection, _: &QueueHandle<Self>) {
        let Some(p) = app.popups.get_mut(*index) else { return };
        match event {
            xdg_popup::Event::Configure { x, y, width, height } => p.place = Some((x, y, width, height)),
            xdg_popup::Event::PopupDone => p.done = true,
            _ => {}
        }
    }
}

impl Dispatch<wl_data_device::WlDataDevice, ()> for App {
    fn event(app: &mut Self, _: &wl_data_device::WlDataDevice, event: wl_data_device::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        match event {
            wl_data_device::Event::DataOffer { .. } => app.offered.clear(),
            wl_data_device::Event::Selection { id } => app.selection = id,
            _ => {}
        }
    }

    // O compositor cria um objeto "oferta" para cada coisa copiada.
    event_created_child!(App, wl_data_device::WlDataDevice, [
        wl_data_device::EVT_DATA_OFFER_OPCODE => (wl_data_offer::WlDataOffer, ()),
    ]);
}

impl Dispatch<wl_data_offer::WlDataOffer, ()> for App {
    fn event(app: &mut Self, _: &wl_data_offer::WlDataOffer, event: wl_data_offer::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        if let wl_data_offer::Event::Offer { mime_type } = event {
            app.offered.push(mime_type);
        }
    }
}

/// O app que copiou: quando alguém cola, ele escreve o texto no cano.
impl Dispatch<wl_data_source::WlDataSource, ()> for App {
    fn event(app: &mut Self, _: &wl_data_source::WlDataSource, event: wl_data_source::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        if let wl_data_source::Event::Send { fd, .. } = event {
            let mut pipe = std::fs::File::from(fd);
            pipe.write_all("ação copiada".as_bytes()).unwrap();
            app.copied_text_sent = true; // o cano fecha aqui (o arquivo sai de cena)
        }
    }
}

/// A camada do app de teste (o número é o índice em `App::layers`).
impl Dispatch<zwlr_layer_surface_v1::ZwlrLayerSurfaceV1, usize> for App {
    fn event(
        app: &mut Self,
        layer: &zwlr_layer_surface_v1::ZwlrLayerSurfaceV1,
        event: zwlr_layer_surface_v1::Event,
        index: &usize,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(l) = app.layers.get_mut(*index) else { return };
        match event {
            zwlr_layer_surface_v1::Event::Configure { serial, width, height } => {
                layer.ack_configure(serial);
                l.size = (width as i32, height as i32);
                l.configures += 1;
            }
            zwlr_layer_surface_v1::Event::Closed => l.closed = true,
            _ => {}
        }
    }
}

delegate_noop!(App: zwlr_layer_shell_v1::ZwlrLayerShellV1);
delegate_noop!(App: ignore wl_output::WlOutput);
delegate_noop!(App: wl_compositor::WlCompositor);
delegate_noop!(App: ignore wl_surface::WlSurface);
delegate_noop!(App: ignore wl_shm::WlShm);
delegate_noop!(App: wl_shm_pool::WlShmPool);
delegate_noop!(App: ignore wl_buffer::WlBuffer);
delegate_noop!(App: zxdg_decoration_manager_v1::ZxdgDecorationManagerV1);
delegate_noop!(App: xdg_positioner::XdgPositioner);
delegate_noop!(App: wl_data_device_manager::WlDataDeviceManager);
