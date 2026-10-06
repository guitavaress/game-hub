extends SceneTree
## Teste do metrô (Fase 8.6), com a biblioteca de verdade e com 200 jogos falsos:
##   - uma estação por bairro, mais a "Central" na praça;
##   - pisar na entrada abre o painel de linhas, com as OUTRAS estações na
##     ordem do mundo;
##   - escolher leva até a saída da estação certa (tela escura e som do trem);
##   - chegar não reabre o painel; sair e voltar reabre; Esc fecha;
##   - com um jogo abrindo, o painel não abre;
##   - com 200 jogos, toda porta fica a no máximo 180 m (pelas ruas) de uma
##     estação do seu bairro;
##   - as estações aparecem no mapa (marcos do world_map).

const MAX_WALK := 180.0

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("== biblioteca de verdade ==")
	var city: Node = await _new_city()
	await _check_ride(city)
	_check_reach(city)
	city.queue_free()
	await process_frame

	print("== 200 jogos falsos ==")
	var library_script: GDScript = load("res://tests/fake_library.gd")
	library_script.install(root, 200)
	city = await _new_city()
	_check_reach(city)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check_ride(city: Node) -> void:
	var player = city.get_node("Player")
	var panel = player.get_transit_panel()
	var launcher = root.get_node("GameLauncher")
	var fade = root.get_node("ScreenFade")
	var stops := _stops()
	var district_ids: Array = []
	for area: Dictionary in get_first_node_in_group("world_map").get_map_data()["areas"]:
		district_ids.append(area["id"])
	_check("%d estações: Central + %d bairros" % [stops.size(), district_ids.size()],
			stops.size() >= district_ids.size() + 1 and stops[0].stop_name == "Central")

	print("== pisar na Central abre o painel ==")
	var central = stops[0]
	await _walk_into(player, central)
	_check("o painel abriu e pausou", panel.is_open() and paused)
	var expected: PackedStringArray = []
	for stop in stops.slice(1):
		expected.append(stop.stop_name)
	_check("lista = as outras estações, na ordem %s" % str(panel.get_stop_names()), panel.get_stop_names() == expected)
	_check("com o painel aberto, a busca e o mapa não abrem",
			not player.get_game_search().can_open() and not player.get_world_map().can_open())

	await _press("release_mouse")
	_check("Esc fechou sem abrir o menu de pausa", not panel.is_open() and not player.get_pause_menu().is_open() and not paused)
	await _frames(5)
	_check("parado na entrada, não reabre", not panel.is_open())
	player.global_position = central.get_exit_transform().origin + Vector3(0, 0.1, 0)
	await _frames(5)
	await _walk_into(player, central)
	_check("saiu e voltou: reabre", panel.is_open())

	print("== viajar ==")
	var target = stops[1]
	panel.choose(0)
	_check("escolher fecha o painel e começa a viagem", not panel.is_open() and player.is_traveling())
	_check("toca o som do trem", panel._ride.playing)
	await create_timer(0.6).timeout
	_check("a tela está escura, com o nome da linha", fade.get_amount() > 0.9 and fade._message.text.contains(target.stop_name))
	await create_timer(2.6).timeout
	_check("a viagem terminou e a tela clareou", not player.is_traveling() and fade.get_amount() < 0.05)
	var exit: Transform3D = target.get_exit_transform()
	var arrived: float = Vector2(player.global_position.x - exit.origin.x, player.global_position.z - exit.origin.z).length()
	_check("chegou na saída de \"%s\" (a %.2f m)" % [target.stop_name, arrived], arrived < 0.3)
	_check("virado para fora da estação", (-player.global_basis.z).dot(target.global_basis.z) > 0.98)
	await _frames(10)
	_check("chegar não abre o painel", not panel.is_open())

	print("== com jogo abrindo, não abre ==")
	launcher.state = launcher.State.LAUNCHING
	player.global_position = target.get_exit_transform().origin + Vector3(0, 0.1, 0)
	await _frames(3)
	await _walk_into(player, target)
	_check("painel fechado", not panel.is_open())
	launcher.state = launcher.State.IDLE
	player.global_position = target.get_exit_transform().origin + Vector3(0, 0.1, 0)
	await _frames(3)


## Toda porta perto de uma estação do seu bairro; estações no mapa.
func _check_reach(city: Node) -> void:
	var stops := _stops()
	var categories := root.get_node("GameCategories")
	var by_color: Dictionary = {}
	for stop in stops.slice(1):
		if not by_color.has(stop.color):
			by_color[stop.color] = []
		by_color[stop.color].append(stop)
	var worst := 0.0
	var far := 0
	for node in get_nodes_in_group("game_portal"):
		if node.app_id <= 0:
			continue
		var neon: Color = categories.get_neon_color(categories.get_category_id(node.app_id))
		var best := INF
		for stop in by_color.get(neon, []):
			best = minf(best, _walk(stop.get_exit_transform().origin, node))
		worst = maxf(worst, best)
		if best > MAX_WALK:
			far += 1
	print("   %d estações; a porta mais longe fica a %.0f m da estação do bairro" % [stops.size(), worst])
	_check("toda porta a no máximo %d m de uma estação do bairro (longe: %d)" % [MAX_WALK, far], far == 0)
	var landmarks: Array = get_first_node_in_group("world_map").get_map_data()["landmarks"]
	_check("cada estação é um marco no mapa", landmarks.size() == stops.size())
	var blocked := 0
	for stop in stops:
		var space: PhysicsDirectSpaceState3D = stop.get_world_3d().direct_space_state
		var query := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 1.6, 0.6)
		query.shape = box
		query.transform = Transform3D(Basis.IDENTITY, stop.get_exit_transform().origin + Vector3(0, 1.0, 0))
		query.collision_mask = 1
		if not space.intersect_shape(query, 1).is_empty():
			blocked += 1
	_check("a saída de toda estação está livre (bloqueadas: %d)" % blocked, blocked == 0)


func _walk(from: Vector3, portal) -> float:
	var points: PackedVector3Array = load("res://worlds/city/city_route_guide.gd").route_points(from, portal)
	var length := 0.0
	for k in points.size() - 1:
		length += points[k].distance_to(points[k + 1])
	return length


func _stops() -> Array:
	var stops: Array = get_nodes_in_group("transit_stop")
	stops.sort_custom(func(a, b) -> bool: return a.order < b.order)
	return stops


## Leva o jogador para o meio da entrada e espera a física perceber.
func _walk_into(player, stop) -> void:
	player.global_position = stop.get_entry_position()
	await _frames(4)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _new_city() -> Node:
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	return city


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
