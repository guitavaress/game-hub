extends SceneTree
## Teste da planta da cidade como dado (Fase 8.2), com a biblioteca de verdade
## e com 200 jogos falsos:
##   - o CityMap está no grupo "world_map";
##   - cada quarteirão pertence a um bairro só, sem sobrepor ninguém;
##   - os limites batem com o tamanho do mapa;
##   - area_name_at acerta a porta de cada jogo;
##   - (15.4) as zonas cobrem a cidade; cada bairro é contíguo e chega à borda;
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
	_check_zones(city, map, areas, bounds, games)

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


## Fase 15.4, setores: as zonas (quarteirões e vagas) cobrem a cidade inteira
## sem sobra; cada bairro é uma área contígua, com borda e com o pórtico no
## anel mais perto da praça.
func _check_zones(city: Node, map: Node, areas: Array, bounds: Rect2, games: Array) -> void:
	var owner: Dictionary[Vector2i, String] = {}
	var repeated := 0
	var rects_in_zones := true
	for area: Dictionary in areas:
		for rect: Rect2 in area["zones"]:
			# A montanha (15.9) também é zona, mas fica fora da mureta: aqui só a cidade.
			if not bounds.encloses(rect):
				continue
			var cell := _cell_of(rect.get_center())
			if owner.has(cell):
				repeated += 1
			owner[cell] = area["id"]
		for rect: Rect2 in area["rects"]:
			rects_in_zones = rects_in_zones and (area["zones"] as Array).has(rect)
	var ring := 0
	for cell: Vector2i in owner:
		ring = maxi(ring, CityLayout.ring_of(cell))
	var expected_cells := 4 * ring * ring + 4 * ring
	_check("as zonas cobrem os anéis 1..%d sem sobra (%d de %d, repetidas: %d)" % [ring, owner.size(), expected_cells, repeated],
			repeated == 0 and owner.size() == expected_cells and not owner.has(Vector2i.ZERO))
	_check("todo quarteirão é zona do seu bairro", rects_in_zones)
	var half: float = bounds.size.x / 2.0
	_check("o mapa vai até a borda das zonas", is_equal_approx(half, ring * CityLayout.BLOCK_PITCH + CityLayout.BLOCK_SIZE / 2.0 + CityLayout.STREET_WIDTH))

	var contiguous := true
	var with_border := true
	var gate_inside := true
	for area: Dictionary in areas:
		var id: String = area["id"]
		var cells: Array[Vector2i] = []
		for rect: Rect2 in area["zones"]:
			if bounds.encloses(rect):
				cells.append(_cell_of(rect.get_center()))
		contiguous = contiguous and _is_connected(cells)
		with_border = with_border and cells.any(func(c: Vector2i) -> bool: return CityLayout.ring_of(c) == ring)
		var gate_ring := CityLayout.ring_of(city._district_cells[id][0])
		for cell in cells:
			gate_inside = gate_inside and CityLayout.ring_of(cell) >= gate_ring
	_check("cada bairro é uma área contígua", contiguous)
	_check("cada bairro chega à borda da cidade", with_border)
	_check("o pórtico fica no anel do bairro mais perto da praça", gate_inside)

	var wrong := 0
	for game in games:
		var portal: Node3D = city.get_node("Building_%d/GamePortal" % game.app_id)
		if map.zone_id_at(portal.global_position) != root.get_node("GameCategories").get_category_id(game.app_id):
			wrong += 1
	_check("zone_id_at acerta a porta de cada jogo (erros: %d)" % wrong, wrong == 0)
	_check("na praça não há zona", map.zone_id_at(Vector3.ZERO).is_empty())


## Todas as células ligadas por lado ou canto (8 vizinhos)?
func _is_connected(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var seen: Dictionary[Vector2i, bool] = {cells[0]: true}
	var queue: Array[Vector2i] = [cells[0]]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var next := cell + Vector2i(dx, dz)
				if cells.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
	return seen.size() == cells.size()


static func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x / CityLayout.BLOCK_PITCH), roundi(point.y / CityLayout.BLOCK_PITCH))


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
