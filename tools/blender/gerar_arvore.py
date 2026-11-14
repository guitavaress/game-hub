# As árvores do hub (Fase 19.2; 19.3: a árvore de rua e o pinheiro corrigido):
# uma função por espécie.
#   pinheiro  o abeto do bairro do RPG (e da vista da cabana): pine.glb
#   rua       a árvore de folha larga das floreiras e da praça: street_tree.glb
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
# A origem é o pé do tronco, no chão; o pinheiro tem ALTURA m e a árvore de
# rua, RUA_ALTURA m. O vento, a
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
# A foto do raminho: FOTO x FOTO, com duas variações (metade de baixo e de cima).
# 19.3: 1024 (era 512), para as agulhas finas terem uns 4 px de largura de perto.
FOTO = 1024
# A largura de uma agulha (na foto, que cobre 1 m do raminho). 19.3: era 7,5 mm,
# e de perto o raminho lembrava uma folha larga; a agulha do abeto tem ~2 mm.
AGULHA_LARGURA = 0.0038
# O passo entre duas agulhas ao longo do ramo (m). 19.3: mais juntas (eram
# 5,5 mm), para o raminho não ficar ralo com as agulhas finas.
AGULHA_PASSO = 0.0045


def argumentos_da_arvore():
    """(espécie, saída, pasta das prévias), pelos argumentos depois de "--"."""
    args = comum.argumentos()
    especie = args[0] if args else "pinheiro"
    arquivo = ARQUIVOS.get(especie)
    if arquivo is None:
        raise SystemExit("Espécie desconhecida: %s (há: %s)" % (especie, ", ".join(ARQUIVOS)))
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
    """O tronco do pinheiro (veja tronco_generico)."""
    alturas = [-0.15, 0.0, 0.08, 0.18, 0.3, 0.45, 0.65, 0.9, 1.2, 1.6]
    z = 1.6
    while z < ALTURA - 0.3:
        z += 0.45 if z < CASCA_METROS else 0.7
        alturas.append(min(z, ALTURA - 0.3))
    alturas.append(ALTURA - 0.05)
    return tronco_generico(alturas, eixo, raio_do_tronco, eixo(ALTURA), CASCA_METROS,
                           semente, lados)


def tronco_generico(alturas, eixo_de, raio_de, ponta_em, casca_metros, semente, lados,
                    raizes=(0.32, 0.35, 0.9), escala_veio=0.45):
    """Um tronco num bmesh: anéis nas "alturas", o meio em eixo_de(z) e o raio
    raio_de(z), fechado num cone até "ponta_em". As raízes (altura, base,
    lobos) alargam o pé em cinco "pés". Leva o veio da casca (gA/gB, para o
    comum.material_madeira) e o UV "bake" cilíndrico (sobe casca_metros m por
    volta da textura)."""
    rnd = random.Random(semente)
    bm = bmesh.new()
    ga = bm.loops.layers.uv.new("gA")
    gb = bm.loops.layers.uv.new("gB")
    uv = bm.loops.layers.uv.new("bake")
    fase = rnd.uniform(0, math.tau)
    aneis = []
    for z in alturas:
        anel = []
        meio = eixo_de(max(z, 0.0))
        r = raio_de(max(z, 0.0))
        # As raízes: cinco "pés" que alargam o tronco perto do chão.
        pe = math.exp(-max(z, 0.0) / raizes[0])
        for k in range(lados):
            a = math.tau * k / lados
            lobo = max(0.0, math.cos(5 * a + fase)) ** 2
            casca = 1.0 + 0.04 * noise.noise(Vector((math.cos(a) * 3, math.sin(a) * 3, z * 2.0)))
            rr = r * casca * (1.0 + pe * (raizes[1] + raizes[2] * lobo))
            anel.append(bm.verts.new(meio + Vector((math.cos(a) * rr, math.sin(a) * rr, 0.0))))
        aneis.append(anel)
    for i in range(len(aneis) - 1):
        for k in range(lados):
            k2 = (k + 1) % lados
            f = bm.faces.new((aneis[i][k], aneis[i][k2], aneis[i + 1][k2], aneis[i + 1][k]))
            f.smooth = True
            for canto, (kk, ii) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                p = canto.vert.co
                # Veio: ao longo = z; "através" = x e y (escala 0,45 no pinheiro:
                # as placas da casca dele são maiores que as da lenha).
                canto[ga].uv = (p.z * escala_veio, p.x * escala_veio)
                canto[gb].uv = (p.y * escala_veio, comum.CASCA)
                canto[uv].uv = (kk / lados, alturas[ii] / casca_metros)
    # A ponta fecha num cone curto.
    ponta = bm.verts.new(ponta_em)
    for k in range(lados):
        k2 = (k + 1) % lados
        f = bm.faces.new((aneis[-1][k], aneis[-1][k2], ponta))
        f.smooth = True
        for canto, uu in zip(f.loops, (k / lados, (k + 1) / lados, (k + 0.5) / lados)):
            p = canto.vert.co
            canto[ga].uv = (p.z * escala_veio, p.x * escala_veio)
            canto[gb].uv = (p.y * escala_veio, comum.CASCA)
            canto[uv].uv = (uu, alturas[-1] / casca_metros)
    bm.normal_update()
    return bm


