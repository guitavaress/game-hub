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
- **Camadas seguem "dentro/fora".** `Player.set_indoors` ganha um segundo argumento opcional, a máscara de render do interior (a casa passa a 20; o jogador não conhece a `Home`). O rig troca as camadas dos corpos ao entrar e ao sair, para a luz da casa iluminar o corpo dentro e o sol iluminar fora. Uma camada nova (18) é "só a câmera do jogador": a do espelho e as do `WindowView` não a enxergam. As luzes da casa passam a iluminar também a 18 e a 19 (hoje só a 20): é a mudança em `home.gd`, feita por uma função só.
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
- [ ] **20.1 O corpo aprende a andar** (pequena · Sonnet, trilha B · medium)
  - Faz: `AvatarBody.animate(speed, on_floor)` com Idle/Walk/Run/Jump, blend e cadência casada; `set_head_hidden(on)` (encolhe o osso da cabeça); `set_shadow_mode(...)` (normal, sem sombra, só sombra). Nada muda na tela ainda.
  - Arquivos: `components/avatar/avatar_body.gd`, `tests/check_avatar.gd`.
  - Teste: `check_avatar` (a animação certa por velocidade; o `speed_scale` cresce com a velocidade; a cabeça encolhe e volta), mais `check_mirror` e `check_friends_wall` (nada quebrou).
  - Commit: `Fase 20.1: o avatar anda, corre e pula pela velocidade`
- [ ] **20.2 A tecla, a opção e as dicas** (pequena · Sonnet, trilha B, depois da 20.1 · medium)
  - Faz: ação `toggle_view`; `AppConfig.get_view()/set_view()`; a linha "Visão" em Esc › Controles; a tecla no cartão de controles e no `KeyHint`. O `Player` ainda não reage.
  - Arquivos: `project.godot`, `autoload/app_config.gd`, `ui/settings_view.gd`, o cartão de controles em `ui/`, `tests/check_gamepad.gd`, `tests/check_menu_keyboard.gd`.
  - Teste: os dois acima.
  - Manual: Esc › Controles mostra "Visão"; trocar grava no `config.cfg`.
  - Commit: `Fase 20.2: tecla e opção de visão`
- [ ] **20.3 O seu corpo em primeira pessoa** (grande · Opus, sessão nova, trilha A · high · revisão de risco: segundo Opus, só leitura)
  - Faz: `player/player_avatar.gd` (os dois corpos, as camadas, dentro/fora, a sombra); o `Player` cria o rig e o alimenta com a velocidade; `set_indoors(ambiente, camadas)`; as luzes da casa iluminam as camadas do corpo; o espelho passa a usar o corpo do jogador (sai o `ReflectionBody` e o `_follow`); o provador pede a pose parada. Acerta a posição do corpo para a câmera não ver o próprio pescoço ao olhar para baixo.
  - Arquivos: `player/player_avatar.gd` (novo), `player/player.gd`, `worlds/home/home.gd`, `worlds/home/home_mirror.gd`, `tests/check_player_avatar.gd` (novo), `tests/check_mirror.gd`, `tests/check_avatar_panel.gd`.
  - Teste: bateria completa. O teste novo confere: a câmera não vê o corpo inteiro na primeira pessoa e vê o de primeira pessoa; as camadas trocam ao entrar e sair de casa; o espelho enxerga o inteiro.
  - Capturas (fora do repositório, `C:\Projetos\game-hub-referencias\fase-20\20.3\`): olhando para baixo parado e andando, na praça de dia e de noite e na casa; a sombra; o espelho; o provador.
  - Manual: andar olhando para baixo na cidade e em casa; conferir a sombra com cabeça; olhar o espelho; abrir o provador.
  - Commit: `Fase 20.3: o corpo em primeira pessoa`
- [ ] **20.4 A câmera em terceira pessoa** (grande · Opus, sessão nova, trilha A · high)
  - Faz: o `SpringArm3D` e o ombro; V alterna com a passagem animada; o `CameraFeel` com `set_rest` e o balanço desligado na terceira; o raio do olhar e o alcance do E; o comprimento menor em casa; a escolha lida e gravada no `config.cfg`. **Entrega uma amostra** (capturas das duas opções da decisão 1) antes de fechar.
  - Arquivos: `player/player.gd`, `player/player.tscn` (só se o braço não puder ser criado por código), `player/camera_feel.gd`, `player/player_avatar.gd`, `tests/check_third_person.gd` (novo), `tests/check_camera_feel.gd`.
  - Teste: bateria completa. O teste novo confere: o braço encurta contra uma parede; alternar troca quais corpos a câmera vê; o E continua achando o alvo e respeitando o alcance; a visão volta do `config.cfg`.
  - Capturas: por trás na praça, numa rua estreita, encostado num prédio, na floresta, na casa (teto e paredes).
  - Commit: `Fase 20.4: a câmera em terceira pessoa`
- [ ] **20.5 O que depende da visão** (grande · Opus, trilha A · medium)
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
