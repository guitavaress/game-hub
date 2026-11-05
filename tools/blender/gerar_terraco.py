# O terraço de pedra seca da fogueira da trilha (Fase 17.7.1): o chão de
# neve batida em cima, as lajes da borda e um "andar" do muro de pedras
# encaixadas, sem argamassa.
#
#   blender --background --factory-startup --python tools/blender/gerar_terraco.py [-- saida.glb]
#
# Sai em assets/models/trail/camp_terrace.glb, com três malhas:
#   snow          o chão de neve batida (raio 1,5 m), no y = 0 da Godot
#   stone_top     as lajes da borda, um pouco acima da neve
#   stone_course  um andar do muro, de 1 m de altura, logo abaixo das lajes
#                 (y de -1,075 a -0,075). A Godot empilha quantos andares a
#                 encosta pedir, cada um girado, para não repetir o desenho.
# As pedras e a neve levam a cor nos vértices (tom e cantos escuros).
# Nada passa de 1,76 m do meio: do lado da trilha o terraço não pode entrar
# na passagem (o check_trail_content confere).

import math
import os
import random
import sys

import bmesh
from mathutils import Vector, noise

sys.path.append(os.path.dirname(__file__))
import comum  # noqa: E402

RAIO_NEVE = 1.5
RAIO_LAJES = 1.6
FUNDO_LAJE = 0.3
TOPO_LAJE = 0.035
ESPESSURA_LAJE = 0.1
RAIO_MURO = 1.6     # o meio do muro
FUNDO_MURO = 0.28   # a espessura do muro (de dentro para fora)
ANDAR = 1.0         # a altura de um andar
TOPO_MURO = -0.075


def neve():
    """O chão do terraço: plano perto da fogueira, levemente pisado perto da borda."""
    bm = bmesh.new()
    aneis, setores = 9, 48
    centro = bm.verts.new((0.0, 0.0, 0.0))
    linhas = []
    for i in range(1, aneis + 1):
        t = i / aneis
        r = RAIO_NEVE * t
        linha = []
        for s in range(setores):
            a = math.tau * s / setores
            p = Vector((math.cos(a) * r, math.sin(a) * r, 0.0))
            fora = max(0.0, (r - 0.95) / (RAIO_NEVE - 0.95))
            z = 0.012 * fora * noise.noise(p * 3.0) + 0.02 * fora * fora
            linha.append(bm.verts.new((p.x, p.y, z)))
        linhas.append(linha)
    for s in range(setores):
        bm.faces.new((centro, linhas[0][s], linhas[0][(s + 1) % setores]))
    for i in range(aneis - 1):
        for s in range(setores):
            s2 = (s + 1) % setores
            bm.faces.new((linhas[i][s], linhas[i + 1][s], linhas[i + 1][s2], linhas[i][s2]))
    # A borda desce para dentro das lajes (sem fresta).
    for v in linhas[-1]:
        v.co.z = -0.04
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    ob = comum.objeto("snow", bm)
    comum.pintar(ob, lambda p, n: (1.0, 1.0, 1.0))
    return ob


def lajes():
    """As lajes da borda: quebradas, de comprimentos diferentes, umas um
    pouco mais altas ou tortas que as outras (assentadas à mão)."""
    rnd = random.Random(21)
    pecas = []
    volta = math.tau * RAIO_LAJES
    andado = rnd.uniform(0.0, 0.2)
    inicio = andado
    while andado < volta + inicio - 0.2:
        comprimento = min(rnd.uniform(0.38, 0.85), volta + inicio - andado - 0.03)
        if comprimento < 0.22:
            break
        angulo = (andado + comprimento / 2.0) / RAIO_LAJES
        tamanho = (comprimento - rnd.uniform(0.015, 0.05), FUNDO_LAJE + rnd.uniform(-0.05, 0.0),
                   ESPESSURA_LAJE + rnd.uniform(-0.025, 0.03))
        bm = comum.pedra(tamanho, 500 + len(pecas), redondeza=0.12, ondulacao=0.1, cortes=rnd.randint(2, 4),
                         funda=(0.05, 0.16), divisoes=2, base=-0.5, chanfro=0.008, cortes_de_lado=True)
        direcao = Vector((math.cos(angulo), math.sin(angulo), 0.0))
        lugar = direcao * (RAIO_LAJES + rnd.uniform(-0.035, 0.0))
        lugar.z = TOPO_LAJE + rnd.uniform(-0.015, 0.02) - tamanho[2] * 0.45
        comum.colocar(bm, lugar, angulo + math.pi / 2 + rnd.uniform(-0.06, 0.06),
                      (rnd.uniform(-0.06, 0.06), rnd.uniform(-0.05, 0.05)))
        pecas.append(comum.objeto("laje%d" % len(pecas), bm))
        andado += comprimento
    ob = comum.reduzir(comum.juntar(pecas, "stone_top"), 0.6)
    comum.pintar(ob, _tom_de_pedra)
    return ob


