# Roadmap do Game Hub

Este arquivo é a **fonte única** do roadmap: para onde o projeto vai e em que ordem. O que já está pronto, e como usar, fica no [README](../README.md). Cada fase nova ganha um plano detalhado em [`docs/plans/`](plans/README.md) antes de começar.

## Visão: o norte

O Game Hub começou como um launcher 3D: uma cidade onde cada jogo da biblioteca Steam é um prédio. A ideia de longo prazo é maior. O projeto quer ser um **desktop virtual transformado em mundo**:

- **A casa é o computador.** Você mora numa casa, cabana ou tenda, e dentro dela ficam a biblioteca, os amigos, as configurações e as estatísticas. Sair da casa é "ir jogar".
- **A biblioteca é a matéria-prima do mundo.** Os seus jogos decidem os bairros, os biomas, a arquitetura, o clima e o som. Duas bibliotecas diferentes geram dois mundos diferentes.
- **Os amigos estão lá.** Hoje eles aparecem como hologramas. No futuro, você poderá visitar o mundo deles.
- **A inspiração é o PlayStation Home**: espaço pessoal, identidade, encontro e descoberta, com os jogos no centro.

O caminho dos dados, que não depende de engine:

```
Steam  →  dados do jogo  →  World Profile  →  gerador do mundo  →  engine  →  Game Hub
(biblioteca,  (tags, horas,     (bioma, clima,      (cidade hoje,      (Godot)
 amigos)       capas)            arquitetura, som)   biomas depois)
```

## As versões da visão (storyboard V1–V6)

