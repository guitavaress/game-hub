class_name LookoutDeck
extends Node3D
## A plataforma de madeira do mirante (Fase 15.10): avança da beirada do disco
## do mirante, virada para a praça (e a torre do relógio, no centro da cidade),
## por cima da encosta que desce. É dali que se vê o bairro, a cidade e o vão
## (do meio do disco, a beirada tapa a vista: capturas da 15.9.1b).
##
## Peças: o piso de tábuas (com colisão e footstep = "wood"), os pés até a
## encosta, o guarda-corpo nos três lados de fora e um banco no disco, de
## frente para a abertura. As paredes invisíveis da beirada da plataforma
## entram no corpo das paredes da trilha (TrailDressing usa outline()), e o
## anel do mirante abre onde a plataforma encosta (is_in_opening()).
##
## A direção sai da linha do mirante até a praça e gira aos poucos, para um
## lado e para o outro, até achar um lugar que sirva:
##   - longe da trilha que chega (as paredes se cruzariam). A última volta da
##     trilha costuma subir pelo lado da praça, então o giro é comum;
##   - por cima da encosta que desce: o chão nunca fura o piso, e na ponta
##     fica pelo menos MIN_DROP abaixo dele (senão não há vista nem "ponta").
## Sem lugar, não há plataforma (direction() = ZERO) e o mirante fica como
## antes: o anel fechado.
##
## As contas são estáticas e puras (os testes conferem sem montar nada).
## Medidas a partir do jogador (cápsula de 0,4 m de raio, olho a 1,7 m).

## Largura do piso e quanto ele avança além da beirada do disco (m).
const WIDTH: float = 4.0
const REACH: float = 4.5
## O piso começa este tanto para dentro do disco (sem degrau na emenda).
const ROOT_INSET: float = 1.0
## O piso fica um pouco acima do disco, para a encosta logo depois da beirada
## (que oscila uns centímetros) não furar as tábuas. A cápsula (raio 0,4 m)
## sobe 6 cm como uma rampa de ~32°, abaixo dos 45° de piso: nem percebe.
const TOP_LIFT: float = 0.06
const THICKNESS: float = 0.3
const PLANK_DEPTH: float = 0.22
const PLANK_GAP: float = 0.03
const PLANK_HEIGHT: float = 0.06
## O guarda-corpo (e a parede invisível) fica este tanto para dentro da borda.
const RAIL_INSET: float = 0.15
const RAIL_HEIGHT: float = 1.0
const RAIL_SIZE: float = 0.08
const RAIL_POST_SPACING: float = 1.2
const RAIL_POST: Vector3 = Vector3(0.1, 1.05, 0.1)
## Os pés: da parte que fica no ar até a encosta, enterrados este tanto.
const LEG_SIZE: float = 0.22
const LEG_SINK: float = 0.3
## Pontos da linha da parede a cada meio metro (como o anel do mirante).
const OUTLINE_STEP: float = 0.5
## A plataforma fica a pelo menos isto além das paredes da trilha.
const TRAIL_CLEARANCE: float = 0.5
## Na ponta, o chão fica pelo menos isto abaixo do piso (m).
const MIN_DROP: float = 1.0
## Fora do disco, o chão fica pelo menos isto abaixo de cima do piso (m).
const FLOOR_GAP: float = 0.0
## O giro procurado, de TURN_STEP em TURN_STEP, até MAX_TURN de cada lado.
const TURN_STEP: float = deg_to_rad(5.0)
const MAX_TURN: float = deg_to_rad(75.0)
## O ponto da vista fica a isto dos guarda-corpos da ponta e do lado da praça.
const VIEW_INSET: float = 0.6
## O banco: no disco, a BENCH_BACK m da beirada, de frente para a abertura.
const BENCH_BACK: float = 1.8
const BENCH_SEAT: Vector3 = Vector3(1.6, 0.08, 0.45)
const BENCH_SEAT_HEIGHT: float = 0.45
const BENCH_BACKREST: Vector3 = Vector3(1.6, 0.45, 0.06)
const DECK_COLOR: Color = Color("6B4E35")
const BEAM_COLOR: Color = Color("3A2A1E")  # a madeira das estacas da trilha
const FOOTSTEP: String = "wood"

var _direction: Vector2 = Vector2.ZERO


