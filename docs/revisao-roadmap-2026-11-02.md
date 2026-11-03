# Revisão da ROADMAP (2026-11-02)

O dono sente que o projeto está gastando tempo demais e que não está direcionando os agentes da melhor forma. Este arquivo reúne perguntas sobre a [ROADMAP](ROADMAP.md) inteira, inclusive as fases feitas. **Responda direto aqui, no campo "Resposta"** (curto vale: "sim", "não sei", "corta"). Com as respostas, a ROADMAP, o AGENTS.md e o modelo de plano são revistos numa rodada de planejamento.

## O que os números mostram
- **Fases 1–6 + visual v2:** 2 dias (26–28/09).
- **Fases 7–13:** 8 dias (05–12/10), ~130 commits.
- **Fase 14:** 1 semana, 49 commits, refeita 3 vezes (launcher → telões → mesa com três monitores).
- **Fase 15:** 16 dias (17/10–02/11) para **um** bairro, com ~25 commits no meio sobre ferramentas (Laya, Jev, capturas). A meta de montagem (50 ms) não passou.
- **Planos:** de 117 linhas (Fase 7) para ~640 (fases 14 e 15). Cada sessão de agente lê o AGENTS.md (174 linhas) mais o plano, e isso gasta cota.
- **Fluxo de trabalho:** mudou 4 vezes em 5 semanas (Claude sozinho → OpenCode → Claude + Codex → duas trilhas no Orca). Agora há também um rascunho de Paperclip + OmniRoute.
- **Dívida:** 8 fases (8 a 15) dizem "falta a conferência no desktop". A Trilha do desktop existe desde 18/10 e nunca foi feita. Os sons da Fase 11 foram escolhidos pelo nome do arquivo e até hoje ninguém os ouviu.
- **Tamanho:** 85 testes e ~43 mil linhas de GDScript.

**Hipótese do Claude, para você confirmar ou derrubar:** o tempo está indo menos para o hub e mais para (a) as trocas de ferramenta e de fluxo, (b) a cerimônia por subetapa e os planos longos, e (c) o polimento de coisas que ninguém usa no dia a dia, sem uma regra de "usar antes de seguir".

**Resposta:** A

---

## A. Para que e para quem

**1. Você abre o hub para jogar no dia a dia, no lugar da Steam?** Se não, o que te impede? A ROADMAP diz: "primeiro validar que o hub continua divertido depois que passa a novidade". Essa validação aconteceu?

**Resposta:** Ainda não ocorreu, não estou testando diariamente ainda.

**2. Para quem é o hub:** só você, você e os amigos, ou um produto público? O brand kit e o rascunho de Paperclip sugerem produto. Se for só para você, metade das pendências cai (200/1000 jogos, controle Xbox, Windows conferido).

**Resposta:** Produto mesmo. MVP terá 3 fases: Para mim, para mim e amigos, e público (provavelmente irá envolver custos e questões de legalidade + monetização). Quando a fase for para público iremos desenvolver um PoC para publicar em plataformas como o Reddit, em r/ especificos.

**3. O que é "tempo demais" para você:** horas suas, cota do Claude e do Codex, ou a frustração de ver pouca mudança visível no hub?

**Resposta:** Frustração de pouca mudança estar ocorrendo durante dias.

**4. Qual é o momento "uau"** que um amigo deve ter nos primeiros 5 minutos? Alguma fase já entregou esse momento?

**Resposta:** Acredito que não, ainda não levei a amigos. Sinto que o produto cidade estava funcional mas sem aspecto Wow. O que realmente está muito bom é a performance e está funcional perfeitamente.

## B. Fases feitas: valeram o que custaram?

**5. Ritmo:** as fases 7–13 levaram 8 dias, e a 15 levou 16 dias para um bairro. O que pesou mais: a dificuldade real (terreno), o escopo, ou o processo (trilhas, revisões, ferramentas)?

