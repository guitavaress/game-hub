# As árvores do hub (Fase 19.2): uma função por espécie. Nesta subetapa, só o
# pinheiro (o do bairro do RPG e da vista da cabana).
#
#   blender --background --factory-startup --python tools/blender/gerar_arvore.py \
#       [-- <espécie> [saida.glb] [pasta das prévias]]
#
# Sem argumentos, gera o pinheiro em assets/models/trees/pine.glb. Com a pasta
# das prévias, renderiza também duas vistas (de perto e de longe), só para
# conferir a forma sem abrir a Godot (as prévias não entram no .glb).
#
# O .glb tem duas malhas (uma por material, um desenho cada na Godot):
#   bark    o tronco e os galhos (a casca do comum.material_madeira, assada
#           numa textura alta e estreita: o UV dá a volta no tronco)
#   leaves  os "cartões" de agulhas: retângulos com a foto de um raminho de
#           abeto (feito aqui mesmo, de agulhas de verdade, e fotografado de
#           cima com fundo transparente). A cor dos vértices escurece o miolo
#           da copa (a sombra de dentro), e a Godot multiplica pela textura.
# A origem é o pé do tronco, no chão; o pinheiro tem ALTURA m. O vento, a
# troca pela impostora de longe e a escala de cada cópia ficam na Godot
# (worlds/city/tree_model.gd e tree_model.gdshader).

import math
import os
import random
import sys
import tempfile

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.append(os.path.dirname(__file__))
import comum  # noqa: E402

# --- Pinheiro: as medidas -------------------------------------------------------
ALTURA = 10.0           # m, do chão à ponta
RAIO_BASE = 0.2         # m, o tronco logo acima das raízes
RAIO_PONTA = 0.02
COPA_BAIXO = 1.7        # m, onde começam os galhos vivos
COPA_RAIO = 2.5         # m, o raio da copa embaixo
ANDAR = 0.4             # m entre dois verticilos (os "andares" de galhos)
# A casca: o UV sobe CASCA_METROS por volta da textura (o tronco de cima repete).
CASCA_METROS = 5.0
# A foto do raminho: 512 x 512, com duas variações (metade de baixo e de cima).
FOTO = 512


def argumentos_da_arvore():
    """(espécie, saída, pasta das prévias), pelos argumentos depois de "--"."""
    args = comum.argumentos()
    especie = args[0] if args else "pinheiro"
    arquivo = {"pinheiro": "pine"}.get(especie)
    if arquivo is None:
        raise SystemExit("Espécie desconhecida: %s (há: pinheiro)" % especie)
    saida = args[1] if len(args) > 1 else os.path.join(comum.PASTA_GRUPOS, "trees", arquivo + ".glb")
    os.makedirs(os.path.dirname(os.path.abspath(saida)), exist_ok=True)
    previas = args[2] if len(args) > 2 else ""
    return especie, os.path.abspath(saida), previas


# --- Peças ----------------------------------------------------------------------

def raio_da_copa(z):
    """O raio da copa na altura z: um cone um pouco cheio (expoente < 1)."""
    if z <= COPA_BAIXO:
        return COPA_RAIO
    t = max(0.0, (ALTURA - z) / (ALTURA - COPA_BAIXO))
    return COPA_RAIO * t ** 0.85


def eixo(z):
    """O meio do tronco na altura z: quase reto, com uma curva leve."""
    t = z / ALTURA
    return Vector((0.06 * noise.noise(Vector((t * 2.0, 1.0, 0.0))) * t,
                   0.06 * noise.noise(Vector((t * 2.0, 7.0, 0.0))) * t, z))


def raio_do_tronco(z):
    t = max(0.0, min(1.0, z / ALTURA))
    return RAIO_PONTA + (RAIO_BASE - RAIO_PONTA) * (1.0 - t) ** 1.3


