# Ferramenta: triagem das falhas da bateria com o Jev

**Status:** aprovado em 2026-10-29, com prioridade sobre a Fase 15 (pausada até aqui terminar). Sem trilhas: uma sessão só, do Claude.
**Branch:** `ferramenta-jev`, criada da `fase-15` (`7c12530`) no checkout principal. Só arquivos novos; volta para a `fase-15` quando o dono pedir.

## Contexto
O smoke de 2026-10-29 ([laya-spike-2026-10-27.md](../design/laya-spike-2026-10-27.md)) escolheu o Jev 1.14 como modelo "System 1" para ajudar o desenvolvimento. A primeira tarefa real: quando a bateria falha, o agente hoje lê o log inteiro da Godot de cada teste para saber se é **ambiente** (Godot travou, importação, `user://` em uso por outra trilha) ou **regressão de verdade**. A ferramenta faz essa triagem e entrega ao agente só um resumo curto. O hub e a bateria não mudam: a ferramenta fica **ao lado** da bateria, que continua determinística e offline.

## Pronto quando
- `python tools/jev/triar_falhas.py <saída do run_tests>` devolve, por teste que falhou, a categoria, a frase do log que decidiu e se a falha tem ligação com os arquivos do diff.
- Passa no portão (abaixo) num gabarito que **não** foi usado para ajustar as perguntas.
- Sem a chave ou sem rede, a ferramenta avisa e para: um erro nunca vira resposta.
- A bateria passa (`RESULTADO GERAL: TUDO OK`) e nada mudou em `tests/run_tests.sh`.

## Decisões de arquitetura
- **O código decide o que é determinístico, e o Jev só o resto** (a tabela-verdade da skill TypeSafe):
  - saída 124 → tempo esgotado;
  - `SCRIPT ERROR` → erro de script;
  - passa ao rodar de novo → instável;
  - o Jev julga só o que sobra: "o log mostra uma conferência do jogo que falhou?" e "a falha toca algum destes arquivos do diff?".
- **Gabarito de graça por falhas provocadas:** quebrar de propósito uma conferência, um nome ou a importação, ou encurtar o tempo, sempre numa cópia descartável do projeto (`git worktree add --detach`, apagada no fim). O `user://` e o `config.cfg` nunca são tocados. A causa é conhecida por construção. Falhas reais que aparecerem entram junto.
- **Versão fixa** `jev-1.14.0`; o pedido exato é guardado para repetir; a chave vem de `TYPESAFE_API_KEY_FILE` (fora do repositório).
- **Só sai do PC o log de teste e os nomes de arquivos do diff:** nada de `config.cfg`, nem chave, nem capas.
- **Privacidade do gabarito:** os logs podem trazer o caminho da pasta pessoal e nomes de jogos da biblioteca. Um `limpar_log()` troca o caminho e o nome do usuário por marcadores antes de qualquer envio, e o gabarito fica **fora do repositório** (`C:\Ferramentas\jev\gabarito\`); no repositório entra só o script que o recria.
- **Cada uso do Jev termina com o relatório de custo:** chamadas, tokens de entrada, US$ e saldo estimado.
- `tools/jev/` ganha um `.gdignore` (a Godot não lê a pasta; o export já exclui `tools/*`).
- **Descartado:** o Laya (fraco sem treino, desinstalado) e mudar o `run_tests.sh` (é da trilha A e de todas as sessões).

## Subetapas
- [x] **J.1 Coleta** (Opus · medium; revisão `/codex:review`)
  - Faz: `tools/jev/coletar_falhas.py` lê a saída do `run_tests.sh`, roda de novo cada teste que falhou e guarda o log completo e o diff numa pasta temporária.
  - Teste: uma saída falsa de bateria com 2 falhas → 2 logs guardados; com `TUDO OK` → nada.
  - [x] **J.1.1** (revisão do Codex): lê a saída da bateria em UTF-8, UTF-8 com BOM (o `>` do PowerShell deste PC) e UTF-16 (o do Windows PowerShell 5.1 padrão).
- [ ] **J.2 Gabarito** (Opus · medium; revisão `/codex:review`)
  - Faz: `tools/jev/provocar_falhas.py` cria ~60 falhas conhecidas numa cópia descartável (4 tipos × vários testes) e grava `falhas.jsonl` fora do repositório (só logs limpos). Uma parte fica guardada só para o portão.
- [ ] **J.3 Triagem e portão** (Opus · high; revisão `/codex:adversarial-review`)
  - Faz: `tools/jev/triar_falhas.py` (perguntas num lugar só) e `tools/jev/avaliar.py`.
  - Portão, na parte guardada:
    - acerto balanceado ≥ 90%;
    - vencer a base só com regras do código por ≥ 10 pontos;
    - nenhuma categoria colapsada;
    - limiar de cada `noul` medido, não chutado;
    - custo por triagem registrado.
  - Se o código sozinho já resolver quase tudo, a conclusão é "não precisa do Jev", e para aqui.
- [ ] **J.4 Uso pelos agentes** (Opus · low; revisão `/codex:review`)
  - Faz: `.claude/skills/triagem-falhas/SKILL.md` e uma seção curta no `AGENTS.md`: quando a bateria falha, rodar a triagem e ler o resumo.
  - **Auditoria em cada uso:** o agente confere 1 log inteiro por triagem. Se errar 2 vezes seguidas, a ferramenta é suspensa.

## Fora do escopo
- Qualquer IA dentro do hub ou dentro do `run_tests.sh`.
- Triagem de assets, de achados de revisão e escolha de modelo (próximas candidatas, cada uma com seu portão).

## Checklist de teste manual (fim)
1. Quebre de propósito uma conferência num teste (numa cópia descartável) e rode `bash tests/run_tests.sh`.
2. Rode `python tools/jev/triar_falhas.py` com a saída.
   - **Deve acontecer:** a falha vem como "regressão", com a frase do log que decidiu e o arquivo do diff.
3. Renomeie o arquivo da chave e rode de novo.
   - **Deve acontecer:** um aviso claro de "sem chave", e nenhuma triagem inventada.
