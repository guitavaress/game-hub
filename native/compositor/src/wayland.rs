//! O lado Wayland do compositor: o que os apps enxergam.
//!
//! Um app aberto pelo hub conecta no socket do hub (ex.: `gamehub-0`) e acha
//! aqui um "monitor" (o output `HUB-1`), um teclado e um mouse (o seat), e
//! o xdg-shell, que é o jeito de criar janelas. Cada janela ("toplevel") vira
//! um `Win`, com a imagem já em RGBA, pronta para a Godot.
//!
//! Nada aqui conhece a Godot: o `Core` é o compositor inteiro, e o nó
//! (`node.rs`) só chama o `Core` e transforma os `Event`s em sinais. Por isso
//! os testes (`tests.rs`) usam o `Core` direto, com um app de teste.

use std::os::unix::net::UnixStream;
use std::sync::Arc;
use std::time::Instant;

use smithay::input::keyboard::XkbConfig;
use smithay::input::pointer::CursorImageStatus;
use smithay::input::{Seat, SeatHandler, SeatState};
use smithay::output::{Mode, Output, PhysicalProperties, Scale, Subpixel};
use smithay::reexports::wayland_protocols::xdg::decoration::zv1::server::zxdg_toplevel_decoration_v1::Mode as DecorationMode;
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::reexports::wayland_server::backend::{ClientData, ClientId, DisconnectReason};
use smithay::reexports::wayland_server::protocol::wl_callback::WlCallback;
use smithay::reexports::wayland_server::protocol::{wl_buffer, wl_seat, wl_surface::WlSurface};
use smithay::reexports::wayland_server::{Client, Display, DisplayHandle, ListeningSocket, Resource};
use smithay::utils::{Serial, Transform};
use smithay::wayland::buffer::BufferHandler;
use smithay::wayland::compositor::{
    with_states, BufferAssignment, CompositorClientState, CompositorHandler, CompositorState, Damage,
    SurfaceAttributes,
};
use smithay::wayland::output::{OutputHandler, OutputManagerState};
use smithay::wayland::selection::data_device::{
    ClientDndGrabHandler, DataDeviceHandler, DataDeviceState, ServerDndGrabHandler,
};
use smithay::wayland::selection::SelectionHandler;
use smithay::wayland::shell::xdg::decoration::{XdgDecorationHandler, XdgDecorationState};
use smithay::wayland::shell::xdg::{
    PopupSurface, PositionerState, SurfaceCachedState, ToplevelSurface, XdgShellHandler, XdgShellState,
    XdgToplevelSurfaceData,
};
use smithay::wayland::shm::{with_buffer_contents, ShmHandler, ShmState};
use smithay::{
    delegate_compositor, delegate_data_device, delegate_output, delegate_seat, delegate_shm, delegate_xdg_decoration,
    delegate_xdg_shell,
};

use crate::pixels::{copy_rows, crop_rect, damaged_rows, Rect, ShmLayout};

/// Tamanho com que toda janela nasce (o de um telão), até o telão pedir outro
/// com `resize`.
pub const WINDOW_SIZE: (i32, i32) = (1280, 720);
/// O maior tamanho que o hub aceita pedir para uma janela.
pub const MAX_SIZE: i32 = 4096;

/// O que aconteceu e a Godot precisa saber (vira sinal no nó).
#[derive(Debug, PartialEq, Eq)]
pub enum Event {
    /// Janela nova com a primeira imagem: id, app_id, título, pid do app.
    Opened(i64, String, String, i64),
    /// A janela fechou (o app fechou, morreu ou escondeu a janela).
    Closed(i64),
    /// O app trocou o título da janela (ex.: o site aberto no navegador).
    TitleChanged(i64, String),
}

/// Uma janela de app.
pub struct Win {
    /// Número que a Godot usa para falar desta janela (1, 2, 3...).
    pub id: i64,
    pub toplevel: ToplevelSurface,
    /// A última imagem (só o recorte da janela), em RGBA: 4 bytes por pixel.
    pub pixels: Vec<u8>,
    /// Onde o recorte está dentro da imagem do app (a sombra fica de fora).
    pub crop: Rect,
    /// Tem imagem nova que ainda não subiu para a textura.
    pub dirty: bool,
    /// Já mandou a primeira imagem (só então a Godot fica sabendo da janela).
    pub mapped: bool,
    /// Pedidos de "me avise quando mostrar": respondidos em `frame_done()`.
    pub callbacks: Vec<WlCallback>,
}