**Resposta:** Acho que o processo, e o fato de eu estar desenvolvendo isso no meu notebook e somente no dia 18 ter chego no meu PC principal, e alguns dias nem toquei no projeto.

**6. Fase 7 (World Profile):** você já criou um bairro só escrevendo um perfil? A "densidade" e o "landmark" continuam sem efeito. A abstração veio antes da necessidade?

**Resposta:** Acho que sim. Focamos na montanha gélida, só que com o híbrido da cidade traz alguns aspectos interessantes, mas sinto que está muito... "básico", sabe? Não sei descrever muito bem perdão, é um feeling, o desenvolvimento do mirante está levando em conta um caminho de design que não sei se é o correto, está tudo muito... meh. Funcional mas não criativo sabe?

**7. Fase 8 (Escala):** quantos jogos você tem instalados de verdade? Se forem algumas dezenas, o metrô e a otimização para 200 e 1000 jogos eram para agora?

**Resposta:** São poucos jogos, mas gostei da ideia de termos os espaços para instalar os jogos por dentro do Game Hub, achei bem legal isso.

**8. Fases 9 e 13 (casa):** desde 12/10, você usou a estante, o espelho, o quadro de estatísticas ou a troca de loft para cabana? O que nunca foi usado?

**Resposta:** Tudo foi usado, entretanto a casa está muito vazia, e nada aconchegante. Fora que o visual da janela está péssimo.

**9. Fase 12 (controle Xbox):** você joga com controle? A conferência está pendente há 3 semanas.

**Resposta:** Não jogo, mas está perfeito, sem reclamações.

**10. Fase 11 (sons):** os sons nunca foram ouvidos e ninguém sentiu falta. Isso diz que o som não importa agora, ou que ninguém está testando o hub de fato?

**Resposta:** Não importa por hora, e não será o efeito Wow, temos prioridades antes, mas provavelmente terei que investir um dinheiro para ter efeitos para o projeto.

**11. Fase 14 (compositor em Rust, só no Linux):** a fase mais cara do projeto, refeita 3 vezes. Você usa a mesa com três monitores no dia a dia? No desktop, você vai usar mais o Windows ou o Linux? Se for o Windows, ela não roda na máquina que é a meta.

**Resposta:** Gastamos tempo no Linux durante 15 dias, então aproveitei para desenvolver essa etapa em paralelo. Agora que estamos no Linux iremos dar uma pausa nessa questão, temos prioridades antes.

**12. Fase 15:** você foi até o mirante mais de uma vez? Os setores contínuos (a base da 16) já mudaram alguma coisa que você vê?

**Resposta:** Sim, trilha ficou ok mas sem conteúdo, e o Mirante horrível.

## C. Dívida: "feita, falta conferir"

**13. Há 8 fases com conferência pendente.** Fazemos tudo num dia só, com um checklist único? Ou declaramos o que não importa e apagamos?

**Resposta:** Fazemos tudo em um dia só com checklist único ao meu ver.

**14. A meta de 50 ms na montagem:** a cidade monta enquanto você está no loft. Um tranco de 86 ms nesse momento dá para perceber? A base já dava 73 ms. Talvez a meta esteja errada, e não o código.

**Resposta:** Não consegui sentir muito para ser honesto, vamos deixar mais em aberto essa otimização pois não estamos nem próximos de um produto legal, somente funcional e bem em fase inicial.

**15. Uma fase só deve contar como feita depois que você a usou de verdade?** Por exemplo: uma semana de uso, com uma nota de 3 linhas.

**Resposta:** Não precisa.

## D. O processo (onde o Claude suspeita que o tempo vai)

**16. O fluxo mudou 4 vezes em 5 semanas**, e há um quinto (Paperclip) na mesa. Cada troca custa sessões só de documentação. Congelamos o fluxo atual por, digamos, 3 fases?

