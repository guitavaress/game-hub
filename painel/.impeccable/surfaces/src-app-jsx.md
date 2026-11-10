---
version: 1
slug: "src-app-jsx"
primary_target: "src/App.jsx"
related_targets: ["src/tema.css"]
---

# Painel do cofre (a página inteira)

Escopo: o painel inteiro em `src/` (abertura, seções, leitor, busca, avisos). Modo: Operate na abertura e nas seções; Read no leitor de documentos.

Público e tarefa: o dono, no desktop, abre para saber "quanto o projeto andou?" em 3 segundos, olhando o produto inteiro (o que foi feito e para onde vai), depois lê planos, ideias e o ROADMAP e decide o próximo passo. Celular é secundário (funciona e lê bem).

Recusado pelo dono: prédios e trilha/montanha no centro (o mundo já implementado), cara de painel genérico, neon e brilho demais, texto espremido em cartão. Fica do painel atual: o nível de acabamento e de animação, e o escuro como padrão.

Momento memorável: o quadro V1–V6 com uma ilustração por versão, as feitas acesas e as futuras ainda apagadas, abaixo da abertura com os mundos futuros no horizonte.

Em aberto: nada.

## Direction contract

THESIS: O painel é o quadro da visão do produto: as versões V1–V6 do ROADMAP, cada uma com sua imagem e seu status, as três etapas do produto e a fase de agora; mostra o que foi feito já mirando o futuro. Recusa o painel de projeto padrão (barra lateral, fileira de números) e o espelho do mundo já construído (prédios, trilha).

OWN-WORLD: Chão void #07121E, placas navy #0D1C2E e surface #132D49, ação em papel #F6FAFE sobre o escuro, acentos cyan #24BAF5 e glow #67E8F9 só em estado e dado. Ilustrações cinematográficas azul-noite com luz âmbar, geradas por nós, como pranchas com máscara suave; o futuro fica dessaturado. Sora nos títulos, Manrope na interface, Literata no texto longo; números tabulares. Separação por linha de 1 px e degrau de tom, sem halo nem neon.

STORY: O dono vê em segundos que V1 e V2 estão feitas, V3 em parte e V4 é a próxima, que está na etapa 1 de 3 e na Fase 17 (13 de 15); abre a próxima subetapa, desce para ler o rumo, os planos e as ideias, e decide.

FIRST VIEWPORT: Barra de cima com logo, as oito seções, busca (Ctrl K), tema, animações e "ao vivo". Abertura: à esquerda "Game Hub", a frase da visão do ROADMAP e as 3 etapas; à direita a ilustração do horizonte com máscara. Abaixo, o quadro de 6 versões (imagem, V grande, selo de status, nome, o que é, as fases). Embaixo, a fase em andamento com a régua de subetapas e o botão da próxima, as próximas fases e o ritmo de commits.

FORM: Quadro da visão, direção fixada pelo dono a partir do esboço dele (fora da lista sorteada; vence o sorteio); seed:2ddeb34075b37b7f. Interação-assinatura: o quadro se revela na abertura da esquerda para a direita (a imagem abre de baixo para cima, as futuras assentam apagadas); quando um [x] é marcado ao vivo, a régua da fase acende a subetapa.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
