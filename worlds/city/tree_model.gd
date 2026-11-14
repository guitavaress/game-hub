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
const SHADER: Shader = preload("res://worlds/city/tree_model.gdshader")
const GENERATED: String = "res://assets/generated/"

## As espécies já lidas: [modelo, tinta] -> {bark_mesh, leaves_mesh,
## bark_material, leaves_material, impostor_mesh, impostor_material, height, radius}.
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
		"bark_mesh": bark,
		"leaves_mesh": leaves,
		"bark_material": bark_material,
		"leaves_material": leaves_material,
		"impostor_mesh": quad,
		"impostor_material": impostor_material,
		"height": height,
		"radius": radius,
	}


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
		(_cells[key] as Node3D).queue_free()
	_cells.clear()
	var config := _config()
	if config != null and not config.settings_changed.is_connected(_on_settings_changed):
		config.settings_changed.connect(_on_settings_changed)
	add(transforms)
	return true


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
	for instance: Node in cell.get_children():
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
