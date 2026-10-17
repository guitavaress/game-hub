extends SceneTree
## Teste do AppSessions e da abertura de apps no mundo (Fase 14.21), com um
## compositor FALSO: nenhum app é aberto de verdade.

var failures := 0


## O compositor de mentira: tem os mesmos sinais e funções que o AppSessions usa.
class FakeCompositor extends Node:
	signal window_opened(id: int, app_id: String, title: String, pid: int)
	signal window_closed(id: int)
	signal title_changed(id: int, title: String)
	signal usable_area_changed(output: int, rect: Rect2i)
	var calls: Array = []
	var closed_ids: Array[int] = []
	var polls := 0
	var output_sizes: Array[Vector2i] = []
	## A área útil de cada saída (a 1 tem uma barra de 26 px em cima).
	var usable := {0: Rect2i(0, 0, 1920, 1080), 1: Rect2i(0, 26, 1920, 1054), 2: Rect2i(0, 0, 1920, 1080)}
	## Qual janela está embaixo do mouse (0 = nenhuma).
	var window_hit := 0

	func poll() -> void:
		polls += 1

	func set_outputs(sizes: Array[Vector2i]) -> bool:
		output_sizes = sizes
		calls.append(["set_outputs", sizes.size()])
		return true

	func get_output_texture(_output: int) -> Texture2D:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		return ImageTexture.create_from_image(image)

	func get_usable_area(output: int) -> Rect2i:
		return usable.get(output, Rect2i())

	func place(id: int, output: int, x: int, y: int, w: int, h: int) -> bool:
		calls.append(["place", id, output, x, y, w, h])
		return true

	func raise(id: int) -> bool:
		calls.append(["raise", id])
		return true

	func window_at(_output: int, _x: float, _y: float) -> int:
		return window_hit

	func close(id: int) -> bool:
		closed_ids.append(id)
		return true

	func focus(id: int) -> void:
		calls.append(["focus", id])

	func key_focused(code: int, pressed: bool) -> void:
		calls.append(["key_focused", code, pressed])

	func pointer_motion_output(output: int, x: float, y: float) -> void:
		calls.append(["motion", output, x, y])

	func pointer_leave() -> void:
		calls.append(["leave"])

	func pointer_button(button: int, pressed: bool) -> void:
		calls.append(["button", button, pressed])

	func pointer_axis(dx: float, dy: float, wheel: bool) -> void:
		calls.append(["axis", dx, dy, wheel])


