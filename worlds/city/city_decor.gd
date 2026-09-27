class_name CityDecor
extends RefCounted
## Decoração da cidade: calçadas, faixas das ruas, postes, praças de bolso,
## árvores e o chafariz. Só visual (e um pouco de colisão); nada de lógica.
##
## Materiais realistas: ambientCG (CC0), em assets/ambientcg/. Árvores: Kenney
## Nature Kit (CC0), recoloridas num verde escuro, em floreiras de concreto.
## Uso:  CityDecor.add_park(self, lote)  — cada função acrescenta nós ao "parent".

const AMBIENTCG: String = "res://assets/ambientcg/"

const TREES: Array[PackedScene] = [
	preload("res://assets/kenney/nature-kit/tree_detailed.glb"),
	preload("res://assets/kenney/nature-kit/tree_cone.glb"),
	preload("res://assets/kenney/nature-kit/tree_default.glb"),
]
const BUSH: PackedScene = preload("res://assets/kenney/nature-kit/plant_bushLarge.glb")

## Os modelos da Nature Kit são pequenos (árvore ~1,7): esta escala deixa a
## árvore com ~6 m e o arbusto com ~0,8 m.
const TREE_SCALE: float = 3.4
const BUSH_SCALE: float = 2.6

## A Nature Kit vem com folhas verde-menta e materiais "metálicos". Trocamos por
## verdes escuros e naturais e tiramos o metálico. Nome do material -> cor nova.
const PLANT_COLORS: Dictionary[String, Color] = {
	"leafsGreen": Color(0.16, 0.3, 0.17),
	"grass": Color(0.18, 0.33, 0.18),
	"woodBark": Color(0.23, 0.17, 0.13),
}

const SIDEWALK_WIDTH: float = 1.5
const GRASS_COLOR: Color = Color(0.12, 0.2, 0.12)
const LANE_MARK_COLOR: Color = Color(0.85, 0.83, 0.76)
const LANE_DASH_LENGTH: float = 2.5
const LANE_DASH_GAP: float = 3.5

## Materiais e texturas já carregados (para não repetir o trabalho).
static var _fixed_materials: Dictionary = {}
static var _pbr_materials: Dictionary = {}
static var _pbr_textures: Dictionary = {}


# --- Materiais realistas (PBR) -----------------------------------------------

## As três texturas de um material da ambientCG: cor, relevo e rugosidade.
static func pbr_textures(folder: String) -> Dictionary:
	if not _pbr_textures.has(folder):
		var base := "%s%s/%s_1K-JPG_" % [AMBIENTCG, folder, folder]
		_pbr_textures[folder] = {
			"albedo": load(base + "Color.jpg"),
			"normal": load(base + "NormalGL.jpg"),
			"roughness": load(base + "Roughness.jpg"),
		}
	return _pbr_textures[folder]


## Material realista pronto, projetado pela posição no mundo (triplanar):
## "meters" = tamanho de uma repetição da textura.
static func pbr_material(folder: String, meters: float, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [folder, meters, tint.to_html()]
	if _pbr_materials.has(key):
		return _pbr_materials[key]
	var textures := pbr_textures(folder)
	var material := StandardMaterial3D.new()
	material.albedo_texture = textures["albedo"]
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = textures["normal"]
	material.roughness_texture = textures["roughness"]
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / meters
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_pbr_materials[key] = material
	return material


# --- Quarteirões -------------------------------------------------------------

## Chão do quarteirão: calçada de placas em volta e o miolo com piso de pedra,
## com um toque (bem leve) da cor do bairro.
static func add_block_ground(parent: Node3D, center: Vector3, district_color: Color) -> void:
	var size := CityLayout.BLOCK_SIZE
	add_pad(parent, center, Vector2(size, size), pbr_material("Tiles139", 2.0, Color(0.75, 0.74, 0.72)), 0.04)
	var inner := size - SIDEWALK_WIDTH * 2.0
	var tint := Color(0.62, 0.62, 0.62).lerp(district_color, 0.18)
	add_pad(parent, center, Vector2(inner, inner), pbr_material("Tiles141", 3.0, tint), 0.05)


## Um poste em cada canto do quarteirão, com o braço virado para o cruzamento.
static func add_block_lights(parent: Node3D, center: Vector3) -> void:
	var corner := CityLayout.BLOCK_SIZE / 2.0 - 0.7
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var light := StreetLight.new()
			light.position = center + Vector3(sx * corner, 0.0, sz * corner)
			# O braço aponta para -Z do poste: giramos para ele apontar para fora.
			light.rotation.y = atan2(-sx, -sz)
			parent.add_child(light)


## Terreno vazio: "praça de bolso" com piso, árvores em floreiras de concreto
## (em grade, bem urbano) e dois bancos.
static func add_park(parent: Node3D, lot: Transform3D) -> void:
	var size := CityLayout.LOT_SIZE - 2.0
	add_pad(parent, lot.origin, Vector2(size, size), pbr_material("Tiles141", 2.5, Color(0.55, 0.55, 0.55)), 0.07)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lot.origin)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_planter_with_tree(parent, lot.origin + Vector3(sx * 3.2, 0.0, sz * 3.2), rng)
	for side in [-1.0, 1.0]:
		add_bench(parent, lot * Transform3D(Basis(Vector3.UP, PI / 2.0 if side > 0 else -PI / 2.0),
				Vector3(side * 1.2, 0.0, 0.0)))


