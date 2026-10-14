# Fase 14: O hub no Omarchy

**Status:** aprovado (2026-10-13)
**Branch:** `fase-14`, criada a partir da `fase-linux` (que ainda não foi para a `main`; quando for, `git rebase --onto main fase-linux fase-14`). Checkout principal (`~/git/game-hub`).

### Trabalho com o Nimbalyst
- **Trilha principal** (sessão comum, branch `fase-14`): faz as subetapas em ordem, é a única que marca `[x]` e escreve em "Decisões tomadas durante a fase", e junta a paralela.
- **Trilha paralela** (uma por vez, em **New Worktree**): só subetapas que não mexem nos arquivos da principal naquela janela.

  | Janela | Principal | Paralela | Por que não brigam |
  |---|---|---|---|
  | 1 | 14.1 → 14.2 → 14.3 | 14.8 (estado do sistema) | a 14.8 só cria arquivos em `autoload/platform/` e `autoload/`, e soma linhas no `check_platform.gd` e no `project.godot` |
  | 2 (depois da 14.3 e da 14.8 juntas) | 14.5 → 14.6 → 14.7 | 14.4 (apps no Windows) | a 14.4 cria só o backend do Windows, um teste e uma linha no `testes.yml` |
  | 3 (depois da 14.7 e da 14.4 juntas) | 14.11 | 14.9 → 14.10 (painel e autostart) | a 14.9/14.10 mexem no `home.gd` (só o painel fixo) e no `computer_desk.gd`; a 14.11 mexe no `hub_window.gd` e no `app_launcher.gd` |

  A 14.0 e a 14.12 ficam só na principal.
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
- [ ] **14.7 A estante de apps** (Sonnet · medium; Opus · high se o visual travar)
  - Faz: um móvel novo na casa, mais estreito que a de jogos (5 × 3 caixas quadradas com o ícone; sem ícone, a inicial na cor da categoria), com páginas e filtro por categoria (reaproveita `LibraryShelf.ShelfButton`), cartão ao olhar ("Brave · Internet"), segurar E abre pelo `AppLauncher` e a volta põe o jogador na frente dela. Entra em `Home.MOVABLE` como `"apps"` e em `norte_esquerda` nas 3 disposições.
  - Arquivos: `worlds/home/app_shelf.gd` (novo), `worlds/home/home.gd` (`MOVABLE`), `profiles/home_catalog.tres` (`placements`).
  - Teste: `tests/check_app_shelf.gd` (com a pasta de exemplo: caixas, páginas, filtro, abrir chama o `AppLauncher` com a origem certa, volta na frente); `check_home_custom` continua passando com o móvel novo.
  - Manual: captura em casa, de frente para a janela: a estante cabe entre a parede e o janelão.
  - Commit: `Fase 14.7: estante de apps na casa`
- [x] **14.8 Estado do sistema** (Sonnet · medium) — *trilha paralela, janela 1*
  - Faz: `SystemInfo` (estático, em `autoload/platform/`) com backend Linux: bateria (`/sys/class/power_supply/BAT*`: %, carregando, tem bateria?), rede (`nmcli`: tipo, conectado, nome) e volume (`wpctl`: %, mudo); a base responde "não sei". O autoload `SystemStatus` pergunta a cada 5 s numa thread, para enquanto o hub dorme e avisa `changed`.
  - Arquivos: `autoload/platform/system_info.gd` + `system_info_backend.gd` + `system_info_linux.gd` (novos), `autoload/system_status.gd` (novo), `project.godot`, `tests/check_platform.gd` (`"/sys/class`, `nmcli`, `wpctl`).
  - Teste: `tests/check_system_status.gd` com uma pasta `/sys` de exemplo e respostas falsas do `nmcli` e do `wpctl` (com bateria, sem bateria, sem rede, mudo).
  - Commit: `Fase 14.8: estado do sistema (bateria, rede, volume)`
  - Feito: commit `6b30755` na trilha paralela, juntado na principal (worktree `estado-sistema` mantido para as próximas paralelas).
