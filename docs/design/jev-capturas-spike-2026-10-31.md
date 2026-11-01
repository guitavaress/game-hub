# Spike: o Jev nas capturas de tela (2026-10-31)

Plano e histórico: [docs/plans/ferramenta-jev-capturas.md](../plans/ferramenta-jev-capturas.md).

## A pergunta
Existe alguma conferência de captura em que o Jev acerte ≥ 90% **e** vença uma régua de código por ≥ 10 pontos, num portão que ninguém viu? Conferir capturas é a tarefa que mais se repete na Fase 15 (15.10 e 15.13).

## Como foi medido
- **Gabarito:** 80 capturas do bairro RPG com defeito conhecido por construção, feitas numa cópia descartável:
  - `user://` próprio;
  - biblioteca falsa com IDs inventados, então nenhuma capa real.

  O ajuste tem 30 capturas: praça, pórtico e cima, às 13 h e às 22 h. O portão tem 50: mirante e câmera deslocada, às 10 h e às 20 h.
- **Limiares** (da régua e do Jev) medidos só no ajuste. A nota sai só no portão.
- **Comparação** com a régua do plano e também com a melhor regra simples escolhida no ajuste.
- **Regra do Jev:** ≥ 90%, ≥ 10 pontos acima da régua e nenhuma classe zerada.

## Resultado no portão (acerto balanceado)

| Conferência | Régua do plano | Melhor regra simples | Jev | Decisão |
|---|---|---|---|---|
| dia ou noite | 75% (brilho do céu) | 92% (nenhum pixel quase preto) | 100% | **código** (o Jev vence por 8 pontos, menos que 10) |
| neve estourada | 100% (brilho médio ≥ 0,7261) | — | 75% | **código** |
| **pinheiros sumiram** | 43% | 47% | **100%** | **Jev** (p ≥ 0,70) |
| tela preta | — | — | — | fora: a variante não ficou preta |
| torre visível | — | — | — | fora: o bairro RPG ainda não tem torre (vem na 15.10) |

**Leitura:** o nicho do Jev nas capturas é **"algo sumiu da cena?"**, ou seja, presença de objeto. Pixels não separam um pinheiro escuro de uma rocha ou de uma sombra. Brilho, cor e dia ou noite, o código resolve, e de graça.

## Ressalvas
- **Poucos casos de "sim":** 5 capturas de "pinheiros sumiram" no portão.
- **Só "todos sumiram":** o caso "alguns sumiram" não foi medido.
- **Um bairro só:** o RPG, com neve.
- **Imagem no Jev ainda é protótipo** na TypeSafe ("Dreamer-ready").
- **A regra do dia é frágil:** basta um pixel quase preto para ela dizer "noite". No portão, ela errou 3 capturas de dia da praça às 10 h. Por isso o `conferir_capturas.py` mostra quando o Jev discorda dela (a resposta do Jev vem no mesmo pedido). Usa o esperado (a hora pedida) para decidir se confere neve e pinheiros.
- **Mudar qualquer limiar pede medir de novo** com o `avaliar_capturas.py`, e nunca acertar "no olho".

## Custo
- **Spike inteiro:** 111 chamadas, 632.234 tokens de entrada, ~US$ 0,027 (teto US$ 0,50).
- **Desperdício:** US$ 0,016 foi de um defeito, a chave da imagem `screenshot`. A API troca toda ocorrência da chave pela imagem, inclusive nas perguntas. Corrigido, e há um teste que barra isso.
- **Por captura:** ~2,8 mil tokens a 1280×720, ~US$ 0,00012. Uma rodada de 8 capturas custa menos de US$ 0,001.

## O que fica
- **`tools/jev/capturas/conferir_capturas.py <pasta> [--jev]`:** uma tabela por captura com dia ou noite, neve, pinheiros e torre (pela geometria), e os avisos do que olhar primeiro.
  - Com `capturas.jsonl` (do `gerar_capturas.py`), compara com o esperado.
  - O Jev só recebe pastas em que toda captura diz `sem_capas: true`.
  - Saída 0 = nada a olhar, 1 = há avisos, 2 = erro.
- **Na skill `revisao-do-hub` (Evidência):** o comando para gerar e conferir.
- **A torre (15.10):** o gerador já mede a torre pela geometria (projeção na tela, altura em pixels e linha de visão). Quando ela existir, rodar o portão de novo com `--descricao-torre` para saber se o Jev julga "a torre se destaca" melhor que a geometria.
- **A aprovação visual continua sendo do dono.**

## Achado fora do Jev
A biblioteca falsa (`tests/fake_library.gd`) usa as **capas de verdade** do cache da Steam, a menos que `fixed_ids = true`.
- O gerador liga isso só na cópia descartável.
- A skill `revisao-do-hub` ainda sugere a biblioteca falsa como se ela não tivesse capas. A decisão fica com o dono.
