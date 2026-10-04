# Fase Linux: o hub rodando no Omarchy (Hyprland) sem quebrar o Windows

**Status:** em andamento (L.0)
**Branch:** `fase-linux`

## Contexto
O ROADMAP deixava a Fase Linux como "quando precisar". Ela foi antecipada porque o dono está viajando com um notebook que roda Omarchy (Arch + Hyprland, Wayland). O desktop final (Ryzen 5 5600, 32 GB, RTX 4070) terá **dual boot**, então **Windows e Linux são alvos de primeira classe**: nada aqui pode piorar o Windows.

Hoje o código só do Windows está em três pontos: `autoload/win_registry.gd` (`reg query`), `autoload/game_launcher.gd` (`tasklist` e chaves do registro) e `autoload/steam_library.gd` (`SteamPath`, `ActiveUser`). O resto (VDF, capas, amigos, `steam://rungameid`) já é portátil. Veja [ROADMAP](../ROADMAP.md) e [PLATAFORMA](../PLATAFORMA.md).

## Pronto quando
- `bash tests/run_tests.sh` termina com `RESULTADO GERAL: TUDO OK` no Linux e no Windows.
- No Omarchy: entrar na porta de um jogo abre o jogo, o hub some e, ao fechar o jogo, volta na mesma porta. Vale para um jogo nativo e para um jogo Proton.
- Nenhum arquivo fora de `autoload/platform/` cita registro do Windows, `tasklist`, `/proc` ou `hyprctl`.

## Notebook de desenvolvimento (checado em 2026-10-03)
- Ryzen 5 7520U, **Radeon 610M** (driver `amdgpu` + `vulkan-radeon`), **7 GB de RAM**. Serve para ver se funciona, na qualidade **Leve**. O desempenho de verdade se avalia no desktop com a 4070.
- Telas: eDP 1920×1080 com **escala 1.5** e HDMI 1080p com escala 1 (bom teste de monitor misto).
- Sessão Wayland, Hyprland. Steam nativa em `~/.local/share/Steam`. `steam://` abre a Steam (`xdg-mime` → `steam.desktop`).
- `~/.steam/registry.vdf` **não serve para saber o jogo rodando**: nem com jogo aberto aparecem `RunningAppID`, `Apps` ou `ActiveProcess` (veja a L.0). O PID da Steam está em `~/.steam/steam.pid` e em `HKLM/Software/Valve/Steam/SteamPID` (os dois batem; `/proc/<pid>/comm` = `steam`).
- Jogos de teste instalados: **Undertale** (391540, nativo), **Balatro** (2379780, Proton), Hollow Knight e Death Must Die (Proton).
- Godot 4.7.2 oficial instalada em `~/.local/bin/godot` (SHA512 conferido), fora do repositório.

## Decisões de arquitetura
- **Uma interface de plataforma, dois backends** (regra 5 do CLAUDE.md), em `autoload/platform/`:
  - `steam_client.gd` (`class_name SteamClient`, estático, **não** autoload): `steam_path()`, `read_state(app_id, check_steam) -> Dictionary` (mesmas chaves de hoje: `running_app_id`, `steam_running`, `app_running`, `app_updating`), `active_account_id()`, `is_process_alive(pid)`. Escolhe o backend por `OS.get_name()`.
  - `steam_client_windows.gd`: o código atual, movido sem mudar comportamento.
  - `steam_client_linux.gd`: **jogo rodando = processo `reaper` com `SteamLaunch AppId=<id>` na linha de comando, ignorando os que têm `Install=1`** (lido em `/proc/*/cmdline`; decidido na L.0). Steam aberta = PID de `~/.steam/steam.pid` vivo em `/proc` com `comm` = `steam`. Caminho da Steam: `~/.steam/root`, `~/.local/share/Steam` ou Flatpak. Pasta raiz (`/proc` e `$HOME`) injetável para testes.
  - `win_registry.gd` passa a morar em `autoload/platform/` (o `class_name` não muda).
  - *Descartado:* `if OS.get_name() == "Linux"` espalhado no launcher e na biblioteca (quebra a regra 5).
