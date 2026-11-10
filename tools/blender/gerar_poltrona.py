# Poltrona da cabana (17.9.1b), GPL-3.0; o GLB gerado é nosso (MIT).
# Origem no chão, no centro; frente -Z da Godot; 0,70 × 0,99 × 0,70 m.
# Um só modelo, sem manta: a Godot veste uma das duas poltronas em código.
# blender --background --factory-startup --python tools/blender/gerar_poltrona.py
# Opcional: -- saida.glb pasta_das_previas
import math
import os
import sys

import bpy
import bmesh
from mathutils.bvhtree import BVHTree

sys.path.append(os.path.dirname(__file__))
import comum

G = comum.G


def main():
    caminho = comum.saida('armchair', 'home')
    comum.iniciar()
    madeira, tecido = [], []

    def juntar_peca(lista, bm, tom=1.0):
        ob = comum.objeto('peca', bm)
        comum.pintar(ob, lambda p, n: (tom, tom, tom))
        lista.append(ob)

    def viga(a, b, largura, espessura, lado=(1, 0, 0)):
        juntar_peca(madeira, comum.tabua_casa_entre(G(*a), G(*b), largura, espessura,
                    len(madeira) + 179, G(*lado), torto=0.0, chanfro=0.004), 0.92)

    # Pés e montantes: as pernas traseiras continuam até o alto do encosto.
    for x in (-0.29, 0.29):
        viga((x, 0, -0.29), (x, 0.56, -0.29), 0.05, 0.05)
        viga((x, 0, 0.29), (x, 0.94, 0.29), 0.05, 0.05)
        # Travessa lateral aparente e apoio arredondado por baixo do braço.
        viga((x, 0.19, -0.32), (x, 0.19, 0.32), 0.075, 0.065, (0, 1, 0))
        viga((x, 0.47, -0.32), (x, 0.47, 0.31), 0.07, 0.07, (0, 1, 0))
        viga((x, 0.12, -0.29), (x, 0.12, 0.29), 0.035, 0.04, (0, 1, 0))
    for y, z in [(0.19, -0.30), (0.19, 0.29), (0.89, 0.30)]:
        viga((-0.315, y, z), (0.315, y, z), 0.065, 0.055, (0, 1, 0))

    # Saia, assento solto e encosto cheio. Costuras separadas continuam na
    # mesma malha/material; a cor permite trocar o tecido inteiro na Godot.
    for tam, pos, raio, recuo, tom in [
        ((0.60, 0.15, 0.60), (0, 0.285, -0.01), 0.035, 0, 0.88),
        ((0.43, 0.135, 0.53), (0, 0.425, -0.065), 0.05, 0, 1.0),
        ((0.70, 0.62, 0.18), (0, 0.68, 0.26), 0.065, 0.065, 0.97),
        ((0.15, 0.14, 0.70), (-0.275, 0.54, 0), 0.055, 0, 0.95),
        ((0.15, 0.14, 0.70), (0.275, 0.54, 0), 0.055, 0, 0.95),
    ]:
        juntar_peca(tecido, comum.almofada(tam, pos, raio, len(tecido) + 5, recuo), tom)

    # Vivos do assento e da frente do encosto: raios suaves, só 2 mm.
    def vivo(largura, altura, raio, converter, alvo, origem_de):
        bm = bmesh.new()
        bm.from_mesh(alvo.data)
        arvore = BVHTree.FromBMesh(bm)
        pontos = []
        for cx, cy, angulo in [(largura / 2 - raio, altura / 2 - raio, 0),
                               (-largura / 2 + raio, altura / 2 - raio, 90),
                               (-largura / 2 + raio, -altura / 2 + raio, 180),
                               (largura / 2 - raio, -altura / 2 + raio, 270)]:
            for k in range(7):
                a = math.radians(angulo + k * 90 / 6)
                p = converter(cx + raio * math.cos(a), cy + raio * math.sin(a))
                origem = origem_de(p)
                direcao = (p - origem).normalized()
                encontro, normal, _, _ = arvore.ray_cast(origem, direcao)
                if encontro is None:
                    raise RuntimeError('O vivo perdeu a superfície da almofada')
                pontos.append(encontro + normal * 0.0007)
        bm.free()
        juntar_peca(tecido, comum.cordao(pontos, raio=0.0015), 0.78)

    vivo(0.43, 0.53, 0.05, lambda x, z: G(x, 0.425, z - 0.065), tecido[1],
         lambda p: G(0, 0.425, -0.065) + (p - G(0, 0.425, -0.065)) * 3)
    vivo(0.64, 0.55, 0.055, lambda x, y: G(x, y + 0.68, 0.26), tecido[2],
         lambda p: p + G(0, 0, -1))
    objetos = [comum.juntar(madeira, 'wood'), comum.juntar(tecido, 'fabric')]
    piso = comum.chao(1.2)
    comum.assar_oclusao(objetos, forca=0.65, distancia=0.16, amostras=32)
    bpy.data.objects.remove(piso)
    objetos[0].data.materials.append(comum.material_simples('wood', (0.35, 0.25, 0.18), 0.6))
    objetos[1].data.materials.append(comum.material_simples('fabric', (0.34, 0.22, 0.16), 1.0))
    comum.exportar(objetos, caminho)
    comum.previa_casa(objetos, 'poltrona', (0, 0.48, 0),
                     [('frente', (0, 1.0, -3)), ('tres_quartos', (2, 1.65, -2.8))], 1.3)


if __name__ == '__main__':
    main()
