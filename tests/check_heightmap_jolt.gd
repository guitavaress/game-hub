extends SceneTree
## Fase 15.9.1a: prova real no Jolt, sem cidade, Steam ou mudança no config.
## O oráculo lê vértices/índices da malha e interpola cada triângulo em XZ.
## HeightMap é o candidato; se sua diagonal divergir, a fita é o plano B.

const TOLERANCE: float = 0.05
const MAP_LAYER: int = 1
const STRIP_LAYER: int = 4
const RAY_TOP: float = 200.0
const RAY_BOTTOM: float = -20.0

class FallingPlayer extends CharacterBody3D:
	var ticks: int = 0
	var gravity: float = 9.8

	func _physics_process(delta: float) -> void:
		velocity = Vector3(0.0, velocity.y - gravity * delta, 0.0)
		move_and_slide()
		ticks += 1

var failures: int = 0
var _space: PhysicsDirectSpaceState3D
var _world: Node3D
var _triangles: Dictionary[Vector2i, PackedVector3Array] = {}
var _field: Heightfield
var _cell: float


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_check("projeto usa Jolt Physics", ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics")
	_world = Node3D.new()
	root.add_child(_world)
	_space = _world.get_world_3d().direct_space_state
	# Duas orientações e origens fora de zero expõem troca X/Z e centro errado.
	for east: bool in [false, true]:
		_field = Heightfield.new()
		_field.noise_seed = 7
		_field.configure(176.0, deg_to_rad(50.0 if east else -49.0), deg_to_rad(130.0 if east else 49.0))
		var trail: MountainTrail = MountainTrail.plan_from_cell(_field, Vector2i(4, 0) if east else Vector2i(0, -4))
		_check("trilha válida (%s)" % ("leste" if east else "norte"), trail.valid)
		_field.set_trail(trail)
		for step: float in [4.0, 3.0, 2.0]:
			_cell = step
			await _check_region(trail, east)
	_world.free()
	print("FORMA_APROVADA: ConcavePolygonShape3D (triângulos de TerrainMesh)")
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _check_region(trail: MountainTrail, east: bool) -> void:
	var label: String = "%s %.0f m" % ["leste" if east else "norte", _cell]
	var area: Rect2 = trail.bounds()
	var rect: Rect2 = TerrainCollision.aligned_rect(_field, area, _cell)
	_check("%s: alinhamento contém o pedido e expande menos de uma célula" % label,
			rect.encloses(area) and (area.position - rect.position).x < _cell
			and (area.position - rect.position).y < _cell and (rect.end - area.end).x < _cell
			and (rect.end - area.end).y < _cell)
	_build_oracle(rect)
	var map_body: StaticBody3D = _heightmap(rect)
	var strip: ConcavePolygonShape3D = TerrainCollision.build(_field, area, _cell)
	_check("%s: fita tem faces" % label, strip != null)
	if strip == null:
		map_body.free()
		return
	var strip_body: StaticBody3D = _body(strip, STRIP_LAYER)
	# Espera o registro das duas formas no servidor antes de lançar os raios.
	await physics_frame
	await physics_frame
	var points: PackedVector2Array = _sample_points(rect, trail)
	var map_stats: Vector3 = _ray_stats(points, rect, MAP_LAYER)
	var strip_stats: Vector3 = _ray_stats(points, rect, STRIP_LAYER)
	print("MEDIDA_JOLT %s pontos=%d HeightMap_erro=%.6f faltas=%d extras=%d fita_erro=%.6f faltas=%d extras=%d"
			% [label, points.size(), map_stats.x, int(map_stats.y), int(map_stats.z),
			strip_stats.x, int(strip_stats.y), int(strip_stats.z)])
	_check("%s: ≥50 raios incluem trilha, mirante, bordas e cantos" % label, points.size() >= 50)
	_check("%s: fita coincide com triângulos desenhados (±5 cm), inclusive vazios" % label,
			strip_stats.x <= TOLERANCE and strip_stats.y == 0.0 and strip_stats.z == 0.0)
	# A falha do candidato é evidência para escolher o plano B, não falha da fita.
	print("   HeightMap %s: %s" % [label, "compatível" if map_stats.x <= TOLERANCE
			and map_stats.y == 0.0 and map_stats.z == 0.0 else "rejeitado; usar fita"])
	var outside: PackedVector2Array = PackedVector2Array([
		Vector2(rect.position.x - 0.1, rect.get_center().y), Vector2(rect.end.x + 0.1, rect.get_center().y),
		Vector2(rect.get_center().x, rect.position.y - 0.1), Vector2(rect.get_center().x, rect.end.y + 0.1)])
	var no_outside: bool = true
	for point: Vector2 in outside:
		no_outside = no_outside and _ray(point, MAP_LAYER).is_empty() and _ray(point, STRIP_LAYER).is_empty()
	_check("%s: nenhum raio fora dos quatro lados bate" % label, no_outside)
	# No mirante plano, a cápsula do jogador deve pousar e permanecer parada.
	await _check_landing(trail.lookout_center, MAP_LAYER, label + " HeightMap")
	await _check_landing(trail.lookout_center, STRIP_LAYER, label + " fita")
	map_body.free()
	strip_body.free()
	await physics_frame


func _heightmap(rect: Rect2) -> StaticBody3D:
	var width: int = roundi(rect.size.x / _cell) + 1
	var depth: int = roundi(rect.size.y / _cell) + 1
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(width * depth)
	for z: int in range(depth):
		for x: int in range(width):
			heights[z * width + x] = _field.surface_at(rect.position + Vector2(x, z) * _cell)
	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = width
	shape.map_depth = depth
	shape.map_data = heights
	var body: StaticBody3D = _body(shape, MAP_LAYER)
	var collision: CollisionShape3D = body.get_child(0)
	collision.scale = Vector3(_cell, 1.0, _cell)
	collision.position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	_check("HeightMap: amostras, extensão e centro correspondem ao retângulo", shape.map_data.size() == width * depth
			and is_equal_approx((shape.map_width - 1) * collision.scale.x, rect.size.x)
			and is_equal_approx((shape.map_depth - 1) * collision.scale.z, rect.size.y)
			and Vector2(collision.position.x, collision.position.z) == rect.get_center())
	return body


func _body(shape: Shape3D, layer: int) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)
	return body


