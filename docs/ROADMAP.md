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
| **V2** Mundo pessoal | Casa, avatar, amigos e áreas privadas | 🗓️ planejada: [Fase 9](#fase-9-a-casa) |
| **V3** Mundo dinâmico | Biomas e arquitetura gerados a partir dos jogos | 🟡 base na [Fase 7](#fase-7-world-profile); biomas em [Depois](#depois) |
| **V4** Multiplayer e visitas | Visitar o mundo dos amigos, eventos | 🔭 horizonte |
| **V5** Linux e desktop | Rodar no Linux; o hub como ambiente de desktop (Hyprland) | ✅ Linux pronto ([Fase Linux](#fase-linux-feita)) + 🔭 horizonte (desktop) |
| **V6** Plataforma | Mundos, biomas e enfeites criados pela comunidade; loja | 🔭 horizonte |

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

### Fase 7: World Profile

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

**Pronto quando:** criar um bairro novo é escrever um perfil novo, mais um script de enfeite opcional, sem mexer em nenhum `match`.

### Fase 8: Escala

**Objetivo:** o hub continua gostoso com **centenas de jogos**.

**Entregas:**
- **Viagem rápida:** da busca (Tab) e dos pórticos direto para a porta do jogo ou para a entrada do bairro.
- **Bússola** (antigo P3.23): uma faixa no topo, com a seta do destino da busca.
- **Minimapa** (antigo P3.24): visto de cima, atualizado poucas vezes por segundo.
- **Transporte entre bairros:** metrô ou bonde, antes de qualquer carro.
- Teste de desempenho com uma **biblioteca falsa de ~200 jogos**, com ajustes de desenho à distância (LOD) se precisar.

**Pronto quando:** com 200 jogos, o hub continua leve, e qualquer jogo fica a menos de ~20 s de distância.

### Fase 9: A casa

**Objetivo:** o primeiro passo da ideia "a casa é o computador" (V2).

**Entregas:**
- Um **interior** onde o jogador nasce.
- O HUD em **forma física**: estante com a biblioteca, mural dos amigos e painel de configurações.
- O menu de pausa (Esc) continua existindo como atalho.

**Pronto quando:** dá para configurar tudo e escolher um jogo sem sair da casa.

### Fase Linux (feita)

Antecipada em 2026-10, quando o dono passou a usar um notebook com Omarchy. O desktop vai ter dual boot, então **Windows e Linux são alvos de primeira classe**. Plano e registro: [plans/fase-linux.md](plans/fase-linux.md).

**O que entregou:**
- **Mesma interface** em `autoload/platform/`: o `SteamClient` responde "onde está a Steam?", "quem está logado?" e "qual jogo está rodando?"; o `WindowHost` esconde e mostra a janela.
- **No Linux, o jogo rodando vem do processo `reaper`** que a Steam cria para cada jogo. O `~/.steam/registry.vdf` não guarda isso.
- **No Hyprland**, o jogo abre num workspace vazio do monitor escolhido, e o hub se esconde num workspace oculto e volta ao fechar o jogo.
- Detalhes técnicos em [PLATAFORMA](PLATAFORMA.md).

**Falta:** a conferência no Windows (checklist no fim do plano). A bateria passa inteira no Linux (24 testes), com Balatro, Skyrim, Valheim e Stardew instalados.

## Depois

- **Primeiro bioma** (antigo P3.27): uma montanha de gelo, com HDRI próprio, terreno e o mesmo HUD. Usa o World Profile.
- **Biomas gerados por código** a partir da biblioteca: RPG vira floresta ou castelo, corrida vira pista e garagens, terror vira neblina e abandono.

## Horizonte (sem compromisso)

Ideias guardadas para não se perderem. Nada aqui está planejado.

- **Multiplayer e visitas** (V4): visitar o mundo dos amigos. É o primeiro item com **custo de servidor**.
- **Desktop no Hyprland** (V5): o hub como ambiente de desktop no Linux.
- **Plataforma e comunidade** (V6): mundos, biomas e enfeites criados por usuários; loja.
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

## Regras que já valem

- **Dados de mundo em perfis:** a partir da Fase 7, cores, sons, enfeites e clima novos por categoria entram no perfil, e não em `match` espalhado.
- **Plataforma isolada:** código específico do Windows ou do Linux só em `autoload/platform/` (o `tests/check_platform.gd` confere). Os sistemas pedem "qual jogo está rodando?" ao `SteamClient`, e não "leia o registro".
