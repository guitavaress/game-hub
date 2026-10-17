extends SceneTree
## Teste dos monitores da mesa (Fase 14.28, antes o telão de app da 14.19), com
## fontes falsas: nada de compositor de verdade.
##
## Confere que:
##   - E num monitor sem fonte pede o compositor (seat_requested), e sem
##     compositor (available falso) não senta;
##   - sentado, a câmera enquadra os TRÊS monitores;
##   - o raio do mouse acha o monitor e o pixel: um clique no meio do monitor da
##     direita vira o pixel do meio da fonte da direita, e só dela;
##   - o mouse anda de um monitor para o outro, e o cursor só aparece onde está;
##   - com o botão apertado o mouse fica preso no monitor do clique;
##   - as teclas vão para a fonte; Esc curto chega, Esc longo (ou B) levanta;
##   - levantar solta o foco das fontes e tira o mouse dos apps.

var failures := 0


class FakeSource extends DeskMonitorSource:
	var texture: Texture2D = null
	var focus_calls: Array[bool] = []
	var keys: Array[InputEventKey] = []
	var pointers: Array[Vector2] = []
	var buttons: Array = []
	var scrolls: Array[Vector2] = []
	var leaves := 0

	func get_texture() -> Texture2D:
		return texture

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

	func set_focused(on: bool) -> void:
		focus_calls.append(on)

	func pointer_leave() -> void:
		leaves += 1