def tronco(semente=3, lados=14):
    """O tronco num bmesh, com as raízes que alargam o pé, o veio da casca
    (gA/gB, para o comum.material_madeira) e o UV "bake" cilíndrico."""
    rnd = random.Random(semente)
    bm = bmesh.new()
    ga = bm.loops.layers.uv.new("gA")
    gb = bm.loops.layers.uv.new("gB")
    uv = bm.loops.layers.uv.new("bake")
    alturas = [-0.15, 0.0, 0.08, 0.18, 0.3, 0.45, 0.65, 0.9, 1.2, 1.6]
    z = 1.6
    while z < ALTURA - 0.3:
        z += 0.45 if z < CASCA_METROS else 0.7
        alturas.append(min(z, ALTURA - 0.3))
    alturas.append(ALTURA - 0.05)
    fase = rnd.uniform(0, math.tau)
    aneis = []
    for z in alturas:
        anel = []
        meio = eixo(max(z, 0.0))
        r = raio_do_tronco(max(z, 0.0))
        # As raízes: cinco "pés" que alargam o tronco perto do chão.
        pe = math.exp(-max(z, 0.0) / 0.32)
        for k in range(lados):
            a = math.tau * k / lados
            lobo = max(0.0, math.cos(5 * a + fase)) ** 2
            casca = 1.0 + 0.04 * noise.noise(Vector((math.cos(a) * 3, math.sin(a) * 3, z * 2.0)))
            rr = r * casca * (1.0 + pe * (0.35 + 0.9 * lobo))
            anel.append(bm.verts.new(meio + Vector((math.cos(a) * rr, math.sin(a) * rr, 0.0))))
        aneis.append(anel)
    for i in range(len(aneis) - 1):
        for k in range(lados):
            k2 = (k + 1) % lados
            f = bm.faces.new((aneis[i][k], aneis[i][k2], aneis[i + 1][k2], aneis[i + 1][k]))
            f.smooth = True
            for canto, (kk, ii) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                p = canto.vert.co
                # Veio: ao longo = z; "através" = x e y (escala 0,45: as placas
                # da casca do pinheiro são maiores que as da lenha).
                canto[ga].uv = (p.z * 0.45, p.x * 0.45)
                canto[gb].uv = (p.y * 0.45, comum.CASCA)
                canto[uv].uv = (kk / lados, alturas[ii] / CASCA_METROS)
    # A ponta fecha num cone curto.
    ponta = bm.verts.new(eixo(ALTURA))
    for k in range(lados):
        k2 = (k + 1) % lados
        f = bm.faces.new((aneis[-1][k], aneis[-1][k2], ponta))
        f.smooth = True
        for canto, uu in zip(f.loops, (k / lados, (k + 1) / lados, (k + 0.5) / lados)):
            p = canto.vert.co
            canto[ga].uv = (p.z * 0.45, p.x * 0.45)
            canto[gb].uv = (p.y * 0.45, comum.CASCA)
            canto[uv].uv = (uu, alturas[-1] / CASCA_METROS)
    bm.normal_update()
    return bm


