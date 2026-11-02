extends SceneTree
## Teste dos avisos (P1.4): título + frase, tipos, pilha de 3, uma vez por execução.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	for i in 30:
		await process_frame
	var hud = city.get_node("Player").get_hud()
	print("avisos na abertura: ", hud.get_messages())
	hud.clear_messages()
	await process_frame

	print("\n== título + frase ==")
	hud.show_report("Balatro não abriu\nAbra a Steam e entre de novo.")
	await process_frame
	await process_frame
	var toast = hud._toasts.get_child(0)
	_check("título e frase separados", toast.title == "Balatro não abriu" and toast.text == "Abra a Steam e entre de novo.")
	_check("info por padrão (6 s)", toast.kind == 0 and is_equal_approx(toast.get_meta("seconds"), 6.0))
	_check("largura 500 px", is_equal_approx(toast.size.x, 500.0) and is_equal_approx(hud._toasts.size.x, 500.0))
	_check("altura de 2 linhas (40..90 px)", toast.size.y > 40.0 and toast.size.y < 90.0)
	print("   tamanho: ", toast.size, " topo da pilha: ", hud._toasts.global_position.y)
	_check("logo abaixo da bússola (12 + 30 + 8 px do topo)", is_equal_approx(hud._toasts.global_position.y, 50.0))

	print("\n== repetido é ignorado ==")
	hud.show_report("Balatro não abriu\nAbra a Steam e entre de novo.")
	_check("continua 1", hud.get_messages().size() == 1)

	print("\n== pilha de até 3 ==")
	hud.show_message("Dois")
	hud.show_message("Três", "", 1)  # erro
	hud.show_message("Quatro", "", 2)  # sessão
	var messages: PackedStringArray = hud.get_messages()
	print("   ", messages)
	_check("3 na tela, o mais antigo saindo", messages.size() == 3 and messages[0] == "Dois" and messages[2] == "Quatro")
	var kinds := []
	for child in hud._toasts.get_children():
		kinds.append([child.title, child.kind, child.get_meta("seconds")])
	print("   tipos: ", kinds)
	_check("erro 10 s, sessão 5 s", kinds[2][2] == 10.0 and kinds[3][2] == 5.0)
	await create_timer(0.4).timeout
	_check("o mais antigo foi apagado", hud._toasts.get_child_count() == 3)

	print("\n== some sozinho ==")
	hud.clear_messages()
	hud.show_message("Rápido", "", 0, 0.3)
	await create_timer(0.8).timeout
	_check("sumiu depois do tempo", hud._toasts.get_child_count() == 0)

	print("\n== aviso de amigos: uma vez por execução ==")
	var fs = root.get_node("FriendsService")
	fs.problem.emit("Amigos: teste de aviso\nFaça alguma coisa.")
	_check("apareceu", hud.get_messages().size() == 1 and hud.get_messages()[0] == "Amigos: teste de aviso — Faça alguma coisa.")
	hud.clear_messages()
	fs.problem.emit("Amigos: teste de aviso\nFaça alguma coisa.")
	_check("não aparece de novo", hud.get_messages().is_empty())

	print("\n== erro do launcher vira aviso vermelho ==")
	var launcher = root.get_node("GameLauncher")
	launcher._app_id = 2379780
	var timeout_message: String = launcher._timeout_message({"steam_running": false})
	launcher._app_id = 0
	launcher.session_ended.emit(2379780, null, false, timeout_message)
	await process_frame
	var error_toast = hud._toasts.get_child(0)
	print("   ", hud.get_messages())
	_check("vermelho, título + frase", error_toast.kind == 1 and error_toast.title == "Balatro não abriu"
		and "Abra a Steam" in error_toast.text)

	print("\n== painel aberto: o HUD sai de baixo (16.2) ==")
	var player = city.get_node("Player")
	_check("começa com o HUD", hud.visible)
	var panels := {"busca": player.get_game_search(), "mapa": player.get_world_map(),
			"pausa": player.get_pause_menu()}
	for panel_name: String in panels:
		var panel = panels[panel_name]
		panel.open()
		_check("%s aberta: HUD escondido" % panel_name, panel.is_open() and not hud.visible)
		panel.close()
		_check("%s fechada: HUD de volta" % panel_name, not panel.is_open() and hud.visible)
	paused = false
	var stops := city.find_children("*", "TransitStop", true, false)
	_check("há estação de metrô", not stops.is_empty())
	if not stops.is_empty():
		var transit = player.get_transit_panel()
		_check("metrô aberto: HUD escondido", transit.open_for(stops[0]) and not hud.visible)
		transit.close()
		_check("metrô fechado: HUD de volta", hud.visible)
	paused = false
	print("   aviso com o mapa aberto espera a volta do HUD")
	hud.clear_messages()
	player.get_world_map().open()
	hud.show_message("Chegou com o mapa aberto")
	_check("fica na fila", hud.get_messages().is_empty())
	player.get_world_map().close()
	await process_frame
	_check("aparece ao fechar", hud.get_messages().size() == 1)
	hud.clear_messages()
	print("   a abertura continua escondendo")
	player.start_intro()
	_check("abertura: HUD escondido", not hud.visible)
	player.get_world_map().open()
	player.get_world_map().close()
	_check("abrir e fechar um painel não traz o HUD na abertura", not hud.visible)
	player.finish_intro()
	_check("fim da abertura: HUD de volta", hud.visible)
	player.get_world_map().open()
	player.start_intro()
	player.finish_intro()
	_check("fim da abertura com o mapa aberto: HUD continua escondido", not hud.visible)
	player.get_world_map().close()
	_check("fechou o mapa: HUD de volta", hud.visible)
	paused = false

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
