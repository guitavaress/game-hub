class_name BiomeScatter
extends Node3D
## Pinheiros e rochas espalhados no bairro de um bioma (Fase 15.7).
##
## Cada família do bioma (BiomeSpec.scatter, as que têm in_town) vira UMA
## MultiMesh (um só desenho para todas as cópias) e, se tiver colisão, um
## corpo com um cilindro por cópia. Os pinheiros são impostores (a foto de
## TreeImpostor, com a tinta e o vento do pinheiro); as rochas são a malha do
## glTF com o material de pedra com neve por cima (BiomeBuilder.snow_cover_material).
##
## Onde pode: só nas "regiões", o miolo de neve de cada quarteirão e de cada
## vaga, onde não passa calçada nem rua. Cada família fica a
## walkable_clearance metros da beira da região (a calçada) e dos pontos
## "keep_out" (portas e estações, cada um com o seu raio livre). O sorteio é
## sempre igual (semente fixa por bairro, família e quarteirão).
##
## A conta (plan) é pura e estática: a 15.9 reaproveita para a encosta.

## Distância mínima entre dois troncos de pinheiro, além dos raios.
const IMPOSTOR_SPACING: float = 3.0
## Distância mínima entre duas rochas (ou entre uma rocha e um tronco).
const MESH_SPACING: float = 0.8
## As rochas são esticadas para os lados (blocos baixos e largos, brief 15.0).
const MESH_SPREAD: Vector2 = Vector2(1.1, 1.4)
## Quanto da altura da rocha fica enterrado (a base irregular não flutua).
const MESH_SINK: float = 0.08
## Tentativas de sorteio por cópia desejada, antes de desistir.
const ATTEMPTS_PER_ITEM: int = 30
## Tamanho de uma repetição da textura da rocha, em metros.
const ROCK_METERS: float = 2.0
## Quanto a ponta do pinheiro anda com o vento (m, na altura do atlas).
const PINE_SWAY: float = 0.18
## Altura máxima do cilindro de colisão (no pinheiro, só o tronco importa).
const COLLISION_HEIGHT_MAX: float = 4.0

## Malhas já lidas dos glTF (caminho -> {mesh, aabb}).
static var _meshes: Dictionary = {}

## As cópias de cada família (índice no BiomeSpec.scatter -> Array[Transform3D]).
## A MultiMesh guarda os dados só na placa de vídeo (sem tela, nos testes, ela
## devolve tudo zerado): aqui fica a cópia para quem precisa consultar.
var _transforms: Dictionary = {}


## As cópias de uma família, no espaço do BiomeScatter (que fica na origem).
func get_transforms(index: int) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	result.assign(_transforms.get(index, []))
	return result


## Monta as famílias do bioma que vão no bairro. "regions": o miolo de neve
## dos quarteirões e vagas; "keep_out": pontos livres (x, z, raio).
func setup(category_id: String, biome: BiomeSpec, regions: Array[Rect2], keep_out: Array[Vector3]) -> void:
	name = "BiomeScatter_%s" % category_id
	# O que já foi posto (x, z, raio), para as famílias não se atropelarem.
	var occupied: Array[Vector3] = []
	for i in biome.scatter.size():
		var spec := biome.scatter[i]
		if not spec.in_town:
			continue
		var source := _source(spec, biome)
		if source.is_empty():
			push_warning("O elemento %s do bioma %s não carregou." % [spec.source, biome.id])
			continue
		var items := plan(spec, regions, keep_out, occupied, hash([category_id, i]),
				source["height"], source["radius"])
		_add_family(i, spec, source, items)


## As cópias de uma família: [{position, height, yaw, scale (Vector3), radius,
## collision}]. Acrescenta cada uma em "occupied". "base_height" e
## "base_radius": altura e raio da malha (ou do tronco) sem escala.
static func plan(spec: ScatterSpec, regions: Array[Rect2], keep_out: Array[Vector3],
		occupied: Array[Vector3], seed_value: int, base_height: float, base_radius: float) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if spec.density <= 0.0 or base_height <= 0.0:
		return items
	var impostor := spec.kind == "impostor"
	var spacing := IMPOSTOR_SPACING if impostor else MESH_SPACING
	var clearance := spec.walkable_clearance
	# Escala de referência: a da menor altura, sem esticar (o raio de colisão
	# do perfil vale para ela e cresce junto com a cópia).
	var reference := spec.height_range.x / base_height
	var spread := MESH_SPREAD if not impostor else Vector2.ONE
	var largest := base_radius * spec.height_range.y / base_height * spread.y
	for region in regions:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, region.position])
		var usable := region.grow(-clearance)
		if usable.size.x <= 0.0 or usable.size.y <= 0.0:
			continue
		var wanted := floori(usable.get_area() * spec.density / 100.0 + rng.randf())
		# Só os pontos livres perto desta região (para a conta não crescer com a cidade).
		var near_keep: Array[Vector3] = []
		for point in keep_out:
			var reach := maxf(point.z, clearance) + largest
			if usable.grow(reach).has_point(Vector2(point.x, point.y)):
				near_keep.append(point)
		var placed := 0
		var tries := 0
		while placed < wanted and tries < wanted * ATTEMPTS_PER_ITEM:
			tries += 1
			# Os sorteios sempre na mesma ordem (o resultado não muda).
			var height := rng.randf_range(spec.height_range.x, spec.height_range.y)
			var yaw := rng.randf() * TAU
			var stretch := rng.randf_range(spread.x, spread.y)
			var u := rng.randf()
			var v := rng.randf()
			var scale_y := height / base_height
			var scale_xz := scale_y * stretch
			var radius := base_radius * scale_xz
			var collision := spec.collision_radius * scale_xz / reference
			var footprint := maxf(radius, collision) if not impostor else maxf(collision, 0.5)
			var inner := usable.grow(-footprint)
			if inner.size.x <= 0.0 or inner.size.y <= 0.0:
				continue
			var spot := inner.position + Vector2(u, v) * inner.size
			if _blocked(spot, footprint, clearance, spacing, near_keep, occupied):
				continue
			occupied.append(Vector3(spot.x, spot.y, footprint))
			items.append({
				"position": Vector3(spot.x, 0.0, spot.y),
				"height": height,
				"yaw": yaw,
				"scale": Vector3(scale_xz, scale_y, scale_xz),
				"radius": footprint,
				"collision": collision,
			})
			placed += 1
	return items