## Floreira de concreto (com colisão) e uma árvore dentro.
static func add_planter_with_tree(parent: Node3D, base: Vector3, rng: RandomNumberGenerator) -> void:
	var planter := CSGBox3D.new()
	planter.size = Vector3(1.8, 0.55, 1.8)
	planter.position = base + Vector3(0.0, 0.275, 0.0)
	planter.material = pbr_material("Concrete034", 2.0, Color(0.7, 0.7, 0.7))
	planter.use_collision = true
	parent.add_child(planter)
	add_pad(parent, base + Vector3(0.0, 0.5, 0.0), Vector2(1.6, 1.6), make_material(Color(0.1, 0.08, 0.06)), 0.06)
	add_model(parent, TREES[rng.randi_range(0, TREES.size() - 1)], base + Vector3(0.0, 0.55, 0.0),
			TREE_SCALE * rng.randf_range(0.85, 1.1), rng.randf() * TAU)
	add_model(parent, BUSH, base + Vector3(0.45, 0.55, 0.35), BUSH_SCALE, rng.randf() * TAU)


## Banco simples: base de concreto e assento de madeira escura.
static func add_bench(parent: Node3D, where: Transform3D) -> void:
	var bench := Node3D.new()
	bench.transform = where
	parent.add_child(bench)
	for x in [-0.8, 0.8]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.25, 0.42, 0.5)
		leg.mesh = leg_mesh
		leg.position = Vector3(x, 0.21, 0.0)
		leg.material_override = pbr_material("Concrete034", 2.0, Color(0.6, 0.6, 0.6))
		bench.add_child(leg)
	var seat := MeshInstance3D.new()
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(2.0, 0.08, 0.55)
	seat.mesh = seat_mesh
	seat.position = Vector3(0.0, 0.46, 0.0)
	var wood := make_material(Color(0.24, 0.16, 0.1))
	wood.roughness = 0.6
	seat.material_override = wood
	bench.add_child(seat)


# --- Praça -------------------------------------------------------------------

## Praça: piso de pedra, chafariz de concreto com água, árvores e postes.
static func add_plaza(parent: Node3D) -> void:
	var size := CityLayout.BLOCK_SIZE
	add_pad(parent, Vector3.ZERO, Vector2(size, size), pbr_material("Tiles141", 3.0, Color(0.6, 0.6, 0.59)), 0.04)

	# Chafariz: uma bacia (cilindro MENOS um cilindro menor) com água dentro.
	var basin := CSGCylinder3D.new()
	basin.name = "Fountain"
	basin.radius = 2.0
	basin.height = 0.6
	basin.sides = 48
	basin.position = Vector3(0.0, 0.3, 0.0)
	basin.material = pbr_material("Concrete034", 2.0, Color(0.72, 0.72, 0.72))
	basin.use_collision = true
	var hollow := CSGCylinder3D.new()
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.radius = 1.75
	hollow.height = 0.6
	hollow.sides = 48
	hollow.position = Vector3(0.0, 0.15, 0.0)
	basin.add_child(hollow)
	parent.add_child(basin)

	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 1.75
	water_mesh.bottom_radius = 1.75
	water_mesh.height = 0.05
	water.mesh = water_mesh
	water.position = Vector3(0.0, 0.47, 0.0)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.03, 0.06, 0.08)
	water_material.roughness = 0.02
	water_material.metallic = 0.2
	water.material_override = water_material
	parent.add_child(water)

	# Árvores em floreiras nos quatro cantos, e os postes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var corner := size / 2.0 - 4.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_planter_with_tree(parent, Vector3(sx * corner, 0.0, sz * corner), rng)
	add_block_lights(parent, Vector3.ZERO)


