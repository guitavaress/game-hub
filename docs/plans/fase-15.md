# Fase 15: primeiro bioma, o bairro RPG na montanha

**Status:** aprovado em 2026-10-17
**Branch:** `fase-15`, criada a partir da `fase-linux` (em `bbbfa41`), no checkout principal (`~/git/game-hub`). A `fase-linux` ainda não foi para a `main`; quando for, `git rebase --onto main fase-linux fase-15`.

## Contexto
A V3 diz que "a biblioteca decide o mundo" ([ROADMAP › Fase 15](../ROADMAP.md#fase-15-primeiro-bioma-o-bairro-rpg-na-montanha)). Esta fase prova a ideia com um bioma só: o bairro RPG vira uma **montanha nevada**, no mesmo mapa da cidade.

Como fica no fim da fase:
- **Quarteirões do RPG:** continuam planos, mas com chão de neve, calçada de pedra, arcos de pedra no lugar dos prédios, pinheiros, rochas, neve caindo, névoa mais densa e vento.
- **A montanha:** logo atrás do bairro, fora da borda da cidade, sobe uma montanha. Uma trilha caminhável leva a um **mirante** com a torre do RPG.
- **A planta da cidade:** passa a ser em **setores**, uma fatia por bairro da praça até a borda, para que todo bairro tenha uma borda própria. Isso já serve aos biomas da Fase 16.

### Levantamento (só leitura)
- **Tudo assume chão plano em y = 0:**
  - o `Ground` é um `CSGBox3D` só (city.gd:860);
  - o metrô usa `FLOOR_Y` 0,085;
  - os pontos e decalques da rota estão em y = 0;
  - as poças e as manchas de luz dos postes são decalques baixos;
  - as faixas ficam em y = 0,03;
  - o teleporte não procura o chão.

  Nenhum código de produção usa terreno ou raio até o chão.
- **Como os bairros recebem os quarteirões:** o `_build_districts` (city.gd:349) dá a cada bairro o próximo trecho da lista de anéis do `CityLayout.block_cells`. O RPG vem logo depois de Esportes, perto da praça. Com 200 jogos falsos, são 57 jogos, ou 15 quarteirões.
- **O arco (`ArchShell`) não serve como está:**
  - **não mostra a capa** (nem tem o nó `Poster`);
  - com arcos, o `_build_landmark` sai cedo (`buildings.is_empty()`), e **a torre some**.
- **O clima não serve a uma cunha:** o `_build_weather` junta os quarteirões num `Rect2` só, que numa cunha cobriria os vizinhos. O `WeatherSpec` só conhece "garoa".
- **A névoa:** a global vem do `DayNight` (densidade por hora). Névoa por bairro, hoje, só com `FogVolume`, e o volumétrico fica desligado na Leve.
- **Assets que faltam:** pinheiro, textura de neve ou de rocha e passo na neve. Do Kenney Nature Kit só há um subconjunto (`tree_cone`, `rock_smallA`).
- **Já no projeto:**
  - o `wind_loop.wav` (gerado);
  - `PavingStones070`;
  - o pipeline de impostor (`tools/make_tree_impostor.gd` → `TreeImpostor`);
  - o Sky3D como opção de céu.
- **Testes:** testes que assumem prédio ou posição vão mudar (tabela em "Riscos"). O `check_profiles` exige `shell == "building"` e procura ids de bairro entre aspas em `worlds/`.

## Pronto quando
- **Montanha:** com a biblioteca de verdade e com 200 jogos falsos, o bairro RPG tem chão de neve, arcos com a capa do jogo, pinheiros, rochas, neve caindo e névoa. Atrás dele há uma montanha com trilha até um mirante com a torre do RPG, e dá para subir a pé.
- **Visual aprovado:** as capturas dos 3 pontos do brief (praça, pórtico do RPG e mirante), de dia e à noite, estão aprovadas pelo dono, e o pinheiro, as rochas e a neve combinam com a cidade PBR.
- **Setores:** todo bairro é uma área contígua, com o pórtico perto da praça e uma borda própria. O layout é determinístico: a mesma biblioteca dá a mesma cidade.
- **Os outros bairros:** só mudam de lugar. Jogos, variantes, cores e enfeites ficam iguais, comparados a um retrato gravado antes.
- **Nada quebra:** metrô, rota da busca, minimapa, mapa grande, bússola e título do bairro continuam funcionando, e nenhuma porta fica a mais de 180 m de uma estação.
- **Bioma como dado:** o bioma é dado (`BiomeSpec` em `profiles/biomes/`), e nenhum id de bairro ou de bioma aparece no código de `worlds/`.
- **Desempenho:**
  - **meta no desktop (Alta):** pior quadro da montagem ≤ 50 ms e sem queda visível ao subir a trilha. **Fica pendente para a trilha do desktop**;
  - **no notebook (Leve):** só antes e depois, com o mesmo código base, o mesmo dia e a mesma máquina, a 0 e a 200 jogos.
- A bateria inteira passa, com os testes novos.

## Decisões de arquitetura

### 1. Portais no chão plano, montanha atrás (decisão do dono, 2026-10-17)
Os quarteirões do RPG ficam em y = 0. Metrô, rota, decalques e faixas não mudam.

A montanha fica **fora do quadrado da cidade**, na orla entre a mureta e o horizonte (`CitySkyline`, 400 m). Uma trilha atravessa a mureta por um vão.

**Descartado:** portas em terraços. Tudo que assume y = 0 teria de mudar.

### 2. Layout em setores para todos os bairros (decisão do dono)
Entra `worlds/city/sector_layout.gd` (`SectorLayout`, uma função pura e estática). O `plan(counts, focus)` devolve `Array[DistrictSector]` (`district_sector.gd`, RefCounted), com estes campos:
- `blocks`: `[0]` é o quarteirão do pórtico;
- `territory`: os quarteirões mais as vagas da cunha;
- `wedge`: os ângulos da fatia;
- `border_cells()`: as células do território no anel de fora.

O algoritmo é determinístico, e os empates se decidem por x e depois z:
1. **Tamanho:** R é o menor anel com 4R² + 4R ≥ total de quarteirões.
2. **Primeiro a borda:** as 8R células do anel R, em ordem horária a partir do norte, são divididas em trechos contíguos. Cada bairro recebe pelo menos 1 célula, proporcional aos seus quarteirões (pelo maior resto). Assim **todo bairro tem borda**.
3. **Cunha:** são as células dos anéis 1 a R entre os limites angulares desses trechos.
4. **Crescimento na ordem do mundo:**
   - a semente é a célula livre da cunha mais perto da praça e da bissetriz;
   - a cunha cresce por vizinhança, primeiro pelos lados e depois pelos cantos, sempre de dentro para fora;
   - as vagas sobram perto da borda;
   - se faltar lugar, R += 1 (no máximo +2), e o teste conta isso.
5. **`focus`:** o primeiro bairro cujo bioma tem terreno de fundo gira o anel para que o meio da fatia dele caia no **norte**. Sem `focus`, o comportamento é o de hoje.

Mais regras:
- As vagas dos bairros sem bioma ganham só o chão do quarteirão. Isso se confirma pela captura na 15.4.
- O `CityLayout` fica com as contas da grade (mais `half_extent_rings`). O `block_cells` continua, porque o `check_scale` usa.

### 3. O bioma como dado: `BiomeSpec`
Arquivos novos em `profiles/`:
- `biome_spec.gd`;
- `terrain_spec.gd`;
- `scatter_spec.gd`;
- `biomes/montanha.tres`, gerado por `tools/gerar_bioma.gd`, como na 7.1.

O `DistrictProfile` ganha `@export var biome: BiomeSpec`. Vazio (null) quer dizer "cidade".

| Spec | Campos |
|---|---|
| `BiomeSpec` | `id`, `display_name`; chão (`ground_folder`, `ground_meters`, `ground_tint`, `path_folder`, `path_tint`, `footstep`, `cover_streets`); `shell`; `scatter: Array[ScatterSpec]`; `weather`; névoa (`fog_density_scale`, `fog_tint`, `fog_tint_amount`, `fog_height_density`, `fog_blend_meters`); `snow_cover` (neve por cima de rochas e arcos); `ambience_bed`; `backdrop: TerrainSpec` |
| `ScatterSpec` | `source`, `kind` ("impostor"/"mesh"), `density` por 100 m², `height_range`, `tint`, `collision_radius`, `in_town`, `on_backdrop` |
| `TerrainSpec` | `peak_height` 90, `lookout_height` 32, `max_grade` 0,15, `trail_width` 3, `apron` 8, `outer_radius` 370, `edge_fade_degrees` 10, `lookout_radius` 9, semente e frequência do ruído, `snow_folder`, `rock_folder`, `snow_slope` 0,75 |

Os valores que valem saem de ajudantes no `DistrictProfile` (`effective_shell()`, `effective_weather()`, `footstep()`), sem `match` por bioma.

### 4. Terreno por malha feita por código (decisão do dono)
**Descartado:** o Terrain3D, que põe ~27 MB de binários no histórico e derruba a primeira importação, inclusive na CI.

O ponto único fica em `worlds/city/biome/`. A cidade só conhece o `BackdropTerrain`; trocar pelo Terrain3D no futuro é escrever outro com a mesma API.

**Peças:**

| Arquivo | O que faz |
|---|---|
| `heightfield.gd` | as contas das alturas, puras |
| `terrain_mesh.gd` | `ArrayMesh` em pedaços de ~64 m |
| `mountain_trail.gd` | o traçado da trilha, puro |
| `terrain.gdshader` | o material do terreno |
| `backdrop_terrain.gd` | API: `setup(spec, sector, half)`, `height_at`, `get_trail_points`, `get_lookout`, `get_openings`, `get_zone_rects` |

**A altura:**
- é uma máscara (o ângulo dentro da cunha com degradê de ~10°, mais um `smoothstep` depois de uma faixa plana fora da borda e uma queda antes de 370 m) vezes uma rampa, mais um ruído "ridged" (`FastNoiseLite`, semente fixa);
- a base fica 0,3 m abaixo e escurece até a cor do "Outskirts", para não brigar com o plano de fora;
- os quadrados com a máscara zerada são descartados.

**A trilha:**
- sai do meio do lado de fora da célula de borda mais perto da bissetriz;
- vai reta por ~20 m e depois em zigue-zague, com as curvas suavizadas (Chaikin);
- tem rampa de no máximo 15%;
- o terreno é escavado para a altura da trilha;
- termina num mirante com disco plano.

**Colisão:**
- `HeightMapShape3D` **só no retângulo da trilha e do mirante**, com `footstep = "snow"`. Plano B: uma fita de `ConcavePolygonShape3D`;
- paredes invisíveis dos dois lados da trilha, com estacas de cerca para mostrar o limite;
- vão na mureta, na barreira e no corrimão;
- dois pilares e o texto "Trilha do Mirante" na entrada;
- um marco no `CityMap`.

**Desenho por qualidade:**
- o tamanho do quadrado da grade vem do `GraphicsQuality`: 4 m na Leve, 3 m na Média e 2 m na Alta;
- na Leve, o terreno não faz sombra e o shader não usa triplanar;
- o shader põe neve vista de cima e rocha triplanar onde a encosta é mais inclinada que `snow_slope`.

**Montagem:** um pedaço por `_keep_frame_light()`. Se a montanha não couber (`half > outer_radius − 80`), não há terreno, e a torre fica no quarteirão.

### 5. A torre do RPG vai para o mirante
O `DistrictLandmark` ganha `anchor: Transform3D`. Com âncora, ele ignora `buildings`. Isso resolve a torre que sumia com os arcos, e ela vira o objetivo visível da trilha. O letreiro do bairro continua sobre o 1º quarteirão.

### 6. Neve, névoa, passos e som
**Neve:**
- o `WeatherSpec.kind` ganha "neve";
- o `DistrictWeather` ganha uma tabelinha por tipo de clima, e nunca por bairro;
- `area: Rect2` vira `areas: Array[Rect2]`, que vem do `CityMap`.

**Zonas no `CityMap`:** `add_zone`, `zone_rects` e `zone_id_at`, que cobrem quarteirões, vagas e montanha. O `area_id_at` não muda, então minimapa e título continuam iguais.

**Névoa:**
- um nó novo, `worlds/city/biome/biome_atmosphere.gd`, calcula 10 vezes por segundo um peso de 0 a 1 pela distância até as zonas;
- o `DayNight` ganha `set_fog_overlay(peso, escala, cor, quanto)` e aplica a mistura na hora, sem piscar com o F8;
- é névoa de profundidade, então **funciona na Leve**.

**Passos:** "snow" no `player.gd` (`FOOTSTEP_SURFACES`). O corpo fino do setor (topo em y 0,02) e a colisão da trilha levam a marca.

**Som:** o `BiomeAtmosphere` toca o `wind_loop.wav` com o mesmo peso da névoa e abaixa ~6 dB o fundo da cidade.

### 7. A cidade só chama o bioma
O `worlds/city/biome/biome_builder.gd` faz:
- o chão do bioma;
- o setor coberto;
- as vagas;
- a casca;
- o terreno;
- as zonas;
- a âncora do marco.

O `city.gd` só ganha `if biome != null`. O `autoload/` só ganha números no `GraphicsQuality` (regra 1).

## Skills por subetapa (visual)
As skills do projeto (`.claude/skills/`) entram nas subetapas com estes papéis. Cada subetapa diz qual skill carregar antes de começar.

| Skill | Para que serve nesta fase |
|---|---|
| `create-game-assets` | **coerência**: a cidade é PBR (ambientCG); o pinheiro, as rochas e a neve não podem destoar. Brief de direção de arte, manifesto e uma amostra aprovada antes do resto (15.0) |
| `level-design` | a trilha e o mirante **em greybox** antes de enfeitar; medidas a partir do jogador; linhas de visão (a torre vista da praça e do pórtico); guiar pela luz, e não só por paredes (15.9 e 15.10) |
| `godot-shaders` / `shader-programming` | shader do terreno; **neve por cima** de rochas e arcos (pela normal do mundo); pinheiro balançando ao vento; flocos macios (15.7, 15.8 e 15.11) |
| `godot-3d-essentials` | névoa **com altura** (o pé do morro some na bruma e o pico aparece), neve sem estourar o branco (exposição e albedo) (15.12) |
| `audio-design` | vento em camadas, mais forte com a altura; abafar a cidade (15.12) |
| `revisao-do-hub` | revisão visual com capturas antes de fechar a fase (15.13) |

## Subetapas
- [ ] **15.0 Direção de arte, amostra e assets** (Opus · high na direção; Sonnet · low no download) · skill `create-game-assets`
  - **Faz, em três passos:**
    1. **Brief e manifesto** (`docs/design/bioma-montanha.md`):
       - paleta: neve fria, levemente azulada, com o néon roxo do RPG como única cor quente de luz;
       - materiais: PBR, como a cidade;
       - densidade de detalhe, escala dos pinheiros e das rochas em metros e a orçamento de texturas;
       - **3 pontos de vista de referência:** da praça, do pórtico do RPG e do mirante. Do mirante, a captura vem depois da 15.9.

       O brief vem com capturas de "antes" desses pontos, na pasta temporária.
    2. **Amostra:** pede permissão para baixar só **um pinheiro, uma rocha e a neve**. Monta uma cena de teste com um quarteirão RPG em greybox e captura nos três pontos (dia e noite). **O dono aprova a amostra.**
    3. **O resto:** com a amostra aprovada, pede permissão para o resto da família, baixa, importa, põe o `LICENSE` e o crédito no README.
  - **Lista candidata** (a confirmar nos sites, com nome e tamanho):
    - ambientCG: neve (ex.: Snow010A ou Snow006) e rocha (ex.: Rock035), 1K-JPG, ~3 a 5 MB cada;
    - pinheiro da Poly Haven: o glTF fica **fora do repositório** e vira atlas pelo `tools/make_tree_impostor.gd`, saindo em `assets/generated/pine_impostor.png` (~1 a 2 MB);
    - **rochas PBR da Poly Haven** (a versão mais leve), para combinar com a cidade. Plano B: `rock_large*` do Kenney Nature Kit, que tem cor chapada e pode destoar (a amostra decide);
    - `footstep_snow_000` a `004` do Kenney Impact Sounds.
  - Teste: o `check_textures` passa a contar as novas texturas (sai dos 22) e confere VRAM e mipmaps no atlas.
  - Commit: `Fase 15.0: direção de arte e assets do bioma montanha`
- [ ] **15.1 O bioma como dado, sem efeito** (Sonnet · medium)
  - Faz: entram `BiomeSpec`, `TerrainSpec`, `ScatterSpec`, o `montanha.tres` (pelo `tools/gerar_bioma.gd`), o campo `biome` e os ajudantes no `DistrictProfile`. O `rpg.tres` **ainda não** liga o bioma.
  - Teste: o `check_profiles` ganha a seção de biomas (carrega, ids únicos, pastas e sons existem) e a varredura de ids de bioma em `worlds/`.
  - Commit: `Fase 15.1: o bioma como dado (sem efeito)`
- [ ] **15.2 Retrato da planta e o plano por bairro** (Sonnet · medium)
  - Faz:
    - o `tools/retrato_planta.gd` grava `tests/fixtures/planta_atual.json`, com 6, 40 e 200 jogos falsos. O retrato tem, por bairro, os quarteirões, o pórtico, o letreiro e as estações; tem o `half`; e, por `app_id`, a casca, os andares e a parede;
    - o `_build_districts` passa a usar `DistrictSector`, vindo de `CityLayout.ring_plan(counts)`. É o comportamento de hoje, embrulhado.
  - Arquivos: `district_sector.gd` (novo), `city_layout.gd`, `city.gd`, o tool.
  - Teste: `check_planta.gd`, com tudo idêntico ao retrato.
  - Commit: `Fase 15.2: retrato da planta e o plano por bairro`
- [ ] **15.3 SectorLayout, a função pura** (Opus · high)
  - Arquivos: `worlds/city/sector_layout.gd` e `tests/check_sector_layout.gd`.
  - O teste roda os casos fixos ([1], [1,1,1,1], [1,2], 10 × [1], [30,1,…] e os 200 falsos) e 300 listas sorteadas com semente fixa.
  - O teste confere:
    - nenhuma célula repetida e a soma certa;
    - todo bairro 8-conexo;
    - o pórtico no menor anel do bairro;
    - todo território com borda;
    - o maior bairro chegando à borda;
    - as bissetrizes em ordem horária;
    - o resultado determinístico;
    - quantas vezes R cresceu.
  - O teste imprime o mapa ASCII dos 200 falsos.
  - Commit: `Fase 15.3: layout em setores (função pura)`
- [ ] **15.4 A cidade em setores** (Opus · high)
  - Faz:
    - liga o `SectorLayout` (`focus` ainda −1);
    - põe chão nas vagas;
    - o `CityMap` ganha as zonas;
    - o `DistrictWeather` passa a usar `areas`;
    - o `_build_weather` vai para depois de todos os bairros.
  - Arquivos: `city.gd`, `city_map.gd`, `district_weather.gd`, `city_decor.gd`.
  - Teste:
    - o `check_planta` passa a conferir "mesmos bairros, contagens e variantes; só o lugar mudou";
    - o `check_city_map` ganha a conferência de contiguidade;
    - ajustes no `check_weather` e no `check_scale`;
    - `check_metro` (180 m) e `check_gates`.
  - Manual: captura de cima com 200 falsos, na pasta temporária, nunca no repositório.
  - Commit: `Fase 15.4: bairros em setores da praça até a borda`
- [ ] **15.5 O arco mostra a capa** (Sonnet · medium)
  - Faz: o `ArchShell` ganha uma placa `Poster` com o hero do jogo (`GameArt`), e o filete acende na carga da porta.
  - Teste:
    - o `check_portal_shell` confere o arco com `Poster` e textura;
    - `check_variants`, `check_phase6_step1` e `check_phase3_cache` passam a filtrar `is CityBuilding`.
  - Commit: `Fase 15.5: o arco mostra a capa do jogo`
- [ ] **15.6 O bioma no chão** (Sonnet · medium)
  - Faz:
    - o `rpg.tres` liga o `montanha.tres`;
    - entra o `biome_builder.gd`: arcos, neve no miolo, calçada de pedra, setor coberto com colisão e `footstep = "snow"`, sem parques;
    - faixas e poças pulam as zonas do bioma;
    - "snow" no `player.gd`;
    - `focus` = o bairro com terreno de fundo.
  - Teste:
    - `check_biome.gd` (novo): só o bairro com bioma muda, há "snow" debaixo do jogador e não há faixa nem poça na zona;
    - o `check_footsteps` ganha a neve.
  - Commit: `Fase 15.6: chão de neve e arcos no bairro RPG`
- [ ] **15.7 Pinheiros e rochas** (Sonnet · medium) · skill `godot-shaders`
  - Faz:
    - o `TreeImpostor` e o shader passam a aceitar outro atlas e a escala da instância. Com escala 1, as árvores de hoje ficam iguais;
    - **pinheiro ao vento:** um balanço leve no vértice do impostor, mais forte na ponta e com fase por instância. Fica desligado nas árvores de hoje;
    - **neve por cima:** um material das rochas e dos arcos do bioma que mistura a textura de neve onde a normal do mundo aponta para cima (sem acúmulo dinâmico). O quanto vem do `BiomeSpec` (`snow_cover`);
    - entra o `biome/biome_scatter.gd`: pinheiros e rochas em MultiMesh, cilindros de colisão nos pinheiros da cidade;
    - nada vai na frente das portas, nas calçadas, nos postes, no pórtico ou na estação.
  - Teste: `check_trees` sem mudança; `check_biome` com 1 a 2 desenhos por tipo e nada na faixa da porta; `check_metro`.
  - Commit: `Fase 15.7: pinheiros e rochas no bairro RPG`
- [ ] **15.8 O núcleo do terreno** (Opus · high) **[paralela, janela 1]**
  - Arquivos novos: `heightfield.gd`, `terrain_mesh.gd`, `mountain_trail.gd`, `terrain.gdshader` e `tests/check_terrain.gd`.
  - O teste confere:
    - a mesma semente dá a mesma altura;
    - a altura é 0 dentro do quadrado e depois de `outer_radius`;
    - a trilha fica dentro da cunha, com rampa ≤ `max_grade`, e termina em `lookout_height`;
    - a escavação bate com a trilha (±5 cm);
    - não há quadrados mascarados;
    - o tempo de geração é impresso.
  - Commit: `Fase 15.8: núcleo do terreno (alturas, malha, trilha)`
- [ ] **15.9 A montanha atrás do bairro** (Opus · high) · skill `level-design`
  - Faz:
    - **primeiro**, um teste mínimo do `HeightMapShape3D` no Jolt (tamanho, escala e centro); se falhar, vai o plano B;
    - **greybox antes do visual:**
      - a trilha e o mirante com material cinza;
      - as medidas vêm do `player.gd` (velocidade, pulo de 4,8 m/s ≈ 1,2 m de altura): largura, rampa e altura das paredes;
      - capturas dos 3 pontos do brief: **a torre aparece da praça e do pórtico?** A entrada da trilha se vê da rua?
      - só depois entra o material de neve e rocha;
    - **guiar pela luz:** lampiões baixos ao longo da trilha (a cada ~15 m, acesos à noite pelo grupo `city_night`), além das estacas;
    - entra o `backdrop_terrain.gd`;
    - o vão na mureta, a colisão e as paredes da trilha;
    - os pilares e o marco no mapa;
    - as zonas da montanha.
  - Teste: `check_mountain_trail.gd`:
    - raio para baixo em 50 pontos bate com o visual (±5 cm);
    - teste de forma dos dois lados mostra parede;
    - existe só um vão;
    - o jogador sobe com entrada simulada até 10 m acima do chão;
    - com 600 falsos, a montanha some sem erro.
  - Commit: `Fase 15.9: montanha e trilha caminhável`
- [ ] **15.10 O mirante e a torre** (Sonnet · medium) · skill `level-design`
  - Faz:
    - plataforma de madeira (`footstep = "wood"`), cerca e banco;
    - `anchor` no `DistrictLandmark`; sem terreno, a torre fica no centro do 1º quarteirão;
    - **a vista é o prêmio:** o banco e a abertura da cerca ficam virados para a praça e a torre do relógio, e a captura do brief é feita dali.
  - Teste: o `check_landmarks` passa a aceitar o marco ancorado.
  - Commit: `Fase 15.10: o mirante com a torre do RPG`
- [ ] **15.11 Neve** (Sonnet · medium) **[paralela, janela 2]**
  - Arquivos: `weather_spec.gd`, `district_weather.gd` e `check_weather`. A paralela não mexe em `.tres`: a principal liga a neve no `montanha.tres` ao juntar.
  - Commit: `Fase 15.11: neve no clima dos bairros`
- [ ] **15.12 Névoa e vento do bioma** (Sonnet · medium) **[paralela, janela 2]** · skills `godot-3d-essentials` e `audio-design`
  - Faz:
    - a mistura da névoa inclui a **névoa com altura** do Environment (`fog_height`, `fog_height_density`): o pé do morro fica na bruma e o pico aparece. Funciona na Leve;
    - o vento fica em duas camadas: a de baixo, no bairro, e uma mais forte que cresce com a altura na trilha;
    - a neve não estoura o branco: albedo da neve ≤ 0,85, conferido por captura de dia com sol.
  - Arquivos: `day_night.gd` (`set_fog_overlay`), `biome/biome_atmosphere.gd` (novo), `check_daynight` e `check_biome_atmosphere.gd`.
  - O teste confere: peso 0 deixa tudo igual a hoje; dentro da zona o peso é 1; a transição é suave; o F8 não apaga a mistura.
  - A ligação ao `BiomeBuilder` entra ao juntar.
  - Commit: `Fase 15.12: névoa e vento do bioma`
- [ ] **15.13 Revisão visual** (Opus · high) · skill `revisao-do-hub`
  - Faz:
    - roda a revisão com as lentes `level-design`, `godot-3d-essentials`, `create-game-assets` e `audio-design`;
    - capturas nos 3 pontos do brief, de dia, no pôr do sol e à noite, com o céu de fotos e com o Sky3D, todas na pasta temporária;
    - entrega um relatório com impacto × esforço.
  - **O dono escolhe** o que entra. Os ajustes aprovados viram 15.13.1, 15.13.2… (cada um com commit); o resto vai para a Fase 16 ou para a trilha do desktop.
  - Commit: só os das 15.13.x.
- [ ] **15.14 Qualidade** (Sonnet · medium)
  - Faz: `GraphicsQuality.terrain_cell_meters` e `scatter_amount`; o terreno se refaz ao trocar a qualidade; sem sombra do terreno na Leve.
  - Teste: `check_graphics_quality`.
  - Commit: `Fase 15.14: terreno e enfeites por qualidade`
- [ ] **15.15 Medida e documentação** (Sonnet · medium)
  - Faz:
    - o `medir_desempenho` ganha `MEDIDA_MONTANHA` (sobe a trilha e gira no mirante);
    - no notebook (Leve), antes e depois lado a lado no mesmo dia, com um worktree da base da fase contra a ponta, a 0 e a 200 jogos;
    - a meta do desktop fica anotada como pendente na trilha do desktop;
    - README, ROADMAP e o mapa do CLAUDE.md (`worlds/city/biome/`, `profiles/biomes/`; trocar "addons/ (ainda vazio)").
  - Teste: `check_perf_tool`.
  - Commit: `Fase 15.15: medida e documentação`

### Trilhas (principal no checkout, paralela num git worktree)
| Janela | Principal | Paralela | Por que não brigam |
|---|---|---|---|
| 1 | 15.0 → 15.4 | 15.8 | a 15.8 só cria arquivos novos em `biome/` e `tests/` |
| 2 (15.4 e 15.8 juntas) | 15.5 → 15.7 | 15.11, depois 15.12 | a principal não mexe em `district_weather`, `weather_spec`, `day_night` nem nos `.tres` de clima |
| 3 | 15.9 → 15.10 → 15.13 (revisão) → 15.14 → 15.15 | nenhuma | tudo passa pelo `biome_builder` e pelo `city.gd` |

A paralela é criada com `git worktree add -b worktree/<nome> ~/git/game-hub_worktrees/<nome> fase-15`. Ela não marca o plano. A principal junta com `git merge --no-ff`, roda a bateria e marca `[x]`. O commit é feito com o e-mail noreply (`-c user.email=...`).

## Riscos
| Risco | Como perceber cedo | O que fazer |
|---|---|---|
| Cunha que não fecha numa biblioteca estranha | 15.3 conta quantas vezes R cresce | ajustar antes de ligar na cidade |
| Caminhadas mais longas nas cunhas | `check_metro` na 15.4 | subir o máximo de estações por bairro |
| `HeightMapShape3D` no Jolt | primeiro passo da 15.9 | fita de triângulos |
| Montanha sem espaço numa biblioteca enorme | 600 falsos na 15.9 | sem terreno; torre no quarteirão |
| Briga pelo mesmo plano no pé do morro | captura na 15.9 | base 0,3 m abaixo e escurecida |
| Névoa piscando com o relógio | `check_biome_atmosphere` com F8 | mistura dentro do `DayNight` |
| Tempo de montagem do terreno em GDScript | tempo impresso no `check_terrain` | um pedaço por quadro |
| Escala no impostor mudando as árvores de hoje | `check_trees` | escala 1 tem de dar o mesmo resultado |

Testes afetados:
- `check_weather`, `check_scale`, `check_metro`, `check_landmarks`, `check_variants`, `check_phase6_step1`, `check_phase3_cache`, `check_profiles`, `check_textures`, `check_footsteps`, `check_daynight` e `check_trees`;
- `check_gates`, `check_city_map`, `check_district_title`, `check_minimap` e `check_search` devem passar sem mudança.

## Fora do escopo
- Outros biomas, o bioma escolhido pelo `config.cfg` e o bioma que cresce com as horas (Fase 16).
- O Terrain3D.
- Neve acumulando com o tempo e pegadas. A "neve por cima" fixa, feita no shader, entra na 15.7.
- Andar livre pela montanha.
- Quarteirões em declive.
- A montanha no minimapa.
- Viagem rápida até o mirante.
- LOD automático.
- O Sky3D como céu padrão (decisão da trilha do desktop). A revisão da 15.13 compara os dois céus na montanha e leva o resultado para essa decisão.
- IK dos pés.

## Decisões tomadas durante a fase
- 2026-10-17: portais no chão plano com a montanha atrás; setores para todos os bairros; terreno por malha feita por código (dono, no planejamento).

## Checklist de teste manual (fim da fase)
1. **Abrir a cidade:** `~/.local/bin/godot --path . worlds/city/city.tscn`, com a biblioteca de verdade. Sair de casa (E na porta) e abrir o mapa (M).
   - **Deve acontecer:** cada bairro é uma fatia da praça até a borda, e o RPG fica ao norte.
2. **Entrar no bairro RPG.**
   - **Deve acontecer:** neve no chão e caindo, névoa mais densa, vento e passos de neve; arcos de pedra com a capa do jogo; pinheiros e rochas.
3. **Segurar E num arco.**
   - **Deve acontecer:** o jogo abre como antes e, ao fechar, você volta no mesmo arco.
4. **Subir a montanha:** seguir as placas "Trilha do Mirante", atravessar o vão da mureta e subir a pé.
   - **Deve acontecer:** não dá para sair da trilha. No alto ficam o mirante e a torre acesa, e a cidade aparece lá embaixo.
5. **Usar o metrô e a busca.** Abrir o metrô e viajar para outro bairro; na busca (Tab), escolher um jogo RPG e usar Shift+Enter.
   - **Deve acontecer:** a viagem e a rota funcionam, e a rota segue pelas ruas.
6. **Trocar a qualidade** (Esc > Opções > Leve/Alta).
   - **Deve acontecer:** a montanha se refaz e não some.
7. **Repetir com 200 jogos falsos:** `godot --path . -s tools/medir_desempenho.gd -- 200 leve 22`.
   - **Deve acontecer:** comparar os números com os de antes (só no notebook). A meta absoluta fica para a trilha do desktop.
