# Fase 8: Escala

**Status:** aprovado (2026-10-05)
**Branch:** `fase-8`, criada a partir de `fase-7`. A cadeia é `main` ← `fase-linux` (PR #1) ← `fase-7` ← `fase-8`. Quando cada uma entrar na `main`, a seguinte é rebaseada: `git rebase --onto main fase-7 fase-8`.

## Contexto
Hoje a biblioteca tem 7 jogos e a cidade cabe num anel em volta da praça. Com **200 jogos**, ela vira uma grade de 352 × 352 m (4 anéis), e a porta mais longe fica a 230–300 m pelas ruas: 25 a 34 s correndo. A fase faz o hub continuar gostoso nessa escala ([ROADMAP › Fase 8](../ROADMAP.md#fase-8-escala)). Ela traz quatro coisas:
- **viagem rápida** pela busca;
- **bússola** e **minimapa** (com um mapa grande no M);
- **metrô** entre os bairros;
- uma medida de desempenho com uma **biblioteca falsa de 200 jogos**, que guia os ajustes de desenho à distância.

Escolhas do dono (2026-10-05):
- transporte = metrô com estações;
- minimapa desenhado a partir da planta da cidade, e não filmado por uma câmera;
- na busca, Enter continua acendendo o caminho e uma segunda tecla leva direto à porta.

Levantamento (só leitura), com arquivo:linha:
- **Busca:** `ui/game_search.gd`. `_choose()` (264-271) acende a faixa pelo grupo `route_guide` e emite `game_chosen`, que ninguém escuta. `can_open()` (119-123) bloqueia com jogo abrindo, na porta, na abertura e com o menu aberto.
- **Faixa de luz:** `worlds/city/city_route_guide.gd`, com `show_route`, `clear_route`, `has_route` e `route_points` (estático).
- **Teleporte:** `player.teleport_to(Transform3D)` (`player/player.gd:212-219`) não tem escurecimento. O `GamePortal` usa `get_return_transform()` (214-215) para devolver o jogador à porta.
- **Escurecer a tela:** `ScreenFade` tem `set_amount`, `fade_in` e `set_message`. **Não existe `fade_out`.**
- **Tela:** o HUD (`ui/hud.gd`) não tem bússola nem mapa. Os avisos ficam no topo central (`TOASTS_TOP = 12`), e a busca fica a 72 px do topo.
- **Teclas livres:** M, T, Q, E, F, R, G, C, V, números, F1–F7, F9, F10 e F12.
- **Cidade:** guarda só `_gate_spots` e `_district_signs`. **Não guarda qual bairro ocupa quais quarteirões.**
  - O pórtico de cada bairro fica no 1º quarteirão (`city.gd:289-317`) e não tem interação.
  - `CityLayout.block_cells` monta anéis quadrados, com 8r quarteirões por anel.
- **Custo por prédio:**
  - Não há luz nos prédios, mas há uns 20–30 nós CSG/mesh e 4–6 materiais próprios.
  - A capa e o hero são carregados sem compressão. São cerca de 4,8 MB por hero, o que daria **~950 MB com 200 jogos** (`game_art.gd:168-174`).
  - Os sons em loop dos bairros Esportes e Terror tocam sempre.
- **Custo por quarteirão:** 4 postes com **SpotLight3D + Decal** cada, o que dá ~240 com 200 jogos (`city_decor.gd:109-117`). Há também uma placa que gira em todo quadro.
- **Desenho à distância:** não existe nenhum LOD. `visibility_range` só aparece no nome dos amigos.
- **Biblioteca:**
  - Não existe biblioteca falsa. Dá para preencher `SteamLibrary._games/_games_by_id/_games_loaded` e `StoreInfo._cache` pelo teste.
  - App IDs inventados fariam o `GameArt` tentar a CDN e gravar arquivos `.none` em `user://cache`.
  - A pasta `librarycache` da Steam tem 791 jogos com capa local, que podem servir de capas reais sem internet.
- **Testes:** nenhum mede FPS. Só o tempo de montagem é medido (`check_phase6_step1`, `check_intro`).

## Pronto quando
- **Leve com 200 jogos.** Com a biblioteca falsa, na qualidade **Leve** e no notebook, a caminhada padrão passa dos **30 FPS em média**, sem engasgos acima de 100 ms. A memória de textura fica **abaixo de 1 GB**. No desktop, a Alta tem de passar de 60 FPS (conferir a partir de 18/10).
- **Perto de qualquer jogo.** Qualquer jogo fica a menos de ~20 s:
  - pela busca (Shift+Enter), em ~2 s;
  - pelo metrô, a estação do bairro fica a no máximo 20 s correndo (9 m/s, ou seja 180 m pelas ruas) de qualquer porta do bairro. Um teste com a biblioteca falsa mede isso.
- **Bússola e mapa.** A bússola mostra os pontos cardeais e o destino da busca com a distância. O minimapa e o mapa grande (M) mostram os bairros nas suas cores, você, o destino e as estações.
- **Nada muda sem querer.** Com 7 jogos, a cidade continua igual, exceto pelas estações de metrô e pelo HUD novo. A bateria inteira passa, com os testes novos.

## Decisões de arquitetura
- **O mapa é dado, publicado pelo mundo.**
  - `worlds/city/city_map.gd` (`CityMap`, nó no grupo `world_map`) guarda, para cada bairro: id, nome, cor, quarteirões, pórtico e estações. Guarda também os limites e a praça.
  - Ele responde a dois pedidos genéricos:
    - `get_map_data()` devolve áreas (retângulo, cor, nome), marcos (estação, praça) e limites;
    - `area_name_at(posição)` devolve o nome do bairro onde a posição está.
  - A UI (`ui/`) só fala com o grupo e nunca conhece a cidade (regras 1 e 2). Um bioma futuro publica o seu próprio `world_map`.
  - *Descartado:* a UI ler o `CityLayout` direto, porque amarraria o HUD à cidade.
- **Destino da busca:** a faixa de luz ganha `get_target_position()` e o sinal `route_changed`. A bússola e os mapas leem do grupo `route_guide`, como a busca já faz.
- **Viagem rápida no jogador:**
  - `player.travel_to(alvo, mensagem, segundos, som)` escurece a tela (`ScreenFade.fade_out`, novo), teleporta com `teleport_to`, apaga a faixa e clareia.
  - Durante a viagem, o movimento, a busca e o menu ficam travados. A trava usa `ScreenFade.get_amount()`, que o `can_open()` já confere.
  - O mesmo `travel_to` serve à busca e ao metrô.
  - Chegando a uma porta, o jogador fica no `ReturnPoint`, virado para a porta, e **o jogo não abre sozinho**.
  - Atenção: o `ReturnPoint` olha para a rua (está girado 180° no `game_portal.tscn`). Na viagem, o alvo usa a origem dele com a base girada de volta.
- **Metrô = parada genérica + aparência da cidade:**
  - `components/transit_stop/transit_stop.gd` (`TransitStop`, grupo `transit_stop`) tem a lógica:
    - nome, cor e ordem da parada;
    - uma `EntryArea` com a máscara do jogador (como a do portal);
    - um ponto de saída (`get_exit_transform()`).
  - Pisar na entrada abre o painel de linhas. O painel só reabre depois que o jogador sai da área.
  - `worlds/city/metro_entrance.gd` (`MetroEntrance extends TransitStop`) monta a aparência: boca de escada com corrimão e totem "M" em néon na cor do bairro. Segue o padrão do PortalShell, em que a lógica é genérica e a casca é do mundo.
  - Um bioma futuro pode ter teleférico com a mesma `TransitStop`.
- **Painel de linhas:** `ui/transit_panel.gd`, criado pelo jogador como a busca. Ele lista as paradas do grupo, na ordem do mundo e sem a atual: bolinha da cor, nome e "12 jogos".
  - Setas ou números escolhem, Enter viaja e Esc fecha.
  - A viagem dura ~2,5 s, com a tela escura, a mensagem "Metrô → RPG e Fantasia" e o som do trem.
  - Ao viajar, a parada de chegada ignora a sua entrada até o jogador sair dela, para não reabrir o painel.
- **Onde ficam as estações:**
  - uma "Central" na praça;
  - uma por bairro, na calçada junto ao pórtico;
  - uma **segunda** se alguma porta do bairro passar de 180 m da estação. Ela fica no quarteirão do bairro mais longe da primeira.
  - O ponto exato é conferido em captura. Um teste confere que a estação não bate em poste, placa nem prédio.
- **Som do trem gerado por código:** uma função nova no `assets/generated/make_sounds.py` (ronco grave mais os "tac-tac" dos trilhos, ~3 s, `metro_ride.wav`). Nada é baixado.
- **Minimapa e mapa grande desenhados em 2D:**
  - `ui/minimap.gd` desenha com `_draw()` a partir do `get_map_data()`, 5 vezes por segundo. Custo quase zero.
  - Fica no canto superior direito, com o norte para cima, você como seta girando e o nome do bairro embaixo.
  - O M abre `ui/world_map.gd`, que ocupa a tela e pausa como a busca, com os nomes dos bairros, as estações e o destino. Clicar no mapa para viajar fica fora (o metrô já faz isso).
- **Bússola:**
  - `ui/compass.gd` é uma faixa de ~480 × 28 px no topo central, com N/L/S/O, marcas a cada 45° e o marcador do destino com "140 m".
  - Os avisos descem para baixo dela.
  - No menu de pausa, a opção **"Bússola e mapa: ligado/desligado"** (padrão ligado) esconde a bússola e o minimapa.
- **Biblioteca falsa só nos testes:**
  - `tests/fake_library.gd` monta N jogos falsos. Usa App IDs da `librarycache` local da Steam (capas reais, sem internet) e completa com IDs inventados se faltar.
  - Preenche o `StoreInfo._cache` em memória com tags espalhadas pelos bairros, com um bairro bem maior para testar a 2ª estação.
  - A única mudança no código do jogo é `GameArt.allow_downloads` (padrão `true`), que o teste desliga.
  - O teste confere que nada foi gravado em `user://cache`.
- **Desempenho medido antes de mexer:**
  - `tools/medir_desempenho.gd` roda com janela, a biblioteca falsa de 200 jogos e uma caminhada padrão (praça até o bairro mais longe e volta, de dia e de noite), nas qualidades Leve e Alta.
  - Ele imprime o tempo médio e o pior tempo por quadro, as chamadas de desenho e a memória de textura, e salva capturas na pasta temporária.
  - Roda na 8.1 (linha de base) e na 8.8 (depois dos ajustes).
  - Só entra ajuste que a medida pedir.

## Subetapas
Ordem: medir e estruturar primeiro (nada visível), depois a viagem, o HUD, o metrô e os ajustes de desempenho por último.

- [x] **8.0 Preparação** (Opus · high)
  - Faz: `git checkout -b fase-8` a partir de `fase-7` e salva este plano em `docs/plans/fase-8.md`.
  - Commit: `Fase 8.0: plano`
- [ ] **8.1 Biblioteca falsa e linha de base** (Sonnet · medium)
  - Faz: `tests/fake_library.gd`, `GameArt.allow_downloads` e `tools/medir_desempenho.gd`. Roda a medida no notebook (Leve e Alta, 7 e 200 jogos) e anota os números em "Decisões tomadas durante a fase".
  - Teste: `tests/check_scale.gd` monta a cidade com 200 jogos falsos e confere:
    - todos os prédios existem, cada um com `GamePortal`;
    - nenhum bairro vazio e nenhuma requisição à rede;
    - `user://cache` intacto;
    - o tempo de montagem é impresso.
  - Commit: `Fase 8.1: biblioteca falsa e medida de desempenho`
- [ ] **8.2 Mapa da cidade como dado** (Sonnet · medium)
  - Faz: `CityMap` (grupo `world_map`, com `get_map_data` e `area_name_at`), preenchido por `_build_districts` e `_build_gate`. A faixa de luz ganha `get_target_position()` e `route_changed`. Nada muda na tela.
  - Teste: `tests/check_city_map.gd`, com 7 e com 200 jogos. Cada quarteirão pertence a um só bairro; as áreas não se sobrepõem; `area_name_at` acerta a porta de cada jogo; os limites batem com o `half_extent`; o alvo da faixa é a porta escolhida.
  - Commit: `Fase 8.2: mapa da cidade como dado`
- [ ] **8.3 Viagem rápida pela busca** (Sonnet · medium)
  - Faz:
    - `ScreenFade.fade_out` e `player.travel_to`;
    - na busca, Shift+Enter (ou Shift+clique) viaja até a porta, e a dica da busca mostra "Shift+Enter ir até lá";
    - a linha nova em `CONTROL_ROWS`.
  - Teste: `tests/check_fast_travel.gd`:
    - o jogador chega no `ReturnPoint`, virado para a porta;
    - a tela volta a clarear;
    - o jogo **não** abre (`GameLauncher` falso);
    - a busca e o menu não abrem durante a viagem;
    - não viaja com um jogo rodando;
    - Enter continua só acendendo a faixa.
    - `check_search` passa sem mudança.
  - Commit: `Fase 8.3: viagem rápida pela busca`
- [ ] **8.4 Bússola** (Sonnet · medium)
  - Faz: `ui/compass.gd` no HUD, os avisos descem e a opção "Bússola e mapa" no menu de pausa (`config.cfg`, seção `video`).
  - Teste: `tests/check_compass.gd`. O rumo bate com a direção da câmera (N ao olhar para −Z). O marcador do destino aparece só com a faixa acesa, no ângulo certo e com a distância. A opção esconde a bússola. Os avisos não ficam por cima dela. `check_toasts` passa.
  - Manual: captura com janela, de dia e de noite.
  - Commit: `Fase 8.4: bússola`
- [ ] **8.5 Minimapa e mapa grande** (Sonnet · medium; Opus se o visual teimar)
  - Faz: `ui/minimap.gd` (canto superior direito, 5 vezes por segundo) e `ui/world_map.gd` (tecla M, nova ação `open_map`, pausa como a busca). A linha "M mapa" entra em `CONTROL_ROWS`.
  - Teste: `tests/check_minimap.gd`:
    - a seta fica na posição do jogador;
    - o nome do bairro embaixo acerta;
    - o destino aparece;
    - o M abre e pausa, e M/Esc fecham;
    - o mapa não abre com a busca ou o menu aberto;
    - a opção esconde o minimapa;
    - funciona com 200 jogos.
  - Manual: capturas, com 7 e com 200 jogos.
  - Commit: `Fase 8.5: minimapa e mapa grande`
- [ ] **8.6 Metrô: paradas e painel de linhas** (Opus · high: interação nova)
  - Faz:
    - `TransitStop` e `ui/transit_panel.gd`;
    - viagem pelo `travel_to`, com mensagem e som (`metro_ride.wav` gerado);
    - a cidade cria as paradas com uma aparência provisória (um totem simples).
  - Teste: `tests/check_metro.gd`:
    - uma parada por bairro, mais a Central;
    - pisar abre o painel, que lista as outras paradas na ordem do mundo;
    - escolher leva à saída da parada certa;
    - chegar não reabre o painel, mas sair e voltar reabre;
    - Esc fecha;
    - o painel não abre com jogo rodando;
    - com 200 jogos, toda porta fica a ≤ 180 m de uma estação do seu bairro (cria a 2ª estação quando precisar).
  - Commit: `Fase 8.6: metrô entre bairros`
- [ ] **8.7 Metrô: a boca da estação** (Opus · high: visual e posição)
  - Faz: a aparência do `MetroEntrance` (boca de escada, corrimão, totem "M" em néon que acende à noite pelo grupo `city_night`, nome da estação) e a posição final junto ao pórtico e na praça. As estações aparecem no minimapa.
  - Teste: em `check_metro`, a estação não encosta em poste, placa, pórtico nem terreno, e a passagem pela calçada continua livre. `check_gates`, `check_night_life` e `check_district_props` passam.
  - Manual: capturas de dia e de noite, na praça e num bairro.
  - Commit: `Fase 8.7: boca do metrô`
- [ ] **8.8 Desempenho com 200 jogos** (Opus · high)
  - Faz: roda a medida, compara com a 8.1 e aplica, **na ordem e só o que a medida pedir**:
    1. **Capas:** limitar o tamanho do hero e da capa ao carregar (ex.: hero com até 1280 px de largura), ou carregar só perto.
    2. **Postes:** `distance_fade` nas SpotLights e nos Decals (as luzes longe apagam suave).
    3. **Detalhes:** `visibility_range` nos detalhes pequenos (telhado, marquise, moldura da porta, cartaz) e nos enfeites dos bairros.
    4. **Sons:** os emissores em loop só tocam perto.
    5. **Placas:** as placas que giram só giram perto.
  - Teste: em `check_scale`, os campos de distância ficam ligados e nada some a menos de 40 m. A bateria inteira passa. Nova medida no notebook, com os números anotados no plano.
  - Commit: `Fase 8.8: desempenho com 200 jogos`
- [ ] **8.9 Docs** (Sonnet · low)
  - Faz:
    - README: viagem rápida, bússola, mapa, metrô e as teclas novas;
    - ROADMAP: Fase 8 feita;
    - CLAUDE.md: mapa com `components/transit_stop/`, `CityMap` e as UIs novas;
    - `tests/README.md`: biblioteca falsa, `check_scale` e os testes novos;
    - `docs/plans/fase-8.md` marcado.
  - Commit: `Fase 8.9: documentação`

## Riscos
- **Topo da tela cheio:** os avisos, a bússola e a busca disputam o topo. A 8.4 desce os avisos e confere em captura.
- **Estação no caminho:** a estação pode cair num poste, numa placa ou na rua. Um teste geométrico e capturas na 8.7 pegam isso.
- **Painel reabrindo ao chegar:** a entrada fica ignorada até o jogador sair da área. A 8.6 testa isso.
- **Biblioteca falsa que suja o cache:** `allow_downloads = false`, o cache da loja fica só em memória e um teste confere `user://cache`.
- **Medida no notebook varia:** a caminhada padrão é sempre a mesma. Cada número é a média de 3 rodadas, com a mesma qualidade e a janela no mesmo monitor.
- **Capas limitadas ficam borradas de perto:** conferir em captura a 3 m da fachada antes de fixar o tamanho.
- **Sem Windows até 18/10:** nada aqui depende do sistema. No desktop, repetir a bateria e a medida na Alta.

## Fora do escopo
- Clicar no mapa para viajar, viajar para um bairro pela busca, bonde andando de verdade e carros. Ficam no "Depois" e no "Horizonte" do ROADMAP.
- Densidade e landmark por perfil (continuam reservados, da Fase 7).
- Juntar os nós CSG dos prédios num mesh único (só se a 8.8 mostrar que é o gargalo; aí volta ao modo plan).
- Push e merge: nada vai para o GitHub sem o dono pedir.

## Decisões tomadas durante a fase
- 2026-10-05: metrô com estações; minimapa desenhado pela planta; na busca, Enter = caminho e Shift+Enter = ir até lá (dono).

## Checklist de teste manual (fim da fase)
No notebook (Omarchy), qualidade **Leve**:
1. F5. Bússola no topo e minimapa no canto, com o nome do bairro em que você está.
2. Tab, digitar "bal", **Shift+Enter**: a tela escurece e você aparece na frente da porta do Balatro, virado para ela, sem o jogo abrir.
3. Tab, "sta", **Enter**: a faixa acende e a bússola mostra o destino e a distância.
4. M: mapa grande com os bairros, você e o destino. M fecha.
5. Andar até a estação de metrô da praça: abre o painel de linhas. Escolher um bairro: tela escura com som de trem e você sai na estação dele. Sair e voltar à entrada reabre o painel.
6. Esc › Som e vídeo › "Bússola e mapa": desligado esconde os dois.
7. Entrar numa porta: o jogo abre e volta como sempre (Undertale e Balatro).

No desktop com Windows (a partir de 18/10): o mesmo, mais `bash tests/run_tests.sh` e `tools/medir_desempenho.gd` na Alta.

## Verificação
1. `bash tests/run_tests.sh` ao fim de cada subetapa: `RESULTADO GERAL: TUDO OK`.
2. `check_scale` e `check_metro` com a biblioteca falsa de 200 jogos.
3. `tools/medir_desempenho.gd` com janela, na 8.1 e na 8.8, com os números anotados no plano.
4. Capturas (8.4, 8.5, 8.7 e 8.8) só na pasta temporária da sessão, nunca no repositório (mostram capas de jogos).
