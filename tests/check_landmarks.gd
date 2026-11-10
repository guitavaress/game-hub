extends SceneTree
## Teste dos marcos altos da cidade (Fase 11.5: a torre do relógio da praça):
##   - a torre existe, passa da altura de um prédio de 3 andares e tem colisão só na coluna;
##   - os ponteiros seguem a hora (15:30 = horas entre o 3 e o 4, minutos no 6);
##   - o mapa tem o marco "Torre do relógio";
##   - ninguém da praça (amigos, estação do metrô) encosta na coluna;
##   - as floreiras da praça ficam sem arbusto.
## E os marcos dos bairros (Fase 11.6), com 200 jogos; desde a 15.10, a torre
## do RPG (arcos, sem telhado) fica ancorada no mirante da montanha e, com
## 1000 jogos (sem montanha), no meio do primeiro quarteirão do bairro.

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

	# A luz própria da noite (17.5): holofotes de baixo para cima e o chafariz.
	var night_lights: Array = tower.get_night_lights()
	var uplights := night_lights.filter(func(l: Light3D) -> bool: return l is SpotLight3D)
	tower.set_night(1.0)
	_check("à noite, quatro holofotes e a luz do chafariz acesos (%d luzes)" % night_lights.size(),
			uplights.size() == 4 and night_lights.size() == 5
			and night_lights.all(func(l: Light3D) -> bool: return l.visible and l.light_energy > 0.5))
	_check("os holofotes apontam para cima, para a torre",
			uplights.all(func(l: SpotLight3D) -> bool: return l.global_basis.z.y < -0.8))
	var quiet := true
	for light: Light3D in night_lights:
		quiet = quiet and not light.shadow_enabled and light.light_cull_mask & (1 << 19) == 0
	_check("nenhuma luz da torre faz sombra nem entra em casa", quiet)
	tower.set_night(0.0)
	_check("de dia, as luzes da torre ficam apagadas",
			night_lights.all(func(l: Light3D) -> bool: return not l.visible))

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
				and not city.get_home().is_ancestor_of(node):
			var position: Vector3 = city.to_local(node.global_position)
			if absf(position.x) >= plaza_half or absf(position.z) >= plaza_half:
				continue
			bushes += 1
	_check("a praça não tem arbusto (%d na praça)" % bushes, bushes == 0)

	city.queue_free()
	await process_frame
	await _check_district_landmarks()
	await _check_landmark_without_mountain()
	_finish()


## Com 200 jogos falsos: todo bairro, menos a Simulação (a grua), tem um marco, o topo
## passa do prédio mais alto possível e o letreiro fica acima dele.
func _check_district_landmarks() -> void:
	print("== marcos dos bairros (200 jogos) ==")
	var library_script: GDScript = load("res://tests/fake_library.gd")
	library_script.install(root, 200)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame
	var profiles: GDScript = load("res://profiles/profiles.gd")
	var variant_class: GDScript = load("res://worlds/city/building_variant.gd")
	var sign_class: GDScript = load("res://worlds/city/district_sign.gd")
	var plate_half: float = sign_class.PLATE_HEIGHT * city.DISTRICT_SIGN_TEXT_HEIGHT / sign_class.TEXT_HEIGHT / 2.0
	var expected := 0
	var found := 0
	for id: String in city._district_cells:
		var profile = profiles.district(id)
		var landmark: Node = city.get_node_or_null("DistrictLandmark_%s" % id)
		if id == "simulacao":
			_check("simulacao não tem marco (a grua é o marco)", landmark == null and profile.landmark_script.is_empty())
			continue
		if profile.effective_shell() != "building":
			# Com arcos (o bioma do RPG, desde a 15.6), o marco não tem prédio
			# onde ficar: desde a 15.10, fica ancorado no mirante da montanha.
			expected += 1
			if landmark == null:
				_check("%s (arcos) tem marco ancorado" % id, false)
				continue
			found += 1
			_check_mountain_tower(city, id, landmark)
			continue
		_check("%s tem landmark_script no perfil" % id, profile != null and not profile.landmark_script.is_empty())
		expected += 1
		if landmark == null:
			_check("%s tem marco" % id, false)
			continue
		found += 1
		var top: float = landmark.get_top_y()
		_check("%s: o topo (%.1f m) passa do prédio mais alto possível (%.1f m)" % [id, top, variant_class.max_total_height()],
				top > variant_class.max_total_height())
		var district_sign: Node3D = city.get_node("DistrictSign_%s" % id)
		_check("%s: o letreiro fica acima do marco" % id, district_sign.position.y - plate_half > top)
	_check("todos os bairros, menos a Simulação, têm marco (%d)" % expected, expected == city._district_cells.size() - 1 and found == expected)
	city.queue_free()
	await process_frame


