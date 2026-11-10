# O abrigo de madeira do mirante (Fase 17.8): quatro pilares, as vigas, a
# tesoura aparente na frente, o telhado de duas águas em tábuas sobrepostas
# com neve por cima, a parede do fundo em tábuas de pé, meias-paredes dos
# lados, um banco por dentro, a vara de ferro onde a Godot pendura a
# tapeçaria do seu RPG mais jogado e os dois braços de ferro das lanternas.
#
#   blender --background --factory-startup --python tools/blender/gerar_abrigo.py [-- saida.glb]
#
# Sai em assets/models/lookout/shelter.glb, uma malha por material: "wood"
# (a Wood049 na Godot), "snow" (a Snow010A) e "iron". No espaço da Godot: a
# origem no chão, no meio; a frente aberta para +Z; 3,9 m de largura (x) com
# o beiral, 3,2 m de fundo (z) e a cumeeira a 3,2 m. As medidas que a Godot
# usa (LookoutDeck): os ganchos das lanternas em (±1,6; 1,97; 1,43) e a
# tapeçaria de 1,0 × 1,5 m pendurada na vara, em z = -0,95, de y = 2,52 a 1,02.

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
import comum  # noqa: E402

G = comum.G
PX = 1.6        # x dos pilares
PZ = 1.1        # z dos pilares
POST = 0.16
EAVE = 2.25     # topo dos pilares
PLATE = 0.14    # altura da viga de cima (frechal)
RIDGE = 3.1     # a linha de cima dos caibros, na cumeeira
BACK = -PZ - POST / 2.0  # a face de trás dos pilares de trás

rnd = random.Random(17)
madeira = []
ferro = []


def linha_do_telhado(x):
    """A altura da linha de cima dos caibros em x (o telhado desce para os lados)."""
    inclinacao = (RIDGE - (EAVE + PLATE)) / PX
    return RIDGE - abs(x) * inclinacao


def junta(bm, tom=None):
    ob = comum.objeto("peca_%d" % len(madeira), bm)
    t = tom if tom is not None else rnd.uniform(0.82, 1.1)
    quente = rnd.uniform(-0.03, 0.05)
    comum.pintar(ob, lambda p, n: (t * (1 + quente), t, t * (1 - quente)))
    madeira.append(ob)


def tabua(a, b, largura, espessura, lado=None, tom=None, **opcoes):
    """Uma tábua de "a" a "b" (posições da Godot); "lado" (Godot) diz para onde
    vai a largura."""
    lado_b = G(*lado) if lado is not None else None
    semente = rnd.randint(0, 99999)
    junta(comum.tabua_entre(G(*a), G(*b), largura, espessura, semente, lado_b, **opcoes), tom)


def peca_de_ferro(bm):
    ferro.append(comum.objeto("ferro_%d" % len(ferro), bm))


def estrutura():
    # Os pilares (um pouco mais escuros: madeira grossa, mais velha).
    for x in (-PX, PX):
        for z in (-PZ, PZ):
            tabua((x, 0.0, z), (x, EAVE, z), POST, POST, lado=(1, 0, 0), tom=rnd.uniform(0.7, 0.85),
                  chanfro=0.012, torto=0.0)
    # Os frechais, de frente a trás em cima dos pilares, passando um pouco.
    for x in (-PX, PX):
        tabua((x, EAVE + PLATE / 2.0, -PZ - 0.42), (x, EAVE + PLATE / 2.0, PZ + 0.42), POST, PLATE,
              lado=(1, 0, 0), tom=0.78, chanfro=0.01)
    # As vigas de amarração, de um pilar ao outro (frente e fundo).
    for z in (-PZ, PZ):
        tabua((-PX - 0.12, EAVE - 0.08, z), (PX + 0.12, EAVE - 0.08, z), 0.14, 0.16, lado=(0, 1, 0),
              tom=0.8, chanfro=0.01)
    # As mãos-francesas dos pilares da frente (para a frente e para o lado).
    for x in (-PX, PX):
        s = 1.0 if x > 0 else -1.0
        tabua((x, 1.72, PZ), (x - s * 0.5, EAVE - 0.14, PZ), 0.09, 0.08, lado=(0, 0, 1), chanfro=0.006)
        for z in (-PZ, PZ):
            t = 1.0 if z > 0 else -1.0
            tabua((x, 1.72, z), (x, EAVE - 0.02, z - t * 0.5), 0.09, 0.08, lado=(1, 0, 0), chanfro=0.006)
    # As soleiras dos lados e do fundo.
    for x in (-PX, PX):
        tabua((x, 0.06, -PZ - 0.08), (x, 0.06, PZ + 0.08), 0.13, 0.12, lado=(1, 0, 0), tom=0.72)
    tabua((-PX, 0.06, -PZ), (PX, 0.06, -PZ), 0.13, 0.12, lado=(0, 0, 1), tom=0.72)


