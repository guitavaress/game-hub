# Fase 15: primeiro bioma, o bairro RPG na montanha

**Status:** em andamento — 15.0, 15.2 e 15.8 concluídas; **15.1 implementada e testada, aguardando checklist manual**. 15.2 executada a pedido do dono em 2026-10-24; próxima implementação: 15.3. Escopo aprovado em 2026-10-17.
**Branch:** `fase-15`, no desktop Windows (`C:\Projetos\game-hub`); ponta de implementação conferida: `ed834cd`. Criada de `bbbfa41`, recebeu a `fase-linux` em `0a93c4a` e o núcleo do terreno em `b372efa`. A `main` local (`940dedf`) já é ancestral desta branch; a antiga instrução de rebase não se aplica. Merge na `main` só com pedido do dono.
**Execução:** OpenCode v2.1.3 + modelos OpenAI; comandos e política em [../OPENCODE.md](../OPENCODE.md). O trabalho concluído pelo Claude permanece registrado com seus commits.

## Ponto de retomada histórico (2026-10-23, anterior à 15.1/15.2)

| Entrega | Evidência | Situação |
|---|---|---|
| 15.0: brief, amostra e família de assets | `a386560`, `ed834cd`, [brief](../design/bioma-montanha.md) | Concluída; aprovação do dono registrada em 2026-10-19 |
| 15.8: alturas, trilha, malha e shader | `729edf0`, integrado em `b372efa`; `tests/check_terrain.gd` | Concluída como núcleo isolado |
| 15.1–15.7 e 15.9–15.15 | Checklists abaixo | Pendentes; não há `BiomeSpec`, `BiomeBuilder` nem ligação do terreno em `city.gd` |

São **2 de 16 subetapas de primeiro nível**; isso não representa percentual de esforço ou de experiência jogável. A montanha ainda não aparece no hub normal. O próximo commit de implementação é a **15.1**, mantendo `rpg.tres` sem bioma até a 15.6.

### Validação de retomada

- **Histórico:** o commit `ed834cd` registra 76/76 testes no Windows em 2026-10-19.
- **Teste específico reexecutado em 2026-10-23:** `check_terrain.gd` terminou com `RESULTADO: TUDO OK`. Exercita cinco geometrias e grades de 4/3/2 m. No caso de 200 falsos, a grade de 2 m levou ~171 ms no total e ~8,9 ms no chunk mais lento. São tempos headless do núcleo, não FPS nem aceitação da montagem completa.
- **Bateria completa da retomada (2026-10-23, Windows, Godot 4.7.2):** **76/76 scripts aprovados**, `RESULTADO GERAL: TUDO OK`, saída 0, usando `& 'C:\Program Files\Git\bin\bash.exe' tests/run_tests.sh`. Inclui `check_terrain`, `check_textures`, perfis, mapas, metrô, portais e backends Windows. Rust/compositor nativo pulado por ser Windows; testes do backend Linux com fixtures não equivalem a uma execução real no Linux. Log local: `C:\Users\gui_t\AppData\Local\Temp\opencode\fase-15-bateria-2026-10-23.log`.
- **Infra OpenCode:** JSON carregado pelo serviço v2.1.3 na localização `C:\Projetos\game-hub`; API confirmou modelos/variantes dos agentes, registro dos seis comandos e configuração de revisão em sessão filha. Referências de modelos conferidas no catálogo. Isso valida configuração/disponibilidade, não um benchmark ou execução de prompts em todos os modelos.
- **Visual, colisão jogável, desempenho com janela e Linux:** não revalidados nesta retomada. Entram nos pontos de aceitação abaixo, depois da integração.

### Execução e modelos por subetapa

IDs e variantes conferidos no catálogo local em 2026-10-23. A distribuição é inicial; não há comparação medida de preço, velocidade ou qualidade entre os modelos. Use os resultados das primeiras subetapas para ajustar.

