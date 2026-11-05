# Scripts do Blender (Fase 17.7.1)

Modelos da trilha da montanha feitos no **Blender 5.2 LTS**, só por script e sem abrir a janela. Cada script monta um modelo e escreve o `.glb` direto em `assets/models/trail/`. Rodar de novo refaz o mesmo modelo.

O Blender fica fora do repositório e só no desenvolvimento (no Windows, pelo winget: `BlenderFoundation.Blender`). O hub não precisa dele.

## Como rodar
Da raiz do repositório (no Git Bash; no PowerShell, ponha `&` antes do caminho entre aspas):

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/gerar_fogueira.py
```

Depois, abra o editor da Godot (ou rode `--headless --import`) para ela importar o `.glb` novo. Um caminho depois de `--` troca o arquivo de saída (ex.: `-- C:/temp/teste.glb`, para comparar sem mexer no repositório).

| Script | Gera | O que é | Tempo |
|---|---|---|---|
| `gerar_fogueira.py` | `campfire.glb` (410 KB) | o anel de pedras com fuligem, a cama de cinza, a lenha rachada queimada por dentro e a brasa | ~30 s |
| `gerar_terraco.py` | `camp_terrace.glb` (240 KB) | o chão de neve, as lajes da borda e um andar (1 m) do muro de pedra seca | ~5 s |
| `gerar_bancos.py` | `benches.glb` (155 KB) | os três bancos (da fogueira, o comprido e o curto da margem) | ~10 s |
| `gerar_monte_de_pedras.py` | `cairn.glb` (80 KB) | as lajes empilhadas, com neve em cima, e as pedrinhas do pé | ~3 s |

`comum.py` tem as peças que todos usam: a pedra (caixa arredondada, ondulada por ruído, lascada por cortes planos e com as quinas chanfradas), a tábua, a tora e a acha rachada, o material de madeira procedural (anéis, fibras, casca, quinas gastas, carvão), o "assar" desse material numa textura pequena (cor e relevo), a oclusão de ambiente (os cantos escuros) assada nas cores dos vértices e a exportação.

## Como o modelo chega na Godot
- **Uma malha por material**, com o nome do material (`stone`, `wood`, `snow`, `ash`, `embers`): cada uma vira um desenho. O `TrailModels` (`worlds/city/biome/trail_models.gd`) lê as malhas, e a fogueira e o `TrailDressing` juntam as peças por material, como na 17.7.
- **Pedra, neve e cinza** usam as texturas PBR do projeto (Rock058 e Snow010A, projetadas pelo mundo), multiplicadas pela **cor dos vértices** que o Blender assou: o tom de cada pedra, a fuligem e os cantos escuros.
- **Os bancos** usam a madeira da casa (`home_wood.gdshader`, compartilhada, sem textura nova): o veio de cada tábua vem do UV do modelo (em metros), e o tom de cada tábua e os cantos escuros, da cor dos vértices.
- **A lenha e a brasa** usam a **textura assada** que vem dentro do `campfire.glb` (JPEG de 512 e 256 px: casca, carvão e as rachas da brasa). A brasa tem uma textura de brilho, que a Godot acende à noite. Na importação, a Godot tira essas texturas para arquivos `campfire_*.jpg` ao lado.
- **Para o arquivo ficar pequeno:** sem tangentes (a Godot gera as mesmas), a cor dos vértices em 16 bits (gravada dividida por 1,6; o `TrailModels.VERTEX_GAIN` multiplica de volta) e o UV só onde ele é usado.
- As chamas e a luz do fogo continuam na Godot (`campfire_flame.gdshader` e a OmniLight do `Campfire`).
- Nenhum `.blend` entra no repositório: o script é a fonte.

## Licença
Estes scripts usam a API Python do Blender, que é **GPL**. Por isso esta pasta é **GPL-3.0** (o texto está no [`LICENSE`](LICENSE), copiado da instalação do Blender). Os `.glb` que eles geram são **nossos**, como o resto do repositório (**MIT**): a licença do Blender diz que o que se cria com ele é de quem cria.
