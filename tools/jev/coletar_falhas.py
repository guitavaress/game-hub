"""J.1 — Coleta das falhas da bateria.

Lê a saída do tests/run_tests.sh, roda de novo SÓ os testes que falharam (com o
mesmo comando da bateria) e guarda, numa pasta temporária fora do repositório:
  - <teste>.log   o log completo da segunda rodada;
  - coleta.json   o que a bateria mostrou, o resultado da segunda rodada e os
                  nomes dos arquivos do diff.

Uso:
  bash tests/run_tests.sh > saida.txt
  python tools/jev/coletar_falhas.py saida.txt           # ou "-" para ler do stdin
  python tools/jev/coletar_falhas.py saida.txt --base fase-15 --saida C:/temp/coleta

Nada aqui fala com a internet: a coleta é só local.
"""
import argparse
import json
import os
import re
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(__file__))
import comum  # noqa: E402

# "check_gates: FALHOU" ou "check_gates: ERRO DE SCRIPT"; as linhas de baixo,
# com 4 espaços, são o resumo que a bateria mostrou.
LINHA_FALHA = re.compile(r"^(check_\w+): (FALHOU|ERRO DE SCRIPT)\s*$")
LINHA_RESUMO = re.compile(r"^    (.*)$")


def decodificar(dados: bytes) -> str:
    """Lê a saída da bateria em qualquer codificação comum.

    O `> saida.txt` do Windows PowerShell 5.1 grava em UTF-16 (com BOM); o Git Bash, em
    UTF-8. Lida como UTF-8, a de UTF-16 vira letras com NUL no meio e nenhuma falha seria
    achada.
    """
    if dados.startswith((b"\xff\xfe", b"\xfe\xff")):
        return dados.decode("utf-16", errors="replace")
    # UTF-16 sem BOM: metade dos bytes é NUL (texto quase todo ASCII).
    if dados and dados.count(b"\x00") > len(dados) // 4:
        par = dados[1::2].count(b"\x00") > dados[0::2].count(b"\x00")
        return dados.decode("utf-16-le" if par else "utf-16-be", errors="replace")
    return dados.decode("utf-8-sig", errors="replace")


def ler_falhas(texto: str) -> list:
    """Acha as falhas na saída da bateria. Devolve [{teste, status_bateria, resumo_bateria}]."""
    falhas = []
    linhas = texto.splitlines()
    atual = None
    for linha in linhas:
        m = LINHA_FALHA.match(linha)
        if m:
            atual = {"teste": m.group(1), "status_bateria": m.group(2), "resumo_bateria": []}
            falhas.append(atual)
            continue
        r = LINHA_RESUMO.match(linha)
        if atual is not None and r:
            atual["resumo_bateria"].append(r.group(1))
            continue
        atual = None

    # A bateria para antes dos testes quando a importação falha ou a Godot não existe.
    if "RESULTADO GERAL: erro de script ao importar" in texto:
        i = linhas.index("RESULTADO GERAL: erro de script ao importar")
        erros = [l for l in linhas[:i] if l and not l.startswith("==")]
        falhas.append({"teste": comum.FALHA_IMPORTACAO, "status_bateria": "ERRO DE SCRIPT",
                       "resumo_bateria": erros[-5:]})
    for linha in linhas:
        if linha.startswith("Godot não encontrada em"):
            falhas.append({"teste": comum.FALHA_SEM_GODOT, "status_bateria": "AMBIENTE",
                           "resumo_bateria": [linha]})
            break
    return falhas


def rodar_de_novo(falha: dict, godot: str, projeto: str = comum.PROJETO) -> dict:
    """Roda a falha de novo. Devolve {saida, status, log}; sem Godot, status "sem godot"."""
    if not godot or falha["teste"] == comum.FALHA_SEM_GODOT:
        return {"saida": None, "status": "sem godot", "log": ""}
    if falha["teste"] == comum.FALHA_IMPORTACAO:
        r = comum.rodar(comum.comando_importacao(godot, projeto), comum.TEMPO_IMPORTACAO, projeto)
        tem_erro = re.search(r"script error|parse error", r["log"], re.IGNORECASE)
        r["status"] = "ERRO DE SCRIPT" if tem_erro else "ok"
        return r
    r = comum.rodar(comum.comando_teste(godot, falha["teste"], projeto), comum.TEMPO_TESTE, projeto)
    r["status"] = comum.veredito(falha["teste"], r["log"])
    return r


def coletar(texto: str, pasta: str, godot: str, diff: list, rodar=rodar_de_novo) -> list:
    """Coleta cada falha em `pasta`. Devolve as entradas gravadas no coleta.json.

    `rodar` pode ser trocado nos testes, para não abrir a Godot.
    """
    falhas = ler_falhas(texto)
    if not falhas:
        return []
    os.makedirs(pasta, exist_ok=True)
    entradas = []
    for falha in falhas:
        t0 = time.perf_counter()
        r = rodar(falha, godot)
        nome_log = re.sub(r"[^\w.-]", "_", falha["teste"]) + ".log"
        with open(os.path.join(pasta, nome_log), "w", encoding="utf-8") as f:
            f.write(r["log"])
        entradas.append({
            **falha,
            "rodada2": {
                "saida": r["saida"],
                "status": r["status"],
                "passou": r["status"] == "ok",
                "tempo_esgotado": r["saida"] == comum.SAIDA_TEMPO_ESGOTADO,
                "segundos": round(time.perf_counter() - t0, 1),
            },
            "log": nome_log,
        })
    with open(os.path.join(pasta, "coleta.json"), "w", encoding="utf-8") as f:
        json.dump({"diff": diff, "falhas": entradas}, f, ensure_ascii=False, indent=1)
    return entradas


def main() -> int:
    # No Windows, a saída por pipe vem em cp1252 e estraga os acentos.
    sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="Coleta as falhas da bateria (J.1).")
    p.add_argument("saida_bateria", help='arquivo com a saída do run_tests.sh, ou "-" para o stdin')
    p.add_argument("--saida", help="pasta onde guardar (padrão: pasta temporária do sistema)")
    p.add_argument("--base", default="HEAD", help="ref do git para o diff (padrão: HEAD)")
    a = p.parse_args()

    if a.saida_bateria == "-":
        texto = decodificar(sys.stdin.buffer.read())
    else:
        with open(a.saida_bateria, "rb") as f:
            texto = decodificar(f.read())
    if "cargo test: FALHOU" in texto:
        print("aviso: o cargo test falhou; ele fica fora da triagem (veja a saída da bateria).")

    pasta = a.saida or os.path.join(tempfile.gettempdir(), "game-hub-jev",
                                    time.strftime("coleta-%Y%m%d-%H%M%S"))
    entradas = coletar(texto, pasta, comum.achar_godot(), comum.arquivos_do_diff(a.base))
    if not entradas:
        print("nada a coletar: a saída não tem falhas de teste.")
        return 0
    for e in entradas:
        r = e["rodada2"]
        print("%s: bateria %s; de novo: %s%s" % (
            e["teste"], e["status_bateria"], r["status"],
            " (tempo esgotado)" if r["tempo_esgotado"] else ""))
    print("coleta em: %s" % pasta)
    return 0


if __name__ == "__main__":
    sys.exit(main())