**Resposta:** Pode ser, precisamos fazer uma atualização do ROADMAP com o que foi feito e planos para futuro.

**17. Laya e Jev:** foram ~25 commits, e a ferramenta "com prioridade sobre a Fase 15". A triagem de falhas economizou mais tempo do que custou? A bateria falhava tanto assim?

**Resposta:** Isso não sei dizer, achei que ia ajudar muito, até coloquei dinheiro, mas não está se pagando até o momento.

**18. Duas trilhas em paralelo** (Claude e Codex): o ganho compensa a entrega, o merge e a revisão cruzada? Para quem tem conhecimento básico, coordenar 2 agentes e 6 modelos também é trabalho seu.

**Resposta:** Sinto que a limitação está mais em desenvolvermos em Godot e que não podemos ficar tocando muito em paralelo, e infelizmente somente 2 trilhas. A ideia seria o Opus gerir as trilhas e subagentes tocarem essa parte (ou workers no Orca)

**19. Revisão cruzada em quase toda subetapa:** muitas saíram "sem defeitos". Deixamos a revisão só para os pontos de risco (geometria, compositor, dados que se perdem)?

**Resposta:** Sim

**20. Planos de ~640 linhas:** você lê todos? Um plano de 1 página (objetivo, pronto quando, subetapas de 1 linha, decisões) resolveria?

**Resposta:** Pode deixar detalhado sim, falha minha ai

**21. Cerimônia por subetapa** (bateria completa, captura, revisão, `[x]`, resumo, checklist, commit): ela vale para toda subetapa, ou só para as grandes? Um commit só de docs precisa da bateria inteira?

**Resposta:** Só para grandes ao meu ver.

**22. Quanto do seu tempo vai para ler planos e resumos, e quanto para testar o hub?** Se a leitura passa do teste, o fluxo está invertido.

**Resposta:** Sim, hoje leio mais o plano do que testo.

**23. Como você prefere direcionar:** aprovar subetapas uma a uma, ou dar um resultado ("quero X, me mostre quando estiver bom") e testar só o fim?

**Resposta:** Aprovar subetapas 1 a 1

## E. O futuro (fases 16, 17, 18 e o Horizonte)

**24. Qual é o norte de verdade:** um launcher de jogos bonito (cidade, amigos) ou um desktop virtual (Waylandcraft, V5)? Os dois disputam o mesmo tempo.

**Resposta:** Launcher de Jogos + Ambiente Virtual de interação com amigos.

**25. Fase 16 (3 ou 4 biomas):** se um bioma levou 16 dias, quanto vão levar 4? Fazemos biomas "baratos" (chão, enfeites e clima, sem terreno) e só a parte que é o coração da visão (o bioma cresce com as horas jogadas)?

**Resposta:** Essa parte dos biomas que me pega, a minha ideia era um pouco mais grandiosa do que estou vendo atualmente, está bem "barato" hoje como falou. Se for para servir como PoC vamos seguir com o barato e sempre de olho no futuro.

**26. Fase 17 (visitar um amigo)** é o que mais lembra o PlayStation Home (encontro). Ela deveria vir **antes** da 16? Seus amigos têm perfil público na Steam?

**Resposta:** Essa etapa iremos realizar com REA no V-sekai. Ele trará otimas funcionalidades que já existem nele e que são amplamente utilizadas no VRChat

**27. Fase 18 (perfis do usuário):** sem outros usuários, quem vai usar? Ela fica parada até alguém além de você testar o hub?

**Resposta:** Fica parada no momento.

**28. Falta uma fase "mostrar para alguém"?** Um build para 2 ou 3 amigos testarem, antes de mais mundo.

**Resposta:** Falta sim ao meu ver.

**29. Brand kit e Paperclip:** você está pensando em produto ou em equipe? Se sim, isso muda a ordem toda. Se não, eles saem da mesa.

**Resposta:** Pensando em produto no final, mas é um projeto passional meu.

