extends SceneTree
## Teste das árvores: as impostoras (P2.22) viraram o TreeModel (Fase 19.2, a
## amostra; 19.3, todas as árvores do jogo).
##   - na cidade: uma árvore de rua por floreira, todas num TreeModel só
##     (StreetTrees), entre 5 e 6,5 m; nenhuma árvore só de foto;
##   - no bairro do RPG: os pinheiros são um TreeModel (o modelo do Blender);
##   - os dois modelos (pine.glb e street_tree.glb) dentro do orçamento, com as
##     malhas bark e leaves e o atlas de longe tirado deles;
##   - o TreeModel monta as células, aceita árvores aos poucos (add) e troca
##     modelo e foto na mesma distância, com a variação por árvore.

const PINE := "res://assets/models/trees/pine.glb"
const STREET_TREE := "res://assets/models/trees/street_tree.glb"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame
	_check_city(city)
	city.queue_free()
	await process_frame
	for model: String in [PINE, STREET_TREE]:
		_check_species(model)
	await _check_tree_model()

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## As árvores do jogo: as das floreiras e as do bairro do RPG.
func _check_city(city: Node) -> void:
	print("  -- na cidade")
	var planters := 0
	for child in city.get_children():
		if child is CSGBox3D and is_equal_approx(child.size.x, 1.8) and is_equal_approx(child.size.y, 0.55):
			planters += 1
	var street: TreeModel = city.get_node_or_null("StreetTrees")
	var transforms: Array[Transform3D] = street.get_transforms() if street != null else []
	print("   floreiras: %d | árvores de rua: %d" % [planters, transforms.size()])
	_check("as árvores de rua num TreeModel só (StreetTrees)",
			street != null and city.find_children("*", "TreeModel", true, false).size() >= 1)
	_check("uma árvore por floreira", planters > 0 and transforms.size() == planters)
	var heights_ok := street != null
	var on_planter := true
	for item in transforms:
		var meters := item.basis.get_scale().y * street.model_height()
		heights_ok = heights_ok and meters > 4.99 and meters < 6.51
		# O pé da árvore fica na terra da floreira (0,5 m acima do chão).
		on_planter = on_planter and is_equal_approx(item.origin.y, 0.5)
	_check("altura entre 5 e 6,5 m", heights_ok)
	_check("o pé de cada árvore na terra da floreira", on_planter)
	var counts := {"Bark": 0, "Leaves": 0, "Impostor": 0}
	if street != null:
		for cell: Node in street.get_children():
			for part: String in counts:
				var instance := cell.get_node_or_null(part) as MultiMeshInstance3D
				if instance != null:
					counts[part] += instance.multimesh.instance_count
	_check("as três partes com todas as árvores de rua (%s)" % str(counts),
			counts["Bark"] == transforms.size() and counts["Leaves"] == transforms.size()
			and counts["Impostor"] == transforms.size())
	# Nenhuma árvore só de foto: nenhuma MultiMesh fora de um TreeModel usa o shader da impostora.
	var photos := 0
	for node in city.find_children("*", "GeometryInstance3D", true, false):
		var material := (node as GeometryInstance3D).material_override as ShaderMaterial
		if material != null and material.shader == TreeImpostor.SHADER and not node.get_parent().get_parent() is TreeModel:
			photos += 1
	_check("nenhuma árvore que seja só a foto (%d)" % photos, photos == 0)
	var models := 0
	for node in city.find_children("*", "Node3D", true, false):
		if node.scene_file_path.contains("tree"):
			models += 1
	_check("nenhuma cena de árvore instanciada (tudo em MultiMesh)", models == 0)
	# Os pinheiros do RPG (o bioma da montanha: família "tree").
	var scatter: Node = city.find_child("BiomeScatter_rpg", true, false)
	var pines: TreeModel = scatter.get_node_or_null("Scatter_0") if scatter != null else null
	_check("os pinheiros do RPG são um TreeModel com cópias",
			pines != null and pines.get_transforms().size() > 0)
	# Revisão da 19.3: os pinheiros são montados antes de entrar na cena e
	# precisam seguir a qualidade do mesmo jeito (vale com qualquer config).
	var config: Node = city.get_node("/root/AppConfig")
	for trees: TreeModel in [street, pines]:
		if trees == null:
			continue
		_check("%s ouve a troca de qualidade do menu" % trees.name,
				config.settings_changed.is_connected(trees._on_settings_changed))


