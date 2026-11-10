---
name: Game Hub — painel do cofre
description: Quadro da visão do produto, calmo e vivo, com leitura editorial.
colors:
  gh-void: "#07121e"
  gh-navy: "#0d1c2e"
  gh-surface: "#132d49"
  gh-blue: "#1269b7"
  gh-electric: "#168eea"
  gh-cyan: "#24baf5"
  gh-glow: "#67e8f9"
  fundo-dark: "#07121e"
  painel-dark: "#0d1c2e"
  painel-2-dark: "#102640"
  elevado-dark: "#1b2f49"
  borda-dark: "#21384f"
  borda-forte-dark: "#2b4660"
  texto-dark: "#eaf6ff"
  suave-dark: "#a5b9cd"
  fraco-dark: "#7f95ab"
  destaque-dark: "#67e8f9"
  destaque-2-dark: "#24baf5"
  perigo-dark: "#ff8a8a"
  fundo-light: "#f6fafe"
  painel-light: "#ffffff"
  painel-2-light: "#eef4fa"
  elevado-light: "#ffffff"
  borda-light: "#dbe6f0"
  borda-forte-light: "#c4d5e5"
  texto-light: "#132d49"
  suave-light: "#4a647d"
  fraco-light: "#5d7690"
  destaque-light: "#0b5fa7"
  destaque-2-light: "#168eea"
  perigo-light: "#c23b3b"
  acao: "#1269b7"
  acao-texto: "#ffffff"
  acao-hover: "#1576cb"
typography:
  display:
    fontFamily: "Sora, Segoe UI, system-ui, sans-serif"
    fontSize: "clamp(2.8rem, 4.8vw, 4.8rem)"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "-0.04em"
  headline:
    fontFamily: "Sora, Segoe UI, system-ui, sans-serif"
    fontSize: "clamp(1.6rem, 2.4vw, 2.15rem)"
    fontWeight: 600
    lineHeight: 1.12
    letterSpacing: "-0.03em"
  title:
    fontFamily: "Sora, Segoe UI, system-ui, sans-serif"
    fontSize: "19px"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "-0.03em"
  body:
    fontFamily: "Manrope, Segoe UI, system-ui, sans-serif"
    fontSize: "15.5px"
    fontWeight: 400
    lineHeight: 1.6
  reading:
    fontFamily: "Literata, Georgia, serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.8
  label:
    fontFamily: "Manrope, Segoe UI, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.6
rounded:
  sm: "8px"
  md: "14px"
  lg: "22px"
  xl: "30px"
  button: "10px"
  field: "12px"
  image: "4px"
  pill: "99px"
spacing:
  compact: "8px"
  item: "12px"
  grid: "16px"
  inset: "20px"
  group: "24px"
  section-inner: "28px"
  block: "32px"
  page: "40px"
  section: "96px"
components:
  button-primary:
    backgroundColor: "{colors.acao}"
    textColor: "{colors.acao-texto}"
    rounded: "{rounded.button}"
    padding: "8px 14px"
  button-primary-hover:
    backgroundColor: "{colors.acao-hover}"
  button-secondary:
    textColor: "{colors.texto-dark}"
    rounded: "{rounded.button}"
    padding: "8px 14px"
  button-clear-dark:
    backgroundColor: "{colors.texto-dark}"
    textColor: "{colors.fundo-dark}"
    padding: "12px 14px"
  field-dark:
    backgroundColor: "{colors.painel-dark}"
    textColor: "{colors.texto-dark}"
    rounded: "{rounded.field}"
    padding: "0 14px"
    height: "42px"
  chip-dark:
    textColor: "{colors.suave-dark}"
    rounded: "{rounded.pill}"
    padding: "2px 9px"
  idea-dark:
    backgroundColor: "{colors.painel-dark}"
    rounded: "{rounded.md}"
    padding: "16px"
---

# Design System: Game Hub — painel do cofre

## Overview

**Creative North Star: "Quadro da visão do produto"**

Um cofre para ler com calma e decidir. O chão azul-noite, as divisões finas e a tipografia editorial dão continuidade entre a visão do produto e os documentos. O nome, o símbolo e a paleta do Game Hub são compromissos de marca; o escuro é o tema padrão.

O mundo visual é calmo, mas vivo: ilustrações cinematográficas azul-noite com luz âmbar ficam em pranchas, com máscaras suaves quando se integram ao fundo. O futuro perde saturação. Estados, dados e mudanças reais recebem ciano; a leitura recebe espaço. A composição evita a fileira genérica de cartões numéricos, prédios como tema central e texto longo espremido em cartão.

**Key Characteristics:**

- Azul-noite e papel, com acento ciano funcional.
- Sora nos títulos, Manrope na interface e Literata na leitura longa.
- Linhas finas e degraus de tom organizam o conteúdo.
- Ilustração como prancha; estados também são escritos.
- Movimento de entrada e atualização com redução pelo sistema e pelo botão do painel.

