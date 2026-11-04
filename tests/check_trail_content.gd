extends SceneTree
## Fase 17.7: distribuição pura e montagem real, sem cidade ou rede.

var failures: int = 0
var _script: GDScript


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	root.get_node("GameArt").allow_downloads = false
	_script = load("res://worlds/city/biome/trail_dressing.gd")
	var rows: Array[Dictionary] = [
		{"app_id": 9000003, "name": "Terceiro", "minutes": 360},
		{"app_id": 9000002, "name": "Segundo", "minutes": 60},
		{"app_id": 9000001, "name": "Primeiro", "minutes": -1},
		{"app_id": 9000004, "name": "Empate", "minutes": 60}]
	var ordered: Array = _script.ordered_games(rows)
	_check("horas crescem; desconhecidas primeiro; empate estável por ID",
			_ids(ordered) == [9000001, 9000002, 9000004, 9000003])
	_check("ordenar não muda a lista recebida", rows[0]["app_id"] == 9000003)
	for parameters: Vector3 in [Vector3(176, -49, 49), Vector3(62, -60, 60),
			Vector3(176, -8, 8), Vector3(176, 50, 130), Vector3(252, -45, 45)]:
		var field := Heightfield.new()
		field.configure(parameters.x, deg_to_rad(parameters.y), deg_to_rad(parameters.z))
		var from := Vector2(field.half, 0.0) if parameters.y > 0.0 else Vector2(0.0, -field.half)
		var trail := MountainTrail.plan(field, from, from.normalized())
		_check("trilha válida para %s" % parameters, trail.valid)
		if not trail.valid:
			continue
		field.set_trail(trail)
		_check_layout(field, trail, rows)
		if parameters.x == 62:
			await _check_nodes(field, trail, rows)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


func _check_layout(field: Heightfield, trail: MountainTrail, rows: Array[Dictionary]) -> void:
	var stops: Array = _script.stop_spots(field, trail)
	var banners: Array = _script.banner_spots(field, trail, rows)
	var kinds: Array[String] = []
	for stop: Dictionary in stops:
		kinds.append(stop["kind"])
	_check("quatro paradas: fogo, pedras, queda congelada e banco", kinds == _script.STOP_KINDS)
	_check("sem jogos, nenhum estandarte", _script.banner_spots(field, trail, [] as Array[Dictionary]).is_empty())
	_check("os quatro jogos cabem", banners.size() == 4)
	var previous_index: int = -1
	var previous_minutes: int = -2
	var in_order: bool = true
	for banner: Dictionary in banners:
		in_order = in_order and int(banner["index"]) > previous_index and int(banner["game"]["minutes"]) >= previous_minutes
		previous_index = banner["index"]
		previous_minutes = banner["game"]["minutes"]
	_check("as horas crescem conforme se sobe", in_order)
	var walls: Array = _script.wall_lines(field, trail)
	var safe: bool = true
	var avoids_walls: bool = true
	for spot: Dictionary in stops + banners:
		for p: Vector2 in _script.footprint_points(spot):
			var distance := trail.closest(p).x
			safe = safe and distance > field.trail_width / 2.0 and distance < _script.WALL_OFFSET
			for line: PackedVector3Array in walls:
				for i in range(1, line.size()):
					var a := Vector2(line[i - 1].x, line[i - 1].z)
					var b := Vector2(line[i].x, line[i].z)
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < 0.025:
						avoids_walls = false
	_check("volumes fora dos 3 m pisáveis e dentro das paredes", safe)
	_check("volumes não tocam os segmentos reais das paredes", avoids_walls)
	var many: Array[Dictionary] = []
	for i in 500:
		many.append({"app_id": 9100000 + i, "name": "Falso", "minutes": i})
	var crowded: Array = _script.banner_spots(field, trail, many)
	var spacing_ok: bool = not crowded.is_empty()
	for i in range(1, crowded.size()):
		spacing_ok = spacing_ok and int(crowded[i]["index"]) - int(crowded[i - 1]["index"]) >= _script.BANNER_SPACING
	_check("500 jogos respeitam a capacidade e guardam o mais jogado", spacing_ok
			and crowded[-1]["game"]["app_id"] == 9100499 and crowded.size() < 500)


