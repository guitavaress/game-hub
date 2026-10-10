extends SceneTree
## Teste da busca, do mapa e da volta dentro de casa (Fase 9.8):
##   - na busca em casa, Enter vira "ir até a porta" (sem faixa de luz) e a dica muda;
##   - na rua a busca continua igual (Enter acende a faixa);
##   - o mapa abre com "Você está em casa" no lugar da seta;
##   - um jogo aberto por fora que fecha não tira o jogador de casa (e na rua, ainda puxa).

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
	await create_timer(1.0).timeout
	var launcher = root.get_node("GameLauncher")
	launcher._poll_timer.paused = true
	var player = city.get_node("Player")
	var search = player.get_game_search()
	var world_map = player.get_world_map()
	var guide = city.get_node("RouteGuide")
	var home = city.get_home()
	var portal = city.get_node("Building_%d/GamePortal" % BALATRO)

	print("== Na rua: a busca é a de sempre ==")
	search.open()
	_check("a dica do Enter é 'acender o caminho'", search._enter_hint.text == "acender o caminho")
	search.set_query("balatro")
	search.choose_selected()
	await process_frame
	_check("Enter acende a faixa de luz", not search.is_open() and guide.has_route())
	guide.clear_route()
	world_map.open()
	await _frames(3)
	_check("o mapa mostra a seta (não 'em casa')", not world_map.get_view().is_indoors())
	world_map.close()

	print("== Em casa: Enter vai até a porta ==")
	player.teleport_to(home.get_spawn_transform())
	player.set_indoors(home.get_environment())
	await _frames(2)
	search.open()
	_check("a dica do Enter muda para 'ir até a porta'", search._enter_hint.text == "ir até a porta")
	search.set_query("balatro")
	search.choose_selected()
	await create_timer(0.2).timeout
	_check("a busca fechou e o jogador está viajando", not search.is_open() and player.is_traveling())
	await create_timer(1.4).timeout
	var arrival: Transform3D = portal.get_arrival_transform()
	_check("chegou na frente da porta do jogo", player.global_position.distance_to(arrival.origin) < 0.5)
	_check("não acendeu faixa de luz", not guide.has_route())
	_check("saiu de casa", not player.is_indoors())

	print("== O mapa em casa ==")
	player.teleport_to(home.get_spawn_transform())
	player.set_indoors(home.get_environment())
	await _frames(2)
	world_map.open()
	await _frames(3)
	_check("o mapa diz que está em casa", world_map.get_view().is_indoors())
	world_map.close()

	print("== Jogo aberto por fora fecha ==")
	var home_spot: Vector3 = player.global_position
	launcher.session_ended.emit(BALATRO, null, true, "")
	await _frames(3)
	_check("em casa, o jogador continua onde estava", player.is_indoors() and player.global_position.distance_to(home_spot) < 0.1)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(30.0, 0.1, 30.0)))
	player.set_indoors(null)
	await _frames(2)
	launcher.session_ended.emit(BALATRO, null, true, "")
	await _frames(3)
	_check("na rua, ainda é puxado para a porta do jogo",
			player.global_position.distance_to(portal.get_return_transform().origin) < 0.5)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
