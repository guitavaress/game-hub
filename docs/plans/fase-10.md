# Fase 10: Acabamento

**Status:** em andamento
**Branch:** `fase-10`, nascida da `fase-9` (`3eb8403`), no checkout principal (`~/git/game-hub`). A cadeia fica `main` ← `fase-linux` ← … ← `fase-9` ← `fase-10`.

## Contexto
O dono achou o hub "um pouco abaixo". A revisão de 2026-10-10 ([docs/design/revisao-2026-10-10.md](../design/revisao-2026-10-10.md)) separou um **top 5 de muito resultado com pouco trabalho**. Esta fase faz só esse top 5, quase todo com dados, configuração e UI, sem decisão de arquitetura nova:
1. texturas com mipmaps e compressão, e anti-aliasing por qualidade (7.1 + 8.1);
2. a UI escala com a tela (5.1);
3. a porta do prédio diz como entrar (2.1);
4. bairros com arquitetura própria e um letreiro alto por bairro (3.2 + 3.1);
5. primeira vez guiada: cartão de controles, nascer virado para a estante e aviso de "cidade pronta" (1.1 + 1.2 + 1.3).

Ao fim, a cidade fica nítida e sem cintilação, a UI tem o mesmo tamanho relativo em 720p e em 1440p, cada bairro tem silhueta e nome visíveis de longe, e quem abre o hub pela primeira vez sabe o que apertar.

## Pronto quando
- As 21 texturas da ambientCG e o atlas das árvores são importados com compressão de placa e mipmaps, e o asfalto ao longe não "granula" mais (captura de dia).
- Alta usa MSAA 2x + SMAA, Média usa SMAA e Leve usa FXAA. A Leve também tem sombra do sol mais curta e mais barata.
- Em 2560 × 1440, o menu de pausa ocupa a mesma fração da tela que em 1280 × 720, e a sensibilidade do mouse não muda com a resolução.
- O cartão de um prédio mostra "Entre pela porta para jogar"; a porta do loft, vista de dentro, diz "E para sair".
- Cada bairro (menos "Outros") tem pesos de andares e de paredes no `.tres`. Há **um** letreiro por bairro, acima do prédio mais alto possível.
- Na primeira vez, um cartão mostra os controles e o aviso dos amigos espera ele sair. O jogador nasce virado para a estante. Quando a cidade fica pronta, aparece "A cidade está pronta", com um som.
- A bateria inteira passa, com os testes novos, e a medida no notebook (parado, lado a lado com a `fase-9`) não piora mais de ~2 FPS na Leve.

## Decisões de arquitetura
- **Fase própria, e não 9.12+** (dono, 2026-10-10): a Fase 9 fica fechada como está.
- **Entrar no prédio continua sendo "ficar no vão"** (dono, 2026-10-10). Muda só o texto do cartão. "Segurar E" fica só em casa.
- **Qualidade gráfica continua no `GraphicsQuality`** (`autoload/graphics_quality.gd`, ajudante estático). O anti-aliasing entra no `apply_to_viewport` (que o `AppConfig` já chama). A sombra do sol entra num `apply_to_sun(light, level)` novo, que a cidade chama. O ajudante recebe um `DirectionalLight3D` e não conhece a cidade (regra 1).
- **A ação do cartão fica no `GamePortal.get_look_info()`**, e não no `GameInfo.look_info()`: a estante usa o mesmo `GameInfo` com outra ação ("Segure E para jogar"). O texto é genérico e serve a qualquer casca (regra 3).
- **Arquitetura dos bairros é só dado** (regra 4): `floor_weights` (3 a 7 andares) e `wall_weights` (`Concrete034`, `Concrete048`, `Bricks097`) nos `.tres`. O código já lê os pesos desde a Fase 7.
- **Letreiro por bairro, e não por quarteirão:** ele nasce junto do pórtico (primeiro quarteirão do bairro), em cima do meio do quarteirão. A altura vem das constantes do `BuildingVariant` (prédio mais alto possível + folga), e não de um número solto.
- **"Já viu os controles" mora no `config.cfg`** (`[ui] seen_controls_hint`), pelo `AppConfig`, como as outras opções. O cartão é UI (`ui/`). Quem decide mostrar é o jogador, ao fim da abertura (`Player.finish_intro`); assim, os testes com `play_intro = false` não o veem.

