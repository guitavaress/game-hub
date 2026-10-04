# Plataforma: Steam, Windows e Linux

Como o hub conversa com a Steam e com o sistema operacional. Tudo isto já está implementado. O arquivo serve de referência para depurar. A história de como o Linux entrou está em [plans/fase-linux.md](plans/fase-linux.md).

## Onde mora o código de cada sistema
Tudo fica em `autoload/platform/`. Fora dessa pasta, nenhum arquivo executa `reg`, `tasklist` ou `hyprctl`, nem lê `/proc` (o `tests/check_platform.gd` confere):
- `steam_client.gd` (`SteamClient`): a única porta para a Steam. `SteamLibrary` e `GameLauncher` perguntam a ele "onde está a Steam?", "quem está logado?" e "qual jogo está rodando?".
- `steam_client_backend.gd`: o contrato que cada sistema cumpre (a versão base é a de um sistema sem suporte, que não acha a Steam).
- `steam_client_windows.gd` e `win_registry.gd`: a resposta no Windows (registro e `tasklist`).
- `steam_client_linux.gd`: a resposta no Linux (pasta da Steam e processos em `/proc`).
- `window_host.gd` (`WindowHost`): quem esconde e mostra a janela do hub. A versão base minimiza e restaura (Windows).
- `window_host_hyprland.gd`: a janela no Hyprland (workspaces).

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

## Janela
### Windows (e Linux fora do Hyprland)
- **Esconder:** `DisplayServer.window_set_mode(WINDOW_MODE_MINIMIZED)`. Enquanto o hub dorme, ele liga `OS.low_processor_usage_mode`, pausa a árvore e baixa o FPS.
- **Voltar:** restaura monitor, posição, tamanho e modo (guardados em `user://window.cfg`), chama `window_move_to_foreground()` e põe o jogador no marcador de retorno do portal.
- O Linux fora do Hyprland (GNOME, KDE) usa este caminho, mas **não foi testado**.

### Hyprland
O Hyprland não tem minimizar e decide sozinho posição e tamanho, por isso o hub usa workspaces e não guarda o `window.cfg`:
- **Abrir jogo:** o jogo abre num workspace vazio do **monitor do jogo** (`[window] game_monitor` no `config.cfg`; vazio ou desligado = o monitor em foco). Se o workspace que esse monitor mostra já está vazio, é ele; senão, o hub cria o de menor número livre.
- **Esconder:** o hub vai para o workspace especial `special:gamehub`, sem levar a tela junto.
- **Voltar:** o hub volta ao workspace onde estava e ganha o foco.
- **Comandos (Hyprland 0.56, `hyprctl dispatch` em Lua):**
  - `hl.dsp.focus({ monitor = 'HDMI-A-1' })`, `hl.dsp.focus({ workspace = '4' })` (cria o 4 no monitor em foco, se não existir);
  - `hl.dsp.window.move({ workspace = 'special:gamehub', follow = false, window = 'address:0x...' })`;
  - `hl.dsp.focus({ window = 'address:0x...' })`.
  - A API está em `/usr/share/hypr/stubs/hl.meta.lua`. Se o Lua for recusado, o hub tenta a sintaxe antiga (`movetoworkspacesilent`, `focuswindow`...).
- **Armadilhas:**
  - **aspas duplas somem:** quando a Godot precisa ler a resposta (`OS.execute` com saída), ela roda o comando por um shell, com cada argumento entre aspas duplas. Uma aspa dupla dentro do argumento some no caminho. Use aspas simples no Lua e só caracteres seguros nos nomes;
  - `workspace = 'empty'` vai para o primeiro workspace vazio de **qualquer** monitor (por isso o hub escolhe o número).
- **Driver de vídeo:** Wayland (`display/display_server/driver.linuxbsd` no `project.godot`). No Wayland, a Godot informa errado o monitor e a escala e diz que a janela está sem foco mesmo quando está ativa; como quem cuida da janela é o Hyprland, isso não atrapalha.

### No editor
Desative a janela embutida (aba Game › ⋮ › Embed Game on Next Play). Senão, a janela pertence ao editor e o hub não consegue escondê-la.
