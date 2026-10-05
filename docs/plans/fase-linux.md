# Fase Linux: o hub rodando no Omarchy (Hyprland) sem quebrar o Windows

**Status:** concluída no Linux (L.0–L.7). Falta só o checklist no Windows (fim deste arquivo) antes de juntar na `main`.
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
- [x] **L.0 Preparação e investigação** (modelo: Opus · esforço: high) · `44b28f6`
  - Faz: instala a Godot no Linux, ajusta o `tests/run_tests.sh` para achá-la, roda a bateria e responde às perguntas abertas 1, 2 e 5 com testes ao vivo (feito). As perguntas 3 e 4 foram para a L.3. Não muda código do jogo.
  - Teste: a bateria ainda **não** passa no Linux (pergunta 5): a causa é conhecida e é resolvida na L.2.
  - Arquivos: `docs/plans/fase-linux.md`, `tests/run_tests.sh`.
  - Manual: o dono instala na Steam um jogo pequeno **nativo** e o Balatro (**Proton**).
  - Commit: `Fase Linux L.0: investigação no Omarchy e runner de testes no Linux`
- [x] **L.1 Interface de plataforma, só Windows** (Sonnet · medium) · `465fc6a`
  - Faz: cria `SteamClient` e `steam_client_windows.gd`; `game_launcher.gd` e `steam_library.gd` passam a usá-los. Comportamento idêntico no Windows.
  - Teste: bateria toda; `tests/check_platform.gd` confere o backend escolhido e que nada fora de `autoload/platform/` cita `WinRegistry` ou `tasklist`.
  - Commit: `Fase Linux L.1: interface de plataforma (SteamClient)`
- [x] **L.2 Backend Linux da Steam** (Sonnet · medium; Opus se a detecção teimar) · `67b2b8b`
  - Faz: `steam_client_linux.gd`. Uma varredura de `/proc` dá o jogo rodando (`reaper`, sem `Install=1`) e se a Steam está aberta (processo `steam`). A pasta da Steam vem de `~/.steam/root`, de `~/.local/share/Steam` ou do Flatpak. O `SteamLibrary` passou a achar quem está logado pelo maior `Timestamp` do `loginusers.vdf` quando não há `MostRecent`; a Steam nova não grava mais esse campo, nem aqui nem, provavelmente, no Windows.
  - Teste: `tests/check_steam_linux.gd` com uma "home" e um `/proc` falsos em `tests/fixtures/linux/` (`.gdignore` na pasta). Ele cobre o `Install=1`, um `bash` e o `steam-launch-wrapper` com o texto `SteamLaunch AppId=` e a escolha do usuário no `loginusers.vdf`.
  - Bateria no Linux: 17 testes ok e 6 com falha, **todas por jogos que este notebook não tem** (Skyrim 489830, Valheim 892970, Stardew 413150, app 3405690 e um jogo de terror). Veja "Decisões tomadas durante a fase".
  - Ao vivo, chamando `GameLauncher.launch()` de verdade numa Godot sem janela, com o jogo no monitor externo num workspace vazio:
    - Undertale (nativo): `RUNNING` em 2 s; ao fechar, `session_ended ok=true`;
    - Balatro (Proton): `RUNNING` em 8 s; ao fechar, `ok=true`;
    - Undertale aberto **pela Steam**, por fora do hub: o hub percebeu sozinho e encerrou com `ok=true` ao fechar.
  - Commit: `Fase Linux L.2: backend Linux da Steam`