## Subetapas
Ordem: o que não muda o desenho da tela primeiro (importação, qualidade), depois UI, depois dados de bairro e, por último, a primeira vez (que depende do resto pronto).

| Janela | Principal | Paralela (New Worktree, opcional) |
|---|---|---|
| 1 | 10.0 → 10.1 → 10.2 | 10.5 (só `.tres` e `check_profiles`) |
| 2 | 10.3 → 10.4 | 10.6 (letreiros: `city.gd` na montagem do bairro e `check_gates`) |
| 3 | 10.7 → 10.8 → 10.9 | — |

Junta da paralela igual à Fase 9: `git merge --no-ff worktree/<nome>`, bateria, `[x]` com os dois hashes; **apagar o worktree antes do chat**.

- [x] **10.0 Preparação** (Sonnet · low) — 36515da
  - Faz: cria a branch `fase-10` a partir da `fase-9`, salva este plano em `docs/plans/fase-10.md` e põe a "Fase 10: Acabamento" no ROADMAP (em andamento).
  - Commit: `Fase 10.0: plano`

- [x] **10.1 Texturas nítidas** (Sonnet · medium) — revisão 7.1 — ca68231
  - Faz: nos 21 `.import` de `assets/ambientcg/*/` e no `assets/generated/tree_impostor.png.import`: `compress/mode=2` (VRAM) e `mipmaps/generate=true`; nos `*_NormalGL.jpg.import`, também `compress/normal_map=1`. Os shaders já pedem mipmap (`building_facade.gdshader`, `tree_impostor.gdshader`) e o relevo já usa `hint_normal`.
  - HDRIs (`assets/polyhaven/hdri/*.import`): testar VRAM (BPTC) e ficar com ela só se o céu não ganhar faixas na captura; senão ficam como estão.
  - Teste: `tests/check_textures.gd` lê cada `.import` (`ConfigFile`) e confere modo e mipmaps; carrega uma textura de cada pasta e confere `get_format()` comprimido e `has_mipmaps()`. Impede que alguém volte o import sem querer.
  - Medida: `tools/medir_desempenho.gd -- 200 leve 12` e `-- 200 leve 22`, antes e depois, com o notebook parado; anotar a memória de textura.
  - Manual: capturas de dia da rua longa (`praca_dia_rua`) e das árvores de longe, antes e depois, em `/tmp`.
  - Commit: `Fase 10.1: texturas com mipmaps e compressão`

- [ ] **10.2 Anti-aliasing e Leve mais leve** (Sonnet · medium) — revisão 8.1
  - Faz, em `autoload/graphics_quality.gd`:
    - `apply_to_viewport`: Alta = `msaa_3d = MSAA_2X` + `screen_space_aa = SMAA`; Média = SMAA; Leve = FXAA (com o FSR em 50% de sempre). Tamanho do atlas da sombra do sol (`RenderingServer.directional_shadow_atlas_set_size`): 4096 na Alta e na Média, 2048 na Leve.
    - `apply_to_sun(light, level)` novo: distância da sombra 120 m (Alta e Média) e 70 m (Leve).
    - `describe()` com os textos novos.
  - Em `worlds/city/city.gd`: chamar `apply_to_sun` ao criar o sol (hoje `directional_shadow_max_distance = 120.0` fixo, perto da linha 656) e no `_on_settings_changed`.
  - Teste: `tests/check_graphics_quality.gd` aplica cada qualidade e confere MSAA, SMAA/FXAA, escala do 3D e distância da sombra num `DirectionalLight3D` de teste; devolve a qualidade do usuário no fim. `check_settings_view` e `check_pause_menu` passam.
  - Medida: notebook parado, Leve e Média, lado a lado com a `fase-9`.
  - Manual: captura ampliada da beira da calçada (`zoom_calcada_leve_x_alta`) nas três qualidades.
  - Commit: `Fase 10.2: anti-aliasing por qualidade`

