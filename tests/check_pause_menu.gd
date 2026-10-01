extends SceneTree
## Teste do menu de pausa (P2.12). Guarda o config.cfg antes e devolve no fim.
## NUNCA salva uma chave de API (só testa a recusa de uma chave inválida).

const CONFIG := "user://config.cfg"

var failures := 0
var backup := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	backup = FileAccess.get_file_as_string(CONFIG)
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	for i in 60:
		await process_frame
	var app = root.get_node("AppConfig")
	var fade = root.get_node("ScreenFade")
	var player = city.get_node("Player")
	var menu = player.get_pause_menu()
	var lines_before := FileAccess.get_file_as_string(CONFIG).split("\n").size()

	print("\n== Esc abre e fecha ==")
	await _esc()
	_check("abriu e pausou", menu.is_open() and paused)
	await _esc()
	_check("fechou e despausou", not menu.is_open() and not paused)

	print("\n== não abre durante a espera na porta ==")
	fade.set_door_charge(0.5, "Teste", Color.WHITE)
	await _esc()
	_check("continua fechado", not menu.is_open())
	fade.set_door_charge(0.0)

	print("\n== volume ==")
	menu.open()
	var old_effects: float = app.get_volume("Efeitos")
	menu._volume_sliders["Efeitos"].value = 37.0
	var bus := AudioServer.get_bus_index("Efeitos")
	_check("vale na hora (memória e canal)", is_equal_approx(app.get_volume("Efeitos"), 0.37)
		and absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.37)) < 0.01)
	_check("ainda não gravou", not "effects_volume=0.37" in FileAccess.get_file_as_string(CONFIG))
	menu.close()
	var text := FileAccess.get_file_as_string(CONFIG)
	_check("gravou ao fechar", "effects_volume=0.37" in text)
	_check("comentários preservados", "; Passos, portal, avisos." in text and "; Chave da Steam Web API" in text)

	print("\n== qualidade ==")
	menu.open()
	var env: Environment = city._environment
	menu._quality_buttons["leve"].pressed.emit()
	_check("leve: sem SSR/SSAO, 3D em 50%", app.get_quality() == "leve" and not env.ssr_enabled
		and not env.ssao_enabled and is_equal_approx(root.scaling_3d_scale, 0.5))
	menu._quality_buttons["media"].pressed.emit()
	_check("média: SSAO sim, SSR não, 3D 100%", not env.ssr_enabled and env.ssao_enabled
		and is_equal_approx(root.scaling_3d_scale, 1.0))
	menu._quality_buttons["alta"].pressed.emit()
	_check("alta: tudo ligado", env.ssr_enabled and env.ssao_enabled)
	_check("gravou quality=\"alta\"", "quality=\"alta\"" in FileAccess.get_file_as_string(CONFIG))
	print("   dica: ", menu._quality_hint.text)

	print("\n== hora ==")
	menu._time_buttons["noite"].pressed.emit()
	var hour: float = city._day_night.current_hour()
	_check("noite fixa = 22h", absf(hour - 22.0) < 0.01 and city._day_night.get_night() > 0.9)
	menu._time_buttons["dia"].pressed.emit()
	_check("dia fixo = 14h", absf(city._day_night.current_hour() - 14.0) < 0.01 and city._day_night.get_night() < 0.1)
	menu._time_buttons["relogio"].pressed.emit()
	_check("volta ao relógio", app.get_time_of_day() == "relogio")

	print("\n== amigos: chave inválida é recusada ==")
	var key_before: String = app.get_web_api_key()
	menu._show_page(2)
	_check("só a aba Amigos marcada", menu._tab_buttons[2].button_pressed
		and not menu._tab_buttons[0].button_pressed and menu._pages[2].visible and not menu._pages[0].visible)
	menu._key_field.text = "abc"
	menu._save_friends()
	_check("recusou sem gravar", app.get_web_api_key() == key_before and "32" in menu._friends_status.text)
	print("   status: ", menu._friends_status.text)
	_check("campo da chave é secreto", menu._key_field.secret)
	menu._key_field.text = ""
	menu.close()

	var lines_after := FileAccess.get_file_as_string(CONFIG).split("\n").size()
	_check("arquivo com o mesmo número de linhas", lines_after == lines_before)

	# Devolve o config.cfg como estava.
	app.set_volume("Efeitos", old_effects, false)
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	_check("config.cfg restaurado", FileAccess.get_file_as_string(CONFIG) == backup)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _esc() -> void:
	var esc := InputEventAction.new()
	esc.action = "release_mouse"
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
