# Game Hub — contexto do projeto

## Visão
Um launcher em forma de mundo 3D em primeira pessoa. Cada jogo da biblioteca Steam é um prédio numa cidade, e os prédios se agrupam em bairros por categoria. Ao entrar na porta, a tela escurece, o hub se minimiza e o jogo abre pela Steam. Quando o jogo fecha, o hub volta na mesma porta. Amigos aparecem como hologramas na porta do jogo que estão jogando.

**Norte de longo prazo:** um desktop virtual transformado em mundo, inspirado no PlayStation Home. A casa é o computador, e a biblioteca decide como o mundo é (bairros, biomas, clima, som). **Sistemas e cenário ficam separados**, porque os mesmos sistemas vão servir a biomas e mundos maiores.

- **Feito:** fases 1–9, visual v2 e Fase Linux (detalhes no [README](README.md); da Fase Linux falta a conferência no Windows, no fim de [docs/plans/fase-linux.md](docs/plans/fase-linux.md)).
- **Próximas fases, ordem e decisões:** [docs/ROADMAP.md](docs/ROADMAP.md). Nada do "Horizonte" é implementado sem virar fase antes.

## Sobre o dono do projeto
- Tem conhecimento **básico** de programação. Explique as decisões de forma simples, em português, e comente o código em português.
- Testa no editor da Godot: no Windows (desktop) e no Linux (notebook com Omarchy). Toda tarefa termina com um **checklist de teste manual** curto: o que abrir, o que apertar, o que deve acontecer.
- Quando algo precisar ser feito à mão no editor, dê o passo a passo.

## Stack
- **Godot 4.7.2** (versão padrão, não .NET), em `C:\Godot\Godot_v4.7.2-stable_win64_console.exe` no Windows e em `~/.local/bin/godot` no Linux. **GDScript com tipagem estática** (`var x: int`). Renderer Forward+, física Jolt.
- **Windows 10** e **Linux** (Omarchy: Hyprland 0.56, Wayland). O desktop (Ryzen 5 5600, RTX 4070) terá dual boot; o notebook de viagem é fraco (use a qualidade Leve). Detalhes de Steam, Windows e Linux: [docs/PLATAFORMA.md](docs/PLATAFORMA.md).
- Git, com um commit por passo concluído e testado.

## Mapa do projeto

```
autoload/      sistemas globais; não conhecem nenhum mundo
  steam_library, steam_game, vdf      biblioteca instalada (parser VDF/ACF)
  store_info, game_categories         tags da loja → categoria/bairro
  game_art                            capas (cache local da Steam → CDN → user://cache)
  game_launcher, hub_window           abrir jogo, minimizar/voltar, sessão
  friends_service, steam_friend       amigos pela Steam Web API
  app_config, graphics_quality        user://config.cfg, qualidade gráfica
  platform/                           ÚNICO lugar com código de sistema operacional
    steam_client (+ backends por SO)    "onde está a Steam? qual jogo está rodando?"
    window_host (+ hyprland)            esconder/mostrar a janela do hub
    win_registry                        lê o registro do Windows
profiles/      perfis de dados (Fase 7): um .tres por bairro em districts/,
               a lista do mundo em world_profile.tres; Profiles lê.
               Clima: worlds/city/district_weather.gd
components/    peças reutilizáveis em qualquer mundo
  game_portal/      a "porta" de um jogo (app_id, área de entrada, marcadores)
  friend_npc/       holograma de amigo
  transit_stop/     parada de transporte (lógica do metrô; a aparência é do mundo)
  travel_door/      porta de viagem (E leva a outro lugar; a aparência é de quem usa)
  screen_3d/        tela 3D clicável (o conteúdo é qualquer Control)
  ambient_emitter/  som ambiente por categoria
player/        primeira pessoa; cria HUD, menu de pausa (Esc), busca (Tab), mapa (M) e painel do metrô
ui/            HUD (bússola, minimapa), avisos, telas "Abrindo"/"Jogando", fade, menus, mapa grande, painel do metrô
worlds/home/   a casa (loft): sala, estante, mural e computador; não conhece nenhum mundo
worlds/city/   o primeiro mundo: layout, prédios, decoração, dia e noite, planta (CityMap), metrô
  district_props/  o elemento de identidade de cada bairro (um script por bairro)
tests/         bateria automática (veja tests/README.md)
tools/         scripts de geração rodados à mão (ex.: atlas das árvores)
assets/        só CC0, com LICENSE em cada pasta de origem
docs/          ROADMAP, PLATAFORMA, plans/ (planos das fases), design/
```