## Monta a plataforma. Falso (e nada montado) se não houver lugar para ela.
func setup(field: Heightfield, trail: MountainTrail) -> bool:
	name = "LookoutDeck"
	_direction = direction(field, trail)
	if _direction == Vector2.ZERO:
		return false
	var center := trail.lookout_center
	var top := deck_top(field)
	# O -Z do nó aponta para fora (a praça); x é o lado. A origem fica no
	# centro do disco, na altura do piso.
	position = Vector3(center.x, top, center.y)
	basis = Basis.looking_at(Vector3(_direction.x, 0.0, _direction.y))
	var near := field.lookout_radius - ROOT_INSET
	var far := field.lookout_radius + REACH
	_add_floor(near, far)
	_add_legs(field, near, far)
	_add_railing(field, far)
	_add_bench(field)
	return true


## Para onde a plataforma aponta (no chão, unitário), ou ZERO se não couber.
func get_direction() -> Vector2:
	return _direction


## A direção da plataforma: a da praça (o centro da cidade), girada o mínimo
## para ficar longe da trilha e por cima da encosta. ZERO se nenhuma servir.
static func direction(field: Heightfield, trail: MountainTrail) -> Vector2:
	var toward := -trail.lookout_center.normalized()
	var steps := roundi(MAX_TURN / TURN_STEP)
	for k in steps + 1:
		for side: float in [1.0, -1.0]:
			if k == 0 and side < 0.0:
				continue
			var candidate := toward.rotated(side * k * TURN_STEP)
			if _clear_of_trail(field, trail, candidate) and _over_slope(field, trail, candidate):
				return candidate
	return Vector2.ZERO


## O piso inteiro (com folga) fica longe das paredes da trilha?
static func _clear_of_trail(field: Heightfield, trail: MountainTrail, along_dir: Vector2) -> bool:
	var side_dir := Vector2(-along_dir.y, along_dir.x)
	var limit := TrailDressing.WALL_OFFSET + TRAIL_CLEARANCE
	var along := field.lookout_radius - ROOT_INSET
	while along <= field.lookout_radius + REACH + 0.001:
		var lateral := -WIDTH / 2.0
		while lateral <= WIDTH / 2.0 + 0.001:
			var p := trail.lookout_center + along_dir * along + side_dir * lateral
			if trail.closest(p).x < limit:
				return false
			lateral += 0.5
		along += 0.5
	return true


## A encosta desce embaixo do piso? Fora do disco, o chão fica abaixo do
## piso em toda a largura, e na ponta, pelo menos MIN_DROP abaixo.
static func _over_slope(field: Heightfield, trail: MountainTrail, along_dir: Vector2) -> bool:
	var side_dir := Vector2(-along_dir.y, along_dir.x)
	var top := deck_top(field)
	var along := field.lookout_radius
	while along <= field.lookout_radius + REACH + 0.001:
		for lateral: float in [-WIDTH / 2.0, 0.0, WIDTH / 2.0]:
			var p := trail.lookout_center + along_dir * along + side_dir * lateral
			if field.surface_at(p) > top - FLOOR_GAP:
				return false
		along += 0.5
	var tip := trail.lookout_center + along_dir * (field.lookout_radius + REACH)
	return field.surface_at(tip) <= top - MIN_DROP


## A altura de cima do piso (y do mundo).
static func deck_top(field: Heightfield) -> float:
	return field.lookout_height + TOP_LIFT


## Metade da abertura do anel (e da distância entre os guarda-corpos dos lados).
static func opening_half() -> float:
	return WIDTH / 2.0 - RAIL_INSET


## Um ponto (no chão) do anel do mirante fica na abertura da plataforma?
static func is_in_opening(trail: MountainTrail, along_dir: Vector2, p: Vector2) -> bool:
	if along_dir == Vector2.ZERO:
		return false
	var local := p - trail.lookout_center
	return local.dot(along_dir) > 0.0 and absf(local.dot(Vector2(-along_dir.y, along_dir.x))) < opening_half()


