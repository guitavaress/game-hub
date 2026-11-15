# Roadmap do Game Hub

Este arquivo é a **fonte única** do roadmap: para onde o projeto vai e em que ordem. Como usar o que já está pronto fica no [README](../README.md). Cada fase ganha um plano em [`plans/`](plans/README.md) antes de começar, e o plano é o registro detalhado dela. Esta versão saiu da [revisão de 2026-11-02](revisao-roadmap-2026-11-02.md).

## Visão

O Game Hub é um **launcher de jogos em forma de mundo** e um **lugar para encontrar os amigos**, inspirado no PlayStation Home.

- **A casa é o seu espaço:** a biblioteca, os amigos, as estatísticas e o seu avatar.
- **A cidade é a sua biblioteca:** cada jogo é uma porta, os bairros vêm das categorias, e o que você joga molda o lugar.
- **Os amigos estão lá:** hoje como hologramas; depois, num encontro de verdade dentro do hub.

O hub já é rápido e funciona bem. O que falta é o **"uau"**: encantar nos primeiros 5 minutos, de quem entra pela primeira vez a quem volta todo dia.

```
Steam  →  dados do jogo  →  perfil do mundo  →  gerador  →  Godot  →  Game Hub
(biblioteca,  (tags, horas,     (bioma, clima,      (cidade,
 amigos)       capas)            arquitetura, som)   biomas)
```

### O caminho do produto

