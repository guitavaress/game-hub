extends SceneTree
## Resumo sem dados pessoais e formulário navegável, sem gravar configuração.

var failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	var config: Node = root.get_node("AppConfig")
	var library: Node = root.get_node("SteamLibrary")
	var saved_config: ConfigFile = config._config
	var saved_games: Array[SteamGame] = library._games
	var saved_loaded: bool = library._games_loaded
	# Só troca a configuração na memória; nenhum setter que salva é chamado.
	var fake := ConfigFile.new()
	var key := "FAKE_PRIVATE_KEY_FOR_FEEDBACK_TEST"
	var steam_id := "76561190000000001"
	fake.set_value("steam", "web_api_key", key)
	fake.set_value("steam", "steam_id", steam_id)
	fake.set_value("video", "quality", "alta")
	config._config = fake
	var game := SteamGame.new()
	game.app_id = 999999
	game.name = "Jogo Privado Inventado"
	game.library_path = "C:/Users/PessoaPrivada/Steam"
	var games: Array[SteamGame] = [game]
	for i in 199:
		var extra := SteamGame.new()
		extra.app_id = 999000000 + i
		extra.name = "Jogo Inventado %d" % i
		games.append(extra)
	games[1].name = "Portal"
	games[2].name = "Inside"
	library._games = games
	library._games_loaded = true
	var report_script: GDScript = load("res://autoload/feedback_report.gd")
	var report: String = report_script.build({"impressao": "Gostei", "dificuldades": "Nada", "voltaria": "Sim",
		"ignorado": key + steam_id + game.name + game.library_path})
	_check("respostas esperadas aparecem", report.contains("Gostei") and report.contains("Nada") and report.contains("Voltaria a abrir? Sim"))
	var technical := report.get_slice("\n\n", 0)
	for private_value: String in [key, steam_id, game.library_path, "PessoaPrivada"]:
		_check("resumo técnico exclui dado privado configurado", not technical.contains(private_value))
	var no_game_names: bool = true
	for installed: SteamGame in games:
		no_game_names = no_game_names and not technical.contains(installed.name)
	_check("resumo técnico não contém títulos com biblioteca cheia", no_game_names)
	_check("resumo só conta biblioteca e presença da chave", technical.contains("Jogos: 200") and technical.contains("Bairros: 1") and technical.contains("Chave configurada: sim"))
	for field: String in ["Versão:", "Sistema:", "Placa de vídeo:", "Qualidade:", "FPS agora:"]:
		_check("campo técnico presente: " + field, report.contains(field))
	if DisplayServer.get_name() == "headless":
		_check("sem renderização o FPS fica indisponível", technical.contains("FPS agora: indisponível"))
	var common_words := "O portal da casa ficou bom. Inside também é um jogo."
	_check("palavras iguais a títulos permanecem intactas nas respostas", report_script.build({"impressao": common_words}).contains(common_words))
	var pasted: String = report_script.build({"dificuldades": "%s %s %s\n%s" % [key, steam_id, game.name, game.library_path]})
	_check("identificadores e caminhos colados são removidos", not pasted.contains(key) and not pasted.contains(steam_id) and not pasted.contains("PessoaPrivada"))
	_check("nome de jogo digitado permanece na resposta", pasted.contains(game.name))
	var patterns: String = report_script.build({"impressao": "0123456789abcdef0123456789abcdef 76561190000000002"})
	_check("padrões de chave e SteamID também são removidos", not patterns.contains("0123456789abcdef0123456789abcdef") and not patterns.contains("76561190000000002"))
	fake.set_value("steam", "web_api_key", "")
	_check("sem chave aparece não", report_script.build({}).contains("Chave configurada: não"))
	config._config = saved_config
	library._games = saved_games
	library._games_loaded = saved_loaded

	var view: Control = load("res://ui/feedback_view.gd").new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	view.open()
	await process_frame
	var initial_technical: String = view._preview.text.get_slice("\n\n", 0)
	_check("abre com foco na primeira resposta", root.gui_get_focus_owner() == view._impression)
	for i in view._focus_chain.size():
		_check("Tab percorre controle %d" % i, root.gui_get_focus_owner() == view._focus_chain[i])
		await _key(KEY_TAB)
	_check("Tab completa o ciclo", root.gui_get_focus_owner() == view._impression)
	await _action("ui_down")
	_check("controle sai da primeira resposta", root.gui_get_focus_owner() == view._difficulties)
	# D-pad segue os mesmos vizinhos que as setas do teclado.
	view._choices[0].grab_focus()
	await _action("ui_down")
	_check("controle chega à próxima opção", root.gui_get_focus_owner() == view._choices[1])
	await _action("ui_down")
	await _action("ui_accept")
	_check("controle escolhe Não e atualiza a prévia", view._preview.text.contains("Voltaria a abrir? Não"))
	view._impression.text = "Muito bom"
	view._impression.text_changed.emit(view._impression.text)
	_check("prévia inclui resposta antes da cópia", view._preview.text.contains("Muito bom"))
	_check("dados técnicos capturados ao abrir permanecem estáveis", view._preview.text.get_slice("\n\n", 0) == initial_technical)
	var closed: Array[bool] = [false]
	view.closed.connect(func() -> void: closed[0] = true)
	await _action("ui_cancel")
	_check("B fecha e emite closed", not view.visible and closed[0] and root.gui_get_focus_owner() == null)
	view.queue_free()
	await process_frame
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
	await process_frame
	await process_frame


func _action(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)
	await process_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
