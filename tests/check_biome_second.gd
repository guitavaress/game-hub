extends SceneTree
## Fase 19.1: um segundo bairro com bioma. Com 200 jogos falsos, a Ação ganha,
## só na memória (o .tres não muda), um bioma de teste com prédios, rochas
## densas e um som de fundo próprio. Confere:
##   - cada bairro com bioma tem a sua atmosfera, e só a de maior peso onde o
##     jogador está fala com o céu (a névoa do DayNight é a dela);
##   - o som de fundo de cada um vem do perfil; o vento alto só no da montanha;
##   - os prédios entram no grupo scatter_keep_out, e nenhum enfeite nasce
##     dentro de um prédio (sem o desvio, as rochas cairiam dentro deles).
var failures: int = 0

const TEST_DISTRICT: String = "acao"
const TEST_BED: String = "res://assets/generated/city_bed.wav"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 200, false, true)
	var profile: DistrictProfile = Profiles.district(TEST_DISTRICT)
	var biome: BiomeSpec = _test_biome()
	profile.biome = biome
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(0.5).timeout

	_check_atmospheres(city, biome)
	_check_buildings_keep_out(city, biome)
	profile.biome = null
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## O bioma de teste: o chão e a pedra que já existem, a casca do bairro
## (prédios), rochas bem densas no miolo, sem terreno de fundo, névoa própria.
func _test_biome() -> BiomeSpec:
	var biome := BiomeSpec.new()
	biome.id = "teste"
	biome.display_name = "Bioma de teste"
	biome.ground_folder = "Snow010A"
	biome.ground_meters = 3.0
	biome.ground_tint = Color(0.5, 0.7, 0.45)
	biome.path_folder = "PavingStones070"
	biome.cover_streets = false
	biome.fog_density_scale = 2.5
	biome.fog_tint = Color(0.6, 0.8, 0.5)
	biome.fog_tint_amount = 0.4
	biome.ambience_bed = AmbienceSpec.new()
	biome.ambience_bed.kind = "loop"
	biome.ambience_bed.files = PackedStringArray([TEST_BED])
	biome.ambience_bed.volume_db = -20.0
	var rock := ScatterSpec.new()
	rock.source = "res://assets/polyhaven/models/moon_rock_02/moon_rock_02_1k.gltf"
	rock.height_range = Vector2(0.6, 1.2)
	rock.density = 4.0
	biome.scatter.append(rock)
	return biome


func _check_atmospheres(city: Node, biome: BiomeSpec) -> void:
	print("== duas atmosferas, uma voz ==")
	var rpg: Node = city.get_node_or_null("BiomeAtmosphere_rpg")
	var test: Node = city.get_node_or_null("BiomeAtmosphere_%s" % TEST_DISTRICT)
	_check("cada bairro com bioma tem a sua atmosfera", rpg != null and test != null)
	if rpg == null or test == null:
		return
	var day_night: Node = city._day_night
	var player: Node3D = city.get_node("Player")
	var map: Node = city.get_node("CityMap")
	var test_spot: Vector2 = (map.zone_rects(TEST_DISTRICT)[0] as Rect2).get_center()
	var rpg_spot: Vector2 = (map.zone_rects("rpg")[0] as Rect2).get_center()

	player.global_position = Vector3(test_spot.x, 0.5, test_spot.y)
	rpg.update_now()
	test.update_now()
	_check("no bairro de teste: a voz é dele", test.has_voice() and not rpg.has_voice())
	_check("e a névoa do céu é a do bioma de teste", is_equal_approx(day_night._fog_overlay_weight, test.get_weight())
			and test.get_weight() > 0.99 and is_equal_approx(day_night._fog_overlay_scale, biome.fog_density_scale))

	player.global_position = Vector3(rpg_spot.x, 0.5, rpg_spot.y)
	rpg.update_now()
	test.update_now()
	_check("no RPG: a voz passa para a montanha", rpg.has_voice() and not test.has_voice())
	# (BiomeBuilder usa autoloads: no teste vai por load(), sem o nome da classe.)
	var builder: GDScript = load("res://worlds/city/biome/biome_builder.gd")
	_check("e a névoa é a da montanha", is_equal_approx(day_night._fog_overlay_scale,
			builder.biome_of("rpg").fog_density_scale) and day_night._fog_overlay_weight > 0.99)

	player.global_position = Vector3(0.0, 0.5, 0.0)
	rpg.update_now()
	test.update_now()
	_check("na praça: uma voz só e nenhuma névoa de bioma", int(rpg.has_voice()) + int(test.has_voice()) == 1
			and day_night._fog_overlay_weight == 0.0)

	print("== o som de fundo de cada um ==")
	_check("o bairro de teste toca o som do perfil", test._bed_source == load(TEST_BED)
			and (test.get_node("WindLow") as AudioStreamPlayer).playing)
	_check("a montanha continua com o vento", rpg._bed_source == load("res://assets/generated/wind_loop.wav"))
	_check("vento alto só na montanha (que tem terreno de fundo)",
			(rpg.get_node("WindHigh") as AudioStreamPlayer).stream != null
			and (test.get_node("WindHigh") as AudioStreamPlayer).stream == null)


