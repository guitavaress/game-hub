# Scripts do Blender (Fase 17.7.1; o mirante na 17.8)

Modelos da montanha e da casa feitos no **Blender 5.2 LTS**, só por script e sem abrir a janela. Cada script monta um modelo e escreve o `.glb` direto em `assets/models/<grupo>/`: `trail/` (a trilha), `lookout/` (o mirante) e `home/` (a cabana). Rodar de novo refaz o mesmo modelo.

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
| `gerar_deque.py` | `lookout/deck.glb` (50 KB) | as peças soltas do deque, que a Godot espalha e estica: 4 tábuas do piso, o poste, o corrimão, a tábua fina (régua de baixo e o X) e a viga | ~7 s |
| `gerar_abrigo.py` | `lookout/shelter.glb` (690 KB) | o abrigo: pilares, vigas, a tesoura da frente, o telhado de tábuas com neve, a parede do fundo, as meias-paredes, o banco de dentro, a vara da tapeçaria e os braços das lanternas | ~3 s |
| `gerar_lanterna.py` | `lookout/lantern.glb` (40 KB) | a lanterna de ferro com o vidro (a Godot acende o vidro e põe a luz) | ~2 s |
| `gerar_luneta.py` | `lookout/telescope.glb` (120 KB) | a luneta de latão: a base torneada com três pés, a coluna, o garfo e o tubo com a ocular | ~2 s |
| `gerar_poltrona.py` | `home/armchair.glb` (259 KiB) | armação Wood049, cinco volumes estofados, vivos do assento e encosto | ~5 s com prévias |
| `gerar_lareira.py` | `home/fireplace.glb` (228 KiB) | pedras aparelhadas, soleira, consolo Wood049, fundo de fuligem e grade de ferro | ~5 s com prévias |
| `gerar_arvore.py` | `trees/pine.glb` (795 KB), `trees/street_tree.glb` (449 KB) e `trees/forest_tree.glb` (764 KB) | 19.2: o pinheiro (abeto) de 10 m: tronco com raízes, verticilos de galhos e cartões de agulhas (a foto de um raminho feito de agulhas de verdade, com transparência). 19.3: a árvore de rua de 6 m (copa oval de folhas largas) e o pinheiro com agulhas finas e verde de abeto. 19.7: a árvore da floresta de 13 m (tronco alto, copa larga e irregular) | ~35 s cada; ~65 s com prévias |

`comum.py` tem as peças que todos usam (17.8: também `orientar`/`tabua_entre`, para pôr uma tábua de um ponto a outro, e `caixa`, `cilindro` e `tubo`, as peças de metal torneadas): a pedra (caixa arredondada, ondulada por ruído, lascada por cortes planos e com as quinas chanfradas), a tábua, a tora e a acha rachada, o material de madeira procedural (anéis, fibras, casca, quinas gastas, carvão), o "assar" desse material numa textura pequena (cor e relevo), a oclusão de ambiente (os cantos escuros) assada nas cores dos vértices e a exportação.

## Como o modelo chega na Godot
- **Uma malha por material**, com o nome do material (`stone`, `wood`, `snow`, `ash`, `embers`): cada uma vira um desenho. O `TrailModels` (`worlds/city/biome/trail_models.gd`) lê as malhas, e a fogueira e o `TrailDressing` juntam as peças por material, como na 17.7.
- **Pedra, neve e cinza** usam as texturas PBR do projeto (Rock058 e Snow010A, projetadas pelo mundo), multiplicadas pela **cor dos vértices** que o Blender assou: o tom de cada pedra, a fuligem e os cantos escuros.
- **A madeira** (desde a 17.8: os bancos, o deque, o abrigo) usa a **Wood049** da ambientCG (`assets/ambientcg/Wood049/`, CC0), uma só para todos: o veio de cada tábua vem do UV do modelo (em metros, o x ao longo da tábua), e o tom de cada tábua e os cantos escuros, da cor dos vértices. A Godot escurece e esquenta a cor por material (`TrailModels.wood`).
- **O latão e o ferro** (a luneta, as lanternas, as ferragens) são metal liso da Godot (`TrailModels.metal`), escurecido pela cor dos vértices. O vidro da lanterna acende à noite.
- **As peças do deque** saem soltas e a Godot as estica (`TrailModels.stretched`, que corrige as normais): o tamanho do deque depende do mirante (o raio, a torre, a trilha que chega).
- **A lenha e a brasa** usam a **textura assada** que vem dentro do `campfire.glb` (JPEG de 512 e 256 px: casca, carvão e as rachas da brasa). A brasa tem uma textura de brilho, que a Godot acende à noite. Na importação, a Godot tira essas texturas para arquivos `campfire_*.jpg` ao lado.
- **Para o arquivo ficar pequeno:** sem tangentes (a Godot gera as mesmas), a cor dos vértices em 16 bits (gravada dividida por 1,6; o `TrailModels.VERTEX_GAIN` multiplica de volta) e o UV só onde ele é usado.
- As chamas e a luz do fogo continuam na Godot (`campfire_flame.gdshader` e a OmniLight do `Campfire`).
- Nenhum `.blend` entra no repositório: o script é a fonte.