- [x] **L.3 Janela no Hyprland** (Opus · high: é o ponto mais incerto) · `57b6d3e`
  - Antes de codar: responder às perguntas 3 e 4 ao vivo (Wayland × X11; `hyprctl` no Hyprland 0.56.2). Feito: veja as perguntas.
  - Comportamento pedido pelo dono: ao abrir um jogo, o **jogo abre num workspace vazio no monitor do jogo** (`[window] game_monitor` no `config.cfg`; no notebook, `HDMI-A-1`; vazio ou desligado = o monitor em foco) e o **hub vai para o special workspace**. Quando o jogo fecha, o hub volta ao workspace onde estava, com foco.
  - Faz:
    - `autoload/platform/window_host.gd` (`WindowHost`): a versão base é a janela normal da Godot (minimizar), igual ao Windows de antes; `WindowHost.create()` escolhe.
    - `window_host_hyprland.gd`: os workspaces. Usa a sintaxe Lua e cai na antiga se ela for recusada.
    - `HubWindow` chama o anfitrião e, no Hyprland, não guarda nem restaura posição.
    - `GameLauncher.launch()` chama `HubWindow.make_room_for_game()` logo depois de pedir o jogo.
    - `AppConfig` ganhou a seção `[window]`.
    - `project.godot` usa o Wayland no Linux.
  - Teste: `tests/check_window_host.gd` com um `hyprctl` falso (comandos montados, monitor desligado, jogo aberto por fora, Hyprland antigo, janela não encontrada). No Linux, uma conferência extra roda o `OS.execute` de verdade com `tests/fixtures/linux/hyprctl_eco.sh`. O `check_platform` agora também procura `OS.execute("hyprctl"`.
  - Ao vivo, com o hub de verdade e janela (Wayland), hub num workspace do eDP-1 e jogos no HDMI:
    - Undertale (HDMI mostrando um workspace vazio): o jogo abriu nele, o hub foi para `special:gamehub` e voltou ao workspace dele, ativo, ao fechar;
    - Balatro (HDMI mostrando um workspace ocupado): o hub criou o workspace 4 no HDMI, o jogo abriu lá, e o resto igual.
    - Nos dois, o mouse voltou ao modo capturado.
  - Commit: `Fase Linux L.3: janela no Hyprland`
- [x] **L.4 Documentação** (Sonnet · low)
  - Faz: `docs/PLATAFORMA.md` reescrito (Steam comum, Windows, Linux, janela no Hyprland e as armadilhas); README (Linux nos requisitos, como rodar, pasta de dados, `[window]`, como funciona); ROADMAP (fase feita, sem a frase errada sobre o `registry.vdf`); CLAUDE.md (stack, mapa, regra 5); `tests/README.md` (Godot no Linux, testes que dependem da biblioteca, `tests/fixtures/`).
  - Commit: `Fase Linux L.4: documentação`

- [x] **L.5 O jogo no lugar certo (e tela cheia opcional) no Hyprland** (Opus · high)
  - Por quê: o dono viu os jogos abrindo no tiling, às vezes no workspace do hub, e a tela "pulando" de monitor. Causas, vistas ao vivo:
    - o Omarchy liga `focus_on_activate`, e as janelas da Steam ("Launching...", a janela principal) puxam o foco;
    - quando a "Launching..." fechava, o Hyprland devolvia o foco ao hub, e o jogo nascia no workspace dele;
    - a troca de workspace no clique deixava a tela vazia durante toda a abertura.
  - Faz:
    - `GameLauncher` chama `HubWindow.make_room_for_game()` só quando o jogo começa (`RUNNING`), junto com esconder o hub, e não mais no clique. Até lá, a tela "Abrindo…" continua à vista;
    - `make_room_for_game` não apaga o "workspace de volta" se o hub já se escondeu antes (pelo timer de 10 s);
    - `SteamClient.game_process_ids(app_id)`: os reapers do jogo (no Windows, `[]`);
    - `HubWindow.place_game()`: a cada 0,5 s, por até 90 s, `WindowHost.place_game_windows()`. No Hyprland, acha as janelas do jogo pela árvore de processos (`/proc/<pid>/stat`), garante que cada uma está sozinha num workspace do monitor do jogo (se não, foca o monitor e move para um vazio, levando a tela) e dá foco. Janelas flutuantes (launchers, avisos) ficam como estão; cada janela é tratada uma vez;
    - **tela cheia forçada é opcional** (`[window] game_fullscreen`, padrão `false`), com `fullscreen_state` (define o estado; o `fullscreen` comum alterna).
  - Por que a tela cheia não é forçada por padrão: **jogos que não mudam de tamanho quebram**. O Undertale (GameMaker) ficou desenhado no canto, tanto em tela cheia forçada quanto no tiling; com o F4 do próprio jogo, ficou perfeito (captura conferida). O Undertale não guarda o F4 entre aberturas. O Balatro se ajusta bem ao tiling e tem tela cheia nas opções.
  - Fora do projeto, na config do Omarchy do notebook (`~/.config/hypr`, com backup `*.bak.1791168844`): `steam -silent` no `autostart.lua` (a Steam começa na bandeja) e `o.window("steam", { suppress_event = "maximize activate activatefocus" })` no `hyprland.lua` (as janelas da Steam não roubam o foco). Validado com `hyprctl reload` e `hyprctl configerrors`.
  - Teste: `tests/check_window_host.gd` (corrida de foco, jogo já no lugar, tela cheia ligada e desligada, launcher flutuante, janela já em tela cheia, hub escondido antes pelo timer) com a árvore `tests/fixtures/linux/proc_arvore/`; `check_steam_linux` (processos do jogo); `check_platform` (contrato).
  - Ao vivo: Balatro com o hub no eDP-1: a tela "Abrindo…" ficou à vista até o jogo começar, a Steam não roubou mais o foco, o jogo nasceu num workspace novo do HDMI, e o hub voltou ativo ao fechar.
  - Commit: `Fase Linux L.5: jogo no lugar certo e tela cheia opcional no Hyprland`