def tesoura(z):
    """A tesoura da frente (aparente) e a do fundo: o pendural e as escoras."""
    tabua((0.0, EAVE, z), (0.0, RIDGE - 0.02, z), 0.12, 0.12, lado=(1, 0, 0), tom=0.8)
    for s in (-1.0, 1.0):
        x = s * 0.9
        tabua((0.0, EAVE + 0.2, z), (x, linha_do_telhado(x) - 0.13, z), 0.1, 0.09, lado=(0, 0, 1))


def telhado():
    inclinacao = (RIDGE - (EAVE + PLATE)) / PX
    angulo = math.atan(inclinacao)
    borda = 1.98  # o beiral (x)
    for s in (-1.0, 1.0):
        # Os caibros, de cada lado, do beiral à cumeeira.
        for z in (-PZ - 0.36, -PZ, -0.37, 0.37, PZ, PZ + 0.36):
            baixo = (s * borda, linha_do_telhado(borda) - 0.075, z)
            cima = (0.0, RIDGE - 0.075, z)
            tabua(baixo, cima, 0.14, 0.07, lado=(0, 1, 0), tom=0.8, chanfro=0.006)
        # As tábuas do telhado, sobrepostas como escamas (a de baixo por cima).
        comprimento = math.hypot(borda, borda * inclinacao)
        passo = 0.2
        k = 0
        d = 0.06
        while d < comprimento + 0.02:
            x = s * (borda - d * math.cos(angulo))
            y = linha_do_telhado(abs(x)) + 0.018 + 0.012 * (k % 2)
            a = (x, y, -PZ - 0.5)
            b = (x, y, PZ + 0.5)
            normal = (s * math.sin(angulo), math.cos(angulo), 0.0)
            # A largura corre ao longo da água (descendo para o beiral).
            descida = (s * math.cos(angulo), -math.sin(angulo) - 0.06, 0.0)
            semente = rnd.randint(0, 99999)
            bm = comum.tabua_entre(G(*a), G(*b), 0.24, 0.025, semente, G(*descida), chanfro=0.005, torto=0.006)
            junta(bm, rnd.uniform(0.62, 0.95))
            d += passo
            k += 1
    # A cumeeira: duas tábuas que se encontram em cima.
    for s in (-1.0, 1.0):
        a = (s * 0.06, RIDGE + 0.06, -PZ - 0.52)
        b = (s * 0.06, RIDGE + 0.06, PZ + 0.52)
        lado = (s * math.cos(angulo), -math.sin(angulo), 0.0)
        tabua(a, b, 0.16, 0.035, lado=lado, tom=0.7)


def neve():
    """A neve nas duas águas: uma placa macia por cima das tábuas, mais grossa
    no meio e com a beirada arredondada."""
    inclinacao = (RIDGE - (EAVE + PLATE)) / PX
    angulo = math.atan(inclinacao)
    pecas = []
    for k, s in enumerate((-1.0, 1.0)):
        # Ao longo da água, de 6 cm além do beiral até perto da cumeeira.
        largura = 2.05
        bm = comum.pedra((largura, 3.12, 0.15), 700 + k, redondeza=0.3, ondulacao=0.05, cortes=0,
                         divisoes=6, base=-0.5, chanfro=0.0)
        meio = 0.965
        x = s * (1.98 - meio * math.cos(angulo))
        y = linha_do_telhado(abs(x)) + 0.11
        # O x da placa desce a água; o y dela é o z da Godot (frente e fundo).
        descida = Vector((s * math.cos(angulo), 0.0, -math.sin(angulo)))
        comum.orientar(bm, descida, Vector((0.0, s, 0.0)), G(x, y, 0.0))
        ob = comum.objeto("neve_%d" % k, bm)
        comum.pintar(ob, lambda p, n: (1.0, 1.0, 1.0))
        pecas.append(ob)
    return pecas


def parede_do_fundo():
    """Tábuas de pé por fora dos pilares de trás, do chão até o telhado."""
    largura = 0.2
    x = -PX - 0.06
    while x < PX + 0.07:
        centro = x + largura / 2.0
        topo = linha_do_telhado(min(abs(centro), PX)) - 0.08
        semente = rnd.randint(0, 99999)
        bm = comum.tabua_entre(G(centro, 0.02, BACK - 0.016), G(centro, topo, BACK - 0.016),
                               largura - 0.008, 0.03, semente, G(1, 0, 0), chanfro=0.005, torto=0.003)
        # O topo acompanha a água do telhado.
        inclinacao = (RIDGE - (EAVE + PLATE)) / PX
        for v in bm.verts:
            if v.co.z > topo - 0.03:
                v.co.z += (abs(centro) - abs(v.co.x)) * inclinacao * (1.0 if abs(centro) < PX else 0.0)
        bm.normal_update()
        junta(bm, rnd.uniform(0.7, 1.0))
        x += largura