## Cabana (17.9.1b)

Os dois modelos são só forma: a integração na casa é da 17.9.2. O contrato completo (referencial, medidas, materiais e pontos do fogo/chaminé) está em [`assets/models/home/README.md`](../../assets/models/home/README.md).

Para gerar os modelos e as duas prévias de cada um (frente e 3/4, Eevee), no PowerShell:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python tools/blender/gerar_poltrona.py -- assets/models/home/armchair.glb C:/Projetos/game-hub-referencias/uau/depois-17.9.1b
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python tools/blender/gerar_lareira.py -- assets/models/home/fireplace.glb C:/Projetos/game-hub-referencias/uau/depois-17.9.1b
```

Sem os argumentos depois de `--`, gera só o GLB no caminho padrão. As prévias usam Wood049 e Rock058 já presentes no projeto; não entram no GLB. O tecido da prévia tem ruído fino no relevo para representar o tecido procedural da casa, sem criar arquivo de textura. Nenhum download é necessário.

O `comum.py` ganhou apenas funções novas: `ajustar_caixa`, `almofada`, `tabua_casa_entre`, `cordao` e `previa_casa`. Os móveis têm UV da madeira também nas bordas verticais, com o veio em metros. A densidade maior fica nas bordas do estofado para evitar a silhueta poligonal; não houve redução que sacrificasse essa forma. Ambos cabem no orçamento (300/800 KiB).

Depois de conferir que não há outra Godot de teste rodando, importe e teste:

```powershell
& 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& 'C:/Program Files/Git/bin/bash.exe' tests/run_tests.sh check_home_models check_textures
```

O teste mede as malhas importadas, uma superfície por material, UV/cor/normais, AABB com tolerância de 5 mm, raios no assento/encosto e na abertura da lareira, apoio do fogo e do lampião, orçamento e ausência de imagens/luzes/câmeras/animações no GLB.

## Licença
Estes scripts usam a API Python do Blender, que é **GPL**. Por isso esta pasta é **GPL-3.0** (o texto está no [`LICENSE`](LICENSE), copiado da instalação do Blender). Os `.glb` que eles geram são **nossos**, como o resto do repositório (**MIT**): a licença do Blender diz que o que se cria com ele é de quem cria.

## Árvores (19.2; 19.3)

`gerar_arvore.py` tem uma função por espécie: `pinheiro` (o abeto do bairro do RPG), `rua` (a árvore das floreiras e da praça, 19.3) e `floresta` (a do bioma da floresta, na Aventura, 19.7). Da raiz do repositório:

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/gerar_arvore.py -- pinheiro [saida.glb] [pasta das prévias]
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/gerar_arvore.py -- rua [saida.glb] [pasta das prévias]
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/gerar_arvore.py -- floresta [saida.glb] [pasta das prévias]
```

Sem argumentos, grava `assets/models/trees/pine.glb`; com `rua`, `assets/models/trees/street_tree.glb`; com `floresta`, `assets/models/trees/forest_tree.glb`. A pasta das prévias (opcional, fora do repositório) recebe duas vistas no Cycles (`<espécie>_perto.png` e `<espécie>_longe.png`), só para conferir a forma.

