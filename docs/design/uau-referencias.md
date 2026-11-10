# Referências do "uau" (Fase 17.1, 2026-11-03)

O que cada imagem de referência ensina, o sistema visual que sai delas e o "antes" medido. É a base da [Fase 17](../plans/fase-17.md): a casa (17.2 a 17.4), a noite da cidade (17.5), a trilha (17.7) e o mirante (17.8).

**As imagens não estão no repositório**, e nada delas entra no jogo: são só referência. Ficam em `C:\Projetos\game-hub-referencias\uau\` (ao lado do repositório):
- `01_casa_noite.png` … `05_praca_noite.png`: as cinco escolhidas pelo dono, em 2026-11-03;
- `rodada-1\` e `rodada-2\`: todas as tentativas, com as folhas de comparação;
- `antes\`: as capturas do hub de hoje (veja "O antes").

## Como foram feitas
- **Modelo:** FLUX 3 Image Klein (Black Forest Labs, 15/10/2026), versão destilada int8. Roda no ComfyUI local, na RTX 4070 (12 GB), a ~7 s por imagem em 1536 × 864. Venceu o Z-Image Turbo numa comparação de 20 imagens:
  - chão seco dentro de casa (o Z-Image molhava a sala);
  - todos os elementos pedidos na trilha;
  - uma praça mais legível;
  - e o dobro da velocidade.
- **Sem a interface:** o ComfyUI rodou como servidor e recebeu os pedidos pela API. O script de geração ficou fora do repositório.
- **Prompts:** os cinco do plano, com o bloco comum "noite elegante". Duas mudanças:
  - "não ter texto nem pessoas" foi dito no texto positivo, porque com CFG 1 o prompt negativo é ignorado;
  - "molhado" ficou só para as cenas de fora.
- **Licença:** a FLUX Kommunity License permite o uso. As imagens ficam fora do repositório e não são publicadas.

## O sistema visual (o que vale para a fase toda)

### Claro e escuro (medido nas cinco imagens)
A régua é a luminância de 0 a 255 (preto a branco), medida em toda a imagem.

| | Casa | Janela | Trilha | Mirante | Praça |
|---|---|---|---|---|---|
| Média | 51 | 56 | 70 | 51 | 53 |
| 5% mais escuros até | 8 | 12 | 17 | 16 | 16 |
| Mediana | 44 | 48 | 69 | 41 | 43 |
| 95% até | 118 | 132 | 131 | 116 | 130 |
| Quase preto (< 25) | 24% | 22% | 11% | 17% | 20% |

**A regra:** a noite é escura na média (~50), mas **só ~20% da imagem é quase preta** e os pontos claros chegam a ~120–130. Ninguém estoura no branco (0–1%). O escuro fica nos cantos e no céu, e o chão, a fachada e o objeto principal ficam no meio-tom.

### Cores, por papel
- **Base fria (sombra, céu, neve):** azul-acinzentado `#0F1C24`, `#1E313E`, `#344E64`, `#536175`. A sombra nunca é preto puro nem cinza neutro: ela puxa para o azul.
- **Base quente (madeira, tijolo, tecido sob a luz):** `#2B1910`, `#5C3621`, `#654836`, `#9D7054`.
- **Luz quente (lâmpadas, fogo, janelas acesas):** âmbar `#E0A060`, `#C08040`, `#E08040`. É o acento dominante.
- **Néon (os bairros):** magenta `#C00060`/`#A02060`, ciano, violeta. **É pouco:** os acentos vivos somam de 0,7% a 2,9% da imagem, e quase tudo é âmbar. O néon é tempero e marca os bairros; não ilumina a cena.

### Luz
- **Fontes principais e motivadas:** cada área clara tem uma fonte visível (abajur, pendente, fogueira, poste, holofote na torre). Não há luz "do nada".
- **Poças de luz:** uma área clara e quente embaixo de cada fonte, com queda suave até o escuro. Entre duas poças, o meio-tom frio.
- **Quente perto, frio longe:** o primeiro plano é quente (interior, fogo, lanternas), e o fundo é frio (céu, neve, montanha).
- **Holofote de baixo para cima** nos marcos (a torre do relógio, a torre do mirante): o marco se lê de longe à noite.
- **Reflexo no chão molhado** só fora de casa. Ele dobra a luz dos postes e do néon sem acrescentar fontes.