impl Win {
    pub fn width(&self) -> i32 {
        self.crop.w
    }

    pub fn height(&self) -> i32 {
        self.crop.h
    }
}

pub struct State {
    pub dh: DisplayHandle,
    compositor_state: CompositorState,
    xdg_shell_state: XdgShellState,
    _decoration_state: XdgDecorationState,
    shm_state: ShmState,
    seat_state: SeatState<State>,
    data_device_state: DataDeviceState,
    _output_manager: OutputManagerState,
    pub seat: Seat<State>,
    output: Output,
    pub windows: Vec<Win>,
    next_id: i64,
    pub events: Vec<Event>,
    /// Quanto tempo as cópias shm → RGBA levaram, somado (para a medida).
    pub copy_us_total: u128,
    pub copy_count: u64,
}

impl State {
    /// Liga todos os "serviços" que os apps procuram. `layout` e `variant`
    /// são os do teclado (ex.: "br" e ""), no formato do xkb.
    pub fn new(dh: DisplayHandle, layout: &str, variant: &str) -> Result<State, String> {
        let mut seat_state = SeatState::new();
        let mut seat = seat_state.new_wl_seat(&dh, "hub");
        let xkb = XkbConfig { layout, variant, ..Default::default() };
        // 400 ms para começar a repetir, 30 repetições por segundo: quem repete é o app.
        seat.add_keyboard(xkb, 400, 30).map_err(|e| format!("keymap do layout '{layout}' falhou: {e}"))?;
        seat.add_pointer();

        // Um "monitor" de mentira, do tamanho de um telão.
        let output = Output::new(
            "HUB-1".into(),
            PhysicalProperties {
                size: (0, 0).into(),
                subpixel: Subpixel::Unknown,
                make: "Game Hub".into(),
                model: "Telao".into(),
            },
        );
        let mode = Mode { size: WINDOW_SIZE.into(), refresh: 60_000 };
        output.change_current_state(Some(mode), Some(Transform::Normal), Some(Scale::Integer(1)), Some((0, 0).into()));
        output.set_preferred(mode);
        output.create_global::<State>(&dh);

        Ok(State {
            compositor_state: CompositorState::new::<State>(&dh),
            xdg_shell_state: XdgShellState::new::<State>(&dh),
            _decoration_state: XdgDecorationState::new::<State>(&dh),
            shm_state: ShmState::new::<State>(&dh, vec![]),
            data_device_state: DataDeviceState::new::<State>(&dh),
            _output_manager: OutputManagerState::new(),
            seat_state,
            seat,
            output,
            windows: Vec::new(),
            next_id: 1,
            events: Vec::new(),
            copy_us_total: 0,
            copy_count: 0,
            dh,
        })
    }

    /// A janela com esse id, se ainda existir.
    pub fn window(&self, id: i64) -> Option<&Win> {
        self.windows.iter().find(|w| w.id == id)
    }

    /// Lê a imagem nova do app para a janela: só o recorte e só as linhas com dano.
    fn read_buffer(&mut self, index: usize, buffer: &wl_buffer::WlBuffer, damage: &[Damage]) {
        let surface = self.windows[index].toplevel.wl_surface().clone();
        let geometry = with_states(&surface, |states| {
            states.cached_state.get::<SurfaceCachedState>().current().geometry
        })
        .map(|g| Rect::new(g.loc.x, g.loc.y, g.size.w, g.size.h));
        // A escala é 1 e não há rotação: dano "da superfície" e "do buffer" usam os mesmos números.
        let damage: Vec<Rect> = damage
            .iter()
            .map(|d| match d {
                Damage::Surface(r) => Rect::new(r.loc.x, r.loc.y, r.size.w, r.size.h),
                Damage::Buffer(r) => Rect::new(r.loc.x, r.loc.y, r.size.w, r.size.h),
            })
            .collect();

        let start = Instant::now();
        let win = &mut self.windows[index];
        let copied = with_buffer_contents(buffer, |ptr, len, data| {
            // SEGURANÇA: o Smithay garante que `ptr` aponta para `len` bytes
            // mapeados enquanto esta função roda.
            let src = unsafe { std::slice::from_raw_parts(ptr, len) };
            let layout = ShmLayout {
                offset: data.offset,
                width: data.width,
                height: data.height,
                stride: data.stride,
                format: data.format,
            };
            let crop = crop_rect(data.width, data.height, geometry);
            // Recorte novo (tamanho ou sombra mudaram) ou primeira imagem: copia tudo.
            let rows = if crop != win.crop || win.pixels.is_empty() {
                win.pixels = vec![0u8; (crop.w * crop.h * 4) as usize];
                win.crop = crop;
                0..crop.h
            } else {
                damaged_rows(&crop, &damage)
            };
            if rows.is_empty() {
                return Some(false);
            }
            copy_rows(src, &layout, &crop, rows, &mut win.pixels).then_some(true)
        });
        match copied {
            Ok(Some(true)) => {
                win.dirty = true;
                self.copy_us_total += start.elapsed().as_micros();
                self.copy_count += 1;
            }
            Ok(Some(false)) => {} // nada mudou dentro do recorte
            _ => {
                // Formato que o hub não entende (ou memória com defeito): esquece a imagem.
                win.pixels.clear();
                win.crop = Rect::default();
            }
        }
    }
}

