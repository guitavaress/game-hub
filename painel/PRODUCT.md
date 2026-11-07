# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
Um usuário só: o dono do Game Hub. Ele tem conhecimento básico de programação, lê em português e acompanha um projeto tocado por agentes de IA (Claude Code e Codex, pelo Orca). Abre o painel no navegador do desktop para **ler com calma e decidir**: entender onde o projeto está, ler planos, ideias e o ROADMAP, e escolher o próximo passo ou o que aprovar.

## Product Purpose
Mostrar o cofre `docs/` (o Obsidian do projeto) e o git como um painel visual. A pergunta que ele tem que responder em 3 segundos é **"quanto o projeto andou?"**: fases feitas, a fase atual, a linha do tempo e o ritmo de commits. Depois disso, ele serve para ler os documentos e decidir. Dá certo quando o dono abre, entende o progresso sem procurar e encontra o texto que precisa para a próxima decisão.

## Positioning
Não é um gerenciador de tarefas genérico: é o próprio cofre de um projeto real, lido ao vivo dos arquivos `.md` e do git, sem cadastro e sem banco. O progresso vem do que os agentes marcam (`[x]` nos planos, commits). O projeto é um launcher em forma de cidade 3D, e o painel pode usar essa imagem (cada fase um prédio, cada subetapa feita uma janela acesa), que nenhum outro painel tem.

## Operating Context
- Os agentes editam `docs/` e fazem commits enquanto o dono trabalha. O painel confere os arquivos e o git a cada 2 s e avisa o que mudou.
- As notas são escritas no Obsidian. O painel só lê, e "Abrir no Obsidian" leva até a nota.
- Fontes de dados: `docs/plans/fase-N.md` (subetapas com `[ ]`/`[x]`), `docs/ROADMAP.md`, a linha do tempo (gantt) do `docs/Início.md`, `docs/ideias/`, o resto dos `.md` e o `git log`.
- Roda no Docker Desktop do Windows, em http://localhost:4170.

## Capabilities and Constraints
- Seções atuais: Agora, Fase atual, Rumo, Linha do tempo, O que falta, Ideias, Atividade (git) e Documentos. Leitor de documentos com links entre notas, busca (`Ctrl+K` ou `/`), avisos ao vivo, tema claro e escuro, botão para desligar as animações.
- **Só lê.** O repositório entra no contêiner como somente leitura, e o painel nunca escreve no cofre.
- O e-mail do git nunca aparece. Capas de jogos nunca entram (o repositório é público).
- Stack: React 19, Motion 12 e marked, compilados com o Vite. O servidor é Node sem dependências. Tudo fica em `painel/` e nada disso entra no hub (a Godot).
- Interface em português do Brasil, com texto simples.
- Em aberto: o uso no celular ou no notebook. Hoje o uso é no desktop, e o layout para telas pequenas existe, mas é secundário.

## Brand Commitments
- **Obrigatórios** (dono, 2026-11-07): o nome "Game Hub", o logo (`public/logo.png`, `public/simbolo.svg`) e **a paleta de cores** do brand kit (`game-hub-brand-kit/design-tokens.css`: void `#07121E`, navy `#0D1C2E`, surface `#132D49`, blue `#1269B7`, electric `#168EEA`, cyan `#24BAF5`, glow `#67E8F9`, paper `#F6FAFE`).
- **Livres** (dono, 2026-11-07): a tipografia, o layout, a composição e o estilo. O resto do brand kit (Space Grotesk, raios, grade de fundo, brilhos) não obriga nada.

## Evidence on Hand
Só dados reais do cofre e do git: as fases e as subetapas dos planos, o ROADMAP, o gantt do `Início.md`, as ideias e os commits. Nenhum número de progresso, data ou prazo pode ser inventado. Quando um dado falta (ex.: uma fase sem plano), o painel mostra que falta.

## Product Principles
1. **O progresso vem primeiro:** a primeira tela responde "quanto andou?" antes de qualquer outra coisa.
2. **O texto do cofre é o conteúdo:** ler um plano ou uma ideia tem que ser confortável, e não espremido num cartão.
3. **Só a verdade do cofre:** o painel mostra o que está escrito e marcado, sem inventar nem enfeitar números.
4. **Calmo, mas vivo:** a mudança ao vivo aparece sem tirar o foco da leitura.
5. **Português simples:** os nomes e os rótulos usam a linguagem do dono, e não o jargão de ferramenta.

## Accessibility & Inclusion
- Respeitar o "reduzir movimento" do sistema e manter o botão que desliga as animações.
- Os dois temas (claro e escuro) com contraste legível. O brilho do brand kit é decoração e não substitui texto acessível.
- Tudo funciona pelo teclado (busca, leitor, navegação).
