extends SceneTree
## Teste da volta com resumo (P2.13). Steam FALSA: nenhum jogo abre de verdade.

const BALATRO := 2379780
const SKYRIM := 489830
const SUMMARIES_JSON := """{"response":{"players":[
 {"steamid":"76561190000000002","personaname":"Bruno","personastate":1,"gameid":"2379780"}
]}}"""

var L
var H
var F
var hud
var city: Node
var fake := {"running_app_id": 0, "steam_running": true, "app_running": false, "app_updating": false}
var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	city = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	for i in 30:
		await process_frame
	L = root.get_node("GameLauncher")
	H = root.get_node("HubWindow")
	F = root.get_node("ScreenFade")
	hud = city.get_node("Player").get_hud()
	L._poll_timer.paused = true
	L.state_reader = func(_id: int, _check: bool) -> Dictionary: return fake.duplicate()
	L.url_opener = func(_url: String) -> int: return OK
	var fs = root.get_node("FriendsService")
	var typed: Array[SteamFriend] = []
	typed.assign(fs.parse_players(JSON.parse_string(SUMMARIES_JSON)))
	fs._set_friends(typed)
	L._last_seen_running = 0

	print("\n== formato da duração ==")
	_check("12 min / 1 h 12 min / 2 h / 24 h", hud.format_duration(12) == "12 min"
		and hud.format_duration(72) == "1 h 12 min" and hud.format_duration(120) == "2 h"
		and hud.format_duration(1452, true) == "24 h")

	print("\n== jogou 1 h 12 min e fechou ==")
	hud.clear_messages()
	var before: int = root.get_node("SteamLibrary").get_playtime_minutes(BALATRO)
	L.launch(BALATRO, city.get_node("Building_%d/GamePortal" % BALATRO))
	fake.running_app_id = BALATRO
	await _poll()
	L._running_since_ms -= 72 * 60 * 1000
	fake.running_app_id = 0
	await _poll()
	await process_frame
	var toast = _session_toast()
	_check("aviso verde de sessão", toast != null and toast.get_meta("seconds") == 5.0)
	if toast != null:
		print("   ", toast.overline, " | ", toast.title, " | ", toast.text)
		_check("rótulo BEM-VINDO DE VOLTA", toast.overline == "BEM-VINDO DE VOLTA")
		_check("título '1 h 12 min de Balatro'", toast.title == "1 h 12 min de Balatro")
		var expected_total: String = hud.format_duration(before + 72, true) + " no total"
		_check("total = antes + sessão (" + expected_total + ")", toast.text.begins_with(expected_total))
		_check("Bruno ainda está jogando", toast.text.ends_with("Bruno ainda está jogando"))

	print("\n== a tela 'Jogando' se dissolve em 0,8 s ==")
	print("   cortina %.2f | tela do jogo visível %s modo '%s'" % [F.get_amount(), F.game_screen.visible, F.game_screen._mode])
	_check("dissolvendo a tela 'Jogando' (sem passar pelo preto)", F.get_amount() > 0.5
		and F.game_screen.visible and F.game_screen._mode == "jogando")
	await create_timer(0.4).timeout
	var middle: float = F.get_amount()
	await create_timer(0.6).timeout
	_check("no meio, transparente pela metade (%.2f)" % middle, middle > 0.2 and middle < 0.8)
	_check("no fim, sumiu", F.get_amount() < 0.01 and not F.game_screen.visible)

	print("\n== andar tira o aviso (depois de 1,5 s) ==")
	hud.on_player_moved()
	_check("ainda não saiu (pouco tempo)", _session_toast() != null or toast.get_age() > 1.5)
	await create_timer(0.7).timeout
	hud.on_player_moved()
	await process_frame
	_check("saiu ao andar", _session_toast() == null)

	print("\n== jogo que fecha logo: erro, sem resumo ==")
	hud.clear_messages()
	L.launch(BALATRO, city.get_node("Building_%d/GamePortal" % BALATRO))
	fake.running_app_id = BALATRO
	await _poll()
	fake.running_app_id = 0
	await _poll()
	await process_frame
	_check("sem aviso de sessão", _session_toast() == null and hud.get_messages().size() == 1)

	print("\n== troca direta de jogo: só um resumo, o do último ==")
	hud.clear_messages()
	await create_timer(0.9).timeout
	L.launch(BALATRO, city.get_node("Building_%d/GamePortal" % BALATRO))
	fake.running_app_id = BALATRO
	await _poll()
	L._running_since_ms -= 30 * 60 * 1000
	fake.running_app_id = SKYRIM
	await _poll()
	_check("hub continua dormindo, sem aviso", H.is_sleeping and _session_toast() == null)
	L._running_since_ms -= 5 * 60 * 1000
	fake.running_app_id = 0
	await _poll()
	await process_frame
	var last = _session_toast()
	_check("resumo do Skyrim (5 min)", last != null and last.title.begins_with("5 min de "))
	if last != null:
		print("   ", last.title, " | ", last.text)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _session_toast():
	for toast in hud._visible_toasts():
		if toast.kind == Toast.Kind.SESSION:
			return toast
	return null


func _poll() -> void:
	L._poll()
	while L._poll_task != -1:
		await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
