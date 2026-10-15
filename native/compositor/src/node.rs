//! O nó `HubCompositor` que a Godot enxerga.
//!
//! Só o `autoload/platform/app_compositor.gd` cria este nó. A interface é pequena
//! e não sabe nada de mundo, telão ou casa:
//! - `start(socket, layout, variant)`, `stop()` e `poll()` (a cada quadro);
//! - sinais `window_opened(id, app_id, title, pid)`, `window_closed(id)` e
//!   `title_changed(id, title)`;
//! - `get_texture(id)`: a imagem da janela, que só sobe quando muda;
//! - `resize(id, w, h)` e `close(id)`: o telão manda o tamanho e pede para fechar;
//! - `key`, `pointer_motion` e `pointer_button`: teclado e mouse para a janela.
//!
//! Não há laço de eventos separado: o `poll()` faz tudo sem esperar
//! (aceita apps novos, lê as mensagens, sobe as imagens e responde).
//! O compositor em si é o `Core` (wayland.rs); aqui só fica a parte da Godot.

use std::collections::HashMap;
use std::time::Instant;

use godot::classes::image::Format;
use godot::classes::{INode, Image, ImageTexture, Node};
use godot::prelude::*;

use smithay::backend::input::{ButtonState, KeyState};
use smithay::input::keyboard::{FilterResult, Keycode};
use smithay::input::pointer::{ButtonEvent, MotionEvent};
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::utils::SERIAL_COUNTER;

use crate::wayland::{toplevel_names, Core, Event};

/// A "superfície" (a área de desenho) da janela com esse id.
fn surface(core: &Core, id: i64) -> Option<WlSurface> {
    core.state.window(id).map(|w| w.toplevel.wl_surface().clone())
}

#[derive(GodotClass)]
#[class(base = Node, init)]
pub struct HubCompositor {
    base: Base<Node>,
    running: Option<Core>,
    /// A textura de cada janela (id → textura), criada na primeira imagem.
    textures: HashMap<i64, Gd<ImageTexture>>,
    /// Quanto tempo as subidas de textura levaram, somado (para a medida).
    upload_us_total: u128,
    upload_count: u64,
}

#[godot_api]
impl INode for HubCompositor {
    /// Saiu da árvore: desliga (os apps perdem a conexão e fecham).
    fn exit_tree(&mut self) {
        self.stop();
    }
}

#[godot_api]
impl HubCompositor {
    #[signal]
    fn window_opened(id: i64, app_id: GString, title: GString, pid: i64);

    #[signal]
    fn window_closed(id: i64);

    #[signal]
    fn title_changed(id: i64, title: GString);

    /// Abre o socket (ex.: "gamehub-0", dentro do XDG_RUNTIME_DIR) com o
    /// layout do teclado (ex.: "br", variante ""). Devolve false se falhar
    /// (o motivo vai para o log).
    #[func]
    fn start(&mut self, socket: GString, layout: GString, variant: GString) -> bool {
        self.stop();
        let started = Core::new(&layout.to_string(), &variant.to_string()).and_then(|mut core| {
            core.listen(&socket.to_string())?;
            Ok(core)
        });
        match started {
            Ok(core) => {
                self.running = Some(core);
                true
            }
            Err(e) => {
                godot_error!("Compositor: {e}");
                false
            }
        }
    }

    /// Desliga: fecha o socket, e os apps conectados perdem a conexão.
    #[func]
    fn stop(&mut self) {
        self.running = None;
        self.textures.clear();
    }

    #[func]
    fn is_running(&self) -> bool {
        self.running.is_some()
    }

