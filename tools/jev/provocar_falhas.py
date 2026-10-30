"""J.2 — Gabarito por falhas provocadas.

Numa cópia descartável do projeto (git worktree --detach, apagada no fim), quebra de
propósito um teste ou o código que ele usa, roda só aquele teste e guarda o log. Como a
causa é conhecida por construção, cada log vira uma linha de gabarito com a resposta certa.

Categorias (a resposta certa):
  regressao       uma conferência ou o código que ela usa mudou e o teste falha;
  erro_de_script  um nome errado (SCRIPT ERROR), no teste, no código ou na importação;
  tempo_esgotado  o teste não termina (laço sem fim ou tempo curto demais);
  ambiente        o problema não está no código: jogo exigido não instalado, cache da Godot
                  (.godot/) faltando, Godot ausente;
  instavel        falhou uma vez e passou ao rodar de novo.

Segurança:
  - nunca toca o user:// nem o config.cfg: só usa testes que não mexem neles, e só muda
    arquivos dentro da cópia descartável;
  - cada log passa por comum.limpar_log() (pasta pessoal, nome do usuário, jogos instalados);
  - o gabarito fica FORA do repositório (padrão: C:\\Ferramentas\\jev\\gabarito).

Uso:
  python tools/jev/provocar_falhas.py                 # tudo (umas dezenas de minutos)
  python tools/jev/provocar_falhas.py --so-base       # só confere quais testes servem
Enquanto roda, não abra a Godot nem rode a bateria em outra janela.
"""
import argparse
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(__file__))
import comum  # noqa: E402

SEMENTE = 1507

# Testes que mexem no user:// (config.cfg, cache) ficam de fora: matar um deles no meio
# pode deixar o config.cfg do dono sem a cópia devolvida. Testes que leem o sistema ou a
# conta da Steam também ficam de fora, para os logs não levarem dado do dono.
TOCA_USER = re.compile(r"user://|config\.cfg|AppConfig|app_config")
FORA_POR_PRIVACIDADE = {"check_desktop_apps_windows", "check_system_status", "check_system_panel",
                        "check_steam_windows", "check_steam_linux", "check_window_host"}

# Quantos casos de cada tipo (o total fica perto de 60).
METAS = {"regressao_teste": 14, "regressao_codigo": 10, "erro_teste": 6, "erro_codigo": 4,
         "erro_importacao": 2, "laco_sem_fim": 5, "tempo_curto": 3, "ambiente_cache": 6,
         "ambiente_sem_jogo": 6,
         "sem_godot": 2, "instavel": 5}

# Os jogos que vários testes exigem instalados (tests/README.md).
JOGOS_EXIGIDOS = {2379780: "Balatro", 489830: "Skyrim", 892970: "Valheim", 413150: "Stardew"}

TEMPO_ERRO = 25       # um SCRIPT ERROR deixa o teste parado até o tempo acabar; 25 s bastam
TEMPO_LACO = 25
PASTAS_DE_CODIGO = ("autoload/", "components/", "worlds/", "profiles/", "ui/", "player/")


# ---- Peças puras (testadas em test_provocar.py) -----------------------------------------
LINHA_CHECK = re.compile(r'^(\s*)_check\((".*?"(?:\s*%\s*[^,]+)?),\s*(.+)\)\s*$')


def linhas_de_check(texto: str) -> list:
    """Os números das linhas com um _check(...) inteiro numa linha só."""
    return [i for i, l in enumerate(texto.splitlines()) if LINHA_CHECK.match(l)]


def inverter_check(texto: str, i: int) -> str:
    """Troca `_check("x", cond)` por `_check("x", not (cond))` na linha i."""
    linhas = texto.splitlines(keepends=True)
    m = LINHA_CHECK.match(linhas[i].rstrip("\r\n"))
    fim = linhas[i][len(linhas[i].rstrip("\r\n")):]
    linhas[i] = "%s_check(%s, not (%s))%s" % (m.group(1), m.group(2), m.group(3), fim)
    return "".join(linhas)