| Etapa | Para quem | Chega quando |
|---|---|---|
| 1 | Para mim | você abre o hub para jogar no dia a dia, no lugar da Steam |
| 2 | Para mim e os amigos | 2 ou 3 amigos instalam e usam (fase [Mostrar para amigos](#2-mostrar-para-amigos)) |
| 3 | Público | um PoC publicado em subreddits específicos. Antes: custos, questões legais e monetização ([Horizonte](#horizonte-sem-compromisso)) |

### As versões da visão (storyboard V1–V6)

| Versão | O que é | Situação |
|---|---|---|
| **V1** Cidade e categorias | A biblioteca vira uma cidade com bairros | ✅ fases 1–6 |
| **V2** Mundo pessoal | Casa, avatar e amigos | ✅ fases 9 e 13 |
| **V3** Mundo dinâmico | O que você joga molda o lugar | 🟡 primeiro bioma na Fase 15; [biomas baratos](#3-biomas-baratos-poc), em andamento na Fase 19 |
| **V4** Amigos | Encontrar e visitar os amigos | 🔜 [Visitar amigos](#4-visitar-amigos), adiada em 2026-11-12 |
| **V5** Desktop | O hub como ambiente de desktop | ⏸️ mesa com três monitores na Fase 14 (só Linux); [parado](#parados) |
| **V6** Plataforma | Mundos criados pela comunidade, loja | [Horizonte](#horizonte-sem-compromisso) |

## Próximas fases

Nesta ordem, até alguém decidir mudar. **O número é dado quando a fase começa** (o próximo livre, a partir de 20), com o plano aprovado em `plans/fase-N.md`.

Os planos e as revisões antigas citam outros números: a "Fase 16" deles é a fase 3 abaixo (biomas), a "Fase 17" é a 4 (amigos) e a "Fase 18" está em [Parados](#parados).

### 1. O momento uau — feita na Fase 17
**Objetivo:** o hub encanta. É onde mora a frustração de hoje:
- a casa está vazia e pouco aconchegante, e a vista da janela está péssima;
- a trilha não tem conteúdo, e o mirante está feio;
- a luz apaga a praça e o mirante à noite e deixa o dia sem contraste (revisão de design, C1 e C2).

**Como:**
- **Primeira subetapa:** você escolhe de 3 a 5 referências do que é "uau" (imagens que ficam fora do repositório).
- Uma amostra é aprovada antes de construir o resto (skill `create-game-assets`).
- Primeiro a luz e o que já existe; modelos novos só se a amostra pedir. Assets só CC0, com permissão antes de baixar.

**Pronto quando:** a casa, a janela, a trilha e o mirante passam na sua comparação de antes e depois, nas capturas e no jogo.

**Andamento:** é a [Fase 17](plans/fase-17.md): **feita e na `main`** (PR #3, 2026-11-10). As capturas de antes e depois e a folha da fase estão em `C:\Projetos\game-hub-referencias\uau\`. Medida no desktop (200 jogos, Alta): 144,8 FPS na caminhada, p99 13 ms. O tranco de ~87 ms na abertura foi aceito (é compilação de shader, uma vez por abertura).

### 2. Mostrar para amigos
**Objetivo:** a etapa 2 do produto. Um build que 2 ou 3 amigos instalam e usam.

**Entregas** (o plano decide os detalhes):
- o export para o Windows;
- o primeiro uso sem editar arquivo à mão;
- o que fazer sem a chave da Steam Web API;
- um jeito simples de ouvir o que eles acharam.

**Pronto quando:** um amigo instala sozinho, abre um jogo pelo hub e conta o que achou.

**Andamento:** é a [Fase 18](plans/fase-18.md), em andamento desde 2026-11-10. As subetapas **18.0 a 18.6 estão feitas**: versão 0.18.0, executável do Windows, primeira abertura guiada, amigos opcionais sem cobrança, botão "Contar o que achei" e zip com LEIA-ME e licenças. O `tools/empacotar_windows.sh` gera e confere o pacote, recusando dados pessoais e sobras de desenvolvimento, inclusive dentro do pck. O [README](../README.md) foi reorganizado em 2026-11-11 para apresentar o mundo e orientar quem vai experimentar. **O [Release 0.18.0](https://github.com/guitavaress/game-hub/releases/tag/v0.18.0) foi publicado em 2026-11-12** (PR #4 na `main`, tag `v0.18.0`). **Falta só o retorno dos amigos:** a fase fecha quando o primeiro resumo entrar no plano.

### 3. Biomas baratos (PoC)
**Objetivo:** provar o coração da V3 ("o que você joga molda o lugar") sem o custo da montanha.

**Entregas:**
- 2 biomas só com chão, enfeites e clima, sem terreno: a floresta (Aventura) e o deserto (Sobrevivência);
- o bairro (e o marco dele) cresce com as horas jogadas;
- as sobras da Fase 15: a encosta com pinheiros e rochas, o canto côncavo da divisa neve/asfalto e o destaque da torre de dia;
- pedidos do dono no planejamento (2026-11-12): **todas as árvores como modelos do Blender** (inclusive as da janela da cabana) e **o céu vivo**: o dia em gradiente (nascer do sol, manhã, tarde, pôr do sol, noite), o clima dinâmico e a chuva refeita.

**Pronto quando:** um bioma novo é um perfil novo, e dá para ver um bairro maior que outro pelas horas jogadas.

**Andamento:** é a [Fase 19](plans/fase-19.md), aprovada em 2026-11-12. A 19.1 a 19.6 estão feitas (o código aceita mais de um bioma; o dono aprovou o pinheiro por script em 2026-11-13; todas as árvores do hub são modelos do Blender, com a foto do mesmo modelo de longe; o dia passa por nascer do sol, manhã, tarde, pôr do sol e noite, sem pulo; a chuva nova, em camadas, aprovada pelo dono em 2026-11-14; o tempo muda sozinho na cidade toda, com a opção "Clima" no menu). A revisão de risco da 19.6 foi feita e corrigida. A 19.6.1, pedida pelo dono ao testar a casa, está feita: a janela mostra a chuva no vidro, e a vista não deforma mais ao andar pela sala (a lente da foto ficou mais larga). A 19.9 (o bairro que você mais joga ocupa mais terreno) foi adiantada e está feita; a revisão de risco achou dois problemas graves, corrigidos em 2026-11-14 (com horas, a cidade e a montanha não mudam de tamanho; o bairro cresce só nas vagas que já existiam). A 19.7 está feita: a Aventura virou floresta (grama, árvores de mata feitas no Blender, rochas com musgo, pássaros, folhas na chuva), com arcos no lugar dos prédios; o dono escolhe entre arcos e prédios pelas capturas, e a escolha vale para o deserto. A 19.8 está feita: a Sobrevivência virou deserto (areia, rochas com areia por cima, sem árvores, vento, poeira no lugar da chuva e névoa quente), também com arcos. Depois vem a 19.10 (o marco cresce com as horas).

### 4. Visitar amigos
**Objetivo:** o encontro com os amigos acontece **dentro do hub**: avatar próprio, espelho, voz, sala de encontro e uma rede simples. Substitui a "visita sem servidor" de antes.

**Adiada em 2026-11-12** (era a fase 3, "Visitar amigos (V-Sekai)"). O dono conferiu o V-Sekai e achou o projeto parado. Os números do GitHub nesse dia:
- o jogo ([v-sekai-game](https://github.com/V-Sekai/v-sekai-game)): 253 commits em 2024, 82 em 2025 (o último de código em junho de 2025) e 8 em 2026, todos de robô;
- o servidor (uro): o último commit é de junho de 2025;
- seguem vivos: o godot-vrm (do V-Sekai, atualizado para a Godot 4.7 em julho de 2026) e, fora dele, o netfox e o TwoVoIP.

**Quando voltar, a primeira subetapa é um estudo curto**, que atualiza o [estudo de 15/10](design/exploracao-open-source-2026-10-15.md) e responde:
- que funções queremos;
- para cada peça candidata: a licença, **se o projeto está vivo** (commits de código, não de robô), se roda na Godot 4.7.2 oficial e se precisa de servidor;
- qual é o menor encontro que dá para testar.

O V-Sekai entra como leitura de ideias (o código é MIT e continua aberto), e não como base. O **REA** (engenharia reversa) só no que existir apenas compilado; as regras estão no [AGENTS.md](../AGENTS.md#modelos-e-esforço).

**Pronto quando:** o plano da fase sai do estudo, com o menor encontro definido.

### 5. A janela de verdade
**Objetivo:** a janela da casa deixa de ser uma foto da cidade e passa a mostrar a cidade ao vivo: a chuva caindo, o céu mudando, as luzes acendendo, com a profundidade certa quando você anda pela sala.

**Pedida pelo dono em 2026-11-14**, depois de notar na Fase 19 que a foto não mostra a chuva e deforma ao andar. A Fase 19 melhora a foto (chuva desenhada no vidro e lente mais larga, subetapa 19.6.1); esta fase troca a foto.

**A primeira subetapa é uma medida no desktop**, que compara dois caminhos:
- a vista ao vivo em baixa taxa (a janela redesenha a cidade algumas vezes por segundo, em resolução menor);
- o vidro transparente olhando a cidade real (a casa num lugar de verdade da cidade, e a cidade desenhada enquanto você está em casa). **É o caminho preferido do dono** (2026-11-14): a casa ou a cabana vira parte da cidade, entra-se pela porta andando, sem a tela escurecer, e a cidade não é desenhada duas vezes.

O que o vidro transparente tem de resolver, e o teste da primeira subetapa já mostra:
- a luz de dentro: hoje a câmera troca para o ambiente da casa ao entrar; com o vidro, a sala usa o céu, a névoa e a exposição da cidade, e o visual da casa à noite é refeito só com luzes;
- o custo de desenhar a cidade o tempo todo de dentro de casa;
- onde a casa fica, para a janela ter vista (andar alto ou ponto elevado), e o prédio por fora, que muda com o tema (a cabana talvez na beira da trilha);
- a chuva, a névoa e o som da rua não entram na sala.

A foto continua como reserva na qualidade Leve e enquanto a cidade monta.

**Pronto quando:** de dentro de casa, na Alta, dá para ver a chuva cair lá fora e a vista não deforma ao andar, sem a casa perder a meta de desempenho do desktop.

### 6. Amigos andando pela cidade
**Objetivo:** os amigos que hoje ficam parados em roda no chafariz passam a andar livremente pela cidade: pelas calçadas, de bairro em bairro, parando de vez em quando. A cidade deixa de parecer vazia.

**Pedida pelo dono em 2026-11-15.** Hoje, o amigo online que não está num jogo da sua biblioteca vira um holograma parado na praça (`_update_plaza_friends`, em `worlds/city/city.gd`). Quem está jogando um jogo seu continua na porta desse jogo: isso não muda.

O que a fase tem de resolver (o plano decide):
- **por onde andam:** só nas calçadas e na praça, sem atravessar prédio, porta, boca do metrô, marco, árvore nem rocha. A planta da cidade (`CityMap`) e as áreas de desvio dos biomas já existem;
- **o corpo andando:** o holograma hoje é parado; precisa de um passo que não pareça deslizar;
- **achar o amigo:** com ele andando, o mapa (M) e o minimapa mostram onde ele está, e a busca leva até ele;
- **a regra de arquitetura:** o andar é uma peça genérica em `components/` (serve a qualquer mundo); a cidade só diz onde se pode andar;
- **o custo:** muitos amigos online não podem derrubar a medida do desktop.

É um passeio **inventado pelo hub**, e não a posição real do amigo: ver o amigo de verdade andando é a "V4 ao vivo" do [Horizonte](#horizonte-sem-compromisso), que pede servidor.

**Pronto quando:** com amigos online, você os vê andando pelas ruas, nenhum atravessa nada, e dá para achar qualquer um pelo mapa.

## Dia de conferência

As fases feitas que diziam "falta a conferência no desktop" viram **um checklist único, feito num dia só**: [plans/conferencia-desktop.md](plans/conferencia-desktop.md).

## Parados

Nada aqui anda sem uma decisão nova sua.

| O quê | Por quê |
|---|---|
| Compositor e o desktop virtual (V5) | A mesa com três monitores fica como está (só Linux). Outras prioridades vêm antes |
| Perfis do usuário (a antiga Fase 18) | Ninguém além de você usa o hub ainda |
| Ouvir e trocar os sons (Fase 11) | Não é o "uau" agora. Mais tarde, talvez com sons comprados |
| Meta de 50 ms na montagem (Fase 15: 86 ms) | Ninguém sentiu o tranco. Fica em aberto até o produto pedir |
| Jev (TypeSafe) | Não se pagou até aqui: sem tarefa nova e sem gasto. A triagem da bateria é só código e continua, opcional |

## Feito

| Fase | O que entregou | Plano |
|---|---|---|
| 1–6 | Andar em primeira pessoa, portal de jogo, cidade por categorias, launcher, amigos como hologramas, dia e noite | — |
| Visual v2 | Céus HDRI, materiais PBR, telas "Abrindo" e "Jogando", pausa, busca, pórticos e a identidade dos 10 bairros | — |
| 7 World Profile | Bairros como dado (`profiles/`), `PortalShell`, garoa por bairro | [fase-7](plans/fase-7.md) |
| 8 Escala | Biblioteca falsa de 200 jogos, viagem rápida, bússola, minimapa, mapa (M) e metrô | [fase-8](plans/fase-8.md) |
| 9 A casa | Loft, estante, mural, computador e "E para interagir" | [fase-9](plans/fase-9.md) |
| 10 Acabamento | Mipmaps, anti-aliasing, UI que escala, primeira vez guiada e letreiros | [fase-10](plans/fase-10.md) |
| 11 Sensação e marcos | Curvas nas transições, câmera com peso, porta que pesa, torre do relógio e marcos, som | [fase-11](plans/fase-11.md) |
| 12 Tema e controles | Tema único, menus pelo teclado e controle Xbox (conferido por você em 2026-11-02) | [fase-12](plans/fase-12.md) |
| 13 Casa, parte 2 | Loft e cabana, cores, disposições, estatísticas, avatar e espelho | [fase-13](plans/fase-13.md) |
| 14 O hub no Omarchy | Painel do sistema, autostart, compositor Wayland e a mesa com três monitores (só Linux; em [Parados](#parados)) | [fase-14](plans/fase-14.md) |
| 15 Primeiro bioma | O RPG na neve, com arcos, pinheiros e uma montanha com trilha e mirante; setores contínuos | [fase-15](plans/fase-15.md) |
| 16 Leitura | Capas inteiras na estante, arco legível dos dois lados, avisos e título em lugares próprios, nomes da praça só de perto, textos que dizem o que apertar e estações do metrô com o lugar | [fase-16](plans/fase-16.md) |
| 17 O momento uau | A casa à noite com objetos e a cidade de verdade na janela (que acende quando fica pronta); a cidade com contraste de dia e de noite; a trilha do RPG com paradas e os modelos do Blender; o mirante como destino; a torre em pedra; a cabana com o aconchego do loft | [fase-17](plans/fase-17.md) |
| Linux | O hub roda no Linux; a plataforma fica isolada em `autoload/platform/` ([PLATAFORMA](PLATAFORMA.md)) | [fase-linux](plans/fase-linux.md) |

## Horizonte (sem compromisso)

Ideias guardadas para não se perderem. Nada aqui está planejado. Ideias novas vão para [`ideias/`](ideias/README.md).

- **Etapa pública do produto:** custos, questões legais, monetização e o PoC no Reddit.
- **V4 ao vivo:** ver o amigo andando, com o avatar dele, e eventos. É o primeiro item com custo de servidor; o estudo da fase [Visitar amigos](#4-visitar-amigos) diz se ele é necessário.
- **V5 completo:** o hub como a sessão inteira do Hyprland, janelas em qualquer lugar, dmabuf.
- **V6 com compartilhamento e loja:** mundos, biomas e enfeites criados por usuários.
- **Addons para depois** ([avaliação](design/addons-2026-10-13.md)): GodotSteam (amigos sem a chave da Web API), gdcef (navegador no `Screen3D`), trailers nos telões, LimboAI e Godot Steam Audio.
- **Veículos**, do mais simples ao mais caro: carros decorativos, dirigir um veículo simples, tráfego. Transporte público já existe (o metrô) e vem antes de dirigir.
- **Brand kit** (`game-hub-brand-kit/`, estudo não aprovado): no máximo um acento de cor e o símbolo, quando o produto pedir (revisão de design).

## Decisões registradas

- **Engine: seguir na Godot.** O hub fica aberto junto com os jogos, então ser leve é requisito.
- **Sem protótipo paralelo** (outra engine, web 3D): dividiria o esforço antes de a experiência estar validada.
- **Monetização depois** da etapa 2 do produto.
- **2026-10-12:** o bairro vira o bioma, nos quarteirões do próprio bairro e no mesmo mapa da cidade.
- **2026-11-02, revisão da ROADMAP:**
  - o norte é o launcher + o encontro com amigos; o desktop virtual entra em pausa;
  - o produto tem 3 etapas;
  - a ordem é Leitura → Uau → Amigos → V-Sekai → Biomas baratos (Leitura feita na Fase 16);
  - o fluxo de trabalho fica congelado por 3 fases;
  - a cerimônia completa vale só para subetapas grandes, e a revisão cruzada só nos pontos de risco;
  - as conferências pendentes viram um dia só.
  Detalhes no [AGENTS.md](../AGENTS.md) e na [revisão](revisao-roadmap-2026-11-02.md).
- **2026-11-12:** os biomas baratos passam à frente de visitar amigos, porque o jogo do V-Sekai está parado desde junho de 2025 (números na [fase 4](#4-visitar-amigos)). A Fase 19 ganha também as árvores no Blender e o céu vivo (dia em gradiente, clima dinâmico, chuva refeita).

As regras de arquitetura (dados de mundo em perfis, plataforma isolada etc.) estão no [AGENTS.md](../AGENTS.md#regras-de-arquitetura).