def tubo_por(bm, pontos, raios, lados, uv_base):
    """Um galho (tubo fino) ao longo de "pontos", com o raio de cada ponto.
    O UV cai numa faixa estreita da casca do tronco ("uv_base" = (u, v))."""
    ga = bm.loops.layers.uv["gA"]
    gb = bm.loops.layers.uv["gB"]
    uv = bm.loops.layers.uv["bake"]
    aneis = []
    comprimento = 0.0
    passos = [0.0]
    for i in range(1, len(pontos)):
        comprimento += (pontos[i] - pontos[i - 1]).length
        passos.append(comprimento)
    for i, p in enumerate(pontos):
        t = (pontos[min(i + 1, len(pontos) - 1)] - pontos[max(i - 1, 0)]).normalized()
        lado = t.cross(Vector((0, 0, 1)))
        if lado.length < 0.01:
            lado = Vector((1, 0, 0))
        lado.normalize()
        cima = lado.cross(t).normalized()
        aneis.append([bm.verts.new(p + raios[i] * (lado * math.cos(math.tau * k / lados)
                                                    + cima * math.sin(math.tau * k / lados)))
                      for k in range(lados)])
    for i in range(len(aneis) - 1):
        for k in range(lados):
            k2 = (k + 1) % lados
            f = bm.faces.new((aneis[i][k], aneis[i][k2], aneis[i + 1][k2], aneis[i + 1][k]))
            f.smooth = True
            for canto, (kk, ii) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                p = canto.vert.co
                canto[ga].uv = (p.z * 0.45, p.x * 0.45)
                canto[gb].uv = (p.y * 0.45, comum.CASCA)
                # Fora do quadrado (u + 10) enquanto a casca é assada: o galho
                # não escreve na textura do tronco; depois volta para dentro.
                canto[uv].uv = (uv_base[0] + 0.08 * kk / lados + 10.0, uv_base[1] + passos[ii] / CASCA_METROS)
    ponta = bm.verts.new(pontos[-1] + (pontos[-1] - pontos[-2]).normalized() * raios[-1] * 2.0)
    for k in range(lados):
        bm.faces.new((aneis[-1][k], aneis[-1][(k + 1) % lados], ponta)).smooth = True


def galhos(semente=11):
    """Os verticilos: a cada ANDAR, 4 a 6 galhos em volta do tronco, longos
    embaixo e curtos em cima (a copa em cone). Devolve (bmesh dos galhos,
    lista de galhos), cada galho = [pontos da linha do meio]."""
    rnd = random.Random(semente)
    bm = bmesh.new()
    bm.loops.layers.uv.new("gA")
    bm.loops.layers.uv.new("gB")
    bm.loops.layers.uv.new("bake")
    lista = []
    z = COPA_BAIXO
    giro = rnd.uniform(0, math.tau)
    while z < ALTURA - 0.45:
        alto = (z - COPA_BAIXO) / (ALTURA - COPA_BAIXO)
        quantos = rnd.randint(5, 6) if alto < 0.75 else rnd.randint(4, 5)
        giro += 2.39996  # o ângulo de ouro: um verticilo não fica em cima do outro
        for k in range(quantos):
            a = giro + math.tau * k / quantos + rnd.uniform(-0.3, 0.3)
            zz = z + rnd.uniform(-0.08, 0.08)
            comprimento = raio_da_copa(zz) * rnd.uniform(0.85, 1.05)
            if comprimento < 0.25:
                continue
            # Embaixo os galhos caem e a ponta sobe um pouco; em cima, apontam para cima.
            subida = math.radians(-8.0 + 38.0 * alto)
            queda = 0.22 * (1.0 - alto)
            direcao = Vector((math.cos(a), math.sin(a), 0.0))
            lado = Vector((-direcao.y, direcao.x, 0.0))
            torto = rnd.uniform(-0.08, 0.08)
            inicio = eixo(zz) + direcao * raio_do_tronco(zz) * 0.7
            pontos = []
            for i in range(5):
                t = i / 4.0
                d = t * comprimento
                h = math.tan(subida) * d - queda * comprimento * t * t + 0.1 * comprimento * t ** 4
                pontos.append(inicio + direcao * d + lado * torto * comprimento * t * t + Vector((0, 0, h)))
            raio = 0.008 + 0.022 * comprimento / COPA_RAIO
            raios = [raio * (1.0 - 0.8 * i / 4.0) for i in range(5)]
            tubo_por(bm, pontos, raios, 5 if comprimento > 1.2 else 4, (rnd.uniform(0.0, 0.9), rnd.uniform(0.05, 0.6)))
            lista.append(pontos)
        z += ANDAR * rnd.uniform(0.85, 1.15) * (1.0 - 0.35 * alto)
    # Tocos secos no tronco, abaixo da copa (os galhos que caíram).
    for k in range(7):
        zz = rnd.uniform(0.7, COPA_BAIXO - 0.1)
        a = rnd.uniform(0, math.tau)
        direcao = Vector((math.cos(a), math.sin(a), rnd.uniform(-0.25, 0.05))).normalized()
        inicio = eixo(zz) + direcao * raio_do_tronco(zz) * 0.6
        c = rnd.uniform(0.12, 0.4)
        pontos = [inicio, inicio + direcao * c * 0.5, inicio + direcao * c]
        r = rnd.uniform(0.012, 0.022)
        tubo_por(bm, pontos, [r, r * 0.8, r * 0.5], 5, (rnd.uniform(0.0, 0.9), rnd.uniform(0.05, 0.6)))
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    return bm, lista


