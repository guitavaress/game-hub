//! O lado Wayland do compositor: o que os apps enxergam.
//!
//! Um app aberto pelo hub conecta no socket do hub (ex.: `gamehub-0`) e acha
//! aqui um "monitor" (o output `HUB-1`), um teclado e um mouse (o seat), e
//! o xdg-shell, que é o jeito de criar janelas. Cada janela ("toplevel") vira
//! um `Win`, com a imagem já em RGBA, pronta para a Godot.
//!
//! Nada aqui conhece a Godot: o nó (`node.rs`) chama o `State` e lê os
//! `Event`s que ficaram na fila.

use smithay::input::keyboard::XkbConfig;
use smithay::input::pointer::CursorImageStatus;
use smithay::input::{Seat, SeatHandler, SeatState};
use smithay::output::{Mode, Output, PhysicalProperties, Scale, Subpixel};
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::reexports::wayland_server::backend::{ClientData, ClientId, DisconnectReason};
use smithay::reexports::wayland_server::protocol::wl_callback::WlCallback;
use smithay::reexports::wayland_server::protocol::{wl_buffer, wl_seat, wl_surface::WlSurface};
use smithay::reexports::wayland_server::{Client, DisplayHandle, Resource};
use smithay::utils::{Serial, Transform};
use smithay::wayland::buffer::BufferHandler;
use smithay::wayland::compositor::{
    with_states, BufferAssignment, CompositorClientState, CompositorHandler, CompositorState, SurfaceAttributes,
};
use smithay::wayland::output::{OutputHandler, OutputManagerState};
use smithay::wayland::selection::data_device::{
    ClientDndGrabHandler, DataDeviceHandler, DataDeviceState, ServerDndGrabHandler,
};
use smithay::wayland::selection::SelectionHandler;
use smithay::wayland::shell::xdg::{
    PopupSurface, PositionerState, ToplevelSurface, XdgShellHandler, XdgShellState, XdgToplevelSurfaceData,
};
use smithay::wayland::shm::{with_buffer_contents, ShmHandler, ShmState};
use smithay::{
    delegate_compositor, delegate_data_device, delegate_output, delegate_seat, delegate_shm, delegate_xdg_shell,
};

use crate::pixels::shm_to_rgba;

/// Tamanho com que toda janela nasce (o de um telão). A 14.16 deixa o telão
/// mudar isso com `resize`.
pub const WINDOW_SIZE: (i32, i32) = (1280, 720);

/// O que aconteceu e a Godot precisa saber (vira sinal no nó).
pub enum Event {
    /// Janela nova com a primeira imagem: id, app_id, título, pid do app.
    Opened(i64, String, String, i64),
    /// A janela fechou (o app fechou ou morreu).
    Closed(i64),
}

/// Uma janela de app.
pub struct Win {
    /// Número que a Godot usa para falar desta janela (1, 2, 3...).
    pub id: i64,
    pub toplevel: ToplevelSurface,
    /// A última imagem, em RGBA (4 bytes por pixel).
    pub pixels: Vec<u8>,
    pub width: i32,
    pub height: i32,
    /// Tem imagem nova que ainda não subiu para a textura.
    pub dirty: bool,
    /// Já mandou a primeira imagem (só então a Godot fica sabendo da janela).
    pub mapped: bool,
    /// Pedidos de "me avise quando mostrar": respondidos depois de subir a imagem.
    pub callbacks: Vec<WlCallback>,
}

pub struct State {
    pub dh: DisplayHandle,
    compositor_state: CompositorState,
    xdg_shell_state: XdgShellState,
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
        let Some(win) = self.windows.iter_mut().find(|w| w.toplevel.wl_surface() == surface) else {
            return;
        };
        // O protocolo xdg pede: o app faz um commit vazio, e só então o
        // compositor manda o primeiro "configure" (o tamanho da janela).
        if !win.toplevel.is_initial_configure_sent() {
            win.toplevel.send_configure();
        }
        let (buffer, callbacks) = with_states(surface, |states| {
            let mut guard = states.cached_state.get::<SurfaceAttributes>();
            let attrs = guard.current();
            (attrs.buffer.take(), std::mem::take(&mut attrs.frame_callbacks))
        });
        win.callbacks.extend(callbacks);
        let Some(BufferAssignment::NewBuffer(buffer)) = buffer else {
            return;
        };
        let start = std::time::Instant::now();
        let copied = with_buffer_contents(&buffer, |ptr, len, data| {
            // SEGURANÇA: o Smithay garante que `ptr` aponta para `len` bytes
            // mapeados enquanto esta função roda.
            let src = unsafe { std::slice::from_raw_parts(ptr, len) };
            shm_to_rgba(src, data.offset, data.width, data.height, data.stride, data.format)
                .map(|pixels| (pixels, data.width, data.height))
        });
        // Já copiamos: o app pode reaproveitar a memória.
        buffer.release();
        let Ok(Some((pixels, width, height))) = copied else {
            return;
        };
        self.copy_us_total += start.elapsed().as_micros();
        self.copy_count += 1;
        win.pixels = pixels;
        win.width = width;
        win.height = height;
        win.dirty = true;
        if !win.mapped {
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
        // O telão decide o tamanho: a janela nasce com o tamanho dele, já "ativa"
        // (o app desenha como janela em foco).
        surface.with_pending_state(|state| {
            state.size = Some(WINDOW_SIZE.into());
            state.states.set(xdg_toplevel::State::Activated);
        });
        self.output.enter(surface.wl_surface());
        let id = self.next_id;
        self.next_id += 1;
        self.windows.push(Win {
            id,
            toplevel: surface,
            pixels: Vec::new(),
            width: 0,
            height: 0,
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

    // Menus (popups) ficam para a 14.18.
    fn new_popup(&mut self, _surface: PopupSurface, _positioner: PositionerState) {}
    fn grab(&mut self, _surface: PopupSurface, _seat: wl_seat::WlSeat, _serial: Serial) {}
    fn reposition_request(&mut self, _surface: PopupSurface, _positioner: PositionerState, _token: u32) {}
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
delegate_seat!(State);
delegate_data_device!(State);
delegate_output!(State);