def tubo_por(bm, pontos, raios, lados, uv_base, casca_metros=CASCA_METROS):
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
                canto[uv].uv = (uv_base[0] + 0.08 * kk / lados + 10.0, uv_base[1] + passos[ii] / casca_metros)
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
            # 19.3: os galhos curtos (no alto, finos e cobertos de agulhas) com 3
            # lados, para o modelo caber no orçamento com a foto das agulhas em 1024.
            tubo_por(bm, pontos, raios, 5 if comprimento > 1.2 else 3, (rnd.uniform(0.0, 0.9), rnd.uniform(0.05, 0.6)))
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
        passos = max(4, int(comprimento / AGULHA_PASSO))
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
                agulha(p, dn, tamanho, AGULHA_LARGURA, tom, z + rnd.uniform(-0.002, 0.002))
            # Uma fileira de cima, mais curta e mais para a frente (o abeto tem
            # agulhas viradas para cima no meio do ramo).
            if i % 2 == 0:
                s = rnd.choice((-1.0, 1.0))
                angulo = math.radians(rnd.uniform(20, 45))
                dn = (d * math.cos(angulo) + lado * s * math.sin(angulo)).normalized()
                agulha(p, dn, tamanho * 0.75, AGULHA_LARGURA * 0.95, tom + 1, z + 0.004)
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
    # 19.3: verde de abeto, escuro e puxado para o azul (na 19.2 era um verde
    # vivo e claro, que de dia saía saturado demais).
    tons = [(0.014, 0.024, 0.019), (0.018, 0.031, 0.025), (0.023, 0.038, 0.030),
            (0.028, 0.046, 0.035), (0.035, 0.055, 0.040), (0.052, 0.074, 0.048),
            (0.055, 0.04, 0.026)]
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
    bark = casca_assada(madeira_bm, galhos_bm, (0.19, 0.115, 0.075), (0.075, 0.045, 0.03), 0.12,
                        256, 1024)
    leaves = comum.objeto("leaves", folhas(lista))
    leaves.data.materials.append(material_folhas(img_folhas))
    # WEBP a 60 (e não 85): a foto das agulhas (1024) cabe no orçamento de 800 KB.
    comum.exportar_com_alfa([bark, leaves], saida, qualidade=60)
    if previas:
        previa(bark, leaves, previas, "pinheiro", ALTURA)


def casca_assada(madeira_bm, galhos_bm, clara, escura, cinza, largura, altura, raio_chao=6.0):
    """O tronco e os galhos num objeto "bark": a casca do comum.material_madeira
    (só o tipo CASCA) assada no tronco, numa textura alta e estreita; os galhos
    usam faixas dessa mesma textura (ficam fora do quadrado enquanto ela é
    assada, para não escrever nela, e depois voltam para dentro)."""
    madeira = comum.objeto("tronco", madeira_bm)
    ramos = comum.objeto("galhos", galhos_bm)
    chao = comum.chao(raio_chao, 0.0)
    mat = comum.material_madeira("casca_procedural", clara=clara, escura=escura,
                                 cinza=cinza, aneis=120.0, gasto=0.2)
    for ob in (madeira, ramos):
        ob.data.materials.append(mat)
        ob.data.uv_layers.active = ob.data.uv_layers["bake"]
    comum.assar_textura_retangular([madeira], mat, largura, altura, "bark")
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
    return bark