- [ ] **10.3 UI que escala** (Sonnet · medium; Opus se a tela 3D quebrar) — revisão 5.1
  - Faz:
    - `project.godot`: `window/stretch/mode="canvas_items"` e `window/stretch/aspect="expand"`, base 1280 × 720.
    - `player/player.gd` (linhas ~149–151): olhar com `motion.screen_relative` em vez de `motion.relative`. Com o stretch, o `relative` encolhe em telas grandes e o mouse ficaria mais lento em 1440p.
    - Conferir a tela 3D: `components/screen_3d/screen_3d.gd:211` usa `event.position` com `project_ray_origin`, que já trabalha no mesmo espaço do stretch; o `check_screen_3d` confirma.
  - Teste: uma conferência nova no `check_pause_menu` (o `root.content_scale_mode` é `CANVAS_ITEMS` e o aspecto é `EXPAND`). `check_screen_3d`, `check_minimap`, `check_search` e `check_compass` passam.
  - Manual: capturas em 1280 × 720, 1920 × 1080 e 2560 × 1440 (`--resolution`) do menu de pausa, da busca, do mapa, do HUD com aviso e do computador focado. Conferir à mão que o mouse gira igual em janela e em tela cheia.
  - Commit: `Fase 10.3: a UI escala com a tela`

- [ ] **10.4 A porta diz como entrar** (Sonnet · low) — revisão 2.1
  - Faz:
    - `components/game_portal/game_portal.gd` (`get_look_info`): acrescenta `"action": "Entre pela porta para jogar"` ao dicionário do `GameInfo.look_info()`.
    - `worlds/home/home.gd` (`_build_front_door`): `_front_door.action_text = "E para sair"`. A porta "Casa" da praça continua "E para entrar".
  - Teste: `check_look_card` confere a linha de ação do prédio. `check_shelf` passa a comparar o cartão da caixa com o do portal **sem** a chave `action` (as duas ações são diferentes de propósito). `check_home` confere o "E para sair".
  - Commit: `Fase 10.4: a porta diz como entrar`

- [ ] **10.5 Bairros com arquitetura própria** (Sonnet · medium) — revisão 3.2
  - Faz: pesos nos `.tres` de `profiles/districts/` (andares 3·4·5·6·7 | paredes concreto escuro·concreto claro·tijolo). Ponto de partida, a ajustar pelas capturas:

    | Bairro | Andares | Paredes | Ideia |
    |---|---|---|---|
    | estrategia | 0 · 0 · 0,2 · 0,4 · 0,4 | 0,5 · 0,5 · 0 | torres de escritório |
    | simulacao | 0 · 0,1 · 0,2 · 0,35 · 0,35 | 0,4 · 0,4 · 0,2 | alto, misto |
    | acao | 0 · 0,2 · 0,35 · 0,3 · 0,15 | 0,6 · 0,3 · 0,1 | médio-alto, concreto |
    | esportes | 0,1 · 0,3 · 0,4 · 0,2 · 0 | 0,3 · 0,5 · 0,2 | médio, claro |
    | cartas | 0,2 · 0,3 · 0,3 · 0,2 · 0 | 0,1 · 0,4 · 0,5 | cassino de tijolo |
    | rpg | 0,45 · 0,35 · 0,2 · 0 · 0 | 0,1 · 0,1 · 0,8 | baixo, tijolo |
    | aventura | 0,5 · 0,35 · 0,15 · 0 · 0 | 0,1 · 0,2 · 0,7 | baixo, tijolo |
    | casual | 0,55 · 0,35 · 0,1 · 0 · 0 | 0,1 · 0,8 · 0,1 | baixo, claro |
    | sobrevivencia (Terror) | 0,5 · 0,3 · 0,2 · 0 · 0 | 0,85 · 0,15 · 0 | baixo, concreto escuro |
    | outros | padrão | padrão | — |
  - Teste: em `check_profiles`, trocar "os 10 perfis usam o padrão" por: cada peso tem o tamanho certo (5 e 3) e soma > 0; "outros" fica no padrão. As outras conferências do retrato continuam. `check_variants`, `check_scale` e `check_metro` passam.
  - Manual: capturas `bairro_noite_alto` e `bairro_dia_alto` (vista de cima), antes e depois.
  - Commit: `Fase 10.5: arquitetura própria por bairro`