# --- As agulhas -----------------------------------------------------------------

def material_emissao(nome, cor):
    """Só emissão: a foto de cima guarda a cor sem luz nenhuma."""
    mat = bpy.data.materials.new(nome)
    arv = mat.node_tree
    for n in list(arv.nodes):
        arv.nodes.remove(n)
    saida = arv.nodes.new("ShaderNodeOutputMaterial")
    emissao = arv.nodes.new("ShaderNodeEmission")
    emissao.inputs["Color"].default_value = (*cor, 1.0)
    emissao.inputs["Strength"].default_value = 1.0
    arv.links.new(emissao.outputs[0], saida.inputs["Surface"])
    return mat


def raminho(bm_por_cor, centro_y, semente):
    """Um raminho de abeto, chato, com a base em x = 0 e a ponta em x = 1
    (a foto cobre x de 0 a 1 e y de centro_y - 0,25 a centro_y + 0,25).
    As agulhas vão em vários tons (bm_por_cor: uma lista de bmesh, do mais
    escuro ao mais claro, cada um vira um material de emissão)."""
    rnd = random.Random(semente)
    tons = len(bm_por_cor)

    def agulha(p, direcao, comprimento, largura, tom, z):
        bm = bm_por_cor[max(0, min(tons - 2, tom))]
        lado = Vector((-direcao.y, direcao.x, 0.0)) * largura / 2.0
        a = bm.verts.new(p - lado + Vector((0, 0, z)))
        b = bm.verts.new(p + lado + Vector((0, 0, z)))
        c = bm.verts.new(p + direcao * comprimento * 0.85 + lado * 0.6 + Vector((0, 0, z)))
        d = bm.verts.new(p + direcao * comprimento + Vector((0, 0, z)))
        e = bm.verts.new(p + direcao * comprimento * 0.85 - lado * 0.6 + Vector((0, 0, z)))
        bm.faces.new((a, b, c, d, e))

    def ramo(inicio, direcao, comprimento, nivel, z):
        """Um ramo com agulhas dos dois lados; os ramos dão filhos (até o
        nível 2). Nenhuma agulha sai da faixa da foto (|y - centro_y| < 0,24)."""
        passos = max(4, int(comprimento / 0.0055))
        curva = rnd.uniform(-0.3, 0.3)
        pontos = []
        d = direcao.copy()
        p = inicio.copy()
        for i in range(passos + 1):
            if abs(p.y - centro_y) > 0.24 - 0.05 or p.x > 0.985 - 0.04:
                break
            pontos.append((p.copy(), d.copy()))
            d = (d + Vector((-d.y, d.x, 0.0)) * curva / passos).normalized()
            p = p + d * comprimento / passos
        if len(pontos) < 3:
            return
        # O raminho (talo) em marrom: um tom à parte (o último bmesh).
        talo = bm_por_cor[-1]
        for i in range(len(pontos) - 1):
            pa, da = pontos[i]
            pb, _ = pontos[i + 1]
            lado = Vector((-da.y, da.x, 0.0)) * (0.005, 0.0032, 0.0022)[nivel]
            v = [talo.verts.new(pa - lado + Vector((0, 0, z))), talo.verts.new(pa + lado + Vector((0, 0, z))),
                 talo.verts.new(pb + lado + Vector((0, 0, z))), talo.verts.new(pb - lado + Vector((0, 0, z)))]
            talo.faces.new(v)
        for i, (p, d) in enumerate(pontos):
            t = i / max(1, len(pontos) - 1)
            lado = Vector((-d.y, d.x, 0.0))
            # A ponta é o broto novo (mais claro); a base, a mais escura.
            tom = int((0.2 + 0.45 * t + rnd.uniform(-0.25, 0.25)) * (tons - 2) + (1.5 if t > 0.8 else 0.0))
            tamanho = (0.052, 0.045, 0.038)[nivel] * (1.0 - 0.35 * t) * rnd.uniform(0.85, 1.1)
            for s in (-1.0, 1.0):
                if rnd.random() < 0.08:
                    continue
                angulo = math.radians(rnd.uniform(50, 80))
                dn = (d * math.cos(angulo) + lado * s * math.sin(angulo)).normalized()
                agulha(p, dn, tamanho, 0.0075, tom, z + rnd.uniform(-0.002, 0.002))
            # Uma fileira de cima, mais curta e mais para a frente (o abeto tem
            # agulhas viradas para cima no meio do ramo).
            if i % 2 == 0:
                s = rnd.choice((-1.0, 1.0))
                angulo = math.radians(rnd.uniform(20, 45))
                dn = (d * math.cos(angulo) + lado * s * math.sin(angulo)).normalized()
                agulha(p, dn, tamanho * 0.75, 0.007, tom + 1, z + 0.004)
        if nivel >= 2:
            return
        # Os filhos: alternados, abertos para a frente, mais curtos na ponta.
        espaco = (0.055, 0.045)[nivel]
        cada = max(1, int(espaco / (comprimento / passos)))
        s_lado = 1.0 if rnd.random() < 0.5 else -1.0
        for i in range(len(pontos)):
            t = i / max(1, len(pontos) - 1)
            if t < 0.05 or t > 0.88 or i % cada != 0:
                continue
            p, d = pontos[i]
            s_lado = -s_lado
            lado = Vector((-d.y, d.x, 0.0))
            angulo = math.radians(rnd.uniform(40, 55) if nivel == 0 else rnd.uniform(45, 65))
            df = (d * math.cos(angulo) + lado * s_lado * math.sin(angulo)).normalized()
            cf = (0.3 * (1.0 - 0.7 * t), 0.09 * (1.0 - 0.5 * t))[nivel] * rnd.uniform(0.85, 1.1)
            ramo(p, df, cf, nivel + 1, z - 0.003 * (nivel + 1))

    ramo(Vector((0.015, centro_y + rnd.uniform(-0.02, 0.02), 0.0)), Vector((1.0, rnd.uniform(-0.04, 0.04), 0.0)).normalized(),
         0.94, 0, 0.0)