| Etapas/papel | Modelo e esforço | Entrada pelo OpenCode |
|---|---|---|
| Planejamento de qualquer etapa | `openai/gpt-6-astra#high` | `/fase15-planejar <etapa>` |
| 15.1, 15.2, 15.5, 15.6, 15.10, 15.11, 15.14 e medição da 15.15 | `openai/gpt-6-astra#medium` | `/fase15-passo <etapa>` |
| 15.3, 15.4, 15.7, 15.9 e 15.12 | `openai/gpt-6-astra#high` | `/fase15-dificil <etapa>` |
| Revisões de 15.3/15.4, 15.9/15.10 e 15.13 | `openai/gpt-6.1-sol#high` | `/fase15-revisar <escopo>`; principal fornece diff, logs e capturas |
| Levantamento delimitado, se delegado | `openai/gpt-6-luna#low` | `explore`, com arquivos/pergunta explícitos |
| Texto mecânico e execução/relato de testes | `openai/gpt-5.3-codex-spark#low` | `/fase15-docs <ajuste>` e `/fase15-testes [testes]` |

Sol revisa; a principal coordena as capturas e faz os ajustes aprovados. Spark relata falhas, mas a investigação técnica volta ao Astra. Não usar vários implementadores sobre `city.gd`, `BiomeBuilder` ou o plano ao mesmo tempo. O modo Plan propõe; Build grava decisões aprovadas no plano versionado.

