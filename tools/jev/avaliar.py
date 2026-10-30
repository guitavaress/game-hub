"""J.3 — O portão: a triagem com o Jev contra a base só com regras, no gabarito da J.2.

1. Pergunta ao Jev cada caso do gabarito (as respostas ficam guardadas em
   respostas_jev.jsonl, ao lado do gabarito: rodar de novo não paga de novo, a menos que
   o pedido mude).
2. Mede o limiar do "sim" na parte de AJUSTE.
3. Dá a nota na parte do PORTÃO, que não foi usada para ajustar nada.

Portão (docs/plans/ferramenta-jev.md): acerto balanceado ≥ 90%; vencer a base por ≥ 10
pontos; nenhuma categoria colapsada (acerto 0); limiar medido; custo registrado. Se a base
já passa de 90%, a conclusão é "não precisa do Jev".

Uso:
  python tools/jev/avaliar.py                 # gabarito na pasta padrão
  python tools/jev/avaliar.py --sem-enviar    # só a base e a estimativa de custo
"""
import argparse
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import jev  # noqa: E402
import perguntas  # noqa: E402
import provocar_falhas  # noqa: E402
import triar_falhas as tf  # noqa: E402

CANDIDATOS = [0.5, 0.6, 0.7, 0.8, 0.9, 0.95]
META_ACERTO = 0.90
META_VANTAGEM = 0.10


# Casos do 1º gabarito que não acontecem na bateria (ela importa o projeto antes, e a
# importação refaz o cache): ficam fora da conta.
FORA_DO_ESCOPO = {"ambiente_sem_classes", "ambiente_sem_importados", "ambiente_sem_uids"}


def ler_gabarito(pasta: str) -> list:
    with open(os.path.join(pasta, "falhas.jsonl"), encoding="utf-8") as f:
        casos = [json.loads(l) for l in f if l.strip()]
    return [c for c in casos if c["provocacao"] not in FORA_DO_ESCOPO]


def assinatura(corpo: dict) -> str:
    return hashlib.sha256(json.dumps(corpo, sort_keys=True).encode("utf-8")).hexdigest()[:16]


def acerto_balanceado(pares: list, categorias: list) -> tuple:
    """(média do acerto por categoria, {categoria: acerto}). pares = [(certo, previsto)]."""
    por_cat = {}
    for c in categorias:
        da_cat = [prev for certo, prev in pares if certo == c]
        if da_cat:
            por_cat[c] = sum(1 for prev in da_cat if prev == c) / len(da_cat)
    return (sum(por_cat.values()) / len(por_cat) if por_cat else 0.0), por_cat


def prever(casos, resp, limiar_cat, limiar_lig):
    """Para cada caso: (categoria base, categoria Jev, ligado base, ligado Jev)."""
    saida = []
    for c in casos:
        log = c["log_texto"]
        p = resp[c["id"]]
        base = tf.categoria_base(c, log)[0]
        com_jev = tf.categoria_com_jev(c, log, p, limiar_cat, 1 - limiar_cat)[0]  # faixa simétrica
        outros = perguntas.arquivos_para_o_jev(c)
        # "ligado" do gabarito: a falha tem ligação com o diff (algum arquivo).
        lig_base = bool(tf.ligados_ao_diff(c, log))
        lig_jev = bool(tf.ligados_com_jev(c, p, outros, limiar_lig))
        saida.append((c, base, com_jev, lig_base, lig_jev))
    return saida