- **A árvore de rua (19.3):** um tronco curto (2 m) que abre em cinco galhos grossos e um "líder" no meio; cada galho dá ramos, e cada ramo, raminhos, até a casca de uma copa oval (um elipsoide de 2,5 m de raio). As folhas são cartões com a foto de um raminho de folhas largas (feito aqui, com folhas ovais, nervura e talinho; 512 px), nas pontas dos ramos e raminhos, virados para fora da copa. A casca é a do pinheiro em placas mais finas e marrom-acinzentada; o tronco cobre a textura inteira (2,4 m por volta), para os galhos, que usam faixas dela, não caírem num pedaço vazio.
- **A árvore da floresta (19.7):** uma folhosa alta de mata (como um carvalho crescido entre outras árvores), com as mesmas funções da árvore de rua e outra `Forma`: tronco alto e limpo (os galhos grossos saem de 3,8 a 6,5 m, e não de uma forquilha só), copa larga (4,3 m de raio) com "calombos" (a `Copa` com `ondas`: o raio muda com a direção, por um ruído), folhas menores e mais juntas num verde de mata mais escuro, e casca marrom mais funda. 13 m, 13,2 mil triângulos. A parametrização deixou a árvore de rua idêntica (o `.glb` regerado sai com os mesmos bytes).
- **O pinheiro corrigido (19.3):** a foto das agulhas passou a 1024 px, com agulhas de 3,8 mm (eram 7,5 mm: de perto, o raminho lembrava uma folha larga) e mais juntas; os tons são de abeto (verde-escuro puxado para o azul; na 19.2 saía saturado e claro de dia). Para caber no orçamento: o WEBP a 60 e os galhos curtos do alto com 3 lados (ficam cobertos pelas agulhas).

- **Duas malhas:** `bark` (tronco e galhos) e `leaves` (os cartões de agulhas). A origem é o pé do tronco, no chão; o pinheiro tem 10 m (a copa passa de 3 m de raio embaixo).
- **A casca** é o `material_madeira` do `comum.py`, só com o tipo casca, assado numa textura alta e estreita (256 × 1024: o UV dá a volta no tronco e sobe 5 m; o tronco de cima repete). Os galhos usam uma faixa dessa mesma textura.
- **As agulhas:** o script monta dois raminhos de abeto com agulhas de verdade (três níveis de ramos), fotografa de cima com fundo transparente (`comum.foto_de_cima`, só emissão: a foto guarda a cor, a luz é da Godot) e espalha a cor por baixo do transparente (`comum.sangrar_cor`). Cada cartão é um retângulo 2:1 com uma das duas metades da foto; o do meio e o de baixo são dobrados (a ponta cai).
- **A cor dos vértices** das folhas escurece o miolo e o andar de baixo da copa (a sombra de dentro). Vai para o glTF sem o ganho (`GANHO`) das pedras.
- **WEBP:** o `comum.exportar_com_alfa` grava as texturas em WEBP (o JPEG do `exportar` perde a transparência das agulhas). A Godot lê o `EXT_texture_webp` e tira as texturas para `pine_*.webp` ao lado.
- **Na Godot:** as LODs automáticas ficam desligadas no `.glb.import` de cada árvore (a simplificação abriria buracos nos cartões): numa espécie nova, troque `meshes/generate_lods` para `false` depois da primeira importação. Quem desenha é o `TreeModel` (`worlds/city/tree_model.gd`): o modelo perto, a impostora do mesmo modelo longe. O atlas de longe de `<nome>.glb` é sempre `assets/generated/<nome>_impostor.png`. Depois de mudar um modelo, refaça o atlas dele (com janela):

```
"C:/Godot/Godot_v4.7.2-stable_win64_console.exe" --path . -s res://tools/make_tree_impostor.gd -- res://assets/models/trees/pine.glb res://assets/generated/pine_impostor.png
"C:/Godot/Godot_v4.7.2-stable_win64_console.exe" --path . -s res://tools/make_tree_impostor.gd -- res://assets/models/trees/street_tree.glb res://assets/generated/street_tree_impostor.png
"C:/Godot/Godot_v4.7.2-stable_win64_console.exe" --path . -s res://tools/make_tree_impostor.gd -- res://assets/models/trees/forest_tree.glb res://assets/generated/forest_tree_impostor.png
```

O `comum.py` ganhou só funções novas: `assar_textura_retangular`, `foto_de_cima`, `sangrar_cor` e `exportar_com_alfa`.
