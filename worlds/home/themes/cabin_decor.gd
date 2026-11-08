extends HomeDecor
## O enfeite da CABANA (Fase 13.12): a lareira de pedra, com fogo que tremula,
## duas poltronas viradas para ela sobre um tapete, lampiões de ferro
## pendurados nas vigas e um vaso com um arbusto. O arbusto é do Kenney Nature
## Kit e o fogo é um shader.
##
## Desde a sala de 9 x 7 m (Fase 17.4b), a lareira fica no canto de estar da
## parede norte (Home.LIVING_CORNER_WIDTH, o mesmo canto do sofá no loft), com
## o vaso no canto: as paredes oeste e leste são dos móveis. As
## peças não tampam os móveis de nenhuma disposição, nem a porta, nem a janela.
## Cada peça grande é um nó com a marca "cabin_piece" (o teste acha por ela).
##
## O aconchego (Fase 17.9.2), no sistema visual aprovado do loft (paleta de
## base fria com madeira e tecido quentes; luz em poças quentes com meio-tom
## frio entre elas; cantos cheios e passagens livres):
##   - a poltrona e a lareira são modelos do Blender (assets/models/home/, lidos
##     pelo HomeModels): a poltrona de madeira aparente e estofado redondo, a
##     lareira de pedra aparelhada com soleira, consolo e grade. O fogo, a luz,
##     o lampião do consolo, a chaminé (que acompanha a altura da sala) e as
##     colisões continuam aqui;
##   - o âmbar fica perto do fogo, dos lampiões e da vela: as luzes são curtas
##     e caem rápido, e entre elas fica o ambiente frio do perfil;
##   - os tecidos são de lã crua e musgo apagado, e não laranja;
##   - o canto de estar ganhou objetos: a manta caída numa poltrona, um toco de
##     árvore de mesinha (caneca, livros e uma vela acesa), o cesto de lenha
##     ao lado da lareira e velas no consolo.

const RUG_SHADER: Shader = preload("res://worlds/home/home_rug_vintage.gdshader")
const BUSH_SCENE: PackedScene = preload("res://assets/kenney/nature-kit/plant_bush.glb")
const CRACKLE_SOUND: AudioStream = preload("res://assets/generated/fire_crackle.wav")

## O vaso: largura do arbusto, no canto noroeste (a PIECE_GAP das paredes).
const PLANT_WIDTH: float = 0.7
const PIECE_GAP: float = 0.05
const PLANT_SPOT: Vector2 = Vector2(-Home.ROOM_SIZE.x / 2.0 + PIECE_GAP + PLANT_WIDTH / 2.0,
		-Home.ROOM_SIZE.z / 2.0 + PIECE_GAP + PLANT_WIDTH / 2.0)
