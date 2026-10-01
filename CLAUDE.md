# Game Hub — contexto do projeto

## Visão
Um "launcher" em forma de mundo 3D em primeira pessoa. O jogador caminha por uma cidade onde cada prédio representa um jogo da sua biblioteca Steam. Ao entrar no prédio, a tela escurece, o hub se minimiza e o jogo abre pela Steam. Quando o jogo fecha, o hub reaparece na porta do mesmo prédio. Amigos da Steam aparecem como NPCs na porta do prédio do jogo que estão jogando.

A cidade é a **primeira versão**. No futuro, os mesmos sistemas serão reaproveitados num mundo aberto maior (ex.: montanha de gelo com Skyrim, cidade medieval com Baldur's Gate, pista de corrida com som de motor ouvido de longe). Por isso, **sistemas e cenário devem ficar separados** desde o início.

**O norte de longo prazo:** um **desktop virtual transformado em mundo**, inspirado no PlayStation Home. A casa do jogador é o computador (biblioteca, amigos e configurações ficam dentro dela), sair da casa é "ir jogar", e a biblioteca Steam decide como o mundo é (bairros, biomas, clima, som). Versões V1–V6, fases seguintes e decisões: **[docs/ROADMAP.md](docs/ROADMAP.md)**.

## Sobre o dono do projeto
- Tem conhecimento **básico** de programação. Explique as decisões de forma simples e comente o código em português.
- Vai testar tudo no editor da Godot, no Windows. Sempre termine uma tarefa com um **checklist de teste manual** curto (o que abrir, o que apertar, o que deve acontecer).
- Quando algo precisar ser feito à mão no editor da Godot, dê o passo a passo.

## Stack
- **Godot 4.x** (versão estável mais recente), **GDScript** com tipagem estática (`var x: int`).
- **Windows 10** hoje; Linux planejado (Fase Linux do roadmap). Código específico do sistema operacional fica só em arquivos isolados (hoje: `autoload/win_registry.gd` e o `tasklist` no `game_launcher.gd`). Steam instalada.
- Git desde o primeiro dia; um commit por etapa concluída.
- Nas fases iniciais, use formas primitivas (CSGBox3D, MeshInstance3D com BoxMesh) em vez de assets. Assets (ex.: kits CC0 da Kenney) entram só na fase de polimento.

## Arquitetura

```
res://
  autoload/            # sistemas globais, independentes de qualquer mundo
    steam_library.gd   # lê jogos instalados
    game_launcher.gd   # abre jogo, minimiza hub, detecta fechamento
    friends_service.gd # (fase 5) amigos via Steam Web API
    app_config.gd      # lê/grava user://config.cfg
  components/
    game_portal/       # peça reutilizável: qualquer lugar que "é" um jogo
  player/              # controlador em primeira pessoa
  ui/                  # HUD, fade de transição
  worlds/
    city/              # primeiro mundo
```

### Regras
1. **Sistemas não conhecem mundos.** Nada em `autoload/` referencia cenas de `worlds/`. A comunicação é por sinais.
2. **Mundos só posicionam portais.** Um mundo não contém lógica de Steam; ele instancia `GamePortal`s e os decora.
3. **GamePortal é genérico.** Hoje fica na porta de um prédio; depois ficará numa caverna, num portão, no boxe de uma pista. Ele não pode depender de ser um prédio.
4. **Dados de mundo moram em perfis** (a partir da Fase 7, World Profile). O que muda de um bairro/bioma para outro (cores, som, enfeite, clima, arquitetura) é dado num perfil, e não um `match` de id de categoria espalhado pelo código.
5. **Sistemas não dependem da plataforma.** Eles perguntam "qual jogo está rodando?" ou "onde está a Steam?", e só um arquivo isolado sabe se a resposta vem do registro do Windows ou do `registry.vdf` do Linux.

### GamePortal (componente-chave)
- `@export var app_id: int`
- `Area3D` de entrada (a "porta").
- `Marker3D` onde NPCs de amigos aparecem (fase 5).
- `Marker3D` de retorno: onde o jogador reaparece quando o jogo fecha.
- Ao entrar na área: inicia fade de ~1,5 s. Se o jogador sair antes, cancela. Se completar, chama `GameLauncher.launch(app_id, self)`.
- Também é alvo do raycast da câmera: ao olhar para ele, o HUD mostra o nome do jogo.

### Detalhes técnicos do Windows/Steam
- **Caminho da Steam:** registro `HKCU\Software\Valve\Steam`, valor `SteamPath`. Ler com `OS.execute("reg", ["query", ...], output)`.
- **Bibliotecas:** `<SteamPath>/steamapps/libraryfolders.vdf` lista todas as pastas de biblioteca (pode haver mais de um disco). Em cada uma, `steamapps/appmanifest_<appid>.acf` tem `appid` e `name`. Escrever um parser simples de VDF/ACF.
- **Filtrar o que não é jogo:** redistribuíveis, Proton, SteamVR, ferramentas (ex.: appid 228980). Manter uma lista de exclusão editável.
- **Abrir jogo:** `OS.shell_open("steam://rungameid/<appid>")`. **Não** passar parâmetros pela URL (a Steam mostra um aviso). Parâmetros para pular aberturas são configurados pelo usuário na própria Steam (Propriedades > Opções de inicialização).
- **Detectar jogo rodando:** valor DWORD `RunningAppID` em `HKCU\Software\Valve\Steam`. Fica igual ao appid enquanto o jogo roda e volta a 0 quando fecha. Consultar a cada ~2 s com um `Timer` enquanto um jogo estiver ativo.
  - Estados: `IDLE → LAUNCHING → RUNNING → IDLE`.
  - Se em `LAUNCHING` o valor não virar o appid em ~90 s, voltar ao hub e mostrar aviso no HUD.
- **Minimizar/restaurar:** `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)`. Enquanto minimizado, reduzir consumo (`OS.low_processor_usage_mode = true`, pausar a árvore, FPS baixo). Ao restaurar: modo de janela anterior + `DisplayServer.window_move_to_foreground()`, reposicionar o jogador no marcador de retorno do portal.
- **Segredos:** a chave da Steam Web API (fase 5) fica em `user://config.cfg`, nunca no repositório. `.gitignore` adequado para Godot.

## Fases

1. **Andar em primeira pessoa numa praça.** CharacterBody3D, mouse look, WASD, pulo, correr com Shift, Esc libera o mouse. Chão e alguns blocos como prédios. Raycast da câmera e um HUD mínimo (mira no centro).
2. **Um GamePortal funcionando com appid fixo.** Um prédio com portal. Olhar mostra o nome; entrar faz fade, abre o jogo, minimiza o hub; ao fechar o jogo, o hub volta com o jogador na porta. Implementar `GameLauncher` completo aqui.
3. **Cidade gerada da biblioteca.** `SteamLibrary` lê os jogos instalados; a cidade cria um prédio + portal por jogo numa grade de ruas. Arte na fachada: verificar primeiro o cache local da Steam (`<SteamPath>/appcache/librarycache/`, investigar a estrutura atual das pastas) e, se não achar, baixar do CDN da Steam com `HTTPRequest`; salvar em `user://cache/`. Placeholder se nada funcionar.
4. **Robustez do launcher.** Timeouts, jogo que falha ao abrir, Steam fechada, jogo aberto por fora do hub, múltiplos monitores.
5. **Amigos como NPCs.** `FriendsService` usa a Steam Web API (`ISteamUser/GetFriendList` e `ISteamUser/GetPlayerSummaries`, campo `gameid`), consultando a cada 1–2 min. Amigo jogando algo da biblioteca → NPC no marcador daquele portal. Online sem jogar → praça central. Offline → não aparece. Rótulo com o nome sobre o NPC.
6. **Organização e polimento.** Gênero via `store.steampowered.com/api/appdetails` para agrupar prédios em bairros. Áudio 3D por portal (`AudioStreamPlayer3D`). Assets CC0, sons, iluminação, HUD com horas jogadas.

As fases 1–6 (e o visual v2 que veio depois) estão prontas. **Fases 7 em diante** (World Profile, Escala, A casa, Linux) e o horizonte de longo prazo: **[docs/ROADMAP.md](docs/ROADMAP.md)**. Nada do "Horizonte" deve ser implementado sem virar fase antes.

## Como trabalhar
- Uma fase por vez. Antes de programar uma fase, apresente um plano curto e espere aprovação.
- **Fluxo:** `/model opusplan`. O Opus planeja no modo plan; o Sonnet executa. O plano aprovado de cada fase é salvo em `docs/plans/fase-N.md`, seguindo o modelo de [docs/plans/README.md](docs/plans/README.md): Contexto → Passos (com arquivos) → Verificação → Checklist de teste manual → Mensagem de commit.
- **Volte ao modo plan quando:** começar uma fase nova, surgir uma decisão de arquitetura que o plano não previa, ou o mesmo erro aparecer duas vezes seguidas.
- **Orca é opcional:** serve como painel ou para rodar trabalhadores em paralelo, quando as partes da tarefa forem independentes (cada um no seu worktree).
- Prefira criar/configurar nós por código quando isso evitar arquivos `.tscn` complexos escritos à mão; quando `.tscn` for necessário, mantenha simples.
- Se possível, valide scripts com a Godot em modo headless antes de entregar. **Antes de cada commit, rode `bash tests/run_tests.sh`** (precisa terminar com `RESULTADO GERAL: TUDO OK`). Recurso novo ganha um `tests/check_<nome>.gd` no mesmo formato: imprime `[ok]`/`[FALHOU]` e termina com `RESULTADO: TUDO OK`.
- Ao final de cada fase: resumo do que foi feito, checklist de teste manual, sugestão de mensagem de commit.