## A linha da parede invisível em volta da plataforma (x e z do mundo; y, a
## altura do piso): do anel, por um lado até a ponta, a ponta, e o outro lado
## de volta ao anel. Vazia se não houver plataforma.
static func outline(field: Heightfield, trail: MountainTrail, along_dir: Vector2) -> PackedVector3Array:
	var line := PackedVector3Array()
	if along_dir == Vector2.ZERO:
		return line
	var side_dir := Vector2(-along_dir.y, along_dir.x)
	var s := opening_half()
	var ring := field.lookout_radius + TrailDressing.RING_GAP
	var root := sqrt(ring * ring - s * s)  # onde o lado encontra o anel
	var tip := field.lookout_radius + REACH - RAIL_INSET
	var corners: Array[Vector2] = [Vector2(root, -s), Vector2(tip, -s), Vector2(tip, s), Vector2(root, s)]
	var y := deck_top(field)
	for i in corners.size():
		var a := corners[i]
		line.append(_to_world(trail, along_dir, side_dir, a, y))
		if i == corners.size() - 1:
			break
		var b := corners[i + 1]
		var pieces := ceili(a.distance_to(b) / OUTLINE_STEP)
		for k in range(1, pieces):
			line.append(_to_world(trail, along_dir, side_dir, a.lerp(b, float(k) / pieces), y))
	return line


## O ponto do piso de onde se olha a vista (no mundo): o canto da ponta do
## lado da praça, a VIEW_INSET dos dois guarda-corpos (onde uma pessoa se
## debruça; o guarda-corpo fica abaixo do quadro). Sem plataforma, o centro
## do disco.
static func view_spot(field: Heightfield, trail: MountainTrail, along_dir: Vector2) -> Vector3:
	if along_dir == Vector2.ZERO:
		return Vector3(trail.lookout_center.x, field.lookout_height, trail.lookout_center.y)
	var side_dir := Vector2(-along_dir.y, along_dir.x)
	var plaza_side := signf(side_dir.dot(-trail.lookout_center))
	var tip := field.lookout_radius + REACH - RAIL_INSET - VIEW_INSET
	var p := trail.lookout_center + along_dir * tip + side_dir * plaza_side * (opening_half() - VIEW_INSET)
	return Vector3(p.x, deck_top(field), p.y)


static func _to_world(trail: MountainTrail, along_dir: Vector2, side_dir: Vector2, local: Vector2, y: float) -> Vector3:
	var p := trail.lookout_center + along_dir * local.x + side_dir * local.y
	return Vector3(p.x, y, p.y)


# --- Peças (no espaço do nó: -Z para fora, origem no centro do disco) ---------

## O piso: uma laje escura com a colisão (footstep "wood") e as tábuas por
## cima, atravessadas (uma MultiMesh).
func _add_floor(near: float, far: float) -> void:
	var length := far - near
	var slab_size := Vector3(WIDTH, THICKNESS - PLANK_HEIGHT, length)
	var slab := MeshInstance3D.new()
	slab.name = "Slab"
	slab.mesh = _box(slab_size)
	slab.material_override = CityDecor.make_material(BEAM_COLOR)
	slab.position = Vector3(0.0, -PLANK_HEIGHT - slab_size.y / 2.0, -(near + length / 2.0))
	add_child(slab)

	var body := StaticBody3D.new()
	body.name = "Deck"
	body.set_meta("footstep", FOOTSTEP)
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, THICKNESS, length)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position = Vector3(0.0, -THICKNESS / 2.0, -(near + length / 2.0))
	body.add_child(collision)
	add_child(body)

	var planks: Array[Transform3D] = []
	var z := near + PLANK_DEPTH / 2.0
	while z <= far - PLANK_DEPTH / 2.0 + 0.001:
		planks.append(Transform3D(Basis.IDENTITY, Vector3(0.0, -PLANK_HEIGHT / 2.0, -z)))
		z += PLANK_DEPTH + PLANK_GAP
	_add_multimesh("Planks", _box(Vector3(WIDTH, PLANK_HEIGHT, PLANK_DEPTH)),
			CityDecor.make_material(DECK_COLOR), planks)


## Os pés: nos cantos e no meio dos lados da parte que fica no ar, da laje
## até a encosta (só onde o chão fica abaixo do piso).
func _add_legs(field: Heightfield, near: float, far: float) -> void:
	var legs: Array[Transform3D] = []
	var bottom := -THICKNESS
	var edge := field.lookout_radius + 1.0
	for along: float in [edge, (edge + far) / 2.0, far - LEG_SIZE]:
		if along < near:
			continue
		for side: float in [-1.0, 1.0]:
			var local := Vector3(side * (WIDTH / 2.0 - LEG_SIZE), 0.0, -along)
			var world := transform * local  # a montanha fica na origem da cidade
			var ground := field.surface_at(Vector2(world.x, world.z)) - position.y
			if ground >= bottom - 0.05:
				continue
			var height := bottom - ground + LEG_SINK
			var leg := Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, height, 1.0)),
					Vector3(local.x, bottom - height / 2.0, local.z))
			legs.append(leg)
	_add_multimesh("Legs", _box(Vector3(LEG_SIZE, 1.0, LEG_SIZE)), CityDecor.make_material(BEAM_COLOR), legs)


