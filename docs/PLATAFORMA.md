# Plataforma: Steam, Windows e Linux

Como o hub conversa com a Steam e com o sistema operacional. Tudo isto já está implementado. O arquivo serve de referência para depurar. A história de como o Linux entrou está em [plans/fase-linux.md](plans/fase-linux.md).

## Onde mora o código de cada sistema
Tudo fica em `autoload/platform/`. Fora dessa pasta, nenhum arquivo executa `reg`, `tasklist`, `hyprctl`, `nmcli`, `wpctl` ou `uwsm-app`, nem lê `/proc`, `/sys` ou arquivos `.desktop` (o `tests/check_platform.gd` confere):
- `steam_client.gd` (`SteamClient`): a única porta para a Steam. `SteamLibrary` e `GameLauncher` perguntam a ele "onde está a Steam?", "quem está logado?" e "qual jogo está rodando?".
- `steam_client_backend.gd`: o contrato que cada sistema cumpre (a versão base é a de um sistema sem suporte, que não acha a Steam).
- `steam_client_windows.gd` e `win_registry.gd`: a resposta no Windows (registro e `tasklist`).
- `steam_client_linux.gd`: a resposta no Linux (pasta da Steam e processos em `/proc`).
- `window_host.gd` (`WindowHost`): quem esconde e mostra a janela do hub. A versão base minimiza e restaura (Windows).
- `window_host_hyprland.gd`: a janela no Hyprland (workspaces), e também achar a janela de um app e dizer quando ela fecha.
- `desktop_apps.gd` (`DesktopApps`), `desktop_apps_backend.gd`, `desktop_apps_linux.gd` e `desktop_apps_windows.gd`: a lista dos programas instalados, o ícone de cada um e como abri-los (Fase 14).
- `system_info.gd` (`SystemInfo`), `system_info_backend.gd` e `system_info_linux.gd`: bateria, rede e volume (Fase 14). Fora do Linux, "não sei".
- `autostart.gd` (`Autostart`): abrir o hub ao entrar na sessão e a linha do atalho (Fase 14).

## Steam (igual nos dois sistemas)
- **Bibliotecas:** `<Steam>/steamapps/libraryfolders.vdf` lista todas as pastas, e pode haver mais de um disco. Em cada uma, `steamapps/appmanifest_<appid>.acf` traz o `appid` e o `name`.
- **O que não é jogo:** redistribuíveis, Proton, Steam Linux Runtime, SteamVR e ferramentas (ex.: appid 228980) ficam fora, por uma lista de ids e por pedaços de nome.
- **Abrir jogo:** `OS.shell_open("steam://rungameid/<appid>")` (no Linux, vai pelo `xdg-open`). **Não** passe parâmetros pela URL, porque a Steam mostra um aviso. Parâmetros de inicialização são configurados pelo usuário na própria Steam.
- **Jogo rodando:** o `GameLauncher` pergunta ao `SteamClient` a cada ~2 s (~5 s com o hub parado).
  - Estados: `IDLE → LAUNCHING → RUNNING → IDLE`.
  - Se o jogo não aparecer como rodando em ~90 s, o hub volta e mostra um aviso.
- **Quem está logado:** se a Steam não disser, o hub usa o `<Steam>/config/loginusers.vdf`: quem tem `MostRecent` = 1 ou, se ninguém tiver (a Steam nova não grava mais isso), o maior `Timestamp`. Com a conta, ele lê o tempo jogado em `userdata/<conta>/config/localconfig.vdf`.
- **Capas:** primeiro o cache local `<Steam>/appcache/librarycache/`; senão o CDN da Steam; tudo salvo em `user://cache/`.
- **Amigos:** `ISteamUser/GetFriendList` e `ISteamUser/GetPlayerSummaries` (campo `gameid`), a cada 1–2 min. Os erros 401 (lista privada), 403 (chave inválida) e 429 (excesso de consultas) viram avisos no HUD, sem nunca mostrar a chave.

