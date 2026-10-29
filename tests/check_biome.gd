extends SceneTree
## Teste do bioma no chão (Fase 15.6): com 200 jogos falsos, só o bairro com
## bioma (o RPG, com a montanha) muda. Ele fica com a fatia no norte, arcos no
## lugar dos prédios, neve nos quarteirões e nas ruas (setor coberto com a
## marca "snow"), e as faixas e poças da cidade pulam as zonas dele.
var failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 200, false, true)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(0.5).timeout

	var biome_ids: Array[String] = []
	for district in Profiles.districts():
		if district.biome != null:
			biome_ids.append(district.id)
	print("bairros com bioma: ", biome_ids)
	_check("só o RPG tem bioma", biome_ids.size() == 1 and biome_ids[0] == "rpg")

	print("\n== cascas ==")
	var arches := 0
	var wrong_shell := 0
	for child: Node in city.get_children():
		if not String(child.name).begins_with("Building_"):
			continue
		var is_arch: bool = child.get_script().resource_path.ends_with("arch_shell.gd")
		if child.category_id == "rpg":
			arches += 1
		if is_arch != (child.category_id == "rpg"):
			wrong_shell += 1
	print("   arcos no RPG: ", arches)
	_check("o RPG tem arcos e os outros bairros continuam com prédios", arches > 0 and wrong_shell == 0)

	print("\n== a fatia no norte ==")
	var cells: Array = city._district_cells["rpg"]
	var middle := Vector2.ZERO
	for cell: Vector2i in cells:
		middle += Vector2(cell)
	middle /= float(cells.size())
	print("   meio dos quarteirões do RPG: ", middle)
	_check("o RPG fica ao norte da praça (z < 0)", middle.y < 0.0 and absf(middle.x) <= absf(middle.y))

	print("\n== setor coberto ==")
	var cover: StaticBody3D = city.get_node_or_null("BiomeCover_rpg")
	_check("o RPG tem o setor coberto", cover != null)
	_check("o setor coberto tem a marca \"snow\"", cover != null and cover.get_meta("footstep", "") == "snow")
	var others := 0
	for child: Node in city.get_children():
		if String(child.name).begins_with("BiomeCover_") and child != cover:
			others += 1
	_check("nenhum outro bairro tem setor coberto", others == 0)
	var half: float = (city.get_node("CityMap").get_map_data()["bounds"] as Rect2).size.x / 2.0
	# (BiomeBuilder e BiomeAtmosphere usam autoloads: no teste vão por load(), sem o nome da classe.)
	var builder: GDScript = load("res://worlds/city/biome/biome_builder.gd")
	# Só as zonas dentro da mureta: a da montanha (15.9) não ganha chão de neve.
	var bounds := Rect2(-half, -half, half * 2.0, half * 2.0)
	var town: Array[Rect2] = []
	town.assign(city.get_node("CityMap").zone_rects("rpg").filter(func(r: Rect2) -> bool: return bounds.encloses(r)))
	var rects: Array[Rect2] = builder.covered_rects(town, half, true)
	var shapes := 0
	if cover != null:
		for child: Node in cover.get_children():
			if child is CollisionShape3D:
				shapes += 1
	_check("uma colisão por zona do RPG (%d)" % rects.size(), shapes == rects.size() and not rects.is_empty())
	var reaches_wall := false
	for rect in rects:
		reaches_wall = reaches_wall or is_equal_approx(rect.position.y, -half)
	_check("a neve da borda vai até a mureta do norte", reaches_wall)

	print("\n== neve debaixo do jogador ==")
	var player = city.get_node("Player")
	# Na rua, no canto de uma zona do RPG (o cruzamento fica livre de postes).
	var zone: Rect2 = city.get_node("CityMap").zone_rects("rpg")[0]
	var spot := zone.position + Vector2(1.5, 1.5)
	player.global_position = Vector3(spot.x, 0.5, spot.y)
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	print("   superfície em ", spot, ": ", player.get_surface())
	_check("na rua do RPG a superfície é \"snow\"", player.get_surface() == "snow")

	print("\n== névoa e vento (15.12, ligados ao juntar) ==")
	var atmosphere: Node = city.get_node_or_null("BiomeAtmosphere_rpg")
	_check("o RPG tem a atmosfera do bioma", atmosphere != null)
	var bed: AudioStreamPlayer = city.get_ambience_bed()
	_check("o fundo da cidade está no grupo city_ambience_bed", bed != null and bed.is_in_group(&"city_ambience_bed"))
	if atmosphere != null:
		atmosphere.update_now()
		_check("dentro do RPG o peso da névoa é 1 (%.2f)" % atmosphere.get_weight(), is_equal_approx(atmosphere.get_weight(), 1.0))
	var albedo_max: float = load("res://worlds/city/biome/biome_atmosphere.gd").SNOW_ALBEDO_MAX
	var snow_color: Color = builder.ground_material(builder.biome_of("rpg")).albedo_color
	_check("a neve não passa do albedo %.2f" % albedo_max,
			maxf(snow_color.r, maxf(snow_color.g, snow_color.b)) <= albedo_max)

	player.global_position = Vector3(0.0, 0.5, 40.0)
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	_check("ao sul da praça (fora do RPG) continua \"concrete\"", player.get_surface() == "concrete")
	if atmosphere != null:
		atmosphere.update_now()
		_check("longe do RPG o peso da névoa é 0", atmosphere.get_weight() == 0.0)

	print("\n== faixas e poças ==")
	var dashes_in := 0
	var markings: MultiMeshInstance3D = city.get_node("LaneMarkings")
	for i in markings.multimesh.instance_count:
		var origin := markings.multimesh.get_instance_transform(i).origin
		if _inside(Vector2(origin.x, origin.z), rects):
			dashes_in += 1
	var puddles_in := 0
	var puddles := 0
	for child: Node in city.get_children():
		if child is Decal:
			puddles += 1
			if _inside(Vector2(child.position.x, child.position.z), rects):
				puddles_in += 1
	print("   faixas: %d (na neve: %d); poças: %d (na neve: %d)" % [markings.multimesh.instance_count, dashes_in, puddles, puddles_in])
	_check("nenhuma faixa na zona do bioma", dashes_in == 0 and markings.multimesh.instance_count > 0)
	_check("nenhuma poça na zona do bioma", puddles_in == 0 and puddles > 0)

	print("\n== clima ==")
	_check("o clima do RPG é neve", city.get_node_or_null("DistrictWeather_rpg") != null
			and city.get_node("DistrictWeather_rpg").spec.kind == "neve")

	_check_scatter(city, builder)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


