# Game Hub — contexto do projeto

## Visão
Um "launcher" em forma de mundo 3D em primeira pessoa. O jogador caminha por uma cidade onde cada prédio representa um jogo da sua biblioteca Steam. Ao entrar no prédio, a tela escurece, o hub se minimiza e o jogo abre pela Steam. Quando o jogo fecha, o hub reaparece na porta do mesmo prédio. Amigos da Steam aparecem como NPCs na porta do prédio do jogo que estão jogando.

A cidade é a **primeira versão**. No futuro, os mesmos sistemas serão reaproveitados num mundo aberto maior (ex.: montanha de gelo com Skyrim, cidade medieval com Baldur's Gate, pista de corrida com som de motor ouvido de longe). Por isso, **sistemas e cenário devem ficar separados** desde o início.

## Sobre o dono do projeto
- Tem conhecimento **básico** de programação. Explique as decisões de forma simples e comente o código em português.
- Vai testar tudo no editor da Godot, no Windows. Sempre termine uma tarefa com um **checklist de teste manual** curto (o que abrir, o que apertar, o que deve acontecer).
- Quando algo precisar ser feito à mão no editor da Godot, dê o passo a passo.

## Stack
- **Godot 4.x** (versão estável mais recente), **GDScript** com tipagem estática (`var x: int`).
- **Windows 10**. Steam instalada.
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

**Futuro (não implementar agora):** mundo aberto com biomas por gênero, portais em pontos de referência visíveis de longe, LOD e carregamento por regiões.

## Como trabalhar
- Uma fase por vez. Antes de programar uma fase, apresente um plano curto e espere aprovação.
- Prefira criar/configurar nós por código quando isso evitar arquivos `.tscn` complexos escritos à mão; quando `.tscn` for necessário, mantenha simples.
- Se possível, valide scripts com a Godot em modo headless antes de entregar.
- Ao final de cada fase: resumo do que foi feito, checklist de teste manual, sugestão de mensagem de commit.