## Windows
- **Pasta da Steam:** registro `HKCU\Software\Valve\Steam`, valor `SteamPath` (lido com `reg query`).
- **Jogo rodando:** o DWORD `RunningAppID` na mesma chave fica igual ao appid enquanto o jogo roda e volta a 0 quando fecha. `Apps\<appid>` traz `Running` e `Updating`.
- **Steam aberta:** `ActiveProcess\pid`, conferido com o `tasklist`. `ActiveProcess\ActiveUser` é a conta logada.
- **Dados do hub:** `%APPDATA%\Godot\app_userdata\Game Hub\` (`config.cfg`, `window.cfg`, `cache/`).

## Linux
- **Pasta da Steam:** o atalho `~/.steam/root` (a própria Steam o mantém apontando para a instalação), `~/.local/share/Steam` ou as pastas do Flatpak (`~/.var/app/com.valvesoftware.Steam/...`; no código, mas não testado).
- **O `registry.vdf` NÃO serve:** o `~/.steam/registry.vdf` existe, mas não guarda o jogo rodando (testado com o jogo aberto: sem `RunningAppID`, sem `Apps`).
- **Jogo rodando:** a Steam abre cada jogo, nativo ou Proton, por um processo chamado **`reaper`**, com a linha de comando `reaper SteamLaunch AppId=<id> -- <comando do jogo>`. Ele vive enquanto o jogo roda e some quando o jogo fecha.
  - **Armadilha:** na primeira vez que um jogo Proton abre, a Steam roda antes o script de instalação com outro `reaper`, que tem **`Install=1`**. Esse não é o jogo e é ignorado. Depois dele, a Steam pode passar dezenas de segundos processando shaders sem nenhum `reaper` (o hub ainda está em `LAUNCHING`, esperando).
  - Só contam processos com o nome (`/proc/<pid>/comm`) igual a `reaper`: outros processos podem ter o mesmo texto na linha de comando (ex.: o `steam-launch-wrapper`).
- **Steam aberta:** existe um processo chamado `steam` (na mesma volta por `/proc`). O `steam.pid` não é usado: um arquivo velho ou ausente daria "Steam fechada" no meio do jogo.
- **"Atualizando":** o Linux não diz isso de um jeito simples; `app_updating` é sempre `false` (só deixa a mensagem de "não abriu" mais genérica).
- **Godot e `/proc`:** os arquivos de `/proc` dizem ter tamanho 0, e `FileAccess.get_file_as_string` devolve `""`. Leia com `FileAccess.open(...).get_buffer(4096)`. O `cmdline` separa os argumentos com o byte 0.
- **Dados do hub:** `~/.local/share/godot/app_userdata/Game Hub/`.

## Apps, sistema e autostart (Fase 14)
### Linux
- **Lista de apps:** os `.desktop` de `$XDG_DATA_HOME/applications` (`~/.local/share`) e de cada `$XDG_DATA_DIRS/applications` (`/usr/share`), com subpastas (`a/b.desktop` tem o id `a-b`). O primeiro arquivo com um id vence, mesmo escondido (é como o usuário apaga um app do sistema). Entram só `Type=Application` sem `NoDisplay`/`Hidden`, com `OnlyShowIn`/`NotShowIn` de acordo com o `XDG_CURRENT_DESKTOP`, com `TryExec` que existe, e que **não** sejam jogos da Steam (`steam://rungameid`). O nome vem do `Name[pt_BR]` quando há. Os web apps do Omarchy têm espaço no id (ex.: `Basecamp`) e funcionam do mesmo jeito.
- **Ícones:** caminho absoluto, ou pelo nome em `<tema>/<tamanho>/apps/<nome>.png|svg` (tamanhos 256, 128, scalable, 48...) nas pastas `icons` do XDG e em `~/.icons`; o tema é o `gtk-icon-theme-name` do GTK, depois `hicolor`, `Adwaita` e `Yaru`. Por último, `/usr/share/pixmaps`. SVG é desenhado em 256 px.
- **Abrir:** `uwsm-app -- <id>.desktop` (como o Omarchy abre); sem ele, `gtk-launch <id>`; sem ele, o `Exec` do arquivo. O app herda a saída do hub.
- **Achar a janela do app (Hyprland):** o Brave abre uma janela nova no processo que já existia, então não dá para achar pelo pid. Antes de abrir, o hub guarda os endereços de todas as janelas (`hyprctl clients -j`); a janela do app é a **primeira nova** do tiling (não flutuante, não a do hub, fora do `special:`), de preferência com a classe do `StartupWMClass`. O app nasce no workspace do hub e o hub se esconde (`special:gamehub`), então ele toma o lugar. Se a janela não aparece em 10 s (um app que só focou uma janela que já existia), segue "sem acompanhar": a sessão só acaba quando o hub volta a ter foco.
- **Chamar o hub de volta (atalho):** `omarchy-launch-or-focus 'Game Hub' '<godot> --path <projeto>'`. Focar uma janela do `special:gamehub` abre o `special` por cima da tela, e a Godot recebe `NOTIFICATION_APPLICATION_FOCUS_IN`; o hub avisa `focus_returned` se estava escondido há mais de 1 s. Com um app aberto, isso encerra a sessão do app; com um jogo da Steam rodando, o hub se esconde de novo (`hl.dsp.workspace.toggle_special('gamehub')`, só se o special estiver aberto, depois de focar o monitor dele). A linha para colar no `~/.config/hypr/bindings.lua` sai da aba **Sistema** do computador (`SUPER + H`; `SUPER + G` já é do Omarchy). Cuidado: o padrão `Game Hub` também casa com um título de janela que contenha essas palavras (ex.: uma aba do navegador).
- **Bateria:** `/sys/class/power_supply/BAT*` (`capacity` e `status`). **Rede:** `nmcli -t -f TYPE,STATE,CONNECTION dev`. **Volume:** `wpctl get-volume @DEFAULT_AUDIO_SINK@`. Qualquer parte que falhe responde "não sei" e some do painel.
- **Autostart:** `~/.config/autostart/game-hub.desktop`, com `Exec=<godot> --path <projeto>`. Criar liga, apagar desliga.
### Windows
- **Lista de apps:** os atalhos `.lnk` do Menu Iniciar do usuário (`%AppData%\Microsoft\Windows\Start Menu\Programs`) e de todos (`%ProgramData%\...`), com subpastas; o do usuário vence. O nome é o do arquivo; desinstaladores e `.url` (os jogos da Steam) ficam de fora. Sem ícone nem categoria (a caixa mostra a inicial). Abrir é entregar o `.lnk` ao `OS.shell_open`.
- **Ainda não feito no Windows:** conferir a lista e abrir um app de verdade (o teste roda só no GitHub Actions), acompanhar a janela do app, o painel do sistema e o autostart. Sem acompanhar a janela, a sessão do app acaba quando o hub volta a ter foco.