func _check_nodes(field: Heightfield, trail: MountainTrail, rows: Array[Dictionary]) -> void:
	var dressing: Node3D = _script.new()
	root.add_child(dressing)
	dressing.setup(field, trail)
	_check("sem chamada, só cenário", _banner_nodes(dressing).is_empty())
	var fire: Node3D = dressing.get_node_or_null("TrailStop_campfire/Campfire")
	_check("fogueira existe no grupo city_night", fire != null and fire.is_in_group("city_night"))
	if fire != null:
		var light: OmniLight3D = fire.get_node("Firelight")
		call_group("city_night", "set_night", 1.0)
		_check("grupo acende fogo à noite", light.visible and light.light_energy > 0.0)
		call_group("city_night", "set_night", 0.0)
		_check("grupo apaga fogo de dia", not light.visible and not fire.get_node("Flames").visible)
		_check("fogo apaga de longe como lampiões", light.distance_fade_enabled
				and light.distance_fade_begin == _script.LAMP_FADE_BEGIN
				and light.distance_fade_length == _script.LAMP_FADE_LENGTH and not light.shadow_enabled)
	var games: Array[SteamGame] = []
	var minutes: Dictionary = {}
	for row in rows:
		var game := SteamGame.new()
		game.app_id = row["app_id"]
		game.name = row["name"]
		games.append(game)
		minutes[game.app_id] = row["minutes"]
	load("res://tests/fake_library.gd").set_playtimes(root, minutes)
	dressing.set_games(games)
	var banners := _banner_nodes(dressing)
	_check("API recebe SteamGame e ordena com as horas da biblioteca", banners.size() == 4
			and banners[0].app_id == 9000001 and banners[-1].app_id == 9000003)
	for i in games.size() + 1:
		await process_frame
	_check("pedidos de capa terminam e desligam o processamento", not dressing.is_processing())
	if not banners.is_empty():
		var cloth: MeshInstance3D = banners[0].get_node("Cloth")
		var material: StandardMaterial3D = cloth.material_override
		var normals: PackedVector3Array = cloth.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var facing_path: bool = true
		for normal in normals:
			facing_path = facing_path and normal.z > 0.0
		_check("a frente do tecido recebe a luz do caminho", facing_path)
		_check("sem capa, tecido liso", material.albedo_texture == null)
		var image := Image.create(4, 6, false, Image.FORMAT_RGB8)
		image.fill(Color.CORAL)
		var texture := ImageTexture.create_from_image(image)
		root.get_node("GameArt").art_ready.emit(9999999, texture)
		_check("capa de outro jogo não troca o tecido", material.albedo_texture == null)
		root.get_node("GameArt").art_ready.emit(banners[0].app_id, texture)
		_check("art_ready troca pela capa certa", material.albedo_texture == texture)
	# Confere as malhas construídas, além das contas: nenhuma peça extrapola a margem.
	var meshes_safe: bool = true
	for node: Node in dressing.get_children():
		if node.has_meta("trail_stop") or String(node.name).begins_with("TrailBanner_"):
			meshes_safe = _meshes_in_margin(node, trail, field.trail_width / 2.0) and meshes_safe
	_check("malhas reais também cabem fora da passagem e dentro da cerca", meshes_safe)
	dressing.set_games(games)
	_check("nova lista substitui os estandartes", _banner_nodes(dressing).size() == 4)
	dressing.set_games([])
	await process_frame
	_check("lista vazia retira capas e pedidos sem retirar cenário", _banner_nodes(dressing).is_empty()
			and is_instance_valid(fire) and not dressing.is_processing())
	dressing.queue_free()
	await process_frame


func _meshes_in_margin(node: Node, trail: MountainTrail, inner: float) -> bool:
	var safe: bool = true
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node
		var bounds := mesh.get_aabb()
		for i in 8:
			var p := mesh.global_transform * bounds.get_endpoint(i)
			var distance := trail.closest(Vector2(p.x, p.z)).x
			if distance < inner or distance > _script.WALL_OFFSET:
				print("   fora: %s (%.3f m)" % [mesh.get_path(), distance])
				safe = false
	for child in node.get_children():
		safe = _meshes_in_margin(child, trail, inner) and safe
	return safe


func _banner_nodes(dressing: Node) -> Array[Node]:
	return dressing.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("TrailBanner_"))


func _ids(rows: Array) -> Array[int]:
	var ids: Array[int] = []
	for row: Dictionary in rows:
		ids.append(int(row["app_id"]))
	return ids


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
