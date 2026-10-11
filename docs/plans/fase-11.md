# Fase 11: Sensação e marcos

**Status:** em andamento
**Branch:** `fase-11`, nascida da `fase-10` (`7000288`), no checkout principal (`~/git/game-hub`). A cadeia fica `main` ← `fase-linux` ← … ← `fase-10` ← `fase-11`.

## Contexto
A Fase 10 fez o top 5 da [revisão de 2026-10-10](../design/revisao-2026-10-10.md). Esta fase faz os itens 5, 6 e 8 da "Ordem sugerida", mais os itens soltos que cabem:
- **game feel da porta e da câmera** (2.2, 2.3, 6.2), com **sensibilidade do mouse e FOV** (a parte da 5.3 que mexe na câmera);
- **marcos altos**: torre do relógio na praça (1.4) e o `landmark_script` do perfil ligado, um marco por bairro (3.3);
- **som**: barramento de música, fundo da cidade, som de "Outros", reverberação e passos de madeira em casa (6.1, 2.4);
- **soltos**: título ao entrar no bairro (3.4), aviso do pórtico (3.5), arbusto da praça (7.2) e créditos (7.3).

O item 7 (tema único e menu por teclado/controle, 5.2 e 5.3) vira a **Fase 12: Tema e controles** (decisão do dono, 2026-10-10). Ao fim desta fase, entrar numa porta "pesa" (a câmera fecha e o vão acende), andar tem balanço, a praça e cada bairro têm um ponto alto visível de longe, e a cidade e a casa soam diferente uma da outra.

## Pronto quando
- Fades, avisos, cartão do que se olha e vinheta da porta usam curvas (nenhum tween de UI linear).
- Andando, a câmera balança 2–3 cm no ritmo dos passos; ao pousar, afunda ~5 cm; correndo, o FOV abre 5°; no ar, o controle é menor. A opção "Balanço da câmera" desliga tudo isso.
- Na carga da porta, o FOV fecha ~6°, a câmera avança um pouco e o néon do vão ganha força; ao recuar, tudo volta. O zumbido da carga não é mais o mesmo dos hologramas.
- Em Esc › Controles, dá para mudar a sensibilidade do mouse e o FOV, e vale na hora.
- A praça tem uma torre do relógio de ~18 m, que marca a hora da cidade e aparece no minimapa.
- Cada bairro (menos a Simulação, cuja grua já é o marco) tem um marco no quarteirão do pórtico, acima do prédio mais alto possível, e o letreiro fica acima dele.
- Há um canal "Música" (com deslizador) onde tocam os jingles; a cidade tem um som de fundo baixinho; "Outros" tem som; em casa, os passos são de madeira e têm eco leve.
- Ao entrar num bairro, aparece o título "RPG E FANTASIA · 12 jogos" por ~2,5 s.
- Pórtico que não cabe gera aviso; o arbusto da Kenney sai da praça; `metro_ride.wav` e `city_bed.wav` estão nos créditos, e `assets/generated/` tem `LICENSE.txt`.
- A bateria inteira passa, com os testes novos, e a medida no notebook (`fase-10` × `fase-11`, intercaladas) não piora mais de ~2 FPS na Leve.

