# Fase 18: Mostrar para amigos

**Status:** aprovado em 2026-11-10; em andamento
**Branch:** `fase-18`, criada da `origin/main` depois do merge da Fase 17 (PR #3).

## Para o dono (até 10 linhas)
- **O que você vai ver quando a fase acabar:** uma página de Release no GitHub com um `.zip`. O amigo baixa, descompacta, abre o `GameHub.exe` e entra na casa, sem instalar a Godot e sem editar arquivo. Em Esc há um botão "Contar o que achei", que copia um resumo para ele colar para você.
- **Agora:** 18.0 a 18.5 feitas: o `.exe` abre com o ícone novo e, na primeira vez, a porta da casa diz o que está acontecendo (buscando, baixando capas, ou por que a cidade está vazia). A próxima é a 18.6 (o pacote: LEIA-ME, licenças e zip).
- **Ordem:** PR da Fase 17 → o build que abre de verdade → o primeiro uso de um PC "limpo" → amigos sem chave → o botão de feedback → o zip e o Release → os amigos usam.
- **Para testar:** cada subetapa traz o próprio checklist; a 18.2 já entrega um `.exe` para você abrir.
- **Decisões já tomadas (2026-11-09):** PR da 17 no GitHub primeiro; entrega por Release no GitHub; feedback por botão que copia um resumo; a chave é opcional e o hub não cobra.
- **Decisões que esperam você:** pedir a publicação do Release (18.7). O ícone foi decidido em 2026-11-10: o símbolo do brand kit.

## Contexto
É a fase [2. Mostrar para amigos](../ROADMAP.md#2-mostrar-para-amigos), a etapa 2 do produto: 2 ou 3 amigos instalam e usam. Hoje só o dono usa o hub, sempre pelo editor, com o cache cheio e a chave configurada. O amigo vai encontrar o contrário: um `.exe`, cache vazio, sem chave, outra placa de vídeo.

O que já existe (exploração de 2026-11-09):
- **Export:** `export_presets.cfg` tem os presets Windows e Linux (`build/windows/GameHub.exe`, sem `embed_pck`), e o CI (`.github/workflows/testes.yml`, job `exportar`) exporta os dois a cada push em `fase-*`. Há um build local de 24/10 (exe 109 MB + pck 46 MB) que **ninguém abriu como usuário**. A branch `guitavaress/check-export` (worktree do Orca) tem um `tests/check_export_presets.gd` pronto e não juntado.
- **Primeiro uso:** o `AppConfig` cria o `config.cfg` sozinho; a chave entra por Esc › Amigos (`ui/settings_view.gd`); `city.gd` (`_show_startup_messages`) já avisa "Não encontrei a Steam" e "Nenhum jogo instalado"; `ui/controls_hint.gd` mostra o cartão da primeira vez.
- **Sem chave:** o `friends_service.gd` (`_start`) manda o aviso "Amigos desligados" ao HUD a cada abertura; o mural (`worlds/home/friends_wall.gd`) diz só "Configure os amigos em Esc › Amigos".
- **Faltas:** não há versão nem ícone no `project.godot`; os `LICENSE` dos assets não vão no export (não são recursos); `game-hub-brand-kit/` (não rastreado, sem `.gdignore`) entra num export local; o `user://` do `.exe` é o mesmo do editor (mesmo nome de projeto), então no PC do dono o build nunca parece "limpo".

## Pronto quando
- Um amigo baixa o zip do Release, abre o hub sem ajuda, abre um jogo pela porta ou pela estante e manda o resumo do botão. (É o "Pronto quando" do ROADMAP.)
- O `.exe` exportado abre, monta a cidade e abre um jogo de verdade no desktop, partindo de um `user://` vazio.
- Sem chave, nenhuma mensagem de erro ou cobrança aparece; o mural explica como ligar os amigos.
- O zip traz o LEIA-ME e as licenças, e não traz nada pessoal (nem `config.cfg`, nem chave, nem capas, nem `docs/`, `tests/`, `tools/`, `painel/`, brand kit).
- Desempenho no desktop, Alta: o `.exe` não fica abaixo do editor na medida da Fase 17 (144,8 FPS na caminhada, p99 13 ms).

## Decisões de arquitetura
- **Zip, não instalador.** `GameHub.exe` + `GameHub.pck` + `LEIA-ME.txt` + `licencas/`, sem `embed_pck` (um exe com o pck embutido dispara mais antivírus).
  Descartado: instalador (Inno Setup seria ferramenta nova, e o fluxo está congelado) e assinatura de código (custa; o LEIA-ME explica o aviso do SmartScreen).
- **Um script refazível monta o pacote:** `tools/empacotar_windows.sh` exporta, copia as licenças, confere o conteúdo e gera o zip **fora do repositório**. O Release usa o zip desse script, feito no desktop e testado à mão; o artefato do CI segue só como prova de que exporta.
- **Versão num lugar só:** `application/config/version` no `project.godot` (começa em `0.18.0`). O menu de pausa, o resumo de feedback e o nome do zip leem dali.
- **"Primeira vez" e "sem chave" são estado, não erro.** O `FriendsService` ganha um estado consultável ("falta a chave") em vez de emitir `problem` nesse caso; `problem` fica só para falha de verdade (403, 401, sem rede). O HUD não muda; o mural e a aba Amigos leem o estado. Sistemas seguem sem conhecer mundos.
- **O resumo de feedback é montado por um sistema sem tela** (`autoload/feedback_report.gd`, só funções estáticas, sem autoload novo): versão, sistema, placa de vídeo, qualidade, FPS médio, número de jogos e de bairros, se há chave (sim/não). **Nunca** entram: a chave, o SteamID, nomes de amigos, nomes de jogos, caminhos de pasta. O texto é mostrado inteiro antes de copiar. Nada é enviado pela rede.
- **Sem código de SO fora de `autoload/platform/`:** o nome da placa vem do `RenderingServer`, e "abrir a pasta de dados" usa `OS.shell_open` (já usado no projeto).
- **Testar o "PC limpo" sem perder os dados do dono:** o `user://` é fixo na Godot e é o mesmo do editor, então não dá para trocar de pasta por opção. O caminho é o script `tools/pc_limpo.ps1`, que **renomeia** a pasta `%APPDATA%\Godot\app_userdata\Game Hub` para `Game Hub.guardado` e a devolve depois (nunca apaga; recusa rodar se já houver uma guardada). É uma ação nos dados do dono: o script só roda quando ele pedir.

## Subetapas
Trilha A (Claude, checkout principal). Trilha B (Codex, worktree próprio) só na 18.5, em paralelo com a 18.3/18.4. Uma Godot por vez.

- [x] **18.0 PR da Fase 17, branch e plano** (só de docs + merge · sessão do coordenador · medium) — 2026-11-10; o teste de export veio em `39fe623`, `1217eac` e `bc0e765`; o plano, no commit `Docs: plano da Fase 18`
  - Faz: bateria completa na `fase-17`; push da `fase-17` e PR #3 (pedido pelo dono em 2026-11-09); o dono aprova e junta. Depois: `fase-18` criada da `origin/main`, este plano, ROADMAP (Fase 17 feita; a fase 2 ganha "é a Fase 18") e `Início.md` (linha do tempo: 17 `done`, 18 `active`).
  - Limpeza: juntar o `tests/check_export_presets.gd` da `guitavaress/check-export` (cherry-pick dos 3 commits) e apagar esse worktree e o `guitavaress/gh-smoke-1` pelo roteiro do AGENTS.md.
  - Antes do push: `git status` e o diff conferidos (sem `config.cfg`, sem chave, sem capturas). Os arquivos não rastreados (`.agents/`, `.vscode/`, `game-hub-brand-kit/`, `saida.txt`, `game_hub_paperclip_omniroute.md`) **não** entram.
  - Commit: `Docs: plano da Fase 18 (Mostrar para amigos)`
- [x] **18.1 Versão e higiene do export** (tamanho: pequena · quem: Sonnet, subagente · esforço: medium) — `ce52743`, 2026-11-10; testes `check_export_presets check_pause_menu check_settings_view check_menu_keyboard` ok; o `painel/` já fica fora por ter `.gdignore`
  - Faz: `config/version="0.18.0"`; a versão aparece no rodapé do menu de pausa; `game-hub-brand-kit/` e `.agents/` fora do export (entrada no `exclude_filter` dos dois presets, e não um `.gdignore` numa pasta não rastreada); o `check_export_presets` passa a conferir esses filtros e a versão.
  - Arquivos: `project.godot`, `export_presets.cfg`, `ui/pause_menu.gd`, `tests/check_export_presets.gd`, `tests/check_pause_menu.gd`.
  - Teste: `check_export_presets check_pause_menu check_settings_view`. Captura do menu de pausa.
  - Manual: Esc mostra "Game Hub 0.18.0" no rodapé.
  - Commit: `Fase 18.1: versao do hub e export sem sobras`
- [x] **18.2 O `.exe` que abre de verdade** (tamanho: grande · quem: Opus, sessão nova · esforço: high · revisão: o dono, abrindo o build) — `1ec6eba`, 2026-11-10; bateria completa ok. O `.exe` abre na casa e monta a cidade com o log limpo; abrir um jogo pelo `.exe` e o F3 ficam no checklist do dono
  - Faz: exporta no desktop e roda o `.exe` como usuário; corrige o que só quebra fora do editor. Suspeitos já achados: `autoload/platform/omarchy_binds.gd` (`globalize_path("res://...lua")` não existe num pck; só Linux, mas tem que falhar calado), `autoload/platform/app_compositor.gd` (a extensão em `native/`, excluída do export), o `DebugMenu` (F3) num build de release, o título da janela e o log em arquivo (`debug/file_logging`, ligado, em `user://logs/`).
  - Conferir no pck (achado da 18.1): `.claude/` (tem `settings.local.json`), `.codex/`, `.vscode/` e `build/` estão na raiz sem `.gdignore` e fora do `exclude_filter`. A Godot costuma pular pastas que começam com ponto, mas um `.json` vira recurso; se algum aparecer no pck, entra no filtro (e no `check_export_presets`).
  - Ícone: o da janela e da barra de tarefas (`config/icon`). **Decisão do dono:** um ícone simples feito por código/SVG nesta subetapa, ou o símbolo do brand kit (estudo não aprovado). O ícone do `.exe` no Explorer fica de fora se exigir o `rcedit` (ferramenta nova).
  - Arquivos: `tools/empacotar_windows.sh` (novo: só a parte de exportar, nesta subetapa), `tests/check_exported_build.gd` (novo: confere no pck, com `--main-pack`, que as cenas e os autoloads carregam e que `tests/`, `tools/` e `docs/` não estão lá; pula se não houver build), mais os consertos.
  - Teste: bateria completa; o `.exe` abre, a cidade monta, um jogo abre e o hub volta; `tools/medir_desempenho.gd` no editor comparado com o FPS do F3 no build.
  - Manual: o dono abre `build/windows/GameHub.exe`.
  - Commit: `Fase 18.2: o build do Windows abre e joga`
- [x] **18.3 O primeiro uso num PC limpo** (commit `00c1811`) (tamanho: grande · quem: Opus · esforço: high · revisão: Astra, `/codex:review`, porque mexe em dado salvo e no caminho de partida de todos os sistemas)
  - Faz: roda o build com o `user://` vazio (script `tools/pc_limpo.ps1`, com o pedido do dono) e conserta o que aparecer. O que já se sabe que precisa:
    - a primeira montagem, com o `StoreInfo` e o `GameArt` baixando tudo: a casa diz o que está acontecendo ("Buscando as capas… N de M") em vez de parecer travada;
    - sem internet na primeira vez: a cidade monta com todos em "Outros" e sem capas, com um aviso só;
    - sem Steam e sem jogos: os avisos do `_show_startup_messages` passam a ficar também na porta da casa (quem não leu o aviso de 10 s entende por que a cidade está vazia);
    - PC fraco: se o FPS médio dos primeiros 20 s na cidade ficar abaixo de 30 na Alta, um aviso único sugere "Esc › Qualidade › Leve" (grava em `[ui]` que já avisou). Sem trocar sozinho.
  - Arquivos: `worlds/city/city.gd`, `worlds/home/home.gd` (o texto da porta), `autoload/store_info.gd` / `autoload/game_art.gd` (só expor o progresso, se ainda não expõem), `autoload/app_config.gd` (`[ui] seen_quality_hint`), `ui/hud.gd`, `tools/pc_limpo.ps1` (novo), `tests/check_first_run.gd` (novo: sem cache, biblioteca falsa, Steam ausente e vazia; estende o que o `check_first_time` já cobre).
  - Teste: bateria completa; capturas da casa na primeira abertura (fora do repositório).
  - Commit: `Fase 18.3: a primeira abertura explica o que acontece`
  - **Feito (2026-11-10):** a placa da porta (Label3D na `TravelDoor` da frente) mostra "Buscando capas e categorias… N de M", depois "Baixando as capas… N de M", e some no fim; com a cidade vazia, diz o motivo e fica. `StoreInfo.get_progress()`, `GameArt.get_download_progress()` e `is_downloading()`. O aviso do PC fraco cita "Esc › Som e vídeo › Qualidade" (o caminho real do menu).
    - **Bug achado:** o `GameArt` anotava `.none` (7 dias sem tentar) também quando a rede nem conectava: o amigo que abrisse sem internet ficaria uma semana sem capas. Agora só anota quando a loja respondeu sem a imagem.
    - **Decisões:** `StoreInfo.api_url` virou variável, para o teste simular "sem internet" sem mexer na rede; o "sem internet" de verdade ficou só no teste (bloquear o `.exe` no firewall pede administrador). `tests/README.md` ganhou as armadilhas do teste novo.
    - **Teste no `.exe` com a pasta vazia (com internet):** a abertura mostra "Buscando capas e categorias…", a casa abre com as capas na estante, o cartão de controles e um aviso só ("Amigos desligados"). A loja e as capas chegaram durante a abertura; as placas foram conferidas em captura própria. Os dados do dono voltaram (`pc_limpo.ps1 devolver`).
    - **Revisão (Astra, `/codex:review`):** dois achados aceitos: o `pc_limpo.ps1` passa a recusar também o hub rodado pelo F5 do editor (`--remote-debug`); o `check_first_run` usa um caminho falso da Steam numa máquina sem Steam (o CI), para os cenários com jogos.
- [x] **18.4 Amigos sem chave, sem cobrança** (commit `71c3138`, 2026-11-10) (tamanho: pequena · quem: Sonnet, subagente · esforço: medium)
  - Faz: sem chave, o `FriendsService` não emite `problem` (ganha `needs_key()`); o HUD fica quieto. O mural da casa vira o convite: "Veja seus amigos aqui" e os 3 passos (abrir a página da chave, colar em Esc › Amigos, salvar), e E no mural abre a pausa já na aba Amigos. A aba Amigos numera os mesmos passos. Chave inválida e lista privada continuam avisando.
  - Arquivos: `autoload/friends_service.gd`, `worlds/home/friends_wall.gd`, `ui/settings_view.gd`, `ui/pause_menu.gd` (abrir numa aba), `tests/check_phase5.gd`, `tests/check_friends_wall.gd`, `tests/check_settings_view.gd`.
  - Teste: os três acima mais `check_first_time check_pause_menu`. Captura do mural e da aba.
  - Commit: `Fase 18.4: sem chave, o mural convida em vez de cobrar`
- [x] **18.5 O botão "Contar o que achei"** (tamanho: pequena · quem: Sol, trilha B · esforço: medium · worktree `worktree/feedback`, criado da `fase-18` depois da 18.2)
  - Faz: `FeedbackReport.build(respostas)` monta o texto; a tela (`ui/feedback_view.gd`) tem 3 perguntas ("O que você achou?", "O que travou ou confundiu?", "Voltaria a abrir?" com Sim/Talvez/Não), mostra o resumo técnico inteiro e o botão "Copiar" (`DisplayServer.clipboard_set`), com a frase "Cole para quem te mandou o hub". Navegável por teclado e controle.
  - Arquivos da B: `autoload/feedback_report.gd` (novo), `ui/feedback_view.gd` (novo), `tests/check_feedback.gd` (novo: o texto nunca contém a chave, o SteamID, um nome de jogo ou um caminho com o nome do usuário, mesmo com eles configurados; foco por teclado). **A A integra:** o botão no rodapé de `ui/pause_menu.gd` e o `check_pause_menu`.
  - Teste: `check_feedback check_pause_menu check_menu_keyboard check_gamepad check_platform`. Captura da tela.
  - Commit: `Fase 18.5: contar o que achei` (B: `3775d91`, `ec1810a`; merge `d37b397`) e `Fase 18.5: o botao no menu de pausa` (A: `9e1a061`)
- [ ] **18.6 O pacote: LEIA-ME, licenças e zip** (tamanho: grande · quem: Opus · esforço: high · revisão: Astra, `/codex:adversarial-review`, porque é o que sai do PC do dono para o dos outros)
  - Faz: o `empacotar_windows.sh` passa a montar a pasta `GameHub-<versão>-windows/` com o exe, o pck, o `LEIA-ME.txt` (o que é; requisitos: Windows 10/11, Steam, placa com Vulkan; como abrir e o aviso do SmartScreen; os controles; amigos opcionais; onde ficam os dados e como apagar; como contar o que achou) e `licencas/` (o `LICENSE` do projeto, os dos assets CC0, a OFL da Barlow, MIT do Debug Menu e do Sky3D, a licença da Godot). O script **recusa** gerar o zip se achar no pacote um `config.cfg`, um texto de 32 hex ao lado de `web_api_key`, imagens de capa, ou as pastas `tests`, `tools`, `docs`, `painel`, `native`. O zip sai em `C:\Projetos\game-hub-builds\` (fora do repositório).
  - Arquivos: `tools/empacotar_windows.sh`, `tools/pacote/LEIA-ME.txt` (novo, o modelo), `tests/check_package.gd` (novo: confere a lista de licenças contra `assets/*/LICENSE*` e `addons/*/LICENSE*`, para nenhuma ficar de fora), `README.md` (seção "Baixar e jogar", antes de "Como rodar").
  - Teste: bateria completa; descompactar o zip numa pasta nova, abrir e jogar; conferir o tamanho.
  - Commit: `Fase 18.6: o pacote do Windows com LEIA-ME e licencas`
- [ ] **18.7 Release e os amigos** (só de docs + publicação · Opus e o dono · medium)
  - Faz: bateria completa, PR da `fase-18` e merge (dono). Tag `v0.18.0` e o Release no GitHub com o zip e as notas (o texto do LEIA-ME resumido), **só quando o dono pedir**. O dono manda o link a 2 ou 3 amigos.
  - Registro: este plano ganha a seção "O que os amigos disseram" (os resumos colados, sem nome de ninguém; o repositório é público). O que virar ideia vai para `docs/ideias/`; o que for defeito vira uma 18.8 curta.
  - Fecha a fase: README (linha 18 na tabela), ROADMAP (fase feita, "Etapa 2" do produto), `Início.md`.
  - Commit: `Docs: fechamento da Fase 18`

## Riscos
- **O build quebra onde o editor não quebra** (caminho `res://` num pck, extensão ausente). Percebemos na 18.2, que por isso vem antes de qualquer acabamento.
- **Antivírus ou SmartScreen barra o `.exe` sem assinatura.** O LEIA-ME explica "Mais informações › Executar assim mesmo". Se um amigo não conseguir abrir, isso volta ao modo plano (assinatura ou outro formato).
- **A placa do amigo não tem Vulkan.** A 18.2 confere qual mensagem aparece, e o LEIA-ME diz o requisito.
- **Um amigo com 3 jogos vê uma cidade vazia.** Fica como achado de feedback (a ideia [instalar-jogos-pelo-hub](../ideias/instalar-jogos-pelo-hub.md) e a fase de biomas tratam disso), não como trabalho desta fase.
- **Vazamento no pacote ou no resumo.** Dois testes dedicados (`check_package`, `check_feedback`) e a revisão adversarial da 18.6.
- **Cota do ChatGPT Plus.** Só a 18.5 e duas revisões usam o Codex. Se acabar, o Sonnet faz a 18.5 na trilha A.

## Fora do escopo
- Build de Linux para amigos, instalador, atualização automática e assinatura de código.
- GodotSteam (amigos sem chave): segue no Horizonte da ROADMAP.
- Esconder um jogo ou trocar o bairro dele pela tela (hoje só no `config.cfg`): vira ideia em `docs/ideias/` se o feedback pedir.
- Telemetria ou envio automático de feedback: nada sai do PC do amigo sem ele copiar e colar.
- Perfis do usuário (Parados) e a visita aos amigos (a próxima fase).

## Decisões tomadas durante a fase
- 2026-11-10 (18.2): o que só quebrava no `.exe` e o que mudou.
  - **Capas sem compressão no build.** O template de export não tem o compressor S3TC (só o editor tem): cada capa dava um `ERROR` no log. O `GameArt.can_compress()` (falso quando `OS.has_feature("template")`) pula a compressão lá. As capas funcionam igual, mas gastam mais memória de vídeo no `.exe` do que no editor (os números do `medir_desempenho` com `--main-pack` não mostram isso, porque o editor comprime). Se um amigo com placa fraca reclamar, a saída é comprimir as capas para o cache já no formato da placa, e isso é fase própria.
  - **Sobras no pck:** `res://.mcp.json` e `res://opencode.json` entravam (são `.json` na raiz). Saíram pelo `exclude_filter` dos dois presets, junto com `.claude/*`, `.codex/*`, `.vscode/*` e `build/*` por garantia (essas não apareciam). O `.lua` do `OmarchyBinds` não vai no pck (não é recurso): no build ele devolve vazio sem chamar o `lua`. O `AppCompositor` já desistia calado (só Linux e só com o `.so`).
  - **Ícone:** o símbolo flat do brand kit, copiado para `assets/brand/icone.svg` (arte do projeto, MIT). A Godot 4.7 troca o ícone do `.exe` sozinha com `modify_resources` (sem `rcedit`), então o ícone aparece também no Explorer. No fundo escuro, a casa azul-marinho fica discreta e a porta ciano é o que se vê.
  - **O DebugMenu (F3) fica no build:** é como o dono mede o FPS no `.exe`. O log em arquivo (`user://logs/`) também fica: é o que um amigo pode mandar se algo quebrar.
  - **Desempenho (desktop, Alta, 200 jogos, 22 h, 2560 × 1440, 165 Hz):** editor 151,0 FPS na caminhada (p99 12 ms); o pck exportado, rodado com `--main-pack`, 152,1 FPS (p99 12 ms). Casa 165, espelho 165, montanha 162,6 nos dois. O `.exe` de release ignora `-s`, por isso o motor exato do `.exe` se confere pelo F3 (checklist).
- 2026-11-10 (18.0): a bateria da `fase-17` falhava de vez em quando, em testes diferentes a cada rodada. Duas correções entraram na Fase 17 antes do PR (`5bc17ea`): sem janela, os modelos do mirante carregam na hora (o carregamento em segundo plano às vezes deixava uma malha vazia no servidor de desenho dos testes), e o `check_home_start` espera a tela de abertura sumir (até 3 s) em vez de 0,5 s fixos. A segunda não teve a causa confirmada: se o teste voltar a falhar em "tela clara, HUD de volta, jogador anda", olhar qual das quatro condições falhou.
- 2026-11-10 (18.0): limpeza feita. O worktree e a branch `guitavaress/check-export` (já juntada aqui) e a branch `guitavaress/gh-smoke-1` (sem commits próprios) foram apagados.
- 2026-11-09: PR da Fase 17 no GitHub antes da branch; entrega por Release no GitHub; feedback por botão que copia um resumo; a chave é opcional e o hub não cobra (planejamento, respostas do dono).

## Checklist de teste manual (fim da fase)
1. `bash tests/run_tests.sh` até `RESULTADO GERAL: TUDO OK`.
2. `bash tools/empacotar_windows.sh`: gera o zip em `C:\Projetos\game-hub-builds\` e imprime "pacote conferido".
3. Com o seu pedido, `tools/pc_limpo.ps1 guardar`; descompacte o zip numa pasta nova e abra o `GameHub.exe`.
   - A casa aparece, a porta mostra o progresso e destranca; nenhum aviso sobre amigos.
   - O mural mostra os 3 passos; E nele abre Esc › Amigos.
   - Abra um jogo pela estante: o hub some, o jogo abre, e ao fechar o hub volta.
   - Esc › "Contar o que achei" › responda › Copiar › cole no Bloco de Notas: sem chave, sem ID, sem nomes.
4. `tools/pc_limpo.ps1 devolver`: os seus dados voltam.
5. F3 no build, na caminhada da praça, Alta: perto de 144 FPS.