## Os três monitores da mesa, no grupo "desk_monitors" (o contrato do AppSessions).
class FakeDesk extends Node3D:
	var monitors: Array[DeskMonitor3D] = []

	func _ready() -> void:
		for i in 3:
			var monitor := DeskMonitor3D.new()
			monitor.output_index = i
			add_child(monitor)
			monitors.append(monitor)


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

	# A mesa de mentira: três monitores no grupo "desk_monitors".
	var desk := FakeDesk.new()
	root.add_child(desk)
	await process_frame
	var monitors := desk.monitors

	print("== Sem compositor: o fluxo é o da parte 1 ==")
	S.compositor_factory = func() -> Node: return null
	S._tried = false
	_check("sem compositor, não abre no mundo", not S.can_open_in_world() and not A.opens_in_world())
	_check("os monitores seguem sem fonte", monitors[1].get_source() == null)
	_check("attach_monitors diz que não deu", not S.attach_monitors())
	_check("launch abre pelo abridor de fora", A.launch("foot", null) and outside == ["foot"] and opened.is_empty())
	_check("o hub dorme (fluxo de fora)", H.is_sleeping and started == ["foot"])
	A.cancel_launch()
	ended.clear()
	started.clear()
	outside.clear()
	H.wake()

	print("== Com compositor: uma saída e uma fonte por monitor ==")
	var comp := FakeCompositor.new()
	S.compositor_factory = func() -> Node: return comp
	S._tried = false
	_check("agora abre no mundo", S.can_open_in_world() and A.opens_in_world() and S.get_compositor() == comp)
	await process_frame
	_check("o poll roda a cada quadro", comp.polls > 0)
	_check("o compositor ganhou 3 saídas, do tamanho dos monitores", comp.output_sizes == [Vector2i(1920, 1080), Vector2i(1920, 1080), Vector2i(1920, 1080)])
	var sources_ok := true
	for monitor in monitors:
		sources_ok = sources_ok and monitor.get_source() != null
	_check("cada monitor ganhou a sua fonte", sources_ok and monitors[0].get_source() != monitors[1].get_source())
	_check("a fonte entrega a textura da saída", monitors[2].get_source().get_texture() != null)

	print("== Com compositor: janela nova vai para o monitor do meio ==")
	_check("launch aceita", A.launch("brave", null))
	_check("abriu no compositor, e não por fora", opened == ["brave"] and outside.is_empty())
	_check("o hub fica acordado e sem tela 'Abrindo'", not H.is_sleeping and started.is_empty())
	_check("a sessão espera a janela", A.state == A.State.LAUNCHING and ended.is_empty())
	_check("não abre outro enquanto espera", not A.launch("foot", null) and ended.size() == 1 and not ended[0]["ok"])
	ended.clear()
	comp.calls.clear()
	comp.window_opened.emit(1, "brave-origin", "Brave", 100)
	_check("a janela é do app aberto", S.app_of(1) == "brave" and S.window_count() == 1)
	_check("foi para o monitor do meio, na área útil (sem a barra)", ["place", 1, 1, 0, 26, 1920, 1054] in comp.calls
			and S.output_of(1) == 1)
	_check("ganhou o foco da mesa e foi para cima", S.focused_window() == 1 and ["raise", 1] in comp.calls)
	_check("sem ninguém sentado, o teclado não é dela ainda", not (["focus", 1] in comp.calls))
	_check("a sessão acabou com sucesso, no mundo", A.state == A.State.IDLE and ended.size() == 1 and ended[0]["ok"]
			and ended[0]["id"] == "brave" and A.last_session_in_world)
	_check("o hub não dormiu", not H.is_sleeping)

	print("== O mouse decide para onde vai a próxima janela ==")
	var right_source: DeskMonitorSource = monitors[2].get_source()
	comp.calls.clear()
	right_source.send_pointer(Vector2(640, 360))
	_check("o pixel da saída vai direto para o compositor", ["motion", 2, 640.0, 360.0] in comp.calls)
	comp.window_opened.emit(2, "brave-origin", "Outra", 100)
	_check("a segunda janela do mesmo cliente vai para onde o mouse esteve, ainda do Brave",
			S.output_of(2) == 2 and S.app_of(2) == "brave" and ["place", 2, 2, 0, 0, 1920, 1080] in comp.calls)
	comp.window_opened.emit(3, "foot", "Terminal", 300)
	_check("um cliente de fora do hub também ganha lugar, com o app_id dele", S.app_of(3) == "foot" and S.window_count() == 3)
	_check("a janela nova fica com o foco", S.focused_window() == 3 and S.focus_title() == "Terminal")

	print("== A fonte traduz para o compositor ==")
	comp.calls.clear()
	right_source.send_scroll(Vector2(0, 1))
	_check("rolar para cima vira dy negativo", ["axis", 0.0, -1.0, true] in comp.calls)
	comp.window_hit = 2
	right_source.send_button(MOUSE_BUTTON_LEFT, true)
	_check("o botão esquerdo vira 0x110", ["button", 0x110, true] in comp.calls)
	_check("clicar numa janela dá o foco a ela e a põe por cima", S.focused_window() == 2 and ["raise", 2] in comp.calls)
	comp.window_hit = 0
	comp.calls.clear()
	right_source.send_button(MOUSE_BUTTON_LEFT, true)
	_check("clicar onde não há janela (a barra) não muda o foco", S.focused_window() == 2 and not (["raise", 2] in comp.calls))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	comp.calls.clear()
	right_source.send_key(key)
	_check("a tecla vira evdev e vai para quem tem o teclado", ["key_focused", 30, true] in comp.calls)
	key.echo = true
	comp.calls.clear()
	right_source.send_key(key)
	_check("a repetição de tecla não é enviada", comp.calls.is_empty())
	right_source.pointer_leave()
	_check("a mira que sai tira o mouse dos apps", ["leave"] in comp.calls)
	comp.calls.clear()
	right_source.set_focused(true)
	_check("sentar dá o teclado à janela em foco", ["focus", 2] in comp.calls)
	comp.calls.clear()
	comp.window_opened.emit(6, "foot", "Sentado", 301)
	_check("sentado, a janela nova já ganha o teclado", ["focus", 6] in comp.calls and S.focused_window() == 6)
	right_source.set_focused(false)
	_check("levantar tira o foco de todas", ["focus", 0] in comp.calls)
	comp.window_closed.emit(6)
	comp.title_changed.emit(2, "Novo título")
	_check("o título acompanha o app", right_source.get_title() == "Terminal" or S.focus_title() != "")
	_check("ao fechar a de cima, o foco volta para a que estava embaixo dela (a 2, clicada antes)", S.focused_window() == 2 and S.window_count() == 3)

	print("== A barra muda a área útil ==")
	comp.calls.clear()
	comp.usable[1] = Rect2i(0, 60, 1920, 1020)
	comp.usable_area_changed.emit(1, comp.usable[1])
	_check("as janelas da saída se ajustam", ["place", 1, 1, 0, 60, 1920, 1020] in comp.calls
			and not (["place", 2, 2, 0, 0, 1920, 1080] in comp.calls))

	print("== Hub dormindo: o compositor fica ocioso ==")
	var polls_before: int = comp.polls
	H.sleep(false)
	await process_frame
	await process_frame
	_check("dormindo, não há poll (nem textura nova)", S.is_dormant() and comp.polls == polls_before)
	H.focus_returned.emit()
	_check("o atalho do hub não mexe nos apps do mundo (sessão já ociosa)", A.state == A.State.IDLE and S.window_count() == 3)
	H.wake()
	await process_frame
	await process_frame
	_check("acordado, o poll volta", not S.is_dormant() and comp.polls > polls_before)

	print("== A janela fecha ==")
	var gone: Array[int] = []
	S.window_gone.connect(func(id: int) -> void: gone.append(id))
	comp.window_closed.emit(2)
	_check("o aviso sai e a janela some da lista", S.window_count() == 2 and gone == [2] and S.app_of(2) == "")
	comp.window_closed.emit(1)
	comp.window_closed.emit(3)
	_check("todas fechadas: nenhuma com o foco", S.window_count() == 0 and S.focused_window() == 0)
	comp.window_closed.emit(99)
	_check("fechar uma que não existe não quebra", gone == [2, 1, 3])

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

	print("== O arranjo: várias janelas, ações e monitores cheios ==")
	comp.window_closed.emit(5)
	comp.calls.clear()
	comp.usable[1] = Rect2i(0, 26, 1920, 1054)
	comp.usable_area_changed.emit(1, comp.usable[1])
	comp.window_opened.emit(10, "foot", "A", 500)  # o mouse esteve na saída 2
	comp.window_opened.emit(11, "foot", "B", 501)
	comp.window_opened.emit(12, "foot", "C", 502)
	_check("três janelas no monitor do mouse se dividem",
			["place", 10, 2, 0, 0, 960, 1080] in comp.calls and ["place", 11, 2, 960, 0, 960, 540] in comp.calls
			and ["place", 12, 2, 960, 540, 960, 540] in comp.calls)
	comp.window_opened.emit(13, "foot", "D", 503)
	_check("com o monitor cheio, a quarta vai para o vizinho", S.output_of(13) == 1 and S.free_slots() == 5)
	comp.calls.clear()
	_check("foco para a direita passa de monitor (a mais perto)", S.focused_window() == 13 and S.focus_direction(Vector2i.RIGHT) and S.focused_window() == 10)
	_check("tela cheia liga, põe por cima e desliga", S.toggle_fullscreen() and ["place", 10, 2, 0, 0, 1920, 1080] in comp.calls
			and ["raise", 10] in comp.calls and not S.toggle_fullscreen())
	_check("mover para o monitor 1 (saída 0)", S.move_focused_to(0) and S.output_of(10) == 0)
	_check("mover para onde já está é recusado", not S.move_focused_to(0))
	comp.closed_ids.clear()
	S.close_focused()
	_check("fechar a janela em foco pede ao app", comp.closed_ids == [10])
	comp.window_closed.emit(10)
	for i in 6:
		comp.window_opened.emit(20 + i, "foot", "Enche", 600 + i)
	_check("tudo cheio: nenhuma vaga", S.free_slots() == 0 and S.window_count() == 9)
	comp.window_opened.emit(30, "foot", "Sobra", 700)
	_check("a janela que não cabe é fechada", comp.closed_ids == [10, 30] and S.window_count() == 9)
	ended.clear()
	_check("launch avisa que os monitores estão cheios", not A.launch("foot", null) and ended.size() == 1
			and ended[0]["msg"].begins_with("Os monitores estão cheios"))
	for id in [11, 12, 13, 20, 21, 22, 23, 24, 25]:
		comp.window_closed.emit(id)
	_check("fechando tudo, as vagas voltam", S.free_slots() == 9 and S.window_count() == 0)

	print("== Sem monitores, a janela é fechada ==")
	desk.free()
	await process_frame
	comp.window_opened.emit(4, "foot", "Mais um", 301)
	_check("sem onde mostrar, a janela é fechada", comp.closed_ids.back() == 4 and S.app_of(4) == "" and S.window_count() == 0)
	_check("sem monitores, não abre no mundo", not S.can_open_in_world())

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
