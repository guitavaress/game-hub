// SPIKE da Fase 14.14: um compositor Wayland mínimo dentro da Godot.
// Código descartável: serve para responder às perguntas do spike
// (o godot-rust carrega? o foot aparece? a tecla chega? quanto custa a cópia?).

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;

use godot::classes::image::Format;
use godot::classes::{Image, ImageTexture, INode, Node};
use godot::prelude::*;

use smithay::backend::input::{ButtonState, KeyState};
use smithay::input::keyboard::{FilterResult, Keycode, XkbConfig};
use smithay::input::pointer::{ButtonEvent, CursorImageStatus, MotionEvent};
use smithay::input::{Seat, SeatHandler, SeatState};
use smithay::output::{Mode, Output, PhysicalProperties, Scale, Subpixel};
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::reexports::wayland_server::backend::{ClientData, ClientId, DisconnectReason};
use smithay::reexports::wayland_server::protocol::wl_shm;
use smithay::reexports::wayland_server::protocol::{wl_buffer, wl_seat, wl_surface::WlSurface};
use smithay::reexports::wayland_server::{Client, Display, DisplayHandle, ListeningSocket, Resource};
use smithay::utils::{Serial, Transform, SERIAL_COUNTER};
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

// ---------------------------------------------------------------------------
// Entrada da GDExtension
// ---------------------------------------------------------------------------

struct HubExtension;

#[gdextension]
unsafe impl ExtensionLibrary for HubExtension {}

// ---------------------------------------------------------------------------
// O estado do compositor (lado Wayland)
// ---------------------------------------------------------------------------

enum Event {
    Opened(i64, String, String, i64),
    Closed(i64),
}

struct Win {
    id: i64,
    toplevel: ToplevelSurface,
    pixels: Vec<u8>, // RGBA8
    width: i32,
    height: i32,
    dirty: bool,
    mapped: bool,
    callbacks: Vec<smithay::reexports::wayland_server::protocol::wl_callback::WlCallback>,
}

struct State {
    dh: DisplayHandle,
    compositor_state: CompositorState,
    xdg_shell_state: XdgShellState,
    shm_state: ShmState,
    seat_state: SeatState<State>,
    data_device_state: DataDeviceState,
    _output_manager: OutputManagerState,
    seat: Seat<State>,
    output: Output,
    windows: Vec<Win>,
    next_id: i64,
    events: Vec<Event>,
    size: (i32, i32),
    copy_us_total: u128,
    copy_count: u64,
}

#[derive(Default)]
struct ClientState {
    compositor_state: CompositorClientState,
}

impl ClientData for ClientState {
    fn initialized(&self, _client_id: ClientId) {}
    fn disconnected(&self, _client_id: ClientId, _reason: DisconnectReason) {}
}

impl CompositorHandler for State {
    fn compositor_state(&mut self) -> &mut CompositorState {
        &mut self.compositor_state
    }

