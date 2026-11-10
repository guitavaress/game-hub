# A luneta de latão do mirante (Fase 17.8): a base torneada, a coluna com
# anéis, o garfo e o tubo com a ocular, os anéis e o para-sol. Na Godot,
# olhar para ela e apertar E aproxima a vista da cidade (LookoutTelescope).
#
#   blender --background --factory-startup --python tools/blender/gerar_luneta.py [-- saida.glb]
#
# Sai em assets/models/lookout/telescope.glb, uma malha por material: "brass"
# (o latão) e "iron" (a borracha da ocular, a lente escura e os botões). No
# espaço da Godot: a origem no chão, no meio da base; o tubo aponta para -Z,
# 6° para baixo (a cidade fica lá embaixo), com o eixo em y = 1,38 e a ocular
# em (0; 1,43; 0,44).

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
import comum  # noqa: E402

G = comum.G
EIXO_Y = 1.38            # a altura do eixo do tubo
INCLINACAO = math.radians(6.0)
GROSSURA = 1.2           # o tubo e a coluna: um pouco mais grossos que o real, para se lerem de longe
latao = []
ferro = []


def junta(lista, bm, nome):
    lista.append(comum.objeto("%s_%d" % (nome, len(lista)), bm))


def coluna():
    """A base torneada e a coluna, do chão até o garfo."""
    topo = EIXO_Y - 0.13
    perfil = [(0.0, 0.215), (0.025, 0.215), (0.04, 0.195), (0.07, 0.125), (0.11, 0.075),
              (0.15, 0.052), (0.18, 0.046), (0.205, 0.037), (0.5, 0.032), (0.515, 0.043),
              (0.545, 0.043), (0.56, 0.032), (topo - 0.09, 0.034), (topo - 0.06, 0.047),
              (topo - 0.02, 0.052), (topo, 0.036)]
    perfil = [(z, r * (GROSSURA if z > 0.15 else 1.0)) for z, r in perfil]
    junta(latao, comum.tubo(perfil, lados=40), "base")
    # Os três pés de garra, saindo da base.
    for k in range(3):
        a = math.tau * k / 3.0 + 0.5
        d = Vector((math.cos(a), math.sin(a), 0.0))
        bm = comum.caixa((0.15, 0.04, 0.022), (0.0, 0.0, 0.0), 0.006)
        comum.orientar(bm, d + Vector((0.0, 0.0, -0.25)), None, d * 0.2 + Vector((0.0, 0.0, 0.03)))
        junta(latao, bm, "pe")


def garfo():
    """O garfo em cima da coluna, que segura o tubo pelo eixo."""
    base_y = EIXO_Y - 0.13
    junta(latao, comum.caixa((0.21, 0.06, 0.025), G(0.0, base_y + 0.012, 0.0), 0.005), "garfo")
    for s in (-1.0, 1.0):
        junta(latao, comum.caixa((0.018, 0.05, 0.16), G(s * 0.095, base_y + 0.09, 0.0), 0.004), "garfo")
        # O botão de aperto, por fora.
        bm = comum.tubo([(-0.02, 0.016), (0.0, 0.016), (0.0, 0.022), (0.03, 0.022)], lados=14,
                        eixo=Vector((s, 0.0, 0.0)), centro=G(s * 0.106, EIXO_Y, 0.0))
        junta(ferro, bm, "botao")
    # O eixo atravessado.
    junta(latao, comum.tubo([(-0.096, 0.017), (0.096, 0.017)], lados=16, eixo=Vector((1.0, 0.0, 0.0)),
                            centro=G(0.0, EIXO_Y, 0.0)), "eixo")


def tubo():
    """O tubo: de trás (a ocular) para a frente (o para-sol). t = ao longo do
    eixo, a partir do eixo do garfo, positivo para a frente."""
    frente = Vector(G(0.0, -math.sin(INCLINACAO), -math.cos(INCLINACAO)))
    centro = G(0.0, EIXO_Y, 0.0)
    perfil = [(-0.43, 0.022), (-0.395, 0.022), (-0.39, 0.03), (-0.205, 0.03), (-0.2, 0.045),
              (-0.177, 0.045), (-0.173, 0.052), (-0.034, 0.052), (-0.03, 0.058), (0.0, 0.058),
              (0.004, 0.052), (0.186, 0.052), (0.19, 0.058), (0.22, 0.058), (0.224, 0.052),
              (0.416, 0.052), (0.42, 0.06), (0.456, 0.06), (0.46, 0.064), (0.676, 0.064),
              (0.68, 0.069), (0.70, 0.069), (0.703, 0.06)]
    perfil = [(t, r * GROSSURA) for t, r in perfil]
    junta(latao, comum.tubo(perfil, lados=40, eixo=frente, centro=centro), "tubo")
    # A borracha da ocular, atrás, e a lente escura, lá na frente.
    junta(ferro, comum.tubo([(-0.452, 0.019 * GROSSURA), (-0.448, 0.025 * GROSSURA), (-0.428, 0.025 * GROSSURA)], lados=24,
                            eixo=frente, centro=centro), "ocular")
    junta(ferro, comum.tubo([(0.66, 0.059 * GROSSURA), (0.665, 0.059 * GROSSURA)], lados=32, eixo=frente,
                            centro=centro), "lente")
    # O botão do foco, de lado no tubo de trás.
    lado = Vector((1.0, 0.0, 0.0))
    p = Vector(centro) + frente * -0.29
    junta(latao, comum.tubo([(0.0, 0.009), (0.035, 0.009), (0.035, 0.018), (0.05, 0.018)], lados=14,
                            eixo=lado, centro=p), "foco")
    junta(latao, comum.tubo([(0.0, 0.009), (0.035, 0.009), (0.035, 0.018), (0.05, 0.018)], lados=14,
                            eixo=-lado, centro=p), "foco")


def main():
    caminho = comum.saida("telescope", "lookout")
    comum.iniciar()
    coluna()
    garfo()
    tubo()
    brass = comum.juntar(latao, "brass")
    iron = comum.juntar(ferro, "iron")
    comum.pintar(brass, lambda p, n: (1.0, 1.0, 1.0))
    comum.pintar(iron, lambda p, n: (1.0, 1.0, 1.0))
    piso = comum.chao(1.0, 0.0)
    comum.assar_oclusao([brass, iron], forca=0.7, distancia=0.08)
    bpy.data.objects.remove(piso)
    brass.data.materials.append(comum.material_simples("brass", (0.78, 0.57, 0.24), 0.35))
    iron.data.materials.append(comum.material_simples("iron", (0.06, 0.06, 0.06), 0.5))
    comum.exportar([brass, iron], caminho)


main()
