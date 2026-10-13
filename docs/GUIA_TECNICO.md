# Game Hub — guia técnico

Mapa do código para iniciar uma tarefa com o contexto necessário. Complementa [CLAUDE.md](../CLAUDE.md) e [AGENTS.md](../AGENTS.md); o comportamento para o usuário está no [README](../README.md). Atualize as partes afetadas quando a arquitetura mudar. Fases, decisões e progresso continuam em [plans/](plans/README.md), e a direção futura em [ROADMAP.md](ROADMAP.md).

## Entrada e organização

O [project.godot](../project.godot) inicia [worlds/city/city.tscn](../worlds/city/city.tscn). A cena usa [city.gd](../worlds/city/city.gd) para montar ambiente, casa, jogador e cidade. Grande parte dos nós nasce por código, não em cenas detalhadas.

Com janela, o jogador nasce em casa e a cidade monta por orçamento de tempo entre quadros. A porta da rua fica bloqueada até a montagem terminar. `play_intro = false`, usado na maioria dos testes, coloca o jogador na praça e usa a montagem direta. Espere `city.is_city_ready()` ou o sinal `city_ready` antes de inspecionar a cidade pronta.

A base é Godot 4.7, com 4.7.2 como referência no CLAUDE.md e na CI, GDScript tipado, Forward+ e Jolt. A UI usa `canvas_items`, base 1280 × 720; coordenadas de UI não equivalem necessariamente aos pixels da janela.

### Autoloads registrados

A fonte desta lista é a seção `[autoload]` de project.godot. A pasta `autoload/` também contém classes auxiliares: estar nessa pasta não torna uma classe um singleton.

| Nome | Responsabilidade | Implementação |
|---|---|---|
| `AppConfig` | Configurações persistentes e sinal `settings_changed` | [app_config.gd](../autoload/app_config.gd) |
| `InputDevice` | Último aparelho usado e nomes das dicas | [input_device.gd](../autoload/input_device.gd) |
| `SteamLibrary` | Biblioteca instalada, conta, horas e última vez jogado | [steam_library.gd](../autoload/steam_library.gd) |
| `StoreInfo` | Tags e URLs de arte da loja, com cache | [store_info.gd](../autoload/store_info.gd) |
| `GameCategories` | Categoria de cada jogo, consultando os perfis | [game_categories.gd](../autoload/game_categories.gd) |
| `GameArt` | Capas, hero e logo; carregamento e cache de imagens | [game_art.gd](../autoload/game_art.gd) |
| `HubWindow` | Pausar, esconder e restaurar o hub e sua janela | [hub_window.gd](../autoload/hub_window.gd) |
| `GameLauncher` | Pedido de abertura e acompanhamento da sessão | [game_launcher.gd](../autoload/game_launcher.gd) |
| `FriendsService` | Amigos, status e imagens pela Steam Web API | [friends_service.gd](../autoload/friends_service.gd) |
| `ScreenFade` | Cortina de transição e efeito da porta | [screen_fade.gd](../ui/screen_fade.gd) |

`Profiles`, `SteamClient`, `GraphicsQuality`, `HubTheme` e `LibraryStats` são classes com funções estáticas, não autoloads. `WindowHost` é uma classe de backend criada por sua fábrica. `SteamGame`, `SteamFriend` e os Resources de `profiles/` representam dados.

## Fluxos e contratos principais

### Biblioteca → perfis → cidade

1. [SteamClient](../autoload/platform/steam_client.gd) escolhe o backend do SO e informa a pasta da Steam e a conta ativa. [SteamLibrary](../autoload/steam_library.gd) lê `libraryfolders.vdf`, os manifests ACF e os dados locais de horas; [Vdf](../autoload/vdf.gd) faz o parsing. Redistribuíveis e ferramentas são filtrados.
2. [StoreInfo](../autoload/store_info.gd) fornece tags da loja. [GameCategories](../autoload/game_categories.gd) usa primeiro a categoria forçada na configuração, depois a primeira tag compatível e, sem correspondência, `outros`.
3. [Profiles](../profiles/profiles.gd) carrega [world_profile.tres](../profiles/world_profile.tres) e os [perfis de bairros](../profiles/districts/). A ordem da lista define a ordem dos bairros. [DistrictProfile](../profiles/district_profile.gd) reúne cores, tags, sons, enfeite, clima, casca, pesos de arquitetura e script de marco. `density` está reservado, sem efeito; `landmark_script` já é usado.
4. [CityLayout](../worlds/city/city_layout.gd) organiza o espaço; [city.gd](../worlds/city/city.gd) monta os bairros e as cascas, e [CityMap](../worlds/city/city_map.gd) representa a planta para mapas e transporte.
5. [GameArt](../autoload/game_art.gd) procura primeiro seu cache, depois o cache da Steam e então a rede. Imagens podem chegar depois da montagem; consumidores acompanham seus sinais. O carregamento antecipado de arte do mundo usa threads, mas a compressão S3TC permanece na thread principal por uma limitação registrada no código.