## Pinheiros e rochas (15.7): uma MultiMesh por família do bairro, nada nas
## calçadas, nas portas, nas passagens dos arcos nem nas estações; pinheiros a
## 6 m de onde se anda; colisão por cópia; sorteio sempre igual; arcos com a
## pedra de neve por cima. 15.7.1: as distâncias contam "folga + raio" (o tronco
## no pinheiro, o vértice mais longe na rocha), a cópia inteira fica fora da
## faixa da porta, a estação é a boca inteira e cada cilindro é conferido.
func _check_scatter(city: Node, builder: GDScript) -> void:
	print("\n== pinheiros e rochas (15.7) ==")
	var biome = builder.biome_of("rpg")
	var scatter = city.get_node_or_null("BiomeScatter_rpg")  # sem tipo: BiomeScatter usa autoloads
	_check("o RPG tem o BiomeScatter", scatter != null)
	var others := 0
	for child: Node in city.get_children():
		if String(child.name).begins_with("BiomeScatter_") and child != scatter:
			others += 1
	_check("nenhum outro bairro tem pinheiros e rochas", others == 0)
	if scatter == null:
		return

	# Só as zonas dentro da mureta (a da montanha, 15.9, não ganha os enfeites da cidade).
	var bounds: Rect2 = city.get_node("CityMap").get_map_data()["bounds"]
	var town: Array[Rect2] = []
	town.assign(city.get_node("CityMap").zone_rects("rpg").filter(func(r: Rect2) -> bool: return bounds.encloses(r)))
	var regions: Array[Rect2] = builder.scatter_regions(town)
	var keep_out: Array[Vector3] = builder.keep_out_points(city)
	var stations: Array[Rect2] = builder.keep_out_areas(city)
	var scatter_script: GDScript = load("res://worlds/city/biome/biome_scatter.gd")
	# As portas do RPG, com a frente (para a rua), para conferir a faixa da porta.
	var doors: Array[Transform3D] = []
	for node in city.get_tree().get_nodes_in_group("game_portal"):
		if node.get_parent() != null and node.get_parent().get("category_id") == "rpg":
			doors.append(node.global_transform)
	print("   regiões de neve: %d | portas: %d | estações: %d | portas do RPG: %d"
			% [regions.size(), keep_out.size(), stations.size(), doors.size()])
	_check("cada estação do metrô vira uma área livre (a boca inteira)",
			stations.size() == city.get_tree().get_nodes_in_group("transit_stop").size()
			and stations.all(func(r: Rect2) -> bool: return r.get_area() > 4.0))

	var town_specs := 0
	for i in biome.scatter.size():
		var spec = biome.scatter[i]
		var family: MultiMeshInstance3D = scatter.get_node_or_null("Scatter_%d" % i)
		if not spec.in_town:
			_check("família %d (só da montanha) fica fora do bairro" % i, family == null)
			continue
		town_specs += 1
		var label := "pinheiros" if spec.kind == "impostor" else "rochas"
		_check("%s: uma MultiMesh com cópias" % label, family != null and family.multimesh.instance_count > 0)
		if family == null:
			continue
		var transforms: Array[Transform3D] = scatter.get_transforms(i)
		var count := transforms.size()
		_check("%s: a MultiMesh tem todas as cópias (%d)" % [label, count], family.multimesh.instance_count == count)
		var outside_snow := 0
		var near_walk := 0
		var in_door := 0
		var near_keep := 0
		var bad_body := 0
		var body: StaticBody3D = scatter.get_node_or_null("ScatterCollision_%d" % i)
		# A rocha medida aqui mesmo, pelos vértices (e não pela caixa da malha).
		var rock: Dictionary = scatter_script.mesh_of(spec.source) if spec.kind == "mesh" else {}
		for k in count:
			var origin := transforms[k].origin
			var spot := Vector2(origin.x, origin.z)
			var item_scale := transforms[k].basis.get_scale()
			var cylinder: CollisionShape3D = body.get_child(k) if body != null and k < body.get_child_count() else null
			# O raio da cópia: no pinheiro, o tronco (o cilindro; os 6 m contam
			# dele, decisão do dono); na rocha, o vértice mais longe, na escala dela.
			var radius := 0.0
			if spec.kind == "mesh":
				radius = float(rock["reach"]) * item_scale.x
			elif cylinder != null:
				radius = (cylinder.shape as CylinderShape3D).radius
			if cylinder != null:
				var shape := cylinder.shape as CylinderShape3D
				var same_spot := Vector2(cylinder.position.x, cylinder.position.z).distance_to(spot) < 0.01
				var top := cylinder.position.y + shape.height / 2.0
				var body_ok := same_spot and absf(cylinder.position.y - shape.height / 2.0) < 0.01
				if spec.kind == "mesh":
					# Cobre a pedra e para no topo desenhado (ela é enterrada um pouco).
					var drawn_top: float = origin.y + ((rock["aabb"] as AABB).end.y) * item_scale.y
					body_ok = body_ok and shape.radius >= radius - 0.001 and absf(top - drawn_top) < 0.01
				if not body_ok:
					bad_body += 1
			var region_ok := false
			for region in regions:
				if region.has_point(spot):
					region_ok = true
					# A beira da região é a calçada: a cópia fica a "folga + raio" dela.
					var gap := minf(minf(spot.x - region.position.x, region.end.x - spot.x),
							minf(spot.y - region.position.y, region.end.y - spot.y))
					if gap < spec.walkable_clearance + radius - 0.01:
						near_walk += 1
			if not region_ok:
				outside_snow += 1
			for point in keep_out:
				if spot.distance_to(Vector2(point.x, point.y)) < maxf(point.z, spec.walkable_clearance) + radius - 0.01:
					near_keep += 1
			for area in stations:
				if scatter_script.area_distance(area, spot) < maxf(scatter_script.AREA_GAP, spec.walkable_clearance) + radius - 0.01:
					near_keep += 1
			# A faixa da porta: da rua (6 m à frente) até 3 m atrás da passagem do
			# arco, e nenhum pedaço da cópia dentro dela.
			for door in doors:
				var local := door.affine_inverse() * origin
				if absf(local.x) < 2.5 + radius and local.z > -3.0 - radius and local.z < 6.0 + radius:
					in_door += 1
		print("   %s: %d cópias; fora da neve %d, perto da calçada %d, na faixa da porta %d, perto de porta/estação %d"
				% [label, count, outside_snow, near_walk, in_door, near_keep])
		_check("%s: todos no miolo de neve (nada na calçada nem na rua)" % label, outside_snow == 0)
		_check("%s: a %.0f m ou mais da calçada (e a cópia inteira na neve)" % [label, spec.walkable_clearance], near_walk == 0)
		_check("%s: nada na faixa da porta nem na passagem do arco" % label, in_door == 0)
		_check("%s: longe das portas e das estações" % label, near_keep == 0)
		if spec.collision_radius > 0.0:
			_check("%s: um cilindro de colisão por cópia" % label, body != null and body.get_child_count() == count)
			_check("%s: cada cilindro no lugar da cópia, do chão para cima%s (%d errados)"
					% [label, ", cobrindo a pedra até o topo desenhado" if spec.kind == "mesh" else "", bad_body], bad_body == 0)
		if spec.kind == "impostor":
			var material: ShaderMaterial = family.material_override
			var tint: Color = material.get_shader_parameter("tint")
			_check("pinheiros: atlas do pinheiro, tinta do perfil e vento ligado",
					material.get_shader_parameter("atlas").resource_path == spec.source
					and tint.is_equal_approx(spec.tint)
					and float(material.get_shader_parameter("sway_amount")) > 0.0)
			var heights_ok := true
			for k in count:
				var height: float = transforms[k].basis.get_scale().y \
						* float(load("res://assets/generated/pine_impostor.json").data["tree_height"])
				heights_ok = heights_ok and height >= spec.height_range.x - 0.01 and height <= spec.height_range.y + 0.01
			_check("pinheiros: altura entre %.0f e %.0f m" % [spec.height_range.x, spec.height_range.y], heights_ok)
		else:
			var material: ShaderMaterial = family.material_override
			_check("rochas: pedra com neve por cima",
					material != null and material.shader.resource_path.ends_with("snow_cover.gdshader")
					and is_equal_approx(float(material.get_shader_parameter("snow_cover")), biome.snow_cover))
	_check("uma MultiMesh por família do bairro (%d)" % town_specs,
			scatter.find_children("*", "MultiMeshInstance3D", false, false).size() == town_specs)

	# O sorteio é sempre igual (mesma entrada, mesmo resultado).
	var first: Array = scatter_script.plan(biome.scatter[0], regions, keep_out, [] as Array[Vector3], 7, 8.8, 0.44, stations)
	var second: Array = scatter_script.plan(biome.scatter[0], regions, keep_out, [] as Array[Vector3], 7, 8.8, 0.44, stations)
	_check("o sorteio é determinístico (%d cópias)" % first.size(), not first.is_empty() and first == second)

	# Os arcos do bioma usam a pedra com neve por cima.
	var dressed := 0
	var arches := 0
	for child: Node in city.get_children():
		if String(child.name).begins_with("Building_") and child.get("category_id") == "rpg":
			arches += 1
			var stone: Node = child.get_node_or_null("Stone")
			var mesh: MeshInstance3D = stone.get_child(0) if stone != null else null
			if mesh != null and mesh.material_override is ShaderMaterial \
					and mesh.material_override.shader.resource_path.ends_with("snow_cover.gdshader"):
				dressed += 1
	_check("os arcos do RPG têm neve por cima (%d de %d)" % [dressed, arches], arches > 0 and dressed == arches)


static func _inside(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if rect.has_point(point):
			return true
	return false


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
