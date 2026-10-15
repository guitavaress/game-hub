# Spike da Fase 14.14 (semente)

Código do spike "um terminal num quadro", guardado como ponto de partida da 14.15. **Não é usado pelo hub** (a pasta `native/compositor/` tem `.gdignore`, então a Godot não a lê).

- `../src/lib.rs`: o compositor mínimo (Smithay 0.7.0 + godot-rust 0.5.5), classe `HubCompositor`.
- `hub.gdextension`: o arquivo que a Godot usa para carregar o `.so`.
- `teste_foot.gd`: sem janela. Abre o `foot` dentro do compositor, salva a imagem em PNG e digita `echo ação` + Enter.
- `teste_janela.gd`: com janela. Um quadro 3D com o app; teclado e mouse vão para ele; Shift + Esc fecha.

Como rodar (num projeto Godot à parte, fora do repositório):
1. `cargo build --release` nesta pasta (`native/compositor/`).
2. Crie uma pasta com um `project.godot` mínimo, copie o `hub.gdextension` e o `.so` (`target/release/libhub_compositor_spike.so`) para `bin/`, e escreva `res://hub.gdextension` em `.godot/extension_list.cfg`.
3. `godot --headless --path <pasta> -s teste_foot.gd` (com `SAIDA=<pasta das imagens>`) ou `godot --path <pasta> -s teste_janela.gd`.