## Decisões de arquitetura
- **Fases 11 e 12** (dono, 2026-10-10): o tema único mexe em todas as telas de uma vez; ele vem depois, já com as linhas novas desta fase (título do bairro, deslizadores, Música). A Fase 12 ganha plano próprio.
- **A câmera ganha um ajudante, `player/camera_feel.gd`** (`CameraFeel`, um `Node` filho do `Player`). Ele calcula o deslocamento da câmera (balanço, afundada, avanço) e o FOV (base + corrida + carga) a cada quadro. O `player.gd` (522 linhas) só o alimenta (velocidade, passada, chão, pouso). Durante o foco numa tela 3D e na viagem rápida, o ajudante não mexe na câmera (quem manda é o `_slide_camera`).
- **A carga da porta chega à câmera pelo `ScreenFade`**, e não pelo portal: o `CameraFeel` lê `ScreenFade.door_charge.get_progress()`. Já é o estado único "uma porta carregando", vale para qualquer casca, e o portal não precisa conhecer o jogador.
- **O vão acende pela casca:** o `GamePortal` ganha o sinal `charge_changed(ratio)`. A `PortalShell` liga esse sinal a um método `_on_portal_charge(ratio)` (vazio por padrão), e o `CityBuilding` o usa para dar força à luz do vão. O portal continua sem saber se é prédio ou arco (regra 3).
- **Opções da câmera no `config.cfg`, seção `[controls]`** (pelo `AppConfig`, com o texto comentado como as outras seções): `camera_motion=true`, `mouse_sensitivity=1.0` (multiplicador, de 0,5 a 2,0) e `fov=75` (de 60 a 100). O jogador escuta `settings_changed`.
- **Marcos por bairro em `worlds/city/district_landmarks/`**, um script por bairro, todos herdando de `DistrictLandmark` (`Node3D`: recebe `category_id` e os `buildings` do quarteirão, e responde `get_top_y()`). O marco fica **no telhado do prédio mais alto do quarteirão do pórtico** (como a grua): não ocupa calçada nem o miolo (onde fica a mesa da Estratégia). A cidade carrega o script pelo `landmark_script` do perfil (regra 4), como já faz com o `props_script`. A altura de cada marco é calculada para o topo passar do `BuildingVariant.max_total_height()`.
- **Só emissão, nenhuma luz nova** nos marcos e na torre: luz (4.x) espera a medida no desktop.
- **Simulação fica sem `landmark_script`:** a grua (até ~51 m) já é o ponto mais alto da cidade.
- **Música = barramento + jingles, por ora** (dono, 2026-10-10). A faixa de verdade fica para quando houver uma CC0 aprovada.
- **Fundo da cidade é dado do mundo:** o `WorldProfile` ganha `ambience_bed: AmbienceSpec` (um loop 2D, sem posição, no canal "Ambiente"). Em casa, o abafado que já existe no canal "Ambiente" faz o "lá fora".
- **Passos pela superfície do chão:** quem monta um chão diz do que ele é com `set_meta("footstep", "wood")` no corpo de colisão; o jogador lê o chão em que pisa (a colisão de baixo do `move_and_slide`) e escolhe a lista de sons. Sem a marca, é concreto. Serve para grama e neve nos biomas, sem o jogador conhecer o mundo.
- **Eco de casa num canal próprio "Passos"** (envia para "Efeitos", então o volume de Efeitos continua valendo). O `AudioEffectReverb` liga e desliga com o `set_indoors`, como o abafado. Os cliques da UI não ganham eco.
- **Título do bairro é UI** (`ui/district_title.gd`), ligado ao bairro que o minimapa já calcula (`MapView` › `CityMap.area_id_at`). O `CityMap` ganha a contagem de jogos por bairro.

## Assets (aprovados pelo dono em 2026-10-10)
Baixados para uma pasta nova e vazia em `/tmp` (fora do repositório); entram só os arquivos usados, nas pastas que já têm o `License.txt` da Kenney (CC0):

| Pacote | Origem | Tamanho do zip | O que entra | Subetapa |
|---|---|---|---|---|
| Impact Sounds | kenney.nl/assets/impact-sounds (`kenney_impact-sounds.zip`) | 0,8 MB | `footstep_wood_000` a `004.ogg` (~40 KB) em `assets/kenney/impact-sounds/` | 11.10 |
| Sci-Fi Sounds | kenney.nl/assets/sci-fi-sounds (`kenney_sci-fi-sounds.zip`) | 5,9 MB | 2 sons (a carga da porta e o loop de "Outros"), escolhidos de ouvido, em `assets/kenney/sci-fi-sounds/` | 11.3 e 11.9 |

Antes de copiar, conferir a lista de arquivos dentro do zip. O `city_bed.wav` é gerado pelo `make_sounds.py` (CC0, do projeto).

## Subetapas
Ordem: o que é só UI primeiro, depois a câmera, os marcos, o som e, por último, o título do bairro (que usa o mapa já com os marcos).

| Janela | Principal (checkout `~/git/game-hub`, `fase-11`) | Paralela (New Worktree "marcos", opcional) |
|---|---|---|
| 1 | 11.0 → 11.1 → 11.2 | 11.5 (depois do commit da 11.0) |
| 2 | 11.3 → 11.4 | 11.6 |
| 3 | 11.8 → 11.9 → 11.10 | 11.7 |
| 4 | junta a paralela → 11.11 → 11.12 | — |

