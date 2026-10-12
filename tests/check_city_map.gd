extends SceneTree
## Teste da planta da cidade como dado (Fase 8.2), com a biblioteca de verdade
## e com 200 jogos falsos:
##   - o CityMap está no grupo "world_map";
##   - cada quarteirão pertence a um bairro só, sem sobrepor ninguém;
##   - os limites batem com o tamanho do mapa;
##   - area_name_at acerta a porta de cada jogo;
##   - a faixa de luz conta o destino e avisa quando muda (route_changed).

var failures := 0
var _route_signals := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("== biblioteca de verdade ==")
	var city: Node = await _new_city()
	await _check_map(city, true)
	city.queue_free()
	await process_frame

	print("== 200 jogos falsos ==")
	var library_script: GDScript = load("res://tests/fake_library.gd")
	library_script.install(root, 200)
	city = await _new_city()
	await _check_map(city, false)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check_map(city: Node, with_route: bool) -> void:
	var maps := get_nodes_in_group("world_map")
	_check("um CityMap no grupo world_map", maps.size() == 1)
	var map = maps[0]
	var data: Dictionary = map.get_map_data()
	var areas: Array = data["areas"]
	var games: Array = root.get_node("SteamLibrary").get_installed_games()

	var all_rects: Array[Rect2] = [data["plaza"]]
	var blocks := 0
	var total_games := 0
	for area: Dictionary in areas:
		for rect: Rect2 in area["rects"]:
			all_rects.append(rect)
			blocks += 1
		total_games += int(area["games"])
	var overlaps := 0
	for i in all_rects.size():
		for j in range(i + 1, all_rects.size()):
			if all_rects[i].intersects(all_rects[j]):
				overlaps += 1
	_check("%d bairros, %d quarteirões, sem sobreposição (%d)" % [areas.size(), blocks, overlaps], overlaps == 0 and blocks > 0)
	_check("a soma dos jogos dos bairros = a biblioteca (%d)" % games.size(), total_games == games.size())

	var order: Array = root.get_node("GameCategories").get_category_ids()
	var in_world_order := true
	var last := -1
	for area: Dictionary in areas:
		var at: int = order.find(area["id"])
		in_world_order = in_world_order and at > last
		last = at
	_check("bairros na ordem do mundo", in_world_order)

	var bounds: Rect2 = data["bounds"]
	var inside := true
	for rect in all_rects:
		inside = inside and bounds.encloses(rect.grow(-0.01))
	_check("os limites cobrem tudo (%d m de lado)" % int(bounds.size.x), inside and is_equal_approx(bounds.size.x, bounds.size.y) and bounds.size.x > 0.0)
	_check("praça no meio do mapa", (data["plaza"] as Rect2).has_point(Vector2.ZERO) and map.area_name_at(Vector3.ZERO) == "Praça")
	_check("fora do mapa não há bairro", map.area_name_at(Vector3(bounds.end.x + 50.0, 0.0, 0.0)).is_empty())

	var wrong := 0
	for game in games:
		var portal: Node3D = city.get_node("Building_%d/GamePortal" % game.app_id)
		var expected: String = root.get_node("GameCategories").get_category_name(root.get_node("GameCategories").get_category_id(game.app_id))
		if map.area_name_at(portal.global_position) != expected:
			wrong += 1
	_check("area_name_at acerta a porta de cada jogo (erros: %d)" % wrong, wrong == 0)

	var gates_ok := true
	for area: Dictionary in areas:
		var gate: Vector2 = area["gate"]
		gates_ok = gates_ok and gate != Vector2.INF and bounds.has_point(gate)
	_check("todo bairro tem o pórtico no mapa", gates_ok)

	var guide: Node = city.get_node("RouteGuide")
	var player: Node3D = city.get_node("Player")
	var portal = get_nodes_in_group("game_portal").filter(func(n: Node) -> bool: return n.app_id > 0)[0]
	_route_signals = 0
	guide.route_changed.connect(func() -> void: _route_signals += 1)
	guide.show_route(player, portal)
	_check("faixa acesa: destino = a porta escolhida", guide.has_route() and guide.get_target_position().is_equal_approx(portal.global_position))
	_check("route_changed avisou ao acender", _route_signals >= 1)
	var before := _route_signals
	guide.clear_route()
	_check("route_changed avisou ao apagar", _route_signals > before and not guide.has_route())


func _new_city() -> Node:
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	for i in 5:
		await process_frame
	return city


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
