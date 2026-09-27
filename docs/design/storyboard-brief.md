# Game Hub — briefing de design (v2: direção "semi-realista + noite elegante")

> Documento para o **Claude Design**, segunda rodada. Na v1 o hub usava assets **Kenney** (low-poly "fofo") e o dono achou o resultado **infantil**. Escolhemos então uma nova direção e fizemos uma **prova de conceito jogável** numa branch separada (`prova-visual-1-3`).
> Este briefing descreve essa prova, **as ferramentas usadas** e o que queremos refinar.
> Imagens em `referencias/`:
> - `antes/`: visual Kenney;
> - `prova_1-3/`: visual novo;
> - `comparacao/`: os dois lado a lado, **mesmo enquadramento**.
>
> São prints reais do hub, e os amigos que aparecem neles são **fictícios**.

---

## 0. O que mudou da v1 para a prova

| Aspecto | Antes (Kenney) | Prova "1+3" |
|---|---|---|
| Céu | cores geradas (`ProceduralSkyMaterial`) | **3 fotos HDRI reais** (dia com nuvens, pôr do sol, noite estrelada com Via Láctea), misturadas pela hora |
| Prédios | caixas coloridas, com janelas desenhadas por código | **concreto claro, concreto bege ou tijolo** (PBR), janelas de **vidro** que refletem o céu, **faixas de néon** na cor do bairro (topo e acima do térreo) |
| Letreiro | nome do jogo em texto 3D com contorno grosso | **logo oficial do jogo** (PNG transparente da Steam); se não houver logo, o nome em Barlow Condensed |
| Chão | cores lisas | **asfalto, piso e placas de pedra** (PBR), com o asfalto "molhado" à noite (reflexos) |
| Postes | modelo Kenney | **postes modernos feitos por código** (haste fina, LED) com luz em cone no chão |
| Árvores | Kenney verde-menta, soltas, com flores | Kenney **recoloridas em verde escuro**, em **floreiras de concreto**, e bancos (praças "de bolso") |
| Amigos | personagens Kenney "cabeçudos" | **hologramas**: silhueta translúcida com linhas de varredura, avatar da Steam no rosto, projetor no chão, cor por status |
| Tipografia | fonte padrão da Godot | **Barlow / Barlow Condensed** (OFL) no HUD e nas placas |
| HUD | texto solto sob a mira (brigava com a porta) | **cartão** discreto embaixo (nome + "23 h jogadas · jogado hoje"), avisos em painel escuro com barra de cor |
| Luz | tonemap Filmic, glow | **tonemap AgX**, **reflexos (SSR)**, **neblina** por hora do dia, SSAO, glow |
| Sons | Kenney | continuam Kenney; só a vinheta "infantil" de pizzicato foi trocada por um som de interface |

**Veredito do dono até aqui:** gostou da direção. A tarefa agora é **refinar e decidir** o que falta (seção 5).

---

## 1. O que é o Game Hub (resumo)

Launcher da biblioteca Steam em forma de **cidade 3D em primeira pessoa**:
- **Cada jogo instalado é um prédio**, com a capa e o logo na fachada. Os prédios ficam em **bairros por categoria** (as tags da Steam decidem).
- **Entrar pela porta** escurece a tela em 1,5 s e abre o jogo pela Steam. O hub minimiza e, quando o jogo fecha, volta com o jogador **na porta do mesmo prédio**.
- **Amigos da Steam** aparecem como hologramas: na porta do jogo que estão jogando, ou em volta do chafariz se estiverem online sem jogar.
- **Dia e noite** seguem o relógio do PC (F8 adianta 3 h). Há som ambiente 3D por bairro e horas jogadas no HUD.
- **Futuro:** um mundo aberto com **biomas por gênero** (montanha de gelo para o Skyrim, cidade medieval, pista de corrida…). A linguagem visual tem que funcionar lá também.
- **Quem implementa** tem conhecimento básico de programação, então as propostas precisam ser **modulares**, uma por vez.

---

## 2. Ferramentas (ênfase deste briefing)

