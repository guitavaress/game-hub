# Lareira de pedra da cabana (17.9.1b), GPL-3.0; GLB nosso (MIT).
# Coordenadas da Godot: parede X=0, frente +X, centro Z=0, chão Y=0.
# A chaminé fica em código: de Y=1,57 até Home.ROOM_SIZE.y.
# Sem fogo, lenha, luz, chamas nem lampião: esses continuam na Godot.
# blender --background --factory-startup --python tools/blender/gerar_lareira.py
# Opcional: -- saida.glb pasta_das_previas
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(__file__))
import comum

G = comum.G


def main():
    caminho = comum.saida('fireplace', 'home')
    comum.iniciar()
    grupos = {nome: [] for nome in ('stone', 'wood', 'soot', 'iron')}
    rnd = random.Random(1791)

    def parte(nome, bm, tom=1.0):
        ob = comum.objeto('peca', bm)
        comum.pintar(ob, lambda p, n: (tom, tom, tom))
        grupos[nome].append(ob)

    def bloco(limites, semente):
        x0, x1, y0, y1, z0, z1 = limites
        tamanho = (x1 - x0, z1 - z0, y1 - y0)
        centro = G((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        bm = comum.pedra(tamanho, semente, redondeza=0.13, ondulacao=0.045,
                        cortes=2, funda=(0.01, 0.045), divisoes=3, base=-0.5,
                        chanfro=0.004, cortes_de_lado=True)
        comum.ajustar_caixa(bm, tamanho, centro)
        parte('stone', bm, rnd.uniform(0.82, 1.14))

    # Cinco fiadas nos pilares. Juntas desencontradas nas laterais deixam
    # claro que são blocos de pedra assentados, não uma textura de calçada.
    for lado in (-1, 1):
        z0, z1 = (-0.9, -0.5) if lado < 0 else (0.5, 0.9)
        for fiada in range(5):
            y0, y1 = fiada * 0.29, (fiada + 1) * 0.29
            corte = 0.31 if fiada % 2 else 0.43
            for i, (a, b) in enumerate([(0, corte - 0.004), (corte + 0.004, 0.7)]):
                bloco((a, b, y0 + (0.004 if fiada else 0), y1 - 0.004,
                       z0, z1), 1000 + (lado + 1) * 100 + fiada * 2 + i)
    # Degrau do fogo e a verga de três pedras largas sobre a abertura.
    for i in range(3):
        z0 = -0.5 + i / 3
        z1 = -0.5 + (i + 1) / 3
        bloco((0, 0.7, 0, 0.30, z0 + 0.003, z1 - 0.003), 1300 + i)
        bloco((0, 0.7, 1.17, 1.45, z0 + 0.003, z1 - 0.003), 1400 + i)
    # Soleira de lajes, 6 cm de altura: mantém a passagem de hoje.
    for i in range(4):
        bloco((0.70, 1.06, 0, 0.06, -0.8 + i * 0.4 + 0.003,
               -0.8 + (i + 1) * 0.4 - 0.003), 1500 + i)
    # Fundo e piso pretos: a cavidade continua aberta para +X.
    parte('soot', comum.caixa((0.10, 1.0, 0.87), G(0.05, 0.735, 0), 0.003))
    parte('soot', comum.caixa((0.60, 1.0, 0.02), G(0.40, 0.31, 0), 0.003))
    # Consolo maciço, com o veio no sentido da largura, como os outros
    # modelos Wood049. Superfície superior Y=1,57 recebe o lampião.
    parte('wood', comum.tabua_casa_entre(G(0.41, 1.51, -1), G(0.41, 1.51, 1),
                0.82, 0.12, 1701, G(1, 0, 0), chanfro=0.012, torto=0.0), 0.9)
    # Duas pequenas mísulas de madeira sustentam o balanço do consolo.
    for z in (-0.72, 0.72):
        parte('wood', comum.tabua_casa_entre(G(0.53, 1.20, z), G(0.74, 1.44, z),
                    0.10, 0.08, 1702, G(0, 0, 1), chanfro=0.006, torto=0.0), 0.84)
    # Grade baixa: barras torneadas, aro superior e pés pousados no degrau.
    for i in range(9):
        z = -0.45 + i * 0.1125
        bm = comum.tubo([(-0.18, 0.009), (-0.16, 0.009), (-0.145, 0.006),
                         (0.125, 0.006), (0.145, 0.010), (0.18, 0.010)],
                         lados=8, centro=G(0.73, 0.48, z))
        parte('iron', bm)
    for y in (0.325, 0.66):
        parte('iron', comum.caixa((0.025, 0.92, 0.025), G(0.73, y, 0), 0.004))
    for z in (-0.45, 0.45):
        parte('iron', comum.caixa((0.14, 0.035, 0.025), G(0.68, 0.3225, z), 0.003))
    objetos = [comum.juntar(pecas, nome) for nome, pecas in grupos.items()]
    piso = comum.chao(2.0)
    comum.assar_oclusao(objetos, forca=0.7, distancia=0.18, amostras=32)
    bpy.data.objects.remove(piso)
    cores = {'stone': (0.70, 0.66, 0.59), 'wood': (0.35, 0.25, 0.18),
             'soot': (0.035, 0.029, 0.024), 'iron': (0.075, 0.070, 0.065)}
    for ob in objetos:
        mat = comum.material_simples(ob.name, cores[ob.name], 0.65 if ob.name in ('wood', 'iron') else 0.95)
        if ob.name == 'iron':
            mat.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value = 0.7
        ob.data.materials.append(mat)
    comum.exportar(objetos, caminho)
    comum.previa_casa(objetos, 'lareira', (0.40, 0.77, 0),
                     [('frente', (4, 1.5, 0)), ('tres_quartos', (3.8, 2.7, 3.4))], 2.65)


if __name__ == '__main__':
    main()
