//! O lado Wayland do compositor: o que os apps enxergam.
//!
//! Um app aberto pelo hub conecta no socket do hub (ex.: `gamehub-0`) e acha
//! aqui os "monitores" (os outputs `HUB-1`, `HUB-2`...), um teclado e um mouse
//! (o seat), e o xdg-shell, que é o jeito de criar janelas. Cada janela
//! ("toplevel") vira um `Win`, com a imagem já em RGBA, pronta para a Godot.
//!
//! Saídas (Fase 14.26): cada monitor da mesa é uma saída (`wl_output`, com o
//! `xdg-output`). O hub diz onde cada janela fica (`place`), e o compositor
//! junta as janelas de uma saída numa imagem só (`compose_outputs`), que vira
//! a textura daquele monitor. O mouse também é por saída
//! (`pointer_motion_output`): o compositor acha a janela embaixo do ponto.
//!
//! Camadas (Fase 14.27): o layer-shell é como o Quickshell do Omarchy desenha
//! a barra, o fundo e o menu. Uma camada também é um `Win` (com o papel
//! `Role::Layer`), para aproveitar a cópia da imagem, os menus e o mouse, mas
//! a Godot não fica sabendo dela (nenhum `Opened`): é o compositor que decide
//! o lugar (pelas âncoras, em `layers.rs`) e desenha na saída, na ordem fundo,
//! baixo, janelas, topo e sobreposição. A faixa que a barra reserva diminui a
//! área útil da saída (`Event::UsableAreaChanged`), onde o hub arruma as janelas.
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
use smithay::reexports::wayland_server::backend::{ClientData, ClientId, DisconnectReason, GlobalId};
use smithay::reexports::wayland_server::protocol::wl_callback::WlCallback;
use smithay::reexports::wayland_server::protocol::{wl_buffer, wl_seat, wl_surface::WlSurface};
use smithay::reexports::wayland_server::{Client, Display, DisplayHandle, ListeningSocket, Resource};
use smithay::utils::{Serial, Transform, SERIAL_COUNTER};
use smithay::wayland::buffer::BufferHandler;
use smithay::wayland::compositor::{
    add_pre_commit_hook, with_states, BufferAssignment, CompositorClientState, CompositorHandler, CompositorState, Damage,
    SurfaceAttributes,
};
use smithay::reexports::wayland_server::protocol::wl_output::WlOutput;
use smithay::wayland::shell::wlr_layer::{
    Anchor, KeyboardInteractivity, Layer, LayerSurface, LayerSurfaceAttributes, LayerSurfaceCachedState,
    WlrLayerShellHandler, WlrLayerShellState,
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
use smithay::wayland::shm::{with_buffer_contents, ShmHandler, ShmState};
use smithay::utils::{Logical, Rectangle};
use smithay::{
    delegate_compositor, delegate_data_device, delegate_layer_shell, delegate_output, delegate_primary_selection,
    delegate_seat, delegate_shm, delegate_xdg_decoration, delegate_xdg_shell,
};

use crate::layers::{self, LayerSpec};
use crate::pixels::{blend_over, blend_over_clipped, copy_rows, crop_rect, damaged_rows, fill, Rect, ShmLayout};

/// Tamanho com que toda janela nasce (o de um telão), até o telão pedir outro
/// com `resize`.
pub const WINDOW_SIZE: (i32, i32) = (1280, 720);
/// O maior tamanho que o hub aceita pedir para uma janela.
pub const MAX_SIZE: i32 = 4096;
/// Quanto um "dente" da rodinha do mouse rola, em pixels (o mesmo número que
/// o Linux usa: os apps esperam 15).
pub const WHEEL_STEP: f64 = 15.0;

/// Quantas saídas o hub aceita (a mesa tem 3; folga para o futuro).
pub const MAX_OUTPUTS: usize = 8;
/// A cor de uma saída onde não há nada (nem janela, nem a camada do fundo). RGBA.
pub const OUTPUT_BACKGROUND: [u8; 4] = [18, 18, 22, 255];

/// O que aconteceu e a Godot precisa saber (vira sinal no nó).
#[derive(Debug, PartialEq, Eq)]
pub enum Event {
    /// Janela nova com a primeira imagem: id, app_id, título, pid do app.
    Opened(i64, String, String, i64),
    /// A janela fechou (o app fechou, morreu ou escondeu a janela).
    Closed(i64),
    /// O app trocou o título da janela (ex.: o site aberto no navegador).
    TitleChanged(i64, String),
    /// A área útil da saída mudou (uma camada reservou ou soltou uma faixa):
    /// a saída e o retângulo que sobra para as janelas.
    UsableAreaChanged(usize, Rect),
}

/// O que a superfície é: uma janela comum (xdg) ou uma camada (layer-shell).
pub enum Role {
    Toplevel(ToplevelSurface),
    Layer(LayerInfo),
}

/// Uma camada: a barra, o fundo, o menu, uma notificação...
pub struct LayerInfo {
    pub surface: LayerSurface,
    /// O nome que o app deu (ex.: "quickshell"), só para conferir.
    pub namespace: String,
    /// Em qual saída ela fica (None: a saída sumiu e o app foi avisado).
    pub output: Option<usize>,
    /// Já fez o commit inicial (só então as âncoras e o tamanho valem).
    committed: bool,
    /// Escondeu (commit sem imagem): o próximo commit precisa de um configure novo.
    configure_again: bool,
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
    /// Onde a janela fica: (saída, retângulo em pixels da saída). None: em
    /// nenhuma saída (só a textura própria, a API por janela da parte 2).
    /// Numa camada, quem decide é o compositor (`State::arrange`).
    pub place: Option<(usize, Rect)>,
    /// Mudou desde a última composição das saídas (o `dirty` é da textura própria).
    out_dirty: bool,
}

/// Um monitor da mesa, visto pelos apps (a `Output`) e pelo hub (a imagem composta).
pub struct OutputSlot {
    pub output: Output,
    global: GlobalId,
    pub size: (i32, i32),
    /// O que sobra para as janelas depois das faixas reservadas pelas camadas.
    pub usable: Rect,
    /// A imagem composta (RGBA): o fundo e as janelas desta saída.
    pub pixels: Vec<u8>,
    /// Precisa compor de novo (uma janela entrou, saiu ou mudou de lugar).
    dirty: bool,
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
    fn new(id: i64, role: Role) -> Win {
        Win {
            id,
            role,
            pixels: Vec::new(),
            crop: Rect::default(),
            dirty: false,
            mapped: false,
            callbacks: Vec::new(),
            popups: Vec::new(),
            composed: Vec::new(),
            place: None,
            out_dirty: false,
        }
    }

    pub fn wl_surface(&self) -> &WlSurface {
        match &self.role {
            Role::Toplevel(t) => t.wl_surface(),
            Role::Layer(l) => l.surface.wl_surface(),
        }
    }

    pub fn toplevel(&self) -> Option<&ToplevelSurface> {
        match &self.role {
            Role::Toplevel(t) => Some(t),
            Role::Layer(_) => None,
        }
    }

    pub fn layer(&self) -> Option<&LayerInfo> {
        match &self.role {
            Role::Layer(l) => Some(l),
            Role::Toplevel(_) => None,
        }
    }

    pub fn is_layer(&self) -> bool {
        self.layer().is_some()
    }

    /// O que a camada pediu no último commit (None numa janela comum).
    pub fn layer_state(&self) -> Option<LayerSurfaceCachedState> {
        let layer = self.layer()?;
        Some(with_states(layer.surface.wl_surface(), |states| {
            *states.cached_state.get::<LayerSurfaceCachedState>().current()
        }))
    }

    /// Em que altura da pilha a superfície fica: 0 fundo, 1 baixo, 2 janelas,
    /// 3 topo, 4 sobreposição (a maior fica por cima).
    fn stack_level(&self) -> u8 {
        match self.layer_state().map(|s| s.layer) {
            None => 2,
            Some(Layer::Background) => 0,
            Some(Layer::Bottom) => 1,
            Some(Layer::Top) => 3,
            Some(Layer::Overlay) => 4,
        }
    }

    /// O teclado desta camada (None numa janela comum).
    fn keyboard_mode(&self) -> Option<KeyboardInteractivity> {
        self.layer_state().map(|s| s.keyboard_interactivity)
    }

    /// O nome do app e o título (numa camada: "layer:<nome>" e o nível).
    pub fn names(&self) -> (String, String) {
        match &self.role {
            Role::Toplevel(t) => toplevel_names(t),
            Role::Layer(l) => {
                let level = self.layer_state().map(|s| format!("{:?}", s.layer)).unwrap_or_default();
                (format!("layer:{}", l.namespace), level)
            }
        }
    }

    /// A imagem mudou: sobe de novo a textura própria e a da saída.
    fn touch(&mut self) {
        self.dirty = true;
        self.out_dirty = true;
    }

    /// O pedaço da saída que a janela cobre de verdade: o lugar dela,
    /// cortado pelo tamanho da imagem (o app pode não ter redesenhado ainda).
    fn visible_rect(&self) -> Option<(usize, Rect)> {
        let (output, rect) = self.place?;
        if !self.mapped || self.crop.is_empty() {
            return None;
        }
        Some((output, rect.intersect(&Rect::new(rect.x, rect.y, self.crop.w, self.crop.h))))
    }

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
            None => self.wl_surface().clone(),
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
            None => (self.wl_surface().clone(), (-self.crop.x as f64, -self.crop.y as f64)),
        }
    }

    /// A área onde os menus podem ficar, contada a partir do canto do recorte
    /// de `parent`: numa janela, a imagem dela (o menu é empurrado para caber
    /// no lugar); numa camada, a saída inteira (o menu da barra desce para fora
    /// dela). `output_size`: o tamanho da saída da camada.
    fn popup_area(&self, parent: &WlSurface, output_size: Option<(i32, i32)>) -> Rectangle<i32, Logical> {
        let (px, py) = self.surface_position(parent);
        if let (true, Some((_, rect)), Some((w, h))) = (self.is_layer(), self.place, output_size) {
            return Rectangle::new((-rect.x - px, -rect.y - py).into(), (w, h).into());
        }
        let (w, h) = if self.crop.is_empty() { WINDOW_SIZE } else { (self.crop.w, self.crop.h) };
        Rectangle::new((-px, -py).into(), (w, h).into())
    }

    /// O ponto (x, y) da imagem aceita o mouse? Vale a "região de clique" que
    /// o app declarou (uma camada transparente pode deixar o clique passar);
    /// sem região, a imagem toda.
    fn takes_pointer(&self, x: f64, y: f64) -> bool {
        let point = (x.floor() as i32 + self.crop.x, y.floor() as i32 + self.crop.y);
        with_states(self.wl_surface(), |states| {
            let mut guard = states.cached_state.get::<SurfaceAttributes>();
            guard.current().input_region.as_ref().is_none_or(|region| region.contains(point))
        })
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
    /// A camada que ganhou o teclado num clique (teclado "on_demand", ex.: um
    /// campo de busca na barra) ou por abrir um menu com "grab". Perde quando
    /// o hub dá o foco a uma janela.
    layer_focus: Option<i64>,
    /// Superfícies cuja camada o app já destruiu (veja `calm_dead_layer`).
    dead_layers: Vec<WlSurface>,
    /// Onde o mouse está: a janela e, se for o caso, o menu.
    pointer_over: Option<(i64, Option<usize>)>,
    /// O clique que fechou os menus não vai para o app, nem o "soltou" dele.
    swallow_release: Option<u32>,
    /// Os monitores, na ordem (0 é o da esquerda). Começa com um só, do
    /// tamanho de um telão, até o hub chamar `set_outputs`.
    pub outputs: Vec<OutputSlot>,
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

        // Um "monitor" de mentira, do tamanho de um telão (o hub troca com set_outputs).
        let outputs = vec![new_output(&dh, 0, WINDOW_SIZE, 0)];

        Ok(State {
            compositor_state: CompositorState::new::<State>(&dh),
            xdg_shell_state: XdgShellState::new::<State>(&dh),
            layer_shell_state: WlrLayerShellState::new::<State>(&dh),
            _decoration_state: XdgDecorationState::new::<State>(&dh),
            shm_state: ShmState::new::<State>(&dh, vec![]),
            data_device_state: DataDeviceState::new::<State>(&dh),
            primary_selection_state: PrimarySelectionState::new::<State>(&dh),
            focused_window: None,
            layer_focus: None,
            dead_layers: Vec::new(),
            pointer_over: None,
            swallow_release: None,
            // Com o xdg-output: apps como o Quickshell perguntam o nome e o lugar de cada monitor.
            _output_manager: OutputManagerState::new_with_xdg_output::<State>(&dh),
            seat_state,
            seat,
            outputs,
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
            if w.wl_surface() == surface {
                Some((wi, None))
            } else {
                w.popups.iter().position(|p| p.surface.wl_surface() == surface).map(|pi| (wi, Some(pi)))
            }
        })
    }

    /// Quem fica com o teclado, nesta ordem:
    /// 1. a camada de topo ou de sobreposição com teclado "exclusive" (o menu
    ///    do Omarchy aberto), a mais de cima;
    /// 2. a camada que ganhou o teclado num clique ou num menu (`layer_focus`);
    /// 3. a janela que o hub escolheu (`focused_window`).
    fn keyboard_owner(&self) -> Option<&Win> {
        let exclusive = (3..=4).rev().find_map(|level| {
            self.windows.iter().rev().find(|w| {
                w.mapped
                    && w.stack_level() == level
                    && w.keyboard_mode() == Some(KeyboardInteractivity::Exclusive)
            })
        });
        let on_demand = self.layer_focus.and_then(|id| self.window(id)).filter(|w| {
            w.mapped && (w.keyboard_mode() != Some(KeyboardInteractivity::None) || w.popups.iter().any(|p| p.grab))
        });
        exclusive.or(on_demand).or_else(|| self.focused_window.and_then(|id| self.window(id)))
    }

    /// Põe o teclado em quem deve recebê-lo (veja `keyboard_owner`): a
    /// superfície dele ou o menu com "grab" dela.
    fn refresh_keyboard_focus(&mut self) {
        let target = self.keyboard_owner().map(|w| w.keyboard_target());
        let keyboard = self.seat.get_keyboard().unwrap();
        if keyboard.current_focus() != target {
            keyboard.set_focus(self, target, SERIAL_COUNTER.next_serial());
        }
    }

    /// A saída para uma camada nova: a que o app pediu, ou a da janela com
    /// foco, ou a primeira.
    fn output_for_layer(&self, wanted: Option<&WlOutput>) -> usize {
        let asked = wanted.and_then(|w| self.outputs.iter().position(|slot| slot.output.owns(w)));
        let focused = self.focused_window.and_then(|id| self.window(id)).and_then(|w| w.place).map(|(o, _)| o);
        asked.or(focused).unwrap_or(0)
    }

    /// Arruma as camadas da saída `o` (veja `layers.rs`): dá o lugar e o
    /// tamanho de cada uma (o configure só sai se o tamanho mudou) e avisa se
    /// a área útil mudou.
    fn arrange(&mut self, o: usize) {
        let Some(size) = self.outputs.get(o).map(|slot| slot.size) else { return };
        let mut indices = Vec::new();
        let mut specs = Vec::new();
        for (i, win) in self.windows.iter().enumerate() {
            let Some(info) = win.layer() else { continue };
            if info.output != Some(o) || !info.committed {
                continue;
            }
            let s = win.layer_state().unwrap();
            indices.push(i);
            specs.push(LayerSpec {
                layer: s.layer,
                size: (s.size.w, s.size.h),
                anchor: s.anchor,
                zone: s.exclusive_zone,
                margin: s.margin,
                mapped: win.mapped,
            });
        }
        let (places, usable) = layers::arrange(size, &specs);
        for (&i, rect) in indices.iter().zip(places) {
            let win = &mut self.windows[i];
            let new = Some((o, rect));
            if win.place != new {
                win.place = new;
                win.out_dirty = true;
            }
            let Role::Layer(info) = &mut win.role else { continue };
            info.surface.with_pending_state(|state| state.size = Some((rect.w, rect.h).into()));
            if info.configure_again || !initial_configure_sent(&info.surface) {
                info.configure_again = false;
                info.surface.send_configure();
            } else {
                info.surface.send_pending_configure();
            }
        }
        let slot = &mut self.outputs[o];
        if slot.usable != usable {
            slot.usable = usable;
            slot.dirty = true;
            self.events.push(Event::UsableAreaChanged(o, usable));
        }
    }

    /// O que está embaixo do ponto (x, y) da saída: o índice da superfície (a
    /// mais de cima, da sobreposição até o fundo) e o ponto na imagem dela.
    /// Menus contam; numa janela, só dentro do lugar dela (é onde aparecem).
    fn surface_at(&self, output: usize, x: f64, y: f64) -> Option<(usize, f64, f64)> {
        (0..=4u8).rev().find_map(|level| {
            self.windows.iter().enumerate().rev().find_map(|(i, w)| {
                let (o, rect) = w.visible_rect()?;
                if o != output || w.stack_level() != level {
                    return None;
                }
                let (lx, ly) = (x - rect.x as f64, y - rect.y as f64);
                let inside = x >= rect.x as f64
                    && y >= rect.y as f64
                    && x < (rect.x + rect.w) as f64
                    && y < (rect.y + rect.h) as f64;
                let on_popup = w.popup_at(lx, ly).is_some() && (inside || w.is_layer());
                let hit = on_popup || (inside && (!w.is_layer() || w.takes_pointer(lx, ly)));
                hit.then_some((i, lx, ly))
            })
        })
    }

    /// Fecha todos os menus da janela (o app recebe "popup_done" e os destrói).
    fn dismiss_popups(&mut self, window_index: usize) {
        for popup in self.windows[window_index].popups.iter().rev() {
            popup.surface.send_popup_done();
        }
    }

    /// A saída precisa compor de novo (se existir).
    fn mark_output(&mut self, place: Option<(usize, Rect)>) {
        if let Some(slot) = place.and_then(|(o, _)| self.outputs.get_mut(o)) {
            slot.dirty = true;
        }
    }

    /// A janela mais de cima da saída `output` no ponto (x, y). None se não
    /// houver janela, ou se uma camada (a barra, o menu) estiver por cima.
    pub fn window_at(&self, output: usize, x: f64, y: f64) -> Option<i64> {
        let (i, _, _) = self.surface_at(output, x, y)?;
        let win = &self.windows[i];
        (!win.is_layer()).then_some(win.id)
    }

    /// Monta a imagem da saída `index`: o fundo liso e, por cima, as camadas
    /// e as janelas dela, de baixo para cima (fundo, baixo, janelas, topo e
    /// sobreposição; no mesmo nível, a última da lista por cima), cada uma no
    /// seu lugar e com os menus. Os menus de uma janela ficam presos ao lugar
    /// dela; os de uma camada podem sair dela (o menu que desce da barra).
    fn compose(&mut self, index: usize) {
        let (w, h) = self.outputs[index].size;
        let whole = Rect::new(0, 0, w, h);
        let mut pixels = std::mem::take(&mut self.outputs[index].pixels);
        pixels.resize((w * h * 4) as usize, 0);
        fill(&mut pixels, OUTPUT_BACKGROUND);
        for level in 0..=4u8 {
            for win in self.windows.iter() {
                let Some((o, clip)) = win.visible_rect() else { continue };
                if o != index || win.stack_level() != level {
                    continue;
                }
                blend_over_clipped(&mut pixels, w, h, &win.pixels, win.width(), win.height(), clip.x, clip.y, clip);
                let popup_clip = if win.is_layer() { whole } else { clip };
                for (i, p) in win.popups.iter().enumerate() {
                    if p.mapped {
                        let (px, py) = win.popup_position(i);
                        let (x, y) = (clip.x + px, clip.y + py);
                        blend_over_clipped(&mut pixels, w, h, &p.pixels, p.crop.w, p.crop.h, x, y, popup_clip);
                    }
                }
            }
        }
        let slot = &mut self.outputs[index];
        slot.pixels = pixels;
        slot.dirty = false;
    }
}