- **Por que essa divisão:** a principal mexe em `player/`, `ui/`, `autoload/` e som; a paralela, em `worlds/city/` (praça, marcos, `.tres` dos bairros). Quase não se cruzam.
- **Conflitos esperados (pequenos):** `profiles/districts/outros.tres` (a 11.9 põe som, a 11.7 põe marco) e `tests/check_profiles.gd` (as duas acrescentam conferências). Ao juntar, ficar com as duas mudanças. `city.gd` muda nas duas, em funções diferentes.
- **Junta (igual às fases 9 e 10):** na principal, `git merge --no-ff worktree/marcos`, bateria inteira, `[x]` com os dois hashes; apagar o worktree antes do chat.
- **Uma bateria por vez:** as duas trilhas usam o mesmo `user://`. O `run_tests.sh` tem trava; não rodar `godot -s` à mão enquanto a outra trilha testa.
- Sem worktree, tudo vai na principal, na ordem 11.0 → 11.12.

### Bloco A: sensação (principal)

- [x] **11.0 Preparação** (Sonnet · low)
  - Faz: cria a branch `fase-11` a partir da `fase-10`, salva este plano em `docs/plans/fase-11.md`, põe a "Fase 11: Sensação e marcos" no ROADMAP (em andamento) e anota a "Fase 12: Tema e controles" (5.2 e 5.3 sem a sensibilidade e o FOV) em "Próximas fases".
  - Commit: `Fase 11.0: plano`

- [x] **11.1 Curvas nas transições** (Sonnet · medium) — revisão 2.3
  - Faz:
    - `ui/screen_fade.gd`: `fade_out` com `TRANS_CUBIC` + `EASE_IN`, `fade_in` com `TRANS_CUBIC` + `EASE_OUT`.
    - `ui/toast.gd`: entrada `TRANS_CUBIC` + `EASE_OUT`; saída `EASE_IN`, subindo 6 px enquanto some.
    - `ui/hud.gd`: o cartão do que se olha aparece com fade de 0,12 s e desliza 8 px para cima (hoje é só `visible`); some com fade de 0,08 s. Trocar de alvo sem sair do cartão não repete a animação.
    - `ui/door_charge.gd`: a vinheta usa uma curva (`ease(progress, 1.8)`: fecha devagar no começo e rápido no fim); o anel continua linear (mostra o tempo de verdade).
    - `ui/controls_hint.gd` e `ui/splash_screen.gd`: saída com `EASE_IN`.
  - Teste: `tests/check_transitions.gd` (novo): no meio de um `fade_out`, a cortina está abaixo de 0,5 (EASE_IN); o cartão do HUD começa transparente e chega a 1; a vinheta com `progress = 0,5` recebe menos que 0,5. `check_toasts`, `check_door_charge` e `check_first_time` passam.
  - Manual: capturas em `/tmp` do cartão no meio da animação (gravação curta ou duas capturas seguidas).
  - Commit: `Fase 11.1: curvas nas transições`

- [x] **11.2 Câmera com peso** (Sonnet · medium; Opus se o balanço brigar com o foco da tela 3D) — revisão 6.2
  - Faz:
    - `player/camera_feel.gd` (novo, `CameraFeel`): balanço vertical de 2,5 cm e lateral de 1,2 cm na fase da passada (`_stride_progress / stride`, que já existe), afundada de 5 cm ao pousar (mola que volta em ~0,25 s, proporcional à velocidade da queda), FOV +5° correndo (suavizado). Tudo some com suavidade ao parar. Não mexe na câmera durante o foco ou a viagem.
    - `player/player.gd`: cria o `CameraFeel`, manda velocidade, passada e pouso; `AIR_CONTROL = 0.35` multiplica o `blend` no ar.
    - `autoload/app_config.gd`: seção `[controls]` (texto comentado em `ADDED_SECTIONS`) com `camera_motion=true`; `get_camera_motion()`/`set_camera_motion()`.
    - `ui/settings_view.gd` (aba Controles): `CheckButton` "Balanço da câmera" com a dica "desligue se der enjoo".
  - Teste: `tests/check_camera_feel.gd` (novo; guarda e devolve o `config.cfg`): andando, o deslocamento oscila e fica dentro de ±3 cm; ao pousar, afunda até 5 cm e volta; correndo, FOV = base + 5; com `camera_motion=false`, deslocamento 0 e FOV base; em foco numa tela 3D, a câmera fica onde o `_slide_camera` deixou. `check_interact`, `check_screen_3d`, `check_settings_view` e `check_pause_menu` passam.
  - Manual: andar e correr pela praça; pular de um banco; desligar a opção e ver a câmera parar de balançar.
  - Commit: `Fase 11.2: câmera com peso`

