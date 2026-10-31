"""Spike do Jev nas capturas (C.2): gera o gabarito de capturas com defeito conhecido.

Para cada variante (normal, torre escondida, pinheiro preto, neve estourada, tela
quase preta), roda o gerar_capturas.gd numa cópia descartável do projeto:
  - a pasta de dados (user://) é própria da cópia (provocar_falhas.Copia, J.2.1);
  - a biblioteca falsa usa IDs inventados (fixed_ids): nenhuma capa de jogo real;
  - nada muda no repositório, e a cópia é apagada no fim.

Depois reduz cada PNG para 1280x720 (o limite do Jev é 1568 px por lado) e grava
<saida>/capturas.jsonl no formato do contrato (docs/plans/ferramenta-jev-capturas.md).

  python tools/jev/capturas/gerar_capturas.py [--saida PASTA]
Enquanto roda, não abra a Godot nem rode a bateria em outra janela.
"""
import argparse
import json
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import comum  # noqa: E402
import provocar_falhas as pf  # noqa: E402

VARIANTES = ["normal", "torre_escondida", "sem_pinheiros", "neve_estourada", "tela_preta"]
# Ajuste: as horas e os pontos que as perguntas vão "ver". Portão: outras horas, câmera
# deslocada e o mirante, que o ajuste nunca vê.
RODADAS = [("ajuste", "13,22", False), ("portao", "10,20", True)]
PONTOS_DO_AJUSTE = {"praca", "portico", "cima"}
# A torre conta como "visível" (rótulo verdadeiro) só se for clara: na tela, sem nada na
# frente e com pelo menos esta altura (px, numa imagem de 720). Abaixo disso, ambígua.
TORRE_CLARA_PX = 20.0
GDSCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gerar_capturas.gd")
# 0xC0000005: a Godot com janela às vezes cai ao FECHAR, depois de salvar (visto na C.1).
SAIDAS_ACEITAS = {0, 3221225477}


def pasta_padrao() -> str:
    if os.name == "nt":
        return r"C:\Ferramentas\jev\capturas\gabarito"
    return os.path.join(os.path.expanduser("~"), ".local", "share", "game-hub-jev", "capturas")


def rotulos(variante: str, noite: float, geo: dict) -> dict:
    """A resposta certa de cada conferência, por construção. None = não dá para julgar."""
    dia = True if noite < 0.1 else (False if noite > 0.9 else None)
    preta = variante == "tela_preta"
    # A variante "tela_preta" NÃO fica preta (a exposição x0,02 deixa a cena cinza e
    # reconhecível: o néon e a névoa não escurecem). Rótulo "sim" seria falso: fica fora.
    r = {"tela_preta": None if preta else False, "dia": None if preta else dia}
    if preta:
        # Na tela quase preta não dá para ver neve, pinheiro nem torre.
        r.update({"neve_estourada": None, "sem_pinheiros": None, "torre_visivel": None})
        return r
    r["neve_estourada"] = (True if dia else None) if variante == "neve_estourada" else False
    # De noite um pinheiro quase não se vê, com ou sem defeito: fica fora.
    if not dia:
        r["sem_pinheiros"] = None
    else:
        r["sem_pinheiros"] = variante == "sem_pinheiros"
    if variante == "torre_escondida" or not geo["torre_na_tela"]:
        r["torre_visivel"] = False
    elif geo["torre_desobstruida"] and geo["torre_altura_px"] >= TORRE_CLARA_PX:
        r["torre_visivel"] = True
    else:
        r["torre_visivel"] = None                     # pequena ou tapada: ambígua
    return r


def parte_de(rodada: str, ponto: str) -> str:
    return "ajuste" if rodada == "ajuste" and ponto in PONTOS_DO_AJUSTE else "portao"


