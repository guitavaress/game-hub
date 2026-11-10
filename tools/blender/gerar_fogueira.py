# A fogueira da trilha (Fase 17.7.1): o anel de pedras, a cama de cinza e
# terra queimada, a lenha rachada em pirâmide (queimada por dentro), duas
# toras cruzadas embaixo, gravetos e a brasa.
#
#   blender --background --factory-startup --python tools/blender/gerar_fogueira.py [-- saida.glb]
#
# Sai em assets/models/trail/campfire.glb, com quatro malhas (uma por
# material, um desenho cada na Godot):
#   stone   o anel de pedras (cor nos vértices: tom, fuligem e cantos escuros)
#   ash     a cama de cinza, a terra queimada e os pedaços de carvão (cor nos vértices)
#   wood    a lenha e as toras (textura assada: veio, casca, carvão)
#   embers  a brasa (textura assada, com o brilho das rachas em outra textura)
# O chão é o y = 0 da Godot (o chão do terraço). As chamas e a luz ficam na
# Godot (campfire_flame.gdshader e a OmniLight do Campfire).

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.append(os.path.dirname(__file__))
import comum  # noqa: E402
from comum import G  # noqa: E402

RAIO_ANEL = 0.55
PEDRAS = 12
TOPO_PIRAMIDE = G(0.02, 0.64, -0.01)


def anel_de_pedras():
    rnd = random.Random(7)
    pecas = []
    for k in range(PEDRAS):
        angulo = math.tau * k / PEDRAS + 0.12 * math.sin(k * 1.7)
        tamanho = (rnd.uniform(0.2, 0.28), rnd.uniform(0.17, 0.23), rnd.uniform(0.13, 0.2))
        bm = comum.pedra(tamanho, 40 + k, redondeza=rnd.uniform(0.55, 0.8), ondulacao=0.16,
                         cortes=rnd.randint(1, 3), funda=(0.05, 0.18), divisoes=3, base=-0.28)
        direcao = comum.godot_dir(angulo)
        lugar = direcao * (RAIO_ANEL + rnd.uniform(-0.03, 0.03))
        lugar.z = tamanho[2] * 0.2 - 0.02
        comum.colocar(bm, lugar, math.atan2(direcao.y, direcao.x) + math.pi / 2 + rnd.uniform(-0.3, 0.3),
                      (rnd.uniform(-0.12, 0.12), rnd.uniform(-0.15, 0.05)))
        pecas.append(comum.objeto("pedra%d" % k, bm))
    ob = comum.reduzir(comum.juntar(pecas, "stone"), 0.6)

    def cor(p, n):
        # Tom de cada pedra (ruído grande) e a fuligem: o lado de dentro e o
        # alto, virados para o fogo, ficam pretos.
        base = 1.2 + 0.2 * noise.noise(p * 3.0)
        frio = 0.03 * noise.noise(p * 2.0 + Vector((7, 7, 7)))
        para_dentro = Vector((-p.x, -p.y, 0.0)).normalized()
        dentro = max(0.0, n.dot(para_dentro)) * 0.75 + max(0.0, n.z) * 0.35
        fuligem = 1.0 - 0.78 * min(1.0, dentro) * (0.65 + 0.35 * noise.noise(p * 14.0))
        return (base * fuligem * (1.0 - frio), base * fuligem, base * fuligem * (1.0 + frio))
    comum.pintar(ob, cor)
    return ob


