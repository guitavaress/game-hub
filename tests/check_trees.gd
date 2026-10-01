extends SceneTree
## Teste das árvores impostoras (P2.22).

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

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