## A lareira: encostada na parede norte, ao lado do vaso (o consolo é 0,2 m
## mais largo que ela). As poltronas ficam a ARMCHAIR_FROM_WALL da parede e a
## ARMCHAIR_SPREAD do meio dela, para os lados: longe da parede oeste, que é
## dos móveis.
const FIREPLACE_WIDTH: float = 1.8
const FIREPLACE_DEPTH: float = 0.7
const FIREPLACE_X: float = PLANT_SPOT.x + PLANT_WIDTH / 2.0 + PIECE_GAP + (FIREPLACE_WIDTH + 0.2) / 2.0
const ARMCHAIR_FROM_WALL: float = 1.5
const ARMCHAIR_SPREAD: float = 0.55
## Os modelos (assets/models/home/; o contrato está no README.md da pasta).
const ARMCHAIR_MODEL: String = "armchair"
const FIREPLACE_MODEL: String = "fireplace"
## Medidas da lareira que o modelo segue (o contrato): o degrau de pedra onde
## fica o fogo, a boca (largura e alto), a altura do consolo e a chaminé.
const FIRE_FLOOR: float = 0.3
const OPENING_WIDTH: float = 1.0
const OPENING_TOP: float = 1.17
const MANTEL_Y: float = 1.57
const MANTEL_DEPTH: float = 0.82
const CHIMNEY_DEPTH: float = 0.5
const CHIMNEY_WIDTH: float = 1.4
## Os tons dos modelos (cor linear: o HomeModels multiplica pela cor dos
## vértices). A pedra é cinza-fria (a Rock058 já é escura e tem veios cor de
## ferrugem: um tom quente demais os acendia em laranja sob o fogo).
const STONE_TINT: Color = Color(0.56, 0.6, 0.64)
const STONE_METERS: float = 1.6
const MANTEL_TINT: Color = Color(0.2, 0.13, 0.085)
const SOOT_TINT: Color = Color(0.035, 0.029, 0.024)
const IRON_TINT: Color = Color(0.075, 0.07, 0.065)
## A poltrona: madeira escura e lã crua (menos saturada que o laranja de antes).
const CHAIR_WOOD_TINT: Color = Color(0.13, 0.085, 0.055)
const CHAIR_FABRIC_TINT: Color = Color(0.3, 0.24, 0.19)
## A chaminé (uma caixa, sem cor nos vértices): pedra em fiadas (a
## PavingStones070 do projeto, de pé), cinza como a da lareira. A Rock058 lisa
## numa caixa daquele tamanho virava um rochedo só.
const CHIMNEY_TEXTURE: String = "PavingStones070"
const CHIMNEY_METERS: float = 1.1
const CHIMNEY_TINT: Color = Color(0.5, 0.5, 0.52)
const IRON_COLOR: Color = Color(0.08, 0.075, 0.07)
const FIRE_COLOR: Color = Color(1.0, 0.55, 0.25)
## O fogo: forte e curto (o âmbar fica no canto da lareira), com sombra: as
## poltronas desenham a sombra delas no tapete.
const FIRE_ENERGY: float = 3.4
const FIRE_RANGE: float = 5.5
const FIRE_ATTENUATION: float = 1.7
## Os lampiões das vigas: poças curtas (o resto da sala fica no meio-tom frio).
const LANTERN_RANGE: float = 5.0
const LANTERN_ATTENUATION: float = 1.3
## A manta caída na poltrona da esquerda: tricô cinza-azulado (frio, para
## contrastar com a lã crua e com o fogo).
const THROW_COLOR: Color = Color(0.3, 0.33, 0.36)
const POT_COLOR: Color = Color(0.42, 0.28, 0.2)
## O tapete (o mesmo antigo e gasto do loft, no tom da cabana): musgo apagado,
## creme e ferrugem.
const RUG_FIELD: Color = Color(0.2, 0.22, 0.18)
const RUG_PATTERN: Color = Color(0.56, 0.5, 0.4)
const RUG_DARK: Color = Color(0.09, 0.1, 0.09)
const RUG_ACCENT: Color = Color(0.42, 0.2, 0.13)
const RUG_SIZE: Vector2 = Vector2(2.6, 1.8)
## O toco de mesinha (ao lado da poltrona da direita, longe do fogo) e o cesto
## de lenha (entre ele e a lareira): na beira do canto, fora da janela.
const STUMP_SPOT: Vector2 = Vector2(FIREPLACE_X + 1.28, -Home.ROOM_SIZE.z / 2.0 + 1.62)
const STUMP_RADIUS: float = 0.2
const STUMP_HEIGHT: float = 0.46
const BASKET_SPOT: Vector2 = Vector2(FIREPLACE_X + 1.3, -Home.ROOM_SIZE.z / 2.0 + 0.86)
const BASKET_RADIUS: float = 0.2
## A vela do toco: uma luz pequena e curta, sem sombra (fraca demais para
## aparecer no vidro da janela).
const CANDLE_ENERGY: float = 0.35
const CANDLE_RANGE: float = 1.6
const CANDLE_COLOR: Color = Color(1.0, 0.62, 0.3)
const BOOK_COLORS: Array[Color] = [Color(0.36, 0.14, 0.1), Color(0.16, 0.22, 0.2), Color(0.5, 0.42, 0.3)]
const MUG_COLOR: Color = Color(0.5, 0.46, 0.4)
const BARK_COLOR: Color = Color(0.11, 0.08, 0.06)
const LOG_END_COLOR: Color = Color(0.46, 0.35, 0.24)
const WICKER_COLOR: Color = Color(0.22, 0.16, 0.1)
const WAX_COLOR: Color = Color(0.86, 0.8, 0.68)

## O fogo: duas folhas cruzadas com este shader (feito aqui, uma vez só).
const FLAME_CODE: String = """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	// y = 0 embaixo (na lenha), 1 em cima; o ruído sobe com o tempo.
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME + seed;
	float n = noise(vec2(uv.x * 4.0 + seed, uv.y * 3.0 - t * 2.4)) * 0.6
			+ noise(vec2(uv.x * 9.0 - seed, uv.y * 7.0 - t * 4.0)) * 0.4;
	float x = abs((uv.x - 0.5) * 2.0 + (n - 0.5) * 0.5 * uv.y);
	float width = 1.0 - uv.y * 0.85;
	float flame = (1.0 - smoothstep(width * 0.45, width, x)) * (1.0 - smoothstep(0.25, 1.0, uv.y + (n - 0.5) * 0.6));
	flame *= smoothstep(0.0, 0.1, uv.y);
	vec3 color = mix(vec3(1.0, 0.22, 0.03), vec3(1.0, 0.78, 0.35), smoothstep(0.25, 0.85, flame));
	ALBEDO = color * 4.0;
	ALPHA = clamp(flame, 0.0, 1.0);
}
"""

