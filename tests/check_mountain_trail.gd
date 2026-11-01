extends SceneTree
## Teste da montanha atrás do bairro (Fase 15.9). Desde a 15.9.1b (greybox):
## com 200 jogos falsos, o bairro com terreno de fundo (o RPG) ganha uma
## montanha só, atrás da mureta do norte, com a trilha do vão até o mirante.
## Confere:
##   - a trilha começa na mureta e termina na altura do mirante;
##   - raio para baixo em 50 pontos da trilha bate com os triângulos
##     desenhados (±5 cm), no corpo com a marca "snow";
##   - a mureta tem um vão só, onde a trilha passa, e o chão continua ali;
##   - 15.10: a torre do RPG no mirante; a plataforma de madeira na beirada
##     virada para a praça (piso "wood", guarda-corpo, banco, e a cápsula não
##     cai da ponta);
##   - 15.9.2: o mirante fora da linha do obelisco; a montanha é zona do bairro;
##   - 15.9.3: paredes dos dois lados e em volta do mirante, estacas, lampiões,
##     placa, marco no mapa, neve e rocha, e uma subida de verdade até 10 m;
##   - sem espaço (cidade grande demais), não há montanha (com a cidade
##     inteira: check_mountain_fallback).
## (Scripts que usam autoloads vão por load(), sem o nome da classe: em -s,
## o nome puxa os autoloads antes da hora.)
var failures: int = 0
var _space: PhysicsDirectSpaceState3D
## A plataforma do mirante (15.10), por load(): ela usa o TrailDressing.
var _deck: GDScript = load("res://worlds/city/biome/lookout_deck.gd")


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

	print("\n== a torre (15.10) ==")
	var tower: Node3D = city.get_node_or_null("DistrictLandmark_rpg")
	var lookout: Vector3 = terrain.lookout_world()
	_check("a torre do RPG fica no mirante", tower != null
			and Vector2(tower.global_position.x - lookout.x, tower.global_position.z - lookout.z).length() <= field.lookout_radius
			and is_equal_approx(tower.global_position.y, lookout.y))
	if tower == null:
		_finish()
		return

	print("\n== fora da linha praça–obelisco (15.9.2) ==")
	var script: GDScript = load("res://worlds/city/biome/backdrop_terrain.gd")
	var off: float = terrain.lookout_angle()
	print("   o mirante fica a %.1f° da bissetriz da cunha" % rad_to_deg(off))
	_check("o mirante sai da linha praça–obelisco (≥ %.0f°)" % rad_to_deg(script.LOOKOUT_MIN_ANGLE),
			absf(off) >= script.LOOKOUT_MIN_ANGLE - 0.0001)
	# Da praça, ao sul do obelisco (o ponto da captura), a linha até a torre passa longe dele.
	var eye := Vector2(0.0, 12.0)
	var to_tower := Vector2(tower.global_position.x, tower.global_position.z) - eye
	var clearance := absf(eye.cross(to_tower.normalized()))
	print("   da praça, a linha até a torre passa a %.1f m do obelisco" % clearance)
	_check("a linha da praça até a torre passa a mais de 3 m do obelisco", clearance > 3.0)
	_check("a torre tem ~6 m de largura", is_equal_approx(tower.footprint().size.x, 6.0))

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

	await _check_limits(city, terrain, points)
	_check_deck(terrain, tower)
	_check_signs(city, terrain, points)
	await _check_climb(city, points)

	print("\n== sem espaço, sem montanha ==")
	var sector: DistrictSector = city._sectors["rpg"]
	var spec: TerrainSpec = Profiles.district("rpg").biome.backdrop
	var crowded = load("res://worlds/city/biome/backdrop_terrain.gd").new()
	_check("com a borda a 300 m, a montanha não cabe", not crowded.setup(spec, sector, 300.0))
	crowded.free()
	_finish()


