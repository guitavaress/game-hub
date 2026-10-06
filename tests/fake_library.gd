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
## Uso (num script de teste, depois de "await process_frame"):
##   var library = load("res://tests/fake_library.gd")
##   library.install(root, 200)

const FIRST_INVENTED_ID: int = 9000000
## Fatia de cada bairro (soma 1.0). Os que não aparecem aqui dividem o resto.
const SHARES: Dictionary = {"rpg": 0.30, "acao": 0.15, "aventura": 0.12, "sobrevivencia": 0.10}


## Instala "count" jogos falsos. Devolve a lista (em ordem alfabética).
static func install(root: Node, count: int) -> Array[SteamGame]:
	var library := root.get_node("SteamLibrary")
	var store := root.get_node("StoreInfo")
	root.get_node("GameArt").allow_downloads = false

	var ids := _art_ids(library.get_steam_path())
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
	return games


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


## O arquivo começa como um JPEG? (Alguns da cache da Steam são outra coisa.)
static func _is_jpeg(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var head := file.get_buffer(2)
	return head.size() == 2 and head[0] == 0xFF and head[1] == 0xD8