- [ ] **11.3 A porta pesa** (Sonnet · medium) — revisão 2.2 e parte da 2.4
  - Faz:
    - `player/camera_feel.gd`: com a carga (`ScreenFade.door_charge.get_progress()`), FOV −6° e avanço de 0,12 m, os dois com `ease` (vale mesmo com o balanço desligado: é parado e pequeno).
    - `components/game_portal/game_portal.gd`: sinal `charge_changed(ratio)`, emitido quando a carga muda (e 0 ao entrar no jogo ou ao cancelar de vez).
    - `components/portal_shell/portal_shell.gd`: liga o sinal ao `_on_portal_charge(ratio)` (vazio por padrão).
    - `worlds/city/city_building.gd`: `_on_portal_charge` multiplica a emissão do brilho do vão e do néon da porta (até ~3× no fim da carga).
    - Som: baixar o Sci-Fi Sounds (tabela de assets), ouvir as opções e trocar o `CHARGE_SOUND`; o `forceField_000` fica só nos hologramas.
  - Teste: `check_door_charge` ganha: com um portal carregando, o FOV da câmera fica abaixo da base e volta ao cancelar; o sinal chega à casca (o brilho do vão sobe e volta); o som da carga não é o do `FriendNpc`. `check_portal_shell` e `check_portal_regression` passam.
  - Manual: captura `porta_*_carga60` (antes e depois), de dia e de noite.
  - Commit: `Fase 11.3: a porta pesa`

- [ ] **11.4 Sensibilidade do mouse e FOV** (Sonnet · low) — parte da revisão 5.3
  - Faz:
    - `autoload/app_config.gd`: `mouse_sensitivity` (0,5 a 2,0; padrão 1,0) e `fov` (60 a 100; padrão 75) na `[controls]`, com get/set.
    - `player/player.gd`: o giro usa `mouse_sensitivity × multiplicador`; o `CameraFeel` usa o FOV do config como base. O foco na tela 3D já lê o `_camera.fov` atual.
    - `ui/settings_view.gd` (aba Controles): dois deslizadores ("Sensibilidade do mouse" e "Campo de visão"), com o valor ao lado e gravação atrasada, como os volumes.
  - Teste: `check_settings_view` confere os dois deslizadores e que mexer neles muda o config; `check_camera_feel` confere que o FOV base segue o config e que o giro dobra com o multiplicador 2,0. `check_screen_3d` passa com FOV 90.
  - Manual: mudar os dois com o menu aberto e sentir a diferença na hora.
  - Commit: `Fase 11.4: sensibilidade do mouse e FOV`

### Bloco B: marcos (paralela, ou principal sem worktree)

- [ ] **11.5 Torre do relógio na praça** (Sonnet · medium) — revisão 1.4 e 7.2
  - Faz:
    - `worlds/city/plaza_clock_tower.gd` (novo, `PlazaClockTower`): coluna de concreto (~1,2 m de lado) saindo do meio do chafariz, com ~18 m (a altura do prédio de 3 andares do `BuildingVariant` + 3 m); quatro mostradores de néon claro a ~15 m, com ponteiros de hora e minuto; coroa de néon que acende à noite (`city_night`). Colisão só na coluna.
    - `worlds/city/city.gd`: cria a torre junto da praça e passa o `DayNight`; a torre lê `current_hour()` uma vez por segundo. `_map.add_landmark("marco", "Torre do relógio", …)`.
    - `ui/map_view.gd`: desenha o marco como um ponto claro (no minimapa e no mapa grande).
    - `worlds/city/city_decor.gd`: as floreiras da praça ficam sem o arbusto da Kenney (só a árvore); as dos parques continuam.
  - Teste: `tests/check_landmarks.gd` (novo): a torre existe, o topo passa da altura do prédio de 3 andares, `set_hour(15.5)` põe o ponteiro das horas entre o 3 e o 4 e o dos minutos no 6; o mapa tem o marco; nenhum amigo da praça nem a estação do metrô encosta na coluna. `check_city_map`, `check_minimap` e `check_metro` passam.
  - Manual: capturas `praca_dia_chegada` e `praca_noite_chegada`, e uma de costas para a praça, a ~80 m, vendo a torre acima dos telhados.
  - Commit: `Fase 11.5: torre do relógio na praça`

