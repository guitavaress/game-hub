extends SceneTree
## Teste dos números das estatísticas (Fase 13.5): LibraryStats com a biblioteca falsa.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var fake = load("res://tests/fake_library.gd")
	var stats = load("res://components/library_stats/library_stats.gd")
	var library := root.get_node("SteamLibrary")
	var categories := root.get_node("GameCategories")

	# --- Horas exatas, para conferir as contas à mão ---
	var games: Array = fake.install(root, 200)
	var minutes: Dictionary = {}
	var expected_total := 0
	var by_district: Dictionary = {}  # id → [minutos, jogos]
	for i in games.size():
		var game: SteamGame = games[i]
		var m := (i % 40) * 30  # 0, 30, 60... (1 em cada 40 com zero)
		minutes[game.app_id] = m
		expected_total += m
		var id: String = categories.get_category_id(game.app_id)
		var entry: Array = by_district.get(id, [0, 0])
		entry[0] += m
		entry[1] += 1
		by_district[id] = entry
	var last_game: SteamGame = games[7]
	fake.set_playtimes(root, minutes, {last_game.app_id: 2000000000, games[3].app_id: 1900000000})

	var result: Dictionary = stats.compute()
	_check("conta os 200 jogos instalados", result["game_count"] == 200)
	_check("as horas são conhecidas", result["hours_known"] == true)
	_check("o total confere (%d min)" % expected_total, result["total_minutes"] == expected_total)
	_check("alguém foi jogado", result["played_any"] == true)

	var top: Array = result["top"]
	_check("o top tem só 5", top.size() == 5)
	var top_sorted := true
	for i in range(1, top.size()):
		if top[i]["minutes"] > top[i - 1]["minutes"]:
			top_sorted = false
	_check("o top vem do mais para o menos jogado", top_sorted)
	var best := 0
	for m: int in minutes.values():
		best = maxi(best, m)
	_check("o primeiro do top é o maior (%d min)" % best, top[0]["minutes"] == best)
	_check("o top só tem quem foi jogado", top.all(func(t: Dictionary) -> bool: return t["minutes"] > 0))
	_check("o top traz nome e app_id", not String(top[0]["name"]).is_empty() and top[0]["app_id"] > 0)

	var districts: Array = result["districts"]
	var sum_minutes := 0
	var sum_games := 0
	var ordered := true
	var matches := true
	for i in districts.size():
		var d: Dictionary = districts[i]
		sum_minutes += d["minutes"]
		sum_games += d["games"]
		if i > 0 and d["minutes"] > districts[i - 1]["minutes"]:
			ordered = false
		if not by_district.has(d["id"]) or by_district[d["id"]] != [d["minutes"], d["games"]]:
			matches = false
	_check("as horas de cada bairro conferem", matches and districts.size() == by_district.size())
	_check("os bairros vêm na ordem das horas", ordered)
	_check("as horas dos bairros somam o total", sum_minutes == expected_total)
	_check("os jogos dos bairros somam 200", sum_games == 200)
	_check("só aparecem bairros com jogos", districts.all(func(d: Dictionary) -> bool: return d["games"] > 0))
	_check("o bairro tem nome para mostrar", not String(districts[0]["name"]).is_empty())

	var last: Dictionary = result["last_played"]
	_check("o último jogado é o de data maior", last.get("app_id", 0) == last_game.app_id and last.get("time", 0) == 2000000000)
	_check("o último jogado traz o nome", last.get("name", "") == last_game.name)

	# --- Horas desconhecidas (-1): a contagem por bairro continua ---
	fake.set_playtimes(root, {})
	_check("sem localconfig a Steam responde -1", library.get_playtime_minutes(games[0].app_id) == -1)
	result = stats.compute()
	_check("horas desconhecidas: hours_known = false", result["hours_known"] == false)
	_check("horas desconhecidas: total 0 e top vazio", result["total_minutes"] == 0 and result["top"].is_empty())
	_check("horas desconhecidas: ninguém 'jogado'", result["played_any"] == false)
	_check("horas desconhecidas: 200 jogos", result["game_count"] == 200)
	districts = result["districts"]
	var count_ordered := true
	var count_sum := 0
	for i in districts.size():
		count_sum += districts[i]["games"]
		if i > 0 and districts[i]["games"] > districts[i - 1]["games"]:
			count_ordered = false
	_check("horas desconhecidas: bairros por quantidade de jogos", count_ordered and count_sum == 200)
	_check("horas desconhecidas: sem 'jogado por último' (sem datas)", result["last_played"].is_empty())

	# --- Tudo 0: horas conhecidas, nenhuma hora ---
	var zeros: Dictionary = {}
	for game: SteamGame in games:
		zeros[game.app_id] = 0
	fake.set_playtimes(root, zeros)
	result = stats.compute()
	_check("tudo 0: horas conhecidas", result["hours_known"] == true)
	_check("tudo 0: nenhuma hora jogada", result["total_minutes"] == 0 and result["played_any"] == false)
	_check("tudo 0: top vazio", result["top"].is_empty())
	_check("tudo 0: bairros com a contagem de jogos", not result["districts"].is_empty() and result["districts"][0]["games"] > 0)

	# --- Horas falsas automáticas e velocidade ---
	fake.install(root, 200, true)
	var start := Time.get_ticks_usec()
	result = stats.compute()
	var elapsed_ms := (Time.get_ticks_usec() - start) / 1000.0
	print("  (200 jogos: %.2f ms)" % elapsed_ms)
	_check("horas falsas automáticas: conhecidas e com total", result["hours_known"] == true and result["total_minutes"] > 0)
	_check("horas falsas automáticas: top de 5 e último jogado", result["top"].size() == 5 and not result["last_played"].is_empty())
	_check("com 200 jogos o cálculo leva menos de 5 ms", elapsed_ms < 5.0)

	# --- Biblioteca vazia ---
	fake.install(root, 0)
	fake.set_playtimes(root, {})
	result = stats.compute()
	_check("biblioteca vazia: 0 jogos", result["game_count"] == 0)
	_check("biblioteca vazia: tudo vazio, sem erro", result["total_minutes"] == 0 and result["top"].is_empty() \
			and result["districts"].is_empty() and result["last_played"].is_empty() and result["hours_known"] == false)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
