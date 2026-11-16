extends SceneTree
## Teste da encosta com pinheiros e rochas (Fase 19.12), com 200 jogos falsos
## (o RPG tem a montanha). Confere:
##   - as famílias on_backdrop do bioma estão na encosta (pinheiros e rochas),
##     e só elas (a cidade não ganha as da encosta);
##   - todas as peças ficam na encosta: fora da cidade, com montanha embaixo;
##   - nenhuma na trilha (os pinheiros com a folga do perfil além das paredes),
##     nas paradas, no mirante, na plataforma dele nem no cone da luneta;
##   - as rochas: só no chão inclinado, longe do mirante, cada uma diferente;
##   - cada peça assenta no chão: a árvore em pé, sem pé no ar e sem afundar
##     demais; a rocha com a base embaixo do chão, o topo para fora e deitada
##     na inclinação;
##   - mesma montanha, mesma encosta (a conta de novo e outra montanha igual);
##   - a quantidade cai com a qualidade gráfica (e a troca no menu refaz);
##   - com as horas falsas (o RPG no nível 3), a encosta é a mesma.
## (Scripts que usam autoloads vão por load(), sem o nome da classe.)

## Folga mínima de qualquer peça até as paredes da trilha e do anel (m).
const GAP: float = 0.5
## O cone conferido aqui é mais estreito que o da montagem (8°, tubo de 3 m):
## o eixo de cada peça não pode entrar nele.
const CONE: float = deg_to_rad(5.0)
const TUBE: float = 2.0

var failures: int = 0
## Carregados no _run, depois do primeiro quadro (com os autoloads já no lugar).
var _dressing: GDScript
var _deck_script: GDScript
var _telescope_script: GDScript
var _quality: GDScript


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_dressing = load("res://worlds/city/biome/trail_dressing.gd")
	_deck_script = load("res://worlds/city/biome/lookout_deck.gd")
	_telescope_script = load("res://worlds/city/biome/lookout_telescope.gd")
	_quality = load("res://autoload/graphics_quality.gd")
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 200, false, true)
	var city := await _build_city()
	var terrain = get_first_node_in_group("mountain_trail")
	_check("a montanha existe", terrain != null)
	if terrain == null:
		_finish()
		return
	var scatter = terrain.get_scatter()
	_check("a encosta tem o SlopeScatter", scatter != null)
	if scatter == null:
		_finish()
		return
	var field: Heightfield = terrain.field
	var trail: MountainTrail = terrain.trail
	var biome = terrain.biome
	var families: Array[int] = terrain.slope_families()

	print("\n== as famílias ==")
	var kinds: Array[String] = []
	for index in families:
		kinds.append(biome.scatter[index].kind)
	_check("pinheiros e rochas vão para a encosta (%s)" % [kinds], "tree" in kinds and "mesh" in kinds)
	var town = city.get_node_or_null("BiomeScatter_rpg")
	var town_on_slope := 0
	for index in families:
		town_on_slope += town.get_transforms(index).size() if town != null else 0
	_check("a cidade não ganha as famílias da encosta", town != null and town_on_slope == 0)
	var built := {}
	for index in families:
		built[index] = scatter.get_transforms(index)
		print("   família %d (%s): %d peças" % [index, biome.scatter[index].kind, built[index].size()])
		_check("a família %d tem peças na encosta" % index, built[index].size() > 20)

	_check_places(terrain, scatter, field, trail, biome, families, built)
	_check_seated(scatter, field, biome, families, built)
	_check_same(terrain, city, families, built)
	await _check_quality(city, families)

	print("\n== com as horas falsas, a mesma encosta ==")
	city.queue_free()
	await process_frame
	await process_frame
	load("res://tests/fake_library.gd").install(root, 200, true, true)
	city = await _build_city()
	_check("com as horas falsas, o RPG está no nível 3", city.district_level("rpg") == 3)
	var grown = get_first_node_in_group("mountain_trail")
	var same := grown != null and grown.get_scatter() != null
	if same:
		for index in families:
			same = same and _same_positions(grown.get_scatter().get_transforms(index), built[index])
	_check("os pinheiros e as rochas ficam nos mesmos lugares", same)
	_finish()