- [ ] **10.6 Um letreiro alto por bairro** (Sonnet · medium) — revisão 3.1
  - Faz, em `worlds/city/city.gd`:
    - o `DistrictSign` sai do `_build_block` (hoje um por quarteirão, a 17 m) e passa a nascer uma vez por bairro, no primeiro quarteirão, junto do `_build_gate` (perto da linha 356), em cima do meio do quarteirão;
    - a altura vira `BuildingVariant` (prédio mais alto possível, com recuo e telhado) + ~5 m, e o texto cresce (`DISTRICT_SIGN_TEXT_HEIGHT` de 1,8 para ~4);
    - as placas de rua por quarteirão (`_build_street_sign`) continuam.
  - Teste: `check_gates` deixa de contar quarteirões pelos letreiros (passa a usar `city._district_cells`) e ganha "um letreiro por bairro" e "letreiro acima do prédio mais alto possível". `check_variants` ("nenhum letreiro dentro de prédio") passa.
  - Manual: capturas `praca_*_chegada` e `bairro_noite_alto`, de dia e de noite.
  - Commit: `Fase 10.6: um letreiro alto por bairro`

- [ ] **10.7 Primeira vez guiada** (Sonnet · medium) — revisão 1.1 + 1.3
  - Faz:
    - `autoload/app_config.gd`: `get_seen_controls_hint()`/`set_seen_controls_hint()` em `[ui] seen_controls_hint` (o `_write_option_to_file` já cria a seção que faltar).
    - `ui/controls_hint.gd` (novo): cartão no pé da tela com as teclas (`GameScreen.make_key_cap`): WASD andar · Shift correr · E usar · Tab buscar · M mapa · Esc menu. Some depois de ~15 s ou no primeiro E; ao sumir, grava "visto".
    - `ui/hud.gd`: `show_controls_hint()`. Enquanto o cartão está aberto, os avisos esperam na fila que já existe (`_waiting_messages`), e o dos amigos não é a primeira coisa na tela. `show_message` ganha um `sound` opcional.
    - `player/player.gd` (`finish_intro`): mostra o cartão se ainda não foi visto.
    - `worlds/city/city.gd` (fim da montagem, com `play_intro`): aviso "A cidade está pronta · A porta da rua já abre", com o `assets/kenney/music-jingles/jingles_PIZZI00.ogg`.
  - Teste: `tests/check_first_time.gd` (guarda e devolve o `config.cfg`, como o `check_pause_menu`): sem "visto", `finish_intro` mostra o cartão e o aviso dos amigos espera; ao fechar, grava "visto" e o aviso aparece; na segunda vez, não mostra. `check_home_start` também guarda e devolve o `config.cfg` e confere o aviso "A cidade está pronta".
  - Commit: `Fase 10.7: primeira vez guiada`

- [ ] **10.8 Nascer virado para a estante** (Sonnet · low) — revisão 1.2
  - Faz: `worlds/home/home.gd` (`get_spawn_transform`) gira o jogador ~35° para oeste: ele vê a estante e o janelão. O sofá já tem braços e almofadas (9.9); nada muda nele.
  - Teste: `check_home` e `check_home_start` passam a esperar "entre a janela e a estante" no lugar de "olhando para o norte".
  - Manual: captura `casa_noite_nascer`.
  - Commit: `Fase 10.8: nascer virado para a estante`

- [ ] **10.9 Medida e docs** (Sonnet · low)
  - Faz:
    - medida final no notebook, **parado**, `fase-9` × `fase-10` lado a lado (Leve, 22 h, 200 jogos; e 30 jogos ao meio-dia), anotada em "Decisões";
    - no topo do `tools/medir_desempenho.gd`, a nota "medir com o notebook parado e comparar lado a lado no mesmo dia" (revisão 8.3);
    - README (nitidez, qualidades, UI que escala, letreiros, bairros diferentes, cartão de controles), ROADMAP (Fase 10 feita), `tests/README.md` (testes novos), CLAUDE.md ("Feito: fases 1–10");
    - na revisão, uma linha dizendo quais itens a Fase 10 fez;
    - plano marcado.
  - Commit: `Fase 10.9: documentação`