static var _flame_shader: Shader


func build() -> void:
	var wall_z := -Home.ROOM_SIZE.z / 2.0
	_add_fireplace(Vector3(FIREPLACE_X, 0.0, wall_z))
	_add_rug(Vector3(FIREPLACE_X, 0.0, wall_z + ARMCHAIR_FROM_WALL + 0.05), RUG_SIZE)
	# As poltronas olham para a frente da lareira, viradas uma para a outra
	# (assim o fogo fica à vista entre elas).
	var fire := Vector3(FIREPLACE_X, 0.0, wall_z + 0.5)
	_add_armchair(Vector3(FIREPLACE_X - ARMCHAIR_SPREAD, 0.0, wall_z + ARMCHAIR_FROM_WALL), fire, true)
	_add_armchair(Vector3(FIREPLACE_X + ARMCHAIR_SPREAD, 0.0, wall_z + ARMCHAIR_FROM_WALL), fire, false)
	_add_stump_table(Vector3(STUMP_SPOT.x, 0.0, STUMP_SPOT.y))
	_add_log_basket(Vector3(BASKET_SPOT.x, 0.0, BASKET_SPOT.y))
	for spot in [Vector2(-Home.ROOM_SIZE.x / 3.0, 0.0), Vector2(Home.ROOM_SIZE.x / 3.0, 0.0),
			Vector2(Home.WINDOW_CENTER_X, Home.BEAM_Z[0])]:
		_add_hanging_lantern(Vector3(spot.x, 0.0, spot.y))
	_add_plant(Vector3(PLANT_SPOT.x, 0.0, PLANT_SPOT.y))


