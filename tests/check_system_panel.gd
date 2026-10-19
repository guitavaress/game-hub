extends SceneTree
## Teste do painel do sistema da casa (Fase 14.9), com um SystemStatus de mentira:
##   - o painel está na casa, fixo na parede norte, acima do computador;
##   - os textos de hora, data, bateria, Wi-Fi e volume;
##   - some o que o sistema não sabe (sem bateria, sem nada);
##   - a hora muda quando o relógio muda.

var failures := 0


func _initialize() -> void:
	_run()


## Um estado de mentira no formato do SystemInfo.
func _state(battery: Dictionary, network: Dictionary, volume: Dictionary) -> Dictionary:
	return {"battery": battery, "network": network, "volume": volume}


func _run() -> void:
	await process_frame
	var status: Node = root.get_node("SystemStatus")
	# As classes são carregadas por load(): citar SystemPanel/Home direto faria a
	# Godot compilar o teste antes de os autoloads existirem.
	var panel_script: GDScript = load("res://worlds/home/system_panel.gd")
	var home_script: GDScript = load("res://worlds/home/home.gd")
	var desk_script: GDScript = load("res://worlds/home/computer_desk.gd")
	var home: Node3D = home_script.new()
	root.add_child(home)
	await process_frame

	print("== o painel na casa ==")
	var panel = home.get_system_panel()
	var desk: Node3D = home.get_node("ComputerDesk")
	_check("a casa tem o painel do sistema", panel != null and panel.is_in_group("system_panel"))
	_check("está na parede norte", is_equal_approx(panel.position.z, -home_script.ROOM_SIZE.z / 2.0))
	_check("fica em cima do computador (mesmo x)", is_equal_approx(panel.position.x, desk.position.x))
	_check("acima do monitor", panel_script.CENTER_Y - panel_script.PANEL_SIZE.y / 2.0 > desk_script.SCREEN_HEIGHT + desk_script.SCREEN_SIZE.y / 2.0)
	_check("cabe abaixo do teto", panel_script.CENTER_Y + panel_script.PANEL_SIZE.y / 2.0 < home_script.ROOM_SIZE.y)
	_check("escuta o SystemStatus", status.changed.is_connected(panel.refresh))

	print("== hora e data ==")
	panel.clock = func() -> Dictionary: return {"year": 2026, "month": 10, "day": 14, "weekday": 3, "hour": 9, "minute": 5, "second": 0}
	panel.refresh_clock()
	_check("hora HH:MM", panel.get_time_text() == "09:05")
	_check("dia da semana e data", panel.get_date_text() == "qua, 14 out")
	panel.clock = func() -> Dictionary: return {"year": 2026, "month": 12, "day": 1, "weekday": 2, "hour": 23, "minute": 59, "second": 0}
	panel.refresh_clock()
	_check("a hora muda com o relógio", panel.get_time_text() == "23:59" and panel.get_date_text() == "ter, 1 dez")

	print("== tudo conhecido ==")
	status.apply(_state({"present": true, "percent": 67, "charging": false},
			{"known": true, "type": "wifi", "connected": true, "name": "Casa"},
			{"known": true, "percent": 45, "muted": false}))
	_check("três linhas, na ordem", panel.get_visible_rows() == ["battery", "network", "volume"])
	_check("textos certos", panel.get_row_texts() == ["Bateria 67%", "Wi-Fi · Casa", "Volume 45%"])

	print("== carregando, cabo, mudo ==")
	status.apply(_state({"present": true, "percent": 100, "charging": true},
			{"known": true, "type": "ethernet", "connected": true, "name": "Cabo 1"},
			{"known": true, "percent": 30, "muted": true}))
	_check("carregando / cabo / mudo", panel.get_row_texts() == ["Carregando 100%", "Cabo · Cabo 1", "Volume mudo"])

	print("== sem rede e nome comprido ==")
	status.apply(_state({"present": true, "percent": 10, "charging": false},
			{"known": true, "type": "none", "connected": false, "name": ""},
			{"known": true, "percent": 0, "muted": false}))
	_check("sem rede", panel.get_row_texts() == ["Bateria 10%", "Sem rede", "Volume 0%"])
	status.apply(_state({"present": false, "percent": 0, "charging": false},
			{"known": true, "type": "wifi", "connected": true, "name": "Uma rede com um nome muito comprido"},
			{"known": false, "percent": 0, "muted": false}))
	var long_text: String = panel.get_row_texts()[0]
	_check("nome comprido é cortado com …", long_text.ends_with("…") and long_text.length() <= "Wi-Fi · ".length() + panel_script.MAX_NAME)

	print("== desktop sem bateria ==")
	status.apply(_state({"present": false, "percent": 0, "charging": false},
			{"known": true, "type": "ethernet", "connected": true, "name": "Cabo"},
			{"known": true, "percent": 80, "muted": false}))
	_check("a linha da bateria some e as outras sobem", panel.get_visible_rows() == ["network", "volume"])
	var first_row: Label3D = null
	for child in panel.get_node("Rows").get_children():
		if child is Label3D:
			first_row = child
			break
	_check("a primeira linha ocupa o lugar de cima", first_row != null and is_equal_approx(first_row.position.y, panel_script.CENTER_Y + panel_script.FIRST_ROW_Y))

	print("== o sistema não sabe de nada ==")
	status.apply(SystemInfoBackend.unknown())
	_check("nenhuma linha, mas a hora continua", panel.get_visible_rows().is_empty() and panel.get_time_text() == "23:59")

	print("== a cor do néon ==")
	home.get_system_panel().set_accent(Color(0.2, 0.8, 1.0))
	_check("trocar a cor refaz a borda sem duplicar", panel.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Board")).size() == 1)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