func _build_city() -> Node:
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	var started := Time.get_ticks_msec()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	print("cidade montada em %d ms" % (Time.get_ticks_msec() - started))
	await physics_frame
	return city


## Onde as peças ficam: na encosta, fora da trilha, das paradas, do mirante,
## da plataforma e da vista da luneta.
func _check_places(terrain, scatter, field: Heightfield, trail: MountainTrail, biome,
		families: Array[int], built: Dictionary) -> void:
	print("\n== onde ficam ==")
	var wall: float = _dressing.WALL_OFFSET
	var ring: float = field.lookout_radius + _dressing.RING_GAP
	var deck: PackedVector3Array = _deck_script.outline(field, trail, _deck_script.direction(field, trail))
	var deck_polygon := PackedVector2Array()
	for p in deck:
		deck_polygon.append(Vector2(p.x, p.z))
	var stops: Array[Dictionary] = _dressing.stop_spots(field, trail)
	_check("as quatro paradas existem", stops.size() == 4)
	var layout: Dictionary = terrain.get_deck().get_layout()
	var eye: Vector3 = (layout["telescope"] as Transform3D) * _telescope_script.EYEPIECE
	var target: Vector3 = _deck_script.TELESCOPE_TARGET
	var axis := (target - eye).normalized()
	var length := eye.distance_to(target)
	var line: Array = terrain.view_line()
	_check("a vista da luneta vai da ocular até a praça",
			line.size() == 3 and (line[0] as Vector3).is_equal_approx(eye) and (line[1] as Vector3).is_equal_approx(axis))

	for index in families:
		var spec = biome.scatter[index]
		var tree: bool = spec.kind != "mesh"
		var outside := 0
		var on_trail := 0
		var on_stop := 0
		var on_lookout := 0
		var on_deck := 0
		var in_view := 0
		var closest := INF
		for item: Transform3D in built[index]:
			var spot := Vector2(item.origin.x, item.origin.z)
			var sample := field.sample(spot)
			if field.square_distance(spot) <= 0.0 or sample.w < 0.5 or sample.x < 1.0:
				outside += 1
			var distance := _trail_distance(trail, spot)
			closest = minf(closest, distance)
			if distance < wall + (spec.walkable_clearance if tree else GAP):
				on_trail += 1
			for stop: Dictionary in stops:
				var place: Transform3D = stop["transform"]
				var points: PackedVector2Array = _dressing.outer_points(stop)
				points.append(Vector2(place.origin.x, place.origin.z))
				for p in points:
					if spot.distance_to(p) < 1.0:
						on_stop += 1
						break
			if spot.distance_to(trail.lookout_center) < ring + GAP:
				on_lookout += 1
			if deck_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(spot, deck_polygon):
				on_deck += 1
			var top := _top(scatter, spec, index, item)
			for k in 9:
				var p := item.origin.lerp(top, k / 8.0)
				var along := (p - eye).dot(axis)
				if along > 0.0 and along < length \
						and (p - eye - axis * along).length() < along * tan(CONE) + TUBE:
					in_view += 1
					break
		if not tree:
			_check_rocks(terrain, field, trail, spec, built[index])
		var label := "pinheiros" if tree else "rochas"
		_check("%s: todos na encosta (%d fora)" % [label, outside], outside == 0)
		_check("%s: nenhum na trilha nem perto dela (o mais perto a %.1f m do meio)" % [label, closest],
				on_trail == 0)
		_check("%s: nenhum nas paradas (%d)" % [label, on_stop], on_stop == 0)
		_check("%s: nenhum no mirante (%d)" % [label, on_lookout], on_lookout == 0)
		_check("%s: nenhum na plataforma (%d)" % [label, on_deck], on_deck == 0)
		_check("%s: nenhum na frente da luneta (%d)" % [label, in_view], in_view == 0)


