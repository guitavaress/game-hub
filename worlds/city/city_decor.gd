class_name CityDecor
extends RefCounted
## Decoração da cidade: calçadas, faixas das ruas, postes, praças de bolso,
## floreiras e o chafariz. Só visual (e um pouco de colisão); nada de lógica.
##
## Materiais realistas: ambientCG (CC0), em assets/ambientcg/. Plantas: nas
## floreiras de concreto, uma árvore "impostora" (a foto de uma jacarandá de
## verdade, veja TreeImpostor) e arbustos baixos (Kenney Nature Kit, CC0,
## recoloridos num verde escuro; abaixo de 1 m o "low-poly" não aparece).
## Uso:  CityDecor.add_park(self, lote)  — cada função acrescenta nós ao "parent".

const AMBIENTCG: String = "res://assets/ambientcg/"

## Emissão de TODO o néon da cidade (faixas, moldura da porta, letreiros):
## de dia é quase só tinta; à noite brilha e o glow faz o halo.
const NEON_DAY: float = 0.15
const NEON_NIGHT: float = 3.2

const BUSH: PackedScene = preload("res://assets/kenney/nature-kit/plant_bushLarge.glb")

## O arbusto da Nature Kit é pequeno (~0,3): esta escala deixa ele com ~0,7 m.
const BUSH_SCALE: float = 2.2
## Altura das árvores das floreiras (sorteada entre os dois valores, em metros).
const TREE_HEIGHT_RANGE: Vector2 = Vector2(5.0, 6.5)
## Onde ficam os arbustos dentro da floreira (a partir do centro, em metros).
const PLANTER_BUSH_SPOTS: Array[Vector2] = [Vector2(-0.4, -0.35), Vector2(0.42, -0.2), Vector2(-0.05, 0.42)]

## A Nature Kit vem com folhas verde-menta e materiais "metálicos". Trocamos por
## verdes escuros e naturais e tiramos o metálico. Nome do material -> cor nova.
const PLANT_COLORS: Dictionary[String, Color] = {
	"leafsGreen": Color(0.16, 0.3, 0.17),
	"grass": Color(0.18, 0.33, 0.18),
	"woodBark": Color(0.23, 0.17, 0.13),
}

const SIDEWALK_WIDTH: float = 1.5
## Largura da borda de pedra em volta do piso da praça.
const PLAZA_BORDER: float = 1.0
const GRASS_COLOR: Color = Color(0.12, 0.2, 0.12)
const LANE_MARK_COLOR: Color = Color(0.85, 0.83, 0.76)
const LANE_DASH_LENGTH: float = 2.5
const LANE_DASH_GAP: float = 3.5
## Poças: um sorteio a cada PUDDLE_STEP metros de rua, com esta chance.
const PUDDLE_STEP: float = 12.0
const PUDDLE_CHANCE: float = 0.4

## Materiais e texturas já carregados (para não repetir o trabalho).
static var _fixed_materials: Dictionary = {}
static var _pbr_materials: Dictionary = {}
static var _pbr_textures: Dictionary = {}
static var _puddles: Array = []


# --- Materiais realistas (PBR) -----------------------------------------------


## Emissão do néon para uma hora do dia (0 = dia, 1 = noite).
static func neon_energy(night: float) -> float:
	return lerpf(NEON_DAY, NEON_NIGHT, night)


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


## Terreno vazio: "praça de bolso" com piso, floreiras de concreto com
## arbustos baixos (em grade, bem urbano) e dois bancos.
static func add_park(parent: Node3D, lot: Transform3D) -> void:
	var size := CityLayout.LOT_SIZE - 2.0
	add_pad(parent, lot.origin, Vector2(size, size), pbr_material("Tiles141", 2.5, Color(0.55, 0.55, 0.55)), 0.07)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lot.origin)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_planter(parent, lot.origin + Vector3(sx * 3.2, 0.0, sz * 3.2), rng)
	for side in [-1.0, 1.0]:
		add_bench(parent, lot * Transform3D(Basis(Vector3.UP, PI / 2.0 if side > 0 else -PI / 2.0),
				Vector3(side * 1.2, 0.0, 0.0)))


## Floreira de concreto (com colisão) com uma árvore (impostora: só uma foto,
## veja TreeImpostor) e três arbustos baixos em volta.
static func add_planter(parent: Node3D, base: Vector3, rng: RandomNumberGenerator) -> void:
	var planter := CSGBox3D.new()
	planter.size = Vector3(1.8, 0.55, 1.8)
	planter.position = base + Vector3(0.0, 0.275, 0.0)
	planter.material = pbr_material("Concrete034", 2.0, Color(0.7, 0.7, 0.7))
	planter.use_collision = true
	parent.add_child(planter)
	add_pad(parent, base + Vector3(0.0, 0.5, 0.0), Vector2(1.6, 1.6), make_material(Color(0.1, 0.08, 0.06)), 0.06)
	for spot in PLANTER_BUSH_SPOTS:
		add_model(parent, BUSH, base + Vector3(spot.x, 0.55, spot.y),
				BUSH_SCALE * rng.randf_range(0.8, 1.05), rng.randf() * TAU)
	var tree := TreeImpostor.new()
	tree.height = rng.randf_range(TREE_HEIGHT_RANGE.x, TREE_HEIGHT_RANGE.y)
	tree.position = base + Vector3(0.0, 0.5, 0.0)
	tree.rotation.y = rng.randf() * TAU  # cada árvore mostra outro lado
	parent.add_child(tree)


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