Para criar bairros, siga o procedimento do README: perfil novo e inclusão no WorldProfile, com scripts de aparência opcionais. Evite repetir decisões por id de categoria em diferentes sistemas.

### Portal → launcher → janela → retorno

[GamePortal](../components/game_portal/game_portal.gd) fornece área de entrada, informações do jogo e marcadores. Sua origem fica no chão; `+Z` aponta para fora e a área de entrada fica no lado `-Z`. A aparência pertence a [PortalShell](../components/portal_shell/portal_shell.gd) e às implementações de prédio/arco.

Ao permanecer na área de entrada pelo tempo configurado, o portal chama `GameLauncher.launch(app_id, source)`. O launcher abre `steam://rungameid/<appid>` e acompanha `IDLE → LAUNCHING → RUNNING → IDLE`. A consulta de estado roda em thread; a leitura de SO pertence ao SteamClient. `HubWindow` pausa o mundo e delega o controle da janela ao WindowHost. A janela só se esconde quando o jogo aparece ou após o limite de espera para minimizar; isso não é o timeout total de abertura.

Os sinais `launch_started`, `game_started` e `session_ended` comunicam a sessão. Cada pedido recebe um `session_ended` com a mesma origem, inclusive em falhas. A origem decide o retorno: portal para a porta, estante para a estante. Sessões detectadas fora do hub usam `source = null`; o portal evita puxar para a rua quem está dentro de casa. Preserve esse contrato ao mexer no launcher.

Os testes substituem `state_reader` e `url_opener` para não abrir jogos. Windows usa registro/processos; Linux usa os processos `reaper`, ignorando `Install=1`; Hyprland usa workspaces para esconder e restaurar. Consulte [PLATAFORMA.md](PLATAFORMA.md) antes de alterar esses backends.

### Casa, avatar, amigos e configurações

- [Home](../worlds/home/home.gd) lê tema e disposição por Profiles e reage a `AppConfig.settings_changed`. [home_catalog.tres](../profiles/home_catalog.tres) lista temas, disposições e paletas; [HomeProfile](../profiles/home_profile.gd) descreve a casca. Enfeites em [themes/](../worlds/home/themes/) estendem [HomeDecor](../worlds/home/home_decor.gd). A casa não depende de um mundo específico.
- [LibraryShelf](../worlds/home/library_shelf.gd) pagina e filtra a biblioteca. Suas caixas usam [GameInfo](../components/game_portal/game_info.gd) e o launcher, mas **não são GamePortal**: busca, mapa e metrô não devem contar jogos em dobro.
- [FriendsService](../autoload/friends_service.gd) emite `friends_changed` e `avatar_ready`. A cidade posiciona [FriendNpc](../components/friend_npc/friend_npc.gd) e a casa mostra [FriendsWall](../worlds/home/friends_wall.gd); o serviço não conhece o cenário.
- [LibraryStats](../components/library_stats/library_stats.gd) calcula os números sem tela; [StatsWall](../worlds/home/stats_wall.gd) apresenta e atualiza ao acordar. Horas da Steam podem refletir a sessão anterior com atraso.
- [AvatarSpec](../profiles/avatar_spec.gd) descreve o avatar, [avatar_catalog.tres](../profiles/avatar_catalog.tres) fornece opções e [AvatarBody](../components/avatar/avatar_body.gd) cria o corpo compartilhado pelo jogador e pelos hologramas. [HomeMirror](../worlds/home/home_mirror.gd) e [AvatarPanel](../ui/avatar_panel.gd) oferecem reflexo e personalização.
- [ComputerDesk](../worlds/home/computer_desk.gd) usa [Screen3D](../components/screen_3d/screen_3d.gd) para uma tela clicável. [SettingsView](../ui/settings_view.gd) é compartilhada com o menu de pausa; [HomeSettingsView](../worlds/home/home_settings_view.gd) cuida da personalização da casa.
- [AppConfig](../autoload/app_config.gd) persiste em `user://config.cfg`; o posicionamento da janela usa `user://window.cfg` quando aplicável. Não leia nem imprima esses arquivos indiscriminadamente: a configuração pode conter a chave Steam. Caminhos por SO estão em PLATAFORMA.md.