## As rochas: só no chão inclinado (nada no chão plano de neve), longe do
## mirante, e diferentes entre si (tamanho, achatamento e inclinação).
func _check_rocks(terrain, field: Heightfield, trail: MountainTrail, spec, rocks: Array[Transform3D]) -> void:
	var on_flat := 0
	var near_lookout := 0
	var smallest := INF
	var largest := 0.0
	var flattest := INF
	var roundest := 0.0
	var tilted := 0
	var surface: Callable = field.surface_at
	var reach: float = terrain.get_scatter().mesh_of(spec.source)["reach"]
	for item: Transform3D in rocks:
		var spot := Vector2(item.origin.x, item.origin.z)
		var up: Vector3 = terrain.get_scatter().ground_normal(surface, spot, 1.0)
		var seat_up: Vector3 = terrain.get_scatter().ground_normal(surface, spot,
				maxf(reach * item.basis.x.length(), 1.0))
		# A montagem mede o chão com o passo do tamanho da rocha; aqui, 1 m (a folga).
		if up.y > terrain.ROCK_MAX_UP + 0.05:
			on_flat += 1
		if spot.distance_to(trail.lookout_center) < terrain.ROCK_LOOKOUT_GAP - 0.01:
			near_lookout += 1
		var size := item.basis.x.length()
		smallest = minf(smallest, size)
		largest = maxf(largest, size)
		var ratio := item.basis.y.length() / size
		flattest = minf(flattest, ratio)
		roundest = maxf(roundest, ratio)
		if item.basis.y.normalized().dot(seat_up) < cos(deg_to_rad(3.0)):
			tilted += 1
	_check("rochas: nenhuma no chão plano de neve (%d)" % on_flat, on_flat == 0)
	_check("rochas: nenhuma a menos de %.0f m do mirante (%d)" % [terrain.ROCK_LOOKOUT_GAP, near_lookout],
			near_lookout == 0)
	_check("rochas: de tamanhos diferentes (escala de %.2f a %.2f)" % [smallest, largest],
			largest > smallest * 2.0)
	_check("rochas: umas mais achatadas que outras (altura/largura de %.2f a %.2f)" % [flattest, roundest],
			roundest > flattest * 1.3)
	_check("rochas: muitas inclinadas para um lado (%d de %d)" % [tilted, rocks.size()],
			tilted > rocks.size() / 3)


## Cada peça assenta no chão do jeito dela.
func _check_seated(scatter, field: Heightfield, biome, families: Array[int], built: Dictionary) -> void:
	print("\n== no chão ==")
	for index in families:
		var spec = biome.scatter[index]
		var floating := 0
		var buried := 0
		var tilted := 0
		var worst := 0.0
		for item: Transform3D in built[index]:
			var spot := Vector2(item.origin.x, item.origin.z)
			if spec.kind != "mesh":
				# Em pé, com o pé abaixo do chão em volta do tronco...
				var low := field.surface_at(spot)
				for k in 8:
					low = minf(low, field.surface_at(spot + Vector2.from_angle(TAU * k / 8.0) * 0.4))
				if item.origin.y > low + 0.01:
					floating += 1
				# ...e sem afundar mais que o desnível embaixo da árvore.
				var sink := field.surface_at(spot) - item.origin.y
				worst = maxf(worst, sink)
				if sink > 1.5:
					buried += 1
				if not item.basis.y.normalized().is_equal_approx(Vector3.UP):
					tilted += 1
				continue
			var aabb: AABB = scatter.mesh_of(spec.source)["aabb"]
			var base := item * Vector3(0.0, aabb.position.y, 0.0)
			var top := item * Vector3(0.0, aabb.end.y, 0.0)
			if base.y > field.surface_at(Vector2(base.x, base.z)) + 0.01:
				floating += 1
			if top.y < field.surface_at(Vector2(top.x, top.z)) + 0.3:
				buried += 1
			# O chão medido como na montagem: em volta da rocha inteira (o raio
			# dela, pelo menos 1 m). A rocha grande deita na inclinação média.
			var reach: float = scatter.mesh_of(spec.source)["reach"] * item.basis.x.length()
			var up := (scatter.ground_normal(field.surface_at, spot, maxf(reach, 1.0)) as Vector3)
			if item.basis.y.normalized().dot(up) < 0.9:
				tilted += 1
		if spec.kind != "mesh":
			_check("pinheiros: nenhum com o pé no ar (%d)" % floating, floating == 0)
			_check("pinheiros: nenhum enterrado (o mais fundo, %.2f m)" % worst, buried == 0)
			_check("pinheiros: todos em pé (%d tortos)" % tilted, tilted == 0)
		else:
			_check("rochas: a base embaixo do chão (%d no ar)" % floating, floating == 0)
			_check("rochas: o topo para fora do chão (%d enterradas)" % buried, buried == 0)
			_check("rochas: deitadas na inclinação do chão (%d tortas)" % tilted, tilted == 0)