### 2.1 Godot 4.7.2 (GDScript, Forward+, física Jolt): quem faz o quê na prova
| Elemento | Como é feito (nó / recurso) |
|---|---|
| Céu | **shader de céu** `sky_blend.gdshader`: 3 texturas HDRI; o script `DayNight` muda os "pesos" a cada segundo (as estrelas só entram depois do pôr do sol) |
| Fachadas | **shader espacial** `building_facade.gdshader` numa caixa `CSGBox3D`: textura PBR projetada pela posição no mundo, grade de janelas (célula de 3 × 3,5 m) com vidro reflexivo e moldura, janelas acesas sorteadas à noite, **2 faixas de néon** (topo e térreo) |
| Porta | vão recortado (CSG) com concreto escuro; painel de luz na cor do bairro; moldura de metal escuro com filete de néon |
| Letreiro | `Sprite3D` com o `logo.png` do jogo (fallback: `Label3D` em Barlow Condensed) |
| Capa | `QuadMesh` *unshaded* (capa 600×900 da Steam) com moldura de metal |
| Chão | `StandardMaterial3D` com texturas PBR (cor, relevo, rugosidade) em **projeção triplanar**; a rugosidade do asfalto cai à noite para ficar "molhado" |
| Postes | geometria simples por código + `SpotLight3D` (luz em cone) + LED emissivo; acendem à noite |
| Amigos | **shader** `hologram.gdshader` (aditivo, borda "fresnel", varredura) em cápsula + esfera; `Sprite3D` do avatar; projetor com anel emissivo (`TorusMesh`) |
| Letreiros dos bairros | `Label3D` *billboard* em Barlow Condensed, cor de néon mais forte à noite |
| HUD | `CanvasLayer` + `PanelContainer` + `StyleBoxFlat` (fundo escuro translúcido, cantos de 6 px, barra de cor nos avisos); fonte pelo tema do projeto |
| Ambiente | `WorldEnvironment`: tonemap **AgX**, glow, SSAO, **SSR**, neblina (mais densa e azulada à noite) |
| Som | `AudioStreamPlayer3D` por portal (motor, cartas, vento, pássaros…) |

Também disponíveis para propostas simples:
- **Visual:** `GPUParticles3D`, `Decal`, `FogVolume` e névoa volumétrica, `Tween` e `AnimationPlayer`, shaders simples, `ReflectionProbe`, `LightmapGI`.
- **Interface:** `SubViewport` (por exemplo, para um minimapa).

### 2.2 Assets (todos gratuitos e podem ir para o repositório público)
| Fonte | Licença | O que usamos |
|---|---|---|
| **Poly Haven** (HDRIs) | CC0 | `kloofendal_48d_partly_cloudy_puresky` (dia), `belfast_sunset_puresky` (pôr do sol), `rogland_clear_night` (noite), todos em 2K |
| **ambientCG** (materiais PBR) | CC0 | `Road012A` (asfalto), `Bricks097` (tijolo), `Concrete034` / `Concrete048` (concreto), `Tiles139` / `Tiles141` (piso), todos em 1K |
| **Google Fonts** | OFL | Barlow (Medium, SemiBold) e Barlow Condensed SemiBold |
| **Kenney** | CC0 | sons; árvores e arbustos da Nature Kit, provisoriamente |

Podem ser propostos (grátis):
- mais **HDRIs** e **materiais** da Poly Haven e da ambientCG, como outro céu de pôr do sol mais quente ou fachadas prontas;
- **Quaternius** (CC0), low-poly adulto (*Downtown City MegaKit*, *Universal Base Characters*);
- fontes **OFL** do Google Fonts;
- ícones de teclas (Kenney *Input Prompts*, CC0).

⚠️ **Evitar:** assets pagos (Synty, Fab) e arquivos que não podem ir para um repositório público (Mixamo). ⚠️ **Modelos realistas da Poly Haven são pesados demais** (árvores com 3,7 a 7,8 milhões de polígonos): o hub fica aberto junto com os jogos.

### 2.3 Imagens da Steam disponíveis por jogo
| Imagem | Tamanho | Uso na prova |
|---|---|---|
| Capa em pé | 600×900 | painel na fachada |
| **Logo** | PNG transparente, ~600×250 | **letreiro sobre a porta (novo)** |
| **Hero** | 1920×620 (banner largo) | **ainda não usada** |
| Capa deitada | 460×215 | reserva |
| Avatar de amigo | 64×64 | rosto do holograma |

### 2.4 Limites práticos
- **Câmera:** primeira pessoa, a 1,6 m do chão, FOV 75°. O jogador anda a 5 m/s e corre a 9 m/s.
- **Leveza:** a cidade monta em ~0,7 s, e os assets novos somam ~32 MB (texturas 1K, céus 2K).
- **Escala:** 18 jogos em 7 bairros hoje. O layout (quarteirões de 28 m, ruas de 10 m) precisa escalar para centenas.
- **Idioma:** todos os textos em **português do Brasil**.