def textura_de_agulhas():
    """Fotografa dois raminhos (um em cada metade da foto) e devolve a imagem
    (RGBA, com a cor espalhada por baixo do transparente), já embutida."""
    # Os tons (cor linear): do verde-escuro velho ao broto claro; e o talo.
    tons = [(0.018, 0.045, 0.024), (0.026, 0.062, 0.03), (0.034, 0.078, 0.034),
            (0.045, 0.095, 0.038), (0.06, 0.115, 0.042), (0.09, 0.16, 0.055),
            (0.07, 0.045, 0.025)]
    bms = [bmesh.new() for _ in tons]
    raminho(bms, -0.25, 21)
    raminho(bms, 0.25, 34)
    objetos = []
    for i, (bm, cor) in enumerate(zip(bms, tons)):
        ob = comum.objeto("agulhas%d" % i, bm)
        ob.data.materials.append(material_emissao("tom%d" % i, cor))
        objetos.append(ob)
    pasta = tempfile.mkdtemp(prefix="arvore_")
    caminho = comum.foto_de_cima(objetos, os.path.join(pasta, "agulhas.png"), FOTO, FOTO, 1.0, (0.5, 0.0))
    for ob in objetos:
        bpy.data.objects.remove(ob)
    img = bpy.data.images.load(caminho)
    img.name = "leaves_cor"
    comum.sangrar_cor(img)
    img.pack()
    return img


