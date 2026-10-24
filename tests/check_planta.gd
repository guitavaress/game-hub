extends SceneTree
## Regressão da 15.2: compara a montagem com o retrato anterior à refatoração.
var failures: int = 0

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	_check_plan()
	var portrait: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planta_atual.json"))
	for count: int in [6, 40, 200]:
		load("res://tests/fake_library.gd").install(root, count, false, true)
		var city: Node = load("res://worlds/city/city.tscn").instantiate()
		city.play_intro = false
		root.add_child(city)
		while not city.is_city_ready():
			await process_frame
		var captured: Dictionary = load("res://tests/planta_snapshot.gd").capture(city)
		# Normaliza os números para o formato do JSON histórico.
		var actual: Dictionary = JSON.parse_string(JSON.stringify(captured))
		var expected: Dictionary = portrait["cases"][str(count)]
		_check("%d jogos: metade do mapa preservada" % count, actual["half"] == expected["half"])
		_check("%d jogos: bairros, blocos, pórticos, letreiros e estações idênticos" % count, actual["districts"] == expected["districts"])
		_check("%d jogos: cascas, andares, paredes e posições idênticos" % count, actual["games"] == expected["games"] and actual["games"].size() == count)
		city.queue_free()
		await process_frame
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


func _check_plan() -> void:
	_check("plano vazio", CityLayout.ring_plan([]).is_empty())
	var counts: Array[int] = [1, 0, 2, 15]
	var plan: Array[DistrictSector] = CityLayout.ring_plan(counts)
	var cells: Array[Vector2i] = []
	var sizes_ok: bool = plan.size() == counts.size()
	for i: int in plan.size():
		sizes_ok = sizes_ok and plan[i].blocks.size() == counts[i] and plan[i].territory == plan[i].blocks
		cells.append_array(plan[i].blocks)
	_check("contagens por bairro e territórios preservados", sizes_ok)
	_check("concatenação preserva os anéis e sua ordem", cells == CityLayout.block_cells(18))
	plan[0].territory.clear()
	_check("território não altera blocos nem outro bairro", plan[0].blocks.size() == 1 and plan[2].territory.size() == 2)
	var sector: DistrictSector = DistrictSector.new()
	sector.territory = [Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 1)]
	_check("borda no anel externo", sector.border_cells() == [Vector2i(2, 0), Vector2i(-2, 1)])
	_check("território sem borda da cidade", sector.border_cells(3).is_empty())


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
