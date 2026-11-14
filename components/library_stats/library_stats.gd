class_name LibraryStats
extends RefCounted
## Os NÚMEROS da biblioteca (Fase 13.5): horas totais, os mais jogados, horas
## por bairro e o jogado por último. Só funções estáticas, sem tela, como o
## GameInfo. O quadro de estatísticas da casa desenha o resultado, e a cidade
## (Fase 19.9: o bairro cresce com as horas) usa o district_levels().
##
## Conta SÓ os jogos instalados (os mesmos da cidade). O localconfig.vdf também
## tem jogos desinstalados e ferramentas, e contar esses deixaria o quadro
## diferente da cidade.

## Quantos jogos entram no "mais jogados".
const TOP_COUNT: int = 5
## Faixas da fatia de horas que dão o NÍVEL do bairro (Fase 19.9), em por cento
## do total: a partir de 10% é o nível 1, de 20% o 2 e de 40% o 3. São faixas,
## e não a conta exata, para a planta da cidade não mudar a cada hora jogada:
## ela só muda quando um bairro passa de uma faixa para outra.
const LEVEL_PERCENTS: Array[int] = [10, 20, 40]
## Abaixo disto (10 h na biblioteca toda), ninguém cresce: com poucas horas, um
## jogo de uma tarde faria o bairro dele dominar a cidade.
const LEVEL_MIN_TOTAL_MINUTES: int = 600


## Calcula tudo de uma vez. Devolve um Dictionary com:
##   game_count:    quantos jogos instalados (0 = biblioteca vazia);
##   hours_known:   a Steam sabe as horas? (false = sem usuário logado ou sem localconfig.vdf);
##   total_minutes: soma dos minutos (0 se as horas são desconhecidas);
##   played_any:    alguém foi jogado de verdade? (false com horas conhecidas = "nenhuma hora");
##   top:           até 5 de {app_id, name, minutes}, do mais para o menos jogado (só quem tem minutos > 0);
##   districts:     {id, name, minutes, games} de cada bairro COM jogos, do que tem mais horas
##                  para o que tem menos (sem horas: do que tem mais jogos; empate: ordem do mundo);
##   last_played:   {app_id, name, time} do jogado mais recentemente, ou {} se ninguém foi jogado.
static func compute() -> Dictionary:
	var games := SteamLibrary.get_installed_games()
	var hours_known := false
	var total := 0
	var played: Array[Dictionary] = []
	var by_district: Dictionary = {}
	var latest_id := 0
	var latest_time := 0

	for game in games:
		var minutes := SteamLibrary.get_playtime_minutes(game.app_id)
		if minutes >= 0:
			hours_known = true
			total += minutes
			if minutes > 0:
				played.append({"app_id": game.app_id, "name": game.name, "minutes": minutes})

		var district_id := GameCategories.get_category_id(game.app_id)
		var entry: Dictionary = by_district.get(district_id, {"minutes": 0, "games": 0})
		entry["minutes"] = int(entry["minutes"]) + maxi(minutes, 0)
		entry["games"] = int(entry["games"]) + 1
		by_district[district_id] = entry

		var last_played := SteamLibrary.get_last_played(game.app_id)
		if last_played > latest_time:
			latest_time = last_played
			latest_id = game.app_id

	# Mais minutos primeiro; empate pelo nome, para a ordem não mudar de uma conta para outra.
	played.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["minutes"] != b["minutes"]:
			return a["minutes"] > b["minutes"]
		return String(a["name"]) < String(b["name"]))

	var last: Dictionary = {}
	if latest_time > 0:
		last = {"app_id": latest_id, "name": SteamLibrary.get_game_name(latest_id), "time": latest_time}

	return {
		"game_count": games.size(),
		"hours_known": hours_known,
		"total_minutes": total,
		"played_any": total > 0,
		"top": played.slice(0, TOP_COUNT),
		"districts": _sorted_districts(by_district, hours_known),
		"last_played": last,
	}


## O nível de cada bairro (0 a 3) pela fatia de horas dele (Fase 19.9: o bairro
## cresce com as horas). Função pura: recebe a lista "districts" do compute()
## (ou qualquer lista de {id, minutes}) e devolve id → nível, com TODOS os
## bairros da lista. Sem horas conhecidas, com tudo em 0 ou com menos de 10 h
## no total, todos ficam no nível 0 (a cidade fica como era antes da 19.9).
static func district_levels(districts: Array[Dictionary]) -> Dictionary[String, int]:
	var total := 0
	for district in districts:
		total += maxi(int(district.get("minutes", 0)), 0)
	var levels: Dictionary[String, int] = {}
	for district in districts:
		var minutes := maxi(int(district.get("minutes", 0)), 0)
		var level := 0
		if total >= LEVEL_MIN_TOTAL_MINUTES:
			# Conta inteira (sem arredondar): minutos / total >= faixa / 100.
			for percent in LEVEL_PERCENTS:
				if minutes * 100 >= total * percent:
					level += 1
		levels[String(district["id"])] = level
	return levels


## Os bairros com jogos, já na ordem do quadro. A ordem do mundo
## (GameCategories.get_category_ids) desempata, então o resultado é estável.
static func _sorted_districts(by_district: Dictionary, hours_known: bool) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id in GameCategories.get_category_ids():
		if not by_district.has(id):
			continue
		list.append({
			"id": id,
			"name": GameCategories.get_category_name(id),
			"minutes": by_district[id]["minutes"],
			"games": by_district[id]["games"],
		})
	# sort_custom não é estável; o índice na lista (ordem do mundo) entra como último critério.
	var order: Dictionary = {}
	for i in list.size():
		order[list[i]["id"]] = i
	var key := "minutes" if hours_known else "games"
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a[key] != b[key]:
			return a[key] > b[key]
		if hours_known and a["games"] != b["games"]:
			return a["games"] > b["games"]
		return order[a["id"]] < order[b["id"]])
	return list
