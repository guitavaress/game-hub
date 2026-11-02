# Planos das fases

Cada fase do [roadmap](../ROADMAP.md) ganha um plano aqui **antes** de qualquer código. O plano também é a **memória entre sessões**: uma sessão nova lê o arquivo, vê quais subetapas estão marcadas `[x]` e continua da primeira em aberto.

## Regras
- O arquivo se chama `fase-N.md` (ex.: `fase-7.md`). Planeje no modo plano do Claude Code e obtenha **aprovação do dono** antes de implementar. Modelos e revisão em [AGENTS.md](../../AGENTS.md#modelos-e-esforço).
- **Subetapas curtas:** cada uma cabe numa sessão e termina num commit. Se uma subetapa precisa de mais de ~5 arquivos novos ou de dois sistemas diferentes, divida.
- **Cada subetapa tem um tamanho, grande ou pequena**, e ele decide a cerimônia (testes, captura, revisão). A definição está no [AGENTS.md](../../AGENTS.md#fluxo-de-uma-fase).
- **O plano pode ser detalhado**, porque os agentes precisam do detalhe. O dono lê **só o bloco "Para o dono"** no topo, e esse bloco tem que caber em 10 linhas.
- **A ordem importa:** primeiro o que não muda nada visível (estrutura, dados), depois o que usa a estrutura nova, e o visual por último.
- **Durante a execução:**
  - marque `[x]` na subetapa ao fazer o commit, com o hash curto;
  - decisão nova ou mudança de rumo vai para "Decisões tomadas durante a fase", com data;
  - se a decisão mudar a arquitetura, volte ao modo plan antes de seguir.
- **Ao fim da fase:** o plano fica no repositório como registro. O README e o ROADMAP são atualizados.

## Modelo

Copie o bloco abaixo para um `fase-N.md` novo e preencha. O plano é lido no início de cada sessão: detalhe o que os agentes precisam, sem repetir o AGENTS.md.

```markdown
# Fase N: <nome>

**Status:** em planejamento | aprovado | em andamento | concluída
**Branch:** `fase-N`

## Para o dono (até 10 linhas)
- **O que você vai ver quando a fase acabar:** uma ou duas frases, do ponto de vista de quem joga.
- **Agora:** a subetapa em andamento e o que já dá para testar.
- **Para testar:** o que abrir e o que deve acontecer (o checklist completo fica no fim).
- **Decisões que esperam você:** a lista, ou "nenhuma".

## Contexto
Por que a fase existe, o que ela resolve e como o hub fica quando ela acabar
(3 a 6 linhas). Link para a seção da fase no ROADMAP.

## Pronto quando
- Critério verificável 1 (ex.: "criar um bairro novo não exige mexer em nenhum match").
- Critério verificável 2.

## Decisões de arquitetura
- **<decisão>:** escolha feita e o motivo, em uma ou duas linhas.
  Alternativa descartada e por quê.

## Subetapas
- [ ] **N.1 <nome>** (tamanho: pequena · quem: Sonnet, subagente · esforço: medium)
  - Faz: o que muda, em uma ou duas frases.
  - Arquivos: `caminho/novo.gd` (novo), `caminho/existente.gd` (muda X).
  - Teste: `tests/check_<nome>.gd` verifica Y (na pequena, roda só os testes do que mudou).
  - Manual: o que o dono abre e vê.
  - Commit: `Fase N.1: <mensagem>`
- [ ] **N.2 <nome>** (tamanho: grande · quem: Opus, sessão nova · esforço: high · revisão: Astra, só se for de risco)
  - ...

## Riscos
- O que pode dar errado e como percebemos cedo.

## Fora do escopo
- O que parece fazer parte, mas fica para depois (e onde foi anotado).

## Decisões tomadas durante a fase
- AAAA-MM-DD: <decisão> (subetapa N.x).

## Checklist de teste manual (fim da fase)
1. O que abrir.
2. O que apertar.
3. O que deve acontecer.
```
