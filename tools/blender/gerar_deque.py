# As peças do deque do mirante (Fase 17.8): tábuas do piso, o poste e as
# réguas do guarda-corpo e a viga dos pés. Madeira de deque ao relento:
# quinas gastas, tábuas um pouco empenadas.
#
#   blender --background --factory-startup --python tools/blender/gerar_deque.py [-- saida.glb]
#
# Sai em assets/models/lookout/deck.glb, só madeira (o material "wood", que a
# Godot troca pela Wood049). São peças soltas, cada uma na origem, que a Godot
# espalha e estica (LookoutDeck): o tamanho do deque depende do mirante (o
# raio do disco, a torre, a trilha que chega), e por isso o lugar de cada
# tábua é da Godot. No espaço da Godot (y para cima):
#   plank_0..plank_3  tábua do piso: 2,4 m em x, 0,2 m em z, 0,045 m de
#                     espessura, com o topo em y = 0
#   post              poste do guarda-corpo: 0,12 × 0,12, de y = 0 a y = 1,1,
#                     com a cabeça em ponta de diamante
#   handrail          o corrimão: 1 m em x (a Godot estica), 0,11 × 0,055
#   board             tábua fina: 1 m em x, 0,09 × 0,028 (a régua de baixo e o X)
#   beam              viga: 1 m em y (a Godot estica), 0,18 × 0,18 (os pés e
#                     as vigas debaixo da plataforma)
# O UV ("veio", em metros) corre ao longo de cada peça. A cor dos vértices
# escurece os lados e o fundo das tábuas: entre uma e outra, a fresta fica
# escura, como se fosse a sombra de baixo.

import os
import sys

import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
import comum  # noqa: E402

PLANK_LENGTH = 2.4
PLANK_WIDTH = 0.2
PLANK_THICK = 0.045


def lados_escuros(p, n):
    """Topo claro, lados e fundo escuros (a fresta entre as tábuas)."""
    if n.z > 0.6:
        return (1.0, 1.0, 1.0)
    if n.z < -0.6:
        return (0.35, 0.35, 0.35)
    return (0.55, 0.53, 0.5)


def tabua_do_piso(k):
    # Poucos cortes ao longo (a cada 0,8 m): o piso tem centenas de tábuas.
    bm = comum.tabua(PLANK_LENGTH, PLANK_WIDTH, PLANK_THICK, 400 + k, chanfro=0.007, torto=0.004, passo=0.8)
    # O topo fica em z = 0 (y = 0 na Godot).
    for v in bm.verts:
        v.co.z -= PLANK_THICK / 2.0
    ob = comum.objeto("plank_%d" % k, bm)
    comum.pintar(ob, lados_escuros)
    return ob


def poste():
    bm = comum.tabua(1.1, 0.12, 0.12, 410, chanfro=0.008, torto=0.0)
    # Em pé: o x da tábua vira o z (para cima), da base (z = 0) ao topo.
    comum.orientar(bm, Vector((0.0, 0.0, 1.0)), Vector((0.0, 1.0, 0.0)), Vector((0.0, 0.0, 0.55)))
    # A cabeça em ponta de diamante: o anel de cima desce para o meio.
    topo = max(v.co.z for v in bm.verts)
    for v in bm.verts:
        if v.co.z > topo - 0.012:
            v.co.x *= 0.35
            v.co.y *= 0.35
            v.co.z += 0.03
    bm.normal_update()
    ob = comum.objeto("post", bm)
    comum.pintar(ob, lambda p, n: (1.0, 1.0, 1.0))
    return ob


def regua(nome, largura, espessura, semente, chanfro):
    bm = comum.tabua(1.0, largura, espessura, semente, chanfro=chanfro, torto=0.0)
    ob = comum.objeto(nome, bm)
    comum.pintar(ob, lambda p, n: (1.0, 1.0, 1.0) if n.z > -0.5 else (0.7, 0.7, 0.7))
    return ob


def viga():
    bm = comum.tabua(1.0, 0.18, 0.18, 420, chanfro=0.01, torto=0.0)
    comum.orientar(bm, Vector((0.0, 0.0, 1.0)), Vector((0.0, 1.0, 0.0)), Vector((0.0, 0.0, 0.5)))
    ob = comum.objeto("beam", bm)
    comum.pintar(ob, lambda p, n: (1.0, 1.0, 1.0))
    return ob


def main():
    caminho = comum.saida("deck", "lookout")
    comum.iniciar()
    pecas = [tabua_do_piso(k) for k in range(4)]
    pecas += [poste(), regua("handrail", 0.11, 0.055, 411, 0.014),
              regua("board", 0.09, 0.028, 412, 0.006), viga()]
    # Cada peça num lugar só para assar (uma não faz sombra na outra).
    for k, ob in enumerate(pecas):
        ob.location.y = k * 1.5
    comum.assar_oclusao(pecas, forca=0.6, distancia=0.05)
    madeira = comum.material_simples("wood", (0.45, 0.36, 0.28), 0.85)
    for ob in pecas:
        ob.location.y = 0.0
        ob.data.materials.append(madeira)
    comum.exportar(pecas, caminho)


main()
