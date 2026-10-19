# Bioma montanha: direção de arte e manifesto (Fase 15.0)

**Data:** 2026-10-17 · **Plano:** [fase-15.md](../plans/fase-15.md) · **Skill:** `create-game-assets`
**Status:** amostra **aprovada** pelo dono em 2026-10-19 (capturas refeitas no desktop); família completa no repositório.

## Moldura técnica
- **Motor:** Godot 4.7.2, Forward+, primeira pessoa (olho a 1,7 m, FOV do `player.gd`).
- **Escala da cidade:** lote de 14 m, quarteirão de 28 m, rua de 10 m, andar de 3,5 m (térreo 3,6 m). Prédios do RPG têm 4 a 6 andares (~18 a 25 m).
- **Meta de desempenho:** desktop na Alta (regra do projeto). O notebook na Leve só compara antes e depois.
- **Plataformas:** Windows e Linux.

## A ideia em uma frase
Uma **vila de pedra nevada ao pé de uma montanha fria**, onde a única luz quente é o **néon roxo do RPG**. De dia é branca e azulada; à noite, azul-escura, com os arcos e os lampiões em roxo e âmbar baixo.

## Sistema visual

### Formas
- **Pinheiros:** cones estreitos e escuros, em pé, mais altos que largos (proporção ~1:3). Leem como "ponta de flecha" contra o céu e contra a neve.
- **Rochas:** blocos baixos e largos, de quinas quebradas. Nunca redondas como seixo, nunca mais altas que o jogador dentro do bairro.
- **Arcos:** pedra, já existentes (`ArchShell`), com a capa do jogo (15.5) e neve por cima (15.7).
- **Montanha:** silhueta com um pico só, puxando o olho para o norte. A torre do RPG no mirante é o ponto mais alto do lado de cá.

### Valores (claro e escuro)
- O chão de neve é o **plano mais claro** da cena; nada pode competir com ele em claridade, senão a neve vira papel branco.
- Pinheiros e rochas são os **escuros**: é o contraste deles com a neve que desenha o bairro.
- O céu fica entre os dois (o HDRI de hoje). A névoa do bioma puxa o fundo para o tom do céu, e o pico aparece por cima dela.

### Paleta (papéis e cores)
| Papel | Cor | Observação |
|---|---|---|
| Neve iluminada | `#BCC5D2` (tinta sobre a textura) | albedo ≤ 0,85 (plano, 15.12); levemente azul. Ajustada na amostra: com `#D6DEE8` a neve virava papel branco |
| Neve na sombra | sai da luz, não da textura | a sombra azul vem do céu; não pintar azul na textura |
| Rocha | cinza-azulado frio, ~`#5E6670` | sem marrom forte nem musgo verde |
| Pinheiro | verde muito escuro, quase preto | a foto do atlas é verde-oliva; a tinta (0,45; 0,55; 0,55) no shader escurece e esfria (amostra). Vai para o `ScatterSpec.tint` |
| Calçada de pedra | a `PavingStones070` de hoje, puxada para cinza | já está no projeto |
| **Luz quente única** | néon do RPG `#934CFF` (roxo) | arcos, letreiro, pórtico e torre |
| Lampiões da trilha | âmbar baixo, `#FFB060`, pouca energia | só à noite (grupo `city_night`); guiam, não iluminam o bairro |
| Névoa do bioma | do `DayNight`, misturada a um azul frio | 15.12 |
| Pé da montanha | escurece até o `Outskirts` (`#15171C`) | não brigar com o chão de fora |

### Materiais
- **PBR, como a cidade:** cor, relevo (NormalGL) e rugosidade da ambientCG ou da Poly Haven, em 1K. Nada de cor chapada sem textura ao lado de um prédio PBR.
- **Neve:** rugosidade alta (fosca), relevo suave; nada de brilho de gelo.
- **Neve por cima** de rochas e arcos: pela normal do mundo (15.7), sem pintar neve na textura da rocha.
- **Iluminação nunca vem na textura** (sem sombra ou brilho "assado" na cor).

### Detalhe e foco
- No bairro, o detalhe fica **perto das portas e do pórtico** (o caminho do jogador). Pinheiros e rochas ficam nos cantos dos lotes e nas vagas, **nunca na frente de uma porta, de um poste, do pórtico ou da estação** (15.7).
- Na montanha, menos detalhe e mais silhueta: grupos de pinheiros na encosta baixa, rocha à mostra nas encostas íngremes (`snow_slope`), neve no alto.

### Movimento
- Neve caindo devagar e na diagonal do vento; flocos macios (15.11).
- Pinheiros balançam pouco, mais na ponta, cada um no seu tempo (15.7).
- Nada pisca: a névoa e o vento entram e saem suaves pela distância (15.12).