## Um nó-pai para as peças de um móvel, com a marca do teste.
func _piece(piece_name: String, kind: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = piece_name
	pivot.position = at
	pivot.rotation.y = yaw
	pivot.set_meta("cabin_piece", kind)
	return add_node(pivot)


## Caixa dentro de um nó-pai (coordenadas dele).
func _box(parent: Node3D, box_name: String, box_size: Vector3, center: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	return HomeDecor.make_box(parent, box_name, box_size, center, material, solid, profile.footstep)


## Uma malha pronta dentro de um nó-pai.
func _mesh(parent: Node3D, mesh_name: String, mesh: Mesh, material: Material, at: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = mesh_name
	node.mesh = mesh
	node.material_override = material
	node.transform = at
	parent.add_child(node)
	return node


## Colisão de caixa (sem desenho) dentro de um nó-pai: o modelo desenha, e a
## caixa segura o jogador.
func _solid(parent: Node3D, solid_name: String, box_size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = solid_name
	body.set_meta("footstep", profile.footstep)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	parent.add_child(body)


func _at(x: float, y: float, z: float, rotation: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rotation), Vector3(x, y, z))


## Lareira de pedra (o modelo do Blender: pilares, verga, fundo de fuligem,
## soleira, consolo de madeira e a grade de ferro), a lenha em brasa com o
## fogo, um lampião e duas velas no consolo, e a chaminé até o teto. Uma luz
## laranja tremula junto com o fogo, e a lenha estala baixinho. "at" é o meio
## da lareira, na parede norte; o nó gira para o x dele apontar para a sala (+z).
func _add_fireplace(at: Vector3) -> void:
	var fireplace := _piece("Fireplace", "lareira", at, -PI / 2.0)
	# Coordenadas do nó: x = 0 na parede, para dentro da sala; z ao longo dela.
	HomeModels.place(fireplace, FIREPLACE_MODEL, "stone", HomeModels.stone(STONE_TINT, STONE_METERS))
	HomeModels.place(fireplace, FIREPLACE_MODEL, "wood", HomeModels.wood(MANTEL_TINT, 0.55))
	HomeModels.place(fireplace, FIREPLACE_MODEL, "soot", HomeModels.matte(SOOT_TINT))
	HomeModels.place(fireplace, FIREPLACE_MODEL, "iron", HomeModels.metal(IRON_TINT))
	# As colisões, com as medidas da lareira (o modelo não tem nenhuma): os
	# pilares, o degrau da boca, a verga e o consolo. Ninguém entra no fogo.
	var d := FIREPLACE_DEPTH
	var pillar := (FIREPLACE_WIDTH - OPENING_WIDTH) / 2.0
	for side in [-1.0, 1.0]:
		_solid(fireplace, "FireplacePillar", Vector3(d, MANTEL_Y, pillar),
				Vector3(d / 2.0, MANTEL_Y / 2.0, side * (OPENING_WIDTH + pillar) / 2.0))
	_solid(fireplace, "FireplaceBase", Vector3(d, FIRE_FLOOR, OPENING_WIDTH), Vector3(d / 2.0, FIRE_FLOOR / 2.0, 0.0))
	_solid(fireplace, "FireplaceLintel", Vector3(d, MANTEL_Y - OPENING_TOP, OPENING_WIDTH),
			Vector3(d / 2.0, (OPENING_TOP + MANTEL_Y) / 2.0, 0.0))
	_solid(fireplace, "FireplaceMantel", Vector3(MANTEL_DEPTH, 0.12, FIREPLACE_WIDTH + 0.2),
			Vector3(MANTEL_DEPTH / 2.0, MANTEL_Y - 0.06, 0.0))
	# A chaminé acompanha a altura da sala: fica em código (o modelo para no
	# consolo).
	var flue := Home.ROOM_SIZE.y - MANTEL_Y
	var chimney := HomeMaterials.pbr(CHIMNEY_TEXTURE, CHIMNEY_METERS, CHIMNEY_TINT)
	_box(fireplace, "Chimney", Vector3(CHIMNEY_DEPTH, flue, CHIMNEY_WIDTH),
			Vector3(CHIMNEY_DEPTH / 2.0, MANTEL_Y + flue / 2.0, 0.0), chimney, true)
	_add_fire(fireplace, Vector3(0.32, FIRE_FLOOR + 0.02, 0.0))
	# Um lampião pequeno em cima do consolo (só brilho, sem luz própria) e duas
	# velas do outro lado.
	_add_lantern_body(fireplace, Vector3(0.3, MANTEL_Y, -0.65), 0.7, false)
	var wax := HomeShapes.Batch.new()
	var flames := HomeShapes.Batch.new()
	for candle: Array in [[0.28, 0.6, 0.16], [0.36, 0.72, 0.11]]:
		var stick := CylinderMesh.new()
		stick.top_radius = 0.028
		stick.bottom_radius = 0.03
		stick.height = candle[2]
		stick.radial_segments = 12
		wax.add_mesh(stick, _at(candle[0], MANTEL_Y + candle[2] / 2.0, candle[1]), WAX_COLOR)
		flames.add_mesh(_candle_flame(), _at(candle[0], MANTEL_Y + candle[2] + 0.02, candle[1]), Color.WHITE)
	_mesh(fireplace, "MantelCandles", wax.commit(), HomeMaterials.vertex_colored(0.6))
	var lit := _mesh(fireplace, "MantelCandleFlames", flames.commit(), HomeMaterials.glow(CANDLE_COLOR, 4.0))
	lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A chama de uma vela: uma gota pequena (a malha é feita uma vez).
static var _flame_mesh: SphereMesh


static func _candle_flame() -> SphereMesh:
	if _flame_mesh == null:
		_flame_mesh = SphereMesh.new()
		_flame_mesh.radius = 0.009
		_flame_mesh.height = 0.04
		_flame_mesh.radial_segments = 8
		_flame_mesh.rings = 4
	return _flame_mesh


## A lenha em brasa, as duas folhas de fogo e a luz que tremula (com sombra).
func _add_fire(parent: Node3D, at: Vector3) -> void:
	var log_wood := HomeMaterials.wood(Color(0.16, 0.1, 0.06), false, 0.9)
	for i in 3:
		var fire_log := MeshInstance3D.new()
		fire_log.name = "FireLog"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.06
		mesh.bottom_radius = 0.06
		mesh.height = 0.62
		fire_log.mesh = mesh
		fire_log.material_override = log_wood
		fire_log.position = at + Vector3(-0.06 + i * 0.07, 0.06 + (0.07 if i == 1 else 0.0), 0.0)
		fire_log.rotation = Vector3(PI / 2.0, 0.0, (i - 1) * 0.35)
		parent.add_child(fire_log)
	_box(parent, "Embers", Vector3(0.34, 0.03, 0.56), at + Vector3(0.0, 0.015, 0.0), HomeMaterials.glow(Color(1.0, 0.35, 0.08), 3.0))

	if _flame_shader == null:
		_flame_shader = Shader.new()
		_flame_shader.code = FLAME_CODE
	for i in 2:
		var flame := MeshInstance3D.new()
		flame.name = "Flame"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.7, 0.7)
		flame.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = _flame_shader
		material.set_shader_parameter("seed", float(i) * 7.3)
		flame.material_override = material
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = at + Vector3(0.0, 0.36, 0.0)
		# A folha olha para dentro da sala (+X), e a segunda fica cruzada.
		flame.rotation.y = PI / 2.0 + (0.0 if i == 0 else 0.6)
		parent.add_child(flame)

	var light := FireLight.new()
	light.name = "FireLight"
	light.light_color = FIRE_COLOR
	light.base_energy = FIRE_ENERGY
	light.omni_range = FIRE_RANGE
	light.omni_attenuation = FIRE_ATTENUATION
	# A sombra das poltronas e da grade no tapete e no chão.
	light.shadow_enabled = true
	light.shadow_blur = 1.2
	light.position = at + Vector3(0.45, 0.55, 0.0)
	parent.add_child(light)

	var crackle := AudioStreamPlayer3D.new()
	crackle.name = "FireCrackle"
	crackle.stream = AmbientEmitter.looping(CRACKLE_SOUND)
	crackle.bus = &"Ambiente"
	crackle.volume_db = -12.0
	crackle.max_distance = 9.0
	crackle.unit_size = 2.0
	crackle.autoplay = true
	crackle.position = at + Vector3(0.2, 0.3, 0.0)
	parent.add_child(crackle)


func _add_rug(center: Vector3, rug_size: Vector2) -> void:
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var plane := PlaneMesh.new()
	plane.size = rug_size
	rug.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = RUG_SHADER
	material.set_shader_parameter("field_color", RUG_FIELD)
	material.set_shader_parameter("pattern_color", RUG_PATTERN)
	material.set_shader_parameter("dark_color", RUG_DARK)
	material.set_shader_parameter("accent_color", RUG_ACCENT)
	material.set_shader_parameter("rug_size", rug_size)
	rug.material_override = material
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rug.position = center + Vector3(0.0, 0.006, 0.0)
	rug.set_meta("cabin_piece", "tapete")
	add_node(rug)


## Poltrona virada para "look_at" (o modelo do Blender: estrutura de madeira
## aparente e estofado de lã), com colisão. "throw" = com a manta de tricô
## caída do encosto até a frente do assento.
func _add_armchair(at: Vector3, look_at: Vector3, throw: bool) -> void:
	# A frente da poltrona é o -Z do nó (como o sofá do loft e o modelo).
	var to_fire := look_at - at
	var chair := _piece("Armchair", "poltrona", at, atan2(-to_fire.x, -to_fire.z))
	HomeModels.place(chair, ARMCHAIR_MODEL, "wood", HomeModels.wood(CHAIR_WOOD_TINT, 0.5))
	HomeModels.place(chair, ARMCHAIR_MODEL, "fabric", HomeModels.fabric(CHAIR_FABRIC_TINT, 0.45))
	# Colisões: a base (até o assento) e o encosto.
	_solid(chair, "ArmchairBase", Vector3(0.7, 0.49, 0.7), Vector3(0.0, 0.245, 0.0))
	_solid(chair, "ArmchairBack", Vector3(0.7, 0.99, 0.2), Vector3(0.0, 0.495, 0.25))
	if throw:
		_add_throw(chair)


## A manta de tricô: sai de trás do encosto, passa por cima dele, desce pela
## frente do encosto, atravessa o assento e cai pela frente, com as dobras
## crescendo. Um pouco fora do meio, como jogada de verdade.
func _add_throw(chair: Node3D) -> void:
	var x := 0.03
	# O meio da manta, de trás para a frente, em (z, y) da poltrona (a frente é -z).
	var line: Array[Vector2] = [
		Vector2(0.36, 0.86), Vector2(0.3, 1.0), Vector2(0.2, 1.01), Vector2(0.155, 0.88),
		Vector2(0.135, 0.68), Vector2(0.09, 0.53), Vector2(-0.05, 0.515), Vector2(-0.2, 0.51),
		Vector2(-0.31, 0.49), Vector2(-0.355, 0.4), Vector2(-0.37, 0.28),
	]
	var path := PackedVector3Array()
	for i in line.size():
		path.append(Vector3(x - float(i) / line.size() * 0.05, line[i].y, line[i].x))
	var mesh := HomeShapes.drape(path, Vector3.RIGHT, Vector3(0.0, 0.4, 0.05), 0.4, 2.5, Vector2(0.006, 0.022), THROW_COLOR)
	_mesh(chair, "ArmchairThrow", mesh, HomeMaterials.fabric_tinted(true))


## O toco de árvore que serve de mesinha, ao lado da poltrona da direita: a
## casca e o tampo claro com os anéis; em cima, uma caneca, dois livros e uma
## vela acesa num pires (uma luz pequena e curta, sem sombra). Tem colisão.
func _add_stump_table(at: Vector3) -> void:
	var stump := _piece("StumpTable", "mesinha", at, 0.4)
	var bark := HomeShapes.Batch.new()
	var body := CylinderMesh.new()
	body.top_radius = STUMP_RADIUS
	body.bottom_radius = STUMP_RADIUS * 1.12
	body.height = STUMP_HEIGHT
	body.radial_segments = 14
	body.cap_top = false
	bark.add_mesh(body, _at(0.0, STUMP_HEIGHT / 2.0, 0.0), BARK_COLOR)
	# As raízes: três calombos na base.
	for i in 3:
		var angle := TAU * i / 3.0 + 0.5
		var root := SphereMesh.new()
		root.radius = 0.07
		root.height = 0.1
		root.radial_segments = 8
		root.rings = 4
		bark.add_mesh(root, _at(cos(angle) * STUMP_RADIUS * 1.05, 0.03, sin(angle) * STUMP_RADIUS * 1.05), BARK_COLOR.darkened(0.15))
	# O tampo: os anéis do tronco (discos claros e escuros, um sobre o outro).
	for ring in 4:
		var disc := CylinderMesh.new()
		var radius := STUMP_RADIUS * (1.0 - ring * 0.22) - 0.008
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.004
		disc.radial_segments = 20
		var tone := LOG_END_COLOR.darkened(0.12) if ring % 2 == 1 else LOG_END_COLOR
		bark.add_mesh(disc, _at(0.0, STUMP_HEIGHT + 0.002 + ring * 0.0006, 0.0), tone)
	_mesh(stump, "StumpBody", bark.commit(), HomeMaterials.vertex_colored(0.9))
	_solid(stump, "StumpCollision", Vector3(STUMP_RADIUS * 2.0, STUMP_HEIGHT, STUMP_RADIUS * 2.0), Vector3(0.0, STUMP_HEIGHT / 2.0, 0.0))
	var top := STUMP_HEIGHT + 0.005
	var items := HomeShapes.Batch.new()
	HomeShapes.book(items, Vector3(0.035, 0.22, 0.15), _at(-0.04, top + 0.0175, 0.05, Vector3(0.0, 0.3, PI / 2.0)), BOOK_COLORS[0])
	HomeShapes.book(items, Vector3(0.025, 0.18, 0.13), _at(-0.05, top + 0.035 + 0.0125, 0.04, Vector3(0.0, -0.1, PI / 2.0)), BOOK_COLORS[1])
	var saucer := CylinderMesh.new()
	saucer.top_radius = 0.05
	saucer.bottom_radius = 0.04
	saucer.height = 0.01
	saucer.radial_segments = 16
	items.add_mesh(saucer, _at(0.1, top + 0.005, -0.08), MUG_COLOR.darkened(0.3))
	var candle := CylinderMesh.new()
	candle.top_radius = 0.026
	candle.bottom_radius = 0.027
	candle.height = 0.075
	candle.radial_segments = 12
	items.add_mesh(candle, _at(0.1, top + 0.01 + 0.0375, -0.08), WAX_COLOR)
	var mug := CylinderMesh.new()
	mug.top_radius = 0.04
	mug.bottom_radius = 0.037
	mug.height = 0.09
	mug.radial_segments = 18
	mug.cap_top = false
	items.add_mesh(mug, _at(0.09, top + 0.045, 0.09), MUG_COLOR)
	var tea := CylinderMesh.new()
	tea.top_radius = 0.037
	tea.bottom_radius = 0.037
	tea.height = 0.002
	tea.radial_segments = 18
	items.add_mesh(tea, _at(0.09, top + 0.075, 0.09), Color(0.12, 0.06, 0.03))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.018
	handle.outer_radius = 0.028
	handle.rings = 12
	handle.ring_segments = 6
	items.add_mesh(handle, _at(0.13, top + 0.048, 0.09, Vector3(PI / 2.0, 0.0, 0.0)), MUG_COLOR)
	_mesh(stump, "StumpItems", items.commit(), HomeMaterials.vertex_colored(0.55))
	var flame := _mesh(stump, "StumpCandleFlame", _candle_flame(), HomeMaterials.glow(CANDLE_COLOR, 4.0),
			_at(0.1, top + 0.01 + 0.075 + 0.02, -0.08))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "CandleLight"
	light.light_color = CANDLE_COLOR
	light.light_energy = CANDLE_ENERGY
	light.omni_range = CANDLE_RANGE
	light.omni_attenuation = 1.4
	light.position = Vector3(0.1, top + 0.16, -0.08)
	stump.add_child(light)


## O cesto de vime com a lenha para o fogo, entre a lareira e o toco: as
## achas em pé, um pouco tortas, com as pontas claras do corte. Tem colisão.
func _add_log_basket(at: Vector3) -> void:
	var basket := _piece("LogBasket", "lenha", at, -0.3)
	var wicker := HomeShapes.Batch.new()
	var body := CylinderMesh.new()
	body.top_radius = BASKET_RADIUS
	body.bottom_radius = BASKET_RADIUS * 0.85
	body.height = 0.34
	body.radial_segments = 18
	body.cap_top = false
	wicker.add_mesh(body, _at(0.0, 0.17, 0.0), WICKER_COLOR)
	# A trama: aros um pouco mais escuros e a borda grossa.
	for i in 4:
		var hoop := TorusMesh.new()
		var radius := lerpf(BASKET_RADIUS * 0.86, BASKET_RADIUS, (i + 0.5) / 4.0)
		hoop.inner_radius = radius - 0.006
		hoop.outer_radius = radius + 0.006
		hoop.rings = 20
		hoop.ring_segments = 4
		wicker.add_mesh(hoop, _at(0.0, 0.04 + i * 0.085, 0.0), WICKER_COLOR.darkened(0.25))
	var rim := TorusMesh.new()
	rim.inner_radius = BASKET_RADIUS - 0.018
	rim.outer_radius = BASKET_RADIUS + 0.016
	rim.rings = 24
	rim.ring_segments = 6
	wicker.add_mesh(rim, _at(0.0, 0.34, 0.0), WICKER_COLOR.darkened(0.1))
	_mesh(basket, "BasketBody", wicker.commit(), HomeMaterials.vertex_colored(0.9))
	var logs := HomeShapes.Batch.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in 7:
		var angle := TAU * i / 7.0
		var spread := 0.0 if i == 0 else BASKET_RADIUS * 0.55
		var spot := Vector2(cos(angle), sin(angle)) * spread
		var length := rng.randf_range(0.5, 0.62)
		var radius := rng.randf_range(0.035, 0.05)
		# Cada acha encosta para fora do meio do cesto, um pouco torta.
		var lean := Vector3(spot.y * 0.9, rng.randf_range(0.0, TAU), -spot.x * 0.9)
		var place := Transform3D(Basis.from_euler(lean), Vector3(spot.x, 0.02 + length / 2.0, spot.y))
		var piece := CylinderMesh.new()
		piece.top_radius = radius
		piece.bottom_radius = radius * 1.05
		piece.height = length
		piece.radial_segments = 7
		piece.cap_top = false
		logs.add_mesh(piece, place, BARK_COLOR.lightened(rng.randf_range(0.0, 0.08)))
		var cut := CylinderMesh.new()
		cut.top_radius = radius * 0.96
		cut.bottom_radius = radius * 0.96
		cut.height = 0.004
		cut.radial_segments = 7
		logs.add_mesh(cut, place * _at(0.0, length / 2.0, 0.0), LOG_END_COLOR)
	_mesh(basket, "BasketLogs", logs.commit(), HomeMaterials.vertex_colored(0.95))
	_solid(basket, "BasketCollision", Vector3(BASKET_RADIUS * 2.0, 0.5, BASKET_RADIUS * 2.0), Vector3(0.0, 0.25, 0.0))


## Lampião pendurado numa viga: corrente, corpo de ferro com vidro aceso e a luz.
func _add_hanging_lantern(at: Vector3) -> void:
	var beam_bottom := Home.ROOM_SIZE.y - Home.BEAM_SIZE.y
	var lantern := _piece("Lantern", "lampiao", Vector3(at.x, beam_bottom - 0.75, at.z))
	var chain := MeshInstance3D.new()
	chain.name = "LanternChain"
	var chain_mesh := CylinderMesh.new()
	chain_mesh.top_radius = 0.008
	chain_mesh.bottom_radius = 0.008
	chain_mesh.height = 0.45
	chain.mesh = chain_mesh
	chain.material_override = HomeMaterials.metal(IRON_COLOR, 0.6)
	chain.position = Vector3(0.0, 0.75 - 0.225, 0.0)
	lantern.add_child(chain)
	_add_lantern_body(lantern, Vector3.ZERO, 1.0, true)


## O corpo do lampião (base, vidro aceso, quatro hastes e o chapéu), com a
## base em "at". "with_light" = acende uma luz de verdade (os do teto).
func _add_lantern_body(parent: Node3D, at: Vector3, scale: float, with_light: bool) -> void:
	var iron := HomeMaterials.metal(IRON_COLOR, 0.55)
	var s := scale
	_box(parent, "LanternBase", Vector3(0.2, 0.03, 0.2) * s, at + Vector3(0.0, 0.015, 0.0) * s, iron)
	_box(parent, "LanternGlass", Vector3(0.14, 0.2, 0.14) * s, at + Vector3(0.0, 0.13, 0.0) * s,
			HomeMaterials.glow(profile.lamp_color, 3.0))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(parent, "LanternPost", Vector3(0.018, 0.22, 0.018) * s, at + Vector3(x * 0.08, 0.13, z * 0.08) * s, iron)
	var cap := MeshInstance3D.new()
	cap.name = "LanternCap"
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.02 * s
	cap_mesh.bottom_radius = 0.13 * s
	cap_mesh.height = 0.08 * s
	cap.mesh = cap_mesh
	cap.material_override = iron
	cap.position = at + Vector3(0.0, 0.28, 0.0) * s
	parent.add_child(cap)
	if not with_light:
		return
	var light := OmniLight3D.new()
	light.name = "Lamp"
	light.light_color = profile.lamp_color
	light.light_energy = profile.lamp_energy
	light.omni_range = LANTERN_RANGE
	light.omni_attenuation = LANTERN_ATTENUATION
	light.position = at + Vector3(0.0, 0.1, 0.0)
	parent.add_child(light)


## Vaso de barro com o arbusto do Kenney Nature Kit, com uns 1,1 m de altura.
func _add_plant(at: Vector3) -> void:
	var plant := _piece("Plant", "vaso", at)
	var pot := MeshInstance3D.new()
	pot.name = "PlantPot"
	var pot_mesh := CylinderMesh.new()
	pot_mesh.top_radius = 0.24
	pot_mesh.bottom_radius = 0.17
	pot_mesh.height = 0.42
	pot.mesh = pot_mesh
	pot.material_override = HomeMaterials.matte(POT_COLOR, 0.9)
	pot.position = Vector3(0.0, 0.21, 0.0)
	plant.add_child(pot)
	var body := _box(plant, "PlantCollision", Vector3(0.44, 0.42, 0.44), Vector3(0.0, 0.21, 0.0), pot.material_override, true)
	body.visible = false  # só a colisão do vaso
	var bush := BUSH_SCENE.instantiate() as Node3D
	bush.name = "PlantBush"
	plant.add_child(bush)
	# O modelo vem noutro tamanho: mede e ajusta a largura para PLANT_WIDTH.
	var bounds := AABB()
	var first := true
	for node in bush.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = _relative_transform(mesh, bush) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var widest := maxf(bounds.size.x, bounds.size.z)
	if widest > 0.001:
		bush.scale = Vector3.ONE * (PLANT_WIDTH / widest)
	bush.position = Vector3(0.0, 0.38 - bounds.position.y * bush.scale.y, 0.0)


## A posição de "node" vista de "ancestor" (funciona antes de entrar na árvore).
func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


## A luz do fogo: tremula sozinha (brilho e um tiquinho de posição), num
## ritmo que não se repete.
class FireLight:
	extends OmniLight3D

	var base_energy: float = 2.0
	var _time: float = 0.0
	var _origin: Vector3

	func _ready() -> void:
		_origin = position
		light_energy = base_energy

	func _process(delta: float) -> void:
		_time += delta
		var flicker := 0.55 * sin(_time * 7.3) + 0.3 * sin(_time * 13.1 + 1.7) + 0.15 * sin(_time * 23.7 + 0.4)
		light_energy = base_energy * (0.85 + 0.15 * flicker)
		position = _origin + Vector3(0.0, 0.02 * sin(_time * 5.1), 0.03 * sin(_time * 3.7 + 1.0))
