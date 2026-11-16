class_name BiomeScatter
extends Node3D
## Pinheiros e rochas espalhados no bairro de um bioma (Fase 15.7).
##
## Cada família do bioma (BiomeSpec.scatter, as que têm in_town) vira UMA
## MultiMesh (um só desenho para todas as cópias) e, se tiver colisão, um
## corpo com um cilindro por cópia. As rochas são a malha do glTF com o
## material de pedra com neve por cima (BiomeBuilder.snow_cover_material).
## As árvores (tipo "tree", 19.3) são um TreeModel (o modelo do Blender perto,
## a foto dele longe), com a tinta do perfil; o tipo "impostor" (só a foto,
## TreeImpostor, como os pinheiros até a 19.2) continua valendo.
##
## Onde pode: só nas "regiões", o miolo de neve de cada quarteirão e de cada
## vaga, onde não passa calçada nem rua. Cada família fica a
## walkable_clearance metros da beira da região (a calçada), dos pontos
## "keep_out" (as portas, cada uma com o seu raio livre) e das áreas
## "keep_out_areas" (a boca de cada estação do metrô). As distâncias contam da
## beira da cópia: do tronco no pinheiro (decisão do dono, 2026-10-29) e do
## vértice mais longe na rocha. O sorteio é sempre igual (semente fixa por
## bairro, família e quarteirão).
##
## 15.7.1 (revisão do Astra): o raio da rocha vem dos vértices (a caixa da
## malha é menor que a pedra); o cilindro da rocha cobre o desenho e para na
## altura dele (a rocha é enterrada um pouco); as estações viram áreas.
##
## A conta (plan) é pura e estática: a 15.9 reaproveita para a encosta.
##
## 19.7 (a floresta, num bairro que pode ter prédios): a COPA de cada árvore
## (o raio dela no modelo, TreeModel.species, na escala da cópia) fica a
## CROWN_GAP m dos prédios, das bocas do metrô, dos marcos e das portas, além
## da conta de sempre do tronco. Assim nenhuma copa atravessa uma parede. Uma
## árvore pode ficar mais perto da calçada que a copa: a copa passa por cima
## de quem anda (a da floresta começa acima de 3,5 m). As rochas usam a pasta
## do material do perfil (ScatterSpec.material_folder), com o chão do bioma
## por cima, sem depender da montanha.
##
## 19.12 (a encosta): as famílias on_backdrop vão para a montanha pelo MESMO
## plan(), chamado pela BackdropTerrain. Para isso, o plan() aceita um filtro
## ("accept": quem chama diz se o lugar serve: na encosta, longe da trilha, do
## mirante e da vista da luneta) e o add_on_ground() assenta cada cópia no
## chão de um terreno: a árvore em pé, com o pé no ponto mais baixo em volta do
## tronco; a rocha deitada na inclinação do chão. Na cidade, nada muda.

## Distância mínima entre dois troncos de árvore (impostora ou modelo), além dos raios.
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
## Distância mínima entre uma cópia e a boca de uma estação (além da
## walkable_clearance, se ela for maior): o lugar de quem desce a escada.
const AREA_GAP: float = 1.5
## Folga entre a beira da copa de uma árvore e um prédio, uma boca do metrô,
## um marco ou uma porta (19.7).
const CROWN_GAP: float = 0.5
## No chão de um terreno (19.12): quantos pontos em volta da cópia medem o chão.
const GROUND_SAMPLES: int = 8
## Quanto o pé da árvore desce abaixo do ponto mais baixo em volta do tronco.
const TREE_SINK: float = 0.05
## Lado (m) das células em que as rochas de um terreno são repartidas: cada
## célula é uma MultiMesh, para a Godot cortar o que está fora da tela e
## escolher o detalhe (LOD) pela distância de cada célula.
const GROUND_CELL: float = 32.0
## O BiomeBuilder (o material da rocha com neve), lido pelo caminho (_source).
const BUILDER_PATH: String = "res://worlds/city/biome/biome_builder.gd"

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
## dos quarteirões e vagas; "keep_out": pontos livres (x, z, raio);
## "keep_out_areas": retângulos livres (no chão).
## "amount" (15.14): quanto da densidade do perfil fica (GraphicsQuality.scatter_amount).
func setup(category_id: String, biome: BiomeSpec, regions: Array[Rect2], keep_out: Array[Vector3],
		keep_out_areas: Array[Rect2] = [], amount: float = 1.0) -> void:
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
				source["height"], source["radius"], keep_out_areas, amount, float(source.get("crown", 0.0)))
		_add_family(i, spec, source, items)


