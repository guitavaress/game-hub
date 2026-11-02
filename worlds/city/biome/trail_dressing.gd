class_name TrailDressing
extends Node3D
## Os limites e a sinalização da trilha da montanha (Fase 15.9.3):
##   - paredes invisíveis dos dois lados da trilha e em volta do mirante (só
##     a entrada da trilha fica aberta), para ninguém sair da parte pisável;
##   - estacas de cerca com uma corda, na linha das paredes, para o limite se
##     ver;
##   - lampiões baixos a cada ~15 m, alternando os lados, acesos à noite
##     (grupo "city_night", como os postes);
##   - na entrada (o vão da mureta), dois pilares de pedra e a placa
##     "Trilha do Mirante" virada para a cidade.
##
## As contas (onde ficam as paredes, as estacas e os lampiões) são funções
## estáticas e puras, para os testes conferirem sem montar nada.
##
## Medidas a partir do jogador (player.tscn: cápsula de 0,4 m de raio; o pulo
## de 4,8 m/s sobe ~1,2 m): a parede fica a 2 m do meio da trilha (a trilha
## tem 3 m) e sobe 3 m acima do chão, alto demais para pular.

const SIGN_TEXT: String = "Trilha do Mirante"
## Distância do meio da trilha até a parede (metade da trilha + a folga do vão da mureta).
const WALL_OFFSET: float = 2.0
## A parede sobe isto acima do chão e desce isto abaixo dele.
const WALL_HEIGHT: float = 3.0
const WALL_SINK: float = 1.0
## Um ponto da parede que fique mais perto da trilha do que isto (numa curva
## fechada, o lado de dentro dobra sobre si) sai da linha.
const FOLD_TOLERANCE: float = 0.3
## O anel em volta do mirante: além do disco plano, com pontos a cada 0,5 m.
const RING_GAP: float = 0.5
const RING_STEP: float = 0.5
## Estacas: a cada 3 m, com a corda nesta altura.
const STAKE_SPACING: float = 3.0
const STAKE_SIZE: Vector3 = Vector3(0.1, 1.1, 0.1)
const STAKE_SINK: float = 0.15
const ROPE_HEIGHT: float = 0.85
const ROPE_THICKNESS: float = 0.04
const WOOD_COLOR: Color = Color("3A2A1E")
const ROPE_COLOR: Color = Color("6B5A45")
## Lampiões: a cada 15 m, a partir do 6º metro, um pouco para dentro da parede.
const LAMP_SPACING: int = 15
const LAMP_FIRST: int = 6
const LAMP_INSET: float = 0.25
const LAMP_POST: Vector3 = Vector3(0.12, 0.8, 0.12)
const LAMP_HEAD: Vector3 = Vector3(0.24, 0.28, 0.24)
const LAMP_COLOR: Color = Color(1.0, 0.66, 0.32)  # a do lampião a gás (StreetLight)
const LAMP_ENERGY: float = 1.6
const LAMP_RANGE: float = 7.0
const LAMP_GLOW: float = 4.0
## Os lampiões longe do jogador apagam (economia de luz): começam a sumir aqui.
const LAMP_FADE_BEGIN: float = 60.0
const LAMP_FADE_LENGTH: float = 20.0
const IRON_COLOR: Color = Color("1F1C1A")
## Os pilares da entrada, logo depois da mureta (que tem 0,6 m de espessura).
const PILLAR_SIZE: Vector3 = Vector3(0.8, 3.4, 0.8)
const PILLAR_BACK: float = 0.3
const BEAM_HEIGHT: float = 0.55
const BEAM_DEPTH: float = 0.5
const TEXT_HEIGHT: float = 0.42
const FONT_SIZE: int = 96
const STONE_COLOR: Color = Color(0.55, 0.56, 0.6)

var _lamp_lights: Array[OmniLight3D] = []
var _glass: StandardMaterial3D
var _labels: Array[Label3D] = []


