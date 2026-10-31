"""C.3 - O portão do Jev nas capturas: o Jev contra uma "régua de código" (medidas de pixels e
de geometria), em cada conferência, num gabarito de capturas com defeito conhecido.

O que faz:
1. Lê o gabarito (capturas.jsonl, ao lado dos PNG). Rótulo `null` = a captura fica fora
   daquela conferência.
2. Mede os limiares SÓ na parte "ajuste" (a régua e o Jev).
3. Dá a nota SÓ na parte "portao", que não ajustou nada: régua, Jev e a concordância dos dois.
4. Veredito por conferência: o Jev só fica onde acerta >= 90%, vence a régua por >= 10 pontos e
   nenhuma classe (sim ou não) zera. No resto, a régua de código basta.

Arquivos de cache, na pasta do gabarito:
- medidas.jsonl       {"id", "arquivo", "tamanho", "medidas": {...}}  (medidas de pixels do PNG)
- respostas_jev.jsonl {"id", "assinatura", "p": {conferencia: probabilidade_de_sim}}
  Rodar de novo não paga de novo: a assinatura é a do pedido inteiro (imagem e perguntas).

Uso:
  python tools/jev/capturas/avaliar_capturas.py --gabarito PASTA [--sem-enviar] [--so-ajuste]
                                                [--descricao-torre TEXTO]
"""
import argparse
import json
import os
import sys

# Para achar `jev`, `avaliar` e `comum` (uma pasta acima) e os módulos desta pasta.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import avaliar  # noqa: E402
import jev  # noqa: E402
import perguntas_capturas as pc  # noqa: E402

TETO_US = 0.50                              # teto de custo do Jev no spike (US$)
CANDIDATOS_JEV = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
LIMIAR_JEV_PADRAO = 0.7                     # empate de limiar do Jev: o mais perto deste
META_ACERTO = 0.90                          # o Jev precisa acertar pelo menos isto
META_VANTAGEM = 0.10                        # e vencer a régua por pelo menos isto
EPS = 1e-9                                  # tolerância das contas com decimais
TOKENS_IMAGEM = 2700                        # uma captura 1280x720 (medido na C.1: ~2.844 com 3 perguntas)
PARTES = ("ajuste", "portao")
CLASSES = [True, False]


# ---------------------------------------------------------------- gabarito

def ler_gabarito(pasta: str, partes: tuple = PARTES) -> list:
    """As linhas do capturas.jsonl. `partes` filtra já na leitura: com ("ajuste",) o portão
    nem entra na memória (o modo --so-ajuste nunca o lê)."""
    with open(os.path.join(pasta, "capturas.jsonl"), encoding="utf-8") as f:
        casos = [json.loads(l) for l in f if l.strip()]
    return [c for c in casos if c.get("parte") in partes]


# ---------------------------------------------------------------- medidas de pixels (cache)

def _medir_png(caminho: str) -> dict:
    """A régua de pixels (a do Worker A). Importada só aqui, para o resto não depender dela."""
    import regua_pixels
    return regua_pixels.medir(caminho)


def carregar_medidas(casos: list, pasta: str, medir=None) -> dict:
    """{id: medidas}. Mede os PNG que ainda não estão em medidas.jsonl (ou que mudaram de tamanho)."""
    arq = os.path.join(pasta, "medidas.jsonl")
    cache = {}
    if os.path.isfile(arq):
        with open(arq, encoding="utf-8") as f:
            for l in f:
                if l.strip():
                    r = json.loads(l)
                    cache[r["id"]] = r  # a linha mais nova vence
    medir = medir or _medir_png
    resultado, novas = {}, []
    for c in casos:
        caminho = os.path.join(pasta, c["arquivo"])
        tamanho = os.path.getsize(caminho)
        r = cache.get(c["id"])
        if r and r.get("arquivo") == c["arquivo"] and r.get("tamanho") == tamanho:
            resultado[c["id"]] = r["medidas"]
            continue
        m = medir(caminho)
        resultado[c["id"]] = m
        novas.append({"id": c["id"], "arquivo": c["arquivo"], "tamanho": tamanho, "medidas": m})
    if novas:
        with open(arq, "a", encoding="utf-8") as f:
            for r in novas:
                f.write(json.dumps(r) + "\n")
    return resultado


# ---------------------------------------------------------------- a régua de código

