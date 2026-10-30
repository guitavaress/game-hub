"""Peças comuns da triagem das falhas da bateria (plano docs/plans/ferramenta-jev.md).

Tudo aqui imita o tests/run_tests.sh sem mudá-lo: a bateria continua sendo a fonte
da verdade, e estas ferramentas só ficam ao lado dela.
"""
import os
import shutil
import subprocess

# A raiz do projeto: tools/jev/ → duas pastas acima.
PROJETO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Os mesmos tempos do run_tests.sh.
TEMPO_TESTE = 240
TEMPO_IMPORTACAO = 300

# Saída que o `timeout` do run_tests.sh dá quando o tempo acaba.
SAIDA_TEMPO_ESGOTADO = 124

# Nomes "falsos" de teste para as falhas que não são de um check_*.gd.
FALHA_IMPORTACAO = "(importação)"
FALHA_SEM_GODOT = "(godot ausente)"


def achar_godot() -> str:
    """Acha a Godot na mesma ordem do run_tests.sh. Devolve "" se não achar."""
    candidatos = [os.environ.get("GODOT", ""),
                  r"C:\Godot\Godot_v4.7.2-stable_win64_console.exe",
                  shutil.which("godot") or "",
                  os.path.join(os.path.expanduser("~"), ".local", "bin", "godot")]
    for caminho in candidatos:
        if caminho and os.path.isfile(caminho):
            return caminho
    return ""


def veredito(teste: str, saida: str) -> str:
    """O mesmo julgamento do run_tests.sh: "ok", "ERRO DE SCRIPT" ou "FALHOU"."""
    if "SCRIPT ERROR" in saida:
        return "ERRO DE SCRIPT"
    if "RESULTADO: TUDO OK" in saida:
        return "ok"
    if teste == "check_phase3_cache" and "pronta" in saida:
        return "ok"
    if teste == "check_portal_regression" and "ok:" in saida and "FALHOU" not in saida:
        return "ok"
    return "FALHOU"


def comando_teste(godot: str, teste: str, projeto: str = PROJETO) -> list:
    """O comando que o run_tests.sh usa para um teste (com o caso especial do cache)."""
    cmd = [godot, "--headless", "--path", projeto, "-s", "res://tests/%s.gd" % teste]
    if teste == "check_phase3_cache":
        cmd += ["--", "--mode=cached"]
    return cmd


def comando_importacao(godot: str, projeto: str = PROJETO) -> list:
    return [godot, "--headless", "--path", projeto, "--import"]


def rodar(cmd: list, tempo: int, pasta: str = PROJETO) -> dict:
    """Roda um comando e devolve {"saida": código, "log": texto}.

    Tempo esgotado vira a saída 124, como no `timeout` do run_tests.sh.
    """
    try:
        r = subprocess.run(cmd, cwd=pasta, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=tempo)
        return {"saida": r.returncode, "log": r.stdout.decode("utf-8", errors="replace")}
    except subprocess.TimeoutExpired as e:
        parcial = (e.stdout or b"").decode("utf-8", errors="replace")
        return {"saida": SAIDA_TEMPO_ESGOTADO, "log": parcial}


# Arquivos novos (ainda fora do git) que contam como "mudança" para a triagem.
EXTENSOES_DO_PROJETO = (".gd", ".tres", ".tscn", ".gdshader", ".sh", ".py")


def arquivos_do_diff(base: str = "HEAD", pasta: str = PROJETO) -> list:
    """Os nomes dos arquivos mudados desde `base`, mais os novos do projeto.

    Só os nomes: o conteúdo nunca sai daqui.
    """
    def git(*args) -> list:
        r = subprocess.run(["git", *args], cwd=pasta, stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL)
        return [l for l in r.stdout.decode("utf-8", errors="replace").splitlines() if l]

    mudados = git("diff", "--name-only", base)
    # Pastas escondidas (.agents/, .vscode/...) são do editor ou de ferramentas, não do hub.
    novos = [f for f in git("ls-files", "--others", "--exclude-standard")
             if f.endswith(EXTENSOES_DO_PROJETO) and not f.startswith(".")]
    return sorted(set(mudados + novos))
