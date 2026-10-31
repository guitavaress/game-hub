# Spike: o Jev nas capturas de tela

**Status:** aprovado em 2026-10-31. Vem antes da 15.10, e a Fase 15 espera. Sem trilhas: uma sessão só, do Claude.
**Branch:** `spike-jev-capturas`, criada da `fase-15` (`99805ce`). Merge só quando o dono pedir.

## Contexto
A [ferramenta do Jev](ferramenta-jev.md) mostrou que, na triagem da bateria, uma regra de código bastava. No plano da Fase 15, a tarefa que mais se repete é **conferir capturas**: "a torre aparece da praça?", "a neve estoura?", "o pinheiro ficou quase preto", "a 2ª hora saiu de dia" (defeito do `capturar_pontos.gd`). A 15.10 e a 15.13 inteiras dependem disso.

**Ressalvas:**
- Imagem no Jev ainda é **protótipo** ("Dreamer-ready" na documentação da TypeSafe).
- Boa parte das conferências pode ser medida por código: pixels e geometria.

**A pergunta do spike:** existe alguma conferência de captura em que o Jev acerte ≥ 90% **e** vença por ≥ 10 pontos uma régua de código, num portão que ninguém viu antes? Se não existir, a régua de código entra sozinha: ela acelera a 15.10 e a 15.13 do mesmo jeito.

## Regras (lições da ferramenta do Jev)
- **Ler e copiar o critério do hub** antes de imitar:
  - os pontos e a câmera do `tools/capturar_pontos.gd`;
  - a biblioteca falsa do `tests/fake_library.gd`;
  - o marco (`DistrictLandmark`), o material do pinheiro e o da neve.
- **Toda captura numa cópia descartável com `user://` próprio:** reusar a `Copia` de `tools/jev/provocar_falhas.py`, com o `override.cfg` conferido pela Godot. O `capturar_pontos.gd` grava a qualidade do usuário, então ele nunca roda no checkout principal.
- **Só biblioteca falsa (200 jogos), sem amigos** (`tests/quiet_friends.gd`): nenhuma capa real vai ao Jev. Antes de cada envio, conferir que não há capa real.
- **Antes de cada regra ou commit, a pergunta adversarial:** "quando isto erra, e o que acontece?".
- **Teto de custo do Jev: US$ 0,50.** Cada passo com o Jev termina com o relatório de custo.

## Subetapas
- [x] **C.0 Plano e revisão adversarial antes de codar** (Opus · low; revisão `/codex:adversarial-review --base fase-15`)
  - Este arquivo, com commit; o dono roda a revisão antes da C.1.
  - Revisão adversarial (2026-10-31): aprovada, sem achados.
- [x] **C.1 Formato e custo da imagem** (Opus · medium)
  - Ler na documentação viva: `images.md`, `noul.md`, `box.md` e o OpenAPI (o mapa `assets`, o cabeçalho `TypeSafe-Danger-Zone-Images: true`, o limite de 1568 px).
  - O `tools/jev/jev.py` aprende a mandar imagem. Erro continua sendo erro.
  - **1 captura** de teste (1280×720, biblioteca falsa) com 1 pergunta: medir quantos tokens a imagem gasta e fixar o tamanho do gabarito dentro do teto.
  - Feito em 2026-10-31:
    - **Custo:** 2.844 tokens por pedido com uma captura de 1280×720 e 3 perguntas (~US$ 0,00012). O teto de US$ 0,50 dá ~4 mil capturas; o limite real é o tempo da Godot.
    - **Respostas na captura da praça às 13 h:** dia 0,97, torre visível 0,05, pinheiro preto 0,20. As três batem com o que se vê. Uma captura não prova nada; ela só mostra que o formato funciona.
    - **Achado: a biblioteca falsa usa capas DE VERDADE.** Ela usa a pasta de capas da Steam do dono (`appcache/librarycache`). Na cópia descartável, o `FakeLibrary.install` passa a usar `fixed_ids = true` (IDs inventados, nomes em texto, nenhuma capa). O repositório não muda. A skill `revisao-do-hub` sugere a biblioteca falsa para as capturas como se ela não tivesse capas: corrigir isso fica para o dono decidir.
    - **A Godot com janela termina com `3221225477`** (erro de acesso à memória) depois de salvar as capturas, ao fechar. As capturas saem inteiras. Vigiar na C.2.
