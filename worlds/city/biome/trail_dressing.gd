class_name TrailDressing
extends Node3D
## Os limites e a sinalização da trilha da montanha (Fase 15.9.3):
##   - paredes invisíveis dos dois lados da trilha e em volta do mirante (só
##     a entrada da trilha fica aberta), para ninguém sair da parte pisável;
##   - estacas de cerca com uma corda, na linha das paredes, para o limite se
##     ver;
##   - lampiões baixos a cada ~9 m, alternando os lados, acesos à noite
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
## Lampiões: a cada 9 m, a partir do 6º metro, um pouco para dentro da parede.
const LAMP_SPACING: int = 9
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
var _field: Heightfield
var _trail: MountainTrail
var _banners: Array[TrailBanner] = []
var _art_queue: Array[TrailBanner] = []
var _campfire: Campfire

## A margem tem só 0,5 m: peças compridas acompanham a trilha, sem alargá-la.
const CONTENT_DEPTH: float = 0.34
const CONTENT_MARGIN: float = 0.06
const BANNER_SPACING: int = 3
const STOP_SHARES: Array[float] = [0.20, 0.43, 0.65, 0.84]
const STOP_KINDS: Array[String] = ["campfire", "cairn", "frozen_fall", "bench"]
const STOP_LENGTHS: Array[float] = [3.0, 2.8, 3.2, 2.0]


## Monta tudo para a trilha. "stone" é o material dos pilares (null = cinza).
func setup(field: Heightfield, trail: MountainTrail, stone: Material = null) -> void:
	name = "TrailDressing"
	_field = field
	_trail = trail
	set_process(false)
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
	_add_stops(field, trail)
	set_night(0.0)


## Recebe a mesma Array de SteamGame de district["games"], depois de setup.
## Horas vêm da biblioteca; as contas recebem uma cópia, sem alterar a lista.
## Sobe do menos ao mais jogado. Se a biblioteca exceder os lugares seguros,
## expõe os mais jogados que couberem, mantendo pelo menos 3 m entre mastros.
func set_games(games: Array) -> void:
	_art_queue.clear()
	for banner in _banners:
		remove_child(banner)
		banner.queue_free()
	_banners.clear()
	set_process(false)
	if _trail == null or games.is_empty():
		return
	var entries: Array[Dictionary] = []
	var library: Node = get_tree().root.get_node("SteamLibrary")
	for game: SteamGame in games:
		entries.append({"app_id": game.app_id, "name": game.name,
				"minutes": library.get_playtime_minutes(game.app_id)})
	for placement in banner_spots(_field, _trail, entries):
		var banner := TrailBanner.new()
		banner.transform = placement["transform"]
		add_child(banner)
		banner.setup(placement["game"])
		_banners.append(banner)
		_art_queue.append(banner)
	# get_art lê a capa; preload_world_art só carrega hero/logo, não capas.
	# Uma leitura por quadro evita uma rajada de disco ao receber a biblioteca.
	set_process(not _art_queue.is_empty())


func _process(_delta: float) -> void:
	if not _art_queue.is_empty():
		var banner: TrailBanner = _art_queue.pop_front()
		banner.request_art()
	set_process(not _art_queue.is_empty())


## Ordenação pura: horas desconhecidas (-1) antes das conhecidas; empate por ID.
static func ordered_games(games: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary[int, bool] = {}
	for game in games:
		var id: int = int(game.get("app_id", 0))
		if id <= 0 or seen.has(id):
			continue
		seen[id] = true
		result.append(game.duplicate())
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["minutes"]) != int(b["minutes"]):
			return int(a["minutes"]) < int(b["minutes"])
		return int(a["app_id"]) < int(b["app_id"]))
	return result


## Cada parada tem transform, size, index e kind. Procura uma reta perto da
## fração desejada; não força uma peça numa curva em que ela não cabe.
static func stop_spots(field: Heightfield, trail: MountainTrail) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not trail.valid:
		return result
	var lamps := lamp_spots(field, trail)
	for k in STOP_KINDS.size():
		var wanted := roundi((trail.points.size() - 1) * STOP_SHARES[k])
		var size := Vector2(STOP_LENGTHS[k], CONTENT_DEPTH)
		var found: Dictionary = {}
		for offset in range(0, 25):
			for direction: int in [1, -1]:
				var index := wanted + offset * direction
				for side: float in [1.0, -1.0]:
					var spot := _content_spot(field, trail, index, side, size)
					if not spot.is_empty() and _away_from_lamps(spot, lamps):
						found = spot
						break
				if not found.is_empty():
					break
			if not found.is_empty():
				break
		if not found.is_empty():
			found["kind"] = STOP_KINDS[k]
			result.append(found)
	return result


