# Fase 14: O hub no Omarchy

**Status:** **reaberta** (2026-10-14). A parte 1 (14.0–14.12, o launcher) está feita no Linux. A [parte 2](#parte-2-janelas-no-mundo) põe as janelas dos apps dentro do mundo, como o Waylandcraft.
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
- [ ] **14.19 O telão** (Sonnet · medium): *trilha paralela, janela 4*
  - Faz: `components/app_window_3d/` herda da `Screen3D`. Recebe uma "fonte de janela" (a de verdade vem do `AppSessions`; nos testes, uma falsa com uma textura qualquer). Mouse e teclas viram chamadas na fonte; Esc curto vai para o app e segurar Esc sai; a fonte recebe o tamanho; o cursor é desenhado pelo hub. Só usa a interface, sem tocar no Rust.
  - Teste: `tests/check_app_window_3d.gd` com fonte falsa (clique no meio vira as coordenadas certas, Esc curto e longo, `resize` com a resolução).
  - Commit: `Fase 14.19: o telão de app`
- [ ] **14.20 Telões na casa** (Sonnet · medium; Opus · high se o visual travar): *trilha paralela, janela 4, depois da 14.19*
  - Faz: `worlds/home/app_screens.gd` cria três `AppWindow3D` fixos, no alto das paredes, no grupo `app_screen`. Mostra "Livre", o cartão ao olhar e "segure X para fechar". O `home.gd` cria os telões junto do painel.
  - Teste: `tests/check_app_screens.gd` (três telões, oferta ao `AppSessions` falso, telão libera ao fechar). O `check_home` continua passando.
  - Manual: captura dos três telões (fora do repositório).
  - Commit: `Fase 14.20: telões na casa`
- [ ] **14.21 Abrir no mundo** (Sonnet · medium)
  - Faz: o autoload `AppSessions`. O `AppLauncher` passa a usar o compositor quando `AppCompositor.is_available()`, com o ambiente da decisão "Abrir", os ajustes por app (ozone, perfil do Brave) e o plano B em ~10 s. A estante de apps abre no próximo telão livre. Telões cheios mostram o aviso. O hub não some para app no mundo.
  - Teste: `tests/check_app_sessions.gd` com compositor falso:
    - janela nova liga ao app;
    - a segunda janela do mesmo cliente vai para outro telão;
    - telões cheios recusam;
    - sem janela em 10 s, cai no plano B;
    - sem compositor, o fluxo é o da parte 1.

    O `check_app_launcher` continua passando.
  - Commit: `Fase 14.21: abrir apps dentro do mundo`
- [ ] **14.22 Dormir, sair e o atalho** (Sonnet · medium)
  - Faz: compositor ocioso enquanto o hub dorme; aviso ao sair com apps abertos; o atalho `SUPER + H` sem mudança para apps fora.
  - Teste: `check_app_sessions` (dormindo, não sobe textura) e o teste do menu de pausa.
  - Commit: `Fase 14.22: o compositor ao dormir e ao sair`
- [ ] **14.23 Medida e documentação** (Sonnet · medium): *só principal*
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
9. No **desktop** (Alta), a medida da 14.23 está dentro da meta. No notebook, ela só confirma que o Leve não piorou.
