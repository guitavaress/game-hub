# Ferramenta: triagem das falhas da bateria (medida com o Jev)

**Status:** aprovado em 2026-10-29, com prioridade sobre a Fase 15 (pausada até aqui terminar). Sem trilhas: uma sessão só, do Claude.
**Branch:** `ferramenta-jev`, criada da `fase-15` (`7c12530`) no checkout principal. Só arquivos novos; volta para a `fase-15` quando o dono pedir.

## Contexto
O smoke de 2026-10-29 ([laya-spike-2026-10-27.md](../design/laya-spike-2026-10-27.md)) escolheu o Jev 1.14 como modelo "System 1" para ajudar o desenvolvimento. A primeira tarefa real: quando a bateria falha, o agente hoje lê o log inteiro da Godot de cada teste para saber se é **ambiente** (Godot travou, importação, `user://` em uso por outra trilha) ou **regressão de verdade**. A ferramenta faz essa triagem e entrega ao agente só um resumo curto. O hub e a bateria não mudam: a ferramenta fica **ao lado** da bateria, que continua determinística e offline.

## Pronto quando
- `python tools/jev/triar_falhas.py <saída do run_tests>` devolve, por teste que falhou, a categoria, a frase do log que decidiu e se a falha tem ligação com os arquivos do diff.
- Passa no portão (abaixo) num gabarito que **não** foi usado para ajustar as perguntas.
- ~~Sem a chave ou sem rede, a ferramenta avisa e para~~ (a J.3 tirou o Jev da triagem: ela roda sem chave e sem rede).
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
  - [x] **J.1.2** (revisão do Codex): a importação rodada de novo só passa com saída 0 e sem erro de script; tempo esgotado ou outra saída vira "FALHOU" (a importação boa sai com 0, conferido na Godot 4.7.2).
- [x] **J.2 Gabarito** (Opus · medium; revisão `/codex:review`)
  - Faz: `tools/jev/provocar_falhas.py` cria ~60 falhas conhecidas numa cópia descartável (4 tipos × vários testes) e grava `falhas.jsonl` fora do repositório (só logs limpos). Uma parte fica guardada só para o portão.
  - Feito em 2026-10-29: 61 casos em 30 min, nos 44 testes que não tocam o `user://` (regressão 24, erro de script 12, ambiente 12, tempo esgotado 8, instável 5; 20 no portão). Nenhum dado privado nos logs (conferido pelo script e à mão).
  - **Achado:** das 12 falhas de ambiente, as 10 que rodam a Godot aparecem como `SCRIPT ERROR`. O jogo faltando vira "null instance" e o cache apagado vira "Identifier not declared". A regra "SCRIPT ERROR → erro de script" erra todas; a J.3 precisa tratar isso.
- [x] **J.3 Triagem e portão** (Opus · high; revisão `/codex:adversarial-review`)
  - Faz: `tools/jev/triar_falhas.py` (a triagem), `perguntas.py` e `jev.py` (o Jev, num lugar só) e `avaliar.py` (o portão).
  - **Feito em 2026-10-30. Conclusão: a triagem usa só código; o Jev não é preciso nesta tarefa (decisão do dono).**
    - O gabarito novo (semente 2911) foi gerado depois que as perguntas ficaram prontas. O portão dele (21 casos, 4 de ambiente) ninguém olhou antes da nota. O cache estragado saiu do gabarito: a bateria importa o projeto antes dos testes e refaz o cache.
    - Portão (acerto balanceado): base do plano 80% (ambiente 0%); **com o Jev 95%** (ambiente 75%); **regras finais 95%** (ambiente 75%). Limiar medido no ajuste: 0,70. Ligação com o diff: regras 97%, Jev 100%.
    - O Jev passou no portão contra a base do plano (+15 pontos, nada colapsou), mas a regra de uma linha `Node not found: "Building_<id>` (o prédio do jogo exigido que falta) faz o mesmo. Pelo critério acima, "não precisa do Jev".
    - A tabela final: Godot ausente → ambiente; passou de novo → instável; `Parse Error`/`Compile Error` → erro de script; prédio faltando → ambiente; outro `SCRIPT ERROR` → erro de script; saída 124 → tempo esgotado; o resto → regressão.
    - O único erro do portão: um jogo faltando que não deixa rastro no log (`check_session_summary` só mostra "[FALHOU] resumo do Skyrim"). Por isso a triagem também confere se os 4 jogos exigidos estão instalados e avisa no topo.
    - Lições para o próximo uso do Jev:
      - ler cada erro: o trecho do log cortava a causa, que fica no começo (agora junta linhas repetidas e guarda começo e fim);
      - uma pergunta que mistura dois julgamentos confunde ("conferência falhou" com "arquivo faltando");
      - comparar com uma regra simples escrita depois de ver os dados, e não só com a base do plano.
    - Custo total do Jev na J.3: 137 chamadas, 176.603 tokens, ~US$ 0,0074 (média de US$ 0,00005 por triagem).
  - Revisão: depois do commit, com `/codex:adversarial-review --base fase-15`.
  - Portão, na parte guardada:
    - acerto balanceado ≥ 90%;
    - vencer a base só com regras do código por ≥ 10 pontos;
    - nenhuma categoria colapsada;
    - limiar de cada `noul` medido, não chutado;
    - custo por triagem registrado.
  - Se o código sozinho já resolver quase tudo, a conclusão é "não precisa do Jev", e para aqui.
- [ ] **J.4 Uso pelos agentes** (Opus · low; revisão `/codex:review`)
  - Faz: `.claude/skills/triagem-falhas/SKILL.md` e uma seção curta no `AGENTS.md`: quando a bateria falha, rodar a triagem (só código) e ler o resumo.
  - **Auditoria em cada uso:** o agente confere 1 log inteiro por triagem. Se errar 2 vezes seguidas, a ferramenta é suspensa.

## Fora do escopo
- Qualquer IA dentro do hub ou dentro do `run_tests.sh`.
- Triagem de assets, de achados de revisão e escolha de modelo (próximas candidatas para o Jev, cada uma com seu portão; a próxima tarefa do Jev sai daqui).

## Checklist de teste manual (fim)
1. Quebre de propósito uma conferência num teste (numa cópia descartável) e rode `bash tests/run_tests.sh`.
2. Rode `python tools/jev/triar_falhas.py` com a saída.
   - **Deve acontecer:** a falha vem como "regressão", com a frase do log que decidiu e o arquivo do diff.
   - Feito em 2026-10-30 com o `check_gates`: "REGRESSÃO", frase "[FALHOU] um pórtico por bairro", ligada a `tests/check_gates.gd`.
3. ~~Sem a chave~~: não se aplica mais (a triagem não usa o Jev).