## A torre ancorada no mirante (15.10): na base que a montanha dá, mais larga,
## com colisão, néon que acende à noite, e o letreiro do bairro fica onde estava.
func _check_mountain_tower(city: Node, id: String, landmark: Node) -> void:
	var terrain: Node = city.get_node_or_null("BackdropTerrain_%s" % id)
	_check("%s: a montanha existe (200 jogos)" % id, terrain != null)
	if terrain == null:
		return
	var spot: Vector3 = terrain.tower_spot()
	var lookout: Vector3 = terrain.lookout_world()
	print("   torre do %s em %s, topo a %.1f m" % [id, landmark.global_position, landmark.get_top_y()])
	_check("%s: o marco está ancorado" % id, landmark.is_anchored())
	_check("%s: a torre fica no ponto da montanha (no mirante)" % id,
			landmark.global_position.distance_to(spot) < 0.01
			and Vector2(spot.x - lookout.x, spot.z - lookout.z).length() < terrain.field.lookout_radius)
	_check("%s: o bloco cinza da 15.9 saiu" % id, terrain.get_node_or_null("TowerMarker") == null)
	_check_tower_body(id, landmark)
	var district_sign: Node3D = city.get_node("DistrictSign_%s" % id)
	_check("%s: o letreiro não sobe por causa da torre do mirante" % id,
			district_sign.position.y < landmark.get_top_y())


## A forma da torre ancorada: ~6 m de fuste, colisão na base e néon no topo.
func _check_tower_body(id: String, landmark: Node) -> void:
	var base: Rect2 = landmark.footprint()
	_check("%s: a base tem ~6 m (%.1f m)" % [id, base.size.x], absf(base.size.x - 6.0) < 0.01 and absf(base.size.y - 6.0) < 0.01)
	_check("%s: a base tem colisão" % id, landmark.get_node_or_null("Solid") is StaticBody3D)
	_check("%s: entra no grupo que os pinheiros evitam" % id, landmark.is_in_group(&"scatter_keep_out"))
	# 17.10: o fuste é de pedra (a textura PBR do projeto, projetada pelo
	# mundo) e não mais o bloco liso azul-escuro de concreto.
	var shaft: float = landmark.shaft_size()
	var shaft_mesh: MeshInstance3D = null
	var tallest := 0.0
	for child: Node in landmark.find_children("*", "MeshInstance3D", true, false):
		var piece := child as MeshInstance3D
		if piece.mesh is BoxMesh and (piece.mesh as BoxMesh).size.y > tallest:
			tallest = (piece.mesh as BoxMesh).size.y
			shaft_mesh = piece
	var stone: StandardMaterial3D = shaft_mesh.material_override as StandardMaterial3D if shaft_mesh != null else null
	_check("%s: o fuste é de pedra, com relevo (textura projetada pelo mundo e cor clara)" % id,
			stone != null and stone.albedo_texture != null and stone.uv1_triplanar
			and not stone.vertex_color_use_as_albedo and stone.albedo_color.v > 0.5)
	# A cornija em degraus embaixo da plataforma: três anéis mais largos que o
	# fuste, cada vez mais largos de baixo para cima (a silhueta de castelo).
	var steps: Array[Vector2] = []  # (altura do meio, largura)
	for child: Node in landmark.find_children("*", "MeshInstance3D", true, false):
		var piece := child as MeshInstance3D
		if piece.material_override != stone or not (piece.mesh is BoxMesh):
			continue
		var size := (piece.mesh as BoxMesh).size
		if size.y < 1.0 and size.x > shaft + 0.01 and size.x < shaft + 3.0:
			steps.append(Vector2(piece.position.y, size.x))
	steps.sort()
	_check("%s: a cornija tem três degraus, cada vez mais largos (%d)" % [id, steps.size()],
			steps.size() == 3 and steps[0].x < steps[1].x and steps[1].x < steps[2].x
			and steps[0].y < steps[1].y and steps[1].y < steps[2].y)
	# O portal: o vão escuro nas duas faces maiores (a torre fica ao alcance do
	# jogador e era uma parede cega).
	var doors := 0
	for child: Node in landmark.find_children("*", "MeshInstance3D", true, false):
		var piece := child as MeshInstance3D
		var material := piece.material_override as StandardMaterial3D
		if material == null or not (piece.mesh is BoxMesh) or material.albedo_color.v >= 0.1:
			continue
		var size := (piece.mesh as BoxMesh).size
		if size.y > 2.5 and size.y < 3.5 and size.x > 1.2 and size.x < 2.4:
			doors += 1
	print("   portais: %d (vão escuro nas faces da praça e de trás)" % doors)
	_check("%s: as duas faces maiores têm portal (vão escuro)" % id, doors == 2)
	var neon_top := 0.0
	var neon: StandardMaterial3D = landmark.get("_neon_material")
	for child: Node in landmark.find_children("*", "MeshInstance3D", true, false):
		if (child as MeshInstance3D).material_override == neon:
			neon_top = maxf(neon_top, (child as Node3D).global_position.y)
	_check("%s: tem néon no topo (até %.1f m, topo a %.1f m)" % [id, neon_top, landmark.get_top_y()],
			neon_top > landmark.get_top_y() - 8.0)
	landmark.set_night(1.0)
	var night_energy := neon.emission_energy_multiplier
	landmark.set_night(0.0)
	_check("%s: o néon acende à noite (grupo city_night)" % id,
			landmark.is_in_group("city_night") and night_energy > neon.emission_energy_multiplier)


