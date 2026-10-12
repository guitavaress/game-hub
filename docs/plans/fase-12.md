# Fase 12: Tema e controles

**Status:** aprovado (2026-10-11), em andamento
**Branch:** `fase-12`, nascida da `fase-11` (`b1abfbb`), no checkout principal (`~/git/game-hub`). A cadeia fica `main` ← `fase-linux` ← … ← `fase-11` ← `fase-12`.

## Contexto
É o que sobrou da [revisão de 2026-10-10](../design/revisao-2026-10-10.md) que não depende do desktop: **5.2** (tema único) e **5.3** (menu por teclado e controle; a sensibilidade do mouse e o FOV já entraram na Fase 11). Veja [ROADMAP › Fase 12](../ROADMAP.md#fase-12-tema-e-controles-depois-da-11).

Hoje cada tela monta o próprio estilo: são ~130 `add_theme_*_override` em 14 arquivos, 13 tamanhos de fonte, 3 raios de canto e 4 opacidades de painel. Os controles do menu têm `focus_mode = FOCUS_NONE`, então nada funciona sem mouse, e o `project.godot` não tem nenhum botão de controle (gamepad).

Ao fim da fase:
- todas as telas usam um tema só, com 5 tamanhos de fonte, um raio e duas cores de painel, e o visual fica igual ou mais limpo;
- o menu de pausa e a tela do computador funcionam só com o teclado;
- dá para **jogar tudo com um controle Xbox**: andar, olhar, pular, correr, interagir, pausa, mapa, metrô, busca (sem digitar) e computador;
- as dicas desenhadas na tela trocam para os botões do controle quando ele é usado, e voltam para as teclas com o teclado ou o mouse.

Escolhas do dono (2026-10-11): controle **Xbox** (tem um para testar), o controle **joga tudo**, e as **dicas trocam** conforme o aparelho usado.

## Pronto quando
- Existe um `HubTheme` e nenhuma tela tem estilo "solto": cor de painel, raio, tamanho de fonte e botão vêm do tema. As capturas de antes e depois, em 720p e 1440p, mostram as telas iguais ou mais limpas.
- Com o menu de pausa aberto, setas, Enter e Esc fazem tudo: trocar de aba, mexer nos volumes, escolher a qualidade, ligar e desligar opções e fechar. O item com foco tem uma borda clara.
- No computador da casa, o teclado também navega (sem precisar do mouse).
- Com o controle Xbox: analógico esquerdo anda, direito olha, A pula, X interage, analógico esquerdo apertado corre, Y abre a busca, View abre o mapa, Menu abre a pausa, B volta, LB e RB trocam de aba.
- Na busca com o controle, o direcional percorre **todos** os resultados (não só os 8 primeiros), A acende o caminho e X vai até a porta.
- Usou o controle: as dicas ("Esc", "E", "Tab", "Segure E para jogar") passam a mostrar "B", "X", "Y", "Segure X para jogar". Mexeu no teclado ou no mouse: voltam.
- Em Esc › Controles há a "Sensibilidade do controle", e a lista de teclas mostra também os botões.
- A bateria inteira passa, com os testes novos.

## Decisões de arquitetura
- **Tema montado por código** (regra 6): `ui/hub_theme.gd` (`HubTheme`, só estático) monta um `Theme` uma vez (`HubTheme.get_theme()`). Cada tela põe esse tema no seu `Control` de cima (`theme = HubTheme.get_theme()`), inclusive o conteúdo da tela 3D do computador, que mora num `SubViewport`. *Descartado:* depender da herança do tema da janela através do `CanvasLayer` e do `SubViewport` (não é garantida nos dois casos); e um `.tres` escrito à mão.
- **O que o tema guarda:**
  - fonte padrão (Barlow SemiBold, como o `gui/theme/custom_font` de hoje) e tamanho padrão;
  - **5 tamanhos**: 14 (dica), 16 (texto), 20 (destaque), 28 (título) e 46 (título grande). As duas telas de tela cheia (a "Abrindo"/"Jogando" e o splash) continuam com os seus números enormes (52 a 96), como constantes nomeadas do `HubTheme`;
  - **um raio** (6) e **duas cores de painel** (0,85 para HUD, avisos e cartões; 0,94 para menus). O painel lateral do menu de pausa encosta na borda e fica sem raio;
  - estilos padrão de `Button`, `LineEdit`, `HSlider`, `CheckButton` e `PanelContainer`;
  - variações nomeadas (`theme_type_variation`): `HubCaption`, `HubBody`, `HubLead`, `HubTitle`, `HubSection`, `HubButtonPrimary`, `HubTab`, `HubSegment`, `HubKeyCap`, `HubPanel`, `HubPanelStrong`;
  - um estilo de **foco** visível (borda clara de 2 px), que a 12.4 usa.

  As constantes de cor (`TEXT_COLOR`, `HINT_COLOR`...) que hoje se repetem em vários arquivos passam a morar no `HubTheme`.
- **Quem sabe qual aparelho está em uso é um autoload novo, `autoload/input_device.gd`** (`InputDevice`). Ele olha cada evento (`_input`) e guarda o último aparelho: teclado e mouse, ou controle. Emite `device_changed(gamepad: bool)` e responde `label_for(acao) -> String` ("E" ou "X", "Esc" ou "B"). A tabela "ação → tecla, botão Xbox" é dado, numa constante dele. Não conhece mundo nenhum (regra 1).
- **Teclas desenhadas por ação**, e não por texto: `GameScreen.make_key_cap(...)` ganha uma versão que recebe o nome da ação (`interact`, `release_mouse`...) e troca o texto sozinha quando o aparelho muda. Os botões A, B, X e Y têm a cor do controle Xbox (verde, vermelho, azul e amarelo).
- **A dica do cartão usa um marcador:** quem responde `get_look_info()` escreve `"action": "Segure {interact} para jogar"`. O HUD troca `{interact}` pelo rótulo do aparelho atual. Vale para a porta de viagem, a estante, o mural e a tela 3D. O `GamePortal` ("Entre pela porta para jogar") não muda.
- **Botões do controle (Xbox):**

  | Ação | Teclado | Controle |
  |---|---|---|
  | andar (`move_*`) | WASD | analógico esquerdo |
  | olhar (`look_*`, novas) | mouse | analógico direito |
  | pular (`jump`) | Espaço | A |
  | correr (`sprint`) | Shift | apertar o analógico esquerdo |
  | interagir (`interact`) | E | X |
  | busca (`search_game`) | Tab | Y |
  | mapa (`open_map`) | M | View |
  | pausa (`release_mouse`) | Esc | Menu |
  | voltar e fechar (`ui_cancel`) | Esc | B |
  | confirmar (`ui_accept`) | Enter | A |
  | trocar de aba (`tab_prev`/`tab_next`, novas) | ←/→ na fileira das abas | LB/RB |
  | ir até a porta, na busca | Shift+Enter | X |

  `F8` (relógio) e `F11` (tela cheia) ficam só no teclado. O nome `release_mouse` fica como está (renomear mexeria em muitos arquivos e testes sem ganho).
- **Fechar painéis também com `ui_cancel`:** a busca, o mapa, o metrô, o menu de pausa e a tela 3D hoje fecham com `release_mouse` (Esc). Passam a fechar também com `ui_cancel` (B). O Esc está nas duas ações; cada painel marca o evento como tratado, então ele não fecha duas coisas.
- **Olhar com o analógico** no `player.gd`: um `look_by_stick(delta)` a cada quadro, com zona morta, curva quadrática (precisão perto do centro) e a sensibilidade nova `stick_sensitivity` (`[controls]` no `config.cfg`, de 0,5 a 2,0). O olhar pelo mouse não muda.
- **Busca sem digitar:** com o controle, o campo continua lá (vazio), e a lista mostra os jogos mais perto. O direcional rola por **todos** os resultados, numa janela de 8 que acompanha o escolhido. Teclado virtual fica de fora.
- **Tela 3D com o controle:** os eventos do controle e as teclas de navegação vão para o `SubViewport` (hoje só vão o mouse e as teclas de texto). Ao focar, o primeiro controle da tela ganha o foco. B (`ui_cancel`) sai, igual ao segundo Esc. Digitar a chave continua precisando do teclado.

## Subetapas
Ordem: primeiro o tema (fundação, quase nada muda na tela), depois o teclado nos menus, depois o controle, e por último as dicas que trocam (que dependem do tema e das ações).

| Janela | Principal (checkout `~/git/game-hub`, `fase-12`) | Paralela (New Worktree "controle", opcional) |
|---|---|---|
| 1 | 12.0 → 12.1 → 12.2 → 12.3 | 12.5 (depois do commit da 12.0) |
| 2 | junta a paralela → 12.4 → 12.6 → 12.7 → 12.8 | — |

- **Por que essa divisão:** o tema (12.1–12.3) mexe só em `ui/` e em `worlds/home/computer_desk.gd`; a 12.5 mexe só em `project.godot`, `player/player.gd` e `autoload/app_config.gd`. Não se cruzam.
- **Junta (igual às fases 9 a 11):** na principal, `git merge --no-ff worktree/controle -m "Fase 12.5: junta a trilha paralela"`, bateria inteira, `[x]` com os dois hashes. **Apagar o worktree antes do chat.**
- **Uma bateria por vez:** o `user://` é um só. O `run_tests.sh` tem trava; não rodar `godot -s` à mão enquanto a outra trilha testa.
- Sem worktree, tudo vai na principal, na ordem 12.0 → 12.8.

### Bloco A: tema (principal)

- [x] **12.0 Preparação** (Sonnet · low) — aea55ff
  - Faz: cria a branch `fase-12` a partir da `fase-11`, faz o commit deste plano e marca a Fase 12 como "em andamento" no ROADMAP.
  - Commit: `Fase 12.0: plano`

- [x] **12.1 O tema** (Opus · high: é a fundação, e decide os tamanhos de todas as telas) — 59456bf
  - Faz:
    - `ui/hub_theme.gd` (novo), com tudo o que está em "Decisões" (fontes, 5 tamanhos, raio, painéis, botões, campo, deslizador, chave, aba, botões lado a lado, foco, cores);
    - passam a usar o tema as telas de configuração: `ui/settings_view.gd`, `ui/pause_menu.gd` e a tela do computador (`worlds/home/computer_desk.gd`). As funções de estilo do `SettingsView` (`box`, `style_button`, `label`, `_field`, `_style_slider`) somem ou viram uma linha com `theme_type_variation`;
    - o `GameScreen.make_key_cap` passa a usar a variação `HubKeyCap`.
  - Teste: `tests/check_theme.gd` (novo):
    - o tema tem as variações e os 5 tamanhos;
    - o menu de pausa e o `SettingsView` sozinho ficam sem estilo solto (nenhum `add_theme_*_override` nos nós);
    - o texto do computador usa o mesmo tema dentro do `SubViewport`.
    - `check_pause_menu`, `check_settings_view` e `check_screen_3d` passam.
  - Manual: capturas do menu de pausa (as três abas) e do computador focado, antes e depois, em 1280 × 720 e 2560 × 1440, só em `/tmp`.
  - Commit: `Fase 12.1: o tema do hub`

- [x] **12.2 Tema nos painéis** (Sonnet · medium) — 3fb2012
  - Faz: busca (`ui/game_search.gd`), metrô (`ui/transit_panel.gd`), mapa (`ui/world_map.gd`), avisos (`ui/toast.gd`) e cartão de controles (`ui/controls_hint.gd`) passam a usar o tema, e as constantes de cor repetidas saem desses arquivos.
  - Teste: o `check_theme` ganha os cinco painéis na conferência "sem estilo solto". `check_search`, `check_metro`, `check_toasts`, `check_first_time` e `check_minimap` passam.
  - Manual: capturas dos cinco, antes e depois, em 720p e 1440p.
  - Commit: `Fase 12.2: tema nos painéis`

- [x] **12.3 Tema no HUD e nas telas cheias** (Sonnet · medium) — fb47845
  - Faz: o HUD (`ui/hud.gd`: cartão do que se olha, bússola, moldura do minimapa), o título do bairro (`ui/district_title.gd`), a carga da porta (`ui/door_charge.gd`, só o texto), a tela "Abrindo"/"Jogando" (`ui/game_screen.gd`) e o splash (`ui/splash_screen.gd`) passam a usar o tema. Os números grandes viram as constantes de tela cheia do `HubTheme`.
  - Teste: o `check_theme` cobre essas telas. `check_look_card`, `check_compass`, `check_door_charge`, `check_session_summary`, `check_home_start` e `check_transitions` passam.
  - Manual: capturas da tela "Abrindo", do cartão do prédio, do título do bairro e da carga da porta.
  - Commit: `Fase 12.3: tema no HUD e nas telas cheias`

### Bloco B: controle (paralela)

- [x] **12.5 Andar e olhar com o controle** (Sonnet · medium) — 1e63502
  - Faz:
    - `project.godot`:
      - botões e eixos do controle nas ações que já existem (veja a tabela em "Decisões");
      - ações novas `look_left/right/up/down` (analógico direito) e `tab_prev/tab_next` (LB e RB);
      - zona morta de 0,2 nos analógicos.
    - `autoload/app_config.gd`: `get_stick_sensitivity`/`set_stick_sensitivity` (`[controls] stick_sensitivity=1.0`, com a linha comentada no texto padrão do `config.cfg`).
    - `player/player.gd`: `look_by_stick(delta)` a cada quadro, travado nos mesmos casos que o mouse (abertura, foco na tela 3D, painel aberto).
  - Teste: `tests/check_gamepad.gd` (novo, guarda e devolve o `config.cfg`):
    - eventos de controle falsos (`Input.parse_input_event` com `InputEventJoypadMotion` e `InputEventJoypadButton`) fazem o jogador andar, girar, pular e interagir;
    - a zona morta segura o analógico parado;
    - com o menu aberto, o analógico não gira a câmera;
    - a sensibilidade do controle muda o giro.
    - `check_interact` e `check_camera_feel` passam.
  - Manual: com o controle Xbox ligado, andar pela praça, olhar, pular, correr, entrar numa porta e apertar X na porta "Casa".
  - Commit: `Fase 12.5: andar e olhar com o controle`

### Bloco C: menus e dicas (principal, depois de juntar)

- [x] **12.4 Menu pelo teclado** (Sonnet · medium; Opus se o foco brigar com a tela 3D) — b00f132
  - Faz:
    - `ui/settings_view.gd`:
      - tira os `FOCUS_NONE` e liga os vizinhos de foco (abas → controles da página → rodapé);
      - ←/→ na fileira das abas troca de página, e `tab_prev`/`tab_next` trocam de qualquer lugar;
      - ao abrir, o foco vai para a aba escolhida;
      - os botões lado a lado (Leve | Média | Alta) escolhem com ←/→ e Enter.
    - `ui/pause_menu.gd`: o rodapé (Continuar, Sair do hub) entra na ordem do foco; o menu fecha também com `ui_cancel`.
    - `components/screen_3d/screen_3d.gd`:
      - as teclas de navegação (setas, Tab, Enter) também vão para o `SubViewport`;
      - ao focar, o primeiro controle da tela ganha o foco;
      - a regra dos dois Esc continua: o primeiro só sai do campo de texto.
    - `ui/game_search.gd`, `ui/world_map.gd` e `ui/transit_panel.gd` fecham também com `ui_cancel`.
  - Teste: `tests/check_menu_keyboard.gd` (novo, guarda e devolve o `config.cfg`):
    - abrir a pausa, descer até o volume Geral, apertar → e conferir que o volume subiu;
    - ir até a aba Controles e ligar e desligar o "Balanço da câmera";
    - Esc fecha;
    - no computador, as setas e o Enter trocam o "Bússola e mapa".
    - `check_pause_menu` e `check_screen_3d` passam.
  - Manual: abrir o menu e fazer tudo só com o teclado; repetir no computador da casa.
  - Commit: `Fase 12.4: menu pelo teclado`

- [x] **12.6 Painéis pelo controle** (Sonnet · medium) — 772aed4
  - Faz:
    - **busca**: Y abre e fecha; o direcional rola por todos os resultados (janela de 8 que acompanha o escolhido); A acende o caminho (em casa, vai até a porta); X vai até a porta; B fecha. O A do controle não pode ser confundido com o Espaço digitado no campo: só o botão do controle conta;
    - **mapa**: View abre e fecha, B fecha;
    - **metrô**: já usa `ui_up`, `ui_down` e `ui_accept`; B fecha;
    - **menu de pausa**: Menu abre e fecha; LB e RB trocam de aba;
    - **computador**: X foca; os botões do controle vão para o `SubViewport`; B sai;
    - **tela "Abrindo"**: B cancela (o `GameLauncher` já escuta `ui_cancel`);
    - em Esc › Controles, o deslizador "Sensibilidade do controle".
  - Teste: `tests/check_gamepad.gd` ganha os painéis:
    - Y abre a busca, o direcional chega ao 12º resultado (com 30 jogos falsos), X viaja e B fecha;
    - View abre o mapa;
    - Menu abre a pausa, RB troca de aba, B fecha;
    - no computador, B sai do foco.
    - `check_search`, `check_fast_travel`, `check_metro` e `check_screen_3d` passam.
  - Manual: com o controle, achar um jogo pela busca e viajar até ele; usar o metrô; mudar a qualidade no computador.
  - Commit: `Fase 12.6: painéis pelo controle`

- [ ] **12.7 Dicas que trocam** (Sonnet · medium)
  - Faz:
    - `autoload/input_device.gd` (novo autoload `InputDevice`: último aparelho, sinal `device_changed`, tabela de rótulos);
    - `GameScreen.make_key_cap` por ação, trocando sozinho; A, B, X e Y nas cores do Xbox;
    - os rodapés da busca, do metrô, do mapa, da pausa, da tela "Abrindo" e do computador, e o cartão de controles da primeira vez, passam a usar as teclas por ação;
    - a dica do cartão com o marcador `{interact}`, trocado pelo HUD, em `components/travel_door/travel_door.gd`, `worlds/home/library_shelf.gd`, `worlds/home/friends_wall.gd`, `worlds/home/home.gd` e `components/screen_3d/screen_3d.gd`;
    - na aba Controles, a lista de teclas ganha a coluna do controle.
  - Teste: `tests/check_input_device.gd` (novo):
    - um botão do controle troca para o modo controle, e uma tecla ou um movimento do mouse volta;
    - uma tecla por ação muda o texto ("Esc" ↔ "B");
    - o cartão da estante mostra "Segure X para jogar" no modo controle;
    - um analógico parado dentro da zona morta **não** troca o modo (senão as dicas piscariam).
    - `check_interact`, `check_shelf`, `check_friends_wall`, `check_home` e `check_first_time` passam.
  - Manual: na estante, olhar uma capa, tocar no controle e ver "Segure X para jogar"; mexer no mouse e voltar a "Segure E".
  - Commit: `Fase 12.7: dicas que trocam com o controle`

- [ ] **12.8 Docs** (Sonnet · low)
  - Faz:
    - README: tabela de controles com a coluna do Xbox e uma linha sobre o menu pelo teclado;
    - ROADMAP: Fase 12 feita;
    - CLAUDE.md: mapa com `autoload/input_device.gd` e `ui/hub_theme.gd`;
    - `tests/README.md`: os testes novos e como simular o controle (`Input.parse_input_event`);
    - na revisão de 2026-10-10, os itens 5.2 e 5.3 marcados como feitos;
    - plano marcado.
  - Commit: `Fase 12.8: documentação`

## Riscos
- **O tema muda o visual sem querer** (tamanhos arredondados para os 5 novos, cores juntadas): capturas de antes e depois em cada subetapa do bloco A, em 720p e 1440p. Se algo ficar pior, ajusta-se o tema, e não a tela.
- **Tema que não chega ao `SubViewport` do computador:** o tema é posto direto no conteúdo da tela 3D, e o `check_theme` confere.
- **O foco do teclado brigando com o jogo:** o Tab é "busca", o E é "interagir" e as setas não fazem nada no jogo. Com o menu aberto, o mundo está pausado e a busca não abre (`is_overlay_open`). O `check_menu_keyboard` confere que o Tab e o E não vazam para fora do menu.
- **O Espaço e o A são os dois `ui_accept`:** na busca, apertar Espaço no campo não pode escolher o jogo. Só um `InputEventJoypadButton` conta como "A".
- **Dicas piscando** (um analógico com folga manda eventos pequenos o tempo todo): só conta como "usar o controle" um botão ou um analógico além da zona morta.
- **Mouse visível com o controle:** com o menu aberto, o cursor aparece e pode ficar parado em cima de um botão. Na 12.6, com o controle, o cursor fica escondido; com o teclado, volta.
- **Controle no Linux (Wayland/SDL)** e no Windows (XInput) podem numerar os botões de outro jeito. A Godot usa o padrão SDL (`JOY_BUTTON_A`...). Conferir à mão nos dois sistemas.
- **Testes que gravam no `config.cfg`:** `check_gamepad` e `check_menu_keyboard` guardam e devolvem o arquivo.

## Fora do escopo
- Trocar teclas ou botões (remapear).
- Vibração do controle e botões do PlayStation ou do Switch (o rótulo segue o Xbox; outro controle funciona, mas a dica diz A/B/X/Y).
- Teclado virtual para digitar na busca ou a chave no computador.
- Luz (4.x) e `distance_fade` dos postes (8.2): continuam esperando a medida no desktop.

## Decisões tomadas durante a fase
- 2026-10-11: controle Xbox, o controle joga tudo, e as dicas trocam com o aparelho usado (dono). Plano aprovado.
- 2026-10-11 (12.1): **o tema**.
  - Espaçamentos ("separation") ficam no nó: são arrumação, não estilo. O `check_theme` confere só cor, fonte, tamanho e caixa.
  - Além das variações do plano: `HubBodyLight` (texto secundário), `HubValue` (número do deslizador), `HubBrand` ("GAME HUB"), `HubKeyLabel` (letra da tecla) e `HubStatusOk`/`HubStatusError` (a linha de situação dos amigos troca de variação, em vez de cor).
  - O `CheckButton` recebe de volta as caixas vazias do tema padrão da Godot: sem isso, herdava a caixa com borda do `Button` do tema.
  - Com o texto em 16 px, as frases da aba Controles quebram a linha (antes alargavam o painel) e a tecla desenhada fica no meio da fileira, sem esticar.
  - A tela do computador usa o painel forte sem transparência (`HubScreen`). O "Leve" escolhido continua apagado na tela 3D, como antes (é o brilho do 3D, não o tema).
- 2026-10-11: **correção fora do plano** (7bd7867). Com uma chave salva, os amigos de verdade entram na praça; com mais de 10 online, a segunda volta da roda punha um holograma na saída da estação Central (o `check_metro` acusou). Os amigos agora desviam da calçada da estação e da chegada da porta "Casa". Os testes que usam amigos falsos ou andam pela praça chamam `tests/quiet_friends.gd`, e as esperas pela rede do `check_phase5` contam tempo.
- 2026-10-11 (12.2): o tema ganhou `HubRow`/`HubRowSelected` (linha escolhida das listas), `HubToast*` (a barrinha da cor do tipo) e `HubOverline*` (rótulo do aviso). A cor que vem de dado (o neon do bairro na busca) passa por `HubTheme.tint`, que marca o texto; o `check_theme` aceita só essa exceção. O painel dos avisos passou de 78% para 85% de opacidade e o da busca e do metrô de 92% para 94% (as duas cores do tema). O cartão de controles ficou com margens um pouco menores.
- 2026-10-12 (12.3): o tema ganhou `HubCard` (cartão do que se olha), `HubPlate` (plaquinha da carga da porta), `HubHeading`, `HubTitleSmall`, `HubDisplay`/`HubDisplaySub` (título do bairro, com sombra) e `HubFs*` (os textos enormes das telas cheias: 104, 96, 72, 52 e 24 px, constantes nomeadas `SIZE_FULLSCREEN_*`). O `check_theme` aceita esses tamanhos só nessas variações; fora delas, só os 5. A bússola, que desenha por código, usa as constantes do tema (cor do painel, raio e os tamanhos 14 e 16: as letras pequenas passaram de 12 para 14 px).
  - O nome no cartão do que se olha passou de 26 para 28 px, e a linha de amigos e a dica, de 15 para 14 e 16 px.
  - A plaquinha da carga da porta passou de 62% para 85% de opacidade (a cor de painel do tema).
- 2026-10-12 (12.4): feita na principal, **antes** de juntar a paralela 12.5 (o dono seguiu a ordem 12.3 → 12.4). As ações `tab_prev`/`tab_next` (LB e RB) ainda não existem: o `SettingsView` já escuta, mas só se a ação existir (`InputMap.has_action`); a 12.5 as cria no `project.godot`. `next_page()`/`previous_page()` valem desde já.
  - A ordem do foco é montada à mão (`SettingsView._link_focus`): aba › cada linha de cima para baixo › rodapé (Continuar e Sair, ou o "Sair do hub" do computador) › volta à aba. A busca por geometria do Godot dava a volta pela tela e pulava os botões lado a lado.
  - O deslizador não tem borda de foco: com o foco, a parte cheia fica branca.
  - O primeiro Esc na tela 3D só tira o foco de um campo de texto (`LineEdit`). Antes, tirava o foco de qualquer coisa, e com o teclado começando na aba o primeiro Esc seria "gasto".
  - Busca, mapa, metrô, menu de pausa e tela 3D fecham também com `ui_cancel` (o B do controle). Só o Esc abre o menu de pausa.
- 2026-10-12 (12.5): feita na principal, sem a paralela.
  - Neste Godot (4.7, Linux), `ui_accept` e `ui_cancel` **não** vêm com botões de controle. O `project.godot` agora declara as seis ações de interface (`ui_accept`, `ui_cancel`, `ui_up/down/left/right`) com as teclas de sempre mais A, B, o direcional e o analógico esquerdo. Sem isso, o B não fecharia os painéis e o direcional não moveria os menus.
  - Olhar com o analógico direito: `Player._look_with_stick`, a cada quadro, com curva quadrática e `STICK_TURN_SPEED` = 3,2 rad/s (uma volta em ~2 s com a sensibilidade em 1,0). Trava como o mouse (abertura, foco na tela 3D e painel aberto).
  - Achado da 12.4: o `SettingsView._link_focus` rodava antes de o rodapé entrar na árvore e acusava erro de caminho; agora só liga o rodapé que já está na árvore.
- 2026-10-12 (12.6): a busca passou a ter **todos** os resultados, com uma janela de 8 linhas que rola junto com a escolha e a linha "6 a 13 de 30" embaixo (antes só os 8 mais perto apareciam). O A do controle faz o mesmo que o Enter e o X, o que o Shift+Enter (o joypad não depende de o campo de texto ter o foco). O mapa, o metrô, a pausa e a tela "Abrindo" já funcionavam com o controle pelas ações de 12.4 e 12.5; só a tela 3D precisou encaminhar os botões e o analógico para dentro do `SubViewport`.
  - O cursor do mouse segue visível com o menu aberto, mesmo usando o controle: esconder pelo aparelho usado fica para a 12.7 (`InputDevice`).

## Checklist de teste manual (fim da fase)
No notebook (Omarchy), qualidade **Leve**, com o controle Xbox ligado:
1. F5. Sem tocar no mouse, aperte Esc e use só setas, Enter e Esc: troque de aba, suba o volume Geral, mude a qualidade e feche.
2. Pegue o controle: as dicas na tela passam a mostrar os botões. Ande com o analógico esquerdo, olhe com o direito, pule com A.
3. Na estante, olhe uma capa: o cartão diz "Segure X para jogar". Toque no mouse: volta para "Segure E".
4. X no computador: o direcional anda pelas opções e A escolhe. B volta.
5. X na porta da rua. Na praça, Y abre a busca: desça com o direcional até um jogo mais longe e aperte X para ir até a porta.
6. View abre o mapa; B fecha. Pise numa estação e escolha um bairro com o direcional e A.
7. Menu abre a pausa; LB e RB trocam de aba; B fecha.
8. Entre num prédio e, na tela "Abrindo", aperte B: a espera é cancelada.
9. Compare o menu de pausa em janela e em tela cheia (F11): o tamanho e as cores continuam iguais.

No desktop (Windows, a partir de 18/10): os passos 2, 4 e 5 com o controle pelo XInput.

## Verificação
1. `bash tests/run_tests.sh` ao fim de cada subetapa: `RESULTADO GERAL: TUDO OK`.
2. Capturas (12.1, 12.2, 12.3) com janela, antes e depois, em 1280 × 720 e 2560 × 1440, só em `/tmp` (algumas mostram capas).
3. O controle de verdade só no teste manual; os testes automáticos usam eventos falsos.