### Fica de fora
- Gelo brilhante, pingentes, neve fofa acumulando, pegadas (fora do escopo da fase).
- Cor quente que não seja o roxo do RPG ou o âmbar baixo dos lampiões.
- Rocha marrom, laranja ou com musgo verde forte.
- Pinheiro de desenho animado (cor chapada, cone liso) ao lado da cidade fotográfica.

## Contrato técnico
| Item | Regra |
|---|---|
| Texturas de superfície | ambientCG 1K-JPG; só **Color, NormalGL e Roughness** entram no repositório (como a `PavingStones070`) |
| Importação | compressão de placa (VRAM) e mipmaps; NormalGL com a compressão de relevo (o `check_textures` confere) |
| Pinheiro | **impostor** (2 triângulos por árvore), atlas de 4 × 2 quadros de 512 px gerado pelo `tools/make_tree_impostor.gd`, saída `assets/generated/pine_impostor.png` + `.json`. O glTF fica **fora do repositório** |
| Rocha | malha leve (≤ 8 mil triângulos), em MultiMesh; colisão é um cilindro ou caixa simples, nunca a malha |
| Escala | pinheiro no bairro: 8 a 14 m (o prédio mais baixo do RPG tem ~18 m); na montanha: 10 a 18 m. Rocha no bairro: 0,6 a 1,5 m de altura; na montanha: até 4 m |
| Orçamento de textura do bioma | **≤ 16 MB de VRAM** a mais (Alta), somando neve, rocha, atlas do pinheiro e a rocha 3D |
| Pastas | `assets/ambientcg/<Id>/`, `assets/polyhaven/models/<id>/`, `assets/generated/pine_impostor.*`; LICENSE em cada pasta de origem e crédito no README |

## Os 3 pontos de vista de referência
Capturados pelo `tools/capturar_pontos.gd` (novo nesta subetapa), com 200 jogos falsos, na Alta, às 13h e às 22h. As imagens ficam **só na pasta temporária da sessão** (têm capas de jogos).

| Ponto | Onde fica a câmera | O que tem de dar certo no fim da fase |
|---|---|---|
| **Praça** | no meio da praça, de lado para o obelisco, olhando para o bairro | a torre do RPG e o pico aparecem por cima dos telhados; o bairro já se lê "frio" de longe |
| **Pórtico** | na rua, 12 m antes do pórtico, olhando para dentro | neve no chão, arcos com capa, pinheiros e névoa; o roxo é a luz mais forte |
| **Mirante** | no mirante, olhando para a praça (depois da 15.9) | a cidade lá embaixo, a torre do relógio ao fundo; a vista é o prêmio |

Há também um ponto **de cima** (60 m), que mostra o bairro inteiro com a cidade em volta; serve para conferir o layout em setores (15.4).

### Antes (2026-10-17, layout em anéis)
- **Praça, dia:** a torre do RPG aparece no meio, por cima dos prédios, com o letreiro "RPG E FANTASIA" ao lado. É um bom começo para a linha de visão: quando o RPG for ao norte, ela tem de continuar visível.
- **Pórtico, dia e noite:** rua de asfalto entre prédios de tijolo, com faixas roxas e estandartes. À noite, chuva (garoa) e poças refletindo. Nada diz "montanha" ainda.
- **De cima:** o RPG está espalhado num anel em volta da praça (o problema que a 15.4 resolve).

## Manifesto dos assets
Situação: `planejado` → `amostra` (baixado para testar) → `aprovado` (o dono aprovou) → `no jogo`.

