# A lanterna do mirante (Fase 17.8): ferro preto com o vidro aceso. Fica
# pendurada nos braços do abrigo ou em pé no topo de um poste.
#
#   blender --background --factory-startup --python tools/blender/gerar_lanterna.py [-- saida.glb]
#
# Sai em assets/models/lookout/lantern.glb, uma malha por material: "iron" e
# "glass" (a Godot acende o vidro à noite e põe a luz no meio dele). No espaço
# da Godot, a origem é o ponto de pendurar (o alto da argola) e a lanterna
# desce dali: o vidro vai de y = -0,165 a -0,385 (o meio em -0,275) e a base
# termina em y = -0,435.

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(__file__))
import comum  # noqa: E402

G = comum.G
ferro = []


def peca(bm):
    ferro.append(comum.objeto("ferro_%d" % len(ferro), bm))


def argola():
    """A argola de cima, de pé no plano x-y da Godot."""
    bm = bmesh.new()
    raio, fio = 0.026, 0.0055
    lados, voltas = 8, 20
    aneis = []
    for i in range(voltas):
        a = math.tau * i / voltas
        centro = Vector((math.cos(a) * raio, 0.0, math.sin(a) * raio))
        para_fora = Vector((math.cos(a), 0.0, math.sin(a)))
        anel = []
        for k in range(lados):
            b = math.tau * k / lados
            p = centro + (para_fora * math.cos(b) + Vector((0.0, 1.0, 0.0)) * math.sin(b)) * fio
            anel.append(bm.verts.new(p))
        aneis.append(anel)
    for i in range(voltas):
        i2 = (i + 1) % voltas
        for k in range(lados):
            k2 = (k + 1) % lados
            bm.faces.new((aneis[i][k], aneis[i][k2], aneis[i2][k2], aneis[i2][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.smooth = True
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=G(0.0, -raio - fio, 0.0))
    return bm


def main():
    caminho = comum.saida("lantern", "lookout")
    comum.iniciar()
    peca(argola())
    # O chapéu: uma pirâmide de quatro lados, com a chaminé em cima.
    chapeu = comum.cilindro(0.118, 0.03, 0.085, lados=4, suave=False)
    bmesh.ops.rotate(chapeu, verts=chapeu.verts[:], cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 4, 3, 'Z'))
    bmesh.ops.translate(chapeu, verts=chapeu.verts[:], vec=G(0.0, -0.105, 0.0))
    peca(chapeu)
    chamine = comum.cilindro(0.022, 0.022, 0.03, lados=10)
    bmesh.ops.translate(chamine, verts=chamine.verts[:], vec=G(0.0, -0.065, 0.0))
    peca(chamine)
    # As molduras de cima e de baixo e a base.
    peca(comum.caixa((0.19, 0.19, 0.022), G(0.0, -0.155, 0.0), 0.003))
    peca(comum.caixa((0.19, 0.19, 0.03), G(0.0, -0.4, 0.0), 0.004))
    peca(comum.caixa((0.15, 0.15, 0.02), G(0.0, -0.425, 0.0), 0.003))
    # As quatro colunas dos cantos e uma grade fina no meio de cada lado.
    for x in (-0.082, 0.082):
        for z in (-0.082, 0.082):
            peca(comum.caixa((0.017, 0.017, 0.235), G(x, -0.277, z), 0.002))
    for k in range(4):
        a = k * math.pi / 2.0
        x, z = math.cos(a) * 0.078, math.sin(a) * 0.078
        tamanho = (0.006, 0.006, 0.22)
        peca(comum.caixa(tamanho, G(x, -0.277, z), 0.0))
    # O vidro: uma caixa por dentro das colunas.
    vidro = comum.objeto("glass", comum.caixa((0.15, 0.15, 0.22), G(0.0, -0.275, 0.0), 0.004))
    iron = comum.juntar(ferro, "iron")
    comum.pintar(iron, lambda p, n: (1.0, 1.0, 1.0))
    comum.pintar(vidro, lambda p, n: (1.0, 1.0, 1.0))
    comum.assar_oclusao([iron, vidro], forca=0.6, distancia=0.04)
    iron.data.materials.append(comum.material_simples("iron", (0.08, 0.08, 0.08), 0.6))
    vidro.data.materials.append(comum.material_simples("glass", (1.0, 0.7, 0.35), 0.2))
    comum.exportar([iron, vidro], caminho)


main()