## Regras de arquitetura
1. **Sistemas não conhecem mundos.** Nada em `autoload/` referencia `worlds/`. A comunicação é por sinais e grupos (ex.: `game_portal`, `route_guide`, `city_night`).
2. **Mundos só posicionam e decoram portais.** Lógica de Steam não entra em mundo.
3. **GamePortal é genérico.** Hoje fica na porta de um prédio; amanhã num arco de pedra ou num boxe de corrida. Ele não pode depender de ser um prédio.
4. **Dados de mundo moram em perfis** (a partir da Fase 7). Cores, som, enfeite, clima e arquitetura de um bairro são dados, e não um `match` de categoria espalhado pelo código.
5. **Plataforma isolada.** Os sistemas perguntam "qual jogo está rodando?" ao `SteamClient`. Só `autoload/platform/` sabe se a resposta vem do registro do Windows ou dos processos do Linux (o `tests/check_platform.gd` confere).
6. Prefira criar nós por código a escrever `.tscn` complexos à mão. Quando `.tscn` for necessário, mantenha simples.

## Segurança e privacidade (sempre)
- A chave da Steam Web API fica só em `user://config.cfg`, fora do repositório. **Nunca** peça que ela seja colada no chat, nunca a imprima e nunca a ponha em log ou aviso.
- Commits com o e-mail noreply do GitHub (`32810557+guitavaress@users.noreply.github.com`). Nenhum e-mail pessoal no repositório.
- **Prints com capas de jogos nunca vão para o repositório** (é público). Capturas ficam na pasta temporária da sessão.
- **Não enviar para o GitHub (push) sem o dono pedir.** Commits locais, em branch, podem ser feitos.

## Assets
- Só **CC0** (Kenney, Poly Haven, ambientCG, Quaternius...), com o `LICENSE` na pasta e o crédito no README.
- **Antes de baixar, peça permissão** dizendo o nome do arquivo, a origem e o tamanho.
- Arquivos-fonte pesados (ex.: modelo glTF de centenas de MB) ficam **fora do repositório**. Entra só o que o jogo usa (ex.: o atlas gerado).

## Como trabalhar

### Modelos e esforço
| Momento | Modelo | Esforço |
|---|---|---|
| Planejar uma fase, decisão de arquitetura, revisar um plano | Opus | high |
| Executar um passo do plano | Sonnet (ou Opus) | medium |
| Bug teimoso (o mesmo erro duas vezes), problema visual difícil | Opus | high |
| Tarefa mecânica (renomear, ajustar texto, docs curtos) | Sonnet | low ou medium |

- O atalho `/model opusplan` faz isso sozinho: Opus no modo plan, Sonnet na execução.
- O esforço mais alto da lista do `/effort` fica reservado para quando algo travar de verdade. Não deixe esforço alto como padrão.

### Fluxo de uma fase
1. **Plano primeiro.** No modo plan, escreva `docs/plans/fase-N.md` seguindo [docs/plans/README.md](docs/plans/README.md) e espere aprovação.
2. **Uma branch por fase** (`fase-7`) e **subetapas numeradas** (7.1, 7.2...). Cada subetapa tem teste, commit e o seu `[x]` marcado no plano.
3. **Volte ao modo plan quando:** surgir uma decisão de arquitetura que o plano não previa, ou o mesmo erro aparecer duas vezes seguidas. Atualize o plano.
4. **Ao fim de cada subetapa:** resumo curto, checklist de teste manual e a mensagem do commit.
5. **Ao fim da fase:** atualizar README (o que mudou para o usuário) e ROADMAP (fase marcada como feita); juntar na `main` só quando o dono pedir.

### Sessões e contexto
- **Uma sessão por subetapa grande.** O plano em `docs/plans/` é a memória entre sessões: uma sessão nova lê o plano, vê o que está marcado e continua dali.
- Leia o mapa acima antes de explorar o código. Abra só os arquivos que o passo precisa.
- **Nimbalyst:** o projeto é o checkout principal (`~/git/game-hub`), na branch da fase. A trilha principal usa sessões comuns; uma trilha paralela usa **New Worktree**, que nasce da branch atual em `~/git/game-hub_worktrees/<nome>` (branch `worktree/<nome>`). O plano da fase diz quem é a trilha principal e como juntar.
- **Botões Commit e Merge do Nimbalyst não são usados:** o Commit usa o e-mail pessoal do git global, e o Merge pula a bateria e o plano. O commit é feito pelo agente, com o e-mail noreply.
- **Uma bateria por vez:** o `user://` (com o `config.cfg` e o cache) é um só para todos os worktrees. O `run_tests.sh` tem trava, mas um `godot -s` rodado à mão não espera.

### Testes
- **Antes de cada commit:** `bash tests/run_tests.sh` precisa terminar com `RESULTADO GERAL: TUDO OK`.
- Recurso novo ganha um `tests/check_<nome>.gd`. Formato e armadilhas: [tests/README.md](tests/README.md).
- Mudança visual: confira com captura de tela (com janela, fora do repositório) antes de entregar.
