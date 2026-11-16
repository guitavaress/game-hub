class_name TreeModel
extends Node3D
## Árvores de VERDADE de perto e a foto delas de longe (Fase 19.2; em uso desde a 19.3).
##
## Perto, cada árvore é o modelo feito no Blender (tools/blender/gerar_arvore.py,
## em assets/models/trees/): uma MultiMesh por material (a casca e as folhas),
## com o vento no tree_model.gdshader. Longe, é a impostora do MESMO modelo (o
## atlas que tools/make_tree_impostor.gd tira do .glb), com o tree_impostor.gdshader.
## As duas trocam a uma distância que segue a qualidade gráfica
## (swap_distance), numa faixa pontilhada: nunca as duas no mesmo ponto da tela.
## 19.3: cada árvore troca na SUA distância (até SWAP_JITTER para mais ou para
## menos, sorteada pela posição dela): quando você anda, as árvores trocam uma
## de cada vez, e não um anel inteiro pontilhado de uma vez.
##
## Para a Godot não mandar à placa o que está longe, as cópias são repartidas
## em CÉLULAS (quadrados de CELL_METERS m): cada célula tem as suas MultiMesh, e
## a Godot só desenha o modelo das células perto e a impostora das longe
## (visibility_range). Dentro da célula, a troca é árvore por árvore (no shader).
##
## A CÂMERA DA TERCEIRA PESSOA (Fase 20.5): cada árvore ganha um volume só da
## câmera (CameraBlock) com a forma da copa: um casco convexo tirado do modelo
## (crown_hull), da altura em que os galhos abrem até o topo, um pouco mais
## estreito que as folhas (CROWN_SHRINK). O braço da câmera para na beira da
## copa, em vez de entrar nos galhos; o jogador não bate nele. Um corpo por
## célula, com uma forma por árvore (a mesma forma da espécie, na escala da
## cópia).
##
## O atlas de um modelo é sempre impostor_path(modelo):
## assets/models/trees/pine.glb -> assets/generated/pine_impostor.png.
##
## Uso:
##   var trees := TreeModel.new()
##   add_child(trees)
##   trees.setup("res://assets/models/trees/pine.glb", transforms)
##   trees.add(mais_transforms)   # acrescenta aos poucos (as floreiras da cidade)
## "transforms": uma por árvore, no espaço deste nó; a origem é o pé do tronco
## e a escala Y diz a altura (1 = a altura do modelo, model_height()).

## Lado de uma célula (m).
const CELL_METERS: float = 32.0
## Largura da faixa da troca, para cada lado da distância (m).
const SWAP_BAND: float = 2.5
## Quanto a distância da troca de cada árvore varia (fração, para cada lado).
const SWAP_JITTER: float = 0.15
## Quanto a ponta anda com o vento (m, na altura do modelo): o mesmo do pinheiro de hoje.
const SWAY: float = 0.18
## A copa (para o volume da câmera) começa onde o modelo passa deste raio (m,
## sem escala): abaixo é só o tronco, que já tem colisão de verdade.
const CROWN_MIN_RADIUS: float = 0.6
## O volume fica com esta fração do raio das folhas: a câmera pode encostar
## nas pontas soltas, mas não entra no meio dos galhos.
const CROWN_SHRINK: float = 0.85
## Fatia de altura (m, sem escala) e pontos por anel do casco da copa.
const CROWN_BAND: float = 0.5
const CROWN_RING: int = 8
const SHADER: Shader = preload("res://worlds/city/tree_model.gdshader")
const GENERATED: String = "res://assets/generated/"

## As espécies já lidas: [modelo, tinta] -> {bark_mesh, leaves_mesh,
## bark_material, leaves_material, impostor_mesh, impostor_material, height, radius,
## crown_shape}.
static var _species: Dictionary = {}

var _transforms: Array[Transform3D] = []
var _species_key: Array = []
## As cópias por célula (Vector2i -> Array[Transform3D], no espaço deste nó).
var _by_cell: Dictionary = {}
## O nó de cada célula (Vector2i -> Node3D).
var _cells: Dictionary = {}