def valor_regua(conferencia: str, medidas: dict, geometria: dict) -> float:
    """O número que a régua compara com o limiar (sempre "maior = mais sim", menos na tela preta).

    Na torre, sem estar na tela ou com algo na frente, o valor é -infinito: nunca passa."""
    if conferencia == "dia":
        return medidas["brilho_ceu"]
    if conferencia == "tela_preta":
        return medidas["brilho_medio"]
    if conferencia == "neve_estourada":
        # O brilho médio, e não a fração >= 0,98: o tonemap da Godot quase nunca chega a
        # 0,98, e no ajuste essa fração deu 0 até nas capturas estouradas (régua quebrada).
        return medidas["brilho_medio"]
    if conferencia == "sem_pinheiros":
        # Sem pinheiros, o chão de neve tem menos manchas escuras. A régua não sabe onde
        # estão os pinheiros: rochas e sombras também contam.
        return medidas["fracao_escura_baixo"]
    if conferencia == "torre_visivel":
        g = geometria or {}
        if g.get("torre_na_tela") and g.get("torre_desobstruida"):
            return float(g.get("torre_altura_px", 0.0))
        return float("-inf")
    raise ValueError("conferência desconhecida: %r" % conferencia)


def decide_regua(conferencia: str, medidas: dict, geometria: dict, limiar: float) -> bool:
    """O "sim" da régua. Na tela preta e nos pinheiros sumidos o "sim" é o valor BAIXO
    ("menor ou igual"); nas outras, o alto ("maior ou igual")."""
    valor = valor_regua(conferencia, medidas, geometria)
    if conferencia in MENOR_E_SIM:
        return valor <= limiar
    return valor >= limiar


# As conferências em que um valor baixo da régua quer dizer "sim".
MENOR_E_SIM = {"tela_preta", "sem_pinheiros"}


