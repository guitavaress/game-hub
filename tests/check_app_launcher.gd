extends SceneTree
## Teste do AppLauncher (Fase 14.6) com abridor e janelas FALSOS: nenhum app é
## aberto de verdade e nenhuma janela é tocada.

const BALATRO: int = 2379780

var A: Node  # AppLauncher
var L: Node  # GameLauncher
var H: Node  # HubWindow
var F: Node  # ScreenFade
var failures := 0
var opened: Array[String] = []
var ended: Array = []
var started: Array = []
## O que a janela falsa responde: o endereço do app ("" = ainda não apareceu) e se existe.
var fake_address: String = ""
var fake_exists: bool = true
var tracks: bool = true
var open_ok: bool = true
var config_backup: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	A = root.get_node("AppLauncher")
	L = root.get_node("GameLauncher")
	H = root.get_node("HubWindow")
	F = root.get_node("ScreenFade")
	var library: Node = root.get_node("AppLibrary")
	config_backup = FileAccess.get_file_as_string(root.get_node("AppConfig").CONFIG_PATH)
	L._poll_timer.paused = true

	var brave := _app("brave-origin", "Brave Origin", "brave-origin")
	var foot := _app("foot", "Foot", "")
	var all: Array[DesktopApp] = [brave, foot]
	library.set_apps(all)

	A.threaded = false
	A.opener = func(app: DesktopApp) -> bool:
		opened.append(app.id)
		return open_ok
	A.can_track = func() -> bool: return tracks
	A.list_windows = func() -> PackedStringArray: return PackedStringArray(["0xaa"])
	A.window_reader = func(before: PackedStringArray, wm_class: String, address: String) -> Dictionary:
		_seen_before = before
		_seen_class = wm_class
		if address.is_empty():
			return {"address": fake_address, "exists": true}
		return {"address": address, "exists": fake_exists}
	A.app_session_ended.connect(func(id: String, source: Node, ok: bool, msg: String) -> void:
		ended.append({"id": id, "source": source, "ok": ok, "msg": msg}))
	A.app_launch_started.connect(func(id: String, _source: Node) -> void: started.append(id))
	L.url_opener = func(_url: String) -> int: return OK

	print("== sessão completa (acompanhando a janela) ==")
	var origin := Node.new()
	_check("launch devolve true", A.launch("brave-origin", origin))
	_check("o abridor recebeu o app certo", opened == ["brave-origin"])
	_check("app_launch_started avisou", started == ["brave-origin"])
	_check("LAUNCHING e o hub dorme", A.state == A.State.LAUNCHING and H.is_sleeping and A.is_busy())
	_check("a tela 'Abrindo' mostra o nome do app",
			F.game_screen.visible and F.game_screen.get_mode() == "abrindo" and F.game_screen.get_title() == "BRAVE ORIGIN")
	_check("o app sobe para o começo da estante", library.apps[0].id == "brave-origin")
	A._poll()
	_check("janela ainda não apareceu: continua LAUNCHING", A.state == A.State.LAUNCHING)
	_check("a consulta recebeu a foto de antes e a classe da janela",
			_seen_before == PackedStringArray(["0xaa"]) and _seen_class == "brave-origin")
	fake_address = "0xbb"
	A._poll()
	_check("achou a janela: RUNNING e acompanhando", A.state == A.State.RUNNING and A.is_tracking_window())
	A._poll()
	_check("janela aberta: continua RUNNING", A.state == A.State.RUNNING and ended.is_empty())
	fake_exists = false
	A._poll()
	_check("janela sumiu: sessão acaba com sucesso e o hub acorda",
			A.state == A.State.IDLE and not H.is_sleeping and ended.size() == 1 and ended[0].ok and ended[0].source == origin)
	_check("o sinal traz o id do app", ended[0].id == "brave-origin")
	_check("só a sessão acabou uma vez", ended.size() == 1)
	origin.free()

	print("== janela nunca aparece (sem acompanhar) ==")
	_reset()
	A.launch("foot")
	A._poll()
	_check("logo no começo: ainda LAUNCHING", A.state == A.State.LAUNCHING)
	A._launch_started_ms -= 11000
	A._poll()
	_check("passou de 10 s: RUNNING sem acompanhar", A.state == A.State.RUNNING and not A.is_tracking_window())
	A._poll()
	_check("sem janela para olhar, a sessão não acaba sozinha", A.state == A.State.RUNNING and ended.is_empty())
	H.focus_returned.emit()
	_check("o hub ganhou foco de volta: sessão acaba e o hub acorda",
			A.state == A.State.IDLE and not H.is_sleeping and ended.size() == 1 and ended[0].ok)

	print("== sistema que não acompanha janelas ==")
	_reset()
	tracks = false
	A.launch("foot")
	_check("não pede a foto das janelas", A._before.is_empty())
	A._poll()
	_check("antes de 10 s: continua LAUNCHING", A.state == A.State.LAUNCHING)
	A._launch_started_ms -= 11000
	A._poll()
	_check("depois de 10 s: RUNNING sem acompanhar", A.state == A.State.RUNNING and not A.is_tracking_window())
	H.wake()
	_check("qualquer acordar do hub encerra a sessão (uma vez só)",
			A.state == A.State.IDLE and ended.size() == 1 and ended[0].ok)
	tracks = true

	print("== cancelar com Esc ==")
	_reset()
	A.launch("foot")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	A._unhandled_input(esc)
	_check("Esc cancela: IDLE, hub acordado, erro com 'cancelou'",
			A.state == A.State.IDLE and not H.is_sleeping and ended.size() == 1
			and not ended[0].ok and ended[0].msg.contains("cancelou"))
	A.cancel_launch()
	_check("cancelar de novo não faz nada", ended.size() == 1)
	A.launch("foot")
	fake_address = "0xcc"
	A._poll()
	A._unhandled_input(esc)
	_check("Esc depois que o app abriu não encerra", A.state == A.State.RUNNING)
	A.cancel_launch()
	H.focus_returned.emit()
	_check("(limpeza) sessão encerrada pelo foco", A.state == A.State.IDLE)

	print("== recusas ==")
	_reset()
	L.state = L.State.RUNNING
	_check("com um jogo rodando, recusa", not A.launch("foot") and opened.is_empty())
	_check("a recusa também vira app_session_ended (erro)", ended.size() == 1 and not ended[0].ok and started.is_empty())
	L.state = L.State.IDLE
	_reset()
	_check("app que não está na lista: recusa", not A.launch("nao-existe") and opened.is_empty()
			and ended.size() == 1 and not ended[0].ok)
	_reset()
	open_ok = false
	_check("o sistema recusou abrir: erro, nada dorme", not A.launch("foot") and not H.is_sleeping
			and A.state == A.State.IDLE and ended.size() == 1 and not ended[0].ok
			and ended[0].msg.contains("Não consegui abrir Foot") and started.is_empty())
	open_ok = true
	_reset()
	A.launch("foot")
	_check("com um app abrindo, recusa outro", not A.launch("brave-origin") and ended.size() == 1 and not ended[0].ok)
	var game_ended: Array = []
	L.session_ended.connect(func(_id: int, _s: Node, ok: bool, msg: String) -> void: game_ended.append({"ok": ok, "msg": msg}))
	_check("o GameLauncher também recusa enquanto o app está ocupado",
			not L.launch(BALATRO) and game_ended.size() == 1 and not game_ended[0].ok)
	A.cancel_launch()

	print("== cada launch tem um fim ==")
	_reset()
	for i in 3:
		A.launch("foot")
		A.cancel_launch()
	A.launch("nao-existe")
	_check("4 pedidos, 4 sinais de fim", ended.size() == 4)

	print("== consulta de uma sessão velha não vale ==")
	_reset()
	A.launch("foot")
	var old_session: int = A._session_number
	A.cancel_launch()
	A._on_windows_read({"address": "0xdd", "exists": true}, old_session)
	_check("resultado velho é ignorado", A.state == A.State.IDLE)

	print("== com o icone pronto, a tela mostra o ícone ==")
	var screen = F.game_screen
	screen.show_app_opening("Foot", null)
	_check("sem ícone: o nome grande aparece", screen.get_mode() == "abrindo" and not screen._logo.visible and screen._name_label.visible)
	screen.show_app_opening("Foot", ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8)))
	_check("com ícone: ele ocupa o lugar do logo", screen._logo.visible and not screen._name_label.visible
			and screen.get_status() == "Abrindo Foot…")
	_check("apps não mostram o hero de jogo", not screen._hero.visible)

	var file := FileAccess.open(root.get_node("AppConfig").CONFIG_PATH, FileAccess.WRITE)
	file.store_string(config_backup)
	file.close()
	root.get_node("AppConfig")._config.load(root.get_node("AppConfig").CONFIG_PATH)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


var _seen_before: PackedStringArray = PackedStringArray()
var _seen_class: String = ""


func _app(id: String, app_name: String, wm_class: String) -> DesktopApp:
	var app := DesktopApp.new()
	app.id = id
	app.name = app_name
	app.wm_class = wm_class
	return app


func _reset() -> void:
	opened.clear()
	ended.clear()
	started.clear()
	fake_address = ""
	fake_exists = true
	if A.state != A.State.IDLE:
		A.cancel_launch()
		if A.state != A.State.IDLE:
			H.wake()
	ended.clear()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