## Distribui os jogos pela subida inteira, sem ocupar paradas ou lampiões.
static func banner_spots(field: Heightfield, trail: MountainTrail, games: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if games.is_empty() or not trail.valid:
		return result
	var stops := stop_spots(field, trail)
	var lamps := lamp_spots(field, trail)
	var slots: Array[Dictionary] = []
	for index in range(14, trail.points.size() - 14, BANNER_SPACING):
		var reserved := false
		for stop in stops:
			if absi(index - int(stop["index"])) < 5:
				reserved = true
		if reserved:
			continue
		var preferred := 1.0 if slots.size() % 2 == 0 else -1.0
		for side: float in [preferred, -preferred]:
			var spot := _content_spot(field, trail, index, side, TrailBanner.FOOTPRINT)
			if not spot.is_empty() and _away_from_lamps(spot, lamps):
				slots.append(spot)
				break
	var ordered := ordered_games(games)
	var count := mini(ordered.size(), slots.size())
	for i in count:
		var slot_index := roundi(float(i) * (slots.size() - 1) / maxf(count - 1, 1.0))
		if count == 1:
			slot_index = slots.size() - 1
		var spot := slots[slot_index].duplicate()
		spot["game"] = ordered[ordered.size() - count + i]
		result.append(spot)
	return result


## Retângulo inteiro amostrado, não só o centro: protege também as curvas.
## Local X acompanha a trilha; +Z olha para o caminho (frente das peças).
static func _content_spot(field: Heightfield, trail: MountainTrail, index: int, side: float, size: Vector2) -> Dictionary:
	if index < 10 or index >= trail.points.size() - 10:
		return {}
	var tangent := (trail.points[index + 1] - trail.points[index - 1]).normalized()
	var outward := Vector2(-tangent.y, tangent.x) * side
	var middle := trail.points[index] + outward * (field.trail_width / 2.0 + WALL_OFFSET) / 2.0
	if middle.distance_to(trail.lookout_center) < field.lookout_radius + 3.0:
		return {}
	var basis := Basis.looking_at(Vector3(outward.x, 0.0, outward.y))
	var transform := Transform3D(basis, Vector3(middle.x, field.surface_at(middle), middle.y))
	var spot := {"transform": transform, "size": size, "index": index}
	for point in footprint_points(spot):
		var distance := trail.closest(point).x
		if distance < field.trail_width / 2.0 + CONTENT_MARGIN or distance > WALL_OFFSET - CONTENT_MARGIN:
			return {}
	return spot


static func footprint_points(spot: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var size: Vector2 = spot["size"]
	var transform: Transform3D = spot["transform"]
	var steps := ceili(size.x / 0.15)
	for i in range(steps + 1):
		for z: float in [-size.y / 2.0, 0.0, size.y / 2.0]:
			var p := transform * Vector3(lerpf(-size.x / 2.0, size.x / 2.0, float(i) / steps), 0.0, z)
			points.append(Vector2(p.x, p.z))
	return points


static func _away_from_lamps(spot: Dictionary, lamps: PackedVector2Array) -> bool:
	var transform: Transform3D = spot["transform"]
	var size: Vector2 = spot["size"]
	for lamp in lamps:
		var local := transform.affine_inverse() * Vector3(lamp.x, transform.origin.y, lamp.y)
		if absf(local.x) < size.x / 2.0 + 0.3 and absf(local.z) < size.y / 2.0 + 0.3:
			return false
	return true


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
	if _campfire != null:
		_campfire.set_night(night)
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

## Quatro conjuntos pequenos, pousados na margem; a faixa central fica livre.
func _add_stops(field: Heightfield, trail: MountainTrail) -> void:
	var stone := CityDecor.pbr_material("Rock058", 0.7, Color("89939D"))
	var wood := HomeMaterials.wood(Color("58402E"), false, 0.85)
	for spot in stop_spots(field, trail):
		var stop := Node3D.new()
		stop.name = "TrailStop_%s" % spot["kind"]
		stop.transform = spot["transform"]
		stop.set_meta("trail_stop", spot["kind"])
		add_child(stop)
		match String(spot["kind"]):
			"campfire":
				_add_bench(stop, -0.6, 1.5, wood, stone)
				_add_campfire(stop, 1.10, stone, wood)
			"cairn":
				_add_bench(stop, -0.7, 1.2, wood, stone)
				for level in 7:
					var width := lerpf(0.64, 0.16, float(level) / 6.0)
					_rock(stop, Vector3(0.82 + sin(level * 2.0) * 0.035, 0.10 + level * 0.20, 0.0),
							Vector3(width, 0.24, CONTENT_DEPTH * (1.0 - level * 0.07)), stone)
			"frozen_fall":
				_add_frozen_fall(stop, stone)
			"bench":
				_add_bench(stop, 0.0, 1.9, wood, stone)


func _add_bench(parent: Node3D, x: float, length: float, wood: Material, stone: Material) -> void:
	# Pernas enterradas: a rampa não deixa o banco flutuando no lado mais baixo.
	for side: float in [-1.0, 1.0]:
		_piece(parent, "BenchFoot", _box(Vector3(0.18, 0.85, 0.28)),
				Vector3(x + side * (length / 2.0 - 0.2), 0.06, 0.0), stone)
	for z: float in [-0.085, 0.085]:
		_piece(parent, "Seat", _box(Vector3(length, 0.09, 0.16)), Vector3(x, 0.48, z), wood)
	_piece(parent, "Back", _box(Vector3(length, 0.20, 0.06)), Vector3(x, 0.84, -0.13), wood)
	for side: float in [-1.0, 1.0]:
		_piece(parent, "BackPost", _box(Vector3(0.06, 0.55, 0.06)),
				Vector3(x + side * (length / 2.0 - 0.2), 0.67, -0.13), wood)


func _add_campfire(parent: Node3D, x: float, stone: Material, wood: Material) -> void:
	_campfire = Campfire.new()
	_campfire.name = "Campfire"
	_campfire.position.x = x
	parent.add_child(_campfire)
	_campfire.add_to_group("city_night")
	# Fogo pequeno de beira de caminho: anel oval, toras e brasas, sem partículas.
	for k in 10:
		var angle := TAU * k / 10.0
		_rock(_campfire, Vector3(cos(angle) * 0.23, 0.04, sin(angle) * 0.115),
				Vector3(0.13, 0.16, 0.10), stone)
	for z: float in [-0.07, 0.07]:
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.045
		log_mesh.bottom_radius = 0.055
		log_mesh.height = 0.42
		log_mesh.radial_segments = 12
		var log := _piece(_campfire, "Log", log_mesh, Vector3(0.0, 0.12, z), wood)
		log.rotation.z = PI / 2.0
	_campfire.embers = StandardMaterial3D.new()
	_campfire.embers.albedo_color = Color("4A2517")
	_campfire.embers.emission_enabled = true
	_campfire.embers.emission = Color("E08040")
	_rock(_campfire, Vector3(0.0, 0.10, 0.0), Vector3(0.35, 0.08, 0.19), _campfire.embers)
	_campfire.flames = Node3D.new()
	_campfire.flames.name = "Flames"
	_campfire.add_child(_campfire.flames)
	# Línguas curvas de chama, com transparência suave, em uma única malha.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tongue in 7:
		var x0 := (tongue - 3) * 0.045
		var height := 0.27 + 0.14 * (0.5 + 0.5 * sin(tongue * 3.7))
		for level in 6:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0)]:
				var t := float(level + corner.y) / 6.0
				var width := (1.0 - t) * 0.045
				surface.set_color(Color(1.0, lerpf(0.64, 0.20, t), 0.08, (1.0 - t) * 0.85))
				surface.add_vertex(Vector3(x0 + sin(t * 5.0 + tongue) * t * 0.03 + (corner.x * 2 - 1) * width,
						0.15 + t * height, sin(tongue * 2.0) * 0.045))
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.vertex_color_use_as_albedo = true
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_piece(_campfire.flames, "Fire", surface.commit(), Vector3.ZERO, flame_material)
	_campfire.light = OmniLight3D.new()
	_campfire.light.name = "Firelight"
	_campfire.light.position.y = 0.6
	_campfire.light.light_color = LAMP_COLOR
	_campfire.light.omni_range = LAMP_RANGE
	_campfire.light.shadow_enabled = false
	_campfire.light.distance_fade_enabled = true
	_campfire.light.distance_fade_begin = LAMP_FADE_BEGIN
	_campfire.light.distance_fade_length = LAMP_FADE_LENGTH
	_campfire.add_child(_campfire.light)