    /// Chamado a cada quadro: aceita apps novos, processa as mensagens, sobe
    /// as imagens novas e avisa os apps que o quadro foi mostrado.
    #[func]
    fn poll(&mut self) {
        let Some(core) = self.running.as_mut() else { return };
        if let Err(e) = core.dispatch() {
            godot_error!("Compositor: {e}");
        }

        // As imagens que mudaram viram Image (a subida para a placa vem depois).
        let mut images: Vec<(i64, Gd<Image>)> = Vec::new();
        for win in core.state.windows.iter_mut() {
            if win.dirty && win.width() > 0 {
                win.dirty = false;
                let bytes = PackedByteArray::from(win.pixels.as_slice());
                if let Some(image) = Image::create_from_data(win.width(), win.height(), false, Format::RGBA8, &bytes) {
                    images.push((win.id, image));
                }
            }
        }
        // "Quadro mostrado": quem pediu pode desenhar o próximo.
        core.frame_done();
        let events = core.take_events();

        for (id, image) in images {
            self.upload(id, image);
        }

        // Os sinais saem "adiados" (no fim do quadro): quem ouve pode chamar o
        // compositor de volta sem bagunçar o poll().
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
                Event::TitleChanged(id, title) => {
                    let args =
                        ["title_changed".to_variant(), id.to_variant(), GString::from(title.as_str()).to_variant()];
                    self.base_mut().call_deferred("emit_signal", &args);
                }
            }
        }
    }

    /// A textura da janela (a mesma enquanto o tamanho não muda), ou null.
    #[func]
    fn get_texture(&self, id: i64) -> Option<Gd<ImageTexture>> {
        self.textures.get(&id).cloned()
    }

    /// A imagem atual da janela, na memória (ex.: para salvar em PNG num teste).
    #[func]
    fn get_image(&self, id: i64) -> Option<Gd<Image>> {
        let win = self.running.as_ref()?.state.window(id)?;
        if win.width() <= 0 {
            return None;
        }
        let bytes = PackedByteArray::from(win.pixels.as_slice());
        Image::create_from_data(win.width(), win.height(), false, Format::RGBA8, &bytes)
    }

    /// Pede ao app outro tamanho para a janela (o telão manda a resolução dele).
    /// A textura muda de tamanho quando a imagem nova chegar.
    #[func]
    fn resize(&mut self, id: i64, width: i32, height: i32) -> bool {
        self.running.as_mut().is_some_and(|core| core.resize(id, width, height))
    }

    /// Pede ao app para fechar a janela. Quando ele fechar, sai o `window_closed`.
    #[func]
    fn close(&mut self, id: i64) -> bool {
        self.running.as_mut().is_some_and(|core| core.close(id))
    }

    #[func]
    fn get_title(&self, id: i64) -> GString {
        self.running
            .as_ref()
            .and_then(|core| core.state.window(id))
            .map(|w| GString::from(toplevel_names(&w.toplevel).1.as_str()))
            .unwrap_or_default()
    }

    /// Uma tecla para a janela, com o código evdev do Linux (o ponto único
    /// do GDScript traduz a tecla da Godot). A janela ganha o foco do teclado.
    #[func]
    fn key(&mut self, id: i64, evdev: i32, pressed: bool) {
        let Some(core) = self.running.as_mut() else { return };
        let Some(surface) = surface(core, id) else { return };
        let keyboard = core.state.seat.get_keyboard().unwrap();
        if keyboard.current_focus().as_ref() != Some(&surface) {
            keyboard.set_focus(&mut core.state, Some(surface), SERIAL_COUNTER.next_serial());
        }
        let time = core.now_ms();
        let state = if pressed { KeyState::Pressed } else { KeyState::Released };
        // O xkb numera as teclas 8 acima do evdev (uma herança do X11).
        keyboard.input::<(), _>(
            &mut core.state,
            Keycode::new(evdev as u32 + 8),
            state,
            SERIAL_COUNTER.next_serial(),
            time,
            |_, _, _| FilterResult::Forward,
        );
        core.flush();
    }

    /// O ponteiro em (x, y), em pixels da janela (0, 0 é o canto de cima à esquerda).
    #[func]
    fn pointer_motion(&mut self, id: i64, x: f64, y: f64) {
        let Some(core) = self.running.as_mut() else { return };
        let Some(surface) = surface(core, id) else { return };
        let pointer = core.state.seat.get_pointer().unwrap();
        let event = MotionEvent { location: (x, y).into(), serial: SERIAL_COUNTER.next_serial(), time: core.now_ms() };
        pointer.motion(&mut core.state, Some((surface, (0.0, 0.0).into())), &event);
        pointer.frame(&mut core.state);
        core.flush();
    }

    /// Botão do mouse, com o código do Linux (0x110 esquerdo, 0x111 direito,
    /// 0x112 do meio). Vai para a janela onde o ponteiro está.
    #[func]
    fn pointer_button(&mut self, button: i32, pressed: bool) {
        let Some(core) = self.running.as_mut() else { return };
        let pointer = core.state.seat.get_pointer().unwrap();
        let state = if pressed { ButtonState::Pressed } else { ButtonState::Released };
        let event = ButtonEvent { serial: SERIAL_COUNTER.next_serial(), time: core.now_ms(), button: button as u32, state };
        pointer.button(&mut core.state, &event);
        pointer.frame(&mut core.state);
        core.flush();
    }

    /// Números para a medida: janelas abertas e o custo médio (em
    /// microssegundos) da cópia da imagem e da subida da textura.
    #[func]
    fn stats(&self) -> VarDictionary {
        let mut d = VarDictionary::new();
        let average = |total: u128, count: u64| if count > 0 { (total / count as u128) as i64 } else { 0 };
        if let Some(core) = self.running.as_ref() {
            let s = &core.state;
            d.set("janelas", s.windows.len() as i64);
            d.set("copias", s.copy_count as i64);
            d.set("copia_media_us", average(s.copy_us_total, s.copy_count));
        }
        d.set("subidas", self.upload_count as i64);
        d.set("subida_media_us", average(self.upload_us_total, self.upload_count));
        d
    }
}

impl HubCompositor {
    /// Sobe a imagem para a textura da janela: reaproveita a textura se o
    /// tamanho for o mesmo (mais barato), senão cria outra.
    fn upload(&mut self, id: i64, image: Gd<Image>) {
        let start = Instant::now();
        let same_size = self
            .textures
            .get(&id)
            .is_some_and(|t| t.get_width() == image.get_width() && t.get_height() == image.get_height());
        if same_size {
            self.textures.get_mut(&id).unwrap().update(&image);
        } else if let Some(texture) = ImageTexture::create_from_image(&image) {
            self.textures.insert(id, texture);
        }
        self.upload_us_total += start.elapsed().as_micros();
        self.upload_count += 1;
    }
}
