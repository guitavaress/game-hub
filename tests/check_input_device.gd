extends SceneTree
## Teste das dicas que trocam com o aparelho (Fase 12.7):
##   - o InputDevice troca entre teclado e controle pelos eventos de verdade
##     (Input.parse_input_event): botão e analógico forte → controle; tecla,
##     clique e mouse mexendo → teclado; analógico com folga NÃO troca;
##   - uma tecla desenhada por dica muda o texto ("Esc" ↔ "B", "E" ↔ "X");
##   - o cartão do que se olha troca "Segure E para jogar" ↔ "Segure X para
##     jogar" sem o jogador tirar o olhar;
##   - A, B, X e Y têm a cor do controle Xbox;
##   - o cursor do mouse some com o controle e volta com o teclado;
##   - as dicas dos móveis e das portas vêm com o marcador {interact}.

var failures := 0
var device_changes: Array[bool] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	var device = root.get_node("InputDevice")
	device.device_changed.connect(func(gamepad: bool) -> void: device_changes.append(gamepad))

	print("== Troca de aparelho ==")
	_check("começa no teclado", not device.is_gamepad())
	await _send(_joy_button(JOY_BUTTON_X))
	_check("um botão do controle troca para o controle", device.is_gamepad())
	_check("e avisa uma vez (device_changed)", device_changes == [true])
	await _send(_joy_button(JOY_BUTTON_A))
	_check("outro botão não avisa de novo", device_changes == [true])
	await _send(_key(KEY_E))
	_check("uma tecla volta para o teclado", not device.is_gamepad())
	await _send(_joy_motion(0, 0.2))
	_check("analógico com folga (20%) NÃO troca (as dicas não piscam)", not device.is_gamepad())
	await _send(_joy_motion(0, 0.9))
	_check("analógico forte (90%) troca", device.is_gamepad())
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(5.0, 0.0)
	await _send(motion)
	_check("mexer o mouse volta para o teclado", not device.is_gamepad())
	await _send(_joy_button(JOY_BUTTON_B))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	await _send(click)
	_check("um clique também", not device.is_gamepad())
	_send_release()

	print("== Teclas desenhadas ==")
	var hint_script: GDScript = load("res://ui/key_hint.gd")  # sem o nome da classe: ela usa um autoload
	var back = hint_script.create("back")
	root.add_child(back)
	var move = hint_script.create("move")
	root.add_child(move)
	await process_frame
	_check("no teclado: 'back' = Esc e 'move' = WASD", back.get_texts() == PackedStringArray(["Esc"])
			and move.get_texts() == PackedStringArray(["W", "A", "S", "D"]))
	device.set_gamepad(true)
	_check("no controle: 'back' = B", back.get_texts() == PackedStringArray(["B"]))
	_check("no controle: 'move' = LS (uma tecla só)", move.get_texts() == PackedStringArray(["LS"]))
	_check("o B é vermelho", _label_color(back) == device.PAD_COLORS["B"])
	var interact = hint_script.create("interact")
	root.add_child(interact)
	await process_frame
	_check("'interact' = X, azul", interact.get_texts() == PackedStringArray(["X"]) and _label_color(interact) == device.PAD_COLORS["X"])
	device.set_gamepad(false)
	_check("de volta ao teclado: 'back' = Esc, sem cor", back.get_texts() == PackedStringArray(["Esc"])
			and _label_color(back) == root.get_node("InputDevice").PAD_COLORS.get("none", _text_color()))
	_check("o texto corrido troca: {interact} e {back}", device.fill("Segure {interact} para jogar") == "Segure E para jogar"
			and device.fill("{back} fecha") == "Esc fecha")
	device.set_gamepad(true)
	_check("no controle: Segure X para jogar", device.fill("Segure {interact} para jogar") == "Segure X para jogar")
	device.set_gamepad(false)
	_check("sem marcador, o texto fica como está", device.fill("Entre pela porta para jogar") == "Entre pela porta para jogar")
	for node in [back, move, interact]:
		node.queue_free()

	print("== Telas com as dicas ==")
	load("res://tests/fake_library.gd").install(root, 12)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var home = city.get_home()
	var menu = player.get_pause_menu()
	var footer := _find_hint(menu, "back")
	_check("o rodapé do menu de pausa tem a dica 'back'", footer != null and footer.get_texts() == PackedStringArray(["Esc"]))
	device.set_gamepad(true)
	_check("e ela vira B no controle", footer.get_texts() == PackedStringArray(["B"]))
	var search_hint := _find_hint(player.get_game_search(), "travel")
	_check("a busca: 'ir até lá' vira X", search_hint != null and search_hint.get_texts() == PackedStringArray(["X"]))
	var first_time = load("res://ui/controls_hint.gd").new()
	root.add_child(first_time)
	await process_frame
	var move_hint = _find_hint(first_time, "move")
	_check("o cartão de controles da 1ª vez usa as mesmas dicas (andar)", move_hint != null
			and move_hint.get_texts() == PackedStringArray(["LS"]))
	first_time.set_process(false)  # não grava "visto" no config.cfg
	first_time.queue_free()
	device.set_gamepad(false)

	hud.set_look_info({"title": "Estante", "action": "Segure {interact} para jogar"})
	_check("no teclado, o cartão diz Segure E para jogar", hud.get_look_action() == "Segure E para jogar")
	device.set_gamepad(true)
	_check("e troca para Segure X sem o jogador tirar o olhar", hud.get_look_action() == "Segure X para jogar")
	device.set_gamepad(false)
	_check("e volta", hud.get_look_action() == "Segure E para jogar")
	hud.set_look_info({})

	var shelf = home.get_node("LibraryShelf")
	var box = shelf.get_box(shelf.get_visible_app_ids()[0])
	_check("a caixa da estante manda o marcador {interact}", box.get_look_info()["action"] == "Segure {interact} para jogar")
	_check("a porta da casa também ({interact} para sair)", home.get_front_door().get_look_info()["action"] == "{interact} para sair")
	_check("a porta 'Casa' da praça também", city.get_home_door().get_look_info()["action"] == "{interact} para entrar")
	_check("o monitor sem sinal não pede nada", home.get_node("ComputerDesk").get_screen().get_look_info()["action"] == "")

	print("== O cursor do mouse ==")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Sem janela (testes), a Godot não muda o modo do mouse: só avisa.
		print("   (sem janela: o modo do mouse não muda; confira à mão — passo 4 do teste manual)")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		device.set_gamepad(true)
		await process_frame
		await process_frame
		_check("com o controle, o cursor fica escondido", Input.mouse_mode == Input.MOUSE_MODE_HIDDEN)
		device.set_gamepad(false)
		_check("com o teclado, o cursor volta", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		device.set_gamepad(true)
		await process_frame
		_check("preso no jogo (CAPTURED), o controle não mexe no mouse", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		device.set_gamepad(false)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Entrega o evento como o aparelho de verdade (passa pelo sinal window_input).
func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _send_release() -> void:
	for index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]:
		var event := _joy_button(index)
		event.pressed = false
		Input.parse_input_event(event)


func _joy_button(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = true
	return event


func _joy_motion(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	return event


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


## A cor normal do texto de uma tecla (a do tema).
func _text_color() -> Color:
	return load("res://ui/hub_theme.gd").TEXT_COLOR


func _label_color(hint: Control) -> Color:
	var label: Label = hint.get_child(0).get_child(0)
	return label.get_theme_color("font_color")


## A primeira KeyHint com este nome debaixo de "node".
func _find_hint(node: Node, hint_name: String) -> Control:
	if node.get_script() != null and node.get_script().resource_path == "res://ui/key_hint.gd" and node.hint_name == hint_name:
		return node
	for child in node.get_children():
		var found := _find_hint(child, hint_name)
		if found != null:
			return found
	return null


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
