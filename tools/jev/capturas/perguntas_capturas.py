"""Tudo o que o Jev lê numa captura de tela, num lugar só: o contexto, as perguntas e o pedido.

Segue a skill TypeSafe: uma pergunta `noul` por julgamento, sobre o que SE VÊ na imagem, com
critérios `true`/`false` concretos. As perguntas são em inglês (a língua em que o Jev foi medido).
A decisão (limiar, veredito) fica no código, em avaliar_capturas.py.

O estado NUNCA entrega a resposta: nada de hora, variante, ponto da câmera nem nome do arquivo
(que tem "praca_13h_normal"). O Jev só recebe a imagem e o contexto fixo.
"""
import json
import os
import sys

# Para achar o `jev` (uma pasta acima) e os módulos desta pasta.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jev  # noqa: E402

# As conferências, na ordem do relatório.
CONFERENCIAS = ["dia", "tela_preta", "neve_estourada", "sem_pinheiros", "torre_visivel"]

# A chave com que a imagem aparece no estado. A API troca pela imagem TODA ocorrência
# desse texto, inclusive dentro das perguntas: por isso ela não pode ser uma palavra.
# (Com "screenshot", a imagem entrava no meio de cada "in this screenshot": 4,5x tokens.)
CHAVE_IMAGEM = "captura_7f3a9c2e"

# Fatos que o Jev não tem como saber sozinho.
CONTEXTO = ("Screenshot of Game Hub, a game launcher made in the Godot engine that shows the "
            "player's game library as a 3D city. The picture is taken from a first-person "
            "view (or from above) inside one district: a role-playing district covered in "
            "snow, with stone arches and a mountain in the background. The arches are "
            "placeholders and show names like 'Jogo Falso 001' (Portuguese for 'Fake "
            "Game 001').")
# (O contexto não diz que há pinheiros: é justamente uma das conferências.)

# O texto no lugar da descrição da torre, até a C.2 dizer como ela aparece.
TORRE_PENDENTE = "<<preencher na C.2: a aparência da torre>>"


def pergunta_torre(descricao: str) -> dict:
    """A noul da torre. A descrição visual (cor, forma, tamanho) vem de quem gerou as capturas."""
    return {
        "type": "noul",
        "instructions": "Is the tower described here visible in the screenshot? "
                        "The tower: %s" % descricao,
        "criteria": {
            "true": "a structure matching that description can be seen, standing out above the "
                    "skyline or the buildings and not hidden behind anything",
            "false": "only buildings, pine trees, rocks, snow and mountains are in view, and "
                     "no structure matches that description",
        },
    }


# Uma pergunta por conferência (a da torre fica com o texto pendente até a C.2).
PERGUNTAS = {
    "dia": {
        "type": "noul",
        "instructions": "Was this screenshot taken in daylight?",
        "criteria": {
            "true": "the sky is bright (light blue, pale or white) and the scene is lit by "
                    "sunlight, with colors as seen in full daytime",
            "false": "the sky is dark (deep blue or black) and the scene is lit only by lamps, "
                     "lit windows or a faint glow, as at night",
        },
    },
    "tela_preta": {
        "type": "noul",
        "instructions": "Is this screenshot almost entirely black, with nothing recognizable in it?",
        "criteria": {
            "true": "nearly every pixel is black or very close to black, so no ground, building, "
                    "tree, sky or mountain can be made out",
            "false": "ground, buildings, trees, sky or mountains can be clearly recognized, "
                     "even if the picture is dim",
        },
    },
    "neve_estourada": {
        "type": "noul",
        "instructions": "Is the snow in this screenshot blown out, a flat white with no visible "
                        "shading?",
        "criteria": {
            "true": "the snow covering the ground and the rocks is a uniform pure white, so "
                    "slopes, bumps and shadows on it cannot be told apart",
            "false": "the snow shows soft shading, light gradients or bluish shadows, so slopes "
                     "and bumps on the ground can be seen",
        },
    },
    "sem_pinheiros": {
        "type": "noul",
        "instructions": "Are the snow-covered blocks in this screenshot empty of pine trees?",
        "criteria": {
            "true": "the snow-covered blocks show only snow, rocks, stone arches and lamps, and "
                    "no pine tree stands anywhere in them",
            "false": "one or more pine trees, tall dark conifers, stand in the snow-covered blocks",
        },
    },
    "torre_visivel": pergunta_torre(TORRE_PENDENTE),
}


def estado(chave_imagem: str = CHAVE_IMAGEM) -> dict:
    """O estado: só o contexto fixo e o lugar da imagem. Nada que entregue a resposta."""
    return {"context": CONTEXTO, "screenshot": chave_imagem}


def exigir_sem_capas(caso: dict) -> None:
    """Proteção: capa de jogo de verdade nunca vai ao Jev. Só passa quem diz `sem_capas: true`."""
    if caso.get("sem_capas") is not True:
        raise ValueError("a captura %r não declara sem_capas=true: recusada, para nunca mandar "
                         "capa de jogo real ao Jev" % caso.get("id"))


def descricao_valida(descricao: str) -> bool:
    """Há descrição de verdade da torre (e não vazia nem o texto pendente)?"""
    return bool(descricao and descricao.strip()) and descricao != TORRE_PENDENTE


def perguntas_do_pedido(descricao_torre: str = "") -> dict:
    """As perguntas de um pedido. Sem descrição da torre, a pergunta da torre fica de fora
    (melhor não perguntar do que mandar o texto pendente)."""
    qs = {k: v for k, v in PERGUNTAS.items() if k != "torre_visivel"}
    if descricao_valida(descricao_torre):
        qs["torre_visivel"] = pergunta_torre(descricao_torre.strip())
    return qs


def pedido_da_captura(caso: dict, pasta: str, descricao_torre: str = "") -> dict:
    """O corpo do pedido de uma captura: todas as conferências, uma pergunta cada, e a imagem."""
    exigir_sem_capas(caso)
    perguntas = perguntas_do_pedido(descricao_torre)
    exigir_chave_unica(perguntas)
    caminho = os.path.join(pasta, caso["arquivo"])
    return jev.pedido(estado(CHAVE_IMAGEM), perguntas, {CHAVE_IMAGEM: jev.imagem_png(caminho)})


def exigir_chave_unica(perguntas: dict) -> None:
    """A chave da imagem só pode aparecer no lugar da imagem: em qualquer outro texto a API
    também a trocaria pela imagem (foi o que aconteceu com a chave "screenshot")."""
    texto = json.dumps({"context": CONTEXTO, "questions": perguntas})
    if CHAVE_IMAGEM in texto:
        raise ValueError("a chave da imagem %r aparece no texto das perguntas" % CHAVE_IMAGEM)


def texto_do_pedido(corpo: dict) -> str:
    """O texto do pedido (sem a imagem), para estimar o custo."""
    return json.dumps({"state": corpo["state"], "questions": corpo["questions"]})