## A distância (m) em que o modelo vira a foto, por qualidade gráfica.
static func swap_distance(level: String) -> float:
	match level:
		"leve":
			return 30.0
		"media":
			return 50.0
	return 70.0


## O atlas da foto de longe de um modelo (o .png que o make_tree_impostor.gd grava).
static func impostor_path(model_path: String) -> String:
	return GENERATED + model_path.get_file().get_basename() + "_impostor.png"


## Lê (uma vez) o modelo e o atlas de uma espécie. {} se algo não carregar.
static func species(model_path: String, tint: Color = Color.WHITE) -> Dictionary:
	var key := [model_path, tint]
	if _species.has(key):
		return _species[key]
	var result := _load_species(model_path, impostor_path(model_path), tint)
	_species[key] = result
	return result


static func _load_species(model_path: String, atlas_path: String, tint: Color) -> Dictionary:
	var scene := load(model_path) as PackedScene
	var atlas := load(atlas_path) as Texture2D
	var info := TreeImpostor.info_for(atlas_path)
	if scene == null or atlas == null or info.is_empty():
		return {}
	var node := scene.instantiate()
	var meshes := {}
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		meshes[String(mesh_instance.name)] = mesh_instance.mesh
	node.free()
	if not meshes.has("bark") or not meshes.has("leaves"):
		push_warning("O modelo %s não tem as malhas bark e leaves." % model_path)
		return {}
	var bark: Mesh = meshes["bark"]
	var leaves: Mesh = meshes["leaves"]
	var box := bark.get_aabb().merge(leaves.get_aabb())
	var height := box.end.y
	var radius := maxf(maxf(-box.position.x, box.end.x), maxf(-box.position.z, box.end.z))
	var bark_material := _make_material(bark, false, height, radius, tint)
	var leaves_material := _make_material(leaves, true, height, radius, tint)
	# A impostora do mesmo tamanho do modelo (escala 1 = a mesma altura).
	var quad := TreeImpostor.make_quad(info, height)
	var impostor_material := TreeImpostor.make_material(atlas, info, tint, SWAY, height)
	impostor_material.set_shader_parameter("near_jitter", SWAP_JITTER)
	return {
		"crown_shape": crown_hull([bark, leaves]),
		"bark_mesh": bark,
		"leaves_mesh": leaves,
		"bark_material": bark_material,
		"leaves_material": leaves_material,
		"impostor_mesh": quad,
		"impostor_material": impostor_material,
		"height": height,
		"radius": radius,
	}


## O casco da copa (para o volume da câmera): em cada fatia de CROWN_BAND m de
## altura, o raio mais largo das malhas; da primeira fatia que passa de
## CROWN_MIN_RADIUS até o topo, um anel de CROWN_RING pontos com esse raio
## vezes CROWN_SHRINK. O casco convexo desses anéis é a forma (null se o
## modelo não tiver copa).
static func crown_hull(meshes: Array) -> ConvexPolygonShape3D:
	var bands := {}
	for mesh: Mesh in meshes:
		for surface in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var band := floori(vertex.y / CROWN_BAND)
				bands[band] = maxf(float(bands.get(band, 0.0)), Vector2(vertex.x, vertex.z).length())
	var keys := bands.keys()
	keys.sort()
	var points := PackedVector3Array()
	var started := false
	for band: int in keys:
		var radius := float(bands[band])
		started = started or radius > CROWN_MIN_RADIUS
		if not started:
			continue
		for y in [band * CROWN_BAND, (band + 1) * CROWN_BAND]:
			for k in CROWN_RING:
				var angle := TAU * k / CROWN_RING
				points.append(Vector3(cos(angle) * radius * CROWN_SHRINK, y, sin(angle) * radius * CROWN_SHRINK))
	if points.size() < 4:
		return null
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