/// O compositor inteiro, sem a Godot: o display Wayland, o socket e o estado.
pub struct Core {
    pub display: Display<State>,
    listener: Option<ListeningSocket>,
    pub state: State,
    /// O relógio dos eventos (os apps só comparam um tempo com o outro).
    start: Instant,
}

impl Core {
    pub fn new(layout: &str, variant: &str) -> Result<Core, String> {
        let display: Display<State> =
            Display::new().map_err(|e| format!("não deu para criar o display Wayland: {e}"))?;
        let state = State::new(display.handle(), layout, variant)?;
        Ok(Core { display, listener: None, state, start: Instant::now() })
    }

    /// Abre o socket (ex.: "gamehub-0", dentro do XDG_RUNTIME_DIR).
    pub fn listen(&mut self, socket: &str) -> Result<(), String> {
        let listener =
            ListeningSocket::bind(socket).map_err(|e| format!("não deu para abrir o socket {socket}: {e}"))?;
        self.listener = Some(listener);
        Ok(())
    }

    /// Liga um app direto, sem socket (os testes usam um par de sockets).
    pub fn add_client(&mut self, stream: UnixStream) -> Result<(), String> {
        self.display
            .handle()
            .insert_client(stream, Arc::new(ClientState::default()))
            .map(|_| ())
            .map_err(|e| format!("app recusado: {e}"))
    }

    pub fn now_ms(&self) -> u32 {
        self.start.elapsed().as_millis() as u32
    }

    /// Sem esperar: aceita apps novos e processa as mensagens que chegaram.
    pub fn dispatch(&mut self) -> Result<(), String> {
        let mut streams = Vec::new();
        if let Some(listener) = self.listener.as_ref() {
            while let Ok(Some(stream)) = listener.accept() {
                streams.push(stream);
            }
        }
        for stream in streams {
            self.add_client(stream)?;
        }
        self.display.dispatch_clients(&mut self.state).map_err(|e| format!("erro ao ler as mensagens: {e}"))?;
        self.flush();
        Ok(())
    }

    /// Manda o que ficou na fila para os apps.
    pub fn flush(&mut self) {
        let _ = self.display.flush_clients();
    }

    /// "Quadro mostrado": responde os pedidos dos apps, que podem desenhar o
    /// próximo. Só responde quem pediu (um app parado não gasta nada).
    pub fn frame_done(&mut self) {
        let now = self.now_ms();
        for win in self.state.windows.iter_mut() {
            for callback in win.callbacks.drain(..) {
                callback.done(now);
            }
        }
        self.flush();
    }

    pub fn take_events(&mut self) -> Vec<Event> {
        self.state.events.drain(..).collect()
    }

    /// Pede ao app outro tamanho para a janela (o do telão). Devolve false se
    /// a janela não existe. O app responde com uma imagem nova desse tamanho.
    pub fn resize(&mut self, id: i64, width: i32, height: i32) -> bool {
        let Some(win) = self.state.windows.iter().find(|w| w.id == id) else { return false };
        let size = (width.clamp(1, MAX_SIZE), height.clamp(1, MAX_SIZE));
        win.toplevel.with_pending_state(|state| state.size = Some(size.into()));
        if win.toplevel.is_initial_configure_sent() {
            win.toplevel.send_pending_configure();
        }
        self.flush();
        true
    }

