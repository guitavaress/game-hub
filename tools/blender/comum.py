# Peças comuns dos scripts do Blender do Game Hub (Fase 17.7.1).
#
# Cada script "gerar_*.py" monta um modelo e o exporta em .glb para a pasta
# assets/models/ do repositório. Tudo é feito por código, sem abrir a janela:
#
#   blender --background --factory-startup --python tools/blender/gerar_X.py
#
# O que está aqui:
#   - limpar a cena e ligar o Cycles (o motor que "assa" luz e textura);
#   - G(): converte uma posição da Godot (Y para cima) para o Blender (Z para cima);
#   - pedra(): uma pedra de verdade (caixa arredondada, ondulada por ruído,
#     lascada por cortes planos e com as quinas chanfradas);
#   - tábua, tora e lenha rachada, com as "coordenadas do veio" que o
#     material de madeira usa;
#   - o material de madeira procedural (veio, nós, quinas gastas, carvão) e
#     o "assar": copiar esse material para uma textura pequena (cor e relevo);
#   - assar a oclusão de ambiente (os cantos escuros) nas cores dos vértices;
#   - exportar o .glb.
#
# Este arquivo usa a API Python do Blender, que é GPL: por isso a pasta
# tools/blender/ é GPL-3.0 (veja o LICENSE). Os .glb gerados são nossos (MIT).

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PASTA_MODELOS = os.path.join(REPO, "assets", "models", "trail")
# Cada grupo de modelos tem a sua pasta em assets/models/ (17.8: "lookout", o mirante).
PASTA_GRUPOS = os.path.join(REPO, "assets", "models")

# A cor dos vértices vai para o glTF em 16 bits, de 0 a 1. Os tons das pedras
# passam de 1 (mais claros que a textura da Godot): por isso a cor é gravada
# dividida por GANHO, e a Godot multiplica de volta (TrailModels.VERTEX_GAIN).
GANHO = 1.6

# Os tipos de face da madeira (vão no canal Y do mapa "gB").
LISO = 0.0      # tábua aplainada
TOPO = 1.0      # o topo cortado (mostra os anéis)
CASCA = 2.0     # a casca da tora
RACHADO = 3.0   # a face rachada a machado


def argumentos():
    """Os argumentos depois de "--" na linha de comando."""
    if "--" in sys.argv:
        return sys.argv[sys.argv.index("--") + 1:]
    return []


def saida(nome, grupo="trail"):
    """Onde o .glb vai: o 1º argumento, ou assets/models/<grupo>/<nome>.glb."""
    args = argumentos()
    caminho = args[0] if args else os.path.join(PASTA_GRUPOS, grupo, nome + ".glb")
    os.makedirs(os.path.dirname(os.path.abspath(caminho)), exist_ok=True)
    return os.path.abspath(caminho)


def iniciar(amostras=24):
    """Cena vazia, Cycles na CPU e a oclusão de ambiente curta (cantos)."""
    for colecao in (bpy.data.objects, bpy.data.meshes, bpy.data.materials,
                    bpy.data.images, bpy.data.textures):
        for item in list(colecao):
            colecao.remove(item)
    cena = bpy.context.scene
    cena.render.engine = 'CYCLES'
    cena.cycles.device = 'CPU'
    cena.cycles.samples = amostras
    cena.render.bake.margin = 6
    if cena.world is None:
        cena.world = bpy.data.worlds.new("Mundo")
    cena.world.light_settings.distance = 0.35
    return cena


def G(x, y, z):
    """Posição da Godot (x, y para cima, z para trás) no Blender (z para cima)."""
    return Vector((x, -z, y))


def godot_dir(angulo):
    """Heightfield.direction_of da Godot (cos, sin no plano XZ) no Blender."""
    return Vector((math.cos(angulo), -math.sin(angulo), 0.0))


# --- Objetos -------------------------------------------------------------------

def objeto(nome, bm):
    """Cria um objeto da cena a partir de um bmesh (que é liberado)."""
    malha = bpy.data.meshes.new(nome)
    bm.to_mesh(malha)
    bm.free()
    ob = bpy.data.objects.new(nome, malha)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def juntar(objetos, nome):
    """Junta as peças num objeto só (um desenho na Godot)."""
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objetos:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objetos[0]
    if len(objetos) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = nome
    ob.data.name = nome
    return ob


def selecionar(objetos, ativo=None):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objetos:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = ativo or objetos[0]


def chao(raio=4.0, altura=0.0):
    """Um chão provisório (não é exportado), só para a oclusão dos pés."""
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, radius=raio, segments=32)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=(0.0, 0.0, altura))
    return objeto("chao_provisorio", bm)


# --- Pedras --------------------------------------------------------------------