# --- A árvore de rua (19.3) ---------------------------------------------------------
# Uma árvore de folha larga, de copa oval (como as tílias e os plátanos das
# calçadas), para as floreiras e a praça: um tronco curto e limpo que abre em
# cinco galhos grossos; cada galho dá ramos, e cada ramo, raminhos, até a casca
# da copa (um elipsoide). As folhas são cartões com a foto de um raminho de
# folhas (feito aqui, como o das agulhas), nas pontas dos ramos e raminhos.

RUA_ALTURA = 6.0          # m, do chão ao alto da copa
RUA_TRONCO = 2.0          # m, onde o tronco abre nos galhos
RUA_RAIO_BASE = 0.13      # m, o tronco logo acima das raízes
RUA_COPA_CENTRO = 3.85    # m, o meio da copa
RUA_COPA_RAIO = 2.5       # m, a copa para os lados
RUA_COPA_METADE = 2.15    # m, do meio da copa até o alto
# m de tronco por volta da textura da casca: o tronco (até 2,55 m) cobre a
# textura inteira, e os galhos (que usam faixas dela) não caem num pedaço vazio.
RUA_CASCA_METROS = 2.4
RUA_FOTO = 512            # a foto do raminho de folhas (a folha é grande: 512 basta)


def rua_eixo(z):
    """O meio do tronco: quase reto, com uma curva leve."""
    t = z / RUA_TRONCO
    return Vector((0.05 * noise.noise(Vector((t * 1.5, 3.0, 0.0))) * t,
                   0.05 * noise.noise(Vector((t * 1.5, 9.0, 0.0))) * t, z))


def rua_raio(z):
    """O tronco afina pouco até a forquilha e engrossa nela (onde os galhos saem)."""
    t = max(0.0, min(1.0, z / RUA_TRONCO))
    forquilha = math.exp(-((z - RUA_TRONCO) / 0.25) ** 2) * 0.25
    return RUA_RAIO_BASE * (1.0 - 0.28 * t + forquilha)


def ate_a_copa(p, d):
    """Quanto falta (m) de p, na direção d, até a casca da copa (o elipsoide).
    0 se p já está fora e d aponta para fora."""
    c = Vector((0.0, 0.0, RUA_COPA_CENTRO))
    s = Vector((1.0 / RUA_COPA_RAIO, 1.0 / RUA_COPA_RAIO, 1.0 / RUA_COPA_METADE))
    q = (p - c) * s
    e = d * s
    a = e.dot(e)
    b = 2.0 * q.dot(e)
    cc = q.dot(q) - 1.0
    disc = b * b - 4.0 * a * cc
    if disc < 0.0 or a <= 0.0:
        return 0.0
    return max(0.0, (-b + math.sqrt(disc)) / (2.0 * a))


def dentro_da_copa(p):
    """0 no meio da copa, 1 na casca dela (pode passar de 1 fora)."""
    q = p - Vector((0.0, 0.0, RUA_COPA_CENTRO))
    return math.sqrt((q.x / RUA_COPA_RAIO) ** 2 + (q.y / RUA_COPA_RAIO) ** 2 + (q.z / RUA_COPA_METADE) ** 2)


def para_fora(p):
    """A direção para fora da copa em p (a normal do elipsoide que passa por p)."""
    q = p - Vector((0.0, 0.0, RUA_COPA_CENTRO))
    n = Vector((q.x / RUA_COPA_RAIO ** 2, q.y / RUA_COPA_RAIO ** 2, q.z / RUA_COPA_METADE ** 2))
    if n.length < 1e-4:
        return Vector((0.0, 0.0, 1.0))
    return n.normalized()


def curva_de_galho(inicio, direcao, comprimento, rnd, subir, pontos=5):
    """A linha de um galho: começa em "direcao" e vai se virando para cima
    ("subir") e um pouco para o lado (ao acaso)."""
    lado = direcao.cross(Vector((0.0, 0.0, 1.0)))
    if lado.length < 0.01:
        lado = Vector((1.0, 0.0, 0.0))
    lado.normalize()
    torto = rnd.uniform(-0.25, 0.25)
    linha = [inicio.copy()]
    p = inicio.copy()
    d = direcao.normalized()
    passo = comprimento / (pontos - 1)
    for i in range(1, pontos):
        d = (d + Vector((0.0, 0.0, subir / (pontos - 1))) + lado * torto / (pontos - 1)).normalized()
        p = p + d * passo
        linha.append(p.copy())
    return linha