- [x] **L.6 Bateria inteira no Linux** (Sonnet · medium)
  - Faz: depois de instalar Skyrim, Valheim e Stardew, a bateria passou em 23 de 24; o `check_phase6_audio` ainda procurava o prédio do app 3405690 (esportes). Agora ele acha um prédio de esportes pela categoria e, sem nenhum, cria o emissor do bairro pela `CategoryAmbience` e confere do mesmo jeito (loop, tocando, 32 m), avisando na saída. A linha "tela continua preta" do `check_phase4` passa de novo: era o cenário sem Skyrim.
  - Teste: `bash tests/run_tests.sh` → `RESULTADO GERAL: TUDO OK`.
  - Commit: `Fase Linux L.6: bateria inteira passa no Linux`

- [x] **L.7 Teste automático no Windows e no Linux (GitHub Actions)** (Sonnet · medium)
  - Por quê: o dono ficou sem acesso ao Windows durante a viagem, e o plano exige conferir o Windows antes de juntar na `main`.
  - Faz:
    - `.github/workflows/testes.yml`: num `windows-latest` e num `ubuntu-latest`, baixa a Godot oficial 4.7.2, **confere o SHA512** publicado pela engine e roda `tests/run_tests.sh check_platform check_steam_linux check_window_host check_steam_windows`. Só os testes que não dependem de jogos instalados. Gatilhos: `push` em `fase-*`, `pull_request` e manual; só leitura no repositório, sem segredos. Se o do Windows falhar, ele reexecuta o teste com a saída completa e mostra se sobrou chave de teste no registro.
    - `tests/check_steam_windows.gd`: **só no Windows** (nos outros, "pulado"). Cria com o `reg.exe` de verdade a chave `HKCU\Software\GameHubTest\Steam` (caminho com barras normais e um espaço, como a Steam grava; `RunningAppID`; `ActiveProcess\pid` = esta Godot; `ActiveUser`; `Apps\<id>` com `Running`/`Updating`), confere o `SteamClientWindows`, testa o `tasklist` com um PID vivo e um morto, e **apaga a chave no fim**. Seguro no PC do dono: não toca na chave real da Steam.
    - `SteamClientWindows.reg_key`: a chave virou variável (padrão = a real), só para esse teste trocar.
  - **Não cobre** (continua sendo teste manual no Windows): abrir um jogo de verdade, a janela (minimizar e voltar no monitor certo) e a bateria completa (precisa de Balatro, Skyrim, Valheim e Stardew).
  - Conferido aqui: o passo de download rodou de verdade no Linux (baixou, conferiu o SHA512 e rodou `--version`); os 4 testes passam sem as variáveis do Hyprland. **O ramo do Windows do workflow só se valida no próprio GitHub** (as aspas do `reg.exe` via `OS.execute` no Windows são o ponto de maior risco).
  - Commit: `Fase Linux L.7: teste automático no Windows e no Linux (GitHub Actions)`

