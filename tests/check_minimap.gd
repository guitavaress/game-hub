extends SceneTree
## Teste do minimapa e do mapa grande (Fase 8.5), com a biblioteca de verdade
## e com 200 jogos falsos:
##   - o minimapa segue o jogador, mostra o bairro onde ele está e o destino;
##   - M abre o mapa grande e pausa; M ou Esc fecham;
##   - o mapa não abre com a busca aberta, e a busca não abre com o mapa aberto;
##   - tudo da planta cabe no mapa grande;
##   - a opção "Bússola e mapa" esconde o minimapa.

const BALATRO := 2379780

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var config := root.get_node("AppConfig")
	var original_show: bool = config.get_show_map()
	config.set_show_map(true)

	print("== biblioteca de verdade ==")
	var city: Node = await _new_city()
	await _check_minimap(city)
	await _check_world_map(city)
	city.queue_free()
	await process_frame

	print("== 200 jogos falsos ==")
	var library_script: GDScript = load("res://tests/fake_library.gd")
	library_script.install(root, 200)
	city = await _new_city()
	await _check_world_map(city)
	await _check_fits(city)

	config.set_show_map(original_show)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check_minimap(city: Node) -> void:
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var mini = hud.get_minimap()
	var guide = city.get_node("RouteGuide")
	var map = get_first_node_in_group("world_map")
	_check("o minimapa existe e aparece", mini != null and mini.visible)
	mini.refresh()
	_check("a seta fica no meio (segue o jogador)", mini.get_player_pixel().distance_to(mini.size / 2.0) < 1.0)
	_check("na praça: nome embaixo = \"Praça\"", mini.get_area_name() == "Praça")

	var portal = city.get_node("Building_%d/GamePortal" % BALATRO)
	player.teleport_to(Transform3D(Basis.IDENTITY, portal.get_return_transform().origin))
	mini.refresh()
	var expected: String = map.area_name_at(player.global_position)
	_check("no bairro do Balatro: nome = \"%s\"" % expected, mini.get_area_name() == expected and expected != "Praça" and not expected.is_empty())
	var before: Vector2 = mini.to_pixel(Vector2(player.global_position.x, player.global_position.z))
	_check("escala do minimapa: 1 m = %.1f px" % mini.get_scale_pixels(), is_equal_approx(mini.get_scale_pixels(), 1.4))
	_check("o ponto do jogador não se mexe na tela (o mapa é que anda)", before.distance_to(mini.size / 2.0) < 1.0)

	_check("sem faixa: sem destino no minimapa", not mini.get_target_info()["visible"])
	guide.show_route(player, portal)
	mini.refresh()
	var target: Dictionary = mini.get_target_info()
	_check("com faixa: destino = a porta", target["visible"] and target["pos"].distance_to(Vector2(portal.global_position.x, portal.global_position.z)) < 0.1)
	guide.clear_route()
	mini.refresh()
	_check("faixa apagada: destino some", not mini.get_target_info()["visible"])

	var config := root.get_node("AppConfig")
	config.set_show_map(false)
	_check("opção desligada: minimapa escondido", not mini.visible)
	config.set_show_map(true)
	_check("ligada: volta", mini.visible)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 8)))


func _check_world_map(city: Node) -> void:
	var player = city.get_node("Player")
	var world_map = player.get_world_map()
	var search = player.get_game_search()
	var menu = player.get_pause_menu()
	_check("mapa grande fechado no começo", not world_map.is_open())
	await _press("open_map")
	_check("M abriu o mapa e pausou", world_map.is_open() and paused)
	_check("com o mapa aberto, a busca não abre", not search.can_open())
	_check("com o mapa aberto, o menu não abre", not menu.can_open())
	await _press("open_map")
	_check("M fechou e despausou", not world_map.is_open() and not paused)
	await _press("open_map")
	await _press("release_mouse")
	_check("Esc fechou o mapa sem abrir o menu", not world_map.is_open() and not menu.is_open() and not paused)
	search.open()
	_check("com a busca aberta, o mapa não abre", not world_map.can_open())
	search.close()
	await process_frame


## Com o mapa grande aberto, todos os quarteirões cabem na área do controle.
func _check_fits(city: Node) -> void:
	var player = city.get_node("Player")
	var world_map = player.get_world_map()
	world_map.open()
	await process_frame
	await process_frame
	var view = world_map.get_view()
	var data: Dictionary = get_first_node_in_group("world_map").get_map_data()
	var outside := 0
	var blocks := 0
	for area: Dictionary in data["areas"]:
		for rect: Rect2 in area["rects"]:
			blocks += 1
			var corner_a: Vector2 = view.to_pixel(rect.position)
			var corner_b: Vector2 = view.to_pixel(rect.end)
			if corner_a.x < 0.0 or corner_a.y < 0.0 or corner_b.x > view.size.x or corner_b.y > view.size.y:
				outside += 1
	print("   mapa grande de %d x %d px, %d quarteirões, escala %.2f px/m" % [view.size.x, view.size.y, blocks, view.get_scale_pixels()])
	_check("todos os quarteirões cabem no mapa grande (fora: %d)" % outside, outside == 0 and view.size.x > 100.0)
	_check("o jogador aparece dentro do mapa grande", Rect2(Vector2.ZERO, view.size).has_point(view.get_player_pixel()))
	world_map.close()
	await process_frame


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
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
