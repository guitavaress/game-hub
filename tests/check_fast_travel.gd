extends SceneTree
## Teste da viagem rápida pela busca (Fase 8.3):
##   - Shift+Enter leva o jogador à frente da porta, virado para ela;
##   - a tela escurece e volta a clarear;
##   - o jogo NÃO abre (GameLauncher falso);
##   - durante a viagem a busca e o menu não abrem;
##   - com um jogo abrindo/rodando, não viaja;
##   - Enter (sem Shift) continua só acendendo a faixa de luz.

const BALATRO := 2379780

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout  # a tela termina de clarear
	var launcher = root.get_node("GameLauncher")
	var fade = root.get_node("ScreenFade")
	var opened: Array = []
	launcher._poll_timer.paused = true
	launcher.state_reader = func(_id: int, _check: bool) -> Dictionary:
		return {"running_app_id": 0, "steam_running": true, "app_running": false, "app_updating": false}
	launcher.url_opener = func(url: String) -> int:
		opened.append(url)
		return OK
	var player = city.get_node("Player")
	var search = player.get_game_search()
	var menu = player.get_pause_menu()
	var guide = city.get_node("RouteGuide")
	var portal = city.get_node("Building_%d/GamePortal" % BALATRO)
	var door_dir: Vector3 = -portal.global_basis.z

	print("== Shift+Enter viaja ==")
	var start_distance: float = player.global_position.distance_to(portal.global_position)
	search.open()
	search.set_query("balatro")
	search.travel_to_selected()
	_check("a busca fechou", not search.is_open() and not paused)
	await create_timer(0.2).timeout
	_check("viajando: jogador travado", player.is_traveling())
	_check("a tela está escurecendo", fade.get_amount() > 0.3)
	_check("durante a viagem a busca não abre", not search.can_open())
	_check("durante a viagem o menu não abre", not menu.can_open())
	await create_timer(1.3).timeout
	_check("a viagem terminou", not player.is_traveling())
	_check("a tela voltou a clarear", fade.get_amount() < 0.05)
	var distance: float = Vector2(player.global_position.x - portal.global_position.x, player.global_position.z - portal.global_position.z).length()
	print("   distância antes: %.0f m, depois: %.1f m" % [start_distance, distance])
	_check("chegou na frente da porta (de 2 a 5 m)", distance > 2.0 and distance < 5.0)
	var forward: Vector3 = -player.global_basis.z
	_check("virado para a porta", forward.dot(door_dir) > 0.98)
	_check("o jogo NÃO abriu", opened.is_empty() and not launcher.is_busy())
	_check("a busca volta a abrir", search.can_open())

	print("== Enter só acende a faixa ==")
	search.open()
	search.set_query("balatro")
	search.choose_selected()
	await process_frame
	_check("faixa acesa", guide.has_route() or Vector2(player.global_position.x - portal.global_position.x, player.global_position.z - portal.global_position.z).length() < 3.0)
	_check("sem viagem", not player.is_traveling())
	guide.clear_route()

	print("== com jogo abrindo, não viaja ==")
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 8)))
	launcher.state = launcher.State.LAUNCHING
	search.open()
	search.set_query("balatro")
	search.travel_to_selected()
	await create_timer(0.5).timeout
	_check("ficou onde estava", player.global_position.distance_to(Vector3(0, 0.1, 8)) < 0.5 and not player.is_traveling())
	launcher.state = launcher.State.IDLE

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
