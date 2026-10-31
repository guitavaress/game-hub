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
- [ ] **C.2 Capturas com defeito conhecido + régua de código** (Opus · high; revisão `/codex:review`)
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
- [ ] **C.3 Perguntas e portão** (Opus · high; revisão `/codex:adversarial-review`)
  - `perguntas_capturas.py`: uma noul por conferência, sobre o que se vê (torre visível, pinheiro escuro mas verde, neve sem detalhe, dia).
  - `avaliar_capturas.py`:
    - o limiar é medido no ajuste;
    - no portão, três notas por conferência: régua, Jev, e os dois juntos.
  - **O Jev só fica onde passar:**
    - ≥ 90% de acerto;
    - ≥ 10 pontos acima da régua;
    - nenhuma classe colapsada.
- [ ] **C.4 Decisão e entrega** (Opus · low; revisão `/codex:review`)
  - Doc `docs/design/jev-capturas-spike-2026-10-31.md`: os números, o custo e a decisão por conferência.
  - `tools/jev/capturas/conferir_capturas.py <pasta>`: uma tabela por captura (a régua, mais o Jev onde ele passou), para a 15.10 e a 15.13. Mais uma linha na skill `revisao-do-hub`.
  - **A aprovação visual continua sendo do dono.** A ferramenta só aponta o que olhar primeiro.

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