REDUZIR_GD = """extends SceneTree

func _initialize() -> void:
\tvar lista := FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]).split("\\n", false)
\tfor linha in lista:
\t\tvar par := linha.strip_edges().split("|")
\t\tvar img := Image.load_from_file(par[0])
\t\timg.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
\t\timg.save_png(par[1])
\tprint("REDUZIDAS ", lista.size())
\tquit()
"""


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="Gera o gabarito de capturas (spike do Jev, C.2).")
    p.add_argument("--saida", default=pasta_padrao())
    p.add_argument("--base", default="HEAD")
    p.add_argument("--variantes", default=",".join(VARIANTES), help="só estas (teste rápido)")
    p.add_argument("--rodadas", default="ajuste,portao", help="só estas (teste rápido)")
    a = p.parse_args()
    variantes = [v for v in a.variantes.split(",") if v in VARIANTES]
    rodadas = [r for r in RODADAS if r[0] in a.rodadas.split(",")]
    if os.path.normcase(os.path.abspath(a.saida)).startswith(os.path.normcase(comum.PROJETO)):
        print("o gabarito não pode ficar dentro do repositório.")
        return 1
    godot = comum.achar_godot()
    if not godot:
        print("Godot não encontrada (use a variável GODOT).")
        return 1
    real = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Game Hub", "config.cfg")
    antes = os.path.getmtime(real) if os.path.isfile(real) else None

    t0 = time.time()
    brutas = os.path.join(a.saida, "_brutas")
    os.makedirs(brutas, exist_ok=True)
    copia = pf.Copia(a.base, godot)
    casos, pares = [], []
    try:
        # Biblioteca falsa SEM capas reais, só na cópia.
        rel = "tests/fake_library.gd"
        velho = "fake_playtimes: bool = false, fixed_ids: bool = false)"
        texto = copia.ler(rel)
        if velho not in texto:
            raise RuntimeError("a assinatura do FakeLibrary.install mudou; nada foi rodado")
        copia.gravar(rel, texto.replace(velho, "fake_playtimes: bool = false, fixed_ids: bool = true)"))
        # O script fica na raiz da cópia: o tools/jev/ tem .gdignore (a Godot não o lê).
        shutil.copy(GDSCRIPT, os.path.join(copia.pasta, "gerar_capturas.gd"))

        for rodada, horas, deslocar in rodadas:
            for variante in variantes:
                pasta = os.path.join(brutas, "%s_%s" % (rodada, variante))
                os.makedirs(pasta, exist_ok=True)
                cmd = [godot, "--path", copia.pasta, "-s", "res://gerar_capturas.gd", "--",
                       pasta.replace("\\", "/"), "200", "rpg", horas, "alta", variante]
                if deslocar:
                    cmd.append("deslocar")
                r = comum.rodar(cmd, 600, copia.pasta)
                geo_arq = os.path.join(pasta, "geometria.json")
                pngs = sorted(f for f in os.listdir(pasta) if f.endswith(".png"))
                print("  %-7s %-16s saída %s, %d capturas" % (rodada, variante, r["saida"], len(pngs)), flush=True)
                # O que o script disse sobre a variante (para saber se ela pegou de verdade).
                for linha in r["log"].splitlines():
                    if any(k in linha for k in ("pinheiros escondidos", "exposição", "ERROR", "Nenhum", "Sem ")):
                        print("    | " + linha.strip()[:160])
                if r["saida"] not in SAIDAS_ACEITAS or not os.path.isfile(geo_arq) or not pngs:
                    print("    PROBLEMA: veja o log abaixo (últimas linhas)")
                    print("\n".join("    " + l for l in r["log"].splitlines()[-15:]))
                    continue
                with open(geo_arq, encoding="utf-8") as f:
                    geo = json.load(f)
                for png in pngs:  # rpg_<ponto>_<hh>h.png
                    _, ponto, hh = png[:-4].split("_", 2)
                    hora = int(hh.rstrip("h"))
                    noite = float(geo["noite"][str(hora)] if str(hora) in geo["noite"] else geo["noite"]["%d" % hora])
                    caso_id = "%s_%02dh_%s%s" % (ponto, hora, variante, "_d" if deslocar else "")
                    arquivo = caso_id + ".png"
                    pares.append("%s|%s" % (os.path.join(pasta, png).replace("\\", "/"),
                                            os.path.join(a.saida, arquivo).replace("\\", "/")))
                    g = geo["pontos"].get(ponto, {"torre_na_tela": False, "torre_altura_px": 0.0,
                                                  "torre_desobstruida": False})
                    casos.append({"id": caso_id, "arquivo": arquivo, "ponto": ponto, "hora": hora,
                                  "variante": variante, "parte": parte_de(rodada, ponto), "sem_capas": True,
                                  "rotulos": rotulos(variante, noite, g), "geometria": g})

        # Reduz tudo de uma vez (sem janela).
        lista = os.path.join(copia.pasta, "reduzir.txt")
        # newline="": no Windows, o modo texto troca \n por \r\n, e o \r grudava no caminho.
        with open(lista, "w", encoding="utf-8", newline="") as f:
            f.write("\n".join(pares))
        with open(os.path.join(copia.pasta, "reduzir.gd"), "w", encoding="utf-8") as f:
            f.write(REDUZIR_GD)
        r = comum.rodar([godot, "--headless", "--path", copia.pasta, "-s", "res://reduzir.gd", "--",
                         lista.replace("\\", "/")], 600, copia.pasta)
        print("  " + " ".join(l for l in r["log"].splitlines() if "REDUZIDAS" in l))
    finally:
        copia.apagar()

    faltam = [c["id"] for c in casos if not os.path.isfile(os.path.join(a.saida, c["arquivo"]))]
    if faltam:
        print("PROBLEMA: capturas reduzidas faltando: %s" % faltam[:5])
        return 1
    with open(os.path.join(a.saida, "capturas.jsonl"), "w", encoding="utf-8") as f:
        for c in casos:
            f.write(json.dumps(c, ensure_ascii=False) + "\n")
    shutil.rmtree(brutas, ignore_errors=True)
    contagem = {}
    for c in casos:
        for conf, valor in c["rotulos"].items():
            chave = "%s/%s/%s" % (c["parte"], conf, {True: "sim", False: "não", None: "fora"}[valor])
            contagem[chave] = contagem.get(chave, 0) + 1
    print("== %d capturas em %s (%.1f min) ==" % (len(casos), a.saida, (time.time() - t0) / 60))
    for k in sorted(contagem):
        print("   %-34s %d" % (k, contagem[k]))
    if antes is not None:
        print("config.cfg real com a mesma data: %s" % (os.path.getmtime(real) == antes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