## A mesa: compositor, atalhos e Quickshell (Fase 14, partes 2 e 3, só Linux)
- **O compositor** é a GDExtension `native/compositor/` (Rust: Smithay 0.7 e godot-rust 0.5), carregada só por `autoload/platform/app_compositor.gd`. Os apps abertos pelo hub entram pelo socket `gamehub-0`. Cada monitor da mesa é uma **saída** (`wl_output` com xdg-output) de 1920×1080; o Rust compõe cada saída numa textura só (fundo, camadas e janelas), que só sobe quando muda. Camadas (layer-shell): fundo, baixo, topo e sobreposição, com âncoras, margens e zona exclusiva (a barra reserva o alto); o teclado exclusivo vai para o menu aberto.
- **O ambiente de dentro** (`AppCompositor.environment()`): `env -u HYPRLAND_INSTANCE_SIGNATURE` (o `hyprctl` de dentro não acha o Hyprland de fora), `WAYLAND_DISPLAY=gamehub-0`, GTK/Qt/SDL em Wayland e os **calços** primeiro no `PATH`. O `DISPLAY` (X11) fica: apps só X11 abrem fora.
- **Os calços** (`user://shims/`, criados pelo hub): `uwsm-app` e `systemd-run` só rodam o comando (os de verdade abrem uma unidade do systemd com o ambiente de fora, e a janela apareceria lá); `brave-origin` usa o perfil do hub (`user://apps/brave`), senão o Brave acha o de fora aberto e abre a janela lá. Com eles, `omarchy-launch-terminal`, `omarchy-launch-browser`, os webapps e o `omarchy-launch-or-focus` abrem dentro. O `launch-or-focus` sempre abre outra janela (o `hyprctl` de dentro não vê nada); se incomodar, um calço `hyprctl` que responda `clients -j`.
- **Os atalhos:** `omarchy_binds.lua` roda a config de verdade (`hypr.hyprland`) com um `hl` falso que anota `hl.bind` e `hl.unbind` (o `lua` é dependência do Hyprland); `OmarchyBinds` monta `combinação -> lista de ações` (o Hyprland deixa várias na mesma tecla). `hyprctl binds -j` não serve: não traz o comando.
- **O submap** (`gamehub_seat`): sentado, o hub o liga com `hyprctl eval` (Lua em tempo real) para as combinações `SUPER` chegarem à Godot. Armadilhas: o `OS.execute` da Godot **come as aspas duplas** (o Lua do hub usa só aspas simples, e o retorno é conferido: erro vem com código 7); um submap sem tecla nenhuma não é registrado (ele tem a de emergência); um `reload` do Hyprland **apaga as teclas do submap mas deixa o Hyprland dentro dele**: o hub redefine a cada 5 s e renova o vigia (`hl.timer` de 20 s, só vale para a última "geração"). A rede de segurança do dono é a linha universal no `bindings.lua` (`submap_universal = true`, `SUPER + SHIFT + ESC`). O `wtype` só dispara atalhos do Hyprland com o Esc: a conferência é com a mão.
- **O Quickshell de dentro:** `quickshell -n -p $OMARCHY_PATH/shell` (padrão `/usr/share/omarchy/shell`) com `QT_QUICK_BACKEND=software` (o compositor só aceita memória compartilhada). Serviços repetidos falham sem estrago (polkit, notificações, portal); o idle e o bloqueio de tela não existem lá dentro; os workspaces da barra ficam parados; ele repete os scripts da barra (custo de CPU).
- **Defeito do Smithay 0.7:** um commit vazio numa superfície cuja camada já foi destruída derrubava o app (o Quickshell, ao fechar o menu). Um gancho do hub evita.