MUTACOES = [  # (padrão, troca): cada uma muda o comportamento sem quebrar a sintaxe
    (re.compile(r"\btrue\b"), "false"),
    (re.compile(r"\bfalse\b"), "true"),
    (re.compile(r" == "), " != "),
    (re.compile(r" < "), " >= "),
    (re.compile(r" > "), " <= "),
    (re.compile(r"(?<![\w.])(\d+\.\d+)(?![\w.])"), None),  # número com vírgula: dobra
    (re.compile(r"(?<![\w.#])([1-9]\d*)(?![\w.])"), None),  # inteiro: soma 1 e dobra
]


def _codigo_da_linha(linha: str) -> str:
    """A linha sem o comentário e sem as strings (para não mutar texto)."""
    sem_str = re.sub(r'"(?:[^"\\]|\\.)*"', lambda m: " " * len(m.group(0)), linha)
    return sem_str.split("#", 1)[0]


def mutacoes_possiveis(texto: str) -> list:
    """Lista (linha, índice da mutação, posição) de cada mutação que cabe no código."""
    saida = []
    for i, linha in enumerate(texto.splitlines()):
        cod = _codigo_da_linha(linha)
        if not cod.strip() or cod.lstrip().startswith(("func ", "class_name", "extends", "signal",
                                                       "@export", "enum", "static func")):
            continue
        for k, (padrao, _) in enumerate(MUTACOES):
            for m in padrao.finditer(cod):
                saida.append((i, k, m.start()))
    return saida


def aplicar_mutacao(texto: str, linha: int, k: int, pos: int) -> str:
    linhas = texto.splitlines(keepends=True)
    padrao, troca = MUTACOES[k]
    m = padrao.match(linhas[linha], pos)
    if troca is None:
        valor = m.group(1)
        novo = "%.3f" % (float(valor) * 2 + 0.5) if "." in valor else str(int(valor) * 2 + 1)
    else:
        novo = troca
    linhas[linha] = linhas[linha][:m.start()] + novo + linhas[linha][m.end():]
    return "".join(linhas)


CHAMADA = re.compile(r"\b([a-z_][a-z0-9_]{3,})\(")


def chamadas_possiveis(texto: str) -> list:
    """(linha, posição, nome) de cada chamada de função dentro de um corpo de função."""
    saida = []
    for i, linha in enumerate(texto.splitlines()):
        if not linha.startswith("\t"):
            continue
        cod = _codigo_da_linha(linha)
        if cod.lstrip().startswith(("func ", "static func")):
            continue
        for m in CHAMADA.finditer(cod):
            saida.append((i, m.start(1), m.group(1)))
    return saida


def errar_nome(texto: str, linha: int, pos: int, nome: str) -> str:
    """Um erro de digitação: troca duas letras do meio do nome (ex.: "update" → "upadte")."""
    meio = len(nome) // 2
    errado = nome[:meio - 1] + nome[meio] + nome[meio - 1] + nome[meio + 1:]
    if errado == nome:
        errado = nome + "x"
    linhas = texto.splitlines(keepends=True)
    linhas[linha] = linhas[linha][:pos] + errado + linhas[linha][pos + len(nome):]
    return "".join(linhas)


def inserir_laco(texto: str) -> str:
    """Põe um laço sem fim logo depois do primeiro `await process_frame` (como uma espera
    por algo que nunca fica pronto)."""
    linhas = texto.splitlines(keepends=True)
    for i, l in enumerate(linhas):
        if l.strip() == "await process_frame":
            recuo = l[:len(l) - len(l.lstrip())]
            laco = "%swhile true:  # nunca fica pronto\n%s\tawait process_frame\n" % (recuo, recuo)
            linhas.insert(i + 1, laco)
            return "".join(linhas)
    return ""


def resumo_da_bateria(log: str) -> list:
    """As linhas que o run_tests.sh mostraria (grep FALHOU|SCRIPT ERROR|RESULTADO, 8 no máx.)."""
    return [l for l in log.splitlines() if re.search(r"FALHOU|SCRIPT ERROR|RESULTADO", l)][:8]