    /// Pede ao app para fechar a janela (como o X da barra de título).
    /// O app pode perguntar antes ("salvar?"); quando fechar, sai o `Closed`.
    pub fn close(&mut self, id: i64) -> bool {
        let Some(win) = self.state.windows.iter().find(|w| w.id == id) else { return false };
        win.toplevel.send_close();
        self.flush();
        true
    }
}

/// O que o hub guarda de cada app conectado (o Smithay pede).
#[derive(Default)]
pub struct ClientState {
    compositor_state: CompositorClientState,
}

impl ClientData for ClientState {
    fn initialized(&self, _client_id: ClientId) {}
    fn disconnected(&self, _client_id: ClientId, _reason: DisconnectReason) {}
}

/// O nome do app (`app_id`, ex.: "foot") e o título da janela.
pub fn toplevel_names(toplevel: &ToplevelSurface) -> (String, String) {
    with_states(toplevel.wl_surface(), |states| {
        let data = states.data_map.get::<XdgToplevelSurfaceData>().unwrap().lock().unwrap();
        (data.app_id.clone().unwrap_or_default(), data.title.clone().unwrap_or_default())
    })
}

impl CompositorHandler for State {
    fn compositor_state(&mut self) -> &mut CompositorState {
        &mut self.compositor_state
    }

    fn client_compositor_state<'a>(&self, client: &'a Client) -> &'a CompositorClientState {
        &client.get_data::<ClientState>().unwrap().compositor_state
    }

    /// O app terminou de mudar a janela ("commit"): pode ter imagem nova.
    fn commit(&mut self, surface: &WlSurface) {
        let Some(index) = self.windows.iter().position(|w| w.toplevel.wl_surface() == surface) else {
            return;
        };
        // O protocolo xdg pede: o app faz um commit vazio, e só então o
        // compositor manda o primeiro "configure" (o tamanho da janela).
        if !self.windows[index].toplevel.is_initial_configure_sent() {
            self.windows[index].toplevel.send_configure();
        }
        let (buffer, damage, callbacks) = with_states(surface, |states| {
            let mut guard = states.cached_state.get::<SurfaceAttributes>();
            let attrs = guard.current();
            (attrs.buffer.take(), std::mem::take(&mut attrs.damage), std::mem::take(&mut attrs.frame_callbacks))
        });
        self.windows[index].callbacks.extend(callbacks);
        match buffer {
            Some(BufferAssignment::NewBuffer(buffer)) => {
                self.read_buffer(index, &buffer, &damage);
                // Já copiamos: o app pode reaproveitar a memória.
                buffer.release();
            }
            Some(BufferAssignment::Removed) => {
                // O app escondeu a janela. Para a Godot, ela fechou; se voltar,
                // abre de novo (com o mesmo id), refazendo o primeiro "configure".
                let win = &mut self.windows[index];
                win.toplevel.reset_initial_configure_sent();
                win.pixels.clear();
                win.crop = Rect::default();
                win.dirty = false;
                if win.mapped {
                    win.mapped = false;
                    self.events.push(Event::Closed(win.id));
                }
                return;
            }
            None => {}
        }
        let win = &mut self.windows[index];
        if !win.mapped && !win.pixels.is_empty() {
            win.mapped = true;
            let (app_id, title) = toplevel_names(&win.toplevel);
            let pid = surface
                .client()
                .and_then(|c| c.get_credentials(&self.dh).ok())
                .map(|c| c.pid as i64)
                .unwrap_or(-1);
            self.events.push(Event::Opened(win.id, app_id, title, pid));
        }
    }
}

impl BufferHandler for State {
    fn buffer_destroyed(&mut self, _buffer: &wl_buffer::WlBuffer) {}
}

impl ShmHandler for State {
    fn shm_state(&self) -> &ShmState {
        &self.shm_state
    }
}

impl XdgShellHandler for State {
    fn xdg_shell_state(&mut self) -> &mut XdgShellState {
        &mut self.xdg_shell_state
    }

