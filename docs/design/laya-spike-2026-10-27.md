# Spike do Laya como ajudante do desenvolvimento (2026-10-27)

**Resultado: reprovado.** O Laya não entra no fluxo de desenvolvimento por enquanto. Nada mudou no hub.

## A pergunta
O [Laya](https://github.com/NandhaKishorM/laya) (Apache-2.0) é um classificador local, só de texto: ele recebe um texto e uma pergunta de múltipla escolha (`choice`), de nota (`score`) ou de sim/não (`noul`) e devolve as probabilidades, sem gerar texto. A ideia do dono: usá-lo **fora do hub**, como ferramenta do Claude Code e do Codex, para as triagens repetidas sobre listas grandes, que hoje gastam a janela de 5 h das assinaturas. Exemplos: separar assets CC0 para os biomas da Fase 16, escolher sons pelo nome do arquivo e sugerir o bairro dos jogos que caem em "Outros".

A alternativa paga, o Jev (TypeSafe), faz o mesmo tipo de pergunta, mas é uma API cobrada à parte, e por isso ficou de fora.

## Como foi medido
- **Instalação** fora do repositório: venv em `C:\Ferramentas\laya\` (laya 0.4.15 do PyPI, torch 2.14.1 com CUDA 12.6, 4,4 GB) e os modelos no cache do Hugging Face (1,6 GB). A máquina foi o desktop, com a RTX 4070.
- **Gabarito de graça:** 171 jogos (18 da biblioteca do dono e 153 públicos da Steam: os mais jogados e os lançamentos em destaque). O bairro "certo" de cada um é o da regra do hub (`GameCategories.get_category_id`): a primeira tag da loja que estiver em algum bairro.
- **A pergunta ao Laya:** uma `choice` entre os 9 bairros (sem "Outros"). Cada opção leva as tags do perfil em inglês. Foram dois casos:
  - **A:** o Laya vê só o nome e a descrição curta da loja;
  - **B:** vê também as tags que não são de nenhum bairro, que é o que sobra para um jogo de "Outros".
- **Régua combinada antes:** acertar ≥ 70% na 1ª opção e ter o certo entre as 3 primeiras em ≥ 90%.
- Nenhum dado saiu do PC além dos downloads e das consultas públicas à loja da Steam. O `config.cfg` não foi aberto.

## Números
| Modelo | Caso | Acerto na 1ª opção | Certo entre as 3 primeiras | Acerto quando a prob. ≥ 0,7 | Tempo |
|---|---|---|---|---|---|
| `english` | A | 36% | 82% | 53% (76 jogos) | 36 ms/jogo |
| `english` | B | 30% | 71% | 42% (62 jogos) | 36 ms/jogo |
| `typed-decisions` | A | 37% | 81% | 59% (17 jogos) | 35 ms/jogo |
| `typed-decisions` | B | 29% | 72% | 71% (14 jogos) | 35 ms/jogo |

Comparação: o chute dá 11% na 1ª opção e 33% nas 3 primeiras, e responder sempre "Ação" (o maior bairro) dá 32%.

## Leitura
- **O Laya é melhor que o chute, mas mal passa de "responder sempre o maior bairro".** Fica longe da régua nos quatro casos.
- **Dar as tags genéricas piorou**, o que é o contrário do que a triagem precisaria.
- **A probabilidade alta não é confiável:** mesmo acima de 0,7, ele erra de 30% a 58% das vezes. O próprio modelo avisou ao carregar que parte das temperaturas de calibração vem inválida.
- **O gabarito é estrito.** Um jogo que seria Ação e RPG ao mesmo tempo só tem uma resposta certa, por isso a coluna "entre as 3 primeiras" é a mais justa. Mesmo nela, o Laya não chega aos 90%.
- **Isso bate com o README dele:** os modelos-base ficam perto do acaso nas decisões tipadas, e o ganho vem do ajuste fino com dados do próprio domínio (4 a 5 horas de GPU para ~30 mil perguntas rotuladas). Para o nosso uso, isso não compensa.
- **A velocidade é ótima** (35 ms por jogo na RTX 4070), mas velocidade sem acerto não poupa trabalho: cada resposta ainda precisaria ser conferida.

## Armadilha da instalação (Windows)
O venv criado a partir do Python do **Anaconda** herda as DLLs do Visual C++ 14.27 da pasta do Anaconda, e o torch 2.14 falha com `WinError 1114` na `c10.dll`. A solução que funcionou foi carregar o runtime do sistema (`System32`: `vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`) com `ctypes.WinDLL` antes de importar o torch. Um Python fora do Anaconda também deve resolver.

## Quando rever
- Se sair um modelo ajustado para classificar texto curto em português ou inglês com mais de ~10 opções, repetir a mesma prova. Os scripts ficam em `C:\Ferramentas\laya-prova\` (`montar_dados.py` e `prova.py`), fora do repositório.
- Até lá, as triagens continuam com o agente da trilha, usando os modelos mais baratos (Sonnet, Terra) para listas grandes.