## As cópias de uma família: [{position, height, yaw, scale (Vector3), radius,
## collision}]. Acrescenta cada uma em "occupied". "base_height" e
## "base_radius": altura e raio da malha (ou do tronco) sem escala.
## "base_crown" (19.7): o raio da copa sem escala (0 = sem copa; só nas
## árvores), que fica a CROWN_GAP dos pontos e das áreas livres.
## "accept" (19.12, opcional): func(spot: Vector2, footprint: float, crown:
## float, height: float) -> bool, chamada depois das conferências de sempre;
## false descarta o lugar (o sorteio segue na mesma ordem, então o resultado
## continua o mesmo para a mesma semente). "crown" já vem com a CROWN_GAP.
static func plan(spec: ScatterSpec, regions: Array[Rect2], keep_out: Array[Vector3],
		occupied: Array[Vector3], seed_value: int, base_height: float, base_radius: float,
		keep_out_areas: Array[Rect2] = [], amount: float = 1.0, base_crown: float = 0.0,
		accept: Callable = Callable()) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if spec.density <= 0.0 or amount <= 0.0 or base_height <= 0.0:
		return items
	# Árvore (só foto ou modelo): conta do tronco, sem esticar para os lados.
	var impostor := spec.kind != "mesh"
	var spacing := IMPOSTOR_SPACING if impostor else MESH_SPACING
	var clearance := spec.walkable_clearance
	# Escala de referência: a da menor altura, sem esticar (o raio de colisão
	# do perfil vale para ela e cresce junto com a cópia).
	var reference := spec.height_range.x / base_height
	var spread := MESH_SPREAD if not impostor else Vector2.ONE
	var largest := base_radius * spec.height_range.y / base_height * spread.y
	# A maior copa (na maior altura), para achar os pontos e as áreas perto.
	var largest_crown := base_crown * spec.height_range.y / base_height + CROWN_GAP if base_crown > 0.0 else 0.0
	# O maior "footprint" possível de uma cópia desta família (19.12: para
	# achar o que já foi posto perto de cada região).
	var largest_collision := spec.collision_radius * spec.height_range.y / base_height * spread.y / reference
	var largest_footprint := maxf(maxf(largest, largest_collision), 0.5)
	for region in regions:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, region.position])
		var usable := region.grow(-clearance)
		if usable.size.x <= 0.0 or usable.size.y <= 0.0:
			continue
		var wanted := floori(usable.get_area() * spec.density * amount / 100.0 + rng.randf())
		# Só os pontos livres perto desta região (para a conta não crescer com a cidade).
		var near_keep: Array[Vector3] = []
		for point in keep_out:
			var reach := maxf(maxf(point.z, clearance) + largest, largest_crown)
			if usable.grow(reach).has_point(Vector2(point.x, point.y)):
				near_keep.append(point)
		var near_areas: Array[Rect2] = []
		for area in keep_out_areas:
			if usable.grow(maxf(maxf(AREA_GAP, clearance) + largest, largest_crown)).intersects(area):
				near_areas.append(area)
		# 19.12: só o que já foi posto perto desta região pode atrapalhar (a
		# encosta tem centenas de cópias). Quem fica de fora está longe demais
		# de qualquer ponto da região: o resultado é o mesmo de olhar todos.
		var near_occupied: Array[Vector3] = []
		for other in occupied:
			if area_distance(usable, Vector2(other.x, other.y)) < other.z + largest_footprint + spacing:
				near_occupied.append(other)
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
			if not impostor and collision > 0.0:
				# O cilindro da rocha cobre a pedra inteira (nada dela fica "sem corpo").
				collision = maxf(collision, radius)
			var footprint := maxf(radius, collision) if not impostor else maxf(collision, 0.5)
			var inner := usable.grow(-footprint)
			if inner.size.x <= 0.0 or inner.size.y <= 0.0:
				continue
			var spot := inner.position + Vector2(u, v) * inner.size
			var crown := base_crown * scale_xz + CROWN_GAP if base_crown > 0.0 else 0.0
			if _blocked(spot, footprint, clearance, spacing, near_keep, near_occupied, near_areas, crown):
				continue
			if accept.is_valid() and not bool(accept.call(spot, footprint, crown, height)):
				continue
			occupied.append(Vector3(spot.x, spot.y, footprint))
			near_occupied.append(Vector3(spot.x, spot.y, footprint))
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


