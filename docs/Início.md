# Game Hub: início

O painel do cofre. Daqui se chega a tudo o que organiza o projeto.

**Painel visual, ao vivo:** com o Docker aberto, `docker compose -f painel/compose.yaml up -d` na pasta do projeto e abra http://localhost:4170 ([como funciona](../painel/README.md)).

## Agora
- **Fase atual:** [Fase 20, Primeira e terceira pessoa](plans/fase-20.md), aprovada em 2026-11-16, na branch `fase-20`. Uma tecla (V) vai alternar a visão: na terceira pessoa você vê o seu avatar por trás; na primeira, vê o próprio corpo ao olhar para baixo.
  - **Feita:** 20.1 (2026-11-16, `aee6ef2`): o corpo do avatar anda, corre e pula pela velocidade (ainda sem mudança na tela).
  - **Feita:** 20.2 (2026-11-16, `f3e3b44`): Esc › Controles tem a linha "Visão" (primeira ou terceira pessoa), e a tecla V (R3 no controle) aparece na lista de teclas e no cartão "COMO JOGAR". Apertar V ainda não faz nada: a câmera chega na 20.4.
  - **Feita:** 20.3 (2026-11-16, `1dc947d`): olhando para baixo você vê o seu corpo; a sombra no chão tem cabeça; o espelho mostra o corpo de verdade, e no provador o avatar aparece também na frente do vidro. A caminhada não caiu (151,3 e 148,5 FPS). A revisão de risco não achou nada grave. Capturas em `C:\Projetos\game-hub-referencias\fase-20\20.3\`.
  - **Feita:** 20.3.1 (2026-11-16, `7d77f27`): olhando reto para a frente o corpo não aparece mais (o braço não cruza a tela); reto para baixo aparecem o peito, os braços, as pernas e a sombra; descer uma guia não faz o corpo pular. Capturas em `C:\Projetos\game-hub-referencias\fase-20\20.3.1\`.
  - **Espera você:** testar a 20.3 (checklist no plano); dizer se a pose parada do avatar no provador incomoda (é a do modelo, com um pé à frente); dizer se quer ver mais do corpo ao olhar um pouco para baixo; confirmar o R3 como botão da visão.
  - **Feita:** 20.4 (2026-11-16, `67fe3ec`): **a tecla V (R3 no controle) alterna a visão.** Na terceira pessoa a câmera fica atrás do ombro direito, você vê o avatar andar, correr e pular, e ela se aproxima quando bate em parede, prédio ou no teto da casa. A caminhada ficou dentro da meta (pior rodada 2,5% abaixo da partida). Capturas das duas variantes em `C:\Projetos\game-hub-referencias\fase-20\20.4\ombro\` e `...\livre\`.
  - **Espera você (20.4):** escolher o jeito da terceira pessoa. "Ombro" (o padrão): o avatar fica sempre de costas e gira com o mouse. "Livre": o mouse gira só a câmera e o avatar vira para onde anda. Para testar a segunda, troque `THIRD_PERSON_STYLE` para `STYLE_FREE` no topo de `player/player.gd`.
  - **Feita:** 20.5 (2026-11-16, `57d159c`, e a correção do teste 20.5.1, `ca9767f`): **na floresta os galhos não tapam mais a tela** (a câmera bate num volume invisível na copa; o mesmo nas luminárias da casa). Encostado num prédio o corpo não some mais. Computador, luneta e provador vão e voltam sem a câmera passar pela cabeça; voltando de um jogo ou de uma viagem a câmera já chega atrás do ombro; entrar e sair de casa encurta e alonga o braço suavemente; na terceira pessoa cada passo soa quando o pé toca o chão. A caminhada ficou 1,6% abaixo da partida. Capturas em `C:\Projetos\game-hub-referencias\fase-20\20.5\`.
  - **Próxima subetapa:** 20.6, medida e fechamento (bateria completa, a medida nas duas visões, README e ROADMAP).
  - **Espera você:** além do jeito da terceira pessoa e do R3, dizer se a fase fecha com o Release 0.20.0 e se a sombra do corpo em casa fica (uns 100 desenhos a mais, sem mudar o FPS).
- **Fase anterior:** [Fase 19, Biomas baratos, árvores e céu vivo](plans/fase-19.md), **fechada em 2026-11-15 e na `main`** (PR #5, 2026-11-16), com o [Release 0.19.0](https://github.com/guitavaress/game-hub/releases/tag/v0.19.0) publicado em 2026-11-16 (zip de 83 MB): árvores feitas no Blender, o dia em gradiente, clima dinâmico com a chuva refeita, a floresta e o deserto, e os bairros crescendo com as horas.
  - **Fechamento (19.13, 2026-11-15):** bateria completa ok. No desktop (Alta, 200 jogos), a caminhada não caiu em relação ao começo da fase: 132 FPS antes e 136 agora, medidos na mesma hora. A chuva forte custa cerca de 1%. A cidade leva cerca de 1 s a mais para montar (de ~9,3 para ~10,2 s). Os números estão no [plano](plans/fase-19.md).
  - **Subetapa anterior:** 19.8 (2026-11-15, `b3dbf33`): a Sobrevivência vira deserto. Areia no chão e nas ruas, rochas maiores com areia por cima, nenhuma árvore, vento, **poeira** no lugar da chuva, névoa quente e leve, arcos no lugar dos prédios e passos com o som da neve. Capturas em `C:\Projetos\game-hub-referencias\fase-19\19.8\`. Antes, 19.7 (2026-11-14, `408c116`): a Aventura vira floresta. Grama no chão e nas ruas, calçada de pedra, árvores altas de mata (feitas no Blender) com árvores novas por baixo, rochas com musgo, pássaros cantando, folhas caindo na chuva, uma névoa verde leve e passos na grama. As portas viraram **arcos** no meio da mata (a recomendação); com prédios, as árvores só cabem nas vagas. Capturas das duas em `C:\Projetos\game-hub-referencias\fase-19\19.7\arcos\` e `...\19.7\predios\`.
  - **Antes dela:** 19.6.1 (2026-11-14, `8d187a6`): a janela na chuva. Dentro de casa, com chuva lá fora, o vidro mostra os riscos caindo e as gotas paradas e escorrendo (poucas na chuva fraca, muitas na forte; à noite elas pegam as luzes). A vista não entorta mais quando você anda pela sala ou chega perto do vidro. Capturas em `C:\Projetos\game-hub-referencias\fase-19\19.6.1\` (antes e depois do warp, nos três tempos). A janela ao vivo continua sendo uma fase própria ([A janela de verdade](ROADMAP.md#5-a-janela-de-verdade)).
  - **Antes ainda:** 19.6 (2026-11-14, `5a1e679`): o clima dinâmico. O tempo muda sozinho na cidade toda (limpo, nublado, chuva fraca, chuva forte), com passagens suaves; o céu fecha, o chão molha, a montanha neva (nevasca na chuva forte) e a janela da casa mostra o tempo fechado, com a chuva abafada lá dentro. **Esc › Som e vídeo › Clima** escolhe dinâmico ou um tempo fixo (o F9 saiu). Capturas em `C:\Projetos\game-hub-referencias\fase-19\19.6\`.
  - **Feita fora da ordem:** 19.9 (2026-11-14, `fe0f163`): o bairro cresce com as horas. Pela fatia das suas horas, cada bairro tem um nível de 0 a 3, e o nível dá mais terreno (vagas com o chão do bairro), não mais prédios. Sem horas (ou com menos de 10 h no total), a cidade fica igual. Veja no mapa (M). Capturas em `C:\Projetos\game-hub-referencias\fase-19\19.9\`. A revisão de risco achou dois problemas graves, **corrigidos** (`4f623eb`): com horas, a cidade não cresce mais (a mesma mureta, o mesmo metrô e a mesma montanha), e o mirante continua com a plataforma quando o RPG está no nível 3. O preço: o bairro cresce menos (nos 200 jogos falsos, o RPG vai de 24 para 27 zonas, e não mais para 30). Capturas da correção em `C:\Projetos\game-hub-referencias\fase-19\19.9-revisao\`.
  - **Espera você:** aprovar a 19.8 e a 19.7 (a casca ficou em arcos, decidida em 2026-11-15); aprovar a 19.6.1 (a chuva no vidro e a vista sem warp), a 19.6 e a 19.9 (dizer se o crescimento menor depois da correção basta, e se as vagas dos bairros sem bioma devem ganhar enfeites); repetir a medida da correção da 19.9 com você na frente da máquina (a da sessão ficou presa em 60 FPS, com e sem horas iguais); decidir quanto tempo o céu fica limpo (hoje 38%) e se a montanha volta a nevar sempre (hoje 28% do tempo); duas perguntas da chuva (o piso claro da praça não parece molhado; do alto não se vê a chuva caindo), com o custo de cada uma nas decisões da 19.6. Da 19.4, falta ainda medir o F8 das 16 às 19 h com o F3 aberto (veja o plano).
  - **Feita agora:** a 19.12 (2026-11-15, `00c91fe`): a montanha do RPG ganhou pinheiros e rochas na encosta, fora da trilha, do mirante e da vista da luneta. Dá para ver da praça, da trilha, do mirante e da janela da cabana. Custa cerca de 20% dos FPS na montanha (aceito por você). Capturas em `C:\Projetos\game-hub-referencias\fase-19\19.12\` (antes e depois). Antes dela, a 19.10 (`a8a2426`): o marco de cada bairro cresce com o nível de horas. A 19.13 (medida e fechamento) também está feita. A 19.11 (canto da divisa e bandeira na torre) está feita e juntada.
  - **Teste do modelo grátis (OpenCode):** o `free-coding` reprovou na 19.11 (ela passa ao Sonnet). O `free-reasoning` foi aprovado para pesquisa e texto com revisão: escreveu a ideia do [fork da NVIDIA](ideias/godot-fork-nvidia.md).
- **Esperando os amigos:** [Fase 18, Mostrar para amigos](plans/fase-18.md). O [Release 0.18.0](https://github.com/guitavaress/game-hub/releases/tag/v0.18.0) foi publicado em 2026-11-12 (PR #4 na `main`, tag `v0.18.0`, zip de 74 MB com o `.exe`, o `LEIA-ME.txt` e as 22 licenças).
  - **Falta:** 2 ou 3 amigos usarem e mandarem o resumo do botão "Contar o que achei". Cole o resumo (sem o nome) para um agente registrar no plano; aí a fase fecha.
- **Depois da Fase 20:** [Visitar amigos](ROADMAP.md#4-visitar-amigos), adiada em 2026-11-12 (o jogo do V-Sekai está parado desde junho de 2025), e os itens 5 a 7 da ROADMAP.
- **Para fazer num dia só:** [Dia de conferência no desktop](plans/conferencia-desktop.md).
- **Última fase feita:** [Fase 17, O momento uau](plans/fase-17.md), já na `main` (PR #3). As capturas de antes e depois ficam em `C:\Projetos\game-hub-referencias\uau\` (fora do repositório).
- **Decidido em 2026-11-02:** a [revisão da ROADMAP](revisao-roadmap-2026-11-02.md#decisões) e a [revisão de design](design/revisao-2026-11-02.md).

## O que falta
Lista montada sozinha pelo plugin **Tasks**: junta os `- [ ]` abertos dos planos. Clique no nome do arquivo para abrir. Sem o plugin, aparece só o texto da consulta: para instalar, Configurações › Plugins da comunidade › Procurar › "Tasks" › Instalar e Ativar.

**Nas fases**
```tasks
not done
path includes plans/fase-
description does not include ~~
group by filename
short mode
```

**No dia de conferência**
```tasks
not done
path includes plans/conferencia-desktop
short mode
```

## Linha do tempo
Datas tiradas dos commits. As próximas fases ainda não têm data: ali o tamanho das barras só mostra a ordem.

```mermaid
gantt
    title Game Hub, fase a fase
    dateFormat YYYY-MM-DD
    axisFormat %d/%m

    section Base
    Fases 1 a 6, andar, portal, cidade, launcher, amigos, dia e noite :done, f1, 2026-09-26, 2026-09-28
    Visual v2                        :done, v2, 2026-09-27, 2026-09-29

    section Mundo
    Fase 7 World Profile             :done, f7, 2026-09-30, 2026-10-06
    Fase 8 Escala                    :done, f8, 2026-10-05, 2026-10-07
    Fase 9 A casa                    :done, f9, 2026-10-06, 2026-10-11
    Fase 10 Acabamento               :done, f10, 2026-10-10, 2026-10-11
    Fase 11 Sensação e marcos        :done, f11, 2026-10-10, 2026-10-12
    Fase 12 Tema e controles         :done, f12, 2026-10-11, 2026-10-13
    Fase 13 Casa, parte 2            :done, f13, 2026-10-12, 2026-10-13

    section Plataforma
    Fase Linux                       :done, fl, 2026-10-04, 2026-10-20
    Fase 14 O hub no Omarchy         :done, f14, 2026-10-13, 2026-10-20

    section Biomas e leitura
    Fase 15 Primeiro bioma           :done, f15, 2026-10-17, 2026-11-03
    Fase 16 Leitura                  :done, f16, 2026-11-02, 2026-11-03

    section Uau
    Fase 17 O momento uau            :done, f17, 2026-11-02, 2026-11-10

    section Amigos
    Fase 18 Mostrar para amigos      :active, f18, 2026-11-10, 7d

    section Biomas e céu
    Fase 19 Biomas, árvores e céu    :done, f19, 2026-11-12, 2026-11-15

    section Visão
    Fase 20 Primeira e terceira pessoa :active, f20, 2026-11-16, 7d

    section Próximas, sem data
    Visitar amigos                   :u4, after f20, 7d
