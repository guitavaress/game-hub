class_name CityDecor
extends RefCounted
## Decoração da cidade: calçadas, faixas das ruas, postes, árvores, arbustos,
## flores e o chafariz. Só visual (e um pouco de colisão); nada de lógica.
##
## Modelos: Kenney Nature Kit e City Kit Roads (CC0), em assets/kenney/.
## Uso:  CityDecor.add_park(self, lote)  — cada função acrescenta nós ao "parent".

const TREES: Array[PackedScene] = [
	preload("res://assets/kenney/nature-kit/tree_default.glb"),
	preload("res://assets/kenney/nature-kit/tree_detailed.glb"),
	preload("res://assets/kenney/nature-kit/tree_fat.glb"),
	preload("res://assets/kenney/nature-kit/tree_cone.glb"),
]
const BUSHES: Array[PackedScene] = [
	preload("res://assets/kenney/nature-kit/plant_bush.glb"),
	preload("res://assets/kenney/nature-kit/plant_bushLarge.glb"),
	preload("res://assets/kenney/nature-kit/plant_bushSmall.glb"),
]
const FLOWERS: Array[PackedScene] = [
	preload("res://assets/kenney/nature-kit/flower_redA.glb"),
	preload("res://assets/kenney/nature-kit/flower_yellowA.glb"),
	preload("res://assets/kenney/nature-kit/flower_purpleA.glb"),
]
const GRASS: PackedScene = preload("res://assets/kenney/nature-kit/grass.glb")
const ROCK: PackedScene = preload("res://assets/kenney/nature-kit/rock_smallA.glb")

## Os modelos da Nature Kit são pequenos (árvore ~1,7): estas escalas deixam
## árvore com ~6 m, arbusto com ~0,8 m e flor com ~0,6 m.
const TREE_SCALE: float = 3.5
const BUSH_SCALE: float = 3.0
const FLOWER_SCALE: float = 2.0

## A Nature Kit vem com folhas verde-menta e materiais "metálicos" (o que faz
## as plantas refletirem o céu e parecerem azuladas). Trocamos por um verde
## natural e tiramos o metálico. Nome do material no modelo -> cor nova.
const PLANT_COLORS: Dictionary[String, Color] = {
	"leafsGreen": Color(0.29, 0.6, 0.27),
	"grass": Color(0.33, 0.64, 0.29),
}

## Materiais já corrigidos (original -> corrigido), para não criar um por planta.
static var _fixed_materials: Dictionary = {}

const SIDEWALK_WIDTH: float = 1.5
const SIDEWALK_COLOR: Color = Color("9a9892")
const GRASS_COLOR: Color = Color("4f7a3a")
const LANE_MARK_COLOR: Color = Color("e8e2c8")
const LANE_DASH_LENGTH: float = 2.5
const LANE_DASH_GAP: float = 3.5


# --- Quarteirões -------------------------------------------------------------

## Chão do quarteirão: calçada cinza em volta e o miolo na cor do bairro.
static func add_block_ground(parent: Node3D, center: Vector3, district_color: Color) -> void:
	var size := CityLayout.BLOCK_SIZE
	add_pad(parent, center, Vector2(size, size), SIDEWALK_COLOR, 0.04)
	var inner := size - SIDEWALK_WIDTH * 2.0
	add_pad(parent, center, Vector2(inner, inner), district_color.darkened(0.45), 0.05)


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