### Jogador, controles e UI

[Player](../player/player.gd) cuida de movimento, olhar, interação, viagem, foco em telas e estado dentro/fora de casa. Cria HUD e painéis; `is_overlay_open()` centraliza a exclusão entre pausa, busca, mapa e metrô. [CameraFeel](../player/camera_feel.gd) concentra balanço, pouso e FOV.

As ações estão em project.godot; [InputDevice](../autoload/input_device.gd) detecta teclado/mouse ou controle e [KeyHint](../ui/key_hint.gd) adapta as dicas. Use as ações existentes, o tema [HubTheme](../ui/hub_theme.gd) e as fontes [HubFonts](../ui/hub_fonts.gd). Uma tela nova deve entrar na cobertura de `check_theme`.

## Onde mexer e o que conferir

Os testes abaixo são pontos de partida; a bateria inteira continua obrigatória antes de commit. Todos os nomes correspondem a `tests/<nome>.gd`.

| Quero alterar | Consultar primeiro | Testes relacionados |
|---|---|---|
| Descoberta da Steam e janela por SO | `autoload/platform/`, PLATAFORMA.md | `check_platform`, `check_steam_linux`, `check_steam_windows`, `check_window_host` |
| Abertura, falhas e retorno do jogo | `game_launcher.gd`, `hub_window.gd`, `game_portal.gd` | `check_phase4`, `check_portal_regression`, `check_session_summary` |
| Tags, perfis e aparência de bairros | `profiles/`, `game_categories.gd`, `worlds/city/` | `check_profiles`, `check_portal_shell`, `check_variants`, `check_district_props`, `check_landmarks`, `check_weather` |
| Arte, texturas e qualidade | `game_art.gd`, `graphics_quality.gd`, `assets/` | `check_phase3_cache`, `check_textures`, `check_graphics_quality` |
| Montagem e biblioteca grande | `city.gd`, `city_layout.gd`, `tests/fake_library.gd` | `check_scale`, `check_home_start`, `check_perf_tool` |
| Busca, orientação e transporte | `ui/`, `city_map.gd`, `city_route_guide.gd`, `components/transit_stop/` | `check_search`, `check_fast_travel`, `check_city_map`, `check_compass`, `check_minimap`, `check_metro` |
| Casa e móveis | `worlds/home/`, `profiles/home_catalog.tres` | `check_home`, `check_home_profile`, `check_home_custom`, `check_shelf`, `check_stats_wall`, `check_home_view` |
| Avatar e espelho | `components/avatar/`, `profiles/avatar_spec.gd`, `home_mirror.gd`, `avatar_panel.gd` | `check_avatar`, `check_mirror`, `check_avatar_panel` |
| Amigos e hologramas | `friends_service.gd`, `components/friend_npc/`, `friends_wall.gd` | `check_phase5`, `check_holograms`, `check_friends_wall` |
| Interação e configurações em tela 3D | `player.gd`, `screen_3d.gd`, `settings_view.gd` | `check_interact`, `check_screen_3d`, `check_settings_view`, `check_home_overlays` |
| Tema, menus e controle | `hub_theme.gd`, `key_hint.gd`, `input_device.gd`, ações em project.godot | `check_theme`, `check_menu_keyboard`, `check_gamepad`, `check_input_device`, `check_pause_menu` |
| Câmera, transições e som | `camera_feel.gd`, `ui/`, `default_bus_layout.tres`, `components/ambient_emitter/` | `check_camera_feel`, `check_door_charge`, `check_transitions`, `check_footsteps`, `check_phase6_audio`, `check_district_title` |

## Verificação e armadilhas

