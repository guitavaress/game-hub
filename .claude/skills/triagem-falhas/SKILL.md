---
name: triagem-falhas
description: >
  Triagem das falhas da bateria do Game Hub (tests/run_tests.sh). Use quando a bateria não
  terminar com "RESULTADO GERAL: TUDO OK", antes de ler os logs da Godot: a ferramenta roda
  de novo só o que falhou e diz, por teste, se é regressão, erro de script, tempo esgotado,
  ambiente (ex.: jogo exigido não instalado) ou instável, com a frase do log e a ligação
  com o diff. Só código: sem internet, sem chave, sem custo.
---

# Triagem das falhas da bateria

Plano e medida: [docs/plans/ferramenta-jev.md](../../../docs/plans/ferramenta-jev.md).

## Quando usar
Sempre que a bateria falhar, **antes** de abrir o log inteiro de algum teste.

## Como
```bash
bash tests/run_tests.sh > "$TMP/saida.txt"   # a saída fica fora do repositório
python tools/jev/triar_falhas.py "$TMP/saida.txt"
```
- No PowerShell: `& 'C:\Program Files\Git\bin\bash.exe' tests/run_tests.sh > $env:TEMP\saida.txt` e depois `python tools/jev/triar_falhas.py $env:TEMP\saida.txt`. A ferramenta lê UTF-8, UTF-8 com BOM e UTF-16.
- Ela roda de novo **só** os testes que falharam (uma Godot por vez: não rode outra bateria nem a Godot ao mesmo tempo).
- Para comparar com outro ponto do git: `--base fase-15`.
- Os logs completos ficam na pasta que ela imprime no fim (`logs completos em: ...`), fora do repositório.

## Como ler o resultado
| Categoria | O que quer dizer | O que fazer |
|---|---|---|
| REGRESSÃO | uma conferência deu outro resultado | compare a conferência (frase) com o diff |
| ERRO DE SCRIPT | nome ou sintaxe errados | corrija na linha do `at:` |
| TEMPO ESGOTADO | o teste não terminou | procure uma espera sem fim; ou o PC estava lento |
| AMBIENTE | não é o código (jogo exigido faltando, Godot ausente) | confira o que falta; não mexa no código por isso |
| INSTÁVEL | falhou e passou ao rodar de novo | rode a bateria outra vez antes de mexer |

- Um **AVISO DE AMBIENTE** no topo diz que um dos 4 jogos exigidos (Balatro, Skyrim, Valheim, Stardew Valley) não está instalado. Os testes que dependem dele falham mesmo sem rastro no log.
- "ligada ao diff" lista os arquivos mudados que o log cita (ou o próprio teste). "não" quer dizer que o log não cita nenhum arquivo do diff, e não que a falha seja de outro lugar.

## Auditoria (obrigatória)
- Em **toda** triagem, abra o log inteiro de **um** teste (o primeiro da lista) e confira se a categoria bate.
- Se ela errar, diga isso ao dono no resumo da subetapa e anote em `docs/plans/ferramenta-jev.md` (seção "Uso"): teste, categoria certa e categoria dada.
- **Dois erros seguidos suspendem a ferramenta:** volte a ler os logs à mão e avise o dono.

## O que ela não faz
- Não muda a bateria nem o `run_tests.sh`, e não decide por você: é um resumo para ler primeiro.
- O `cargo test` (Linux) fica fora; veja a saída da bateria.