## Perguntas abertas (L.0 responde)
1. ✅ **A Steam do Linux grava o jogo rodando no `registry.vdf`?** **Não.** Com Undertale e Balatro abertos, o arquivo continuou sem `RunningAppID` e sem `Apps`. O plano B virou o plano A: o processo `reaper`.
2. ✅ **Proton e nativo se comportam igual?** Quase. Os dois sobem um `reaper SteamLaunch AppId=<id> -- ...` que vive enquanto o jogo roda e some ao fechar (Balatro: o `reaper` sumiu no mesmo segundo do `Game process removed` do log da Steam). **Armadilha da primeira abertura no Proton:** antes do jogo, a Steam roda o script de instalação com outro `reaper`, que tem **`Install=1`** na linha de comando, e depois passa ~29 s processando o cache de shaders **sem nenhum `reaper`**. Se o hub contasse o `reaper` do `Install=1`, ele acharia que o jogo abriu e voltaria no meio da abertura. Regra: ignorar `Install=1`. A primeira abertura do Balatro levou 49 s do pedido até o jogo (o limite atual é 90 s).
3. ✅ **Godot no Wayland nativo ou no X11 (XWayland)?** **Wayland** (`display/display_server/driver.linuxbsd="wayland"`, que só vale no Linux; se o Wayland falhar, a Godot tenta o X11). Nos dois drivers, o Hyprland ignora "minimizar" e "mudar posição", e a imagem sai igual. O Wayland evita a camada XWayland, que costuma ser pior para mouse capturado e para a NVIDIA. Pontos do Wayland: a Godot informa errado o monitor e a escala (disse tela 0 e escala 2.00, quando era o HDMI com 1.25) e diz `window_is_focused() = false` mesmo com o hub ativo. Como o Hyprland cuida da janela, isso não atrapalha. Falta testar à mão: mouse capturado e F11.
4. ✅ **`hyprctl` esconde e devolve a janela da Godot?** Sim. **No Hyprland 0.56 o `hyprctl dispatch` é Lua**; a sintaxe antiga (`dispatch focusmonitor HDMI-A-1`) responde `error: [string ...`. A API está em `/usr/share/hypr/stubs/hl.meta.lua`. Funcionam (testado):
   - `hl.dsp.focus({ monitor = 'HDMI-A-1' })` e `hl.dsp.focus({ window = 'address:0x...' })`;
   - `hl.dsp.focus({ workspace = '7' })`: vai para o 7 e, se ele não existir, cria no monitor em foco;
   - `hl.dsp.window.move({ workspace = 'special:gamehub', follow = false, window = 'address:0x...' })`: esconde aquela janela (mesmo que outra esteja ativa), sem mostrar o special;
   - `hl.dsp.window.move({ workspace = '3', window = 'address:0x...' })` e depois `hl.dsp.focus({ window = ... })`: devolve e dá foco;
   - `hl.dsp.window.close()`: fecha a janela **ativa** (usado só nos testes ao vivo, depois de conferir qual é a ativa).
   - **Armadilhas:**
     - `workspace = 'empty'` (e `emptym`, `emptynm`) vai para o primeiro workspace vazio de **qualquer** monitor, por isso o hub escolhe o número sozinho;
     - **aspas duplas somem** no `OS.execute` da Godot quando ela lê a resposta (ela passa o comando por um shell), por isso o Lua usa aspas simples.
5. ✅ **A bateria roda no Linux?** Ela importa o projeto sem erro de script, mas a maioria dos testes falha porque `get_steam_path()` devolve vazio no Linux (o HUD mostra "Não encontrei a Steam neste PC") e a cidade nasce sem prédios. Isso é exatamente o que a L.1/L.2 resolvem. Detalhes que valem para depois:
   - os testes usam a biblioteca **real** e procuram o prédio do Balatro (`Building_2379780`), então o Balatro precisa estar instalado;
   - depois de um `SCRIPT ERROR` o teste não chama `quit()` e fica parado até o `timeout` de 240 s. Uma bateria com muitas falhas leva quase uma hora.