## Um modelo do gerar_arvore.py: orçamento, malhas, medidas e o atlas dele.
func _check_species(model: String) -> void:
	var name := model.get_file()
	print("  -- %s" % name)
	var bytes := FileAccess.get_file_as_bytes(model).size()
	print("   %s: %d KB" % [name, bytes / 1024])
	_check("%s dentro do orçamento (até 800 KB)" % name, bytes > 0 and bytes <= 800 * 1024)
	var data := TreeModel.species(model)
	_check("%s carrega (malhas bark e leaves, atlas)" % name, not data.is_empty())
	if data.is_empty():
		return
	var bark: Mesh = data["bark_mesh"]
	var leaves: Mesh = data["leaves_mesh"]
	_check("%s: uma superfície por malha (um desenho por material)" % name,
			bark.get_surface_count() == 1 and leaves.get_surface_count() == 1)
	var leaf_arrays := leaves.surface_get_arrays(0)
	_check("%s: as folhas têm UV e a cor dos vértices (o miolo escuro)" % name,
			leaf_arrays[Mesh.ARRAY_TEX_UV] != null and leaf_arrays[Mesh.ARRAY_COLOR] != null)
	var height := float(data["height"])
	var radius := float(data["radius"])
	print("   altura %.2f m | raio da copa %.2f m" % [height, radius])
	if model == PINE:
		_check("o pinheiro tem uns 10 m e a copa de 2 a 3,5 m de raio",
				height > 9.5 and height < 10.6 and radius > 2.0 and radius < 3.5)
	else:
		_check("a árvore de rua tem uns 6 m e a copa de 2 a 3,2 m de raio",
				height > 5.5 and height < 6.6 and radius > 2.0 and radius < 3.2)
	var leaves_material: ShaderMaterial = data["leaves_material"]
	var bark_material: ShaderMaterial = data["bark_material"]
	_check("%s: folhas e casca no shader da árvore, com textura" % name,
			leaves_material.shader == TreeModel.SHADER and bark_material.shader == TreeModel.SHADER
			and leaves_material.get_shader_parameter("albedo_texture") != null
			and bark_material.get_shader_parameter("albedo_texture") != null
			and bool(leaves_material.get_shader_parameter("foliage"))
			and not bool(bark_material.get_shader_parameter("foliage")))
	var atlas := TreeModel.impostor_path(model)
	var info := TreeImpostor.info_for(atlas)
	_check("%s: o atlas de longe (%s) foi tirado dele" % [name, atlas.get_file()],
			String(info.get("source", "")) == name and is_equal_approx(float(info["tree_height"]), height))