func _check_buildings_keep_out(city: Node, biome: BiomeSpec) -> void:
	print("\n== prédios livres de enfeites ==")
	var builder: GDScript = load("res://worlds/city/biome/biome_builder.gd")
	var scatter_script: GDScript = load("res://worlds/city/biome/biome_scatter.gd")
	var buildings: Array[Node3D] = []
	var outside_group := 0
	for child: Node in city.get_children():
		if String(child.name).begins_with("Building_") and child.has_method("footprint") \
				and child.get_script().resource_path.ends_with("city_building.gd"):
			buildings.append(child)
			if not child.is_in_group(&"scatter_keep_out") or not (child.call("footprint") as Rect2).has_area():
				outside_group += 1
	var test_buildings := buildings.filter(func(b: Node3D) -> bool: return b.get("category_id") == TEST_DISTRICT)
	print("   prédios: %d (no bairro de teste: %d)" % [buildings.size(), test_buildings.size()])
	_check("o bairro de teste continua com prédios", not test_buildings.is_empty())
	_check("cada prédio está no grupo scatter_keep_out com a planta dele", not buildings.is_empty() and outside_group == 0)

	var scatter: Node = city.get_node_or_null("BiomeScatter_%s" % TEST_DISTRICT)
	_check("o bairro de teste tem enfeites", scatter != null)
	if scatter == null:
		return
	var transforms: Array[Transform3D] = scatter.get_transforms(0)
	var rects: Array[Rect2] = []
	for building: Node3D in test_buildings:
		rects.append(_world_rect(building, building.call("footprint")))
	var inside := 0
	for t: Transform3D in transforms:
		var spot := Vector2(t.origin.x, t.origin.z)
		for rect: Rect2 in rects:
			if scatter_script.area_distance(rect, spot) < scatter_script.AREA_GAP - 0.01:
				inside += 1
	print("   rochas: %d" % transforms.size())
	_check("há rochas no bairro de teste", transforms.size() > 0)
	_check("nenhuma rocha dentro de prédio nem colada na parede (%d)" % inside, inside == 0)

	# O teste vale alguma coisa: sem os prédios no grupo, o mesmo sorteio poria
	# rochas dentro deles.
	for building: Node3D in buildings:
		building.remove_from_group(&"scatter_keep_out")
	var areas: Array[Rect2] = builder.keep_out_areas(city)
	for building: Node3D in buildings:
		building.add_to_group(&"scatter_keep_out")
	var bounds: Rect2 = city.get_node("CityMap").get_map_data()["bounds"]
	var town: Array[Rect2] = []
	town.assign(city.get_node("CityMap").zone_rects(TEST_DISTRICT).filter(
			func(r: Rect2) -> bool: return bounds.encloses(r)))
	var source: Dictionary = scatter_script._source(biome.scatter[0], biome)
	var occupied: Array[Vector3] = []
	var without: Array[Dictionary] = scatter_script.plan(biome.scatter[0], builder.scatter_regions(town),
			builder.keep_out_points(city), occupied, hash([TEST_DISTRICT, 0]), source["height"], source["radius"], areas)
	var would_be_inside := 0
	for item: Dictionary in without:
		var position: Vector3 = item["position"]
		var spot := Vector2(position.x, position.z)
		for rect: Rect2 in rects:
			if rect.has_point(spot):
				would_be_inside += 1
	print("   sem o desvio, rochas dentro de prédios: %d" % would_be_inside)
	_check("sem o desvio dos prédios, haveria rochas dentro deles", would_be_inside > 0)


## A caixa no chão (mundo) de um retângulo local de um nó girado.
func _world_rect(node: Node3D, local: Rect2) -> Rect2:
	var area := Rect2()
	for k in 4:
		var corner := Vector2(local.end.x if k & 1 else local.position.x, local.end.y if k & 2 else local.position.y)
		var world := node.global_transform * Vector3(corner.x, 0.0, corner.y)
		area = Rect2(Vector2(world.x, world.z), Vector2.ZERO) if k == 0 else area.expand(Vector2(world.x, world.z))
	return area


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