```
Ao fechar uma fase, troque `active` por `done` e acerte a data do fim. A fase que começar ganha uma linha com a data de início e sai de "Próximas".

## Rumo
- [ROADMAP](ROADMAP.md): para onde o projeto vai e em que ordem (a fonte única).
- [Ideias](ideias/README.md): a caixa de entrada, com a tabela [ideias.base](ideias/ideias.base).
- [Planos das fases](plans/README.md): um plano por fase, que também é a memória entre as sessões dos agentes.

## Referência
- [Plataforma](PLATAFORMA.md): Steam, Windows e Linux.
- Design: [storyboard](design/storyboard-brief.md), [revisão de 2026-11-02](design/revisao-2026-11-02.md), [revisão de 2026-10-10](design/revisao-2026-10-10.md), [bioma montanha](design/bioma-montanha.md), [addons](design/addons-2026-10-13.md), [exploração open source](design/exploracao-open-source-2026-10-15.md).

## Regras do cofre
1. **Ideia nova vai para `ideias/`**, com o modelo "ideia". Ideia não é tarefa: só vira trabalho quando entra na ROADMAP como fase.
2. **Não edite `plans/` de uma fase em andamento:** os agentes marcam os `[x]` lá.
3. **Imagem colada vai para `_anexos/`**, que fica fora do git. Capa de jogo nunca entra no repositório (ele é público).
4. **Links no formato `[texto](arquivo.md)`**, que já é o padrão deste cofre: assim eles funcionam no GitHub e para os agentes.