## Se o ponto (com raio "radius") cai perto demais de um ponto livre ou de
## algo já posto.
static func _blocked(spot: Vector2, radius: float, clearance: float, spacing: float,
		keep_out: Array[Vector3], occupied: Array[Vector3]) -> bool:
	for point in keep_out:
		if spot.distance_to(Vector2(point.x, point.y)) < maxf(point.z, clearance) + radius:
			return true
	for other in occupied:
		if spot.distance_to(Vector2(other.x, other.y)) < other.z + radius + spacing:
			return true
	return false


## Malha, material e medidas de uma família. {} se a origem não carregar.
static func _source(spec: ScatterSpec, biome: BiomeSpec) -> Dictionary:
	if spec.kind == "impostor":
		var atlas := load(spec.source) as Texture2D
		var info := TreeImpostor.info_for(spec.source)
		if atlas == null or info.is_empty():
			return {}
		var tree_height := float(info["tree_height"])
		var quad := TreeImpostor.make_quad(info, tree_height)
		return {
			"mesh": quad,
			"material": TreeImpostor.make_material(atlas, info, spec.tint, PINE_SWAY, tree_height),
			"height": tree_height,
			# O raio do tronco é o de colisão do perfil (na menor altura).
			"radius": spec.collision_radius * tree_height / spec.height_range.x,
			"bottom": 0.0,
			"cull": quad.size.x / 2.0,
		}
	var loaded := _mesh_of(spec.source)
	if loaded.is_empty():
		return {}
	var aabb: AABB = loaded["aabb"]
	var material: Material = null
	if biome.backdrop != null and not biome.backdrop.rock_folder.is_empty():
		material = BiomeBuilder.snow_cover_material(biome, biome.backdrop.rock_folder, spec.tint, ROCK_METERS)
	return {
		"mesh": loaded["mesh"],
		"material": material,
		"height": aabb.size.y,
		"radius": maxf(aabb.size.x, aabb.size.z) / 2.0,
		"bottom": aabb.position.y,
		"cull": 0.0,
	}


## A primeira malha de um glTF (ou de outra cena), lida uma vez só.
static func _mesh_of(path: String) -> Dictionary:
	if _meshes.has(path):
		return _meshes[path]
	var result := {}
	var scene := load(path) as PackedScene
	if scene != null:
		var node := scene.instantiate()
		var found := node.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			var mesh: Mesh = (found[0] as MeshInstance3D).mesh
			result = {"mesh": mesh, "aabb": mesh.get_aabb()}
		node.free()
	_meshes[path] = result
	return result


## Uma família: a MultiMesh e, se houver, o corpo com os cilindros.
func _add_family(index: int, spec: ScatterSpec, source: Dictionary, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source["mesh"]
	multimesh.instance_count = items.size()
	var largest := 1.0
	var transforms: Array[Transform3D] = []
	for k in items.size():
		var item: Dictionary = items[k]
		var item_scale: Vector3 = item["scale"]
		var origin: Vector3 = item["position"]
		if spec.kind == "mesh":
			# A rocha desce até a base encostar no chão, e um pouco mais.
			origin.y = -float(source["bottom"]) * item_scale.y - MESH_SINK * float(item["height"])
		var basis := Basis(Vector3.UP, item["yaw"]) * Basis.from_scale(item_scale)
		transforms.append(Transform3D(basis, origin))
		multimesh.set_instance_transform(k, transforms[k])
		largest = maxf(largest, item_scale.x)
	_transforms[index] = transforms
	var instance := MultiMeshInstance3D.new()
	instance.name = "Scatter_%d" % index
	instance.multimesh = multimesh
	if source["material"] != null:
		instance.material_override = source["material"]
	# O impostor gira para a câmera: a caixa da Godot precisa de folga.
	instance.extra_cull_margin = float(source["cull"]) * largest
	add_child(instance)

	if spec.collision_radius <= 0.0:
		return
	var body := StaticBody3D.new()
	body.name = "ScatterCollision_%d" % index
	add_child(body)
	for item in items:
		var shape := CylinderShape3D.new()
		var height := minf(float(item["height"]), COLLISION_HEIGHT_MAX)
		shape.radius = float(item["collision"])
		shape.height = height
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = (item["position"] as Vector3) + Vector3(0.0, height / 2.0, 0.0)
		body.add_child(collision)
