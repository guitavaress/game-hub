extends SceneTree
## Regressão da planta (15.2; desde a 15.4, em setores): compara a montagem com
## o retrato gravado antes dos setores (tests/fixtures/planta_atual.json, que
## NÃO se regrava). Os bairros só mudam de lugar: mesmos bairros, quarteirões,
## jogos, cascas, andares e paredes, e cada prédio num quarteirão do seu bairro.
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
		_compare_districts(count, actual, expected)
		_compare_games(count, city, actual, expected)
		_check_sectors(count, city)
		city.queue_free()
		await process_frame
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


## Mesmos bairros, com o mesmo número de quarteirões e de jogos; cada um com
## pórtico, letreiro e pelo menos uma estação.
func _compare_districts(count: int, actual: Dictionary, expected: Dictionary) -> void:
	var same_ids: bool = actual["districts"].keys() == expected["districts"].keys()
	var same_counts: bool = same_ids
	var complete: bool = true
	for id: String in actual["districts"]:
		var mine: Dictionary = actual["districts"][id]
		var before: Dictionary = expected["districts"].get(id, {})
		same_counts = same_counts and not before.is_empty() \
				and mine["blocks"].size() == before["blocks"].size() and mine["games"] == before["games"]
		complete = complete and mine["gate"].size() == 12 and mine["sign"].size() == 12 and not mine["stations"].is_empty()
	_check("%d jogos: mesmos bairros" % count, same_ids)
	_check("%d jogos: mesmos quarteirões e jogos por bairro" % count, same_counts)
	_check("%d jogos: todo bairro com pórtico, letreiro e estação" % count, complete)


## Cada jogo: mesmo bairro, casca, andares e parede; o lugar pode mudar, mas o
## prédio fica num quarteirão do próprio bairro.
func _compare_games(count: int, city: Node, actual: Dictionary, expected: Dictionary) -> void:
	var same_look: bool = actual["games"].size() == count and actual["games"].keys().size() == expected["games"].keys().size()
	var in_district: bool = true
	for app_id: String in actual["games"]:
		var mine: Dictionary = actual["games"][app_id]
		var before: Dictionary = expected["games"].get(app_id, {})
		# Desde a 15.6, o bairro com bioma troca a casca (ex.: o RPG vira arcos);
		# o retrato é de antes e não se regrava. Os outros continuam iguais.
		var keys: Array[String] = ["district", "shell", "floors", "wall"]
		var biome: BiomeSpec = Profiles.district(mine["district"]).biome
		if biome != null and not biome.shell.is_empty() and not before.is_empty():
			keys = ["district"]
			same_look = same_look and mine["shell"] == _shell_path(biome.shell)
		for key: String in keys:
			same_look = same_look and not before.is_empty() and mine[key] == before[key]
		var building: Node3D = city.get_node("Building_" + app_id)
		var cell := Vector2i(roundi(building.global_position.x / CityLayout.BLOCK_PITCH),
				roundi(building.global_position.z / CityLayout.BLOCK_PITCH))
		in_district = in_district and (city._district_cells[mine["district"]] as Array).has(cell)
	_check("%d jogos: mesmas cascas, andares e paredes" % count, same_look)
	_check("%d jogos: cada prédio num quarteirão do próprio bairro" % count, in_district)


## Os quarteirões montados são os do SectorLayout; as vagas têm chão; o
## território de cada bairro vira zona no mapa.
func _check_sectors(count: int, city: Node) -> void:
	var map: Node = city.get_node("CityMap")
	var areas: Array = map.get_map_data()["areas"]
	var counts: Array[int] = []
	var ids: Array[String] = []
	for area: Dictionary in areas:
		counts.append((city._district_cells[area["id"]] as Array).size())
		ids.append(area["id"])
	# Desde a 15.6, o bairro com terreno de fundo fica com a fatia no norte.
	# (O BiomeBuilder usa autoloads: no teste vai por load(), sem o nome da classe.)
	var builder: GDScript = load("res://worlds/city/biome/biome_builder.gd")
	var plan: Array[DistrictSector] = SectorLayout.plan(counts, builder.focus_index(ids))
	var rings: Array[DistrictSector] = CityLayout.ring_plan(counts)
	var same_blocks: bool = plan.size() == areas.size()
	var zones_ok: bool = same_blocks
	var vacant_ok: bool = same_blocks
	var vacant: int = 0
	var moved: bool = false
	for i: int in mini(plan.size(), areas.size()):
		var id: String = areas[i]["id"]
		var blocks: Array = city._district_cells[id]
		same_blocks = same_blocks and blocks == plan[i].blocks
		zones_ok = zones_ok and map.zone_rects(id).size() == plan[i].territory.size()
		for cell: Vector2i in plan[i].territory:
			zones_ok = zones_ok and map.zone_rects(id).has(map.block_rect(cell))
			if blocks.has(cell):
				continue
			vacant += 1
			vacant_ok = vacant_ok and city.get_node_or_null("Vacant_%s_%d_%d" % [id, cell.x, cell.y]) != null
		moved = moved or plan[i].blocks != rings[i].blocks
	_check("%d jogos: quarteirões = os do SectorLayout" % count, same_blocks)
	_check("%d jogos: o território de cada bairro vira zona no mapa" % count, zones_ok)
	_check("%d jogos: as %d vagas têm chão" % [count, vacant], vacant_ok)
	if count == 200:
		_check("200 jogos: os bairros mudaram de lugar (setores ligados)", moved)


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


## O script da casca pelo nome do perfil (o mesmo mapa do city.gd).
static func _shell_path(kind: String) -> String:
	return "res://components/portal_shell/arch_shell.gd" if kind == "arch" else "res://worlds/city/city_building.gd"


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