## O TreeModel sozinho: células, add aos poucos e a troca.
func _check_tree_model() -> void:
	print("  -- TreeModel")
	_check("a distância da troca cresce com a qualidade",
			TreeModel.swap_distance("leve") < TreeModel.swap_distance("media")
			and TreeModel.swap_distance("media") < TreeModel.swap_distance("alta"))
	_check("o atlas de um modelo é <nome>_impostor.png em assets/generated",
			TreeModel.impostor_path(PINE) == "res://assets/generated/pine_impostor.png")
	var data := TreeModel.species(PINE)
	# 40 árvores espalhadas em 100 x 100 m: várias células, cada uma com o
	# modelo (casca e folhas) e a impostora, as mesmas cópias nas três.
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for i in 40:
		var spot := Vector3(rng.randf_range(-50.0, 50.0), 0.0, rng.randf_range(-50.0, 50.0))
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), spot))
	var trees := TreeModel.new()
	root.add_child(trees)
	var first: Array[Transform3D] = transforms.slice(0, 25)
	var rest: Array[Transform3D] = transforms.slice(25)
	_check("o setup monta", trees.setup(PINE, first))
	var cells_before := trees.get_cell_count()
	trees.add(rest)
	_check("o add acrescenta (40 cópias, na ordem)", trees.get_transforms() == transforms)
	_check("várias células, e o add só cria as que faltam", trees.get_cell_count() > 1 and trees.get_cell_count() >= cells_before)
	var counts := {"Bark": 0, "Leaves": 0, "Impostor": 0}
	var shared := true
	var ranges := true
	var quality: String = root.get_node("AppConfig").get_quality()
	var distance := TreeModel.swap_distance(quality)
	var nearest := distance * (1.0 - TreeModel.SWAP_JITTER) - TreeModel.SWAP_BAND
	var farthest := distance * (1.0 + TreeModel.SWAP_JITTER) + TreeModel.SWAP_BAND
	for cell: Node in trees.get_children():
		for part: String in counts:
			var instance := cell.get_node_or_null(part) as MultiMeshInstance3D
			if instance == null:
				shared = false
				continue
			counts[part] += instance.multimesh.instance_count
			if instance.material_override != data[part.to_lower() + "_material"]:
				shared = false
			if part == "Impostor":
				ranges = ranges and instance.visibility_range_begin < nearest
			else:
				ranges = ranges and instance.visibility_range_end > farthest
	_check("as três partes com as 40 cópias", counts["Bark"] == 40 and counts["Leaves"] == 40 and counts["Impostor"] == 40)
	_check("um material por parte, o mesmo em todas as células", shared)
	_check("as células cobrem a faixa da troca, com a variação por árvore", ranges)
	var leaves_material: ShaderMaterial = data["leaves_material"]
	var impostor_material: ShaderMaterial = data["impostor_material"]
	_check("modelo e impostora trocam na mesma distância (%.0f m, %s)" % [distance, quality],
			is_equal_approx(float(leaves_material.get_shader_parameter("swap_distance")), distance)
			and is_equal_approx(float(impostor_material.get_shader_parameter("near_hide")), distance))
	_check("e com a mesma variação por árvore (%.0f%%)" % (TreeModel.SWAP_JITTER * 100.0),
			is_equal_approx(float(leaves_material.get_shader_parameter("swap_jitter")), TreeModel.SWAP_JITTER)
			and is_equal_approx(float(impostor_material.get_shader_parameter("near_jitter")), TreeModel.SWAP_JITTER))
	# O setup de novo troca tudo (nada das 40 fica).
	var one: Array[Transform3D] = [Transform3D.IDENTITY]
	trees.setup(PINE, one)
	await process_frame
	_check("um setup novo troca as árvores (1 cópia, 1 célula)",
			trees.get_transforms().size() == 1 and trees.get_cell_count() == 1 and trees.get_child_count() == 1)
	trees.queue_free()
	await process_frame

	# Montado FORA da cena e só depois posto nela (como o BiomeScatter faz):
	# tem de ouvir a qualidade e usar a distância dela.
	var outside := TreeModel.new()
	outside.setup(PINE, one)
	root.add_child(outside)
	var outside_ok: bool = root.get_node("AppConfig").settings_changed.is_connected(outside._on_settings_changed)
	for cell: Node in outside.get_children():
		var bark := cell.get_node_or_null("Bark") as GeometryInstance3D
		outside_ok = outside_ok and bark != null and bark.visibility_range_end > farthest \
				and bark.visibility_range_end < farthest + TreeModel.CELL_METERS + float(data["height"]) * 2.0 + 0.01
	_check("montado fora da cena, segue a qualidade ao entrar nela", outside_ok)
	outside.queue_free()
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