## O guarda-corpo nos três lados de fora: postes a cada ~1,2 m e duas traves
## (em cima e no meio), na linha da parede invisível.
func _add_railing(field: Heightfield, far: float) -> void:
	var s := opening_half()
	var ring := field.lookout_radius + TrailDressing.RING_GAP
	var root := sqrt(ring * ring - s * s)
	var tip := far - RAIL_INSET
	var corners: Array[Vector3] = [Vector3(-s, 0.0, -root), Vector3(-s, 0.0, -tip),
			Vector3(s, 0.0, -tip), Vector3(s, 0.0, -root)]
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	for i in 3:
		var a := corners[i]
		var b := corners[i + 1]
		var pieces := maxi(1, ceili(a.distance_to(b) / RAIL_POST_SPACING))
		for k in pieces + 1:
			if i > 0 and k == 0:
				continue  # o canto já tem poste
			posts.append(Transform3D(Basis.IDENTITY, a.lerp(b, float(k) / pieces) + Vector3(0.0, RAIL_POST.y / 2.0, 0.0)))
		for height: float in [RAIL_HEIGHT, RAIL_HEIGHT / 2.0]:
			var basis := Basis.looking_at(b - a).scaled_local(Vector3(1.0, 1.0, a.distance_to(b)))
			rails.append(Transform3D(basis, (a + b) / 2.0 + Vector3(0.0, height, 0.0)))
	var wood := CityDecor.make_material(BEAM_COLOR)
	_add_multimesh("RailPosts", _box(RAIL_POST), wood, posts)
	_add_multimesh("Rails", _box(Vector3(RAIL_SIZE, RAIL_SIZE, 1.0)), wood, rails)


## O banco, no disco, de frente para a abertura (sentado, olha-se para a praça).
func _add_bench(field: Heightfield) -> void:
	var bench := Node3D.new()
	bench.name = "Bench"
	# O piso do disco fica TOP_LIFT abaixo do nó.
	bench.position = Vector3(0.0, -TOP_LIFT, -(field.lookout_radius - BENCH_BACK))
	add_child(bench)
	var wood := CityDecor.make_material(DECK_COLOR)
	var dark := CityDecor.make_material(BEAM_COLOR)
	var seat := MeshInstance3D.new()
	seat.mesh = _box(BENCH_SEAT)
	seat.material_override = wood
	seat.position = Vector3(0.0, BENCH_SEAT_HEIGHT, 0.0)
	bench.add_child(seat)
	# O encosto fica do lado de trás (para dentro do disco, +Z).
	var back := MeshInstance3D.new()
	back.mesh = _box(BENCH_BACKREST)
	back.material_override = wood
	back.position = Vector3(0.0, BENCH_SEAT_HEIGHT + 0.1 + BENCH_BACKREST.y / 2.0, BENCH_SEAT.z / 2.0)
	bench.add_child(back)
	for side: float in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		leg.mesh = _box(Vector3(0.08, BENCH_SEAT_HEIGHT + 0.1 + BENCH_BACKREST.y, BENCH_SEAT.z))
		leg.material_override = dark
		leg.position = Vector3(side * (BENCH_SEAT.x / 2.0 - 0.1), (BENCH_SEAT_HEIGHT + 0.1 + BENCH_BACKREST.y) / 2.0, 0.0)
		bench.add_child(leg)
	var body := StaticBody3D.new()
	body.name = "BenchBody"
	body.set_meta("footstep", FOOTSTEP)
	var box := BoxShape3D.new()
	box.size = Vector3(BENCH_SEAT.x, BENCH_SEAT_HEIGHT + 0.1 + BENCH_BACKREST.y, BENCH_SEAT.z + 0.06)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position = Vector3(0.0, box.size.y / 2.0, 0.0)
	body.add_child(collision)
	bench.add_child(body)


func _add_multimesh(node_name: String, mesh: Mesh, material: Material, items: Array[Transform3D]) -> void:
	if items.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = items.size()
	for i in items.size():
		multimesh.set_instance_transform(i, items[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)


static func _box(box_size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return mesh