- [ ] **14.9 O painel do sistema** (Sonnet · medium) — *trilha paralela, janela 3*
  - Faz: um painel fixo na parede norte, acima do computador: hora grande (`HH:MM`, dia da semana e data), bateria (ícone e %, "carregando"), Wi-Fi (nome ou "sem rede") e volume (% ou "mudo"); some o que o sistema não sabe (ex.: desktop sem bateria). Label3D e malhas simples, na camada do interior, com a cor do néon.
  - Arquivos: `worlds/home/system_panel.gd` (novo), `worlds/home/home.gd` (cria o painel junto do computador).
  - Teste: `tests/check_system_panel.gd` (com um `SystemStatus` falso: textos certos, linha escondida sem bateria, hora muda).
  - Manual: captura em casa olhando para o computador.
  - Commit: `Fase 14.9: painel do sistema na casa`
- [ ] **14.10 Abrir com o sistema** (Sonnet · medium) — *trilha paralela, janela 3*
  - Faz: `Autostart` em `autoload/platform/` (Linux: criar, apagar e conferir `~/.config/autostart/game-hub.desktop`; os outros: "não dá"); uma aba **Sistema** no computador (só onde dá), com o interruptor "Abrir o hub ao entrar no Omarchy" e o botão "Copiar a linha do atalho" (a linha do `o.bind` com o comando da 14.1, para colar no `bindings.lua`).
  - Arquivos: `autoload/platform/autostart.gd` (novo), `worlds/home/system_settings_view.gd` (novo), `worlds/home/computer_desk.gd` (`add_page`), `tests/check_platform.gd` (`/autostart/`).
  - Teste: `tests/check_autostart.gd` com uma pasta de exemplo no lugar de `~/.config/autostart` (cria, confere o `Exec`, apaga).
  - Commit: `Fase 14.10: abrir o hub ao entrar no Omarchy`
- [ ] **14.11 Chamar o hub pelo atalho** (Opus · high)
  - Faz: liga o resultado da 14.1: com um app aberto, o atalho traz o hub (encerra a sessão de app, o app fica aberto); com o hub parado em outro workspace, o atalho o foca; durante um jogo, nada muda. Se a 14.1 pediu, o script `tools/linux/game-hub-chamar` (e a linha copiada da 14.10 passa a usá-lo).
  - Arquivos: `autoload/hub_window.gd`, `autoload/app_launcher.gd` e, se preciso, `autoload/platform/window_host_hyprland.gd` e `tools/linux/`.
  - Teste: `tests/check_app_launcher.gd` (o `focus_returned` durante um jogo não faz nada).
  - Manual: passo a passo para colar a linha no `~/.config/hypr/bindings.lua`.
  - Commit: `Fase 14.11: chamar o hub pelo atalho`
- [ ] **14.12 Medida e documentação** (Sonnet · medium) — *só principal*
  - Faz: medida em casa no notebook (Leve) com `tools/medir_desempenho.gd` (`MEDIDA_CASA`), comparada à da Fase 13; README (estante de apps, painel, autostart, atalho, `[apps] ocultos`), ROADMAP (Fase 14 feita), PLATAFORMA (apps, sistema, autostart), CLAUDE.md (mapa: `app_library`, `app_launcher`, `system_status`, `platform/desktop_apps*`, `system_info*`, `autostart`).
  - Commit: `Fase 14.12: documentação`

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

## Checklist de teste manual (fim da fase)
1. No notebook, rode o hub (`godot --path ~/git/game-hub`). Em casa, olhe à esquerda do janelão: a estante de apps mostra ícones (Brave, Foot, Spotify...). Passe a página e troque o filtro (Internet, Sistema...).
2. Segure E no **Foot**: "Abrindo…", o hub some e o terminal aparece no lugar dele. Feche o terminal (`exit`): o hub volta, na frente da estante.
3. Segure E no **Brave**: abre uma janela nova (mesmo com o Brave já aberto). Aperte o atalho do `bindings.lua`: o hub volta e o Brave continua aberto.
4. Olhe para o computador: o painel acima dele mostra a hora certa, a bateria igual à da barra do Omarchy, o nome do Wi-Fi e o volume. Mude o volume no teclado: em até ~5 s o painel acompanha.
5. No computador, aba **Sistema**: ligue "Abrir o hub ao entrar no Omarchy". Saia da sessão e entre de novo: o hub abre sozinho. Desligue: o arquivo `~/.config/autostart/game-hub.desktop` some.
6. Abra um jogo pela estante de jogos: tudo funciona como antes (abrir, jogar, fechar, voltar).
7. `bash tests/run_tests.sh` → `RESULTADO GERAL: TUDO OK`.