## Mesma montanha, mesma encosta.
func _check_same(terrain, city: Node, families: Array[int], built: Dictionary) -> void:
	print("\n== mesma montanha, mesma encosta ==")
	var plan: Dictionary = terrain.scatter_plan(terrain.scatter_amount)
	var again := true
	for index in families:
		again = again and _same_positions(_plan_transforms(plan.get(index, [])), built[index], 1.0)
	_check("a conta de novo dá os mesmos lugares", again)
	var twin = load("res://worlds/city/biome/backdrop_terrain.gd").new()
	twin.biome = terrain.biome
	twin.scatter_amount = terrain.scatter_amount
	var ok: bool = twin.setup(terrain.biome.backdrop, city._sectors["rpg"], terrain.field.half)
	var twin_plan: Dictionary = twin.scatter_plan(terrain.scatter_amount) if ok else {}
	var equal := ok
	for index in families:
		equal = equal and _same_positions(_plan_transforms(twin_plan.get(index, [])), built[index], 1.0)
	_check("outra montanha igual dá a mesma encosta", equal)
	twin.free()


## Menos na Leve; a troca no menu refaz a montanha com a quantidade nova.
func _check_quality(city: Node, families: Array[int]) -> void:
	print("\n== a quantidade pela qualidade ==")
	var terrain = get_first_node_in_group("mountain_trail")
	var counts: Array[int] = []
	for level: String in ["leve", "media", "alta"]:
		var plan: Dictionary = terrain.scatter_plan(_quality.scatter_amount(level))
		var total := 0
		for index in families:
			total += (plan.get(index, []) as Array).size()
		counts.append(total)
	print("   leve %d, média %d, alta %d" % [counts[0], counts[1], counts[2]])
	_check("menos na Leve que na Média, e na Média que na Alta", counts[0] < counts[1] and counts[1] < counts[2])

	var app := root.get_node("AppConfig")
	var original: String = app.get_quality()
	var other := "leve" if original != "leve" else "alta"
	app.set_quality(other)
	var frames := 0
	while city._backdrop_rebuilding and frames < 3000:
		await process_frame
		frames += 1
	var fresh = get_first_node_in_group("mountain_trail")
	var total := 0
	if fresh != null and fresh.get_scatter() != null:
		for index in families:
			total += fresh.get_scatter().get_transforms(index).size()
	var wanted: int = counts[0] if other == "leve" else counts[2]
	_check("trocar para %s no menu refaz a encosta com %d peças (%d)" % [other, wanted, total],
			fresh != terrain and total == wanted)
	app.set_quality(original)
	frames = 0
	while city._backdrop_rebuilding and frames < 3000:
		await process_frame
		frames += 1


## O topo (no mundo) do eixo de uma peça: a altura do modelo na árvore, a da malha na rocha.
func _top(scatter, spec, index: int, item: Transform3D) -> Vector3:
	if spec.kind == "mesh":
		var aabb: AABB = scatter.mesh_of(spec.source)["aabb"]
		return item * Vector3(0.0, aabb.end.y, 0.0)
	var height: float = scatter.get_node("Scatter_%d" % index).model_height()
	return item * Vector3(0.0, height, 0.0)


## A distância até a linha da trilha, conferindo todos os trechos.
func _trail_distance(trail: MountainTrail, spot: Vector2) -> float:
	var best := INF
	for i in trail.points.size() - 1:
		var nearest := Geometry2D.get_closest_point_to_segment(spot, trail.points[i], trail.points[i + 1])
		best = minf(best, spot.distance_to(nearest))
	return best


func _plan_transforms(items: Array) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for item: Dictionary in items:
		result.append(Transform3D(Basis.IDENTITY, item["position"]))
	return result


## Os mesmos lugares (no chão), na mesma ordem.
func _same_positions(a: Array[Transform3D], b: Array[Transform3D], tolerance: float = 0.001) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	for k in a.size():
		if Vector2(a[k].origin.x, a[k].origin.z).distance_to(Vector2(b[k].origin.x, b[k].origin.z)) > tolerance:
			return false
	return true


func _finish() -> void:
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