- [ ] **11.6 Marcos por bairro: a estrutura e os três primeiros** (Sonnet · medium; Opus se o letreiro ou a grua brigarem com o marco) — revisão 3.3 e 3.5
  - Faz:
    - `worlds/city/district_landmarks/district_landmark.gd` (novo, `DistrictLandmark`): base com `category_id`, `buildings`, `roof_of_tallest()`, `min_height()` (o que falta para passar do `max_total_height()` + 3 m), um material de néon do bairro e `get_top_y()`.
    - Três marcos: `rpg_tower.gd` (torre de castelo com ameias e flâmula balançando), `sports_floodlights.gd` (torre de refletores de estádio) e `casual_wheel.gd` (roda-gigante girando devagar).
    - `worlds/city/city.gd`: `_build_landmark(cell, category_id, buildings)` no quarteirão do pórtico, pelo `landmark_script` do perfil; `_build_district_sign` também considera o `get_top_y()` do marco. Se o pórtico não couber, `push_warning` (revisão 3.5).
    - `profiles/district_profile.gd`: `landmark_script` sai de "Reservado" (o `density` continua reservado); `rpg.tres`, `esportes.tres`, `casual.tres` ganham o caminho.
  - Teste: `check_landmarks` ganha: com a biblioteca falsa de 200 jogos, cada bairro com `landmark_script` tem um marco, o topo passa do `max_total_height()` e o letreiro fica acima dele; `check_profiles` troca "landmark vazio" por "o script carrega e é um `DistrictLandmark`"; `check_gates` confere um pórtico por bairro com 200 jogos. `check_variants` e `check_district_props` passam.
  - Manual: capturas `bairro_noite_alto` e `bairro_dia_alto`.
  - Commit: `Fase 11.6: marcos por bairro`

- [ ] **11.7 Os outros seis marcos** (Sonnet · medium)
  - Faz, um script por bairro em `worlds/city/district_landmarks/`, todos de formas simples + néon (ponto de partida, a ajustar pelas capturas):

    | Bairro | Marco |
    |---|---|
    | acao | torre de rádio com faróis que varrem o céu à noite (só emissão, faixas de luz) |
    | cartas | dado de néon gigante girando devagar |
    | sobrevivencia (Terror) | caixa d'água enferrujada com uma luz vermelha piscando |
    | estrategia | peça de xadrez (o rei) gigante, de concreto claro com filete de néon |
    | aventura | farol com a lanterna girando |
    | outros | antena com um anel holográfico girando |

    Os `.tres` ganham o `landmark_script`; a Simulação continua vazia (a grua).
  - Teste: `check_landmarks` passa a exigir marco em todos os bairros menos a Simulação; `check_profiles` confere isso.
  - Manual: capturas de cima (`bairro_dia_alto`) e da praça à noite, com os dez bairros.
  - Medida: `tools/medir_desempenho.gd -- 200 leve 22`, antes e depois (os marcos somam desenhos).
  - Commit: `Fase 11.7: os outros marcos`

### Bloco C: som (principal)

- [ ] **11.8 Canal de música** (Sonnet · low) — revisão 6.1 (parte)
  - Faz: `default_bus_layout.tres` ganha "Música" (envia para Master); `AppConfig.VOLUME_KEYS` e o texto da `[audio]` ganham `music_volume` (padrão 0,7, também para quem já tem o arquivo); `SettingsView.VOLUME_ROWS` ganha a linha "Música"; o jingle de "cidade pronta" (`city.gd`) passa a tocar nesse canal.
  - Teste: `check_phase6_audio` passa a esperar quatro canais; `check_settings_view` confere quatro deslizadores; `check_home_start` confere o canal do jingle.
  - Commit: `Fase 11.8: canal de música`