def cama_de_cinza():
    """Um disco irregular de terra queimada e cinza, mais alto no meio."""
    bm = bmesh.new()
    aneis, setores = 12, 40
    centro = bm.verts.new((0.0, 0.0, 0.03))
    linhas = []
    for i in range(1, aneis + 1):
        t = i / aneis
        linha = []
        for s in range(setores):
            a = math.tau * s / setores
            borda = 0.84 + 0.07 * noise.noise(Vector((math.cos(a) * 1.8, math.sin(a) * 1.8, 3.0)))
            r = t * borda
            z = 0.028 * (1.0 - t * t) + 0.006 * noise.noise(Vector((math.cos(a) * r * 8, math.sin(a) * r * 8, 1.0)))
            if i == aneis:
                z = -0.004
            linha.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        linhas.append(linha)
    for s in range(setores):
        bm.faces.new((centro, linhas[0][s], linhas[0][(s + 1) % setores]))
    for i in range(aneis - 1):
        for s in range(setores):
            s2 = (s + 1) % setores
            bm.faces.new((linhas[i][s], linhas[i + 1][s], linhas[i + 1][s2], linhas[i][s2]))
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    disco = comum.objeto("cinza", bm)

    def cor(p, n):
        # Do meio para fora: carvão, cinza clara em manchas, terra queimada.
        r = math.hypot(p.x, p.y)
        mancha = 0.5 + 0.5 * noise.noise(p * 9.0)
        cinza = 0.05 + 0.3 * max(0.0, mancha - 0.35) * (1.0 if r < 0.5 else 0.5)
        terra = (0.1, 0.082, 0.065)
        meio = (0.03 + cinza, 0.027 + cinza * 0.97, 0.025 + cinza * 0.93)
        t = min(1.0, max(0.0, (r - 0.48) / 0.3))
        return tuple(meio[i] * (1 - t) + terra[i] * t for i in range(3))
    comum.pintar(disco, cor)
    pecas = [disco]
    # Pedaços de carvão espalhados (dentro e um pouco fora do anel), pretos.
    rnd = random.Random(11)
    for k in range(26):
        a = rnd.uniform(0, math.tau)
        r = rnd.choice([rnd.uniform(0.1, 0.42), rnd.uniform(0.66, 0.8)])
        tamanho = (rnd.uniform(0.025, 0.06), rnd.uniform(0.02, 0.05), rnd.uniform(0.015, 0.03))
        bm = comum.pedra(tamanho, 300 + k, redondeza=0.3, ondulacao=0.2, cortes=3, funda=(0.1, 0.3),
                         divisoes=1, chanfro=0.0)
        comum.colocar(bm, Vector((math.cos(a) * r, math.sin(a) * r, 0.012 + 0.02 * (1 - r))), rnd.uniform(0, 6))
        pedaco = comum.objeto("carvao%d" % k, bm)
        comum.pintar(pedaco, lambda p, n: (0.022, 0.02, 0.019))
        pecas.append(pedaco)
    return comum.juntar(pecas, "ash")