def direcao_ao_longo(linha, t):
    """O ponto e a direção da linha em t (0 a 1, pelo comprimento)."""
    total = sum((linha[i + 1] - linha[i]).length for i in range(len(linha) - 1))
    resto = t * total
    for i in range(len(linha) - 1):
        seg = (linha[i + 1] - linha[i]).length
        if resto <= seg or i == len(linha) - 2:
            u = min(1.0, resto / max(seg, 1e-6))
            return linha[i].lerp(linha[i + 1], u), (linha[i + 1] - linha[i]).normalized()
        resto -= seg
    return linha[-1], (linha[-1] - linha[-2]).normalized()


def galhos_rua(semente=5):
    """Os galhos da árvore de rua: cinco grossos e um "líder" no meio; cada um
    dá ramos e cada ramo dá raminhos, todos até perto da casca da copa.
    Devolve (bmesh, lista de [linha, nível]) para as folhas."""
    rnd = random.Random(semente)
    bm = bmesh.new()
    bm.loops.layers.uv.new("gA")
    bm.loops.layers.uv.new("gB")
    bm.loops.layers.uv.new("bake")
    lista = []

    def ramificar(linha, raio, nivel):
        if nivel > 3:
            return
        quantos = (0, 5, 4, 0)[nivel]
        lado_alterna = rnd.choice((-1.0, 1.0))
        for k in range(quantos):
            t = 0.25 + 0.7 * (k + rnd.uniform(0.2, 0.8)) / quantos
            p, d = direcao_ao_longo(linha, t)
            lado = d.cross(Vector((0.0, 0.0, 1.0)))
            if lado.length < 0.05:
                lado = d.cross(Vector((1.0, 0.0, 0.0)))
            lado.normalize()
            lado_alterna = -lado_alterna
            giro = Matrix.Rotation(rnd.uniform(-1.2, 1.2), 3, d)
            abre = math.radians(rnd.uniform(35.0, 60.0))
            dn = (d * math.cos(abre) + (giro @ lado) * lado_alterna * math.sin(abre)
                  + Vector((0.0, 0.0, 0.25))).normalized()
            falta = ate_a_copa(p, dn)
            comprimento = min(falta * rnd.uniform(0.75, 0.95), (1.7, 0.9)[nivel - 1])
            if comprimento < 0.2:
                continue
            filho = curva_de_galho(p, dn, comprimento, rnd, 0.15, 4 if nivel == 1 else 3)
            r = raio * (0.5 + 0.1 * (1.0 - t))
            raios = [r * (1.0 - 0.75 * i / (len(filho) - 1)) for i in range(len(filho))]
            tubo_por(bm, filho, raios, 5 if nivel == 1 else 4,
                     (rnd.uniform(0.0, 0.9), rnd.uniform(0.05, 0.6)), RUA_CASCA_METROS)
            lista.append((filho, nivel + 1))
            ramificar(filho, r, nivel + 1)

    giro = rnd.uniform(0, math.tau)
    quantos = 5
    for k in range(quantos):
        a = giro + math.tau * k / quantos + rnd.uniform(-0.25, 0.25)
        z0 = RUA_TRONCO + rnd.uniform(-0.12, 0.3)
        sobe = math.radians(rnd.uniform(38.0, 55.0))
        d = Vector((math.cos(a) * math.cos(sobe), math.sin(a) * math.cos(sobe), math.sin(sobe)))
        inicio = rua_eixo(z0) + Vector((math.cos(a), math.sin(a), 0.0)) * rua_raio(z0) * 0.4
        comprimento = ate_a_copa(inicio, d) * rnd.uniform(0.7, 0.82)
        linha = curva_de_galho(inicio, d, comprimento, rnd, 0.2)
        raio = RUA_RAIO_BASE * rnd.uniform(0.5, 0.6)
        raios = [raio * (1.0 - 0.7 * i / (len(linha) - 1)) for i in range(len(linha))]
        tubo_por(bm, linha, raios, 6, (rnd.uniform(0.0, 0.9), rnd.uniform(0.05, 0.6)), RUA_CASCA_METROS)
        lista.append((linha, 1))
        ramificar(linha, raio, 1)
    # O líder: sobe pelo meio da copa.
    inicio = rua_eixo(RUA_TRONCO - 0.1)
    d = Vector((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), 1.0)).normalized()
    linha = curva_de_galho(inicio, d, ate_a_copa(inicio, d) * 0.72, rnd, 0.0)
    raio = RUA_RAIO_BASE * 0.55
    tubo_por(bm, linha, [raio * (1.0 - 0.75 * i / (len(linha) - 1)) for i in range(len(linha))], 6,
             (rnd.uniform(0.0, 0.9), rnd.uniform(0.05, 0.6)), RUA_CASCA_METROS)
    lista.append((linha, 1))
    ramificar(linha, raio, 1)
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    return bm, lista


