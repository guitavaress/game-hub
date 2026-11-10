class_name HomePlants
extends RefCounted
## Plantas em vaso feitas por código (Fase 17.4), sem modelo baixado. Cada
## planta são dois desenhos: o vaso (cerâmica) e a folhagem (todas as folhas e
## caules numa malha só, com a cor em cada vértice). As folhas são finas, dos
## dois lados, com a nervura em "V" e caindo com o peso.
##
## Tipos ("kind"):
##   - palmeira: folhas compridas em arco, cheias de folhinhas (o canto da janela);
##   - costela:  folhas largas em caules longos que se abrem (canto, chão);
##   - espada:   folhas retas para cima, de borda clara (espada-de-são-jorge);
##   - pendente: folhinhas que transbordam do vaso e caem para um lado (móvel).
## A origem fica no chão, no meio do vaso. Nada daqui conhece a cidade.

const LEAF_DARK: Color = Color(0.13, 0.22, 0.09)
const LEAF_MID: Color = Color(0.2, 0.32, 0.12)
const LEAF_LIGHT: Color = Color(0.3, 0.42, 0.15)
const STEM_COLOR: Color = Color(0.28, 0.3, 0.14)
const SOIL_COLOR: Color = Color(0.08, 0.06, 0.045)

static var _cache: Dictionary[String, Array] = {}


## Monta uma planta. "hang" é o lado para onde a pendente cai (na horizontal) e
## "ledge" quanto ela anda nessa direção antes de cair (a distância até a borda
## do móvel). "solid" põe colisão no vaso (o jogador não atravessa).
static func make(kind: String, plant_height: float, pot_radius: float, pot_height: float, pot_color: Color,
		seed_value: int, solid: bool = true, hang: Vector3 = Vector3.BACK, ledge: float = 0.0) -> Node3D:
	var key := "%s|%.3f|%.3f|%.3f|%s|%d|%s|%.3f" % [kind, plant_height, pot_radius, pot_height, pot_color.to_html(), seed_value, hang, ledge]
	if not _cache.has(key):
		_cache[key] = [_pot_mesh(pot_radius, pot_height, pot_color), _foliage_mesh(kind, plant_height, pot_radius, pot_height, seed_value, hang, ledge)]
	var meshes: Array = _cache[key]
	var plant := Node3D.new()
	plant.name = "Plant"
	var pot := MeshInstance3D.new()
	pot.name = "PlantPot"
	pot.mesh = meshes[0]
	pot.material_override = HomeMaterials.vertex_colored(0.38)
	plant.add_child(pot)
	var leaves := MeshInstance3D.new()
	leaves.name = "PlantLeaves"
	leaves.mesh = meshes[1]
	leaves.material_override = HomeMaterials.leaf()
	plant.add_child(leaves)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = pot_radius
		cylinder.height = pot_height + 0.3
		shape.shape = cylinder
		shape.position = Vector3(0.0, cylinder.height / 2.0, 0.0)
		body.add_child(shape)
		plant.add_child(body)
	return plant


## O vaso: corpo que afina para baixo, borda redonda e a terra por dentro.
static func _pot_mesh(radius: float, height: float, color: Color) -> ArrayMesh:
	var batch := HomeShapes.Batch.new()
	var body := CylinderMesh.new()
	body.top_radius = radius
	body.bottom_radius = radius * 0.78
	body.height = height
	body.radial_segments = 24
	body.rings = 1
	body.cap_top = false
	batch.add_mesh(body, Transform3D(Basis(), Vector3(0.0, height / 2.0, 0.0)), color)
	var rim := TorusMesh.new()
	rim.inner_radius = radius * 0.94
	rim.outer_radius = radius * 1.06
	rim.rings = 24
	rim.ring_segments = 8
	batch.add_mesh(rim, Transform3D(Basis(), Vector3(0.0, height, 0.0)), color.lightened(0.06))
	var soil := CylinderMesh.new()
	soil.top_radius = radius * 0.97
	soil.bottom_radius = radius * 0.97
	soil.height = 0.01
	soil.radial_segments = 24
	batch.add_mesh(soil, Transform3D(Basis(), Vector3(0.0, height * 0.9, 0.0)), SOIL_COLOR)
	return batch.commit()


