extends SceneTree
## Teste do quadro de estatísticas (Fase 13.7): StatsWall com a biblioteca falsa.
##   - as linhas mostram os mesmos números do LibraryStats;
##   - as três mensagens (biblioteca vazia, horas desconhecidas, nenhuma hora);
##   - ao voltar de um jogo (HubWindow.woke_up) o quadro se atualiza;
##   - com 200 jogos, nada passa da moldura;
##   - o quadro está na casa, na âncora da disposição.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var fake = load("res://tests/fake_library.gd")
	var categories := root.get_node("GameCategories")
	var home: Node3D = (load("res://worlds/home/home.gd") as GDScript).new()
	root.add_child(home)
	await process_frame

	print("== o quadro na casa ==")
	var wall = home.get_furniture("estatisticas")
	_check("a casa tem o quadro de estatísticas", wall != null and wall.is_in_group("stats_wall"))
	var anchor: Transform3D = home.get_anchor_transform(home.get_layout().placements["estatisticas"])
	_check("ele está na âncora da disposição", wall.position.is_equal_approx(anchor.origin))
	_check("o quadro escuta a volta de um jogo (woke_up)", root.get_node("HubWindow").woke_up.is_connected(wall.refresh))

	print("== horas conhecidas, 200 jogos ==")
	var games: Array = fake.install(root, 200)
	var minutes := {}
	for i in games.size():
		minutes[games[i].app_id] = (i % 40) * 30
	var last_game: SteamGame = games[7]
	fake.set_playtimes(root, minutes, {last_game.app_id: 2000000000})
	wall.refresh()
	var stats: Dictionary = wall.get_stats()
	var texts: Array[String] = wall.get_texts()
	_check("título", texts.has("SUA BIBLIOTECA"))
	_check("o total é o do LibraryStats (%s)" % wall.format_hours(stats["total_minutes"]), texts.has(wall.format_hours(stats["total_minutes"])))
	var top: Array = stats["top"]
	var top_ok := top.size() == 5
	for game: Dictionary in top:
		top_ok = top_ok and texts.has(wall.format_hours(game["minutes"])) and texts.has(wall._shorten(game["name"], 15))
	_check("os 5 mais jogados, com nome e horas", top_ok)
	var district_ok := true
	var shown := 0
	for entry: Dictionary in stats["districts"].slice(0, wall.DISTRICT_ROWS):
		shown += 1
		district_ok = district_ok and texts.has(wall.format_hours(entry["minutes"])) and texts.has(wall._shorten(entry["name"], 12))
	_check("os %d maiores bairros, com horas" % shown, district_ok and shown == wall.DISTRICT_ROWS)
	_check("o jogado por último aparece", texts.has(wall._shorten(last_game.name, 22)) and wall.get_node("Content/Cover") != null)
	_check("sem mensagem de erro", not texts.has(wall.UNKNOWN_HOURS_TEXT) and not texts.has(wall.NO_HOURS_TEXT))
	# A barra do bairro com mais horas é a mais comprida e não passa do máximo.
	var longest := 0.0
	var inside := true
	var panel := Rect2(-wall.PANEL_SIZE.x / 2.0, wall.CENTER_Y - wall.PANEL_SIZE.y / 2.0, wall.PANEL_SIZE.x, wall.PANEL_SIZE.y)
	for bar in wall.get_bars():
		var size: Vector3 = (bar.mesh as BoxMesh).size
		longest = maxf(longest, size.x)
		inside = inside and panel.encloses(Rect2(bar.position.x - size.x / 2.0, bar.position.y - size.y / 2.0, size.x, size.y))
	_check("as barras não passam do máximo (%.2f m)" % longest, longest <= wall.DISTRICT_BAR_MAX + 0.001)
	_check("todas as barras ficam dentro da moldura (%d barras)" % wall.get_bars().size(), inside and wall.get_bars().size() >= 8)
	_check("os textos ficam dentro da moldura", _labels_inside(wall, panel))
	var neon: Color = categories.get_neon_color(stats["districts"][0]["id"])
	var bar_color := false
	for bar in wall.get_bars():
		if (bar.material_override as StandardMaterial3D).emission.is_equal_approx(neon):
			bar_color = true
	_check("a barra do maior bairro tem a cor de néon dele", bar_color)

	print("== atualiza com horas novas ==")
	var old_total: int = stats["total_minutes"]
	minutes[games[1].app_id] = 99999
	fake.set_playtimes(root, minutes, {last_game.app_id: 2000000000})
	wall.refresh()
	_check("o total mudou", wall.get_stats()["total_minutes"] == old_total - 30 + 99999
			and wall.get_texts().has(wall.format_hours(old_total - 30 + 99999)))

	print("== horas desconhecidas ==")
	fake.set_playtimes(root, {})
	wall.refresh()
	texts = wall.get_texts()
	_check("total \"—\"", texts.has("—"))
	_check("dica para entrar na conta da Steam", texts.has(wall.UNKNOWN_HOURS_TEXT))
	_check("os bairros mostram quantos jogos têm", texts.any(func(t: String) -> bool: return t.ends_with(" jogos")))
	_check("nenhuma hora inventada", not texts.any(func(t: String) -> bool: return t.ends_with(" h") or t.ends_with(" min")))

	print("== nenhuma hora jogada ==")
	var zeros := {}
	for game: SteamGame in games:
		zeros[game.app_id] = 0
	fake.set_playtimes(root, zeros)
	wall.refresh()
	texts = wall.get_texts()
	_check("total \"0 h\"", texts.has("0 h"))
	_check("mensagem de nenhuma hora", texts.has(wall.NO_HOURS_TEXT))
	_check("bairros pela contagem de jogos", texts.any(func(t: String) -> bool: return t.ends_with(" jogos")))

	print("== biblioteca vazia ==")
	fake.install(root, 0)
	wall.refresh()
	texts = wall.get_texts()
	_check("mensagem de nenhum jogo", texts.has(wall.NO_GAMES_TEXT))
	_check("só o título e a mensagem", texts.size() == 2 and wall.get_bars().is_empty())

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## Os textos de uma linha começam dentro do quadro (a linha curta não passa da borda direita).
func _labels_inside(wall: Node3D, panel: Rect2) -> bool:
	for node in wall.get_node("Content").get_children():
		if node is Label3D:
			var label := node as Label3D
			if label.width > 0.0 and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				continue
			var extent := label.get_aabb()
			var left := label.position.x + extent.position.x
			var right := label.position.x + extent.end.x
			if left < panel.position.x - 0.01 or right > panel.end.x + 0.01:
				print("    fora: ", label.text, " (", left, ", ", right, ")")
				return false
	return true


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