def tronco_rua(semente=8):
    """O tronco curto da árvore de rua, até um pouco acima da forquilha."""
    alturas = [-0.12, 0.0, 0.06, 0.14, 0.26, 0.45, 0.8, 1.2, 1.5, 1.75, 1.95, 2.15, 2.35]
    topo = 2.55
    return tronco_generico(alturas, rua_eixo, rua_raio, rua_eixo(topo), RUA_CASCA_METROS,
                           semente, 12, raizes=(0.2, 0.2, 0.55), escala_veio=0.9)


def raminho_folhoso(bm_por_cor, centro_y, semente):
    """Um raminho de folhas largas, chato, com a base em x = 0 e a ponta em
    x = 1 (a foto cobre y de centro_y - 0,25 a centro_y + 0,25). As folhas
    alternam dos dois lados, cada uma num talinho; perto da base saem dois ou
    três raminhos de lado. bm_por_cor: os tons das folhas, do mais escuro ao
    mais claro, e por último o do talo."""
    rnd = random.Random(semente)
    tons = len(bm_por_cor) - 1
    talo = bm_por_cor[-1]

    def folha(base, direcao, comprimento, tom, z):
        """Uma folha oval de ponta fina (12 pontos em volta), e a nervura do meio."""
        bm = bm_por_cor[max(0, min(tons - 1, tom))]
        lado = Vector((-direcao.y, direcao.x, 0.0))
        largura = comprimento * rnd.uniform(0.42, 0.52)
        borda_dir = []
        borda_esq = []
        for i in range(1, 7):
            s = i / 7.0
            # Mais larga perto de 40% do comprimento; a ponta afina.
            w = largura / 2.0 * math.sin(math.pi * s ** 0.8) ** 0.9
            meio = base + direcao * comprimento * s
            borda_dir.append(meio + lado * w)
            borda_esq.append(meio - lado * w)
        contorno = [base] + borda_dir + [base + direcao * comprimento] + list(reversed(borda_esq))
        vs = [bm.verts.new(p + Vector((0.0, 0.0, z))) for p in contorno]
        bm.faces.new(vs)
        # A nervura: um traço fino um tom mais claro, por cima.
        nervura = bm_por_cor[max(0, min(tons - 1, tom + 2))]
        lado_n = lado * 0.0022
        fim = base + direcao * comprimento * 0.85
        nervura.faces.new([nervura.verts.new(p + Vector((0.0, 0.0, z + 0.0008)))
                           for p in (base - lado_n, base + lado_n, fim + lado_n * 0.3, fim - lado_n * 0.3)])

    def ramo(inicio, direcao, comprimento, largura_talo, folha_max, z):
        linha = []
        d = direcao.normalized()
        p = inicio.copy()
        curva = rnd.uniform(-0.25, 0.25)
        passos = 24
        for i in range(passos + 1):
            if abs(p.y - centro_y) > 0.2 or p.x > 0.97:
                break
            linha.append((p.copy(), d.copy()))
            d = (d + Vector((-d.y, d.x, 0.0)) * curva / passos).normalized()
            p = p + d * comprimento / passos
        if len(linha) < 3:
            return []
        for i in range(len(linha) - 1):
            (pa, da), (pb, _) = linha[i], linha[i + 1]
            w = largura_talo * (1.0 - 0.6 * i / len(linha))
            lado = Vector((-da.y, da.x, 0.0)) * w
            talo.faces.new([talo.verts.new(q + Vector((0.0, 0.0, z))) for q in (pa - lado, pa + lado, pb + lado, pb - lado)])
        # As folhas: alternadas, a cada ~1/12 do ramo, maiores no meio.
        lado_s = rnd.choice((-1.0, 1.0))
        cada = max(1, len(linha) // 12)
        for i in range(1, len(linha)):
            if i % cada:
                continue
            t = i / (len(linha) - 1)
            p, d = linha[i]
            lado_s = -lado_s
            lado = Vector((-d.y, d.x, 0.0))
            ang = math.radians(rnd.uniform(35.0, 60.0))
            dn = (d * math.cos(ang) + lado * lado_s * math.sin(ang)).normalized()
            pecolo = 0.02 + 0.01 * rnd.random()
            base = p + dn * pecolo
            lado_p = Vector((-dn.y, dn.x, 0.0)) * 0.0018
            talo.faces.new([talo.verts.new(q + Vector((0.0, 0.0, z + 0.001)))
                            for q in (p - lado_p, p + lado_p, base + lado_p, base - lado_p)])
            tamanho = folha_max * (0.65 + 0.35 * math.sin(math.pi * min(1.0, t * 1.2))) * rnd.uniform(0.85, 1.1)
            # Folha que não cabe na faixa da foto encolhe.
            for _ in range(4):
                ponta = base + dn * tamanho
                if abs(ponta.y - centro_y) < 0.235 and ponta.x < 0.995:
                    break
                tamanho *= 0.75
            tom = int(rnd.uniform(0.0, tons - 2.0) + 0.8 * t)
            folha(base, dn, tamanho, tom, z + 0.002 + rnd.uniform(0.0, 0.004))
        # A folha da ponta.
        p, d = linha[-1]
        folha(p, d, folha_max * 0.8, tons - 2, z + 0.006)
        return linha

    principal = ramo(Vector((0.015, centro_y + rnd.uniform(-0.02, 0.02), 0.0)),
                     Vector((1.0, rnd.uniform(-0.05, 0.05), 0.0)), 0.95, 0.0055, 0.13, 0.0)
    # Os raminhos de lado (atrás do principal: z mais baixo), alternados.
    lado_s = rnd.choice((-1.0, 1.0))
    for k in range(6):
        t = 0.08 + 0.13 * k + rnd.uniform(-0.03, 0.03)
        i = int(t * (len(principal) - 1))
        p, d = principal[i]
        lado_s = -lado_s
        ang = math.radians(rnd.uniform(30.0, 45.0))
        dn = (d * math.cos(ang) + Vector((-d.y, d.x, 0.0)) * lado_s * math.sin(ang)).normalized()
        ramo(p, dn, rnd.uniform(0.32, 0.45) * (1.0 - 0.1 * k), 0.0035, 0.11, -0.012)


def textura_de_folhas():
    """Fotografa dois raminhos de folhas (um em cada metade da foto) e devolve
    a imagem (RGBA, com a cor espalhada por baixo do transparente)."""
    # Os tons (cor linear): verdes de folha de rua, um pouco puxados para o
    # oliva (de dia, a copa não fica verde-limão); e o talo.
    tons = [(0.022, 0.036, 0.014), (0.028, 0.046, 0.017), (0.036, 0.057, 0.02),
            (0.045, 0.068, 0.023), (0.056, 0.08, 0.027), (0.07, 0.094, 0.032),
            (0.085, 0.108, 0.04), (0.06, 0.045, 0.028)]
    bms = [bmesh.new() for _ in tons]
    raminho_folhoso(bms, -0.25, 41)
    raminho_folhoso(bms, 0.25, 58)
    objetos = []
    for i, (bm, cor) in enumerate(zip(bms, tons)):
        ob = comum.objeto("folhas%d" % i, bm)
        ob.data.materials.append(material_emissao("tom_folha%d" % i, cor))
        objetos.append(ob)
    pasta = tempfile.mkdtemp(prefix="arvore_")
    caminho = comum.foto_de_cima(objetos, os.path.join(pasta, "folhas.png"), RUA_FOTO, RUA_FOTO, 1.0, (0.5, 0.0))
    for ob in objetos:
        bpy.data.objects.remove(ob)
    img = bpy.data.images.load(caminho)
    img.name = "leaves_cor"
    comum.sangrar_cor(img)
    img.pack()
    return img


def folhas_rua(lista, semente=29):
    """Os cartões de folhas: nas pontas dos ramos e raminhos, virados para
    fora da copa (e um pouco para cima), com a ponta caída."""
    rnd = random.Random(semente)
    bm = bmesh.new()
    bm.loops.layers.uv.new("bake")
    cor = bm.loops.layers.color.new("Color")

    def cor_de(p):
        # O miolo da copa e a parte de baixo ficam na sombra; a casca de fora, clara.
        fora = max(0.0, min(1.0, dentro_da_copa(p)))
        alto = max(0.0, min(1.0, (p.z - (RUA_COPA_CENTRO - RUA_COPA_METADE)) / (2.0 * RUA_COPA_METADE)))
        v = (0.34 + 0.66 * fora ** 1.3) * (0.78 + 0.22 * alto)
        return (v, v, v * 0.96)

    for linha, nivel in lista:
        if nivel < 2:
            continue
        # Os raminhos (nível 3) levam folhas da metade para fora; os ramos (2),
        # no terço de fora.
        posicoes = (0.3, 0.55, 0.8, 1.0) if nivel == 3 else (0.55, 0.8, 1.0)
        for t in posicoes:
            p, d = direcao_ao_longo(linha, t)
            for k in range(2):
                fora = para_fora(p)
                normal = (fora * 0.65 + Vector((0.0, 0.0, 0.45))
                          + Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(-0.3, 0.3)))).normalized()
                # Ao longo do raminho (no plano do cartão), girado ao acaso.
                ao_longo = d - normal * d.dot(normal)
                if ao_longo.length < 0.05:
                    ao_longo = normal.orthogonal()
                ao_longo = Matrix.Rotation(rnd.uniform(-1.0, 1.0), 3, normal) @ ao_longo.normalized()
                c = rnd.uniform(0.7, 1.0)
                cartao(bm, cor, p - ao_longo * c * 0.35 + normal * rnd.uniform(-0.08, 0.08), ao_longo,
                       normal, c, rnd.randint(0, 1), c * 0.12, cor_de, 2 if k == 0 else 1)
    bm.normal_update()
    return bm


