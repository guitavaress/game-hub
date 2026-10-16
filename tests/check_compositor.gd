extends SceneTree
## Teste do ponto único do compositor (Fase 14.15): autoload/platform/app_compositor.gd.
##
## Confere que:
##   - sem a extensão (caminho que não existe, ou fora do Linux) nada quebra:
##     a carga diz "não" e o hub segue no plano B;
##   - a tradução "tecla da Godot → evdev" acerta letras, números, as teclas
##     do ABNT2 (ç, ´, ~, ', \, /?), setas, F1–F12 e o AltGr;
##   - o layout do teclado sai da resposta do hyprctl (com "us" de reserva);
##   - o ambiente manda o app para o socket do hub.
## Com a extensão compilada (Linux, native/bin/), também liga e desliga um
## compositor de verdade num socket só do teste. Sem ela, essa parte é pulada.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("== sem a extensão ==")
	_check("caminho que não existe: a extensão não carrega",
			not AppCompositor._load("res://nao/existe.gdextension", "res://nao/existe.so"))
	if OS.get_name() != "Linux":
		_check("fora do Linux: is_available() é falso", not AppCompositor.is_available())
		_check("fora do Linux: create() devolve null", AppCompositor.create() == null)

	print("== teclas (Godot → evdev) ==")
	var left := KEY_LOCATION_UNSPECIFIED
	var expected := {
		"A": [KEY_A, 30], "Q": [KEY_Q, 16], "Z": [KEY_Z, 44], "M": [KEY_M, 50],
		"1": [KEY_1, 2], "0": [KEY_0, 11], "espaço": [KEY_SPACE, 57], "Enter": [KEY_ENTER, 28],
		"Esc": [KEY_ESCAPE, 1], "Backspace": [KEY_BACKSPACE, 14], "Tab": [KEY_TAB, 15],
		"ç (ABNT2)": [KEY_SEMICOLON, 39], "~ (ABNT2)": [KEY_APOSTROPHE, 40],
		"´ (ABNT2)": [KEY_BRACELEFT, 26], "[ (ABNT2)": [KEY_BRACERIGHT, 27],
		"' (ABNT2)": [KEY_SECTION, 41], "\\ ao lado do Shift (ABNT2)": [KEY_QUOTELEFT, 86],
		"; (ABNT2, ao lado do ponto)": [KEY_SLASH, 53],
		"seta para cima": [KEY_UP, 103], "seta para baixo": [KEY_DOWN, 108],
		"seta esquerda": [KEY_LEFT, 105], "seta direita": [KEY_RIGHT, 106],
		"Ctrl esquerdo": [KEY_CTRL, 29], "Shift esquerdo": [KEY_SHIFT, 42], "Alt esquerdo": [KEY_ALT, 56],
	}
	for label: String in expected:
		var pair: Array = expected[label]
		var code := AppCompositor.evdev_for_key(pair[0], left, KEY_NONE)
		_check("%s → %d (veio %d)" % [label, pair[1], code], code == pair[1])
	var f_keys := [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12]
	var f_codes := [59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 87, 88]
	var f_ok := true
	for i in f_keys.size():
		f_ok = f_ok and AppCompositor.evdev_for_key(f_keys[i], left, KEY_NONE) == f_codes[i]
	_check("F1–F12 com os códigos certos", f_ok)
	_check("AltGr (Alt da direita) → 100", AppCompositor.evdev_for_key(KEY_ALT, KEY_LOCATION_RIGHT, KEY_NONE) == 100)
	_check("Ctrl da direita → 97", AppCompositor.evdev_for_key(KEY_CTRL, KEY_LOCATION_RIGHT, KEY_NONE) == 97)
	_check("Shift da direita → 54", AppCompositor.evdev_for_key(KEY_SHIFT, KEY_LOCATION_RIGHT, KEY_NONE) == 54)
	_check("/? do ABNT2 (sem código físico, letra /) → 89",
			AppCompositor.evdev_for_key(KEY_NONE, left, KEY_SLASH) == 89)
	_check("/? com Shift (letra ?) → 89", AppCompositor.evdev_for_key(KEY_NONE, left, KEY_QUESTION) == 89)
	_check("tecla sem código físico nem letra conhecida → -1", AppCompositor.evdev_for_key(KEY_NONE, left, KEY_A) == -1)
	_check("tecla fora da tabela (Volume+) → -1", AppCompositor.evdev_for_key(KEY_VOLUMEUP, left, KEY_NONE) == -1)
	var used := {}
	var repeated: Array[int] = []
	for code: int in AppCompositor.EVDEV.values() + AppCompositor.EVDEV_RIGHT.values() + [AppCompositor.EVDEV_ABNT2_SLASH]:
		if used.has(code):
			repeated.append(code)
		used[code] = true
	_check("nenhum código evdev repetido na tabela %s" % str(repeated), repeated.is_empty())
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SEMICOLON
	event.keycode = KEY_SEMICOLON
	_check("evdev_code(evento) usa a tecla física (ç → 39)", AppCompositor.evdev_code(event) == 39)

	print("== mouse ==")
	_check("botão esquerdo → 0x110", AppCompositor.mouse_button_code(MOUSE_BUTTON_LEFT) == 0x110)
	_check("botão direito → 0x111", AppCompositor.mouse_button_code(MOUSE_BUTTON_RIGHT) == 0x111)
	_check("rodinha não é botão → -1", AppCompositor.mouse_button_code(MOUSE_BUTTON_WHEEL_UP) == -1)
	_check("rodinha para baixo → 1 dente para baixo", AppCompositor.wheel_steps(_wheel(MOUSE_BUTTON_WHEEL_DOWN, true, 0.0)) == Vector2(0, 1))
	_check("rodinha para cima → 1 dente para cima", AppCompositor.wheel_steps(_wheel(MOUSE_BUTTON_WHEEL_UP, true, 1.0)) == Vector2(0, -1))
	_check("meio dente para a esquerda (touchpad)", AppCompositor.wheel_steps(_wheel(MOUSE_BUTTON_WHEEL_LEFT, true, 0.5)) == Vector2(-0.5, 0))
	_check("o 'soltou' da rodinha não rola de novo", AppCompositor.wheel_steps(_wheel(MOUSE_BUTTON_WHEEL_DOWN, false, 1.0)) == Vector2.ZERO)
	_check("botão esquerdo não rola", AppCompositor.wheel_steps(_wheel(MOUSE_BUTTON_LEFT, true, 1.0)) == Vector2.ZERO)

	print("== layout do teclado ==")
	var br := AppCompositor.parse_keyboard_layout('{"option": "input:kb_layout", "str": "br", "set": true }',
			'{"option": "input:kb_variant", "str": "", "set": true }')
	_check("hyprctl 'br' → br, sem variante", br.layout == "br" and br.variant == "")
	var two := AppCompositor.parse_keyboard_layout('{"str": "br,us"}', '{"str": "abnt2,"}')
	_check("vários layouts: vale o primeiro (br, abnt2)", two.layout == "br" and two.variant == "abnt2")
	var none := AppCompositor.parse_keyboard_layout("", "")
	_check("sem resposta do hyprctl → us", none.layout == "us" and none.variant == "")
	var bad := AppCompositor.parse_keyboard_layout("não é json", "")
	_check("resposta estranha → us", bad.layout == "us")
	var mine := AppCompositor.keyboard_layout()
	print("   layout deste computador: ", mine)
	_check("keyboard_layout() sempre traz layout e variante", mine.has("layout") and mine.has("variant") and not str(mine.layout).is_empty())

	print("== ambiente do app ==")
	var env := AppCompositor.environment()
	_check("o app vai para o socket do hub", env.has("WAYLAND_DISPLAY=" + AppCompositor.SOCKET))
	_check("GTK e Qt forçados no Wayland", env.has("GDK_BACKEND=wayland") and env.has("QT_QPA_PLATFORM=wayland"))
	_check("o DISPLAY (X11) não é mexido", not ",".join(env).contains("DISPLAY=:"))

	print("== com a extensão ==")
	if not AppCompositor.is_available():
		print("   pulado: extensão não compilada (ou fora do Linux)")
	else:
		await _real_compositor()

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Liga um compositor de verdade num socket só do teste (não briga com o hub aberto).
func _real_compositor() -> void:
	var socket := "gamehub-teste-%d" % OS.get_process_id()
	# O socket em si não é um arquivo comum; o ".lock" do lado é (e some junto).
	var socket_file := OS.get_environment("XDG_RUNTIME_DIR").path_join(socket + ".lock")
	var comp := AppCompositor.create(socket)
	_check("create() devolve o nó ligado", comp != null and comp.call("is_running"))
	if comp == null:
		return
	root.add_child(comp)
	for method in ["poll", "stop", "get_texture", "get_image", "get_title", "resize", "close", "focus", "key", "pointer_motion", "pointer_leave", "pointer_button", "pointer_axis", "stats",
			"set_outputs", "get_output_count", "place", "raise", "get_output_texture", "get_output_image", "window_at", "pointer_motion_output"]:
		_check("o nó tem %s()" % method, comp.has_method(method))
	for sig in ["window_opened", "window_closed", "title_changed"]:
		_check("o nó tem o sinal %s" % sig, comp.has_signal(sig))
	_check("o socket está aberto (%s)" % socket_file, FileAccess.file_exists(socket_file))
	for i in 5:
		comp.call("poll")
		await process_frame
	_check("sem app, nenhuma textura", comp.call("get_texture", 1) == null)
	_check("resize/close de janela que não existe devolvem false",
			not comp.call("resize", 1, 640, 360) and not comp.call("close", 1))
	var stats: Dictionary = comp.call("stats")
	_check("stats() conta 0 janelas", stats.get("janelas", -1) == 0)

	# Saídas (Fase 14.26): os três monitores da mesa.
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1920, 1080), Vector2i(1920, 1080)]
	_check("set_outputs() com 3 monitores", comp.call("set_outputs", sizes) and comp.call("get_output_count") == 3)
	_check("set_outputs() sem nenhum é recusado", not comp.call("set_outputs", [] as Array[Vector2i]) and comp.call("get_output_count") == 3)
	comp.call("poll")
	var output_texture: Texture2D = comp.call("get_output_texture", 2)
	_check("cada saída tem a textura composta (1920×1080)", output_texture != null
			and output_texture.get_size() == Vector2(1920, 1080) and comp.call("get_output_texture", 3) == null)
	var output_image: Image = comp.call("get_output_image", 0)
	_check("a saída vazia mostra o fundo", output_image != null and output_image.get_pixel(960, 540).a == 1.0)
	_check("sem janela, window_at() dá 0", comp.call("window_at", 1, 100.0, 100.0) == 0)
	_check("place() de janela que não existe devolve false", not comp.call("place", 1, 0, 0, 0, 640, 360))
	_check("stats() conta 3 saídas", comp.call("stats").get("saidas", -1) == 3)
	comp.queue_free()
	await process_frame
	await process_frame
	_check("ao sair da árvore, o socket é fechado", not FileAccess.file_exists(socket_file))


func _wheel(button: MouseButton, pressed: bool, factor: float) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.factor = factor
	return event


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
