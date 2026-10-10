extends SceneTree
## Teste do SettingsView (Fase 9.6): monta a tela de configurações sozinha,
## sem menu de pausa, e confere que mexer nela grava no config.cfg.
## Guarda o config.cfg antes e devolve no fim. Nunca salva uma chave de API.

const CONFIG := "user://config.cfg"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var backup := FileAccess.get_file_as_string(CONFIG)
	await process_frame
	var app = root.get_node("AppConfig")
	var view_script: GDScript = load("res://ui/settings_view.gd")
	var view = view_script.new()  # sem tipo: a classe usa autoloads
	root.add_child(view)
	await process_frame

	print("\n== montagem ==")
	_check("três abas e três páginas", view._tab_buttons.size() == 3 and view._pages.size() == 3)
	_check("só a primeira página aparece", view._pages[0].visible and not view._pages[1].visible)
	view.refresh()
	var shown: bool = app.get_show_map()
	_check("refresh() traz o valor do config", view._map_check.button_pressed == shown)

	print("\n== qualidade ==")
	var old_quality: String = app.get_quality()
	var other := "leve" if old_quality != "leve" else "alta"
	view._quality_buttons[other].pressed.emit()
	_check("mudou na memória", app.get_quality() == other)
	_check("gravou no config.cfg", ('quality="%s"' % other) in FileAccess.get_file_as_string(CONFIG))

	print("\n== bússola e mapa ==")
	view._map_check.button_pressed = not shown
	_check("mudou na memória", app.get_show_map() == (not shown))
	_check("gravou no config.cfg", ("show_map=%s" % str(not shown).to_lower()) in FileAccess.get_file_as_string(CONFIG))

	print("\n== teclas ==")
	var has_interact := false
	for row in view_script.CONTROL_ROWS:
		if row[0] == "E":
			has_interact = true
	_check("linha nova do E (interagir)", has_interact)

	view.queue_free()
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	_check("config.cfg restaurado", FileAccess.get_file_as_string(CONFIG) == backup)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
