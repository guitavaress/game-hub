# Fase 13: Casa, parte 2

**Status:** em andamento (aprovado em 2026-10-12)
**Branch:** `fase-13`, criada a partir da `fase-linux` (em `ff3ee5c`), no checkout principal (`~/git/game-hub`). A `fase-linux` ainda não foi para a `main`; quando for, `git rebase --onto main fase-linux fase-13`.

### Trabalho com o Nimbalyst
- **Trilha principal** (sessão comum, branch `fase-13`): faz as subetapas em ordem, é a única que marca `[x]` e escreve em "Decisões tomadas durante a fase", e junta a paralela.
- **Trilha paralela** (uma por vez, em **New Worktree**): só subetapas que não mexem nos arquivos da principal naquela janela.

  | Janela | Principal | Paralela | Por que não brigam |
  |---|---|---|---|
  | 1 | 13.1 → 13.2 → 13.3 | 13.5 (dados das estatísticas) | a 13.5 só cria arquivos novos e mexe no `tests/fake_library.gd` |
  | 2 (depois da 13.3) | 13.4 → 13.7 → 13.8 | 13.6 (avatar: dado e corpo) | a 13.6 mexe no `friend_npc.gd`, `app_config.gd` (a seção `[home]` já entrou na 13.3) e cria `components/avatar/` |
  | 3 (depois da 13.8 e da 13.6 juntas) | 13.9 → 13.10 → 13.11 | 13.12 (a cabana) | a cabana é um perfil novo, um enfeite novo e um shader novo |

  A 13.0 e a 13.13 ficam só na principal.