func _add_frozen_fall(parent: Node3D, stone: Material) -> void:
	# Uma cortina contínua, com sulcos verticais e uma borda de neve. Gelo
	# opaco evita refração e a ordenação cara de várias camadas transparentes.
	var ice := CityDecor.pbr_material("Snow010A", 0.5, Color("ACC9DA")).duplicate() as StandardMaterial3D
	ice.roughness_texture = null
	ice.roughness = 0.23
	ice.normal_scale = 0.12
	var snow := CityDecor.pbr_material("Snow010A", 0.6, Color("C0CCD6"))
	for k in 9:
		var x := -1.40 + k * 0.35
		var height := _ice_height(x)
		_piece(parent, "RockLedge", _box(Vector3(0.38, height + 0.30, 0.16)),
				Vector3(x, height / 2.0 - 0.18, -0.075), stone)
	var curtain := SurfaceTool.new()
	curtain.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	const COLUMNS: int = 64
	const ROWS: int = 20
	for column in COLUMNS:
		for row in ROWS:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var u := float(column + corner.x) / COLUMNS
				var v := float(row + corner.y) / ROWS
				var x := lerpf(-1.48, 1.48, u)
				var ridge := sin(x * 41.0) * 0.014 + sin(x * 19.0) * 0.019
				var z := 0.08 + ridge + sin(v * 9.0 + x) * 0.018
				curtain.set_uv(Vector2(u * 3.0, v * 3.0))
				curtain.add_vertex(Vector3(x, lerpf(_ice_height(x), -0.18, v), z))
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
				Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var x := lerpf(-1.52, 1.52, float(column + corner.x) / COLUMNS)
			cap.set_uv(Vector2(x, corner.y))
			cap.add_vertex(Vector3(x, _ice_height(x) + 0.015 - corner.y * 0.08,
					lerpf(-0.16, 0.14, float(corner.y))))
	curtain.generate_normals()
	curtain.generate_tangents()
	cap.generate_normals()
	_piece(parent, "FrozenCurtain", curtain.commit(), Vector3.ZERO, ice)
	_piece(parent, "SnowLip", cap.commit(), Vector3.ZERO, snow)
	for k in 11:
		var x := -1.3 + k * 0.26
		var length := 0.18 + 0.30 * (0.5 + 0.5 * sin(k * 2.7))
		var icicle := CylinderMesh.new()
		icicle.top_radius = 0.036
		icicle.bottom_radius = 0.005
		icicle.height = length
		icicle.radial_segments = 10
		_piece(parent, "Icicle", icicle, Vector3(x, _ice_height(x) - length / 2.0, 0.125), ice)
		_rock(parent, Vector3(x, -0.03, 0.0), Vector3(0.32, 0.15, 0.30), snow)