## Contexto
A V3 diz que "a biblioteca decide o mundo" ([ROADMAP › Fase 15](../ROADMAP.md#fase-15-primeiro-bioma-o-bairro-rpg-na-montanha)). Esta fase prova a ideia com um bioma só: o bairro RPG vira uma **montanha nevada**, no mesmo mapa da cidade.

Como fica no fim da fase:
- **Quarteirões do RPG:** continuam planos, mas com chão de neve, calçada de pedra, arcos de pedra no lugar dos prédios, pinheiros, rochas, neve caindo, névoa mais densa e vento.
- **A montanha:** logo atrás do bairro, fora da borda da cidade, sobe uma montanha. Uma trilha caminhável leva a um **mirante** com a torre do RPG.
- **A planta da cidade:** passa a ser em **setores**, uma fatia por bairro da praça até a borda, para que todo bairro tenha uma borda própria. Isso já serve aos biomas da Fase 16.

### Levantamento original (2026-10-17, referências de linha daquela revisão)
- **Tudo assume chão plano em y = 0:**
  - o `Ground` é um `CSGBox3D` só (city.gd:860);
  - o metrô usa `FLOOR_Y` 0,085;
  - os pontos e decalques da rota estão em y = 0;
  - as poças e as manchas de luz dos postes são decalques baixos;
  - as faixas ficam em y = 0,03;
  - o teleporte não procura o chão.

  A cidade ainda não usa o núcleo isolado entregue na 15.8.
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
  - **meta no desktop (Alta):** pior quadro da montagem ≤ 50 ms e sem queda visível ao subir a trilha. Como a execução agora está no desktop, medir na 15.15; se faltar a medida, registrar a pendência explicitamente na trilha do desktop;
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
- [x] **15.0 Direção de arte, amostra e assets** — Claude, concluída em `ed834cd` (amostra inicial em `a386560`) · skill `create-game-assets`
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
  - Teste: o `check_textures` já conta 32 texturas (27 ambientCG, 2 atlas e 3 da rocha) e confere compressão VRAM e mipmaps.
  - Commit: `Fase 15.0: direção de arte e assets do bioma montanha`
- [ ] **15.1 O bioma como dado, sem efeito** (Astra · medium)
  - **Implementada em 2026-10-24:** testes direcionados e bateria Windows aprovados (76/76). Checkbox aguarda a conferência manual abaixo. Log: `C:\Users\gui_t\AppData\Local\Temp\opencode\fase-15-1-2026-10-24.log`. Rust pulado no Windows.
  - Faz: entram `BiomeSpec`, `TerrainSpec`, `ScatterSpec`, o `montanha.tres` (pelo `tools/gerar_bioma.gd`), o campo `biome` e os ajudantes no `DistrictProfile`. O `rpg.tres` **ainda não** liga o bioma.
  - Teste: o `check_profiles` ganha a seção de biomas (carrega, ids únicos, pastas e sons existem) e a varredura de ids de bioma em `worlds/`.
  - Contrato: alinhar nomes e valores do `TerrainSpec` a `Heightfield.SPEC_FIELDS`; testar `apply_spec` com o Resource real. Preservar o comportamento de perfis com `biome == null`. A neve só é ativada no perfil ao integrar a 15.11.
  - Detalhamento aprovado em 2026-10-24: `ground_normal_strength` registra o relevo 1,6 aprovado e `walkable_clearance` registra os 6 m de afastamento dos pinheiros. Scatter separado para bairro e montanha, com faixas de altura próprias. Pastas de materiais relativas a `assets/ambientcg/`; origens do scatter são caminhos `res://`.
  - Contratos dos ajudantes: casca vazia e clima null herdam o bairro; passos vazios usam `concrete`. Consultas não modificam os Resources compartilhados. `weather` da montanha permanece null até 15.11; todos os bairros permanecem com `biome == null` até 15.6.
  - Arquivos: três Resources em `profiles/`, `profiles/biomes/montanha.tres`, `tools/gerar_bioma.gd`, `profiles/district_profile.gd`, `tests/check_profiles.gd` e `tests/check_terrain.gd`.
  - Testes: carregar assets com os tipos corretos, IDs únicos, intervalos de scatter, herança/precedência dos ajudantes e todos os dez campos de terreno com valores reais e diferentes dos padrões (cópia isolada). Manter o retrato histórico dos bairros e varrer IDs de bioma em `worlds/`.
  - Manual: abrir `montanha.tres` no Inspector e conferir sub-recursos; conferir Biome vazio no RPG; F6 em `worlds/city/city.tscn`, E para sair e M para abrir o mapa, com o comportamento atual preservado.
  - Commit: `Fase 15.1: o bioma como dado (sem efeito)`
- [x] **15.2 Retrato da planta e o plano por bairro** (Astra · medium)
  - Implementação em 2026-10-24, base `158aec0`: retrato gravado **antes** de alterar `_build_districts`; compara 6, 40 e 200 jogos, inclusive transformações dos prédios. IDs inventados fixos pelo argumento opcional `fixed_ids` de `FakeLibrary`, sem depender das capas da máquina. Captura compartilhada em `tests/planta_snapshot.gd`; gerador recusa sobrescrever o JSON.
  - `DistrictSector` guarda blocos, território e limites da cunha (ainda zerados nos anéis). `ring_plan` recebe contagens de quarteirões, preserva entradas vazias e a ordem original; território é uma cópia independente dos blocos. `border_cells` permite informar o anel externo; sem argumento usa o maior anel do próprio território.
  - Evidência inicial: `check_planta` aprovado. A execução restrita não encontrou jogos reais e `check_city_map` falhou; bateria interrompida antes de iniciar novamente no ambiente normal do Windows. Logs temporários: `fase15-2-retrato.log`, `fase15-2-direcionados.log` e `fase15-2-bateria.log`.
  - Validação final em 2026-10-24: `& 'C:\Program Files\Git\bin\bash.exe' tests/run_tests.sh`, Windows / Godot 4.7.2, **77/77 aprovados**, `RESULTADO GERAL: TUDO OK`, saída 0. Inclui planta, mapa, metrô, variantes e escala. Rust/compositor nativo pulado no Windows. Log: `C:\Users\gui_t\AppData\Local\Temp\fase15-2-bateria.log`. Retrato preservado com SHA-256 `D830E8245FBEBA58EA015F61AED5F69E14CCA7D955244E3208747F4F4CF29178`.
  - Manual sugerido: F6 em `worlds/city/city.tscn`, E para sair de casa, M para conferir o mapa e uma viagem de metrô. Esperado: bairros, prédios, letreiros e estações nas posições anteriores. Não há mudança visual intencional nesta etapa; a validação manual da 15.1 permanece pendente.
  - Faz:
    - o `tools/retrato_planta.gd` grava `tests/fixtures/planta_atual.json`, com 6, 40 e 200 jogos falsos. O retrato tem, por bairro, os quarteirões, o pórtico, o letreiro e as estações; tem o `half`; e, por `app_id`, a casca, os andares e a parede;
    - o `_build_districts` passa a usar `DistrictSector`, vindo de `CityLayout.ring_plan(counts)`. É o comportamento de hoje, embrulhado.
  - Arquivos: `district_sector.gd` (novo), `city_layout.gd`, `city.gd`, o tool.
  - Teste: `check_planta.gd`, com tudo idêntico ao retrato.
  - Sequência: gravar o retrato **antes** de mudar `_build_districts`; não regenerá-lo para acomodar regressões. Base visual/de desempenho pré-integração: `ed834cd`.
  - Commit: `Fase 15.2: retrato da planta e o plano por bairro`
- [ ] **15.3 SectorLayout, a função pura** (Astra · high; revisão Sol · high)
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
- [ ] **15.4 A cidade em setores** (Astra · high; revisão Sol · high)
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
- [ ] **15.5 O arco mostra a capa** (Astra · medium)
  - Faz: o `ArchShell` ganha uma placa `Poster` com o hero do jogo (`GameArt`), e o filete acende na carga da porta.
  - Teste:
    - o `check_portal_shell` confere o arco com `Poster` e textura;
    - `check_variants`, `check_phase6_step1` e `check_phase3_cache` passam a filtrar `is CityBuilding`.
  - Commit: `Fase 15.5: o arco mostra a capa do jogo`
- [ ] **15.6 O bioma no chão** (Astra · medium)
  - Faz:
    - o `rpg.tres` liga o `montanha.tres`;
    - entra o `biome_builder.gd`: arcos, neve no miolo, calçada de pedra, setor coberto com colisão e `footstep = "snow"`, sem parques;
    - faixas e poças pulam as zonas do bioma;
    - "snow" no `player.gd`;
    - `focus` = o bairro com terreno de fundo.
  - Teste:
     - `check_biome.gd` (novo): só o bairro com bioma muda, há "snow" debaixo do jogador e não há faixa nem poça na zona;
     - o `check_footsteps` ganha a neve.
  - Integração gradual: ligar chão, casca e passos nesta etapa; clima de neve e atmosfera só depois de juntar 15.11/15.12. Não referenciar classes ainda ausentes da trilha principal.
  - Commit: `Fase 15.6: chão de neve e arcos no bairro RPG`
- [ ] **15.7 Pinheiros e rochas** (Astra · high) · skill `godot-shaders`
  - Faz:
    - o `TreeImpostor` e o shader passam a aceitar outro atlas e a escala da instância. Com escala 1, as árvores de hoje ficam iguais;
    - **pinheiro ao vento:** um balanço leve no vértice do impostor, mais forte na ponta e com fase por instância. Fica desligado nas árvores de hoje;
    - **neve por cima:** um material das rochas e dos arcos do bioma que mistura a textura de neve onde a normal do mundo aponta para cima (sem acúmulo dinâmico). O quanto vem do `BiomeSpec` (`snow_cover`);
    - entra o `biome/biome_scatter.gd`: pinheiros e rochas em MultiMesh, cilindros de colisão nos pinheiros da cidade;
     - nada vai na frente das portas, nas calçadas, nos postes, no pórtico ou na estação.
     - respeitar a amostra aprovada: pinheiros a pelo menos **6 m das áreas caminháveis**, incluindo a trilha; densidade e exclusões são dados/contratos do scatter.
  - Teste: `check_trees` sem mudança; `check_biome` com 1 a 2 desenhos por tipo e nada na faixa da porta; `check_metro`.
  - Commit: `Fase 15.7: pinheiros e rochas no bairro RPG`
- [x] **15.8 O núcleo do terreno** (Claude Opus, trilha paralela já integrada) — `729edf0`, junta em `b372efa`
  - Arquivos novos: `heightfield.gd`, `terrain_mesh.gd`, `mountain_trail.gd`, `terrain.gdshader` e `tests/check_terrain.gd`.
  - O teste confere:
    - a mesma semente dá a mesma altura;
    - a altura é 0 dentro do quadrado e depois de `outer_radius`;
    - a trilha fica dentro da cunha, com rampa ≤ `max_grade`, e termina em `lookout_height`;
    - a escavação bate com a trilha (±5 cm);
    - não há quadrados mascarados;
    - o tempo de geração é impresso.
  - Commit: `Fase 15.8: núcleo do terreno (alturas, malha, trilha)`
- [ ] **15.9 A montanha atrás do bairro** (Astra · high; revisão Sol · high) · skill `level-design`
  - Pré-requisitos: 15.1–15.8 e integração da janela 2. Dividir a execução em sessões/commits menores: **15.9.1** prova de colisão Jolt e greybox; **15.9.2** `BackdropTerrain`, vão e zonas; **15.9.3** percurso simulado, limites, sinalização e material. Marcar a 15.9 só quando todos os critérios abaixo passarem.
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
     - comparar a colisão com a **interpolação dos triângulos efetivamente desenhados** nas grades de 4, 3 e 2 m, não apenas com `height_at`: a trilha de 3 m pode ser mais estreita que uma célula;
    - teste de forma dos dois lados mostra parede;
    - existe só um vão;
    - o jogador sobe com entrada simulada até 10 m acima do chão;
    - com 600 falsos, a montanha some sem erro.
  - Commit: `Fase 15.9: montanha e trilha caminhável`
- [ ] **15.10 O mirante e a torre** (Astra · medium; revisão Sol · high) · skill `level-design`
  - Faz:
    - plataforma de madeira (`footstep = "wood"`), cerca e banco;
    - `anchor` no `DistrictLandmark`; sem terreno, a torre fica no centro do 1º quarteirão;
    - **a vista é o prêmio:** o banco e a abertura da cerca ficam virados para a praça e a torre do relógio, e a captura do brief é feita dali.
  - Teste: o `check_landmarks` passa a aceitar o marco ancorado.
  - Commit: `Fase 15.10: o mirante com a torre do RPG`
- [ ] **15.11 Neve** (Astra · medium) **[paralela, janela 2]**
  - Arquivos: `weather_spec.gd`, `district_weather.gd` e `check_weather`. A paralela não mexe em `.tres`: a principal liga a neve no `montanha.tres` ao juntar.
  - Commit: `Fase 15.11: neve no clima dos bairros`
- [ ] **15.12 Névoa e vento do bioma** (Astra · high) **[paralela, janela 2]** · skills `godot-3d-essentials` e `audio-design`
  - Faz:
    - a mistura da névoa inclui a **névoa com altura** do Environment (`fog_height`, `fog_height_density`): o pé do morro fica na bruma e o pico aparece. Funciona na Leve;
    - o vento fica em duas camadas: a de baixo, no bairro, e uma mais forte que cresce com a altura na trilha;
    - a neve não estoura o branco: albedo da neve ≤ 0,85, conferido por captura de dia com sol.
  - Arquivos: `day_night.gd` (`set_fog_overlay`), `biome/biome_atmosphere.gd` (novo), `check_daynight` e `check_biome_atmosphere.gd`.
  - O teste confere: peso 0 deixa tudo igual a hoje; dentro da zona o peso é 1; a transição é suave; o F8 não apaga a mistura.
  - A ligação ao `BiomeBuilder` entra ao juntar.
  - Commit: `Fase 15.12: névoa e vento do bioma`
- [ ] **15.13 Revisão visual** (Sol · high; capturas e coordenação pela principal) · skill `revisao-do-hub`
  - Executar **depois da 15.14**, para revisar a versão final nas qualidades Leve e Alta. A numeração foi preservada para manter as referências existentes.
  - Faz:
    - roda a revisão com as lentes `level-design`, `godot-3d-essentials`, `create-game-assets` e `audio-design`;
    - capturas nos 3 pontos do brief, de dia, no pôr do sol e à noite, com o céu de fotos e com o Sky3D, todas na pasta temporária;
    - entrega um relatório com impacto × esforço.
  - **O dono escolhe** o que entra. Os ajustes aprovados viram 15.13.1, 15.13.2… (cada um com commit); o resto vai para a Fase 16 ou para a trilha do desktop.
  - Commit: só os das 15.13.x.
- [ ] **15.14 Qualidade** (Astra · medium)
  - Faz: `GraphicsQuality.terrain_cell_meters` e `scatter_amount`; o terreno se refaz ao trocar a qualidade; sem sombra do terreno na Leve.
  - Teste: `check_graphics_quality`.
  - Commit: `Fase 15.14: terreno e enfeites por qualidade`
- [ ] **15.15 Medida e documentação** (Astra · medium nas medidas; Spark · low no texto mecânico)
  - Faz:
    - o `medir_desempenho` ganha `MEDIDA_MONTANHA` (sobe a trilha e gira no mirante);
     - no desktop (Alta), medir com janela a base pré-integração `ed834cd` e a ponta, no mesmo dia/máquina, a 0 e 200 jogos; registrar montagem (pior quadro ≤ 50 ms), caminhada, subida e giro no mirante, resolução, qualidade, hora e hardware;
     - medir `MEDIDA_MONTANHA` na ponta; na base, sem montanha integrada, comparar só trajetos e métricas comuns. Não atribuir à base uma subida inexistente;
     - no notebook (Leve), repetir antes/depois a 0 e 200 jogos quando disponível; registrar separadamente se não for possível, sem transformar o notebook em meta;
     - verificar com 600 falsos o fallback sem terreno e com biblioteca real o percurso/launcher;
     - README, ROADMAP e o mapa do AGENTS.md (`worlds/city/biome/`, `profiles/biomes/`; conferir o conteúdo real de `addons/`). Registrar explicitamente qualquer pendência de desktop ou Linux.
  - Teste: `check_perf_tool`.
  - Commit: `Fase 15.15: medida e documentação`

### Trilhas no OpenCode (principal no checkout, paralela em worktree e sessão próprios)
| Janela | Principal | Paralela | Por que não brigam |
|---|---|---|---|
| 1 (retomada) | 15.1 → 15.2 → 15.3 → 15.4 | 15.8 já integrada | não recriar o trabalho concluído |
| 2 (15.4 e 15.8 juntas) | 15.5 → 15.6 → 15.7 | 15.11, depois 15.12 | principal fica com `city.gd`, `BiomeBuilder` e `.tres`; paralela com clima/atmosfera |
| 3 (janela 2 integrada) | 15.9 → 15.10 → **15.14 → 15.13** → 15.15 | revisão somente leitura nos pontos indicados | integrações e qualidade prontas antes da revisão visual final |

A paralela nasce do **commit de conclusão da 15.4**, com contrato de `BiomeSpec`, `CityMap.zone_rects` e `DistrictWeather.areas` já estabilizado. Pode usar a criação de worktree do OpenCode (confirmar base e mover/abrir a sessão nele) ou, explicitamente, `git worktree add -b worktree/f15-clima ../game-hub_worktrees/f15-clima fase-15`. Subagente sozinho usa a pasta da sessão: não equivale a worktree.

**Posse de arquivos da janela 2:**
- Principal: `city.gd`, `biome_builder.gd`, cascas, scatter, árvores, passos, perfis `.tres`, plano e documentação de status.
- Paralela: `weather_spec.gd`, `district_weather.gd`, `day_night.gd`, `biome_atmosphere.gd`, `check_weather.gd`, `check_daynight.gd` e `check_biome_atmosphere.gd`. Não edita `city.gd`, `BiomeBuilder` nem `.tres`.
- Handoff: hash-base, arquivos alterados, API esperada, comando/resultado dos testes e pendências visuais. Se um contrato precisar mudar, combinar com a principal antes de editar arquivo compartilhado.

A paralela não marca o plano. A principal confere o diff, junta com `git merge --no-ff`, liga clima/atmosfera nos perfis e no builder, roda a bateria e marca `[x]`. **Uma bateria por vez**, mesmo entre worktrees. Commits com e-mail noreply (`-c user.email=32810557+guitavaress@users.noreply.github.com`). Revisão Sol somente leitura pode ocorrer em sessão filha recebendo diff/logs/capturas da principal.

### Validação em cada entrega

1. Rodar os testes da subetapa durante o trabalho; antes do commit ou após integração, bateria completa. No PowerShell: `& 'C:\Program Files\Git\bin\bash.exe' tests/run_tests.sh`. No Linux: `bash tests/run_tests.sh`. Detalhes em [../OPENCODE.md](../OPENCODE.md#testes-no-windows-e-no-linux).
2. Guardar logs e capturas na pasta temporária da sessão. Registrar comando, ambiente, resultado e commit-base no plano; aprovação histórica não substitui teste atual.
3. Aceites intermediários: **15.4** planta/mapas/metrô; **15.7** portas livres e assets; **15.9/15.10** colisão/percurso/mirante; **15.14/15.13** qualidade e capturas; **15.15** desempenho e documentação. Sol revisa os pontos estruturais indicados; o dono aprova o visual.
4. `[x]` só com critérios da etapa satisfeitos. Um teste headless do núcleo não encerra a integração, uma imagem não prova colisão e tempo de geração não prova FPS.

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
| Colisão analítica diferente dos triângulos da trilha | raios na 15.9, em 4/3/2 m por célula | alinhar malha/colisão; replanejar se precisar de faixa refinada |
| Trabalho paralelo sobrescrever API/perfil | diff e contrato da janela 2 | um dono por arquivo; integração pela principal |
| Testar Windows pelo bash do WSL | runner procura `~/.local/bin/godot` | usar Git Bash explícito; registrar SO de cada execução |

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
- 2026-10-24: detalhamento da 15.1 aprovado e implementado. Gerador salvou o `.tres` pela Godot, usando assets existentes; névoa, densidade e cobertura são valores iniciais a afinar nas etapas visuais. Testes direcionados `check_profiles`, `check_terrain` e `check_textures` aprovados. Bateria completa Windows: 76/76, `RESULTADO GERAL: TUDO OK`; Rust pulado. Conferência manual no editor pendente, por isso a 15.1 ainda não recebeu `[x]`.
- 2026-10-17: portais no chão plano com a montanha atrás; setores para todos os bairros; terreno por malha feita por código (dono, no planejamento).
- 2026-10-17: 15.0 em andamento. Brief em `docs/design/bioma-montanha.md`; amostra baixada (Snow010A, Rock058, moon_rock_02 e o pinheiro fir_sapling_medium, cujo glTF fica em `~/git/game-hub-fontes/`) e capturada por cima do bairro RPG com o `tools/capturar_pontos.gd` (novo). Resultado: rocha = forma da moon_rock_02 com a Rock058 e neve por cima; neve com tinta `#BCC5D2`. **Falta:** o dono aprovar a amostra e permitir os `footstep_snow_*` do Kenney.
- 2026-10-19: a fase passou para o desktop (Windows). A `fase-15` recebeu a `fase-linux` (Fase 14 e correções do Windows) e a 15.8 da `worktree/terreno` (só arquivos novos; bateria 75/75 antes). A amostra foi refeita no desktop e **aprovada pelo dono**; os `footstep_snow_000..004` vieram do Kenney Impact Sounds (0,8 MB o zip, 39 KB no projeto, com permissão). 15.0 concluída.
- 2026-10-23: a pedido do dono, retomada com OpenCode/OpenAI: estado e dependências conferidos; 15.0/15.8 preservadas; próxima 15.1. Configuração de agentes/comandos em `opencode.json`; política em `docs/OPENCODE.md`. Qualidade (15.14) passa antes da revisão visual final (15.13); 15.9 dividida em entregas menores. Meta de desktop será medida na 15.15, pois o desktop já está disponível. Atualização de planejamento/infra, sem implementar as próximas subetapas.
- 2026-10-23: bateria completa no desktop Windows aprovada (76/76; Rust pulado). A tentativa anterior com `bash` do PATH abria o WSL; documentado o comando explícito do Git Bash. Configuração OpenCode validada pela API na localização do projeto.

## Checklist de teste manual (fim da fase)
1. **Abrir o hub no editor:** abrir `project.godot`, apertar **F6** com `worlds/city/city.tscn` aberta, com a biblioteca de verdade. Sair de casa (E na porta) e abrir o mapa (M).
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
7. **Repetir com 200 jogos falsos, com janela:** no PowerShell, `& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --path . -s tools/medir_desempenho.gd -- 200 alta 22`.
   - **Deve acontecer:** medir a meta de desktop e comparar com a base conforme 15.15. No notebook, usar `godot --path . -s tools/medir_desempenho.gd -- 200 leve 22` só para antes/depois.
