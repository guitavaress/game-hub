# O monte de pedras da trilha (Fase 17.7.1): lajes chatas empilhadas, cada
# uma menor e um pouco torta, como as que os caminhantes deixam, com neve
# acumulada em cima de cada uma e umas pedrinhas no pé.
#
#   blender --background --factory-startup --python tools/blender/gerar_monte_de_pedras.py [-- saida.glb]
#
# Sai em assets/models/trail/cairn.glb, com duas malhas:
#   stone  as lajes e as pedrinhas (cor nos vértices: tom e cantos escuros)
#   snow   a neve em cima das lajes (cor nos vértices: cantos escuros)
# O pé do monte é o y = 0 da Godot. Cabe na margem da trilha: 0,32 m de
# fundura no máximo (de -0,16 a 0,16 no z da Godot).

import math
import os
import random
import sys

from mathutils import Vector, noise

sys.path.append(os.path.dirname(__file__))
import comum  # noqa: E402

LAJES = 8
FUNDURA = 0.3


def monte():
    rnd = random.Random(17)
    pedras = []
    neves = []
    z = -0.04
    for nivel in range(LAJES):
        parte = nivel / (LAJES - 1)
        largura = 0.66 + (0.17 - 0.66) * parte
        altura = 0.15 + (0.1 - 0.15) * parte
        fundo = min(FUNDURA, largura * 0.82)
        tamanho = (largura, fundo, altura)
        bm = comum.pedra(tamanho, 200 + nivel, redondeza=0.55, ondulacao=0.1, cortes=3, funda=(0.04, 0.14),
                         divisoes=2, base=-0.42, chanfro=0.01, cortes_de_lado=True)
        lugar = Vector((0.025 * math.sin(nivel * 2.3), 0.012 * math.cos(nivel * 1.7), z + altura * 0.42))
        giro = 0.18 * math.sin(nivel * 3.1)
        inclinacao = (0.05 * math.sin(nivel * 1.9), 0.06 * math.cos(nivel * 2.6))
        comum.colocar(bm, lugar, giro, inclinacao)
        pedras.append(comum.objeto("laje%d" % nivel, bm))
        # A neve: uma almofada fina em cima da laje (some embaixo da de cima).
        topo = z + altura * 0.86
        bm = comum.pedra((largura * 0.78, fundo * 0.74, 0.045 if nivel < LAJES - 1 else 0.06), 260 + nivel,
                         redondeza=0.95, ondulacao=0.12, cortes=0, divisoes=2, base=-0.1)
        comum.colocar(bm, lugar + Vector((0.0, 0.0, topo - lugar.z)), giro, inclinacao)
        neves.append(comum.objeto("neve%d" % nivel, bm))
        z += altura * 0.9
    # Pedrinhas no pé.
    for k in range(5):
        a = math.tau * k / 5 + rnd.uniform(-0.3, 0.3)
        tamanho = (rnd.uniform(0.07, 0.13), rnd.uniform(0.06, 0.1), rnd.uniform(0.04, 0.07))
        lugar = Vector((math.cos(a) * 0.38, math.sin(a) * 0.1, 0.0))
        bm = comum.pedra(tamanho, 280 + k, redondeza=0.7, ondulacao=0.15, cortes=2, divisoes=2)
        comum.colocar(bm, lugar, rnd.uniform(0, 6))
        pedras.append(comum.objeto("pedrinha%d" % k, bm))
    pedra = comum.juntar(pedras, "stone")
    comum.pintar(pedra, lambda p, n: tuple(1.3 + 0.22 * noise.noise(p * 3.0 + Vector((c, 0, 0))) for c in (0, 0.4, 0.8)))
    neve = comum.juntar(neves, "snow")
    comum.pintar(neve, lambda p, n: (1.0, 1.0, 1.0))
    return pedra, neve


def main():
    caminho = comum.saida("cairn")
    comum.iniciar()
    chao = comum.chao(1.5, 0.0)
    pedra, neve = monte()
    comum.assar_oclusao([pedra, neve], forca=0.85, distancia=0.15)
    pedra.data.materials.append(comum.material_simples("stone", (0.6, 0.62, 0.65)))
    neve.data.materials.append(comum.material_simples("snow", (0.8, 0.85, 0.9)))
    import bpy
    bpy.data.objects.remove(chao)
    fundo = max(abs(v.co.y) for ob in (pedra, neve) for v in ob.data.vertices)
    print("Fundura: %.3f m para cada lado" % fundo)
    comum.exportar([pedra, neve], caminho)


main()