- **Janela: um "anfitrião" isolado** (`autoload/platform/window_host.gd`) com `hide_for_game()` e `show_after_game()`. No Hyprland, o hub vai para um *special workspace* via `hyprctl`; fora dele, usa o minimizar da Godot. No Wayland, o `HubWindow` pula posição e monitor da janela (o compositor decide).
- **Dados por sistema:** cada sistema tem o seu `user://config.cfg`. A chave da API é digitada uma vez em cada sistema, pelo menu de pausa, nunca no chat.
- **Dual boot:** uma biblioteca Steam por sistema. Biblioteca Linux em disco NTFS compartilhado costuma quebrar o Proton. O hub lê a Steam do sistema em que está rodando. Sem código.

## Subetapas
- [x] **L.0 Preparação e investigação** (modelo: Opus · esforço: high)
  - Faz: instala a Godot no Linux, ajusta o `tests/run_tests.sh` para achá-la, roda a bateria e responde às perguntas abertas 1, 2 e 5 com testes ao vivo (feito). As perguntas 3 e 4 foram para a L.3. Não muda código do jogo.
  - Teste: a bateria ainda **não** passa no Linux (pergunta 5): a causa é conhecida e é resolvida na L.2.
  - Arquivos: `docs/plans/fase-linux.md`, `tests/run_tests.sh`.
  - Manual: o dono instala na Steam um jogo pequeno **nativo** e o Balatro (**Proton**).
  - Commit: `Fase Linux L.0: investigação no Omarchy e runner de testes no Linux`
- [ ] **L.1 Interface de plataforma, só Windows** (Sonnet · medium)
  - Faz: cria `SteamClient` e `steam_client_windows.gd`; `game_launcher.gd` e `steam_library.gd` passam a usá-los. Comportamento idêntico no Windows.
  - Teste: bateria toda; `tests/check_platform.gd` confere o backend escolhido e que nada fora de `autoload/platform/` cita `WinRegistry` ou `tasklist`.
  - Commit: `Fase Linux L.1: interface de plataforma (SteamClient)`
- [ ] **L.2 Backend Linux da Steam** (Sonnet · medium; Opus se a detecção teimar)
  - Faz: `steam_client_linux.gd` (caminho, estado, conta ativa, processo vivo) e, se a L.0 mandar, o plano B por `/proc`.
  - Teste: `tests/check_steam_linux.gd` com `registry.vdf` de exemplo em `tests/fixtures/` (sem nome de usuário real) e uma pasta `/proc` falsa.
  - Manual: a cidade mostra os jogos do notebook; entrar na porta abre o jogo; fechar o jogo traz o hub de volta.
  - Commit: `Fase Linux L.2: backend Linux da Steam`
- [ ] **L.3 Janela no Hyprland** (Opus · high: é o ponto mais incerto)
  - Antes de codar: responder às perguntas 3 e 4 ao vivo (Wayland × X11; `hyprctl` no Hyprland 0.56.2).
  - Faz: `window_host.gd`; `HubWindow` usa o anfitrião; Wayland pula posição e monitor; o driver de vídeo escolhido vai para o `project.godot`.
  - Teste: `tests/check_window_host.gd` com `hyprctl` falso (confere os comandos montados).
  - Manual: abrir jogo → hub some → fechar jogo → hub volta em tela cheia, com foco e mouse preso.
  - Commit: `Fase Linux L.3: janela no Hyprland`
- [ ] **L.4 Documentação** (Sonnet · low)
  - Faz: seção Linux no `docs/PLATAFORMA.md`; README (como rodar no Linux, pasta de dados); ROADMAP com a fase marcada como feita; mapa do CLAUDE.md (pasta `platform/`, Godot no Linux).
  - Commit: `Fase Linux L.4: documentação`

