"""J.3 — Triagem das falhas da bateria (só código: sem internet, sem chave, sem custo).

Para cada teste que falhou, diz a categoria, a frase do log que decidiu e se a falha tem
ligação com os arquivos do diff. A tabela (`categoria_regras`):

  Godot ausente                                   → ambiente
  passou ao rodar de novo                         → instavel
  Parse Error ou Compile Error no log             → erro_de_script
  'Node not found: "Building_<id>' no log e o jogo <id> NÃO está instalado
                                                  → ambiente (falta um jogo que o teste exige)
  (com o jogo instalado, ou sem dar para saber, o prédio faltando é do código: segue abaixo)
  outro SCRIPT ERROR                              → erro_de_script
  saída 124 ao rodar de novo                      → tempo_esgotado
  o resto (conferências que falharam)             → regressao

Por que só código: no portão da J.3 (docs/plans/ferramenta-jev.md), o Jev acertou 95%, e
esta tabela acertou os mesmos 95%. A tabela com o Jev (`categoria_com_jev`) fica no fim
deste arquivo só para o avaliar.py repetir a medida.

Uso:
  bash tests/run_tests.sh > saida.txt
  python tools/jev/triar_falhas.py saida.txt          # coleta (roda de novo o que falhou) e tria
  python tools/jev/triar_falhas.py --coleta PASTA     # usa uma coleta já feita
"""
import argparse
import json
import os
import re
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(__file__))
import coletar_falhas  # noqa: E402
import comum  # noqa: E402

CATEGORIAS = ["regressao", "erro_de_script", "tempo_esgotado", "ambiente", "instavel"]

ERRO_DE_COMPILACAO = re.compile(r"Parse Error|Compile Error")
# Cada jogo instalado vira um nó "Building_<app id>" na cidade; se ele não existe, o teste
# que precisa daquele jogo falha (tests/README.md: "A biblioteca de verdade importa").
PREDIO_FALTANDO = re.compile(r'Node not found: "Building_(\d+)')


def frase_decisiva(log: str) -> str:
    """A primeira linha que explica a falha: SCRIPT ERROR, depois [FALHOU], depois ERROR."""
    linhas = log.splitlines()
    for marca in ("SCRIPT ERROR", "[FALHOU]", "ERROR"):
        for l in linhas:
            if marca in l:
                return l.strip()[:200]
    return ""


def frase_de_ambiente(log: str) -> str:
    for l in log.splitlines():
        if PREDIO_FALTANDO.search(l):
            return l.strip()[:200]
    return frase_decisiva(log)


def jogos_ausentes_no_log(log: str, instalados) -> list:
    """Os app ids de prédios que faltam no log E cujo jogo não está instalado.

    `instalados` é o conjunto de app ids deste PC, ou None quando não dá para saber. Sem
    essa prova, a lista vem vazia: um prédio pode faltar por causa do código (ex.: uma
    mudança que tira o GamePortal), e a triagem não pode dizer "não é o seu código" sem
    ter certeza (achado da revisão do Codex, J.3.1).
    """
    if instalados is None:
        return []
    ids = {int(m.group(1)) for m in PREDIO_FALTANDO.finditer(log)}
    return sorted(i for i in ids if i not in instalados)


def pela_regra(caso: dict, log: str):
    """O que não depende de ler o log. Devolve (categoria, frase) ou None."""
    r2 = caso["rodada2"]
    if caso["teste"] == comum.FALHA_SEM_GODOT or r2.get("status") == "sem godot":
        return "ambiente", "Godot não encontrada"
    if r2.get("passou"):
        return "instavel", "passou ao rodar de novo"
    return None


def tem_script_error(caso: dict, log: str) -> bool:
    return "SCRIPT ERROR" in log or caso["rodada2"].get("status") == "ERRO DE SCRIPT"


def tempo_esgotado(caso: dict) -> bool:
    return caso["rodada2"].get("saida") == comum.SAIDA_TEMPO_ESGOTADO


def categoria_regras(caso: dict, log: str, instalados) -> tuple:
    """A tabela usada pela ferramenta (veja o topo do arquivo). Devolve (categoria, frase).

    `instalados`: os app ids instalados (comum.apps_instalados()), ou None se não dá para saber.
    """
    regra = pela_regra(caso, log)
    if regra:
        return regra
    if ERRO_DE_COMPILACAO.search(log):
        return "erro_de_script", frase_decisiva(log)
    ausentes = jogos_ausentes_no_log(log, instalados)
    if ausentes:
        nomes = ", ".join("%s (%d)" % (comum.JOGOS_EXIGIDOS.get(i, "jogo"), i) for i in ausentes)
        return "ambiente", "não instalado: %s; no log: %s" % (nomes, frase_de_ambiente(log))
    if tem_script_error(caso, log):
        return "erro_de_script", frase_decisiva(log)
    if tempo_esgotado(caso):
        return "tempo_esgotado", "tempo esgotado (saída 124)"
    return "regressao", frase_decisiva(log)


def ligados_ao_diff(caso: dict, log: str) -> list:
    """O arquivo do próprio teste, ou um arquivo do diff citado pelo nome no log."""
    baixo = log.lower()
    saida = []
    for f in caso.get("diff", []):
        nome = os.path.splitext(os.path.basename(f))[0].lower()
        if f == "tests/%s.gd" % caso["teste"] or (len(nome) >= 4 and nome in baixo):
            saida.append(f)
    return saida


# ---- Linha de comando --------------------------------------------------------------------
def ler_coleta(pasta: str) -> list:
    with open(os.path.join(pasta, "coleta.json"), encoding="utf-8") as f:
        coleta = json.load(f)
    casos = []
    for e in coleta["falhas"]:
        with open(os.path.join(pasta, e["log"]), encoding="utf-8") as f:
            casos.append(({**e, "diff": coleta["diff"]}, f.read()))
    return casos