def lenha():
    rnd = random.Random(5)
    pecas = []
    # Duas toras deitadas e cruzadas embaixo (como na 17.7).
    for k in range(2):
        angulo = k * math.pi / 2.0 + 0.4
        direcao = comum.godot_dir(angulo)
        bm = comum.tora(0.74, 0.058, 60 + k, lados=11)
        comum.colocar(bm, Vector((0, 0, 0.055 + k * 0.095)), math.atan2(direcao.y, direcao.x),
                      (rnd.uniform(0, 6), 0.0))
        pecas.append(comum.objeto("tora%d" % k, bm))
    # A pirâmide de achas rachadas, encostando no alto.
    for k in range(6):
        angulo = math.tau * k / 6 + 0.3
        direcao = comum.godot_dir(angulo)
        base = direcao * (0.34 + 0.03 * math.sin(k * 2.9)) + Vector((0, 0, 0.04))
        topo = TOPO_PIRAMIDE + direcao * 0.05
        comprimento = (topo - base).length + 0.1
        bm = comum.lenha(comprimento, rnd.uniform(0.06, 0.075), 80 + k)
        # x da acha = do pé ao topo; a casca virada para fora.
        eixo = (topo - base).normalized()
        giro = eixo.to_track_quat('X', 'Z').to_matrix().to_4x4()
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0),
                         matrix=Matrix.Rotation(rnd.uniform(-0.6, 0.6) + math.pi, 3, 'X'))
        bmesh.ops.transform(bm, matrix=giro, verts=bm.verts[:])
        bmesh.ops.translate(bm, verts=bm.verts[:], vec=(base + topo) / 2.0)
        pecas.append(comum.objeto("acha%d" % k, bm))
    # Gravetos finos dentro da pirâmide.
    for k in range(5):
        angulo = math.tau * k / 5 + 0.9
        direcao = comum.godot_dir(angulo)
        base = direcao * 0.2 + Vector((0, 0, 0.05))
        topo = TOPO_PIRAMIDE + Vector((0, 0, -0.18)) - direcao * 0.04
        bm = comum.tora((topo - base).length, 0.014, 90 + k, lados=6, chanfro=0.002, entorta=0.006)
        giro = (topo - base).normalized().to_track_quat('X', 'Z').to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=giro, verts=bm.verts[:])
        bmesh.ops.translate(bm, verts=bm.verts[:], vec=(base + topo) / 2.0)
        pecas.append(comum.objeto("graveto%d" % k, bm))
    ob = comum.juntar(pecas, "wood")

    def carvao(p, n):
        # Queimada embaixo (na brasa), por dentro da pirâmide e na ponta (onde
        # a chama lambe); por fora e no meio, a madeira ainda aparece.
        baixo = max(0.0, 1.0 - p.z / 0.32)
        para_dentro = Vector((-p.x, -p.y, 0.0))
        dentro = max(0.0, n.dot(para_dentro.normalized())) if para_dentro.length > 0.01 else 1.0
        ponta = max(0.0, (p.z - 0.42) / 0.2)
        return 0.9 * baixo + 0.8 * dentro + 0.5 * ponta + 0.12 * noise.noise(p * 12.0)
    comum.queimar(ob, carvao)
    return ob


def brasa():
    """Um monte baixo de brasa e pedaços em volta, no meio do anel."""
    rnd = random.Random(13)
    pecas = []
    bm = comum.pedra((0.5, 0.48, 0.09), 60, redondeza=0.9, ondulacao=0.3, cortes=0, divisoes=3, base=-0.2)
    comum.colocar(bm, Vector((0, 0, 0.022)))
    pecas.append(comum.objeto("monte", bm))
    for k in range(34):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.uniform(0, 1)) * 0.3
        tamanho = (rnd.uniform(0.035, 0.08), rnd.uniform(0.03, 0.07), rnd.uniform(0.02, 0.045))
        bm = comum.pedra(tamanho, 400 + k, redondeza=0.35, ondulacao=0.2, cortes=3, funda=(0.1, 0.3),
                         divisoes=1, chanfro=0.0)
        altura = 0.035 + 0.04 * (1.0 - r / 0.3)
        comum.colocar(bm, Vector((math.cos(a) * r, math.sin(a) * r, altura)), rnd.uniform(0, 6),
                      (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4)))
        pecas.append(comum.objeto("brasa%d" % k, bm))
    return comum.juntar(pecas, "embers")


