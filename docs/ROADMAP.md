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
| **V3** Mundo dinâmico | O que você joga molda o lugar | 🟡 primeiro bioma na Fase 15; [biomas baratos](#4-biomas-baratos-poc) |
| **V4** Amigos | Encontrar e visitar os amigos | 🔜 [Visitar amigos (V-Sekai)](#3-visitar-amigos-v-sekai) |
| **V5** Desktop | O hub como ambiente de desktop | ⏸️ mesa com três monitores na Fase 14 (só Linux); [parado](#parados) |
| **V6** Plataforma | Mundos criados pela comunidade, loja | [Horizonte](#horizonte-sem-compromisso) |

## Próximas fases

Nesta ordem, até alguém decidir mudar. **O número é dado quando a fase começa** (o próximo livre, a partir de 19), com o plano aprovado em `plans/fase-N.md`.

Os planos e as revisões antigas citam outros números: a "Fase 16" deles é a fase 4 abaixo (biomas), a "Fase 17" é a 3 (amigos) e a "Fase 18" está em [Parados](#parados).

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

**Andamento:** é a [Fase 18](plans/fase-18.md), em andamento desde 2026-11-10. Decidido no plano: a entrega é um zip num Release do GitHub, o feedback é um botão que copia um resumo, e a chave da Steam é opcional (o hub não cobra). Feitas: a 18.0 (a branch e o plano), a 18.1 (a versão 0.18.0 no menu de pausa e o export sem sobras) a 18.2 (o `.exe` abre e monta a cidade, com o ícone casa-portal; `tools/empacotar_windows.sh` gera e confere o build) e a 18.3 (na primeira abertura, a porta da casa diz o que está acontecendo; sem internet, nada fica 7 dias sem capa; PC fraco recebe uma sugestão da Leve; `tools/pc_limpo.ps1` testa como num PC limpo). e a 18.5 (o botão "Contar o que achei" no menu de pausa copia um resumo para mandar ao amigo). e a 18.4 (sem chave, o mural da casa convida com 3 passos e abre a pausa na aba Amigos; nenhum aviso no HUD) e a 18.6 (o `tools/empacotar_windows.sh` gera o zip com o `.exe`, o LEIA-ME e as licenças, e recusa o pacote se achar algo pessoal, até dentro dos scripts do pck). Próxima: a 18.7 (o Release, a pedido do dono).

### 3. Visitar amigos (V-Sekai)
**Objetivo:** o encontro com os amigos acontece **dentro do hub**, com peças do [V-Sekai](https://github.com/v-sekai) (MIT): avatar VRM, espelho, voz, sala de encontro e ideias de rede. Substitui a "visita sem servidor" de antes.

**Primeira subetapa, um estudo curto.** Atualiza o [estudo de 15/10](design/exploracao-open-source-2026-10-15.md) e responde:
- que funções queremos;
- para cada uma: a licença, se roda na Godot 4.7.2 oficial e se precisa de servidor;
- qual é o menor encontro que dá para testar.

**As ferramentas do estudo:**
- o código do V-Sekai, que é aberto;
- o **REA** (engenharia reversa), só no que existe apenas compilado ou em execução. As regras de uso estão no [AGENTS.md](../AGENTS.md#modelos-e-esforço).

**Pronto quando:** o plano da fase sai do estudo, com o menor encontro definido.

### 4. Biomas baratos (PoC)
**Objetivo:** provar o coração da V3 ("o que você joga molda o lugar") sem o custo da montanha.

**Entregas:**
- 2 ou 3 biomas só com chão, enfeites e clima, sem terreno;
- o bairro (e o marco dele) cresce com as horas jogadas;
- as sobras da Fase 15: a encosta com pinheiros e rochas, o canto côncavo da divisa neve/asfalto e o destaque da torre de dia.

**Pronto quando:** um bioma novo é um perfil novo, e dá para ver um bairro maior que outro pelas horas jogadas.

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
- **V4 ao vivo:** ver o amigo andando, com o avatar dele, e eventos. É o primeiro item com custo de servidor; a fase 4 diz se ele é necessário.
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

As regras de arquitetura (dados de mundo em perfis, plataforma isolada etc.) estão no [AGENTS.md](../AGENTS.md#regras-de-arquitetura).
