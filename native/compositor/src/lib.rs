//! O compositor Wayland do Game Hub (Fase 14, parte 2), como GDExtension.
//!
//! O hub vira um compositor "aninhado": abre um socket próprio
//! (`gamehub-0`), e os apps abertos pelo hub desenham as janelas aqui dentro
//! em vez de no Hyprland. Cada janela vira uma textura que o mundo 3D mostra
//! num telão, e o teclado e o mouse do telão voltam para o app.
//!
//! Só Linux. Bibliotecas: Smithay (o compositor, MIT) e godot-rust (a ponte
//! com a Godot, MPL-2.0). A ideia vem do Waylandcraft (GPL-3.0), mas nenhuma
//! linha de código dele foi copiada.
//!
//! - `pixels`: a conversão da imagem (testada com `cargo test`);
//! - `wayland`: o que os apps enxergam (janelas, teclado, mouse, monitor, camadas);
//! - `layers`: o lugar das camadas do layer-shell (a conta, testada à parte);
//! - `node`: o nó `HubCompositor` da Godot;
//! - `tests`: o compositor com um app de teste (só no `cargo test`).

use godot::prelude::*;

mod layers;
mod node;
mod pixels;
mod wayland;

#[cfg(test)]
mod tests;

/// A entrada da GDExtension (a Godot procura `gdext_rust_init`).
struct HubExtension;

#[gdextension]
unsafe impl ExtensionLibrary for HubExtension {}
