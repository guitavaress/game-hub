//! O nó `HubCompositor` que a Godot enxerga.
//!
//! Só o `autoload/platform/app_compositor.gd` cria este nó. A interface é pequena
//! e não sabe nada de mundo, telão ou casa:
//! - `start(socket, layout, variant)`, `stop()` e `poll()` (a cada quadro);
//! - sinais `window_opened(id, app_id, title, pid)`, `window_closed(id)` e
//!   `title_changed(id, title)`;
//! - `get_texture(id)`: a imagem da janela (com os menus por cima), que só sobe quando muda;
//! - `resize(id, w, h)` e `close(id)`: o telão manda o tamanho e pede para fechar;
//! - `focus`, `key`, `pointer_motion`, `pointer_leave`, `pointer_button` e
//!   `pointer_axis`: teclado e mouse para a janela.
//!
//! Não há laço de eventos separado: o `poll()` faz tudo sem esperar
//! (aceita apps novos, lê as mensagens, sobe as imagens e responde).
//! O compositor em si é o `Core` (wayland.rs); aqui só fica a parte da Godot.

use std::collections::HashMap;
use std::time::Instant;

use godot::classes::image::Format;
use godot::classes::{INode, Image, ImageTexture, Node};
use godot::prelude::*;

use crate::wayland::{Core, Event};

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
                // A janela com os menus por cima.
                let bytes = PackedByteArray::from(win.image());
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

    /// A imagem atual da janela, com os menus, na memória (ex.: para salvar em
    /// PNG num teste).
    #[func]
    fn get_image(&mut self, id: i64) -> Option<Gd<Image>> {
        let win = self.running.as_mut()?.state.windows.iter_mut().find(|w| w.id == id)?;
        if win.width() <= 0 {
            return None;
        }
        let bytes = PackedByteArray::from(win.image());
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
            .map(|w| GString::from(w.role.names().1.as_str()))
            .unwrap_or_default()
    }

    /// Dá o foco do teclado para a janela (0 ou negativo: nenhuma). A janela
    /// com foco desenha como "ativa"; tirar o foco solta as teclas apertadas.
    #[func]
    fn focus(&mut self, id: i64) {
        if let Some(core) = self.running.as_mut() {
            core.focus((id > 0).then_some(id));
        }
    }

    /// Uma tecla para a janela, com o código evdev do Linux (o ponto único
    /// do GDScript traduz a tecla da Godot). A janela ganha o foco do teclado.
    /// Não mande as repetições da Godot (echo): quem repete é o app.
    #[func]
    fn key(&mut self, id: i64, evdev: i32, pressed: bool) {
        if let (Some(core), Ok(evdev)) = (self.running.as_mut(), u32::try_from(evdev)) {
            core.key(id, evdev, pressed);
        }
    }

    /// O ponteiro em (x, y), em pixels da textura da janela (0, 0 é o canto
    /// de cima à esquerda).
    #[func]
    fn pointer_motion(&mut self, id: i64, x: f64, y: f64) {
        if let Some(core) = self.running.as_mut() {
            core.pointer_motion(id, x, y);
        }
    }

    /// O ponteiro saiu de cima da janela (a mira saiu do telão).
    #[func]
    fn pointer_leave(&mut self) {
        if let Some(core) = self.running.as_mut() {
            core.pointer_leave();
        }
    }

    /// Botão do mouse, com o código do Linux (0x110 esquerdo, 0x111 direito,
    /// 0x112 do meio). Vai para a janela onde o ponteiro está.
    #[func]
    fn pointer_button(&mut self, button: i32, pressed: bool) {
        if let (Some(core), Ok(button)) = (self.running.as_mut(), u32::try_from(button)) {
            core.pointer_button(button, pressed);
        }
    }

    /// Rolar na janela onde o ponteiro está (positivo: para baixo / para a
    /// direita). `wheel` true: rodinha, em "dentes" (1, -1...); false:
    /// touchpad, em pixels.
    #[func]
    fn pointer_axis(&mut self, dx: f64, dy: f64, wheel: bool) {
        if let Some(core) = self.running.as_mut() {
            core.pointer_axis(dx, dy, wheel);
        }
    }

    /// Números para a medida: janelas e menus abertos e o custo médio (em
    /// microssegundos) da cópia da imagem e da subida da textura.
    #[func]
    fn stats(&self) -> VarDictionary {
        let mut d = VarDictionary::new();
        let average = |total: u128, count: u64| if count > 0 { (total / count as u128) as i64 } else { 0 };
        if let Some(core) = self.running.as_ref() {
            let s = &core.state;
            d.set("janelas", s.windows.len() as i64);
            d.set("menus", s.windows.iter().map(|w| w.popups.len()).sum::<usize>() as i64);
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