## 15.9.3: as paredes seguram dos dois lados da trilha e em volta do mirante,
## mas não entram no caminho; as estacas ficam na linha delas.
func _check_limits(city: Node, terrain: Node, points: PackedVector3Array) -> void:
	print("\n== limites da trilha (15.9.3) ==")
	var dressing: Node3D = terrain.get_dressing()
	_check("a trilha tem limites e sinalização", dressing != null and dressing.get_node_or_null("TrailWalls") != null)
	if dressing == null:
		return
	var script: GDScript = load("res://worlds/city/biome/trail_dressing.gd")
	var offset: float = script.WALL_OFFSET
	var trail: MountainTrail = terrain.trail
	var field: Heightfield = terrain.field
	var ground_rid: RID = terrain.get_node("TrailCollision").get_rid()
	# A cápsula do jogador (player.tscn), andando de lado a partir do meio da trilha.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.exclude = [ground_rid]
	var lateral_ok := 0
	var lateral_total := 0
	var last := points.size() - 1
	for k in 24:
		var i := 3 + int(k * (last - 6) / 23.0)
		var p := Vector2(points[i].x, points[i].z)
		if p.distance_to(trail.lookout_center) < field.lookout_radius + 3.0:
			continue
		var tangent := (Vector2(points[i + 1].x, points[i + 1].z) - Vector2(points[i - 1].x, points[i - 1].z)).normalized()
		for side: float in [1.0, -1.0]:
			lateral_total += 1
			var normal := Vector2(-tangent.y, tangent.x) * side
			query.transform = Transform3D(Basis.IDENTITY, points[i] + Vector3(0.0, 0.9 + 0.5, 0.0))
			query.motion = Vector3(normal.x, 0.0, normal.y) * (offset + 2.0)
			var moved: float = _space.cast_motion(query)[0] * (offset + 2.0)
			if moved > offset - capsule.radius - 0.35 and moved < offset - capsule.radius + 0.15:
				lateral_ok += 1
	print("   %d de %d empurrões de lado pararam na parede" % [lateral_ok, lateral_total])
	_check("dos dois lados da trilha, a cápsula do jogador para na parede (~%.1f m)" % (offset - capsule.radius),
			lateral_total >= 30 and lateral_ok == lateral_total)

	var blocked_on_path := 0
	query.motion = Vector3.ZERO
	for k in 60:
		var point := points[int(k * last / 59.0)]
		query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0.0, 0.9 + 0.3, 0.0))
		if not _space.intersect_shape(query, 1).is_empty():
			blocked_on_path += 1
	_check("nenhuma parede (nem pilar) no caminho da trilha (60 pontos)", blocked_on_path == 0)

	# O mirante: as paredes em volta, menos onde a trilha chega e onde a
	# plataforma encosta (15.10; a ponta dela é conferida no _check_deck). As
	# direções que dão na torre (atrás do meio) param antes: contam como fechadas.
	var center: Vector3 = terrain.lookout_world() + Vector3(0.0, 0.9 + 0.3, 0.0)
	var entry := (Vector2(points[last - 4].x, points[last - 4].z) - trail.lookout_center).normalized()
	var deck_direction: Vector2 = _deck.direction(field, trail)
	var ring_ok := 0
	var ring_total := 0
	var reach: float = field.lookout_radius + 4.0
	for k in 24:
		var direction := Heightfield.direction_of(TAU * k / 24.0)
		var on_ring: Vector2 = trail.lookout_center + direction * (field.lookout_radius + script.RING_GAP)
		if direction.dot(entry) > 0.8 or _deck.is_in_opening(trail, deck_direction, on_ring):
			continue
		ring_total += 1
		query.transform = Transform3D(Basis.IDENTITY, center)
		query.motion = Vector3(direction.x, 0.0, direction.y) * reach
		var moved: float = _space.cast_motion(query)[0] * reach
		if moved < field.lookout_radius + script.RING_GAP:
			ring_ok += 1
	# Pela entrada, a cápsula passa da linha do anel (a trilha, depois, faz a curva dela).
	var past_ring: float = field.lookout_radius + script.RING_GAP + 1.0
	var exit := (Vector2(points[last - 2].x, points[last - 2].z) - trail.lookout_center).normalized()
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.motion = Vector3(exit.x, 0.0, exit.y) * past_ring
	var entry_free: bool = _space.cast_motion(query)[0] >= 1.0
	_check("o mirante é fechado em volta, fora da entrada e da plataforma (%d de %d direções)" % [ring_ok, ring_total],
			ring_total >= 16 and ring_ok == ring_total)
	_check("e aberto onde a trilha chega", entry_free)

	var lines: Array = script.wall_lines(field, trail)
	var stake_lines: Array = script.stake_lines(lines)
	var stakes := 0
	var off_line := 0
	for line: PackedVector2Array in stake_lines:
		stakes += line.size()
		for p in line:
			var distance := trail.closest(p).x
			var on_ring := absf(p.distance_to(trail.lookout_center) - field.lookout_radius - script.RING_GAP) < 0.05
			if not on_ring and (distance < offset - script.FOLD_TOLERANCE or distance > offset + 0.3):
				off_line += 1
	var multimesh: MultiMesh = (dressing.get_node("Stakes") as MultiMeshInstance3D).multimesh
	print("   %d estacas em %d cercas" % [stakes, stake_lines.size()])
	_check("as estacas são as das cercas (uma MultiMesh)", multimesh.instance_count == stakes)
	_check("e ficam na linha das paredes", stakes > trail.length() * 2.0 / script.STAKE_SPACING * 0.8 and off_line == 0)
	# O anel do mirante vira dois arcos: abre na trilha e na plataforma (que tem guarda-corpo próprio).
	_check("são quatro cercas: os dois lados e os dois arcos do mirante", stake_lines.size() == 4)