Fonte normativa: implementação em `src/tema.css`, `src/App.jsx` e componentes; linguagem confirmada em `PRODUCT.md` e no contrato de direção. Os valores do frontmatter registram o código, inclusive quando a implementação se afasta do contrato.

## Colors

A paleta combina profundidade azul-noite, texto frio e ciano luminoso; no claro, o papel preserva o mesmo parentesco azul.

### Primary

O azul de ação preenche os botões primários, com texto branco e variação própria no hover. O destaque é glow no escuro e azul legível no claro; os links acompanham esse destaque. O segundo destaque colore bordas de interação e dados.

**The Estado e Dado Rule.** Use ciano para estado, progresso, foco e mudança; mantenha as superfícies de leitura calmas.

### Neutral

No escuro, fundo void, painel navy, painel secundário e superfície elevada criam degraus de tom. Texto, suave e fraco distinguem conteúdo, apoio e metadados. Borda e borda forte separam regiões e controles.

No claro, fundo paper, painel branco e painel secundário azul muito claro substituem essas camadas. Elevado também é branco; a borda, o véu e a sombra comunicam a sobreposição. Os tokens com sufixos de tema são o registro portátil; o código seleciona seus equivalentes semânticos por `data-theme`. Não aplique as cores escuras fixas a uma nova superfície que precise alternar tema.

Perigo indica falha de conexão. Seleção de texto usa destaque translúcido no escuro e electric translúcido no claro. Não há uma paleta secundária de âmbar para controles: o âmbar pertence às imagens.

## Typography

**Display Font:** Sora, com Segoe UI e sans-serif do sistema como fallback.
**Body Font:** Manrope, com os mesmos fallbacks.
**Reading Font:** Literata, com Georgia e serif como fallback.
**Code Font:** ui-monospace, Cascadia Code, JetBrains Mono, Consolas e monospace.

Sora dá contorno preciso aos títulos; Manrope mantém a interface compacta e legível. Literata muda o ritmo na gaveta de leitura. A hierarquia é responsiva, sem uma razão modular única.

- **Display:** título de abertura fluido; no celular fixa-se em 2.8rem.
- **Headline:** títulos de seção fluidos.
- **Title:** títulos das próximas fases; as versões usam títulos menores (15px, linha 1.4; 14px no celular).
- **Body:** interface geral; em até 600px passa a 14px.
- **Reading:** documento até 72ch; parágrafos e itens usam mistura de texto e suave, com títulos ainda em Sora.
- **Label:** chips e metadados compactos; selos usam 11px e linha 1.5.
- **Números:** variantes tabulares em contagens e eixos. Os identificadores de versão têm tamanho fluido e entreletra negativa.
- **Código:** tamanho relativo de 0.86em, com fundo e borda próprios no Markdown.

**The Leitura com Espaço Rule.** Texto longo ocupa a gaveta editorial; resumos de cartões servem de entrada para essa leitura.

## Layout

A página é um fluxo vertical com navegação superior fixa durante a rolagem. O conteúdo mede até 1600px, centralizado, com margem interna horizontal de 40px e intervalo de seção de 96px. O cabeçalho mede até 1760px e tem altura mínima de 76px. As seções têm intervalo interno de 28px e margem de rolagem de 100px.

O quadro de versões usa seis colunas iguais e intervalo de 16px. Em até 1250px passa a três colunas; em até 600px, duas. As imagens mudam de 16:10 para 16:8 e depois 4:3. A faixa de andamento passa de três regiões para duas e depois uma. A fase atual divide a largura em 1.25fr/1fr; pares de blocos usam duas colunas. Ideias usam quatro, duas e uma coluna conforme o espaço.

- **Até 1550px:** cabeçalho mais compacto; rótulos de busca e detalhes auxiliares somem.
- **Até 1250px:** a navegação horizontal dá lugar ao menu; versões em três colunas e atividade em uma.
- **Até 900px:** margem interna de 24px e intervalo entre seções de 64px; fase atual e pares ficam em uma coluna.
- **Até 600px:** margem interna de 20px e intervalo de 56px; cabeçalho de 64px; abertura coloca a imagem acima do texto; leitor ocupa a tela inteira.

A gaveta de documentos tem até 880px, afastada 12px das bordas. A busca tem até 680px e margens laterais mínimas de 16px. Tabelas e linhas do tempo preservam rolagem horizontal quando necessário; não comprima os dados até perder sua leitura.

## Elevation & Depth

A separação normal é tonal, com bordas de 1px. O acabamento final remove a sombra de superfícies comuns e cartões de ideias. Sombras estruturais ficam nas sobreposições e avisos, acompanhadas de véu: a gaveta usa desfoque de fundo de 3px e a busca, 4px. A busca fica acima do leitor; avisos ficam acima de ambos.

### Shadow Vocabulary

