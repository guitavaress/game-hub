# Fase 14: O hub no Omarchy

**Status:** **reaberta** (2026-10-14). A parte 1 (14.0–14.12, o launcher) está feita no Linux. A [parte 2](#parte-2-janelas-no-mundo) pôs o compositor e as janelas dos apps dentro do mundo, como o Waylandcraft. A [parte 3](#parte-3-a-mesa-com-três-monitores) (2026-10-15) troca os telões e a estante por três monitores na mesa do computador, com os atalhos, o menu e a barra do Omarchy.
**Branch:** `fase-14`, criada a partir da `fase-linux` (que ainda não foi para a `main`; quando for, `git rebase --onto main fase-linux fase-14`). Checkout principal (`~/git/game-hub`).

### Trabalho com o Nimbalyst
- **Trilha principal** (sessão comum, branch `fase-14`): faz as subetapas em ordem, é a única que marca `[x]` e escreve em "Decisões tomadas durante a fase", e junta a paralela.
- **Trilha paralela** (uma por vez, em **New Worktree**): só subetapas que não mexem nos arquivos da principal naquela janela.

  | Janela | Principal | Paralela | Por que não brigam |
  |---|---|---|---|
  | 1 | 14.1 → 14.2 → 14.3 | 14.8 (estado do sistema) | a 14.8 só cria arquivos em `autoload/platform/` e `autoload/`, e soma linhas no `check_platform.gd` e no `project.godot` |
  | 2 (depois da 14.3 e da 14.8 juntas) | 14.5 → 14.6 → 14.7 | 14.4 (apps no Windows) | a 14.4 cria só o backend do Windows, um teste e uma linha no `testes.yml` |
  | 3 (depois da 14.7 e da 14.4 juntas) | 14.11 | 14.9 → 14.10 (painel e autostart) | a 14.9/14.10 mexem no `home.gd` (só o painel fixo) e no `computer_desk.gd`; a 14.11 mexe no `hub_window.gd` e no `app_launcher.gd` |
  | 4 (parte 2, depois da 14.15) | 14.16 → 14.17 → 14.18 (Rust) | 14.19 → 14.20 (telão e telões na casa) | a principal só mexe em `native/`; a paralela cria `components/app_window_3d/` e `worlds/home/app_screens.gd` e soma uma linha no `home.gd`, usando uma fonte de janela falsa |

  A 14.0, a 14.12, a 14.13, a 14.14 e a 14.23 ficam só na principal. As duas trilhas da janela 4 se juntam antes da 14.21.
- **Passo a passo da paralela:** igual ao da [Fase 13](fase-13.md#trabalho-com-o-nimbalyst): New Worktree com o modelo e o esforço da subetapa; primeira mensagem "execute a subetapa 14.N do plano `docs/plans/fase-14.md`, sem marcar o plano; faça o commit com o e-mail noreply e me diga o hash"; para juntar, na principal e entre duas subetapas: `git merge --no-ff worktree/<nome> -m "Fase 14.N: junta a trilha paralela"`, `bash tests/run_tests.sh` e marcar `[x]` com o hash. Uma bateria por vez.

## Contexto
O primeiro passo da V5 ([ROADMAP › Fase 14](../ROADMAP.md#fase-14-o-hub-no-omarchy)): o hub deixa de ser só um launcher da Steam e começa a ser parte do desktop no Linux. Quando a fase acabar:
- uma **estante de apps** na casa mostra os programas instalados (Brave, terminal, Spotify, Obsidian...), e abrir um deles funciona como abrir um jogo: a tela "Abrindo…", o hub some, e volta quando a janela do app fecha;
- um **painel do sistema** na parede, acima do computador, mostra a hora, a bateria, o Wi-Fi e o volume;
- um interruptor no computador faz o hub **abrir ao entrar no Omarchy**, e um **atalho** (colado à mão no `bindings.lua`) chama o hub de volta.

Levantamento (só leitura):
- **Abrir e voltar** (`autoload/game_launcher.gd`): estados IDLE → LAUNCHING → RUNNING, consulta numa thread a cada 2 s, sinais `launch_started`/`game_started`/`session_ended(app_id: int, ...)`. Tudo é chaveado por `app_id` da Steam, e quem ouve (portal, estante, `ScreenFade`, `GameScreen`, HUD, jogador) lê nome e capa do `SteamLibrary`/`GameArt`.
- **Janela** (`autoload/hub_window.gd` + `autoload/platform/window_host*.gd`): `sleep(false)` cobre a tela, `minimize_now()` esconde, `wake()` traz de volta. No Hyprland, esconder = mover para `special:gamehub`, e voltar = de volta ao workspace guardado, com foco. O `WindowHostHyprland` já lista janelas (`hyprctl clients -j`), acha a do hub pelo pid e tem `_dispatch` com a sintaxe Lua e a antiga.
- **Neste notebook:** ~110 arquivos `.desktop` em `~/.local/share/applications` e `/usr/share/applications`. Os jogos da Steam também têm `.desktop` (`Exec=steam steam://rungameid/...`), e os web apps do Omarchy usam `omarchy-launch-webapp`. O navegador é o **Brave Origin** e o terminal é o **foot**. O Brave roda num processo só: uma janela nova tem o **mesmo pid** da antiga, então achar a janela do app pelo pid não serve; serve "a janela nova que apareceu depois do clique".
- **Omarchy** abre apps com `uwsm-app -- <id>.desktop` (também há `gtk-launch`) e tem `omarchy-launch-or-focus <padrão> <comando>`, que foca uma janela pelo título/classe ou abre o programa. A config do Hyprland é Lua (`~/.config/hypr/bindings.lua`, `o.bind(...)`).
- **Sistema:** bateria em `/sys/class/power_supply/BAT0/{capacity,status}`; rede pelo NetworkManager (`nmcli -t -f TYPE,STATE,CONNECTION dev`); volume pelo `wpctl get-volume @DEFAULT_AUDIO_SINK@`.
- **Casa:** os móveis que mudam de lugar ficam em `Home.MOVABLE` e nos `placements` de cada disposição (`profiles/home_catalog.tres`). O lugar `norte_esquerda` (à esquerda do janelão, ~3,4 m de parede) está livre nas 3 disposições. O computador fica fixo em `norte_direita`. O `SettingsView.add_page` já é usado pelo computador para a aba "Casa".
- **Regra 5:** `tests/check_platform.gd` varre o projeto atrás de código de sistema fora de `autoload/platform/` (lista `PLATFORM_ONLY`). O GitHub Actions (`testes.yml`) roda os testes de plataforma no Windows e no Linux.

## Pronto quando
- **App como jogo:** no notebook, segurar E no Brave ou no foot, na estante de apps, mostra "Abrindo…", o hub some, o app abre no lugar dele, e ao fechar a janela do app o hub volta na frente da estante.
- **Volta pelo atalho:** com um app aberto, o atalho do `bindings.lua` traz o hub de volta (o app continua aberto).
- **Painel certo:** a bateria e o Wi-Fi do painel batem com os da barra do Omarchy; a hora é a do relógio.
- **Autostart:** ligar o interruptor no computador cria `~/.config/autostart/game-hub.desktop`; ao sair e entrar de novo no Omarchy, o hub abre sozinho. Desligar apaga o arquivo.
- **Plataforma isolada:** nenhum `.desktop`, `/sys`, `nmcli`, `wpctl`, `uwsm-app` ou Menu Iniciar fora de `autoload/platform/` (`check_platform` com a lista nova).
- **Windows mínimo:** a lista de apps do Menu Iniciar é lida no Windows (teste no GitHub Actions; abrir de verdade fica para a trilha do desktop).
- A medida em casa no notebook (Leve) não piora mais de ~2 FPS.

## Decisões de arquitetura
- **Apps na casa, não na cidade** (decisão do dono, 2026-10-13): uma estante de apps em `norte_esquerda`. A cidade, o mapa, o metrô e a busca não mudam, e a Fase 15 não briga com um bairro novo.
- **`AppLauncher` separado do `GameLauncher`:** um autoload novo, com a mesma forma (estados, `launch(app_id, origem)`, um `app_session_ended` sempre depois de cada `launch`), mas chaveado pelo id do `.desktop` (String). O `GameLauncher` foi afinado com muito teste (`check_phase4`); misturar app nele arrisca o que já funciona. Os dois não rodam juntos: cada um recusa se o outro estiver ocupado.
  Descartado: um launcher genérico com "alvos" (Steam e app): mais bonito, mas é reescrever o coração do hub.
- **Lista de apps como "fonte", igual à Steam:** `DesktopApp` (dado: id, nome, ícone, categorias, classe da janela) + `AppLibrary` (autoload: lista, ordem, filtros, ocultos) + `DesktopApps` em `autoload/platform/` (estático, como o `SteamClient`) com backend por sistema: Linux lê os `.desktop` (XDG) e acha os ícones no tema; Windows lê os atalhos `.lnk` do Menu Iniciar (sem ícone: a caixa mostra a inicial).
- **Filtro dos apps:** entram só `Type=Application` visíveis (`NoDisplay`/`Hidden` fora, `OnlyShowIn`/`NotShowIn` pelo `XDG_CURRENT_DESKTOP`, `TryExec` que existe). Jogos da Steam (`steam://rungameid`) ficam fora, porque já estão na cidade e na estante de jogos. O usuário esconde o resto no `config.cfg` (`[apps] ocultos = "avahi-discover,bvnc"`), sem tela para isso nesta fase. Ordem: abertos pelo hub mais recentemente primeiro, depois por nome.
- **Abrir:** no Linux, `uwsm-app -- <id>.desktop` quando existir (é como o Omarchy abre); senão `gtk-launch <id>`; senão o `Exec` do arquivo, sem os `%f/%u`. No Windows, `OS.shell_open` no `.lnk`.
- **Achar e acompanhar a janela do app (só Hyprland):** antes de abrir, guardamos os endereços das janelas; a primeira janela **nova** do tiling (de preferência com a classe do `StartupWMClass`) é a do app. O app abre no workspace do hub (ele "toma o lugar" do hub, sem tela cheia e sem monitor de jogo). A sessão acaba quando essa janela some. Isso vive no `WindowHost` (a `HubWindow` repassa), porque é ele quem fala com o `hyprctl`.
- **Fallback sem acompanhar** (Windows, Linux fora do Hyprland, ou app que só focou uma janela que já existia): o hub some depois de ~10 s, e a sessão acaba quando o hub **volta a ter foco** (o atalho, ou clicar nele). Regra simples: **qualquer `HubWindow.wake()` encerra a sessão de app**, e a `HubWindow` avisa `focus_returned` quando ganha foco escondida.
- **Atalho global sem processo novo:** a linha do `bindings.lua` usa o `omarchy-launch-or-focus` com o título da janela do hub: se o hub está aberto, foca; se não, abre. Focar o hub escondido o faz ganhar foco → `focus_returned` → sessão de app acaba → hub volta. A 14.1 confere se o Hyprland mostra mesmo uma janela do `special:` ao focá-la; se não, um script curto em `tools/linux/` faz o "trazer". (O spike confirmou: mostra; sem script.)
  Descartado: instância única com mensagem entre processos (abrir uma Godot nova só para avisar leva segundos).
- **Atalho durante um jogo da Steam:** fica como hoje (o hub mostra a tela "Jogando"); o atalho só encerra sessões de **app**.
- **Autostart pelo hub, atalho à mão** (decisão do dono): um interruptor numa aba **Sistema** do computador (só no Linux) cria ou apaga `~/.config/autostart/game-hub.desktop`, com `Exec=<godot> --path <projeto>` (de `OS.get_executable_path()` e do `res://` globalizado). A mesma aba tem "Copiar a linha do atalho" (para colar no `bindings.lua`). O hub nunca escreve na config do Hyprland.
- **Painel só mostra** (decisão do dono): `SystemStatus` (autoload) pergunta a `SystemInfo` (estático, em `autoload/platform/`) a cada 5 s, numa thread, e para enquanto o hub dorme. O painel é **fixo** na parede norte, acima do computador (como o computador, não muda com a disposição). A hora vem do `Time` (não é código de sistema).
- **Tela "Abrindo" de app:** a `GameScreen` ganha `show_app_opening(nome, ícone)`: o ícone no lugar do logo e "Abrindo…". Sem tela "Usando" (o hub fica escondido enquanto o app está aberto).

## Subetapas
- [x] **14.0 Preparação** (Sonnet · low) — *só principal*
  - Faz: confere com o dono a mudança não salva no `project.godot` (ações `ui_*` que o editor escreveu) e decide se entra ou sai; `git branch -f fase-14 fase-linux` (a `fase-14` não tem commits próprios: confirmar com `git log fase-linux..fase-14` vazio); muda para a `fase-14`; copia este plano para `docs/plans/fase-14.md`.
  - Teste: `bash tests/run_tests.sh` → TUDO OK.
  - Commit: `Fase 14.0: plano`
- [x] **14.1 Spike: janelas de app no Hyprland** (Opus · high) — *precisa do dono no notebook*
  - Faz: um script descartável (fora do repositório, na pasta temporária) que, a partir do hub rodando com `godot --path`, confirma: (a) a classe e o título da janela do hub; (b) `uwsm-app -- foot.desktop` e `uwsm-app -- brave-origin.desktop` abertos pela Godot geram uma janela nova achável pela lista antes/depois; (c) `omarchy-launch-or-focus "Game Hub" ...` com o hub em `special:gamehub` dá foco a ele (e a Godot recebe `NOTIFICATION_APPLICATION_FOCUS_IN`).
  - Arquivos: só o plano ("Decisões tomadas durante a fase", com os resultados e o comando do atalho que funcionou).
  - Commit: `Fase 14.1: resultado do spike das janelas de app`
- [x] **14.2 Lista de apps no Linux** (Sonnet · medium)
  - Faz: o dado `DesktopApp` e o leitor de `.desktop` (pastas XDG, nome em pt_BR quando houver, filtros da decisão, o de `~/.local` vence o de `/usr/share` com o mesmo id); `AppLibrary` com lista, categorias (Internet, Escritório, Mídia, Gráficos, Programação, Sistema, Jogos, Outros, a partir das `Categories` do XDG), ocultos do `config.cfg` e a ordem por "aberto por último" (`[apps] ultimos` no `config.cfg`).
  - Arquivos: `autoload/desktop_app.gd` (novo), `autoload/app_library.gd` (novo, autoload), `autoload/platform/desktop_apps.gd` + `desktop_apps_backend.gd` + `desktop_apps_linux.gd` (novos), `autoload/app_config.gd` (seção `[apps]`), `project.godot` (autoload), `tests/check_platform.gd` (lista `PLATFORM_ONLY`: `".desktop\""`, `uwsm-app`, `gtk-launch`).
  - Teste: `tests/check_desktop_apps.gd` com uma pasta de exemplo em `tests/fixtures/applications/` (um app normal, um `NoDisplay`, um jogo da Steam, um `OnlyShowIn=KDE`, um com `TryExec` inexistente, um nome em pt_BR, o mesmo id em duas pastas).
  - Manual: nenhum (ainda não aparece).
  - Commit: `Fase 14.2: lista de apps do Linux`
  - Feito: nomes de apps com espaço (web apps do Omarchy, ex.: "Basecamp") funcionam como id. A categoria que sobra se chama `diversos` (o `check_profiles` proíbe `"outros"` entre aspas, que é um bairro); o nome na tela continua "Outros".
- [x] **14.3 Ícones dos apps** (Sonnet · medium)
  - Faz: achar o arquivo do ícone (caminho absoluto, ou pelo nome no tema: `~/.local/share/icons`, `/usr/share/icons/hicolor` e o tema do sistema, tamanhos 256 → 128 → scalable → 48, e `/usr/share/pixmaps`); carregar PNG e SVG (SVG rasterizado em 256 px) numa thread, com cache em memória; sinal `icon_ready(app_id)`.
  - Arquivos: `autoload/platform/desktop_apps_linux.gd` (achar o arquivo), `autoload/app_library.gd` (carregar e guardar a textura).
  - Teste: `tests/check_desktop_apps.gd` ganha ícones de exemplo (um PNG, um SVG, um caminho absoluto, um que não existe).
  - Commit: `Fase 14.3: ícones dos apps`
  - Feito: o tema vem do `gtk-icon-theme-name` (GTK 3/4), depois hicolor, Adwaita e Yaru; o `AppLibrary` ganhou `get_icon`/`request_icon`/`has_icon_result`. **Armadilha:** uma lambda que usa o `self` e roda em `WorkerThreadPool` corrompe a memória ao fechar a Godot; use método com `.bind()` (como o `_load_icon_task`).
- [x] **14.4 Lista de apps no Windows** (Sonnet · medium) — *trilha paralela, janela 2*
  - Faz: o backend do Windows lê os `.lnk` de `%ProgramData%` e `%AppData%\Microsoft\Windows\Start Menu\Programs` (com subpastas), tira desinstaladores e atalhos de jogos da Steam (`.url` com `steam://`); id = caminho relativo; abrir = `OS.shell_open`. Sem ícone.
  - Arquivos: `autoload/platform/desktop_apps_windows.gd` (novo), `autoload/platform/desktop_apps.gd` (escolhe o backend), `tests/check_desktop_apps_windows.gd` (novo; com uma pasta de exemplo; no Windows, também a pasta de verdade, sem exigir nenhum app), `.github/workflows/testes.yml` (mais um teste).
  - Manual: nenhum agora (na trilha do desktop, ver a estante no Windows).
  - Commit: `Fase 14.4: lista de apps do Windows`
  - Feito: commit `f4c1cec` na trilha paralela, juntado na principal.
- [x] **14.5 Janelas de app no WindowHost** (Opus · high)
  - Faz: no `WindowHost`, `can_track_windows()`, `list_window_addresses()`, `find_new_window(antes, classe)` e `window_exists(endereço)` (a base responde "não sei acompanhar"); no Hyprland, pelo `hyprctl clients -j`, ignorando flutuantes, a do hub e as do `special:`. Na `HubWindow`: repassar isso e o sinal `focus_returned` (foco de volta com o hub escondido, depois de ~1 s de folga).
  - Arquivos: `autoload/platform/window_host.gd`, `autoload/platform/window_host_hyprland.gd`, `autoload/hub_window.gd`.
  - Teste: `tests/check_window_host.gd` ganha casos com o `hyprctl` falso (janela nova achada, classe preferida, flutuante ignorada, janela some).
  - Commit: `Fase 14.5: achar e acompanhar a janela de um app`
  - Feito: entre várias janelas novas, a classe (`class` ou `initialClass`, sem ligar para maiúsculas) vence; empatou, vence o `focusHistoryID` menor (a que ganhou o foco por último). O `window_exists` diz "existe" se o `hyprctl` não responder (melhor não encerrar a sessão por engano). O `focus_returned` só vale depois de `minimize_now` (não na tela "Abrindo" visível). As quatro funções podem rodar numa thread. Conferido contra o Hyprland de verdade (só leitura).
- [x] **14.6 Abrir um app e voltar** (Sonnet · medium)
  - Faz: o autoload `AppLauncher` (IDLE → LAUNCHING → RUNNING; consulta numa thread a cada 1 s; acha a janela em até 10 s, senão segue "sem acompanhar"; acaba quando a janela some, no `focus_returned`, em qualquer `woke_up` ou com Esc enquanto abre); `DesktopApps.launch(app)`; o `GameLauncher` e o `AppLauncher` recusam abrir se o outro estiver ocupado; a `GameScreen` mostra `show_app_opening`; o HUD mostra o aviso de erro ("Não consegui abrir X").
  - Arquivos: `autoload/app_launcher.gd` (novo), `autoload/platform/desktop_apps_linux.gd` (abrir), `autoload/game_launcher.gd` (uma linha no `_check_can_launch`), `ui/screen_fade.gd`, `ui/game_screen.gd`, `ui/hud.gd`, `project.godot`.
  - Teste: `tests/check_app_launcher.gd` com abridor e janelas falsos: sessão completa, janela que nunca aparece, cancelar com Esc, `focus_returned`, recusa quando o `GameLauncher` está ocupado, e sempre um `app_session_ended` por `launch`.
  - Commit: `Fase 14.6: abrir um app e voltar`
  - Feito: sinais `app_launch_started(id, origem)` e `app_session_ended(id, origem, ok, msg)` (ids são String). Pontos de ligação para a estante (14.7): `AppLauncher.launch(id, self)`, `is_busy()`. O `Player._can_interact` e o `leave_focus` também escutam o `AppLauncher`. Testes com `threaded = false` (consulta sem thread) e `opener`/`can_track`/`list_windows`/`window_reader` falsos. Linux abre com `uwsm-app -- <id>.desktop` → `gtk-launch` → `Exec`; o app herda a saída do hub (sem `setsid` por enquanto). **Falta ver ao vivo** (nada foi aberto de verdade nos testes): a conferência é o checklist da 14.7.
- [x] **14.7 A estante de apps** (Sonnet · medium; Opus · high se o visual travar)
  - Faz: um móvel novo na casa, mais estreito que a de jogos (5 × 3 caixas quadradas com o ícone; sem ícone, a inicial na cor da categoria), com páginas e filtro por categoria (reaproveita `LibraryShelf.ShelfButton`), cartão ao olhar ("Brave · Internet"), segurar E abre pelo `AppLauncher` e a volta põe o jogador na frente dela. Entra em `Home.MOVABLE` como `"apps"` e em `norte_esquerda` nas 3 disposições.
  - Arquivos: `worlds/home/app_shelf.gd` (novo), `worlds/home/home.gd` (`MOVABLE`), `profiles/home_catalog.tres` (`placements`).
  - Teste: `tests/check_app_shelf.gd` (com a pasta de exemplo: caixas, páginas, filtro, abrir chama o `AppLauncher` com a origem certa, volta na frente); `check_home_custom` continua passando com o móvel novo.
  - Manual: captura em casa, de frente para a janela: a estante cabe entre a parede e o janelão.
  - Commit: `Fase 14.7: estante de apps na casa`
  - Feito: `AppShelf` (`worlds/home/app_shelf.gd`), id `"apps"` em `Home.MOVABLE` e em `norte_esquerda` nas 3 disposições (`home_catalog.tres` e `tools/gerar_layouts_casa.gd`). O `check_home` passou a incluir o móvel nos testes de lugar, passagem e sobreposição, e o `home_snapshot` ignora o `AppShelf` (como a estante de jogos). Captura conferida (fora do repositório): a estante cabe entre a parede e o janelão. Caixa sem ícone = inicial na cor da categoria. **Ainda não visto abrindo um app de verdade:** é o item 2 e 3 do checklist da fase.
- [x] **14.8 Estado do sistema** (Sonnet · medium) — *trilha paralela, janela 1*
  - Faz: `SystemInfo` (estático, em `autoload/platform/`) com backend Linux: bateria (`/sys/class/power_supply/BAT*`: %, carregando, tem bateria?), rede (`nmcli`: tipo, conectado, nome) e volume (`wpctl`: %, mudo); a base responde "não sei". O autoload `SystemStatus` pergunta a cada 5 s numa thread, para enquanto o hub dorme e avisa `changed`.
  - Arquivos: `autoload/platform/system_info.gd` + `system_info_backend.gd` + `system_info_linux.gd` (novos), `autoload/system_status.gd` (novo), `project.godot`, `tests/check_platform.gd` (`"/sys/class`, `nmcli`, `wpctl`).
  - Teste: `tests/check_system_status.gd` com uma pasta `/sys` de exemplo e respostas falsas do `nmcli` e do `wpctl` (com bateria, sem bateria, sem rede, mudo).
  - Commit: `Fase 14.8: estado do sistema (bateria, rede, volume)`
  - Feito: commit `6b30755` na trilha paralela, juntado na principal (worktree `estado-sistema` mantido para as próximas paralelas).
- [x] **14.9 O painel do sistema** (Sonnet · medium) — *trilha paralela, janela 3*
  - Faz: um painel fixo na parede norte, acima do computador: hora grande (`HH:MM`, dia da semana e data), bateria (ícone e %, "carregando"), Wi-Fi (nome ou "sem rede") e volume (% ou "mudo"); some o que o sistema não sabe (ex.: desktop sem bateria). Label3D e malhas simples, na camada do interior, com a cor do néon.
  - Arquivos: `worlds/home/system_panel.gd` (novo), `worlds/home/home.gd` (cria o painel junto do computador).
  - Teste: `tests/check_system_panel.gd` (com um `SystemStatus` falso: textos certos, linha escondida sem bateria, hora muda).
  - Manual: captura em casa olhando para o computador.
  - Commit: `Fase 14.9: painel do sistema na casa`
  - Feito: commit `61063e7` na trilha paralela, juntado na principal.
- [x] **14.10 Abrir com o sistema** (Sonnet · medium) — *trilha paralela, janela 3*
  - Faz: `Autostart` em `autoload/platform/` (Linux: criar, apagar e conferir `~/.config/autostart/game-hub.desktop`; os outros: "não dá"); uma aba **Sistema** no computador (só onde dá), com o interruptor "Abrir o hub ao entrar no Omarchy" e o botão "Copiar a linha do atalho" (a linha do `o.bind` com o comando da 14.1, para colar no `bindings.lua`).
  - Arquivos: `autoload/platform/autostart.gd` (novo), `worlds/home/system_settings_view.gd` (novo), `worlds/home/computer_desk.gd` (`add_page`), `tests/check_platform.gd` (`/autostart/`).
  - Teste: `tests/check_autostart.gd` com uma pasta de exemplo no lugar de `~/.config/autostart` (cria, confere o `Exec`, apaga).
  - Commit: `Fase 14.10: abrir o hub ao entrar no Omarchy`
  - Feito: commit `a250b54` na trilha paralela, juntado na principal.
- [x] **14.11 Chamar o hub pelo atalho** (Opus · high)
  - Faz: liga o resultado da 14.1: com um app aberto, o atalho traz o hub (encerra a sessão de app, o app fica aberto); com o hub parado em outro workspace, o atalho o foca; durante um jogo, nada muda. Se a 14.1 pediu, o script `tools/linux/game-hub-chamar` (e a linha copiada da 14.10 passa a usá-lo).
  - Arquivos: `autoload/hub_window.gd`, `autoload/app_launcher.gd` e, se preciso, `autoload/platform/window_host_hyprland.gd` e `tools/linux/`.
  - Teste: `tests/check_app_launcher.gd` (o `focus_returned` durante um jogo não faz nada).
  - Manual: passo a passo para colar a linha no `~/.config/hypr/bindings.lua`.
  - Commit: `Fase 14.11: chamar o hub pelo atalho`
  - Feito: sem script (a 14.1 confirmou o plano A). App aberto: o `focus_returned` já encerrava a sessão (14.6). Jogo rodando: o `GameLauncher` ouve o `focus_returned` e chama `HubWindow.hide_again()`, que no Hyprland fecha o `special:gamehub` (`hl.dsp.workspace.toggle_special('gamehub')`, ou `togglespecialworkspace gamehub` no antigo) só se ele estiver aberto, depois de focar o monitor dele; no Windows não faz nada. Jogo ainda abrindo: o hub fica à vista (Esc cancela), e o `minimize_now` de quando o jogo aparece o esconde de novo. **O toggle_special não foi rodado ao vivo** (abriria um special na tela do dono): conferir no checklist.
- [x] **14.12 Medida e documentação** (Sonnet · medium) — *só principal*
  - Faz: medida em casa no notebook (Leve) com `tools/medir_desempenho.gd` (`MEDIDA_CASA`), comparada à da Fase 13; README (estante de apps, painel, autostart, atalho, `[apps] ocultos`), ROADMAP (Fase 14 feita), PLATAFORMA (apps, sistema, autostart), CLAUDE.md (mapa: `app_library`, `app_launcher`, `system_status`, `platform/desktop_apps*`, `system_info*`, `autostart`).
  - Commit: `Fase 14.12: documentação`
  - Feito: README, ROADMAP, PLATAFORMA e CLAUDE.md atualizados. Medida lado a lado (notebook, Leve, 7 jogos, 22 h; a fase 13 numa cópia do commit `6719022`, no mesmo dia, com o Brave aberto): ver "Decisões tomadas durante a fase".

## Riscos
- **A janela do app não é achada** (app que só foca uma janela que já existia, como o Spotify aberto, ou que abre um launcher flutuante antes): o fallback "sem acompanhar" cobre; o teste da 14.6 tem o caso, e a 14.1 mostra cedo como o Brave e o foot se comportam.
- **Uma janela qualquer aparece no meio** (notificação, outro programa) e é tomada pela do app: preferir a classe do `StartupWMClass` e ignorar flutuantes; aceitar o erro raro (a sessão só acaba mais cedo).
- **Focar uma janela do `special:` não a mostra** (14.1): o plano B é o script curto que move o hub para o workspace atual.
- **Muitos apps sem graça na lista** (~100 entradas, muitas de sistema): filtros do XDG + `ocultos` no `config.cfg` + filtro por categoria. Se ficar ruim, uma lista "fixados" vira item de "Depois".
- **SVG pesado ou quebrado**: carregar numa thread, com limite de tamanho; quebrado cai na inicial.
- **Atalho durante um jogo** pode confundir (o hub mostra "Jogando" no `special:`): definido como "nada muda"; conferir na 14.11.

## Fora do escopo
- Apps na cidade (bairro "Apps"): descartado pelo dono em 2026-10-13.
- Mudar o volume pelo painel (só mostra, decisão do dono); brilho e Bluetooth.
- Escrever o atalho no `bindings.lua` pelo hub; instalar o hub no menu de apps do Omarchy (um `.desktop` em `~/.local/share/applications`); exportar o hub como executável.
- Tela para esconder apps ou fixar favoritos (só o `config.cfg` por enquanto).
- Abrir apps no Windows de verdade e o autostart no Windows: o backend do Windows só lista (a conferência vai para a trilha do desktop).
- O hub como a sessão inteira do Hyprland (Horizonte).

## Decisões tomadas durante a fase
- 2026-10-13: apps numa estante da casa; autostart pelo hub e atalho à mão; painel só mostra (decisões do dono, no planejamento).
- 2026-10-13: resultado do spike (14.1), no notebook (Hyprland 0.56):
  - **Janela do hub:** classe `Game Hub` (o `config/name` do projeto) e título `Game Hub (DEBUG)` rodando com `godot --path` (sem o "(DEBUG)" num executável exportado). O atalho procura pela classe.
  - **Abrir pela Godot:** `OS.create_process("uwsm-app", ["--", "<id>.desktop"])` funciona. O foot apareceu em ~0,3 s e o `uwsm-app` virou o próprio foot (o pid devolvido é o do app; ele fica "filho" do hub). O Brave já aberto abriu uma janela **nova** em ~1,1 s, com o pid do Brave antigo ("Opening in existing browser session"): achar pela lista antes/depois funciona, pelo pid não. As duas nasceram no workspace do hub, no tiling (não flutuantes).
  - **O app herda a saída do hub** (stdout): rodando o hub num terminal, o log do app aparece junto. Sem efeito para o usuário; na 14.6, avaliar `setsid` se incomodar.
  - **Atalho (plano A vale, sem script):** com uma janela em `special:gamehub`, `omarchy-launch-or-focus "<padrão>" "<comando>"` abre o `special` por cima da tela, a janela ganha o foco e a Godot recebe `focus_entered` (o `NOTIFICATION_APPLICATION_FOCUS_IN`). Movê-la de volta para o workspace normal (o que o `show_hub` já faz) fecha o `special` sozinho.
  - **Tecla:** `SUPER + G` já é do Omarchy (agrupar janelas). `SUPER + H` está livre. A linha a colar no `~/.config/hypr/bindings.lua` fica:
    `o.bind("SUPER + H", "Game Hub", "omarchy-launch-or-focus 'Game Hub' '<godot> --path <projeto>'")`
    (a 14.10 monta os caminhos de verdade com `OS.get_executable_path()` e o `res://` globalizado). Cuidado conhecido: o padrão também casa com um título de janela que contenha "Game Hub" (ex.: uma aba do navegador).

- 2026-10-14: **medida (14.12)**, notebook, Leve, 7 jogos, 22 h, lado a lado com o commit `6719022` (fim da Fase 13), no mesmo dia e com o Brave aberto (por isso o p99 da cidade andando, 26 ms, é igual nas duas e vale só para comparar):

  | | Fase 13 | Fase 14 |
  |---|---|---|
  | `MEDIDA_CASA` | 60,0 FPS · p99 19 ms · 165 desenhos | 60,0 FPS · p99 19 ms · **193 desenhos** |
  | `MEDIDA_ESPELHO` | 60,0 FPS · p99 17 ms · 73 desenhos | 60,0 FPS · p99 18 ms · 88 desenhos |
  | cidade andando | 58,7 FPS · p99 26 ms · 696 desenhos | 59,2 FPS · p99 26 ms · 720 desenhos |
  | memória / textura | 161 MB / 140 MB | 173 MB / 187 MB |

  Em casa o FPS fica no teto de 60 (VSync) e o p99 não mudou: **a meta (não piorar mais de ~2 FPS) foi cumprida**. A estante de apps e o painel somam ~28 desenhos na casa. Memória de textura +47 MB: tirar a estante de apps do `Home.MOVABLE` baixa só ~5 MB (os 15 ícones da página); o resto não é desta fase (vem dos commits entre as fases 13 e 14: Debug Menu e Sky3D, que já estavam na branch) e **não foi isolado**. Fica para a trilha do desktop, junto com a medida na Alta.

- 2026-10-14: **fase reaberta** (decisão do dono). A experiência que o dono queria é a do **Waylandcraft** (janelas de programas usadas dentro do mundo), e o planejamento da parte 1 entendeu "parte do desktop" como launcher. Escolhas: usar (não só ver), só Linux, Rust + Smithay com godot-rust (exceção MPL-2.0), perfil próprio do Brave, três telões fixos na casa. O launcher da parte 1 vira o plano B. Veja a [parte 2](#parte-2-janelas-no-mundo).
- 2026-10-14: **meta de desempenho é o desktop** (lembrete do dono). A parte 2 tinha posto a meta "no notebook (Leve)"; corrigido: meta no desktop (Alta), notebook só antes/depois. A regra também foi para o CLAUDE.md (Stack).
- 2026-10-14: **resultado do spike (14.14)**, no notebook (Hyprland 0.56). Rust 1.99 instalado pelo mise (`mise use -g rust@stable`, sem `sudo`); o `cargo` chega pelos atalhos do mise.
  - **Crates:** `godot` 0.5.5 (já tem `api-4-7`: não precisa do `api-custom`) e `smithay` 0.7.0 com `default-features = false, features = ["wayland_frontend"]`. São 93 pacotes, ~20 MB; nenhum GPL (MPL-2.0 só nos do godot-rust; o `r-efi` tem LGPL como uma das opções e nem entra no Linux). A semente ficou em `native/compositor/` (com `.gdignore`; veja `spike/LEIA-ME.md`).
  - **(a) Carrega:** "Initialize godot-rust (API v4.7.stable, runtime v4.7.2)". O `.so` em release tem 7,4 MB (o de depuração, 140 MB). Compilar do zero leva ~1,5 min (depuração) e ~4 min (release) no notebook.
  - **(b) O foot aparece:** `WAYLAND_DISPLAY=gamehub-spike foot` abre uma janela (`app_id=foot`, pid certo pelas credenciais do socket). Sem `calloop`: o `ListeningSocket.accept()` e o `dispatch_clients` rodam no `poll()` a cada quadro. O foot avisa que faltam: seleção primária, ativação xdg, escala fracionária, cursor do servidor, ícone, entrada de texto (IME) e decoração do servidor (usa a própria). Nada disso impede o uso.
  - **(c) Teclado:** keymap `br` no `XkbConfig`, código evdev + 8. `echo ação` saiu certo (o `ç` no lugar do `;` e o til morto no do `'`). No teste com janela, o dono digitou acentos, a tecla `/?`, o AltGr e selecionou texto com o mouse: tudo funcionou. A tabela "tecla física da Godot → evdev" do `spike/teste_janela.gd` é a semente da 14.15.
  - **(d) Brave:** `brave-origin --ozone-platform=wayland --user-data-dir=<pasta> --no-first-run` abriu **dentro** do compositor, mesmo com o Brave de sempre aberto fora (outro processo, `app_id=brave-origin`). O perfil novo mostra a tela de boas-vindas do Brave Origin uma vez. **A imagem tem margem de sombra** (1324×764 para 1280×720 pedidos): a 14.16 recorta pela geometria da janela (`xdg_surface.set_window_geometry`).
  - **(e) Custo (notebook, só para comparar):** compilação de depuração 37 ms por cópia; release **1,5 ms** (sem janela) e **2,7 ms** de cópia + **0,9 ms** de subida da textura por quadro com janela, com o foot redesenhando sem parar (60 FPS, pior quadro 16,7 ms). Para a 14.16: trocar a ordem das cores (BGRA → RGBA) na placa de vídeo em vez de pixel a pixel no Rust, e copiar só as linhas com dano. A meta é conferida no desktop.
- **14.15: como a extensão carrega e a tabela de teclas (2026-10-15).**
  - **O ponto único se chama `AppCompositor`** (`autoload/platform/app_compositor.gd`): a Godot 4.7 já tem uma classe `Compositor` (efeitos de render), e o nome batia.
  - **A extensão não entra na lista automática da Godot.** A pasta `native/` tem `.gdignore`, e o `AppCompositor` carrega o `native/hub_compositor.gdextension` com `GDExtensionManager.load_extension()`, só no Linux e só se o `native/bin/libhub_compositor.so` existir. Assim, no Windows e sem compilar, a Godot não mostra erro nenhum; no Linux sem o `.so`, sai uma linha avisando como compilar. O godot-rust aceita ser carregado com o hub já rodando (conferido no `check_compositor`).
  - **Tabela evdev conferida no código da Godot** (driver Wayland, `key_mapping_xkb.cpp`). O spike tinha três erros que o ABNT2 mostraria: o `´` e o `[` chegam como `BRACELEFT`/`BRACERIGHT` (e não `BRACKET...`), o `'` chega como `SECTION` e o `\|` (ao lado do Shift esquerdo) como `QUOTELEFT`. A tecla `/?` do ABNT2 chega **sem código físico**: ela é reconhecida pela letra (`/` ou `?`) e vira o evdev 89. O lado direito (AltGr, Ctrl, Shift, Super) usa o `location` do evento.
  - **Licenças:** `tools/linux/checar_licencas.sh` lê o `cargo metadata` (sem baixar nada) e avalia a expressão SPDX de cada crate: 84 crates, nenhum GPL; MPL-2.0 só nos do godot-rust. Roda no fim do `compilar_compositor.sh` e da bateria.
  - **Bateria:** o `cargo test` (5 testes da conversão de imagem) roda só na bateria inteira, no Linux, com Rust e depois da primeira compilação (`--offline`: a bateria nunca baixa crate). Sem isso, escreve "pulado".
  - **O spike saiu do repositório:** o quadro com teclado e mouse virou `tools/linux/testar_compositor.gd` (usa o ponto único). O teste sem janela do foot sai de cena: a 14.16 põe um cliente Wayland de teste no `cargo test`.
- **14.16: janelas e imagem (2026-10-15).**
  - **O compositor virou um `Core` sem Godot** (`wayland.rs`): o nó `HubCompositor` só chama o `Core` e transforma os eventos em sinais. Assim, o `cargo test` liga o compositor de verdade com um app de teste (crate `wayland-client` 0.31.14, MIT, só nos testes; permissão do dono em 2026-10-15) na mesma thread, sem Godot e sem socket em disco: 10 testes (abrir com nome, título, pid e cor; recorte da sombra; dano; imagem sem dano; `frame done` só para quem pediu; `resize`; `close`; app que cai; título novo; esconder e mostrar).
  - **Recorte pela geometria da janela** (`set_window_geometry`): a sombra fica de fora. O Brave abre em 1280×720 certinho (no spike vinha 1324×764).
  - **A janela nasce "encostada nos quatro lados"** (estados `Tiled`) **e com decoração do lado do servidor** (`xdg-decoration`): o foot e o Brave não desenham barra de título nem sombra. O telão mostra o nome do app.
  - **Só as linhas com dano são copiadas.** A troca de cores (BGRA → RGBA) **continua no Rust**, e não na placa de vídeo: assim a textura sai num formato comum, e o telão usa um material normal, sem shader especial. A troca agora é feita número a número (o compilador processa vários pixels de uma vez): no notebook, só para comparar, a cópia de 1280×720 inteira caiu de 1,5 ms para 1,0 ms. A subida da textura continua inteira (a Godot não tem subida parcial).
  - **Tamanho mínimo dos apps:** pedido 800×450, o Brave respondeu 800×600 (o mínimo do Chromium). O telão deve usar o tamanho **da textura** para achar o pixel do mouse, e não o tamanho que pediu.
  - **Esconder a janela** (commit sem imagem) sai como `window_closed`; se o app mostrar de novo, sai outro `window_opened` com o mesmo id.
  - Sinais novos: `title_changed(id, title)`; funções novas: `resize(id, w, h)` e `close(id)`.
- **14.17: teclado e mouse (2026-10-15).**
  - **O teclado e o mouse também moram no `Core`**, e o app de teste do `cargo test` confere tudo (6 testes novos, 25 no total): o keymap é o do layout pedido (o cabeçalho diz `pc_br_inet(evdev)`), a repetição (30 por segundo depois de 400 ms) fica com o app, as teclas e o Shift chegam na janela com foco, tirar o foco avisa o app, o clique cai na coordenada certa e a rodinha e o touchpad rolam.
  - **Foco explícito:** `focus(id)` (0 = nenhuma). A janela com foco fica "ativa" (o foot mostra o cursor cheio); as outras, não. A janela **nasce sem foco**. Uma tecla para uma janela sem foco dá o foco a ela. O telão chama `focus` ao entrar (E) e `focus(0)` ao sair.
  - **O mouse soma a sombra:** o pixel (0, 0) da textura é o canto do recorte, e não o da imagem do app. O `pointer_motion` recebe pixels da textura e soma o deslocamento (teste com 22 px de sombra). Funções novas: `pointer_leave()` (a mira saiu do telão) e `pointer_axis(dx, dy, wheel)`. A rodinha vai em "dentes" (15 px e 120/120 por dente, como no Linux); o touchpad vai em pixels. O `AppCompositor.wheel_steps(evento)` traduz a rodinha da Godot.
  - **O keymap `br` confirma a tecla `/?`:** a tecla 89 (`AB11`) dá `/` e `?`, como a tradução do ponto único supõe.
  - **Prova no foot** (sem janela): foco, `echo ação` + Enter pelas teclas evdev, e saiu `ação`. Como o foot só avisa as linhas que mudam, a cópia média caiu para ~0,26 ms (notebook, só para comparar).
- **14.18: menus e copiar e colar (2026-10-15).**
  - **Os menus (popups) são filhos da janela:** cada um tem a própria imagem recortada (a sombra do menu também fica de fora), e a textura da janela sai **já composta**, com os menus por cima (mistura com as cores "pré-multiplicadas" do Wayland). Submenus funcionam (o lugar soma o dos pais). O menu é **empurrado para caber no telão** (`get_unconstrained_geometry`, com a área da janela como limite).
  - **Mouse:** em cima de um menu, o mouse é do menu; fora, da janela. Com o botão apertado, o mouse fica "preso" onde o clique começou (regra do Wayland, como num arrastar).
  - **Grab:** um menu com "grab" (os de verdade pedem) recebe o teclado (setas, Enter, Esc). Um clique fora dele fecha os menus (`popup_done`), e esse clique (e o "soltou" dele) **não vai para a janela**. Quando o menu fecha, o teclado volta para a janela.
  - **Copiar e colar entre os apps do hub:** o foco do teclado também é o foco do copiar e colar (data device) e da "seleção primária" (selecionar e colar com o botão do meio). Teste com dois apps: um copia `ação copiada`, o outro ganha o foco e cola o texto certo. A ponte com a área de transferência do Omarchy continua fora (Fora do escopo).
  - **O formato do cursor pedido pelo app continua ignorado** (o hub desenha o seu); o protocolo de formato de cursor não é oferecido.
  - **Prova no Brave** (sem janela): depois da tela de boas-vindas, o botão direito no meio da página abre o menu de contexto composto na textura, empurrado para caber; um clique fora fecha (`stats()` ganhou `menus`).
  - 31 testes no `cargo test` (5 novos: menu no lugar e por cima com sombra recortada, menu empurrado, mouse e clique no menu, grab com clique fora e teclado, copiar e colar entre dois apps). O `testar_compositor.gd` aceita `APP2` e troca de janela com Shift + F12.
- **14.19 e 14.20: o telão e os telões na casa, juntados em `293a559` (2026-10-15).** A trilha paralela terminou, e o worktree `telao` foi apagado.
  - **A "fonte de janela" é a classe `AppWindowSource`** (`components/app_window_3d/app_window_source.gd`): `get_texture()`, `resize(Vector2i)`, `send_key(InputEventKey)`, `send_pointer(Vector2)`, `send_button(MouseButton, bool)`, `send_scroll(Vector2)` e `get_title()`. O telão (`AppWindow3D`) só conhece essa interface; a fonte de verdade, na 14.21, traduz para o compositor pelo `AppCompositor`.
  - **Para a fonte de verdade (14.21), três cuidados:**
    - o `send_pointer` chega em pixels **da resolução do telão**; se a textura tiver outro tamanho (o Brave não fica menor que 800×600), a fonte converte pela proporção antes do `pointer_motion`;
    - no `send_scroll`, **y positivo é para cima**, e no compositor positivo é para baixo: a fonte inverte o sinal;
    - o telão ainda não avisa foco nem saída do mouse: a 14.21 liga o `focus(id)`/`focus(0)` ao `set_focused` do telão e o `pointer_leave()` quando a mira sai.

- **14.21: abrir no mundo (2026-10-15).**
  - **`AppSessions`** (autoload) é dono do compositor: cria o nó na primeira vez, chama o `poll()` a cada quadro e entrega cada janela nova ao primeiro telão livre (achado pelo grupo `app_screens`, o `AppScreens` da casa). A primeira janela depois de um `open_app` é do app aberto; outra janela do mesmo pid (segunda janela do Brave) vai para outro telão; sem telão livre, a janela é fechada.
  - **`AppLauncher`** abre no mundo quando `AppSessions.can_open_in_world()` (compositor compilado + telões na cena). O hub **não dorme**; a sessão do launcher acaba com sucesso quando a janela chega ao telão (`last_session_in_world`), e o app segue vivo no telão. Telões cheios: aviso "Os telões estão cheios". Sem janela em 10 s: plano B, o fluxo de fora da parte 1 (hub dorme e acompanha a janela). `use_world` desliga o caminho (os testes do fluxo de fora usam).
  - **Abrir:** `env WAYLAND_DISPLAY=… programa [ajustes] args` pelo `Exec` (sem `uwsm-app`). Ajustes por app em `DesktopAppsLinux.compositor_tweaks`: `--ozone-platform=wayland` para Chromium/Electron; o Brave ganha `--user-data-dir=user://apps/brave` e `--no-first-run`.
  - **A fonte** (`AppSessions.WindowSource`) converte: pixel do telão → pixel da textura (proporção), rolagem com y invertido, tecla → evdev (sem repetição), botão → código Linux, foco → `focus(id)`/`focus(0)`. O `AppWindowSource` ganhou `set_focused` e `pointer_leave`, ligados no `AppWindow3D`.
  - `tests/check_app_sessions.gd` (compositor falso): janela liga ao app, segunda janela, telões cheios, tradução da fonte, janela fecha, plano B, sem compositor.

- **14.22: dormir e sair (2026-10-15).** Com o hub dormindo (`HubWindow.is_sleeping`), o `AppSessions` não chama o `poll()`: os apps não recebem "quadro mostrado" e ficam ociosos, e nenhuma textura sobe; ao acordar, volta. O botão "Sair do hub" do menu de pausa, com apps nos telões, pede um segundo clique ("3 apps abertos vão fechar. Sair?"); abrir ou fechar o menu desarma. O atalho `SUPER + H` não muda: apps do mundo não têm sessão no `AppLauncher` (ele fica IDLE), então só os apps de fora reagem ao foco de volta.

- **2026-10-15: a parte 3 (decisão do dono).** O dono não gostou dos telões nas paredes nem da estante de apps. No lugar: **três monitores na mesa do computador**, que são o "Linux de dentro", com os atalhos `SUPER`, o menu (`SUPER + Space`) e a barra do Omarchy funcionando ali; os apps abrem por um lançador no monitor; as configurações do hub ficam só no menu de pausa. O compositor (14.15–14.18), o `AppSessions` (14.21) e o ocioso/aviso ao sair (14.22) continuam. Veja a [parte 3](#parte-3-a-mesa-com-três-monitores).

- **14.24: o spike da mesa (2026-10-15), na branch `spike-14.24` (`d545a3d`). Escolha: (A), o Quickshell de dentro.** As quatro perguntas deram certo no notebook. O código do spike fica na branch (não entra na fase); o layer-shell dela é o ponto de partida da 14.27.
  - **(a) Submap: funciona, sem mexer na config do dono.**
    - O hub liga o submap sozinho com `hyprctl eval` (Lua em tempo real): `hl.define_submap(...)` e `hl.dispatch(hl.dsp.submap(...))`.
    - Com o submap ligado, `SUPER + Enter`, `Space`, `W`, `1` e `F` chegam à Godot como teclas, e nada acontece fora. Ganhar o foco liga o submap e perder desliga.
    - **Armadilhas:**
      - o `OS.execute` da Godot **come as aspas duplas** dos argumentos: o Lua mandado pelo hub usa só aspas simples, e o retorno do `hyprctl eval` é conferido (o erro vem com código 7);
      - um submap sem nenhuma tecla não é registrado: ele precisa ter pelo menos uma (a de sair);
      - um `reload` do Hyprland (o Omarchy faz isso ao trocar o tema) **apaga as teclas do submap, mas deixa o Hyprland dentro dele**, com os atalhos mortos. O hub define o submap de novo a cada entrada e ao ver o evento `configreloaded`. A rede de segurança é a linha universal no `bindings.lua`, testada (funciona dentro do submap e depois do reload): `hl.bind("SUPER + SHIFT + ESCAPE", hl.dsp.submap("reset"), { submap_universal = true, description = "Game Hub: sair do submap" })`;
      - o `hl.timer` funciona (a trava de 120 s do spike). No hub, a ideia é um "vigia": o hub renova o timer a cada poucos segundos, e, se ele travar, o Hyprland sai do submap sozinho.
    - O `wtype` (teclas de mentira) só dispara atalhos do Hyprland com o `Escape`. Para testar atalhos, só com a mão do dono.
  - **(b) Calços: os scripts do Omarchy abrem dentro.** Ficaram três: `uwsm-app` e `systemd-run` (só rodam o comando) e **`brave-origin`**, que põe o perfil só do hub. Sem ele, o `omarchy-launch-browser` e os webapps acham o Brave de fora e abrem a janela lá. Com eles e o `-u HYPRLAND_INSTANCE_SIGNATURE`, abriram dentro: o terminal (foot), o navegador, o Obsidian (`launch-or-focus`) e dois webapps (janelas novas do mesmo Brave).
    - Ressalva: o `launch-or-focus` sempre abre outra janela, porque o `hyprctl` de dentro não acha nada. Se incomodar, um calço `hyprctl` que responda `clients -j` com as janelas do hub (fora do escopo por enquanto).
    - Um perfil novo do Brave mostra a tela de boas-vindas e segura os webapps até alguém clicar.
  - **(c) Layer-shell e Quickshell: funciona.**
    - O layer-shell mínimo no Rust deu cerca de 100 linhas, **sem crate novo** (o `wlr_layer` já vem no Smithay).
    - `quickshell -n -p /usr/share/omarchy/shell` dentro do compositor, com `QT_QUICK_BACKEND=software`, desenha a barra (1280×26), o fundo, as notificações, e o menu abre com `omarchy-menu toggle` (ambiente de dentro). A cópia média ficou em 0,8 ms.
    - Serviços repetidos falham sem estrago: o polkit ("já existe um agente"), as notificações (o nome no D-Bus já tem dono) e o portal. O idle não dispara (o compositor não tem o protocolo de ociosidade), e o bloqueio de tela também não (falta o `ext-session-lock`).
    - **Ressalvas:**
      - sem o `HYPRLAND_INSTANCE_SIGNATURE`, os workspaces da barra ficam parados (1 a 5): a barra de dentro não sabe dos monitores da mesa (fica para depois da parte 3);
      - a segunda instância roda de novo os scripts da barra (o `cpu-status` a cada 2 s, um `inotifywait -r` na home): o custo entra na medida da 14.32;
      - o `wl-clipboard` do Omarchy abre uma janela de 1×1: o hub ignora janelas minúsculas;
      - o `shell.json` do dono não mudou; arquivos de estado (uso dos agentes) são escritos pelas duas instâncias.
  - **(d) Os atalhos: 229 de 229.** Em vez de imitar o Lua no GDScript, o leitor **roda a config de verdade** (`~/.config/hypr/hyprland.lua`) num `lua` com um `hl` falso, que só anota os atalhos. O `lua` é dependência do Hyprland, então sempre existe onde o Omarchy roda. Laços (workspaces 1 a 10), `if` (apps pré-instalados) e `hl.unbind` do usuário saem certos.
    - Bateu com o `hyprctl binds` um a um: 132 comandos, 92 ações de janela (`window.move` 26, `focus` 21, `window.resize` 13, grupos, tela cheia...) e 5 funções Lua (copiar, colar e recortar universais e o zoom), que viram ações do hub ou são ignoradas.
    - O Hyprland deixa **vários atalhos na mesma tecla** (ALT + TAB foca e traz para a frente; F9 tem o apertar e o soltar): a tabela é uma lista, não um mapa.
    - Lua 5.5: a variável do `for` é constante (não dá para reatribuir).

- **14.26: as saídas (2026-10-15).**
  - **API do nó:**
    - `set_outputs([Vector2i...])` troca os monitores (`HUB-1`, `HUB-2`, `HUB-3`, lado a lado, com o `xdg-output`);
    - `place(id, saída, x, y, w, h)` põe a janela e pede o tamanho (saída negativa tira); `raise(id)` põe por cima;
    - `get_output_texture(i)` / `get_output_image(i)` dão a saída composta; `window_at(i, x, y)` diz qual janela está no ponto (para o hub dar o foco no clique, na 14.28/14.29);
    - `pointer_motion_output(i, x, y)` manda o mouse para a janela embaixo (ou tira o mouse dos apps, se não houver janela).
  - **A janela com lugar numa saída não sobe a textura própria**, só a da saída (para não pagar duas cópias). Sem lugar, tudo funciona como na parte 2.
  - **A composição** só refaz as saídas que mudaram (uma janela desenhou, entrou, saiu, fechou ou subiu), mas a saída inteira: fundo liso (`OUTPUT_BACKGROUND`, até o fundo do Omarchy chegar pela 14.27) e as janelas por cima, cada uma cortada pelo seu lugar (um app que desenha maior que o pedido não invade a vizinha). Pixel opaco é só copiado. Recompor só o pedaço que mudou fica para a medida da 14.32, se pesar.
  - **Os menus** continuam dentro da imagem da janela (presos ao retângulo dela).

- **14.27: as camadas (2026-10-17).**
  - **Uma camada é um `Win` com o papel `Role::Layer`**: aproveita a cópia da imagem, os menus e o mouse das janelas, mas a Godot não fica sabendo dela (nenhum `window_opened`). O hub não muda o lugar dela (`place`, `raise` e `resize` devolvem false): o lugar sai das âncoras, das margens e da zona exclusiva (`native/compositor/src/layers.rs`, a conta pura, na ordem do sway: primeiro as que reservam espaço, da sobreposição para o fundo, depois as outras na área útil, ou na saída inteira com -1).
  - **Ordem na saída:** fundo liso, camadas de fundo e de baixo, janelas, camadas de topo e de sobreposição. Os menus de uma camada podem sair dela (o menu que desce da barra); os de uma janela continuam presos ao lugar dela.
  - **Área útil:** o sinal `usable_area_changed(saída, Rect2i)` e o `get_usable_area(saída)`. É onde o `DeskLayout` (14.29) arruma as janelas. Só uma camada que aparece reserva a faixa; esconder (commit sem imagem) solta a faixa, e ela volta com um commit vazio e um configure novo.
  - **Teclado, nesta ordem:** a camada de topo ou de sobreposição com teclado `exclusive` (o menu aberto), a camada que ganhou o teclado num clique (`on_demand`) ou num menu com "grab", e a janela que o hub escolheu (`focus`). O `key(id, ...)` continua, e o `key_focused(evdev, apertou)` manda a tecla para quem tem o teclado (serve com a mesa sem janela). Clicar numa janela, ou o hub chamar `focus`, tira o teclado da camada `on_demand`; a `exclusive` só larga quando some.
  - **Mouse:** a camada respeita a "região de clique" do app (uma camada transparente pode deixar o clique passar). O `window_at` só devolve janela: em cima da barra dá 0 (o clique na barra não dá foco à janela de baixo).
  - **Saída de uma camada:** a que o app pediu; sem pedido (o `omarchy-menu`), a da janela com foco, senão a 0. O `set_outputs` fecha as camadas (o monitor delas sumiu) e o app cria outras nos monitores novos.
  - **Contorno de um defeito do Smithay 0.7** (achado com o Quickshell de verdade): quando o app destrói a camada, o Smithay zera o estado dela, mas a conferência "largura 0 precisa das duas âncoras" continua presa à superfície. O Quickshell, ao fechar o menu, faz mais um commit vazio na superfície, e o erro derrubava o app inteiro (a barra e o fundo juntos). Um gancho nosso, registrado na criação de cada superfície (roda antes do do Smithay), deixa a conferência passar para uma camada já destruída. Teste: `fechar_a_camada_e_dar_commit_na_superficie_nao_derruba_o_app`.
  - **Prova com o Quickshell do Omarchy** (notebook, sem janela, script fora do repositório): com três saídas de 1280×720, ele criou uma barra (`omarchy-bar`, 1280×26, topo) e um fundo (`omarchy-background`, fundo) em cada uma, e a área útil das três ficou em y = 26. O `omarchy-menu toggle` (ambiente de dentro) abriu o menu como sobreposição na saída 0, por cima do fundo escurecido; um Esc pelo `key_focused` fechou só o menu. Cópia média de 0,4 a 0,5 ms (só para comparar).
  - O app de teste do `cargo test` usa o lado do app do layer-shell: o crate `wayland-protocols-wlr` 0.3.12 (MIT) entrou só nos testes (`dev-dependencies`). Ele já estava no `Cargo.lock`, porque o Smithay usa o lado do compositor dele; nada foi baixado.
  - 59 testes no `cargo test` (17 novos: 7 da conta das camadas e 10 de integração).

## Checklist de teste manual (fim da parte 1)
1. No notebook, rode o hub (`godot --path ~/git/game-hub`). Em casa, olhe à esquerda do janelão: a estante de apps mostra ícones (Brave, Foot, Spotify...). Passe a página e troque o filtro (Internet, Sistema...).
2. Segure E no **Foot**: "Abrindo…", o hub some e o terminal aparece no lugar dele. Feche o terminal (`exit`): o hub volta, na frente da estante.
3. Segure E no **Brave**: abre uma janela nova (mesmo com o Brave já aberto). Aperte o atalho do `bindings.lua`: o hub volta e o Brave continua aberto.
4. Olhe para o computador: o painel acima dele mostra a hora certa, a bateria igual à da barra do Omarchy, o nome do Wi-Fi e o volume. Mude o volume no teclado: em até ~5 s o painel acompanha.
5. No computador, aba **Sistema**: ligue "Abrir o hub ao entrar no Omarchy". Saia da sessão e entre de novo: o hub abre sozinho. Desligue: o arquivo `~/.config/autostart/game-hub.desktop` some.
6. Abra um jogo pela estante de jogos: tudo funciona como antes (abrir, jogar, fechar, voltar).
7. `bash tests/run_tests.sh` → `RESULTADO GERAL: TUDO OK`.

---

# Parte 2: janelas no mundo

## Contexto da parte 2
A referência do dono para esta fase é o **Waylandcraft**, um mod do Minecraft que é um compositor Wayland completo (Rust + [Smithay](https://github.com/Smithay/smithay), GPL-3.0). Nele, a janela de cada programa vira um objeto **dentro do mundo**: você anda até ela, digita e clica nela, sem sair do jogo.

Essa referência não foi escrita no planejamento da parte 1, e "o hub como parte do desktop" virou um **launcher** (o app abre por cima, o hub some e volta). A parte 2 corrige o rumo.

**Decisões do dono (2026-10-14):**
- **usar** o app dentro do mundo (digitar e clicar), e não só ver;
- **só no Linux** (no Windows fica o launcher da parte 1);
- **refazer a Fase 14**: a experiência principal passa a ser a das janelas no mundo;
- **Rust + Smithay**, com o godot-rust (MPL-2.0, abrindo uma exceção na regra de licenças);
- o Brave (e apps parecidos) abre com um **perfil próprio do hub**;
- **telões fixos na casa** (pendurar onde quiser fica para depois).

**O que fica da parte 1 e o que muda:**
- **Fica como está:** a lista de apps e os ícones (14.2–14.4), a estante de apps (14.7, que passa a abrir no telão), o painel (14.8, 14.9), o autostart (14.10) e o atalho `SUPER + H` (14.11).
- **Vira o plano B:** abrir **fora** (14.5, 14.6). Vale no Windows, quando a extensão não está compilada, e para apps que só falam X11 (eles nascem fora e caem no fluxo antigo sozinhos, veja "Abrir").
- Nada é revertido: os commits da parte 1 continuam na `fase-14`.

## Pronto quando (parte 2)
- Na estante de apps, segurar E no **foot** faz o terminal aparecer num telão da casa. Com E no telão, a câmera se aproxima, e dá para digitar `ls` e ver a saída, **com acentos do ABNT2** (`ç`, `á`, `~`).
- O **Brave** (perfil do hub) abre num telão: clicar em links, rolar, abrir o menu (popup) e assistir a um vídeo funcionam. O hub nunca some.
- Três apps abertos ocupam os três telões. Um quarto app mostra o aviso "Os telões estão ocupados: feche um app". Fechar a janela pelo próprio app (`exit`, Ctrl+W) libera o telão.
- Segurar Esc (~0,6 s) sai do telão. Um Esc curto vai para o app (o `vim` funciona).
- Um app só X11 abre fora, pelo fluxo da parte 1 (o hub some e volta), e o atalho continua funcionando.
- **Sem a extensão compilada** (ou no Windows), o hub abre e tudo funciona como na parte 1. A bateria passa com e sem o `.so`.
- **Plataforma isolada:** só `autoload/platform/` toca no `HubCompositor` (o `check_platform` confere).
- **Desempenho (a meta é o desktop, Ryzen 5 5600 + RTX 4070, na Alta):** em casa, com os três telões ocupados e o Brave tocando um vídeo num deles, o hub fica no teto do monitor, e o p99 não sobe mais que ~2 ms em relação à casa sem apps. Com apps parados, a queda é quase zero (a imagem só sobe quando muda).
  - **O notebook não é meta:** lá a medida só compara o mesmo código antes e depois (a parte 2 não pode quebrar a qualidade Leve). Se o desktop ainda não estiver disponível na 14.23, a meta fica pendente para a trilha do desktop, e não é trocada pela do notebook.

## Decisões de arquitetura (parte 2)
- **O hub é um compositor Wayland "aninhado".** Ele abre um socket próprio (`gamehub-0`), e os apps abertos pelo hub recebem `WAYLAND_DISPLAY=gamehub-0`. Para o Hyprland, o hub continua sendo uma janela comum; nada muda na config do Omarchy. Esse é o desenho do Waylandcraft.
  Descartado: capturar janelas do Hyprland (screencopy + PipeWire) e injetar teclado virtual. O teclado iria para a janela focada do Hyprland, e não para o telão.
- **Código nativo em Rust:** a pasta `native/compositor/` tem um crate com o **godot-rust (gdext)**, que liga o Rust à Godot, e o **Smithay**, a biblioteca de compositor. O resultado é uma GDExtension Linux x86_64 que dá uma classe `HubCompositor`. A versão de cada crate fica fixada no `Cargo.lock`, e a do Smithay numa versão ou rev exata. O bind com a Godot 4.7.2 sai do `api-custom` (gerado a partir do binário local); o spike confirma.
  **O Waylandcraft é GPL-3.0: só lemos as ideias, nenhuma linha de código é copiada.** Os crates de terceiros passam por uma checagem de licença (sem GPL) na 14.15.
- **O `.so` não vai para o repositório.** `tools/linux/compilar_compositor.sh` compila e copia para `native/bin/` (no `.gitignore`). O `.gdextension` só declara `linux.x86_64`. Sem o `.so`, a Godot só avisa uma vez, e o hub segue no plano B.
- **Ponto único:** `autoload/platform/app_compositor.gd` (classe `AppCompositor`, estática, como o `SteamClient`; o nome `Compositor` já é de uma classe da Godot) é o **único** lugar que faz `ClassDB.class_exists("HubCompositor")` e `ClassDB.instantiate(...)`, sem citar a classe pelo nome no código. Assim o GDScript compila no Windows. O mesmo arquivo tem a tabela "tecla da Godot → código evdev" e lê o layout do teclado (`hyprctl getoption input:kb_layout`, com `us` de reserva). O `check_platform` ganha `HubCompositor` e `WAYLAND_DISPLAY` na lista `PLATFORM_ONLY`.
- **A interface do `HubCompositor` é pequena e sem mundo:**
  - `start(socket, layout)`, `stop()` e `poll()`. O `poll()` roda a cada quadro e processa os eventos sem bloquear.
  - Sinais `window_opened(id, app_id, title, pid)`, `window_closed(id)` e `title_changed(id, title)`.
  - `get_texture(id)`, uma `ImageTexture` que só é atualizada quando a janela manda um quadro novo (dano).
  - `resize(id, w, h)`, `close(id)`, `pointer_motion/button/axis(id, ...)`, `key(id, evdev, pressed)` e `focus(id)`.
- **Só buffers shm (memória comum), sem dmabuf:** a imagem é copiada para uma `ImageTexture`. É simples e funciona no Radeon do notebook. Os popups (menus) são desenhados por cima da janela-mãe, dentro do Rust, e a textura já sai composta. O dmabuf (zero cópia) entra no "Fora do escopo".
- **`AppSessions` (autoload, sem mundo):** liga "app aberto" a "janela do compositor".
  - A primeira janela nova depois de um `launch` é desse app.
  - Outra janela do mesmo cliente Wayland (ex.: uma segunda janela do Brave) vai para o próximo telão livre.
  - Ele avisa `window_ready(id, app_id)` e `window_gone(id)`. O mundo escuta pelo grupo `app_screen`: cada telão se oferece, e o `AppSessions` entrega ao primeiro livre (regra 1).
- **Abrir (Linux):**
  - Pelo `Exec` do `.desktop`, **sem** `uwsm-app`, porque ele passa pelo systemd e perde o `WAYLAND_DISPLAY`. O processo recebe `WAYLAND_DISPLAY=gamehub-0`, `GDK_BACKEND=wayland`, `QT_QPA_PLATFORM=wayland` e `SDL_VIDEODRIVER=wayland`.
  - O `DISPLAY` do Hyprland é **mantido**. Assim, app só X11 nasce **fora** e o `AppLauncher` da parte 1 cuida dele (o hub some e volta).
  - Apps Chromium e Electron (Brave, Chromium, Obsidian, Spotify...) ganham `--ozone-platform=wayland`. O Brave ganha também `--user-data-dir=<user://apps/brave globalizado>`, o perfil próprio. Essas regras ficam numa tabela de "ajustes por app" em `desktop_apps_linux.gd`.
  - Se a janela não aparecer no compositor em ~10 s, vale o plano B (acompanhar fora pelo `WindowHost`, como na 14.6).
- **O telão (`components/app_window_3d/`):** é a mesma ideia da `Screen3D`, que já faz foco, câmera e raio → pixel. Ele herda dela e troca só o conteúdo (a textura do compositor) e o destino do teclado e do mouse.
  - A **tela 3D é que decide o tamanho da janela:** `resize` com a resolução do telão (ex.: 1280×720).
  - **Esc curto vai para o app; segurar Esc (~0,6 s) devolve a câmera.** O botão B do controle segue a mesma regra. O Waylandcraft usa uma tecla de captura; aqui o foco por E já existe.
  - O cursor é desenhado pelo hub (um ponteiro simples por cima do telão).
- **Telões fixos na casa:** são três, como o painel do sistema (não mudam com a disposição). Ficam no alto das paredes, acima dos móveis (leste, oeste e sul), e o lugar exato sai de uma captura. Um telão vazio mostra "Livre". Com app, o cartão ao olhar diz "Brave · E para usar · segure X para fechar".
- **Ciclo de vida:**
  - Enquanto o hub dorme (jogo da Steam aberto), o compositor para de mandar `frame done`, os apps ficam ociosos e as texturas não sobem.
  - Ao sair do hub com apps abertos, o menu de pausa avisa: "3 apps abertos vão fechar". Os apps morrem junto com o compositor.
  - A área de transferência funciona **entre os apps do hub** (o data device do Smithay). A ponte com a do Omarchy fica para depois.

## Subetapas (parte 2)
Branch `fase-14` (checkout principal). A trilha paralela só entra na janela 4 (veja a tabela no começo).

- [x] **14.13 Preparação** (Sonnet · low): *só principal* · `ed0f962`
  - Faz: reabre este plano (status e esta parte 2); CLAUDE.md (pasta `native/` no mapa, exceção MPL-2.0 para o godot-rust, "o compositor é só Linux"); ROADMAP (Fase 14 reaberta, o Waylandcraft como referência da V5). **Pede permissão** para instalar o Rust (`! sudo pacman -S rustup` e `! rustup default stable`, ~250 MB, rodados pelo dono).
  - Teste: `bash tests/run_tests.sh` → TUDO OK.
  - Commit: `Fase 14.13: plano da parte 2 (janelas no mundo)`
- [x] **14.14 Spike: um terminal num quadro** (Opus · high): *só principal; precisa do dono no notebook* · `2ce537e`
  - Faz: um crate mínimo (gdext + Smithay) que abre `gamehub-0`, aceita o `foot`, copia o buffer shm para uma `ImageTexture` num quadro 3D de teste e manda teclas fixas. Confere:
    - (a) o gdext carrega na Godot 4.7.2;
    - (b) o foot aparece;
    - (c) uma tecla chega (com o layout `br`);
    - (d) o Brave com `--ozone-platform=wayland --user-data-dir=...` abre lá dentro;
    - (e) o custo da cópia shm de 1280×720 (no notebook, só para comparar caminhos; a meta é conferida no desktop).

    Antes de baixar os crates, **pede permissão** com a lista (nome, versão, licença).
  - Arquivos: o código do spike vira a semente de `native/compositor/` se der certo. Os resultados vão para "Decisões tomadas durante a fase".
  - Commit: `Fase 14.14: resultado do spike do compositor`
- [x] **14.15 A extensão e o ponto único** (Opus · high) · `b79d676`
  - Faz: o crate `native/compositor/` arrumado (comentários em português), `tools/linux/compilar_compositor.sh`, o `.gdextension`, o `.gitignore` (`native/bin/`, `native/**/target/`), a checagem de licenças dos crates (sem GPL) e `autoload/platform/app_compositor.gd` (`is_available()`, `create()`, tabela evdev, layout). O `run_tests.sh` roda `cargo test` se houver `cargo`; senão, escreve "pulado".
  - Teste: `tests/check_compositor.gd` (sem `.so`: `is_available()` falso e nada quebra; tabela evdev: letras, números, ABNT2 `ç` e `/?`, setas, F1–F12) e o `check_platform` com a lista nova.
  - Commit: `Fase 14.15: extensão do compositor e o ponto único`
- [x] **14.16 Janelas e imagem** (Opus · high): *principal, janela 4* · `f755f61`
  - Faz: no Rust, xdg-shell (toplevel), shm, `frame done` só quando pedido, título, `app_id`, pid do cliente, `resize`, `close`, dano → textura. Os sinais do `HubCompositor`.
  - Teste: `cargo test` com um cliente Wayland de teste (crate `wayland-client`) que manda um buffer de cor conhecida. O compositor abre a janela, a textura tem a cor certa e, ao fechar, sai o `window_closed`.
  - Commit: `Fase 14.16: janelas e imagem no compositor`
- [x] **14.17 Teclado e mouse** (Opus · high): *principal, janela 4* · `578457c`
  - Faz: o seat do Smithay com o keymap do xkb (layout lido pelo ponto único), `key(evdev)`, ponteiro (mover, botões, rolar), foco de teclado por janela e repetição de tecla do lado do cliente (`repeat_info`).
  - Teste: `cargo test` (o cliente de teste recebe a tecla e o clique nas coordenadas certas).
  - Manual: com o quadro do spike, digitar `ação` no foot.
  - Commit: `Fase 14.17: teclado e mouse nas janelas`
- [x] **14.18 Popups e área de transferência** (Opus · high): *principal, janela 4* · `4e26f0b`
  - Faz: o `xdg_popup` (menus e o botão direito do Brave) composto na textura da mãe, com o clique roteado para o popup; o data device entre os apps do hub; e o formato do cursor ignorado (o hub desenha o seu).
  - Teste: `cargo test` (popup abre na posição pedida e recebe o clique; copiar num cliente e colar no outro).
  - Commit: `Fase 14.18: popups e copiar e colar`
- [x] **14.19 O telão** (Sonnet · medium): *trilha paralela, janela 4* · `1ecfa97` (junta em `293a559`) · *substituída pela parte 3 (o telão vira o monitor da mesa na 14.28)*
  - Faz: `components/app_window_3d/` herda da `Screen3D`. Recebe uma "fonte de janela" (a de verdade vem do `AppSessions`; nos testes, uma falsa com uma textura qualquer). Mouse e teclas viram chamadas na fonte; Esc curto vai para o app e segurar Esc sai; a fonte recebe o tamanho; o cursor é desenhado pelo hub. Só usa a interface, sem tocar no Rust.
  - Teste: `tests/check_app_window_3d.gd` com fonte falsa (clique no meio vira as coordenadas certas, Esc curto e longo, `resize` com a resolução).
  - Commit: `Fase 14.19: o telão de app`
- [x] **14.20 Telões na casa** (Sonnet · medium; Opus · high se o visual travar): *trilha paralela, janela 4, depois da 14.19* · `424671b` (junta em `293a559`) · *substituída pela parte 3 (os telões saem na 14.25)*
  - Faz: `worlds/home/app_screens.gd` cria três `AppWindow3D` fixos, no alto das paredes, no grupo `app_screen`. Mostra "Livre", o cartão ao olhar e "segure X para fechar". O `home.gd` cria os telões junto do painel.
  - Teste: `tests/check_app_screens.gd` (três telões, oferta ao `AppSessions` falso, telão libera ao fechar). O `check_home` continua passando.
  - Manual: captura dos três telões (fora do repositório).
  - Commit: `Fase 14.20: telões na casa`
- [x] **14.21 Abrir no mundo** (Sonnet · medium) · `a354100`
  - Faz: o autoload `AppSessions`. O `AppLauncher` passa a usar o compositor quando `AppCompositor.is_available()`, com o ambiente da decisão "Abrir", os ajustes por app (ozone, perfil do Brave) e o plano B em ~10 s. A estante de apps abre no próximo telão livre. Telões cheios mostram o aviso. O hub não some para app no mundo.
  - Teste: `tests/check_app_sessions.gd` com compositor falso:
    - janela nova liga ao app;
    - a segunda janela do mesmo cliente vai para outro telão;
    - telões cheios recusam;
    - sem janela em 10 s, cai no plano B;
    - sem compositor, o fluxo é o da parte 1.

    O `check_app_launcher` continua passando.
  - Commit: `Fase 14.21: abrir apps dentro do mundo`
- [x] **14.22 Dormir, sair e o atalho** (Sonnet · medium) · `5c56b59`
  - Faz: compositor ocioso enquanto o hub dorme; aviso ao sair com apps abertos; o atalho `SUPER + H` sem mudança para apps fora.
  - Teste: `check_app_sessions` (dormindo, não sobe textura) e o teste do menu de pausa.
  - Commit: `Fase 14.22: o compositor ao dormir e ao sair`
- [ ] ~~**14.23 Medida e documentação**~~ (Sonnet · medium): *só principal* · *virou a 14.32, no fim da [parte 3](#parte-3-a-mesa-com-três-monitores)*
  - Faz: a medida em casa no **desktop (Alta)**, que é a meta, sem apps, com o foot parado e com o Brave tocando vídeo; no notebook (Leve), a mesma medida só como comparação antes e depois. Sem o desktop disponível, a meta fica pendente na trilha do desktop. Atualiza o README (janelas no mundo, como compilar, Esc longo, perfil do Brave), o ROADMAP, o PLATAFORMA (compositor, ambiente dos apps, X11 fora) e o CLAUDE.md (mapa: `app_sessions`, `platform/app_compositor`, `components/app_window_3d`, `native/`).
  - Commit: `Fase 14.23: documentação da parte 2`

## Riscos (parte 2)
- **O gdext não suporta a 4.7.2 de cara:** o `api-custom` gera o bind da versão local. O spike (14.14) responde antes de qualquer outra coisa.
- **Teclas do ABNT2:** a Godot pode não dar um código físico para a tecla `/?` (`KEY_RO`) e outras. A tabela do ponto único e o teste com `ç`/`/?` mostram cedo. Uma tecla que faltar fica anotada como limitação.
- **O Brave com o perfil próprio ainda acha a instância de fora:** o `--user-data-dir` diferente cria um processo novo; o spike confere.
- **Cópia shm pesada** (vídeo em 720p a 30–60 quadros, três telões): subir só com dano, limitar o telão a 1280×720 e trocar a ordem das cores na placa de vídeo. Se pesar no desktop, o telão fora da vista não sobe a imagem. O notebook só mostra se uma mudança piorou ou melhorou.
- **Build com Rust para um dono com programação básica:** um script só (`compilar_compositor.sh`), mensagem clara quando o `.so` falta e o plano B sempre funcionando.
- **Smithay muda de API entre versões:** versão fixada no `Cargo.lock`, e a atualização só com spike.

## Fora do escopo (parte 2)
- Pendurar janelas em qualquer lugar e telões na cidade.
- dmabuf (zero cópia), XWayland dentro do hub (`xwayland-satellite`, como o Waylandcraft opcional) e a área de transferência compartilhada com o Omarchy.
- Janelas no mundo no Windows (por lá continua o launcher da parte 1).
- VR, entrada de texto com IME e escala fracionária.
- O hub como a sessão inteira do Hyprland (Horizonte).

## Checklist de teste manual (fim da parte 2)
1. `bash tools/linux/compilar_compositor.sh` e depois `bash tests/run_tests.sh` → `RESULTADO GERAL: TUDO OK` (com o `cargo test`).
2. Apague `native/bin/` e rode a bateria de novo: TUDO OK, com o compositor "pulado".
3. No notebook, `godot --path ~/git/game-hub`: na estante de apps, segure E no **foot**, e ele aparece num telão. Com E no telão, digite `echo ação` e Enter: sai `ação`. Abra o `vim`, aperte Esc curto (o vim sai do modo inserção) e segure Esc (a câmera volta).
4. Segure E no **Brave**: ele abre noutro telão. Clique num link, use o botão direito (o menu aparece) e toque um vídeo. Copie um texto no Brave e cole no foot.
5. Abra um terceiro app e depois um quarto: aparece o aviso "Os telões estão ocupados". Feche o foot com `exit`, e o telão fica "Livre".
6. Abra um app só X11: o hub some e o app aparece fora. `SUPER + H` traz o hub de volta.
7. Abra um jogo da Steam: o hub some como antes. Ao voltar, os telões continuam com os apps.
8. Esc → Sair com apps abertos: o aviso aparece.
9. No **desktop** (Alta), a medida da 14.32 está dentro da meta. No notebook, ela só confirma que o Leve não piorou.

---

# Parte 3: a mesa com três monitores

## Contexto da parte 3
O dono não gostou dos três telões nas paredes (14.19, 14.20) nem da estante de apps. A ideia nova:
- **três monitores na mesa do computador** são o "Linux de dentro". Você senta, e eles funcionam como o desktop do Omarchy: abrir apps, usar os atalhos `SUPER`, o menu (`SUPER + Space`) e a barra;
- **a estante de apps sai.** Os apps abrem por um lançador no monitor (o menu de apps do Omarchy, ou um do hub como plano B);
- **as configurações do hub saem do computador** e ficam só no menu de pausa (as abas Casa e Sistema vão para lá).

Respostas do dono (2026-10-15):
- "comandos do Omarchy" = os atalhos SUPER **e** o menu e a barra do Omarchy;
- abrir apps = lançador no monitor;
- configurações = só no menu de pausa.

O que já existe e continua: o compositor em Rust (14.15 a 14.18: janelas, imagem, teclado, mouse, menus e copiar e colar), o `AppSessions` (14.21: dono do compositor, `poll`, ambiente, perfil do Brave, plano B), o ocioso ao dormir e o aviso ao sair (14.22).

## O que a investigação achou (parte 3)
- **Os atalhos do Omarchy** são Lua: `o.bind("SUPER + RETURN", "Terminal", {omarchy="terminal"})`, em `/usr/share/omarchy/default/hypr/bindings/*.lua` (applications, utilities, tiling, media, clipboard) e no `~/.config/hypr/bindings.lua` do usuário (`hl.unbind`). O `hyprctl binds -j` dá a tecla e a descrição, **mas não o comando** (vem como `__lua N`). Então o hub **lê os arquivos Lua** e traduz:
  - texto → comando;
  - `{omarchy="x"}` → `omarchy-launch-x`;
  - `{webapp=url}` → `omarchy-launch-webapp`;
  - `{launch=...}` e `{tui=...}`;
  - `hl.dsp.*` (fechar, focar, tela cheia, workspace) → ações do próprio hub.
- **O Hyprland come os atalhos SUPER** antes da Godot. O caminho é um **submap** (`hl.define_submap`, `hl.dsp.submap`): sentado à mesa, o hub liga um submap quase vazio, e as teclas passam para ele.
- **Os scripts do Omarchy abrem fora:**
  - `omarchy-launch-*` usam `uwsm-app --` ou `systemd-run --user`, e os dois perdem o `WAYLAND_DISPLAY`;
  - `omarchy-launch-or-focus` usa o `hyprctl` de fora.
  - Saída: o ambiente dos apps de dentro ganha uma **pasta de "calços"** (shims) no começo do `PATH`, com `uwsm-app` e `systemd-run`, que só executam o comando. Ganha também `-u HYPRLAND_INSTANCE_SIGNATURE`: sem ele, o `hyprctl` de dentro não acha o Hyprland de fora, e o launch-or-focus cai no "abrir".
- **O menu e a barra do Omarchy** são o Quickshell (`quickshell -n -p /usr/share/omarchy/shell`, versão 0.3.1). O `omarchy-shell` acha a instância **pelo `WAYLAND_DISPLAY`**, então uma segunda instância dentro do `gamehub-0` convive com a de fora.
  - Precisa de **layer-shell** (barra, menu e fundo são `PanelWindow`), que o compositor ainda não tem.
  - O compositor só tem shm (o Qt pode precisar do render por software).
  - Os serviços duplicados (notificações, idle, lock) são o maior risco. **Vai para um spike antes de tudo.**

## Decisões de arquitetura (parte 3)
- **Cada monitor da mesa é uma "saída" (`wl_output`) do compositor**, e não uma janela. O Rust compõe cada saída numa textura só: fundo, barra, janelas e menus. Assim a barra do Omarchy aparece em cada monitor, como no desktop. Tamanho: **1920×1080 por saída** (texto legível de perto), a ser confirmado na medida da 14.32 (plano: 1600×900).
- **A política fica em GDScript, o mecanismo em Rust.**
  - O Rust põe as janelas onde mandam (`place(id, saída, retângulo)`), compõe e roteia o mouse pela posição na saída.
  - Um `DeskLayout` em GDScript (testável sem o `.so`) decide o lugar de cada janela: lado a lado no monitor, foco, tela cheia, mover de monitor. O dono lê e mexe nele.
- **Os atalhos são do hub, com os comandos do Omarchy.**
  - `autoload/platform/omarchy_binds.gd` lê os Lua (o padrão e o do usuário) e monta "combinação → ação".
  - A ação "rodar comando" roda com o ambiente de dentro (calços + `gamehub-0`). As ações de janela (`SUPER+W`, setas, `SUPER+F`, `SUPER+1..3`) vão para o `DeskLayout`. O que não tem tradução é ignorado e aparece no log uma vez.
  - Os atalhos do usuário valem, porque o hub lê o `bindings.lua` dele.
- **Submap só enquanto sentado à mesa:**
  - liga ao sentar; volta ao normal ao levantar, ao perder o foco, ao dormir e ao sair;
  - o `WindowHostHyprland` é quem fala com o `hyprctl` (regra 5);
  - **saída de emergência:** um submap definido no `bindings.lua` com uma tecla que volta ao normal (o hub oferece a linha para copiar, como o atalho da 14.10). Se o hub travar, a tecla devolve os atalhos.
- **O menu e a barra: Quickshell de dentro (A) ou do hub (B), decidido no spike.**
  - (A) Uma segunda instância do Omarchy shell no `gamehub-0`. `SUPER + Space` e `SUPER + Alt + Space` (o menu de apps) chamam o `omarchy-menu` com o ambiente de dentro.
  - (B) Se o Quickshell não rodar bem lá dentro, o hub desenha uma barra simples (hora, bateria, Wi-Fi e volume, que o `SystemStatus` já tem) e um lançador (busca + Enter, com a lista do `AppLibrary`). Os mesmos atalhos chamam esse lançador.
- **Sai:** os telões (`worlds/home/app_screens.gd`, o teste dele) e a estante de apps (`worlds/home/app_shelf.gd`, o teste dele, o `"apps"` em `Home.MOVABLE` e nas 3 disposições do `home_catalog.tres`). O `AppWindow3D` é adaptado para "monitor de saída", e o `AppWindowSource` passa a falar de uma saída.
- **Fica:** o `AppLibrary` (para o lançador B e os ícones) e o `AppLauncher` (o fluxo de fora, para quando não há compositor). Sem a estante, ele só é chamado pelo lançador B. No Windows, ou sem o `.so`, os monitores mostram "O Linux do hub precisa do compositor (só no Linux)".
- **Regras do projeto:** o `AppSessions` não conhece a mesa. Ele acha os monitores pelo grupo `desk_monitors` (regra 1). Lua, `hyprctl`, calços e `quickshell` ficam só em `autoload/platform/`, e o `check_platform` ganha a lista nova (regra 5).

## Subetapas (parte 3)
Substituem a 14.23 antiga: a medida e os documentos vão para o fim (14.32).
- [x] **14.23 Plano da parte 3** (Sonnet · low)
  - Faz: escreve esta parte no `docs/plans/fase-14.md`. Marca a 14.19 e a 14.20 como "substituídas pela parte 3" e põe a decisão do dono em "Decisões tomadas durante a fase".
  - Commit: `Fase 14.23: plano da parte 3 (a mesa com três monitores)`
- [x] **14.24 Spike: submap, calços e Quickshell** (Opus · high): *precisa do dono no notebook* · `d545a3d` (branch `spike-14.24`) · *escolha: A*
  - Faz, numa branch de spike, sem mexer no hub:
    - (a) com o submap ligado, `SUPER + Enter` chega à Godot como tecla (o `testar_compositor.gd` imprime), e a tecla de emergência volta ao normal;
    - (b) com os calços e o `-u HYPRLAND_INSTANCE_SIGNATURE`, o `omarchy-launch-terminal`, o `omarchy-launch-browser` e o `omarchy-launch-or-focus obsidian ...` abrem **dentro**;
    - (c) um layer-shell mínimo no Rust e `quickshell -n -p /usr/share/omarchy/shell` no `gamehub-0`: a barra aparece? o `omarchy-menu toggle` (ambiente de dentro) abre o menu lá dentro? Os serviços duplicados (notificações, idle, lock) brigam com os de fora?
    - (d) o leitor de Lua de teste acha quantos dos ~190 atalhos.
  - Antes de qualquer crate novo, **pede permissão** (o Smithay já tem o `wlr_layer`; a ideia é não precisar de nada novo).
  - Resultado em "Decisões tomadas durante a fase", com a escolha A ou B.
  - Commit: `Fase 14.24: resultado do spike da mesa`
- [x] **14.25 Tirar os telões e a estante; configurações no menu de pausa** (Sonnet · medium)
  - Faz:
    - apaga `app_screens.gd`, `app_shelf.gd` e os testes deles; tira o `"apps"` do `Home.MOVABLE` e do `home_catalog.tres`;
    - o `PauseMenu` ganha as abas Casa (`HomeSettingsView`) e Sistema (`SystemSettingsView`, onde houver), pelo `SettingsView.add_page`, que já existe;
    - o `ComputerDesk` vira uma mesa mais larga com **três monitores** (o do meio de frente, os dos lados um pouco virados), que por enquanto mostram "Sem sinal";
    - o `AppLauncher.use_world` e a estante somem do `check_app_launcher`.
  - Teste: `check_home`, `check_pause_menu` (abas novas) e `check_computer_desk` (três telas, nenhuma dentro de móvel nas 3 disposições).
  - Manual: captura da mesa (fora do repositório).
  - Commit: `Fase 14.25: três monitores na mesa e configurações no menu de pausa`
- [x] **14.26 Saídas e composição por monitor** (Opus · high): *Rust*
  - Faz:
    - `set_outputs(tamanhos)` cria 3 `wl_output` (com o `xdg-output`);
    - `place(id, saída, x, y, w, h)` manda a janela para o lugar (com `configure`);
    - `get_output_texture(i)` devolve a saída composta (as janelas e os menus por cima, só onde mudou);
    - o mouse por saída: `pointer_motion_output(i, x, y)` acha a superfície embaixo e dá o foco de mouse a ela.
  - A API por janela (14.16 a 14.18) continua para os testes antigos.
  - Teste: `cargo test` (duas janelas lado a lado na saída 0, cor certa em cada metade, clique vai para a da direita, janela na saída 2 não aparece na 0).
  - Commit: `Fase 14.26: saídas e composição por monitor`
- [x] **14.27 Layer-shell** (Opus · high): *Rust; o spike escolheu A*
  - Ponto de partida: o `Role::Layer` e o `configure_layer` da branch `spike-14.24` (sem margens, sem zona exclusiva, uma textura por camada).
  - Faz:
    - `wlr-layer-shell`: camadas fundo, baixo, topo e sobreposição, com âncoras e margens;
    - a **zona exclusiva** (a barra reserva o alto): o sinal `usable_area_changed(saída, retângulo)`;
    - o teclado `exclusive`/`on_demand` (o menu recebe as teclas) e o mouse nas camadas.
  - Teste: `cargo test` (uma barra de 30 px reduz a área útil; um overlay com teclado exclusivo recebe a tecla; o clique na barra não vai para a janela).
  - Commit: `Fase 14.27: layer-shell no compositor`
- [ ] **14.28 Sentar à mesa** (Sonnet · medium; Opus · high se o visual travar)
  - Faz:
    - o `AppWindow3D` vira `DeskMonitor3D` (`components/desk_monitor_3d/`): mostra a textura de uma saída;
    - `E` num monitor "senta": a câmera enquadra os três;
    - o mouse anda pelos três (o raio acha o monitor e o pixel, e vai como `pointer_motion_output`), com o cursor do hub;
    - segurar Esc levanta; o `AppSessions` cria as 3 saídas e acha os monitores pelo grupo `desk_monitors`.
  - Teste: `tests/check_desk_monitors.gd` com compositor falso (raio no meio do monitor da direita vira a saída 2 e o pixel certo; Esc curto e longo; sentar e levantar).
  - Commit: `Fase 14.28: sentar à mesa e usar os três monitores`
- [ ] **14.29 O arranjo das janelas** (Sonnet · medium)
  - Faz: o `DeskLayout` (GDScript puro, dentro do `AppSessions`):
    - janela nova vai para o monitor com foco e divide o espaço lado a lado (como o dwindle, sem passar de 3 por monitor);
    - fechar arruma de novo; foco por direção, inclusive entre monitores;
    - tela cheia no monitor; mover a janela para o monitor 1, 2 ou 3;
    - respeita a área útil (a barra).
  - Teste: `tests/check_desk_layout.gd` (abrir 1, 2 e 3 janelas; fechar a do meio; foco à direita passa de monitor; tela cheia; mover para o 3).
  - Commit: `Fase 14.29: o arranjo das janelas nos monitores`
- [ ] **14.30 Os atalhos do Omarchy** (Sonnet · medium; Opus · high se o leitor de Lua travar)
  - Faz:
    - `autoload/platform/omarchy_binds.gd` roda um leitor em Lua (como o `spike_binds.lua` da 14.24: a config real com um `hl` falso) e monta a tabela (uma lista: várias ações por tecla);
    - sentado à mesa, a combinação vira ação (comando com o ambiente de dentro, ou ação do `DeskLayout`); o resto vai para o app com foco;
    - o submap: ligar e desligar pelo `WindowHost` (Lua só com aspas simples, retorno conferido, definido de novo a cada entrada e no `configreloaded`, e o vigia com `hl.timer`);
    - os calços (`uwsm-app`, `systemd-run`, `brave-origin`) em `user://shims/` (criados pelo `platform`) e o `-u HYPRLAND_INSTANCE_SIGNATURE` no `AppCompositor.environment()`;
    - a aba Sistema ganha "Copiar a linha da tecla de emergência".
  - Teste:
    - `tests/check_omarchy_binds.gd` com arquivos Lua de exemplo: texto, `omarchy=`, `webapp=`, `unbind`, `code:10` = tecla 1, `hl.dsp.window.close()` = fechar e duas ações na mesma tecla;
    - o `check_app_sessions` confere o ambiente novo e o `check_platform` a lista nova.
  - Commit: `Fase 14.30: os atalhos do Omarchy na mesa`
- [ ] **14.31 O menu e a barra** (Sonnet · medium)
  - Faz:
    - (A, a escolha da 14.24) o `AppSessions` sobe o Quickshell de dentro com o compositor (`QT_QUICK_BACKEND=software`; e o fecha junto), e `SUPER + Space` / `SUPER + Alt + Space` chamam o `omarchy-menu` de dentro;
    - (B fica como plano B, se o Quickshell quebrar numa atualização) a barra e o lançador do hub numa camada desenhada pela Godot por cima do monitor do meio, com a lista do `AppLibrary`.
  - Teste: `check_app_sessions` (o processo sobe e desce com o compositor, com comando falso).
  - Commit: `Fase 14.31: o menu e a barra do Omarchy na mesa`
- [ ] **14.32 Medida e documentação** (Sonnet · medium): *a antiga 14.23*
  - Faz:
    - a medida no **desktop (Alta)**, que é a meta: os três monitores parados e com o Brave tocando vídeo num deles. No notebook, só antes e depois; sem o desktop, a meta fica pendente na trilha do desktop;
    - README, ROADMAP, PLATAFORMA (submap, calços, Quickshell de dentro) e o mapa do `CLAUDE.md` (sai `app_shelf`/telões; entram `desk_monitor_3d`, `omarchy_binds`, `native/`).
  - Commit: `Fase 14.32: documentação da parte 3`

## Riscos (parte 3)
- **O Quickshell não roda bem no compositor** (shm só, Qt pedindo protocolos que faltam, serviços duplicados): o spike decide, e o plano B (barra e lançador do hub) não depende dele.
- **Submap preso** (o hub trava sentado): a tecla de emergência no `bindings.lua`; o hub também volta ao normal ao perder o foco e ao sair.
- **Lua do Omarchy muda numa atualização:** o leitor é tolerante. O que ele não entende vira "sem ação", com aviso no log, e o teste usa arquivos de exemplo.
- **Desempenho com 3 saídas de 1920×1080 em shm:** a imagem só sobe quando muda. A medida no desktop pode baixar para 1600×900.

## Fora do escopo (parte 3)
- Os workspaces além de 1 a 3 (cada monitor é um), o scratchpad, as janelas flutuantes e os atalhos de mouse (arrastar janela).
- A captura de tela de dentro (`omarchy-capture-*`) e o bloqueio de tela de dentro.
- A ponte da área de transferência com o Omarchy de fora (continua fora, como na 14.18).

## Checklist de teste manual (fim da parte 3)
1. `bash tools/linux/compilar_compositor.sh`, depois abrir o hub no notebook. Na casa não há telões nem estante, e a mesa tem três monitores com a barra.
2. `E` no monitor do meio: a câmera enquadra os três. `SUPER + Enter` abre o terminal no monitor com foco; `SUPER + Shift + B` abre o Brave ao lado.
3. `SUPER + Space`: o menu do Omarchy abre **no monitor**, e não no desktop de fora. Pelo menu de apps, abra o Obsidian.
4. `SUPER + setas` troca o foco (inclusive de monitor), `SUPER + W` fecha, `SUPER + F` deixa em tela cheia no monitor e `SUPER + Shift + 3` manda a janela para o terceiro monitor.
5. Segure Esc: você levanta, e os atalhos SUPER voltam a ser do Hyprland (teste `SUPER + Enter` fora do hub).
6. Esc → menu de pausa: as abas Casa e Sistema estão lá.
7. `bash tests/run_tests.sh` → `RESULTADO GERAL: TUDO OK` (com o `cargo test`).