def separar_portao(casos: list, semente: int = SEMENTE) -> None:
    """Marca ~1/3 de cada categoria como "portao" (só para a nota final) e o resto como "ajuste"."""
    rnd = random.Random(semente)
    por_cat = {}
    for c in casos:
        por_cat.setdefault(c["categoria"], []).append(c)
    for lista in por_cat.values():
        rnd.shuffle(lista)
        n = max(1, round(len(lista) / 3)) if len(lista) > 1 else 0
        for j, c in enumerate(lista):
            c["parte"] = "portao" if j < n else "ajuste"


# ---- A cópia descartável ------------------------------------------------------------------
class Copia:
    """Um git worktree --detach numa pasta temporária, com o .godot/ do projeto copiado."""

    def __init__(self, base: str):
        self.pasta = os.path.join(tempfile.gettempdir(), "game-hub-jev", "provocar-%d" % os.getpid())
        assert os.path.normcase(os.path.abspath(self.pasta)) != os.path.normcase(comum.PROJETO)
        subprocess.run(["git", "worktree", "add", "--detach", "-q", self.pasta, base],
                       cwd=comum.PROJETO, check=True)
        self._copiar_godot()

    def _copiar_godot(self) -> None:
        destino = os.path.join(self.pasta, ".godot")
        if os.path.isdir(destino):
            shutil.rmtree(destino)
        shutil.copytree(os.path.join(comum.PROJETO, ".godot"), destino)

    def restaurar(self, godot_tambem: bool = False) -> None:
        """Desfaz tudo o que foi mudado na cópia (nunca no projeto de verdade)."""
        subprocess.run(["git", "checkout", "-q", "--", "."], cwd=self.pasta, check=True)
        subprocess.run(["git", "clean", "-fdq"], cwd=self.pasta, check=True)
        if godot_tambem:
            self._copiar_godot()

    def ler(self, rel: str) -> str:
        with open(os.path.join(self.pasta, rel), encoding="utf-8", newline="") as f:
            return f.read()

    def gravar(self, rel: str, texto: str) -> None:
        with open(os.path.join(self.pasta, rel), "w", encoding="utf-8", newline="") as f:
            f.write(texto)

    def apagar(self) -> None:
        subprocess.run(["git", "worktree", "remove", "--force", self.pasta], cwd=comum.PROJETO)
        shutil.rmtree(self.pasta, ignore_errors=True)