def _meio(lista: list):
    """O elemento do meio de uma lista (a lista é ordenada antes; com tamanho par, o de baixo)."""
    ordenada = sorted(lista)
    return ordenada[(len(ordenada) - 1) // 2]


def candidatos_regua(conferencia: str, amostras: list) -> list:
    """Os limiares a testar: os valores vistos no ajuste, os pontos médios entre eles e um
    ponto um pouco além de cada ponta (para a régua poder dizer "tudo sim" ou "tudo não")."""
    valores = sorted({valor_regua(conferencia, a["medidas"], a["geometria"]) for a in amostras})
    valores = [v for v in valores if v != float("-inf")]
    if not valores:
        return [0.0]
    cands = set(valores)
    for x, y in zip(valores, valores[1:]):
        cands.add((x + y) / 2)
    cands.add(valores[0] - 1e-6)
    cands.add(valores[-1] + 1e-6)
    return sorted(cands)


def medir_limiar_regua(conferencia: str, amostras: list) -> float:
    """O limiar da régua com o maior acerto balanceado no ajuste (empate: o do meio)."""
    notas = {}
    for t in candidatos_regua(conferencia, amostras):
        pares = [(a["certo"], decide_regua(conferencia, a["medidas"], a["geometria"], t)) for a in amostras]
        notas[t] = round(avaliar.acerto_balanceado(pares, CLASSES)[0], 9)
    melhor = max(notas.values())
    return _meio([t for t, n in notas.items() if n == melhor])


def medir_limiar_jev(amostras: list) -> float:
    """O limiar do "sim" do Jev no ajuste (empate: o mais perto de 0,7; sobrando empate, o menor)."""
    melhor = None
    for t in CANDIDATOS_JEV:
        pares = [(a["certo"], a["p"] >= t) for a in amostras]
        nota = round(avaliar.acerto_balanceado(pares, CLASSES)[0], 9)
        chave = (nota, -round(abs(t - LIMIAR_JEV_PADRAO), 9))
        if melhor is None or chave > melhor[0]:
            melhor = (chave, t)
    return melhor[1]


# ---------------------------------------------------------------- notas e veredito

def montar_amostras(conferencia: str, casos: list, medidas: dict, respostas) -> list:
    """Uma amostra por captura que TEM rótulo (não-null) nesta conferência.
    `respostas` = {id: {conferencia: p}} ou None (sem Jev). `p` fica None se faltar."""
    amostras = []
    for c in casos:
        certo = (c.get("rotulos") or {}).get(conferencia)
        if certo is None:
            continue  # "não dá para julgar": fica fora
        p = None
        if respostas is not None:
            p = (respostas.get(c["id"]) or {}).get(conferencia)
        amostras.append({"id": c["id"], "certo": bool(certo), "medidas": medidas[c["id"]],
                         "geometria": c.get("geometria") or {}, "p": p})
    return amostras


def previsoes(conferencia: str, amostras: list, lim_regua: float, lim_jev) -> list:
    """Para cada amostra: (régua diz sim?, Jev diz sim? ou None sem Jev)."""
    saida = []
    for a in amostras:
        r = decide_regua(conferencia, a["medidas"], a["geometria"], lim_regua)
        j = (a["p"] >= lim_jev) if (lim_jev is not None and a["p"] is not None) else None
        saida.append((r, j))
    return saida


def _nota_de(pares: list) -> dict:
    acerto, por_classe = avaliar.acerto_balanceado(pares, CLASSES)
    return {"acerto": acerto, "por_classe": por_classe}


def calcular_nota(conferencia: str, amostras: list, lim_regua: float, lim_jev) -> dict:
    """As notas de uma conferência sobre `amostras`: régua, Jev (se houver) e concordância."""
    prev = previsoes(conferencia, amostras, lim_regua, lim_jev)
    nota = {"n": len(amostras), "regua": _nota_de([(a["certo"], r) for a, (r, _) in zip(amostras, prev)]),
            "jev": None, "concordancia": None}
    if lim_jev is not None and all(j is not None for _, j in prev) and prev:
        nota["jev"] = _nota_de([(a["certo"], j) for a, (_, j) in zip(amostras, prev)])
        juntos = [(a, r) for a, (r, j) in zip(amostras, prev) if r == j]
        nota["concordancia"] = {
            "n": len(juntos),
            "fracao": len(juntos) / len(prev),
            # Quando os dois concordam, o palpite é o mesmo; o acerto é o de um deles.
            "acerto": (sum(1 for a, r in juntos if r == a["certo"]) / len(juntos)) if juntos else None,
        }
    return nota


def decidir_veredito(nota: dict) -> tuple:
    """(veredito, motivo). "JEV" só com as três condições; no resto, "RÉGUA", com o motivo."""
    if nota is None or nota["jev"] is None:
        return None, "sem respostas do Jev"
    regua, jev_ = nota["regua"]["acerto"], nota["jev"]["acerto"]
    por_classe = nota["jev"]["por_classe"]
    problemas = []
    if jev_ < META_ACERTO - EPS:
        problemas.append("o Jev acerta %.0f%%, abaixo de %.0f%%" % (jev_ * 100, META_ACERTO * 100))
    if jev_ - regua < META_VANTAGEM - EPS:
        problemas.append("o Jev vence a régua por só %.0f pontos (precisa de %.0f)"
                         % ((jev_ - regua) * 100, META_VANTAGEM * 100))
    colapsadas = ["sim" if c else "não" for c, v in por_classe.items() if v == 0]
    if colapsadas:
        problemas.append("classe colapsada (acerto 0): %s" % ", ".join(colapsadas))
    if len(por_classe) < 2:
        problemas.append("o portão não tem exemplos de sim e de não: não dá para provar que "
                         "nenhuma classe colapsa")
    if not problemas:
        return "JEV", ("o Jev acerta %.0f%%, vence a régua (%.0f%%) por %.0f pontos e nenhuma classe zera"
                       % (jev_ * 100, regua * 100, (jev_ - regua) * 100))
    if regua >= META_ACERTO - EPS:
        problemas.insert(0, "a régua já acerta %.0f%%: não precisa do Jev" % (regua * 100))
    return "RÉGUA", "; ".join(problemas)


def rodar_avaliacao(ajuste: list, portao: list, medidas: dict, respostas, conferencias: list) -> dict:
    """O coração: limiares medidos no `ajuste`, notas e veredito no `portao`.
    Devolve {conferencia: {...}}. `respostas=None` avalia só a régua."""
    saida = {}
    for conf in conferencias:
        a_ajuste = montar_amostras(conf, ajuste, medidas, respostas)
        a_portao = montar_amostras(conf, portao, medidas, respostas)
        r = {"conferencia": conf, "n_ajuste": len(a_ajuste), "n_portao": len(a_portao),
             "lim_regua": None, "lim_jev": None, "nota": None, "veredito": None,
             "motivo": "", "amostras_ajuste": a_ajuste, "amostras_portao": a_portao}
        saida[conf] = r
        if not a_ajuste:
            r["motivo"] = "nenhuma captura rotulada no ajuste: sem como medir o limiar"
            continue
        r["lim_regua"] = medir_limiar_regua(conf, a_ajuste)
        if respostas is not None and all(x["p"] is not None for x in a_ajuste + a_portao):
            r["lim_jev"] = medir_limiar_jev(a_ajuste)
        if not a_portao:
            r["motivo"] = "nenhuma captura rotulada no portão"
            continue
        r["nota"] = calcular_nota(conf, a_portao, r["lim_regua"], r["lim_jev"])
        r["veredito"], r["motivo"] = decidir_veredito(r["nota"])
    return saida


def listar_erros(conferencia: str, amostras: list, lim_regua: float, lim_jev) -> list:
    """As linhas de cada erro (régua ou Jev), com os números. Para o modo --so-ajuste."""
    linhas = []
    for a, (r, j) in zip(amostras, previsoes(conferencia, amostras, lim_regua, lim_jev)):
        erros = []
        if r != a["certo"]:
            erros.append("régua %s (valor %.4g)" % (_sn(r), valor_regua(conferencia, a["medidas"], a["geometria"])))
        if j is not None and j != a["certo"]:
            erros.append("Jev %s (p = %.2f)" % (_sn(j), a["p"]))
        if erros:
            linhas.append("   errou: %s (certo %s): %s" % (a["id"], _sn(a["certo"]), "; ".join(erros)))
    return linhas


def _sn(valor: bool) -> str:
    return "sim" if valor else "não"


# ---------------------------------------------------------------- o Jev (pedidos, cache, teto)

def estimar_tokens(corpo: dict) -> float:
    """Uma estimativa grosseira: a imagem (medida na C.1) mais o texto, ~4 caracteres por token."""
    return TOKENS_IMAGEM + len(pc.texto_do_pedido(corpo)) / 4


def separar_guardadas(pedidos: dict, pasta: str) -> tuple:
    """(respostas já guardadas {id: p}, ids que faltam perguntar). A chave é id + assinatura."""
    arq = os.path.join(pasta, "respostas_jev.jsonl")
    guardadas = {}
    if os.path.isfile(arq):
        with open(arq, encoding="utf-8") as f:
            for l in f:
                if l.strip():
                    r = json.loads(l)
                    guardadas[(r["id"], r["assinatura"])] = r["p"]
    respostas, faltam = {}, []
    for id_, corpo in pedidos.items():
        chave = (id_, avaliar.assinatura(corpo))
        if chave in guardadas:
            respostas[id_] = guardadas[chave]
        else:
            faltam.append(id_)
    return respostas, faltam


def obter_respostas_jev(pedidos: dict, pasta: str, criar_cliente=None) -> tuple:
    """(respostas {id: {conferencia: p}}, cliente ou None, erro ou None).

    Só pergunta o que não está guardado. Erro do Jev (ou teto de custo) PARA tudo: o que já
    foi respondido fica guardado, e um erro nunca vira resposta."""
    respostas, faltam = separar_guardadas(pedidos, pasta)
    if not faltam:
        return respostas, None, None
    try:
        cliente = (criar_cliente or jev.Cliente)()
    except jev.ErroJev as e:
        return respostas, None, str(e)
    arq = os.path.join(pasta, "respostas_jev.jsonl")
    for id_ in faltam:
        if cliente.custo() > TETO_US:
            return respostas, cliente, ("teto de custo: já gastou US$ %.4f, mais que o limite de "
                                        "US$ %.2f. Parado antes da captura %s." % (cliente.custo(), TETO_US, id_))
        corpo = pedidos[id_]
        try:
            resposta = cliente.enviar(corpo)
            p = {qid: jev.noul(resposta, qid) for qid in corpo["questions"]}
        except jev.ErroJev as e:
            return respostas, cliente, "%s. Parado na captura %s." % (e, id_)
        except (KeyError, TypeError, ValueError):
            return respostas, cliente, "resposta do Jev fora do formato esperado. Parado na captura %s." % id_
        respostas[id_] = p
        with open(arq, "a", encoding="utf-8") as f:
            f.write(json.dumps({"id": id_, "assinatura": avaliar.assinatura(corpo), "p": p}) + "\n")
    return respostas, cliente, None


# ---------------------------------------------------------------- relatório

def _pct(v) -> str:
    return "  -- " if v is None else "%4.0f%%" % (v * 100)


def _classes(nota_de: dict) -> str:
    pc_ = nota_de["por_classe"]
    return "sim %s / não %s" % (_pct(pc_.get(True)).strip(), _pct(pc_.get(False)).strip())


def imprimir_conferencia(r: dict, so_ajuste: bool) -> None:
    print("\n-- %s (ajuste: %d capturas, %s: %d)" % (
        r["conferencia"], r["n_ajuste"], "ajuste" if so_ajuste else "portão", r["n_portao"]))
    if r["nota"] is None:
        print("   %s" % r["motivo"])
        return
    lim = "limiar da régua %.4g" % r["lim_regua"]
    if r["lim_jev"] is not None:
        lim += ", limiar do Jev %.2f" % r["lim_jev"]
    print("   %s (medidos no ajuste)" % lim)
    n = r["nota"]
    print("   régua: %s balanceado (%s)" % (_pct(n["regua"]["acerto"]).strip(), _classes(n["regua"])))
    if n["jev"] is not None:
        print("   Jev:   %s balanceado (%s)" % (_pct(n["jev"]["acerto"]).strip(), _classes(n["jev"])))
        c = n["concordancia"]
        print("   concordam em %s das capturas; nelas o acerto é %s"
              % (_pct(c["fracao"]).strip(), _pct(c["acerto"]).strip()))
    if so_ajuste:
        print("   (modo --so-ajuste: isto é desenvolvimento, não é o portão)")
    elif r["veredito"]:
        print("   VEREDITO: %s - %s" % (r["veredito"], r["motivo"]))


def imprimir_custo(cliente) -> None:
    if cliente is not None:
        print("\n%s" % cliente.relatorio())
    else:
        print("\nJev: 0 chamadas nesta rodada")


# ---------------------------------------------------------------- linha de comando

def main(argv=None, criar_cliente=None, medir=None) -> int:
    """`criar_cliente` e `medir` existem para os testes injetarem um Jev falso e medidas prontas."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="O portão do Jev nas capturas (C.3).")
    p.add_argument("--gabarito", required=True, help="pasta com capturas.jsonl e os PNG")
    p.add_argument("--sem-enviar", action="store_true", help="só a régua e a estimativa de custo")
    p.add_argument("--so-ajuste", action="store_true",
                   help="desenvolvimento: usa só o ajuste e mostra cada erro; nunca lê o portão")
    p.add_argument("--descricao-torre", default="",
                   help="a aparência da torre, para a pergunta torre_visivel (sem isto ela não é feita)")
    a = p.parse_args(argv)

    cliente = None
    try:
        partes = ("ajuste",) if a.so_ajuste else PARTES
        casos = ler_gabarito(a.gabarito, partes)
        for c in casos:
            pc.exigir_sem_capas(c)  # antes de qualquer envio
        ajuste = [c for c in casos if c["parte"] == "ajuste"]
        portao = ajuste if a.so_ajuste else [c for c in casos if c["parte"] == "portao"]
        print("gabarito: %d capturas (%d ajuste, %d portão%s)"
              % (len(casos), len(ajuste), 0 if a.so_ajuste else len(portao),
                 "; o portão não foi lido" if a.so_ajuste else ""))

        medidas = carregar_medidas(casos, a.gabarito, medir)
        pedidos = {c["id"]: pc.pedido_da_captura(c, a.gabarito, a.descricao_torre) for c in casos}
    except (ValueError, OSError, KeyError, jev.ErroJev, ImportError) as e:
        print("ERRO: %s" % e)
        imprimir_custo(None)
        return 2

    conferencias = list(pc.CONFERENCIAS)
    if not pc.descricao_valida(a.descricao_torre):
        print("torre_visivel: sem --descricao-torre, o Jev não é perguntado (só a régua)")

    respostas = None
    if a.sem_enviar:
        _, faltam = separar_guardadas(pedidos, a.gabarito)
        tokens = sum(estimar_tokens(pedidos[i]) for i in faltam)
        print("faltam %d pedidos ao Jev (~%.0f mil tokens, ~US$ %.4f; teto US$ %.2f)"
              % (len(faltam), tokens / 1000, tokens * jev.PRECO_POR_TOKEN, TETO_US))
    else:
        respostas, cliente, erro = obter_respostas_jev(pedidos, a.gabarito, criar_cliente)
        if erro:
            print("ERRO: %s" % erro)
            imprimir_custo(cliente)
            return 2

    resultado = rodar_avaliacao(ajuste, portao, medidas, respostas, conferencias)
    print("\n== %s ==" % ("AJUSTE (desenvolvimento)" if a.so_ajuste
                          else "PORTÃO (capturas que não ajustaram nada)"))
    for conf in conferencias:
        r = resultado[conf]
        imprimir_conferencia(r, a.so_ajuste)
        if a.so_ajuste and r["nota"] is not None:
            for linha in listar_erros(conf, r["amostras_portao"], r["lim_regua"], r["lim_jev"]):
                print(linha)
    imprimir_custo(cliente)
    return 0


if __name__ == "__main__":
    sys.exit(main())