static func _foliage_mesh(kind: String, plant_height: float, pot_radius: float, pot_height: float, seed_value: int,
		hang: Vector3, ledge: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var batch := HomeShapes.Batch.new()
	var soil := Vector3(0.0, pot_height * 0.9, 0.0)
	match kind:
		"palmeira":
			_palm(batch, rng, soil, plant_height - soil.y)
		"costela":
			_broadleaf(batch, rng, soil, plant_height - soil.y, pot_radius)
		"espada":
			_sword(batch, rng, soil, plant_height - soil.y, pot_radius)
		"pendente":
			_trailing(batch, rng, soil, plant_height, pot_radius, pot_height, hang, ledge)
	return batch.commit()


## Uma cor de folha sorteada entre o escuro e o claro.
static func _green(rng: RandomNumberGenerator) -> Color:
	var t := rng.randf()
	return LEAF_DARK.lerp(LEAF_MID, t * 2.0) if t < 0.5 else LEAF_MID.lerp(LEAF_LIGHT, (t - 0.5) * 2.0)


## Palmeira: folhas compridas (o caule em arco) com pares de folhinhas.
static func _palm(batch: HomeShapes.Batch, rng: RandomNumberGenerator, soil: Vector3, reach: float) -> void:
	const FRONDS: int = 12
	for f in FRONDS:
		var angle := TAU * f / FRONDS + rng.randf_range(-0.25, 0.25)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var rise := deg_to_rad(rng.randf_range(58.0, 82.0))
		var length := reach * rng.randf_range(0.78, 1.05)
		var arch := rng.randf_range(0.5, 0.9)
		var points := PackedVector3Array()
		var p := soil + outward * 0.02
		var steps := 12
		for s in steps + 1:
			var t := float(s) / steps
			points.append(p)
			var direction := (outward * cos(rise) + Vector3.UP * sin(rise) + Vector3.DOWN * arch * t * 1.6).normalized()
			p += direction * length / steps
		HomeShapes.tube(batch, points, PackedFloat32Array([0.007, 0.003]), STEM_COLOR, 4)
		var color := _green(rng)
		# Pares de folhinhas do primeiro terço até a ponta, menores perto dela.
		for s in range(3, steps):
			var along := (points[s + 1] - points[s]).normalized()
			var side := along.cross(Vector3.UP).normalized()
			var t := float(s) / steps
			for sign_value: float in [-1.0, 1.0]:
				var direction := (side * sign_value + along * 0.8 + Vector3.DOWN * 0.25).normalized()
				var leaf_length := reach * 0.24 * (1.15 - t * 0.6) * rng.randf_range(0.85, 1.1)
				_leaf(batch, points[s].lerp(points[s + 1], 0.5), direction, leaf_length, 0.05, 0.8, color, 0.15, 6)


## Folhas largas em caules compridos que se abrem do meio do vaso.
static func _broadleaf(batch: HomeShapes.Batch, rng: RandomNumberGenerator, soil: Vector3, reach: float, pot_radius: float) -> void:
	const LEAVES: int = 9
	for i in LEAVES:
		var angle := TAU * i / LEAVES * 1.618 + rng.randf_range(-0.2, 0.2)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var rise := deg_to_rad(rng.randf_range(45.0, 80.0))
		var stem_length := reach * rng.randf_range(0.45, 0.75)
		var points := PackedVector3Array()
		var p := soil + outward * pot_radius * 0.2
		var steps := 6
		var direction := Vector3.UP
		for s in steps + 1:
			points.append(p)
			direction = (outward * cos(rise) + Vector3.UP * sin(rise) + Vector3.DOWN * 0.5 * float(s) / steps).normalized()
			p += direction * stem_length / steps
		HomeShapes.tube(batch, points, PackedFloat32Array([0.008, 0.005]), STEM_COLOR.darkened(0.1), 4)
		var blade := (outward * 0.9 + direction * 0.4 + Vector3.UP * 0.1).normalized()
		var size := reach * rng.randf_range(0.32, 0.42)
		_leaf(batch, points[steps], blade, size, size * 0.85, 0.55, _green(rng), 0.12, 8, 0.5)


## Espada-de-são-jorge: folhas retas e grossas para cima, com a borda clara.
static func _sword(batch: HomeShapes.Batch, rng: RandomNumberGenerator, soil: Vector3, reach: float, pot_radius: float) -> void:
	const LEAVES: int = 12
	for i in LEAVES:
		var angle := TAU * i / LEAVES * 1.618
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var tilt := deg_to_rad(rng.randf_range(3.0, 18.0))
		var base := soil + outward * rng.randf_range(0.0, pot_radius * 0.5)
		var direction := (Vector3.UP * cos(tilt) + outward * sin(tilt)).normalized()
		var color := LEAF_DARK.lerp(LEAF_MID, rng.randf_range(0.2, 0.8))
		_leaf(batch, base, direction, reach * rng.randf_range(0.55, 1.0), 0.07, 0.12, color, 0.3, 8, 1.0,
				Color(0.52, 0.5, 0.22))


## Pendente: um tufo em cima e ramos que andam até a borda do móvel e caem.
static func _trailing(batch: HomeShapes.Batch, rng: RandomNumberGenerator, soil: Vector3, drop: float, pot_radius: float,
		pot_height: float, hang: Vector3, ledge: float) -> void:
	for i in 9:
		var angle := TAU * i / 9.0 + rng.randf_range(-0.3, 0.3)
		var direction := (Vector3(cos(angle), 0.0, sin(angle)) * 0.7 + Vector3.UP * 0.8).normalized()
		_leaf(batch, soil, direction, rng.randf_range(0.06, 0.09), 0.06, 0.5, _green(rng), 0.1, 5, 0.5)
	var forward := Vector3(hang.x, 0.0, hang.z).normalized()
	var across := forward.cross(Vector3.UP)
	for v in 5:
		var spread := rng.randf_range(-0.9, 0.9)
		var start := soil + (forward * 0.5 + across * spread * 0.5) * pot_radius
		var lip := Vector3(start.x, pot_height + 0.015, start.z) + forward * pot_radius * 0.7
		var points := PackedVector3Array([start, lip])
		var edge := lip + forward * maxf(ledge - pot_radius * 0.7, 0.02) + across * spread * 0.04
		edge.y = pot_height * 0.15
		points.append(edge)
		var fall := drop * rng.randf_range(0.5, 1.0)
		var steps := 5
		for s in range(1, steps + 1):
			var t := float(s) / steps
			points.append(edge + forward * (0.03 * t) + across * sin(t * 3.0 + v) * 0.02 + Vector3.DOWN * fall * t)
		HomeShapes.tube(batch, points, PackedFloat32Array([0.003]), STEM_COLOR, 3)
		# Uma folhinha a cada pedaço do ramo, virada para fora.
		for s in range(1, points.size()):
			var at := points[s - 1].lerp(points[s], 0.5)
			var out := (forward + across * rng.randf_range(-0.8, 0.8) + Vector3.UP * rng.randf_range(-0.2, 0.4)).normalized()
			_leaf(batch, at, out, rng.randf_range(0.045, 0.065), 0.055, 0.4, _green(rng), 0.1, 4, 0.5)


## Uma folha: uma tira que sai de "base" na direção "direction", vai caindo
## ("droop") e tem a nervura em "V" ("fold"). "shape": 0 = afinada nas duas
## pontas (folhinha), 0,5 = larga perto da base (folha de costela), 1 = espada
## (quase reta até a ponta). "edge" (se não transparente) pinta a borda.
static func _leaf(batch: HomeShapes.Batch, base: Vector3, direction: Vector3, length: float, width: float, droop: float,
		color: Color, fold: float = 0.15, segments: int = 6, shape: float = 0.0, edge: Color = Color(0, 0, 0, 0)) -> void:
	var dir := direction.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.05:
		side = Vector3.RIGHT.rotated(Vector3.UP, base.x * 13.0 + base.z * 7.0)
	side = side.normalized()
	var p := base
	var previous := PackedInt32Array()
	var rib_color := color.lightened(0.1)
	var edge_color := edge if edge.a > 0.0 else color.darkened(0.08)
	for i in segments + 1:
		var t := float(i) / segments
		var d := (dir + Vector3.DOWN * droop * t * 1.4).normalized()
		if i > 0:
			p += d * length / segments
		var face := side.cross(d).normalized()
		if face.y < 0.0:
			face = -face
		var half: float
		if shape >= 1.0:
			half = width * 0.5 * (1.0 - pow(t, 4.0)) * minf(t * 8.0 + 0.4, 1.0)
		elif shape > 0.0:
			half = width * 0.5 * sin(PI * pow(t, 0.55))
		else:
			half = width * 0.5 * sin(PI * pow(t, 0.75))
		var tip := t * t * 0.08
		var rib := batch.vertex(p, face, rib_color.lightened(tip))
		var left := batch.vertex(p - side * half - face * fold * half * 2.0, (face - side * fold).normalized(), edge_color.lightened(tip))
		var right := batch.vertex(p + side * half - face * fold * half * 2.0, (face + side * fold).normalized(), edge_color.lightened(tip))
		var row := PackedInt32Array([left, rib, right])
		if not previous.is_empty():
			batch.quad(previous[0], previous[1], row[1], row[0])
			batch.quad(previous[1], previous[2], row[2], row[1])
		previous = row
