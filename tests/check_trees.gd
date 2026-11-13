extends SceneTree
## Teste das árvores impostoras (P2.22) e do TreeModel (Fase 19.2).

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

	var trees := city.find_children("*", "TreeImpostor", true, false)
	var planters := 0
	for child in city.get_children():
		if child is CSGBox3D and is_equal_approx(child.size.x, 1.8) and is_equal_approx(child.size.y, 0.55):
			planters += 1
	print("   árvores: %d | floreiras: %d" % [trees.size(), planters])
	_check("uma árvore por floreira", trees.size() == planters and planters > 0)
	var ok_size := true
	var shared := true
	for tree in trees:
		var quad: QuadMesh = tree.mesh
		# Altura da árvore dentro do quadro: 5 a 6,5 m.
		var info: Dictionary = load("res://assets/generated/tree_impostor.json").data
		var height: float = quad.size.y * float(info["tree_height"]) / float(info["frame_meters"])
		if height < 4.99 or height > 6.51:
			ok_size = false
		if tree.material_override != trees[0].material_override:
			shared = false
	_check("altura entre 5 e 6,5 m", ok_size)
	_check("um material só para todas (2 triângulos cada)", shared and (trees[0].mesh as QuadMesh).subdivide_width == 0)
	var atlas: Texture2D = trees[0].material_override.get_shader_parameter("atlas")
	_check("atlas 2048 x 1024", atlas.get_width() == 2048 and atlas.get_height() == 1024)
	var models := 0
	for node in city.find_children("*", "Node3D", true, false):
		if node.scene_file_path.contains("tree_"):
			models += 1
	_check("nenhum modelo de árvore pesado na cena", models == 0)
	# Fase 19.2: o TreeModel existe, mas o jogo de hoje ainda não o usa.
	_check("nenhum TreeModel na cidade (a troca é da 19.3)",
			city.find_children("*", "TreeModel", true, false).is_empty())
	var old_pines_ok := true
	for node in city.find_children("Scatter_*", "MultiMeshInstance3D", true, false):
		var material := (node as MultiMeshInstance3D).material_override as ShaderMaterial
		if material != null and material.shader == TreeImpostor.SHADER:
			var hide: Variant = material.get_shader_parameter("near_hide")
			if hide != null and float(hide) != 0.0:
				old_pines_ok = false
	_check("as impostoras de hoje não somem de perto (near_hide = 0)", old_pines_ok)
	city.queue_free()
	await process_frame
	await _check_tree_model()

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## O TreeModel (19.2): o pinheiro do Blender perto e a foto dele longe.
func _check_tree_model() -> void:
	const MODEL := "res://assets/models/trees/pine.glb"
	const ATLAS := "res://assets/generated/pine_blender_impostor.png"
	print("  -- TreeModel (pinheiro do Blender)")
	var bytes := FileAccess.get_file_as_bytes(MODEL).size()
	print("   pine.glb: %d KB" % (bytes / 1024))
	_check("pine.glb dentro do orçamento (até 800 KB)", bytes > 0 and bytes <= 800 * 1024)
	var data := TreeModel.species(MODEL, ATLAS)
	_check("a espécie carrega (malhas bark e leaves, atlas novo)", not data.is_empty())
	if data.is_empty():
		return
	var bark: Mesh = data["bark_mesh"]
	var leaves: Mesh = data["leaves_mesh"]
	_check("uma superfície por malha (um desenho por material)",
			bark.get_surface_count() == 1 and leaves.get_surface_count() == 1)
	var leaf_arrays := leaves.surface_get_arrays(0)
	_check("as folhas têm UV e a cor dos vértices (o miolo escuro)",
			leaf_arrays[Mesh.ARRAY_TEX_UV] != null and leaf_arrays[Mesh.ARRAY_COLOR] != null)
	var height := float(data["height"])
	var radius := float(data["radius"])
	print("   altura %.2f m | raio da copa %.2f m" % [height, radius])
	_check("o pinheiro tem uns 10 m e a copa de 2 a 3,5 m de raio",
			height > 9.5 and height < 10.6 and radius > 2.0 and radius < 3.5)
	var leaves_material: ShaderMaterial = data["leaves_material"]
	var bark_material: ShaderMaterial = data["bark_material"]
	_check("folhas e casca no shader da árvore, com textura",
			leaves_material.shader == TreeModel.SHADER and bark_material.shader == TreeModel.SHADER
			and leaves_material.get_shader_parameter("albedo_texture") != null
			and bark_material.get_shader_parameter("albedo_texture") != null
			and bool(leaves_material.get_shader_parameter("foliage"))
			and not bool(bark_material.get_shader_parameter("foliage")))
	_check("a distância da troca cresce com a qualidade",
			TreeModel.swap_distance("leve") < TreeModel.swap_distance("media")
			and TreeModel.swap_distance("media") < TreeModel.swap_distance("alta"))

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
	_check("o setup monta", trees.setup(MODEL, ATLAS, transforms))
	_check("guarda as 40 cópias", trees.get_transforms().size() == 40)
	_check("várias células", trees.get_cell_count() > 1)
	var counts := {"Bark": 0, "Leaves": 0, "Impostor": 0}
	var shared := true
	var ranges := true
	var quality: String = root.get_node("AppConfig").get_quality()
	var distance := TreeModel.swap_distance(quality)
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
				ranges = ranges and instance.visibility_range_begin < distance
			else:
				ranges = ranges and instance.visibility_range_end > distance
	_check("as três partes com as 40 cópias", counts["Bark"] == 40 and counts["Leaves"] == 40 and counts["Impostor"] == 40)
	_check("um material por parte, o mesmo em todas as células", shared)
	_check("as células cobrem a faixa da troca", ranges)
	var impostor_material: ShaderMaterial = data["impostor_material"]
	_check("modelo e impostora trocam na mesma distância (%.0f m, %s)" % [distance, quality],
			is_equal_approx(float(leaves_material.get_shader_parameter("swap_distance")), distance)
			and is_equal_approx(float(impostor_material.get_shader_parameter("near_hide")), distance))
	var info := TreeImpostor.info_for(ATLAS)
	_check("o atlas novo é do pine.glb", String(info.get("source", "")) == "pine.glb")
	trees.queue_free()
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