## Terreno vazio: gramado com árvores, arbustos e flores (sempre iguais para o
## mesmo terreno, porque o sorteio usa a posição como semente).
static func add_park(parent: Node3D, lot: Transform3D) -> void:
	var size := CityLayout.LOT_SIZE - 2.0
	add_pad(parent, lot.origin, Vector2(size, size), GRASS_COLOR, 0.07)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lot.origin)
	var half := size / 2.0 - 1.0
	for i in 3:
		add_tree(parent, lot.origin + Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half)), rng)
	for i in 5:
		add_model(parent, BUSHES.pick_random(), lot.origin + Vector3(rng.randf_range(-half, half), 0.07,
				rng.randf_range(-half, half)), BUSH_SCALE, rng.randf() * TAU)
	for i in 10:
		add_model(parent, FLOWERS.pick_random(), lot.origin + Vector3(rng.randf_range(-half, half), 0.07,
				rng.randf_range(-half, half)), FLOWER_SCALE, rng.randf() * TAU)
	for i in 8:
		add_model(parent, GRASS, lot.origin + Vector3(rng.randf_range(-half, half), 0.07,
				rng.randf_range(-half, half)), BUSH_SCALE, rng.randf() * TAU)


## Árvore com um "tronco" invisível de colisão (o jogador não atravessa).
static func add_tree(parent: Node3D, base: Vector3, rng: RandomNumberGenerator) -> void:
	var tree_scale := TREE_SCALE * rng.randf_range(0.85, 1.2)
	add_model(parent, TREES[rng.randi_range(0, TREES.size() - 1)], base, tree_scale, rng.randf() * TAU)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.35
	cylinder.height = 3.0
	shape.shape = cylinder
	shape.position = Vector3(0.0, 1.5, 0.0)
	body.add_child(shape)
	body.position = base
	parent.add_child(body)


# --- Praça -------------------------------------------------------------------

## Praça: piso claro, chafariz com água, canteiros de flores e postes.
static func add_plaza(parent: Node3D) -> void:
	var size := CityLayout.BLOCK_SIZE
	add_pad(parent, Vector3.ZERO, Vector2(size, size), Color("b8b2a4"), 0.04)

	# Chafariz: uma bacia (cilindro MENOS um cilindro menor) com água dentro.
	var basin := CSGCylinder3D.new()
	basin.name = "Fountain"
	basin.radius = 2.0
	basin.height = 0.6
	basin.sides = 32
	basin.position = Vector3(0.0, 0.3, 0.0)
	basin.material = make_material(Color("8a8f99"))
	basin.use_collision = true
	var hollow := CSGCylinder3D.new()
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.radius = 1.7
	hollow.height = 0.6
	hollow.sides = 32
	hollow.position = Vector3(0.0, 0.15, 0.0)
	basin.add_child(hollow)
	parent.add_child(basin)

	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 1.7
	water_mesh.bottom_radius = 1.7
	water_mesh.height = 0.05
	water.mesh = water_mesh
	water.position = Vector3(0.0, 0.45, 0.0)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.25, 0.55, 0.85, 0.85)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.05
	water_material.metallic = 0.3
	water.material_override = water_material
	parent.add_child(water)

	# Canteiros nos quatro cantos da praça.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var corner := size / 2.0 - 4.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bed_center := Vector3(sx * corner, 0.0, sz * corner)
			add_pad(parent, bed_center, Vector2(4.0, 4.0), GRASS_COLOR, 0.07)
			add_model(parent, BUSHES[1], bed_center + Vector3(0.0, 0.07, 0.0), BUSH_SCALE, rng.randf() * TAU)
			for i in 6:
				add_model(parent, FLOWERS.pick_random(), bed_center + Vector3(rng.randf_range(-1.6, 1.6), 0.07,
						rng.randf_range(-1.6, 1.6)), FLOWER_SCALE, rng.randf() * TAU)
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
	dash_mesh.size = Vector3(0.22, 0.02, LANE_DASH_LENGTH)
	dash_mesh.material = make_material(LANE_MARK_COLOR)
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
static func add_pad(parent: Node3D, center: Vector3, pad_size: Vector2, pad_color: Color, height: float) -> void:
	var pad := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(pad_size.x, height, pad_size.y)
	pad.mesh = mesh
	pad.position = center + Vector3(0.0, height / 2.0, 0.0)
	pad.material_override = make_material(pad_color)
	parent.add_child(pad)


static func make_material(material_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = material_color
	material.roughness = 0.9
	return material