| Id | Papel | Origem (CC0) | Tamanho do download | Entra no repo | Situação |
|---|---|---|---|---|---|
| `Snow010A` | chão de neve e "neve por cima" | [ambientCG](https://ambientcg.com/view?id=Snow010A), 1K-JPG | 6,6 MB (zip) | 3,1 MB (3 mapas) | aprovado |
| `fir_sapling_medium` | pinheiro (fonte do impostor) | [Poly Haven](https://polyhaven.com/a/fir_sapling_medium), glTF 1K | 78 MB | **não** (em `~/git/game-hub-fontes/`) | aprovado |
| `pine_impostor.png/.json` | atlas do pinheiro (árvore "a", 8,8 m) | gerado pelo `make_tree_impostor.gd` | — | 1,8 MB | aprovado |
| `moon_rock_02` | rocha 3D (só a forma; 3,3 mil triângulos, 25 cm, escala ×5) | [Poly Haven](https://polyhaven.com/a/moon_rock_02), glTF 1K | 1,5 MB | 1,5 MB | aprovado |
| `Rock058` | rocha das encostas e da rocha 3D (triplanar) | [ambientCG](https://ambientcg.com/view?id=Rock058), 1K-JPG | 8,0 MB (zip) | 3,9 MB (3 mapas) | aprovado |
| `footstep_snow_000..004` | passos na neve | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) (o pacote do projeto não tinha os de neve) | 0,8 MB (zip) | 39 KB (5 `.ogg`) | aprovado (entra no jogo na 15.12) |
| `wind_loop.wav` | vento | já no projeto (gerado) | — | — | no jogo |
| `PavingStones070` | calçada de pedra | já no projeto | — | — | no jogo |

### Por que estes
- **Pinheiro:** o `fir_sapling_medium` tem copa cônica e cheia, e o download é de 78 MB. O `fir_tree_01` (19 m, mais "adulto") pesa **487 MB** e tem o tronco pelado embaixo; o `pine_sapling_medium` (268 MB) é ralo. Os três arquivos trazem **três árvores lado a lado**, então o `make_tree_impostor.gd` vai ganhar um argumento para fotografar só uma delas (mudança pequena no tool, sem mudar o atlas de hoje).
- **Rocha:** quase todas as rochas da Poly Haven são marrons ou alaranjadas (fogem da paleta) e pesadas (23 mil a 2 milhões de triângulos). A `moon_rock_02` é cinza, leve (~6 mil) e de forma quebrada. Com a textura `Rock058` em triplanar, ela fica **igual à rocha das encostas da montanha**, e a neve por cima amarra as duas. Se a amostra mostrar que ela parece "lua", o plano B é a `rock_09` (23 mil triângulos, 2 MB) ou o `rock_large*` do Kenney.
- **Neve:** a `Snow010A` é limpa, branca e tem relevo de neve pisada, que aparece bem a 1,7 m do chão. A `Snow004` (mais lisa) é a reserva.
- **Rocha das encostas:** a `Rock058` é a única das cinzas que é **fria** (cinza-azulada) e sem musgo. A `Rock035` é quase preta; as outras têm verde.

### O que a amostra mostrou (2026-10-17)
A amostra é montada **por cima do bairro RPG de verdade**, só durante a captura, por um script descartável que estende o `tools/capturar_pontos.gd` (`_prepare()`): neve nas ruas e no miolo dos quarteirões, grupos de pinheiros e rochas. Cinco pontos (praça, pórtico, de cima e "perto" de um bosque), às 13h e às 22h, com 200 jogos falsos, na Alta, em 1600 × 900.

| Asset | Resultado | Decisão |
|---|---|---|
| Neve | com a tinta `#D6DEE8` virava uma folha branca e lisa. Com `#BCC5D2`, relevo × 1,6 e ladrilho de 3 m, a textura aparece de dia; à noite fica azulada sob os postes | `#BCC5D2`, relevo 1,6, 3 m |
| Rocha 3D | com a textura própria, a `moon_rock_02` sai **bege** (foge da paleta). Com a `Rock058` em triplanar e neve por cima, fica cinza-azulada com o topo branco e combina com a calçada e os prédios | forma da `moon_rock_02` + material da `Rock058` com neve por cima. As texturas próprias dela não são usadas |
| Pinheiro | de 10 m para longe, lê bem como pinheiro escuro contra o céu e a neve. A menos de ~6 m mostra que é uma foto (achatado, com galhos ralos) | serve; os pinheiros ficam a **6 m ou mais** de onde se anda (portas, calçadas, trilha). Neve "assada" no atlas **não** é necessária |
| Calçada | a calçada de placas bege de hoje fica quente demais ao lado da neve | na 15.6, a calçada do bioma usa a `PavingStones070` puxada para cinza (`path_tint`) |

**Refeita no desktop (2026-10-19):** o script descartável foi escrito de novo (o do notebook não foi para o repositório) e rodou no Windows, na Alta, nos mesmos pontos e horas. Confirma a tabela: a neve tem relevo de dia, a rocha fica cinza-azulada com o topo branco, o pinheiro lê bem a 9 m e mostra que é foto a 5 m, e a calçada bege fica quente ao lado da neve. Às 22h a luz ficou de crepúsculo, e não de noite fechada (vem do `DayNight`, não dos assets).

Os números da tabela viram dados do `montanha.tres` na 15.1 (tinta, relevo e metros da neve; tinta do pinheiro; quanto de neve por cima).

## Aprovação
- **Brief:** aprovado junto com a amostra (2026-10-19).
- **Amostra:** aprovada pelo dono em 2026-10-19, pelas capturas refeitas no desktop (pasta temporária da sessão, fora do repositório).
- **Família completa:** 2026-10-19. A família era a amostra mais os `footstep_snow_000..004`, baixados com a permissão do dono.