## Riscos
- `registry.vdf` com atraso: a L.0 mede; o plano B por `/proc` já está desenhado.
- `hyprctl` ausente ou com sintaxe diferente: o anfitrião cai no minimizar padrão e avisa no HUD; o comando fica num só lugar. **Já aconteceu:** o Hyprland 0.56 trocou o `dispatch` por Lua. O anfitrião deve usar a sintaxe Lua e, se receber erro, tentar a antiga, porque o desktop pode estar numa versão diferente.
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
- 2026-10-04: o contrato é a classe `SteamClientBackend` (`steam_client_backend.gd`), e a versão base dela é a de "sistema sem suporte" (não acha a Steam). O "processo vivo?" ficou dentro de cada backend, fora da interface, porque ninguém de fora precisa dele (L.1).
- 2026-10-04: sem Windows na viagem, o backend do Windows foi conferido no Linux com `reg` e `tasklist` falsos (caminho, conta, PID vivo, `Apps\<id>\Running`). O teste manual no Windows fica para a volta, antes de juntar na `main` (L.1).
- 2026-10-04: pedido do dono: o jogo abre num workspace novo no monitor externo e o hub vai para o special workspace (vale para os testes ao vivo e para a L.3).
- 2026-10-04: "Steam aberta" no Linux = existe um processo chamado `steam` (vem na mesma varredura do `/proc`). Não usamos o `steam.pid`: um arquivo velho ou ausente (Flatpak) daria "Steam fechada" no meio do jogo (L.2).
- 2026-10-04: `app_updating` é sempre `false` no Linux. Só deixa mais genérica a mensagem de "o jogo não abriu" (L.2).
- 2026-10-04: as pastas do Flatpak estão no código, mas não foram testadas (não há Flatpak neste notebook) (L.2).
- 2026-10-04: o workspace do jogo é escolhido pelo hub: o que o monitor do jogo já mostra, se estiver vazio; senão, o menor número livre (L.3).
- 2026-10-04: no Hyprland o hub não guarda nem restaura monitor, posição e tamanho (`user://window.cfg`): quem decide é o Hyprland (L.3).
- 2026-10-04: se o `hyprctl` falhar, o hub só registra um aviso no log e usa o minimizar da Godot (que o Hyprland ignora). O aviso no HUD que o plano citava ficou de fora, para não crescer a subetapa (L.3).
- 2026-10-04: Wayland fora do Hyprland (GNOME, KDE) usa a versão base (minimizar e restaurar como no Windows) e **não foi testado** (L.3).
- 2026-10-04: no `config.cfg` deste notebook ficou `game_monitor="HDMI-A-1"`, a pedido do dono (L.3).
- 2026-10-04: bateria depois da L.3: os mesmos 6 testes com falha. Dentro do `check_phase4`, uma linha da seção I (Skyrim), "tela continua preta", passou a passar (antes falhava). A bissecção tirou `game_launcher.gd`, `hub_window.gd` e `project.godot` da lista de causas. A linha mede um clarear de 0,8 s com o hub a 5 FPS (quadros de 200 ms), num cenário que já é inválido sem o Skyrim. No desktop, com o Skyrim, esse trecho segue outro caminho (troca de jogo, hub continua dormindo). Conferir na bateria do Windows (L.3).
- 2026-10-04: tela cheia forçada pelo hub é opcional e vem desligada: jogos que não mudam de tamanho (Undertale) quebram com ela e também com o tiling. Para esses, a tela cheia do próprio jogo ou o `gamescope` nas opções de inicialização da Steam (o dono preferiu não instalar agora) (L.5).
- 2026-10-04: as regras da Steam (silenciosa e sem roubar foco) ficam na config do Omarchy do dono, não no projeto: são preferência da máquina (L.5).
- 2026-10-05: a decisão sobre os testes que dependem da biblioteca foi resolvida assim: o dono instalou Skyrim, Valheim e Stardew (sem biblioteca falsa), e o `check_phase6_audio` deixou de exigir o app 3405690: acha um prédio de esportes pela categoria e, se não houver, confere o motor pela tabela do bairro (L.6). Bateria: 24 de 24 testes passam no notebook.

## Checklist de teste manual (fim da fase)
No notebook (Omarchy):
1. Abrir o projeto na Godot 4.7.2 (`~/.local/bin/godot --path ~/git/game-hub -e`) e apertar F5. No menu Esc, escolher a qualidade **Leve** (na "alta", o notebook roda a ~9 FPS).
2. Mover o mouse: a câmera gira e o cursor fica preso (Wayland). Apertar F11: liga e desliga a tela cheia.
3. Andar até a porta do Undertale e entrar: a tela "Abrindo…" fica à vista até o jogo começar; aí o jogo abre num workspace vazio do monitor externo e o hub some (vai para o workspace oculto). No Undertale, apertar F4 para a tela cheia do próprio jogo (sem isso ele fica desenhado num canto).
4. Fechar o jogo: o hub volta no workspace onde estava, na mesma porta, ativo. Mexer o mouse: a câmera gira (se não girar, clicar uma vez na janela e anotar).
5. Repetir com o Balatro (Proton).
6. Abrir um jogo pela Steam, por fora do hub: o hub some sozinho e volta quando o jogo fecha.
7. Configurar a chave da API pelo menu Esc e conferir os hologramas de amigos.

No desktop com Windows, antes de juntar na `main`:
1. F5, entrar num jogo: o hub minimiza; fechar: volta na mesma porta, no mesmo monitor.
2. `bash tests/run_tests.sh` → `RESULTADO GERAL: TUDO OK`.
