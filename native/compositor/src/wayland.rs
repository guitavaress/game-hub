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

use smithay::backend::input::{Axis, AxisSource, ButtonState, KeyState};
use smithay::input::keyboard::{FilterResult, Keycode, XkbConfig};
use smithay::input::pointer::{AxisFrame, ButtonEvent, CursorImageStatus, MotionEvent};
use smithay::input::{Seat, SeatHandler, SeatState};
use smithay::output::{Mode, Output, PhysicalProperties, Scale, Subpixel};
use smithay::reexports::wayland_protocols::xdg::decoration::zv1::server::zxdg_toplevel_decoration_v1::Mode as DecorationMode;
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::reexports::wayland_server::backend::{ClientData, ClientId, DisconnectReason};
use smithay::reexports::wayland_server::protocol::wl_callback::WlCallback;
use smithay::reexports::wayland_server::protocol::{wl_buffer, wl_seat, wl_surface::WlSurface};
use smithay::reexports::wayland_server::{Client, Display, DisplayHandle, ListeningSocket, Resource};
use smithay::utils::{Serial, Transform, SERIAL_COUNTER};
use smithay::wayland::buffer::BufferHandler;
use smithay::wayland::compositor::{
    with_states, BufferAssignment, CompositorClientState, CompositorHandler, CompositorState, Damage,
    SurfaceAttributes,
};
use smithay::wayland::output::{OutputHandler, OutputManagerState};
use smithay::wayland::selection::data_device::{
    set_data_device_focus, ClientDndGrabHandler, DataDeviceHandler, DataDeviceState, ServerDndGrabHandler,
};
use smithay::wayland::selection::primary_selection::{
    set_primary_focus, PrimarySelectionHandler, PrimarySelectionState,
};
use smithay::wayland::selection::SelectionHandler;
use smithay::wayland::shell::xdg::decoration::{XdgDecorationHandler, XdgDecorationState};
use smithay::wayland::shell::xdg::{
    PopupSurface, PositionerState, SurfaceCachedState, ToplevelSurface, XdgShellHandler, XdgShellState,
    XdgToplevelSurfaceData,
};
use smithay::wayland::shell::wlr_layer::{
    Anchor, Layer, LayerSurface, LayerSurfaceCachedState, WlrLayerShellHandler, WlrLayerShellState,
};
use smithay::wayland::shm::{with_buffer_contents, ShmHandler, ShmState};
use smithay::utils::{Logical, Rectangle};
use smithay::{
    delegate_compositor, delegate_data_device, delegate_output, delegate_primary_selection, delegate_seat,
    delegate_layer_shell, delegate_shm, delegate_xdg_decoration, delegate_xdg_shell,
};

use crate::pixels::{blend_over, copy_rows, crop_rect, damaged_rows, Rect, ShmLayout};

/// Tamanho com que toda janela nasce (o de um telão), até o telão pedir outro
/// com `resize`.
pub const WINDOW_SIZE: (i32, i32) = (1280, 720);
/// O maior tamanho que o hub aceita pedir para uma janela.
pub const MAX_SIZE: i32 = 4096;
/// Quanto um "dente" da rodinha do mouse rola, em pixels (o mesmo número que
/// o Linux usa: os apps esperam 15).
pub const WHEEL_STEP: f64 = 15.0;

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

/// O que a superfície é: uma janela comum (xdg) ou uma camada (layer-shell:
/// barra, fundo, menu do Omarchy). SPIKE 14.24: a camada vira uma "janela" com
/// textura própria, para ver se o Quickshell desenha aqui dentro.
pub enum Role {
    Toplevel(ToplevelSurface),
    /// A camada, o nome dela (namespace) e o nível (fundo, baixo, topo, overlay).
    Layer(LayerSurface, String, Layer),
}

impl Role {
    pub fn wl_surface(&self) -> &WlSurface {
        match self {
            Role::Toplevel(t) => t.wl_surface(),
            Role::Layer(l, _, _) => l.wl_surface(),
        }
    }

    pub fn toplevel(&self) -> Option<&ToplevelSurface> {
        match self {
            Role::Toplevel(t) => Some(t),
            Role::Layer(..) => None,
        }
    }