def material_brasa():
    """Carvão preto com cinza por cima; as rachas e os vãos brilham (laranja)."""
    mat = bpy.data.materials.new("brasa_procedural")
    arv = mat.node_tree
    bsdf = arv.nodes["Principled BSDF"]
    L = arv.links.new
    geo = arv.nodes.new("ShaderNodeNewGeometry")
    vor = arv.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = 'DISTANCE_TO_EDGE'
    vor.inputs["Scale"].default_value = 38.0
    L(geo.outputs["Position"], vor.inputs["Vector"])
    racha = arv.nodes.new("ShaderNodeMapRange")
    L(vor.outputs["Distance"], racha.inputs["Value"])
    racha.inputs["From Min"].default_value = 0.0
    racha.inputs["From Max"].default_value = 0.08
    racha.inputs["To Min"].default_value = 1.0
    racha.inputs["To Max"].default_value = 0.0
    vao = arv.nodes.new("ShaderNodeAmbientOcclusion")
    vao.inputs["Distance"].default_value = 0.05
    fundo = arv.nodes.new("ShaderNodeMapRange")
    L(vao.outputs["AO"], fundo.inputs["Value"])
    fundo.inputs["From Min"].default_value = 0.25
    fundo.inputs["From Max"].default_value = 0.85
    fundo.inputs["To Min"].default_value = 1.0
    fundo.inputs["To Max"].default_value = 0.0
    soma = arv.nodes.new("ShaderNodeMath")
    soma.operation = 'MAXIMUM'
    L(racha.outputs[0], soma.inputs[0])
    L(fundo.outputs[0], soma.inputs[1])
    ruido = arv.nodes.new("ShaderNodeTexNoise")
    ruido.inputs["Scale"].default_value = 9.0
    L(geo.outputs["Position"], ruido.inputs["Vector"])
    calor = arv.nodes.new("ShaderNodeMath")
    calor.operation = 'MULTIPLY'
    L(soma.outputs[0], calor.inputs[0])
    L(ruido.outputs["Fac"], calor.inputs[1])
    rampa = arv.nodes.new("ShaderNodeValToRGB")
    L(calor.outputs[0], rampa.inputs["Fac"])
    rampa.color_ramp.elements[0].position = 0.08
    rampa.color_ramp.elements[0].color = (0, 0, 0, 1)
    rampa.color_ramp.elements[1].position = 0.6
    rampa.color_ramp.elements[1].color = (1.0, 0.42, 0.08, 1)
    meio = rampa.color_ramp.elements.new(0.3)
    meio.color = (0.45, 0.06, 0.01, 1)
    L(rampa.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    # A cor: carvão, com cinza clara nas faces de cima.
    cima = arv.nodes.new("ShaderNodeSeparateXYZ")
    L(geo.outputs["Normal"], cima.inputs[0])
    cinza = arv.nodes.new("ShaderNodeMapRange")
    L(cima.outputs[2], cinza.inputs["Value"])
    cinza.inputs["From Min"].default_value = 0.5
    cinza.inputs["From Max"].default_value = 0.95
    ruido_cinza = arv.nodes.new("ShaderNodeMath")
    ruido_cinza.operation = 'MULTIPLY'
    L(cinza.outputs[0], ruido_cinza.inputs[0])
    L(ruido.outputs["Fac"], ruido_cinza.inputs[1])
    cor = arv.nodes.new("ShaderNodeMix")
    cor.data_type = 'RGBA'
    L(ruido_cinza.outputs[0], cor.inputs["Factor"])
    comum.cor_entrada(cor, "A").default_value = (0.02, 0.016, 0.014, 1)
    comum.cor_entrada(cor, "B").default_value = (0.3, 0.28, 0.26, 1)
    L(comum.cor_saida(cor), bsdf.inputs["Base Color"])
    return mat


def main():
    caminho = comum.saida("campfire")
    comum.iniciar()
    chao = comum.chao(3.0, 0.0)
    pedras = anel_de_pedras()
    cinza = cama_de_cinza()
    madeira = lenha()
    monte = brasa()
    # A oclusão nos vértices (as pedras e a cinza): a lenha e o chão fazem sombra.
    comum.assar_oclusao([pedras, cinza], forca=0.8, distancia=0.25)
    pedras.data.materials.append(comum.material_simples("stone", (0.55, 0.57, 0.6)))
    cinza.data.materials.append(comum.material_simples("ash", (0.1, 0.09, 0.08), 1.0))
    # A madeira e a brasa: textura assada.
    comum.uv_para_assar(madeira)
    mat = comum.material_madeira("lenha_procedural", clara=(0.2, 0.13, 0.075), escura=(0.085, 0.05, 0.028),
                                 cinza=0.15, aneis=160.0, gasto=0.3)
    madeira.data.materials.append(mat)
    comum.assar_textura(madeira, mat, 512, "wood")
    comum.uv_para_assar(monte)
    mat_brasa = material_brasa()
    monte.data.materials.append(mat_brasa)
    comum.assar_textura(monte, mat_brasa, 256, "embers", emissao=True)
    bpy.data.objects.remove(chao)
    comum.exportar([pedras, cinza, madeira, monte], caminho)


main()