## 15.10: a plataforma de madeira na beirada do mirante virada para a praça.
##   - aponta para a praça (o giro, se houver, fica dentro do limite);
##   - raio para baixo no piso inteiro: a madeira ("wood"), na altura do piso,
##     também na parte que fica no ar, além do disco;
##   - a cápsula do jogador, empurrada para a ponta e para os lados, para em
##     cima do piso (não cai);
##   - a abertura do anel deixa passar do disco para a plataforma;
##   - o banco fica no disco, virado para a abertura, com espaço dos lados;
##   - a torre não encosta na plataforma, e o ponto da vista fica na ponta.
func _check_deck(terrain: Node, tower: Node3D) -> void:
	print("\n== a plataforma do mirante (15.10) ==")
	var field: Heightfield = terrain.field
	var trail: MountainTrail = terrain.trail
	var deck: Node3D = terrain.get_deck()
	_check("o mirante tem a plataforma de madeira", deck != null)
	if deck == null:
		return
	var direction: Vector2 = deck.get_direction()
	var toward_plaza := -trail.lookout_center.normalized()
	var turn := rad_to_deg(direction.angle_to(toward_plaza))
	print("   a plataforma aponta a %.0f° da linha até a praça" % absf(turn))
	_check("a abertura fica virada para a praça (até %.0f°)" % rad_to_deg(_deck.MAX_TURN),
			absf(turn) <= rad_to_deg(_deck.MAX_TURN) + 0.01)
	var side := Vector2(-direction.y, direction.x)
	var radius := field.lookout_radius
	var top: float = _deck.deck_top(field)
	var tip: float = radius + _deck.REACH

	# O piso: raios para baixo de 0,5 em 0,5 m, da beirada do disco até a ponta.
	var rays := 0
	var wood := 0
	var level := 0
	var over_air := 0
	var along := radius
	while along <= tip - 0.3:
		for lateral: float in [-1.6, -0.8, 0.0, 0.8, 1.6]:
			var p := trail.lookout_center + direction * along + side * lateral
			var hit := _ray_down(p, top + 2.0)
			rays += 1
			if hit.is_empty():
				continue
			if hit["collider"].get_meta("footstep", "") == "wood":
				wood += 1
			if absf(hit["position"].y - top) < 0.01:
				level += 1
			if field.surface_at(p) < top - 0.5:
				over_air += 1
		along += 0.5
	print("   %d raios no piso: %d na madeira, %d na altura do piso, %d acima da encosta" % [rays, wood, level, over_air])
	_check("o piso inteiro é de madeira (footstep \"wood\")", rays > 30 and wood == rays)
	_check("e fica na altura do piso (±1 cm)", level == rays)
	var tip_point: Vector2 = trail.lookout_center + direction * tip
	var drop: float = top - field.surface_at(tip_point)
	_check("a ponta avança por cima da encosta (o chão %.1f m abaixo; mínimo %.1f m)" % [drop, _deck.MIN_DROP],
			drop >= _deck.MIN_DROP and over_air > 0)

	# A cápsula não cai: empurrada para a ponta e para os lados, ela para no piso.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.exclude = [(deck.get_node("Deck") as CollisionObject3D).get_rid()]
	var middle: Vector2 = trail.lookout_center + direction * (radius + _deck.REACH / 2.0)
	var start := Vector3(middle.x, top + 0.9 + 0.3, middle.y)
	# Do ponto de partida até a borda do piso, em cada direção.
	var pushes: Array[Array] = [[direction, _deck.REACH / 2.0],
			[side, _deck.WIDTH / 2.0], [-side, _deck.WIDTH / 2.0]]
	var held := 0
	for push: Array in pushes:
		var dir: Vector2 = push[0]
		var edge: float = push[1]
		var length := edge + 3.0
		query.transform = Transform3D(Basis.IDENTITY, start)
		query.motion = Vector3(dir.x, 0.0, dir.y) * length
		var moved: float = _space.cast_motion(query)[0] * length
		if moved > 0.5 and moved + capsule.radius <= edge + 0.01:
			held += 1
		print("   empurrão: andou %.2f m (a borda fica a %.2f m)" % [moved, edge])
	_check("empurrada para a ponta e para os lados, a cápsula para em cima do piso", held == 3)

	# A abertura: do meio do disco, pela plataforma até perto da ponta, ao lado do banco.
	var lane := trail.lookout_center + side * 1.3
	query.exclude = []
	query.transform = Transform3D(Basis.IDENTITY, Vector3(lane.x, top + 0.9 + 0.3, lane.y))
	query.motion = Vector3(direction.x, 0.0, direction.y) * (tip - 1.0)
	var free_share: float = _space.cast_motion(query)[0]
	_check("do meio do disco até a ponta, passando ao lado do banco, o caminho é livre (%.0f%%)" % (free_share * 100.0),
			free_share > 0.999)

	var bench: Node3D = deck.get_node_or_null("Bench")
	_check("o banco existe, com colisão", bench != null and bench.get_node_or_null("BenchBody") != null)
	if bench != null:
		var bench_spot := Vector2(bench.global_position.x, bench.global_position.z)
		var facing := -Vector2(bench.global_basis.z.x, bench.global_basis.z.z)
		_check("o banco fica no disco, virado para a abertura (e a praça)",
				bench_spot.distance_to(trail.lookout_center) < radius and facing.dot(direction) > 0.99)

	# A torre fica atrás, longe da plataforma e do banco; a vista fica na ponta.
	var tower_spot := Vector2(tower.global_position.x, tower.global_position.z)
	var tower_along := (tower_spot - trail.lookout_center).dot(direction)
	var tower_reach: float = tower.footprint().size.x / sqrt(2.0)  # do meio ao canto
	_check("a torre fica do outro lado do disco, longe do banco e da plataforma",
			tower_along + tower_reach < radius - _deck.BENCH_BACK - 1.0)
	var view: Vector3 = terrain.view_world()
	var view_along := (Vector2(view.x, view.z) - trail.lookout_center).dot(direction)
	var view_side := (Vector2(view.x, view.z) - trail.lookout_center).dot(side)
	_check("o ponto da vista (capturas) fica na ponta da plataforma, do lado da praça", absf(view.y - top) < 0.01
			and view_along > radius + _deck.REACH / 2.0 and view_along < tip
			and absf(view_side) < _deck.WIDTH / 2.0 and view_side * side.dot(toward_plaza) > 0.0)