## O material de uma malha do modelo: as texturas que vieram no .glb, no shader
## da árvore (vento, troca e, nas folhas, o recorte e a normal da copa).
static func _make_material(mesh: Mesh, foliage: bool, height: float, radius: float,
		tint: Color) -> ShaderMaterial:
	var source := mesh.surface_get_material(0) as BaseMaterial3D
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("foliage", foliage)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("tree_height", height)
	material.set_shader_parameter("crown_radius", radius)
	material.set_shader_parameter("sway_amount", SWAY)
	material.set_shader_parameter("swap_band", SWAP_BAND)
	material.set_shader_parameter("swap_jitter", SWAP_JITTER)
	if source != null:
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
		if source.albedo_texture != null:
			material.set_shader_parameter("texture_size", float(source.albedo_texture.get_width()))
		if source.normal_enabled and source.normal_texture != null:
			material.set_shader_parameter("normal_texture", source.normal_texture)
			material.set_shader_parameter("use_normal_texture", true)
		if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			material.set_shader_parameter("alpha_cut", source.alpha_scissor_threshold)
	return material


## Monta as árvores (troca todas as que havia). Devolve false se a espécie não carregou.
func setup(model_path: String, transforms: Array[Transform3D], tint: Color = Color.WHITE) -> bool:
	var data := species(model_path, tint)
	if data.is_empty():
		push_warning("A árvore %s não carregou." % model_path)
		return false
	_species_key = [model_path, tint]
	_transforms.clear()
	_by_cell.clear()
	for key: Vector2i in _cells:
		# Sai da cena já, para as células velhas e as novas não ficarem juntas um quadro.
		var old: Node3D = _cells[key]
		remove_child(old)
		old.queue_free()
	_cells.clear()
	add(transforms)
	return true


## Ao entrar na cena: passa a ouvir a qualidade do menu e usa a distância dela.
## Fica aqui, e não no setup, porque quem monta as árvores pode montá-las
## antes de pô-las na cena (o BiomeScatter faz assim); fora da cena não há
## AppConfig para perguntar (revisão da 19.3).
func _enter_tree() -> void:
	var config := _config()
	if config != null and not config.settings_changed.is_connected(_on_settings_changed):
		config.settings_changed.connect(_on_settings_changed)
	var data: Dictionary = _species.get(_species_key, {})
	if not data.is_empty():
		_apply_distance(data)


## Acrescenta árvores à espécie do setup (só as células que ganharam árvore são
## refeitas). Sem setup antes, não faz nada.
func add(transforms: Array[Transform3D]) -> void:
	var data: Dictionary = _species.get(_species_key, {})
	if data.is_empty() or transforms.is_empty():
		return
	var touched := {}
	for item in transforms:
		_transforms.append(item)
		var key := Vector2i(floori(item.origin.x / CELL_METERS), floori(item.origin.z / CELL_METERS))
		if not _by_cell.has(key):
			_by_cell[key] = []
		(_by_cell[key] as Array).append(item)
		touched[key] = true
	for key: Vector2i in touched:
		_fill_cell(key, data)
	_apply_distance(data)


## As cópias (no espaço deste nó), na ordem em que entraram.
func get_transforms() -> Array[Transform3D]:
	return _transforms.duplicate()


## Quantas células (cada uma com o modelo e a impostora).
func get_cell_count() -> int:
	return _cells.size()


## A altura do modelo (m), sem escala: a escala Y 1 de uma cópia.
func model_height() -> float:
	var data: Dictionary = _species.get(_species_key, {})
	return float(data.get("height", 0.0))