static func _ice_height(x: float) -> float:
	return 2.20 + 0.55 * cos(x * 0.8) + 0.10 * sin(x * 3.7)


func _rock(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	# Pequenas irregularidades tiram a aparência de esferas empilhadas, sem
	# sair do volume reservado. A textura triplanar continua na escala real.
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var p := vertices[i]
		vertices[i] *= 0.90 + 0.10 * sin(p.x * 17.0 + p.y * 11.0 + p.z * 23.0)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var irregular := ArrayMesh.new()
	irregular.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var rock := _piece(parent, "Stone", irregular, center, material)
	rock.scale = size


func _piece(parent: Node3D, node_name: String, mesh: Mesh, center: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	instance.visibility_range_end = 140.0
	parent.add_child(instance)
	return instance


## A fogueira participa do mesmo contrato dos lampiões, inclusive quando o
## mundo atualiza todo o grupo city_night depois de reconstruir o terreno.
class Campfire extends Node3D:
	var light: OmniLight3D
	var embers: StandardMaterial3D
	var flames: Node3D

	func set_night(night: float) -> void:
		var on := smoothstep(0.3, 0.8, night)
		light.light_energy = 2.8 * on
		light.visible = on > 0.01
		embers.emission_energy_multiplier = 3.0 * on
		flames.visible = on > 0.01

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
