extends SceneTree
## Teste do começo em casa (Fase 9.3), forçando a abertura mesmo sem janela:
##   - o jogador nasce dentro de casa, com a tela "GAME HUB" por um instante;
##   - logo depois anda pela casa, com a tela clara, enquanto a cidade monta;
##   - a porta da rua fica trancada mostrando "Montando a cidade… N%";
##   - a busca e o mapa não abrem enquanto a cidade monta (o menu Esc abre);
##   - quando a cidade fica pronta, a porta destranca;
##   - imprime o pior quadro durante a montagem, com a biblioteca de verdade
##     e com 200 jogos falsos (tests/fake_library.gd).

const FAKE_COUNT := 200

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("\n===== biblioteca de verdade =====")
	await _start_city()
	print("\n===== %d jogos falsos =====" % FAKE_COUNT)
	var library_script: GDScript = load("res://tests/fake_library.gd")
	library_script.install(root, FAKE_COUNT)
	await _start_city()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Monta a cidade com a abertura ligada, confere tudo e mede os quadros.
func _start_city() -> void:
	var fade = root.get_node("ScreenFade")
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = true
	var started_us := Time.get_ticks_usec()
	var ready_at := [-1]
	city.city_ready.connect(func() -> void: ready_at[0] = Time.get_ticks_usec())
	root.add_child(city)
	await process_frame
	await process_frame

	var player = city.get_node("Player")
	var home = city.get_home()
	var door = home.get_front_door()
	print("== começo: dentro de casa, com a tela GAME HUB ==")
	_check("nasceu no ponto de nascer da casa",
			player.global_position.distance_to(home.get_spawn_transform().origin) < 0.5)
	_check("está em casa (ambiente da casa)", player.is_indoors())
	_check("tela GAME HUB visível, parado e sem HUD",
			fade.is_splash_visible() and player.in_intro and not player.get_hud().visible)
	_check("a porta da rua está trancada, com o progresso",
			not door.is_open() and door.locked_reason.begins_with("Montando a cidade"))
	_check("a cidade ainda não está pronta", not city.is_city_ready())

	# Acompanha a montagem quadro a quadro: pior quadro e o que a porta diz.
	var worst_us := 0
	var frames := 0
	var last_us := Time.get_ticks_usec()
	var saw_percent := false
	var checked_free := false
	while ready_at[0] == -1 and Time.get_ticks_usec() - started_us < 60_000_000:
		await process_frame
		var now := Time.get_ticks_usec()
		worst_us = maxi(worst_us, now - last_us)
		last_us = now
		frames += 1
		if door.locked_reason.contains("%"):
			saw_percent = true
		if not checked_free and not player.in_intro and ready_at[0] == -1:
			checked_free = true
			print("== a tela sumiu e a cidade ainda monta ==")
			await create_timer(0.5).timeout  # a tela GAME HUB termina de sumir
			_check("tela clara, HUD de volta, jogador anda",
					not fade.is_splash_visible() and fade.get_amount() < 0.01
					and player.get_hud().visible and player.is_physics_processing())
			if ready_at[0] == -1:
				_check("a busca não abre com a cidade montando", not player.get_game_search().can_open())
				_check("o mapa não abre com a cidade montando", not player.get_world_map().can_open())
				_check("o menu de pausa abre", player.get_pause_menu().can_open())
				_check("a porta continua trancada", not door.is_open())
			else:
				print("   (a cidade ficou pronta antes da tela sumir: sem conferir a montagem)")
			last_us = Time.get_ticks_usec()

	var seconds: float = (ready_at[0] - started_us) / 1_000_000.0
	print("   cidade pronta em %.2f s, %d quadros, pior quadro %.1f ms" % [seconds, frames, worst_us / 1000.0])
	_check("a cidade ficou pronta", city.is_city_ready())
	_check("a porta mostrou a porcentagem", saw_percent)
	_check("a porta destrancou", door.is_open() and door.locked_reason.is_empty())
	_check("busca liberada", not player.world_loading)
	_check("o jogador continua em casa", player.is_indoors())
	await create_timer(1.0).timeout  # a tela GAME HUB some aos ~1,2 s
	_check("tela GAME HUB sumiu", not fade.is_splash_visible())
	_check("busca abre com a cidade pronta", player.get_game_search().can_open())
	_check("prédio do Balatro existe (se instalado)", city.has_node("Building_2379780")
			or root.get_node("SteamLibrary").get_game(2379780) == null)
	print("   avisos do começo: ", player.get_hud().get_messages())
	city.queue_free()
	await process_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