- [ ] **11.9 Fundo da cidade e som de "Outros"** (Sonnet · medium) — revisão 6.1 e 7.3
  - Faz:
    - `assets/generated/make_sounds.py`: `city_bed.wav` (12 s, emenda sem pulo): vento grave + um "rumor" de trânsito distante que sobe e desce. `assets/generated/LICENSE.txt` (CC0) e as linhas do `metro_ride.wav` e do `city_bed.wav` nos créditos do README (revisão 7.3).
    - `profiles/world_profile.gd`: `ambience_bed: AmbienceSpec`; `profiles/world_profile.tres` usa o `city_bed.wav` a ~−22 dB.
    - `worlds/city/city.gd`: um `AudioStreamPlayer` (2D) no canal "Ambiente" toca o fundo do perfil, em loop.
    - `profiles/districts/outros.tres`: um `AmbienceSpec` de loop com o som sci-fi escolhido.
  - Teste: `check_phase6_audio` ganha: o fundo existe, toca em loop no canal "Ambiente" e vem do perfil; "Outros" tem emissor. `check_profiles` confere o `ambience_bed` e o som de "Outros". `assets/generated/LICENSE.txt` existe.
  - Manual: andar entre dois bairros e ouvir o fundo no lugar do silêncio; entrar em casa e ouvir o fundo abafado.
  - Commit: `Fase 11.9: fundo da cidade e som de Outros`

- [ ] **11.10 A casa soa como casa** (Sonnet · medium) — revisão 2.4 e 6.1
  - Faz:
    - Baixar o Impact Sounds (tabela de assets) e copiar os cinco `footstep_wood_*.ogg`.
    - `player/player.gd`: `FOOTSTEP_SOUNDS` vira uma tabela por superfície (`"concrete"`, `"wood"`); depois do `move_and_slide`, o jogador lê a marca `footstep` do chão em que pisa (padrão `"concrete"`). Passos e pulo vão para o canal "Passos"; o `set_indoors` liga e desliga o eco (`AudioEffectReverb`, sala pequena, ~12% de eco) nesse canal, como o abafado.
    - `default_bus_layout.tres`: canal "Passos" (envia para "Efeitos").
    - `worlds/home/home.gd`: o piso (e o tapete) com `set_meta("footstep", "wood")`.
  - Teste: `tests/check_footsteps.gd` (novo): no chão da casa, a superfície é `"wood"` e o som sai da lista de madeira; no chão da cidade, `"concrete"`; `set_indoors(ambiente)` liga o eco e `set_indoors(null)` desliga; "Passos" envia para "Efeitos". `check_home` e `check_phase6_audio` passam.
  - Manual: andar na casa (madeira, com eco leve) e sair para a praça (concreto, seco).
  - Commit: `Fase 11.10: passos de madeira e eco em casa`

### Bloco D: fechamento (principal, depois da junta)

- [ ] **11.11 Título ao entrar no bairro** (Sonnet · medium) — revisão 3.4
  - Faz:
    - `worlds/city/city_map.gd`: `area_games(id)` (quantos jogos o bairro tem).
    - `ui/district_title.gd` (novo, `DistrictTitle`): nome do bairro grande, na cor néon, e "12 jogos" embaixo, no alto da tela, abaixo da bússola; entra com fade e desliza (curvas da 11.1), fica ~2,5 s e sai. Um som curto (`interface-sounds/glass_001.ogg`, baixinho).
    - `ui/hud.gd`: liga o título ao bairro que o minimapa calcula (`MapView`). Não repete o mesmo bairro antes de 20 s (na divisa, não pisca). Na praça e em casa, nada.
  - Teste: `tests/check_district_title.gd` (novo): pôr o jogador num quarteirão de um bairro mostra o título com o nome e a contagem; voltar logo ao mesmo bairro não mostra de novo; a praça não mostra. `check_minimap` e `check_compass` passam.
  - Manual: atravessar um pórtico a pé e chegar a um bairro por viagem rápida (Shift+Enter).
  - Commit: `Fase 11.11: título ao entrar no bairro`

- [ ] **11.12 Medida e docs** (Sonnet · low)
  - Faz:
    - medida no notebook, `fase-10` × `fase-11` intercaladas (Leve, 22 h, 200 jogos; e 30 jogos ao meio-dia), anotada em "Decisões";
    - README (porta e câmera, opções novas, torre e marcos, sons, título do bairro, créditos), ROADMAP (Fase 11 feita), `tests/README.md` (testes novos), CLAUDE.md ("Feito: fases 1–11");
    - na revisão, uma linha dizendo quais itens a Fase 11 fez;
    - plano marcado.
  - Commit: `Fase 11.12: documentação`