    /// O nome do app e o título (para a camada: "layer:<nome>" e o nível).
    pub fn names(&self) -> (String, String) {
        match self {
            Role::Toplevel(t) => toplevel_names(t),
            Role::Layer(_, namespace, layer) => (format!("layer:{namespace}"), format!("{layer:?}")),
        }
    }
}

/// Uma janela de app.
pub struct Win {
    /// Número que a Godot usa para falar desta janela (1, 2, 3...).
    pub id: i64,
    pub role: Role,
    /// A última imagem (só o recorte da janela), em RGBA: 4 bytes por pixel.
    pub pixels: Vec<u8>,
    /// Onde o recorte está dentro da imagem do app (a sombra fica de fora).
    pub crop: Rect,
    /// Tem imagem nova que ainda não subiu para a textura.
    pub dirty: bool,
    /// Já mandou a primeira imagem (só então a Godot fica sabendo da janela).
    pub mapped: bool,
    /// Pedidos de "me avise quando mostrar" (da janela e dos menus):
    /// respondidos em `frame_done()`.
    pub callbacks: Vec<WlCallback>,
    /// Os menus abertos desta janela (e os submenus), do mais antigo para o
    /// mais novo: o último fica por cima.
    pub popups: Vec<Popup>,
    /// A imagem da janela com os menus por cima (só usada quando há menu).
    composed: Vec<u8>,
}

/// Um menu ("popup"): o do botão direito, o de uma lista, uma dica...
/// Ele é desenhado por cima da janela, dentro da mesma textura.
pub struct Popup {
    pub surface: PopupSurface,
    /// Quem abriu o menu: a janela ou outro menu (submenu).
    parent: WlSurface,
    /// Onde o menu fica, a partir do canto do recorte do pai.
    pub pos: (i32, i32),
    /// A imagem do menu (só o recorte, sem sombra), em RGBA.
    pub pixels: Vec<u8>,
    pub crop: Rect,
    pub mapped: bool,
    /// O menu pediu o "grab": um clique fora fecha os menus, e ele recebe o teclado.
    pub grab: bool,
}

impl Win {
    pub fn width(&self) -> i32 {
        self.crop.w
    }

    pub fn height(&self) -> i32 {
        self.crop.h
    }

    /// A imagem que vai para a textura: a janela, com os menus por cima.
    pub fn image(&mut self) -> &[u8] {
        if !self.popups.iter().any(|p| p.mapped) {
            return &self.pixels;
        }
        self.composed.clear();
        self.composed.extend_from_slice(&self.pixels);
        for i in 0..self.popups.len() {
            let (x, y) = self.popup_position(i);
            let p = &self.popups[i];
            if p.mapped {
                blend_over(&mut self.composed, self.crop.w, self.crop.h, &p.pixels, p.crop.w, p.crop.h, x, y);
            }
        }
        &self.composed
    }

    /// Onde o canto do menu `index` fica na imagem da janela (somando os pais).
    pub fn popup_position(&self, index: usize) -> (i32, i32) {
        let popup = &self.popups[index];
        let (px, py) = self.surface_position(&popup.parent);
        (px + popup.pos.0, py + popup.pos.1)
    }

    /// Onde o canto do recorte desta superfície (a janela ou um menu) fica na imagem.
    fn surface_position(&self, surface: &WlSurface) -> (i32, i32) {
        match self.popups.iter().position(|p| p.surface.wl_surface() == surface) {
            Some(i) => self.popup_position(i),
            None => (0, 0), // a própria janela
        }
    }

    /// O menu mais de cima que tem o ponto (x, y) da imagem, se houver.
    pub fn popup_at(&self, x: f64, y: f64) -> Option<usize> {
        (0..self.popups.len()).rev().find(|&i| {
            let p = &self.popups[i];
            let (px, py) = self.popup_position(i);
            p.mapped
                && x >= px as f64
                && y >= py as f64
                && x < (px + p.crop.w) as f64
                && y < (py + p.crop.h) as f64
        })
    }