## 15.9.3: lampiões que acendem à noite, a placa da entrada e o marco no mapa;
## e a montanha com a neve e a rocha do bioma.
func _check_signs(city: Node, terrain: Node, points: PackedVector3Array) -> void:
	print("\n== lampiões, placa e marco (15.9.3) ==")
	var dressing: Node3D = terrain.get_dressing()
	if dressing == null:
		return
	var script: GDScript = load("res://worlds/city/biome/trail_dressing.gd")
	var trail: MountainTrail = terrain.trail
	var lights: Array = dressing.get_lamp_lights()
	print("   %d lampiões em %.0f m de trilha" % [lights.size(), trail.length()])
	_check("um lampião a cada ~15 m", lights.size() >= int(trail.length() / script.LAMP_SPACING) - 2)
	var spots: PackedVector2Array = script.lamp_spots(terrain.field, trail)
	var widest := 0.0
	for i in range(1, spots.size()):
		widest = maxf(widest, spots[i].distance_to(spots[i - 1]))
	_check("sem trecho escuro: lampiões a no máximo 18 m um do outro (%.1f m)" % widest, widest <= 18.0)
	dressing.set_night(1.0)
	_check("à noite, todos acesos", lights.all(func(l: OmniLight3D) -> bool: return l.visible and l.light_energy > 0.0))
	dressing.set_night(0.0)
	_check("de dia, todos apagados", lights.all(func(l: OmniLight3D) -> bool: return not l.visible))
	_check("eles estão no grupo city_night", dressing.is_in_group("city_night"))

	_check("a placa diz \"%s\"" % script.SIGN_TEXT, dressing.get_sign_text() == script.SIGN_TEXT)
	var gate: Node3D = dressing.get_node_or_null("TrailGate")
	var inward := Vector3(-trail.outward.x, 0.0, -trail.outward.y)
	_check("os pilares ficam no vão e a placa olha para a cidade", gate != null
			and Vector2(gate.position.x, gate.position.z).distance_to(trail.start) < 1.0
			and gate.global_basis.z.dot(inward) > 0.99
			and gate.get_node_or_null("Pillars") != null)

	var trails: Array = city._map.get_map_data()["landmarks"].filter(
			func(l: Dictionary) -> bool: return l["kind"] == "trilha")
	_check("o mapa tem o marco da trilha, na entrada", trails.size() == 1
			and trails[0]["name"] == script.SIGN_TEXT and (trails[0]["pos"] as Vector2).is_equal_approx(trail.start))

	var chunk: MeshInstance3D = null
	for child: Node in terrain.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Chunk_"):
			chunk = child
			break
	var material := chunk.mesh.surface_get_material(0) as ShaderMaterial if chunk != null else null
	_check("a montanha tem a neve e a rocha do bioma", material != null
			and material.get_shader_parameter("snow_albedo") != null
			and material.get_shader_parameter("rock_albedo") != null)