- **Passo a passo da paralela:** igual ao da [Fase 9](fase-9.md#trabalho-com-o-nimbalyst): New Worktree com o modelo e o esforço da subetapa; primeira mensagem "execute a subetapa 13.N do plano `docs/plans/fase-13.md`, sem marcar o plano; faça o commit com o e-mail noreply e me diga o hash"; para juntar, na principal e entre duas subetapas: `git merge --no-ff worktree/<nome> -m "Fase 13.N: junta a trilha paralela"`, `bash tests/run_tests.sh` e marcar `[x]` com o hash. Sem os botões Commit e Merge do Nimbalyst. Uma bateria por vez.

## Contexto
A casa da [Fase 9](fase-9.md) é o primeiro passo da V2, mas é igual para todo mundo e não diz nada sobre quem mora nela. A Fase 13 ([ROADMAP › Fase 13](../ROADMAP.md#fase-13-casa-parte-2)) faz a casa virar "sua":
- uma parede com a sua **história de jogador** (horas, mais jogados, horas por bairro, o último jogado);
- **temas da casa como dado** (regra 4): o loft vira o primeiro perfil, e entra uma **cabana**; a troca é pelo computador;
- **personalizar**: cor das paredes, do néon e posições prontas dos móveis;
- um **avatar** (o modelo da Quaternius, com cores) que você vê num **espelho**, salvo no `config.cfg`, no mesmo formato que os amigos receberão na V4.

Tudo roda bem no notebook (Leve), onde o dono está até ~18/10.

Levantamento (só leitura):
- **A casa** (`worlds/home/home.gd`, 487 linhas) monta tudo por código, com as cores em constantes (`FLOOR_WOOD`, `PLASTER_TINT`, `NEON_COLOR`, `LAMP_COLOR`...). Partes: `_build_environment`, `_build_room`, `_build_window` (shader `home_window.gdshader`, que recebe `night`), `_build_lights` (3 pendentes), `_build_front_door`, `_build_decor` (tapete, sofá, mesinha, abajur, néon), `_build_furniture` (estante a oeste, mural a leste e mesa do computador ao norte, em x = 3,6). A sala tem 12 × 3,4 × 9 m. A porta da rua fica no meio da parede sul.
- **Materiais** (`home_materials.gd`): `wood`, `pbr` (pastas da ambientCG), `fabric`, `metal`, `matte` e `glow`, com cache.
- **Perfis** (`profiles/`): `DistrictProfile` com sub-recursos (`AmbienceSpec`, `WeatherSpec`), lista em `world_profile.tres` e o `Profiles` (estático) como porta de entrada. Enfeite por caminho de script (`props_script`) e fábrica por tabela (`_shells` no `city.gd`), sem `match`.
- **Horas:** `SteamLibrary.get_playtime_minutes(app_id)` devolve **−1 quando não sabe** (sem usuário logado ou sem `localconfig.vdf`) e 0 para quem nunca jogou. `get_last_played` junta o manifesto e o `localconfig`. `reload_playtimes()` já roda no `HubWindow.woke_up` (a volta de um jogo). `GameInfo.format_playtime`/`format_last_played` já formatam.
- **Config:** o `AppConfig` acrescenta seções novas no fim do arquivo (`ADDED_SECTIONS`) e troca só a linha mudada (`_set_option`), avisando por `settings_changed(section, key)`.
- **Modelo do avatar** (`assets/quaternius/animated_human.glb`): uma malha só (~1.600 triângulos), **sem textura** e sem cor por vértice, com animações Idle, Walk, Run e outras. O UV de cada face aponta para um ponto de uma paleta que não veio no arquivo: são **5 grupos de UV** (5 zonas de cor). Isso permite colorir as partes por shader.
- **Foco:** `player.focus_on(alvo)` aceita qualquer nó com `get_camera_pose(fov, aspect)` e `set_focused(on, player)`. O computador (`Screen3D`) usa esse contrato.
- **Medida:** `tools/medir_desempenho.gd` já tem o trecho `MEDIDA_CASA` (gira no ponto de nascer por ~3 s). Na Fase 9, em casa, deu 60 FPS na Leve, com 101 desenhos.
- **Assets já no projeto:** ambientCG (Bricks097, Concrete034/048, PavingStones070, Tiles139/141...), Kenney Nature Kit (árvores, arbusto, pedra), Kenney Mini Characters (12 bonecos, sem uso) e os HDRI da Poly Haven.

## Pronto quando
- **Tema na hora:** trocar de loft para cabana pelo computador muda a casa na hora, com a câmera ainda no monitor, e volta igual. Nenhum `match` por tema e nenhum id de tema fora de `profiles/` (varredura no teste, como no `check_profiles`).
- **O loft não muda:** a casa montada pelo perfil do loft é igual à de hoje, peça por peça (comparada a um retrato gravado antes da mudança).
- **Personalizar:** a cor das paredes e a do néon mudam na hora e ficam salvas; há 3 disposições prontas dos móveis, todas com passagem livre até cada móvel.
- **Estatísticas reais:** a parede mostra as horas totais, os 5 mais jogados, as horas por bairro e o jogado mais recente, e se atualiza ao voltar de um jogo. Sem horas ou sem jogos, aparece uma mensagem clara, sem quebrar.
- **Avatar:** o espelho mostra o avatar escolhido, que fica salvo no `config.cfg` e volta igual ao reabrir o hub. O dado (`AvatarSpec.to_dict()`) é o mesmo que a V4 vai trocar, e os hologramas dos amigos continuam iguais.
- **Desempenho (notebook, Leve, 22 h):** de frente para o espelho, a queda é de no máximo ~3 FPS em relação à medida de antes; no ponto de nascer (`MEDIDA_CASA`), não muda.
- A bateria inteira passa, com os testes novos.

## Decisões de arquitetura

### 1. HomeProfile: o tema da casa como dado
- **Formato: `.tres`, como os bairros** (Fase 7). Arquivos novos em `profiles/`:
  - `home_surface.gd` (`HomeSurface`): **uma superfície** = tipo de material (`wood`, `pbr`, `matte`, `metal`, `fabric`), cor, pasta da ambientCG (para `pbr`), tamanho da repetição, aspereza, tábuas sim/não e **`paintable`** (se a cor escolhida pelo usuário pinta esta superfície);
  - `home_profile.gd` (`HomeProfile`):
    - `id`, `display_name`;
    - **Superfícies:** `floor`, `ceiling`, `feature_wall` (a parede da janela), `walls` (as outras três), `skirting`, `beams` (vazio = sem vigas);
    - **Luz:** cor e força das lâmpadas, cor do fundo, luz ambiente de dia e de noite, cor da luz do dia;
    - **Janela:** o shader da vista (`window_shader`) e a superfície da moldura;
    - **Néon:** cor padrão e força (0 = sem néon);
    - **Decoração:** `decor_script` (caminho de um script, como o `props_script` dos bairros) com os móveis de enfeite e as luminárias do tema;
    - `footstep` ("wood");
  - `home_layout.gd` (`HomeLayout`): uma **disposição pronta** (veja a decisão 3);
  - `home_catalog.gd` (`HomeCatalog`) e `home_catalog.tres`: a lista dos temas (o primeiro é o padrão), a lista das disposições e as **paletas** de cores de parede e de néon que o computador oferece;
  - `profiles/homes/loft.tres` (e depois `cabana.tres`).
- **O `Profiles` ganha** `home_catalog()`, `home(id)` e `home_layout(id)`. Id vazio ou desconhecido → o primeiro da lista, com aviso no log.
- **Como a casa passa a ler:**
  - `HomeMaterials.from_surface(surface, tint)` cria o material de uma `HomeSurface`. O `match` dele é pelo **tipo de material** (madeira, textura, fosco...), nunca pelo tema; é a mesma ideia da fábrica de cascas da Fase 7.
  - O `home.gd` separa duas partes:
    - a **casca**: chão, paredes, teto, janela, néon, porta, luz ambiente e o enfeite do tema, tudo lido do perfil, dentro de um nó `Shell` que pode ser refeito;
    - os **móveis** (estante, mural, computador e, depois, estatísticas e espelho), que **não são refeitos** ao trocar de tema.
  - As constantes de cor saem do `home.gd` e vão para o `loft.tres`.
  - O enfeite do loft (tapete, sofá, mesinha, abajur e pendentes) sai do `home.gd` para `worlds/home/themes/loft_decor.gd`, que estende uma base `HomeDecor` (`worlds/home/home_decor.gd`, com o `add_box` que hoje se repete no `home.gd` e no `computer_desk.gd`).
- **A sala tem o mesmo tamanho em todos os temas** (12 × 3,4 × 9 m, janela ao norte, porta ao sul). Assim as disposições dos móveis valem para qualquer tema. Casas de outro tamanho ficam para depois.
- **"Nada visível muda" é provado por um retrato:** antes de mexer, `tools/retrato_casa.gd` grava `tests/fixtures/casa_atual.json` com cada peça (nome, posição global, tamanho), cada material (tipo e parâmetros), cada luz e o ambiente. O teste compara a casa nova com ele. A comparação é pela posição global e não pelo caminho do nó, porque as peças mudam de pai.
- **Os `.tres` são gerados pela Godot** (`ResourceSaver`) a partir das constantes de hoje, como na 7.1, para não errar um dígito de cor.
- *Descartado:* um `match tema:` no `home.gd`, porque quebra a regra 4 e não serviria aos perfis do usuário da Fase 18.

### 2. Estatísticas: um quadro na parede, feito de texto 3D
- **Onde:** um **quadro na parede** (`worlds/home/stats_wall.gd`, `StatsWall`), com o mesmo acabamento do mural (moldura de madeira). Por padrão fica na parede sul, à esquerda da porta, e muda de parede com a disposição.
- **Como é desenhado:** com `Label3D` e barras (caixas finas), como o mural e a estante.
  - *Descartado:* `Screen3D` (`SubViewport`), porque é uma segunda tela renderizando, para um conteúdo que muda só ao voltar de um jogo.
  - *Descartado:* a estante, que já está cheia de capas e tem páginas.
- **O que mostra:**
  - **"Horas jogadas"**: o total, em letra grande;
  - **"Mais jogados"**: os 5 primeiros, com barra proporcional ao primeiro e as horas;
  - **"Por bairro"**: uma barra por bairro com horas, na cor de néon do bairro, do maior para o menor;
  - **"Jogado por último"**: a capa pequena (`GameArt`), o nome e "há 3 dias" (`GameInfo.format_last_played`).
- **Conta só os jogos instalados** (os mesmos da cidade). O `localconfig.vdf` também tem jogos desinstalados e ferramentas, e contar esses deixaria a parede diferente da cidade.
- **Os números saem de uma classe sem tela** (`components/library_stats/library_stats.gd`, `LibraryStats`, só funções estáticas, como o `GameInfo`). Ela lê `SteamLibrary` e `GameCategories` e devolve um resultado com: quantos jogos, se as horas são conhecidas, o total, os 5 mais jogados, as horas e a quantidade de jogos por bairro e o último jogado. Não conhece a casa: a Fase 16 (o bairro cresce com as horas) vai reaproveitar.
- **Sem horas ou sem jogos:**

  | Situação | Como se percebe | O quadro mostra |
  |---|---|---|
  | Biblioteca vazia | 0 jogos instalados | "Nenhum jogo instalado ainda. Instale um jogo na Steam e ele aparece aqui." |
  | Horas desconhecidas (Steam sem usuário logado, ou sem `localconfig.vdf`) | `get_playtime_minutes` = −1 | Total "—" e a dica "Entre na sua conta da Steam para ver as horas". "Por bairro" vira **quantos jogos** por bairro, e "Jogado por último" continua (vem também do manifesto). |
  | Horas conhecidas, mas tudo 0 | soma = 0 | "Nenhuma hora jogada ainda", com a contagem por bairro. |
- **Quando atualiza:** ao montar e no `HubWindow.woke_up` (a volta de um jogo, que já relê as horas). Se a Steam ainda não tiver gravado o `localconfig.vdf`, as horas novas aparecem na volta seguinte (anotado em Riscos).

### 3. Personalizar: cores por paleta e posições prontas
- **No `config.cfg`**, numa seção nova `[home]`, acrescentada como as outras:
  - `theme` ("" = o tema padrão do catálogo);
  - `layout` ("" = a disposição padrão);
  - `wall_color` e `neon_color` (texto `"#rrggbb"`; "" = a cor do tema).

  O `AppConfig` ganha os `get_`/`set_` e avisa por `settings_changed("home", ...)`. A `Home` ouve e aplica na hora, como a qualidade gráfica já faz. O `AppConfig` guarda só textos: quem entende "loft" é o `Profiles`.
- **As cores vêm de paletas prontas** (~8 cores de parede e ~8 de néon, no `home_catalog.tres`), escolhidas por amostras clicáveis.
  - *Descartado:* o `ColorPicker` da Godot, ruim de usar com o controle e dentro da tela 3D.
  - A cor da parede pinta só as superfícies `paintable` do tema: no loft, o reboco (o tijolo da janela fica).
  - A cor do néon troca a faixa e a luz dela.
- **Posições prontas = âncoras fixas nas paredes.** A `Home` conhece 6 lugares:
  - `oeste` e `leste` (no meio das paredes do lado);
  - `sul_esquerda` e `sul_direita` (dos lados da porta);
  - `norte_esquerda` (à esquerda da janela);
  - `norte_direita` (o computador).

  Uma `HomeLayout` diz que móvel vai em qual âncora e para onde se nasce olhando. Três disposições:

  | Disposição | Estante | Mural | Estatísticas | Espelho |
  |---|---|---|---|---|
  | Padrão | oeste | leste | sul_esquerda | sul_direita |
  | Espelhada | leste | oeste | sul_direita | sul_esquerda |
  | Estante na entrada | sul_esquerda | leste | oeste | sul_direita |

  - **O computador fica sempre em `norte_direita`**: assim a troca feita pelo próprio computador nunca move a mesa com a câmera focada nela.
  - Os móveis são criados por uma tabela id → classe (como a `_shells` da cidade), sem `match`.
  - *Descartado:* arrastar móveis livremente (pedido no ROADMAP: "sem arrastar livre").
- **Trocar de tema com o foco no computador:** só a `Shell` é refeita. A mesa, o monitor e a câmera ficam onde estão. Tudo o que é refeito volta para a camada do interior (`INTERIOR_LAYER`) e ganha a marca de passos.

### 4. O espelho: resolução baixa e só de perto
O jogador é só uma câmera (não tem corpo). Então o espelho precisa de duas coisas: um **corpo** (o avatar) onde o jogador está, que só o espelho vê, e uma **imagem refletida**.

| Opção | Custo no notebook | Parece espelho? |
|---|---|---|
| A. Espelho de verdade em resolução cheia (`SubViewport` + câmera refletida, todo quadro) | desenha a sala **duas vezes**: ~dobra o custo em casa | sim |
| B. O mesmo em **resolução baixa** (Leve 240×450) | os pixels caem ~8×, mas as ~100 chamadas de desenho continuam | sim, um pouco borrado |
| C. **Atualizar só de perto** e só quando o espelho está na tela | zero no resto da casa e na cidade | sim, quando importa |
| D. **Prévia no computador** (o avatar girando, sem a sala, só com o foco) | baixo, só com o foco | não: é uma vitrine |
| E. "Espelho falso" (o avatar num nicho atrás do vidro, sem refletir a sala) | quase zero | não reflete a sala, e o truque aparece |

**Escolha: B + C juntos.**
- Um `SubViewport` pequeno, com resolução por qualidade (`GraphicsQuality.mirror_resolution`: Leve 240×450, Média 320×600, Alta 480×900).
- Ele **só renderiza** com o jogador em casa, a até ~4,5 m, na frente do espelho, e com o espelho na tela (`VisibleOnScreenNotifier3D`). Fora disso fica em `UPDATE_DISABLED`, e o vidro guarda a última imagem.
- Na **Leve**, atualiza **um quadro sim, um não** (30 por segundo).
- A câmera do espelho usa um `Environment` próprio, sem SSAO, brilho nem névoa, sem MSAA e sem sombras, e enxerga até ~10 m.
- **A conta da reflexão:** a câmera do espelho fica no ponto refletido da câmera do jogador, **virada de frente para o plano do espelho**, com projeção `FRUSTUM` e deslocamento (`frustum_offset`), para o recorte bater com a moldura. O plano de corte próximo fica no vidro, para nada atrás da parede aparecer. A imagem é invertida no eixo X pelo material do vidro.
- **O corpo:** um `AvatarBody` segue a câmera do jogador (posição no chão e giro), com Idle parado e Walk andando. Ele fica numa camada de render só dos reflexos (`AvatarBody.REFLECTION_LAYER` = 19), que a câmera do jogador deixa de ver. O jogador nunca vê o próprio corpo de dentro, mas o espelho vê.
- **Plano B:** se a medida da 13.10 cair mais de ~3 FPS na Leve, fica a opção E só na Leve (anotar em "Decisões tomadas durante a fase").
- **Prévia no computador:** não entra. O lugar de escolher o avatar é o próprio espelho (decisão 5).

### 5. O avatar: o mesmo dado para você e para os amigos
- **O que dá para escolher:**
  - a **cor de cada uma das 5 zonas** do modelo (o nome de cada zona, como pele, cabelo, blusa, calça e sapatos, é confirmado na 13.6 por captura);
  - **5 combinações prontas** ("visuais").

  O modelo é um só (o "Animated Human", que já é o corpo dos hologramas).
  - *Descartado:* os **Kenney Mini Characters** (12 variações, já no projeto). Têm outro estilo (cabeçudo), as cores vêm presas numa textura e o avatar ficaria diferente da figura que os amigos usam. Ficam guardados para um "corpo" alternativo no futuro.
  - *Descartado nesta fase:* altura e acessórios. A altura mexe na altura da câmera.
- **Cor por zona, sem textura:** um shader (`components/avatar/avatar_palette.gdshader`) escolhe a cor pela faixa do UV, com uma `uniform` por zona. Nada é baixado.
- **O dado:**
  - `profiles/avatar_spec.gd` (`AvatarSpec`, Resource): `body` ("human") e as 5 cores;
  - `to_dict()`/`from_dict()` no formato `{"version": 1, "body": "human", "colors": {"skin": "#c68e64", ...}}`. **É esse dicionário** que a V4 ao vivo vai mandar e receber;
  - no `config.cfg`, numa seção `[avatar]`, cada cor numa linha (fácil de ler e de editar à mão).
- **O corpo:** `components/avatar/avatar_body.gd` (`AvatarBody`) carrega o modelo, ajusta a altura e a frente (o `_fit_body` que hoje mora no `FriendNpc`), aplica as cores e toca as animações.
  - O **`FriendNpc` passa a usar o `AvatarBody`**, com o material de holograma por cima, e fica igual na tela (o `check_holograms` confere).
  - Ele ganha um campo opcional `avatar: AvatarSpec`. Vazio = o holograma de hoje. Na V4, é por ali que entra o avatar que o amigo escolheu.
- **Onde se escolhe: no espelho, como um provador.**
  - E no espelho → `player.focus_on(espelho)`: a câmera recua ~1,8 m e fica de frente para ele, e um **painel 2D** aparece à direita, com as combinações prontas e as amostras de cor por zona (navegável por mouse, teclado e controle). Esc volta.
  - Você se vê mudando na hora. O espelho cumpre o contrato do `focus_on`, então o jogador não muda.
  - As paletas e as combinações prontas ficam em `profiles/avatar_catalog.tres`.

### 6. O computador ganha a aba "Casa"
A tela do computador passa a ter duas seções no alto: **Configurações** (o `SettingsView` de hoje, sem mudança) e **Casa** (`worlds/home/home_settings_view.gd`), com:
- **Tema:** os botões dos temas do catálogo;
- **Móveis:** os botões das disposições;
- **Paredes** e **Néon:** amostras de cor, mais "do tema".

Cada clique grava no `AppConfig`, e a casa muda atrás do monitor na hora. A navegação por teclado e controle segue a do `SettingsView` (ordem montada à mão). O menu de pausa (Esc) **não** ganha a aba Casa: a casa se muda de dentro de casa.

### 7. A cabana: dá para fazer sem baixar nada
- **Paredes de tora e teto de tábuas:** o shader de madeira que já existe (`home_wood.gdshader`), com tábuas largas na horizontal e um parâmetro novo de "tora" (sombra arredondada em cada tábua). Vigas de madeira no lugar das de aço.
- **Piso:** tábuas mais escuras (o mesmo shader).
- **Lareira:** pedra da ambientCG que já está no projeto (`PavingStones070`, triplanar), fogo com brilho que tremula e uma `OmniLight3D` laranja que tremula junto.
- **Vista da janela:** um shader novo (`worlds/home/home_window_forest.gdshader`) com morros e pinheiros em silhueta, céu de dia e de noite, e o mesmo `night` do grupo `city_night`.
- **Enfeite** (`worlds/home/themes/cabin_decor.gd`): duas poltronas de tecido, um tapete (o shader do tapete com outras cores), lampiões e um vaso com o arbusto do Kenney Nature Kit.
- **Néon:** uma faixa âmbar mais fraca. Ele continua personalizável.
- **Nenhum download é necessário.** Se a pedra ou a madeira ficarem fracas na captura, a 13.12 para e pede permissão, com o nome, a origem (ambientCG) e o tamanho do arquivo.
- *Opcional, se couber:* o estalo da lareira gerado pelo `assets/generated/make_sounds.py` (som feito por nós, sem baixar).

### 8. O que não muda
- `GamePortal`, `GameLauncher`, `TravelDoor` e `Screen3D` não mudam de contrato.
- Nada em `autoload/` passa a conhecer a casa (regra 1). O `AppConfig` guarda textos, e o `GraphicsQuality` só ganha um número por qualidade.
- A casa continua sem conhecer a cidade.

## Subetapas
Ordem: estrutura e dados primeiro (nada visível), depois o que usa a estrutura, e o visual por último (estatísticas na parede, espelho e cabana).

- [x] **13.0 Plano** (Opus · high)
  - Faz: cria a branch `fase-13` a partir da `fase-linux` e grava este plano. O `project.godot` modificado no checkout (o editor reordenando as ações `ui_*`) ficou fora do commit.
  - Commit: `Fase 13.0: plano`
- [x] **13.1 Retrato da casa e o formato do perfil** (Sonnet · medium) — HASH
  - Faz:
    - `tools/retrato_casa.gd` grava `tests/fixtures/casa_atual.json` (rodado uma vez, sobre o código de hoje; duas rodadas devem dar arquivos iguais);
    - cria `HomeSurface`, `HomeProfile`, `HomeLayout` e `HomeCatalog`;
    - gera `profiles/homes/loft.tres` e `profiles/home_catalog.tres` pela Godot, a partir das constantes do `home.gd`;
    - o `Profiles` ganha `home_catalog()`, `home(id)` e `home_layout(id)`.
    - O `home.gd` ainda não muda.
  - Arquivos:
    - novos: `profiles/home_surface.gd`, `home_profile.gd`, `home_layout.gd`, `home_catalog.gd`, `home_catalog.tres`, `profiles/homes/loft.tres`, `tools/retrato_casa.gd`, `tests/fixtures/casa_atual.json`;
    - muda: `profiles/profiles.gd`.
  - Teste: `tests/check_home_profile.gd`:
    - o catálogo carrega, com ids únicos;
    - o loft é o padrão;
    - as cores e os materiais do loft batem com o retrato;
    - um id vazio ou desconhecido devolve o loft.
  - Manual: abrir `profiles/homes/loft.tres` no inspetor e ver os grupos (Superfícies, Luz, Janela, Néon, Decoração).
  - Commit: `Fase 13.1: retrato da casa e perfil do tema`
- [ ] **13.2 A casa lê o perfil** (Opus · high: refatoração do visual sem mudar nada)
  - Faz:
    - `HomeMaterials.from_surface`;
    - o `home.gd` separa a `Shell` (refazível) dos móveis e lê o perfil do loft;
    - as constantes de cor saem do `home.gd`;
    - a base `HomeDecor` e o `loft_decor.gd` (tapete, sofá, mesinha, abajur e pendentes);
    - o `computer_desk.gd` passa a usar o `add_box` da base.
  - Arquivos:
    - novos: `worlds/home/home_decor.gd`, `worlds/home/themes/loft_decor.gd`;
    - mudam: `worlds/home/home.gd`, `home_materials.gd`, `computer_desk.gd`.
  - Teste:
    - `check_home_profile` compara a casa montada com o retrato: mesmas peças, posições, tamanhos, materiais, luzes e ambiente;
    - varredura: nenhum id de tema entre aspas fora de `profiles/` e `tests/`;
    - `check_home`, `check_home_start`, `check_shelf`, `check_friends_wall` e `check_screen_3d` passam sem mudança.
  - Manual: F5. O loft está igual ao de antes (de noite e de dia, F8).
  - Commit: `Fase 13.2: a casa lê o perfil do tema`
- [ ] **13.3 Escolhas da casa no config e troca na hora** (Sonnet · medium; Opus se a troca com foco teimar)
  - Faz:
    - seção `[home]` no `AppConfig` (`theme`, `layout`, `wall_color`, `neon_color`), com `get_`/`set_` e `settings_changed`;
    - a `Home` ouve e aplica: refaz a `Shell` no tema novo e pinta as superfícies `paintable` e o néon.
  - Arquivos: `autoload/app_config.gd`, `worlds/home/home.gd`.
  - Teste: `tests/check_home_custom.gd` (guarda e devolve o `config.cfg`):
    - um segundo tema de teste (cópia do loft com outras cores, feita no próprio teste) troca a casa na hora;
    - os móveis continuam os mesmos nós;
    - a cor da parede pinta só o que é `paintable`, e a do néon troca a faixa e a luz;
    - um id desconhecido cai no loft;
    - **com a câmera focada no computador**, trocar o tema não tira o foco;
    - tudo o que foi refeito está na camada do interior.
  - Manual: editar `[home] wall_color="#3a6ea5"` no `config.cfg`, abrir o hub e ver as paredes azuis.
  - Commit: `Fase 13.3: escolhas da casa no config.cfg`
- [ ] **13.4 Posições prontas dos móveis** (Sonnet · medium)
  - Faz:
    - as 6 âncoras na `Home`;
    - a tabela de móveis (id → classe);
    - as 3 `HomeLayout` no catálogo;
    - o ponto de nascer vira da disposição;
    - a estante e o mural usam a âncora (o ponto de volta da estante segue junto).
  - Arquivos: `worlds/home/home.gd`, `profiles/home_catalog.tres`, `tests/check_home.gd`.
  - Teste: `check_home`, para **cada disposição**:
    - nada fica fora da sala;
    - a passagem até cada móvel e o ponto de volta da estante estão livres (física);
    - nenhum móvel cobre a porta nem a janela;
    - trocar a disposição em jogo move os móveis.
  - Manual: `layout="espelhada"` no `config.cfg`: a estante aparece a leste.
  - Commit: `Fase 13.4: posições prontas dos móveis`
- [ ] **13.5 Estatísticas: os números** (Sonnet · medium) — *trilha paralela, janela 1*
  - Faz: `LibraryStats` (total, top 5, por bairro com horas e quantidade de jogos, último jogado, "horas conhecidas?"), só com jogos instalados.
  - Arquivos:
    - novo: `components/library_stats/library_stats.gd`;
    - muda: `tests/fake_library.gd` (horas falsas opcionais).
  - Teste: `tests/check_library_stats.gd`, com a biblioteca falsa:
    - as somas e a ordem conferem;
    - o top 5 tem só 5;
    - os bairros vêm na ordem das horas;
    - horas −1 → "desconhecidas", com a contagem por bairro;
    - tudo 0 → "nenhuma hora";
    - biblioteca vazia → 0 jogos, sem erro;
    - com 200 jogos, o cálculo leva menos de ~5 ms.
  - Manual: nada visível (o quadro é a 13.7).
  - Commit: `Fase 13.5: números das estatísticas`
- [ ] **13.6 Avatar: o dado e o corpo** (Opus · high: zonas do UV e mexe nos hologramas) — *trilha paralela, janela 2*
  - Faz:
    - `AvatarSpec` (com `to_dict`/`from_dict`);
    - o shader de paleta;
    - `AvatarBody` (modelo, ajuste, cores, Idle e Walk, `REFLECTION_LAYER`);
    - seção `[avatar]` no `AppConfig`;
    - o `FriendNpc` passa a usar o `AvatarBody`, com o holograma por cima e o campo `avatar` opcional;
    - **identificar as 5 zonas** por captura (cores de teste) e dar nome a elas.
  - Arquivos:
    - novos: `profiles/avatar_spec.gd`, `components/avatar/avatar_body.gd`, `components/avatar/avatar_palette.gdshader`;
    - mudam: `components/friend_npc/friend_npc.gd`, `autoload/app_config.gd`.
  - Teste: `tests/check_avatar.gd`:
    - `to_dict` → `from_dict` devolve o mesmo;
    - gravar no `config.cfg` e ler devolve o mesmo (com cópia e devolução);
    - o `AvatarBody` tem ~1,7 m e olha para +Z;
    - cada zona recebe a cor certa;
    - `check_holograms` e `check_phase5` passam sem mudança.
  - Manual: na praça, os hologramas dos amigos estão iguais.
  - Commit: `Fase 13.6: avatar como dado e corpo`
- [ ] **13.7 O quadro de estatísticas** (Sonnet · medium)
  - Faz: `StatsWall` (moldura, título, total, top 5 com barras, por bairro nas cores do bairro, último jogado com capa e as três mensagens), na âncora da disposição, atualizando no `HubWindow.woke_up`.
  - Arquivos:
    - novo: `worlds/home/stats_wall.gd`;
    - mudam: `worlds/home/home.gd` (tabela de móveis), `profiles/home_catalog.tres`.
  - Teste: `tests/check_stats_wall.gd`:
    - com horas falsas, as linhas mostram os mesmos números do `LibraryStats`;
    - as três mensagens aparecem nos três casos;
    - depois do `woke_up` com horas novas, o total muda;
    - com 200 jogos, as barras de bairro não passam da moldura.
  - Manual: F5, virar para a parede sul: as suas horas reais, os mais jogados e as barras coloridas. Captura de noite (Leve), fora do repositório.
  - Commit: `Fase 13.7: estatísticas na parede`
- [ ] **13.8 A aba "Casa" no computador** (Sonnet · medium)
  - Faz:
    - `HomeSettingsView` (tema, móveis, paredes e néon);
    - a tela do computador ganha as seções Configurações e Casa;
    - navegação por teclado e controle.
  - Arquivos:
    - novo: `worlds/home/home_settings_view.gd`;
    - muda: `worlds/home/computer_desk.gd`.
  - Teste: `tests/check_home_view.gd`:
    - um clique simulado no tema muda o `config.cfg` e a casa, com o foco mantido;
    - a amostra de cor pinta a parede;
    - "do tema" volta à cor original;
    - ↑↓←→ e Enter alcançam todos os botões;
    - `check_screen_3d` e `check_pause_menu` passam.
  - Manual: E no computador, aba Casa, trocar a cor do néon e a disposição, Esc e ver a sala.
  - Commit: `Fase 13.8: aba Casa no computador`
- [ ] **13.9 Medida de referência** (Sonnet · low)
  - Faz: o `tools/medir_desempenho.gd` ganha o trecho **`MEDIDA_ESPELHO`**: o jogador fica a ~1,8 m da âncora do espelho, olhando para ela, balançando a câmera por ~3 s. Roda no notebook (Leve, 7 jogos, 22 h, notebook parado) e anota `MEDIDA_CASA` e `MEDIDA_ESPELHO` em "Decisões tomadas durante a fase". Essa é a medida **antes** do espelho, e este commit é a referência.
  - Arquivos: `tools/medir_desempenho.gd`, `docs/plans/fase-13.md`.
  - Teste: `tests/check_perf_tool.gd`, que roda a ferramenta sem janela, com 7 jogos, e confere que as três linhas `MEDIDA*` saem.
  - Manual: rodar o comando da ferramenta (no cabeçalho dela) e colar as linhas.
  - Commit: `Fase 13.9: medida de referência em casa`
- [ ] **13.10 O espelho** (Opus · high: projeção refletida e desempenho)
  - Faz:
    - `HomeMirror` (moldura, vidro com a imagem invertida, `SubViewport`, câmera refletida com `FRUSTUM` e deslocamento, regras de "só de perto", Leve a 30 por segundo);
    - o `AvatarBody` do jogador na camada dos reflexos;
    - o `player.gd` tira a camada 19 da câmera;
    - `GraphicsQuality.mirror_resolution`.
    - **Medida depois**, lado a lado com a da 13.9, no mesmo dia. Se cair mais de ~3 FPS, vale o plano B.
  - Arquivos:
    - novo: `worlds/home/home_mirror.gd`;
    - mudam: `worlds/home/home.gd`, `player/player.gd`, `autoload/graphics_quality.gd`, `docs/plans/fase-13.md`.
  - Teste: `tests/check_mirror.gd`:
    - longe do espelho, ou de costas para ele, o `SubViewport` fica desligado; de perto e olhando, liga;
    - a resolução segue a qualidade;
    - a câmera do jogador não vê a camada 19, e a do espelho vê;
    - um ponto na frente do espelho e o reflexo dele ficam simétricos ao plano;
    - fora de casa, desligado.
  - Manual: andar até o espelho e se ver; andar de lado e o reflexo acompanhar; F8 e a luz mudar no reflexo. Capturas Leve e Alta, fora do repositório.
  - Commit: `Fase 13.10: o espelho`
- [ ] **13.11 O provador: escolher o avatar no espelho** (Sonnet · medium)
  - Faz:
    - o espelho cumpre o contrato do `focus_on` (`get_camera_pose`, `set_focused` e Esc);
    - o painel 2D à direita (combinações prontas e amostras por zona, com o `HubTheme`);
    - `AvatarCatalog` com as paletas e as 5 combinações;
    - grava em `[avatar]`, e o corpo muda na hora.
  - Arquivos:
    - novos: `profiles/avatar_catalog.gd`, `profiles/avatar_catalog.tres`, `ui/avatar_panel.gd`;
    - muda: `worlds/home/home_mirror.gd`.
  - Teste: `tests/check_avatar_panel.gd`:
    - E foca e o painel aparece;
    - um clique numa amostra muda a cor no corpo do espelho e no `config.cfg`;
    - uma combinação pronta troca as 5 cores;
    - Esc fecha e devolve a câmera;
    - o menu de pausa não abre durante o foco;
    - reabrir a casa mantém o avatar.
  - Manual: E no espelho, trocar a blusa para verde, Esc, fechar e abrir o hub: continua verde.
  - Commit: `Fase 13.11: avatar no espelho`
- [ ] **13.12 A cabana** (Opus · high: visual) — *trilha paralela, janela 3*
  - Faz:
    - `profiles/homes/cabana.tres` (gerado pela Godot) e o item no catálogo;
    - `cabin_decor.gd` (lareira, poltronas, tapete, lampiões e vaso);
    - a vista de floresta;
    - o parâmetro "tora" no shader de madeira;
    - o estalo da lareira, se couber.
  - Arquivos:
    - novos: `profiles/homes/cabana.tres`, `worlds/home/themes/cabin_decor.gd`, `worlds/home/home_window_forest.gdshader`;
    - mudam: `profiles/home_catalog.tres`, `worlds/home/home_wood.gdshader`.
  - Teste:
    - `check_home_profile`: a cabana carrega e monta sem erro, e a varredura de ids passa;
    - `check_home` roda as 3 disposições também na cabana (nada fora da sala, passagens livres; a lareira e as poltronas não tampam nenhuma âncora).
  - Manual: aba Casa › Cabana; capturas de dia e de noite, na Leve e na Alta, fora do repositório; e o FPS na Leve perto do de loft.
  - Commit: `Fase 13.12: tema cabana`
- [ ] **13.13 Medida final e documentação** (Sonnet · low)
  - Faz:
    - a medida no notebook (loft e cabana, Leve), anotada;
    - README (temas, cores, móveis, estatísticas, espelho e avatar; como criar um tema novo);
    - ROADMAP (Fase 13 feita; V2 atualizada);
    - CLAUDE.md (mapa: `components/avatar/`, `components/library_stats/`, os perfis da casa);
    - `tests/README.md` (testes novos e retrato da casa);
    - plano marcado;
    - `git branch -f fase-13 HEAD`, se precisar.
  - Teste: bateria inteira.
  - Commit: `Fase 13.13: documentação`

## Riscos
- **A conta do espelho (projeção refletida)** é a parte mais delicada: reflexo torto ou "vendo atrás da parede". A 13.10 é Opus, tem teste de simetria e captura. O plano B (espelho falso só na Leve) está decidido.
- **Desempenho:** a medida antes e depois, lado a lado e com o notebook parado (13.9 e 13.10). O espelho desligado de longe garante que a `MEDIDA_CASA` e a cidade não mudam.
- **As 5 zonas do UV podem não separar bem** (por exemplo, blusa e calça na mesma zona). A 13.6 confere por captura; se for assim, as opções viram as zonas que existem, com outros nomes, sem mexer no modelo.
- **Mexer no `FriendNpc`** pode mudar os hologramas. O `check_holograms` e uma captura na praça (13.6) pegam isso.
- **Refazer a casa com o foco no computador:** a mesa fica fora da `Shell`, e há teste com o foco ligado (13.3 e 13.8).
- **O loft mudar sem querer na refatoração:** o retrato da 13.1 e a comparação da 13.2.
- **A Steam grava o `localconfig.vdf` atrasada:** as horas da última sessão podem aparecer só na volta seguinte. Aceito e escrito no README; a 13.7 confere à mão com um jogo de verdade.
- **`.tres` escrito à mão:** os perfis são gerados pela Godot (como na 7.1), e o `--import` da bateria pega erro de sintaxe.
- **Duas baterias ao mesmo tempo:** a trava do `run_tests.sh`; os testes novos guardam e devolvem o `config.cfg`.

## Fora do escopo
- Arrastar móveis livremente, casas de outro tamanho e mais temas (temas do usuário em `user://` são a Fase 18).
- Corpo alternativo (Kenney Mini Characters), altura, cabelo e acessórios 3D.
- Ver o avatar escolhido pelos amigos (V4 ao vivo, Horizonte). Nesta fase, o `FriendNpc` só aceita o dado.
- Aba Casa no menu de pausa.
- Estatísticas de jogos desinstalados ou de horas por dia ou semana (a Steam não guarda isso no `localconfig.vdf`).
- Push e merge: nada vai para o GitHub sem o dono pedir.

## Decisões tomadas durante a fase
- 2026-10-12: plano aprovado (dono).
- 2026-10-12 (13.1): o retrato (`tests/fixtures/casa_atual.json`, 120 linhas) é gerado por `tests/home_snapshot.gd`, que o teste da 13.2 reaproveita. Fica fora dele a estante e o mural (dependem da biblioteca e dos amigos). Nomes de nó repetidos (`@MeshInstance3D@N`) viram "auto", porque o número muda com a ordem de criação. O retrato foi gravado à noite (luz do dia com força 0).
- 2026-10-12 (13.1): o catálogo já traz as paletas de cor (8 de parede, 8 de néon); as disposições (`layouts`) ficam vazias até a 13.4, e `Profiles.home_layout` devolve null enquanto isso. `tools/gerar_perfis_casa.gd` lê as constantes do `home.gd` e só funciona antes da 13.2.

## Checklist de teste manual (fim da fase)
No notebook (Omarchy), qualidade **Leve**:
1. F5. O loft está como antes. Na parede sul, o quadro mostra as suas horas, os 5 mais jogados e as barras por bairro.
2. Segurar E num jogo da estante, jogar um pouco e fechar: de volta em casa, o "Jogado por último" mostra esse jogo (as horas podem vir só na próxima volta).
3. E no computador › aba **Casa** › **Cabana**: atrás do monitor, a casa vira cabana (lareira, troncos e floresta na janela). Esc. Andar pela cabana.
4. Aba Casa: paredes num tom de azul e néon verde; disposição **Espelhada**. Esc: a estante está a leste, as paredes azuis e a faixa verde.
5. Ir até o espelho: você se vê, e o reflexo anda junto. E no espelho: trocar uma cor e escolher uma combinação pronta; Esc.
6. Fechar e abrir o hub: cabana, cores, disposição e avatar continuam iguais.
7. Na praça, os hologramas dos amigos estão como sempre.
8. Voltar para Loft e "do tema" nas cores: tudo como no passo 1.

No desktop (a partir de 18/10): o mesmo na Alta, mais `bash tests/run_tests.sh` e a medida.

## Verificação
1. `bash tests/run_tests.sh` ao fim de cada subetapa: `RESULTADO GERAL: TUDO OK`.
2. `check_home_profile` (retrato e varredura), `check_home` (3 disposições × 2 temas), `check_library_stats` e `check_stats_wall` também com a biblioteca falsa de 200 jogos.
3. A medida antes (13.9) e depois (13.10) anotada aqui, lado a lado.
4. Capturas (13.6, 13.7, 13.10 e 13.12) só na pasta temporária da sessão, nunca no repositório (mostram capas de jogos).