### Densidade e materiais
- **Casa:** cantos cheios e passagens livres (17.4b; antes, "tudo encostado nas paredes, com o meio livre"): o canto de estar é um grupo no canto, com o sofá encostado e visto de frente; estante cheia, sofá com manta e almofadas, mesa de centro com caneca e livros, 3–4 plantas, tapete. Parede de tijolo à vista, chão de madeira encerado (seco), tecido fosco.
- **Fora:** madeira escura e gasta, pedra, neve azulada; os metais com brilho (luneta de latão).
- **Leitura de longe:** marcos altos e acesos (torres), caminhos marcados por fileiras de luz (lanternas da trilha, postes da praça).

### O que NÃO copiar
- Texto, letreiros e logotipos que a IA inventa (a casa da rodada 2 `s6006` tem um).
- Nevoeiro e reflexos "de filme" pesados demais: no jogo, cada efeito custa quadro e tem que caber na meta.
- Prédios de cidade grande e arranha-céus: a nossa cidade é compacta, de prédios baixos por bairro.
- Uma lua grande e próxima: no céu do jogo ela não ganha esse destaque.
- Qualquer detalhe que só funciona numa imagem parada (vapor, faíscas exageradas).

## Cada imagem

### 01 Casa à noite → 17.2, 17.4
- **Ensina:** três fontes quentes (abajur, dois pendentes) fazem poças no sofá e no tapete. O néon é uma linha fina na parede de tijolo. A janela é um quadro frio e grande com a cidade e a montanha. A estante colorida dá ritmo à parede da esquerda.
- **Para o código:** sombras no abajur e num pendente; o tijolo e a madeira mais quentes; a manta, as almofadas e as plantas (17.4).
- **Não copiar:** o quadro na parede direita e o comprimento da sala (a nossa é menor).

### 02 A vista da janela → 17.3
- **Ensina:** a cidade vista de cima, com cada bairro na sua cor, a torre do relógio no meio e a trilha de lanternas subindo a montanha até o mirante. A cortina e o parapeito quentes emolduram o frio.
- **Para o código:** o ponto `window_view_point` precisa enquadrar a torre do relógio, os bairros e a trilha acesa. Um véu leve no vidro, com o reflexo da sala.

### 03 A trilha à noite → 17.7
- **Ensina:** a cerca de estacas e cordas com lanternas baixas faz um caminho de luz. Os estandartes coloridos, altos, ficam dos dois lados. Uma parada (pilha de pedras, banco, fogueira) aparece no fim de cada trecho, e a cascata congelada fica ao fundo. A neve azulada é o meio-tom.
- **Para o código:** os estandartes com as capas dos jogos de RPG no lugar das cores; as paradas a intervalos; a lanterna a cada ~8–10 m, e não a cada 15 pontos.

### 04 O mirante à noite → 17.8
- **Ensina:** o deque com guarda-corpo na borda; o abrigo de madeira com lanternas e a fogueira com bancos em volta; a luneta de latão em primeiro plano, apontada para a cidade; a torre com coroa de néon atrás. A cidade inteira brilha embaixo: é a recompensa.
- **Para o código:** a fogueira como luz principal (quente, com sombra); a luneta com E (`focus_on`); o RPG mais jogado em destaque.

### 05 A praça à noite → 17.5
- **Ensina:** a torre do relógio com holofote de baixo; o chafariz aceso no centro; o chão de pedra molhado refletindo os postes e o néon; postes a intervalos regulares; árvores e canteiros com bancos. Chão, torre e chafariz se leem, e a noite continua noite.
- **Para o código:** a luz própria da torre e do chafariz; postes em volta da praça, não só nos 4 cantos; o ambiente da noite menos preto (veja "O antes").