def pedra(tamanho, semente, redondeza=0.75, ondulacao=0.12, cortes=2,
          funda=(0.06, 0.2), divisoes=4, base=-0.3, chanfro=0.012, cortes_de_lado=False):
    """Uma pedra num bmesh novo, no tamanho (x, y, z do Blender, metros).

    redondeza: 0 = caixa, 1 = bola; ondulacao: o ruído grande da forma;
    cortes: quantas lascas planas (faces quebradas); funda: quanto cada lasca
    entra (fração do tamanho); base: a altura (fração) em que a base é
    achatada para pousar; chanfro: o raio das quinas das lascas (gastas)."""
    rnd = random.Random(semente)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=divisoes, use_grid_fill=True)
    desvio = Vector((rnd.uniform(-90, 90), rnd.uniform(-90, 90), rnd.uniform(-90, 90)))
    for v in bm.verts:
        p = v.co.copy()
        bola = p.normalized() * 0.5
        q = p.lerp(bola, redondeza)
        q *= 1.0 + ondulacao * noise.noise(q * 2.2 + desvio) + 0.03 * noise.noise(q * 7.0 + desvio)
        q.z = max(q.z, base)
        v.co = Vector((q.x * tamanho[0], q.y * tamanho[1], q.z * tamanho[2]))
    lascas = []
    for _ in range(cortes):
        if cortes_de_lado:
            a = rnd.uniform(0.0, math.tau)
            n = Vector((math.cos(a), math.sin(a), rnd.uniform(-0.25, 0.35))).normalized()
        else:
            n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.1, 1.0))).normalized()
        alcance = max(v.co.dot(n) for v in bm.verts)
        menor = min(v.co.dot(n) for v in bm.verts)
        ponto = n * (alcance - (alcance - menor) * rnd.uniform(*funda))
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=0.0005, plane_co=ponto, plane_no=n, clear_outer=True)
        borda = [e for e in bm.edges if e.is_boundary]
        if borda:
            feito = bmesh.ops.holes_fill(bm, edges=borda, sides=0)
            lascas.extend(feito["faces"])
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
    vivas = [f for f in lascas if f.is_valid]
    quinas = set()
    for f in vivas:
        for e in f.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(25):
                quinas.add(e)
    if quinas and chanfro > 0.0:
        bmesh.ops.bevel(bm, geom=list(quinas), offset=chanfro, offset_type='OFFSET', segments=2,
                        profile=0.5, affect='EDGES', clamp_overlap=True)
    for f in vivas:
        if f.is_valid:
            f.smooth = False  # a lasca é plana; a quina chanfrada fica suave
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4], quad_method='BEAUTY',
                          ngon_method='BEAUTY')
    bm.normal_update()
    return bm


def colocar(bm, posicao, giro_z=0.0, inclinacao=(0.0, 0.0)):
    """Gira e move um bmesh (posição já no Blender)."""
    m = Matrix.Translation(posicao) @ Matrix.Rotation(giro_z, 4, 'Z') \
        @ Matrix.Rotation(inclinacao[0], 4, 'X') @ Matrix.Rotation(inclinacao[1], 4, 'Y')
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
    bm.normal_update()
    return bm


def reduzir(ob, razao):
    """Menos triângulos sem mudar a forma (o Decimate do Blender junta as
    arestas que menos fazem falta). Vale para pedras, que são densas."""
    mod = ob.modifiers.new("reduzir", 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    mod.ratio = razao
    selecionar([ob])
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob


def pintar(ob, cor_de):
    """Atributo "tinta" (cor por vértice): cor_de(posição, normal) -> (r, g, b)."""
    malha = ob.data
    tinta = malha.color_attributes.new("tinta", 'FLOAT_COLOR', 'POINT')
    for i, v in enumerate(malha.vertices):
        r, g, b = cor_de(v.co, v.normal)
        tinta.data[i].color = (r, g, b, 1.0)
    return ob


def assar_oclusao(objetos_alvo, forca=0.85, distancia=0.35, amostras=64):
    """Assa a oclusão de ambiente nos vértices e junta com a "tinta": a cor
    final ("Color") é tinta × oclusão. Os outros objetos da cena fazem sombra."""
    cena = bpy.context.scene
    cena.world.light_settings.distance = distancia
    cena.cycles.samples = amostras
    for ob in objetos_alvo:
        ao = ob.data.color_attributes.new("ao", 'FLOAT_COLOR', 'POINT')
        ob.data.color_attributes.active_color = ao
        ob.data.attributes.active_color = ao
    selecionar(objetos_alvo)
    cena.render.bake.target = 'VERTEX_COLORS'
    bpy.ops.object.bake(type='AO')
    for ob in objetos_alvo:
        malha = ob.data
        ao = malha.color_attributes["ao"]
        tinta = malha.color_attributes.get("tinta")
        final = malha.color_attributes.new("Color", 'BYTE_COLOR', 'POINT')
        for i in range(len(malha.vertices)):
            o = ao.data[i].color[0]
            o = 1.0 - forca * (1.0 - o)
            t = tinta.data[i].color if tinta else (1.0, 1.0, 1.0, 1.0)
            final.data[i].color = tuple(min(1.0, t[k] * o / GANHO) for k in range(3)) + (1.0,)
        malha.color_attributes.remove(malha.color_attributes["ao"])
        if malha.color_attributes.get("tinta"):
            malha.color_attributes.remove(malha.color_attributes["tinta"])
        final = malha.color_attributes["Color"]
        malha.color_attributes.active_color = final
        malha.attributes.active_color = final
        malha.color_attributes.render_color_index = malha.color_attributes.active_color_index
    cena.render.bake.target = 'IMAGE_TEXTURES'


def material_simples(nome, cor=(0.8, 0.8, 0.8), aspereza=0.9):
    """Material liso (a Godot troca pelo dela: pedra, neve, cinza)."""
    mat = bpy.data.materials.new(nome)
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*cor, 1.0)
    bsdf.inputs["Roughness"].default_value = aspereza
    return mat