## 15.9.3: o jogador sobe a trilha de verdade (física, entrada simulada, correndo)
## do lado de dentro da mureta até 10 m de altura, sem sair do caminho.
func _check_climb(city: Node, points: PackedVector3Array) -> void:
	print("\n== subida simulada (15.9.3) ==")
	var player = city.get_node("Player")
	player.set_indoors(null)
	var first := points[0]
	var out := Vector3(points[4].x - first.x, 0.0, points[4].z - first.z).normalized()
	player.teleport_to(Transform3D(Basis.looking_at(out), first - out * 4.0 + Vector3.UP * 0.2))
	for i in 10:
		await physics_frame
	var last := points.size() - 1
	var near := 0
	var worst_off := 0.0
	var started := Time.get_ticks_msec()
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for frame in 60 * 40:
		await physics_frame
		var here := Vector2(player.global_position.x, player.global_position.z)
		# O ponto da trilha mais perto, procurando só um pouco à frente.
		var best := INF
		for i in range(near, mini(near + 12, last + 1)):
			var distance := here.distance_to(Vector2(points[i].x, points[i].z))
			if distance < best:
				best = distance
				near = i
		if near > 2:  # já passou da mureta (antes dela, o jogador vem da rua)
			worst_off = maxf(worst_off, best)
		var target := points[mini(near + 3, last)]
		var to_target := Vector2(target.x, target.z) - here
		player.rotation.y = atan2(-to_target.x, -to_target.y)
		if player.global_position.y >= 10.0:
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print("   subiu até %.1f m em %.1f s (ponto %d de %d); o mais longe do meio da trilha: %.2f m"
			% [player.global_position.y, (Time.get_ticks_msec() - started) / 1000.0, near, last, worst_off])
	_check("o jogador sobe a pé até 10 m acima do chão", player.global_position.y >= 10.0)
	_check("sem sair da trilha (a menos de 1,5 m do meio)", worst_off < 1.5)


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
