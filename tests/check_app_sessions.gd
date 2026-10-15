extends SceneTree
## Teste do AppSessions e da abertura de apps no mundo (Fase 14.21), com um
## compositor FALSO: nenhum app é aberto de verdade.

var failures := 0


## O compositor de mentira: tem os mesmos sinais e funções que o AppSessions usa.
class FakeCompositor extends Node:
	signal window_opened(id: int, app_id: String, title: String, pid: int)
	signal window_closed(id: int)
	signal title_changed(id: int, title: String)
	var calls: Array = []
	var closed_ids: Array[int] = []
	var polls := 0

	func poll() -> void:
		polls += 1

	func get_texture(_id: int) -> Texture2D:
		var image := Image.create(800, 600, false, Image.FORMAT_RGBA8)
		return ImageTexture.create_from_image(image)

	func resize(id: int, w: int, h: int) -> void:
		calls.append(["resize", id, w, h])

	func close(id: int) -> bool:
		closed_ids.append(id)
		return true

	func focus(id: int) -> void:
		calls.append(["focus", id])

	func key(id: int, code: int, pressed: bool) -> void:
		calls.append(["key", id, code, pressed])

	func pointer_motion(id: int, x: float, y: float) -> void:
		calls.append(["motion", id, x, y])

	func pointer_leave() -> void:
		calls.append(["leave"])

	func pointer_button(button: int, pressed: bool) -> void:
		calls.append(["button", button, pressed])

	func pointer_axis(dx: float, dy: float, wheel: bool) -> void:
		calls.append(["axis", dx, dy, wheel])


func _initialize() -> void:
	_run()


func _app(id: String, app_name: String) -> DesktopApp:
	var app := DesktopApp.new()
	app.id = id
	app.name = app_name
	return app


