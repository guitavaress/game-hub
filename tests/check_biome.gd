extends SceneTree
## Teste do bioma no chão (Fase 15.6): com 200 jogos falsos, só o bairro com
## bioma (o RPG, com a montanha) muda. Ele fica com a fatia no norte, arcos no
## lugar dos prédios, neve nos quarteirões e nas ruas (setor coberto com a
## marca "snow"), e as faixas e poças da cidade pulam as zonas dele.
var failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 200, false, true)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(0.5).timeout

	var biome_ids: Array[String] = []
	for district in Profiles.districts():
		if district.biome != null:
			biome_ids.append(district.id)
	print("bairros com bioma: ", biome_ids)
	_check("só o RPG tem bioma", biome_ids.size() == 1 and biome_ids[0] == "rpg")

	print("\n== cascas ==")
	var arches := 0
	var wrong_shell := 0
	for child: Node in city.get_children():
		if not String(child.name).begins_with("Building_"):
			continue
		var is_arch: bool = child.get_script().resource_path.ends_with("arch_shell.gd")
		if child.category_id == "rpg":
			arches += 1
		if is_arch != (child.category_id == "rpg"):
			wrong_shell += 1
	print("   arcos no RPG: ", arches)
	_check("o RPG tem arcos e os outros bairros continuam com prédios", arches > 0 and wrong_shell == 0)

	print("\n== a fatia no norte ==")
	var cells: Array = city._district_cells["rpg"]
	var middle := Vector2.ZERO
	for cell: Vector2i in cells:
		middle += Vector2(cell)
	middle /= float(cells.size())
	print("   meio dos quarteirões do RPG: ", middle)
	_check("o RPG fica ao norte da praça (z < 0)", middle.y < 0.0 and absf(middle.x) <= absf(middle.y))

	print("\n== setor coberto ==")
	var cover: StaticBody3D = city.get_node_or_null("BiomeCover_rpg")
	_check("o RPG tem o setor coberto", cover != null)
	_check("o setor coberto tem a marca \"snow\"", cover != null and cover.get_meta("footstep", "") == "snow")
	var others := 0
	for child: Node in city.get_children():
		if String(child.name).begins_with("BiomeCover_") and child != cover:
			others += 1
	_check("nenhum outro bairro tem setor coberto", others == 0)
	var half: float = (city.get_node("CityMap").get_map_data()["bounds"] as Rect2).size.x / 2.0
	var rects := BiomeBuilder.covered_rects(city.get_node("CityMap").zone_rects("rpg"), half, true)
	var shapes := 0
	if cover != null:
		for child: Node in cover.get_children():
			if child is CollisionShape3D:
				shapes += 1
	_check("uma colisão por zona do RPG (%d)" % rects.size(), shapes == rects.size() and not rects.is_empty())
	var reaches_wall := false
	for rect in rects:
		reaches_wall = reaches_wall or is_equal_approx(rect.position.y, -half)
	_check("a neve da borda vai até a mureta do norte", reaches_wall)

	print("\n== neve debaixo do jogador ==")
	var player = city.get_node("Player")
	# Na rua, no canto de uma zona do RPG (o cruzamento fica livre de postes).
	var zone: Rect2 = city.get_node("CityMap").zone_rects("rpg")[0]
	var spot := zone.position + Vector2(1.5, 1.5)
	player.global_position = Vector3(spot.x, 0.5, spot.y)
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	print("   superfície em ", spot, ": ", player.get_surface())
	_check("na rua do RPG a superfície é \"snow\"", player.get_surface() == "snow")
	player.global_position = Vector3(0.0, 0.5, 40.0)
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	_check("ao sul da praça (fora do RPG) continua \"concrete\"", player.get_surface() == "concrete")

	print("\n== faixas e poças ==")
	var dashes_in := 0
	var markings: MultiMeshInstance3D = city.get_node("LaneMarkings")
	for i in markings.multimesh.instance_count:
		var origin := markings.multimesh.get_instance_transform(i).origin
		if _inside(Vector2(origin.x, origin.z), rects):
			dashes_in += 1
	var puddles_in := 0
	var puddles := 0
	for child: Node in city.get_children():
		if child is Decal:
			puddles += 1
			if _inside(Vector2(child.position.x, child.position.z), rects):
				puddles_in += 1
	print("   faixas: %d (na neve: %d); poças: %d (na neve: %d)" % [markings.multimesh.instance_count, dashes_in, puddles, puddles_in])
	_check("nenhuma faixa na zona do bioma", dashes_in == 0 and markings.multimesh.instance_count > 0)
	_check("nenhuma poça na zona do bioma", puddles_in == 0 and puddles > 0)

	print("\n== clima ==")
	_check("o clima do RPG é neve", city.get_node_or_null("DistrictWeather_rpg") != null
			and city.get_node("DistrictWeather_rpg").spec.kind == "neve")

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


static func _inside(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if rect.has_point(point):
			return true
	return false


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