## Referência independente: lê os índices reais, sem usar faces da colisão nem
## calcular altura no Heightfield para determinar a superfície esperada.
func _build_oracle(rect: Rect2) -> void:
	_triangles.clear()
	for coord: Vector2i in TerrainMesh.chunk_coords(_field, _cell):
		if not TerrainMesh.chunk_rect(_field, coord, _cell).intersects(rect):
			continue
		var mesh: ArrayMesh = TerrainMesh.build_chunk(_field, coord, _cell)
		if mesh == null:
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i: int in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[i]]
			var b: Vector3 = vertices[indices[i + 1]]
			var c: Vector3 = vertices[indices[i + 2]]
			var center: Vector3 = (a + b + c) / 3.0
			var key: Vector2i = Vector2i(((Vector2(center.x, center.z) - _field.grid_origin) / _cell).floor())
			var faces: PackedVector3Array = _triangles.get(key, PackedVector3Array())
			faces.append_array(PackedVector3Array([a, b, c]))
			_triangles[key] = faces


func _visual_height(point: Vector2, rect: Rect2) -> float:
	var key: Vector2i = Vector2i(((point - _field.grid_origin) / _cell).floor())
	# Pontos na linha da grade pertencem também à célula vizinha; nos cantos
	# externos só a célula de dentro pode fornecer uma face desenhada.
	for dz: int in [-1, 0]:
		for dx: int in [-1, 0]:
			var faces: PackedVector3Array = _triangles.get(key + Vector2i(dx, dz), PackedVector3Array())
			for i: int in range(0, faces.size(), 3):
				var a: Vector3 = faces[i]
				var b: Vector3 = faces[i + 1]
				var c: Vector3 = faces[i + 2]
				var center: Vector3 = (a + b + c) / 3.0
				if not rect.has_point(Vector2(center.x, center.z)):
					continue
				var ab: Vector2 = Vector2(b.x - a.x, b.z - a.z)
				var ac: Vector2 = Vector2(c.x - a.x, c.z - a.z)
				var ap: Vector2 = point - Vector2(a.x, a.z)
				var determinant: float = ab.cross(ac)
				var u: float = ap.cross(ac) / determinant
				var v: float = ab.cross(ap) / determinant
				if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
					return a.y + u * (b.y - a.y) + v * (c.y - a.y)
	return NAN


func _sample_points(rect: Rect2, trail: MountainTrail) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	# 11x11 cobre exatamente as quatro bordas e os quatro cantos.
	for z: int in range(11):
		for x: int in range(11):
			points.append(rect.position + rect.size * Vector2(x / 10.0, z / 10.0))
	for i: int in range(60):
		points.append(trail.points[roundi(i * (trail.points.size() - 1) / 59.0)])
	points.append(trail.lookout_center)
	# Interior das duas metades de cada célula: expõe a diagonal errada, que
	# não aparece num teste limitado aos vértices da grade.
	for key: Vector2i in _triangles:
		var origin: Vector2 = _field.grid_origin + Vector2(key) * _cell
		for offset: Vector2 in [Vector2(0.25, 0.65), Vector2(0.75, 0.35), Vector2(0.5, 0.5)]:
			var point: Vector2 = origin + offset * _cell
			if rect.has_point(point):
				points.append(point)
	return points


## x = maior erro em metros, y = raios sem colisão, z = colisões sem visual.
func _ray_stats(points: PackedVector2Array, rect: Rect2, layer: int) -> Vector3:
	var result: Vector3 = Vector3.ZERO
	for point: Vector2 in points:
		var expected: float = _visual_height(point, rect)
		var hit: Dictionary = _ray(point, layer)
		if is_nan(expected):
			if not hit.is_empty():
				result.z += 1.0
		elif hit.is_empty():
			result.y += 1.0
		else:
			var position: Vector3 = hit["position"]
			result.x = maxf(result.x, absf(position.y - expected))
	return result


func _ray(point: Vector2, layer: int) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(point.x, RAY_TOP, point.y), Vector3(point.x, RAY_BOTTOM, point.y), layer)
	query.hit_back_faces = false
	return _space.intersect_ray(query)


func _check_landing(point: Vector2, layer: int, label: String) -> void:
	var body: FallingPlayer = FallingPlayer.new()
	body.collision_layer = 2
	body.collision_mask = layer
	body.gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	body.add_child(collision)
	body.position = Vector3(point.x, _field.lookout_height + 3.0, point.y)
	_world.add_child(body)
	while body.ticks < 100:
		await physics_frame
	_check("%s: cápsula do jogador pousou no mirante" % label, body.is_on_floor()
			and absf(body.position.y - _field.lookout_height) <= TOLERANCE)
	var landed: Vector3 = body.position
	var stable: bool = true
	while body.ticks < 160:
		await physics_frame
		stable = stable and body.is_on_floor() and body.position.distance_to(landed) < 0.005
	_check("%s: permaneceu apoiada e parada por 60 ticks" % label, stable)
	body.free()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
