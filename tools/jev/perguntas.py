"""Tudo o que o Jev lê, num lugar só: o estado, as perguntas e os limiares.

Segue a skill TypeSafe: o Jev faz julgamentos pequenos e observáveis ("o log mostra um
arquivo que não carregou?"), e a decisão (regressão, ambiente...) fica no código, na
tabela de triar_falhas.py. As perguntas são em inglês, a língua em que o Jev foi medido.
"""

# Limiares do "sim" e do "não" de cada noul. Entre os dois, a pergunta não se decidiu.
# Começam no padrão da skill (0,7 / 0,3); o avaliar.py mede na parte de ajuste do gabarito.
LIMIAR_SIM = 0.7
LIMIAR_NAO = 0.3

# Fatos que o Jev não tem como saber sozinho.
CONTEXTO = ("Automated test of Game Hub, a game launcher made in the Godot engine. Each test "
            "prints one line per check, '[ok]' or '[FALHOU]' (Portuguese for 'failed'), and ends "
            "with a 'RESULTADO' line. Some text is in Portuguese. '<jogo>' stands for a game "
            "title and '<projeto>' or '<casa>' for folders, hidden for privacy. The hub builds "
            "a city from the Steam games installed on this computer: each installed game "
            "becomes a building node named 'Building_<app id>'. Several tests need four "
            "specific games installed: Balatro (2379780), Skyrim (489830), Valheim (892970) "
            "and Stardew Valley (413150).")

LINHAS_DO_FIM = 40          # o fim do log quase sempre diz como o teste acabou
MAX_CARACTERES = 6000       # um log grande vira um trecho; o custo é por token
PARTE_DO_COMECO = 0.45      # num log cortado, ~45% do espaço vai para o começo (a causa)


def _juntar_repetidas(linhas: list) -> list:
    """Um erro repetido 30 vezes vira um só, com a contagem: a causa não se afoga no efeito.

    Compara pares "erro + linha de baixo" (o "at: arquivo"), que é como a Godot imprime.
    """
    vistos, saida = {}, []
    i = 0
    while i < len(linhas):
        par = tuple(linhas[i:i + 2]) if "ERROR" in linhas[i] else (linhas[i],)
        if len(par) == 2 and par in vistos:
            vistos[par] += 1
            i += 2
            continue
        if len(par) == 2:
            vistos[par] = 1
        saida.append(par)
        i += len(par)
    resultado = []
    for par in saida:
        resultado.extend(par)
        if len(par) == 2 and vistos.get(par, 1) > 1:
            resultado.append("   (repetida %d vezes)" % vistos[par])
    return resultado


def trecho_do_log(log: str) -> str:
    """As linhas que uma pessoa olharia: erros, avisos, conferências, e o fim do log.

    Se ainda passar do limite, guarda o começo (onde costuma estar a causa) e o fim (como
    o teste acabou), e corta o meio.
    """
    linhas = _juntar_repetidas(log.splitlines())
    marcadas = set(range(max(0, len(linhas) - LINHAS_DO_FIM), len(linhas)))
    for i, l in enumerate(linhas):
        if any(p in l for p in ("ERROR", "FALHOU", "WARNING", "RESULTADO", "Failed", "Can't",
                                "Cannot", "repetida")):
            marcadas.update((i, i + 1))  # a linha de baixo costuma ter o "at: arquivo"
    partes, anterior = [], -1
    for i in sorted(j for j in marcadas if j < len(linhas)):
        if i != anterior + 1 and partes:
            partes.append("...")
        partes.append(linhas[i])
        anterior = i
    texto = "\n".join(partes)
    if len(texto) <= MAX_CARACTERES:
        return texto
    comeco = int(MAX_CARACTERES * PARTE_DO_COMECO)
    return texto[:comeco] + "\n... (meio cortado) ...\n" + texto[-(MAX_CARACTERES - comeco):]


def estado(caso: dict, log: str) -> dict:
    return {
        "context": CONTEXTO,
        "failure": {
            "test": caso["teste"],
            "battery_lines": caso.get("resumo_bateria", []),
            "log_excerpt": trecho_do_log(log),
        },
    }


# A pergunta que vale para qualquer falha.
# (Uma pergunta "faltou carregar um arquivo?" saiu: a bateria importa o projeto antes dos
#  testes, então um arquivo que não carrega nela é mudança no projeto, não ambiente.)
PERGUNTAS = {
    "jogo_faltando": {
        "type": "noul",
        "instructions": "Does `failure.log_excerpt` show that a Steam game the test expects is "
                        "not installed on this computer?",
        "criteria": {
            "true": "the log shows the building of a game the test needs missing from the city, "
                    "such as a 'Node not found' error for a 'Building_<app id>' node, and the errors "
                    "that follow "
                    "come from that missing building",
            "false": "every building the test looks for is in the city, and the failing checks "
                     "or errors are about something else",
        },
    },
}
# (A pergunta "uma conferência deu resultado errado?" também saiu: ver um "[FALHOU]" no log
#  é busca exata, do código; e o critério dela misturava conferência com arquivo faltando.)


def pergunta_ligacao(arquivo: str) -> dict:
    """Uma pergunta por arquivo mudado (a skill: um item por pergunta, nada de lista)."""
    return {
        "type": "noul",
        "instructions": "Does the failure of `failure.test` involve the file %s?" % arquivo,
        "criteria": {
            "true": "the log, the test name or the failing checks point to %s: the same file, "
                    "class, system or feature" % arquivo,
            "false": "%s belongs to a different part of the hub from the one the failing checks "
                     "talk about" % arquivo,
        },
    }


def perguntas_do_caso(caso: dict) -> dict:
    """As perguntas de um caso. O arquivo do próprio teste o código já resolve (é busca exata)."""
    qs = dict(PERGUNTAS)
    for i, arquivo in enumerate(arquivos_para_o_jev(caso)):
        qs["ligado_%d" % i] = pergunta_ligacao(arquivo)
    return qs


def arquivos_para_o_jev(caso: dict) -> list:
    proprio = "tests/%s.gd" % caso["teste"]
    return [f for f in caso.get("diff", []) if f != proprio]