    /// Janela nova. Ela só aparece para a Godot quando mandar a primeira imagem.
    fn new_toplevel(&mut self, surface: ToplevelSurface) {
        surface.with_pending_state(|state| {
            // O telão decide o tamanho: a janela nasce com o tamanho dele.
            state.size = Some(WINDOW_SIZE.into());
            // "Ativa" (desenha como janela em foco) e "encostada nos quatro
            // lados": os apps deixam de desenhar sombra e cantos redondos.
            state.states.set(xdg_toplevel::State::Activated);
            state.states.set(xdg_toplevel::State::TiledLeft);
            state.states.set(xdg_toplevel::State::TiledRight);
            state.states.set(xdg_toplevel::State::TiledTop);
            state.states.set(xdg_toplevel::State::TiledBottom);
            // Sem barra de título do app: o hub mostra o nome no telão.
            state.decoration_mode = Some(DecorationMode::ServerSide);
        });
        self.output.enter(surface.wl_surface());
        let id = self.next_id;
        self.next_id += 1;
        self.windows.push(Win {
            id,
            toplevel: surface,
            pixels: Vec::new(),
            crop: Rect::default(),
            dirty: false,
            mapped: false,
            callbacks: Vec::new(),
        });
    }

    fn toplevel_destroyed(&mut self, surface: ToplevelSurface) {
        if let Some(i) = self.windows.iter().position(|w| w.toplevel == surface) {
            let win = self.windows.remove(i);
            if win.mapped {
                self.events.push(Event::Closed(win.id));
            }
        }
    }

    fn title_changed(&mut self, surface: ToplevelSurface) {
        let Some(win) = self.windows.iter().find(|w| w.toplevel == surface) else { return };
        if win.mapped {
            let (_, title) = toplevel_names(&win.toplevel);
            self.events.push(Event::TitleChanged(win.id, title));
        }
    }

    // O telão tem tamanho fixo: pedidos de maximizar ou tela cheia só
    // recebem o tamanho de sempre de volta.
    fn maximize_request(&mut self, surface: ToplevelSurface) {
        surface.send_configure();
    }

    fn fullscreen_request(
        &mut self,
        surface: ToplevelSurface,
        _output: Option<smithay::reexports::wayland_server::protocol::wl_output::WlOutput>,
    ) {
        surface.send_configure();
    }

    // Menus (popups) ficam para a 14.18.
    fn new_popup(&mut self, _surface: PopupSurface, _positioner: PositionerState) {}
    fn grab(&mut self, _surface: PopupSurface, _seat: wl_seat::WlSeat, _serial: Serial) {}
    fn reposition_request(&mut self, _surface: PopupSurface, _positioner: PositionerState, _token: u32) {}
}

/// Decoração "do lado do servidor": o app não desenha barra de título nem
/// botões. Quem pede outra coisa recebe a mesma resposta.
impl XdgDecorationHandler for State {
    fn new_decoration(&mut self, toplevel: ToplevelSurface) {
        toplevel.with_pending_state(|state| state.decoration_mode = Some(DecorationMode::ServerSide));
    }

    fn request_mode(&mut self, toplevel: ToplevelSurface, _mode: DecorationMode) {
        self.new_decoration(toplevel.clone());
        if toplevel.is_initial_configure_sent() {
            toplevel.send_pending_configure();
        }
    }

    fn unset_mode(&mut self, toplevel: ToplevelSurface) {
        self.request_mode(toplevel, DecorationMode::ServerSide);
    }
}

impl SeatHandler for State {
    type KeyboardFocus = WlSurface;
    type PointerFocus = WlSurface;
    type TouchFocus = WlSurface;

    fn seat_state(&mut self) -> &mut SeatState<Self> {
        &mut self.seat_state
    }

    fn focus_changed(&mut self, _seat: &Seat<Self>, _focused: Option<&WlSurface>) {}
    // O formato do cursor que o app pede é ignorado: o hub desenha o seu.
    fn cursor_image(&mut self, _seat: &Seat<Self>, _image: CursorImageStatus) {}
}

// Copiar e colar entre os apps do hub (o "data device"); a 14.18 completa.
impl SelectionHandler for State {
    type SelectionUserData = ();
}

impl DataDeviceHandler for State {
    fn data_device_state(&self) -> &DataDeviceState {
        &self.data_device_state
    }
}

impl ClientDndGrabHandler for State {}
impl ServerDndGrabHandler for State {}

impl OutputHandler for State {}

delegate_compositor!(State);
delegate_shm!(State);
delegate_xdg_shell!(State);
delegate_xdg_decoration!(State);
delegate_seat!(State);
delegate_data_device!(State);
delegate_output!(State);
