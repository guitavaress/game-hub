# System 1 para o desenvolvimento: Laya × Jev (2026-10-27 a 29)

**Decisão:** os ajudantes de desenvolvimento com modelo "System 1" usam o **Jev 1.14** (TypeSafe). O Laya sem treino é fraco demais e foi desinstalado. Nada mudou no hub nem na bateria.

> A primeira versão deste texto (commit `4bf774a`) dizia que o Laya estava "reprovado". A prova daquele dia estava **quebrada**, como explicado abaixo. A conclusão de agora vem do smoke corrigido, com os dois modelos lado a lado.

## A pergunta
Um modelo "System 1" recebe um texto e perguntas tipadas: múltipla escolha (`choice`), nota (`score`) ou sim/não (`noul`). Ele devolve as probabilidades numa passada só, sem gerar texto. A ideia do dono é usá-lo **fora do hub**, como ajudante do Claude Code e do Codex, para os julgamentos repetidos sobre listas grandes que hoje gastam a janela de 5 h das assinaturas: triagem das falhas da bateria, achados de revisão, catálogos de assets e sons.

- **Jev** (TypeSafe): API paga, US$ 0,042 por milhão de tokens de entrada; a saída é grátis.
- **Laya** (Apache-2.0): roda no PC. Serve o mesmo protocolo do Jev (`POST /v1/systemone`), então a skill TypeSafe e o mesmo código valem para os dois.

## O que a primeira prova fez de errado
1. **Opções cortadas:** o Laya divide um orçamento de 192 tokens (256 no `typed-decisions`) entre as opções. A pergunta tinha 492, e cada bairro chegou com 19 tokens (`laya/common.py`, `build_head`).
2. **Colapso não conferido:** ele respondeu "RPG" em 97 a 124 dos 171 jogos (o gabarito tem 22). Os 36% de acerto foram quase por acaso.
3. **Régua frouxa e régua estrita ao mesmo tempo:** só um bairro valia como certo, embora cada jogo toque 3,2 bairros em média. E, no critério "qualquer bairro possível", responder sempre "Ação" já dá 75%.
4. **Modelo errado:** o `typed-decisions` é ajustado para faturas, incidentes, atendimento e rastros de agente.
5. **Leitura errada do próprio README do Laya**, que avisa: "uma base rápida para especializar, não um motor de decisão sem treino".

## O smoke corrigido
- **Dados:** 153 jogos públicos da Steam (os mais jogados e os lançamentos em destaque). Os 18 da biblioteca do dono ficaram fora do Jev. O bairro de referência é o da regra do hub (a primeira tag da loja que está num bairro). O modelo vê o nome, a descrição curta e só as tags que não são de nenhum bairro, para o gabarito não vazar.
- **As mesmas perguntas para os dois:**
  - **V1:** uma `choice` entre os 9 bairros. No Laya, com orçamento suficiente (`head_max_len=512`) e as 9 rotações da ordem das opções na mesma passada; no Jev, a ordem normal e a invertida;
  - **V2:** uma `noul` por bairro, com critérios de sim e de não.
- **Medidas que não se deixam enganar pela classe comum:** acerto balanceado (a média do acerto em cada bairro; 11% é chute) e AUROC médio dos sim/não por bairro (0,50 é chute).
- **Versões:** `laya` 0.4.15 com o modelo inglês (revisão `7b928d8`) na RTX 4070; `jev-1.14.0` fixo, e não o apelido.
- **Regra de decisão fixada antes de ver os números:** se o Jev passar o Laya por 10 pontos ou mais, ele vale para o uso sem treino.

| Medida | Laya sem treino (RTX 4070) | Jev 1.14 | Chute |
|---|---|---|---|
| Acerto estrito (V1) | 20% | **76%** | 11% |
| Acerto balanceado (V1) | 16% | **74%** | 11% |
| AUROC médio (V2) | 0,67 | **0,90** | 0,50 |
| Resposta mais dada × gabarito | "RPG" 138 × 20 | "Ação" 51 × 52 | — |
| Mesma resposta com outra ordem (V1) | 91% | 95% | — |
| ECE da V1 (menor é melhor) | 0,14 | 0,09 | — |
| Tempo | 321 ms por jogo (18 perguntas) | 286 ms por pedido (11 perguntas, pela internet) | — |
| Custo do smoke inteiro | grátis | US$ 0,019 (454.625 tokens) | — |

## Leitura
- **O Jev ganha com folga** (+58 pontos no acerto balanceado) e não colapsa. Como as perguntas eram as mesmas, o problema do Laya era o modelo, não a tarefa.
- **Bate com os benchmarks independentes** (nibzard/decision-model-benchmark e AbdelStark/jev-benchmarks, set./out. 2026): fora do que o Laya treinou, o Jev sem treino vale mais ou menos o dobro.
- **Custo:** US$ 5 dão ~119 milhões de tokens, ou umas 40 mil chamadas do tamanho destas.
- **Cuidado:** o Jev dá probabilidades muito extremas (às vezes 1,0 contra 0,0), e os benchmarks avisam que a confiança dele não é uma probabilidade calibrada. Em cada tarefa, o limiar para agir é medido num gabarito, nunca chutado.
- **O Laya só faria sentido treinando uma cabeça própria para uma tarefa fixa,** com muitos exemplos rotulados. Hoje não compensa.

## Regras para usar o Jev no desenvolvimento
- **Só como ajudante dos agentes.** Nunca no hub, e nunca dentro da bateria, que continua determinística e offline.
- **A chave fica num arquivo fora do repositório,** passado ao script por `TYPESAFE_API_KEY_FILE`. Nunca no chat, no log nem no commit.
- **Versão fixa** (`jev-1.14.0`) e o pedido exato guardado, para repetir. Um erro HTTP é erro, nunca resposta.
- **Só dado público,** ou dado do dono com a permissão dele.
- **Cada tarefa nova passa por um portão:** um gabarito, uma base simples a vencer, o limiar medido e uma auditoria por amostra em cada uso.

## Notas
- **Armadilha do Windows** (se o Laya voltar): um venv criado do Python do **Anaconda** herda o Visual C++ 14.27 da pasta dele, e o torch 2.14 falha com `WinError 1114` na `c10.dll`. Resolve carregando antes o runtime do `System32` (`vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`) com `ctypes.WinDLL`.
- **Scripts e dados:** ficam fora do repositório, em `C:\Ferramentas\laya-prova\` (`montar_dados.py` e `smoke.py`). A parte do Jev roda com qualquer Python 3.
- **Próximo passo:** a primeira tarefa real, a triagem das falhas da bateria (erro de ambiente × regressão), com o seu próprio plano e portão.
