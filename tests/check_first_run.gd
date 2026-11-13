extends SceneTree
## Teste da primeira abertura num PC limpo (Fase 18.3). Estende o
## check_first_time (o cartão de controles) com o que um amigo encontra:
##   - SEM INTERNET na primeira vez (sem cache da loja e a loja sem responder):
##     a cidade monta com todos em "Outros", com UM aviso só sobre a loja, e a
##     porta mostrou "Buscando capas e categorias… N de M" enquanto esperava;
##   - capas que falham sem conectar NÃO ficam anotadas por 7 dias (com
##     internet, na próxima vez, elas vêm); as que a loja respondeu sem ter, sim;
##   - com a cidade pronta, a porta conta as capas chegando e a placa some no fim;
##   - SEM JOGOS: a cidade monta, e a placa da porta da casa diz por que está
##     vazia (e continua lá depois do aviso do topo); SEM STEAM: o motivo é a Steam;
##   - PC FRACO: abaixo de 30 FPS na Alta, um aviso único sugere a Leve e grava
##     [ui] seen_quality_hint; na segunda vez, não mede de novo.
## Nada de rede de verdade: a loja aponta para um endereço sem ninguém
## (127.0.0.1:9; no Windows ele espera o tempo-limite em vez de recusar) e os
## downloads do GameArt ficam desligados, menos o de teste, para o mesmo endereço.
## Guarda o config.cfg e o cache da loja (store_info.json) antes e devolve no fim.

const CONFIG := "user://config.cfg"
const STORE_CACHE := "user://cache/store_info.json"
const ART_DIR := "user://cache/art"
## Endereço sem ninguém: o "sem internet" do teste.
const NO_NET_URL := "http://127.0.0.1:9/?input_json="
const FAKE_COUNT := 12
## App ID inventado para os downloads de teste (nenhum jogo de verdade tem).
const FAKE_ART_ID := 9_999_001

var failures := 0
var config_backup := ""
var store_file_backup := ""
var store_had_file := false


func _initialize() -> void:
	_run()