## Monta tudo para a trilha. "stone" é o material dos pilares (null = cinza).
func setup(field: Heightfield, trail: MountainTrail, stone: Material = null) -> void:
	name = "TrailDressing"
	add_to_group("city_night")
	var lines := wall_lines(field, trail)
	# A plataforma do mirante (15.10) tem guarda-corpo próprio: a parede dela
	# entra no corpo das paredes, mas não ganha estacas.
	var deck := LookoutDeck.outline(field, trail, LookoutDeck.direction(field, trail))
	var walls := lines.duplicate()
	if deck.size() >= 2:
		walls.append(deck)
	_add_walls(field, walls)
	_add_fence(field, lines)
	_add_lamps(field, trail)
	_add_gate(trail, stone if stone != null else CityDecor.make_material(STONE_COLOR))
	set_night(0.0)


## As linhas das paredes, no chão: x e z do mundo e, em y, a altura da trilha
## (ou do mirante) ali. Os dois lados da trilha, da mureta até o mirante, e o
## anel do mirante, aberto onde a trilha chega e onde a plataforma de madeira
## encosta (15.10; a parede da plataforma é a LookoutDeck.outline).
static func wall_lines(field: Heightfield, trail: MountainTrail) -> Array[PackedVector3Array]:
	var lines: Array[PackedVector3Array] = []
	var deck_direction := LookoutDeck.direction(field, trail)
	var last := trail.points.size() - 1
	for side: float in [1.0, -1.0]:
		var line := PackedVector3Array()
		for i in trail.points.size():
			var tangent := (trail.points[mini(i + 1, last)] - trail.points[maxi(i - 1, 0)]).normalized()
			var p := trail.points[i] + Vector2(-tangent.y, tangent.x) * side * WALL_OFFSET
			if p.distance_to(trail.lookout_center) < field.lookout_radius:
				continue
			if trail.closest(p).x < WALL_OFFSET - FOLD_TOLERANCE:
				continue
			line.append(Vector3(p.x, trail.heights[i], p.y))
		if line.size() >= 2:
			lines.append(line)

	# O anel: começa logo depois da entrada e dá a volta até o outro lado dela.
	var radius := field.lookout_radius + RING_GAP
	var count := ceili(TAU * radius / RING_STEP)
	var ring: Array[Vector2] = []
	var open: Array[bool] = []
	for k in count:
		var p := trail.lookout_center + Heightfield.direction_of(TAU * k / count) * radius
		ring.append(p)
		open.append(trail.closest(p).x < WALL_OFFSET - FOLD_TOLERANCE
				or LookoutDeck.is_in_opening(trail, deck_direction, p))
	var first := open.find(true)
	var arc := PackedVector3Array()
	for step in count:
		var k := (first + 1 + step) % count if first >= 0 else step
		if open[k]:
			if arc.size() >= 2:
				lines.append(arc)
			arc = PackedVector3Array()
			continue
		arc.append(Vector3(ring[k].x, field.lookout_height, ring[k].y))
	if first < 0:
		arc.append(arc[0])  # sem trilha encostando: o anel fecha
	if arc.size() >= 2:
		lines.append(arc)
	return lines


