class_name FakeLibrary
extends RefCounted
## Biblioteca FALSA para os testes de escala (Fase 8): N jogos que não existem
## na Steam. Troca a lista do SteamLibrary e as tags do StoreInfo só na
## memória, e desliga os downloads do GameArt (nada de rede nem de arquivo
## novo em user://cache).
##
## Os App IDs vêm da pasta de capas da própria Steam (appcache/librarycache),
## para os prédios terem capa e hero de verdade, sem internet. Se faltar, o
## resto é inventado (sem capa: o prédio mostra o nome em texto).
##
## Os bairros recebem fatias desiguais de propósito (RPG fica com 30%): é o
## caso difícil para o metrô e para o mapa.
##
## Horas falsas (opcional): "install(root, 200, true)" dá a cada jogo minutos
## jogados (a maioria com horas, uns 20% com zero) e uma "última vez". Os
## bairros recebem horas desiguais de propósito (HOUR_WEIGHTS: o RPG fica com
## mais da metade), para a cidade ter bairros de níveis 0 a 3 (Fase 19.9).
## Sem o terceiro argumento, as horas ficam DESCONHECIDAS (como sem usuário
## logado; desde a 19.9): antes o SteamLibrary lia o localconfig.vdf de
## verdade, e as horas reais dos App IDs da cache mudavam a planta da cidade
## de um PC para outro. Para casos exatos, use set_playtimes.
##
## Uso (num script de teste, depois de "await process_frame"):
##   var library = load("res://tests/fake_library.gd")
##   library.install(root, 200)

const FIRST_INVENTED_ID: int = 9000000
## Fatia de cada bairro (soma 1.0). Os que não aparecem aqui dividem o resto.
const SHARES: Dictionary = {"rpg": 0.30, "acao": 0.15, "aventura": 0.12, "sobrevivencia": 0.10}
## Peso das horas falsas por bairro (19.9): os minutos de cada jogo são
## multiplicados pelo peso do bairro dele (quem não aparece aqui: 0,5). Com 200
## jogos dá RPG no nível 3, Ação no 2, Aventura no 1 e o resto no 0 (a
## Sobrevivência, sem nenhuma hora).
const HOUR_WEIGHTS: Dictionary = {"rpg": 3.0, "acao": 3.0, "aventura": 2.0, "sobrevivencia": 0.0}


## Instala "count" jogos falsos. Devolve a lista (em ordem alfabética).
static func install(root: Node, count: int, fake_playtimes: bool = false, fixed_ids: bool = false) -> Array[SteamGame]:
	var library := root.get_node("SteamLibrary")
	var store := root.get_node("StoreInfo")
	root.get_node("GameArt").allow_downloads = false

	# Retratos usam IDs inventados para não depender da cache desta máquina.
	var ids: Array = [] if fixed_ids else _art_ids(library.get_steam_path())
	var games: Array[SteamGame] = []
	var by_id: Dictionary[int, SteamGame] = {}
	for i in count:
		var game := SteamGame.new()
		game.app_id = ids[i] if i < ids.size() else FIRST_INVENTED_ID + i
		game.name = "Jogo Falso %03d" % (i + 1)
		game.install_dir = "falso_%d" % i
		games.append(game)
		by_id[game.app_id] = game

	library._games = games
	library._games_by_id = by_id
	library._games_loaded = true
	_spread_tags(store, games)
	if fake_playtimes:
		_spread_playtimes(library, games)
	else:
		_apply_playtimes(library, {}, {})  # horas desconhecidas
	return games


## Põe minutos e "última vez" exatos, só na memória. "minutes" é app_id → minutos;
## {} = horas DESCONHECIDAS (get_playtime_minutes devolve -1, como sem usuário logado).
## "last_played" é app_id → segundos desde 1970 (opcional).
static func set_playtimes(root: Node, minutes: Dictionary, last_played: Dictionary = {}) -> void:
	var library := root.get_node("SteamLibrary")
	_apply_playtimes(library, minutes, last_played)


## Com 200 jogos, quantos ficaram em cada bairro (para os testes lerem).
static func count_by_district(root: Node) -> Dictionary:
	var counts := {}
	for game in root.get_node("SteamLibrary").get_installed_games():
		var id: String = root.get_node("GameCategories").get_category_id(game.app_id)
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


## App IDs com capa em pé de verdade na cache da Steam, em ordem.
static func _art_ids(steam_path: String) -> Array[int]:
	var ids: Array[int] = []
	if steam_path.is_empty():
		return ids
	var folder := steam_path + "/appcache/librarycache"
	for entry in DirAccess.get_directories_at(folder):
		if not entry.is_valid_int():
			continue
		var cover_ok := _is_jpeg(folder + "/" + entry + "/library_600x900.jpg")
		var hero_path := folder + "/" + entry + "/library_hero.jpg"
		if cover_ok and (not FileAccess.file_exists(hero_path) or _is_jpeg(hero_path)):
			ids.append(entry.to_int())
	ids.sort()
	return ids


## Dá a cada jogo a primeira tag de um bairro, nas fatias de SHARES.
static func _spread_tags(store: Node, games: Array[SteamGame]) -> void:
	var profiles: Array = Profiles.world().districts
	var weights: Array[float] = []
	var named_total := 0.0
	var unnamed := 0
	for profile in profiles:
		if SHARES.has(profile.id):
			named_total += SHARES[profile.id]
		else:
			unnamed += 1
	for profile in profiles:
		weights.append(SHARES[profile.id] if SHARES.has(profile.id) else (1.0 - named_total) / maxf(unnamed, 1))
	var now := int(Time.get_unix_time_from_system())
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for game in games:
		var profile = profiles[rng.rand_weighted(PackedFloat32Array(weights))]
		var tags: Array = [profile.tags[0]] if profile.tags.size() > 0 else []
		store._cache[str(game.app_id)] = {"fetched": now, "tags": tags,
				"capsule": "", "capsule_2x": "", "hero": "", "header": ""}


## Copia para os dicionários tipados (Dictionary[int, int]) do SteamLibrary.
static func _apply_playtimes(library: Node, minutes: Dictionary, last_played: Dictionary) -> void:
	library._playtime_minutes.clear()
	library._playtime_minutes.merge(minutes)
	library._local_last_played.clear()
	library._local_last_played.merge(last_played)
	library._playtimes_loaded = true


## Horas inventadas (sempre as mesmas): cerca de 20% dos jogos com 0 min, o resto
## entre 1 min e 400 h vezes o peso do bairro (HOUR_WEIGHTS), e uma última vez
## nos últimos 90 dias.
static func _spread_playtimes(library: Node, games: Array[SteamGame]) -> void:
	var minutes: Dictionary = {}
	var last_played: Dictionary = {}
	var now := int(Time.get_unix_time_from_system())
	var categories: Node = library.get_tree().root.get_node("GameCategories")
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for game in games:
		if rng.randf() < 0.2:
			minutes[game.app_id] = 0
		else:
			var weight: float = HOUR_WEIGHTS.get(categories.get_category_id(game.app_id), 0.5)
			minutes[game.app_id] = roundi(rng.randi_range(1, 24000) * weight)
			var played_at: int = now - rng.randi_range(0, 90 * 86400)
			if minutes[game.app_id] > 0:
				last_played[game.app_id] = played_at
	_apply_playtimes(library, minutes, last_played)


## O arquivo começa como um JPEG? (Alguns da cache da Steam são outra coisa.)
static func _is_jpeg(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var head := file.get_buffer(2)
	return head.size() == 2 and head[0] == 0xFF and head[1] == 0xD8