NOMES = {"regressao": "REGRESSÃO", "erro_de_script": "ERRO DE SCRIPT", "tempo_esgotado":
         "TEMPO ESGOTADO", "ambiente": "AMBIENTE", "instavel": "INSTÁVEL"}

O_QUE_FAZER = {
    "regressao": "o código mudou o resultado: compare a conferência com o diff",
    "erro_de_script": "corrija o nome ou a sintaxe na linha do \"at:\"",
    "tempo_esgotado": "o teste não terminou: procure uma espera sem fim (ou o PC estava lento)",
    "ambiente": "não é o seu código: confira se o jogo exigido está instalado (tests/README.md)",
    "instavel": "passou ao rodar de novo: rode a bateria outra vez antes de mexer em algo",
}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="Triagem das falhas da bateria (J.3), só com código.")
    p.add_argument("saida_bateria", nargs="?", help='saída do run_tests.sh, ou "-" para o stdin')
    p.add_argument("--coleta", help="pasta de uma coleta já feita (coleta.json)")
    p.add_argument("--base", default="HEAD", help="ref do git para o diff (padrão: HEAD)")
    a = p.parse_args()

    if a.coleta:
        pasta = a.coleta
    elif a.saida_bateria:
        if a.saida_bateria == "-":
            dados = sys.stdin.buffer.read()
        else:
            with open(a.saida_bateria, "rb") as f:
                dados = f.read()
        pasta = os.path.join(tempfile.gettempdir(), "game-hub-jev", time.strftime("coleta-%Y%m%d-%H%M%S"))
        if not coletar_falhas.coletar(coletar_falhas.decodificar(dados), pasta, comum.achar_godot(),
                                      comum.arquivos_do_diff(a.base)):
            print("nada a triar: a saída não tem falhas de teste.")
            return 0
    else:
        p.error("passe a saída da bateria ou --coleta PASTA")

    # Um jogo exigido que falta pode derrubar um teste sem deixar rastro no log (no portão,
    # o check_session_summary só mostrou "[FALHOU] resumo do Skyrim"). Conferir é exato.
    instalados = comum.apps_instalados()
    if instalados is None:
        print("AVISO: a Steam não foi achada; sem saber o que está instalado, nenhum prédio "
              "faltando é tratado como ambiente.")
    for app_id, nome in comum.exigidos_faltando().items():
        print("AVISO DE AMBIENTE: %s (%d) não está instalado; os testes que dependem dele "
              "falham sem ser culpa do código (tests/README.md)." % (nome, app_id))

    for caso, log in ler_coleta(pasta):
        cat, frase = categoria_regras(caso, log, instalados)
        lig = ligados_ao_diff(caso, log)
        print("%s: %s" % (caso["teste"], NOMES[cat]))
        if frase:
            print("    frase: %s" % frase)
        print("    ligada ao diff: %s" % (", ".join(lig) if lig else "não"))
        print("    o que fazer: %s" % O_QUE_FAZER[cat])
    print("logs completos em: %s" % pasta)
    return 0


# ---- Só para a medida (avaliar.py): a base do plano e a tabela com o Jev -------------------
SINAIS_DE_AMBIENTE = re.compile(r"Failed loading|Can't load|Cannot open|No loader found|"
                                r"Could not find|not installed|não instalad", re.IGNORECASE)


def categoria_base(caso: dict, log: str) -> tuple:
    """A tabela original do plano ("SCRIPT ERROR → erro de script"): a base do portão."""
    regra = pela_regra(caso, log)
    if regra:
        return regra
    if tem_script_error(caso, log):
        return "erro_de_script", frase_decisiva(log)
    if tempo_esgotado(caso):
        return "tempo_esgotado", "tempo esgotado (saída 124)"
    m = SINAIS_DE_AMBIENTE.search(log)
    if m:
        return "ambiente", m.group(0)
    return "regressao", frase_decisiva(log)


def categoria_com_jev(caso: dict, log: str, p: dict, sim: float = 0.7, nao: float = 0.3) -> tuple:
    """A tabela medida no portão: no lugar da regra do prédio, o Jev responde
    "falta um jogo instalado?" (p["jogo_faltando"]); entre `nao` e `sim`, "indefinido"."""
    regra = pela_regra(caso, log)
    if regra:
        return regra
    if ERRO_DE_COMPILACAO.search(log):
        return "erro_de_script", frase_decisiva(log)
    falta = p["jogo_faltando"]
    if tem_script_error(caso, log):
        if falta >= sim:
            return "ambiente", frase_de_ambiente(log)
        return ("erro_de_script" if falta <= nao else "indefinido"), frase_decisiva(log)
    if tempo_esgotado(caso):
        return "tempo_esgotado", "tempo esgotado (saída 124)"
    if falta >= sim:
        return "ambiente", frase_de_ambiente(log)
    return ("regressao" if falta <= nao else "indefinido"), frase_decisiva(log)


def ligados_com_jev(caso: dict, p: dict, arquivos_para_o_jev: list, sim: float = 0.7) -> list:
    """O arquivo do próprio teste (código) mais os que o Jev ligou (ligado_<i>)."""
    proprio = "tests/%s.gd" % caso["teste"]
    saida = [proprio] if proprio in caso.get("diff", []) else []
    for i, f in enumerate(arquivos_para_o_jev):
        if p.get("ligado_%d" % i, 0.0) >= sim:
            saida.append(f)
    return saida


if __name__ == "__main__":
    sys.exit(main())