def material_folhas(img):
    """O material das folhas que vai no .glb: a textura, recortada pela
    transparência (alphaMode MASK: o nó "Arredondar" diz ao exportador) e dos
    dois lados."""
    mat = bpy.data.materials.new("leaves")
    arv = mat.node_tree
    bsdf = arv.nodes["Principled BSDF"]
    tex = arv.nodes.new("ShaderNodeTexImage")
    tex.image = img
    arv.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    corte = arv.nodes.new("ShaderNodeMath")
    corte.operation = 'ROUND'
    arv.links.new(tex.outputs["Alpha"], corte.inputs[0])
    arv.links.new(corte.outputs[0], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.85
    mat.use_backface_culling = False
    return mat


def cartao(bm, cor, inicio, direcao, normal, comprimento, variacao, curva, cor_de, dobras=2):
    """Um cartão de agulhas: retângulo 2:1, dobrado no meio se "dobras" = 2
    (a ponta cai "curva" m), com a base em "inicio" e o comprimento ao longo
    de "direcao". "variacao" (0 ou 1): qual metade da foto. "cor_de(p)" dá o
    tom do vértice. Liso (a Godot refaz a normal das folhas no shader)."""
    largura = comprimento * 0.5
    x = direcao.normalized()
    n = (normal - x * x.dot(normal)).normalized()
    y = n.cross(x).normalized()
    uv = bm.loops.layers.uv["bake"]
    linhas = []
    for i in range(dobras + 1):
        t = i / dobras
        meio = inicio + x * comprimento * t - n * curva * t * t
        linhas.append([bm.verts.new(meio - y * largura / 2.0), bm.verts.new(meio + y * largura / 2.0)])
    v0 = variacao * 0.5
    for i in range(dobras):
        f = bm.faces.new((linhas[i][0], linhas[i + 1][0], linhas[i + 1][1], linhas[i][1]))
        f.smooth = True
        for canto, (u, v) in zip(f.loops, ((i / dobras, 0.0), ((i + 1) / dobras, 0.0),
                                            ((i + 1) / dobras, 1.0), (i / dobras, 1.0))):
            canto[uv].uv = (u, v0 + v * 0.5)
            canto[cor] = (*cor_de(canto.vert.co), 1.0)


def folhas(lista, semente=17):
    """Os cartões ao longo de cada galho e na ponta do tronco."""
    rnd = random.Random(semente)
    bm = bmesh.new()
    bm.loops.layers.uv.new("bake")
    cor = bm.loops.layers.color.new("Color")

    def cor_de(p):
        # O miolo da copa e o andar de baixo ficam na sombra; a casca de fora, clara.
        rr = raio_da_copa(p.z)
        fora = max(0.0, min(1.0, Vector((p.x, p.y)).length / max(rr, 0.35)))
        alto = max(0.0, min(1.0, (p.z - COPA_BAIXO) / (ALTURA - COPA_BAIXO)))
        v = (0.38 + 0.62 * fora ** 0.8) * (0.82 + 0.18 * alto)
        return (v * 0.97, v, v * 0.95)

    for pontos in lista:
        comprimento = sum((pontos[i + 1] - pontos[i]).length for i in range(len(pontos) - 1))
        tamanho = 0.8 + 0.55 * min(1.0, comprimento / COPA_RAIO)
        passo = tamanho * 0.36
        d = 0.15 * comprimento
        k = 0
        while d < comprimento + 0.05:
            # O ponto e a direção do galho na distância d.
            resto = d
            for i in range(len(pontos) - 1):
                seg = (pontos[i + 1] - pontos[i]).length
                if resto <= seg or i == len(pontos) - 2:
                    t = min(1.0, resto / seg)
                    p = pontos[i].lerp(pontos[i + 1], t)
                    direcao = (pontos[i + 1] - pontos[i]).normalized()
                    break
                resto -= seg
            lado = direcao.cross(Vector((0, 0, 1))).normalized()
            cima = lado.cross(direcao).normalized()
            fim = d / max(comprimento, 0.01)
            c = tamanho * (1.0 - 0.3 * fim) * rnd.uniform(0.9, 1.1)
            # O cartão do meio: quase deitado (o raminho é chato), seguindo o galho.
            giro = Matrix.Rotation(rnd.uniform(-0.3, 0.3), 3, cima)
            rolar = Matrix.Rotation(rnd.uniform(-0.3, 0.3), 3, direcao)
            cartao(bm, cor, p - direcao * c * 0.15, giro @ direcao, rolar @ cima, c,
                   rnd.randint(0, 1), c * 0.12, cor_de)
            # Os dois de lado, abertos em leque e caídos para fora.
            for s in (-1.0, 1.0):
                if fim > 0.95 and rnd.random() < 0.5:
                    continue
                abre = Matrix.Rotation(s * rnd.uniform(0.75, 1.05), 3, cima)
                cai = Matrix.Rotation(s * rnd.uniform(0.25, 0.5), 3, abre @ direcao)
                dir_lado = abre @ direcao
                cartao(bm, cor, p, dir_lado, cai @ cima, c * rnd.uniform(0.65, 0.8),
                       rnd.randint(0, 1), c * 0.15, cor_de, 1)
            # A camada de baixo: outro cartão um pouco abaixo, girado (a copa
            # do abeto é feita de "andares" grossos, não de folhas soltas).
            if fim < 0.85:
                giro2 = Matrix.Rotation(rnd.uniform(-0.5, 0.5), 3, cima)
                rolar2 = Matrix.Rotation(rnd.uniform(-0.45, 0.45), 3, direcao)
                cartao(bm, cor, p - cima * c * 0.12 - direcao * c * 0.05, giro2 @ direcao, rolar2 @ cima,
                       c * 0.9, rnd.randint(0, 1), c * 0.18, cor_de)
            # De vez em quando, um raminho pendurado (de lado, mais em pé).
            if fim < 0.9:
                s = rnd.choice((-1.0, 1.0))
                pende = Matrix.Rotation(s * rnd.uniform(0.9, 1.25), 3, direcao)
                cartao(bm, cor, p, (direcao - cima * 0.35).normalized(), pende @ cima,
                       c * 0.7, rnd.randint(0, 1), c * 0.2, cor_de, 1)
            d += passo * rnd.uniform(0.85, 1.15)
            k += 1
    # A ponta: o broto do alto, cartões em pé em volta do tronco.
    topo = eixo(ALTURA - 1.1)
    for k in range(4):
        a = math.tau * k / 4 + rnd.uniform(-0.2, 0.2)
        normal = Vector((math.cos(a), math.sin(a), 0.0))
        cartao(bm, cor, topo + Vector((0, 0, -0.1)), Vector((0.06 * math.cos(a), 0.06 * math.sin(a), 1.0)),
               normal, 1.25, k % 2, 0.0, cor_de)
    bm.normal_update()
    return bm


# --- O pinheiro -------------------------------------------------------------------

def pinheiro(saida, previas):
    comum.iniciar()
    img_folhas = textura_de_agulhas()
    madeira_bm = tronco()
    galhos_bm, lista = galhos()
    madeira = comum.objeto("tronco", madeira_bm)
    ramos = comum.objeto("galhos", galhos_bm)
    chao = comum.chao(6.0, 0.0)
    # A casca: o material de lenha do comum, só com o tipo CASCA, assado no
    # tronco (os galhos ficam fora do quadrado e não escrevem nele).
    mat = comum.material_madeira("casca_procedural", clara=(0.19, 0.115, 0.075), escura=(0.075, 0.045, 0.03),
                                 cinza=0.12, aneis=120.0, gasto=0.2)
    for ob in (madeira, ramos):
        ob.data.materials.append(mat)
        ob.data.uv_layers.active = ob.data.uv_layers["bake"]
    comum.assar_textura_retangular([madeira], mat, 256, 1024, "bark")
    bpy.data.objects.remove(chao)
    ramos.data.materials.clear()
    ramos.data.materials.append(bpy.data.materials["bark"])
    # Os galhos voltam para dentro do quadrado (a textura repete).
    for poly in ramos.data.polygons:
        for li in poly.loop_indices:
            canto = ramos.data.uv_layers["bake"].data[li]
            canto.uv = (canto.uv[0] - 10.0, canto.uv[1])
    bark = comum.juntar([madeira, ramos], "bark")
    bark.data.materials.clear()
    bark.data.materials.append(bpy.data.materials["bark"])
    # A casca é de um lado só (o glTF diria "doubleSided" e a Godot desenharia o dentro).
    bpy.data.materials["bark"].use_backface_culling = True
    leaves = comum.objeto("leaves", folhas(lista))
    leaves.data.materials.append(material_folhas(img_folhas))
    comum.exportar_com_alfa([bark, leaves], saida)
    if previas:
        previa(bark, leaves, img_folhas, previas)


def previa(bark, leaves, img_folhas, pasta):
    """Duas vistas no Cycles (de perto e de longe), com sol e céu: só para
    conferir a forma. Não entram no .glb (que já foi gravado)."""
    os.makedirs(pasta, exist_ok=True)
    arv = leaves.data.materials[0].node_tree
    bsdf = arv.nodes["Principled BSDF"]
    tex = next(n for n in arv.nodes if n.type == 'TEX_IMAGE')
    tinta = arv.nodes.new("ShaderNodeVertexColor")
    tinta.layer_name = "Color"
    mult = arv.nodes.new("ShaderNodeMixRGB")
    mult.blend_type = 'MULTIPLY'
    mult.inputs[0].default_value = 1.0
    arv.links.new(tex.outputs["Color"], mult.inputs[1])
    arv.links.new(tinta.outputs["Color"], mult.inputs[2])
    arv.links.new(mult.outputs[0], bsdf.inputs["Base Color"])
    piso = comum.chao(60.0, 0.0)
    piso.data.materials.append(comum.material_simples("neve_previa", (0.75, 0.78, 0.82)))
    cena = bpy.context.scene
    cena.render.engine = 'CYCLES'
    cena.cycles.samples = 48
    cena.render.film_transparent = False
    cena.view_settings.view_transform = 'AgX'
    cena.render.resolution_x = 900
    cena.render.resolution_y = 1100
    cena.world.use_nodes = True
    fundo = cena.world.node_tree.nodes["Background"]
    fundo.inputs[0].default_value = (0.45, 0.6, 0.85, 1)
    fundo.inputs[1].default_value = 0.9
    sol = bpy.data.lights.new("sol_previa", 'SUN')
    sol.energy = 4.0
    ob_sol = bpy.data.objects.new("sol_previa", sol)
    cena.collection.objects.link(ob_sol)
    ob_sol.rotation_euler = (math.radians(50), 0.0, math.radians(35))
    camera = bpy.data.cameras.new("camera_previa")
    camera.lens = 35
    ob = bpy.data.objects.new("camera_previa", camera)
    cena.collection.objects.link(ob)
    cena.camera = ob
    for rotulo, pos, alvo in (("perto", (4.5, -3.0, 1.7), (0.0, 0.0, 3.2)),
                              ("longe", (18.0, -12.0, 2.0), (0.0, 0.0, 4.8))):
        ob.location = pos
        ob.rotation_euler = (Vector(alvo) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
        cena.render.filepath = os.path.join(os.path.abspath(pasta), "pinheiro_%s.png" % rotulo)
        bpy.ops.render.render(write_still=True)


ESPECIES = {"pinheiro": pinheiro}


def main():
    especie, saida, previas = argumentos_da_arvore()
    ESPECIES[especie](saida, previas)


main()