## F. A ROADMAP como documento

**30. Reescrever a ROADMAP com só o futuro** e uma tabela das fases feitas (uma linha cada), deixando o histórico nos planos? Isso também corrige as inconsistências de hoje:
- a linha da V3 marca ✅ a Fase 16, que ainda não existe;
- "fluxo e modelos em OPENCODE.md", que saiu do fluxo;
- "Juntar a fase-linux na main", que já foi feito;
- a Fase 15, feita, continua em "Próximas fases";
- "O que já foi feito" repete o README, e o histórico ocupa ~2/3 do arquivo.

**Resposta:**  Pode ser!

---

## Pendência achada ao montar este cofre
- ✅ **Resolvida em 2026-11-02 (`7c4a5e9`).** O `check_daynight` dependia do céu salvo no `config.cfg`: com `sky="sky3d"`, o `sun` do relógio fica vazio (de propósito) e o teste quebrava na linha 51. Agora o teste guarda o céu do usuário, usa o de fotos e devolve o céu no fim.

---

## Decisões

Rodada de planejamento feita com as respostas acima, em 2026-11-02. O dono também esclareceu três pontos:
- a resposta "A" da hipótese quer dizer **concordo com tudo**;
- a visita aos amigos acontece **dentro do hub**, com peças do V-Sekai, estudadas com o código dele e com o **REA**, que o dono instalou;
- a ordem das fases é **Leitura → Uau → Amigos**.

| Resposta | Decisão | Onde ficou |
|---|---|---|
| Hipótese, 16 | Fluxo congelado por 3 fases. O REA é a única exceção, só no estudo do V-Sekai | [AGENTS.md](../AGENTS.md#modelos-e-esforço) |
| 18 | O Opus coordena; as subetapas pequenas rodam como subagentes ou workers do Orca | AGENTS.md |
| 19, 21 | Subetapa grande × pequena; revisão cruzada só nas grandes de risco; commit de docs sem bateria | [AGENTS.md](../AGENTS.md#fluxo-de-uma-fase) |
| 20, 22, 23 | Plano detalhado com o bloco "Para o dono"; o resumo começa pelo que se vê; aprovação uma a uma | [plans/README.md](plans/README.md) |
| 13 | Um dia de conferência, com checklist único | [conferencia-desktop.md](plans/conferencia-desktop.md) |
| 9, 10, 14 | Controle conferido; sons e meta de 50 ms parados | [ROADMAP](ROADMAP.md#parados) |
| 11, 24 | Norte: launcher + encontro com amigos; compositor e V5 em pausa | [ROADMAP](ROADMAP.md#visão) |
| 2, 28, 29 | Produto em 3 etapas; fase "Mostrar para amigos"; brand kit no Horizonte | [ROADMAP](ROADMAP.md#o-caminho-do-produto) |
| 4, 6, 8, 12 | A falta de "uau" (casa, janela, trilha, mirante) vira a fase "O momento uau" | [ROADMAP](ROADMAP.md#1-o-momento-uau) |
| 25 | Biomas baratos como PoC | [ROADMAP](ROADMAP.md#4-biomas-baratos-poc) |
| 26 | Visitar amigos com o V-Sekai, começando por um estudo | [ROADMAP](ROADMAP.md#3-visitar-amigos-v-sekai) |
| 17 | Jev parado; a triagem fica opcional | ROADMAP e AGENTS.md |
| 27 | Perfis do usuário parados | [ROADMAP](ROADMAP.md#parados) |
| 30 | ROADMAP reescrita só com o futuro e uma tabela do feito | [ROADMAP](ROADMAP.md) |
| 7 | "Instalar jogos pelo hub" vira uma ideia | [ideias/instalar-jogos-pelo-hub.md](ideias/instalar-jogos-pelo-hub.md) |
| 15 | Sem regra de "usar antes de seguir" | — |