## Janela
### Windows (e Linux fora do Hyprland)
- **Esconder:** `DisplayServer.window_set_mode(WINDOW_MODE_MINIMIZED)`. Enquanto o hub dorme, ele liga `OS.low_processor_usage_mode`, pausa a árvore e baixa o FPS.
- **Voltar:** restaura monitor, posição, tamanho e modo (guardados em `user://window.cfg`), chama `window_move_to_foreground()` e põe o jogador no marcador de retorno do portal.
- O Linux fora do Hyprland (GNOME, KDE) usa este caminho, mas **não foi testado**.

### Hyprland
O Hyprland não tem minimizar e decide sozinho posição e tamanho, por isso o hub usa workspaces e não guarda o `window.cfg`:
- **Abrir jogo:** a tela "Abrindo…" fica à vista até o jogo começar (`RUNNING`). Aí a tela vai para um workspace vazio do **monitor do jogo** (`[window] game_monitor` no `config.cfg`; vazio ou desligado = o monitor em foco): se o workspace que esse monitor mostra já está vazio, é ele; senão, o de menor número livre. Trocar só nesse momento, e não no clique, evita a "corrida de foco": quando a janelinha "Launching..." da Steam fecha, o Hyprland devolve o foco à última janela usada (o hub).
- **Janela do jogo:** quando ela aparece, o hub confere se está sozinha num workspace do monitor do jogo; se não, foca o monitor e move a janela para um vazio, levando a tela junto. A janela do jogo é achada pela árvore de processos: é de um "filho" (ou neto) do `reaper` (`/proc/<pid>/stat`). Janelas flutuantes (launchers, avisos) ficam como estão.
- **Tela cheia:** opcional (`[window] game_fullscreen`, padrão `false`). **Forçar o tamanho quebra jogos que não se redimensionam** (o Undertale fica desenhado num canto, tanto em tela cheia forçada quanto no tiling). Quando é o próprio jogo que pede tela cheia (F4 no Undertale, opção de vídeo no Balatro), o Hyprland respeita e fica certo. Para jogos antigos que sempre abrem em janela, a saída é o `gamescope` nas opções de inicialização da Steam (ex.: `gamescope -f -F nearest -- %command%`).
- **Esconder:** o hub vai para o workspace especial `special:gamehub`, sem levar a tela junto.
- **Voltar:** o hub volta ao workspace onde estava e ganha o foco.
- **Comandos (Hyprland 0.56, `hyprctl dispatch` em Lua):**
  - `hl.dsp.focus({ monitor = 'HDMI-A-1' })`, `hl.dsp.focus({ workspace = '4' })` (cria o 4 no monitor em foco, se não existir);
  - `hl.dsp.window.move({ workspace = 'special:gamehub', follow = false, window = 'address:0x...' })`;
  - `hl.dsp.focus({ window = 'address:0x...' })`;
  - `hl.dsp.window.fullscreen_state({ internal = 2, client = 2, window = 'address:0x...' })` **define** tela cheia. Cuidado: `hl.dsp.window.fullscreen(...)` e `hl.dsp.window.float({ window = ... })` **alternam** (chamados duas vezes, desfazem); para flutuar sem alternar, `float({ action = 'set', window = ... })`.
  - A API está em `/usr/share/hypr/stubs/hl.meta.lua`. Se o Lua for recusado, o hub tenta a sintaxe antiga (`movetoworkspacesilent`, `focuswindow`...).