# --- Madeira -------------------------------------------------------------------
# Cada peça de madeira guarda, em cada canto de face, as "coordenadas do veio":
#   gA = (ao longo do veio, através 1), gB = (através 2, tipo da face).
# O miolo da árvore (a medula) é a reta "através 1 = 0 e através 2 = 0": a
# distância até ela dá os anéis. Na tábua, a medula fica fora da tábua (os
# anéis aparecem como arcos no topo e como listras compridas nas faces).
# "carvao" (0 a 1, por vértice) queima a madeira.

def _veio(bm, medula, tipo_de, desvio_longo=0.0):
    """Grava gA e gB num bmesh ainda nas coordenadas da peça (x = veio)."""
    ga = bm.loops.layers.uv.new("gA")
    gb = bm.loops.layers.uv.new("gB")
    for f in bm.faces:
        tipo = tipo_de(f)
        for canto in f.loops:
            p = canto.vert.co
            canto[ga].uv = (p.x + desvio_longo, p.y - medula[0])
            canto[gb].uv = (p.z - medula[1], tipo)


def tabua(comprimento, largura, espessura, semente, chanfro=0.006, torto=0.004, medula=None, passo=0.32):
    """Uma tábua (x = comprimento, y = largura, z = espessura), centrada.
    "passo": a cada quanto a tábua ganha um corte para poder empenar (17.8:
    as do piso do deque usam passos longos, para terem menos vértices)."""
    rnd = random.Random(semente)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(comprimento, largura, espessura), verts=bm.verts[:])
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=chanfro, offset_type='OFFSET', segments=2,
                    profile=0.5, affect='EDGES', clamp_overlap=True)
    # Cortes ao longo para a tábua poder empenar um pouco.
    passos = max(1, int(comprimento / passo))
    for k in range(1, passos):
        x = -comprimento / 2.0 + comprimento * k / passos
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=0.0001, plane_co=(x, 0, 0), plane_no=(1, 0, 0))
    desvio = Vector((rnd.uniform(-50, 50), rnd.uniform(-50, 50), 0.0))
    for v in bm.verts:
        t = v.co.x / max(comprimento, 0.01)
        v.co.z += torto * noise.noise(Vector((t * 2.0, 0.3, 0.0)) + desvio)
        v.co.y += torto * 0.5 * noise.noise(Vector((t * 1.5, 4.0, 0.0)) + desvio)
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    if medula is None:
        medula = (rnd.uniform(-0.25, 0.25), -rnd.uniform(0.12, 0.35))
    _veio(bm, medula, lambda f: TOPO if abs(f.normal.x) > 0.8 else LISO, rnd.uniform(0, 5))
    return bm


def orientar(bm, direcao, largura=None, centro=(0.0, 0.0, 0.0)):
    """Gira uma peça feita ao longo do x (y = largura, z = espessura) para o x
    apontar em "direcao" e o y ficar o mais perto possível de "largura" (no
    Blender); depois a leva até "centro". Sem "largura", a peça fica deitada
    (o y na horizontal); de pé (x vertical), o y fica no y do Blender."""
    x = Vector(direcao).normalized()
    if largura is None:
        largura = Vector((0.0, 0.0, 1.0)).cross(x) if abs(x.z) < 0.95 else Vector((0.0, 1.0, 0.0))
    largura = Vector(largura)
    y = (largura - x * x.dot(largura)).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(centro)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
    bm.normal_update()
    return bm


def tabua_entre(a, b, largura, espessura, semente, lado=None, **opcoes):
    """Uma tábua de "a" até "b" (posições do Blender), com a largura virada
    para "lado" (veja orientar). O veio corre de a até b."""
    a, b = Vector(a), Vector(b)
    bm = tabua((b - a).length, largura, espessura, semente, **opcoes)
    return orientar(bm, b - a, lado, (a + b) / 2.0)


# --- Metal ---------------------------------------------------------------------

def caixa(tamanho, centro=(0.0, 0.0, 0.0), chanfro=0.003):
    """Uma caixa com as quinas chanfradas (ferro, latão), sem veio."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=tamanho, verts=bm.verts[:])
    if chanfro > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=chanfro, offset_type='OFFSET', segments=1,
                        profile=0.5, affect='EDGES', clamp_overlap=True)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=centro)
    bm.normal_update()
    return bm


def cilindro(raio_baixo, raio_cima, altura, lados=24, chanfro=0.0, suave=True):
    """Um cilindro (ou cone) em pé no z, centrado na origem."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lados,
                          radius1=raio_baixo, radius2=raio_cima, depth=altura)
    if chanfro > 0.0:
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if e.calc_face_angle(0.0) > math.radians(50)],
                        offset=chanfro, offset_type='OFFSET', segments=2, profile=0.5,
                        affect='EDGES', clamp_overlap=True)
    for f in bm.faces:
        # As tampas ficam chapadas; o lado, liso.
        f.smooth = suave and abs(f.normal.z) < 0.9
    bm.normal_update()
    return bm


