extends SceneTree
## Teste do controle Xbox (Fase 12.5), com eventos FALSOS de controle:
##   - as ações têm os botões e eixos do plano;
##   - o analógico esquerdo anda; a zona morta segura o analógico parado;
##   - o analógico direito gira a câmera, e a sensibilidade do controle muda o giro;
##   - A pula, o analógico apertado corre e X vira "interagir";
##   - com o menu aberto (ou sem foco no jogo), o analógico não gira a câmera.
## Guarda o config.cfg antes e devolve no fim.

const CONFIG := "user://config.cfg"

var failures := 0
var backup := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	backup = FileAccess.get_file_as_string(CONFIG)
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	root.get_node("GameLauncher")._poll_timer.paused = true
	var app = root.get_node("AppConfig")
	var player = city.get_node("Player")

	print("== As ações ==")
	var wanted := {
		"move_forward": [&"motion", 1, -1.0], "move_back": [&"motion", 1, 1.0],
		"move_left": [&"motion", 0, -1.0], "move_right": [&"motion", 0, 1.0],
		"look_left": [&"motion", 2, -1.0], "look_right": [&"motion", 2, 1.0],
		"look_up": [&"motion", 3, -1.0], "look_down": [&"motion", 3, 1.0],
		"jump": [&"button", JOY_BUTTON_A], "sprint": [&"button", JOY_BUTTON_LEFT_STICK],
		"interact": [&"button", JOY_BUTTON_X], "search_game": [&"button", JOY_BUTTON_Y],
		"open_map": [&"button", JOY_BUTTON_BACK], "release_mouse": [&"button", JOY_BUTTON_START],
		"tab_prev": [&"button", JOY_BUTTON_LEFT_SHOULDER], "tab_next": [&"button", JOY_BUTTON_RIGHT_SHOULDER],
	}
	var missing: Array[String] = []
	for action in wanted:
		if not InputMap.has_action(action) or not _has_event(action, wanted[action]):
			missing.append(action)
	_check("as 16 ações têm o botão ou eixo certo (faltando: %s)" % str(missing), missing.is_empty())
	_check("o B é ui_cancel e o A, ui_accept (e o Esc, o Enter e o Espaço continuam)",
			_has_event("ui_cancel", [&"button", JOY_BUTTON_B]) and _has_event("ui_accept", [&"button", JOY_BUTTON_A])
			and _has_key("ui_cancel", KEY_ESCAPE) and _has_key("ui_accept", KEY_ENTER) and _has_key("ui_accept", KEY_SPACE))
	_check("o direcional e o analógico esquerdo movem os menus (ui_up/down/left/right)",
			_has_event("ui_up", [&"button", JOY_BUTTON_DPAD_UP]) and _has_event("ui_down", [&"button", JOY_BUTTON_DPAD_DOWN])
			and _has_event("ui_left", [&"button", JOY_BUTTON_DPAD_LEFT]) and _has_event("ui_right", [&"button", JOY_BUTTON_DPAD_RIGHT])
			and _has_event("ui_down", [&"motion", 1, 1.0]) and _has_key("ui_down", KEY_DOWN))
	_check("o Esc continua abrindo a pausa (o teclado não mudou)", _has_key("release_mouse", KEY_ESCAPE)
			and _has_key("interact", KEY_E) and _has_key("search_game", KEY_TAB))

	print("== Andar ==")
	player.global_position = Vector3(30.0, 0.1, 30.0)
	player.rotation = Vector3.ZERO
	await _frames(10)
	var start: Vector3 = player.global_position
	_stick(1, 0.1)  # dentro da zona morta
	await _frames(20)
	_check("analógico quase parado (10%) não anda", player.global_position.distance_to(start) < 0.05)
	_stick(1, -1.0)  # para a frente
	await _frames(30)
	var moved: Vector3 = player.global_position - start
	_check("analógico esquerdo para a frente anda para a frente (%.1f m)" % moved.length(), moved.length() > 1.0 and moved.z < -0.5)
	_stick(1, 0.0)
	await _frames(20)

	print("== Pular e correr ==")
	var floor_y: float = player.global_position.y
	_button(JOY_BUTTON_A, true)
	await _frames(6)
	_check("A pula", player.global_position.y > floor_y + 0.05)
	_button(JOY_BUTTON_A, false)
	await _frames(40)
	_button(JOY_BUTTON_LEFT_STICK, true)
	await _frames(2)
	_check("apertar o analógico esquerdo vira 'correr'", Input.is_action_pressed("sprint"))
	_button(JOY_BUTTON_LEFT_STICK, false)
	_button(JOY_BUTTON_X, true)
	await _frames(2)
	_check("X vira 'interagir'", Input.is_action_pressed("interact"))
	_button(JOY_BUTTON_X, false)
	await _frames(2)

	print("== Olhar ==")
	app.set_stick_sensitivity(1.0, false)
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation.x = 0.0
	await _frames(3)
	_stick(2, 0.1)
	await _frames(20)
	_check("analógico direito quase parado (10%) não gira", absf(player.rotation.y) < 0.001)
	_stick(2, 1.0)
	await create_timer(0.3).timeout
	var turned_1: float = player.rotation.y
	_stick(2, 0.0)
	_check("analógico direito para a direita gira a visão para a direita (%.2f rad em 0,3 s)" % -turned_1,
			turned_1 < -0.5 and turned_1 > -1.5)
	player.rotation = Vector3.ZERO
	app.set_stick_sensitivity(2.0, false)
	await _frames(3)
	_stick(2, 1.0)
	await create_timer(0.3).timeout
	var turned_2: float = player.rotation.y
	_stick(2, 0.0)
	_check("com a sensibilidade em 2,0, gira o dobro (%.2f × %.2f)" % [turned_2, turned_1],
			absf(turned_2 / turned_1 - 2.0) < 0.35)
	app.set_stick_sensitivity(1.0, false)
	player.rotation = Vector3.ZERO
	var head: Node3D = player.get_node("Head")
	head.rotation.x = 0.0
	await _frames(3)
	_stick(3, -1.0)
	await create_timer(0.5).timeout
	_stick(3, 0.0)
	_check("analógico direito para cima olha para cima", head.rotation.x > 0.3)
	_stick(3, 1.0)
	await create_timer(1.5).timeout
	_stick(3, 0.0)
	_check("e o olhar para baixo tem um limite (não dá cambalhota)", head.rotation.x >= -deg_to_rad(89.5) and head.rotation.x < -0.3)
	head.rotation.x = 0.0

	print("== Travas ==")
	var menu = player.get_pause_menu()
	player.rotation = Vector3.ZERO
	menu.open()
	await _frames(3)
	_stick(2, 1.0)
	await create_timer(0.4).timeout
	_stick(2, 0.0)
	_check("com o menu aberto, o analógico não gira a câmera", absf(player.rotation.y) < 0.001)
	menu.close()
	await _frames(3)
	var angle_before: float = player.rotation.y
	player.start_intro()
	_stick(2, 1.0)
	await create_timer(0.3).timeout
	_stick(2, 0.0)
	_check("na abertura, também não gira", absf(player.rotation.y - angle_before) < 0.001)
	player.finish_intro()

	# Devolve o config.cfg como estava.
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Inclina um analógico (axis: 0/1 = esquerdo X/Y, 2/3 = direito X/Y).
func _stick(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)


## A ação tem este evento de controle? spec = [&"motion", eixo, valor] ou [&"button", botão].
func _has_event(action: String, spec: Array) -> bool:
	for event in InputMap.action_get_events(action):
		if spec[0] == &"motion" and event is InputEventJoypadMotion:
			if event.axis == spec[1] and is_equal_approx(event.axis_value, spec[2]):
				return true
		elif spec[0] == &"button" and event is InputEventJoypadButton and event.button_index == spec[1]:
			return true
	return false


func _has_key(action: String, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.physical_keycode == key or event.keycode == key):
			return true
	return false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
