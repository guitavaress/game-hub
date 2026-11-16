# Fase 20: Primeira e terceira pessoa

**Status:** aprovado em 2026-11-16; em andamento
**Branch:** `fase-20`, criada da `main` (`c0bda53`).

## Para o dono (até 10 linhas)
- **O que você vai ver quando a fase acabar:** uma tecla (V) e um botão do controle alternam a visão. Na terceira pessoa, a câmera fica atrás do ombro do seu avatar e você o vê andar, correr e pular pela cidade e pela casa, sem a câmera entrar em parede. Na primeira, ao olhar para baixo, você vê o seu corpo andando, e ele faz sombra no chão.
- **Ordem:** o corpo aprende a andar sem deslizar → a tecla e a opção no menu → o corpo em primeira pessoa (e o espelho passa a mostrar o corpo de verdade) → a câmera em terceira pessoa → tudo o que depende da visão (E, portas, luneta, mesa, espelho) → medida e fechamento.
- **Para testar:** cada subetapa traz o próprio checklist.
- **Decisões que esperam você:** (1) na amostra da 20.4, o jeito da terceira pessoa: câmera sobre o ombro com o avatar sempre de costas (recomendado, igual à primeira pessoa nos controles) ou avatar que vira para onde anda; (2) o botão do controle (proposto: clique do analógico direito, se estiver livre); (3) se a fase fecha com um Release 0.20.0.

