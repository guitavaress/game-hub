extends HomeDecor
## O enfeite da CABANA (Fase 13.12): a lareira de pedra no canto sudoeste, com
## fogo que tremula, duas poltronas de tecido viradas para ela sobre um tapete,
## lampiões de ferro pendurados nas vigas e um vaso com um arbusto no canto
## noroeste. Nada é baixado: a pedra é a PavingStones070 (ambientCG) que o
## projeto já tem, o arbusto é do Kenney Nature Kit e o fogo é um shader.
##
## As peças não tampam nenhum lugar pronto dos móveis (Home.ANCHORS), nem a
## porta, nem a janela: a lareira fica na parede oeste, entre o lugar "oeste"
## (até z = 2) e o "sul_esquerda" (a partir de z = 4,2). Cada peça grande é um
## nó com a marca "cabin_piece" (o teste acha por ela, e não pelo nome).

const RUG_SHADER: Shader = preload("res://worlds/home/home_rug.gdshader")
const BUSH_SCENE: PackedScene = preload("res://assets/kenney/nature-kit/plant_bush.glb")
const CRACKLE_SOUND: AudioStream = preload("res://assets/generated/fire_crackle.wav")

## A lareira: encostada na parede oeste, com o meio em z = FIREPLACE_Z.
const FIREPLACE_Z: float = 3.1
const FIREPLACE_WIDTH: float = 1.8
const FIREPLACE_DEPTH: float = 0.7
## Altura do degrau de pedra onde fica o fogo.
const FIRE_FLOOR: float = 0.3
const STONE_COLOR: Color = Color(0.78, 0.74, 0.7)
const SOOT_COLOR: Color = Color(0.05, 0.04, 0.035)
const IRON_COLOR: Color = Color(0.08, 0.075, 0.07)
const FIRE_COLOR: Color = Color(1.0, 0.55, 0.25)
const MANTEL_WOOD: Color = Color(0.26, 0.16, 0.09)
const ARMCHAIR_COLOR: Color = Color(0.5, 0.2, 0.12)
const THROW_COLOR: Color = Color(0.72, 0.6, 0.4)
const POT_COLOR: Color = Color(0.55, 0.3, 0.18)

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
	_add_fireplace()
	_add_rug(Vector3(-4.55, 0.0, FIREPLACE_Z), Vector2(1.7, 2.5))
	# As poltronas olham para a frente da lareira, viradas uma para a outra
	# (assim o fogo fica à vista entre elas).
	var fire := Vector3(-5.0, 0.0, FIREPLACE_Z)
	_add_armchair(Vector3(-4.5, 0.0, 2.55), fire, true)
	_add_armchair(Vector3(-4.5, 0.0, 3.65), fire, false)
	for spot in [Vector2(-3.0, 0.0), Vector2(3.0, 0.0), Vector2(0.0, -Home.ROOM_SIZE.z / 3.0)]:
		_add_hanging_lantern(Vector3(spot.x, 0.0, spot.y))
	_add_plant(Vector3(-5.5, 0.0, -3.65))


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


## Lareira de pedra: dois pilares, a verga, o fundo de fuligem, a lenha em
## brasa com o fogo, a grade de ferro (sólida: ninguém entra no fogo), o
## consolo de madeira com um lampião e a chaminé até o teto. Uma luz laranja
## tremula junto com o fogo, e a lenha estala baixinho.
func _add_fireplace() -> void:
	var fireplace := _piece("Fireplace", "lareira", Vector3(-Home.ROOM_SIZE.x / 2.0, 0.0, FIREPLACE_Z))
	var stone := HomeMaterials.pbr("PavingStones070", 0.8, STONE_COLOR)
	var soot := HomeMaterials.matte(SOOT_COLOR, 1.0)
	var w := FIREPLACE_WIDTH
	var d := FIREPLACE_DEPTH
	var opening := 1.0
	var pillar := (w - opening) / 2.0
	# A boca fica num degrau de pedra (FIRE_FLOOR): o fogo aparece por cima
	# do encosto das poltronas para quem está em pé.
	var top := FIRE_FLOOR + 0.87
	# Coordenadas do nó: x = 0 na parede, para dentro da sala; z ao longo dela.
	for side in [-1.0, 1.0]:
		_box(fireplace, "FireplacePillar", Vector3(d, top + 0.28, pillar), Vector3(d / 2.0, (top + 0.28) / 2.0, side * (opening + pillar) / 2.0), stone, true)
	_box(fireplace, "FireplaceBase", Vector3(d, FIRE_FLOOR, opening), Vector3(d / 2.0, FIRE_FLOOR / 2.0, 0.0), stone, true)
	_box(fireplace, "FireplaceLintel", Vector3(d, 0.28, opening), Vector3(d / 2.0, top + 0.14, 0.0), stone, true)
	_box(fireplace, "FireplaceBack", Vector3(0.1, 0.87, opening), Vector3(0.05, FIRE_FLOOR + 0.435, 0.0), soot)
	_box(fireplace, "FireplaceFloor", Vector3(d - 0.1, 0.02, opening), Vector3(d / 2.0 + 0.05, FIRE_FLOOR + 0.01, 0.0), soot)
	# A pedra do chão na frente (baixinha, dá para pisar).
	_box(fireplace, "Hearth", Vector3(0.36, 0.06, w - 0.2), Vector3(d + 0.18, 0.03, 0.0), stone)
	# Consolo e chaminé.
	var mantel_y := top + 0.34
	_box(fireplace, "Mantel", Vector3(d + 0.12, 0.12, w + 0.2), Vector3((d + 0.12) / 2.0, mantel_y, 0.0),
			HomeMaterials.wood(MANTEL_WOOD, false, 0.6), true)
	var flue_depth := d - 0.2
	var flue_bottom := mantel_y + 0.06
	_box(fireplace, "Chimney", Vector3(flue_depth, Home.ROOM_SIZE.y - flue_bottom, w - 0.4),
			Vector3(flue_depth / 2.0, flue_bottom + (Home.ROOM_SIZE.y - flue_bottom) / 2.0, 0.0), stone, true)
	_add_fire(fireplace, Vector3(0.32, FIRE_FLOOR + 0.02, 0.0))
	# Grade de ferro na frente da boca (só enfeite: o degrau já segura o jogador).
	var iron := HomeMaterials.metal(IRON_COLOR, 0.6)
	var screen_x := d + 0.03
	_box(fireplace, "FireScreenTop", Vector3(0.025, 0.025, opening - 0.1), Vector3(screen_x, FIRE_FLOOR + 0.36, 0.0), iron)
	for i in 9:
		_box(fireplace, "FireScreenBar", Vector3(0.012, 0.36, 0.012),
				Vector3(screen_x, FIRE_FLOOR + 0.18, -(opening - 0.1) / 2.0 + i * (opening - 0.1) / 8.0), iron)
	# Um lampião pequeno em cima do consolo (só brilho, sem luz própria).
	_add_lantern_body(fireplace, Vector3(0.3, mantel_y + 0.06, -w / 2.0 + 0.25), 0.7, false)


