"""Peças comuns da triagem das falhas da bateria (plano docs/plans/ferramenta-jev.md).

Tudo aqui imita o tests/run_tests.sh sem mudá-lo: a bateria continua sendo a fonte
da verdade, e estas ferramentas só ficam ao lado dela.
"""
import os
import re
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


# ---- Privacidade: o que nunca sai do PC ------------------------------------------------------
def _pastas_da_steam() -> list:
    """As pastas da Steam (para achar os jogos instalados e escondê-los dos logs)."""
    pastas = []
    if os.name == "nt":
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as k:
                pastas.append(winreg.QueryValueEx(k, "SteamPath")[0])
        except OSError:
            pass
        pastas.append(r"C:\Program Files (x86)\Steam")
    else:
        casa = os.path.expanduser("~")
        pastas += [os.path.join(casa, ".steam", "steam"), os.path.join(casa, ".local", "share", "Steam")]
    return [p for p in pastas if os.path.isdir(p)]


def _manifestos() -> list:
    """Os appmanifest_<id>.acf de todas as bibliotecas da Steam deste PC."""
    bibliotecas = set()
    for steam in _pastas_da_steam():
        bibliotecas.add(os.path.normpath(steam))
        vdf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
        if os.path.isfile(vdf):
            with open(vdf, encoding="utf-8", errors="replace") as f:
                for caminho in re.findall(r'"path"\s+"([^"]+)"', f.read()):
                    bibliotecas.add(os.path.normpath(caminho.replace("\\\\", "\\")))
    saida = []
    for bib in bibliotecas:
        apps = os.path.join(bib, "steamapps")
        if os.path.isdir(apps):
            saida += [os.path.join(apps, a) for a in os.listdir(apps)
                      if a.startswith("appmanifest_") and a.endswith(".acf")]
    return saida


def jogos_instalados() -> list:
    """Os nomes dos jogos instalados (lidos dos appmanifest_*.acf de cada biblioteca)."""
    nomes = set()
    for arq in _manifestos():
        with open(arq, encoding="utf-8", errors="replace") as f:
            m = re.search(r'"name"\s+"([^"]+)"', f.read())
        if m:
            nomes.add(m.group(1))
    return sorted(nomes)


# Os jogos que vários testes exigem instalados (tests/README.md, "A biblioteca de verdade importa").
JOGOS_EXIGIDOS = {2379780: "Balatro", 489830: "Skyrim", 892970: "Valheim", 413150: "Stardew Valley"}


def apps_instalados():
    """Os app ids instalados neste PC, ou None se a Steam não foi achada (não dá para saber)."""
    if not _pastas_da_steam():
        return None
    ids = set()
    for arq in _manifestos():
        m = re.search(r"appmanifest_(\d+)\.acf$", arq)
        if m:
            ids.add(int(m.group(1)))
    return ids


def exigidos_faltando() -> dict:
    """Os jogos exigidos que não estão instalados neste PC ({app id: nome}).

    Se não achar a Steam, devolve todos: sem biblioteca, os testes falham do mesmo jeito.
    """
    ids = apps_instalados() or set()
    return {i: nome for i, nome in JOGOS_EXIGIDOS.items() if i not in ids}


def palavras_privadas() -> list:
    """O que nunca vai num log enviado: a pasta pessoal, o nome do usuário e os jogos instalados."""
    casa = os.path.expanduser("~")
    usuario = os.path.basename(casa)
    palavras = [casa, usuario] + [n for n in jogos_instalados() if len(n) >= 4]
    return [p for p in palavras if p]


def _variantes(caminho: str) -> list:
    """O mesmo caminho como cada programa escreve: com barra invertida, com barra
    normal (C:/Users/x) e no jeito do Git Bash (/c/Users/x)."""
    v = {caminho, caminho.replace("\\", "/")}
    m = re.match(r"^([A-Za-z]):[\\/](.*)$", caminho)
    if m:
        v.add("/%s/%s" % (m.group(1).lower(), m.group(2).replace("\\", "/")))
    return sorted(v, key=len, reverse=True)


def limpar_log(log: str, pastas_do_projeto: list, privados: list) -> str:
    """Troca a pasta do projeto por <projeto>, a pasta pessoal por <casa>, o nome do usuário
    por <usuario> e cada jogo instalado por <jogo>."""
    casa = os.path.expanduser("~")
    trocas = []
    for pasta in list(pastas_do_projeto) + [PROJETO]:
        trocas += [(v, "<projeto>") for v in _variantes(os.path.abspath(pasta))]
    trocas += [(v, "<casa>") for v in _variantes(casa)]
    for palavra in privados:
        if os.path.isabs(palavra):
            continue
        trocas.append((palavra, "<usuario>" if palavra == os.path.basename(casa) else "<jogo>"))
    for antes, depois in sorted(trocas, key=lambda t: len(t[0]), reverse=True):
        log = re.sub(re.escape(antes), depois, log, flags=re.IGNORECASE)
    return log


def tem_dado_privado(log: str, privados: list) -> bool:
    """Confere depois da limpeza: se algo privado sobrou, é verdadeiro."""
    baixo = log.lower()
    for palavra in privados:
        for v in (_variantes(palavra) if os.path.isabs(palavra) else [palavra]):
            if v.lower() in baixo:
                return True
    return False