# --- Ruas --------------------------------------------------------------------

## Faixas tracejadas no meio das ruas (sem pintar em cima dos cruzamentos).
## Todas as faixas são UMA MultiMesh: milhares de cópias custam quase nada.
static func add_street_markings(parent: Node3D, cells: Array[Vector2i], half: float) -> void:
	var ring := 0
	for cell in cells:
		ring = maxi(ring, maxi(absi(cell.x), absi(cell.y)))
	# As ruas passam entre os quarteirões: no meio de dois centros vizinhos.
	var lines: Array[float] = []
	for k in range(-ring - 1, ring + 1):
		lines.append((k + 0.5) * CityLayout.BLOCK_PITCH)

	var dashes: Array[Transform3D] = []
	var period := LANE_DASH_LENGTH + LANE_DASH_GAP
	for line in lines:
		var t := -half + period / 2.0
		while t < half - period / 2.0:
			if not _near_any(t, lines, CityLayout.STREET_WIDTH / 2.0 + 0.5):
				# Rua na direção Z (x fixo) e rua na direção X (z fixo, girada 90°).
				dashes.append(Transform3D(Basis.IDENTITY, Vector3(line, 0.03, t)))
				dashes.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(t, 0.03, line)))
			t += period

	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.18, 0.02, LANE_DASH_LENGTH)
	var paint := make_material(LANE_MARK_COLOR)
	paint.roughness = 0.6
	dash_mesh.material = paint
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dash_mesh
	multimesh.instance_count = dashes.size()
	for i in dashes.size():
		multimesh.set_instance_transform(i, dashes[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "LaneMarkings"
	instance.multimesh = multimesh
	parent.add_child(instance)


static func _near_any(value: float, list: Array[float], distance: float) -> bool:
	for item in list:
		if absf(value - item) < distance:
			return true
	return false


# --- Utilidades --------------------------------------------------------------

## Coloca um modelo (.glb) na cena, com escala e giro.
static func add_model(parent: Node3D, scene: PackedScene, position: Vector3, model_scale: float, yaw: float) -> Node3D:
	var model := scene.instantiate() as Node3D
	model.position = position
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = yaw
	_fix_materials(model)
	parent.add_child(model)
	return model


## Tira o "metálico" dos materiais do modelo e aplica as cores de PLANT_COLORS.
static func _fix_materials(model: Node) -> void:
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh_instance.mesh.get_surface_count():
			var original := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			if not _fixed_materials.has(original):
				var fixed := original.duplicate() as StandardMaterial3D
				fixed.metallic = 0.0
				fixed.roughness = 0.9
				if PLANT_COLORS.has(original.resource_name):
					fixed.albedo_color = PLANT_COLORS[original.resource_name]
				_fixed_materials[original] = fixed
			mesh_instance.set_surface_override_material(surface, _fixed_materials[original])


## Placa fina de chão, só visual (a colisão é do chão de baixo).
static func add_pad(parent: Node3D, center: Vector3, pad_size: Vector2, material: Material, height: float) -> void:
	var pad := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(pad_size.x, height, pad_size.y)
	pad.mesh = mesh
	pad.position = center + Vector3(0.0, height / 2.0, 0.0)
	pad.material_override = material
	parent.add_child(pad)


static func make_material(material_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = material_color
	material.roughness = 0.9
	return material