# ---- O gerador ------------------------------------------------------------------------------
class Gerador:
    def __init__(self, godot: str, copia: Copia, limpar):
        self.godot, self.copia, self.limpar = godot, copia, limpar
        self.rnd = random.Random(SEMENTE)
        self.casos = []
        self.tempos = {}            # teste → segundos da rodada limpa
        self.arquivos_gd = []       # todos os .gd do projeto (para o diff de "isca")
        self.classes = {}           # class_name → arquivo
        self.autoloads = {}         # nome do autoload → arquivo

    # -- preparação
    def mapear(self) -> None:
        r = subprocess.run(["git", "ls-files", "*.gd"], cwd=self.copia.pasta, stdout=subprocess.PIPE)
        self.arquivos_gd = r.stdout.decode().split()
        for f in self.arquivos_gd:
            if f.startswith(PASTAS_DE_CODIGO):
                m = re.search(r"^class_name\s+(\w+)", self.copia.ler(f), re.MULTILINE)
                if m:
                    self.classes[m.group(1)] = f
        for m in re.finditer(r'^(\w+)="\*res://(.+\.gd)"', self.copia.ler("project.godot"), re.MULTILINE):
            self.autoloads[m.group(1)] = m.group(2)

    def testes_seguros(self) -> list:
        saida = []
        for f in sorted(os.listdir(os.path.join(self.copia.pasta, "tests"))):
            nome = f[:-3]
            if (f.startswith("check_") and f.endswith(".gd") and nome not in FORA_POR_PRIVACIDADE
                    and not TOCA_USER.search(self.copia.ler("tests/" + f))):
                saida.append(nome)
        return saida

    def rodar(self, teste: str, tempo: int) -> dict:
        t0 = time.perf_counter()
        r = comum.rodar(comum.comando_teste(self.godot, teste, self.copia.pasta), tempo, self.copia.pasta)
        r["segundos"] = round(time.perf_counter() - t0, 1)
        r["status"] = comum.veredito(teste, r["log"])
        return r

    def base(self, testes: list) -> None:
        """Roda cada teste uma vez sem mudança: só os que passam (e não demoram) servem."""
        for t in testes:
            r = self.rodar(t, comum.TEMPO_TESTE)
            ok = r["status"] == "ok" and r["segundos"] < 90
            print("  base %-32s %-6s %5.1f s" % (t, r["status"], r["segundos"]), flush=True)
            if ok:
                self.tempos[t] = r["segundos"]

    def codigo_do_teste(self, teste: str) -> list:
        """Os arquivos de código que o teste usa: caminhos res://, classes e autoloads citados."""
        texto = self.copia.ler("tests/%s.gd" % teste)
        # O (?!\w) evita pegar o começo de um ".gdshader".
        achados = set(re.findall(r'res://((?:%s)[\w/]+\.gd)(?!\w)' % "|".join(PASTAS_DE_CODIGO), texto))
        for nome, arq in list(self.classes.items()) + list(self.autoloads.items()):
            if re.search(r"\b%s\b" % nome, texto):
                achados.add(arq)
        return sorted(a for a in achados if a.startswith(PASTAS_DE_CODIGO)
                      and os.path.isfile(os.path.join(self.copia.pasta, a)))

    def iscas(self, evitar: list, minimo: int = 0, maximo: int = 3) -> list:
        """Arquivos sem ligação com a falha, como mudanças que o agente fez em outra parte."""
        livres = [f for f in self.arquivos_gd if f not in evitar and not f.startswith("tests/")]
        return self.rnd.sample(livres, self.rnd.randint(minimo, maximo))

    # -- registro
    def guardar(self, teste, r, categoria, ligado, provocacao, mudado, diff, status_bateria=None,
                rodada2=None):
        log = self.limpar(r["log"])
        caso = {
            "id": "%s-%02d" % (provocacao, sum(1 for c in self.casos if c["provocacao"] == provocacao)),
            "teste": teste,
            "status_bateria": status_bateria or (r["status"] if r["status"] != "ok" else "FALHOU"),
            "resumo_bateria": resumo_da_bateria(log),
            "rodada2": rodada2 or {"saida": r["saida"], "status": r["status"], "passou": False,
                                   "tempo_esgotado": r["saida"] == comum.SAIDA_TEMPO_ESGOTADO},
            "log_texto": log,
            "diff": sorted(set(diff)),
            "categoria": categoria,
            "ligado_ao_diff": ligado,
            "provocacao": provocacao,
            "arquivo_mudado": mudado,
        }
        self.casos.append(caso)
        print("  + %-22s %-30s %s" % (provocacao, teste, categoria), flush=True)

    def _sorteia_testes(self) -> list:
        t = list(self.tempos)
        self.rnd.shuffle(t)
        return t

    def _tempo(self, teste: str) -> int:
        return int(self.tempos[teste] * 3 + 20)

    # -- os tipos de falha
    def regressao_teste(self, meta: int) -> None:
        for t in self._sorteia_testes():
            if meta <= 0:
                return
            rel = "tests/%s.gd" % t
            texto = self.copia.ler(rel)
            linhas = linhas_de_check(texto)
            if not linhas:
                continue
            self.copia.gravar(rel, inverter_check(texto, self.rnd.choice(linhas)))
            r = self.rodar(t, self._tempo(t))
            self.copia.restaurar()
            if r["status"] == "FALHOU" and r["saida"] != comum.SAIDA_TEMPO_ESGOTADO:
                self.guardar(t, r, "regressao", True, "regressao_teste", rel, [rel] + self.iscas([rel]))
                meta -= 1

    def regressao_codigo(self, meta: int, tentativas: int = 4) -> None:
        for t in self._sorteia_testes():
            if meta <= 0:
                return
            arquivos = self.codigo_do_teste(t)
            for _ in range(tentativas if arquivos else 0):
                rel = self.rnd.choice(arquivos)
                texto = self.copia.ler(rel)
                muts = mutacoes_possiveis(texto)
                if not muts:
                    continue
                self.copia.gravar(rel, aplicar_mutacao(texto, *self.rnd.choice(muts)))
                r = self.rodar(t, self._tempo(t))
                self.copia.restaurar()
                if r["status"] == "FALHOU" and r["saida"] != comum.SAIDA_TEMPO_ESGOTADO:
                    self.guardar(t, r, "regressao", True, "regressao_codigo", rel, [rel] + self.iscas([rel]))
                    meta -= 1
                    break

    def erro_de_nome(self, meta: int, no_codigo: bool) -> None:
        for t in self._sorteia_testes():
            if meta <= 0:
                return
            alvos = self.codigo_do_teste(t) if no_codigo else ["tests/%s.gd" % t]
            if not alvos:
                continue
            rel = self.rnd.choice(alvos)
            texto = self.copia.ler(rel)
            chamadas = chamadas_possiveis(texto)
            if not chamadas:
                continue
            self.copia.gravar(rel, errar_nome(texto, *self.rnd.choice(chamadas)))
            r = self.rodar(t, TEMPO_ERRO)
            self.copia.restaurar()
            if r["status"] == "ERRO DE SCRIPT":
                tipo = "erro_codigo" if no_codigo else "erro_teste"
                self.guardar(t, r, "erro_de_script", True, tipo, rel, [rel] + self.iscas([rel]))
                meta -= 1

    def erro_importacao(self, meta: int) -> None:
        candidatos = [f for f in self.arquivos_gd if f.startswith(PASTAS_DE_CODIGO)]
        for _ in range(meta * 3):
            if meta <= 0:
                return
            rel = self.rnd.choice(candidatos)
            texto = self.copia.ler(rel)
            chamadas = chamadas_possiveis(texto)
            if not chamadas:
                continue
            self.copia.gravar(rel, errar_nome(texto, *self.rnd.choice(chamadas)) + "\n\tfunc )\n")
            r = comum.rodar(comum.comando_importacao(self.godot, self.copia.pasta),
                            comum.TEMPO_IMPORTACAO, self.copia.pasta)
            self.copia.restaurar()
            if re.search(r"script error|parse error", r["log"], re.IGNORECASE):
                r["status"] = "ERRO DE SCRIPT"
                self.guardar(comum.FALHA_IMPORTACAO, r, "erro_de_script", True, "erro_importacao",
                             rel, [rel] + self.iscas([rel]))
                meta -= 1

    def laco_sem_fim(self, meta: int) -> None:
        for t in self._sorteia_testes():
            if meta <= 0:
                return
            rel = "tests/%s.gd" % t
            novo = inserir_laco(self.copia.ler(rel))
            if not novo:
                continue
            self.copia.gravar(rel, novo)
            r = self.rodar(t, TEMPO_LACO)
            self.copia.restaurar()
            if r["saida"] == comum.SAIDA_TEMPO_ESGOTADO and r["status"] == "FALHOU":
                self.guardar(t, r, "tempo_esgotado", True, "laco_sem_fim", rel, [rel] + self.iscas([rel]))
                meta -= 1

    def tempo_curto(self, meta: int) -> None:
        """Um PC lento: o teste é cortado no meio, sem mudança nenhuma no código."""
        lentos = sorted(self.tempos, key=self.tempos.get, reverse=True)
        for t in lentos[:meta]:
            r = self.rodar(t, max(1, int(self.tempos[t] / 3)))
            if r["saida"] == comum.SAIDA_TEMPO_ESGOTADO:
                self.guardar(t, r, "tempo_esgotado", False, "tempo_curto", "", self.iscas([], 1))

    def ambiente_cache(self, meta: int) -> None:
        """O cache da Godot (.godot/) estragado ou faltando: nada no código mudou."""
        estragos = [  # (nome, o que apagar dentro do .godot/)
            ("sem_classes", ["global_script_class_cache.cfg"]),
            ("sem_importados", ["imported"]),
            ("sem_uids", ["uid_cache.bin"]),
        ]
        por_estrago = max(1, meta // len(estragos))
        for nome, apagar in estragos:
            achados = 0
            for t in self._sorteia_testes():
                if achados >= por_estrago:
                    break
                for item in apagar:
                    alvo = os.path.join(self.copia.pasta, ".godot", item)
                    if os.path.isdir(alvo):
                        shutil.rmtree(alvo)
                    elif os.path.exists(alvo):
                        os.remove(alvo)
                r = self.rodar(t, self._tempo(t))
                self.copia.restaurar(godot_tambem=True)
                if r["status"] != "ok":
                    self.guardar(t, r, "ambiente", False, "ambiente_" + nome, "", self.iscas([], 1),
                                 status_bateria=r["status"])
                    achados += 1

    def ambiente_sem_jogo(self, meta: int) -> None:
        """Um dos jogos que os testes exigem não está instalado (veja tests/README.md).

        Só na cópia: a biblioteca passa a pular aquele jogo, como se ele não existisse.
        O diff não mostra isso, porque no caso real nada no código mudou.
        """
        rel = "autoload/steam_library.gd"
        original = "if _is_tool(game) or game.app_id in user_excluded:"
        for t in self._sorteia_testes():
            if meta <= 0:
                return
            texto_teste = self.copia.ler("tests/%s.gd" % t)
            ids = [i for i, nome in JOGOS_EXIGIDOS.items()
                   if str(i) in texto_teste or nome in texto_teste]
            if not ids:
                continue
            app_id = self.rnd.choice(ids)
            texto = self.copia.ler(rel)
            if original not in texto:
                print("  aviso: steam_library.gd mudou; o caso sem_jogo ficou de fora")
                return
            self.copia.gravar(rel, texto.replace(
                original, original[:-1] + " or game.app_id == %d:" % app_id))
            r = self.rodar(t, self._tempo(t))
            self.copia.restaurar()
            if r["status"] != "ok":
                self.guardar(t, r, "ambiente", False, "ambiente_sem_jogo", "", self.iscas([], 1),
                             status_bateria=r["status"])
                meta -= 1

    def sem_godot(self, meta: int) -> None:
        for i in range(meta):
            t = self.rnd.choice(list(self.tempos))
            r = {"saida": None, "status": "sem godot",
                 "log": "Godot não encontrada em /c/Godot/Godot_v4.7.2-stable_win64_console.exe "
                        "(use a variável GODOT).\n"}
            self.guardar(comum.FALHA_SEM_GODOT, r, "ambiente", False, "sem_godot", "",
                         self.iscas([], 1), status_bateria="AMBIENTE",
                         rodada2={"saida": None, "status": "sem godot", "passou": False,
                                  "tempo_esgotado": False})

    def instavel(self, meta: int) -> None:
        """Falha na 1ª vez (o log da bateria) e passa na 2ª (sem a mudança)."""
        for t in self._sorteia_testes():
            if meta <= 0:
                return
            rel = "tests/%s.gd" % t
            texto = self.copia.ler(rel)
            linhas = linhas_de_check(texto)
            if not linhas:
                continue
            self.copia.gravar(rel, inverter_check(texto, self.rnd.choice(linhas)))
            r1 = self.rodar(t, self._tempo(t))
            self.copia.restaurar()
            if r1["status"] != "FALHOU":
                continue
            r2 = self.rodar(t, self._tempo(t))
            if r2["status"] == "ok":
                # O log guardado é o da 2ª rodada, como o coletar_falhas.py guarda.
                caso_r = dict(r2)
                self.guardar(t, caso_r, "instavel", False, "instavel", "", self.iscas([], 1),
                             status_bateria="FALHOU",
                             rodada2={"saida": r2["saida"], "status": "ok", "passou": True,
                                      "tempo_esgotado": False})
                self.casos[-1]["resumo_bateria"] = resumo_da_bateria(self.limpar(r1["log"]))
                meta -= 1


def pasta_padrao() -> str:
    if os.name == "nt":
        return r"C:\Ferramentas\jev\gabarito"
    return os.path.join(os.path.expanduser("~"), ".local", "share", "game-hub-jev", "gabarito")


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="Gera o gabarito de falhas provocadas (J.2).")
    p.add_argument("--saida", default=pasta_padrao(), help="pasta do gabarito (fora do repositório)")
    p.add_argument("--base", default="HEAD", help="commit usado na cópia descartável")
    p.add_argument("--so-base", action="store_true", help="só roda a base e para")
    a = p.parse_args()

    godot = comum.achar_godot()
    if not godot:
        print("Godot não encontrada (use a variável GODOT).")
        return 1
    if os.path.normcase(os.path.abspath(a.saida)).startswith(os.path.normcase(comum.PROJETO)):
        print("o gabarito não pode ficar dentro do repositório.")
        return 1

    t0 = time.time()
    copia = Copia(a.base)
    privados = comum.palavras_privadas()
    limpar = lambda log: comum.limpar_log(log, [copia.pasta], privados)  # noqa: E731
    try:
        g = Gerador(godot, copia, limpar)
        g.mapear()
        testes = g.testes_seguros()
        print("== base: %d testes sem user:// ==" % len(testes), flush=True)
        g.base(testes)
        print("   %d servem" % len(g.tempos), flush=True)
        if a.so_base:
            return 0
        print("== provocando ==", flush=True)
        passos = [
            lambda: g.regressao_teste(METAS["regressao_teste"]),
            lambda: g.regressao_codigo(METAS["regressao_codigo"]),
            lambda: g.erro_de_nome(METAS["erro_teste"], no_codigo=False),
            lambda: g.erro_de_nome(METAS["erro_codigo"], no_codigo=True),
            lambda: g.erro_importacao(METAS["erro_importacao"]),
            lambda: g.laco_sem_fim(METAS["laco_sem_fim"]),
            lambda: g.tempo_curto(METAS["tempo_curto"]),
            lambda: g.ambiente_cache(METAS["ambiente_cache"]),
            lambda: g.ambiente_sem_jogo(METAS["ambiente_sem_jogo"]),
            lambda: g.sem_godot(METAS["sem_godot"]),
            lambda: g.instavel(METAS["instavel"]),
        ]
        for passo in passos:
            # Um tipo com defeito não derruba os outros: o que já foi feito fica.
            try:
                passo()
            except Exception:  # noqa: BLE001
                import traceback
                print("ERRO num passo (os outros seguem):", flush=True)
                print(traceback.format_exc(), flush=True)
                copia.restaurar(godot_tambem=True)
    finally:
        copia.apagar()

    separar_portao(g.casos)
    vazou = [c["id"] for c in g.casos if comum.tem_dado_privado(c["log_texto"], privados)]
    if vazou:
        print("PARADO: dado privado sobrou nos logs de %s; nada foi gravado." % vazou)
        return 1
    os.makedirs(a.saida, exist_ok=True)
    with open(os.path.join(a.saida, "falhas.jsonl"), "w", encoding="utf-8") as f:
        for c in g.casos:
            f.write(json.dumps(c, ensure_ascii=False) + "\n")
    contagem = {}
    for c in g.casos:
        chave = "%s/%s" % (c["categoria"], c["parte"])
        contagem[chave] = contagem.get(chave, 0) + 1
    with open(os.path.join(a.saida, "resumo.json"), "w", encoding="utf-8") as f:
        json.dump({"semente": SEMENTE, "base": a.base, "testes_usados": len(g.tempos),
                   "casos": len(g.casos), "contagem": contagem,
                   "minutos": round((time.time() - t0) / 60, 1)}, f, ensure_ascii=False, indent=1)
    print("== %d casos em %s (%.1f min) ==" % (len(g.casos), a.saida, (time.time() - t0) / 60))
    for k in sorted(contagem):
        print("   %-28s %d" % (k, contagem[k]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
