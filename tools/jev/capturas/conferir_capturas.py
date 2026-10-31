"""C.4 - Confere uma pasta de capturas e aponta quais olhar primeiro.

Cada conferência usa quem passou no portão da C.3 (docs/design/jev-capturas-spike-2026-10-31.md):
- dia/noite e neve estourada: a régua de código (pixels), sem custo;
- sem pinheiros: o Jev (só com --jev e só em capturas de dia, onde ele foi medido);
- torre: a geometria que o gerador grava (projeção e linha de visão), quando houver.

A aprovação visual continua sendo do dono: a tabela só diz por onde começar.

O Jev só recebe capturas SEM capas de jogo: as de uma pasta com capturas.jsonl em que toda
linha diz `sem_capas: true` (o gerar_capturas.py grava isso: biblioteca falsa com `fixed_ids`,
numa cópia descartável). Pasta sem esse arquivo: só a régua de código.

Uso:
  python tools/jev/capturas/gerar_capturas.py --saida PASTA --variantes normal --rodadas ajuste
  python tools/jev/capturas/conferir_capturas.py PASTA [--jev]

Saída: 0 = nada a olhar; 1 = alguma captura com aviso; 2 = erro.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import avaliar_capturas as ac  # noqa: E402
import jev  # noqa: E402
import perguntas_capturas as pc  # noqa: E402

# Os limiares medidos SÓ no ajuste da C.3 (30 capturas) e conferidos no portão (50 outras).
# Mudar qualquer um pede medir de novo (avaliar_capturas.py), nunca acertar "no olho".
DIA_QUASE_PRETO_MAX = 0.0       # de dia, nenhum pixel quase preto (portão: 92%; frágil, veja o doc)
NEVE_BRILHO_MEDIO_MIN = 0.7261  # neve estourada: brilho médio a partir disto (portão: 100%)
JEV_SEM_PINHEIROS_MIN = 0.70    # o "sim" do Jev para "sem pinheiros" (portão: 100%)
TORRE_CLARA_PX = 20.0           # a mesma altura mínima do gabarito (gerar_capturas.py)


def ler_casos(pasta: str) -> tuple:
    """(casos, tem_manifesto). Com capturas.jsonl, as linhas dele; sem, um caso por PNG,
    sem rótulos, sem geometria e sem a garantia de não ter capas."""
    arq = os.path.join(pasta, "capturas.jsonl")
    if os.path.isfile(arq):
        with open(arq, encoding="utf-8") as f:
            return [json.loads(l) for l in f if l.strip()], True
    pngs = sorted(f for f in os.listdir(pasta) if f.lower().endswith(".png"))
    return [{"id": f[:-4], "arquivo": f} for f in pngs], False


def parece_dia(medidas: dict) -> bool:
    return medidas["fracao_quase_preto"] <= DIA_QUASE_PRETO_MAX


def neve_estourada(medidas: dict) -> bool:
    return medidas["brilho_medio"] >= NEVE_BRILHO_MEDIO_MIN


def torre_visivel(geometria: dict):
    """True/False pela geometria; None quando a captura não tem geometria da torre."""
    if not geometria or "torre_na_tela" not in geometria:
        return None
    return bool(geometria["torre_na_tela"] and geometria.get("torre_desobstruida")
                and geometria.get("torre_altura_px", 0.0) >= TORRE_CLARA_PX)


def conferir(caso: dict, medidas: dict, p_jev) -> dict:
    """As respostas de uma captura e os avisos. `p_jev` = {conferencia: p} ou None (sem Jev).

    Com rótulos (o que a captura deveria mostrar), o aviso é a resposta diferente do esperado.
    Sem rótulos, o aviso é o defeito em si (neve estourada, pinheiros sumidos)."""
    esperado = caso.get("rotulos") or {}
    tem_esperado = bool(esperado)
    r = {"dia": parece_dia(medidas), "neve_estourada": None, "sem_pinheiros": None,
         "torre_visivel": torre_visivel(caso.get("geometria"))}
    # Neve e pinheiros só foram medidos de dia: à noite ficam sem resposta. Quem diz se é dia
    # é o esperado (a hora pedida), quando há; senão, a régua. Assim um erro da régua do dia
    # não esconde as outras conferências.
    de_dia = esperado.get("dia") if tem_esperado else r["dia"]
    if de_dia:
        r["neve_estourada"] = neve_estourada(medidas)
        if p_jev is not None and p_jev.get("sem_pinheiros") is not None:
            r["sem_pinheiros"] = p_jev["sem_pinheiros"] >= JEV_SEM_PINHEIROS_MIN
    avisos = []
    nomes = {"dia": ("parece dia", "parece noite"), "neve_estourada": ("neve estourada", "neve normal"),
             "sem_pinheiros": ("sem pinheiros", "com pinheiros"),
             "torre_visivel": ("torre visível", "torre não aparece")}
    for conf, valor in r.items():
        if valor is None:
            continue
        if tem_esperado:
            certo = esperado.get(conf)
            if certo is not None and valor != certo:
                avisos.append("%s (esperado: %s)" % (nomes[conf][0 if valor else 1],
                                                     nomes[conf][0 if certo else 1]))
        elif conf in ("neve_estourada", "sem_pinheiros") and valor:
            avisos.append(nomes[conf][0])
    # O Jev também responde "dia" (vem no mesmo pedido). Ele não ganhou o portão por margem,
    # mas quando discorda da régua vale olhar: a régua do dia é frágil.
    if p_jev is not None and p_jev.get("dia") is not None:
        jev_dia = p_jev["dia"] >= ac.LIMIAR_JEV_PADRAO
        if jev_dia != r["dia"]:
            avisos.append("o Jev acha que é %s" % ("dia" if jev_dia else "noite"))
    return {"id": caso["id"], "respostas": r, "avisos": avisos}


def _celula(valor, sim: str, nao: str) -> str:
    return "-" if valor is None else (sim if valor else nao)


def imprimir_tabela(linhas: list) -> None:
    print("%-30s %-6s %-9s %-10s %-9s %s" % ("captura", "hora", "neve", "pinheiros", "torre", "olhar"))
    for l in linhas:
        r = l["respostas"]
        print("%-30s %-6s %-9s %-10s %-9s %s" % (
            l["id"][:30], _celula(r["dia"], "dia", "noite"), _celula(r["neve_estourada"], "ESTOURA", "ok"),
            _celula(r["sem_pinheiros"], "SUMIRAM", "ok"), _celula(r["torre_visivel"], "aparece", "não"),
            ("!! " + "; ".join(l["avisos"])) if l["avisos"] else ""))


def main(argv=None, criar_cliente=None, medir=None) -> int:
    """`criar_cliente` e `medir` existem para os testes injetarem um Jev falso e medidas prontas."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="Confere uma pasta de capturas (C.4).")
    p.add_argument("pasta")
    p.add_argument("--jev", action="store_true",
                   help="pergunta ao Jev se os pinheiros sumiram (só capturas sem capas; custa)")
    a = p.parse_args(argv)

    cliente = None
    try:
        casos, tem_manifesto = ler_casos(a.pasta)
        if not casos:
            print("ERRO: nenhuma captura em %s" % a.pasta)
            ac.imprimir_custo(None)
            return 2
        respostas = None
        if a.jev:
            if not tem_manifesto:
                raise ValueError("a pasta não tem capturas.jsonl, então nada prova que as capturas "
                                 "não têm capas de jogo: o Jev não é usado. Gere com gerar_capturas.py.")
            for c in casos:
                pc.exigir_sem_capas(c)  # antes de qualquer envio
        medidas = ac.carregar_medidas(casos, a.pasta, medir)
        if a.jev:
            # O mesmo pedido do portão (todas as perguntas), para o limiar medido valer.
            pedidos = {c["id"]: pc.pedido_da_captura(c, a.pasta) for c in casos}
            respostas, cliente, erro = ac.obter_respostas_jev(pedidos, a.pasta, criar_cliente)
            if erro:
                print("ERRO: %s" % erro)
                ac.imprimir_custo(cliente)
                return 2
    except (ValueError, OSError, KeyError, jev.ErroJev, ImportError) as e:
        print("ERRO: %s" % e)
        ac.imprimir_custo(None)
        return 2

    linhas = [conferir(c, medidas[c["id"]], respostas.get(c["id"]) if respostas else None) for c in casos]
    print("%d capturas em %s%s" % (len(casos), a.pasta,
                                   "" if tem_manifesto else " (sem capturas.jsonl: sem esperado nem torre)"))
    if not a.jev:
        print("pinheiros: sem --jev, não conferidos")
    print()
    imprimir_tabela(linhas)
    com_aviso = sum(1 for l in linhas if l["avisos"])
    print("\n%d de %d capturas para olhar primeiro. A aprovação visual continua sendo sua."
          % (com_aviso, len(linhas)))
    ac.imprimir_custo(cliente)
    return 1 if com_aviso else 0


if __name__ == "__main__":
    sys.exit(main())