- **Leitor:** `0 30px 90px rgb(0 0 0 / 0.45)`.
- **Busca:** `0 30px 90px rgb(0 0 0 / 0.5)`.
- **Aviso escuro:** `0 22px 60px rgb(0 0 0 / 0.32), 0 2px 6px rgb(0 0 0 / 0.25)`.
- **Aviso claro:** `0 22px 50px rgb(19 45 73 / 0.12), 0 2px 6px rgb(19 45 73 / 0.08)`.
- **Aba escolhida:** borda interna e sombra curta, sem elevar o conjunto de filtros.

**The Superfície Calma Rule.** Superfícies comuns ficam planas; sombra estrutural identifica conteúdo sobreposto.

O código ainda contém halos na trilha, no progresso, na linha do tempo e no realce de mudança. São efeitos locais preexistentes, não uma autorização para espalhar neon ou uma regra de superfície.

## Shapes

Controles e recipientes têm cantos suaves, sem uma única curvatura aplicada a tudo. Botões usam 10px; campos e grupos de abas usam 12px; cartões de ideia, 14px; grandes superfícies e sobreposições, 22px. Imagens de versão e selos usam cantos discretos de 4px. Chips são pílulas; nós da trilha são circulares. O raio de 30px permanece declarado na base, sem servir de padrão para os componentes amostrados.

Linhas separadoras organizam blocos abertos e versões. O futuro e estados parados usam também borda tracejada em elementos próprios. Não transforme cada região textual em cartão.

## Components

### Buttons

Contidos e claros. O secundário tem fundo transparente, borda forte e texto; o primário usa azul de ação. Ambos têm preenchimento de 8px 14px e altura mínima de 38px. Hover muda fundo e borda; active desce 1px e reduz para 0.98. Pressionado recebe painel secundário, borda de segundo destaque e texto de destaque. Desabilitado reduz opacidade a 0.5.

O botão da próxima subetapa inverte texto e fundo do tema, usa raio de 6px e preenchimento de 12px 14px. Seu hover sobe 2px. O contrato chama essa ação de papel; o código usa o token de texto do tema, registrado aqui como evidência.

### Chips e selos

Chips usam contorno forte e texto suave, com preenchimento compacto; o destaque acrescenta tintura de 9% e borda de 45% do destaque. São rótulos, sem hover inventado. Selos de estado são mais retos e usam texto explícito; estados feitos ou atuais recebem tintura de destaque, parados ou horizonte recebem contorno tracejado.

### Cards / Containers

Cartões de ideia têm fundo de painel, borda fina, raio de 14px, preenchimento de 16px e nenhuma sombra no acabamento final. Hover reforça a borda. Os títulos são Sora e resumos são Manrope. Versões são pranchas abertas com linha inferior, imagem e conteúdo em coluna, sem uma caixa externa.

### Inputs / Fields

Campo de busca com altura de 42px, raio de 12px, fundo de painel e borda forte. O foco dentro colore a borda e acrescenta anel translúcido de 3px. Na paleta, o campo mede 58px, perde cantos e mantém apenas a linha inferior.

### Navigation

Links discretos de 12px, texto suave em repouso e texto principal em hover ou ativo. A seção visível recebe sublinhado de destaque de 2px. O menu compacto reaproveita os mesmos links e permite quebra de linha.

### Leitor e paleta

Diálogos com fundo de painel e borda forte. Leitor abre pela direita, com cabeçalho persistente e corpo rolável; paleta entra perto do topo com campo e resultados. Busca por Ctrl+K ou /; setas escolhem resultado e Enter abre. Tab permanece no diálogo da frente, Esc o fecha, foco retorna à origem; o conteúdo de fundo fica inerte.

### Foco e movimento

O foco global usa contorno de 2px em destaque, afastado 2px, com cantos de 6px. Componentes que limpam estilos precisam manter o foco visível. O link de pular conteúdo aparece ao receber foco.

Transições de estado usam 150ms ou 220ms com `cubic-bezier(0.16, 1, 0.3, 1)`. Imagens revelam-se em 1s, escalonadas em 85ms; o leitor entra em 420ms. Indicadores de dados e contadores animam mudanças reais. A preferência do sistema e o botão manual reduzem animações e transições CSS; Motion recebe a mesma preferência. O contador imperativo também respeita ambas.

## Do's and Don'ts

### Do:

- **Do** preservar nome, símbolo e paleta do Game Hub.
- **Do** usar tokens semânticos para manter claro e escuro coerentes.
- **Do** escrever o estado junto da cor e conservar números tabulares.
- **Do** reservar Literata e largura confortável para documentos.
- **Do** manter foco visível, fundo inerte em diálogos e redução de movimento pelos dois controles.
- **Do** guardar a proveniência das ilustrações junto aos rasters de publicação.

### Don't:

- **Don't** transformar texto longo em resumo espremido num cartão.
- **Don't** usar prédios como centro da linguagem visual do painel.
- **Don't** espalhar neon ou sombras de elevação em superfícies comuns.
- **Don't** inventar dados, datas ou progresso para preencher a composição.
- **Don't** retirar os estados de teclado ao reproduzir um componente.
