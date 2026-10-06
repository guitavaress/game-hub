# Fase 9: A casa

**Status:** em andamento (aprovado em 2026-10-06)
**Branch:** a sessão roda num **worktree do claude-squad**, na branch `guitavares/game-hub` (que hoje aponta para o mesmo commit da `fase-8`, `9136f27`). Os commits da fase vão nessa branch; o checkout principal (`~/git/game-hub`) fica na `fase-8` e não é tocado. No fim da fase, `git branch -f fase-9 HEAD` dá o nome de sempre à branch. A cadeia fica `main` ← `fase-linux` ← `fase-7` ← `fase-8` ← `fase-9`.

### Trabalho com o claude-squad
- **Trilha principal** (instância "Game Hub", branch `guitavares/game-hub`):
  - faz as subetapas em ordem;
  - é a única que marca `[x]` e escreve em "Decisões tomadas durante a fase";
  - junta as branches paralelas.
  - "Uma sessão por subetapa" vira um `/clear` (ou uma conversa nova) na mesma instância.
- **Trilha paralela** (opcional, uma por vez): uma instância nova do cs para uma subetapa que não mexe nos mesmos arquivos da principal naquele momento.

  | Janela | Principal | Paralela |
  |---|---|---|
  | 1 (agora) | 9.1 → 9.2 → 9.3 | 9.6 |
  | 2 (com a 9.3 e a 9.6 juntas) | 9.4 → 9.5 | 9.7 |
  | 3 (depois da 9.8) | 9.9 | 9.10 |

  A 9.8 e a 9.11 ficam só na principal.
- **Passo a passo da paralela:**
  1. No cs, `n` cria a instância com o nome da subetapa (ex.: "9.6 config").
  2. Ela nasce do HEAD do checkout principal (`fase-8`) e não do nosso. Por isso, a primeira mensagem é: "`git merge --ff-only guitavares/game-hub`; depois execute a subetapa 9.N deste plano, sem marcar o plano; faça o commit com o e-mail noreply e me diga o hash".
  3. Ela roda só os testes dela. **Nunca rode a bateria em duas instâncias ao mesmo tempo**: o `user://` (com o `config.cfg`, a chave e o cache) é um só para todos os worktrees.
  4. Para juntar, na principal e entre duas subetapas:
     - `git merge --no-ff <branch da paralela> -m "Fase 9.N: junta a trilha paralela"`;
     - `bash tests/run_tests.sh`;
     - marcar `[x]` com o hash.
  5. Só depois de juntar, encerrar a instância no cs (`D`).
  6. Teste no editor: abrir o `project.godot` do worktree (o caminho aparece no cs). Cada worktree reimporta o projeto na primeira vez.
  7. O atalho de push do cs não é usado sem o dono pedir.

