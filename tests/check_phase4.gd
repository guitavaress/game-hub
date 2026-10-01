extends SceneTree
## Teste da Fase 4 com uma Steam FALSA (nenhum jogo é aberto de verdade).

const BALATRO := 2379780
const SKYRIM := 489830
const STARDEW := 413150
const WALLPAPER := 431960   # escondido da cidade
const LOSSLESS := 993090    # escondido da cidade
const NOT_INSTALLED := 620

var L  # GameLauncher
var H  # HubWindow
var F  # ScreenFade
var city: Node
var player
var fake := {}
var opened: Array = []
var ended: Array = []
var started: Array = []
var failures := 0
var fps_before := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	city = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	for i in 30:
		await process_frame

	L = root.get_node("GameLauncher")
	H = root.get_node("HubWindow")
	F = root.get_node("ScreenFade")
	player = city.get_node("Player")
	L._poll_timer.paused = true  # nós decidimos quando olhar a "Steam"
	L.state_reader = func(_app_id: int, _check: bool) -> Dictionary: return fake.duplicate()
	L.url_opener = func(url: String) -> int:
		opened.append(url)
		return OK
	L.session_ended.connect(func(a, s, ok, m): ended.append({"app": a, "source": s, "ok": ok, "msg": m}))
	L.game_started.connect(func(a, s): started.append({"app": a, "source": s}))
	_steam(0)
	L._last_seen_running = -1
	fps_before = Engine.max_fps

	print("\n== A. primeira olhada (baseline) ==")
	await _poll()
	_check("continua IDLE", L.state == 0)

	print("\n== B. abrir e fechar normalmente ==")
	_clear()
	L.launch(BALATRO, _portal(BALATRO))
	_check("abriu steam://rungameid/%d" % BALATRO, opened.back() == "steam://rungameid/%d" % BALATRO)
	_check("LAUNCHING e dormindo", L.state == 1 and H.is_sleeping and paused)
	var gs = F.game_screen
	_check("tela 'Abrindo' com o nome", gs.visible and gs.get_mode() == "abrindo" and gs.get_title() == "BALATRO")
	_check("status 'Abrindo pela Steam…'", gs.get_status() == "Abrindo pela Steam…" and not L.steam_was_closed)
	_check("3D desligado e ainda sem minimizar (30 fps)", root.disable_3d and Engine.max_fps == H.COVERED_MAX_FPS)
	await _poll()
	_check("ainda LAUNCHING com RunningAppID=0", L.state == 1)
	_steam(BALATRO)
	await _poll()
	_check("RUNNING", L.state == 2 and started.size() == 1)
	_check("jogo apareceu -> minimizou (5 fps)", Engine.max_fps == H.SLEEP_MAX_FPS)
	_check("tela 'Jogando' com o nome", gs.visible and gs.get_mode() == "jogando" and gs.get_title() == "BALATRO")
	_check("rótulo 'JOGANDO AGORA'", "JOGANDO AGORA" in gs.get_status())
	_check("hero desfocada (480 px)", gs._blurred_hero.texture != null and gs._blurred_hero.texture.get_width() == 480)
	L._running_since_ms -= 3723000  # 1 h 2 min 3 s
	gs._update_playing_texts()
	_check("tempo da sessão 1:02:03", gs._session_time.text.begins_with("1:02:0"))
	print("   total: ", gs._total_time.text)
	_steam(0)
	await _poll()
	_check("IDLE, acordou, sucesso", L.state == 0 and not H.is_sleeping and not paused and ended.back().ok)
	_check("3D ligado de novo e fps restaurado", not root.disable_3d and Engine.max_fps == fps_before)
	await process_frame
	_check("jogador na porta do Balatro", _at_door(BALATRO))
	await create_timer(1.2).timeout
	_check("tela do jogo some depois do clarear", not gs.visible and F.get_amount() < 0.01)

	print("\n== C. jogo fecha logo depois de abrir ==")
	await _launch_and_run(BALATRO)
	_steam(0)
	await _poll()
	_check("falhou com 'fechou logo depois'", not ended.back().ok and "logo depois" in ended.back().msg)
	print("   msg: ", ended.back().msg)

	print("\n== D. tempo esgotado (jogo não abre) e depois abre atrasado ==")
	_clear()
	L.launch(BALATRO, _portal(BALATRO))
	L._launch_started_ms -= 91000
	await _poll()
	_check("falhou por tempo", L.state == 0 and not ended.back().ok and "não abriu em 90 s" in ended.back().msg)
	print("   msg: ", ended.back().msg)
	_steam(BALATRO)
	await _poll()
	_check("abriu atrasado -> sessão externa", L.state == 2 and L._external and H.is_sleeping)
	L._running_since_ms -= 60000
	_steam(0)
	await _poll()
	_check("voltou", L.state == 0 and ended.back().ok and ended.back().source == null)

	print("\n== E. tempo esgotado com o jogo atualizando ==")
	_clear()
	L.launch(BALATRO, _portal(BALATRO))
	fake.app_updating = true
	L._launch_started_ms -= 91000
	await _poll()
	_check("mensagem de atualização", "atualizando" in ended.back().msg)
	print("   msg: ", ended.back().msg)
	fake.app_updating = false

	print("\n== F. Steam fechada na hora de abrir ==")
	_clear()
	fake.steam_running = false
	L.launch(BALATRO, _portal(BALATRO))
	_check("espera 180 s", L._launch_timeout == 180.0)
	_check("status 'Abrindo a Steam…'", L.steam_was_closed and F.game_screen.get_status() == "Abrindo a Steam…")
	L._launch_started_ms -= 91000
	await _poll()
	_check("aos 91 s ainda espera", L.state == 1)
	L._launch_started_ms -= 90000
	await _poll()
	_check("aos 181 s: 'A Steam não abriu'", L.state == 0 and "Steam não abriu" in ended.back().msg)
	fake.steam_running = true

	print("\n== G. Steam morre durante o jogo ==")
	await _launch_and_run(BALATRO)
	fake.steam_running = false
	await _poll()
	_check("voltou com aviso", L.state == 0 and "Steam fechou" in ended.back().msg)
	print("   msg: ", ended.back().msg)
	fake.steam_running = true
	_steam(0)
	await _poll()

	print("\n== H. Lossless Scaling 'toma' o RunningAppID ==")
	await _launch_and_run(BALATRO)
	_steam(LOSSLESS)
	fake.app_running = true
	await _poll()
	_check("continua RUNNING (Apps\\Balatro\\Running = 1)", L.state == 2 and L._app_id == BALATRO)
	L._running_since_ms -= 60000
	fake.app_running = false
	await _poll()
	_check("fechou quando Running = 0", L.state == 0 and ended.back().ok)
	_steam(0)
	await _poll()

	print("\n== I. troca direta de jogo (Balatro -> Skyrim) ==")
	await _launch_and_run(BALATRO)
	_steam(SKYRIM)
	await _poll()
	_check("sessão do Balatro encerrada, hub continua dormindo",
		ended.back().app == BALATRO and ended.back().ok and H.is_sleeping and L._app_id == SKYRIM and L.state == 2)
	_check("tela continua preta", F.get_amount() > 0.99)
	_check("tela 'Jogando' trocou para o Skyrim", F.game_screen.get_mode() == "jogando" and F.game_screen._app_id == SKYRIM)
	L._running_since_ms -= 60000
	_steam(0)
	await _poll()
	await process_frame
	_check("voltou na porta do Skyrim", L.state == 0 and not H.is_sleeping and _at_door(SKYRIM))

	print("\n== J. jogo aberto por fora do hub (Stardew) ==")
	_clear()
	_steam(STARDEW)
	await _poll()
	_check("hub dormiu", L.state == 2 and L._external and H.is_sleeping)
	_check("externo: ainda visível (30 fps)", Engine.max_fps == H.COVERED_MAX_FPS)
	_check("externo: 'ABRIU PELA STEAM' + nome", "ABRIU PELA STEAM" in F.game_screen.get_status()
		and F.game_screen.get_title() == "STARDEW VALLEY")
	await create_timer(L.EXTERNAL_NOTICE_SECONDS + 0.3).timeout
	_check("externo: minimizou depois de 1,5 s (5 fps)", Engine.max_fps == H.SLEEP_MAX_FPS)
	L._running_since_ms -= 60000
	F.game_screen._update_playing_texts()
	_check("externo: depois vira 'JOGANDO AGORA'", "JOGANDO AGORA" in F.game_screen.get_status())
	_steam(0)
	await _poll()
	await process_frame
	_check("voltou na porta do Stardew", L.state == 0 and _at_door(STARDEW))

	print("\n== K. app fora da cidade (Wallpaper Engine) é ignorado ==")
	_steam(WALLPAPER)
	await _poll()
	_check("continua IDLE", L.state == 0 and not H.is_sleeping)
	_steam(0)
	await _poll()

	print("\n== L. jogo que já estava aberto antes do hub é ignorado ==")
	L._last_seen_running = -1
	_steam(STARDEW)
	await _poll()
	_check("continua IDLE", L.state == 0)
	_steam(0)
	await _poll()

	print("\n== M. Esc cancela a espera ==")
	_clear()
	L.launch(BALATRO, _portal(BALATRO))
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_check("cancelou", L.state == 0 and not H.is_sleeping and "cancelou" in ended.back().msg)

	print("\n== N. jogo não instalado ==")
	_clear()
	L.launch(NOT_INSTALLED, _portal(BALATRO))
	_check("recusou sem abrir nem dormir", opened.is_empty() and not H.is_sleeping and "não está mais instalado" in ended.back().msg)
	print("   msg: ", ended.back().msg)

	print("\n== O. pedido enquanto outro jogo abre ==")
	_clear()
	L.launch(BALATRO, _portal(BALATRO))
	L.launch(SKYRIM, _portal(SKYRIM))
	_check("recusou o segundo", ended.back().app == SKYRIM and "Já existe" in ended.back().msg and L._app_id == BALATRO)
	L.cancel_launch()

	print("\n== P. jogo demora: minimiza sozinho no tempo-limite ==")
	_clear()
	_steam(0)
	L.launch(BALATRO, _portal(BALATRO))
	L._minimize_after(0.2)  # no lugar dos 10 s
	await create_timer(0.4).timeout
	_check("minimizou, ainda LAUNCHING", L.state == 1 and Engine.max_fps == H.SLEEP_MAX_FPS)
	L.cancel_launch()

	print("\n== Q. 'minimizar depois' de uma sessão velha não vale ==")
	_clear()
	L.launch(BALATRO, _portal(BALATRO))
	L._minimize_after(0.2)
	L.cancel_launch()
	L.launch(BALATRO, _portal(BALATRO))  # nova sessão (timer de 10 s)
	await create_timer(0.4).timeout
	_check("não minimizou", L.state == 1 and Engine.max_fps == H.COVERED_MAX_FPS)
	L.cancel_launch()

	await process_frame
	print("\n== leitor REAL (sua Steam agora): ", L._read_steam_state(BALATRO, true))
	print("== HUD: '", player.get_hud().get_messages(), "'")
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


# --- Ajudantes ---------------------------------------------------------------

func _steam(running_app_id: int) -> void:
	fake = {"running_app_id": running_app_id, "steam_running": fake.get("steam_running", true),
		"app_running": fake.get("app_running", false), "app_updating": fake.get("app_updating", false)}


func _poll() -> void:
	L._poll()
	while L._poll_task != -1:
		await process_frame


func _launch_and_run(app_id: int) -> void:
	_clear()
	_steam(0)
	L.launch(app_id, _portal(app_id))
	_steam(app_id)
	await _poll()


func _portal(app_id: int) -> Node:
	return city.get_node("Building_%d/GamePortal" % app_id)


func _at_door(app_id: int) -> bool:
	return player.global_position.distance_to(_portal(app_id).get_return_transform().origin) < 0.3


func _clear() -> void:
	opened.clear()
	started.clear()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
