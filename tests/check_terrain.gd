extends SceneTree
## Teste do núcleo do terreno (Fase 15.8): alturas, trilha e malha, sem a
## cidade. Só contas: Heightfield, MountainTrail e TerrainMesh.

const SHADER_PATH := "res://worlds/city/biome/terrain.gdshader"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var spec := load("res://profiles/biomes/montanha.tres") as BiomeSpec
	_check("perfil real tem terreno", spec != null and spec.backdrop != null)
	if spec != null and spec.backdrop != null:
		var configured := Heightfield.new()
		configured.apply_spec(spec.backdrop)
		for field in Heightfield.SPEC_FIELDS:
			_check("contrato TerrainSpec: " + field, field in spec.backdrop and configured.get(field) == spec.backdrop.get(field))
		var changed := spec.backdrop.duplicate(true) as TerrainSpec
		for field in Heightfield.SPEC_FIELDS:
			changed.set(field, changed.get(field) * 2)
		configured.apply_spec(changed)
		for field in Heightfield.SPEC_FIELDS:
			_check("aplica valor não padrão: " + field, configured.get(field) == changed.get(field) and configured.get(field) != spec.backdrop.get(field))
	# Cunhas de exemplo (ângulos a partir do norte, sentido horário). O "half"
	# de 176 m é o da cidade com 200 jogos falsos (anel 4).
	_check_case("200 falsos, cunha de ~98° ao norte", 176.0, -49.0, 49.0, true)
	_check_case("biblioteca pequena (anel 1)", 62.0, -60.0, 60.0, false)
	_check_case("cunha estreita (16°)", 176.0, -8.0, 8.0, false)
	_check_case("cunha a leste (fora do norte)", 176.0, 50.0, 130.0, false)
	_check_case("cidade grande (anel 6)", 252.0, -45.0, 45.0, false)

	print("\n-- sem espaço para a montanha")
	var crowded := _make_field(300.0, -45.0, 45.0, 7)
	_check("com a borda a 300 m (menos de 80 m até o raio de fora), não cabe", not crowded.fits())

	print("\n-- shader")
	var shader: Shader = load(SHADER_PATH)
	var uniforms := []
	if shader != null:
		for uniform in shader.get_shader_uniform_list():
			uniforms.append(uniform["name"])
	_check("terrain.gdshader carrega e tem snow_slope, triplanar e as texturas",
			shader != null and "snow_slope" in uniforms and "triplanar" in uniforms
			and "snow_albedo" in uniforms and "rock_albedo" in uniforms)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check_case(label: String, half: float, from_degrees: float, to_degrees: float, time_all_qualities: bool) -> void:
	print("\n-- %s (half %.0f m)" % [label, half])
	var field := _make_field(half, from_degrees, to_degrees, 7)
	_check("a montanha cabe", field.fits())

	# 1. A mesma semente dá a mesma altura; outra semente, outra montanha.
	var twin := _make_field(half, from_degrees, to_degrees, 7)
	var other := _make_field(half, from_degrees, to_degrees, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var same := true
	var differs := false
	var tallest := 0.0
	for i in 400:
		var p := _point_in_wedge(field, rng)
		var h := field.mountain_height(p)
		tallest = maxf(tallest, h)
		if not is_equal_approx(h, twin.mountain_height(p)):
			same = false
		if absf(h - other.mountain_height(p)) > 0.5:
			differs = true
	_check("mesma semente, mesma altura", same)
	_check("outra semente, outra altura", differs)
	print("   pico amostrado: %.1f m (o pico do perfil é %.0f m)" % [tallest, field.peak_height])
	_check("a montanha sobe (mais de 40% do pico) e não passa do pico", tallest > field.peak_height * 0.4 and tallest <= field.peak_height + 0.01)

	# 2. A trilha.
	var started := Time.get_ticks_usec()
	var trail := _plan_trail(field)
	var plan_ms := (Time.get_ticks_usec() - started) / 1000.0
	_check("a trilha coube", trail.valid)
	if not trail.valid:
		return
	field.set_trail(trail)
	print("   trilha: %.0f m, %d pontos, mirante a %.0f m da praça (%.1f ms)"
			% [trail.length(), trail.points.size(), trail.lookout_center.length(), plan_ms])

	# Dentro da cunha, com o acostamento.
	var margin := field.trail_width / 2.0 + Heightfield.SHOULDER
	var inside := true
	var worst_edge := INF
	for p in trail.points:
		var edge := field.edge_distance(p)
		worst_edge = minf(worst_edge, edge)
		if edge < margin:
			inside = false
	_check("a trilha fica dentro da cunha (pior folga %.1f m)" % worst_edge, inside)
	_check("o mirante fica dentro da cunha e antes do raio de fora",
			field.edge_distance(trail.lookout_center) >= field.lookout_radius
			and trail.lookout_center.length() + field.lookout_radius < field.outer_radius)

	# Rampa, começo e fim.
	var steepest := 0.0
	var climbs := true
	for i in range(1, trail.points.size()):
		var step := trail.points[i].distance_to(trail.points[i - 1])
		var rise := trail.heights[i] - trail.heights[i - 1]
		if rise < -0.0001:
			climbs = false
		if step > 0.05:
			steepest = maxf(steepest, rise / step)
	print("   rampa mais forte: %.1f%%" % (steepest * 100.0))
	_check("rampa ≤ %.0f%%" % (field.max_grade * 100.0), steepest <= field.max_grade + 0.0001)
	_check("a trilha só sobe", climbs)
	_check("começa no chão da cidade (y = 0)", absf(trail.heights[0]) < 0.001)
	_check("termina na altura do mirante (%.0f m)" % field.lookout_height,
			absf(trail.heights[trail.heights.size() - 1] - field.lookout_height) < 0.001)
	var start := trail.points[0]
	_check("começa na borda da cidade", absf(field.square_distance(start)) < 0.01)

	# 3. A escavação bate com a trilha (±5 cm), no meio e perto das beiradas.
	var worst_carve := 0.0
	for i in range(0, trail.points.size(), 3):
		var p := trail.points[i]
		var tangent := (trail.points[mini(i + 1, trail.points.size() - 1)] - trail.points[maxi(i - 1, 0)]).normalized()
		var across := Vector2(-tangent.y, tangent.x) * field.trail_width * 0.4
		for spot in [p, p + across, p - across]:
			var expected := trail.closest(spot).y
			worst_carve = maxf(worst_carve, absf(field.height_at(spot) - expected))
		worst_carve = maxf(worst_carve, absf(field.surface_at(p) - trail.heights[i]))
	print("   maior diferença entre o chão e a trilha: %.3f m" % worst_carve)
	_check("a escavação bate com a trilha (±5 cm)", worst_carve <= 0.05)
	# A trilha corre rente à montanha (rampa), e não num cânion.
	var deepest_cut := 0.0
	var highest_fill := 0.0
	for i in trail.points.size():
		var difference := field.uncarved_height(trail.points[i]) - trail.heights[i]
		deepest_cut = maxf(deepest_cut, difference)
		highest_fill = maxf(highest_fill, -difference)
	print("   escavação mais funda: %.1f m; aterro mais alto: %.1f m" % [deepest_cut, highest_fill])
	_check("a trilha corre rente ao chão (escavação e aterro ≤ 3 m)", deepest_cut <= 3.0 and highest_fill <= 3.0)
	var forward_grows := true
	for i in range(1, trail.points.size()):
		if (trail.points[i] - trail.start).dot(trail.outward) < (trail.points[i - 1] - trail.start).dot(trail.outward) - 0.0001:
			forward_grows = false
	_check("cada ponto da trilha fica mais longe da borda que o anterior", forward_grows)
	var view_open := true
	var to_city := (trail.start - trail.lookout_center).normalized()
	for meters in range(int(field.lookout_radius) + 6, 80, 4):
		if field.uncarved_height(trail.lookout_center + to_city * meters) > field.lookout_height + 1.0:
			view_open = false
	_check("do mirante, a vista para a cidade é aberta (nada mais alto no caminho)", view_open)
	var behind := field.uncarved_height(trail.lookout_center + trail.outward * (field.lookout_radius + 40.0))
	print("   montanha 40 m atrás do mirante: %.1f m" % behind)
	if trail.lookout_center.length() + 70.0 < field.outer_radius:  # com espaço para o pico
		_check("atrás do mirante, a montanha sobe mais que ele", behind > field.lookout_height + 10.0)
	var flat := true
	for i in 16:
		var spot := trail.lookout_center + Vector2.from_angle(i * TAU / 16.0) * field.lookout_radius * 0.9
		if absf(field.height_at(spot) - field.lookout_height) > 0.05:
			flat = false
	_check("o mirante é um disco plano na altura dele", flat
			and absf(field.height_at(trail.lookout_center) - field.lookout_height) < 0.001)

	# 4. Zero dentro do quadrado e depois do raio de fora.
	var zero_inside := true
	var zero_outside := true
	for i in 300:
		var p := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if field.height_at(p) != 0.0:
			zero_inside = false
		var far := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(field.outer_radius, field.outer_radius + 60.0)
		if field.height_at(far) != 0.0 or field.sample(far).w != 0.0:
			zero_outside = false
	_check("altura 0 dentro do quadrado da cidade", zero_inside)
	_check("altura 0 e sem malha depois de %.0f m" % field.outer_radius, zero_outside)
	var foot := Heightfield.direction_of(field.wedge_center + 0.6 * field.wedge_half)
	foot *= (field.half + 2.0) / maxf(absf(foot.x), absf(foot.y))  # 2 m para fora da mureta
	_check("a base afunda 0,3 m (some debaixo do chão de fora)",
			is_equal_approx(field.surface_at(foot), -Heightfield.SINK))

	# 5. A malha.
	var qualities: Array = [4.0, 3.0, 2.0] if time_all_qualities else [4.0]
	for cell: float in qualities:
		_check_mesh(field, cell)


func _check_mesh(field: Heightfield, cell: float) -> void:
	var started := Time.get_ticks_usec()
	var coords := TerrainMesh.chunk_coords(field, cell)
	var slowest := 0.0
	var meshes: Array[ArrayMesh] = []
	for coord in coords:
		var chunk_started := Time.get_ticks_usec()
		var mesh := TerrainMesh.build_chunk(field, coord, cell)
		slowest = maxf(slowest, (Time.get_ticks_usec() - chunk_started) / 1000.0)
		if mesh != null:
			meshes.append(mesh)
	var total_ms := (Time.get_ticks_usec() - started) / 1000.0

	var vertex_count := 0
	var triangle_count := 0
	var masked := 0
	var off_surface := 0
	var down := 0
	var trail_vertices := 0
	for mesh in meshes:
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		vertex_count += vertices.size()
		triangle_count += indices.size() / 3
		for i in vertices.size():
			var v := vertices[i]
			if absf(field.surface_at(Vector2(v.x, v.z)) - v.y) > 0.001:
				off_surface += 1
			if normals[i].y <= 0.0:
				down += 1
			if colors[i].r > 0.99:
				trail_vertices += 1
		for t in range(0, indices.size(), 6):
			# Cada quadrado (2 triângulos) tem pelo menos um canto com cobertura.
			var covered := false
			for k in [0, 1, 2, 5]:
				var v := vertices[indices[t + k]]
				if field.sample(Vector2(v.x, v.z)).w > 0.0:
					covered = true
			if not covered:
				masked += 1
			# Os triângulos olham para cima (sentido horário visto de cima).
			var a := vertices[indices[t]]
			var b := vertices[indices[t + 1]]
			var c := vertices[indices[t + 2]]
			if (b - a).cross(c - a).y >= 0.0:
				down += 1
	var full_grid := coords.size() * TerrainMesh.cells_per_chunk(cell) * TerrainMesh.cells_per_chunk(cell) * 2
	print("   malha de %.0f m: %d pedaços (%d com algo), %d vértices, %d triângulos (de %d na grade cheia)"
			% [cell, coords.size(), meshes.size(), vertex_count, triangle_count, full_grid])
	print("   tempo de geração (%.0f m): %.0f ms no total, %.1f ms no pedaço mais lento" % [cell, total_ms, slowest])
	_check("malha de %.0f m: tem triângulos e descartou quadrados vazios" % cell,
			triangle_count > 0 and triangle_count < full_grid)
	_check("malha de %.0f m: nenhum quadrado mascarado" % cell, masked == 0)
	_check("malha de %.0f m: vértices na altura do chão (±1 mm)" % cell, off_surface == 0)
	_check("malha de %.0f m: normais e triângulos para cima" % cell, down == 0)
	_check("malha de %.0f m: a trilha está pintada na cor dos vértices" % cell, trail_vertices > 10)


func _make_field(half: float, from_degrees: float, to_degrees: float, seed_value: int) -> Heightfield:
	var field := Heightfield.new()
	field.noise_seed = seed_value
	field.configure(half, deg_to_rad(from_degrees), deg_to_rad(to_degrees))
	return field


## A trilha sai da célula de borda (anel de fora) mais perto do meio da cunha.
func _plan_trail(field: Heightfield) -> MountainTrail:
	var ring := roundi((field.half - CityLayout.BLOCK_SIZE / 2.0 - CityLayout.STREET_WIDTH) / CityLayout.BLOCK_PITCH)
	var border: Array[Vector2i] = []
	for x in range(-ring, ring + 1):
		for z in range(-ring, ring + 1):
			var cell := Vector2i(x, z)
			if maxi(absi(x), absi(z)) == ring and field.edge_distance(Vector2(cell) * CityLayout.BLOCK_PITCH) > 0.0:
				border.append(cell)
	var cell := MountainTrail.border_cell_nearest(border, field.wedge_center)
	return MountainTrail.plan_from_cell(field, cell)


func _point_in_wedge(field: Heightfield, rng: RandomNumberGenerator) -> Vector2:
	return _point_in_wedge_at(field, rng.randf_range(field.half, field.outer_radius), rng.randf_range(-1.0, 1.0))


## Um ponto a "radius" da praça, na fração "share" da cunha (-1 a 1).
func _point_in_wedge_at(field: Heightfield, radius: float, share: float) -> Vector2:
	return Heightfield.direction_of(field.wedge_center + share * field.wedge_half) * radius


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