O contrato completo e os exemplos ficam em [tests/README.md](../tests/README.md); execute pelo [run_tests.sh](../tests/run_tests.sh):

```bash
bash tests/run_tests.sh check_platform check_steam_linux check_window_host check_steam_windows
bash tests/run_tests.sh check_home_profile check_home_custom
bash tests/run_tests.sh
```

O runner importa antes de testar e exige `RESULTADO GERAL: TUDO OK`. A Godot pode ser indicada por `GODOT=/caminho/da/godot`. A [CI](../.github/workflows/testes.yml) roda somente os quatro testes de plataforma em Windows e Linux, não a bateria inteira; `check_steam_windows` é pulado fora do Windows.

- Scripts `-s` acessam autoloads por `root.get_node("Nome")`. Classes que dependem deles podem exigir `load(...).new()` e tipo `Node`, em vez do nome global. Classes novas precisam da importação antes do teste.
- Espere a cidade ficar pronta, não um número fixo de frames. O padrão headless não testa o nascimento em casa: para isso, use o caso de `check_home_start`.
- Alguns testes dependem de Balatro, Skyrim, Valheim e Stardew Valley instalados. Para casos novos, prefira [fake_library.gd](../tests/fake_library.gd) antes de criar a cidade. Para amigos falsos ou caminhada pela praça, instale [quiet_friends.gd](../tests/quiet_friends.gd) para evitar interferência das consultas reais.
- `user://` é compartilhado entre worktrees. Use a trava do runner, guarde/restaure dados alterados e normalize as escolhas da casa antes de compará-la com o padrão.
- Não regenere os retratos de regressão `tests/fixtures/casa_atual.json` e `tests/fixtures/profiles_atuais.json` só para fazer uma mudança passar. Eles preservam o comportamento anterior. Nós repetidos podem mudar de nome; use os metadados existentes para localizar peças da casa.
- `Input.parse_input_event` simula o estado do controle e a detecção pelo InputDevice; `root.push_input` atende a entrada dos painéis. Cliques na tela 3D precisam da conversão de coordenadas descrita em tests/README.md.
- Headless não valida reflexos, aparência, áudio percebido ou FPS. [medir_desempenho.gd](../tools/medir_desempenho.gd) mede com janela e emite `MEDIDA`, `MEDIDA_CASA` e `MEDIDA_ESPELHO`. Exemplo: `godot --path . -s tools/medir_desempenho.gd -- 200 leve 22`. O notebook serve para comparação; o desktop é a referência absoluta.
- Erros de script podem impedir `quit()` e deixar o teste aguardando o timeout. Leia a falha antes de repetir uma bateria inteira.

## Pendências documentadas e manutenção

Na preparação deste guia (2026-10-12), os documentos registram as fases 1–13 e Linux como implementadas, com conferências manuais ainda pendentes. Isso é contexto documental, não resultado de testes feitos nesta preparação:

- [Fase Linux](plans/fase-linux.md): abrir/fechar um jogo real e conferir a janela no Windows.
- [Fase 8](plans/fase-8.md) e [Fase 9](plans/fase-9.md): desempenho no desktop, escala da cidade e montagem sem travar a casa.
- [Fase 10](plans/fase-10.md) e [Fase 11](plans/fase-11.md): visual em Alta no desktop, sensação e conferência dos sons.
- [Fase 12](plans/fase-12.md): controle físico, incluindo Windows/XInput; eventos falsos não comprovam essa experiência.
- [Fase 13](plans/fase-13.md): temas, personalização, avatar e espelho no desktop.

Consulte os planos e a “Trilha do desktop” no ROADMAP para o estado atualizado. Steam Flatpak e Linux fora do Hyprland também são caminhos documentados sem validação manual confirmada. Não inicie a próxima fase apenas por ela aparecer no roadmap.

Para referências especializadas de Godot/design, veja o [índice em .claude/skills/](../.claude/skills/README.md) e leia somente a skill pertinente. Esses arquivos podem ser consultados pelo Codex, mas não se presume carregamento automático. Preserve os avisos Apache-2.0 e as licenças dos assets; o README registra as origens e a exceção OFL das fontes.

Ao retomar uma sessão, confira `git status --short`, `git branch --show-current`, o plano e os últimos commits. O nome da branch, os testes executados e as subetapas abertas são estado da sessão, não invariantes deste guia.
