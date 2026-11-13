class_name TreeModel
extends Node3D
## Árvores de VERDADE de perto e a foto delas de longe (Fase 19.2).
##
## Perto, cada árvore é o modelo feito no Blender (tools/blender/gerar_arvore.py,
## em assets/models/trees/): uma MultiMesh por material (a casca e as folhas),
## com o vento no tree_model.gdshader. Longe, é a impostora do MESMO modelo (o
## atlas que tools/make_tree_impostor.gd tira do .glb), com o tree_impostor.gdshader.
## As duas trocam a uma distância que segue a qualidade gráfica
## (swap_distance), numa faixa pontilhada: nunca as duas no mesmo ponto da tela.
##
## Para a Godot não mandar à placa o que está longe, as cópias são repartidas
## em CÉLULAS (quadrados de CELL_METERS m): cada célula tem as suas MultiMesh, e
## a Godot só desenha o modelo das células perto e a impostora das longe
## (visibility_range). Dentro da célula, a troca é árvore por árvore (no shader).
##
## Uso:
##   var trees := TreeModel.new()
##   add_child(trees)
##   trees.setup("res://assets/models/trees/pine.glb", "res://assets/generated/pine_blender_impostor.png", transforms)
## "transforms": uma por árvore, no espaço deste nó; a origem é o pé do tronco
## e a escala Y diz a altura (1 = a altura do modelo, model_height()).

## Lado de uma célula (m).
const CELL_METERS: float = 32.0
## Largura da faixa da troca, para cada lado da distância (m).
const SWAP_BAND: float = 2.5
## Quanto a ponta anda com o vento (m, na altura do modelo): o mesmo do pinheiro de hoje.
const SWAY: float = 0.18
const SHADER: Shader = preload("res://worlds/city/tree_model.gdshader")

## As espécies já lidas: [modelo, atlas, tinta] -> {bark_mesh, leaves_mesh,
## bark_material, leaves_material, impostor_mesh, impostor_material, height, radius}.
static var _species: Dictionary = {}

var _transforms: Array[Transform3D] = []
var _species_key: Array = []
var _cells: Array[Node3D] = []


## A distância (m) em que o modelo vira a foto, por qualidade gráfica.
static func swap_distance(level: String) -> float:
	match level:
		"leve":
			return 30.0
		"media":
			return 50.0
	return 70.0


## Lê (uma vez) o modelo e o atlas de uma espécie. {} se algo não carregar.
static func species(model_path: String, atlas_path: String, tint: Color = Color.WHITE) -> Dictionary:
	var key := [model_path, atlas_path, tint]
	if _species.has(key):
		return _species[key]
	var result := _load_species(model_path, atlas_path, tint)
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


## Monta as árvores. Devolve false se a espécie não carregou.
func setup(model_path: String, atlas_path: String, transforms: Array[Transform3D],
		tint: Color = Color.WHITE) -> bool:
	var data := species(model_path, atlas_path, tint)
	if data.is_empty():
		push_warning("A árvore %s não carregou." % model_path)
		return false
	_species_key = [model_path, atlas_path, tint]
	_transforms = transforms.duplicate()
	for cell in _cells:
		cell.queue_free()
	_cells.clear()
	# Reparte as cópias pelas células.
	var groups := {}
	for item in _transforms:
		var key := Vector2i(floori(item.origin.x / CELL_METERS), floori(item.origin.z / CELL_METERS))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(item)
	for key: Vector2i in groups:
		_add_cell(key, groups[key], data)
	var config := _config()
	if config != null and not config.settings_changed.is_connected(_on_settings_changed):
		config.settings_changed.connect(_on_settings_changed)
	_apply_distance(data)
	return true


## As cópias (no espaço deste nó), na ordem do setup.
func get_transforms() -> Array[Transform3D]:
	return _transforms.duplicate()


## Quantas células (cada uma com o modelo e a impostora).
func get_cell_count() -> int:
	return _cells.size()


## A altura do modelo (m), sem escala: a escala Y 1 de uma cópia.
func model_height() -> float:
	var data: Dictionary = _species.get(_species_key, {})
	return float(data.get("height", 0.0))


func _add_cell(key: Vector2i, items: Array, data: Dictionary) -> void:
	var cell := Node3D.new()
	cell.name = "Cell_%d_%d" % [key.x, key.y]
	cell.position = Vector3((key.x + 0.5) * CELL_METERS, 0.0, (key.y + 0.5) * CELL_METERS)
	add_child(cell)
	_cells.append(cell)
	var local: Array[Transform3D] = []
	var largest := 1.0
	for item: Transform3D in items:
		local.append(Transform3D(item.basis, item.origin - cell.position))
		largest = maxf(largest, item.basis.get_scale().y)
	for part: String in ["bark", "leaves", "impostor"]:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = data[part + "_mesh"]
		multimesh.instance_count = local.size()
		for k in local.size():
			multimesh.set_instance_transform(k, local[k])
		var instance := MultiMeshInstance3D.new()
		instance.name = part.capitalize()
		instance.multimesh = multimesh
		instance.material_override = data[part + "_material"]
		if part == "impostor":
			# A impostora gira para a câmera: a caixa da Godot precisa de folga.
			instance.extra_cull_margin = (data["impostor_mesh"] as QuadMesh).size.x / 2.0 * largest
		else:
			# O vento tira a árvore um pouco da caixa.
			instance.extra_cull_margin = 1.0
		cell.add_child(instance)


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
	var slack := CELL_METERS * 0.75 + float(data["height"]) * 2.0
	for cell in _cells:
		for instance: Node in cell.get_children():
			var geometry := instance as GeometryInstance3D
			if geometry.name == "Impostor":
				geometry.visibility_range_begin = maxf(0.0, distance - SWAP_BAND - slack)
			else:
				geometry.visibility_range_end = distance + SWAP_BAND + slack


## O AppConfig pelo caminho (sem o nome do autoload: o gerador do atlas usa
## esta classe antes de os autoloads existirem).
func _config() -> Node:
	return get_node_or_null(^"/root/AppConfig")


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		var data: Dictionary = _species.get(_species_key, {})
		if not data.is_empty():
			_apply_distance(data)
