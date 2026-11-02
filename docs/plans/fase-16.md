# Fase 16: Leitura

**Status:** aprovado em 2026-11-02; em andamento
**Branch:** `fase-16`, criada da ponta da `fase-15` (`234c37e`). A `main` já tem o bioma (`fa6870e`); a `fase-15` só soma os 8 commits de docs da revisão, que entram na `main` junto com esta fase.

## Para o dono (até 10 linhas)
- **O que você vai ver:** capas inteiras na estante; o nome do arco do RPG legível dos dois lados; aviso e título do bairro em lugares separados, e o HUD some quando você abre a busca, o mapa ou o metrô; a praça sem parede de nomes; e textos que dizem a verdade: "solte E" na estante, "Esc › Amigos" no mural, estações com o lugar, legenda no mapa e a mesa do Windows sem jargão.
- **Agora:** 16.1 e 16.2 aprovadas; 16.3, 16.4 e 16.6 juntadas. 16.4 aprovada; a 16.5 espera a sua aprovação; depois vem o fechamento (16.7).
- **Para testar:** cada subetapa traz o próprio checklist; o completo fica no fim.
- **Decisões que esperam você:** nenhuma. As escolhas de texto e de distância estão em "Decisões de arquitetura".

## Contexto
É o bloco curto da [revisão de design de 2026-11-02](../design/revisao-2026-11-02.md#próximo-passo) (itens A1–A5, B1, B2 e C3 pequeno), primeira fase da [ROADMAP nova](../ROADMAP.md#1-leitura). Nada de luz, modelos ou pórticos (são da fase "O momento uau" ou depois). Tudo é correção localizada de UI, texto e de duas cascas 3D, sem tocar em Steam, lançamento ou plataforma.

## Pronto quando
Os quatro resultados da tabela "Próximo passo" da revisão aparecem nas capturas (fora do repositório) e no seu teste:
1. **Estante e arco:** capas inteiras; o nome do arco não aparece ao contrário por trás.
2. **Topo e painéis:** aviso e título nunca se cruzam; painel aberto sem cartão da porta nem HUD por trás; o título cede durante a carga.
3. **Praça legível:** hologramas presentes, sem parede de nomes.
4. **Textos que orientam:** "solte E" na estante, "Esc › Amigos" no mural, estações com lugar, legenda no mapa, mesa indisponível sem jargão.

## Decisões de arquitetura
- **Capa numa face própria (A1):** a caixa (`BoxMesh`) fica com cor escura e a capa vai num `QuadMesh` na frente, inteira. Se a capa ainda for a horizontal (`header.jpg`, até chegar a HD), o quad encolhe para a proporção dela, centrado, em vez de esticar. Descartado: UV próprio no `BoxMesh` (mais código, mesmo resultado).
- **Arco com verso (A4):** dois `Label3D` com `double_sided = false`, um de cada lado (o de trás girado 180°), para ler certo pelos dois lados. Só o `ArchShell` muda; o `GamePortal` não sabe. Os outros `Label3D` sem a flag não mudam às cegas (a revisão pede conferir um a um; ficam fora).
- **Topo com dois lugares (A2):** os avisos ficam no topo (onde estão). O título do bairro desce para uma faixa própria, abaixo do espaço máximo da pilha de avisos (3 avisos), calculada pelas constantes do HUD e não por número solto.
- **HUD some com painel aberto (A2):** o `player.gd` passa a ter **um só lugar** que decide se o HUD aparece: `não intro e não foco e não painel aberto` (hoje `start_intro`, `finish_intro`, `focus_on` e `_end_focus` mexem em `_hud.visible` direto). Os quatro painéis (busca, mapa, metrô, pausa) já emitem `opened`/`closed`; o player só escuta. Os avisos que chegarem nesse tempo já esperam na fila (`hud.gd`, `_waiting_messages`).
- **Título cede à carga (A2):** o `DistrictTitle` não aparece (e some rápido, se já estiver na tela) enquanto `ScreenFade.door_charge.visible`. Lê o autoload, sem sinal novo.
- **Nomes dos hologramas (A3), tirando código:** o rótulo do amigo só aparece de perto (`LABEL_MAX_DISTANCE` de 20 m para ~5 m, com fade de distância). De longe fica o corpo; sob a mira o HUD já mostra nome e estado (`get_look_label`). Se a captura ainda mostrar nomes se cruzando de perto, aí sim "só o mais perto mostra" (decisão registrada na fase, não antes).
- **A carga recebe a instrução de quem usa (A5):** `ScreenFade.set_door_charge(...)` e `DoorCharge.set_progress(...)` ganham um parâmetro opcional `hint`; o padrão continua "recue para cancelar" (o portal não muda) e a estante passa `InputDevice.fill("solte {interact} para cancelar")`. Regra 3: a UI recebe o texto.
- **Mural:** "Configure os amigos em {menu} › Amigos", com `InputDevice.fill` (Esc no teclado, Menu no controle).
- **Metrô com lugar (B1):** o nome da estação fica só o nome do bairro (sai o "· 2"). O `detail` diz onde ela fica e o que ela atende: "perto da praça · N jogos perto" na primeira e "a ~X m da praça · N jogos perto" nas outras (N = portas mais perto dessa estação; X arredondado de 10 em 10). Tudo calculado no `city.gd` (o mundo), o `TransitStop` só recebe o texto. Descartado: direção (norte/sul), porque as estações de um bairro ficam na mesma fatia e teriam a mesma direção.
- **Mapa (B2):** legenda curta só no mapa grande (você, casa, metrô, torre, trilha), desenhada com as mesmas funções de símbolo do `MapView` para não divergir; os nomes passam a ser desenhados por último (o "Praça" deixa de ficar coberto) e a trilha ganha o nome "Trilha do Mirante" no mapa grande.
- **Mesa no Windows (C3 pequeno):** com `available == false`, a tela mostra "SÓ NO LINUX" no lugar de "SEM SINAL", e o detalhe (tela e cartão) vira "Esta mesa funciona no hub no Linux. No Windows ela fica desligada." A disponibilidade segue vindo de `AppSessions.is_supported()`; nada de detectar Windows no mundo (regra 5).

## Subetapas
Trilha A (Claude, checkout principal) e trilha B (Codex, worktree `worktree/leitura-b`, só os arquivos listados). Se a cota do ChatGPT acabar, o Sonnet faz as da B na trilha A.

- [x] **16.0 Plano** (só de docs · Opus) — este arquivo em `docs/plans/fase-16.md`; `Início.md` aponta para ele. Commit: `Docs: plano da Fase 16 (Leitura)`
- [x] **16.1 Estante e arco** (pequena + captura · trilha A, Sonnet subagente · medium)
  - Arquivos: `worlds/home/library_shelf.gd` (`ShelfBox`: caixa escura + quad da capa; `show_art`), `components/portal_shell/arch_shell.gd` (nome + verso).
  - Teste: `check_shelf` (o quad existe, tem a textura, a caixa não; proporção da capa horizontal), `check_portal_shell` (dois rótulos, `double_sided = false`, verso girado). Rodar `check_shelf check_portal_shell check_portal_regression`.
  - Captura: estante de dia e de noite; arco do RPG pela frente e por trás.
  - Commit: `Fase 16.1: capas inteiras na estante e nome do arco dos dois lados`
- [x] **16.2 Topo e painéis** (`1f4f068`) (grande, sem revisão cruzada · trilha A, Opus · high) — grande porque mexe no `player.gd`, que tudo usa; roda a bateria completa.
  - Arquivos: `ui/district_title.gd` (faixa própria; cede à carga), `ui/hud.gd` (expõe a altura máxima da pilha de avisos), `player/player.gd` (`_update_hud_visibility()` único, ligado aos `opened`/`closed` dos painéis).
  - Teste: `check_district_title` (retângulo do título não cruza o da pilha cheia; não aparece com carga), um caso novo em `check_search` ou `check_toasts` (abre busca → HUD escondido; fecha → volta; intro e foco continuam escondendo). Depois a bateria completa.
  - Captura: aviso + título juntos; busca, mapa e metrô abertos; carga na porta.
  - Commit: `Fase 16.2: aviso e título em lugares próprios; HUD some com painel aberto`
- [x] **16.3 Praça legível** (`f4c4cc5`, merge `f420805`) (pequena + captura · trilha B, Sol · medium)
  - Arquivo: `components/friend_npc/friend_npc.gd` (distância do rótulo e fade).
  - Teste: `check_holograms check_phase5 check_avatar`.
  - Captura: chegada à praça às 13 h e às 22 h, com a biblioteca falsa e amigos falsos.
  - Commit: `Fase 16.3: nomes dos hologramas só de perto`
- [x] **16.4 Instruções certas** (`86a82aa`, merge `6b8152a`, constante `d50d24d`) (pequena · trilha B, Sol · medium, worktree `worktree/leitura-b2` saído da `fase-16`) — depois da 16.1 (mesmo arquivo da estante).
  - Arquivos: `ui/door_charge.gd` e `ui/screen_fade.gd` (`hint` opcional), `worlds/home/library_shelf.gd` (passa "solte {interact}"), `worlds/home/friends_wall.gd` (texto do mural), `components/desk_monitor_3d/desk_monitor_3d.gd` e `desk_monitor_view.gd` (estado indisponível).
  - Teste: `check_door_charge check_shelf check_friends_wall check_desk_monitors check_computer_desk check_theme check_transitions check_pause_menu` (o `check_desk_monitors:102` espera "SEM SINAL": manter para disponível, novo caso para indisponível).
  - Captura: carga na estante; mural vazio; mesa no Windows.
  - Commit: `Fase 16.4: instruções certas na estante, no mural e na mesa`
- [x] **16.5 Metrô com lugar** (`89b1658`) (pequena · trilha A, Sonnet subagente · medium)
  - Arquivo: `worlds/city/city.gd` (`_build_metro`/`_add_metro_stop`, ~563–650: nome e `detail`).
  - Teste: `check_metro check_fast_travel check_city_map` (nomes sem "· N"; `detail` com "praça"; soma dos "jogos perto" = total do bairro).
  - Captura: painel do metrô no RPG (o bairro com mais estações).
  - Commit: `Fase 16.5: estações do metrô dizem onde ficam`
- [x] **16.6 Legenda do mapa** (`ede7e4c`, `ff0c55b`, merge `f420805`) (pequena + captura · trilha B, Sol · medium)
  - Arquivos: `ui/map_view.gd` (nomes por último; nome da trilha; funções de símbolo reaproveitáveis), `ui/world_map.gd` (legenda).
  - Teste: `check_city_map check_planta check_minimap` (legenda só no mapa grande; minimapa igual).
  - Captura: mapa (M) aberto na praça.
  - Commit: `Fase 16.6: legenda e nomes legíveis no mapa`
- [ ] **16.7 Fechamento** (Opus coordena; docs pelo Haiku, conferidos) — merge da trilha B (diff lido pelo Opus), bateria completa até `TUDO OK`, as capturas dos quatro resultados, README (o que mudou), ROADMAP (Leitura em "Feito", com a fase 16) e `Início.md`. Merge na `main` só quando você pedir.

## Riscos
- **HUD que não volta** depois de fechar um painel, ou que reaparece na intro: a regra única e o teste de abrir/fechar cada painel pegam cedo.
- **Título baixo demais** atrapalha a mira: conferir na captura em 1600×900 e 2560×1440.
- **Rótulo dos amigos curto demais** some antes de você chegar perto: a mira cobre, mas conferir jogando.
- **Trilha B e A no mesmo arquivo:** a B só toca `friend_npc.gd`, `map_view.gd` e `world_map.gd`; nada disso a A mexe nesta fase.

## Fora do escopo
- Luz e contraste (C1, C2): fase "O momento uau". Pórticos e limiar do arco (B3, B5), letreiros (B4), vitrines (C4), abertura dos painéis (D-T1), seção E (jargão do Sky3D, fonte dos títulos 3D, busca fora de ordem) e o borrão da pausa: ficam na revisão, para depois.
- Funções novas nos monitores da mesa (C3 médio): parado com o V5.
- Os outros `Label3D` sem `double_sided = false`.

## Decisões tomadas durante a fase
- 2026-11-02: plano aprovado pelo dono como está (16.0).
- 2026-11-02 (16.1): a captura mostrou a 2ª linha do nome do arco atrás da placa (o rótulo era centrado na vertical). Os dois rótulos passam a ser ancorados por baixo (`VERTICAL_ALIGNMENT_BOTTOM`): o nome cresce para cima.
- 2026-11-02: o dono aprovou a 16.1. A trilha B entregou a 16.3 (`f4c4cc5`) e a 16.6 (`ede7e4c`, `ff0c55b`, revisadas pelo Opus: legenda com as cores do mapa e nome da trilha vindo dos dados) na `worktree/leitura-b`; o merge e as capturas ficam com a A.
- 2026-11-02: a 16.4 passa da trilha A para a B (Sol), por decisão do dono, para usar a cota do ChatGPT enquanto a A faz a 16.2. Os arquivos das duas não se cruzam. Como a 16.4 precisa da estante da 16.1, ela sai de um worktree novo (`worktree/leitura-b2`) criado da `fase-16`.
- 2026-11-02 (merge da B, `f420805`): testes da 16.3 e da 16.6 ok; capturas da praça às 13 h e às 22 h (12 amigos falsos) sem parede de nomes: de longe só os corpos, de perto só o nome do mais próximo, sem nomes cruzados. O "só o mais perto mostra" não é necessário. O mapa (M) mostra a legenda, "Praça" e "Trilha do Mirante"; a bússola e o minimapa ainda aparecem por trás (é a 16.2).
- 2026-11-02: a bateria completa da 16.2 vale também para o merge da `worktree/leitura-b` (feito no começo da 16.2, com os testes de cada subetapa e as capturas).

- 2026-11-02 (16.2): a captura com a faixa abaixo da pilha **cheia** (3 avisos) pôs o "24 jogos" em cima da mira (o risco previsto). A faixa passa a ficar abaixo do espaço de **2** avisos comuns (`Hud.TITLE_BAND_TOASTS`); um 3º aviso, ou avisos longos, fazem o título ceder a vez pelo mesmo caminho da carga (não aparece, ou some em 0,15 s). Nunca se cruzam, e o título fica ~80 px acima da mira (720 de altura de referência).
- 2026-11-02 (16.2): a altura de um aviso comum sai do tema (`Toast.nominal_height()`, em `ui/toast.gd`, arquivo fora da lista original), e não de número solto. A pilha é medida pelo tamanho já arrumado: no quadro em que um aviso entra, o mínimo dele ainda é provisório (centenas de px).
- 2026-11-02 (16.2): as capturas saíram em 2560×1440 (a janela não aceita 1600×900 pelo script); a UI escala com a janela (`canvas_items`), então 1600×900 fica igual em proporção.
- 2026-11-02: o dono aprovou a 16.2. Padrão novo: sessões finalizadas do Orca são fechadas antes de abrir as novas (AGENTS.md).
- 2026-11-02 (merge da `worktree/leitura-b2`, `6b8152a`): a frase "recue para cancelar" estava escrita duas vezes; ficou só em `DoorCharge.DEFAULT_HINT`, e o `ScreenFade` usa a constante (`d50d24d`). Testes da 16.4 ok; capturas: a carga na estante diz "solte E para cancelar", o mural vazio diz "Configure os amigos em Esc › Amigos" e a mesa no Windows mostra "SÓ NO LINUX" nos três monitores e no cartão, sem "compositor". Worktree e branch `leitura-b2` apagados.
- 2026-11-02: o dono aprovou a 16.4.
- 2026-11-02 (16.5, `89b1658`): a distância "a ~X m da praça" é em linha reta até a Central, de 10 em 10 m; os "N jogos perto" usam a mesma medida pelas ruas da criação das estações. O `detail` é escrito depois que todas as estações do bairro existem, então o comentário do `TransitStop` passou a dizer que ele pode vir depois (só o painel lê, ao abrir); o contrato não mudou. Testes ok; captura do painel na Central (200 jogos falsos): as 3 do RPG "perto da praça · 16", "a ~150 m · 18" e "a ~120 m · 23". A ordem no painel é a de criação (não a distância).

## Checklist de teste manual (fim da fase)
1. Abra o hub no Windows. Na casa, olhe a estante: cada caixa mostra a capa inteira.
2. Segure E numa capa e leia a frase: "solte E para cancelar". Solte: a carga some.
3. Olhe o mural sem amigos (ou com "Mostrar amigos" desligado): diz "Esc › Amigos". Olhe a mesa: "SÓ NO LINUX", sem a palavra "compositor".
4. Saia para a praça. Os hologramas estão lá; o nome só aparece quando você chega perto ou mira.
5. Entre num bairro logo depois de um aviso: título e aviso não se cruzam.
6. Aperte Tab, depois M, depois pise numa estação: com cada painel aberto, a bússola, o minimapa e o cartão da porta somem; ao fechar, voltam.
7. No painel do metrô do RPG: cada estação diz "perto da praça" ou "a ~X m da praça" e quantos jogos atende.
8. No mapa (M): legenda no canto, "Praça" legível, "Trilha do Mirante" escrita.
9. No RPG, segure E num arco: o título do bairro não cai em cima da carga. Dê a volta no arco: o nome lê certo por trás.
