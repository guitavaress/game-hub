extends SceneTree
## Teste da montanha atrás do bairro (Fase 15.9). Desde a 15.9.1b (greybox):
## com 200 jogos falsos, o bairro com terreno de fundo (o RPG) ganha uma
## montanha só, atrás da mureta do norte, com a trilha do vão até o mirante.
## Confere:
##   - a trilha começa na mureta e termina na altura do mirante;
##   - raio para baixo em 50 pontos da trilha bate com os triângulos
##     desenhados (±5 cm), no corpo com a marca "snow";
##   - a mureta tem um vão só, onde a trilha passa, e o chão continua ali;
##   - o bloco da torre fica no mirante;
##   - sem espaço (cidade grande demais), não há montanha.
## (Scripts que usam autoloads vão por load(), sem o nome da classe: em -s,
## o nome puxa os autoloads antes da hora.)
var failures: int = 0
var _space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 200, false, true)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	var started := Time.get_ticks_msec()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	print("cidade montada em %d ms (com a montanha)" % (Time.get_ticks_msec() - started))
	await physics_frame
	await physics_frame
	_space = city.get_world_3d().direct_space_state

	var terrains := get_nodes_in_group("mountain_trail")
	_check("uma montanha só, a do RPG", terrains.size() == 1 and terrains[0].name == "BackdropTerrain_rpg")
	if terrains.size() != 1:
		_finish()
		return
	var terrain = terrains[0]
	var field: Heightfield = terrain.field
	var trail: MountainTrail = terrain.trail
	var half: float = field.half
	var points: PackedVector3Array = terrain.trail_world_points()
	print("   trilha: %d pontos, %.0f m; mirante em %s" % [points.size(), trail.length(), terrain.lookout_world()])

	print("\n== começo e fim ==")
	var first := points[0]
	_check("a trilha começa na mureta", absf(maxf(absf(first.x), absf(first.z)) - half) < 0.5 and absf(first.y) < 0.01)
	_check("ela sai pelo norte (o lado do RPG)", trail.outward.is_equal_approx(Vector2(0.0, -1.0)))
	_check("e termina na altura do mirante", absf(points[points.size() - 1].y - field.lookout_height) < 0.01)
	_check("o mirante fica na altura do perfil", is_equal_approx(terrain.lookout_world().y, field.lookout_height))

	print("\n== colisão = desenho ==")
	var cell: float = load("res://worlds/city/biome/backdrop_terrain.gd").CELL_METERS
	var worst := 0.0
	var worst_trail := 0.0
	var misses := 0
	var wrong_body := 0
	for k in 50:
		var p := points[int(k * (points.size() - 1) / 49.0)]
		var hit := _ray_down(Vector2(p.x, p.z), p.y + 3.0)
		if hit.is_empty():
			misses += 1
			continue
		if hit["collider"].get_meta("footstep", "") != "snow":
			wrong_body += 1
		worst = maxf(worst, absf(hit["position"].y - _drawn_height(field, Vector2(p.x, p.z), cell)))
		worst_trail = maxf(worst_trail, absf(hit["position"].y - p.y))
	print("   maior diferença: %.3f m do desenho, %.3f m do traçado da trilha" % [worst, worst_trail])
	_check("os 50 raios acertam o chão", misses == 0)
	_check("o chão da trilha tem a marca \"snow\"", wrong_body == 0)
	_check("a colisão bate com os triângulos desenhados (±5 cm)", worst <= 0.05)
	_check("e fica perto do traçado da trilha (±25 cm)", worst_trail <= 0.25)

	print("\n== o vão da mureta ==")
	var openings: Array[Rect2] = terrain.get_openings()
	_check("um vão só", openings.size() == 1)
	var start := Vector2(first.x, first.z)
	var out := trail.outward
	var across := _ray(Vector3(start.x - out.x * 2.0, 0.6, start.y - out.y * 2.0),
			Vector3(start.x + out.x * 2.0, 0.6, start.y + out.y * 2.0))
	_check("a mureta e a barreira deixam passar no vão", across.is_empty())
	var beside := start + Vector2(-out.y, out.x) * (field.trail_width + 2.0)
	var blocked := _ray(Vector3(beside.x - out.x * 2.0, 0.6, beside.y - out.y * 2.0),
			Vector3(beside.x + out.x * 2.0, 0.6, beside.y + out.y * 2.0))
	_check("ao lado do vão, a mureta continua", not blocked.is_empty())
	var barriers := 0
	for child: Node in city.get_children():
		if String(child.name).begins_with("Barrier"):
			barriers += 1
	_check("a barreira de um lado vira dois trechos (5 no total)", barriers == 5)
	var floor_hits := 0
	for step: float in [-1.5, 0.0, 1.5, 4.0]:
		var hit := _ray_down(start + out * step, 2.0)
		if not hit.is_empty() and absf(hit["position"].y) < 0.1:
			floor_hits += 1
	_check("o chão continua de dentro para fora do vão", floor_hits == 4)

	print("\n== a torre (greybox) ==")
	var tower: Node3D = terrain.get_node_or_null("TowerMarker")
	var lookout: Vector3 = terrain.lookout_world()
	_check("o bloco da torre fica no mirante", tower != null
			and Vector2(tower.position.x - lookout.x, tower.position.z - lookout.z).length() <= field.lookout_radius
			and tower.position.y > lookout.y)

	print("\n== fora da linha praça–obelisco (15.9.2) ==")
	var script: GDScript = load("res://worlds/city/biome/backdrop_terrain.gd")
	var off: float = terrain.lookout_angle()
	print("   o mirante fica a %.1f° da bissetriz da cunha" % rad_to_deg(off))
	_check("o mirante sai da linha praça–obelisco (≥ %.0f°)" % rad_to_deg(script.LOOKOUT_MIN_ANGLE),
			absf(off) >= script.LOOKOUT_MIN_ANGLE - 0.0001)
	# Da praça, ao sul do obelisco (o ponto da captura), a linha até a torre passa longe dele.
	var eye := Vector2(0.0, 12.0)
	var to_tower := Vector2(tower.position.x, tower.position.z) - eye
	var clearance := absf(eye.cross(to_tower.normalized()))
	print("   da praça, a linha até a torre passa a %.1f m do obelisco" % clearance)
	_check("a linha da praça até a torre passa a mais de 3 m do obelisco", clearance > 3.0)
	_check("o bloco da torre tem ~6 m de largura", is_equal_approx((tower.mesh as BoxMesh).size.x, 6.0))

	print("\n== a montanha é zona do bairro (15.9.2) ==")
	var map = city._map
	var inside := Rect2(-half, -half, half * 2.0, half * 2.0)
	var mountain_zones: Array[Rect2] = []
	for zone: Rect2 in map.zone_rects("rpg"):
		if not inside.encloses(zone):
			mountain_zones.append(zone)
	_check("uma zona fora da mureta, a da montanha", mountain_zones.size() == 1)
	if mountain_zones.size() == 1:
		var outside_points := 0
		var covered_points := 0
		for p in points:
			if absf(p.z) > half + 0.01:
				outside_points += 1
				if mountain_zones[0].has_point(Vector2(p.x, p.z)):
					covered_points += 1
		_check("a zona cobre a trilha toda depois da mureta (%d de %d pontos)" % [covered_points, outside_points],
				outside_points > 0 and covered_points == outside_points)
		_check("e não entra na cidade", not mountain_zones[0].intersects(inside))
	_check("no mirante, zone_id_at diz \"rpg\"", map.zone_id_at(lookout) == "rpg")
	var weather: Node = city.get_node_or_null("DistrictWeather_rpg")
	_check("o clima do RPG vale na montanha", weather != null
			and (weather.areas as Array).any(func(r: Rect2) -> bool: return r.has_point(Vector2(lookout.x, lookout.z))))
	var atmosphere: Node = city.get_node_or_null("BiomeAtmosphere_rpg")
	_check("a névoa e o vento valem inteiros no mirante", atmosphere != null
			and is_equal_approx(atmosphere.wind_weights(lookout).x, 1.0))
	var cover: Node3D = city.get_node_or_null("BiomeCover_rpg")
	var cover_outside := 0
	if cover != null:
		for shape: Node in cover.get_children():
			if shape is CollisionShape3D and maxf(absf(shape.position.x), absf(shape.position.z)) > half:
				cover_outside += 1
	_check("o chão de neve da cidade não vai para a montanha", cover != null and cover_outside == 0)
	var scatter_outside := 0
	for child: Node in city.get_children():
		if child.has_method("get_transforms"):
			for index in 8:
				for item: Transform3D in child.get_transforms(index):
					if maxf(absf(item.origin.x), absf(item.origin.z)) > half:
						scatter_outside += 1
	_check("os pinheiros e as rochas da cidade ficam dentro da mureta", scatter_outside == 0)

	print("\n== sem espaço, sem montanha ==")
	var sector: DistrictSector = city._sectors["rpg"]
	var spec: TerrainSpec = Profiles.district("rpg").biome.backdrop
	var crowded = load("res://worlds/city/biome/backdrop_terrain.gd").new()
	_check("com a borda a 300 m, a montanha não cabe", not crowded.setup(spec, sector, 300.0))
	crowded.free()
	_finish()


func _finish() -> void:
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


## A altura dos triângulos desenhados (TerrainMesh) num ponto: a mesma grade e
## a mesma diagonal (do canto 0 ao canto 3 de cada quadrado).
static func _drawn_height(field: Heightfield, p: Vector2, cell: float) -> float:
	var local := (p - field.grid_origin) / cell
	var corner := local.floor()
	var f := local - corner
	var base := field.grid_origin + corner * cell
	var h00 := field.surface_at(base)
	var h10 := field.surface_at(base + Vector2(cell, 0.0))
	var h01 := field.surface_at(base + Vector2(0.0, cell))
	var h11 := field.surface_at(base + Vector2(cell, cell))
	if f.x >= f.y:
		return h00 + f.x * (h10 - h00) + f.y * (h11 - h10)
	return h00 + f.y * (h01 - h00) + f.x * (h11 - h01)


func _ray_down(p: Vector2, from_y: float) -> Dictionary:
	return _ray(Vector3(p.x, from_y, p.y), Vector3(p.x, -0.5, p.y))


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