/// Cria um monitor (`HUB-1`, `HUB-2`...) com o tamanho dado, a `x` pixels da
/// borda esquerda do primeiro (os monitores ficam lado a lado, como na mesa).
fn new_output(dh: &DisplayHandle, index: usize, size: (i32, i32), x: i32) -> OutputSlot {
    let output = Output::new(
        format!("HUB-{}", index + 1),
        PhysicalProperties {
            size: (0, 0).into(),
            subpixel: Subpixel::Unknown,
            make: "Game Hub".into(),
            model: "Monitor da mesa".into(),
        },
    );
    let mode = Mode { size: size.into(), refresh: 60_000 };
    output.change_current_state(Some(mode), Some(Transform::Normal), Some(Scale::Integer(1)), Some((x, 0).into()));
    output.set_preferred(mode);
    let global = output.create_global::<State>(dh);
    OutputSlot { output, global, size, usable: Rect::new(0, 0, size.0, size.1), pixels: Vec::new(), dirty: true }
}

/// A camada já recebeu o primeiro configure?
fn initial_configure_sent(layer: &LayerSurface) -> bool {
    with_states(layer.wl_surface(), |states| {
        states.data_map.get::<std::sync::Mutex<LayerSurfaceAttributes>>().unwrap().lock().unwrap().initial_configure_sent
    })
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
    /// (Numa camada, quem decide o tamanho é o compositor: devolve false.)
    pub fn resize(&mut self, id: i64, width: i32, height: i32) -> bool {
        let Some(toplevel) = self.state.window(id).and_then(|w| w.toplevel()) else { return false };
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
    /// apertadas, do ponto de vista do app. Uma camada com o teclado
    /// "on_demand" perde o teclado; a "exclusive" (o menu aberto) continua com ele.
    pub fn focus(&mut self, id: Option<i64>) {
        let id = id.filter(|&id| self.state.window(id).is_some_and(|w| !w.is_layer()));
        self.state.focused_window = id;
        self.state.layer_focus = None;
        // O teclado vai para a janela (ou para o menu com "grab" dela).
        self.state.refresh_keyboard_focus();
        for win in &self.state.windows {
            let Some(toplevel) = win.toplevel() else { continue };
            let active = id == Some(win.id);
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
    /// manda só o "apertou" e o "soltou"). Com uma camada "exclusive" aberta
    /// (o menu), a tecla vai para ela.
    pub fn key(&mut self, id: i64, evdev: u32, pressed: bool) {
        if !self.state.window(id).is_some_and(|w| !w.is_layer()) {
            return;
        }
        if self.focused() != Some(id) {
            self.focus(Some(id));
        }
        self.key_focused(evdev, pressed);
    }

    /// Uma tecla para quem tem o teclado agora (o menu, a barra ou a janela
    /// com foco), sem mudar o foco. Serve também com a mesa sem janela nenhuma.
    pub fn key_focused(&mut self, evdev: u32, pressed: bool) {
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
        // O clique numa camada "on_demand" (um campo na barra) dá o teclado a
        // ela; o clique numa janela devolve o teclado para a janela do hub.
        if pressed {
            if let Some((id, _)) = self.state.pointer_over {
                let wants = self.state.window(id).map(|w| (w.keyboard_mode(), w.stack_level()));
                let take = match wants {
                    Some((Some(KeyboardInteractivity::OnDemand), _)) => true,
                    // "exclusive" no fundo ou embaixo vale como "on_demand" (regra do protocolo).
                    Some((Some(KeyboardInteractivity::Exclusive), level)) => level < 2,
                    _ => false,
                };
                let is_window = matches!(wants, Some((None, _)));
                if take || (is_window && self.state.layer_focus.is_some()) {
                    self.state.layer_focus = take.then_some(id);
                    self.state.refresh_keyboard_focus();
                }
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

    // --- Saídas (Fase 14.26) ---------------------------------------------------

    /// Troca os monitores pelos de `sizes` (largura, altura de cada um), lado
    /// a lado. Os apps veem os monitores velhos sumirem e os novos chegarem.
    /// Janelas que estavam numa saída que deixou de existir ficam sem lugar.
    /// As camadas são fechadas (o monitor delas sumiu): o app cria outras
    /// nos monitores novos, como quando se tira um monitor do cabo.
    pub fn set_outputs(&mut self, sizes: &[(i32, i32)]) -> bool {
        if sizes.is_empty() || sizes.len() > MAX_OUTPUTS {
            return false;
        }
        let state = &mut self.state;
        for slot in state.outputs.drain(..) {
            for win in &state.windows {
                slot.output.leave(win.wl_surface());
            }
            state.dh.remove_global::<State>(slot.global);
        }
        for win in state.windows.iter_mut() {
            if let Role::Layer(info) = &mut win.role {
                if info.output.take().is_some() {
                    info.surface.send_close();
                }
                win.place = None;
            }
        }
        if state.layer_focus.is_some() {
            state.layer_focus = None;
            state.refresh_keyboard_focus();
        }
        let mut x = 0;
        for (i, &(w, h)) in sizes.iter().enumerate() {
            let size = (w.clamp(1, MAX_SIZE), h.clamp(1, MAX_SIZE));
            state.outputs.push(new_output(&state.dh, i, size, x));
            x += size.0;
        }
        let count = state.outputs.len();
        for win in state.windows.iter_mut() {
            match win.place {
                Some((o, _)) if o < count => state.outputs[o].output.enter(win.wl_surface()),
                Some(_) => win.place = None,
                None => {}
            }
        }
        self.flush();
        true
    }

    pub fn output_count(&self) -> usize {
        self.state.outputs.len()
    }

    /// Põe a janela na saída `output`, no retângulo `rect` (pixels da saída), e
    /// pede ao app esse tamanho. `output` None tira a janela das saídas.
    /// Devolve false se a janela ou a saída não existem (ou se for uma camada:
    /// o lugar dela vem das âncoras).
    pub fn place(&mut self, id: i64, output: Option<usize>, rect: Rect) -> bool {
        if output.is_some_and(|o| o >= self.state.outputs.len()) {
            return false;
        }
        let Some(wi) = self.state.windows.iter().position(|w| w.id == id && !w.is_layer()) else { return false };
        let rect = Rect::new(rect.x, rect.y, rect.w.clamp(1, MAX_SIZE), rect.h.clamp(1, MAX_SIZE));
        let new = output.map(|o| (o, rect));
        let old = self.state.windows[wi].place;
        if old == new {
            return true;
        }
        self.state.mark_output(old);
        self.state.mark_output(new);
        let surface = self.state.windows[wi].wl_surface().clone();
        for (i, slot) in self.state.outputs.iter().enumerate() {
            if output == Some(i) {
                slot.output.enter(&surface);
            } else {
                slot.output.leave(&surface);
            }
        }
        self.state.windows[wi].place = new;
        let old_size = old.map(|(_, r)| (r.w, r.h));
        if output.is_some() && old_size != Some((rect.w, rect.h)) {
            self.resize(id, rect.w, rect.h);
        }
        self.flush();
        true
    }

    /// Põe a janela por cima das outras janelas (na composição e para o
    /// mouse). As camadas de topo e de sobreposição continuam por cima dela.
    pub fn raise(&mut self, id: i64) -> bool {
        let Some(wi) = self.state.windows.iter().position(|w| w.id == id && !w.is_layer()) else { return false };
        let win = self.state.windows.remove(wi);
        let place = win.place;
        self.state.windows.push(win);
        self.state.mark_output(place);
        true
    }

    /// Junta de novo as saídas que mudaram. Devolve quais (os índices).
    pub fn compose_outputs(&mut self) -> Vec<usize> {
        let state = &mut self.state;
        let mut changed = Vec::new();
        for o in 0..state.outputs.len() {
            let touched = state.windows.iter().any(|w| w.out_dirty && matches!(w.place, Some((p, _)) if p == o));
            if state.outputs[o].dirty || touched {
                state.compose(o);
                changed.push(o);
            }
        }
        for win in state.windows.iter_mut() {
            win.out_dirty = false;
        }
        changed
    }

    /// O ponteiro em (x, y), em pixels da saída `output`: vai para a janela
    /// (ou o menu) que estiver embaixo. Sem janela embaixo, o ponteiro sai dos apps.
    /// Camadas contam: em cima da barra, o mouse é da barra.
    pub fn pointer_motion_output(&mut self, output: usize, x: f64, y: f64) {
        match self.state.surface_at(output, x, y) {
            Some((i, lx, ly)) => self.pointer_motion(self.state.windows[i].id, lx, ly),
            None => self.pointer_leave(),
        }
    }

    /// A área útil da saída (o que sobra das faixas das camadas).
    pub fn usable_area(&self, output: usize) -> Option<Rect> {
        self.state.outputs.get(output).map(|slot| slot.usable)
    }

    /// Pede ao app para fechar a janela (como o X da barra de título).
    /// O app pode perguntar antes ("salvar?"); quando fechar, sai o `Closed`.
    pub fn close(&mut self, id: i64) -> bool {
        let Some(win) = self.state.windows.iter().find(|w| w.id == id) else { return false };
        match &win.role {
            Role::Toplevel(t) => t.send_close(),
            Role::Layer(l) => l.surface.send_close(),
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

impl State {
    /// O commit de uma camada: a imagem (como numa janela, mas sem avisar a
    /// Godot), depois arrumar as camadas da saída (o primeiro configure, a
    /// zona exclusiva) e ver quem fica com o teclado.
    fn commit_layer(&mut self, index: usize, buffer: Option<BufferAssignment>, surface: &WlSurface, damage: &[Damage]) {
        let win = &mut self.windows[index];
        match buffer {
            Some(BufferAssignment::NewBuffer(buffer)) => {
                let start = Instant::now();
                if read_picture(surface, &buffer, damage, &mut win.pixels, &mut win.crop) == Some(true) {
                    win.touch();
                    self.copy_us_total += start.elapsed().as_micros();
                    self.copy_count += 1;
                }
                buffer.release();
                if !win.mapped && !win.pixels.is_empty() {
                    win.mapped = true;
                    win.out_dirty = true;
                }
            }
            Some(BufferAssignment::Removed) => {
                // Escondeu: some da saída, solta a faixa reservada, e só volta
                // depois de um commit vazio e de um configure novo.
                win.pixels.clear();
                win.crop = Rect::default();
                win.mapped = false;
                win.out_dirty = true;
                if let Role::Layer(info) = &mut win.role {
                    info.committed = false;
                    info.configure_again = true;
                }
                let place = win.place;
                self.mark_output(place);
            }
            None => {}
        }
        if let Some(o) = self.windows[index].layer().and_then(|l| l.output) {
            self.arrange(o);
        }
        self.refresh_keyboard_focus();
    }

    /// Contorno de um defeito do Smithay 0.7: quando o app destrói a camada, o
    /// Smithay zera o que ela pediu (tamanho 0, sem âncora), mas a conferência
    /// "largura 0 precisa das duas âncoras" continua presa à superfície. O
    /// próximo commit nela (o Quickshell faz um, vazio, ao fechar o menu)
    /// disparava o erro e derrubava o app inteiro (a barra e o fundo juntos).
    /// Para uma camada morta, "encostada nos quatro lados" deixa a conferência
    /// passar; e ela não é mais usada para nada.
    fn calm_dead_layer(&mut self, surface: &WlSurface) {
        if self.dead_layers.contains(surface) {
            with_states(surface, |states| {
                states.cached_state.get::<LayerSurfaceCachedState>().pending().anchor = Anchor::all();
            });
        }
    }

    /// Guarda um menu novo da superfície `index` (aberto pela janela, por uma
    /// camada ou por outro menu) e calcula o lugar dele.
    fn track_popup(&mut self, index: usize, parent: WlSurface, surface: PopupSurface, positioner: PositionerState) {
        let output_size = self.windows[index].place.and_then(|(o, _)| self.outputs.get(o)).map(|slot| slot.size);
        let win = &mut self.windows[index];
        let geometry = positioner.get_unconstrained_geometry(win.popup_area(&parent, output_size));
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

    /// Tira a superfície da lista (o app destruiu). Uma janela avisa a Godot;
    /// uma camada arruma de novo as outras da saída (a faixa dela fica livre).
    fn remove_window(&mut self, surface: &WlSurface) {
        let Some(i) = self.windows.iter().position(|w| w.wl_surface() == surface) else { return };
        let win = self.windows.remove(i);
        self.mark_output(win.place);
        if self.focused_window == Some(win.id) {
            self.focused_window = None;
        }
        if self.layer_focus == Some(win.id) {
            self.layer_focus = None;
        }
        match win.layer() {
            Some(info) => {
                if let Some(o) = info.output {
                    self.arrange(o);
                }
                self.refresh_keyboard_focus();
            }
            None if win.mapped => self.events.push(Event::Closed(win.id)),
            None => {}
        }
    }
}

impl CompositorHandler for State {
    fn compositor_state(&mut self) -> &mut CompositorState {
        &mut self.compositor_state
    }

    /// Toda superfície nova ganha o nosso gancho de antes do commit. Ele roda
    /// antes dos ganchos do Smithay (são chamados na ordem em que entraram).
    fn new_surface(&mut self, surface: &WlSurface) {
        add_pre_commit_hook::<State, _>(surface, |state, _, surface| state.calm_dead_layer(surface));
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
        // compositor manda o primeiro "configure" (o tamanho e o lugar). Numa
        // camada, o configure sai do `arrange`, no fim deste commit.
        match popup {
            None => match &mut self.windows[index].role {
                Role::Toplevel(t) if !t.is_initial_configure_sent() => {
                    t.send_configure();
                }
                Role::Layer(info) => info.committed = true,
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
            win.out_dirty |= win.mapped;
            return;
        }

        if win.is_layer() {
            self.commit_layer(index, buffer, surface, &damage);
            return;
        }
        match buffer {
            Some(BufferAssignment::NewBuffer(buffer)) => {
                let start = Instant::now();
                if read_picture(surface, &buffer, &damage, &mut win.pixels, &mut win.crop) == Some(true) {
                    win.touch();
                    self.copy_us_total += start.elapsed().as_micros();
                    self.copy_count += 1;
                }
                // Já copiamos: o app pode reaproveitar a memória.
                buffer.release();
            }
            Some(BufferAssignment::Removed) => {
                // O app escondeu a janela. Para a Godot, ela fechou; se voltar,
                // abre de novo (com o mesmo id), refazendo o primeiro "configure".
                if let Some(t) = win.toplevel() {
                    t.reset_initial_configure_sent();
                }
                win.pixels.clear();
                win.crop = Rect::default();
                win.dirty = false;
                if win.mapped {
                    win.mapped = false;
                    self.events.push(Event::Closed(win.id));
                }
                let place = win.place;
                self.mark_output(place);
                return;
            }
            None => {}
        }
        if !win.mapped && !win.pixels.is_empty() {
            win.mapped = true;
            win.out_dirty = true;
            let (app_id, title) = win.names();
            let pid = surface
                .client()
                .and_then(|c| c.get_credentials(&self.dh).ok())
                .map(|c| c.pid as i64)
                .unwrap_or(-1);
            self.events.push(Event::Opened(win.id, app_id, title, pid));
        }
    }
}

impl WlrLayerShellHandler for State {
    fn shell_state(&mut self) -> &mut WlrLayerShellState {
        &mut self.layer_shell_state
    }

    /// Camada nova (barra, fundo, menu). O lugar e o tamanho saem no primeiro
    /// commit dela (as âncoras só valem depois dele).
    fn new_layer_surface(&mut self, surface: LayerSurface, output: Option<WlOutput>, _layer: Layer, namespace: String) {
        // A mesma superfície pode ganhar outra camada depois de destruir a
        // primeira: aí ela volta a ser conferida como nova (sem âncora).
        if let Some(i) = self.dead_layers.iter().position(|s| s == surface.wl_surface()) {
            self.dead_layers.remove(i);
            with_states(surface.wl_surface(), |states| {
                states.cached_state.get::<LayerSurfaceCachedState>().pending().anchor = Anchor::empty();
            });
        }
        let o = self.output_for_layer(output.as_ref());
        if let Some(slot) = self.outputs.get(o) {
            slot.output.enter(surface.wl_surface());
        }
        let id = self.next_id;
        self.next_id += 1;
        let info = LayerInfo { surface, namespace, output: Some(o), committed: false, configure_again: false };
        self.windows.push(Win::new(id, Role::Layer(info)));
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
        self.dead_layers.retain(|s| s.is_alive());
        self.dead_layers.push(surface.wl_surface().clone());
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
        // Até ganhar um lugar, a janela "está" no primeiro monitor (o app usa a escala dele).
        if let Some(slot) = self.outputs.first() {
            slot.output.enter(surface.wl_surface());
        }
        let id = self.next_id;
        self.next_id += 1;
        self.windows.push(Win::new(id, Role::Toplevel(surface)));
    }

    fn toplevel_destroyed(&mut self, surface: ToplevelSurface) {
        self.remove_window(surface.wl_surface());
    }

    fn title_changed(&mut self, surface: ToplevelSurface) {
        let Some(win) = self.windows.iter().find(|w| w.toplevel() == Some(&surface)) else { return };
        if win.mapped {
            let (_, title) = win.names();
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
        // Sem pai ainda: é menu de uma camada, que chega em WlrLayerShellHandler::new_popup.
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
        // O menu de uma camada (da barra) leva o teclado mesmo sem o foco do hub.
        if self.windows[index].is_layer() {
            self.layer_focus = Some(self.windows[index].id);
        }
        self.refresh_keyboard_focus();
    }

    /// O app pediu para mudar o lugar do menu (ex.: a lista cresceu).
    fn reposition_request(&mut self, surface: PopupSurface, positioner: PositionerState, token: u32) {
        let Some((index, Some(pi))) = self.find(surface.wl_surface()) else { return };
        let output_size = self.windows[index].place.and_then(|(o, _)| self.outputs.get(o)).map(|slot| slot.size);
        let win = &mut self.windows[index];
        let parent = win.popups[pi].parent.clone();
        let geometry = positioner.get_unconstrained_geometry(win.popup_area(&parent, output_size));
        surface.with_pending_state(|state| {
            state.geometry = geometry;
            state.positioner = positioner;
        });
        win.popups[pi].pos = (geometry.loc.x, geometry.loc.y);
        win.dirty = win.mapped;
        win.out_dirty |= win.mapped;
        surface.send_repositioned(token);
        let _ = surface.send_configure();
    }

    /// O menu fechou: sai da imagem, e o teclado volta para quem tinha antes.
    fn popup_destroyed(&mut self, surface: PopupSurface) {
        let Some((index, Some(pi))) = self.find(surface.wl_surface()) else { return };
        let win = &mut self.windows[index];
        win.popups.remove(pi);
        win.dirty = win.mapped;
        win.out_dirty |= win.mapped;
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