## Contexto
É a fase [8. Primeira e terceira pessoa](../ROADMAP.md#8-primeira-e-terceira-pessoa), escolhida pelo dono em 2026-11-16 para ser a Fase 20 (passa à frente de Visitar amigos, da janela, dos amigos andando e de instalar jogos). Dá mudança visível logo, e o corpo que anda aqui é a mesma peça dos amigos andando e do "V4 ao vivo".

O que já existe (lido em 2026-11-16):
- **Jogador** (`player/player.gd`, `player/player.tscn`): `CharacterBody3D` com `Head` (1,6 m) › `Camera3D` › `LookRay` (30 m, máscara 5). O corpo gira no Y, a cabeça no X. A câmera **não vê** a camada 19 (`AvatarBody.REFLECTION_LAYER`). O foco numa tela (`focus_on`, `_slide_camera`, `leave_focus`) desliza a câmera e a devolve para `_head.global_transform * _camera_rest`.
- **`CameraFeel`** (`player/camera_feel.gd`): balanço, pouso, FOV da corrida e da porta, sempre como deslocamento sobre `_rest`.
- **`AvatarBody`** (`components/avatar/avatar_body.gd`): carrega `assets/quaternius/animated_human.glb` (uma malha só, `Human_Mesh`), ajusta a altura, pinta por faixa de UV e toca só `Idle` e `Walk`. O modelo **já tem** `Run` e `Jump` (e Death, Punch, Working), e os ossos `Neck`/`Head`.
- **Espelho** (`worlds/home/home_mirror.gd`): cria um corpo **próprio** (`ReflectionBody`) na camada 19, que segue o jogador (`_follow`) só enquanto o espelho desenha; no provador, fica parado em `FITTING_SPOT`.
- **Casa** (`worlds/home/home.gd`): tudo o que ela desenha vai para a camada 20 (`INTERIOR_LAYER`); as luzes dela só iluminam a 20, e o sol da cidade não ilumina a 20. Chama `player.set_indoors(ambiente)` ao entrar e `set_indoors(null)` ao sair.
- **Quem usa o foco:** `Screen3D`, `DeskMonitor3D`, `HomeMirror`, `LookoutTelescope`.
- **Config e menu:** o padrão é o do "Balanço da câmera" (`AppConfig.get/set_camera_motion`, linha em `ui/settings_view.gd`, `settings_changed`).
- **Testes vizinhos:** `check_avatar`, `check_mirror`, `check_camera_feel`, `check_gamepad`, `check_menu_keyboard`, `check_avatar_panel`.

## Pronto quando
- V (e o botão do controle) alterna a visão em qualquer lugar onde se anda; a escolha volta ao reabrir o hub e aparece em Esc › Controles e no cartão de controles.
- Terceira pessoa: o avatar anda, corre e pula com o passo casado à velocidade; encostado numa parede, num prédio, numa árvore ou no teto da casa, a câmera se aproxima e não atravessa.
- Primeira pessoa: olhando para baixo, vê-se tronco, braços, pernas e pés (sem a cabeça na frente da câmera), andando junto.
- O corpo faz sombra nas duas visões, na cidade e na casa; o espelho mostra o corpo inteiro, com cabeça, nas duas.
- E para interagir, entrar numa porta de jogo, luneta, mesa com monitores, telas, provador, mapa, busca, metrô e viagem rápida funcionam igual nas duas visões.
- Desktop, Alta, 200 jogos: a caminhada não cai mais que 3% em relação à medida do começo da fase (`tools/medir_desempenho.gd`, pelo `tools/com_trava.sh`).
- Regras: nada em `autoload/` conhece mundo; o andar mora em `components/avatar/`; a casa e a cidade não ganham lógica de visão.

## Decisões de arquitetura
- **O andar é do `AvatarBody`, e não do jogador.** Uma função só, `animate(velocidade_horizontal, no_chão)`, escolhe Idle, Walk, Run ou Jump, mistura as trocas (tempo de blend do `AnimationPlayer`) e acerta o `speed_scale` pela velocidade real (passada medida do modelo, guardada como constante), para o pé não deslizar. `play_idle`/`play_walk` continuam (os hologramas usam). Os amigos andando reaproveitam isto.
  Descartado: `AnimationTree` com blend space (mais nós e mais estado para quatro animações).
- **Um "rig" do jogador com dois corpos**, num arquivo novo `player/player_avatar.gd` (filho do `Player`, criado por código):
  - o **inteiro**: é o que a terceira pessoa mostra, o que o espelho reflete e o que faz a sombra (com cabeça) nas duas visões;
  - o **de primeira pessoa**: o mesmo modelo com o osso `Head` (ou `Neck`) encolhido, sem sombra, visto só pela câmera do jogador e só na primeira pessoa. Na primeira pessoa, o inteiro fica numa camada que a câmera do jogador não vê (a 19, que já existe), mas continua fazendo sombra e aparecendo no espelho.
  Descartado: um corpo só com a cabeça cortada no shader (a malha é única e a sombra perderia a cabeça); cortar a malha no Blender (o modelo é da Quaternius, CC0, e ficaria com duas versões).
- **Camadas seguem "dentro/fora".** O rig troca as camadas dos corpos ao entrar e ao sair de casa, para a luz da casa iluminar o corpo dentro e o sol iluminar fora. As luzes da casa que usam máscara passam por uma função só (`Home.light_layers()`).
  - **Como ficou na 20.3** (mudou em relação ao plano aprovado): a camada 18 já era das placas dos bairros, então o corpo que só a câmera do jogador vê usa a **17 fora de casa** e a **16 dentro**; o inteiro fica na **19** (a do reflexo, que já existia). O sol do mundo não acende a 16 nem a 19. O espelho vê a 20 e a 19; a janela (`WindowView`) esconde a 16, a 17 e a 19. O segundo argumento do `set_indoors` não entrou: pôr o corpo na camada 20 faria o espelho ver o corpo sem cabeça.
- **O espelho deixa de ter corpo próprio.** O `HomeMirror` usa o corpo inteiro do jogador (acha pelo grupo `player`, como hoje, e pede `get_avatar()`); o `_follow` sai. No provador, ele pede ao rig para ficar parado no `FITTING_SPOT`, e o avatar passa a aparecer também "ao vivo", na frente do vidro.
- **A câmera em terceira pessoa é um `SpringArm3D`** (peça da Godot que encurta o braço quando bate em algo), preso à `Head`, com deslocamento para o ombro direito. A câmera continua sendo a mesma `Camera3D` (tudo o que pergunta `get_camera_3d()` segue funcionando). Trocar de visão anima o comprimento do braço de 0 ao valor da visão (0 = primeira pessoa), então a passagem é contínua. Comprimento menor dentro de casa. Valores como constantes no topo do arquivo.
  Descartado: duas câmeras (o espelho, a placa do bairro e os monitores leem a câmera atual; o `CameraFeel` teria dois donos).
- **`CameraFeel` passa a receber o repouso de quem manda** (`set_rest`), em vez de guardar um fixo: na terceira pessoa, o balanço lateral e o vertical desligam (o corpo já balança); o pouso, o FOV da corrida e o da porta continuam.
- **O raio do olhar continua na câmera.** Na terceira pessoa, ele alonga pelo comprimento do braço e ignora o que estiver entre a câmera e o avatar; o alcance do E é medido a partir do avatar, para não dar para interagir de mais longe que hoje.
- **No foco** (tela, mesa, luneta), o corpo some e a câmera vai e volta como hoje; a volta usa o repouso da visão atual. O provador é a exceção: o corpo aparece.
- **Dado salvo:** `config.cfg`, `[controls] view` = `first` (padrão) ou `third`. Ação nova `toggle_view` no `project.godot` (V; botão do controle conferido contra o `check_gamepad`).
- **Assets:** nenhum download. Nenhum `.tres` muda.

## Subetapas
Trilha A: checkout principal (Opus coordena e faz as grandes, uma por vez). Trilha B: worktree criado da `fase-20`, Sonnet (`--agent claude --model claude-sonnet-5-5 --effort medium`); a B roda só os testes do que mudou, e a bateria completa roda no merge.

- [x] **20.0 Branch, docs e medida de partida** (só de docs · coordenador · medium) — 2026-11-16; commit `Docs: plano da Fase 20`
  - **Medida de partida** (desktop, RTX 4070, Alta, 200 jogos, 13 h, tempo limpo, 2560x1440, vsync a 165 Hz; `medir_desempenho.gd -- 200 alta 13 limpo`, duas vezes): caminhada **149,4 e 148,0 FPS** (p99 12 ms; pior 36 e 34 ms; ~2560 desenhos); casa **164,9** (p99 8 ms, 193 desenhos); espelho **164,9 e 164,8** (p99 7 ms, 115 desenhos); montanha **162,7** (p99 10 ms); montagem 9,5 s. A casa, o espelho e a montanha encostam no teto do vsync (165): ali, compare o p99 e os desenhos.
  - Faz: cria a `fase-20`; grava este plano em `docs/plans/fase-20.md`; a ROADMAP diz que o item 8 é a Fase 20, em andamento; `Início.md` (fase atual, linha no gantt). Mede a caminhada no desktop (Alta, 200 jogos) e anota o número aqui.
  - Arquivos: `docs/plans/fase-20.md` (novo), `docs/ROADMAP.md`, `docs/Início.md`.
  - Commit: `Docs: plano da Fase 20`
- [x] **20.1 O corpo aprende a andar** (pequena · Sonnet, trilha B · medium) — 2026-11-16; `aee6ef2` (trilha B), merge `0de17a3`, bateria completa ok
  - **Entregue:** `animate(horizontal_speed, on_floor)`, `set_head_hidden(on)`/`is_head_hidden()`, `enum ShadowMode { NORMAL, OFF, SHADOWS_ONLY }` com `set_shadow_mode`/`get_shadow_mode`. A cabeça é encolhida por um `SkeletonModifier3D` (`HeadHider`), que roda depois da animação: vale só para o quadro desenhado (a pose guardada do osso segue com escala 1).
  - **Passada medida** (osso `LeftFoot`, 60 quadros por ciclo, altura de 1,7 m): Walk 1,585 m por ciclo de 1,0 s; Run 2,362 m por ciclo de 0,625 s. Cadência limitada a 0,5–3,2.
  - **Pendência para a 20.3:** o jogador anda a 5 m/s, o que dá cadência 3,15 no Walk (passo acelerado demais). Candidato: baixar o `RUN_THRESHOLD` de 7 para cerca de 3,5 (5 m/s vira Run a 1,32; 9 m/s, Run a 2,38), decidido pela captura. A passada não acompanha uma altura diferente de 1,7 m. O Jump toca uma vez e segura a pose (não há animação de pouso).
  - Faz: `AvatarBody.animate(speed, on_floor)` com Idle/Walk/Run/Jump, blend e cadência casada; `set_head_hidden(on)` (encolhe o osso da cabeça); `set_shadow_mode(...)` (normal, sem sombra, só sombra). Nada muda na tela ainda.
  - Arquivos: `components/avatar/avatar_body.gd`, `tests/check_avatar.gd`.
  - Teste: `check_avatar` (a animação certa por velocidade; o `speed_scale` cresce com a velocidade; a cabeça encolhe e volta), mais `check_mirror` e `check_friends_wall` (nada quebrou).
  - Commit: `Fase 20.1: o avatar anda, corre e pula pela velocidade`
- [x] **20.2 A tecla, a opção e as dicas** (pequena · Sonnet, trilha B, depois da 20.1 · medium) — 2026-11-16; `f3e3b44` (trilha B), merge `1e466c3`, bateria completa ok
  - **Entregue:** a ação `toggle_view` (V e o botão 8, o clique do analógico direito, "R3"); `AppConfig.VIEW_FIRST`/`VIEW_THIRD`, `get_view()` e `set_view()` (`[controls] view`); a linha "Visão" em Esc › Controles; "V / R3 — trocar a visão" na lista de teclas; "V visão" no cartão de controles (`InputDevice.HINTS["view"]`). O `Player` ainda não reage (20.4). Mexeu também em `autoload/input_device.gd`. Capturas em `C:\Projetos\game-hub-referencias\fase-20\20.2\`.
  - Faz: ação `toggle_view`; `AppConfig.get_view()/set_view()`; a linha "Visão" em Esc › Controles; a tecla no cartão de controles e no `KeyHint`. O `Player` ainda não reage.
  - Arquivos: `project.godot`, `autoload/app_config.gd`, `ui/settings_view.gd`, o cartão de controles em `ui/`, `tests/check_gamepad.gd`, `tests/check_menu_keyboard.gd`.
  - Teste: os dois acima.
  - Manual: Esc › Controles mostra "Visão"; trocar grava no `config.cfg`.
  - Commit: `Fase 20.2: tecla e opção de visão`
- [x] **20.3 O seu corpo em primeira pessoa** (grande · Opus, sessão nova, trilha A · high · revisão de risco: segundo Opus, só leitura) — 2026-11-16; `1dc947d`, bateria completa ok (repetida pela coordenadora)
  - **Entregue:** `player/player_avatar.gd` (`PlayerAvatar`: `animate`, `set_indoors`, `set_hidden`, `set_view`, `hold_pose`/`release_pose`, `get_full_body`/`get_first_person_body`; `FIRST_PERSON_BACK = 0,2 m`); `Player.get_avatar()`; no `AvatarBody`, `set_shadow_twin_layers`, `view_layers(indoors)`, `indoor_layers()`, `player_layers()`, `VIEW_LAYER = 17`, `INDOOR_VIEW_LAYER = 16`, `HIDDEN_HEAD_BONE = "Neck"`; `Home.light_layers()`. O espelho usa o corpo do jogador (saíram o `ReflectionBody` e o `_follow`). `tools/capturar_corpo.gd` (novo) tira as fotos pela câmera do jogador; as outras duas ferramentas de captura escondem o corpo.
  - **Sombra:** na Godot 4.7.2, um corpo numa camada que a câmera não vê **não faz sombra**. Ficou o caminho reserva, com um ajuste: o inteiro segue na camada 19 (para o espelho) e uma cópia "só sombra" da malha, no mesmo esqueleto, faz a sombra numa camada que a câmera vê.
  - **Cadência:** `RUN_THRESHOLD` de 7 para 3,5 m/s (andando a 5 m/s, Run a 1,32; correndo a 9 m/s, a 2,38). O `near` da câmera não mudou (0,05).
  - **Medida** (mesmo comando da 20.0): caminhada **151,3 e 148,5 FPS** (p99 11 e 12 ms), sem queda. Casa e espelho no teto do vsync, com mais desenhos (casa 193 → 290; espelho 115 → 151): a cópia da sombra se mexe o tempo todo, e cada luz com sombra redesenha os móveis a cada quadro (hipótese da revisão; a 20.3.1 mede).
  - **Revisão de risco** (segundo Opus, só leitura): **nada grave**. Médio, para a 20.4: na terceira pessoa o `_hidden` não escondia o corpo inteiro (corrigido na 20.3.1). Baixos: o custo em casa, uma conferência vazia no `check_mirror`, e este plano citando a camada 18. Para a 20.4: o `SpringArm3D` tem de ignorar a cápsula do jogador; com o braço encolhido abaixo de ~0,5 m, a câmera entra na cabeça (voltar à primeira pessoa); o espelho mede a distância pela câmera e quase não liga com o braço de ~3 m; o corpo segue o giro do `Player`.
  - Capturas em `C:\Projetos\game-hub-referencias\fase-20\20.3\`.
- [x] **20.3.1 Correções do corpo** (pequena no escopo, com bateria completa · Opus, trilha A · medium) — pedida pela coordenadora ao ver as capturas; 2026-11-16; `7d77f27`, bateria completa ok
  - **Entregue:** `FIRST_PERSON_BACK` de 0,2 para 0,3 m (olhando reto para a frente, o corpo fica fora da tela andando e correndo; a −30°, o braço não passa mais pelo centro; a tampa do pescoço saiu da tela). O `hold_pose` toca o Idle na hora, sem mistura. `full_seen := (_view == VIEW_THIRD and not _hidden) or _posed`. `AvatarBody.AIR_GRACE = 0,15 s` antes do Jump (descer uma guia não faz o corpo pular). O `check_mirror` confere a camada que a câmera do espelho vê.
  - **Custo da sombra em casa** (medido com e sem a cópia, duas rodadas): casa 287/290 desenhos com, 191/190 sem; espelho 150/151 com, 116 sem. FPS (164,9) e p99 (8 e 7 ms) iguais nos dois casos, no teto do vsync. **Fica como está**, salvo decisão do dono.
  - **Pendências para o dono:** a pose parada do modelo (o Idle da Quaternius é uma "postura de guarda", com um pé à frente; no provador parece um passo; trocar pede outra animação); com o recuo de 0,3 m, a ~35° para baixo aparece menos corpo que antes (0,25 m é o meio-termo, com risco de o braço voltar ao centro).
  - Capturas em `C:\Projetos\game-hub-referencias\fase-20\20.3.1\`.
  - Faz: o braço não cruza mais o meio da tela andando e correndo; a tampa do pescoço fica discreta ao olhar reto para baixo; o avatar fica parado no provador; o `_hidden` vale na terceira pessoa; uma tolerância curta no ar antes do Jump; a conferência vazia do `check_mirror`; a medida do custo da sombra em casa (só medir).
  - Commit: `Fase 20.3.1: correções do corpo em primeira pessoa`
  - Faz: `player/player_avatar.gd` (os dois corpos, as camadas, dentro/fora, a sombra); o `Player` cria o rig e o alimenta com a velocidade; `set_indoors(ambiente, camadas)`; as luzes da casa iluminam as camadas do corpo; o espelho passa a usar o corpo do jogador (sai o `ReflectionBody` e o `_follow`); o provador pede a pose parada. Acerta a posição do corpo para a câmera não ver o próprio pescoço ao olhar para baixo.
  - Arquivos: `player/player_avatar.gd` (novo), `player/player.gd`, `worlds/home/home.gd`, `worlds/home/home_mirror.gd`, `tests/check_player_avatar.gd` (novo), `tests/check_mirror.gd`, `tests/check_avatar_panel.gd`.
  - Teste: bateria completa. O teste novo confere: a câmera não vê o corpo inteiro na primeira pessoa e vê o de primeira pessoa; as camadas trocam ao entrar e sair de casa; o espelho enxerga o inteiro.
  - Capturas (fora do repositório, `C:\Projetos\game-hub-referencias\fase-20\20.3\`): olhando para baixo parado e andando, na praça de dia e de noite e na casa; a sombra; o espelho; o provador.
  - Manual: andar olhando para baixo na cidade e em casa; conferir a sombra com cabeça; olhar o espelho; abrir o provador.
  - Commit: `Fase 20.3: o corpo em primeira pessoa`
- [x] **20.4 A câmera em terceira pessoa** (grande · Opus, sessão nova, trilha A · high) — 2026-11-16; `67fe3ec`, bateria completa ok (relatada pelo worker; `check_third_person` com 57 conferências)
  - **Entregue:** `Player.toggle_view()`, `get_view()`, `is_third_person()`, `is_view_settled()`, `get_camera_arm()`, `get_arm_length()` e a variável `third_person_style`; `CameraFeel.set_rest(rest, bob)`/`get_rest()`; `PlayerAvatar.animate(velocidade, no_chão, backwards)` (andando de ré, o passo toca ao contrário). `tools/capturar_terceira.gd` (novo).
  - **Como ficou:** a câmera continua em `Head/Camera3D` (13 arquivos usam esse caminho): o `SpringArm3D` só mede o espaço, e o jogador põe a câmera na ponta. O braço bate só no mundo, ignora a cápsula e fica desligado na primeira pessoa. Constantes no topo do `player.gd`: braço de 3,0 m na rua e 1,8 m em casa; ombro 0,3 m à direita; 0,25 m acima da cabeça; margem 0,05 m; com o braço abaixo de 0,5 m o corpo inteiro some da câmera (a sombra fica); passagem de 0,35 s; na terceira pessoa o olhar vai até 70° para cima e para baixo. O raio do olhar sai do ombro e o alcance (30 m) é medido da cabeça. O espelho mede a distância pelo jogador. Trocar a opção no menu vale ao fechar o menu (o mundo fica pausado atrás dele).
  - **As duas variantes** (decisão 1 do dono): `THIRD_PERSON_STYLE` no topo de `player/player.gd`, `STYLE_SHOULDER` (padrão: o avatar sempre de costas, girando com o mouse) ou `STYLE_FREE` (o mouse gira só a câmera, e o avatar vira para onde anda). Capturas das duas em `C:\Projetos\game-hub-referencias\fase-20\20.4\ombro\` e `...\livre\` (a diferença aparece em `praca_lado` e `praca_tras`).
  - **Medida** (mesmo comando da 20.0): primeira pessoa **149,4 e 145,6 FPS**, terceira **148,3 e 146,8** (p99 12 ms nas quatro). A pior rodada fica 2,5% abaixo da melhor da partida, dentro da meta de 3%. Em casa, a terceira pessoa desenha mais (291 → 423), porque a câmera vê mais da sala; segue no teto do vsync.
  - **Defeito visto pela coordenadora, para a 20.5:** na floresta (`floresta_13h.png`), a câmera fica dentro dos galhos de uma árvore, que tapam a tela (as copas não têm colisão). As luminárias penduradas da casa também não têm.
  - **Outras pendências:** encostado numa parede o corpo some (pode estranhar); girando muito rápido rente a uma parede a câmera pode encostar nela por um instante; testes vizinhos supõem a primeira pessoa (só os que mudaram a forçam).
  - Faz: o `SpringArm3D` e o ombro; V alterna com a passagem animada; o `CameraFeel` com `set_rest` e o balanço desligado na terceira; o raio do olhar e o alcance do E; o comprimento menor em casa; a escolha lida e gravada no `config.cfg`. **Entrega uma amostra** (capturas das duas opções da decisão 1) antes de fechar.
  - Arquivos: `player/player.gd`, `player/player.tscn` (só se o braço não puder ser criado por código), `player/camera_feel.gd`, `player/player_avatar.gd`, `tests/check_third_person.gd` (novo), `tests/check_camera_feel.gd`.
  - Teste: bateria completa. O teste novo confere: o braço encurta contra uma parede; alternar troca quais corpos a câmera vê; o E continua achando o alvo e respeitando o alcance; a visão volta do `config.cfg`.
  - Capturas: por trás na praça, numa rua estreita, encostado num prédio, na floresta, na casa (teto e paredes).
  - Commit: `Fase 20.4: a câmera em terceira pessoa`
- [ ] **20.5 O que depende da visão** (grande · Opus, trilha A · medium)
  - Faz também (acrescentado em 2026-11-16, depois das capturas da 20.4): **a câmera não fica dentro da copa das árvores nem das luminárias**. O mundo dá a esses enfeites um volume simples numa camada de física só da câmera (o braço bate nele; o jogador não), e os testes passam a não depender da visão gravada no `config.cfg`.
  - Faz: foco (telas, mesa, luneta: o corpo some, a câmera volta ao repouso da visão atual); provador nas duas visões; entrar numa porta de jogo e voltar dela; `teleport_to`, viagem rápida e metrô; a abertura; o som dos passos casado com o passo da animação, se a amostra pedir.
  - Arquivos: `player/player.gd`, `player/player_avatar.gd`, e só o necessário em `components/screen_3d/`, `components/desk_monitor_3d/`, `worlds/city/biome/lookout_telescope.gd`; `tests/check_third_person.gd` e os testes de foco existentes (`check_screen_3d`, `check_desk_monitors`, `check_home`, `check_door_charge`).
  - Teste: bateria completa.
  - Manual: nas duas visões, abrir um jogo por uma porta, usar a luneta, sentar na mesa (Linux), usar o computador, o provador, o mapa, a busca e o metrô.
  - Commit: `Fase 20.5: tudo funciona nas duas visões`
- [ ] **20.6 Medida e fechamento** (grande · Opus coordena; Haiku nos docs · medium)
  - Faz: bateria completa; a mesma medida da 20.0, nas duas visões; README (o que mudou para quem usa), ROADMAP (fase feita), `Início.md`; versão 0.20.0 só se o dono pedir o Release.
  - Commit: `Docs: fechamento da Fase 20`

## Riscos
- **Luz e camadas** (o maior): o corpo aparecer preto dentro de casa, ou iluminado pelo sol através do telhado. Percebe-se já nas capturas da 20.3; por isso ela vem antes da câmera e tem revisão de risco.
- **Sombra de quem a câmera não vê:** a Godot faz sombra pela luz, e não pela câmera, mas isso se confirma no primeiro passo da 20.3. Se não valer, o corpo inteiro vira "só sombra" numa camada visível.
- **O pé desliza:** a passada do modelo é medida uma vez; se a corrida (9 m/s) ficar rápida demais para a animação `Run`, a cadência satura e o fato fica registrado.
- **Câmera na casa:** a sala tem 9 × 7 m e teto de 3 m; se a terceira pessoa ficar ruim, a casa força um braço bem curto (decisão na 20.4, com captura).
- **Testes que supõem o `ReflectionBody`:** `check_mirror` e `check_avatar_panel` mudam na 20.3.
- **Dois erros iguais** em camadas ou no braço: voltar ao modo plano.

## Fora do escopo
- Amigos andando pela cidade (item 6 da ROADMAP): só reaproveitam o `animate`.
- Roupas, peças novas de avatar, animações novas ou modelo novo.
- Mira diferente, emotes, câmera livre ou modo foto (ideia nova vai para `docs/ideias/`).
- Refazer o espelho (resolução, reflexo da cidade).

## Decisões tomadas durante a fase
- 2026-11-16: o item 8 da ROADMAP vira a Fase 20, por escolha do dono.
- 2026-11-16 (20.2): o botão do controle é o clique do analógico direito (R3, índice 8), que estava livre. Falta o dono confirmar.
- 2026-11-16 (20.3): a sombra vem de uma cópia "só sombra" da malha, porque a Godot só faz sombra de quem a câmera vê; as camadas do corpo são 17 (fora), 16 (dentro) e 19 (o inteiro); o `set_indoors` ficou com um argumento só. Os conceitos "dentro de casa" e "o seu corpo" ficaram no `AvatarBody` (camadas), porque movê-los para `player/` faria a casa e a cidade dependerem do jogador (a revisão recomendou deixar).

## Checklist de teste manual (fim da fase)
1. Abrir o hub pelo editor (F5). Em casa, olhar para baixo: o corpo aparece, sem cabeça na frente.
2. Andar até o espelho: o reflexo tem o corpo inteiro. E no espelho: o provador abre e o avatar fica parado na frente do vidro.
3. Apertar V: a câmera sai para trás do ombro. Andar pela sala encostando nas paredes: a câmera não atravessa.
4. Sair para a cidade, andar, correr (Shift) e pular: o passo acompanha, e a sombra segue o corpo.
5. Encostar de costas num prédio e numa árvore: a câmera se aproxima.
6. Olhar para uma porta de jogo e segurar E: o jogo abre; ao fechar, o hub volta na mesma visão.
7. M, Tab e o metrô: iguais nas duas visões.
8. Fechar e reabrir o hub: a visão escolhida continua.
9. No controle: o botão escolhido alterna a visão.

## Verificação (para os agentes)
- Pequenas: `bash tests/run_tests.sh check_<nome> ...`. Grandes, merges e fim da fase: `bash tests/run_tests.sh` até `RESULTADO GERAL: TUDO OK`.
- Capturas e medidas: sempre por `bash tools/com_trava.sh <comando>`, salvas em `C:\Projetos\game-hub-referencias\fase-20\`.
- Antes de cada commit: `git status` e o diff, sem `config.cfg` nem chave; e-mail noreply.