## Se o ponto (com raio "radius") cai perto demais de um ponto livre, de uma
## área livre ou de algo já posto. "crown" (19.7): o raio da copa com a folga
## (0 = sem copa), que também não pode chegar aos pontos e às áreas livres.
static func _blocked(spot: Vector2, radius: float, clearance: float, spacing: float,
		keep_out: Array[Vector3], occupied: Array[Vector3], areas: Array[Rect2] = [],
		crown: float = 0.0) -> bool:
	for point in keep_out:
		if spot.distance_to(Vector2(point.x, point.y)) < maxf(maxf(point.z, clearance) + radius, crown):
			return true
	for area in areas:
		if area_distance(area, spot) < maxf(maxf(AREA_GAP, clearance) + radius, crown):
			return true
	for other in occupied:
		if spot.distance_to(Vector2(other.x, other.y)) < other.z + radius + spacing:
			return true
	return false


## A distância de um ponto até um retângulo (0 dentro dele).
static func area_distance(area: Rect2, point: Vector2) -> float:
	var nearest := point.clamp(area.position, area.end)
	return point.distance_to(nearest)


## Malha, material e medidas de uma família (19.12: a encosta usa as mesmas).
## {} se a origem não carregar. Para o plan(): height, radius e (árvores) crown.
static func source_of(spec: ScatterSpec, biome: BiomeSpec) -> Dictionary:
	return _source(spec, biome)


## A direção "para cima" do chão num ponto (19.12): a normal do terreno pela
## diferença das alturas a "step" metros para cada lado. "surface" é
## func(ponto: Vector2) -> float, a altura do chão.
static func ground_normal(surface: Callable, spot: Vector2, step: float) -> Vector3:
	var dx := float(surface.call(spot + Vector2(step, 0.0))) - float(surface.call(spot - Vector2(step, 0.0)))
	var dz := float(surface.call(spot + Vector2(0.0, step))) - float(surface.call(spot - Vector2(0.0, step)))
	return Vector3(-dx, 2.0 * step, -dz).normalized()


## Uma família num terreno (19.12, a encosta): as cópias do plan() assentadas
## no chão de "surface" (func(ponto: Vector2) -> float). Sem colisão: ninguém
## anda fora da trilha. O nó se chama Scatter_<índice>, como na cidade.
func add_on_ground(index: int, spec: ScatterSpec, source: Dictionary, items: Array[Dictionary],
		surface: Callable) -> void:
	_add_family(index, spec, source, items, surface)