- [x] **C.2 Capturas com defeito conhecido + régua de código** (Opus · high; revisão `/codex:review`)
  - `tools/jev/capturas/gerar_capturas.gd` estende o `capturar_pontos.gd` e monta cada variante em `_prepare()`. Roda com janela, na cópia descartável.
  - **Variantes por construção:**
    - normal;
    - torre escondida;
    - torre "apagada" (cinza e pequena, como na 15.9.1b);
    - pinheiro preto;
    - neve estourada;
    - hora trocada;
    - tela quase preta.
  - **Régua de código, medida na Godot na hora da captura** (JSON ao lado do PNG):
    - brilho médio;
    - % de pixels quase brancos e quase pretos;
    - brilho do céu;
    - a torre geométrica: projeção, altura em pixels e linha de visão.
  - **Ajuste:** `praca`, `portico` e `cima`, às 13 h e às 22 h.
  - **Portão** (condições que o ajuste não viu): `mirante`, câmera deslocada, 17 h.
  - O gabarito fica fora do repositório (`C:\Ferramentas\jev\capturas\`).
- [x] **C.3 Perguntas e portão** (Opus · high; revisão `/codex:adversarial-review`)
  - `perguntas_capturas.py`: uma noul por conferência, sobre o que se vê (torre visível, pinheiro escuro mas verde, neve sem detalhe, dia).
  - `avaliar_capturas.py`:
    - o limiar é medido no ajuste;
    - no portão, três notas por conferência: régua, Jev, e os dois juntos.
  - **O Jev só fica onde passar:**
    - ≥ 90% de acerto;
    - ≥ 10 pontos acima da régua;
    - nenhuma classe colapsada.
- [x] **C.4 Decisão e entrega** (Opus · low; revisão `/codex:review`)
  - Doc `docs/design/jev-capturas-spike-2026-10-31.md`: os números, o custo e a decisão por conferência.
  - `tools/jev/capturas/conferir_capturas.py <pasta>`: uma tabela por captura (a régua, mais o Jev onde ele passou), para a 15.10 e a 15.13. Mais uma linha na skill `revisao-do-hub`.
  - **A aprovação visual continua sendo do dono.** A ferramenta só aponta o que olhar primeiro.
  - Feito em 2026-10-31:
    - **Limiares:** os do ajuste da C.3, fixos no código. A regra do dia (nenhum pixel quase preto) é frágil: a tabela avisa quando o Jev discorda dela. Neve e pinheiros usam o esperado (a hora pedida) para saber se é dia.
    - **Conferido no gabarito:** 7 de 80 capturas com aviso. São 3 erros da régua do dia (praça às 10 h), 1 noite que a exposição alta deixou com cara de dia e 3 "telas pretas" escuras. Custo: 0 chamadas, porque as respostas estavam guardadas.
- [ ] **C.2.1 Os achados do `/codex:review` da C.2** (para o dono decidir):
  - o gerador publica o `capturas.jsonl` mesmo quando uma rodada falha;
  - uma `--saida` relativa vai para a pasta errada na Godot;
  - o cache de medidas vale pelo tamanho do PNG, e não pelo conteúdo.
  - Achado meu: sem `--saida`, o gerador sobrescreve o gabarito.

## Contrato da C.2 e da C.3 (combinado antes de dividir o trabalho)
O dono pediu workers em paralelo (2026-10-31). **Só o gerador abre a Godot.** Os workers escrevem Python puro, sem Godot e sem rede, e não fazem commit.

**A régua de pixels sai em Python, não em GDScript** (desvio do plano):
- ela lê o PNG pronto, então não disputa a Godot com o gerador;
- vale para qualquer pasta de capturas, inclusive as antigas.

A régua da torre (geometria) fica na Godot, no gerador.

**O gabarito** (`C:\Ferramentas\jev\capturas\gabarito\`): os PNG de 1280×720 e um `capturas.jsonl` com uma linha por captura:
```json
{"id": "praca_13h_normal", "arquivo": "praca_13h_normal.png", "ponto": "praca", "hora": 13,
 "variante": "normal", "parte": "ajuste", "sem_capas": true,
 "rotulos": {"dia": true, "tela_preta": false, "neve_estourada": false,
             "pinheiro_preto": false, "torre_visivel": true},
 "geometria": {"torre_na_tela": true, "torre_altura_px": 41.5, "torre_desobstruida": true}}
```
- `parte` vale `ajuste` ou `portao`;
- um rótulo `null` quer dizer "não dá para julgar nesta captura": ela fica fora daquela conferência;
- as conferências são `dia`, `tela_preta`, `neve_estourada`, `pinheiro_preto` e `torre_visivel`.

| Quem | Arquivos | Faz |
|---|---|---|
| Opus (esta sessão) | `tools/jev/capturas/gerar_capturas.py`, `gerar_capturas.gd` | as variantes na cópia descartável, os rótulos, a geometria da torre e a rodada |
| Worker A (Sonnet) | `tools/jev/capturas/regua_pixels.py`, `test_regua_pixels.py` | lê o PNG (só biblioteca padrão) e mede brilho, branco, preto e céu |
| Worker B (Sonnet) | `tools/jev/capturas/perguntas_capturas.py`, `avaliar_capturas.py`, `test_capturas_portao.py` | as perguntas, a régua de decisão, o limiar no ajuste, a nota no portão e o teto de custo |

### Resultado da C.2 e da C.3 (2026-10-31)
- **Gabarito:** 80 capturas em 3 min (`C:\Ferramentas\jev\capturas\gabarito\`), 30 de ajuste e 50 de portão. O portão tem outras horas (10 h e 20 h), câmera deslocada e o mirante. Nenhuma capa real (`fixed_ids` na cópia). O `config.cfg` do dono manteve a data.
- **Portão** (acerto balanceado; o limiar do Jev sai do ajuste):

| Conferência | Régua do contrato | Melhor regra simples* | Jev | Decisão |
|---|---|---|---|---|
| dia | 75% | 92% (algum pixel quase preto) | 100% | **régua** (o Jev vence por 8 pontos, menos que 10) |
| neve estourada | 100% (brilho médio) | — | 75% | **régua** |
| **sem pinheiros** | 43% | 47% | **100%** | **Jev** (+53 pontos) |
| tela preta | — | — | — | fora: a variante não ficou preta |
| torre visível | — | — | — | fora: a torre só existe depois da 15.10 |

  \* Escolhida no ajuste entre 3 medidas e avaliada no portão: a lição da triagem (comparar com uma regra simples, não só com a régua do plano).
- **Leitura:** o nicho do Jev nas capturas é **"algo sumiu da cena?"**, presença de objeto: pixels não separam um pinheiro escuro de uma rocha ou de uma sombra. Brilho, cor e dia/noite, o código resolve. A torre da 15.10 é o mesmo tipo de pergunta.
- **Ressalvas:**
  - poucos casos de "sim" (5 no portão para os pinheiros);
  - o defeito é "todos os pinheiros sumiram"; "alguns sumiram" não foi medido;
  - imagem no Jev ainda é protótipo na TypeSafe.
- **Custo do Jev na C.2/C.3:** 110 chamadas, 629.390 tokens, ~US$ 0,026. Disso, US$ 0,016 foram desperdiçados pelo defeito da chave `screenshot`: a API troca toda ocorrência da chave pela imagem, inclusive dentro das perguntas. Corrigido, e há um teste que barra isso.
- **Corrigido no caminho, só com dados do ajuste:** a régua da neve estourada usava a fração ≥ 0,98, que o tonemap nunca alcança (dava 0 em tudo); passou para o brilho médio. Os 16 rótulos da "tela preta" ficaram fora.

### Mudanças durante a C.2 (2026-10-31)
- **A torre fica para depois da 15.10.** Hoje o bairro RPG não tem torre: ele usa arcos em vez de prédios, e o `DistrictLandmark` só se monta em cima de um prédio. A régua geométrica já está no gerador e mede a torre quando a 15.10 a ancorar. A pergunta `torre_visivel` não vai ao Jev sem `--descricao-torre`.
- **"Pinheiro preto" virou "sem pinheiros"** (decisão do dono). O pinheiro do hub já é quase preto (ajuste da 15.7), e a variante mudava só 1% a 3% dos pixels: nem uma pessoa separaria as duas. "Sem pinheiros" é um defeito real (o espalhamento falhar). A régua dele é a fração de pixels escuros no chão (`fracao_escura_baixo`, luma ≤ 0,25), em que valor baixo quer dizer "sim".
- **As horas do portão viraram 10 h e 20 h, em vez de 17 h.** No `DayNight.night_amount`, as 17 h são pôr do sol, e o rótulo "dia" ficaria ambíguo.
- **O contexto mandado ao Jev não cita pinheiros**, para não entregar a resposta de uma das conferências.
- **Os dois workers** (Sonnet) entregaram a régua de pixels (0,63 s por imagem de 1280×720) e o portão, com os testes. Foram conferidos numa captura real da Godot. Dois defeitos meus apareceram e foram corrigidos no teste rápido: a lista de redução com `\r\n` do Windows e a régua da torre, que precisava deixar o corpo do jogador de fora do raio.

## Fora do escopo
- O Jev no hub ou na bateria.
- Mudar o `capturar_pontos.gd`, o hub ou os `.tres`.
- Capturas com a biblioteca de verdade.

## Verificação
1. `python -m unittest discover tools/jev`.
2. `bash tests/run_tests.sh` → `TUDO OK` antes de cada commit.
3. Depois de cada rodada de captura, o `config.cfg` real mantém a data, e `git worktree list` só mostra o checkout principal.
4. O relatório do portão por conferência e o custo total (≤ US$ 0,50).
5. Teste manual do dono: o `conferir_capturas.py` numa pasta de capturas da 15.9.1b, comparando a tabela com o que ele vê.
