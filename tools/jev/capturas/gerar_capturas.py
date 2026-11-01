"""Spike do Jev nas capturas (C.2): gera o gabarito de capturas com defeito conhecido.

Para cada variante (normal, torre escondida, pinheiro preto, neve estourada, tela
quase preta), roda o gerar_capturas.gd numa cópia descartável do projeto:
  - a pasta de dados (user://) é própria da cópia (provocar_falhas.Copia, J.2.1);
  - a biblioteca falsa usa IDs inventados (fixed_ids): nenhuma capa de jogo real;
  - nada muda no repositório, e a cópia é apagada no fim.

Depois reduz cada PNG para 1280x720 (o limite do Jev é 1568 px por lado) e grava
<saida>/capturas.jsonl no formato do contrato (docs/plans/ferramenta-jev-capturas.md).

  python tools/jev/capturas/gerar_capturas.py --saida PASTA_NOVA
Enquanto roda, não abra a Godot nem rode a bateria em outra janela.

A pasta é obrigatória e precisa ser nova (ou vazia): o gerador nunca sobrescreve um gabarito
(o do spike fica em C:\\Ferramentas\\jev\\capturas\\gabarito). Se qualquer rodada falhar (a
variante não pegou, faltou captura), o capturas.jsonl não é gravado.
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
BAIRRO = "rpg"  # o capturar_pontos.gd grava <bairro>_<ponto>_<hh>h.png


def preparar_saida(saida: str) -> str:
    """A pasta de saída como caminho absoluto (a Godot roda em outra pasta, a da cópia: um
    caminho relativo iria parar lá). Recusa a pasta dentro do repositório e qualquer pasta
    que já tenha algo dentro: o gerador nunca mexe num gabarito que já existe, então uma
    rodada que falha não tem o que estragar (C.2.2)."""
    saida = os.path.abspath(saida)
    projeto = os.path.abspath(comum.PROJETO)
    try:
        dentro = os.path.normcase(os.path.commonpath([saida, projeto])) == os.path.normcase(projeto)
    except ValueError:
        dentro = False  # outro disco (Windows): não está dentro
    if dentro:
        raise ValueError("o gabarito não pode ficar dentro do repositório.")
    if os.path.exists(saida) and (not os.path.isdir(saida) or os.listdir(saida)):
        raise ValueError("%s já existe e não está vazia: use uma pasta nova (o gerador nunca "
                         "sobrescreve um gabarito)." % saida)
    return saida


def checar_rodada(saida_godot: int, geo, pngs: list, horas: str) -> str:
    """Por que a rodada não vale ("" = vale). A Godot às vezes cai ao fechar (0xC0000005),
    então o código de saída não basta: confere a variante aplicada e TODAS as capturas
    esperadas (cada ponto da geometria em cada hora pedida)."""
    if saida_godot not in SAIDAS_ACEITAS:
        return "a Godot saiu com %s" % saida_godot
    if geo is None:
        return "sem geometria.json"
    if geo.get("variante_aplicada") is not True:
        # Sem o defeito na cena, o rótulo (que vem do nome da variante) seria falso.
        return "a variante não foi aplicada na cena"
    esperadas = {"%s_%s_%02dh.png" % (BAIRRO, ponto, int(h))
                 for ponto in geo.get("pontos", {}) for h in horas.split(",")}
    if not esperadas:
        return "nenhum ponto na geometria"
    faltam = sorted(esperadas - set(pngs))
    if faltam:
        return "capturas faltando: %s" % faltam[:5]
    return ""


def problemas_para_publicar(falhas: list, casos: list, saida: str) -> list:
    """O que impede gravar o capturas.jsonl. Vazio = pode publicar."""
    problemas = ["rodada com problema: %s" % f for f in falhas]
    if not casos:
        problemas.append("nenhuma captura gerada")
    faltam = [c["id"] for c in casos if not os.path.isfile(os.path.join(saida, c["arquivo"]))]
    if faltam:
        problemas.append("capturas reduzidas faltando: %s" % faltam[:5])
    return problemas


def gravar_manifesto(saida: str, casos: list) -> None:
    """Grava o capturas.jsonl de uma vez (arquivo temporário e troca): nunca fica pela metade."""
    final = os.path.join(saida, "capturas.jsonl")
    with open(final + ".tmp", "w", encoding="utf-8") as f:
        for c in casos:
            f.write(json.dumps(c, ensure_ascii=False) + "\n")
    os.replace(final + ".tmp", final)


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
    p.add_argument("--saida", required=True, help="pasta nova (ou vazia), fora do repositório")
    p.add_argument("--base", default="HEAD")
    p.add_argument("--variantes", default=",".join(VARIANTES), help="só estas (teste rápido)")
    p.add_argument("--rodadas", default="ajuste,portao", help="só estas (teste rápido)")
    a = p.parse_args()
    variantes = [v for v in a.variantes.split(",") if v in VARIANTES]
    rodadas = [r for r in RODADAS if r[0] in a.rodadas.split(",")]
    try:
        a.saida = preparar_saida(a.saida)
    except ValueError as e:
        print(e)
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
    casos, pares, falhas = [], [], []
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
                       pasta.replace("\\", "/"), "200", BAIRRO, horas, "alta", variante]
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
                geo = None
                if os.path.isfile(geo_arq):
                    with open(geo_arq, encoding="utf-8") as f:
                        geo = json.load(f)
                motivo = checar_rodada(r["saida"], geo, pngs, horas)
                if motivo:
                    print("    PROBLEMA: %s. Últimas linhas do log:" % motivo)
                    print("\n".join("    " + l for l in r["log"].splitlines()[-15:]))
                    falhas.append("%s/%s: %s" % (rodada, variante, motivo))
                    continue
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

        # Reduz tudo de uma vez (sem janela). Com rodada ruim, nem reduz: não vai publicar.
        if not falhas:
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

    problemas = problemas_para_publicar(falhas, casos, a.saida)
    if problemas:
        for pr in problemas:
            print("PROBLEMA: %s" % pr)
        print("o capturas.jsonl NÃO foi gravado (a pasta nova fica sem gabarito; apague-a).")
        return 1
    gravar_manifesto(a.saida, casos)
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