class FakePlayer extends Node:
	var left := 0

	func leave_focus() -> void:
		left += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Sem tipo: o ComputerDesk fala com o AppSessions, e um "-s" só enxerga o autoload depois de ligado.
	var desk = load("res://worlds/home/computer_desk.gd").new()
	# O E num monitor sem fonte liga o compositor: aqui não (o de verdade abriria o socket do hub).
	root.get_node("AppSessions").compositor_factory = func() -> Node: return null
	root.add_child(desk)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var player := FakePlayer.new()
	root.add_child(player)
	await process_frame
	var monitors: Array[DeskMonitor3D] = desk.get_screens()
	var left := monitors[0]
	var middle := monitors[1]
	var right := monitors[2]

	print("== Sem compositor ==")
	var requested: Array[int] = [0]
	for monitor in monitors:
		monitor.seat_requested.connect(func() -> void: requested[0] += 1)
	middle.available = false
	middle.interact(player)
	_check("sem compositor, E não pede nada nem senta", requested[0] == 0 and not middle.is_focused())
	middle.available = true
	middle.interact(player)
	_check("com compositor possível, E pede para ligar (e sem fonte ainda não senta)", requested[0] == 1 and not middle.is_focused())
	_check("a imagem do monitor sem fonte é o SEM SINAL", middle.get_content() is DeskMonitorView and middle.get_source() == null)

	print("== A câmera enquadra os três ==")
	var sources: Array[FakeSource] = []
	for monitor in monitors:
		var source := FakeSource.new()
		sources.append(source)
		monitor.set_source(source)
	var window := root.get_visible_rect().size
	var aspect := window.x / maxf(window.y, 1.0)
	var pose := middle.get_camera_pose(camera.fov, aspect)
	_check("os três monitores dão a mesma pose, de qualquer um deles", pose.is_equal_approx(left.get_camera_pose(camera.fov, aspect))
			and pose.is_equal_approx(right.get_camera_pose(camera.fov, aspect)))
	camera.global_transform = pose
	await process_frame
	var inside := true
	for monitor in monitors:
		for pixel in [Vector2.ZERO, Vector2(monitor.resolution.x, 0), Vector2(monitor.resolution), Vector2(0, monitor.resolution.y)]:
			var world: Vector3 = monitor.pixel_to_world(pixel)
			var on_screen := camera.unproject_position(world)
			if camera.is_position_behind(world) or not Rect2(Vector2.ZERO, window).has_point(on_screen):
				inside = false
	_check("os 12 cantos aparecem na janela", inside)
	var middle_on_screen := camera.unproject_position(middle.pixel_to_world(Vector2(middle.resolution) / 2.0))
	_check("o monitor do meio fica no meio da janela", middle_on_screen.distance_to(window / 2.0) < 3.0)
	_check("com fonte, o cartão usa o título da janela", middle.get_look_info()["title"] == "Terminal"
			and middle.get_look_info()["detail"] == "Segure Esc para levantar")

	print("== Sentar ==")
	for source in sources:
		source.focus_calls.clear()
	middle.set_focused(true, player)
	_check("só o monitor do E fica focado (é o líder do assento)", middle.is_focused() and not left.is_focused() and not right.is_focused())
	var all_told := true
	for source in sources:
		all_told = all_told and source.focus_calls == [true]
	_check("as três fontes souberam que o jogador sentou", all_told)

	print("== O mouse pelos três ==")
	var center := Vector2(right.resolution) / 2.0
	var at_right := camera.unproject_position(right.pixel_to_world(center))
	middle._input(_button(at_right, MOUSE_BUTTON_LEFT, true))
	middle._input(_button(at_right, MOUSE_BUTTON_LEFT, false))
	_check("o clique no meio do monitor da direita vira o pixel do meio dele", not sources[2].pointers.is_empty()
			and sources[2].pointers.back().distance_to(center) < 2.0)
	_check("o botão chegou apertado e solto, só na fonte da direita", sources[2].buttons == [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]]
			and sources[0].buttons.is_empty() and sources[1].buttons.is_empty())
	middle._input(_motion(camera.unproject_position(left.pixel_to_world(Vector2(100, 200)))))
	_check("andar até o da esquerda manda o pixel certo para ele", not sources[0].pointers.is_empty()
			and sources[0].pointers.back().distance_to(Vector2(100, 200)) < 2.0)
	middle._process(0.01)
	left._process(0.01)
	right._process(0.01)
	_check("o cursor só aparece no monitor onde o mouse está", left._view.cursor != Vector2.INF
			and right._view.cursor == Vector2.INF and middle._view.cursor == Vector2.INF)
	var hovered := camera.unproject_position(middle.pixel_to_world(Vector2(960, 540)))
	middle._input(_button(hovered, MOUSE_BUTTON_WHEEL_DOWN, true))
	_check("a roda vira rolagem no monitor sob a mira", sources[1].scrolls.size() == 1 and sources[1].scrolls[0].y < 0.0
			and sources[0].scrolls.is_empty())

	print("== Com o botão apertado, o mouse fica preso ==")
	sources[1].pointers.clear()
	sources[2].pointers.clear()
	sources[1].buttons.clear()
	middle._input(_button(hovered, MOUSE_BUTTON_LEFT, true))
	middle._input(_motion(at_right))
	_check("arrastar para o monitor da direita continua no do meio (preso na borda)", not sources[1].pointers.is_empty()
			and sources[2].pointers.is_empty() and sources[1].pointers.back().x > 1900.0)
	middle._input(_button(at_right, MOUSE_BUTTON_LEFT, false))
	_check("soltar fora vale no monitor do clique", sources[1].buttons == [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]]
			and sources[2].buttons.size() == 2)
	var clicks_before: int = sources[0].buttons.size() + sources[1].buttons.size() + sources[2].buttons.size()
	middle._input(_button(Vector2(2.0, 2.0), MOUSE_BUTTON_LEFT, true))
	middle._input(_button(Vector2(2.0, 2.0), MOUSE_BUTTON_LEFT, false))
	var clicks_after: int = sources[0].buttons.size() + sources[1].buttons.size() + sources[2].buttons.size()
	_check("clique fora dos monitores não vira clique no app", clicks_after == clicks_before)
	middle._input(_motion(Vector2(2.0, 2.0)))
	_check("a mira fora dos monitores tira o mouse dos apps", sources[1].leaves >= 1 and middle._under == null)

	print("== Teclas, Esc curto e longo ==")
	middle._input(_key(KEY_A, true))
	_check("tecla comum chega na fonte", sources[1].keys.back().keycode == KEY_A)
	for source in sources:
		source.keys.clear()
	middle._input(_key(KEY_ESCAPE, true))
	middle._process(0.1)
	middle._input(_key(KEY_ESCAPE, false))
	_check("Esc curto chega na fonte (apertar e soltar)", sources[1].keys.size() == 2 and sources[1].keys[0].keycode == KEY_ESCAPE
			and sources[1].keys[0].pressed and not sources[1].keys[1].pressed)
	_check("Esc curto não levanta", player.left == 0)
	sources[1].keys.clear()
	middle._input(_key(KEY_ESCAPE, true))
	middle._process(0.3)
	left._process(0.0)
	right._process(0.0)
	_check("a barra do Esc longo anda, em todos os monitores", middle.get_exit_progress() > 0.3
			and left._view.exit_progress > 0.3 and right._view.exit_progress > 0.3)
	middle._process(0.4)
	_check("Esc longo levanta", player.left == 1)
	middle._input(_key(KEY_ESCAPE, false))
	_check("Esc longo não chega na fonte", sources[1].keys.is_empty())
	player.left = 0
	middle._input(_joy_b(true))
	middle._process(0.7)
	middle._input(_joy_b(false))
	_check("B longo levanta", player.left == 1 and sources[1].keys.is_empty())
	middle._input(_joy_b(true))
	middle._input(_joy_b(false))
	_check("B curto chega como Esc", sources[1].keys.size() == 2 and sources[1].keys[0].keycode == KEY_ESCAPE and player.left == 1)

	print("== Levantar ==")
	var leaves_before: int = sources[0].leaves
	middle.set_focused(false)
	var all_left := true
	for source in sources:
		all_left = all_left and source.focus_calls == [true, false]
	_check("as três fontes souberam que o jogador levantou", all_left)
	_check("o mouse saiu dos apps", sources[0].leaves > leaves_before)
	_check("nenhum monitor guarda o assento", left._leader == null and right._leader == null and middle._leader == null)
	for source in sources:
		source.keys.clear()
		source.buttons.clear()
	middle._input(_key(KEY_B, true))
	middle._input(_button(at_right, MOUSE_BUTTON_LEFT, true))
	_check("sem foco, nada chega", sources[1].keys.is_empty() and sources[2].buttons.is_empty())

	print("== Com uma textura, o monitor usa ==")
	sources[1].texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	middle._process(0.1)
	_check("a view recebe a imagem da saída", middle._view.texture == sources[1].texture)
	middle.set_source(null)
	_check("sem fonte, a imagem some e o monitor volta a Sem sinal", middle._view.texture == null
			and middle.get_look_info()["detail"] == "Sem sinal")

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


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
