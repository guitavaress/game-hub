extends SceneTree
## Teste do telão de app (Fase 14.19), com uma fonte de janela falsa.

var failures := 0


class FakeSource extends AppWindowSource:
	var texture: Texture2D = null
	var sizes: Array[Vector2i] = []
	var keys: Array[InputEventKey] = []
	var pointers: Array[Vector2] = []
	var buttons: Array = []
	var scrolls: Array[Vector2] = []

	func get_texture() -> Texture2D:
		return texture

	func resize(size: Vector2i) -> void:
		sizes.append(size)

	func send_key(event: InputEventKey) -> void:
		keys.append(event)

	func send_pointer(pixel: Vector2) -> void:
		pointers.append(pixel)

	func send_button(button: MouseButton, pressed: bool) -> void:
		buttons.append([button, pressed])

	func send_scroll(delta: Vector2) -> void:
		scrolls.append(delta)

	func get_title() -> String:
		return "Terminal"


class FakePlayer extends Node:
	var left := 0

	func leave_focus() -> void:
		left += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var screen := AppWindow3D.new()
	root.add_child(screen)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var player := FakePlayer.new()
	root.add_child(player)
	await process_frame

	# Sem fonte e sem textura, nada quebra.
	screen.set_focused(true, player)
	screen._input(_motion(Vector2(100, 100)))
	screen._input(_key(KEY_A, true))
	screen._process(0.1)
	_check("sem fonte, o telão mostra 'Livre' e não quebra", screen.get_look_info()["title"] == "Telão")

	var source := FakeSource.new()
	screen.set_source(source)
	_check("sem textura, nada quebra", source.get_texture() == null and screen.get_source() == source)
	screen._process(0.1)

	# Posição da câmera: de frente para o telão.
	camera.global_transform = screen.get_camera_pose(camera.fov, 16.0 / 9.0)
	await process_frame
	_check("resize chegou com a resolução do telão", source.sizes.size() > 0 and source.sizes.back() == Vector2i(1280, 720))
	screen.set_focused(false)
	screen.set_focused(true, player)
	_check("focar manda o resize de novo", source.sizes.size() >= 2 and source.sizes.back() == Vector2i(1280, 720))
	_check("o cartão usa o título da janela", screen.get_look_info()["title"] == "Terminal")

	# Clique no meio do telão = pixel do meio.
	var mid_world := screen.pixel_to_world(Vector2(640, 360))
	var mid_window := camera.unproject_position(mid_world)
	screen._input(_button(mid_window, MOUSE_BUTTON_LEFT, true))
	screen._input(_button(mid_window, MOUSE_BUTTON_LEFT, false))
	var pointer: Vector2 = source.pointers.back() if source.pointers.size() > 0 else Vector2(-1, -1)
	_check("clique no meio vira o pixel do meio", pointer.distance_to(Vector2(640, 360)) < 1.5)
	_check("o botão chegou apertado e solto", source.buttons == [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]])

	screen._input(_button(mid_window, MOUSE_BUTTON_WHEEL_DOWN, true))
	_check("a roda vira rolagem", source.scrolls.size() == 1 and source.scrolls[0].y < 0.0)

	# Teclas comuns vão para a fonte.
	screen._input(_key(KEY_A, true))
	_check("tecla comum chega na fonte", source.keys.back().keycode == KEY_A)

	# Esc curto chega; Esc longo sai sem chegar.
	source.keys.clear()
	screen._input(_key(KEY_ESCAPE, true))
	screen._process(0.1)
	screen._input(_key(KEY_ESCAPE, false))
	_check("Esc curto chega na fonte (apertar e soltar)", source.keys.size() == 2 and source.keys[0].keycode == KEY_ESCAPE and source.keys[0].pressed and not source.keys[1].pressed)
	_check("Esc curto não sai do telão", player.left == 0)

	source.keys.clear()
	screen._input(_key(KEY_ESCAPE, true))
	screen._process(0.3)
	_check("a barra do Esc longo anda", screen.get_exit_progress() > 0.3)
	screen._process(0.4)
	_check("Esc longo sai do telão", player.left == 1)
	screen._input(_key(KEY_ESCAPE, false))
	_check("Esc longo não chega na fonte", source.keys.is_empty())

	# Botão B: mesma regra.
	player.left = 0
	screen._input(_joy_b(true))
	screen._process(0.7)
	screen._input(_joy_b(false))
	_check("B longo sai do telão", player.left == 1 and source.keys.is_empty())
	screen._input(_joy_b(true))
	screen._input(_joy_b(false))
	_check("B curto chega como Esc", source.keys.size() == 2 and source.keys[0].keycode == KEY_ESCAPE and player.left == 1)

	# Com uma textura, o telão usa.
	source.texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	screen._process(0.1)
	_check("com textura, a view recebe a imagem", screen._view.texture == source.texture)

	# Sem foco, nada chega.
	screen.set_focused(false)
	source.keys.clear()
	screen._input(_key(KEY_B, true))
	_check("sem foco, as teclas não chegam", source.keys.is_empty())

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _key(code: Key, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func _joy_b(pressed: bool) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_B
	e.pressed = pressed
	return e


func _motion(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	return e


func _button(pos: Vector2, index: MouseButton, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = index
	e.pressed = pressed
	return e


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