def tubo(perfil, lados=32, eixo=None, centro=(0.0, 0.0, 0.0)):
    """Uma peça torneada (latão): "perfil" = [(z, raio), ...] de baixo para
    cima, girado em volta do z; depois apontado para "eixo" (o z vira o eixo)."""
    bm = bmesh.new()
    aneis = []
    for z, r in perfil:
        anel = []
        for k in range(lados):
            a = math.tau * k / lados
            anel.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        aneis.append(anel)
    for i in range(len(aneis) - 1):
        for k in range(lados):
            k2 = (k + 1) % lados
            bm.faces.new((aneis[i][k], aneis[i][k2], aneis[i + 1][k2], aneis[i + 1][k]))
    bm.faces.new(list(reversed(aneis[0])))
    bm.faces.new(aneis[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.smooth = len(f.verts) == 4
    if eixo is not None:
        z = Vector(eixo).normalized()
        x = Vector((1.0, 0.0, 0.0)) if abs(z.x) < 0.9 else Vector((0.0, 1.0, 0.0))
        x = (x - z * z.dot(x)).normalized()
        y = z.cross(x)
        m = Matrix((x, y, z)).transposed().to_4x4()
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=centro)
    bm.normal_update()
    return bm


def tora(comprimento, raio, semente, lados=12, afina=0.85, chanfro=0.008, entorta=0.012):
    """Uma tora redonda com casca (x = comprimento), centrada."""
    rnd = random.Random(semente)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lados,
                          radius1=raio, radius2=raio * afina, depth=comprimento)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, 'Y'))
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if e.calc_face_angle(0.0) > math.radians(50)],
                    offset=chanfro, offset_type='OFFSET', segments=2, profile=0.5, affect='EDGES',
                    clamp_overlap=True)
    passos = max(2, int(comprimento / 0.12))
    for k in range(1, passos):
        x = -comprimento / 2.0 + comprimento * k / passos
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=0.0001, plane_co=(x, 0, 0), plane_no=(1, 0, 0))
    desvio = Vector((rnd.uniform(-50, 50), rnd.uniform(-50, 50), 0.0))
    for v in bm.verts:
        t = v.co.x / comprimento
        v.co.y += entorta * noise.noise(Vector((t * 1.7, 0.0, 0.0)) + desvio)
        v.co.z += entorta * noise.noise(Vector((t * 1.7, 9.0, 0.0)) + desvio)
        a = math.atan2(v.co.z, v.co.y)
        r = math.hypot(v.co.y, v.co.z)
        if r > raio * 0.5:  # a casca: sulcos ao longo
            v.co.y *= 1.0 + 0.05 * noise.noise(Vector((a * 2.0, t * 3.0, 3.0)) + desvio)
            v.co.z *= 1.0 + 0.05 * noise.noise(Vector((a * 2.0, t * 3.0, 3.0)) + desvio)
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    _veio(bm, (0.0, 0.0), lambda f: TOPO if abs(f.normal.x) > 0.7 else CASCA, rnd.uniform(0, 5))
    return bm


def lenha(comprimento, raio, semente, abertura=None, chanfro=0.006):
    """Uma acha de lenha rachada (um gomo da tora: casca no arco, faces
    rachadas nos lados), com x = comprimento; a medula fica em y = z = 0."""
    rnd = random.Random(semente)
    abertura = abertura or rnd.uniform(1.3, 1.9)
    bm = bmesh.new()
    contorno = [Vector((0.0, raio * 0.08 * rnd.uniform(-1, 1), 0.0))]
    arco = 6
    for k in range(arco + 1):
        a = -abertura / 2.0 + abertura * k / arco
        r = raio * (1.0 + 0.04 * rnd.uniform(-1, 1))
        contorno.append(Vector((0.0, math.cos(a) * r, math.sin(a) * r)))
    # Um ponto no meio de cada lado rachado (a rachadura não é reta).
    pontos = [contorno[0]]
    meio1 = contorno[1] * 0.5 + Vector((0, 0, raio * 0.05 * rnd.uniform(-1, 1)))
    pontos.append(meio1)
    pontos.extend(contorno[1:])
    meio2 = contorno[-1] * 0.5 + Vector((0, 0, raio * 0.05 * rnd.uniform(-1, 1)))
    pontos.append(meio2)
    verts = [bm.verts.new(p + Vector((-comprimento / 2.0, 0, 0))) for p in pontos]
    face = bm.faces.new(verts)
    feito = bmesh.ops.extrude_face_region(bm, geom=[face])
    novos = [g for g in feito["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=novos, vec=(comprimento, 0, 0))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if e.calc_face_angle(0.0) > math.radians(40)],
                    offset=chanfro, offset_type='OFFSET', segments=2, profile=0.5, affect='EDGES',
                    clamp_overlap=True)
    passos = max(2, int(comprimento / 0.12))
    for k in range(1, passos):
        x = -comprimento / 2.0 + comprimento * k / passos
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=0.0001, plane_co=(x, 0, 0), plane_no=(1, 0, 0))
    desvio = Vector((rnd.uniform(-50, 50), rnd.uniform(-50, 50), 0.0))
    for v in bm.verts:
        t = v.co.x / comprimento
        v.co.y += 0.008 * noise.noise(Vector((t * 1.7, 0.0, 0.0)) + desvio)
        v.co.z += 0.008 * noise.noise(Vector((t * 1.7, 9.0, 0.0)) + desvio)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()

    def tipo(f):
        if abs(f.normal.x) > 0.7:
            return TOPO
        c = f.calc_center_median()
        return CASCA if math.hypot(c.y, c.z) > raio * 0.82 else RACHADO
    _veio(bm, (0.0, 0.0), tipo, rnd.uniform(0, 5))
    return bm