func _run() -> void:
	config_backup = FileAccess.get_file_as_string(CONFIG)
	store_had_file = FileAccess.file_exists(STORE_CACHE)
	store_file_backup = FileAccess.get_file_as_string(STORE_CACHE) if store_had_file else ""
	await process_frame
	var app = root.get_node("AppConfig")
	var store = root.get_node("StoreInfo")
	var art = root.get_node("GameArt")
	app.set_seen_controls_hint(true)  # o cartão seguraria os avisos (o check_first_time cobre)
	load("res://tests/quiet_friends.gd").install(root)
	var memory_backup: Dictionary = store._cache.duplicate(true)
	# Sem a Steam nesta máquina (o CI), a biblioteca falsa teria jogos "sem
	# Steam", e a porta diria que falta a Steam: um caminho falso, só no teste.
	var library = root.get_node("SteamLibrary")
	var steam_backup: String = library._steam_path
	if library.get_steam_path().is_empty():
		library._steam_path = "c:/steam-falsa"

	print("== sem internet na primeira vez ==")
	var games: Array = load("res://tests/fake_library.gd").install(root, FAKE_COUNT, false, true)
	store._cache = {}  # sem cache da loja: o PC limpo
	store.api_url = NO_NET_URL
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = true
	var door_texts: Array[String] = []
	root.add_child(city)
	while not city.is_city_ready():
		var text: String = city.get_home().get_door_status()
		if not text.is_empty() and not text in door_texts:
			door_texts.append(text)
		await process_frame
	print("   a porta disse: ", door_texts)
	var player = city.get_node("Player")
	var hud = player.get_hud()
	_check("a porta disse \"Buscando capas e categorias… N de %d\"" % FAKE_COUNT,
			door_texts.any(func(t: String) -> bool:
				return t.begins_with("Buscando capas e categorias") and t.ends_with("de %d" % FAKE_COUNT)))
	_check("a porta disse \"Montando a cidade… N%\"", door_texts.any(func(t: String) -> bool: return t.begins_with("Montando a cidade")))
	_check("a loja terminou: %s de %d" % [store.get_progress(), FAKE_COUNT],
			not store.is_fetching() and store.get_progress() == Vector2i(FAKE_COUNT, FAKE_COUNT))
	var categories := root.get_node("GameCategories")
	_check("todos os jogos no bairro \"Outros\"",
			games.all(func(g: SteamGame) -> bool: return categories.get_category_id(g.app_id) == "outros"))
	_check("a porta destrancou, e a placa sumiu", city.get_home().get_front_door().is_open()
			and city.get_home().get_door_status().is_empty())
	await _frames(2)
	var messages := Array(hud.get_messages())
	print("   avisos: ", messages)
	var store_notes := messages.filter(func(m: String) -> bool: return "loja" in m.to_lower())
	_check("um aviso só sobre a loja, dizendo os %d em \"Outros\"" % FAKE_COUNT,
			store_notes.size() == 1 and ("%d jogo(s)" % FAKE_COUNT) in store_notes[0])
	_check("nenhum aviso de erro sobre capas ou Steam",
			not messages.any(func(m: String) -> bool: return "capa" in m.to_lower() or "Não encontrei" in m))

	print("== capas: sem conectar não fica anotado ==")
	art.allow_downloads = true
	var stem := str(FAKE_ART_ID)
	_remove_art_marks(stem)
	var urls: Array[String] = ["http://127.0.0.1:9/capa.jpg"]
	art._queue_download(FAKE_ART_ID, stem, urls)
	_check("baixando, progresso 0 de 1", art.is_downloading() and art.get_download_progress() == Vector2i(0, 1))
	city._show_city_state_at_door(games)
	_check("a porta conta as capas: \"%s\"" % city.get_home().get_door_status(),
			city.get_home().get_door_status().ends_with("Baixando as capas… 0 de 1"))
	var deadline := Time.get_ticks_msec() + 20_000  # o GameArt desiste em 15 s
	while art.is_downloading() and Time.get_ticks_msec() < deadline:
		await process_frame
	await create_timer(city.DOOR_DOWNLOADS_INTERVAL * 2.0).timeout
	_check("o download acabou: %s, baixando = %s" % [art.get_download_progress(), art.is_downloading()],
			not art.is_downloading() and art.get_download_progress() == Vector2i(1, 1))
	_check("a placa da porta sumiu no fim", city.get_home().get_door_status().is_empty())
	_check("sem conectar: nada anotado (tenta de novo na próxima vez)",
			not FileAccess.file_exists("%s/%s.none" % [ART_DIR, stem]))
	# A loja respondeu e não tinha a imagem: aí, sim, 7 dias sem tentar.
	var http := HTTPRequest.new()
	art.add_child(http)
	art._active[stem] = {}
	art._finish_download(http, {"app_id": FAKE_ART_ID, "stem": stem, "urls": [], "kind": "cover", "reached": true}, null)
	_check("a loja respondeu sem a imagem: anotado", FileAccess.file_exists("%s/%s.none" % [ART_DIR, stem]))
	_remove_art_marks(stem)
	art.allow_downloads = false
	root.remove_child(city)
	city.free()
	await _frames(2)

	print("== sem jogos ==")
	load("res://tests/fake_library.gd").install(root, 0)
	city = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = true
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	# Sem jogos a cidade fica pronta antes de a tela de abertura sumir: os
	# avisos esperam o HUD aparecer.
	var intro_deadline := Time.get_ticks_msec() + 5000
	while not city.get_node("Player").get_hud().visible and Time.get_ticks_msec() < intro_deadline:
		await process_frame
	await _frames(2)
	var status: String = city.get_home().get_door_status()
	print("   a placa diz: ", status.replace("\n", " | "))
	# O motivo vem do mesmo caminho da Steam que a cidade leu (o falso, no CI).
	var city_script: GDScript = load("res://worlds/city/city.gd")
	var reason: PackedStringArray = city_script.empty_city_reason(library.get_steam_path(), 0)
	_check("a placa diz que a cidade está vazia e por quê (%s)" % reason[0],
			status.begins_with("A cidade está vazia") and reason[0] in status)
	var front_door = city.get_home().get_front_door()
	_check("a porta abre e o cartão fala da praça vazia", front_door.is_open() and "vazia" in front_door.detail)
	hud = city.get_node("Player").get_hud()
	_check("o aviso do topo também apareceu",
			Array(hud.get_messages()).any(func(m: String) -> bool: return m.begins_with(reason[0])))
	hud.clear_messages()
	_check("sem o aviso do topo, a placa continua", city.get_home().get_door_status() == status)

	print("== sem Steam ==")
	var no_steam: PackedStringArray = city_script.empty_city_reason("", 0)
	_check("sem a Steam, o motivo é a Steam", no_steam.size() == 2 and "Steam" in no_steam[0] and "Instale a Steam" in no_steam[1])
	_check("sem a Steam, vale mesmo com jogos na lista", city_script.empty_city_reason("", 5) == no_steam)
	_check("com Steam e sem jogos, o motivo são os jogos", "Nenhum jogo" in city_script.empty_city_reason("c:/steam", 0)[0])
	_check("com Steam e jogos, a cidade não está vazia", city_script.empty_city_reason("c:/steam", 3).is_empty())

	print("== PC fraco ==")
	_check("abaixo de 30 na Alta: sugere a Leve", hud.should_suggest_light(22.0, "alta", false))
	_check("acima de 30: não", not hud.should_suggest_light(45.0, "alta", false))
	_check("na Leve ou na Média: não", not hud.should_suggest_light(22.0, "leve", false)
			and not hud.should_suggest_light(22.0, "media", false))
	_check("já avisou: não", not hud.should_suggest_light(22.0, "alta", true))
	app.set_quality("alta")
	app.set_seen_quality_hint(false)
	hud.start_quality_check()
	_check("na Alta, sem ter avisado, mede", hud.is_checking_quality())
	hud._finish_quality_check(22.0)
	_check("o aviso aparece, com a média e o caminho no menu",
			Array(hud.get_messages()).any(func(m: String) -> bool:
				return m.begins_with("O hub está pesado") and "22 FPS" in m and "Leve" in m))
	_check("gravou que avisou (na memória e no config.cfg)", app.get_seen_quality_hint()
			and "seen_quality_hint=true" in FileAccess.get_file_as_string(CONFIG))
	_check("nada mudou sozinho: continua na Alta", app.get_quality() == "alta")
	hud.start_quality_check()
	_check("na segunda vez, não mede de novo", not hud.is_checking_quality())
	app.set_seen_quality_hint(false)
	app.set_quality("leve")
	hud.start_quality_check()
	_check("na Leve, não mede", not hud.is_checking_quality())

	root.remove_child(city)
	city.free()
	# Devolve tudo: a Steam, a loja (memória, endereço e arquivo) e o config.cfg.
	library._steam_path = steam_backup
	store._cache = memory_backup
	store.api_url = store.API_URL
	if store_had_file:
		var store_file := FileAccess.open(STORE_CACHE, FileAccess.WRITE)
		store_file.store_string(store_file_backup)
		store_file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE_CACHE))
	_check("cache da loja restaurado", FileAccess.get_file_as_string(STORE_CACHE) == store_file_backup)
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(config_backup)
	file.close()
	_check("config.cfg restaurado", FileAccess.get_file_as_string(CONFIG) == config_backup)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Apaga as marcas de falha (.none) de um download de teste.
func _remove_art_marks(stem: String) -> void:
	var path := "%s/%s.none" % [ART_DIR, stem]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
