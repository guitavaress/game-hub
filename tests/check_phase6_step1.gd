extends SceneTree
## Fase 6, etapa 1: horas jogadas no HUD e capas HD.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	var start := Time.get_ticks_msec()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	print("cidade pronta em %d ms (com leitura do localconfig.vdf)" % (Time.get_ticks_msec() - start))

	print("\n== textos do HUD ==")
	for child in city.get_children():
		if child.name.begins_with("Building_"):
			print("   ", child.get_node("GamePortal").get_look_label())

	print("\n== formatos ==")
	var portal_script = load("res://components/game_portal/game_info.gd")
	for m in [0, 1, 45, 60, 90, 150, 599, 600, 1436, 6000]:
		print("   %5d min -> %s" % [m, portal_script.format_playtime(m)])
	var now := int(Time.get_unix_time_from_system())
	for d in [0, 1, 2, 29, 31, 70, 400, 900]:
		print("   há %3d dias -> %s" % [d, portal_script.format_last_played(now - d * 86400)])

	print("\n== capas HD (esperando os downloads) ==")
	var art = root.get_node("GameArt")
	var waited := 0
	while (not art._active.is_empty() or not art._queue.is_empty()) and waited < 3600:
		await process_frame
		waited += 1
	await process_frame
	var hd := 0
	var total := 0
	for child in city.get_children():
		if child.name.begins_with("Building_"):
			total += 1
			var tex: Texture2D = child.get_node("Poster").material_override.albedo_texture
			if tex != null and tex.get_width() >= 600:
				hd += 1
			else:
				print("   sem HD: %s (%s)" % [child.game.name, "%dx%d" % [tex.get_width(), tex.get_height()] if tex else "sem capa"])
	print("   capas HD: %d de %d" % [hd, total])
	_check("todas as capas em HD", hd == total)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
