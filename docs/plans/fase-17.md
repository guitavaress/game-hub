# Fase 17: O momento uau

**Status:** aprovado em 2026-11-02; em andamento
**Branch:** `fase-17`, criada da `origin/main` (`c74d6ae`, o merge do PR #2 da Fase 16).

## Para o dono (até 10 linhas)
- **O que você vai ver:** uma casa aconchegante à noite, com luz quente, objetos e a **cidade de verdade** pela janela, acendendo quando fica pronta. Uma praça e um mirante que se leem à noite, e um dia com contraste. Uma trilha com lugares para parar e com os seus jogos de RPG no caminho, até um mirante que recompensa a subida.
- **Agora:** 17.1 e 17.1b feitas: as 5 referências estão em `C:\Projetos\game-hub-referencias\uau\`, e o que cada uma ensina, em [uau-referencias.md](../design/uau-referencias.md). O "antes" da casa já está em `game-hub-referencias\uau\antes\`. **17.2 feita:** a casa à noite com poças de luz quente e sombras; o "depois" está em `game-hub-referencias\uau\depois-17.2\`. **17.3 feita:** a janela mostra a cidade de verdade, que acende quando fica pronta; o "depois" está em `game-hub-referencias\uau\depois-17.3\`. **17.3.1 feita:** as placas dos bairros saíram da janela. **17.4 feita:** sofá, manta, mesinha com caneca e livros, tapete antigo, um canto de leitura com aparador, quadro e palmeira, e mais três plantas, tudo por código; o "depois" está em `game-hub-referencias\uau\depois-17.4\` (com a folha `folha_17.4.png`). **17.4b em andamento:** você achou a sala grande demais e sem aconchego; ela encolhe para 9 × 7 m com teto de 3,0 m (a cabana junto), e os móveis viram cantos agrupados. **Espera você:** aprovar a amostra depois da 17.4b.
- **Ordem:** referências → **amostra = a casa à noite com a janela** (você aprova) → luz da cidade → trilha e mirante → casa de dia e cabana.
- **Para testar:** cada subetapa traz capturas de antes e depois e o próprio checklist.
- **Decisões que esperam você:** aprovar a amostra (17.4); os assets CC0 que a amostra pedir (nome, origem e tamanho antes de baixar).

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
- [ ] **17.4b A sala do tamanho certo** (grande · trilha A, Opus, sessão nova · high · revisão: Astra, `/codex:review`, porque muda a geometria e os lugares prontos de que dependem as disposições, o computador e o painel; e você, pelas capturas) — pedido do dono ao ver a 17.4: o tamanho da sala e a posição dos móveis não dão aconchego.
  - Faz: a sala vai de 12 × 9 m, teto 3,4 m, para **9 × 7 m, teto 3,0 m**, no loft e na cabana (um tamanho só). Os lugares prontos (`ANCHORS`), a janela, a porta, os néons, as luzes e o painel passam a sair do tamanho da sala, sem números soltos. O sofá deixa de flutuar no meio de costas para quem entra: vira um **canto de estar agrupado** (o sofá visto de frente ou de lado por quem nasce, o abajur e uma planta colados nele, um tapete grande sob o sofá e a mesinha, o pendente mais baixo sobre a mesinha). A regra de densidade da 17.4 ("meio livre") vira **cantos cheios e passagens livres**.
  - Arquivos: `worlds/home/home.gd`, `worlds/home/themes/loft_decor.gd`, `worlds/home/themes/cabin_decor.gd` (só para caber; o tratamento é da 17.9), os móveis de `worlds/home/` se algum não couber, `profiles/home_catalog.tres` só se o giro de nascer precisar mudar, `tools/capturar_casa.gd` e os testes da casa (`check_home`, `check_home_profile`, `check_computer_desk`, `check_system_panel`, `check_capture_home`).
  - Captura: os 4 pontos às 22 h e às 13 h em `depois-17.4b`, lado a lado com a 17.4 e a referência 01; a cabana às 22 h, para ver que coube.
  - **Portão:** a aprovação da amostra passa para cá.
  - Commit: `Fase 17.4b: a sala do tamanho certo`
- [ ] **17.5 A noite da cidade** (grande · trilha A, Opus, sessão nova · high · revisão: você, pelas capturas)
  - Faz (C1): noite legível sem deixar de ser noite. Névoa e ambiente noturnos menos pretos, luz própria na torre do relógio e no centro da praça, a lua e a neve no mirante. Teste rápido de SSIL na Alta na cidade, com medida; fica só se couber na meta.
  - Arquivos: `worlds/city/day_night.gd`, `worlds/city/city.gd` (ambiente), `worlds/city/plaza_clock_tower.gd`, `worlds/city/city_decor.gd` (praça), `profiles/biomes/montanha.tres` se preciso.
  - Teste: bateria completa (atenção a `check_daynight`, `check_night_life`, `check_biome_atmosphere`, `check_sky3d`, `check_graphics_quality`); medida no desktop.
  - Captura: praça, pórtico e mirante às 22 h, antes e depois.
  - Commit: `Fase 17.5: a praça e o mirante se leem à noite`
- [ ] **17.6 O dia com contraste** (grande · trilha A, Opus · high · revisão: você)
  - Faz (C2): exposição, céu, sombra e contraste dos materiais que existem; diferenças por bairro só se a captura pedir (campo novo no `DistrictProfile` → volta ao modo plano).
  - Arquivos: `worlds/city/day_night.gd`, `worlds/city/city.gd`, `worlds/city/building_facade.gdshader` se preciso.
  - Captura: `cima` e `portico` às 13 h de 3 bairros, antes e depois.
  - Commit: `Fase 17.6: o dia com contraste`
- [ ] **17.7 A trilha com conteúdo** (grande · trilha B, Astra · high, worktree novo `worktree/uau-b2` saído da `fase-17` depois da 17.4 · revisão: Opus lê o diff antes do merge) — em paralelo com a 17.5 e a 17.6.
  - Faz: pontos de parada (fogueira, ruína ou monte de pedras, uma queda d'água congelada, bancos) e os seus jogos de RPG no caminho (estandartes ou lanternas com as capas, em ordem de horas). Segue o sistema visual aprovado na 17.4.
  - Arquivos: `worlds/city/biome/trail_dressing.gd`, `worlds/city/biome/trail_banner.gd` (novo), `tests/check_trail_content.gd` (novo). A lista de jogos entra pelo `setup` que o `city.gd` já chama (a mudança de uma linha no `city.gd` fica com a A, no merge).
  - Teste: `check_trail_content check_mountain_trail check_biome check_terrain`; captura da subida às 13 h e às 22 h.
  - Commit: `Fase 17.7: a trilha com paradas e com os seus jogos`
- [ ] **17.8 O mirante** (grande · trilha A, Opus · high · revisão: você, pelas capturas)
  - Faz: um destino que recompensa a subida. O jogo de RPG mais jogado em destaque, abrigo de madeira, fogueira, lanternas e uma luneta (E aproxima a vista, pelo `focus_on` que já existe).
  - Arquivos: `worlds/city/biome/lookout_deck.gd`, `worlds/city/city.gd` (merge da 17.7 e a lista de jogos), `tests/check_mountain_trail.gd`.
  - Captura: o ponto `mirante` às 13 h e às 22 h, antes e depois.
  - Commit: `Fase 17.8: o mirante como destino`
- [ ] **17.9 A casa de dia e a cabana** (grande · trilha A, Opus · medium · revisão: você)
  - Faz: o sistema da amostra de dia (luz da janela, a vista às 13 h) e na cabana (a vista dela: a floresta do shader ou a montanha de verdade, decidido pela captura).
  - Arquivos: `worlds/home/home.gd`, `worlds/home/themes/cabin_decor.gd`, `profiles/homes/cabana.tres`.
  - Commit: `Fase 17.9: a casa de dia e a cabana`
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

## Checklist de teste manual (fim da fase)
1. Abra o hub à noite (pausa › Noite). Na casa: luz quente, sombras, objetos; pela janela, a cidade de verdade acende quando fica pronta.
2. Saia para a praça: chão, chafariz e torre visíveis, a noite ainda é noite.
3. Mude para Dia: os bairros têm claro e escuro distintos.
4. Vá ao RPG e suba a trilha: paradas e os seus jogos de RPG no caminho.
5. No mirante: o seu RPG mais jogado em destaque, a fogueira, e a luneta (E) aproximando a cidade.
6. Troque para a cabana pelo computador: o mesmo aconchego.