## Cria a célula (na primeira vez) e põe nas três MultiMesh dela todas as cópias.
func _fill_cell(key: Vector2i, data: Dictionary) -> void:
	var cell: Node3D = _cells.get(key)
	if cell == null:
		cell = Node3D.new()
		cell.name = "Cell_%d_%d" % [key.x, key.y]
		cell.position = Vector3((key.x + 0.5) * CELL_METERS, 0.0, (key.y + 0.5) * CELL_METERS)
		add_child(cell)
		_cells[key] = cell
		for part: String in ["bark", "leaves", "impostor"]:
			var instance := MultiMeshInstance3D.new()
			instance.name = part.capitalize()
			instance.multimesh = MultiMesh.new()
			instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			instance.multimesh.mesh = data[part + "_mesh"]
			instance.material_override = data[part + "_material"]
			cell.add_child(instance)
	var local: Array[Transform3D] = []
	var largest := 1.0
	for item: Transform3D in _by_cell[key]:
		local.append(Transform3D(item.basis, item.origin - cell.position))
		largest = maxf(largest, item.basis.get_scale().y)
	_fill_camera_block(cell, local, data)
	for instance: Node in cell.get_children():
		if not instance is MultiMeshInstance3D:
			continue
		var multimesh := (instance as MultiMeshInstance3D).multimesh
		multimesh.instance_count = local.size()
		for k in local.size():
			multimesh.set_instance_transform(k, local[k])
		if instance.name == "Impostor":
			# A impostora gira para a câmera: a caixa da Godot precisa de folga.
			(instance as GeometryInstance3D).extra_cull_margin = \
					(data["impostor_mesh"] as QuadMesh).size.x / 2.0 * largest
		else:
			# O vento tira a árvore um pouco da caixa.
			(instance as GeometryInstance3D).extra_cull_margin = 1.0


## O volume só da câmera de uma célula (CameraBlock): um corpo, uma forma de
## copa por árvore. Refeito inteiro quando a célula ganha árvores.
func _fill_camera_block(cell: Node3D, local: Array[Transform3D], data: Dictionary) -> void:
	var crown: ConvexPolygonShape3D = data.get("crown_shape")
	if crown == null:
		return
	var body := cell.get_node_or_null(^"CameraBlock") as StaticBody3D
	if body == null:
		body = CameraBlock.make_body()
		cell.add_child(body)
	for owner_id in body.get_shape_owners():
		body.remove_shape_owner(owner_id)
	for item in local:
		var owner_id := body.create_shape_owner(body)
		body.shape_owner_add_shape(owner_id, crown)
		body.shape_owner_set_transform(owner_id, item)


## Quantas formas de copa (volumes da câmera) há, somando as células.
func get_camera_block_count() -> int:
	var count := 0
	for key: Vector2i in _cells:
		var body := (_cells[key] as Node3D).get_node_or_null(^"CameraBlock") as StaticBody3D
		if body != null:
			count += body.get_shape_owners().size()
	return count


## A troca na distância da qualidade atual: nos materiais (árvore por árvore)
## e nas células (a Godot nem manda à placa o que está fora da faixa).
func _apply_distance(data: Dictionary) -> void:
	var config := _config()
	var distance := swap_distance(String(config.call("get_quality")) if config != null else "alta")
	(data["bark_material"] as ShaderMaterial).set_shader_parameter("swap_distance", distance)
	(data["leaves_material"] as ShaderMaterial).set_shader_parameter("swap_distance", distance)
	var impostor: ShaderMaterial = data["impostor_material"]
	impostor.set_shader_parameter("near_hide", distance)
	impostor.set_shader_parameter("near_band", SWAP_BAND)
	# Folga da célula: do meio até o canto, mais a árvore mais alta (a Godot
	# mede até o meio da caixa de cada MultiMesh, que fica no alto da copa).
	# A troca de cada árvore vai de distance × (1 - SWAP_JITTER) a × (1 + SWAP_JITTER).
	var slack := CELL_METERS * 0.75 + float(data["height"]) * 2.0
	var nearest := distance * (1.0 - SWAP_JITTER) - SWAP_BAND
	var farthest := distance * (1.0 + SWAP_JITTER) + SWAP_BAND
	for key: Vector2i in _cells:
		for instance: Node in (_cells[key] as Node3D).get_children():
			var geometry := instance as GeometryInstance3D
			if geometry == null:
				continue
			if geometry.name == "Impostor":
				geometry.visibility_range_begin = maxf(0.0, nearest - slack)
			else:
				geometry.visibility_range_end = farthest + slack


## O AppConfig pelo caminho (sem o nome do autoload: o gerador do atlas usa
## esta classe antes de os autoloads existirem). null fora da árvore de cena.
func _config() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null(^"/root/AppConfig")


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		var data: Dictionary = _species.get(_species_key, {})
		if not data.is_empty():
			_apply_distance(data)
