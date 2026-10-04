# Plataforma: Steam e Windows

Como o hub conversa com a Steam e com o sistema operacional. Isto já está implementado. O arquivo serve de referência para depurar e para a **Fase Linux** (veja o [ROADMAP](ROADMAP.md)).

## Onde mora o código específico do Windows
Tudo fica em `autoload/platform/` (Fase Linux L.1):
- `steam_client.gd` (`SteamClient`): a única porta. `SteamLibrary` e `GameLauncher` perguntam a ele "onde está a Steam?", "quem está logado?" e "qual jogo está rodando?".
- `steam_client_windows.gd`: a resposta no Windows (registro e `tasklist`, para saber se a Steam ainda está viva).
- `steam_client_linux.gd`: a resposta no Linux (processos em `/proc`; detalhes no topo do arquivo e em [plans/fase-linux.md](plans/fase-linux.md)).
- `win_registry.gd`: o único arquivo que lê o registro.
- `steam_client_backend.gd`: o contrato que cada sistema cumpre.

No Linux, os mesmos valores ficam em `~/.steam/registry.vdf`, que o `autoload/vdf.gd` já sabe ler.

## Steam
- **Caminho da Steam:** registro `HKCU\Software\Valve\Steam`, valor `SteamPath` (lido com `reg query`).
- **Bibliotecas:** `<SteamPath>/steamapps/libraryfolders.vdf` lista todas as pastas, e pode haver mais de um disco. Em cada uma, `steamapps/appmanifest_<appid>.acf` traz o `appid` e o `name`.
- **O que não é jogo:** redistribuíveis, Proton, SteamVR e ferramentas (ex.: appid 228980) ficam numa lista de exclusão editável.
- **Abrir jogo:** `OS.shell_open("steam://rungameid/<appid>")`. **Não** passe parâmetros pela URL, porque a Steam mostra um aviso. Parâmetros de inicialização são configurados pelo usuário na própria Steam.
- **Jogo rodando:** o DWORD `RunningAppID` em `HKCU\Software\Valve\Steam` fica igual ao appid enquanto o jogo roda e volta a 0 quando fecha. O launcher consulta a cada ~2 s.
  - Estados: `IDLE → LAUNCHING → RUNNING → IDLE`.
  - Se o jogo não aparecer como rodando em ~90 s, o hub volta e mostra um aviso.
- **Capas:** primeiro o cache local `<SteamPath>/appcache/librarycache/`; senão o CDN da Steam; tudo salvo em `user://cache/`.
- **Amigos:** `ISteamUser/GetFriendList` e `ISteamUser/GetPlayerSummaries` (campo `gameid`), a cada 1–2 min. Os erros 401 (lista privada), 403 (chave inválida) e 429 (excesso de consultas) viram avisos no HUD, sem nunca mostrar a chave.

## Janela
- **Minimizar:** `DisplayServer.window_set_mode(WINDOW_MODE_MINIMIZED)`. Enquanto minimizado, o hub liga `OS.low_processor_usage_mode`, pausa a árvore e baixa o FPS.
- **Voltar:** restaura o modo de janela anterior, chama `window_move_to_foreground()` e põe o jogador no marcador de retorno do portal.
- **No editor:** desative a janela embutida (aba Game › ⋮ › Embed Game on Next Play); senão, minimizar não funciona.
