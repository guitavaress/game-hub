# Fase 17: O momento uau

**Status:** aprovado em 2026-11-02; em andamento
**Branch:** `fase-17`, criada da `origin/main` (`c74d6ae`, o merge do PR #2 da Fase 16).

## Para o dono (até 10 linhas)
- **O que você vai ver:** uma casa aconchegante à noite, com luz quente, objetos e a **cidade de verdade** pela janela, acendendo quando fica pronta. Uma praça e um mirante que se leem à noite, e um dia com contraste. Uma trilha com lugares para parar e com os seus jogos de RPG no caminho, até um mirante que recompensa a subida.
- **Agora:** 17.1 e 17.1b feitas: as 5 referências estão em `C:\Projetos\game-hub-referencias\uau\`, e o que cada uma ensina, em [uau-referencias.md](../design/uau-referencias.md). O "antes" da casa já está em `game-hub-referencias\uau\antes\`. **17.2 feita:** a casa à noite com poças de luz quente e sombras; o "depois" está em `game-hub-referencias\uau\depois-17.2\`. Próxima: 17.3 (a cidade de verdade pela janela).
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
- [ ] **17.3 A cidade de verdade pela janela** (grande · trilha A, Opus · high · revisão: Astra, `/codex:adversarial-review`, porque cria um contrato entre a casa e o mundo e um shader novo)
  - Arquivos: `components/window_view/window_view.gd` (novo), `worlds/home/home_window.gdshader` (amostra o retrato; o procedural fica de reserva), `worlds/home/home.gd` (usa o componente), `worlds/city/city.gd` (põe o ponto no grupo `window_view_point`), `tests/check_window_view.gd` (novo: sem ponto → procedural; com ponto → `UPDATE_ONCE`, sem a camada 20, refeito só na troca de fase do dia; a casa não referencia `worlds/city`).
  - Captura: a janela às 13 h e às 22 h, e o momento em que a cidade acende.
  - Commit: `Fase 17.3: a janela mostra a cidade de verdade`
- [ ] **17.4 Objetos da casa e aprovação da amostra** (grande se entrar asset · trilha A, Opus · high · revisão: você)
  - Faz: o que as referências pedirem e a luz sozinha não resolveu (plantas, livros, manta, objetos de mesa, um tapete melhor). Primeiro por código; modelo CC0 só com a sua permissão (nome, origem, tamanho), com `LICENSE` e crédito no README.
  - **Portão:** você aprova a casa à noite. Se não, volta à 17.2. Aprovada, o plano registra o sistema visual (paleta, luz, densidade) que vale para o resto.
  - Commit: `Fase 17.4: a casa ganha vida` (+ `Assets: <pacote> (CC0)` se houver)
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

## Checklist de teste manual (fim da fase)
1. Abra o hub à noite (pausa › Noite). Na casa: luz quente, sombras, objetos; pela janela, a cidade de verdade acende quando fica pronta.
2. Saia para a praça: chão, chafariz e torre visíveis, a noite ainda é noite.
3. Mude para Dia: os bairros têm claro e escuro distintos.
4. Vá ao RPG e suba a trilha: paradas e os seus jogos de RPG no caminho.
5. No mirante: o seu RPG mais jogado em destaque, a fogueira, e a luneta (E) aproximando a cidade.
6. Troque para a cabana pelo computador: o mesmo aconchego.
