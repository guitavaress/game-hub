# Os bancos de madeira da trilha (Fase 17.7.1): tábuas chanfradas e um
# pouco empenadas, presas em armações de pernas, travessas e encosto. A
# madeira é de banco que fica ao relento: desbotada, com as quinas gastas.
#
#   blender --background --factory-startup --python tools/blender/gerar_bancos.py [-- saida.glb]
#
# Sai em assets/models/trail/benches.glb, três malhas sem textura própria: a
# madeira é a da Godot (home_wood.gdshader, a mesma da casa), que lê o veio
# de cada tábua no UV (em metros, x ao longo do veio). A cor dos vértices
# guarda o tom de cada tábua e os cantos escuros (oclusão).
#   bench_camp   1,25 m, em volta da fogueira (encosto inclinado; pés no chão plano do terraço)
#   bench_long   1,9 m, na margem da trilha (a parada "banco")
#   bench_short  1,2 m, na margem da trilha, ao lado do monte de pedras
# Na Godot, o assento olha para +Z e o encosto fica no -Z (no Blender, o
# encosto fica no +Y). Os da margem cabem em 0,34 m de fundura (a margem tem
# 0,5 m) e têm as pernas compridas, até 0,4 m abaixo do pé: a Godot assenta
# o banco pela ponta mais alta da rampa, e na mais baixa as pernas descem.

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(__file__))
import comum  # noqa: E402


def peca(bm, centro, deitada='X', inclina=0.0):
    """Coloca uma tábua (feita com x = comprimento) em pé ('Z'), atravessada
    ('Y') ou deitada ('X'); "inclina" gira em volta do X (o encosto)."""
    if deitada == 'Z':
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, 'Y'))
    elif deitada == 'Y':
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, 'Z'))
    if inclina:
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=Matrix.Rotation(inclina, 3, 'X'))
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=centro)
    bm.normal_update()
    return bm


def banco(nome, comprimento, margem, semente):
    rnd = random.Random(semente)
    pecas = []

    def junta(bm):
        ob = comum.objeto("%s_%d" % (nome, len(pecas)), bm)
        # Cada tábua num tom (uma mais clara, outra mais escura ou mais quente).
        tom = rnd.uniform(0.82, 1.12)
        quente = rnd.uniform(-0.04, 0.05)
        comum.pintar(ob, lambda p, n: (tom * (1 + quente), tom, tom * (1 - quente)))
        pecas.append(ob)

    assento = 0.46
    if margem:
        tabuas, largura, folga = [-0.1, 0.0, 0.1], 0.09, 0.01
        frente, tras, grossa = -0.1, 0.125, 0.085
        chao, topo_encosto, inclinacao = -0.4, 0.9, 0.0
    else:
        tabuas, largura, folga = [-0.117, 0.0, 0.117], 0.105, 0.012
        frente, tras, grossa = -0.13, 0.13, 0.07
        chao, topo_encosto, inclinacao = 0.0, 0.92, 0.075
    # O assento: tábuas com as pontas desencontradas.
    for k, y in enumerate(tabuas):
        bm = comum.tabua(comprimento + rnd.uniform(-0.015, 0.015), largura, 0.045, semente * 10 + k)
        junta(peca(bm, Vector((rnd.uniform(-0.008, 0.008), y, assento - 0.0225))))
    # As armações: nas pontas e, no banco comprido, uma no meio.
    xs = [-(comprimento / 2 - 0.16), comprimento / 2 - 0.16]
    if comprimento > 1.6:
        xs.insert(1, 0.0)
    for i, x in enumerate(xs):
        meio = 0 < i < len(xs) - 1
        alto = assento - 0.045
        # A perna da frente.
        bm = comum.tabua(alto - chao, grossa, grossa, semente * 10 + 20 + i)
        junta(peca(bm, Vector((x, frente, (alto + chao) / 2)), 'Z'))
        # A de trás sobe até o encosto (menos a do meio).
        cima = alto if meio else topo_encosto
        altura = cima - chao
        bm = comum.tabua(altura / math.cos(inclinacao), grossa, grossa, semente * 10 + 30 + i)
        recuo = math.tan(inclinacao) * altura / 2
        junta(peca(bm, Vector((x, tras + recuo, (cima + chao) / 2)), 'Z', -inclinacao))
        # A travessa que segura o assento e, no chão plano da fogueira, a de
        # baixo (na rampa da margem ela sumiria na neve).
        fundo = tras - frente + grossa
        bm = comum.tabua(fundo, 0.05, 0.055, semente * 10 + 40 + i)
        junta(peca(bm, Vector((x, (tras + frente) / 2, alto - 0.0275)), 'Y'))
        if not margem:
            bm = comum.tabua(fundo - grossa * 2 + 0.02, 0.045, 0.04, semente * 10 + 50 + i)
            junta(peca(bm, Vector((x, (tras + frente) / 2, 0.12)), 'Y'))
    # O encosto: duas réguas presas na frente dos postes de trás.
    for k, z in enumerate((0.66, 0.83)):
        recuo = math.tan(inclinacao) * (z - chao)
        y = tras + recuo - grossa / 2 - 0.014
        bm = comum.tabua(comprimento + 0.03, 0.028, 0.095, semente * 10 + 60 + k)  # em pé: fina no Y
        junta(peca(bm, Vector((0.0, y, z)), 'X', -inclinacao))
    # Do lado da fogueira, uma trava comprida atrás, embaixo.
    if not margem:
        bm = comum.tabua(xs[-1] - xs[0] + grossa, 0.045, 0.06, semente * 10 + 70)
        junta(peca(bm, Vector((0.0, tras + math.tan(inclinacao) * 0.14, 0.14))))
    return comum.juntar(pecas, nome)


def main():
    caminho = comum.saida("benches")
    comum.iniciar()
    bancos = [banco("bench_camp", 1.25, False, 1), banco("bench_long", 1.9, True, 2),
              banco("bench_short", 1.2, True, 3)]
    # Cada banco num lugar só para assar (um não faz sombra no outro); o
    # chão provisório dá a sombra dos pés. Depois voltam para a origem.
    chaos = []
    for k, ob in enumerate(bancos):
        ob.location.x = k * 4.0
        chaos.append(comum.chao(1.2, 0.0))
        chaos[-1].location.x = k * 4.0
    comum.assar_oclusao(bancos, forca=0.75, distancia=0.2)
    madeira = comum.material_simples("wood", (0.35, 0.24, 0.16), 0.85)
    for ob in bancos:
        ob.location.x = 0.0
        ob.data.materials.append(madeira)
    for ob in chaos:
        bpy.data.objects.remove(ob)
    for ob in bancos:
        fundo = max(abs(v.co.y) for v in ob.data.vertices)
        print("%s: fundura de %.3f m para cada lado" % (ob.name, fundo))
    comum.exportar(bancos, caminho)


main()