## Praça: piso de pedra, chafariz de concreto com água, floreiras e postes.
static func add_plaza(parent: Node3D) -> void:
	var size := CityLayout.BLOCK_SIZE
	# Borda de 1 m em outra pedra, e o miolo com placas grandes (a textura
	# repete a cada 4 m, o dobro da calçada: a repetição quase não aparece).
	add_pad(parent, Vector3.ZERO, Vector2(size, size), pbr_material("Tiles141", 3.0, Color(0.5, 0.5, 0.49)), 0.04)
	var inner := size - PLAZA_BORDER * 2.0
	add_pad(parent, Vector3.ZERO, Vector2(inner, inner), pbr_material("Tiles139", 4.0, Color(0.6, 0.64, 0.72)), 0.045)

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

	# Floreiras com arbustos nos quatro cantos, e os postes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var corner := size / 2.0 - 4.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_planter(parent, Vector3(sx * corner, 0.0, sz * corner), rng)
	add_block_lights(parent, Vector3.ZERO)


# --- Ruas --------------------------------------------------------------------

## Poças nas beiras das ruas: manchas escuras e lisas (rugosidade 0) que
## refletem o céu, os postes e o néon. São Decals (projeções no chão),
## sorteadas sempre iguais (semente fixa).
static func add_puddles(parent: Node3D, half: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var textures := _puddle_textures()
	var pitch := CityLayout.BLOCK_PITCH
	var line := -floorf(half / pitch - 0.5) * pitch - pitch / 2.0
	var lines: Array[float] = []
	while line < half:
		if absf(line) < half - 2.0:
			lines.append(line)
		line += pitch
	for street in lines:
		for along_x in [true, false]:  # ruas leste-oeste e norte-sul
			var t := -half + PUDDLE_STEP / 2.0
			while t < half - PUDDLE_STEP / 2.0:
				if rng.randf() < PUDDLE_CHANCE:
					var length := rng.randf_range(1.6, 3.6)
					var width := rng.randf_range(0.9, 1.8)
					var side := 1.0 if rng.randf() < 0.5 else -1.0
					var offset := side * (CityLayout.STREET_WIDTH / 2.0 - 0.8 - width / 2.0)
					var spot := Vector3(t + rng.randf_range(-3.0, 3.0), 0.0, street + offset) if along_x \
							else Vector3(street + offset, 0.0, t + rng.randf_range(-3.0, 3.0))
					var puddle := Decal.new()
					var pair: Array = textures[rng.randi_range(0, textures.size() - 1)]
					puddle.texture_albedo = pair[0]
					puddle.texture_orm = pair[1]
					puddle.albedo_mix = 0.3
					puddle.normal_fade = 0.9  # só no chão (não no meio-fio)
					puddle.cull_mask = 1
					puddle.size = Vector3(length, 1.0, width) if along_x else Vector3(width, 1.0, length)
					puddle.position = spot + Vector3(0.0, 0.2, 0.0)
					puddle.rotation.y = rng.randf_range(-0.15, 0.15)
					parent.add_child(puddle)
				t += PUDDLE_STEP


## Três formatos de poça (manchas irregulares), feitos uma vez: cor (escura,
## o alfa é o formato) e ORM (rugosidade 0 = lisa como água).
static func _puddle_textures() -> Array:
	if not _puddles.is_empty():
		return _puddles
	var noise := FastNoiseLite.new()
	noise.frequency = 0.06
	for variant in 3:
		noise.seed = 17 + variant
		var shape := Image.create(128, 64, false, Image.FORMAT_RGBA8)
		var orm := Image.create(128, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 128:
				# Elipse deformada pelo ruído, com a borda suave.
				var px := (x + 0.5) / 64.0 - 1.0
				var py := (y + 0.5) / 32.0 - 1.0
				var r := sqrt(px * px + py * py) + noise.get_noise_2d(x, y) * 0.45
				var alpha := 1.0 - smoothstep(0.55, 0.8, r)
				shape.set_pixel(x, y, Color(0.035, 0.038, 0.045, alpha))
				orm.set_pixel(x, y, Color(1.0, 0.0, 0.0, 1.0))
		_puddles.append([ImageTexture.create_from_image(shape), ImageTexture.create_from_image(orm)])
	return _puddles


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