## Sem montanha (1000 jogos: a cidade é grande demais para ela), a torre do
## RPG volta ao meio do primeiro quarteirão do bairro, no chão; o letreiro fica
## acima dela, e nenhum pinheiro, rocha ou arco fica na base dela.
func _check_landmark_without_mountain() -> void:
	print("== a torre do RPG sem montanha (1000 jogos) ==")
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 1000, false, true)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await physics_frame
	await physics_frame
	_check("sem montanha", get_nodes_in_group("mountain_trail").is_empty())
	var landmark: Node3D = city.get_node_or_null("DistrictLandmark_rpg")
	_check("o RPG tem marco mesmo sem montanha", landmark != null)
	if landmark == null:
		city.queue_free()
		await process_frame
		return
	var first: Vector2i = city._district_cells["rpg"][0]
	var center := CityLayout.block_center(first)
	print("   torre em %s; meio do 1º quarteirão em %s" % [landmark.global_position, center])
	_check("ancorado no meio do primeiro quarteirão, no chão",
			landmark.is_anchored() and landmark.global_position.distance_to(center) < 0.01)
	_check_tower_body("rpg", landmark)
	# 15.13.4: quatro braseiros; a chama brilha mais de noite que de dia.
	_check("a torre tem quatro braseiros (%d)" % landmark._flames.size(), landmark._flames.size() == 4)
	landmark.set_night(0.0)
	var day_glow: float = landmark._flame_material.emission_energy_multiplier
	landmark.set_night(1.0)
	var night_glow: float = landmark._flame_material.emission_energy_multiplier
	_check("a chama é mais forte de noite (%.1f contra %.1f de dia)" % [night_glow, day_glow], night_glow > day_glow * 3.0)
	var light_count := 0
	for light in landmark.find_children("*", "Light3D", true, false):
		light_count += 1
	_check("os braseiros não criam luz nova (só emissão)", light_count == 0)
	var variant_class: GDScript = load("res://worlds/city/building_variant.gd")
	_check("o topo passa do prédio mais alto possível (%.1f m)" % landmark.get_top_y(),
			landmark.get_top_y() > variant_class.max_total_height())
	var district_sign: Node3D = city.get_node("DistrictSign_rpg")
	_check("o letreiro sobe para ficar acima da torre", district_sign.position.y > landmark.get_top_y())

	# Nenhum pinheiro nem rocha na base (com a folga do espalhamento).
	var base: Rect2 = landmark.footprint()
	var world_base := Rect2(Vector2(center.x, center.z) + base.position, base.size)
	var inside := 0
	for child: Node in city.get_children():
		if child.has_method("get_transforms"):
			for index in 8:
				for item: Transform3D in child.get_transforms(index):
					if world_base.grow(0.5).has_point(Vector2(item.origin.x, item.origin.z)):
						inside += 1
	_check("nenhum pinheiro ou rocha na base da torre (%d)" % inside, inside == 0)
	# Nenhum arco (nem outra coisa sólida) dentro da base, acima do chão.
	var box := BoxShape3D.new()
	box.size = Vector3(base.size.x, 3.0, base.size.y)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, center + Vector3(0.0, 2.0, 0.0))
	query.exclude = [(landmark.get_node("Solid") as CollisionObject3D).get_rid()]
	var hits: Array = city.get_world_3d().direct_space_state.intersect_shape(query, 4)
	_check("nada sólido dentro da base da torre (%d)" % hits.size(), hits.is_empty())
	city.queue_free()
	await process_frame


func _finish() -> void:
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