- **Armadilhas:**
  - **aspas duplas somem:** quando a Godot precisa ler a resposta (`OS.execute` com saída), ela roda o comando por um shell, com cada argumento entre aspas duplas. Uma aspa dupla dentro do argumento some no caminho. Use aspas simples no Lua e só caracteres seguros nos nomes;
  - `workspace = 'empty'` vai para o primeiro workspace vazio de **qualquer** monitor (por isso o hub escolhe o número).
- **Steam no Omarchy (config da máquina, não do projeto):** o Omarchy liga `misc:focus_on_activate`, e as janelas da Steam puxam o foco e a tela. No notebook ficou, em `~/.config/hypr`: `o.launch_on_start("steam -silent")` (a Steam começa na bandeja da barra, que existe: widget `omarchy.tray`) e `o.window("steam", { suppress_event = "maximize activate activatefocus" })`.
- **Transparência:** o Omarchy deixa toda janela levemente transparente; a regra dele para `steam.*` tira isso dos jogos Proton (`steam_app_<id>`), mas não dos nativos (o Undertale tem classe vazia).
- **Driver de vídeo:** Wayland (`display/display_server/driver.linuxbsd` no `project.godot`). No Wayland, a Godot informa errado o monitor e a escala e diz que a janela está sem foco mesmo quando está ativa; como quem cuida da janela é o Hyprland, isso não atrapalha.

### No editor
Desative a janela embutida (aba Game › ⋮ › Embed Game on Next Play). Senão, a janela pertence ao editor e o hub não consegue escondê-la.