## Perguntas abertas (L.0 responde)
1. ✅ **A Steam do Linux grava o jogo rodando no `registry.vdf`?** **Não.** Com Undertale e Balatro abertos, o arquivo continuou sem `RunningAppID` e sem `Apps`. O plano B virou o plano A: o processo `reaper`.
2. ✅ **Proton e nativo se comportam igual?** Quase. Os dois sobem um `reaper SteamLaunch AppId=<id> -- ...` que vive enquanto o jogo roda e some ao fechar (Balatro: o `reaper` sumiu no mesmo segundo do `Game process removed` do log da Steam). **Armadilha da primeira abertura no Proton:** antes do jogo, a Steam roda o script de instalação com outro `reaper`, que tem **`Install=1`** na linha de comando, e depois passa ~29 s processando o cache de shaders **sem nenhum `reaper`**. Se o hub contasse o `reaper` do `Install=1`, ele acharia que o jogo abriu e voltaria no meio da abertura. Regra: ignorar `Install=1`. A primeira abertura do Balatro levou 49 s do pedido até o jogo (o limite atual é 90 s).
3. ⏳ **Godot no Wayland nativo ou no X11 (XWayland)?** Testar mouse capturado, F11, escala 1.5 e monitor misto. Só afeta a L.3; testar no começo dela.
4. ⏳ **`hyprctl` esconde e devolve a janela da Godot, e o jogo ganha o foco?** O Hyprland é o 0.56.2: conferir a sintaxe ao vivo. Só afeta a L.3; testar no começo dela.
5. ✅ **A bateria roda no Linux?** Ela importa o projeto sem erro de script, mas a maioria dos testes falha porque `get_steam_path()` devolve vazio no Linux (o HUD mostra "Não encontrei a Steam neste PC") e a cidade nasce sem prédios. Isso é exatamente o que a L.1/L.2 resolvem. Detalhes que valem para depois:
   - os testes usam a biblioteca **real** e procuram o prédio do Balatro (`Building_2379780`), então o Balatro precisa estar instalado;
   - depois de um `SCRIPT ERROR` o teste não chama `quit()` e fica parado até o `timeout` de 240 s. Uma bateria com muitas falhas leva quase uma hora.

## Riscos
- `registry.vdf` com atraso: a L.0 mede; o plano B por `/proc` já está desenhado.
- `hyprctl` ausente ou com sintaxe diferente: o anfitrião cai no minimizar padrão e avisa no HUD; o comando fica num só lugar.
- Mexer no `HubWindow` pode quebrar o Windows: a L.3 mantém o caminho do Windows intacto, e o teste manual no Windows acontece antes de juntar na `main`.
- O notebook é fraco: aqui só avaliamos se funciona, não o desempenho.

## Fora do escopo
- O hub como ambiente de desktop ou autostart no Hyprland (V5, horizonte).
- Exportar binário ou AppImage (o dono roda pelo editor).
- Regras de janela em `~/.config/hypr`.

## Decisões tomadas durante a fase
- 2026-10-03: Windows e Linux são alvos de primeira classe (dual boot no desktop).
- 2026-10-03: ao abrir o jogo, o hub vai para um special workspace do Hyprland.
- 2026-10-03: Godot 4.7.2 oficial (zip do GitHub) em `~/.local/bin/godot`, não pelo pacman, para ficar na mesma versão do Windows.
- 2026-10-04: no Linux, "qual jogo está rodando" vem do processo `reaper` (ignorando `Install=1`), não do `registry.vdf` (L.0, perguntas 1 e 2).
- 2026-10-04: as perguntas 3 e 4 (janela) passam para o começo da L.3, porque só ela depende delas (L.0).

## Checklist de teste manual (fim da fase)
1. Abrir o projeto na Godot 4.7.2 e apertar F5 (menu Esc → qualidade Leve no notebook).
2. Andar até a porta do jogo nativo e entrar.
3. O jogo abre, o hub some, e ao fechar o jogo o hub volta na mesma porta, com o mouse capturado.
4. Repetir com o Balatro (Proton).
5. Configurar a chave da API pelo menu Esc e conferir os hologramas de amigos.