def queimar(ob, carvao_de):
    """Atributo "carvao" por vértice: carvao_de(posição, normal) -> 0 a 1."""
    malha = ob.data
    atributo = malha.attributes.new("carvao", 'FLOAT', 'POINT')
    for i, v in enumerate(malha.vertices):
        atributo.data[i].value = max(0.0, min(1.0, carvao_de(v.co, v.normal)))


def cor_entrada(no, nome):
    """A entrada de COR de um nó Mix (ele tem "A" e "B" de número, vetor e cor)."""
    return next(s for s in no.inputs if s.name == nome and s.type == 'RGBA')


def cor_saida(no):
    """A saída de COR de um nó Mix."""
    return next(s for s in no.outputs if s.name == "Result" and s.type == 'RGBA')


def _no(arvore, tipo, x=0, y=0, **valores):
    n = arvore.nodes.new(tipo)
    n.location = (x, y)
    for chave, valor in valores.items():
        setattr(n, chave, valor)
    return n


def material_madeira(nome, clara, escura, cinza=0.0, aneis=180.0, gasto=0.5):
    """O material de madeira procedural do Cycles (só para assar).

    clara/escura: as duas cores dos anéis; cinza: o quanto o tempo desbotou
    (madeira ao ar livre fica prateada); aneis: anéis por metro; gasto: o
    quanto as quinas ficam claras (gastas pelo uso)."""
    mat = bpy.data.materials.new(nome)
    arv = mat.node_tree
    for n in list(arv.nodes):
        arv.nodes.remove(n)
    L = arv.links.new
    saida_no = _no(arv, "ShaderNodeOutputMaterial", 1400, 0)
    bsdf = _no(arv, "ShaderNodeBsdfPrincipled", 1150, 0)
    L(bsdf.outputs[0], saida_no.inputs["Surface"])

    ga = _no(arv, "ShaderNodeUVMap", -1600, 200, uv_map="gA")
    gb = _no(arv, "ShaderNodeUVMap", -1600, -100, uv_map="gB")
    sa = _no(arv, "ShaderNodeSeparateXYZ", -1400, 200)
    sb = _no(arv, "ShaderNodeSeparateXYZ", -1400, -100)
    L(ga.outputs[0], sa.inputs[0])
    L(gb.outputs[0], sb.inputs[0])
    pos = _no(arv, "ShaderNodeCombineXYZ", -1200, 100)
    L(sa.outputs[0], pos.inputs[0])
    L(sa.outputs[1], pos.inputs[1])
    L(sb.outputs[0], pos.inputs[2])
    tipo = sb.outputs[1]

    def comparar(valor, x, y):
        c = _no(arv, "ShaderNodeMath", x, y, operation='COMPARE')
        L(tipo, c.inputs[0])
        c.inputs[1].default_value = valor
        c.inputs[2].default_value = 0.5
        return c.outputs[0]
    e_topo = comparar(TOPO, -1000, -300)
    e_casca = comparar(CASCA, -1000, -400)
    e_rachado = comparar(RACHADO, -1000, -500)

    # Os anéis: distância até a medula, torta pelo ruído.
    trans = _no(arv, "ShaderNodeVectorMath", -1000, 200, operation='MULTIPLY')
    L(pos.outputs[0], trans.inputs[0])
    trans.inputs[1].default_value = (0.0, 1.0, 1.0)
    raio = _no(arv, "ShaderNodeVectorMath", -800, 200, operation='LENGTH')
    L(trans.outputs[0], raio.inputs[0])
    escala_ruido = _no(arv, "ShaderNodeVectorMath", -1000, 0, operation='MULTIPLY')
    L(pos.outputs[0], escala_ruido.inputs[0])
    escala_ruido.inputs[1].default_value = (1.2, 9.0, 9.0)
    ruido = _no(arv, "ShaderNodeTexNoise", -800, 0)
    ruido.inputs["Scale"].default_value = 1.0
    ruido.inputs["Detail"].default_value = 4.0
    L(escala_ruido.outputs[0], ruido.inputs["Vector"])
    torto = _no(arv, "ShaderNodeMath", -600, 100, operation='MULTIPLY_ADD')
    L(ruido.outputs["Fac"], torto.inputs[0])
    torto.inputs[1].default_value = 0.018
    L(raio.outputs[1], torto.inputs[2])
    voltas = _no(arv, "ShaderNodeMath", -450, 100, operation='MULTIPLY')
    L(torto.outputs[0], voltas.inputs[0])
    voltas.inputs[1].default_value = aneis
    frac = _no(arv, "ShaderNodeMath", -300, 100, operation='FRACT')
    L(voltas.outputs[0], frac.inputs[0])
    # O lenho tardio (o risco escuro do anel) é a parte final da volta.
    anel = _no(arv, "ShaderNodeMapRange", -150, 100)
    L(frac.outputs[0], anel.inputs["Value"])
    anel.inputs["From Min"].default_value = 0.55
    anel.inputs["From Max"].default_value = 0.95
    # As fibras: riscos finos ao longo do veio.
    escala_fibra = _no(arv, "ShaderNodeVectorMath", -1000, -150, operation='MULTIPLY')
    L(pos.outputs[0], escala_fibra.inputs[0])
    escala_fibra.inputs[1].default_value = (6.0, 260.0, 260.0)
    fibra = _no(arv, "ShaderNodeTexNoise", -800, -150)
    fibra.inputs["Scale"].default_value = 1.0
    fibra.inputs["Detail"].default_value = 2.0
    L(escala_fibra.outputs[0], fibra.inputs["Vector"])
    # A variação de tom de uma peça para outra e ao longo dela.
    escala_mancha = _no(arv, "ShaderNodeVectorMath", -1000, -250, operation='MULTIPLY')
    L(pos.outputs[0], escala_mancha.inputs[0])
    escala_mancha.inputs[1].default_value = (2.5, 6.0, 6.0)
    mancha = _no(arv, "ShaderNodeTexNoise", -800, -250)
    mancha.inputs["Scale"].default_value = 1.0
    L(escala_mancha.outputs[0], mancha.inputs["Vector"])

    tom = _no(arv, "ShaderNodeMath", 0, 100, operation='MULTIPLY_ADD')
    L(anel.outputs[0], tom.inputs[0])
    tom.inputs[1].default_value = 0.65
    fibra_peso = _no(arv, "ShaderNodeMath", -150, -100, operation='MULTIPLY')
    L(fibra.outputs["Fac"], fibra_peso.inputs[0])
    fibra_peso.inputs[1].default_value = 0.45
    L(fibra_peso.outputs[0], tom.inputs[2])
    cor = _no(arv, "ShaderNodeMix", 200, 100, data_type='RGBA')
    L(tom.outputs[0], cor.inputs["Factor"])
    cor_entrada(cor, "A").default_value = (*clara, 1.0)
    cor_entrada(cor, "B").default_value = (*escura, 1.0)
    # O topo (anéis) é mais escuro; a face rachada, mais clara e fibrosa.
    topo_cor = _no(arv, "ShaderNodeMix", 350, 100, data_type='RGBA', blend_type='MULTIPLY')
    L(e_topo, topo_cor.inputs["Factor"])
    L(cor_saida(cor), cor_entrada(topo_cor, "A"))
    cor_entrada(topo_cor, "B").default_value = (0.62, 0.55, 0.5, 1.0)
    rachado_cor = _no(arv, "ShaderNodeMix", 500, 100, data_type='RGBA', blend_type='SCREEN')
    fator_r = _no(arv, "ShaderNodeMath", 350, -50, operation='MULTIPLY')
    L(e_rachado, fator_r.inputs[0])
    fator_r.inputs[1].default_value = 0.15
    L(fator_r.outputs[0], rachado_cor.inputs["Factor"])
    L(cor_saida(topo_cor), cor_entrada(rachado_cor, "A"))
    cor_entrada(rachado_cor, "B").default_value = (0.5, 0.38, 0.26, 1.0)
    # A casca: escura, em placas (Voronoi esticado ao longo).
    escala_casca = _no(arv, "ShaderNodeVectorMath", -1000, -400, operation='MULTIPLY')
    L(pos.outputs[0], escala_casca.inputs[0])
    escala_casca.inputs[1].default_value = (9.0, 40.0, 40.0)
    placas = _no(arv, "ShaderNodeTexVoronoi", -800, -400, feature='DISTANCE_TO_EDGE')
    placas.inputs["Scale"].default_value = 1.0
    L(escala_casca.outputs[0], placas.inputs["Vector"])
    sulco = _no(arv, "ShaderNodeMapRange", -600, -400)
    L(placas.outputs["Distance"], sulco.inputs["Value"])
    sulco.inputs["From Min"].default_value = 0.0
    sulco.inputs["From Max"].default_value = 0.18
    casca_cor = _no(arv, "ShaderNodeMix", -400, -400, data_type='RGBA')
    L(sulco.outputs[0], casca_cor.inputs["Factor"])
    cor_entrada(casca_cor, "A").default_value = (0.03, 0.025, 0.02, 1.0)
    cor_entrada(casca_cor, "B").default_value = (0.16, 0.13, 0.1, 1.0)
    com_casca = _no(arv, "ShaderNodeMix", 650, 100, data_type='RGBA')
    L(e_casca, com_casca.inputs["Factor"])
    L(cor_saida(rachado_cor), cor_entrada(com_casca, "A"))
    L(cor_saida(casca_cor), cor_entrada(com_casca, "B"))
    # O tempo: madeira ao ar livre desbota para o cinza.
    desbota = _no(arv, "ShaderNodeMix", 800, 100, data_type='RGBA')
    desbota.inputs["Factor"].default_value = cinza
    L(cor_saida(com_casca), cor_entrada(desbota, "A"))
    cor_entrada(desbota, "B").default_value = (0.2, 0.19, 0.18, 1.0)
    variacao = _no(arv, "ShaderNodeMapRange", -600, -250)
    L(mancha.outputs["Fac"], variacao.inputs["Value"])
    variacao.inputs["To Min"].default_value = 0.8
    variacao.inputs["To Max"].default_value = 1.15
    varia = _no(arv, "ShaderNodeMix", 950, 100, data_type='RGBA', blend_type='MULTIPLY')
    varia.inputs["Factor"].default_value = 1.0
    L(cor_saida(desbota), cor_entrada(varia, "A"))
    valor_cor = _no(arv, "ShaderNodeCombineColor", -400, -250)
    for k in range(3):
        L(variacao.outputs[0], valor_cor.inputs[k])
    L(valor_cor.outputs[0], cor_entrada(varia, "B"))
    # As quinas gastas (claras) e os cantos escuros (oclusão).
    quina = _no(arv, "ShaderNodeAmbientOcclusion", 600, -250, inside=True, only_local=True)
    quina.inputs["Distance"].default_value = 0.012
    gasta = _no(arv, "ShaderNodeMath", 800, -250, operation='MULTIPLY')
    inverte = _no(arv, "ShaderNodeMath", 700, -250, operation='SUBTRACT')
    inverte.inputs[0].default_value = 1.0
    L(quina.outputs["AO"], inverte.inputs[1])
    L(inverte.outputs[0], gasta.inputs[0])
    gasta.inputs[1].default_value = gasto
    clareia = _no(arv, "ShaderNodeMix", 1000, -50, data_type='RGBA', blend_type='SCREEN')
    L(gasta.outputs[0], clareia.inputs["Factor"])
    L(cor_saida(varia), cor_entrada(clareia, "A"))
    cor_entrada(clareia, "B").default_value = (0.32, 0.27, 0.22, 1.0)
    canto = _no(arv, "ShaderNodeAmbientOcclusion", 800, -400)
    canto.inputs["Distance"].default_value = 0.12
    escurece = _no(arv, "ShaderNodeMapRange", 950, -400)
    L(canto.outputs["AO"], escurece.inputs["Value"])
    escurece.inputs["To Min"].default_value = 0.35
    escurece.inputs["To Max"].default_value = 1.0
    sombra = _no(arv, "ShaderNodeMix", 1100, -150, data_type='RGBA', blend_type='MULTIPLY')
    sombra.inputs["Factor"].default_value = 1.0
    L(cor_saida(clareia), cor_entrada(sombra, "A"))
    sombra_cor = _no(arv, "ShaderNodeCombineColor", 1000, -400)
    for k in range(3):
        L(escurece.outputs[0], sombra_cor.inputs[k])
    L(sombra_cor.outputs[0], cor_entrada(sombra, "B"))
    # O carvão: preto, rachado em quadradinhos (o "couro de jacaré" do fogo).
    carvao = _no(arv, "ShaderNodeAttribute", 600, -600, attribute_name="carvao")
    escala_jacare = _no(arv, "ShaderNodeVectorMath", 400, -700, operation='MULTIPLY')
    L(pos.outputs[0], escala_jacare.inputs[0])
    escala_jacare.inputs[1].default_value = (30.0, 45.0, 45.0)
    jacare = _no(arv, "ShaderNodeTexVoronoi", 600, -750, feature='DISTANCE_TO_EDGE')
    jacare.inputs["Scale"].default_value = 1.0
    L(escala_jacare.outputs[0], jacare.inputs["Vector"])
    racha = _no(arv, "ShaderNodeMapRange", 800, -750)
    L(jacare.outputs["Distance"], racha.inputs["Value"])
    racha.inputs["From Max"].default_value = 0.12
    carvao_cor = _no(arv, "ShaderNodeMix", 950, -700, data_type='RGBA')
    L(racha.outputs[0], carvao_cor.inputs["Factor"])
    cor_entrada(carvao_cor, "A").default_value = (0.005, 0.004, 0.004, 1.0)
    cor_entrada(carvao_cor, "B").default_value = (0.035, 0.03, 0.028, 1.0)
    queima = _no(arv, "ShaderNodeMapRange", 800, -600)
    L(carvao.outputs["Fac"], queima.inputs["Value"])
    queima.inputs["From Min"].default_value = 0.15
    queima.inputs["From Max"].default_value = 0.75
    final = _no(arv, "ShaderNodeMix", 1150, -350, data_type='RGBA')
    L(queima.outputs[0], final.inputs["Factor"])
    L(cor_saida(sombra), cor_entrada(final, "A"))
    L(cor_saida(carvao_cor), cor_entrada(final, "B"))
    L(cor_saida(final), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    # O relevo: anéis, fibras, sulcos da casca e as rachas do carvão.
    altura = _no(arv, "ShaderNodeMath", 600, -900, operation='MULTIPLY_ADD')
    L(fibra.outputs["Fac"], altura.inputs[0])
    altura.inputs[1].default_value = 0.6
    L(anel.outputs[0], altura.inputs[2])
    casca_alt = _no(arv, "ShaderNodeMath", 750, -900, operation='MULTIPLY_ADD')
    L(e_casca, casca_alt.inputs[0])
    L(sulco.outputs[0], casca_alt.inputs[1])
    L(altura.outputs[0], casca_alt.inputs[2])
    carvao_alt = _no(arv, "ShaderNodeMath", 900, -900, operation='MULTIPLY_ADD')
    L(queima.outputs[0], carvao_alt.inputs[0])
    L(racha.outputs[0], carvao_alt.inputs[1])
    L(casca_alt.outputs[0], carvao_alt.inputs[2])
    relevo = _no(arv, "ShaderNodeBump", 1000, -900)
    relevo.inputs["Strength"].default_value = 0.35
    relevo.inputs["Distance"].default_value = 0.0015
    L(carvao_alt.outputs[0], relevo.inputs["Height"])
    L(relevo.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def uv_para_assar(objetos, margem=0.004):
    """Um mapa UV de verdade, sem sobreposição ("bake"), para a textura.
    Vários objetos dividem a mesma textura (as ilhas são arrumadas juntas)."""
    if not isinstance(objetos, (list, tuple)):
        objetos = [objetos]
    for ob in objetos:
        uv = ob.data.uv_layers.new(name="bake")
        ob.data.uv_layers.active = uv
    selecionar(objetos)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margem, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=margem, rotate=True)
    bpy.ops.object.mode_set(mode='OBJECT')


def _imagem(nome, tamanho, dados=False):
    img = bpy.data.images.new(nome, tamanho, tamanho, alpha=False, float_buffer=False)
    if dados:
        img.colorspace_settings.name = 'Non-Color'
    return img


def assar_textura(objetos, mat, tamanho, nome, amostras=32, emissao=False):
    """Assa o material procedural nas texturas (cor e relevo; e o brilho, se
    houver) e troca o material dos objetos por um simples com essas texturas,
    que o glTF leva. Devolve o material novo."""
    if not isinstance(objetos, (list, tuple)):
        objetos = [objetos]
    cena = bpy.context.scene
    cena.cycles.samples = amostras
    cena.render.bake.target = 'IMAGE_TEXTURES'
    arv = mat.node_tree
    alvo = arv.nodes.new("ShaderNodeTexImage")
    arv.nodes.active = alvo
    selecionar(objetos)
    cor = _imagem(nome + "_cor", tamanho)
    alvo.image = cor
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=6)
    relevo = _imagem(nome + "_relevo", tamanho, dados=True)
    alvo.image = relevo
    bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', margin=6)
    brilho = None
    if emissao:
        brilho = _imagem(nome + "_brilho", tamanho)
        alvo.image = brilho
        bpy.ops.object.bake(type='EMIT', margin=6)
    for img in (cor, relevo, brilho):
        if img is not None:
            img.pack()

    novo = bpy.data.materials.new(nome)
    arv2 = novo.node_tree
    bsdf = arv2.nodes["Principled BSDF"]
    uvn = arv2.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "bake"
    t_cor = arv2.nodes.new("ShaderNodeTexImage")
    t_cor.image = cor
    arv2.links.new(uvn.outputs[0], t_cor.inputs[0])
    arv2.links.new(t_cor.outputs["Color"], bsdf.inputs["Base Color"])
    t_rel = arv2.nodes.new("ShaderNodeTexImage")
    t_rel.image = relevo
    arv2.links.new(uvn.outputs[0], t_rel.inputs[0])
    mapa = arv2.nodes.new("ShaderNodeNormalMap")
    mapa.uv_map = "bake"
    arv2.links.new(t_rel.outputs["Color"], mapa.inputs["Color"])
    arv2.links.new(mapa.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.85
    if brilho is not None:
        t_bri = arv2.nodes.new("ShaderNodeTexImage")
        t_bri.image = brilho
        arv2.links.new(uvn.outputs[0], t_bri.inputs[0])
        arv2.links.new(t_bri.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    for ob in objetos:
        ob.data.materials.clear()
        ob.data.materials.append(novo)
        # Só o mapa "bake" vai para a Godot.
        for nome_uv in ("gA", "gB"):
            camada = ob.data.uv_layers.get(nome_uv)
            if camada is not None:
                ob.data.uv_layers.remove(camada)
        if ob.data.attributes.get("carvao") is not None:
            ob.data.attributes.remove(ob.data.attributes["carvao"])
    return novo


def exportar(objetos, caminho):
    """Exporta só estes objetos para um .glb (Y para cima).

    Para o arquivo ficar pequeno: sem tangentes (a Godot gera as mesmas na
    importação), a cor em 16 bits e o UV só onde ele é usado. Quem não tem o
    mapa "bake" (a textura assada) mas tem o "gA" (o veio, em metros) leva o
    gA como UV: é o veio que a madeira da Godot lê."""
    for ob in objetos:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method='BEAUTY', ngon_method='BEAUTY')
        bm.to_mesh(ob.data)
        bm.free()
        camadas = ob.data.uv_layers
        if camadas.get("bake") is None and camadas.get("gA") is not None:
            camadas["gA"].name = "veio"
        for nome_uv in ("gA", "gB"):
            camada = camadas.get(nome_uv)
            if camada is not None:
                camadas.remove(camada)
        if len(camadas):
            camadas.active = camadas[0]
            camadas[0].active_render = True
    selecionar(objetos)
    bpy.ops.export_scene.gltf(
        filepath=caminho, export_format='GLB', use_selection=True, export_apply=True,
        export_yup=True, export_tangents=False, export_normals=True, export_texcoords=True,
        export_vertex_color='ACTIVE', export_all_vertex_colors=False,
        export_materials='EXPORT', export_image_format='JPEG', export_jpeg_quality=88,
        export_cameras=False, export_lights=False, export_animations=False)
    tamanho = os.path.getsize(caminho)
    triangulos = 0
    for ob in objetos:
        ob.data.calc_loop_triangles()
        triangulos += len(ob.data.loop_triangles)
        print("  %-14s %6d triângulos %6d vértices" % (ob.name, len(ob.data.loop_triangles), len(ob.data.vertices)))
    print("GLB: %s (%.0f KB, %d triângulos)" % (caminho, tamanho / 1024.0, triangulos))