    /// Quem recebe o teclado: o menu com "grab" mais de cima, ou a janela.
    pub fn keyboard_target(&self) -> WlSurface {
        match self.popups.iter().rev().find(|p| p.grab) {
            Some(p) => p.surface.wl_surface().clone(),
            None => self.role.wl_surface().clone(),
        }
    }

    /// A superfície (janela ou menu) e onde o canto dela (0, 0 do app, com a
    /// sombra) fica na imagem: é o que o mouse precisa para achar o ponto certo.
    fn pointer_target(&self, popup: Option<usize>) -> (WlSurface, (f64, f64)) {
        match popup {
            Some(i) => {
                let (x, y) = self.popup_position(i);
                let p = &self.popups[i];
                (p.surface.wl_surface().clone(), ((x - p.crop.x) as f64, (y - p.crop.y) as f64))
            }
            None => (self.role.wl_surface().clone(), (-self.crop.x as f64, -self.crop.y as f64)),
        }
    }

    /// A área onde os menus podem ficar (a imagem da janela), contada a partir
    /// do canto do recorte de `parent`: o menu é empurrado para caber no telão.
    fn popup_area(&self, parent: &WlSurface) -> Rectangle<i32, Logical> {
        let (w, h) = if self.crop.is_empty() { WINDOW_SIZE } else { (self.crop.w, self.crop.h) };
        let (px, py) = self.surface_position(parent);
        Rectangle::new((-px, -py).into(), (w, h).into())
    }
}

pub struct State {
    pub dh: DisplayHandle,
    compositor_state: CompositorState,
    xdg_shell_state: XdgShellState,
    layer_shell_state: WlrLayerShellState,
    _decoration_state: XdgDecorationState,
    shm_state: ShmState,
    seat_state: SeatState<State>,
    data_device_state: DataDeviceState,
    primary_selection_state: PrimarySelectionState,
    _output_manager: OutputManagerState,
    pub seat: Seat<State>,
    /// A janela que o hub escolheu para o teclado (o telão em uso).
    pub focused_window: Option<i64>,
    /// Onde o mouse está: a janela e, se for o caso, o menu.
    pointer_over: Option<(i64, Option<usize>)>,
    /// O clique que fechou os menus não vai para o app, nem o "soltou" dele.
    swallow_release: Option<u32>,
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
            layer_shell_state: WlrLayerShellState::new::<State>(&dh),
            _decoration_state: XdgDecorationState::new::<State>(&dh),
            shm_state: ShmState::new::<State>(&dh, vec![]),
            data_device_state: DataDeviceState::new::<State>(&dh),
            primary_selection_state: PrimarySelectionState::new::<State>(&dh),
            focused_window: None,
            pointer_over: None,
            swallow_release: None,
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

    /// Em qual janela (índice) está esta superfície, e se é um menu (índice do menu).
    fn find(&self, surface: &WlSurface) -> Option<(usize, Option<usize>)> {
        self.windows.iter().enumerate().find_map(|(wi, w)| {
            if w.role.wl_surface() == surface {
                Some((wi, None))
            } else {
                w.popups.iter().position(|p| p.surface.wl_surface() == surface).map(|pi| (wi, Some(pi)))
            }
        })
    }

    /// Põe o teclado em quem deve recebê-lo na janela com o foco (a janela
    /// ou o menu com "grab").
    fn refresh_keyboard_focus(&mut self) {
        let target = self.focused_window.and_then(|id| self.window(id)).map(|w| w.keyboard_target());
        let keyboard = self.seat.get_keyboard().unwrap();
        if keyboard.current_focus() != target {
            keyboard.set_focus(self, target, SERIAL_COUNTER.next_serial());
        }
    }

    /// Tira a janela (ou camada) da lista e avisa a Godot, se ela já aparecia.
    fn remove_window(&mut self, surface: &WlSurface) {
        if let Some(i) = self.windows.iter().position(|w| w.role.wl_surface() == surface) {
            let win = self.windows.remove(i);
            if win.mapped {
                self.events.push(Event::Closed(win.id));
            }
            if self.focused_window == Some(win.id) {
                self.focused_window = None;
            }
        }
    }