func _run() -> void:
	await process_frame
	var S: Node = root.get_node("AppSessions")
	var A: Node = root.get_node("AppLauncher")
	var H: Node = root.get_node("HubWindow")
	var library: Node = root.get_node("AppLibrary")
	var config_backup := FileAccess.get_file_as_string(root.get_node("AppConfig").CONFIG_PATH)
	root.get_node("GameLauncher")._poll_timer.paused = true

	library.set_apps([_app("brave", "Brave"), _app("foot", "Foot")] as Array[DesktopApp])
	var opened: Array[String] = []
	var open_ok: Array[bool] = [true]  # lista: a lambda não enxerga mudança de variável simples
	S.opener = func(app: DesktopApp) -> bool:
		opened.append(app.id)
		return open_ok[0]
	var outside: Array[String] = []
	A.threaded = false
	A.opener = func(app: DesktopApp) -> bool:
		outside.append(app.id)
		return true
	A.can_track = func() -> bool: return false
	A.list_windows = func() -> PackedStringArray: return PackedStringArray()
	var ended: Array = []
	var started: Array = []
	A.app_session_ended.connect(func(id: String, _s: Node, ok: bool, msg: String) -> void:
		ended.append({"id": id, "ok": ok, "msg": msg}))
	A.app_launch_started.connect(func(id: String, _s: Node) -> void: started.append(id))

	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame
	var screens: AppScreens = city.get_home().get_node("AppScreens")

	print("== Sem compositor: o fluxo é o da parte 1 ==")
	S.compositor_factory = func() -> Node: return null
	S._tried = false
	_check("sem compositor, não abre no mundo", not S.can_open_in_world() and not A.opens_in_world())
	_check("launch abre pelo abridor de fora", A.launch("foot", null) and outside == ["foot"] and opened.is_empty())
	_check("o hub dorme (fluxo de fora)", H.is_sleeping and started == ["foot"])
	A.cancel_launch()
	ended.clear()
	started.clear()
	outside.clear()
	H.wake()

	print("== Com compositor: janela nova liga ao app ==")
	var comp := FakeCompositor.new()
	S.compositor_factory = func() -> Node: return comp
	S._tried = false
	_check("agora abre no mundo", S.can_open_in_world() and A.opens_in_world() and S.get_compositor() == comp)
	await process_frame
	_check("o poll roda a cada quadro", comp.polls > 0)
	_check("os 3 telões estão livres", S.free_screens() == 3)
	_check("launch aceita", A.launch("brave", null))
	_check("abriu no compositor, e não por fora", opened == ["brave"] and outside.is_empty())
	_check("o hub fica acordado e sem tela 'Abrindo'", not H.is_sleeping and started.is_empty())
	_check("a sessão espera a janela", A.state == A.State.LAUNCHING and ended.is_empty())
	_check("não abre outro enquanto espera", not A.launch("foot", null) and ended.size() == 1 and not ended[0]["ok"])
	ended.clear()
	comp.window_opened.emit(1, "brave-origin", "Brave", 100)
	_check("a janela foi para o 1º telão", screens.get_screens()[0].get_source() != null and S.window_count() == 1)
	_check("a janela é do app aberto", S.app_of(1) == "brave")
	_check("a sessão acabou com sucesso, no mundo", A.state == A.State.IDLE and ended.size() == 1 and ended[0]["ok"]
			and ended[0]["id"] == "brave" and A.last_session_in_world)
	_check("o hub não dormiu", not H.is_sleeping)
	_check("o telão pediu o tamanho", ["resize", 1, 1280, 720] in comp.calls)

	print("== Segunda janela do mesmo cliente ==")
	comp.window_opened.emit(2, "brave-origin", "Outra", 100)
	_check("vai para outro telão, ainda do Brave", screens.get_screens()[1].get_source() != null and S.app_of(2) == "brave")
	comp.window_opened.emit(3, "foot", "Terminal", 300)
	_check("um cliente de fora do hub também ganha telão", S.free_screens() == 0 and S.app_of(3) == "foot")

	print("== Telões cheios ==")
	comp.window_opened.emit(4, "foot", "Mais um", 301)
	_check("sem telão livre, a janela é fechada", comp.closed_ids == [4] and S.window_count() == 3)
	ended.clear()
	_check("launch recusa com aviso", not A.launch("foot", null) and ended.size() == 1 and not ended[0]["ok"]
			and ended[0]["msg"].begins_with("Os telões estão cheios"))
	_check("nada foi aberto", opened == ["brave"])

	print("== A fonte traduz para o compositor ==")
	var src: AppWindowSource = screens.get_screens()[0].get_source()
	comp.calls.clear()
	src.send_pointer(Vector2(640, 360))  # a textura é 800×600, o telão 1280×720
	_check("o mouse é convertido pela proporção", ["motion", 1, 400.0, 300.0] in comp.calls)
	src.send_scroll(Vector2(0, 1))
	_check("rolar para cima vira dy negativo", ["axis", 0.0, -1.0, true] in comp.calls)
	src.send_button(MOUSE_BUTTON_LEFT, true)
	_check("o botão esquerdo vira 0x110", ["button", 0x110, true] in comp.calls)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	src.send_key(key)
	_check("a tecla vira evdev", ["key", 1, 30, true] in comp.calls)
	key.echo = true
	comp.calls.clear()
	src.send_key(key)
	_check("a repetição de tecla não é enviada", comp.calls.is_empty())
	src.set_focused(true)
	src.set_focused(false)
	_check("o foco segue o telão", ["focus", 1] in comp.calls and ["focus", 0] in comp.calls)
	comp.title_changed.emit(1, "Novo título")
	_check("o título acompanha o app", src.get_title() == "Novo título")

	print("== A janela fecha ==")
	var gone: Array[int] = []
	S.window_gone.connect(func(id: int) -> void: gone.append(id))
	comp.window_closed.emit(2)
	_check("o telão fica livre", S.free_screens() == 1 and screens.get_screens()[1].get_source() == null and gone == [2])
	comp.window_closed.emit(1)
	comp.window_closed.emit(3)
	_check("todos livres de novo", S.free_screens() == 3 and S.window_count() == 0)

	print("== Sem janela em 10 s: plano B ==")
	ended.clear()
	opened.clear()
	_check("launch aceita", A.launch("foot", null) and opened == ["foot"] and A.state == A.State.LAUNCHING)
	A._launch_started_ms -= 11000
	A._poll()
	_check("o hub passa a dormir, como na parte 1", H.is_sleeping and started == ["foot"])
	_check("a sessão segue de fora (não é mais do mundo)", A.state == A.State.LAUNCHING and not A._in_world)
	comp.window_opened.emit(5, "foot", "Tarde demais", 400)
	_check("janela tardia não encerra a sessão de fora", A.state == A.State.LAUNCHING and ended.is_empty())
	A.cancel_launch()
	_check("cancelar acaba a sessão com aviso", ended.size() == 1 and not ended[0]["ok"] and not H.is_sleeping)

	print("== O app não abre ==")
	ended.clear()
	open_ok[0] = false
	var launched: bool = A.launch("foot", null)
	_check("launch devolve false e avisa", not launched and ended.size() == 1 and not ended[0]["ok"]
			and A.state == A.State.IDLE)

	var file := FileAccess.open(root.get_node("AppConfig").CONFIG_PATH, FileAccess.WRITE)
	file.store_string(config_backup)
	file.close()
	root.get_node("AppConfig")._config.load(root.get_node("AppConfig").CONFIG_PATH)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