## Contexto
A Fase 8 está fechada (8.0–8.9 marcadas, commits até `9136f27`; faltam só as conferências no desktop/Windows, a partir de 18/10). A Fase 9 é o primeiro passo da ideia "a casa é o computador" (V2, [ROADMAP › Fase 9](../ROADMAP.md#fase-9-a-casa)). O jogador passa a **nascer dentro de um loft**, onde o HUD vira coisas físicas:
- uma **estante** com as capas da biblioteca, de onde se abre um jogo;
- um **mural** com os amigos online;
- um **computador** cuja tela é o menu de configurações.

A porta do loft leva à praça da cidade. O Esc continua abrindo o menu de pausa, como atalho.

Escolhas do dono (2026-10-06):
- a casa é um **interior à parte**: a porta leva à praça com a tela escura, e uma porta "Casa" na praça traz de volta;
- **interação física**: olhar e apertar E; a tela do computador é a própria interface, clicável com o mouse;
- **casa na hora**: o loft aparece em ~1 s e a cidade monta lá fora, com a porta trancada até ela ficar pronta;
- **loft noturno feito por código**, com texturas PBR CC0 e sem modelos baixados.

Levantamento (só leitura):
- **Nascer:** `city.gd` `_ready()` cria o jogador em `PLAYER_SPAWN` (praça) e faz a abertura pelo céu (`player.start_intro`/`finish_intro`, `ScreenFade.show_splash`). Os quarteirões só são montados um por quadro quando `play_intro` está ligado. Sem janela (testes), `play_intro = false`: tela preta e montagem direta.
- **Olhar:** o raio do jogador (`player.gd` `_find_look_info`) já usa o contrato `get_look_info()`/`get_look_label()`, na máscara 5 (camadas 1 e 3). **Não existe tecla de interagir**; o E está livre.
- **Abrir jogo:** `GameLauncher.launch(app_id, source)` aceita qualquer nó como origem; `session_ended(app_id, source, ...)` diz quem pediu. O `GamePortal` escurece, chama `launch` e, na volta, clareia só `if not HubWindow.is_sleeping` (o `HubWindow.wake()` já clareia). Num jogo aberto por fora, o portal daquele jogo puxa o jogador para a porta (`source == null`).
- **Cartão do jogo:** `GamePortal.get_look_info()`, `_play_info()`, `_format_playtime()` e `_format_last_played()` formatam nome, bairro, horas e amigos. Hoje vivem no portal.
- **Vinheta da porta:** `ScreenFade.set_door_charge(ratio, nome, cor)` funciona para qualquer origem.
- **Viagem:** `player.travel_to(alvo, mensagem)`. O alvo "na frente da porta, virado para ela" é calculado dentro de `GameSearch._travel()` (`Transform3D(portal.global_basis, return_point.origin)`).
- **Configurações:** `ui/pause_menu.gd` (628 linhas) monta as abas Som e vídeo, Controles e Amigos dentro do próprio `CanvasLayer`. `check_pause_menu` mexe nelas.
- **Painéis:** `player.is_overlay_open()` (menu, busca, mapa e metrô) garante um de cada vez.
- **Testes:** 29 testes montam `city.tscn` com `play_intro = false` e esperam o jogador na praça; o `check_intro` liga a abertura.
- **Sons:** a cidade usa sons 3D e o canal "Ambiente". A casa ficará a mais de 1 km, longe do alcance deles.

## Pronto quando
- **Nasce em casa.** Com janela, o jogador está dentro do loft em até ~1,5 s depois de abrir o hub. A cidade monta em segundo plano sem travar a casa (nenhum quadro acima de ~50 ms no desktop durante a montagem). A porta mostra "Montando a cidade… 40%" e só abre quando a cidade fica pronta.
- **Escolher um jogo sem sair.** Na estante, olhar uma capa mostra o mesmo cartão do prédio (bairro, horas, amigos). Segurar E abre o jogo pela Steam, e o jogador volta para dentro de casa, na frente da estante. Funciona com 200 jogos (páginas e filtro por bairro).
- **Amigos no mural.** Cada amigo online vira um cartão (foto, nome, situação e jogo). E num amigo que está jogando um jogo da biblioteca leva até a porta desse jogo na cidade.
- **Configurar tudo sem sair.** E no computador aproxima a câmera, e a tela dele mostra as mesmas abas do menu de pausa, clicáveis, inclusive o campo da chave. Esc devolve a câmera.
- **Esc continua.** O menu de pausa abre em casa e na cidade, igual a hoje.
- **Ida e volta.** E na porta do loft leva à praça; E na porta "Casa" da praça traz de volta. Em casa, a bússola e o minimapa somem e o som da cidade fica abafado.
- **Nada quebra.** Os jogos abertos pelos prédios voltam para a porta, como sempre. A bateria inteira passa, com os testes novos.

## Decisões de arquitetura
- **A casa é uma cena própria, colocada pelo mundo.**
  - `worlds/home/home.gd` (`Home`) monta o loft por código.
  - A cidade cria a casa longe da cidade (`HOME_ORIGIN`, ~1,5 km ao sul, fora de qualquer `half_extent`) e liga as duas portas.
  - A casa **não conhece a cidade**: só expõe `get_spawn_transform()`, `get_front_door()` e o grupo `home`. Um bioma futuro coloca a mesma casa.
  - *Descartado:* uma cena raiz nova acima de `city.tscn`, porque mexeria no main_scene e em 29 testes sem ganho agora.
- **Interagir (E): um contrato só.**
  - Ação nova `interact` (E).
  - O jogador procura no alvo do raio, subindo pela árvore como já faz:
    - `interact(player)` é chamado num toque de E;
    - quem precisa de E **segurado** responde `get_hold_seconds() > 0` e recebe `set_hold(ratio)` a cada quadro. O jogador chama `interact` quando enche e `set_hold(0)` ao soltar ou desviar o olhar.
  - O dicionário do `get_look_info()` ganha a chave opcional `"action"` (ex.: "Segure E para jogar"), que o cartão do HUD mostra numa linha de dica.
  - Bloqueado com painel aberto, durante viagem ou foco e com `GameLauncher.is_busy()`.
- **Porta de viagem genérica.** `components/travel_door/travel_door.gd` (`TravelDoor`):
  - uma `LookArea` (camada 3), com nome e destino (`Transform3D`);
  - `locked_reason` (texto) tranca a porta;
  - E chama `player.travel_to(destino, mensagem)`.
  - A aparência é de quem usa, como no PortalShell e no MetroEntrance: a porta do loft é desenhada pela casa, e a porta "Casa" da praça pela cidade.
- **"Em casa" no jogador.**
  - Uma `Area3D` cobre o interior. Ao entrar, a casa chama `player.set_indoors(environment)`; ao sair, `set_indoors(null)`.
  - Com isso:
    - a câmera usa o `Environment` da casa (`Camera3D.environment` passa por cima do `WorldEnvironment` da cidade);
    - a câmera vê só até ~60 m, então a cidade a 1,5 km nem é desenhada;
    - o HUD esconde a bússola e o minimapa;
    - o canal "Ambiente" ganha um filtro passa-baixa e −10 dB (a cidade abafada).
  - O sol da cidade não ilumina dentro: os meshes da casa ficam na camada de render `Home.INTERIOR_LAYER` (20), e a cidade tira essa camada do `light_cull_mask` do sol ao colocar a casa.
  - A qualidade gráfica vale também para a casa (`GraphicsQuality.apply_to_environment`, ouvindo `AppConfig.settings_changed`).
- **Começo: casa na hora, cidade em segundo plano.**
  - Com `play_intro` ligado (padrão com janela), a ordem é:
    1. ambiente;
    2. casa;
    3. jogador no ponto de nascer da casa;
    4. a tela clareia em ~0,5 s, com o splash "GAME HUB" só até a casa ficar pronta;
    5. a cidade monta por **orçamento de tempo** (~6 ms de montagem por quadro, em vez de um quarteirão por quadro).
  - A porta do loft fica com `locked_reason = "Montando a cidade… N%"` até `city_ready`.
  - A abertura pelo céu sai (`start_intro`/`finish_intro` são removidos).
  - Sem janela (`play_intro = false`), tudo fica **como hoje**: tela preta e jogador na praça. Assim os 29 testes não mudam, e os testes novos ligam a casa explicitamente.
- **Informação do jogo compartilhada.** Um `components/game_portal/game_info.gd` (`GameInfo`, só funções estáticas) passa a montar o cartão de um `app_id` (título, bairro, horas, última vez, amigos). O `GamePortal` e a estante usam o mesmo. O resultado do portal não muda (o `check_look_card` confere).
- **Estante** (`worlds/home/library_shelf.gd`):
  - caixas 3D com a capa (`GameArt.get_art`), ~24–30 por página, em ordem de "jogado por último";
  - duas placas (E) passam as páginas, e uma placa (E) troca o filtro (Todos → bairros que existem);
  - cada caixa responde `get_look_info()` (com `GameInfo`) e `get_hold_seconds() = 1.2`;
  - ao encher, escurece (`set_door_charge`) e chama `GameLauncher.launch(app_id, estante)`;
  - na volta (`session_ended` com origem = estante), o jogador fica na frente da estante e a tela clareia se o hub não dormiu, como no portal.
  - As caixas **não** são `GamePortal`: senão a busca, o mapa e o metrô contariam jogos em dobro.
- **Mural dos amigos** (`worlds/home/friends_wall.gd`):
  - um cartão por amigo online (foto com `FriendsService.get_avatar`/`avatar_ready`, nome, cor da situação e jogo), com quem está jogando primeiro;
  - sem chave ou sem amigos, um cartão diz "Configure os amigos no computador";
  - E num amigo leva até a porta do jogo dele; se o jogo não estiver na biblioteca, leva até a praça.
  - O alvo "na frente da porta" sai da busca e vira `GamePortal.get_arrival_transform()`, usado pela busca e pelo mural.
- **Configurações reaproveitadas.**
  - As abas saem do `PauseMenu` para `ui/settings_view.gd` (`SettingsView`, um `Control`: abas, páginas, campos da chave).
  - O `PauseMenu` fica com o fundo, o título "PAUSA" e o rodapé, e põe um `SettingsView` dentro. Na tela, nada muda.
- **Tela 3D clicável** (`components/screen_3d/screen_3d.gd`, `Screen3D`):
  - um quadro com um `SubViewport` (o conteúdo é qualquer `Control`), uma `LookArea` e um `Marker3D` com a pose da câmera;
  - E chama `player.focus_on(tela)`: a câmera desliza até a pose, o mouse aparece e o andar trava (o foco conta em `is_overlay_open()`);
  - o mouse vira raio, o raio vira ponto no plano da tela, e o ponto vira coordenada do `SubViewport` (`push_input`); as teclas também vão para ele, para digitar a chave;
  - Esc sai do foco: o primeiro Esc só tira o foco de um campo de texto, se houver um.
  - O computador da casa usa um `Screen3D` com `SettingsView` mais o botão "Sair do hub".
- **Em casa, os painéis se adaptam:**
  - na busca, Enter vira "ir até a porta" (não há faixa de luz dentro de casa), e a dica muda;
  - o mapa (M) abre com "Você está em casa" no lugar da seta;
  - um jogo aberto por fora que fecha **não** tira o jogador de casa: o portal confere `player.is_indoors()`.
- **O que não muda:** o `GamePortal` e o `GameLauncher` não mudam de contrato, e nada em `autoload/` passa a conhecer a casa (regras 1 e 3).

## Subetapas
Ordem: estrutura e contratos primeiro (nada visível), depois a casa funcional, os móveis e o visual por último.

- [x] **9.0 Preparação** (Opus · high)
  - Faz: salva este plano em `docs/plans/fase-9.md`, com o status "em andamento".
  - Commit: `Fase 9.0: plano`
- [ ] **9.1 Interagir com E** (Sonnet · medium)
  - Faz:
    - ação `interact` (E) no `project.godot`;
    - no `player.gd`: toque, segurar, `set_hold` e as travas;
    - no HUD, a linha `"action"` no cartão.
    - A linha "E interagir" nas teclas fica para a 9.6, que pode rodar em paralelo e mexe no mesmo lugar.
  - Teste: `tests/check_interact.gd`, com um nó falso na cidade:
    - o toque chama `interact`;
    - segurar enche e chama `interact` uma vez só;
    - soltar ou desviar zera;
    - nada acontece com painel aberto, em viagem ou com o launcher ocupado;
    - a dica aparece no cartão.
  - Commit: `Fase 9.1: interagir com E`
- [ ] **9.2 A casa e as portas** (Opus · high: ambiente, camadas e luz)
  - Faz:
    - `worlds/home/home.gd`: sala provisória (chão, paredes, teto, luzes), `Environment` próprio, área "em casa" e porta da rua;
    - os móveis entram por `_build_furniture()`, com uma linha por móvel. É o encaixe da estante, do mural e do computador, para as trilhas paralelas não brigarem em `home.gd`;
    - `components/travel_door/travel_door.gd`;
    - no `player.gd`: `set_indoors`/`is_indoors` (ambiente e alcance da câmera, HUD, filtro no "Ambiente");
    - na cidade: põe a casa em `HOME_ORIGIN`, cria a porta "Casa" provisória na praça e tira a camada do interior do sol.
    - O jogador ainda nasce na praça.
  - Teste: `tests/check_home.gd`:
    - E na porta da praça leva para dentro, com o ambiente da casa e a bússola e o minimapa escondidos;
    - E na porta do loft devolve à praça, e tudo volta ao normal;
    - nenhuma porta abre com jogo rodando;
    - o sol não ilumina a camada do interior.
  - Commit: `Fase 9.2: a casa e as portas`
- [ ] **9.3 Nascer em casa** (Opus · high: começo do hub)
  - Faz:
    - com `play_intro` ligado, o novo começo: casa, jogador, clarear e montagem por orçamento de tempo;
    - a porta trancada com o progresso, destrancando no `city_ready`;
    - remove a abertura pelo céu;
    - os avisos do começo (Steam ausente, loja sem resposta) aparecem quando a cidade fica pronta.
  - Teste: `tests/check_intro.gd` é reescrito como `tests/check_home_start.gd` (`play_intro = true`):
    - o jogador está em casa poucos quadros depois do início, com a tela clara;
    - a porta fica trancada e mostra a porcentagem;
    - o `city_ready` chega e destranca a porta;
    - imprime o pior quadro durante a montagem, com 7 e com 200 jogos (biblioteca falsa).
  - Manual: abrir o hub e andar pela casa enquanto a cidade monta.
  - Commit: `Fase 9.3: nascer em casa`
- [ ] **9.4 Estante da biblioteca** (Sonnet · medium)
  - Faz:
    - `components/game_portal/game_info.gd`, com o `GamePortal` passando a usá-lo;
    - `worlds/home/library_shelf.gd` (caixas, páginas, filtro, segurar E para jogar, volta para a estante);
    - a casa põe a estante numa parede.
  - Teste: `tests/check_shelf.gd` (Steam falsa no launcher):
    - quantidade de caixas por página;
    - páginas e filtro com 200 jogos falsos;
    - o cartão da caixa é igual ao do portal do mesmo jogo;
    - segurar E chama `launch` com a origem = estante;
    - no `session_ended`, o jogador continua em casa e a tela clareia.
    - `check_look_card` e `check_portal_regression` passam.
  - Commit: `Fase 9.4: estante da biblioteca`
- [ ] **9.5 Mural dos amigos** (Sonnet · medium)
  - Faz:
    - `GamePortal.get_arrival_transform()`, com a busca passando a usá-lo;
    - `worlds/home/friends_wall.gd` (cartões, cartão vazio, E leva até a porta ou até a praça);
    - a casa põe o mural na outra parede.
  - Teste: `tests/check_friends_wall.gd`, com amigos falsos (`FriendsService._set_friends`, como no `check_phase5`):
    - um cartão por amigo online, com quem joga primeiro;
    - o cartão vazio sem amigos;
    - E leva à porta certa, virado para ela.
    - `check_fast_travel` passa.
  - Commit: `Fase 9.5: mural dos amigos`
- [ ] **9.6 Configurações separadas do menu** (Sonnet · medium)
  - Faz: `ui/settings_view.gd` com as três abas. O `PauseMenu` passa a usá-lo, e nada muda na tela, exceto a linha nova "E · interagir (porta, estante, mural, computador)" nas teclas.
  - Pode rodar em paralelo à 9.1–9.3 (janela 1).
  - Teste:
    - `check_pause_menu` passa (ajustando só o caminho até os controles, se precisar);
    - `tests/check_settings_view.gd` monta um `SettingsView` sozinho e confere que mudar a qualidade e o "Bússola e mapa" grava no `config.cfg` (com cópia e devolução).
  - Commit: `Fase 9.6: configurações separadas do menu`
- [ ] **9.7 Tela 3D e o computador** (Opus · high: entrada do mouse em 3D)
  - Faz:
    - `components/screen_3d/screen_3d.gd`;
    - no `player.gd`: `focus_on`/`leave_focus`;
    - a mesa com o computador na casa, com `SettingsView` e "Sair do hub" na tela.
  - Teste: `tests/check_screen_3d.gd`:
    - E foca: a câmera chega à pose, o mouse fica visível e o jogador não anda;
    - um clique simulado no ponto do "Bússola e mapa" troca a opção;
    - digitar num campo funciona;
    - o primeiro Esc tira o foco do campo e o segundo devolve a câmera;
    - o menu de pausa não abre durante o foco.
  - Manual: captura da câmera focada, para ver se o texto fica legível.
  - Commit: `Fase 9.7: tela 3D e computador`
- [ ] **9.8 Busca, mapa e volta dentro de casa** (Sonnet · medium)
  - Faz:
    - na busca em casa, Enter = ir até a porta (com a dica);
    - o mapa abre com "Você está em casa";
    - o `GamePortal` não puxa o jogador que está em casa quando um jogo aberto por fora fecha.
  - Teste: `tests/check_home_overlays.gd`. `check_search`, `check_minimap` e `check_phase4` passam.
  - Commit: `Fase 9.8: busca e mapa dentro de casa`
- [ ] **9.9 O loft** (Opus · high: visual)
  - Faz: o visual do interior, todo por código.
    - Piso de madeira, parede de tijolo ou concreto, tapete, sofá, luminárias quentes e uma faixa de néon.
    - O janelão mostra um horizonte de prédios (shader) que segue dia e noite pelo grupo `city_night`.
    - A estante, o mural e a mesa ganham o acabamento final.
    - Planta inicial: janelão ao norte, estante a oeste, mural a leste, mesa perto da janela e porta ao sul. Nasce-se olhando para a janela.
  - Texturas: se faltar madeira ou tecido, **peço permissão antes de baixar** do ambientCG, com nome, tamanho e licença, e só entra o que o jogo usa.
  - Teste: `check_home` confere que nada fica fora da sala e que a passagem até cada móvel está livre (física). Manual: capturas de noite e de dia, nas qualidades Leve e Alta.
  - Commit: `Fase 9.9: o loft`
- [ ] **9.10 A porta "Casa" na praça** (Opus · high: visual e posição)
  - Faz: a fachada da porta "Casa" (moldura, luz e um néon "CASA" que acende à noite) e a posição final na praça. Ela não bate no chafariz, na estação, na roda de amigos nem no caminho de quem anda pela praça. Aparece no minimapa como um marco.
  - Teste: em `check_home`, uma conferência geométrica como a do metrô. `check_metro`, `check_holograms` e `check_phase6_audio` passam.
  - Manual: capturas de dia e de noite.
  - Commit: `Fase 9.10: porta de casa na praça`
- [ ] **9.11 Desempenho e docs** (Sonnet · low; Opus se a medida pedir ajuste)
  - Faz:
    - `tools/medir_desempenho.gd` ganha um trecho dentro de casa; roda no notebook (comparação relativa) e anota;
    - README: a casa, o E, a estante, o mural e o computador;
    - ROADMAP: Fase 9 feita;
    - CLAUDE.md: mapa com `worlds/home/`, `components/travel_door/` e `components/screen_3d/`;
    - `tests/README.md`: os testes novos e o `play_intro`;
    - plano marcado;
    - `git branch -f fase-9 HEAD`.
  - Commit: `Fase 9.11: documentação`

## Riscos
- **Luz de fora dentro de casa:** o ambiente do céu e o sol vazam para dentro. O ambiente da câmera e a camada de render cuidam disso; a 9.2 confere em captura logo cedo.
- **Montagem em segundo plano engasga:** a compressão das capas custa ~6 ms por imagem. O orçamento por quadro e a medida da 9.3 (pior quadro) pegam isso. Se não bastar, a montagem pausa enquanto o jogador olha a estante (decisão nova → modo plan).
- **Entrada do mouse na tela 3D:** a conversão de coordenadas e o foco do teclado no `SubViewport` são a parte mais delicada. A 9.7 é Opus e tem teste com clique simulado. O plano B é o mesmo `SettingsView` num painel 2D emoldurado sobre o monitor.
- **Texto ilegível no monitor:** a pose da câmera e o tamanho do `SubViewport` são ajustados por captura a 1280×720 e em tela cheia.
- **Testes dependem da praça:** com `play_intro = false`, tudo continua como hoje, e só os testes novos ligam a casa.
- **Abrir jogo da estante e voltar:** a volta copia o que o portal faz (clarear só se o hub não dormiu). O teste cobre os dois casos.
- **Esc em dobro:** o Esc da tela 3D, do campo de texto e do menu de pausa podem brigar. A ordem é testada na 9.7.
- **Duas baterias ao mesmo tempo (claude-squad):** o `user://` é compartilhado entre os worktrees, e os testes que guardam e devolvem o `config.cfg` podem apagar a chave ou as opções. Por isso, só uma instância roda testes de cada vez.
- **Instância nova sem o plano:** ela nasce da `fase-8`. Começar com `git merge --ff-only guitavares/game-hub`.

## Fora do escopo
- Avatar visível, personalizar a casa (mover móveis, trocar cores), cabana ou outros temas e estatísticas na parede. Anotar no "Depois" do ROADMAP como "Casa, parte 2".
- Visitar a casa de amigos (V4, Horizonte).
- Entrar na partida de um amigo pela Steam (join): o mural só leva até a porta.
- Modelos glTF de móveis.
- Push e merge: nada vai para o GitHub sem o dono pedir.

## Decisões tomadas durante a fase
- 2026-10-06: interior à parte, interação física com tela clicável, casa na hora com a cidade montando lá fora, loft feito por código (dono).

## Checklist de teste manual (fim da fase)
No notebook (Omarchy), qualidade **Leve**:
1. F5. Em ~1 s você está no loft, de noite, com a janela mostrando prédios. A porta diz "Montando a cidade… N%" e destranca sozinha.
2. Olhar uma capa na estante: aparece o cartão com o bairro e as horas. A placa da seta passa a página; a do filtro mostra só "Cartas".
3. Segurar E no Balatro: a tela escurece, o jogo abre, e ao fechar você está de volta em casa, na frente da estante.
4. Mural: os amigos online aparecem (ou o cartão "Configure os amigos no computador"). E num amigo jogando leva até a porta do jogo dele.
5. E no computador: a câmera chega na tela. Trocar a qualidade e o volume com o mouse. Esc volta.
6. Esc em casa: o menu de pausa de sempre.
7. E na porta: a tela escurece e você aparece na praça, ao lado da porta "Casa", com a bússola e o minimapa. E nela traz de volta.
8. Na cidade, entrar num prédio: o jogo abre e volta para a porta do prédio, como sempre.

No desktop (a partir de 18/10): o mesmo na Alta, mais `bash tests/run_tests.sh` e a medida.

## Verificação
1. `bash tests/run_tests.sh` ao fim de cada subetapa: `RESULTADO GERAL: TUDO OK`.
2. `check_home_start`, `check_shelf` e `check_friends_wall` também com a biblioteca falsa de 200 jogos.
3. Capturas (9.2, 9.7, 9.9 e 9.10) só na pasta temporária da sessão, nunca no repositório (mostram capas de jogos).