| Versão | O que é | Situação |
|---|---|---|
| **V1** Cidade e categorias | Biblioteca Steam vira uma cidade com bairros por categoria | ✅ pronta (fases 1–6, visual v2) |
| **V2** Mundo pessoal | Casa, avatar, amigos e áreas privadas | 🟡 primeiro passo feito na [Fase 9](plans/fase-9.md); avatar, casa personalizável e estatísticas na [Fase 13](#fase-13-casa-parte-2) |
| **V3** Mundo dinâmico | Biomas e arquitetura gerados a partir dos jogos | 🟡 base na [Fase 7](plans/fase-7.md); primeiro bioma na [Fase 15](#fase-15-primeiro-bioma-o-bairro-rpg-na-montanha) e biomas pela biblioteca na [Fase 16](#fase-16-biomas-pela-biblioteca) |
| **V4** Multiplayer e visitas | Visitar o mundo dos amigos, eventos | 🔜 visita sem servidor na [Fase 17](#fase-17-visitar-a-cidade-de-um-amigo); ao vivo no [Horizonte](#horizonte-sem-compromisso) |
| **V5** Linux e desktop | Rodar no Linux; o hub como ambiente de desktop (Hyprland) | ✅ Linux pronto ([Fase Linux](#fase-linux-feita)); primeiro passo de desktop na [Fase 14](#fase-14-o-hub-no-omarchy); o hub como sessão inteira no [Horizonte](#horizonte-sem-compromisso) |
| **V6** Plataforma | Mundos, biomas e enfeites criados pela comunidade; loja | 🔜 perfis do usuário (local) na [Fase 18](#fase-18-mundos-abertos); compartilhamento e loja no [Horizonte](#horizonte-sem-compromisso) |

## O que já foi feito

- **Fases 1 a 6:** andar em primeira pessoa, portal de jogo com o `GameLauncher`, cidade gerada da biblioteca com bairros por categoria, launcher robusto, amigos como hologramas e polimento (horas jogadas, sons, dia e noite).
- **Visual v2 (P1):** céus HDRI, materiais PBR, telas "Abrindo" e "Jogando", avisos e cartão do jogo.
- **Visual v2, parte 2 (P2.12–P2.22):**
  - menu de pausa, busca com Tab e abertura pelo céu;
  - pórticos, prédios variados, horizonte, noite viva, hologramas humanos e árvores;
  - **identidade dos 10 bairros**, cada um com o seu elemento: telões, lâmpadas de cassino, névoa, placar, guindaste, estandartes, lampiões, mesa holográfica, varal de lâmpadas e totem.
- **Fase Linux** (antecipada em 2026-10): o hub roda no Linux (testado no Omarchy, com Hyprland). Windows e Linux ficam atrás da mesma interface em `autoload/platform/`. Falta só a conferência final no Windows antes de juntar na `main`.

Os detalhes estão no [README](../README.md) e no histórico do git.

## Próximas fases

A ordem vale até alguém decidir mudar. Antes de começar uma fase, o plano dela vai para `docs/plans/fase-N.md` e é aprovado.

### Fase 7: World Profile ✅ feita (no Linux; falta conferir no Windows)

**Objetivo:** tudo o que muda de um bairro para outro passa a ser **dado num perfil**, e não mais decisão espalhada pelo código. É a base da V3 (biomas) e deixa a lógica do produto independente de engine.

**Hoje esses dados estão espalhados em:**
- `autoload/game_categories.gd`: a tabela `CATEGORIES` (nome, cores, tags da Steam);
- `components/ambient_emitter/category_ambience.gd`: um `match` com o som de cada bairro;
- `worlds/city/district_props/district_props.gd`: um `match` com o enfeite de cada bairro;
- ids fixos dentro de enfeites (`rpg_banners.gd`, `sports_scoreboard.gd`, `strategy_table.gd`).

**Entregas:**
- Um **perfil por categoria**, com nome, cores, tags, som ambiente, enfeite do bairro, **clima**, arquitetura (estilo dos prédios), densidade e landmark. O formato (Resource `.tres` da Godot ou tabela) é decidido no plano da fase.
- Cidade, sons e enfeites **leem o perfil**.
- **Clima por bairro:** chuva leve à noite (antigo item P3.25), por exemplo uma garoa no bairro Terror.
- **PortalShell** (antigo item P3.26): separar o "invólucro" (prédio, arco de pedra, boxe de corrida) do `GamePortal`. O perfil diz qual invólucro usar.

**Feito:** perfis `.tres` em `profiles/`, `GameCategories` como fachada, som, enfeite, pesos de andares e parede e garoa vindos do perfil, `PortalShell` com prédio e arco. Densidade e landmark ficaram como campos reservados, sem efeito (vão para "Depois").

**Pronto quando:** criar um bairro novo é escrever um perfil novo, mais um script de enfeite opcional, sem mexer em nenhum `match`.

### Fase 8: Escala ✅ feita (no Linux; falta o desempenho no desktop)

**Objetivo:** o hub continua gostoso com **centenas de jogos**.

**Entregas:**
- **Viagem rápida:** da busca (Tab) e dos pórticos direto para a porta do jogo ou para a entrada do bairro.
- **Bússola** (antigo P3.23): uma faixa no topo, com a seta do destino da busca.
- **Minimapa** (antigo P3.24): visto de cima, atualizado poucas vezes por segundo.
- **Transporte entre bairros:** metrô ou bonde, antes de qualquer carro.
- Teste de desempenho com uma **biblioteca falsa de ~200 jogos**, com ajustes de desenho à distância (LOD) se precisar.

**Feito:** biblioteca falsa de 200 jogos para testes (`tests/fake_library.gd`) e `tools/medir_desempenho.gd`; planta da cidade como dado (`CityMap`); viagem rápida (Shift+Enter na busca); bússola; minimapa e mapa grande (M); metrô (`TransitStop` + `MetroEntrance`, com estações extras nos bairros grandes); capas comprimidas (memória de textura de 1,9 GB para 0,5 GB com 200 jogos). Ficaram para depois, se a medida no desktop pedir: LOD, sons e luzes só de perto. Bonde andando de verdade e clicar no mapa para viajar não entraram.

**Pronto quando:** com 200 jogos, o hub continua leve, e qualquer jogo fica a menos de ~20 s de distância.

### Fase 9: A casa ✅ feita (no Linux; falta a conferência no desktop)

**Objetivo:** o primeiro passo da ideia "a casa é o computador" (V2). Plano e registro: [plans/fase-9.md](plans/fase-9.md).

**O que entregou:**
- Um **loft** onde o jogador nasce em ~1 s, com a cidade montando em segundo plano; a abertura pelo céu saiu.
- O HUD em **forma física**: estante com a biblioteca (páginas e filtro por bairro), mural dos amigos e um computador cuja tela é o menu de configurações, clicável.
- **E para interagir**, também nas portas: a do loft e a "Casa" da praça.
- O menu de pausa (Esc), a busca e o mapa continuam funcionando em casa.

**Falta:** a conferência no desktop (Alta, e o pior quadro da montagem ≤ 50 ms). No notebook, em casa, a medida dá 60 FPS na Leve.

### Fase 10: Acabamento ✅ feita (no Linux; falta a conferência no desktop)

**Objetivo:** fazer o top 5 da [revisão de 2026-10-10](design/revisao-2026-10-10.md), que dá muito resultado com pouco trabalho. Plano e registro: [plans/fase-10.md](plans/fase-10.md).

**O que entregou:**
- Texturas com mipmaps e compressão de placa (inclusive os céus): o asfalto ao longe parou de granular, e a memória de textura caiu ~80 MB.
- Anti-aliasing por qualidade (Alta: MSAA 2x + SMAA; Média: SMAA; Leve: FXAA) e, na Leve, sombra do sol mais curta e mais barata.
- A UI escala com a tela (stretch `canvas_items`, base 1280 × 720), sem mudar a velocidade do mouse.
- O cartão do prédio diz "Entre pela porta para jogar"; a porta do loft diz "E para sair".
- Bairros com arquitetura própria (pesos de andares e paredes nos perfis) e um letreiro alto por bairro, acima de todos os telhados.
- Primeira vez guiada: cartão de controles, nascer virado para a estante e aviso de "A cidade está pronta".

**Falta:** a conferência no desktop (Alta com MSAA + SMAA). O resto da revisão fica para uma "Fase 11: Sensação e marcos" (game feel da porta e da câmera, marcos altos, tema único, som).

### Fase 11: Sensação e marcos ✅ feita (no Linux; falta a conferência no desktop)

**Objetivo:** os itens 5, 6 e 8 da "Ordem sugerida" da [revisão de 2026-10-10](design/revisao-2026-10-10.md): game feel da porta e da câmera, marcos altos (torre do relógio e um marco por bairro), som (música, fundo da cidade, passos de madeira) e itens soltos. Plano e registro: [plans/fase-11.md](plans/fase-11.md).

**O que entregou:** curvas em todas as transições de UI; câmera com balanço, afundada ao pousar e FOV de corrida (com opção para desligar); a porta que "pesa" (FOV, avanço, vão aceso e som novo); sensibilidade do mouse e FOV nas opções; torre do relógio na praça e um marco alto por bairro; canal Música, fundo da cidade, som de "Outros" e passos de madeira com eco em casa; título ao entrar no bairro. A medida no notebook (Leve, 200 jogos) piorou ~0,5 FPS.

**Falta:** a conferência no desktop e ouvir os sons (as escolhas foram feitas pelo nome do arquivo).

### Fase 12: Tema e controles ✅ feita (no Linux; falta a conferência com o controle no desktop)

**Objetivo:** tema único para todas as telas (revisão 5.2), menu pelo teclado e **controle Xbox para jogar tudo** (5.3), com as dicas na tela trocando entre teclas e botões conforme o aparelho usado. Plano e registro: [plans/fase-12.md](plans/fase-12.md).

**O que entregou:** o `HubTheme` (5 tamanhos de letra, um raio, duas cores de painel) usado por todas as telas; o menu de pausa e o computador da casa navegáveis por setas, Enter e Esc; o controle Xbox andando, olhando, pulando, interagindo e usando busca, mapa, metrô, pausa e computador; a busca rolando por todos os jogos; e as dicas ("Esc", "E", "Segure E para jogar") que viram os botões do controle quando ele é usado.

**Falta:** a conferência à mão com o controle de verdade, no notebook e no desktop (Windows, XInput). Os testes automáticos usam eventos falsos.

### Fase Linux (feita)

Antecipada em 2026-10, quando o dono passou a usar um notebook com Omarchy. O desktop vai ter dual boot, então **Windows e Linux são alvos de primeira classe**. Plano e registro: [plans/fase-linux.md](plans/fase-linux.md).

**O que entregou:**
- **Mesma interface** em `autoload/platform/`: o `SteamClient` responde "onde está a Steam?", "quem está logado?" e "qual jogo está rodando?"; o `WindowHost` esconde e mostra a janela.
- **No Linux, o jogo rodando vem do processo `reaper`** que a Steam cria para cada jogo. O `~/.steam/registry.vdf` não guarda isso.
- **No Hyprland**, o jogo abre num workspace vazio do monitor escolhido, e o hub se esconde num workspace oculto e volta ao fechar o jogo.
- Detalhes técnicos em [PLATAFORMA](PLATAFORMA.md).

**Falta:** a conferência à mão no Windows (checklist no fim do plano). A bateria passa inteira no Linux (25 testes), com Balatro, Skyrim, Valheim e Stardew instalados, e o GitHub Actions já confere o backend do Windows (`reg.exe` e `tasklist` de verdade); falta abrir um jogo de verdade e ver a janela.

### A ordem a partir da Fase 13

Decidida em 2026-10-12. Até ~18/10/2026 o dono está só no **notebook** (Radeon 610M, qualidade Leve); o **desktop** (RTX 4070, Windows e Linux) é a régua de desempenho e de visual. Por isso vêm primeiro as fases que rodam bem no notebook (13 e 14), depois os biomas, que pedem o desktop para o visual final. O que só o desktop responde fica numa trilha à parte.

| Fase | Nome | Versão | Onde dá para fazer |
|---|---|---|---|
| [13](#fase-13-casa-parte-2) | Casa, parte 2 | V2 | notebook ✅ |
| [14](#fase-14-o-hub-no-omarchy) | O hub no Omarchy | V5 | notebook ✅ (é o lugar ideal) |
| [—](#trilha-do-desktop) | Trilha do desktop (a partir de 18/10, entre duas fases) | todas | só desktop |
| [15](#fase-15-primeiro-bioma-o-bairro-rpg-na-montanha) | Primeiro bioma: o bairro RPG na montanha | V3 | notebook (Leve) + desktop (Alta) |
| [16](#fase-16-biomas-pela-biblioteca) | Biomas pela biblioteca | V3 | notebook (Leve) + desktop (Alta) |
| [17](#fase-17-visitar-a-cidade-de-um-amigo) | Visitar a cidade de um amigo | V4 (sem servidor) | notebook ✅ |
| [18](#fase-18-mundos-abertos) | Mundos abertos | V6 (local) | notebook ✅ |

Cada fase ganha o seu `docs/plans/fase-N.md` (Opus, modo plan, aprovado) só quando começar.

### Fase 13: Casa, parte 2

**Versão:** V2. **Onde testar:** notebook ✅.

**Objetivo:** a casa vira "sua": dá para mudar, mostra a sua história de jogador e você ganha um rosto.

**Entregas:**
- **Estatísticas na parede:** horas totais, os mais jogados, horas por bairro e o jogado mais recente (dados que o `SteamLibrary` já lê do `localconfig.vdf`).
- **Temas da casa como dado** (regra 4): um `HomeProfile` (`.tres`) com materiais, cores, luzes e móveis. O loft atual vira o primeiro perfil, e entra um segundo tema (cabana). A troca é pelo computador da casa.
- **Personalizar:** cor das paredes, do néon e posições prontas de móveis (lugares fixos, sem arrastar livre).
- **Avatar:** escolher a aparência (o modelo da Quaternius que já está no projeto, com cores) e vê-la num espelho na casa. É a mesma figura que os amigos verão na V4.

**Pronto quando:** trocar de loft para cabana pelo computador muda a casa na hora, sem código novo por tema; a parede mostra as estatísticas reais; o espelho mostra o avatar escolhido, que fica salvo no `config.cfg`.

### Fase 14: O hub no Omarchy

**Versão:** V5 (primeiro passo de desktop). **Onde testar:** notebook ✅ (é o lugar ideal).

**Objetivo:** o hub começa a ser parte do desktop no Linux, e não só um launcher da Steam.

**Entregas:**
- **Apps além da Steam:** os programas instalados (arquivos `.desktop` no Linux; atalhos do Menu Iniciar no Windows) viram portais, num bairro "Apps" ou numa estante de apps na casa. Abrir um app usa o mesmo fluxo de "Abrindo" e de voltar.
- **Sistema dentro da casa:** relógio real, bateria, rede e volume num painel físico (uma parede ou o computador).
- **Iniciar com o sistema e atalho global:** entrada de autostart e um atalho do Hyprland para chamar o hub.
- Tudo de sistema operacional só em `autoload/platform/` (regra 5), com o backend do Windows mínimo (só a lista de apps).

**Pronto quando:** no notebook, abrir o Firefox ou o terminal pelo hub funciona como abrir um jogo (o hub some e volta), e a casa mostra a bateria certa.

### Trilha do desktop

**Versão:** todas. **Onde testar:** só no desktop, a partir de 18/10/2026, entre duas fases (sem número fixo).

**Objetivo:** fazer tudo o que só o desktop responde e juntar o trabalho na `main`.

**Entregas:**
- **Conferências pendentes:** desempenho na Alta (fases 8–12; pior quadro da montagem ≤ 50 ms), Windows (Fase Linux e Fase 7), controle Xbox de verdade (Fase 12) e ouvir os sons da Fase 11.
- **A luz que esperava a medida** ([revisão](design/revisao-2026-10-10.md) 4.3 e 8.2): sombra nos postes de perto, `distance_fade` e GI só na Alta.
- Juntar a `fase-linux` na `main`, se o dono pedir.

**Quando começar:** ganha o próximo número livre e um plano curto.

### Fase 15: Primeiro bioma, o bairro RPG na montanha

**Versão:** V3. **Onde testar:** notebook (Leve) + desktop (Alta).

**Objetivo:** provar a ideia "a biblioteca decide o mundo" com um bioma só (antigo P3.27), feito nos quarteirões do próprio bairro, no mesmo mapa da cidade (não é um mundo separado).

**Entregas:**
- O perfil do bairro ganha um **bioma** (dado): chão (neve e pedra no lugar do asfalto), invólucro dos portais (o arco de pedra, que já existe), enfeites espalhados (pinheiros e rochas), clima (neve, reaproveitando a garoa), névoa e som.
- Morros de fundo e uma subida no setor do bairro (terreno simples, feito por código), sem quebrar ruas, metrô e minimapa.
- A cidade continua igual nos outros bairros.

**Risco a decidir no plano:** hoje os quarteirões de um bairro seguem os anéis em volta da praça (um arco, e não uma área compacta). O plano decide se o layout passa a agrupar o bairro num setor contíguo.

**Assets:** pinheiro e rocha CC0 (pedir permissão antes de baixar, com nome, origem e tamanho).

**Pronto quando:** com a biblioteca de verdade e com 200 jogos falsos, o bairro RPG é uma montanha nevada com os portais nela, e a medida no notebook (Leve) não piora mais de ~3 FPS.

### Fase 16: Biomas pela biblioteca

**Versão:** V3. **Onde testar:** notebook (Leve) + desktop (Alta).

**Objetivo:** cada categoria pode ter o seu bioma, e o que você joga molda o lugar.

**Entregas:**
- Um tipo de bioma genérico (`BiomeSpec`) com 3 ou 4 biomas além da montanha (floresta, pista e garagens, neblina e abandono), escolhidos pelo perfil de cada bairro. "Cidade" continua sendo o padrão.
- O bioma reage à biblioteca: o tamanho e o marco do bairro crescem com as horas jogadas, e os jogos mais jogados ficam no ponto mais alto ou mais central.
- Escolher o bioma de um bairro pelo `config.cfg` (como já se escolhe o bairro de um jogo).

**Pronto quando:** criar um bioma novo é escrever um perfil, sem mexer em código da cidade (como a Fase 7 fez com os bairros).

### Fase 17: Visitar a cidade de um amigo

**Versão:** V4, sem servidor. **Onde testar:** notebook ✅.

**Objetivo:** o primeiro passo de "visitar o mundo dos amigos", com custo zero.

**Entregas:**
- Ler a biblioteca **pública** de um amigo pela Steam Web API (`GetOwnedGames`, com a mesma chave já configurada).
- A cidade passa a ser montada a partir de uma "fonte de biblioteca" (a sua ou a de um amigo), e não direto do `SteamLibrary`.
- No mural da casa, "Visitar a cidade de Ana": a tela escurece e você anda na cidade dela, com os bairros e biomas que a biblioteca dela gera. Portas de jogos que você não tem mostram "Ver na loja" em vez de abrir.
- O amigo aparece como o holograma de sempre (com o avatar da Steam) na praça da cidade dele. O avatar escolhido na Fase 13 só chega aos outros com servidor (V4 ao vivo, no Horizonte).

**Pronto quando:** com um amigo de perfil público, dá para visitar a cidade dele e voltar para casa, sem nenhuma conta ou servidor novo.

### Fase 18: Mundos abertos

**Versão:** V6, primeiro passo (local). **Onde testar:** notebook ✅.

**Objetivo:** o usuário cria bairros, biomas e casas sem programar, com **perfis do usuário**.

**Entregas:**
- Uma pasta de perfis do usuário em `user://` (bairros, biomas e temas de casa), lida junto com os do projeto.
- Formato documentado, com validação e aviso amigável de erro.
- Um exemplo pronto e um guia curto no README.

**Pronto quando:** copiar um perfil de bioma para a pasta do usuário e reabrir o hub faz o bioma aparecer, sem tocar no projeto.

## Depois

Vazio: em 2026-10-12, tudo o que estava aqui virou fase (13 a 18).

## Horizonte (sem compromisso)

Ideias guardadas para não se perderem. Nada aqui está planejado.

- **V4 ao vivo:** ver o amigo andando na cidade, com o avatar que ele escolheu, e eventos. É o primeiro item com **custo de servidor**. A visita sem servidor é a [Fase 17](#fase-17-visitar-a-cidade-de-um-amigo).
- **V5 completo:** o hub como a sessão inteira do Hyprland, e não um programa dentro dela. O primeiro passo é a [Fase 14](#fase-14-o-hub-no-omarchy).
- **V6 com compartilhamento e loja:** mundos, biomas e enfeites criados por usuários, trocados entre eles. O primeiro passo, local, é a [Fase 18](#fase-18-mundos-abertos).
- **Veículos**, em degraus do mais simples ao mais caro:
  1. carros decorativos seguindo caminhos;
  2. dirigir um veículo simples;
  3. transporte público entre bairros (já coberto pela Fase 8);
  4. tráfego com semáforos e rotas.

  Simulação realista de carro não serve ao produto. **Transporte público vem antes de dirigir.**

## Decisões registradas

- **Engine: seguir na Godot.** O hub fica aberto junto com os jogos, então ser leve é requisito. A Unreal 5 só entraria se o foco visual ou procedural justificar, e o World Profile em dados mantém essa porta aberta.
- **Sem protótipo paralelo agora** (Astra, web 3D...). Ele dividiria o esforço antes de a experiência atual estar validada.
- **Monetização depois.** Primeiro, validar que o hub continua divertido depois que passa a novidade.
- **Ordem das fases 13 a 18** (2026-10-12): a V2 vem primeiro (Casa, parte 2); **o bairro vira o bioma**, nos quarteirões do próprio bairro e no mesmo mapa da cidade; e a **V4 começa sem servidor**, visitando a cidade gerada da biblioteca pública de um amigo.

## Regras que já valem

- **Dados de mundo em perfis:** a partir da Fase 7, cores, sons, enfeites e clima novos por categoria entram no perfil, e não em `match` espalhado.
- **Plataforma isolada:** código específico do Windows ou do Linux só em `autoload/platform/` (o `tests/check_platform.gd` confere). Os sistemas pedem "qual jogo está rodando?" ao `SteamClient`, e não "leia o registro".