def meias_paredes():
    """Os lados: cinco tábuas deitadas até 1,1 m e um peitoril por cima."""
    for s in (-1.0, 1.0):
        x = s * (PX + POST / 2.0 + 0.016)
        for k in range(5):
            y = 0.14 + k * 0.205
            tabua((x, y, -PZ - 0.08), (x, y, PZ + 0.08), 0.198, 0.03, lado=(0, 1, 0),
                  tom=rnd.uniform(0.72, 1.0), torto=0.004)
        tabua((s * (PX + 0.03), 1.16, -PZ - 0.1), (s * (PX + 0.03), 1.16, PZ + 0.1), 0.24, 0.045,
              lado=(1, 0, 0), tom=0.85)


def banco():
    """O banco por dentro, encostado no fundo."""
    for z in (-0.66, -0.84):
        tabua((-1.35, 0.455, z), (1.35, 0.455, z), 0.17, 0.04, lado=(0, 0, 1), torto=0.003)
    for x in (-1.15, 0.0, 1.15):
        for z in (-0.62, -0.9):
            tabua((x, 0.0, z), (x, 0.435, z), 0.06, 0.06, lado=(1, 0, 0), tom=0.8, torto=0.0)
        tabua((x, 0.4, -0.55), (x, 0.4, -0.97), 0.06, 0.05, lado=(0, 1, 0), tom=0.8, torto=0.0)


def ferragens():
    # A vara da tapeçaria, na frente da viga de amarração do fundo.
    vara_z = -0.95
    vara_y = 2.55
    peca_de_ferro(comum.tubo([(-0.62, 0.012), (0.62, 0.012)], lados=12, eixo=Vector((1, 0, 0)),
                             centro=G(0.0, vara_y, vara_z)))
    for s in (-1.0, 1.0):
        # As pontas (bolinhas) e os suportes até a parede.
        bm = comum.cilindro(0.022, 0.022, 0.04, lados=12)
        bmesh.ops.translate(bm, verts=bm.verts[:], vec=G(s * 0.64, vara_y, vara_z))
        peca_de_ferro(bm)
        peca_de_ferro(comum.caixa((0.018, abs(BACK - vara_z) - 0.02, 0.018), G(s * 0.52, vara_y, (BACK + vara_z) / 2.0), 0.002))
    # Os braços das lanternas, saindo dos pilares da frente.
    for s in (-1.0, 1.0):
        x = s * PX
        frente = PZ + POST / 2.0
        peca_de_ferro(comum.caixa((0.022, 0.30, 0.022), G(x, 2.02, frente + 0.15), 0.003))
        # A escora de baixo, em diagonal.
        bm = comum.caixa((0.24, 0.016, 0.016), (0.0, 0.0, 0.0), 0.002)
        comum.orientar(bm, G(0.0, 0.16, 0.16), G(1, 0, 0), G(x, 1.92, frente + 0.09))
        peca_de_ferro(bm)
        # O gancho na ponta.
        bm = comum.cilindro(0.005, 0.005, 0.05, lados=8)
        bmesh.ops.translate(bm, verts=bm.verts[:], vec=G(x, 1.995, 1.43))
        peca_de_ferro(bm)
        # A chapa presa no pilar.
        peca_de_ferro(comum.caixa((0.09, 0.012, 0.14), G(x, 2.0, frente + 0.006), 0.002))


def main():
    caminho = comum.saida("shelter", "lookout")
    comum.iniciar()
    estrutura()
    tesoura(PZ)
    tesoura(-PZ + 0.02)
    telhado()
    parede_do_fundo()
    meias_paredes()
    banco()
    ferragens()
    neves = neve()
    wood = comum.juntar(madeira, "wood")
    iron = comum.juntar(ferro, "iron")
    comum.pintar(iron, lambda p, n: (1.0, 1.0, 1.0))
    snow = comum.juntar(neves, "snow")
    piso = comum.chao(3.5, 0.0)
    comum.assar_oclusao([wood, iron, snow], forca=0.8, distancia=0.45)
    bpy.data.objects.remove(piso)
    wood.data.materials.append(comum.material_simples("wood", (0.45, 0.36, 0.28), 0.85))
    iron.data.materials.append(comum.material_simples("iron", (0.1, 0.1, 0.1), 0.6))
    snow.data.materials.append(comum.material_simples("snow", (0.9, 0.92, 0.95), 0.9))
    comum.exportar([wood, iron, snow], caminho)


main()