---

## 3. A prova em números

- **Paleta:** as paredes usam tons **neutros** (concreto ~`#D1D4D9`, bege ~`#F2EDE6`, tijolo natural), com só **10% da cor do bairro**. A cor do bairro virou **néon**: mesmo matiz, saturação 70%, brilho 100%. Os letreiros dos bairros usam saturação 80%.
- **Cores dos bairros (matiz de origem):**
  - Esportes e Corrida `#3F8F5A`
  - RPG e Fantasia `#7B5EA7`
  - Sobrevivência e Terror `#8A4B3C`
  - Simulação e Construção `#C9A24A`
  - Estratégia e Tática `#4A6FA5`
  - Ação e Roguelike `#C0503A`
  - Cartas e Tabuleiro `#2F8F8A`
  - Aventura e Mistério `#D08A3C`
  - Casual e Festa `#D27AA0`
  - Outros `#7D8590`
- **Janelas:** vidro `#0D1217`, com rugosidade 0,06 e metálico 0,6. À noite, 45% acendem (luz quente `#FFC780`, algumas neutras), com a emissão ×1,3.
- **Néon:** emissão 0,6 de dia e 3,6 à noite (o glow faz o halo).
- **Luz:**
  - céu com energia 1,0 de dia e 0,45 à noite;
  - neblina com densidade 0,0015 de dia e 0,006 à noite (cor `#080A12`);
  - postes com spot de 62°, 12 m de alcance e luz `#FFE6C2`.
- **HUD:**
  - **mira:** pontinho de 3 px;
  - **cartão:** 48 px acima da borda de baixo, título em 26 px, detalhe em 17 px `#B8BFCC`, fundo `rgba(9,10,13,0.74)`;
  - **avisos:** no topo, texto em 18 px, barra de 4 px `#F2C14E` (info) ou `#E5534B` (erro).
- **Holograma:** cápsula de 1,25 m + cabeça de 0,19 m, flutuando 4 cm (sobe e desce devagar). Cores: `#5FE3A1` jogando, `#6FB7FF` online, `#8A96A8` ausente.

---

## 4. Referências (enviar junto)

Os mesmos 9 enquadramentos em cada pasta (`antes/`, `prova_1-3/` e `comparacao/`):

| # | Arquivo | O que mostra |
|---|---|---|
| 01 | `01_praca_dia.png` | Vista de quem nasce na praça, de dia |
| 02 | `02_praca_por_do_sol.png` | Mesma vista no pôr do sol |
| 03 | `03_praca_noite.png` | Mesma vista à noite |
| 04 | `04_amigos_na_praca.png` | Amigos de perto (Kenney × hologramas), com o HUD mostrando "Duda — Online" |
| 05 | `05_porta_dia_hud.png` | Porta do Balatro de dia, com 2 amigos jogando, letreiro e cartão do HUD |
| 06 | `06_porta_noite.png` | Mesma porta à noite |
| 07 | `07_rua_noite.png` | Rua à noite: néon, asfalto molhado, postes |
| 08 | `08_vista_aerea.png` | A cidade inteira vista de cima |
| 09 | `09_transicao.png` | A "cortina" preta ao entrar num jogo (ainda igual) |

---

## 5. O que ainda incomoda: queremos propostas

1. **Transições ainda são tela preta com texto** (ref. 09): abertura, "Abrindo X…", "Jogando X…" e volta. É a maior oportunidade de UI. Temos o **hero** e o **logo** de cada jogo para usar.
2. **Logo repetido:** muitas capas já trazem o logo, então ele aparece duas vezes na fachada (ref. 05). Alternativas:
   - usar o **hero** 1920×620 em vez da capa;
   - usar uma capa sem logo;
   - um letreiro diferente.