def arvore_de_rua(saida, previas):
    comum.iniciar()
    img_folhas = textura_de_folhas()
    galhos_bm, lista = galhos_rua()
    # Casca de rua: marrom-acinzentada, em placas mais finas que as do pinheiro.
    bark = casca_assada(tronco_rua(), galhos_bm, (0.13, 0.1, 0.075), (0.05, 0.04, 0.03), 0.1,
                        256, 512, raio_chao=4.0)
    leaves = comum.objeto("leaves", folhas_rua(lista))
    leaves.data.materials.append(material_folhas(img_folhas))
    comum.exportar_com_alfa([bark, leaves], saida)
    if previas:
        previa(bark, leaves, previas, "rua", RUA_ALTURA)


# --- A prévia ---------------------------------------------------------------------

def previa(bark, leaves, pasta, nome, altura):
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
    piso.data.materials.append(comum.material_simples("piso_previa", (0.5, 0.5, 0.5)))
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
    k = altura / 10.0
    for rotulo, pos, alvo in (("perto", (4.5 * k, -3.0 * k, 1.7), (0.0, 0.0, 3.2 * k)),
                              ("longe", (18.0 * k, -12.0 * k, 2.0), (0.0, 0.0, 4.8 * k))):
        ob.location = pos
        ob.rotation_euler = (Vector(alvo) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
        cena.render.filepath = os.path.join(os.path.abspath(pasta), "%s_%s.png" % (nome, rotulo))
        bpy.ops.render.render(write_still=True)


ESPECIES = {"pinheiro": pinheiro, "rua": arvore_de_rua}
ARQUIVOS = {"pinheiro": "pine", "rua": "street_tree"}


def main():
    especie, saida, previas = argumentos_da_arvore()
    ESPECIES[especie](saida, previas)


main()