## Onde fica uma cópia no chão de um terreno. A árvore fica em pé, com o pé no
## ponto mais baixo em volta do tronco (do lado de baixo da encosta ela não
## flutua; do lado de cima, o chão cobre um pouco do tronco, como numa árvore
## de verdade). A rocha deita na inclinação do chão embaixo dela, enterrada
## MESH_SINK da altura, e desce mais se alguma beirada da base ficasse acima do
## chão (onde o chão faz curva).
static func _seat(spec: ScatterSpec, source: Dictionary, item: Dictionary, surface: Callable) -> Transform3D:
	var item_scale: Vector3 = item["scale"]
	var position: Vector3 = item["position"]
	var spot := Vector2(position.x, position.z)
	var radius := float(item["radius"])
	var yaw_basis := Basis(Vector3.UP, item["yaw"]) * Basis.from_scale(item_scale)
	if spec.kind != "mesh":
		var low := float(surface.call(spot))
		for k in GROUND_SAMPLES:
			low = minf(low, float(surface.call(spot + Vector2.from_angle(TAU * k / GROUND_SAMPLES) * radius)))
		return Transform3D(yaw_basis, Vector3(spot.x, low - TREE_SINK, spot.y))
	# O chão medido em pelo menos 1 m em volta: a inclinação média, e não a
	# irregularidade embaixo de uma pedra pequena.
	var up := ground_normal(surface, spot, maxf(radius, 1.0))
	# "tilt" (opcional, a encosta põe nas rochas): (direção, ângulo) a mais
	# sobre a inclinação do chão, para nem toda rocha deitar igual.
	var tilt: Vector2 = item.get("tilt", Vector2.ZERO)
	if tilt.y > 0.0:
		up = up.rotated(Vector3(cos(tilt.x), 0.0, sin(tilt.x)), tilt.y).normalized()
	var basis := Basis(Quaternion(Vector3.UP, up)) * yaw_basis
	var bottom := float(source["bottom"]) * item_scale.y
	var sink := MESH_SINK * float(item["height"])
	# O meio da base fica "sink" abaixo do chão, na direção da normal.
	var base := Vector3(spot.x, float(surface.call(spot)), spot.y) - up * sink
	var lift := 0.0
	for k in GROUND_SAMPLES:
		var rim := spot + Vector2.from_angle(TAU * k / GROUND_SAMPLES) * radius
		# A altura do plano da base sobre este ponto da beirada.
		var plane := base.y - (up.x * (rim.x - base.x) + up.z * (rim.y - base.z)) / up.y
		lift = maxf(lift, plane - float(surface.call(rim)))
	base.y -= lift
	return Transform3D(basis, base - up * bottom)


## Malha, material e medidas de uma família. {} se a origem não carregar.
static func _source(spec: ScatterSpec, biome: BiomeSpec) -> Dictionary:
	if spec.kind == "tree":
		var species := TreeModel.species(spec.source, spec.tint)
		if species.is_empty():
			return {}
		var model_height := float(species["height"])
		return {
			"height": model_height,
			# O raio do tronco é o de colisão do perfil (na menor altura).
			"radius": spec.collision_radius * model_height / spec.height_range.x,
			# A copa: o raio das folhas no modelo (19.7).
			"crown": float(species["radius"]),
		}
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
	# A pedra da peça: a do perfil (19.7) ou, sem ela, a rocha do terreno de fundo.
	var folder := spec.material_folder
	if folder.is_empty() and biome.backdrop != null:
		folder = biome.backdrop.rock_folder
	if not folder.is_empty():
		# O BiomeBuilder pelo caminho, e não pelo nome (19.12): a montanha usa o
		# BiomeScatter, e o nome puxaria na compilação o BiomeBuilder e, por
		# ele, os autoloads (os testes do mirante carregam a montanha antes deles).
		var builder: GDScript = load(BUILDER_PATH)
		material = builder.snow_cover_material(biome, folder, spec.tint, ROCK_METERS)
	return {
		"mesh": loaded["mesh"],
		"material": material,
		"height": aabb.size.y,
		# O vértice mais longe do eixo (a caixa da malha fica aquém: 0,126 contra 0,140 m na rocha).
		"radius": loaded["reach"],
		"bottom": aabb.position.y,
		"cull": 0.0,
	}


## A primeira malha de um glTF (ou de outra cena), lida uma vez só: {mesh,
## aabb, reach}, com "reach" = a maior distância de um vértice até o eixo
## vertical (o raio de verdade da peça, com qualquer giro).
static func mesh_of(path: String) -> Dictionary:
	return _mesh_of(path)


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
			var reach := 0.0
			for surface in mesh.get_surface_count():
				for vertex: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					reach = maxf(reach, Vector2(vertex.x, vertex.z).length())
			result = {"mesh": mesh, "aabb": mesh.get_aabb(), "reach": reach}
		node.free()
	_meshes[path] = result
	return result