def andar():
    """Um andar do muro: fiadas de pedras de tamanhos diferentes, com as
    juntas desencontradas de uma fiada para a outra."""
    rnd = random.Random(33)
    pecas = []
    z = TOPO_MURO
    fiada = 0
    while z > TOPO_MURO - ANDAR + 0.05:
        altura = min(rnd.uniform(0.19, 0.3), z - (TOPO_MURO - ANDAR))
        if altura < 0.08:
            break
        volta = math.tau * RAIO_MURO
        andado = rnd.uniform(0.0, 0.3)
        inicio = andado
        while andado < volta + inicio - 0.25:
            comprimento = min(rnd.uniform(0.3, 0.62), volta + inicio - andado - 0.02)
            if comprimento < 0.18:
                break
            meio = andado + comprimento / 2.0
            angulo = meio / RAIO_MURO
            # Um pouco mais altas que a fiada: as pedras se encostam (sem fresta clara).
            tamanho = (comprimento + rnd.uniform(0.0, 0.03), FUNDO_MURO + rnd.uniform(-0.02, 0.02),
                       altura * 1.18)
            bm = comum.pedra(tamanho, 700 + len(pecas), redondeza=0.32, ondulacao=0.07, cortes=rnd.randint(1, 2),
                             funda=(0.03, 0.1), divisoes=1, base=-0.5, chanfro=0.012, cortes_de_lado=True)
            direcao = Vector((math.cos(angulo), math.sin(angulo), 0.0))
            lugar = direcao * (RAIO_MURO + rnd.uniform(-0.02, 0.01))
            lugar.z = z - altura / 2.0
            comum.colocar(bm, lugar, angulo + math.pi / 2, (rnd.uniform(-0.04, 0.04), 0.0))
            pecas.append(comum.objeto("bloco%d" % len(pecas), bm))
            andado += comprimento
        z -= altura
        fiada += 1
    # O miolo atrás das pedras (cascalho escuro): pelas juntas não se vê a neve.
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=RAIO_MURO - 0.08,
                          radius2=RAIO_MURO - 0.08, depth=ANDAR + 0.02)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=(0.0, 0.0, TOPO_MURO - ANDAR / 2.0))
    for f in bm.faces:
        f.smooth = True
    miolo = comum.objeto("miolo", bm)
    comum.pintar(miolo, lambda p, n: (0.25, 0.25, 0.26))
    blocos = comum.juntar(pecas, "stone_course_blocos")
    comum.pintar(blocos, _tom_de_pedra)
    return comum.juntar([blocos, miolo], "stone_course")


def _tom_de_pedra(p, n):
    """Cada pedra num tom (ruído grande), umas mais quentes, outras mais frias."""
    base = 1.25 + 0.25 * noise.noise(p * 2.6 + Vector((3, 1, 4)))
    quente = 0.05 * noise.noise(p * 1.7 + Vector((9, 2, 6)))
    return (base * (1.0 + quente), base, base * (1.0 - quente))


def main():
    caminho = comum.saida("camp_terrace")
    comum.iniciar()
    piso = neve()
    topo = lajes()
    muro = andar()
    # Os cantos escuros: as juntas entre as pedras e a neve junto das lajes.
    comum.assar_oclusao([piso, topo, muro], forca=0.85, distancia=0.2)
    piso.data.materials.append(comum.material_simples("snow", (0.8, 0.85, 0.9)))
    topo.data.materials.append(comum.material_simples("stone", (0.55, 0.57, 0.6)))
    muro.data.materials.append(topo.data.materials[0])
    alcance = max(Vector((v.co.x, v.co.y)).length for ob in (topo, muro) for v in ob.data.vertices)
    print("Maior raio: %.3f m" % alcance)
    comum.exportar([piso, topo, muro], caminho)


main()