## Riscos
- **Balanço x foco na tela 3D e viagem:** o `CameraFeel` mexendo na câmera durante o `_slide_camera` faria a câmera tremer no computador. Ele fica parado nesses casos; o `check_camera_feel` e o `check_screen_3d` pegam.
- **Enjoo:** valores pequenos (2,5 cm, 5°) e uma opção para desligar desde a 11.2.
- **O FOV da carga briga com o FOV de corrida ou com o do config:** um só lugar soma tudo (o `CameraFeel`), com a base do config.
- **Marcos no telhado atravessam a grua ou o letreiro:** o letreiro já sobe acima dos `get_top_y()`; a Simulação não tem marco. `check_landmarks` e `check_variants` conferem.
- **Marcos pesam no notebook:** formas simples, sem luz nova; medida na 11.7 e na 11.12.
- **Eco ou fundo alto demais:** volumes baixos de partida, ajustados de ouvido; o fundo fica no canal "Ambiente" (o deslizador já existe).
- **`config.cfg` antigo sem `music_volume` ou `[controls]`:** os padrões valem sem a linha; a seção nova entra pelo `ADDED_SECTIONS`.
- **Testes que gravam no `config.cfg`:** `check_camera_feel` e `check_settings_view` guardam e devolvem o arquivo, como o `check_pause_menu`.
- **Conflitos na junta da paralela:** só `outros.tres` e `check_profiles.gd` (veja acima).

## Fora do escopo
- **Fase 12: Tema e controles** — tema único (5.2) e menu por teclado e controle, com as ações de controle no `project.godot` (5.3, sem a sensibilidade e o FOV, que entram aqui).
- Luz (4.1–4.4) e `distance_fade` dos postes (8.2): dependem da medida no desktop (a partir de 18/10).
- Uma faixa de música de verdade: espera uma CC0 aprovada pelo dono.
- Loops de Esportes e Terror tocando sempre (nota da Fase 8): é desempenho, e espera a medida no desktop.
- Uma direção de arte única (7.2, além do arbusto da praça): fica para os biomas.
- "Segurar E" para entrar nos prédios (dono: fica o vão).

## Decisões tomadas durante a fase
- 2026-10-10: fase dividida em 11 (sensação e marcos) e 12 (tema e controles); música = barramento + jingles; marco da praça = torre do relógio; aprovados os pacotes Impact Sounds e Sci-Fi Sounds da Kenney (dono).

## Checklist de teste manual (fim da fase)
No notebook (Omarchy), qualidade **Leve**, depois **Alta**:
1. Aperte F5. Em casa, ande: os passos são de madeira, com um eco leve. Lá fora, o som da cidade chega abafado.
2. Saia para a praça. No meio do chafariz, a torre do relógio marca a hora da cidade (aperte F8 e veja os ponteiros pularem 3 horas). No minimapa, ela aparece como um ponto.
3. Ande e corra: a câmera balança de leve e abre um pouco correndo. Pule de um banco: ela afunda ao pousar.
4. Pare no vão de um prédio: a câmera fecha devagar, o vão acende e o zumbido é novo. Recue: tudo volta.
5. Atravesse um pórtico: aparece o nome do bairro e quantos jogos ele tem. De longe, cada bairro tem um marco acima dos telhados, com o letreiro em cima.
6. Ande entre dois bairros: em vez de silêncio, um fundo baixinho de vento e trânsito. Vá até "Outros": ele também tem som.
7. Esc › Controles: desligue "Balanço da câmera" (a câmera para de balançar), mude a sensibilidade e o campo de visão (vale na hora). Em Som e vídeo, há o deslizador "Música".
8. Feche e abra de novo: as opções continuam como você deixou.

## Verificação
1. `bash tests/run_tests.sh` ao fim de cada subetapa: `RESULTADO GERAL: TUDO OK` (uma bateria por vez entre as trilhas).
2. Capturas com janela (11.1, 11.3, 11.5, 11.6, 11.7), só em `/tmp`, nunca no repositório (mostram capas).
3. Medida com `tools/medir_desempenho.gd`, `fase-10` × `fase-11` intercaladas no mesmo dia (11.7 e 11.12). O desktop continua sendo a régua de verdade, a partir de 18/10.
