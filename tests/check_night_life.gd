extends SceneTree
## Teste da "noite viva" (P2.15): vitrines, círculos de luz e poças.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame

	var building = city.get_node("Building_2379780")
	var walls: ShaderMaterial = building._walls_material
	var center: Vector3 = walls.get_shader_parameter("building_center")
	var door_normal: Vector3 = walls.get_shader_parameter("door_normal")
	_check("fachada sabe onde está o prédio e a porta", center.distance_to(building.global_position) < 0.01
		and door_normal.is_equal_approx(building.global_basis.z.normalized()))

	var puddles := 0
	var pools: Array = []
	for node in city.find_children("*", "Decal", true, false):
		if node.get_parent() == city and node.texture_orm != null:
			puddles += 1
		elif node.get_parent() is StreetLight:
			pools.append(node)
	print("   poças: %d | círculos de luz: %d" % [puddles, pools.size()])
	_check("poças nas ruas", puddles > 10)
	_check("um círculo por poste", pools.size() == city.find_children("*", "StreetLight", true, false).size())

	city._on_night_changed(1.0)
	_check("círculos acesos à noite", pools[0].visible and pools[0].emission_energy > 0.3)
	city._on_night_changed(0.0)
	_check("e apagados de dia", not pools[0].visible)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