def medir_limiar(casos, resp, qual: str) -> float:
    """O limiar com o maior acerto balanceado na parte de ajuste (empate: o mais perto de 0,7)."""
    melhor = None
    for t in CANDIDATOS:
        prev = prever(casos, resp, t, t)
        if qual == "categoria":
            nota = acerto_balanceado([(c["categoria"], j) for c, _, j, _, _ in prev], tf.CATEGORIAS)[0]
        else:
            nota = acerto_balanceado([(c["ligado_ao_diff"], lj) for c, _, _, _, lj in prev], [True, False])[0]
        chave = (nota, -abs(t - 0.7))
        if melhor is None or chave > melhor[0]:
            melhor = (chave, t)
    return melhor[1]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="O portão da triagem com o Jev (J.3).")
    p.add_argument("--gabarito", default=provocar_falhas.pasta_padrao())
    p.add_argument("--sem-enviar", action="store_true")
    p.add_argument("--so-ajuste", action="store_true",
                   help="desenvolvimento: usa só a parte de ajuste e mostra cada erro; nunca lê o portão")
    a = p.parse_args()

    casos = ler_gabarito(a.gabarito)
    ajuste = [c for c in casos if c["parte"] == "ajuste"]
    portao = [c for c in casos if c["parte"] == "portao"]
    if a.so_ajuste:
        casos, portao = ajuste, ajuste  # a "nota" sai do próprio ajuste: só para ler os erros
    print("gabarito: %d casos (%d ajuste, %d portão)" % (len(casos), len(ajuste), len(portao)))

    # 1. As respostas do Jev (guardadas).
    arq_resp = os.path.join(a.gabarito, "respostas_jev.jsonl")
    guardadas = {}
    if os.path.isfile(arq_resp):
        with open(arq_resp, encoding="utf-8") as f:
            for l in f:
                r = json.loads(l)
                guardadas[(r["id"], r["assinatura"])] = r["p"]
    pedidos = {c["id"]: jev.pedido(perguntas.estado(c, c["log_texto"]), perguntas.perguntas_do_caso(c))
               for c in casos}
    faltam = [c for c in casos if (c["id"], assinatura(pedidos[c["id"]])) not in guardadas]
    estimativa = sum(len(json.dumps(pedidos[c["id"]])) for c in faltam) / 4
    print("faltam %d pedidos ao Jev (~%.0f mil tokens, ~US$ %.4f)"
          % (len(faltam), estimativa / 1000, estimativa * jev.PRECO_POR_TOKEN))

    if a.sem_enviar:
        base = [(c["categoria"], tf.categoria_base(c, c["log_texto"])[0]) for c in portao]
        nota, por_cat = acerto_balanceado(base, tf.CATEGORIAS)
        print("base só com regras, no portão: acerto balanceado %.0f%%" % (nota * 100))
        for cat, v in por_cat.items():
            print("   %-15s %.0f%%" % (cat, v * 100))
        return 0

    cliente = None
    if faltam:
        try:
            cliente = jev.Cliente()
        except jev.ErroJev as e:
            print("ERRO: %s" % e)
            return 2
        with open(arq_resp, "a", encoding="utf-8") as f:
            for c in faltam:
                try:
                    resposta = cliente.enviar(pedidos[c["id"]])
                    pr = {qid: jev.noul(resposta, qid) for qid in resposta["answers"]}
                except jev.ErroJev as e:
                    print("ERRO: %s. Parado no caso %s." % (e, c["id"]))
                    print(cliente.relatorio())
                    return 2
                ass = assinatura(pedidos[c["id"]])
                guardadas[(c["id"], ass)] = pr
                f.write(json.dumps({"id": c["id"], "assinatura": ass, "p": pr}) + "\n")
    resp = {c["id"]: guardadas[(c["id"], assinatura(pedidos[c["id"]]))] for c in casos}

    # 2. Limiar medido no ajuste.
    lim_cat = medir_limiar(ajuste, resp, "categoria")
    lim_lig = medir_limiar(ajuste, resp, "ligado")
    print("\nlimiar medido no ajuste: categoria %.2f, ligação %.2f" % (lim_cat, lim_lig))

    # 3. Nota no portão.
    prev = prever(portao, resp, lim_cat, lim_lig)
    nota_base, cat_base = acerto_balanceado([(c["categoria"], b) for c, b, _, _, _ in prev], tf.CATEGORIAS)
    nota_jev, cat_jev = acerto_balanceado([(c["categoria"], j) for c, _, j, _, _ in prev], tf.CATEGORIAS)
    lig_base = acerto_balanceado([(c["ligado_ao_diff"], lb) for c, _, _, lb, _ in prev], [True, False])[0]
    lig_jev = acerto_balanceado([(c["ligado_ao_diff"], lj) for c, _, _, _, lj in prev], [True, False])[0]
    indefinidos = sum(1 for _, _, j, _, _ in prev if j == "indefinido")

    nota_regras, cat_regras = acerto_balanceado(
        [(c["categoria"], tf.categoria_regras(c, c["log_texto"])[0]) for c in portao], tf.CATEGORIAS)

    print("\n== PORTÃO (%d casos que não ajustaram nada) ==" % len(portao))
    print("categoria, acerto balanceado: base do plano %.0f%%  |  com o Jev %.0f%%  |  regras finais %.0f%%"
          % (nota_base * 100, nota_jev * 100, nota_regras * 100))
    for cat in tf.CATEGORIAS:
        if cat in cat_jev:
            print("   %-15s base %4.0f%%   Jev %4.0f%%   regras %4.0f%%"
                  % (cat, cat_base[cat] * 100, cat_jev[cat] * 100, cat_regras[cat] * 100))
    print("indefinidos (o Jev não decidiu): %d" % indefinidos)
    print("ligação com o diff, acerto balanceado: base %.0f%%  |  com o Jev %.0f%%" % (lig_base * 100, lig_jev * 100))
    erros = [(c["id"], c["categoria"], j) for c, _, j, _, _ in prev if j != c["categoria"]]
    for e in erros:
        print("   errou: %s (certo %s, deu %s)" % e)
        if a.so_ajuste:
            print("      p = %s" % {k: round(v, 2) for k, v in resp[e[0]].items()})
    if a.so_ajuste:
        erros_lig = [(c["id"], c["ligado_ao_diff"]) for c, _, _, _, lj in prev if lj != c["ligado_ao_diff"]]
        for i, certo in erros_lig:
            print("   ligação errada: %s (certo %s) p = %s" % (
                i, certo, {k: round(v, 2) for k, v in resp[i].items() if k.startswith("ligado")}))
        print("\n(modo --so-ajuste: isto é desenvolvimento, não é o portão)")

    colapsou = [cat for cat, v in cat_jev.items() if v == 0]
    if nota_base >= META_ACERTO:
        veredito = "NÃO PRECISA DO JEV: só as regras já passam de %.0f%%" % (META_ACERTO * 100)
    elif nota_jev >= META_ACERTO and nota_jev - nota_base >= META_VANTAGEM and not colapsou:
        veredito = "PASSOU"
    else:
        motivos = []
        if nota_jev < META_ACERTO:
            motivos.append("acerto abaixo de %.0f%%" % (META_ACERTO * 100))
        if nota_jev - nota_base < META_VANTAGEM:
            motivos.append("vantagem sobre a base menor que %.0f pontos" % (META_VANTAGEM * 100))
        if colapsou:
            motivos.append("categoria colapsada: %s" % ", ".join(colapsou))
        veredito = "NÃO PASSOU (%s)" % "; ".join(motivos)
    print("\nVEREDITO do Jev contra a base do plano: %s" % veredito)
    if nota_regras >= nota_jev:
        print("MAS as regras finais (só código) fazem %.0f%%, contra %.0f%% do Jev: a triagem "
              "usa só as regras." % (nota_regras * 100, nota_jev * 100))

    tokens_por = (cliente.tokens / cliente.chamadas) if cliente and cliente.chamadas else 0
    if cliente:
        print("\n%s (média de %.0f tokens, US$ %.6f por triagem)"
              % (cliente.relatorio(), tokens_por, tokens_por * jev.PRECO_POR_TOKEN))
    else:
        print("\nJev: 0 chamadas nesta rodada (todas as respostas já estavam guardadas)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
