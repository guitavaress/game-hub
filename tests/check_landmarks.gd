extends SceneTree
## Teste dos marcos altos da cidade (Fase 11.5: a torre do relógio da praça):
##   - a torre existe, passa da altura de um prédio de 3 andares e tem colisão só na coluna;
##   - os ponteiros seguem a hora (15:30 = horas entre o 3 e o 4, minutos no 6);
##   - o mapa tem o marco "Torre do relógio";
##   - ninguém da praça (amigos, estação do metrô) encosta na coluna;
##   - as floreiras da praça ficam sem arbusto.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library_script: GDScript = load("res://tests/fake_library.gd")
	library_script.install(root, 30)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame

	# (PlazaClockTower usa autoloads: no teste vai como Node, sem o nome da classe.)
	var tower: Node = city.get_node_or_null("ClockTower")
	_check("a torre existe", tower != null)
	if tower == null:
		_finish()
		return

	var three_floors: float = BuildingVariant.GROUND_FLOOR_HEIGHT + 3.0 * BuildingVariant.FLOOR_HEIGHT \
			+ BuildingVariant.TOP_MARGIN
	_check("o topo passa da altura de um prédio de 3 andares (%.1f m)" % tower.get_top_y(),
			tower.get_top_y() > three_floors + 2.9)
	var bodies := tower.find_children("*", "CollisionObject3D", true, false)
	_check("só a coluna tem colisão", bodies.size() == 1 and bodies[0].name == "Column")

	tower.set_hour(15.5)
	_check("ponteiro das horas entre o 3 e o 4 (%.0f°)" % tower.get_hour_angle(),
			tower.get_hour_angle() > 90.0 and tower.get_hour_angle() < 120.0)
	_check("ponteiro dos minutos no 6 (%.0f°)" % tower.get_minute_angle(),
			is_equal_approx(tower.get_minute_angle(), 180.0))
	var pivot := tower.get_node("Dial0").get_child(-2) as Node3D  # pivô das horas
	_check("o mostrador gira de verdade", pivot != null and absf(pivot.rotation.z) > 0.1)

	var landmarks: Array = []
	for map in get_nodes_in_group("world_map"):
		landmarks.append_array(map.get_map_data()["landmarks"])
	var found := landmarks.filter(func(l: Dictionary) -> bool: return l["kind"] == "marco")
	_check("o mapa tem o marco da torre", found.size() == 1 and found[0]["name"] == "Torre do relógio")

	var clear: float = tower.COLUMN_SIZE
	var friends_ok := true
	for i in 12:
		var spot: Vector3 = city._plaza_friend_position(i, 12)
		friends_ok = friends_ok and Vector2(spot.x, spot.z).length() > clear
	_check("nenhum amigo da praça encosta na coluna", friends_ok)
	_check("a estação Central não encosta na coluna",
			Vector2(city.METRO_CENTRAL_SPOT.x, city.METRO_CENTRAL_SPOT.z).length() > clear)

	var bushes := 0
	var plaza_half: float = CityLayout.BLOCK_SIZE / 2.0
	for node in city.find_children("*", "Node3D", true, false):
		if String(node.scene_file_path).contains("plant_bush") \
				and absf(node.position.x) < plaza_half and absf(node.position.z) < plaza_half:
			bushes += 1
	_check("a praça não tem arbusto (%d na praça)" % bushes, bushes == 0)
	_finish()


func _finish() -> void:
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