## O antes (capturas e medida de 2026-11-03)
**Capturas:** `tools/capturar_pontos.gd`, bairro RPG, 200 jogos falsos, Alta, 13 h e 22 h, em `game-hub-referencias\uau\antes\`.
- A casa foi capturada depois, pela ferramenta da 17.1b (veja "A casa: antes e depois da 17.2").
- Medidas com a mesma régua das referências:

| | Média | Mediana | 95% até | Quase preto | Referência (quase preto) |
|---|---|---|---|---|---|
| Praça do RPG 22 h | 14 | 6 | 60 | **91%** | 20% |
| Mirante 22 h | 17 | 17 | 29 | **77%** | 17% |
| Pórtico do RPG 22 h | 34 | 24 | 119 | 52% | — |
| Praça do RPG 13 h | 126 | 130 | 197 | 0% | — |
| Do alto 13 h | 158 | 174 | 187 | 0% | — |

- **À noite, a praça e o mirante são quase só preto:** 91% e 77% da imagem, contra ~20% nas referências.
  - O mirante não tem ponto claro nenhum: 95% da imagem fica abaixo de 29.
  - É a C1 da revisão de 2026-11-02, agora com número. **Meta da 17.5:** quase preto abaixo de 35% e os 95% chegando a ~100, nos mesmos pontos.
- **De dia, o alto é chapado:** do mais escuro (95) ao mais claro (187) a faixa é curta, tudo é meio-tom claro. É a C2. **Meta da 17.6:** abrir essa faixa (sombras mais fundas) sem estourar o branco.

**Desempenho no desktop** (`medir_desempenho.gd -- 200 alta 22`, 2560 × 1440, VSync a 165 Hz, Ryzen 5 5600 + RTX 4070, com o editor da Godot aberto). As metas da fase se comparam com estas linhas:

| Trecho | FPS médio | p99 | Pior | Desenhos |
|---|---|---|---|---|
| Caminhada | 152,8 | 11 ms | 34 ms | 1725 |
| Casa | 164,9 (teto) | 8 ms | 8 ms | 100 |
| Espelho | 165,0 (teto) | 7 ms | 7 ms | 92 |
| Montanha (trilha e mirante) | 163,0 | 9 ms | 19 ms | 251 |

Montagem da cidade: 6865 ms. Memória de textura: ~1 GB.

## A casa: antes e depois da 17.2
Loft, 22 h, Alta, 200 jogos falsos, mesma régua. O "depois" está em `game-hub-referencias\uau\depois-17.2\`.

| Ponto | Média (antes → depois) | 95% até | Quase preto |
|---|---|---|---|
| nascer | 34 → 40 | 74 → 93 | 38% → 29% |
| sofá | 41 → 39 | 90 → 100 | 22% → 37% |
| estante | 28 → 32 | 82 → 116 | 59% → 61% |
| janela | 35 → 31 | 79 → 74 | 39% → 47% |
| **Referência (casa)** | **51** | **118** | **24%** |

- O claro e escuro abriu: as poças e as luminárias chegam mais alto, e o meio da sala ficou em meio-tom.
- No sofá e na janela, o quase preto subiu. É o canto de estar longe das poças e o céu do shader da janela, quase preto. A 17.3 troca a vista; a 17.4 põe objetos.

## A casa: os objetos da 17.4
Loft, 22 h, Alta, 200 jogos falsos, mesma régua (medida de novo nas imagens, por isso a 17.3.1 difere um pouco da tabela acima). O "depois" está em `game-hub-referencias\uau\depois-17.4\`, com os pontos de perto em `perto\` e a folha `folha_17.4.png`.

| Ponto | Média (17.3.1 → 17.4) | 95% até | Quase preto |
|---|---|---|---|
| nascer | 38 → 38 | 86 → 87 | 38% → 39% |
| sofá | 35 → 35 | 90 → 91 | 50% → 48% |
| estante | 33 → 36 | 116 → 118 | 61% → 52% |
| janela | 26 → 27 | 70 → 73 | 63% → 62% |
| **Referência (casa)** | **51** | **122** | **26%** |

- Os objetos quase não mexem na régua: eles enchem a sala, mas a luz é a mesma da 17.2. O quase preto que sobra está no teto, no canto do computador e na janela à noite (a cidade escura, que é da 17.5).
- Nada foi baixado: tudo é código (`HomeShapes`, `HomePlants`, dois shaders novos).

## A cidade à noite: depois da 17.5
Bairro RPG, 22 h, Alta, céu Sky3D, 200 jogos falsos, mesma régua. O "depois" está em `game-hub-referencias\uau\depois-17.5\`, com a folha `folha_17.5.png` (antes, depois e referência).

| Ponto | Média (antes → depois) | 95% até | Quase preto | Referência (quase preto) |
|---|---|---|---|---|
| Praça | 14 → 48 | 54 → 143 | 92% → 35% | 22% |
| Pórtico | 34 → 47 | 131 → 143 | 52% → 28% | — |
| Mirante | 17 → 46 | 30 → 93 | 76% → 26% | 20% |
| Janela da casa | 37 → 40 | 110 → 111 | 51% → 40% | 23% |

- O que mudou: o luar (a lua do Sky3D segue o céu de verdade e muitas noites está abaixo do horizonte), a névoa azul-marinho, o céu azul-noite e a luz própria da torre e do chafariz.
- A neve do mirante pega o luar e virou o meio-tom azulado das referências. A noite continua escura na média (~47), com o céu azul-noite e as estrelas.
- O que ainda falta contra as referências: os pontos quentes de perto (fogueira e lanternas no mirante, a 17.8) e o chão molhado refletindo as luzes na praça.

## O dia: depois da 17.6
13 h, Alta, céu Sky3D, 200 jogos falsos, mesma régua (faixa = dos 5% mais escuros aos 95%). O "antes" é o código de `ea2074d`, tirado na mesma sessão. Tudo em `game-hub-referencias\uau\depois-17.6\` (o antes em `antes\`), com a folha `folha_17.6.png`.

| Ponto | Média (antes → depois) | 5% | 95% até | Faixa | Estourado (> 245) |
|---|---|---|---|---|---|
| RPG do alto | 157 → 180 | 93 → 93 | 185 → 213 | 92 → 120 | 0% |
| RPG pórtico | 105 → 120 | 53 → 46 | 192 → 212 | 139 → 166 | 0% |
| Ação do alto | 102 → 114 | 58 → 47 | 142 → 174 | 84 → 127 | 0% |
| Ação pórtico | 88 → 100 | 27 → 19 | 183 → 203 | 156 → 184 | 0% |
| Esportes do alto | 124 → 140 | 52 → 42 | 185 → 213 | 133 → 171 | 0% |
| Esportes pórtico | 71 → 80 | 28 → 19 | 128 → 153 | 100 → 134 | 0% |
| Janela da casa | 66 → 74 | 4 → 5 | 183 → 217 | 179 → 212 | 0% |

- **A meta da 17.6 foi batida:** a faixa abriu de 27 a 43 pontos em todos os pontos, as sombras desceram e os claros subiram, sem nada estourar no branco.
- O que mudou: o sol mais forte e um pouco quente, menos luz do céu nas sombras, a curva do tonemap mais em "S", cores um pouco mais vivas e menos neblina de dia. Nenhum bairro precisou de luz própria.
- **A noite não mudou:** as 22 h dos três bairros saem iguais ao antes; o que difere é só onde os hologramas dos amigos se mexeram.

## Manifesto de assets candidatos (CC0, Poly Haven, glTF 1k)
**Nada é baixado sem a permissão do dono**, como manda o AGENTS.md. A pergunta é feita na subetapa que precisar, depois de tentar por código. Os tamanhos são do download de 1k, conferidos pela API do Poly Haven em 2026-11-03. Fica fora: livro decorativo (`decorative_book_set_01`), que não tem glTF.

| Para | Asset | Tamanho |
|---|---|---|
| 17.4 casa | `potted_plant_01`, `potted_plant_02` (plantas em vaso) | 6,3 + 2,6 MB |
| 17.4 casa | `throw_pillows_01` (almofadas) | 1,2 MB |
| 17.4 casa | `book_encyclopedia_set_01` (livros) | 3,3 MB |
| 17.4 casa | `hanging_industrial_lamp` (pendente) | 3,2 MB |
| 17.4 casa | `ceramic_vase_01`, `wooden_bowl_01`, `standing_picture_frame_01` (objetos de mesa) | 0,4 + 1,8 + 0,4 MB |
| 17.7, 17.8 | `Lantern_01`, `wooden_lantern_01` (lanternas) | 1,4 + 3,8 MB |
| 17.7, 17.8 | `wooden_crate_01` (caixote) | 2,3 MB |

São ~27 MB se entrar tudo, dentro do orçamento de ~50 MB da fase. A manta e a caneca não têm modelo no Poly Haven: ficam por código. Para a luneta não há modelo: código (cilindros de latão) ou outra fonte CC0, a pesquisar na 17.8.

## Notas do dono
- 2026-11-03: escolheu as cinco sugestões ("ficaram ótimas").
- O `notas.txt` ("gosto disso por causa de ___") é opcional. Se ele escrever, as frases entram aqui e pesam mais que a leitura acima.