## Onde ficam as estacas: a cada STAKE_SPACING metros em cada linha (as pontas
## sempre têm uma). Cada lista vira uma cerca, com a corda de estaca a estaca.
static func stake_lines(lines: Array[PackedVector3Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for line in lines:
		var stakes := PackedVector2Array([Vector2(line[0].x, line[0].z)])
		var walked := 0.0
		for i in range(1, line.size()):
			var a := Vector2(line[i - 1].x, line[i - 1].z)
			var b := Vector2(line[i].x, line[i].z)
			walked += a.distance_to(b)
			if walked >= STAKE_SPACING or i == line.size() - 1:
				stakes.append(b)
				walked = 0.0
		result.append(stakes)
	return result


## Onde ficam os lampiões (no chão, x e z): a cada LAMP_SPACING pontos da
## trilha, alternando os lados, fora do mirante.
static func lamp_spots(field: Heightfield, trail: MountainTrail) -> PackedVector2Array:
	var spots := PackedVector2Array()
	var last := trail.points.size() - 1
	var side := 1.0
	for i in range(LAMP_FIRST, trail.points.size(), LAMP_SPACING):
		var tangent := (trail.points[mini(i + 1, last)] - trail.points[maxi(i - 1, 0)]).normalized()
		var p := trail.points[i] + Vector2(-tangent.y, tangent.x) * side * (WALL_OFFSET - LAMP_INSET)
		if p.distance_to(trail.lookout_center) < field.lookout_radius + RING_GAP:
			continue
		spots.append(p)
		side = -side
	return spots


## 0 = dia, 1 = noite: os lampiões acendem aos poucos (a regra do StreetLight)
## e a placa brilha um pouco mais.
func set_night(night: float) -> void:
	var on := smoothstep(0.3, 0.8, night)
	for light in _lamp_lights:
		light.light_energy = LAMP_ENERGY * on
		light.visible = on > 0.01
	if _glass != null:
		_glass.emission_energy_multiplier = LAMP_GLOW * on
	var glow := lerpf(1.0, 1.6, night)
	for label in _labels:
		label.modulate = Color(LAMP_COLOR.r * glow, LAMP_COLOR.g * glow, LAMP_COLOR.b * glow)


## Os lampiões (para os testes).
func get_lamp_lights() -> Array[OmniLight3D]:
	return _lamp_lights


## O texto da placa da entrada.
func get_sign_text() -> String:
	return _labels[0].text if not _labels.is_empty() else ""


# --- Peças ----------------------------------------------------------------------

## As paredes: um corpo só, com os quadriláteros verticais de todas as linhas.
func _add_walls(field: Heightfield, lines: Array[PackedVector3Array]) -> void:
	var faces := PackedVector3Array()
	for line in lines:
		for i in range(1, line.size()):
			var a := _wall_span(field, line[i - 1])
			var b := _wall_span(field, line[i])
			faces.append_array([a[0], b[0], b[1], a[0], b[1], a[1]])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.name = "TrailWalls"
	body.add_child(collision)
	add_child(body)


## Embaixo e em cima da parede num ponto: do mais baixo ao mais alto entre o
## chão desenhado e a trilha, com folga.
static func _wall_span(field: Heightfield, point: Vector3) -> Array[Vector3]:
	var ground := field.surface_at(Vector2(point.x, point.z))
	return [Vector3(point.x, minf(ground, point.y) - WALL_SINK, point.z),
			Vector3(point.x, maxf(ground, point.y) + WALL_HEIGHT, point.z)]


## As estacas e as cordas: duas MultiMesh (dois desenhos para a trilha toda).
func _add_fence(field: Heightfield, lines: Array[PackedVector3Array]) -> void:
	var stakes: Array[Transform3D] = []
	var ropes: Array[Transform3D] = []
	for line in stake_lines(lines):
		var previous := Vector3.INF
		for p in line:
			var ground := field.surface_at(p)
			stakes.append(Transform3D(Basis.IDENTITY, Vector3(p.x, ground + STAKE_SIZE.y / 2.0 - STAKE_SINK, p.y)))
			var top := Vector3(p.x, ground + ROPE_HEIGHT, p.y)
			if previous != Vector3.INF and previous.distance_to(top) > 0.01:
				# Uma caixa fina esticada de uma estaca à outra.
				var basis := Basis.looking_at(top - previous)
				basis = basis.scaled_local(Vector3(1.0, 1.0, previous.distance_to(top)))
				ropes.append(Transform3D(basis, (previous + top) / 2.0))
			previous = top
	_add_multimesh("Stakes", _box(STAKE_SIZE), CityDecor.make_material(WOOD_COLOR), stakes)
	_add_multimesh("Ropes", _box(Vector3(ROPE_THICKNESS, ROPE_THICKNESS, 1.0)), CityDecor.make_material(ROPE_COLOR), ropes)


## Os lampiões: a haste e o vidro em MultiMesh e uma luz pequena em cada um.
func _add_lamps(field: Heightfield, trail: MountainTrail) -> void:
	var posts: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	for spot in lamp_spots(field, trail):
		var ground := field.surface_at(spot)
		posts.append(Transform3D(Basis.IDENTITY, Vector3(spot.x, ground + LAMP_POST.y / 2.0, spot.y)))
		var head := Vector3(spot.x, ground + LAMP_POST.y + LAMP_HEAD.y / 2.0, spot.y)
		heads.append(Transform3D(Basis.IDENTITY, head))
		var light := OmniLight3D.new()
		light.name = "Lamp%d" % _lamp_lights.size()
		light.light_color = LAMP_COLOR
		light.omni_range = LAMP_RANGE
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = LAMP_FADE_BEGIN
		light.distance_fade_length = LAMP_FADE_LENGTH
		light.position = head
		add_child(light)
		_lamp_lights.append(light)
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = LAMP_COLOR
	_glass.emission_enabled = true
	_glass.emission = LAMP_COLOR
	_add_multimesh("LampPosts", _box(LAMP_POST), CityDecor.make_material(IRON_COLOR), posts)
	_add_multimesh("LampHeads", _box(LAMP_HEAD), _glass, heads)


## A entrada: dois pilares de pedra (com colisão) logo depois da mureta, uma
## viga por cima e o nome dos dois lados dela (o de dentro, virado para a cidade).
func _add_gate(trail: MountainTrail, stone: Material) -> void:
	var gate := Node3D.new()
	gate.name = "TrailGate"
	var depth := PILLAR_BACK + PILLAR_SIZE.z / 2.0
	gate.position = Vector3(trail.start.x, 0.0, trail.start.y) + Vector3(trail.outward.x, 0.0, trail.outward.y) * depth
	# O -Z do portão aponta montanha acima; o +Z, para a cidade.
	gate.basis = Basis.looking_at(Vector3(trail.outward.x, 0.0, trail.outward.y))
	add_child(gate)
	var half_span := WALL_OFFSET + PILLAR_SIZE.x / 2.0
	var body := StaticBody3D.new()
	body.name = "Pillars"
	gate.add_child(body)
	for side: float in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		pillar.mesh = _box(PILLAR_SIZE)
		pillar.material_override = stone
		pillar.position = Vector3(side * half_span, PILLAR_SIZE.y / 2.0, 0.0)
		gate.add_child(pillar)
		var box := BoxShape3D.new()
		box.size = PILLAR_SIZE
		var collision := CollisionShape3D.new()
		collision.shape = box
		collision.position = pillar.position
		body.add_child(collision)
	var beam_width := half_span * 2.0 + PILLAR_SIZE.x
	var beam := MeshInstance3D.new()
	beam.mesh = _box(Vector3(beam_width, BEAM_HEIGHT, BEAM_DEPTH))
	beam.material_override = stone
	beam.position = Vector3(0.0, PILLAR_SIZE.y + BEAM_HEIGHT / 2.0, 0.0)
	gate.add_child(beam)
	var pixel_size := TEXT_HEIGHT / FONT_SIZE
	var text_width := HubFonts.SIGN.get_string_size(SIGN_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * pixel_size
	if text_width > beam_width - 0.4:
		pixel_size *= (beam_width - 0.4) / text_width
	for side: float in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = SIGN_TEXT
		label.font = HubFonts.SIGN
		label.font_size = FONT_SIZE
		label.pixel_size = pixel_size
		label.outline_size = 0
		label.double_sided = false
		label.position = Vector3(0.0, PILLAR_SIZE.y + BEAM_HEIGHT / 2.0, side * (BEAM_DEPTH / 2.0 + 0.02))
		label.rotation.y = 0.0 if side > 0.0 else PI
		gate.add_child(label)
		_labels.append(label)


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
