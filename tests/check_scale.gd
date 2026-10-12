extends SceneTree
## Teste da cidade em escala (Fase 8): 200 jogos FALSOS (tests/fake_library.gd).
##   - todos os prédios existem, cada um com um GamePortal;
##   - nenhum bairro fica vazio e os bairros têm fatias desiguais;
##   - nada vai para a rede nem para user://cache;
##   - o tempo de montagem é impresso (para comparar entre fases).

const COUNT := 200

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library_script: GDScript = load("res://tests/fake_library.gd")
	var cache_before := _cache_snapshot()
	var games: Array[SteamGame] = library_script.install(root, COUNT)
	_check("%d jogos falsos, com App IDs diferentes" % COUNT, games.size() == COUNT and root.get_node("SteamLibrary").get_installed_games().size() == COUNT)
	var counts: Dictionary = library_script.count_by_district(root)
	print("   jogos por bairro: ", counts)
	_check("os 10 bairros têm jogo", counts.size() == 10)
	_check("RPG é o maior (fatias desiguais)", int(counts.get("rpg", 0)) > int(counts.get("cartas", 0)) * 3)

	var started := Time.get_ticks_msec()
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	print("   cidade com %d jogos pronta em %d ms" % [COUNT, Time.get_ticks_msec() - started])
	for i in 5:
		await process_frame

	var missing := 0
	for game in games:
		if city.get_node_or_null("Building_%d/GamePortal" % game.app_id) == null:
			missing += 1
	_check("todo jogo tem prédio e GamePortal (faltando: %d)" % missing, missing == 0)
	_check("sem requisição à rede (StoreInfo e GameArt)", not root.get_node("StoreInfo").is_fetching() and not root.get_node("GameArt")._active.size() > 0)
	_check("user://cache intacto", _cache_snapshot() == cache_before)
	print("== capas no mundo: comprimidas; na tela inteira: originais ==")
	var art := root.get_node("GameArt")
	var heroes := 0
	var compressed := 0
	var too_wide := 0
	for game in games:
		for texture: Texture2D in [art.get_hero(game.app_id), art.get_logo(game.app_id)]:
			if texture == null:
				continue
			heroes += 1
			if (texture as ImageTexture).get_format() >= Image.FORMAT_DXT1:
				compressed += 1
			if texture.get_width() > art.WORLD_MAX_WIDTH:
				too_wide += 1
	print("   %d heroes e logos no mundo, %d comprimidos" % [heroes, compressed])
	_check("todo hero e logo do mundo comprimido (S3TC)", heroes > 0 and compressed == heroes)
	_check("nenhum mais largo que %d px" % art.WORLD_MAX_WIDTH, too_wide == 0)
	var sample: int = -1
	for game in games:
		if art.get_hero(game.app_id) != null:
			sample = game.app_id
			break
	var full: Texture2D = art.get_hero_full(sample)
	_check("a tela inteira recebe o hero original, sem compressão",
			full != null and (full as ImageTexture).get_format() < Image.FORMAT_DXT1 and full.get_width() >= art.get_hero(sample).get_width())
	_check("o original fica guardado: pedir de novo devolve o mesmo", art.get_hero_full(sample) == full)

	var half: float = CityLayout.half_extent(CityLayout.block_cells(int(ceil(COUNT / 4.0)) + 9))
	print("   mapa de cerca de %d m de lado" % int(half * 2.0))

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Nome, tamanho e data de cada arquivo da cache (para ver se algo foi criado).
func _cache_snapshot() -> Array:
	var result: Array = []
	for folder in ["user://cache", "user://cache/art"]:
		for file in DirAccess.get_files_at(folder):
			result.append("%s/%s:%d" % [folder, file, FileAccess.get_modified_time(folder + "/" + file)])
	result.sort()
	return result


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