## Uma família: a MultiMesh (ou o TreeModel, nas árvores) e, se houver, o
## corpo com os cilindros. O nó se chama Scatter_<índice> nos dois casos.
## "surface" (19.12): com ela, as cópias vão para o chão de um terreno
## (_seat), as rochas são repartidas em células e não há colisão.
func _add_family(index: int, spec: ScatterSpec, source: Dictionary, items: Array[Dictionary],
		surface: Callable = Callable()) -> void:
	if items.is_empty():
		return
	var on_ground := surface.is_valid()
	var largest := 1.0
	var transforms: Array[Transform3D] = []
	for k in items.size():
		var item: Dictionary = items[k]
		var item_scale: Vector3 = item["scale"]
		largest = maxf(largest, item_scale.x)
		if on_ground:
			transforms.append(_seat(spec, source, item, surface))
			continue
		var origin: Vector3 = item["position"]
		if spec.kind == "mesh":
			# A rocha desce até a base encostar no chão, e um pouco mais.
			origin.y = -float(source["bottom"]) * item_scale.y - MESH_SINK * float(item["height"])
		var basis := Basis(Vector3.UP, item["yaw"]) * Basis.from_scale(item_scale)
		transforms.append(Transform3D(basis, origin))
	_transforms[index] = transforms
	if spec.kind == "tree":
		var trees := TreeModel.new()
		trees.name = "Scatter_%d" % index
		add_child(trees)
		trees.setup(spec.source, transforms, spec.tint)
	elif on_ground:
		_add_ground_cells(index, source, transforms, largest)
		return
	else:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = source["mesh"]
		multimesh.instance_count = items.size()
		for k in transforms.size():
			multimesh.set_instance_transform(k, transforms[k])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Scatter_%d" % index
		instance.multimesh = multimesh
		if source["material"] != null:
			instance.material_override = source["material"]
		# O impostor gira para a câmera: a caixa da Godot precisa de folga.
		instance.extra_cull_margin = float(source["cull"]) * largest
		add_child(instance)

	if spec.collision_radius <= 0.0 or on_ground:
		return
	var body := StaticBody3D.new()
	body.name = "ScatterCollision_%d" % index
	add_child(body)
	for item in items:
		var shape := CylinderShape3D.new()
		var height := float(item["height"])
		if spec.kind == "mesh":
			height *= 1.0 - MESH_SINK  # a rocha é enterrada: o corpo para no topo desenhado
		height = minf(height, COLLISION_HEIGHT_MAX)
		shape.radius = float(item["collision"])
		shape.height = height
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = (item["position"] as Vector3) + Vector3(0.0, height / 2.0, 0.0)
		body.add_child(collision)


## As rochas num terreno (19.12), uma MultiMesh por célula de GROUND_CELL m,
## todas debaixo do nó Scatter_<índice>: a Godot corta a célula fora da tela
## e escolhe o detalhe da malha pela distância DELA (numa MultiMesh só, a
## encosta inteira teria um detalhe só, o da rocha mais perto).
func _add_ground_cells(index: int, source: Dictionary, transforms: Array[Transform3D], largest: float) -> void:
	var family := Node3D.new()
	family.name = "Scatter_%d" % index
	add_child(family)
	var cells: Dictionary = {}
	for item in transforms:
		var key := Vector2i(floori(item.origin.x / GROUND_CELL), floori(item.origin.z / GROUND_CELL))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(item)
	for key: Vector2i in cells:
		var items: Array = cells[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = source["mesh"]
		multimesh.instance_count = items.size()
		for k in items.size():
			multimesh.set_instance_transform(k, items[k])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Cell_%d_%d" % [key.x, key.y]
		instance.multimesh = multimesh
		if source["material"] != null:
			instance.material_override = source["material"]
		instance.extra_cull_margin = float(source["cull"]) * largest
		family.add_child(instance)
