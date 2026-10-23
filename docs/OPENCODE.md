# Game Hub no OpenCode

Configuração local: [`opencode.json`](../opencode.json). Regras: [`AGENTS.md`](../AGENTS.md). Plano em execução: [Fase 15](plans/fase-15.md).

**Validação (2026-10-23):** serviço OpenCode v2.1.3 confirmou agentes/modelos/variantes, seis comandos e configuração da revisão em sessão filha na localização do projeto. Bateria Godot no Windows: 76/76, com Rust pulado. Não foi feito benchmark nem rodada de prompts em todos os modelos.

## Modelos e esforço

Catálogo consultado em **2026-10-23**, OpenCode **v2.1.3**. A seleção abaixo é uma política inicial para este projeto, não um benchmark entre modelos. O catálogo não trouxe preços; não presumir que um modelo seja mais barato ou mais rápido pelo nome. Conferir disponibilidade em `/models` ao mudar de máquina.

| Papel | Modelo/variante | Uso |
|---|---|---|
| Implementação padrão, coordenação | `openai/gpt-6-astra#medium` | Uma subetapa com escopo fechado, testes e integração sob um responsável |
| Planejamento e implementação difícil | `openai/gpt-6-astra#high` | Setores, geometria, colisão, shaders, atmosfera e mudanças entre sistemas |
| Revisão independente | `openai/gpt-6.1-sol#high` | Segundo olhar sobre os pontos de maior risco, em sessão filha somente leitura |
| Exploração delimitada | `openai/gpt-6-luna#low` | Agente `explore`: localizar arquivos, referências e contratos; devolver evidências |
| Tarefa mecânica | `openai/gpt-5.3-codex-spark#low` | Texto delimitado, links e execução/relato dos testes; diagnóstico difícil volta ao Astra |
| Reservas disponíveis | `openai/gpt-5.6-terra`, `openai/gpt-5.5` | Alternativas se necessário, sem repartir o mesmo trabalho entre todos os modelos |

- Astra e Sol oferecem `low`, `medium`, `high`, `xhigh`, `max`. Luna e Terra também oferecem `none`. GPT-5.5 e Spark oferecem `none`, `low`, `medium`, `high`, `xhigh`.
- `medium` é o padrão de implementação; `high` fica nos pontos indicados pelo plano. `xhigh`/`max` só após isolar um bloqueio real, com hipótese e reprodução. Dois erros iguais pedem replanejamento, não aumento cego de esforço.
- A escolha de Sol como revisor separa autor e revisão. Não é uma alegação de superioridade medida. Nas primeiras subetapas, registre correções necessárias, retrabalho e resultados; ajuste a distribuição conforme evidência.
- A revisão não substitui testes nem a aprovação visual do dono. Só acione subagentes por pedido explícito ou nas trilhas de delegação previstas no plano.

## Como usar

| Comando | Resultado |
|---|---|
| `/fase15-planejar 15.1` | Plan + Astra high: lê o plano e propõe a execução; não altera código |
| `/fase15-passo 15.1` | Build + Astra medium: implementa essa subetapa aprovada |
| `/fase15-dificil 15.3` | Build + Astra high: executa a etapa de maior complexidade |
| `/fase15-revisar 15.3` | Sol high: revisão somente leitura em sessão filha, com resultado de volta à principal |
| `/fase15-docs corrigir o link X` | Spark low: ajuste textual delimitado |
| `/fase15-testes` | Spark low: executa a bateria completa e relata; não corrige código |
| `/fase15-testes check_terrain check_textures` | Executa só os testes indicados |

Os comandos selecionam **agente e modelo/variante explicitamente**. Trocar apenas o agente na interface pode manter o modelo já selecionado na sessão. O `model` na raiz define o modelo padrão, mas não fixa variante; por isso os agentes e comandos têm `#medium`, `#high` ou `#low`.

O Plan do OpenCode não grava arquivos comuns do repositório. Faça o raciocínio nele; após a aprovação, peça ao Build para registrar a decisão em `docs/plans/fase-15.md`. Não confunda um plano interno do OpenCode com a memória versionada do projeto.

## Sessões e trabalho paralelo

1. Uma sessão por subetapa grande. Comece lendo o plano e o `git status`; termine com evidências, pendências e commit, se os testes passarem.
2. Para a Fase 15, mantenha **uma trilha principal e no máximo uma trilha de implementação paralela**. Os arquivos e contratos são os da tabela do plano.
3. Subagentes herdam a pasta, não um worktree novo. Para implementação paralela, crie um worktree e abra/mova uma sessão para ele **antes** de editar. `worktree.directory` só escolhe a pasta pai; confirme a branch e o commit-base retornados. Se não for a base acordada da `fase-15`, ajuste antes de começar.
4. O subagente recebe contexto novo: informe subetapa, base, arquivos permitidos, contratos, critérios de aceite, testes e arquivos compartilhados que pertencem à principal. O plano fica com a principal.
5. A principal faz a integração, confere o diff, roda testes e marca o plano. Não faça merge na `main` nem push sem pedido.
6. Para revisão com `hub-review`, forneça o diff e o log relevante (ou caminhos temporários). Ele lê arquivos, mas não tem shell nem permissão de editar ou rodar outra bateria.

## Testes no Windows e no Linux

**No PowerShell, na raiz do projeto:**

```powershell
& 'C:\Program Files\Git\bin\bash.exe' tests/run_tests.sh
# Durante uma subetapa:
& 'C:\Program Files\Git\bin\bash.exe' tests/run_tests.sh check_terrain check_textures
```

`C:\Windows\System32\bash.exe` abre o WSL neste desktop e procura a Godot do Linux. Use o Git Bash explicitamente para testar o backend Windows. O runner já encontra `C:\Godot\Godot_v4.7.2-stable_win64_console.exe`.

**No Linux:**

```bash
bash tests/run_tests.sh
```

- Só **uma bateria por vez**, inclusive testes avulsos: todas as sessões compartilham `user://`. No Git Bash, não contar com `flock`.
- A bateria tem de imprimir `RESULTADO GERAL: TUDO OK`. Falhas por ambiente também ficam registradas, com a causa comprovada, sem marcar a execução como aprovada.
- Testes de integração atuais dependem de jogos instalados; detalhes e fixtures em [tests/README.md](../tests/README.md).
- Rust/compositor é validado no Linux; pular no Windows não equivale a aprovar essa parte.
- Headless valida lógica. Capturas com janela, colisão percorrida e medidas na Alta ainda são necessárias nas subetapas correspondentes.

## Referências da configuração

OpenCode V2: [configuração](https://opencode.ai/v2/docs/config), [agentes](https://opencode.ai/v2/docs/agents), [modelos e variantes](https://opencode.ai/v2/docs/models), [comandos](https://opencode.ai/v2/docs/commands). Não há dependência nova, plugin ou credencial no arquivo do projeto.