    /// Guarda um menu novo da janela `index` (aberto pela janela, por outro
    /// menu ou por uma camada) e calcula o lugar dele.
    fn track_popup(&mut self, index: usize, parent: WlSurface, surface: PopupSurface, positioner: PositionerState) {
        let win = &mut self.windows[index];
        let geometry = positioner.get_unconstrained_geometry(win.popup_area(&parent));
        surface.with_pending_state(|state| {
            state.geometry = geometry;
            state.positioner = positioner;
        });
        win.popups.push(Popup {
            surface,
            parent,
            pos: (geometry.loc.x, geometry.loc.y),
            pixels: Vec::new(),
            crop: Rect::default(),
            mapped: false,
            grab: false,
        });
    }

    /// Fecha todos os menus da janela (o app recebe "popup_done" e os destrói).
    fn dismiss_popups(&mut self, window_index: usize) {
        for popup in self.windows[window_index].popups.iter().rev() {
            popup.surface.send_popup_done();
        }
    }
}

/// Lê a imagem nova do app (de uma janela ou de um menu) para `pixels`: só o
/// recorte e só as linhas com dano. Devolve Some(true) se copiou, Some(false)
/// se nada mudou e None se a imagem não serve (formato que o hub não entende).
fn read_picture(
    surface: &WlSurface,
    buffer: &wl_buffer::WlBuffer,
    damage: &[Damage],
    pixels: &mut Vec<u8>,
    crop_now: &mut Rect,
) -> Option<bool> {
    let geometry = with_states(surface, |states| states.cached_state.get::<SurfaceCachedState>().current().geometry)
        .map(|g| Rect::new(g.loc.x, g.loc.y, g.size.w, g.size.h));
    // A escala é 1 e não há rotação: dano "da superfície" e "do buffer" usam os mesmos números.
    let damage: Vec<Rect> = damage
        .iter()
        .map(|d| match d {
            Damage::Surface(r) => Rect::new(r.loc.x, r.loc.y, r.size.w, r.size.h),
            Damage::Buffer(r) => Rect::new(r.loc.x, r.loc.y, r.size.w, r.size.h),
        })
        .collect();
    let copied = with_buffer_contents(buffer, |ptr, len, data| {
        // SEGURANÇA: o Smithay garante que `ptr` aponta para `len` bytes
        // mapeados enquanto esta função roda.
        let src = unsafe { std::slice::from_raw_parts(ptr, len) };
        let layout =
            ShmLayout { offset: data.offset, width: data.width, height: data.height, stride: data.stride, format: data.format };
        let crop = crop_rect(data.width, data.height, geometry);
        // Recorte novo (tamanho ou sombra mudaram) ou primeira imagem: copia tudo.
        let rows = if crop != *crop_now || pixels.is_empty() {
            *pixels = vec![0u8; (crop.w * crop.h * 4) as usize];
            *crop_now = crop;
            0..crop.h
        } else {
            damaged_rows(&crop, &damage)
        };
        if rows.is_empty() {
            return Some(false);
        }
        copy_rows(src, &layout, &crop, rows, pixels).then_some(true)
    });
    match copied {
        Ok(Some(changed)) => Some(changed),
        _ => {
            // Formato que o hub não entende (ou memória com defeito): esquece a imagem.
            pixels.clear();
            *crop_now = Rect::default();
            None
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
        // (os pedidos dos menus também ficam na lista da janela)
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
        // SPIKE 14.24: a camada decide o tamanho dela (pela saída).
        let Some(toplevel) = win.role.toplevel() else { return true };
        let size = (width.clamp(1, MAX_SIZE), height.clamp(1, MAX_SIZE));
        toplevel.with_pending_state(|state| state.size = Some(size.into()));
        if toplevel.is_initial_configure_sent() {
            toplevel.send_pending_configure();
        }
        self.flush();
        true
    }

    /// Dá o foco do teclado para a janela (None: nenhuma). A janela com foco
    /// fica "ativa" (o app desenha como janela em foco, ex.: o cursor cheio do
    /// terminal); as outras, não. Tirar o foco solta as teclas que estavam
    /// apertadas, do ponto de vista do app.
    pub fn focus(&mut self, id: Option<i64>) {
        let id = id.filter(|&id| self.state.window(id).is_some());
        self.state.focused_window = id;
        // O teclado vai para a janela (ou para o menu com "grab" dela).
        self.state.refresh_keyboard_focus();
        let target = id.and_then(|id| self.state.window(id)).map(|w| w.role.wl_surface().clone());
        for win in &self.state.windows {
            let Some(toplevel) = win.role.toplevel() else { continue };
            let active = target.as_ref() == Some(toplevel.wl_surface());
            toplevel.with_pending_state(|state| {
                if active {
                    state.states.set(xdg_toplevel::State::Activated);
                } else {
                    state.states.unset(xdg_toplevel::State::Activated);
                }
            });
            // Só manda se mudou alguma coisa.
            if toplevel.is_initial_configure_sent() {
                toplevel.send_pending_configure();
            }
        }
        self.flush();
    }

    /// A janela com o foco do teclado, se houver.
    pub fn focused(&self) -> Option<i64> {
        self.state.focused_window
    }

    /// Uma tecla para a janela, com o código evdev do Linux. Se a janela não
    /// tinha o foco, ganha. Quem repete a tecla segurada é o app (o compositor
    /// manda só o "apertou" e o "soltou").
    pub fn key(&mut self, id: i64, evdev: u32, pressed: bool) {
        if self.state.window(id).is_none() {
            return;
        }
        if self.focused() != Some(id) {
            self.focus(Some(id));
        }
        let keyboard = self.state.seat.get_keyboard().unwrap();
        let state = if pressed { KeyState::Pressed } else { KeyState::Released };
        let time = self.now_ms();
        // O xkb numera as teclas 8 acima do evdev (uma herança do X11).
        keyboard.input::<(), _>(
            &mut self.state,
            Keycode::new(evdev + 8),
            state,
            SERIAL_COUNTER.next_serial(),
            time,
            |_, _, _| FilterResult::Forward,
        );
        self.flush();
    }

    /// O ponteiro em (x, y), em pixels da imagem da janela (a da textura, sem
    /// a sombra; 0, 0 é o canto de cima à esquerda).
    pub fn pointer_motion(&mut self, id: i64, x: f64, y: f64) {
        let Some(win) = self.state.window(id) else { return };
        // Em cima de um menu, o mouse é do menu; senão, da janela. A imagem é
        // só o recorte: para o app, o ponto fica deslocado pela sombra.
        let popup = win.popup_at(x, y);
        let (surface, origin) = win.pointer_target(popup);
        self.state.pointer_over = Some((id, popup));
        let pointer = self.state.seat.get_pointer().unwrap();
        let event = MotionEvent { location: (x, y).into(), serial: SERIAL_COUNTER.next_serial(), time: self.now_ms() };
        pointer.motion(&mut self.state, Some((surface, origin.into())), &event);
        pointer.frame(&mut self.state);
        self.flush();
    }

    /// O ponteiro saiu de cima da janela (a mira saiu do telão).
    pub fn pointer_leave(&mut self) {
        self.state.pointer_over = None;
        let pointer = self.state.seat.get_pointer().unwrap();
        let event = MotionEvent { location: (0.0, 0.0).into(), serial: SERIAL_COUNTER.next_serial(), time: self.now_ms() };
        pointer.motion(&mut self.state, None, &event);
        pointer.frame(&mut self.state);
        self.flush();
    }

    /// Botão do mouse, com o código do Linux (0x110 esquerdo, 0x111 direito,
    /// 0x112 do meio). Vai para a janela onde o ponteiro está.
    pub fn pointer_button(&mut self, button: u32, pressed: bool) {
        if !pressed && self.state.swallow_release == Some(button) {
            self.state.swallow_release = None;
            return;
        }
        // Um clique fora dos menus com "grab" fecha os menus (e não vai para o app).
        if pressed {
            let over_popup = matches!(self.state.pointer_over, Some((_, Some(_))));
            let grabbing = self.state.windows.iter().position(|w| w.popups.iter().any(|p| p.grab));
            if let (Some(index), false) = (grabbing, over_popup) {
                self.state.dismiss_popups(index);
                self.state.swallow_release = Some(button);
                self.flush();
                return;
            }
        }
        let pointer = self.state.seat.get_pointer().unwrap();
        let state = if pressed { ButtonState::Pressed } else { ButtonState::Released };
        let event = ButtonEvent { serial: SERIAL_COUNTER.next_serial(), time: self.now_ms(), button, state };
        pointer.button(&mut self.state, &event);
        pointer.frame(&mut self.state);
        self.flush();
    }

    /// Rolar na janela onde o ponteiro está. Positivo = para baixo / para a direita.
    /// `wheel`: true para a rodinha (os números são "dentes", ex.: 1 ou -1);
    /// false para o touchpad (os números já são pixels).
    pub fn pointer_axis(&mut self, dx: f64, dy: f64, wheel: bool) {
        let mut frame = AxisFrame::new(self.now_ms()).source(if wheel { AxisSource::Wheel } else { AxisSource::Finger });
        for (axis, amount) in [(Axis::Horizontal, dx), (Axis::Vertical, dy)] {
            if amount == 0.0 {
                continue;
            }
            if wheel {
                // Apps novos leem os "dentes" (120 = um dente); os antigos, os pixels.
                frame = frame.value(axis, amount * WHEEL_STEP).v120(axis, (amount * 120.0).round() as i32);
            } else {
                frame = frame.value(axis, amount);
            }
        }
        let pointer = self.state.seat.get_pointer().unwrap();
        pointer.axis(&mut self.state, frame);
        pointer.frame(&mut self.state);
        self.flush();
    }

    /// Pede ao app para fechar a janela (como o X da barra de título).
    /// O app pode perguntar antes ("salvar?"); quando fechar, sai o `Closed`.
    pub fn close(&mut self, id: i64) -> bool {
        let Some(win) = self.state.windows.iter().find(|w| w.id == id) else { return false };
        match &win.role {
            Role::Toplevel(t) => t.send_close(),
            Role::Layer(l, _, _) => l.send_close(),
        }
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

    /// O app terminou de mudar a janela ou um menu ("commit"): pode ter imagem nova.
    fn commit(&mut self, surface: &WlSurface) {
        let Some((index, popup)) = self.find(surface) else {
            return;
        };
        // O protocolo xdg pede: o app faz um commit vazio, e só então o
        // compositor manda o primeiro "configure" (o tamanho e o lugar).
        match popup {
            None => match &self.windows[index].role {
                Role::Toplevel(t) if !t.is_initial_configure_sent() => {
                    t.send_configure();
                }
                Role::Layer(l, _, _) => configure_layer(l),
                _ => {}
            },
            Some(pi) if !self.windows[index].popups[pi].surface.is_initial_configure_sent() => {
                let _ = self.windows[index].popups[pi].surface.send_configure();
            }
            _ => {}
        }
        let (buffer, damage, callbacks) = with_states(surface, |states| {
            let mut guard = states.cached_state.get::<SurfaceAttributes>();
            let attrs = guard.current();
            (attrs.buffer.take(), std::mem::take(&mut attrs.damage), std::mem::take(&mut attrs.frame_callbacks))
        });
        let win = &mut self.windows[index];
        win.callbacks.extend(callbacks);

        if let Some(pi) = popup {
            // Um menu: a imagem dele entra na textura da janela.
            let p = &mut win.popups[pi];
            match buffer {
                Some(BufferAssignment::NewBuffer(buffer)) => {
                    let start = Instant::now();
                    if read_picture(surface, &buffer, &damage, &mut p.pixels, &mut p.crop) == Some(true) {
                        self.copy_us_total += start.elapsed().as_micros();
                        self.copy_count += 1;
                    }
                    buffer.release();
                    p.mapped = !p.pixels.is_empty();
                }
                Some(BufferAssignment::Removed) => {
                    p.pixels.clear();
                    p.mapped = false;
                }
                None => return,
            }
            win.dirty = win.mapped;
            return;
        }

        match buffer {
            Some(BufferAssignment::NewBuffer(buffer)) => {
                let start = Instant::now();
                if read_picture(surface, &buffer, &damage, &mut win.pixels, &mut win.crop) == Some(true) {
                    win.dirty = true;
                    self.copy_us_total += start.elapsed().as_micros();
                    self.copy_count += 1;
                }
                // Já copiamos: o app pode reaproveitar a memória.
                buffer.release();
            }
            Some(BufferAssignment::Removed) => {
                // O app escondeu a janela. Para a Godot, ela fechou; se voltar,
                // abre de novo (com o mesmo id), refazendo o primeiro "configure".
                if let Some(t) = win.role.toplevel() {
                    t.reset_initial_configure_sent();
                }
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
        if !win.mapped && !win.pixels.is_empty() {
            win.mapped = true;
            let (app_id, title) = win.role.names();
            let pid = surface
                .client()
                .and_then(|c| c.get_credentials(&self.dh).ok())
                .map(|c| c.pid as i64)
                .unwrap_or(-1);
            self.events.push(Event::Opened(win.id, app_id, title, pid));
        }
    }
}

/// SPIKE 14.24: o tamanho que a camada recebe. Encostada nos dois lados (ex.:
/// a barra, de ponta a ponta), ela ganha a largura (ou altura) toda da saída;
/// senão, o que pediu. As margens ainda não contam.
fn configure_layer(layer: &LayerSurface) {
    let (output_w, output_h) = WINDOW_SIZE;
    let (size, anchor) = with_states(layer.wl_surface(), |states| {
        let mut guard = states.cached_state.get::<LayerSurfaceCachedState>();
        let current = guard.current();
        (current.size, current.anchor)
    });
    let w = if size.w == 0 || anchor.contains(Anchor::LEFT | Anchor::RIGHT) { output_w } else { size.w };
    let h = if size.h == 0 || anchor.contains(Anchor::TOP | Anchor::BOTTOM) { output_h } else { size.h };
    layer.with_pending_state(|state| state.size = Some((w, h).into()));
    layer.send_pending_configure();
}

impl WlrLayerShellHandler for State {
    fn shell_state(&mut self) -> &mut WlrLayerShellState {
        &mut self.layer_shell_state
    }

    /// Camada nova (barra, fundo, menu). Ela recebe o tamanho no primeiro
    /// commit (em `commit`), como as janelas.
    fn new_layer_surface(
        &mut self,
        surface: LayerSurface,
        _output: Option<smithay::reexports::wayland_server::protocol::wl_output::WlOutput>,
        layer: Layer,
        namespace: String,
    ) {
        self.output.enter(surface.wl_surface());
        let id = self.next_id;
        self.next_id += 1;
        self.windows.push(Win {
            id,
            role: Role::Layer(surface, namespace, layer),
            pixels: Vec::new(),
            crop: Rect::default(),
            dirty: false,
            mapped: false,
            callbacks: Vec::new(),
            popups: Vec::new(),
            composed: Vec::new(),
        });
    }

    fn new_popup(&mut self, parent: LayerSurface, popup: PopupSurface) {
        let Some((index, _)) = self.find(parent.wl_surface()) else {
            popup.send_popup_done();
            return;
        };
        let positioner = popup.with_pending_state(|state| state.positioner);
        self.track_popup(index, parent.wl_surface().clone(), popup, positioner);
    }

    fn layer_destroyed(&mut self, surface: LayerSurface) {
        self.remove_window(surface.wl_surface());
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
            // "Encostada nos quatro lados": os apps deixam de desenhar sombra e
            // cantos redondos. ("Ativa" só com o foco do teclado: veja Core::focus.)
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
            role: Role::Toplevel(surface),
            pixels: Vec::new(),
            crop: Rect::default(),
            dirty: false,
            mapped: false,
            callbacks: Vec::new(),
            popups: Vec::new(),
            composed: Vec::new(),
        });
    }

    fn toplevel_destroyed(&mut self, surface: ToplevelSurface) {
        self.remove_window(surface.wl_surface());
    }

    fn title_changed(&mut self, surface: ToplevelSurface) {
        let Some(win) = self.windows.iter().find(|w| w.role.wl_surface() == surface.wl_surface()) else { return };
        if win.mapped {
            let (_, title) = win.role.names();
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

    /// Menu novo: calcula o lugar dele (empurrado para caber na janela). O
    /// "configure" com esse lugar sai no primeiro commit do menu.
    fn new_popup(&mut self, surface: PopupSurface, positioner: PositionerState) {
        // Sem pai: é menu de uma camada, que chega depois em WlrLayerShellHandler::new_popup.
        let Some(parent) = surface.get_parent_surface() else { return };
        let Some((index, _)) = self.find(&parent) else {
            // Menu de uma janela que o hub não conhece: fecha na hora.
            surface.send_popup_done();
            return;
        };
        self.track_popup(index, parent, surface, positioner);
    }

    /// O menu quer o "grab" (menus de verdade pedem): ele recebe o teclado
    /// (setas, Enter, Esc) e um clique fora fecha os menus.
    fn grab(&mut self, surface: PopupSurface, _seat: wl_seat::WlSeat, _serial: Serial) {
        let Some((index, Some(pi))) = self.find(surface.wl_surface()) else { return };
        self.windows[index].popups[pi].grab = true;
        self.refresh_keyboard_focus();
    }

    /// O app pediu para mudar o lugar do menu (ex.: a lista cresceu).
    fn reposition_request(&mut self, surface: PopupSurface, positioner: PositionerState, token: u32) {
        let Some((index, Some(pi))) = self.find(surface.wl_surface()) else { return };
        let win = &mut self.windows[index];
        let parent = win.popups[pi].parent.clone();
        let geometry = positioner.get_unconstrained_geometry(win.popup_area(&parent));
        surface.with_pending_state(|state| {
            state.geometry = geometry;
            state.positioner = positioner;
        });
        win.popups[pi].pos = (geometry.loc.x, geometry.loc.y);
        win.dirty = win.mapped;
        surface.send_repositioned(token);
        let _ = surface.send_configure();
    }

    /// O menu fechou: sai da imagem, e o teclado volta para quem tinha antes.
    fn popup_destroyed(&mut self, surface: PopupSurface) {
        let Some((index, Some(pi))) = self.find(surface.wl_surface()) else { return };
        let win = &mut self.windows[index];
        win.popups.remove(pi);
        win.dirty = win.mapped;
        if matches!(self.pointer_over, Some((id, Some(_))) if id == win.id) {
            self.pointer_over = Some((win.id, None));
        }
        self.refresh_keyboard_focus();
    }
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

    /// O copiar e colar segue o teclado: o app com o foco é quem pode ler e
    /// trocar o que está copiado (e o "colar com o botão do meio").
    fn focus_changed(&mut self, seat: &Seat<Self>, focused: Option<&WlSurface>) {
        let client = focused.and_then(|s| self.dh.get_client(s.id()).ok());
        set_data_device_focus(&self.dh, seat, client.clone());
        set_primary_focus(&self.dh, seat, client);
    }
    // O formato do cursor que o app pede é ignorado: o hub desenha o seu.
    fn cursor_image(&mut self, _seat: &Seat<Self>, _image: CursorImageStatus) {}
}

// Copiar e colar entre os apps do hub (o "data device" e a "seleção primária",
// a do botão do meio). Ainda não conversa com a área de transferência do Omarchy.
impl SelectionHandler for State {
    type SelectionUserData = ();
}

impl DataDeviceHandler for State {
    fn data_device_state(&self) -> &DataDeviceState {
        &self.data_device_state
    }
}

impl PrimarySelectionHandler for State {
    fn primary_selection_state(&self) -> &PrimarySelectionState {
        &self.primary_selection_state
    }
}

impl ClientDndGrabHandler for State {}
impl ServerDndGrabHandler for State {}

impl OutputHandler for State {}

delegate_compositor!(State);
delegate_shm!(State);
delegate_xdg_shell!(State);
delegate_layer_shell!(State);
delegate_xdg_decoration!(State);
delegate_seat!(State);
delegate_data_device!(State);
delegate_primary_selection!(State);
delegate_output!(State);