    fn client_compositor_state<'a>(&self, client: &'a Client) -> &'a CompositorClientState {
        &client.get_data::<ClientState>().unwrap().compositor_state
    }

    fn commit(&mut self, surface: &WlSurface) {
        let Some(win) = self.windows.iter_mut().find(|w| w.toplevel.wl_surface() == surface) else {
            return;
        };
        // O protocolo xdg pede: o cliente faz um commit vazio, e só então o
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
        if let Some(BufferAssignment::NewBuffer(buffer)) = buffer {
            let start = Instant::now();
            let copied = with_buffer_contents(&buffer, |ptr, len, data| {
                copy_shm(ptr, len, data.offset, data.width, data.height, data.stride, data.format)
            });
            buffer.release();
            if let Ok(Some((pixels, w, h))) = copied {
                self.copy_us_total += start.elapsed().as_micros();
                self.copy_count += 1;
                win.pixels = pixels;
                win.width = w;
                win.height = h;
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
    }
}

/// Copia a imagem shm (BGRA na memória) para RGBA, linha a linha.
fn copy_shm(
    ptr: *const u8,
    len: usize,
    offset: i32,
    width: i32,
    height: i32,
    stride: i32,
    format: wl_shm::Format,
) -> Option<(Vec<u8>, i32, i32)> {
    let opaque = match format {
        wl_shm::Format::Argb8888 => false,
        wl_shm::Format::Xrgb8888 => true,
        _ => return None,
    };
    let (w, h, s, o) = (width as usize, height as usize, stride as usize, offset as usize);
    if o + s * h > len || w * 4 > s {
        return None;
    }
    let src = unsafe { std::slice::from_raw_parts(ptr, len) };
    let mut out = vec![0u8; w * h * 4];
    for y in 0..h {
        let row = &src[o + y * s..o + y * s + w * 4];
        let dst = &mut out[y * w * 4..(y + 1) * w * 4];
        for (d, p) in dst.chunks_exact_mut(4).zip(row.chunks_exact(4)) {
            d[0] = p[2];
            d[1] = p[1];
            d[2] = p[0];
            d[3] = if opaque { 255 } else { p[3] };
        }
    }
    Some((out, width, height))
}

fn toplevel_names(toplevel: &ToplevelSurface) -> (String, String) {
    with_states(toplevel.wl_surface(), |states| {
        let data = states.data_map.get::<XdgToplevelSurfaceData>().unwrap().lock().unwrap();
        (data.app_id.clone().unwrap_or_default(), data.title.clone().unwrap_or_default())
    })
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

    fn new_toplevel(&mut self, surface: ToplevelSurface) {
        // O telão decide o tamanho: a janela nasce com o tamanho dele.
        let size = self.size;
        surface.with_pending_state(|state| {
            state.size = Some(size.into());
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
    fn cursor_image(&mut self, _seat: &Seat<Self>, _image: CursorImageStatus) {}
}

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

// ---------------------------------------------------------------------------
// O nó da Godot
// ---------------------------------------------------------------------------

struct Inner {
    display: Display<State>,
    listener: ListeningSocket,
    state: State,
    start: Instant,
}

#[derive(GodotClass)]
#[class(base = Node, init)]
pub struct HubCompositor {
    base: Base<Node>,
    inner: Option<Inner>,
    textures: HashMap<i64, Gd<ImageTexture>>,
    upload_us_total: u128,
    upload_count: u64,
}

#[godot_api]
impl INode for HubCompositor {
    fn exit_tree(&mut self) {
        self.inner = None;
    }
}

#[godot_api]
impl HubCompositor {
    #[signal]
    fn window_opened(id: i64, app_id: GString, title: GString, pid: i64);

    #[signal]
    fn window_closed(id: i64);

    /// Abre o socket (ex.: "gamehub-0") com o layout do teclado (ex.: "br").
    #[func]
    fn start(&mut self, socket: GString, layout: GString, width: i32, height: i32) -> bool {
        let display: Display<State> = match Display::new() {
            Ok(d) => d,
            Err(e) => {
                godot_error!("Display::new falhou: {e}");
                return false;
            }
        };
        let listener = match ListeningSocket::bind(socket.to_string()) {
            Ok(l) => l,
            Err(e) => {
                godot_error!("não abri o socket {socket}: {e}");
                return false;
            }
        };
        let dh = display.handle();
        let mut seat_state = SeatState::new();
        let mut seat = seat_state.new_wl_seat(&dh, "hub");
        let layout = layout.to_string();
        let xkb = XkbConfig { layout: &layout, ..Default::default() };
        if seat.add_keyboard(xkb, 400, 30).is_err() {
            godot_error!("keymap do layout {layout} falhou");
            return false;
        }
        seat.add_pointer();

        let output = Output::new(
            "HUB-1".into(),
            PhysicalProperties {
                size: (0, 0).into(),
                subpixel: Subpixel::Unknown,
                make: "Game Hub".into(),
                model: "Telao".into(),
            },
        );
        let mode = Mode { size: (width, height).into(), refresh: 60_000 };
        output.change_current_state(Some(mode), Some(Transform::Normal), Some(Scale::Integer(1)), Some((0, 0).into()));
        output.set_preferred(mode);
        output.create_global::<State>(&dh);

        let state = State {
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
            size: (width, height),
            copy_us_total: 0,
            copy_count: 0,
            dh,
        };
        self.inner = Some(Inner { display, listener, state, start: Instant::now() });
        true
    }

    #[func]
    fn stop(&mut self) {
        self.inner = None;
        self.textures.clear();
    }

    /// Chamado a cada quadro: aceita clientes, processa as mensagens, sobe as
    /// imagens novas e avisa os apps que o quadro foi mostrado.
    #[func]
    fn poll(&mut self) {
        let Some(inner) = self.inner.as_mut() else { return };
        while let Ok(Some(stream)) = inner.listener.accept() {
            if let Err(e) = inner.display.handle().insert_client(stream, Arc::new(ClientState::default())) {
                godot_error!("cliente recusado: {e}");
            }
        }
        if let Err(e) = inner.display.dispatch_clients(&mut inner.state) {
            godot_error!("dispatch: {e}");
        }

        // Sobe as imagens que mudaram.
        let mut uploads: Vec<(i64, Gd<Image>)> = Vec::new();
        let now_ms = inner.start.elapsed().as_millis() as u32;
        for win in inner.state.windows.iter_mut() {
            if win.dirty && win.width > 0 {
                win.dirty = false;
                let bytes = PackedByteArray::from(win.pixels.as_slice());
                if let Some(image) = Image::create_from_data(win.width, win.height, false, Format::RGBA8, &bytes) {
                    uploads.push((win.id, image));
                }
            }
            for cb in win.callbacks.drain(..) {
                cb.done(now_ms);
            }
        }
        let events: Vec<Event> = inner.state.events.drain(..).collect();
        let _ = inner.display.flush_clients();

        for (id, image) in uploads {
            let start = Instant::now();
            let reuse = self
                .textures
                .get(&id)
                .map(|t| t.get_width() == image.get_width() && t.get_height() == image.get_height())
                .unwrap_or(false);
            if reuse {
                self.textures.get_mut(&id).unwrap().update(&image);
            } else if let Some(tex) = ImageTexture::create_from_image(&image) {
                self.textures.insert(id, tex);
            }
            self.upload_us_total += start.elapsed().as_micros();
            self.upload_count += 1;
        }

        // Os sinais saem "adiados": quem ouve pode chamar o compositor de volta.
        for event in events {
            match event {
                Event::Opened(id, app_id, title, pid) => {
                    let args = [
                        "window_opened".to_variant(),
                        id.to_variant(),
                        GString::from(app_id.as_str()).to_variant(),
                        GString::from(title.as_str()).to_variant(),
                        pid.to_variant(),
                    ];
                    self.base_mut().call_deferred("emit_signal", &args);
                }
                Event::Closed(id) => {
                    self.textures.remove(&id);
                    let args = ["window_closed".to_variant(), id.to_variant()];
                    self.base_mut().call_deferred("emit_signal", &args);
                }
            }
        }
    }

    #[func]
    fn get_texture(&self, id: i64) -> Option<Gd<ImageTexture>> {
        self.textures.get(&id).cloned()
    }

    /// A imagem atual da janela, na memória (para salvar em PNG no teste).
    #[func]
    fn get_image(&self, id: i64) -> Option<Gd<Image>> {
        let inner = self.inner.as_ref()?;
        let win = inner.state.windows.iter().find(|w| w.id == id)?;
        if win.width <= 0 {
            return None;
        }
        let bytes = PackedByteArray::from(win.pixels.as_slice());
        Image::create_from_data(win.width, win.height, false, Format::RGBA8, &bytes)
    }

    #[func]
    fn get_title(&self, id: i64) -> GString {
        let Some(inner) = self.inner.as_ref() else { return GString::new() };
        inner
            .state
            .windows
            .iter()
            .find(|w| w.id == id)
            .map(|w| GString::from(toplevel_names(&w.toplevel).1.as_str()))
            .unwrap_or_default()
    }

    /// Uma tecla (código evdev, o mesmo do Linux) para a janela.
    #[func]
    fn key(&mut self, id: i64, evdev: i32, pressed: bool) {
        let Some(inner) = self.inner.as_mut() else { return };
        let Some(surface) = inner.state.windows.iter().find(|w| w.id == id).map(|w| w.toplevel.wl_surface().clone())
        else {
            return;
        };
        let keyboard = inner.state.seat.get_keyboard().unwrap();
        if keyboard.current_focus().as_ref() != Some(&surface) {
            keyboard.set_focus(&mut inner.state, Some(surface), SERIAL_COUNTER.next_serial());
        }
        let time = inner.start.elapsed().as_millis() as u32;
        let state = if pressed { KeyState::Pressed } else { KeyState::Released };
        keyboard.input::<(), _>(
            &mut inner.state,
            Keycode::new(evdev as u32 + 8),
            state,
            SERIAL_COUNTER.next_serial(),
            time,
            |_, _, _| FilterResult::Forward,
        );
        let _ = inner.display.flush_clients();
    }

    /// O ponteiro em (x, y), em pixels da janela.
    #[func]
    fn pointer_motion(&mut self, id: i64, x: f64, y: f64) {
        let Some(inner) = self.inner.as_mut() else { return };
        let Some(surface) = inner.state.windows.iter().find(|w| w.id == id).map(|w| w.toplevel.wl_surface().clone())
        else {
            return;
        };
        let pointer = inner.state.seat.get_pointer().unwrap();
        let time = inner.start.elapsed().as_millis() as u32;
        let event = MotionEvent { location: (x, y).into(), serial: SERIAL_COUNTER.next_serial(), time };
        pointer.motion(&mut inner.state, Some((surface, (0.0, 0.0).into())), &event);
        pointer.frame(&mut inner.state);
        let _ = inner.display.flush_clients();
    }

    /// Botão do mouse (código do Linux: 0x110 esquerdo, 0x111 direito).
    #[func]
    fn pointer_button(&mut self, button: i32, pressed: bool) {
        let Some(inner) = self.inner.as_mut() else { return };
        let pointer = inner.state.seat.get_pointer().unwrap();
        let time = inner.start.elapsed().as_millis() as u32;
        let state = if pressed { ButtonState::Pressed } else { ButtonState::Released };
        let event = ButtonEvent { serial: SERIAL_COUNTER.next_serial(), time, button: button as u32, state };
        pointer.button(&mut inner.state, &event);
        pointer.frame(&mut inner.state);
        let _ = inner.display.flush_clients();
    }

    /// Números do spike: custo médio da cópia shm e da subida da textura.
    #[func]
    fn stats(&self) -> VarDictionary {
        let mut d = VarDictionary::new();
        if let Some(inner) = self.inner.as_ref() {
            let s = &inner.state;
            d.set("copias", s.copy_count as i64);
            d.set("copia_media_us", if s.copy_count > 0 { (s.copy_us_total / s.copy_count as u128) as i64 } else { 0 });
            d.set("janelas", s.windows.len() as i64);
        }
        d.set("subidas", self.upload_count as i64);
        d.set(
            "subida_media_us",
            if self.upload_count > 0 { (self.upload_us_total / self.upload_count as u128) as i64 } else { 0 },
        );
        d
    }
}