3. **Prédios iguais:** todos são caixas 10×10 m com janelas numa grade uniforme e telhado liso. Como variar sem modelagem manual? Ideias: recuos, platibanda, marquise sobre a porta, caixas d'água, andares de alturas diferentes, cores de vidro.
4. **Árvores low-poly** (Kenney recoloridas) ainda destoam do realismo. Precisamos de uma alternativa leve.
5. **Pôr do sol** meio enevoado (o HDRI é nublado): trocar de HDRI ou corrigir cor/exposição?
6. **Noite:** o céu estrelado tem **morros no horizonte** (do próprio HDRI). Os círculos de luz dos postes ainda são discretos. Falta "vida" (vitrines, letreiros animados, carros parados?).
7. **Hologramas em forma de "pílula":** vale uma silhueta mais humana (Quaternius *Universal Base Characters* + o shader de holograma)?
8. **Orientação:** os letreiros dos bairros flutuam a 25 m. Com 100+ jogos, como se achar? Placas de rua, portais de entrada do bairro, minimapa, bússola?
9. **Identidade dos bairros:** hoje só a cor do néon muda. Queremos **1 elemento marcante por bairro**.
10. **Vista aérea / horizonte:** o mapa acaba num muro cinza com neblina (ref. 08). Como "fechar" a cidade? Silhuetas de prédios ao fundo, skyline?
11. **Não há menus:** as configurações ficam num arquivo de texto. Precisamos de um menu de pausa/configurações simples (volumes, tela cheia, sair).

---

## 6. Momentos do storyboard

| # | Momento | Hoje (prova) |
|---|---|---|
| 1 | Abertura | tela preta "Organizando a cidade…" e o fade para a praça |
| 2 | Praça / orientação | chafariz, hologramas em roda, letreiros dos bairros |
| 3 | Caminhar num bairro | fachadas PBR com néon, som ambiente do bairro |
| 4 | Olhar um prédio | cartão embaixo: nome + horas + última vez |
| 5 | Amigos | hologramas com avatar; na porta aparece "Jogando agora" |
| 6 | Entrar na porta | a tela escurece em 1,5 s com zumbido subindo; sair antes cancela |
| 7 | "Abrindo X…" | tela preta com texto (Esc cancela) e o hub minimiza |
| 8 | "Jogando X…" | tela preta se o jogador volta ao hub com o jogo aberto |
| 9 | Volta do jogo | som de confirmação, o jogador na porta, fade de volta |
| 10 | Avisos | painel escuro com barra amarela (info) ou vermelha (erro) |
| 11 | Noite | estrelas, néon, janelas, asfalto molhado |
| 12 | Jogo aberto por fora | o hub escurece e minimiza sozinho |
| 13 | Futuro: bioma | a mesma linguagem numa montanha de gelo ou numa pista de corrida |

---

## 7. O que queremos do Claude Design (v2)

1. **Validar e refinar** a direção "semi-realista + noite elegante": o que manter, o que ajustar (paleta, intensidade do néon, materiais), e um **guia de estilo curto**:
   - paleta neutra + néon por bairro;
   - tipografia Barlow / Barlow Condensed (tamanhos e pesos);
   - materiais;
   - clima de dia, pôr do sol e noite.
2. **Storyboard de 12 a 14 quadros** (seção 6), desenhado **sobre as imagens da prova**. Cada quadro com:
   - enquadramento;
   - o que aparece na tela;
   - som;
   - o que muda;
   - **como fazer na Godot** (nó ou recurso da seção 2.1 e asset da 2.2);
   - prioridade: P1 (rápido e de alto impacto), P2 ou P3.
3. **Mockups de UI em 1280×720**, no mesmo estilo do cartão e dos avisos atuais:
   - tela de abertura;
   - **"Abrindo X…" e "Jogando X…" com hero e logo**;
   - volta do jogo (resumo da sessão?);
   - avisos;
   - menu de pausa/configurações.
4. **Soluções para os 11 pontos da seção 5**, cada uma com "como fazer" e prioridade.
5. **Lista final priorizada** (P1 → P3).

**Regras:**
- Nada pago nem modelagem 3D manual.
- O hub precisa continuar leve.
- Mudanças modulares, uma por vez.
- Tudo em **português do Brasil**, com medidas em metros e pixels.

---

## 8. Glossário
- **Portal (`GamePortal`):** o componente genérico "este lugar é um jogo". Hoje fica na porta do prédio; no futuro, numa caverna, num portão, num boxe de corrida.
- **Bairro:** uma categoria de jogo (tags da Steam), que ocupa quarteirões inteiros.
- **Hub dormindo:** o estado enquanto um jogo roda (tela preta, mundo pausado, janela minimizada).
- **Cortina (`ScreenFade`):** a tela preta das transições, que pode ter um texto no meio.
- **PBR:** material "realista" com cor, relevo e rugosidade (texturas da ambientCG).
- **HDRI:** foto panorâmica 360° que serve de céu e de iluminação (Poly Haven).
- **Néon:** faixa emissiva (que brilha) na cor do bairro.
