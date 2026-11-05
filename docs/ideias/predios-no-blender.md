---
status: crua
versao: V1
custo: G
data: "2026-11-05"
---

<!-- status: crua | madura | virou-fase | descartada · versao: V1 a V6 · custo: P | M | G -->

## O que é
Os prédios da cidade feitos com um **kit de peças modelado no Blender**: janela com moldura, sacada, toldo, porta, cornija e letreiro. O código continua decidindo onde fica cada prédio e qual jogo ele mostra, e monta a fachada com essas peças, como a 17.8 montou o deque e o abrigo do mirante. Junto com as texturas PBR que já temos (ambientCG, Wood049) e a luz da Alta (o SSR do chão molhado, a névoa volumétrica nos postes), a ideia é chegar perto da cena Bistro, sem fork da Godot e sem asset de terceiros.

Veio de 2026-11-05: o dono viu o vídeo do fork RTX da NVIDIA para a Godot (canal Gamefromscratch), gostou dos prédios da cena Bistro e perguntou que modelos eram. A Bistro não serve para o hub: é CC BY 4.0 (e não CC0), é uma rua fixa feita à mão e pesa centenas de MB. O que faz ela parecer "uau" é o detalhe pequeno à mão, os materiais e a luz, e isso dá para fazer do nosso jeito.

## Para quem / por que importa
Os prédios são o que mais se vê na cidade e hoje são caixas por código com a fachada por shader. Depois da casa, da trilha e do mirante (Fase 17), eles são a maior distância entre o hub e as referências. O dono aprovou o Blender como caminho de modelagem depois da 17.7.1, mas deixou os prédios de fora "até virar fase própria" (AGENTS.md, "Assets").

## Menor versão que já dá para testar
Um só bairro (ou um só prédio da praça) com o kit: três ou quatro peças (janela com moldura, cornija, toldo e porta), um script refazível por peça em `tools/blender/`, e a mesma montagem por código de hoje trocando as caixas pelas peças. Captura de antes e depois às 13 h e às 22 h, e a medida no desktop (os prédios são muitos: o custo de desenho é o risco).

## Dúvidas
- Quantos desenhos a cidade aguenta? Hoje a caminhada tem ~1700; peças por janela multiplicam isso. Provável caminho: juntar as peças de cada prédio numa malha por material (como o `TrailProps.Batch`/`Merge`), ou `MultiMesh` por peça.
- O shader de fachada (`building_facade.gdshader`, as janelas acesas à noite) continua por baixo das peças ou é substituído?
- A identidade de cada bairro (o `DistrictProfile`) passa a escolher o estilo das peças (um kit por bairro, ou um kit só com cores e enfeites por bairro)?
- Os testes do SSR, da névoa volumétrica e do SDFGI na Alta (conversa de 2026-11-05 sobre a RTX 4070) podem vir antes, numa subetapa pequena, porque valem para a cidade de hoje também.
- Referência ou atalho possível: o Downtown City MegaKit da Quaternius (CC0, maio de 2026, parte grátis); o dono ainda não viu as imagens, e o traço da Quaternius já foi achado infantil.