## Riscos
- **Relevo comprimido (RGTC) muda o aspecto das paredes:** comparar captura antes e depois; se ficar pior, só o relevo volta a `compress/normal_map=0` com VRAM normal.
- **Árvores com mipmap afinam de longe** (o recorte por transparência some nos mipmaps menores): captura das árvores a 50–100 m; se afinar, o atlas fica sem mipmap e só ganha a compressão.
- **Céu com faixas** com o HDRI comprimido: fica como está (decidido na 10.1 pela captura).
- **Stretch:** mouse mais lento em tela grande (resolvido com `screen_relative`), clique da tela 3D fora do lugar, minimapa e bússola com tamanhos em pixel. O `check_screen_3d` e as capturas em três resolucões pegam cedo.
- **MSAA/SMAA pesam no notebook:** só a Leve importa lá (FXAA, o mais barato); a Alta é para o desktop, ainda sem número.
- **Prédios mais altos** na Estratégia e na Simulação podem encostar no metrô ou nos pórticos: `check_metro`, `check_gates` e `check_variants` pegam isso.
- **Testes que gravam no `config.cfg`:** o cartão da primeira vez grava "visto"; `check_first_time` e `check_home_start` guardam e devolvem o arquivo.

## Fora do escopo
- Os outros itens da revisão (1.4 marco na praça, 2.2 FOV na carga, 2.3 curvas, 2.4 sons, 3.3 `landmark_script`, 3.4 título do bairro, 3.5 aviso do pórtico, 4.x luz, 5.2 tema único, 5.3 menu por teclado e controle, 6.x som e câmera, 7.2 estilos, 7.3 créditos, 8.2 `distance_fade` dos postes). Ficam na ordem sugerida da revisão para uma "Fase 11: Sensação e marcos".
- "Segurar E" para entrar nos prédios (dono: fica o vão).
- Glow mais barato na Leve (é o que faz o néon; medir antes).

## Decisões tomadas durante a fase
- 2026-10-10: fase própria "Acabamento" e entrar no prédio continua sendo ficar no vão (dono).
- 2026-10-10 (10.1): os 3 céus HDRI também ficam comprimidos (BC6H): a captura do céu de dia, do pôr do sol e da noite ficou igual à de antes, sem faixas. O relevo comprimido (RGTC) e as árvores com mipmap também passaram nas capturas (o asfalto ao longe parou de granular; as árvores a ~70 m não afinaram).
- 2026-10-10 (10.1): sem janela, `has_mipmaps()` responde sempre `false` (renderizador falso); o `check_textures` lê o número de mipmaps no cabeçalho do `.ctex` importado.
- 2026-10-10 (10.1): medida (Leve, 200 jogos), **com o notebook ocupado** (Chromium a 50% da CPU), então o FPS não serve de comparação: 22 h 22,4 → 45,4 FPS e 12 h 37,9 → 34,6 FPS (os desenhos pularam entre ~1700 e ~3000 nas duas versões, o mesmo sintoma da revisão 8.3). A memória de textura é confiável: **552 → 470 MB** (22 h) e **531 → 492 MB** (12 h). A comparação de FPS fica para a 10.9, com o notebook parado.

## Checklist de teste manual (fim da fase)
No notebook (Omarchy), qualidade **Leve**, depois **Alta**:
1. Apague a linha `seen_controls_hint` do `config.cfg` (ou a seção `[ui]`) e aperte F5. O cartão de controles aparece no pé da tela; o aviso dos amigos só vem depois. Você nasce vendo a estante e o janelão.
2. Espere a cidade montar: aparece "A cidade está pronta", com um som curto.
3. Saia para a praça. De longe, cada bairro tem um nome grande acima dos telhados; as ruas de RPG e Aventura são baixas e de tijolo, e as de Estratégia, altas.
4. Ande pela rua longa de dia: o asfalto ao longe não cintila, e as bordas da calçada não têm degraus.
5. Olhe um prédio: o cartão diz "Entre pela porta para jogar".
6. Aperte F11 (tela cheia) e Esc: o menu ocupa a mesma parte da tela que em janela, e o mouse gira igual.
7. Feche e abra de novo: o cartão de controles não aparece mais.

## Verificação
1. `bash tests/run_tests.sh` ao fim de cada subetapa: `RESULTADO GERAL: TUDO OK`.
2. Capturas (10.1, 10.2, 10.3, 10.5, 10.6, 10.8) com janela, só em `/tmp`, nunca no repositório (mostram capas).
3. Medida com `tools/medir_desempenho.gd`, notebook parado, `fase-9` × `fase-10` no mesmo dia (10.1, 10.2 e 10.9). O desktop continua sendo a régua de verdade, a partir de 18/10.