## A lenha em brasa, as duas folhas de fogo e a luz que tremula.
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
	light.base_energy = 2.2
	light.omni_range = 6.5
	light.omni_attenuation = 1.3
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
	# Verde-musgo com borda creme e losangos cor de ferrugem.
	material.set_shader_parameter("field_color", Color(0.12, 0.2, 0.13))
	material.set_shader_parameter("border_color", Color(0.78, 0.68, 0.5))
	material.set_shader_parameter("accent_color", Color(0.45, 0.17, 0.09))
	material.set_shader_parameter("diamonds", Vector2(4.0, 6.0))
	rug.material_override = material
	rug.position = center + Vector3(0.0, 0.006, 0.0)
	rug.set_meta("cabin_piece", "tapete")
	add_node(rug)


## Poltrona de tecido virada para "look_at": base, assento, encosto, braços e
## pés de madeira. "throw" = com uma manta dobrada no braço.
func _add_armchair(at: Vector3, look_at: Vector3, throw: bool) -> void:
	# A frente da poltrona é o -Z do nó (como o sofá do loft).
	var to_fire := look_at - at
	var chair := _piece("Armchair", "poltrona", at, atan2(-to_fire.x, -to_fire.z))
	var cloth := HomeMaterials.fabric(ARMCHAIR_COLOR)
	var size := 0.7
	_box(chair, "ArmchairBase", Vector3(size, 0.3, size), Vector3(0.0, 0.22, 0.0), cloth, true)
	_box(chair, "ArmchairSeat", Vector3(size - 0.3, 0.12, size - 0.18), Vector3(0.0, 0.43, -0.06), cloth)
	_box(chair, "ArmchairBack", Vector3(size, 0.62, 0.18), Vector3(0.0, 0.68, size / 2.0 - 0.09), cloth, true)
	for side in [-1.0, 1.0]:
		_box(chair, "ArmchairArm", Vector3(0.15, 0.24, size), Vector3(side * (size / 2.0 - 0.075), 0.49, 0.0), cloth)
		for front in [-1.0, 1.0]:
			_box(chair, "ArmchairFoot", Vector3(0.05, 0.07, 0.05),
					Vector3(side * (size / 2.0 - 0.06), 0.035, front * (size / 2.0 - 0.06)), HomeMaterials.wood(MANTEL_WOOD, false, 0.5))
	if throw:
		var blanket := _box(chair, "ArmchairThrow", Vector3(0.17, 0.05, 0.5), Vector3(-(size / 2.0 - 0.075), 0.63, 0.04),
				HomeMaterials.fabric(THROW_COLOR))
		blanket.rotation.z = deg_to_rad(6.0)


## Lampião pendurado numa viga: corrente, corpo de ferro com vidro aceso e a luz.
func _add_hanging_lantern(at: Vector3) -> void:
	var beam_bottom := Home.ROOM_SIZE.y - 0.22
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
	light.omni_range = 6.5
	light.omni_attenuation = 1.1
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
	# O modelo vem noutro tamanho: mede e ajusta a largura para ~0,8 m.
	var bounds := AABB()
	var first := true
	for node in bush.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = _relative_transform(mesh, bush) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var widest := maxf(bounds.size.x, bounds.size.z)
	if widest > 0.001:
		bush.scale = Vector3.ONE * (0.8 / widest)
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
