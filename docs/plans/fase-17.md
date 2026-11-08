# Fase 17: O momento uau

**Status:** aprovado em 2026-11-02; em andamento
**Branch:** `fase-17`, criada da `origin/main` (`c74d6ae`, o merge do PR #2 da Fase 16).

## Para o dono (até 10 linhas)
- **O que você vai ver:** uma casa aconchegante à noite, com luz quente, objetos e a **cidade de verdade** pela janela, acendendo quando fica pronta. Uma praça e um mirante que se leem à noite, e um dia com contraste. Uma trilha com lugares para parar e com os seus jogos de RPG no caminho, até um mirante que recompensa a subida.
- **Agora:** 17.1 e 17.1b feitas: as 5 referências estão em `C:\Projetos\game-hub-referencias\uau\`, e o que cada uma ensina, em [uau-referencias.md](../design/uau-referencias.md). O "antes" da casa já está em `game-hub-referencias\uau\antes\`. **17.2 feita:** a casa à noite com poças de luz quente e sombras; o "depois" está em `game-hub-referencias\uau\depois-17.2\`. **17.3 feita:** a janela mostra a cidade de verdade, que acende quando fica pronta; o "depois" está em `game-hub-referencias\uau\depois-17.3\`. **17.3.1 feita:** as placas dos bairros saíram da janela. **17.4 feita:** sofá, manta, mesinha com caneca e livros, tapete antigo, um canto de leitura com aparador, quadro e palmeira, e mais três plantas, tudo por código; o "depois" está em `game-hub-referencias\uau\depois-17.4\` (com a folha `folha_17.4.png`). **17.4b feita:** a sala encolheu para 9 × 7 m com teto de 3,0 m (a cabana junto); o sofá virou um canto de estar no canto noroeste, de frente para quem nasce, e a porta da rua foi para perto do canto sudeste; o "depois" está em `game-hub-referencias\uau\depois-17.4b\` (com a folha `folha_17.4b.png`). **Amostra aprovada (2026-11-04).** **17.5 feita:** a praça, o pórtico e o mirante se leem à noite (o luar, a névoa azul-marinho, os holofotes da torre e o chafariz aceso), e a janela da casa mostra a montanha ao luar; o "depois" está em `game-hub-referencias\uau\depois-17.5\` (com a folha `folha_17.5.png`). **17.5 aprovada.** **17.7 feita:** a trilha da B (`5e3fc83`) juntada (`9a839e4`) e polida pela A (`93ec376`): a fogueira com terraço e bancos e a queda d'água congelada no barranco, do lado de fora da cerca, e os seus jogos de RPG nos estandartes; o "depois" está em `game-hub-referencias\uau\depois-17.7b\` (com a folha `folha_17.7b.png`). **17.7 aprovada.** **17.6 feita:** de dia, sol forte e quente, sombras mais fundas e cores mais vivas, nos bairros e na janela da casa, sem mudar a noite; o "depois" está em `game-hub-referencias\uau\depois-17.6\` (com a folha `folha_17.6.png`). **17.6 aprovada.** **17.7.1 feita:** a fogueira, o terraço de pedra seca, os bancos e o monte de pedras da trilha agora são modelos feitos no Blender; o "depois" está em `game-hub-referencias\uau\depois-17.7.1\` (com a folha `folha_17.7.1.png`). O Blender virou o caminho de modelagem (regras no AGENTS.md, em "Assets"). **17.7.1 aprovada.** A madeira dos modelos é a Wood049 da ambientCG (CC0, 1K). **17.8 feita e aprovada:** o mirante virou destino (deque de madeira, abrigo com a capa do seu RPG mais jogado, fogueira, lanternas e a luneta com E); o "depois" está em `game-hub-referencias\uau\depois-17.8\` (com a folha `folha_17.8.png`). **17.9 aprovada para começar (2026-11-08):** a 17.9.1 (a luz de dia e a vista da cabana) na trilha A e os modelos da cabana no Blender (17.9.1b) na trilha B, em paralelo; depois, a 17.9.2 (o acabamento da cabana). **17.9.1 feita:** de dia o sol entra pela janela com sombra (o desenho da janela no chão), o chão devolve a luz e as luminárias ficam de apoio, nos dois temas, e a noite não mudou; a vista da cabana está nas duas opções (a floresta e a montanha de verdade) para você escolher. O "depois" está em `game-hub-referencias\uau\depois-17.9.1\` (com a folha `folha_17.9.1.png`). **17.9.1 aprovada**, e os modelos da poltrona e da lareira (17.9.1b) juntados. Próxima: 17.9.2 (o acabamento da cabana, com a montanha vista do nível do chão).
- **Ordem:** referências → **amostra = a casa à noite com a janela** (você aprova) → luz da cidade → trilha e mirante → casa de dia e cabana.
- **Para testar:** cada subetapa traz capturas de antes e depois e o próprio checklist.
- **Decisões que esperam você:** os assets CC0 que a amostra pedir (nome, origem e tamanho antes de baixar).

## Contexto
A revisão da ROADMAP (2026-11-02) achou o hub "funcional, mas não criativo": a casa vazia, a janela péssima, a trilha sem conteúdo, o mirante feio, e a revisão de design (C1, C2) achou a noite apagando a praça e o mirante e o dia sem contraste. Esta fase é a [1. O momento uau](../ROADMAP.md#1-o-momento-uau). Primeiro a luz e o que já existe; modelos novos só se a amostra pedir.

O que o código tem hoje (exploração de 2026-11-02):
- **Janela:** um `QuadMesh` com shader procedural (`worlds/home/home_window.gdshader`): três planos de colunas sorteadas e um gradiente de céu, sem nuvens nem sol. A cidade de verdade nunca aparece.
- **Casa:** nenhuma luz com sombra, nenhum GI/SSIL nem `ReflectionProbe`; luzes Omni fracas (pendentes, abajur, néon, porta). O sol da cidade não entra (camada 20). Todos os móveis são primitivas por código; o único modelo importado é um arbusto Kenney.
- **Cidade:** os valores de dia e noite são constantes em `worlds/city/day_night.gd:35-62` (noite: névoa quase preta `#080A12`, ambiente 0,2, céu 0,45). A praça à noite só tem 4 postes nos cantos e o néon; a torre do relógio não tem luz própria.
- **Trilha e mirante:** cerca de estacas e cordas, uma lanterna a cada 15 pontos, o portal "Trilha do Mirante"; o mirante tem tábuas, guarda-corpo e um banco (`trail_dressing.gd`, `lookout_deck.gd`).
- **SSIL e SDFGI** não são usados em lugar nenhum.

## Pronto quando
- A casa, a janela, a trilha e o mirante passam na **sua comparação de antes e depois**, nas capturas (mesmos pontos, mesma hora) e no jogo.
- A praça e o mirante às 22 h mostram chão, relevo e caminho (não silhueta preta), e a noite continua noite. O dia (13 h) de vários bairros tem claro e escuro distintos.
- **Desempenho no desktop, Alta** (`tools/medir_desempenho.gd -- 200 alta 22`, comparado com o "antes" da 17.1): a casa segue no teto do VSync; a caminhada e a trilha não caem mais de 10% em FPS e o p99 fica ≤ 16,7 ms. Na Leve, só a comparação antes e depois, se o notebook estiver à mão.
- Regras de arquitetura valendo (a casa não conhece a cidade; o portal segue genérico).

## Decisões de arquitetura
- **Referências fora do repositório:** as imagens ficam em `C:\Projetos\game-hub-referencias\uau\` (ao lado do repositório, não dentro). No repositório entra só o texto: `docs/design/uau-referencias.md`, com o que cada imagem ensina (fontes de luz, cor, claro e escuro, densidade de objetos, materiais) e o que **não** copiar, no formato do `art-direction-brief.md` da skill `create-game-assets`. As imagens geradas são só referência: nada delas entra no jogo.
- **A amostra é a casa de verdade, à noite, no loft.** Ela é construída no código da branch (não num protótipo à parte) e define o sistema visual (luz, paleta, densidade) que o resto segue. Se você não aprovar, itera-se na casa antes de seguir.
- **A vista de verdade na janela (17.3), sem a casa conhecer a cidade:** um componente genérico `components/window_view/` tira um "retrato" do mundo (um `SubViewport` que divide o `World3D`, `UPDATE_ONCE`, sem a camada 20 da casa) de um ponto que **o mundo oferece** num grupo (`window_view_point`); a cidade põe esse ponto (de onde se vê o horizonte, os néons dos bairros, a torre e a montanha). O retrato é refeito só quando a cidade fica pronta e quando muda a fase do dia; nunca a cada quadro. O shader da janela amostra o retrato pela direção do olhar (como um céu), para ter perspectiva sem custo. Sem ponto no grupo (ou enquanto a cidade monta), fica o shader procedural de hoje, e o retrato entra com um fade: **a cidade acende pela janela** quando fica pronta.
  Descartado: render ao vivo a cada quadro (custo de uma segunda cidade) e uma foto HDRI de outra cidade (não seria a sua biblioteca).
- **Luz da casa:** sombras só nas luzes principais (pendente e abajur), e SSIL só na Alta, ligado pelo `GraphicsQuality` (um ponto só). Cores e energias seguem no perfil (`profiles/homes/*.tres`).
- **O retrato do loft (`tests/fixtures/casa_atual.json`) sai do teste.** Ele protegia a refatoração da 13.2 e agora impediria toda mudança intencional na casa. O `check_home_profile` perde só essa seção; o resto (catálogo, ids, cabana) fica. (Corrigir tirando código.)
- **Luz da cidade:** os ajustes gerais ficam em `DayNight` (é do mundo, então constante no código vale). Só se um bairro precisar de luz própria, o `DistrictProfile` ganha um campo (aí volta ao modo plano).
- **Trilha com a biblioteca:** o mundo (que já sabe quais jogos são do RPG) passa a lista à trilha; as capas vêm do `GameArt`. Sem jogos de RPG, a trilha fica só com o cenário.

## Subetapas
Trilha A (Claude, checkout principal: casa, `city.gd`, `day_night.gd`, `.tres`, plano). Trilha B (Codex, worktree próprio, só os arquivos listados). Se a cota do ChatGPT acabar, o Sonnet faz as da B na trilha A.

- [x] **17.0 Plano e branch** (só de docs · Opus) — a branch `fase-17` (veja o topo), este arquivo em `docs/plans/fase-17.md` e `Início.md` apontando para ele. Commit: `Docs: plano da Fase 17 (O momento uau)`
- [x] **17.1 Referências e o "antes"** (só de docs + capturas · você e o Opus · medium, sessão do coordenador)
  - **Você:** de 3 a 5 imagens em `C:\Projetos\game-hub-referencias\uau\` (`01_casa_noite`, `02_vista_janela`, `03_trilha_noite`, `04_mirante_noite`, `05_praca_noite` ou `05_cidade_dia`) e um `notas.txt` com uma frase por imagem: "gosto disso por causa de ___".
  - **Opus:** lê as imagens e escreve `docs/design/uau-referencias.md` (só texto) com o manifesto de assets candidatos.
  - **"Antes":** capturas com `tools/capturar_pontos.gd` (praça e mirante, 13 h e 22 h, 200 falsos, Alta) e da casa (ferramenta da 17.1b), e a medida `medir_desempenho.gd -- 200 alta 22`. Tudo na pasta temporária da sessão.
  - Commit: `Docs: Fase 17.1, referências do uau`
- [x] **17.1b Captura da casa** (`1ff46c4`, merge `fefe6b1`) (pequena · trilha B, Sol · medium, worktree `worktree/uau-b`) — em paralelo com a 17.1.
  - Arquivos: `tools/capturar_casa.gd` (novo; mesmos argumentos do `capturar_pontos.gd` mais o tema `loft|cabana`; pontos `nascer`, `janela`, `sofa`, `estante`; recusa pasta dentro do repositório; ganchos `_prepare()`/`_points()` para amostras), `tests/check_capture_home.gd` (novo).
  - Teste: `check_capture_home check_capture_points`.
  - Commit: `Fase 17.1b: captura da casa por pontos`
- [x] **17.2 A casa aconchegante, com o que existe** (`5be6c4a`) (grande · trilha A, Opus, sessão nova · high · revisão: você, pelas capturas)
  - Faz: luz em poças quentes (pendentes, abajur, néon), sombras nas luzes principais, SSIL na Alta, contraste de claro e escuro na sala; materiais e cores do loft ajustados pelas referências; tira o retrato fixo do `check_home_profile`.
  - Arquivos: `worlds/home/home.gd`, `worlds/home/themes/loft_decor.gd`, `profiles/homes/loft.tres`, `autoload/graphics_quality.gd` (SSIL), `tests/check_home_profile.gd`, `tests/fixtures/casa_atual.json` (sai).
  - Teste: bateria completa; captura antes/depois da casa às 22 h; `MEDIDA_CASA` no desktop.
  - Commit: `Fase 17.2: a casa com luz quente e contraste`
- [x] **17.3 A cidade de verdade pela janela** (`e0c497e`) (grande · trilha A, Opus · high · revisão: Astra, `/codex:adversarial-review`, porque cria um contrato entre a casa e o mundo e um shader novo)
  - Arquivos: `components/window_view/window_view.gd` (novo), `worlds/home/home_window.gdshader` (amostra o retrato; o procedural fica de reserva), `worlds/home/home.gd` (usa o componente), `worlds/city/city.gd` (põe o ponto no grupo `window_view_point`), `tests/check_window_view.gd` (novo: sem ponto → procedural; com ponto → `UPDATE_ONCE`, sem a camada 20, refeito só na troca de fase do dia; a casa não referencia `worlds/city`).
  - Captura: a janela às 13 h e às 22 h, e o momento em que a cidade acende.
  - Commit: `Fase 17.3: a janela mostra a cidade de verdade`
- [x] **17.3.1 Placas dos bairros fora da janela** (`0b9e9ba`) (pequena · trilha A, Sonnet subagente · medium) — pedido do dono ao ver a 17.3: de dia, as placas flutuantes dos bairros apareciam na janela como etiquetas de mapa.
  - Faz: o `WindowViewPoint` ganha `hidden_layers` (o mundo diz o que não entra no retrato); as placas (`DistrictSign`) ficam numa camada própria, que a cidade esconde do retrato. Na rua, nada muda.
  - Arquivos: `components/window_view/window_view_point.gd`, `components/window_view/window_view.gd`, `worlds/city/district_sign.gd`, `worlds/city/city.gd`, `tests/check_window_view.gd`.
  - Teste: `check_window_view check_landmarks check_gates check_variants check_capture_home`; captura da janela às 13 h e às 22 h em `depois-17.3.1`.
  - Commit: `Fase 17.3.1: placas dos bairros fora da janela`
- [x] **17.4 Objetos da casa e aprovação da amostra** (`b4a68f2`) (grande se entrar asset · trilha A, Opus · high · revisão: você)
  - Faz: o que as referências pedirem e a luz sozinha não resolveu (plantas, livros, manta, objetos de mesa, um tapete melhor). Primeiro por código; modelo CC0 só com a sua permissão (nome, origem, tamanho), com `LICENSE` e crédito no README.
  - **Portão:** você aprova a casa à noite. Se não, volta à 17.2. Aprovada, o plano registra o sistema visual (paleta, luz, densidade) que vale para o resto.
  - Commit: `Fase 17.4: a casa ganha vida` (+ `Assets: <pacote> (CC0)` se houver)
- [x] **17.4b A sala do tamanho certo** (`d8a62b3`) (grande · trilha A, Opus, sessão nova · high · revisão: Astra, `/codex:review`, porque muda a geometria e os lugares prontos de que dependem as disposições, o computador e o painel; e você, pelas capturas) — pedido do dono ao ver a 17.4: o tamanho da sala e a posição dos móveis não dão aconchego.
  - Faz: a sala vai de 12 × 9 m, teto 3,4 m, para **9 × 7 m, teto 3,0 m**, no loft e na cabana (um tamanho só). Os lugares prontos (`ANCHORS`), a janela, a porta, os néons, as luzes e o painel passam a sair do tamanho da sala, sem números soltos. O sofá deixa de flutuar no meio de costas para quem entra: vira um **canto de estar agrupado** (o sofá visto de frente ou de lado por quem nasce, o abajur e uma planta colados nele, um tapete grande sob o sofá e a mesinha, o pendente mais baixo sobre a mesinha). A regra de densidade da 17.4 ("meio livre") vira **cantos cheios e passagens livres**.
  - Arquivos: `worlds/home/home.gd`, `worlds/home/themes/loft_decor.gd`, `worlds/home/themes/cabin_decor.gd` (só para caber; o tratamento é da 17.9), os móveis de `worlds/home/` se algum não couber, `profiles/home_catalog.tres` só se o giro de nascer precisar mudar, `tools/capturar_casa.gd` e os testes da casa (`check_home`, `check_home_profile`, `check_computer_desk`, `check_system_panel`, `check_capture_home`).
  - Captura: os 4 pontos às 22 h e às 13 h em `depois-17.4b`, lado a lado com a 17.4 e a referência 01; a cabana às 22 h, para ver que coube.
  - **Portão:** a aprovação da amostra passa para cá.
  - Commit: `Fase 17.4b: a sala do tamanho certo`
- [x] **17.5 A noite da cidade** (`6ff1e30`) (grande · trilha A, Opus, sessão nova · high · revisão: você, pelas capturas)
  - Faz (C1): noite legível sem deixar de ser noite. Névoa e ambiente noturnos menos pretos, luz própria na torre do relógio e no centro da praça, a lua e a neve no mirante. Teste rápido de SSIL na Alta na cidade, com medida; fica só se couber na meta.
  - Arquivos: `worlds/city/day_night.gd`, `worlds/city/city.gd` (ambiente), `worlds/city/plaza_clock_tower.gd`, `worlds/city/city_decor.gd` (praça), `profiles/biomes/montanha.tres` se preciso.
  - Teste: bateria completa (atenção a `check_daynight`, `check_night_life`, `check_biome_atmosphere`, `check_sky3d`, `check_graphics_quality`); medida no desktop.
  - Captura: praça, pórtico e mirante às 22 h, antes e depois.
  - Commit: `Fase 17.5: a praça e o mirante se leem à noite`
- [x] **17.6 O dia com contraste** (`cf0eb4e`) (grande · trilha A, Opus · high · revisão: você)
  - Faz (C2): exposição, céu, sombra e contraste dos materiais que existem; diferenças por bairro só se a captura pedir (campo novo no `DistrictProfile` → volta ao modo plano).
  - Arquivos: `worlds/city/day_night.gd`, `worlds/city/city.gd`, `worlds/city/building_facade.gdshader` se preciso.
  - Captura: `cima` e `portico` às 13 h de 3 bairros, antes e depois.
  - Commit: `Fase 17.6: o dia com contraste`
- [x] **17.7 A trilha com conteúdo** (B `5e3fc83`, merge `9a839e4`, polimento e integração `93ec376`) (grande · trilha B, Astra · high, worktree novo `worktree/uau-b2` saído da `fase-17` depois da 17.4 · revisão: Opus lê o diff antes do merge) — em paralelo com a 17.5 e a 17.6.
  - Faz: pontos de parada (fogueira, ruína ou monte de pedras, uma queda d'água congelada, bancos) e os seus jogos de RPG no caminho (estandartes ou lanternas com as capas, em ordem de horas). Segue o sistema visual aprovado na 17.4.
  - Arquivos: `worlds/city/biome/trail_dressing.gd`, `worlds/city/biome/trail_banner.gd` (novo), `tests/check_trail_content.gd` (novo). A lista de jogos entra pelo `setup` que o `city.gd` já chama (a mudança de uma linha no `city.gd` fica com a A, no merge).
  - Teste: `check_trail_content check_mountain_trail check_biome check_terrain`; captura da subida às 13 h e às 22 h.
  - Commit: `Fase 17.7: a trilha com paradas e com os seus jogos`
- [x] **17.7.1 Teste do Blender** (scripts `19fa5c2`, modelos `e11bd6b`, merge `5d19453`) (grande · trilha A, Opus, sessão nova · high · worktree `worktree/blender` saído da `fase-17` · revisão: você, pelas capturas) — pedido do dono ao ver a 17.7: as peças de primitivas por código ficam com cara de bloco.
  - Faz: o Blender 5.2.3 LTS, instalado pelo winget em `C:\Program Files\Blender Foundation\Blender 5.2\` (fora do repositório, só no desktop). Um script em `tools/blender/` roda sem janela (`--background --python`) e gera a fogueira e as pedras da trilha em `.glb`; a Godot importa, e a captura compara com a fogueira de código da 17.7. Medida no desktop.
  - Decide: se o Blender entra na 17.8 (abrigo, fogueira, lanternas, luneta) e na 17.9 (sofá e plantas da casa).
  - Licença: os `.glb` são nossos; os scripts usam a API do Blender (GPL) e ficam em `tools/blender/` com o `LICENSE` GPL-3.0 da pasta (veja o AGENTS.md).
  - Arquivos: `tools/blender/` (novo), os `.glb` numa pasta nova em `assets/`, `worlds/city/biome/campfire.gd` e `trail_dressing.gd` (usar o modelo), `tests/check_trail_content.gd`.
  - Commit: `Fase 17.7.1: a fogueira e as pedras feitas no Blender`
- [x] **17.8 O mirante** (scripts `680c5f2`, modelos e código `5bd31a8`, merge `5e1fc63`) (grande · trilha A, Opus · high · revisão: você, pelas capturas)
  - Faz: um destino que recompensa a subida. O jogo de RPG mais jogado em destaque, abrigo de madeira, fogueira, lanternas e uma luneta (E aproxima a vista, pelo `focus_on` que já existe).
  - Arquivos: `worlds/city/biome/lookout_deck.gd`, `worlds/city/city.gd` (merge da 17.7 e a lista de jogos), `tests/check_mountain_trail.gd`.
  - Captura: o ponto `mirante` às 13 h e às 22 h, antes e depois.
  - Commit: `Fase 17.8: o mirante como destino`
- [ ] **17.9 A casa de dia e a cabana** (dividida em duas entregas, com a sua aprovação entre elas; decisões de 2026-11-08 em "Decisões tomadas durante a fase")
  - [x] **17.9.1 A luz de dia e a vista da cabana** (`b74c25a`) (grande · trilha A, Opus · high · revisão: você, pelas capturas)
    - Faz: de dia a janela domina a luz da sala (luz do dia com sombra, tons mais neutros), com as luminárias como apoio quente, nos dois temas; a noite aprovada do loft não muda. Na cabana, a vista da janela em comparação: a floresta do shader contra a montanha de verdade (o retrato que já existe), às 13 h e às 22 h, para você escolher. Sem floresta 3D e sem ponto de captura novo.
    - Arquivos: `worlds/home/home.gd`, `worlds/home/themes/loft_decor.gd` e `cabin_decor.gd` (só a luz), `worlds/home/home_window.gdshader` e `home_window_forest.gdshader` (se a luz pedir), `profiles/homes/loft.tres` e `cabana.tres`, `tools/capturar_casa.gd` e os testes da casa (`check_home`, `check_home_profile`, `check_capture_home`, `check_window_view` e o que mais a luz tocar).
    - Captura: os dois temas às 13 h e às 22 h, antes e depois, e a vista da cabana nas duas opções. Medida no desktop, na Alta.
    - Commit: `Fase 17.9.1: a luz de dia na casa`
  - [x] **17.9.1b Os modelos da cabana no Blender** (`2ccc53a`, merge `fe0d2f5`) (grande · trilha B, Codex/Astra · high · revisão: Opus, pelo diff e pelas capturas) — corre em paralelo à 17.9.1; só gera os modelos, sem pôr na casa.
    - Faz: a poltrona (um modelo, usado duas vezes) e a lareira de pedra, com a mesma pegada e altura das peças por código de hoje e a Wood049 e as texturas PBR que já existem; uma malha por material.
    - Arquivos: `tools/blender/gerar_poltrona.py`, `tools/blender/gerar_lareira.py` (e o `comum.py` só para acrescentar), `tools/blender/README.md`, `assets/models/home/` (novo, com os `.import`), `tests/check_home_models.gd` (novo).
    - Commit: `Fase 17.9.1b: a poltrona e a lareira feitas no Blender`
  - [ ] **17.9.2 O acabamento da cabana** (grande · trilha A, Opus · high · revisão: você) — depois da sua aprovação da 17.9.1.
    - Faz: o âmbar perto do fogo e dos lampiões, sombras mais frias, tecidos menos saturados, objetos pequenos no canto de estar; os modelos da 17.9.1b no lugar das primitivas; a vista escolhida por você.
    - Arquivos: `worlds/home/themes/cabin_decor.gd`, `profiles/homes/cabana.tres`, um leitor dos modelos dentro de `worlds/home/` (a casa não conhece a cidade), os testes da casa.
    - Commit: `Fase 17.9.2: a cabana com o aconchego do loft`
- [ ] **17.10 Fechamento** (Opus coordena; docs pelo Haiku, conferidos) — bateria completa até `TUDO OK`, a folha de antes e depois de todos os pontos (fora do repositório), a medida no desktop, README, ROADMAP ("O momento uau" em "Feito") e `Início.md`. Merge na `main` só quando você pedir.

## Assets CC0 que podem pedir permissão
Só se a amostra pedir; a lista exata (nome, link, tamanho) sai da 17.1 e é perguntada antes de baixar. Estilo semirrealista, para combinar com o PBR (Kenney e Quaternius ficam de fora: você achou o low-poly infantil).
- **Poly Haven, modelos (CC0, glTF 1k):** plantas em vaso, livros, almofadas e manta, luminária, objetos de mesa (17.4); lanterna, caixotes, toras (17.7, 17.8).
- **ambientCG, texturas (CC0, 1K):** tecido, madeira, couro (17.4).
- Orçamento: até ~50 MB no repositório na fase toda; fontes pesadas ficam fora.

## Riscos
- **A amostra não convence:** o portão da 17.4 segura o resto; a iteração fica na casa, que é isolada.
- **O retrato da janela fica "pôster":** o shader amostra pela direção do olhar (perspectiva); se ainda parecer chapado, um véu de vidro e reflexo leve.
- **Desempenho:** sombras de Omni e SSIL custam; tudo medido no desktop contra o "antes" da 17.1, e só na Alta.
- **A noite deixa de ser noite:** a comparação é sempre na mesma hora, lado a lado.
- **A e B no mesmo arquivo:** a B só toca os arquivos da trilha e os testes dela; o `city.gd` é só da A.

## Fora do escopo
- Sons (parado), pórticos e limiar do arco (B3, B5), letreiros (B4), vitrines (C4), abertura dos painéis (D-T1), a seção E da revisão.
- Biomas novos e o bairro que cresce com as horas (fase 4 da ROADMAP).

## Decisões tomadas durante a fase
- 2026-11-02: plano aprovado pelo dono (17.0). A `fase-17` saiu direto da `origin/main` (`c74d6ae`), sem passar pela `main` local, porque o `docs/.obsidian/app.json` alterado no checkout impedia trocar para ela; a `main` local foi só adiantada até a `origin/main`, e a `fase-17` não segue nenhuma branch remota.
- 2026-11-02: amostra = a casa à noite com a janela; conteúdo da trilha e do mirante = cenário e a sua biblioteca juntos (respostas do dono no planejamento).
- 2026-11-03 (17.1): as referências foram geradas pelo Opus no ComfyUI local, pela API (sem a interface).
  - Modelo: o FLUX 3 Image Klein. Venceu o Z-Image Turbo, já instalado, numa comparação de 20 imagens.
  - Para isso, o ComfyUI do dono foi atualizado (há branch de backup) e o Klein foi baixado (~11 GB, fora do repositório).
  - O dono escolheu as cinco sugestões.
- 2026-11-03 (17.1): as capturas do "antes" ficam em `game-hub-referencias\uau\antes\`, fora do repositório, e não na pasta temporária. Da 17.2 à 17.8 todas comparam com elas.
  - A casa fica sem "antes" até a 17.1b. Por isso a 17.2 não começa antes da 17.1b.
  - As metas da 17.5 (quase preto < 35%) e da 17.6 (abrir a faixa de claro e escuro) estão em `uau-referencias.md`.
- 2026-11-03 (17.1b, merge `fefe6b1`): a trilha B (Sol) entregou `tools/capturar_casa.gd` e `tests/check_capture_home.gd`. O Opus leu o diff; depois do merge, `check_capture_home check_capture_points` deram ok.
  - O "antes" da casa (loft, 13 h e 22 h, Alta, 200 falsos; pontos nascer, janela, sofa e estante) está em `game-hub-referencias\uau\antes\`. A 17.2 já pode começar.
  - Worktree e branch `uau-b` apagados depois do merge.

- 2026-11-03 (17.2): a luz do loft.
  - **Pendentes:** cada um faz uma poça (um cone para baixo, `SpotLight3D`) e tem uma luz fraca e curta que acende a cúpula e o teto em volta. O do meio foi para cima da mesinha (0; −3), na frente da janela, como na referência; os dos lados, para x = ±3,5. A força está no perfil (`lamp_energy` = 7).
  - **Sombra só em duas luzes:** o pendente da mesinha e o abajur. Nenhuma peça das luminárias faz sombra (a luz fica dentro delas).
  - **Abajur:** foi para trás do braço esquerdo do sofá, para acender o encosto (o que se vê ao entrar) e jogar a sombra do sofá no tapete. A cúpula ficou sem sombreamento e âmbar: com a luz de dentro, ela estourava em branco.
  - **SSIL:** `GraphicsQuality.apply_indoor_light` decide (só na Alta) e só a casa chama. A cidade fica para a 17.5. O SSAO da casa ficou mais forte (raio 1,2; intensidade 2,5).
    - O SSIL e o SSAO valem também na cabana; ela foi conferida por captura e segue bem (a 17.9 cuida dela).
  - **Cores do loft** (`loft.tres`): piso mais escuro e encerado, tijolo mais quente, reboco bege mais fundo, teto escuro. O ambiente da noite ficou fraco e azulado (0,32). Sofá bege acinzentado, com a trama mais suave. Tapete cinza.
    - O `loft.tres` foi editado à mão, só em valores de campos que já existiam (nenhum id mudou).
  - **Fora da lista do plano:**
    - `library_shelf.gd` ganhou uma luz de vitrine (fita de LED e duas luzes fracas). Com a sala em poças, a estante tinha ficado com 78% quase preto (antes: 59%).
    - `home_mirror.gd` ganhou uma arandela. O canto do espelho tinha caído de média 31 para 7.
    - As duas valem nos dois temas.
  - **O retrato saiu:** o `casa_atual.json` e também o `tests/home_snapshot.gd` e o `tools/retrato_casa.gd`, que só serviam a ele. O `check_home_profile` ganhou a seção "a luz do loft (17.2)".
  - **Números (22 h, Alta):**
    - nascer: média 40, quase preto 29% (antes 34 e 38%; referência 51 e 24%);
    - sofá: 39 e 37% (antes 41 e 22%);
    - estante: 32 e 61% (antes 28 e 59%);
    - janela: 31 e 47% (antes 35 e 39%). A janela pesa: o céu do shader é quase preto, e a 17.3 troca a vista.
    - Os pontos claros subiram: os 95% chegam a 93–116 (antes, 74–90).
  - **Medida no desktop:**
    - a casa segue no teto (165,0 FPS, p99 8 ms, 97 desenhos);
    - o espelho, também (165,0);
    - a caminhada ficou em 152,2 (antes 152,8).
  - **De dia (13 h)** a casa ficou parecida com antes, com as luminárias acesas. Em volta da janela ficou mais escuro (40% quase preto, antes 24%): fica para a 17.9.
- 2026-11-03: o dono aprovou a 17.2, sabendo que a diferença ainda é modesta: a janela (17.3) e os objetos (17.4) são o que mais pesa contra a referência. Os `.uid` da 17.1b entraram em `4ce7a2d`.

- 2026-11-03 (17.3): a janela mostra a cidade de verdade.
  - **O contrato:** `components/window_view/` tem o `WindowView` (tira o retrato) e o `WindowViewPoint` (o ponto que o mundo oferece, no grupo `window_view_point`). O ponto avisa as janelas pelo grupo `window_view`, no fim do quadro. A casa usa o `WindowView` e não cita `worlds/city`; o `check_window_view` confere a pasta da casa e a dos componentes.
  - **O ponto da cidade:** do lado oposto ao da montanha (mira a torre do mirante), a 0,92 do raio da cidade e a 0,4 do raio de altura (70 m com 200 jogos), descendo 5°, com zoom 1,2. Escolhido por capturas: mais baixo, os letreiros dos bairros tampavam a vista; assim, a montanha e o céu ficam no terço de cima da janela. Sem montanha, olha para o norte.
  - **O retrato:** lente de 100° numa imagem 2:1 (2048 × 1024 na Alta, 1536 × 768 na Média, 1024 × 512 na Leve), com o mesmo MSAA da tela, para os shaders compilados servirem aos dois (`GraphicsQuality.apply_to_window_view`). O SubViewport é desfeito depois de cada retrato, e a imagem vem da placa sem travar (`texture_get_data_async`): a cópia comum custava ~18 ms.
  - **As fases do dia:** dia abaixo de 0,25 de "noite", pôr do sol até 0,85, noite daí para cima. Na troca, o retrato velho se funde no novo em 1,5 s.
  - **A entrada (3,5 s):** à noite, a vista de reserva se apaga e a cidade acende, as luzes (néon, janelas) antes do resto; de dia, troca simples. Sem isso, a cidade de verdade (mais escura que a reserva) parecia "apagar".
  - **O vidro:** véu frio, reflexo quente da sala (mais forte de lado) e as 4 lâmpadas mais perto da janela refletidas, acompanhando quem anda. Olhando de raspão, fora da lente do retrato, o vidro fecha num véu escuro.
  - **Ganho do retrato à noite: 2,2.** A cidade à noite ainda é quase preta, e sem ganho a janela virava um quadro preto. **A 17.5 precisa rever esse ganho** quando clarear a noite da cidade.
  - **Fora da lista do plano:** `autoload/graphics_quality.gd` (o tamanho e as bordas do retrato) e `tools/capturar_casa.gd` (espera a janela assentar antes de fotografar, senão a captura sai no meio do fade).
  - **Os letreiros dos bairros** giram para a câmera do jogador; no retrato eles saem no ângulo do momento da foto (de frente, de dia, na captura). Fica assim: letreiros estão fora do escopo (B4).
  - **Números** (Alta, 200 jogos; média, 95% até e quase preto):
    - 13 h, o vidro: 138, 184 e 6% → 142, 195 e 6%. A montanha nevada e os bairros aparecem; o resto da sala não mudou.
    - 22 h, o vidro: 42, 174 e 8% → 29, 58 e 58%. A reserva era uma parede de janelas acesas; a cidade de verdade à noite é escura (é a C1, da 17.5). O ponto janela inteiro: 32, 77 e 43% → 28, 74 e 59%.
  - **Medida no desktop** (`200 alta 22`): caminhada 151,8 FPS (antes 152,8; −0,7%), p99 11 ms; casa e espelho no teto (165,0); montanha 162,8. Montagem: pior quadro 88 ms, como antes.
  - **O quadro do retrato:**
    - o primeiro, logo depois da cidade pronta, leva **~87 ms** (antes da 17.3, esse quadro levava ~37 ms). Em troca, o primeiro quadro na rua caiu de ~35 ms para ~8 ms;
    - é o primeiro desenho da cidade, que antes acontecia ao sair pela porta, escondido no fade. Medido: não é o tamanho da imagem (128 × 64 custa igual), nem o MSAA, nem os efeitos de tela. Diluir em fatias deu dois trancos (~60 e ~48 ms) e foi descartado;
    - **pendência para o dono:** é um tranco visível, uma vez por abertura, junto do aviso "A cidade está pronta" (que já tem quadros de 89, 47 e 23 ms). Aceitar, ou estudar na 17.10 aquecer os shaders da cidade durante a montagem;
    - na troca de fase do dia: um quadro de ~13 ms.
  - **Revisão do Astra** (`/codex:adversarial-review`, "needs-attention"): dois achados médios, os dois corrigidos.
    - O ponto saindo no meio de uma captura fazia o retrato velho voltar. Agora uma "geração" invalida a captura, e o teste cobre.
    - De muito de lado, a borda do retrato esticava numa coluna. Agora o ângulo é apertado aos poucos e, fora da lente, o vidro fecha num véu (conferido nas capturas `canto_mesa`, `canto_oeste` e `colado`).
    - Ficou de fora a sugestão de um panorama ou várias vistas para cobrir todos os ângulos: custaria mais retratos, e de raspão o vidro de verdade já reflete mais do que mostra.
  - **Capturas** em `game-hub-referencias\uau\depois-17.3`: os 4 pontos às 13 h e às 22 h, os 3 cantos e a pasta `acende` (a cidade acendendo, de 0 a 4 s, com a folha `folha_acende.png`).
- 2026-11-03: o dono aprovou a 17.3 com duas decisões:
  - as placas dos bairros saem da vista da janela agora (17.3.1, antes da 17.4);
  - o tranco de ~87 ms na primeira foto da janela (uma vez por abertura, junto do aviso "A cidade está pronta") fica aceito. A 17.10 estuda aquecer os shaders da cidade durante a montagem.
  - A janela à noite ainda é escura (59% quase preto): melhora com a noite da cidade (17.5), que também revê o ganho de 2,2 do retrato.
- 2026-11-03 (17.3.1, `0b9e9ba`): as placas dos bairros ficam na camada de render 18 (`DistrictSign.RENDER_LAYER`; a 19 é a do espelho e a 20 a da casa), e o ponto da cidade esconde essa camada do retrato. Testes ok; a captura das 13 h mostra a montanha e os bairros sem nenhuma placa, e nenhum outro rótulo flutuante aparece na janela.

- 2026-11-03 (17.4, `b4a68f2`): a casa ganha vida, tudo por código (nenhum asset baixado; o orçamento de ~50 MB segue intacto).
  - **Peças novas reutilizáveis** em `worlds/home/` (valem para a cabana na 17.9):
    - `HomeShapes` (`home_shapes.gd`): a caixa de cantos redondos e faces estufadas (`soft_box`), o pano caído com dobras (`drape`), o livro e o cano fino. As peças pequenas entram num `Batch`: muitas formas viram uma malha só, com a cor no vértice (um desenho, e não um por peça);
    - `HomePlants` (`home_plants.gd`): plantas em vaso (palmeira, folha larga, espada, pendente), com folhas finas dos dois lados, nervura em "V" e luz atravessando a folha;
    - dois shaders: `home_rug_vintage.gdshader` (tapete antigo e gasto, com o pelo em relevo; o da cabana segue o `home_rug.gdshader`) e `home_picture.gdshader` (a gravura de montanhas do quadro);
    - `HomeMaterials` ganhou `fabric_tinted`, `vertex_colored` e `leaf`. As cores de vértice são tratadas como sRGB (`vertex_color_is_srgb`), para valerem como as do albedo: sem isso, tudo saía desbotado.
  - **O loft** (`loft_decor.gd`):
    - **sofá** de verdade: pés de madeira, base, braços e encosto redondos, dois assentos e duas almofadas de encosto estufados, três almofadas soltas (ardósia, creme, terracota). O encosto desce até a base: visto de trás (o lado que se vê ao entrar), é uma peça só;
    - **manta** de tricô grafite: sai da beira do assento, passa por cima do encosto e cai pelas costas do sofá, porque a câmera de quem entra vê o sofá de trás (na referência ela cai pela frente);
    - **mesinha** com armação de aço e prateleira (livros e uma caixa de jogo embaixo; caneca, dois livros, duas revistas e o controle em cima);
    - **tapete** antigo e gasto, com medalhão, cantos ornados e a borda de florzinhas;
    - **o canto entre a estante e a janela** (o centro da vista de quem nasce): aparador de nogueira com livros em pé, uma pilha deitada, uma esfera de latão, um abajur de mesa e uma planta pendente; o quadro na parede de tijolo; a palmeira grande ao lado da janela. O aparador ocupa o lugar pronto `norte_esquerda`, que nenhuma disposição usa desde que a estante de apps saiu;
    - mais três plantas: a espada ao lado do sofá, uma folha larga no canto do computador e uma pequena no peitoril.
  - **A luz é a da 17.2.** Só entrou o abajur do aparador, fraco (0,49) e de queda suave, sem sombra. Abaixo de 0,5 a janela não o reflete, e assim ele não toma o lugar de um pendente no reflexo do vidro (a janela da 17.3 não mudou).
  - As folhas que passariam da parede ou do vidro são achatadas só nesse eixo (`_keep_inside`): o `check_home` (nada fora da sala) pegou a palmeira, a do canto e a do peitoril.
  - O nó `SofaSeat` ficou como marcador do assento, para o ponto `sofa` do `capturar_casa.gd` seguir igual.
  - **Bateria completa: TUDO OK** (87). Numa primeira rodada, o `check_look_card` falhou uma vez ("clique toca quando o alvo muda") e passou duas vezes sozinho: instável, sem ligação com a casa.
  - **Teste:** o `check_home_profile` ganhou a seção "os objetos do loft (17.4)": as peças existem (sofá, manta, mesinha, tapete, aparador, quadro, 4 plantas e 5 folhagens), as malhas delas ficam na camada 20, e nada tampa a passagem (o nascer, a porta e a frente de cada móvel de todas as disposições do catálogo, mais o computador).
  - **Números** (22 h, Alta; a régua toda está em `uau-referencias.md`): nascer 38 de média e 39% quase preto; sofá 35 e 48%; estante 36 e 52%; janela 27 e 62%. Quase iguais aos da 17.3.1: os objetos enchem a sala, mas a luz não mudou. O que ainda puxa para o preto é o teto, o canto do computador e a janela à noite (a 17.5).
  - **Medida no desktop** (`200 alta 22`, com o ComfyUI do dono aberto): casa 165,0 FPS (teto), p99 8 ms, **110 desenhos** (o código de antes, medido na mesma hora: 105; na 17.2: 97); espelho 164,9; montanha 162,7. Caminhada 148,0 e 149,0 FPS em duas medidas (o código de antes, na mesma hora: 149,6; o "antes" da fase: 152,8, −2,5%), p99 13–14 ms. Uma primeira medida deu 134,9 logo depois de várias capturas; repetida duas vezes, não se confirmou.
  - **Capturas** em `game-hub-referencias\uau\depois-17.4`: os 4 pontos às 13 h e às 22 h, os pontos de perto (`perto\`: frente do sofá, mesinha, o canto e o canto do computador) e a folha `folha_17.4.png` (antes e depois, e a referência 01).
  - **Se a amostra pedir mais realismo:** as plantas e os livros do Poly Haven do manifesto (`potted_plant_01`, `potted_plant_02`, `book_encyclopedia_set_01`, ~12 MB) trocariam as de código. Nada foi baixado; fica para a sua decisão.
- 2026-11-03: o dono viu a 17.4 e ainda não aprovou a amostra. Gostou dos objetos, mas o tamanho da sala (12 × 9 m, 108 m²; a da referência tem uns 30 m²) e a posição dos móveis (o sofá solto no meio, de costas para quem entra; tudo nas paredes, com o meio vazio) não dão aconchego. Decidiu: a sala vai para 9 × 7 m com teto de 3,0 m (cerca de 60 m², todos os móveis seguem cabendo do tamanho que são), e a cabana encolhe junto (um tamanho só, e não um campo no perfil de cada tema). Isso vira a 17.4b, e o portão da amostra passa para ela. Do sistema visual da 17.4 vale a paleta e a luz; a densidade troca o "meio livre" por cantos cheios e passagens livres.
- 2026-11-04 (17.4b, `d8a62b3`): a sala do tamanho certo.
  - **O tamanho:** `Home.ROOM_SIZE` = 9 × 7 m, teto de 3,0 m, para o loft e a cabana. Tudo o que encosta numa parede sai dele e de margens com nome: os lugares prontos (`ANCHORS`), a janela, a porta, o néon, as vigas (`BEAM_Z`, `BEAM_SIZE`), o ponto de nascer e o painel do sistema. Trocar o tamanho não pede mexer em outro número.
  - **A porta da rua saiu do meio da parede sul** e foi para perto do canto sudeste (`DOOR_X`). Centrada, ela deixava 3,85 m de cada lado, e a estante e o quadro de estatísticas têm 4,54 m: não cabiam. Os dois lugares da parede sul agora vão do canto oeste até a porta, cada um com espaço para um `WIDE_PIECE` (4,6 m) e o espelho, em qualquer ordem. O mural (5 m) só vai para oeste e leste, como em todas as disposições.
  - **A parede norte, de oeste para leste:** o canto de estar do tema (`LIVING_CORNER_WIDTH` = 3 m), a janela e o computador (`COMPUTER_SPOT`, a 10 cm da parede leste). A janela ficou com 2,95 × 1,9 m (antes, 5,2 × 2,4), do peitoril a 0,8 m até 0,3 m do teto, em 4 quadros; o `WindowView` e o shader não mudaram.
  - **As vigas e o néon:** as vigas ficaram mais baixas (0,16 m, antes 0,22) e o néon corre entre elas, junto do teto, em pedaços (uma malha por parede). O mural (`FIRST_ROW_Y` 1,0 → 0,78) e o quadro de estatísticas (`CENTER_Y` 1,75 → 1,48) desceram para caber abaixo das vigas, do mesmo tamanho. O painel do sistema ganhou `center_y`: a casa o põe no meio entre o alto dos monitores e o teto (2,24 m).
  - **O canto de estar do loft** é um grupo no canto noroeste (densidade: cantos cheios e passagens livres): o sofá encostado na parede norte, de frente para a sala; o abajur de pé colado no braço do lado do canto, com a planta de folha larga atrás dele; a palmeira do outro lado, na beira da janela; o tapete (3,2 × 2,9 m) pega o abajur, o sofá, a mesinha e um pufe novo de tricô; o pendente desce até 1,85 m sobre a mesinha; o quadro fica em cima do sofá. A manta voltou a cair pela frente, como na referência. O aparador foi para baixo da janela (as coisas em cima dele ficam na metade da frente, longe do peitoril), a espada entre ele e a mesa do computador, e a planta pequena no peitoril.
  - **O nascer** ficou em (0,9; 1,0), um pouco ao sul e a leste do meio, e o giro de cada disposição não mudou (35°, −35° e 130°): na padrão, a estante à esquerda, o sofá de frente com o abajur e a palmeira, e a janela à direita, como na referência 01. Nenhum `.tres` foi mexido.
  - **A cabana só coube** (o aconchego é da 17.9): a lareira foi da parede oeste para o canto de estar da parede norte, com o vaso no canto e as poltronas na frente dela; os lampiões seguem as vigas.
  - **A luz é a da 17.2**, com três ajustes para a sala menor: o abajur de pé alcança 5 m (antes 6), a luz fraca de cada pendente (a que acende a cúpula e o teto) subiu de 0,2 para 0,35 da força e alcança 4 m, e o alcance do cone do pendente é a altura da lâmpada mais 1,5 m (antes, 5 m fixos). Sem o ajuste do enchimento, o teto ficava preto (49% quase preto no nascer).
  - **Números** (22 h, Alta; média, 95% até e quase preto): nascer 43, 125 e 43% (17.4: 40, 90 e 35%; referência 01: 53, 126 e 24%); sofá 45, 123 e 40% (17.4: 37, 93 e 42%); estante 59, 173 e 25%; janela 37, 110 e 51%. Os claros chegaram aos da referência; o que ainda puxa para o preto é o teto e a janela à noite (a 17.5).
  - **Testes:** o `check_home` ganhou "os lugares prontos e o tamanho da sala" (cada lugar dentro da sala e encostado na parede do nome dele; os da parede sul entre o canto e a porta; a parede norte dividida sem encostar; a janela entre o chão e o teto; o nascer longe da porta e das paredes). As zonas da porta e da janela e as passagens saem do tamanho da sala. A conferência da cabana passou a valer para os móveis **das disposições do catálogo**, e não para cada móvel em cada um dos 6 lugares: na sala de 9 × 7 m, o mural de 5 m não cabe em todos os lugares, e nenhuma disposição o põe lá. O `capturar_casa` esconde o corpo do reflexo do espelho, como a câmera do jogador (perto do espelho, a captura saía de dentro da cabeça dele).
  - **Bateria completa: TUDO OK** (87).
  - **Medida no desktop** (`200 alta 22`): casa 165,0 FPS (teto), p99 8 ms, 130 desenhos (17.4: 110; o nascer novo enxerga mais capas da estante); espelho 165,0; montanha 161,7. **A caminhada deu 126,5 e 127,8** — mas o código de antes (1118688), medido na mesma hora num worktree, deu 126,8: a placa estava com 36% de uso e 9 GB ocupados antes de abrir o hub (um python e o NVIDIA Broadcast). A 17.4b não mexe na rua; a comparação com os 152,8 do começo da fase fica para uma medida com a placa livre.
  - **Revisão do Codex** (`/codex:review`, diff da branch contra a `fase-17`): nenhuma regressão concreta. Foi estática (sem rodar testes nem capturas).
  - **Capturas** em `game-hub-referencias\uau\depois-17.4b`: os 4 pontos às 13 h e às 22 h, a cabana às 22 h, os pontos de perto (`perto\`: frente do sofá, mesinha, a janela com o aparador, o canto do computador e a sala vista da porta) e a folha `folha_17.4b.png` (17.4, 17.4b e a referência 01).
  - **Fica de fora:** vista da porta, o meio-sul da sala (o caminho da porta até tudo) ainda é chão livre; ele é a passagem. Se o dono achar vazio, a próxima peça seria um tapete de entrada ou um banco junto da porta.
- 2026-11-04: o dono aprovou a amostra (a casa à noite, depois da 17.4b). Vale para o resto da fase o sistema visual registrado na 17.4 e na 17.4b: paleta de base fria com madeira e tecido quentes e pouco néon; luz em poças quentes com meio-tom frio entre elas; densidade em cantos cheios e passagens livres. Disparadas juntas a 17.5 (trilha A, Opus) e a 17.7 (trilha B, Astra, worktree `uau-b2`). Na 17.7, o `TrailDressing.setup` é chamado pelo `BackdropTerrain`, e não pelo `city.gd`: a B entrega uma função para receber a lista de jogos, e a A liga a lista (pelo `get_dressing()`) no merge.

- 2026-11-04 (17.5): a noite da cidade se lê.
  - **A causa do preto:** no Sky3D (o céu que você usa), a lua segue o céu de verdade. Às 22 h de hoje ela estava abaixo do horizonte (minguante), e a luz da lua era zero; a luz ambiente vinha quase toda do céu preto.
  - **O luar:** uma luz direcional fraca e fria (0,4), do alto (50°) e sem sombra. A cidade cria junto com o Sky3D, e o `DayNight` regula: acende com a noite e desconta a lua do Sky3D quando ela está no céu. No céu de fotos, a "lua" (o sol da cena) foi de 0,25 para 0,45.
  - **Névoa e ambiente da noite** (constantes do `DayNight`): névoa azul-marinho `#1E2C3A` (era `#080A12`) e um pouco menos densa (0,005; era 0,006); o céu pega mais da névoa à noite (`fog_sky_affect` 0,35; de dia segue 0,15); ambiente 1,1 no Sky3D (era 0,9) e 0,3 no de fotos (era 0,2).
  - **A torre e o chafariz:** quatro holofotes âmbar no chão, a 3,4 m do centro, apontados para a torre; uma luz no meio do chafariz e oito lâmpadas na água. Sem sombra e apagados de dia.
  - Nenhum bairro precisou de luz própria: nenhum campo novo no `DistrictProfile`.
  - **Fora da lista do plano:**
    - `skyline.gd`: o horizonte à noite virou azul-marinho. Com o céu mais azul, o preto virava um recorte de papelão.
    - `home_window.gdshader`: o ganho do retrato à noite foi de 2,2 para 1,6. Com a cidade legível, 2,2 deixava a neve da montanha com cara de dia.
    - `tools/capturar_pontos.gd`: espera 3,5 s depois de mudar a hora, porque o Sky3D leva 3 s para trocar a luz do céu. O "antes" refeito com a espera quase não mudou (praça 88%).
    - Testes: `check_sky3d` (o luar) e `check_landmarks` (as luzes da torre).
  - **Números** (22 h, Alta, Sky3D, 200 falsos; média, 95% até e quase preto; a régua toda em `uau-referencias.md`):
    - praça: 14, 54 e 92% → 48, 143 e 35% (referência 05: 53, 140 e 22%);
    - pórtico: 34, 131 e 52% → 47, 143 e 28%;
    - mirante: 17, 30 e 76% → 46, 93 e 26% (referência 04: 51, 127 e 20%);
    - a meta (quase preto abaixo de 35%, 95% perto de 100) foi batida nos três, a praça no limite. O que sobra de quase preto na praça é o céu, que ocupa metade do enquadramento;
    - no céu de fotos: praça 16%, pórtico 20% e mirante 31%;
    - a janela da casa: 37, 110 e 51% → 40, 111 e 40%. Aparecem a montanha nevada ao luar e a cidade.
  - **SSIL na cidade:** testado e descartado. A caminhada caiu 10% (234,9 → 211,3 FPS, sem VSync) e a montanha 14%, e a régua não mudou (praça 48,1 → 48,2).
  - **Medida no desktop:**
    - com VSync, tudo travou em ~60 FPS, o código de antes e o novo (até a casa, que fica no teto de 165). A tela não apresentava a 165 Hz: a sessão estava sem o dono, sem outra Godot medindo, e a GPU parada (0%), com o ComfyUI (8 GB carregados) e o NVIDIA Broadcast abertos;
    - medido então sem VSync (`--disable-vsync`), antes (`e362e97`) e depois na mesma hora: caminhada 236,8 → 234,9 FPS (−0,8%), p99 12 → 12 ms; casa 320,0 → 317,7; espelho 360,1 → 358,9; montanha 318,8 → 316,0;
    - **pendente:** confirmar com VSync, com você no PC, contra os 152,8 do começo da fase (a queda relativa de 0,8% indica ~151,6).
- 2026-11-04: o dono aprovou a 17.5. A trilha B (Astra) entregou a 17.7 em `5e3fc83` (worktree `uau-b2`, base `e362e97`): `TrailDressing.set_games(games: Array)`, chamada depois do `setup`, com os `SteamGame` do bairro (`district["games"]`), em ordem de horas na subida; testes `check_trail_content check_mountain_trail check_biome check_terrain` ok. A cota do ChatGPT acabou no meio (pausa das 1h às 9h) e o Orca reiniciou uma vez; nada se perdeu. O coordenador viu as capturas (`depois-17.7`): os estandartes ficaram bons, mas a fogueira está pequena e chapada, e a queda d'água parece uma cortina azul solta na neve. O dono decidiu: juntar e polir, numa sessão do Opus que revisa o diff, faz o merge, liga a lista no `city.gd` (montagem e `_rebuild_backdrop`) e melhora a fogueira e a queda d'água; a 17.6 vem depois, porque as duas mexem no `city.gd`. A medida da B ficou presa em 60 FPS pelo ambiente (a mesma trava de tela da 17.5); a medida com os 57 estandartes fica para a integração.
- 2026-11-04 (17.7, polimento e merge pela trilha A, Opus):
  - **Revisão do diff da B** (só leitura, antes do merge): nenhum bloqueio.
    - O `_process` do `TrailDressing` só liga enquanto há capas na fila (uma por quadro) e desliga sozinho: custo zero no resto do tempo.
    - Luzes: só a da fogueira (os estandartes não têm luz). Madeira e metal vêm do cache do `HomeMaterials`; o tecido é um por estandarte, mas é preciso (cada um tem a sua capa). As capas são as do `GameArt` (as mesmas dos prédios) e soltam com `set_games([])`.
    - Nada trava o caminho (o teste confere pegada e malhas); a regra 1 continua valendo (nenhum autoload novo).
    - **Achados corrigidos:** o tecido com `CULL_DISABLED` mostrava a capa **espelhada** por trás (o Skyrim de costas na captura da B): agora a frente é só frente e o verso é liso, num material só para todos. E cada pedra era uma malha e um desenho: agora as peças de cada parada se juntam num desenho por material (`TrailProps.Batch`).
  - **Integração:** o `city.gd` guarda os jogos do bairro da montanha e chama `set_games` quando a montagem termina e quando a montanha é refeita (troca de qualidade; os estandartes entram ainda escondidos). Sem jogos de RPG, a trilha fica só com o cenário. Biblioteca de verdade: 2 RPG, 2 estandartes; 200 falsos: 57.
  - **Decisão: a fogueira e a queda d'água passam da cerca.** A margem entre a trilha e a cerca tem só 0,5 m, e por isso a B fez tudo miúdo. Do lado de fora não se pisa (a parede invisível continua a 2 m), mas se vê de perto (1,5 m). Alargar a trilha nas paradas mexeria no terreno (`Heightfield`) e ficou de fora.
    - A escolha do lugar procura primeiro o que cada uma pede: a queda, um barranco que sobe (≥ 1,6 m); a fogueira, um chão que desce pouco. Sem isso, qualquer lugar com o lado de fora livre. Nos dois casos, o lado de fora não encosta em outra perna da trilha nem no mirante (`OUTER_AREAS`, `OUTER_REACH` = 6,6 m; o teste confere).
    - **Fogueira** (`campfire.gd`, classe `Campfire`, serve também ao mirante da 17.8): terraço de pedra seca que nivela a encosta, anel de pedras, terra queimada, lenha em pirâmide, brasa, chamas por shader (`campfire_flame.gdshader`: seis planos cruzados que somam luz, sem ordenar transparência) e luz quente (3,2, alcance 9 m) **com sombra**, que some aos 30 m; três bancos em volta, abertos para a trilha.
    - **Queda d'água:** rochedo de quatro blocos e uma laje por cima, 13 colunas de gelo (finas e grossas; algumas param no meio, como pingente), pingentes na borda e o pé de gelo acumulado junto da cerca. Gelo opaco e liso, com a geada da normal da neve.
    - **Monte de pedras:** destoava (bolas pretas empilhadas) e virou lajes chatas e claras. **Bancos:** os da B ficaram.
    - **Estandartes:** a fileira de 57 não pedia reagrupar (as paradas e os lampiões já quebram o ritmo); cada um sobe de 0 a 0,45 m pela ID do jogo, e a ordem por horas segue.
    - Nenhum asset novo.
  - **Medida no desktop** (`200 alta 22`, VSync, tela a 165 Hz, placa livre: 10% e 1,9 GB antes), antes (`33303f7`, worktree temporário) e depois na mesma hora: caminhada 155,8 → 155,3 FPS (−0,3%; começo da fase: 152,8), p99 10 → 10 ms; montanha 163,1 → 162,9, p99 8 → 9 ms, desenhos 255 → 354 (os 57 estandartes); casa e espelho no teto (165). **A pendência da 17.5 (confirmar com VSync) fica resolvida:** a caminhada está acima dos 152,8.
    - A Godot cai (segmentation fault) ao sair do `medir_desempenho.gd`, **depois** de imprimir tudo, também no código de antes: não é da 17.7.
  - **Bateria:** na 1ª rodada, o `check_mirror` falhou como instável (a triagem: passou ao rodar de novo, sem ligação com o diff); a 2ª deu `TUDO OK`.
  - **Capturas** em `game-hub-referencias\uau\depois-17.7b\` (`biblioteca\` e `falsos\`, 13 h e 22 h: as paradas, a fogueira de perto, um estandarte de frente e de costas, duas subidas e a trilha de longe) e a folha `folha_17.7b.png` (B, depois e a referência 03). As da B saíram mais quentes porque a base dela é anterior à noite da 17.5.
  - A 17.8 não precisa mais ligar a lista de jogos no `city.gd` (já feito aqui).
- 2026-11-04: o dono aprovou a 17.7 e abriu uma exceção ao fluxo congelado para o Blender (registrada no AGENTS.md), com um teste antes da 17.8 (17.7.1). Os modelos saem de scripts Python rodados sem janela, e não do MCP do Blender: um blog relata quatro falhas de segurança no MCP mais conhecido em 2026, e o script deixa cada modelo refazível. A licença do Blender diz que o que se cria com ele (incluindo `.blend` e os arquivos que ele escreve) é de quem cria, e que scripts que usam a API Python, se publicados, têm de ser GPL: por isso a pasta `tools/blender/` leva o LICENSE GPL-3.0. A 17.6 vem antes ou junto (é só luz).
- 2026-11-04 (17.6, `cf0eb4e`): o dia com contraste.
  - **A causa do dia chapado:** a luz do céu enchia as sombras (ambiente 1,0), a neblina lavava o fundo, a exposição estava em −0,3 EV e o AgX achatava os claros. Os 95% de nenhum ponto passavam de ~190.
  - **O que mudou, tudo no `DayNight`** (constantes; valem só no peso do dia do céu, e o pôr do sol e a noite saem com os valores de antes):
    - sol do dia 1,5 (era 1,0), um pouco mais quente (`FFEFD9`); no Sky3D, o `sun_energy` e a cor do sol seguem o mesmo peso;
    - luz ambiente do dia × 0,45 (`DAY_AMBIENT`): a sombra fica mais funda e mais fria;
    - contraste do AgX 1,55 de dia (o padrão, 1,25, à noite) e saturação 1,2 (`adjustment_saturation`). O ajuste de cor fica sempre ligado (à noite, saturação 1,0 não muda nada), para não trocar a variante do shader do tonemap no meio do pôr do sol;
    - exposição do dia +0,25 EV (era −0,3) e neblina do dia 0,0009 (era 0,0015);
    - céu de fotos: sombra do dia 0,8 (era 0,4). Conferido por captura (Ação, 13 h e 22 h): o dia abre igual e a noite sai idêntica.
  - **Nenhum bairro precisou de luz própria** (os três ganharam por igual): nenhum campo novo no `DistrictProfile`. O `city.gd` e o `building_facade.gdshader` não mudaram.
  - **Números** (13 h, Alta, Sky3D, 200 falsos; a tabela inteira em `uau-referencias.md`): a faixa (5% a 95%) abriu de 27 a 43 pontos em todos os pontos (ex.: Ação do alto 84 → 127, RPG do alto 92 → 120, Esportes do alto 133 → 171), sem nada estourar no branco (0%). Bairros: RPG (roxo, neve), Ação (laranja) e Esportes (verde).
  - **A noite não mudou:** as 22 h dos três bairros saem iguais ao antes; a diferença pixel a pixel fica só nos hologramas dos amigos, que se mexem entre as capturas.
  - **A janela da casa às 13 h** pega o dia novo pelo retrato (a montanha mais branca, a cidade com sombra); a luz de dentro da casa não muda (ela tem ambiente próprio).
  - **Teste:** o `check_daynight` ganhou "o dia com contraste": nos dois céus, de dia os valores novos; às 23 h, os da 17.5 (ambiente, contraste padrão, saturação 1,0, exposição).
  - **Medida no desktop** (`200 alta`, VSync, tela a 165 Hz), antes (`ea2074d`, worktree temporário) e depois na mesma hora, com a placa ocupada por outros programas (30–40% de uso: player de vídeo, NVIDIA Broadcast, navegador):
    - 22 h: caminhada 137,8 → 143,3 FPS, p99 14 → 13 ms; montanha 162,5 → 162,5; casa e espelho no teto (165);
    - 13 h: caminhada 134,5 → 140,2 FPS, p99 16 → 14 ms; montanha 162,3 → 162,6; casa e espelho no teto;
    - o código novo não é mais lento que o antigo (a diferença é ruído). Contra os 152,8 do começo da fase, 143,3 é −6% mesmo com a placa ocupada (dentro dos 10%), e o p99 fica ≤ 16,7 ms. Com a placa livre, a 17.7 deu 155,3.
  - **Bateria completa: TUDO OK** (88), na primeira rodada.
  - **Capturas** em `game-hub-referencias\uau\depois-17.6\`: `cima`, `portico`, `praca` e `mirante` às 13 h e às 22 h dos três bairros, os 4 pontos da casa às 13 h, o "antes" de tudo em `antes` e a folha `folha_17.6.png` (antes e depois, com a régua em cada imagem).
- 2026-11-05 (17.7.1, scripts `19fa5c2`, modelos `e11bd6b`, merge `5d19453`): o teste do Blender.
  - **O dono aprovou a 17.6** e decidiu, pelas capturas da 17.7.1: o Blender é o caminho de modelagem ("a qualidade subiu muito"). As regras foram para o AGENTS.md ("Assets"): o Blender faz a forma e a Godot o resto; um script refazível por modelo; materiais compartilhados; orçamento por peça (~300 KB pequena, ~800 KB grande), que cede se a forma piorar (a qualidade vem antes); plantas de preferência do Poly Haven; prédios e terreno fora, até virar fase.
  - **O que entrou:** `tools/blender/` (GPL-3.0, com o texto da licença copiado da instalação do Blender; `comum.py` e um script por modelo: `gerar_fogueira`, `gerar_terraco`, `gerar_bancos`, `gerar_monte_de_pedras`, ~50 s os quatro) e `assets/models/trail/` (4 `.glb` e 5 JPEGs que a Godot tirou da fogueira, ~1 MB no total; antes da redução eram 5,5 MB). No código: `trail_models.gd` (novo, lê as malhas por material), `campfire.gd`, `trail_dressing.gd` e `trail_props.gd` (saem as primitivas que os modelos substituem) e `home_wood.gdshader` (uma opção, desligada por padrão, para ler o veio de cada tábua do modelo; a casa não muda).
  - **O resultado:** o muro do terraço (pedra seca com fiadas e lajes) e os bancos (tábuas chanfradas, armação com travessas) ganharam mais; na lenha e no monte de pedras, a diferença é pequena de longe. A referência 04 segue longe porque lá o chão é um deque com abrigo: é a 17.8.
  - **Pendente para a 17.8:** não existe textura PBR de madeira em `assets/`. Os bancos usam a madeira por código da casa, com veio mais fraco que o da textura que o Blender assava. Decidir antes: uma madeira CC0 da ambientCG (1K, com a permissão do dono) ou uma textura de madeira assada no Blender, uma só para todos os modelos.
  - **Medida** (VSync, 165 Hz, `200 alta 22`, com a placa a 22% de uso antes): caminhada 146,8 → 146,1 FPS (−0,5%), montanha 162,1 → 162,3, desenhos da montanha 332 → 338. Numa rodada com a placa livre: 150,3 → 147,9.
  - **Testes:** o `check_trail_content` ganhou 8 casos (os modelos carregam, ficam no lugar da 17.7, um desenho por material em cada parada, nenhum corpo físico nas paradas, os andares do muro, o banco nivelado). Bateria completa no worktree: TUDO OK (88); depois do merge, com a 17.6, de novo no checkout principal: TUDO OK (88).
  - **Custo de sessão:** ~2 h, contando a montagem das ferramentas; com o `comum.py` pronto, cada modelo novo deve custar 20 a 40 min.
- 2026-11-05: o dono aprovou a 17.7.1 e escolheu, para a madeira dos modelos do Blender, uma textura CC0 da ambientCG em 1K (e não uma assada no Blender). A coordenadora compara as amostras e pede a permissão de download (nome, origem e tamanho) antes da 17.8.
- 2026-11-05 (17.8, scripts `680c5f2`, modelos e código `5bd31a8`, merge `5e1fc63`): o mirante como destino.
  - **O que entrou:** quatro modelos novos do Blender em `assets/models/lookout/` (`deck.glb` 38 KB, `shelter.glb` 690 KB, `lantern.glb` 40 KB, `telescope.glb` 120 KB; nenhuma textura nova), cada um com o seu script em `tools/blender/` (`gerar_deque`, `gerar_abrigo`, `gerar_lanterna`, `gerar_luneta`; o `comum.py` ganhou `orientar`/`tabua_entre`, `caixa`, `cilindro`, `tubo` e o `passo` da tábua). No código: `lookout_deck.gd` (reescrito), `lookout_telescope.gd` e `telescope_view.gdshader` (novos), `trail_models.gd` (a Wood049, o metal, `arrays`, `prefetch`, `stretched`), `trail_props.gd` (`Merge`), `trail_dressing.gd` (os arcos do anel sem estacas; o destaque e a noite repassados ao mirante) e `backdrop_terrain.gd` (o mirante monta em pedaços). O `city.gd` não mudou.
  - **O mirante:**
    - um **deque redondo** de tábuas no disco inteiro (raio 9,25 m), recortado em volta da torre (o buraco fica 15 cm por dentro dela, para a borda recortada se esconder) e onde a trilha chega (ali o chão desce até 0,4 m; o deque para onde o chão fica mais de 4 cm abaixo, e uma fileira de tábuas acompanha o corte). Uma borda de tábuas curtas em volta deixa o círculo liso. A plataforma em balanço continua quando cabe;
    - o **guarda-corpo de madeira** (poste, corrimão, régua de baixo e X) na borda do disco e na plataforma; as estacas e a corda ficam só nos lados da trilha;
    - o **abrigo** (pilares, tesoura aparente, telhado de tábuas com neve, parede do fundo, meias-paredes, banco por dentro) e, na frente dele, a **fogueira** da 17.7.1 com dois bancos: o lugar é escolhido longe de onde a trilha chega, de lado para a vista, fora da torre e de três caminhos livres (do centro até a chegada, até a luneta e até a ponta);
    - a **luneta de latão** na ponta da plataforma (ou, sem ela, na borda do disco virada para a praça). E entra no foco pelo `player.focus_on` que já existe: a câmera desliza da ocular para a frente, 55% do caminho até a praça (parando 12 m antes do que estiver no meio), com o campo da luneta (um círculo com borda escura) e a dica de voltar. Esc ou E voltam. **O contrato do `player.gd` não mudou:** em vez de mudar o FOV (o `CameraFeel` o refaz a cada quadro), a câmera anda pela linha da vista;
    - o **RPG mais jogado** numa tapeçaria com a capa (pelo `GameArt`) na parede do fundo do abrigo, com o nome e as horas embaixo; sem jogos de RPG, o abrigo fica só com a parede. Biblioteca de verdade: Skyrim Special Edition, 135 h;
    - **luzes:** a fogueira (com sombra) e 5 lanternas sem sombra (2 no abrigo, 2 nos postes de onde a trilha chega e 1 junto da luneta).
  - **A madeira:** a Wood049 em todos os modelos (deque, abrigo, guarda-corpo e os bancos da 17.7.1), tingida por material: o piso mais gasto e acinzentado e liso como madeira úmida (pega o brilho do fogo e das lanternas, como na referência 04), o abrigo e os bancos mais escuros. **Achado:** a Wood049 tinha sido importada sem compressão, sem mipmaps e com o normal map em "detectar"; agora segue as outras texturas da ambientCG (VRAM, mipmaps, normal map).
  - **A biblioteca de verdade é outro mirante:** a trilha chega pela frente do disco e a plataforma não cabe (já era assim antes: o "antes" da biblioteca não tinha plataforma nenhuma). A frente vira a chegada da trilha (neve), e a luneta fica na borda ao lado.
  - **Números da régua** (22 h, Alta): o abrigo 47,6 de média, 95% até 100, 19% quase preto (referência 04: 51, 127, 20%). Na chegada, o quase preto subiu (falsos 45% → 50%; biblioteca 34% → 36%): a neve clara deu lugar à madeira escura, e o enquadramento pega a torre e a encosta escuras; a média caiu de 43 para 33. De perto do fogo e do abrigo, a régua bate com a referência.
  - **Medida no desktop** (`200 alta 22`, VSync, tela a 165 Hz, placa livre: 4% e 1,7 GB antes, 6% depois), antes (`044d6d8`, worktree temporário) e depois na mesma hora, duas rodadas alternadas: caminhada 160,3 / 158,9 → 160,0 / 159,4 FPS (começo da fase: 152,8), p99 9–10 → 9 ms; montanha 163,2 / 163,1 → 163,0 / 163,1, p99 9–10 ms, desenhos 355–359 → 359–360; casa e espelho no teto (165). Montagem 7,8 → 7,9–8,1 s, quadros acima de 50 ms 3–4 → 4.
    - **A montagem em pedaços:** a primeira versão montava o mirante num quadro só e, com janela, cada pedaço levava 60–170 ms (11 quadros acima de 50 ms). A causa: a cada tábua o código lia a malha de volta do servidor de desenho (`surface_get_arrays`). Agora cada peça é lida uma vez (`TrailModels.arrays`), as tábuas vão direto para arrays (`TrailProps.Merge`), os `.glb` carregam em segundo plano enquanto o piso monta, e o mirante monta em 9 pedaços.
  - **Testes:** `check_lookout` (novo: os modelos e o orçamento, o deque, o abrigo e as luzes, a luneta com E/Esc de verdade, o destaque com e sem jogos, o jogador andando da trilha até a luneta, o mirante sem a plataforma e o número de desenhos); `check_mountain_trail` (as estacas só nos lados, os arcos com guarda-corpo, os raios da plataforma pulam a luneta), `check_trail_content` (os bancos com a Wood049) e `check_textures` (conta a Wood049). Bateria completa no worktree: TUDO OK (89; na 1ª rodada o `check_textures` falhou só pela contagem das texturas da ambientCG, que não sabia da Wood049 da base `044d6d8`: contagem corrigida para 35).
  - **Capturas** em `game-hub-referencias\uau\depois-17.8\` (`falsos\` e `biblioteca\`, 13 h e 22 h: mirante, chegada, de longe, abrigo, fogo, tapeçaria, luneta, a vista da luneta e a fogueira da trilha), o "antes" em `antes\` e a folha `folha_17.8.png` (antes, depois e a referência 04, com a régua em cada imagem). O script das capturas ficou ao lado (`capturar_mirante.gd`).
  - **Ficou de fora:** um zoom de verdade (FOV) na luneta pediria uma função nova no contrato do foco (`get_camera_fov`), que fica para quando você quiser; mexer a luneta com o mouse; neve acumulada nas bordas do deque; a frente do mirante da biblioteca de verdade em madeira (ali o chão é a trilha, que desce).
- 2026-11-05: o dono aprovou a 17.8 e pediu para anotar a ideia dos prédios no Blender (`docs/ideias/predios-no-blender.md`). Ficam para quando ele voltar: (1) corrigir numa 17.8.1 pequena ou deixar para a 17.10 o que a coordenadora viu nas capturas (a torre do mirante é um bloco liso e escuro, agora bem à vista; a madeira do deque laranja demais, e de dia com cara de nova; o círculo claro em volta da fogueira, que parece areia sobre a madeira); (2) o zoom de verdade (FOV) na luneta, que muda o contrato do foco no `player.gd`; (3) a 17.9 no Codex (Astra), porque o limite semanal do Claude Pro estava em 91% (volta em 2026-11-08, 6h); (4) o teste do SSR, da névoa volumétrica e do SDFGI na Alta, que saiu da conversa sobre a RTX 4070 (o fork RTX da NVIDIA fica fora: é outra Godot, só para placas RTX, e o fluxo está congelado).

- 2026-11-07 (retomada): bateria completa no checkout principal, depois do merge da 17.8: **RESULTADO GERAL: TUDO OK (89 testes)**. Compositor Rust pulado no Windows. Fechamento da 17.8 registrado; o worktree `mirante` já está integrado, mas foi preservado porque contém arquivos não rastreados em `.agents/`. A ideia dos prédios no Blender já estava salva no commit `a715692`.

- 2026-11-08: o dono aprovou a preparação da 17.9 (feita pelo Codex em 2026-11-07) e escolheu o Opus para implementar (o limite do Claude Pro voltou):
  - **Luz de dia:** a janela domina, com sombra e tons mais neutros; as luminárias ficam de apoio quente; nos dois temas, sem mudar a noite do loft.
  - **Cabana:** lareira, duas poltronas e madeira continuam; o âmbar fica perto do fogo e dos lampiões, sombras mais frias, tecidos menos saturados e objetos pequenos no canto de estar.
  - **Vista da cabana:** comparar a montanha de verdade (o retrato que já existe) com a floresta do shader, às 13 h e às 22 h; sem floresta 3D nem ponto de captura novo.
  - **Blender:** uma poltrona (usada duas vezes) e a lareira, com a Wood049; o sofá do loft e as plantas ficam para outra aprovação.
  - **Pendências da 17.8** (torre do mirante, cor do deque, círculo da fogueira) vão para a 17.10; o zoom por FOV e o teste de SSR, névoa volumétrica e SDFGI esperam escopo próprio.
  - **Divisão:** 17.9.1 (luz de dia e vista, trilha A) e 17.9.2 (acabamento da cabana, trilha A), com a aprovação do dono entre elas; os modelos (17.9.1b) correm em paralelo na trilha B.

- 2026-11-08 (17.9.1, `b74c25a`): a luz de dia na casa.
  - **O sol:** uma luz de cone estreito do lado de fora, a 14 m da janela, mirando o vão (40° de altura, 14° do norte para o oeste), sem perder força com a distância e com sombra. A parede norte virou quatro pedaços em volta do vão (uma colisão sem desenho tapa o vão para quem anda; as texturas são projetadas pelo mundo, sem costura): a parede e os quadros da janela desenham a janela no chão de madeira, entre o aparador e quem nasce, fora do tapete (o pelo do tapete vira chuvisco no sol; o teste confere). A casa não sabe onde está o sol do mundo: ele entra sempre do mesmo jeito. No pôr do sol ele esquenta.
  - **A luz rebatida:** uma luz sem sombra sobe do meio da mancha para o teto e a parede da janela. O céu (a luz fria que já existia) agora cai mais devagar e chega à parede do fundo.
  - **As luminárias de apoio:** de dia, todas as luzes da sala (menos as do dia e o fogo da cabana) ficam na metade da força (`lamp_day_scale` = 0,5); a força da noite fica guardada em cada uma, e o reflexo no vidro usa sempre a da noite.
  - **Perfis:** o `HomeProfile` ganhou `sun_color`, `sun_energy`, `sun_bounce` e `lamp_day_scale`. No `loft.tres` e no `cabana.tres` entraram só linhas de valor no `[resource]` (à mão, como na 17.2; nenhum id mudou): sol 8, rebatida 0,4, ambiente do dia neutro (0,62; 0,64; 0,68) a 1,2 no loft e (0,62; 0,64; 0,66) a 1,1 na cabana, céu 3,0. Os geradores antigos (`tools/gerar_perfis_casa.gd`, `gerar_cabana.gd`) já estavam desatualizados desde a 17.2 e não foram mexidos.
  - **A vista da cabana:** as duas funcionam e estão capturadas. O `capturar_casa.gd` ganhou o 6º argumento `vista` (`tema`, `retrato` ou `floresta`), que troca a vista só na memória daquela captura (nada é gravado). O retrato na cabana é o mesmo ponto da cidade do loft (sem ponto novo): de dia, a montanha nevada e a cidade lá embaixo; à noite, a montanha ao luar e a cidade acesa. Lê como "uma cabana no alto do morro, olhando a cidade", e não como chão de floresta. A escolha fica para a 17.9.2.
  - **Números** (Alta, 200 falsos; média, 95% até e quase preto; o antes em `antes-17.9\`, o código de `76202d6`):
    - loft 13 h: nascer 61, 204, 24% → 69, 215, 16%; janela 74, 217, 32% → 84, 218, 16% (a pendência da 17.2, em volta da janela de dia quase preto, resolvida); sofá 78, 220, 12% → 89, 223, 10%; estante 63, 178, 20% → 53, 157, 32% (o fundo da sala, de costas para a janela, ficou mais escuro com as luminárias de apoio);
    - cabana 13 h: nascer 53, 135, 14% → 69, 178, 16%; janela 60, 172, 15% → 73, 175, 13%; sofá 49, 143, 22% → 64, 187, 25%; estante 56, 176, 25% → 48, 162, 35%;
    - **22 h igual:** a estante do loft sai idêntica pixel a pixel; o nascer, o sofá e a janela diferem em 0,05–0,6% dos pixels, só na vista da cidade (que se mexe). Na cabana, a diferença é o fogo tremulando e o relógio da parede;
    - a vista da cabana: floresta 13 h 73, 175, 13% e 22 h 40, 84, 33%; retrato 13 h 92, 219, 13% e 22 h 46, 89, 19%.
  - **Medida no desktop** (`200 alta`, VSync, 165 Hz, placa livre: 2–4% e 1,7 GB antes), antes (`76202d6`, worktree temporário) e depois: 22 h caminhada 154,7 → 155,7 FPS, p99 10 → 10 ms, casa e espelho no teto (165), montanha 162,8 → 162,8; 13 h caminhada 152,1 → 149,9 (p99 11 → 12 ms), casa e espelho no teto, montanha 162,9 → 162,9. Sem VSync, às 13 h, o custo de verdade do sol na casa: 296,7 → 288,0 FPS (−2,9%, ~0,1 ms), espelho 336,4 → 328,1, caminhada 220,1 → 217,4. Desenhos da casa de dia 203 → 208.
  - **Testes:** o `check_home_profile` ganhou "o dia no loft" e "o dia na cabana" (o sol com sombra fora da sala mirando o meio da janela, o vão sem parede, a colisão, o vidro sem sombra, a mancha no chão e fora do tapete, as luminárias na metade de dia e inteiras à noite, nenhuma luz do dia à noite, o fogo de fora) e "as vistas da cabana" (as duas montam; só o retrato liga o `WindowView`); o `check_capture_home` confere que a vista trocada volta no fim. **Bateria completa:** na 1ª rodada o `check_city_map` deu erro de script e a triagem o deu como instável (passou ao rodar de novo, sem ligação com o diff); a 2ª deu `TUDO OK` (89).
  - **Capturas** em `game-hub-referencias\uau\depois-17.9.1\` (loft, cabana e cabana-retrato, 4 pontos, 13 h e 22 h), o antes em `antes-17.9\`, os logs da medida e da bateria, e a folha `folha_17.9.1.png` (antes e depois com a régua, e a vista da cabana nas duas opções).
  - **Fica para a 17.9.2:** a escolha da vista; se o fundo da sala de dia (a estante) deve ficar mais claro (subir `lamp_day_scale` ou o ambiente); o tom laranja da cabana de dia (os tecidos e o âmbar são da 17.9.2).
- 2026-11-08 (17.9.1b, `2ccc53a`, merge `fe0d2f5`): a poltrona e a lareira feitas no Blender, pela trilha B (Codex/Astra, worktree `cabana-modelos`).
  - **O que entrou:** `tools/blender/gerar_poltrona.py` e `gerar_lareira.py` (o `comum.py` só ganhou funções: `ajustar_caixa`, `almofada`, `tabua_casa_entre`, `cordao`, `previa_casa`) e `assets/models/home/` (`armchair.glb` 259 KiB, `wood` e `fabric`, 10.764 triângulos; `fireplace.glb` 228 KiB, `stone`, `wood`, `soot` e `iron`, 9.118 triângulos), com `LICENSE` (MIT) e o `README.md` do contrato. Nenhum download: a madeira é a Wood049, a pedra a Rock058 e o tecido o `HomeMaterials.fabric`, que já existiam.
  - **O contrato para a 17.9.2** (em `assets/models/home/README.md`): as medidas e o referencial das peças por código da cabana (poltrona com a frente em −Z; lareira com a parede em x = 0 e a frente em +X); o fogo, a luz, o lampião do consolo, a chaminé (que acompanha `Home.ROOM_SIZE.y`) e as colisões continuam em código; a grade de ferro já vem no modelo (tirar a feita por caixas); a casa terá o seu próprio leitor, sem `trail_models.gd`.
  - **Revisão da coordenadora** (diff e prévias em `game-hub-referencias\uau\depois-17.9.1b\`): a poltrona tem madeira aparente e estofado arredondado; a lareira, pedras aparelhadas, soleira e consolo. A conferir sob a luz da cabana: as pedras grandes, com cara de bloco, e os veios alaranjados da Rock058.
  - **O Codex bateu no limite de uso** antes dos testes; a coordenadora rodou `check_home_models` e `check_textures` (TUDO OK) e fez o commit. A bateria completa da B ficou para depois do merge (a B só criou arquivos, e assim as duas trilhas não disputaram a Godot).
  - **Bateria completa depois do merge da 17.9.1 e da 17.9.1b:** a 1ª rodada deu `check_home_view` com erro de script (`Nil` em `PackedVector3Array`, no `add_mesh` do `home_shapes.gd`, da 17.4); a triagem o deu como instável, sem ligação com o diff (passou ao rodar de novo). Na 1ª rodada da 17.9.1, o instável foi o `check_city_map`. Na 2ª rodada completa, no checkout principal: **RESULTADO GERAL: TUDO OK (90 testes)**, contando o `check_home_models`. O worktree `cabana-modelos` e a branch foram apagados.
- 2026-11-08: **o dono aprovou a 17.9.1** e respondeu as pendências da 17.9.2:
  - **Vista da cabana: a montanha de verdade (o retrato)**, mas a cabana fica **no nível do chão**: a montanha tem que parecer mais alta na janela (mais montanha, menos cidade de cima). Primeiro tentar pelo enquadramento do retrato; se só um ponto de vista mais baixo vender o "nível do chão", ele pode entrar (sem floresta 3D), registrado aqui.
  - **O fundo da sala de dia (a estante) fica como está:** a luz indireta está ótima.

## Checklist de teste manual (fim da fase)
1. Abra o hub à noite (pausa › Noite). Na casa: luz quente, sombras, objetos; pela janela, a cidade de verdade acende quando fica pronta.
2. Saia para a praça: chão, chafariz e torre visíveis, a noite ainda é noite.
3. Mude para Dia: os bairros têm claro e escuro distintos.
4. Vá ao RPG e suba a trilha: paradas e os seus jogos de RPG no caminho.
5. No mirante: o seu RPG mais jogado em destaque, a fogueira, e a luneta (E) aproximando a cidade.
6. Troque para a cabana pelo computador: o mesmo aconchego.
