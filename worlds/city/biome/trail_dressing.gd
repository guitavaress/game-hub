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
const STOP_LENGTHS: Array[float] = [3.4, 2.8, 3.2, 2.0]
## A fogueira e a queda congelada (polimento da 17.7) passam da cerca: ficam
## no lado de fora, onde não se pisa, e se veem de perto. Em coordenadas da
## parada (x ao longo da trilha, z positivo para o caminho; z = 0 é o meio da
## margem, a 1,75 m do meio da trilha), a área que cada uma ocupa lá fora.
const OUTER_AREAS: Dictionary = {
	"campfire": Rect2(-1.9, -3.5, 3.8, 3.1),
	"frozen_fall": Rect2(-2.3, -4.3, 4.6, 3.9),
}
## Nenhuma peça de fora chega mais longe que isto do meio da trilha.
const OUTER_REACH: float = 6.6
## A fogueira: o meio dela (z da parada, ~3,35 m do meio da trilha) e o
## terraço de pedra que nivela o chão em volta (raio).
const CAMP_CENTER_Z: float = -1.6
const PAD_RADIUS: float = 1.7
## Bancos em volta do fogo: a distância do meio e o comprimento.
const CAMP_BENCH_RADIUS: float = 1.15
const CAMP_BENCH_LENGTH: float = 1.25
## A queda congelada: o pé (no chão, junto da cerca) e a frente do rochedo.
const FALL_FOOT_Z: float = -0.45
const FALL_LIP_Z: float = -1.8
## O barranco que a queda pede: o chão sobe isto na frente do rochedo.
const FALL_BANK_RISE: float = 1.6
## Quantas colunas de gelo descem (finas e grossas, longas e curtas).
const FALL_COLUMNS: int = 13


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
		var kind := STOP_KINDS[k]
		var found: Dictionary = {}
		# Primeiro um lugar do jeito que a parada pede (o barranco, o chão
		# suave); sem ele, qualquer lugar com o lado de fora livre.
		for picky: bool in [true, false]:
			for offset in range(0, 25):
				for direction: int in [1, -1]:
					var index := wanted + offset * direction
					for side: float in [1.0, -1.0]:
						var spot := _content_spot(field, trail, index, side, size)
						if spot.is_empty() or not _away_from_lamps(spot, lamps):
							continue
						spot["kind"] = kind
						if not _outside_clear(field, trail, spot):
							continue
						if picky and not _suits(field, spot):
							continue
						found = spot
						break
					if not found.is_empty():
						break
				if not found.is_empty():
					break
			if not found.is_empty():
				break
		if not found.is_empty():
			result.append(found)
	return result


## Os pontos (x e z do mundo) da área de fora de uma parada; vazio se ela
## fica toda na margem.
static func outer_points(spot: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not OUTER_AREAS.has(spot.get("kind", "")):
		return points
	var area: Rect2 = OUTER_AREAS[spot["kind"]]
	var transform: Transform3D = spot["transform"]
	var columns := ceili(area.size.x / 0.4)
	var rows := ceili(area.size.y / 0.4)
	for i in columns + 1:
		for j in rows + 1:
			var local := area.position + area.size * Vector2(float(i) / columns, float(j) / rows)
			var p := transform * Vector3(local.x, 0.0, local.y)
			points.append(Vector2(p.x, p.z))
	return points


## O lado de fora não encosta em outra perna da trilha nem no mirante.
static func _outside_clear(field: Heightfield, trail: MountainTrail, spot: Dictionary) -> bool:
	for p in outer_points(spot):
		var distance := trail.closest(p).x
		if distance < WALL_OFFSET + CONTENT_MARGIN or distance > OUTER_REACH:
			return false
		if p.distance_to(trail.lookout_center) < field.lookout_radius + 3.0:
			return false
	return true


## A fogueira quer um chão que desça pouco (o terraço nivela até ~1,4 m); a
## queda congelada quer um barranco que suba atrás dela.
static func _suits(field: Heightfield, spot: Dictionary) -> bool:
	match String(spot["kind"]):
		"campfire":
			var far := rise_at(field, spot, Vector2(0.0, CAMP_CENTER_Z - PAD_RADIUS))
			var sides := absf(rise_at(field, spot, Vector2(PAD_RADIUS, CAMP_CENTER_Z))
					- rise_at(field, spot, Vector2(-PAD_RADIUS, CAMP_CENTER_Z)))
			return far > -1.4 and far < 0.3 and sides < 0.9
		"frozen_fall":
			return rise_at(field, spot, Vector2(0.0, FALL_LIP_Z)) > FALL_BANK_RISE
	return true


## Quanto o chão sobe (ou desce) num ponto da parada (x, z locais), contado
## da altura da parada.
static func rise_at(field: Heightfield, spot: Dictionary, local: Vector2) -> float:
	var transform: Transform3D = spot["transform"]
	var p := transform * Vector3(local.x, 0.0, local.y)
	return field.surface_at(Vector2(p.x, p.z)) - transform.origin.y


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

## As quatro paradas. O monte de pedras e o banco ficam na margem (a faixa
## de 0,5 m entre a trilha e a cerca); a fogueira e a queda congelada passam
## da cerca, para terem tamanho sem estreitar o caminho.
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
				_add_camp(stop, field, spot, HomeMaterials.wood(Color("44382E"), false, 0.9))
			"cairn":
				_add_bench(stop, -0.7, 1.2, wood, stone)
				_add_cairn(stop, Vector3(0.82, 0.0, 0.0))
			"frozen_fall":
				_add_frozen_fall(stop, field, spot)
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


## A fogueira do caminho, logo depois da cerca: um terraço de pedra seca
## nivela o chão da encosta, e em cima dele ficam o fogo e três bancos em
## volta, abertos para a trilha (quem passa vê o fogo de frente).
func _add_camp(stop: Node3D, field: Heightfield, spot: Dictionary, wood: Material) -> void:
	var batch := TrailProps.Batch.new()
	var center := Vector2(0.0, CAMP_CENTER_Z)
	# O chão do terraço: a altura do chão na borda de perto (junto da cerca).
	var top := 0.0
	for x: float in [-1.0, 0.0, 1.0]:
		top += rise_at(field, spot, Vector2(x, center.y + PAD_RADIUS * 0.85)) / 3.0
	top += 0.05
	var lowest := top
	for k in 24:
		var p := center + Heightfield.direction_of(TAU * k / 24.0) * PAD_RADIUS
		lowest = minf(lowest, rise_at(field, spot, p))
	# O corpo do terraço (pedra) e a neve batida em cima.
	var rough_stone := CityDecor.pbr_material("Rock058", 1.1, Color("7E8892"))
	var body_height := top - lowest + 0.5
	batch.add(TrailProps.cylinder(PAD_RADIUS + 0.08, PAD_RADIUS, body_height, 28),
			Transform3D(Basis.IDENTITY, Vector3(center.x, top - 0.03 - body_height / 2.0, center.y)), rough_stone)
	var snow := CityDecor.pbr_material("Snow010A", 0.6, Color("ADB8C3"))
	batch.add(TrailProps.cylinder(PAD_RADIUS - 0.04, PAD_RADIUS - 0.1, 0.06, 28),
			Transform3D(Basis.IDENTITY, Vector3(center.x, top - 0.03, center.y)), snow)
	# A mureta de pedra seca: pedras grandes onde o chão desce, pequenas onde
	# ele quase encosta; nenhuma do lado da trilha (o caminho fica livre).
	for k in 20:
		var angle := TAU * k / 20.0
		var direction := Heightfield.direction_of(angle)
		if direction.y > 0.55:
			# O lado de perto, junto da cerca: um meio-fio baixo, por dentro da borda.
			var curb := center + direction * (PAD_RADIUS - 0.18)
			batch.add(TrailProps.rock(Vector3(0.42, 0.2, 0.26), 90 + k, 0.5),
					Transform3D(Basis(Vector3.UP, -angle + PI / 2.0), Vector3(curb.x, top - 0.02, curb.y)), rough_stone)
			continue
		var p := center + direction * (PAD_RADIUS + 0.05)
		var drop := top - rise_at(field, spot, p)
		var bottom := top - drop - 0.25 if drop > 0.12 else top - 0.12
		var height := drop + 0.45 if drop > 0.12 else 0.3
		var size := Vector3(0.62 + 0.12 * sin(k * 2.7), height / 0.82, 0.5)
		batch.add(TrailProps.rock(size, 90 + k, 0.6),
				Transform3D(Basis(Vector3.UP, -angle + PI / 2.0), Vector3(p.x, bottom + 0.32 * size.y, p.y)), rough_stone)
	# Três bancos em volta do fogo (o lado da trilha fica aberto).
	for angle: float in [-PI / 2.0, PI * 0.12, PI * 0.88]:
		var direction := Heightfield.direction_of(angle)
		var place := center + direction * CAMP_BENCH_RADIUS
		# O banco olha para o fogo: o encosto fica do lado de fora.
		var basis := Basis.looking_at(Vector3(direction.x, 0.0, direction.y))
		_bench_into(batch, Transform3D(basis, Vector3(place.x, top - 0.03, place.y)),
				CAMP_BENCH_LENGTH, wood)
	batch.build(stop, "Camp", 140.0)
	_campfire = Campfire.new()
	_campfire.position = Vector3(center.x, top - 0.03, center.y)
	stop.add_child(_campfire)
	_campfire.build(rough_stone, HomeMaterials.wood(Color("3F2C20"), false, 0.9),
			LAMP_FADE_BEGIN, LAMP_FADE_LENGTH)


## O monte de pedras: lajes chatas empilhadas, cada uma menor e um pouco
## torta, como as que os caminhantes deixam. Cabe na margem (fundura).
func _add_cairn(stop: Node3D, at: Vector3) -> void:
	var batch := TrailProps.Batch.new()
	var stone := CityDecor.pbr_material("Rock058", 0.6, Color("A3ABB2"))
	var y := at.y - 0.04
	for level in 8:
		var share := float(level) / 7.0
		var width := lerpf(0.66, 0.17, share)
		var height := lerpf(0.16, 0.11, share)
		var size := Vector3(width, height / 0.82, minf(CONTENT_DEPTH - 0.02, width * 0.85))
		var place := at + Vector3(0.03 * sin(level * 2.3), y + 0.32 * size.y, 0.015 * cos(level * 1.7))
		batch.add(TrailProps.rock(size, 200 + level, 0.3),
				Transform3D(Basis(Vector3.UP, 0.12 * sin(level * 3.1)) * Basis(Vector3.BACK, 0.05 * sin(level * 1.9)), place), stone)
		y += height * 0.92
	batch.build(stop, "Cairn", 140.0)


## Um banco de tábuas com encosto, de pernas de madeira, no chão do lugar
## dado; o assento olha para +Z do lugar e o encosto fica no -Z.
static func _bench_into(batch: TrailProps.Batch, place: Transform3D, length: float, wood: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * (length / 2.0 - 0.16)
		batch.add(TrailProps.box(Vector3(0.1, 0.46, 0.34)), place * Transform3D(Basis.IDENTITY, Vector3(x, 0.21, 0.0)), wood)
		batch.add(TrailProps.box(Vector3(0.08, 0.5, 0.07)), place * Transform3D(Basis.IDENTITY, Vector3(x, 0.66, -0.16)), wood)
	for z: float in [-0.09, 0.09]:
		batch.add(TrailProps.box(Vector3(length, 0.06, 0.16)), place * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.46, z)), wood)
	for y: float in [0.68, 0.86]:
		batch.add(TrailProps.box(Vector3(length, 0.12, 0.04)),
				place * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0.0, y, -0.19)), wood)


## A queda d'água congelada, encostada no barranco do lado de fora: um
## rochedo atrás (a borda de onde o gelo cai), colunas de gelo grossas que
## descem pela encosta e se alargam embaixo, pingentes na borda e um pé de
## gelo e neve acumulado no chão, junto da cerca.
func _add_frozen_fall(stop: Node3D, field: Heightfield, spot: Dictionary) -> void:
	var batch := TrailProps.Batch.new()
	var ice := _ice_material()
	var snow := CityDecor.pbr_material("Snow010A", 0.6, Color("C0CCD6"))
	var rock := CityDecor.pbr_material("Rock058", 1.6, Color("7A858F"))
	var foot := rise_at(field, spot, Vector2(0.0, FALL_FOOT_Z))
	var bank := rise_at(field, spot, Vector2(0.0, FALL_LIP_Z))
	# A borda do gelo: acima do barranco e alta o bastante para ser uma queda.
	var lip := maxf(bank + 1.4, foot + 3.0)
	# O rochedo: um bloco no meio, dois dos lados e um mais alto atrás.
	# [x, z, largura, fundura, topo acima da borda]
	var boulders: Array[Array] = [[0.0, FALL_LIP_Z - 0.8, 2.4, 1.7, 0.35],
			[-1.75, FALL_LIP_Z - 0.35, 1.4, 1.3, 0.05], [1.6, FALL_LIP_Z - 0.65, 1.6, 1.4, 0.0],
			[0.5, FALL_LIP_Z - 1.7, 2.5, 1.6, 1.1]]
	for k in boulders.size():
		var b: Array = boulders[k]
		var ground := rise_at(field, spot, Vector2(b[0], b[1]))
		var bottom := minf(ground, foot) - 0.6
		var height: float = lip + float(b[4]) - bottom
		var size := Vector3(b[2], height / 0.82, b[3])
		batch.add(TrailProps.rock(size, 120 + k, 0.55),
				Transform3D(Basis(Vector3.UP, 0.25 * sin(k * 2.1)), Vector3(b[0], bottom + 0.32 * size.y, b[1])), rock)
	# A laje da borda, por cima do rochedo e um pouco para a frente: o gelo
	# nasce embaixo dela.
	batch.add(TrailProps.rock(Vector3(3.3, 0.75, 1.4), 128, 0.5),
			Transform3D(Basis(Vector3.UP, 0.08), Vector3(0.1, lip + 0.12, FALL_LIP_Z - 0.35)), rock)
	# As colunas de gelo: caem da borda e seguem a encosta até o pé.
	var ice_surface := SurfaceTool.new()
	ice_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in FALL_COLUMNS:
		var x := -1.25 + k * 2.5 / (FALL_COLUMNS - 1) + 0.06 * sin(k * 4.1)
		# As mais curtas param no meio da encosta, afinando como um pingente.
		var reach := 1.0 if k % 3 != 1 else 0.6 + 0.25 * (0.5 + 0.5 * sin(k * 1.3))
		_ice_column(ice_surface, field, spot, x, lip - 0.05 - 0.2 * absf(x), foot, k, reach)
	ice_surface.index()
	ice_surface.generate_tangents()
	batch.add(ice_surface.commit(), Transform3D.IDENTITY, ice)
	# Pingentes na borda do rochedo, dos lados da queda.
	for k in 10:
		var x := -1.85 + k * 0.41
		if absf(x) < 1.0 and k % 3 != 0:
			continue
		var length := 0.35 + 0.6 * (0.5 + 0.5 * sin(k * 2.7))
		var top := lip - 0.02
		batch.add(TrailProps.cylinder(0.006, 0.05, length, 8),
				Transform3D(Basis.IDENTITY, Vector3(x, top - length / 2.0, FALL_LIP_Z + 0.22)), ice)
	# O pé: gelo acumulado e neve em volta, no chão junto da cerca.
	for k in 3:
		var x := -0.75 + k * 0.75
		var ground := rise_at(field, spot, Vector2(x, FALL_FOOT_Z - 0.2))
		batch.add(TrailProps.rock(Vector3(1.5, 0.72, 1.15), 140 + k, 0.3),
				Transform3D(Basis(Vector3.UP, 0.3 * sin(k * 2.0)), Vector3(x, ground - 0.12, FALL_FOOT_Z - 0.2)), ice)
	for x: float in [-1.75, 1.75]:
		var ground := rise_at(field, spot, Vector2(x, FALL_FOOT_Z - 0.4))
		batch.add(TrailProps.rock(Vector3(1.3, 0.34, 1.0), 150 + int(x), 0.25),
				Transform3D(Basis.IDENTITY, Vector3(x, ground - 0.12, FALL_FOOT_Z - 0.45)), snow)
	batch.build(stop, "Fall", 140.0)


## Uma coluna de gelo: um tubo irregular que cai quase reto da borda e depois
## escorre pela encosta, mais grosso embaixo (o gelo se acumula).
func _ice_column(surface: SurfaceTool, field: Heightfield, spot: Dictionary, x: float, top: float,
		foot: float, seed: int, reach: float) -> void:
	const RINGS: int = 18
	const SEGMENTS: int = 10
	var base := 0.07 + 0.09 * (0.5 + 0.5 * sin(seed * 2.6 + 1.0))
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	for i in RINGS:
		var t := float(i) / (RINGS - 1) * reach
		var radius := base * (0.6 + 1.1 * t) * (1.0 + 0.2 * sin(t * (13.0 + seed) + seed * 2.3))
		if reach < 1.0:
			radius *= maxf(1.0 - smoothstep(reach - 0.25, reach, t), 0.04)
		else:
			radius *= 1.0 - 0.5 * smoothstep(0.88, 1.0, t)  # a ponta some dentro do pé
		var z := lerpf(FALL_LIP_Z + 0.25, FALL_FOOT_Z - 0.3, smoothstep(0.15, 1.0, t))
		var ground := rise_at(field, spot, Vector2(x, z))
		var y := maxf(lerpf(top, foot + 0.1, t), ground + radius * 0.55)
		centers.append(Vector3(x + 0.04 * sin(t * 6.0 + seed), y, z))
		radii.append(radius)
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for i in RINGS:
		var tangent := (centers[mini(i + 1, RINGS - 1)] - centers[maxi(i - 1, 0)]).normalized()
		var up := tangent.cross(Vector3.RIGHT).normalized()
		var side := up.cross(tangent).normalized()
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for s in SEGMENTS:
			var a := TAU * s / SEGMENTS
			var n := (side * cos(a) + up * sin(a)).normalized()
			ring.append(centers[i] + n * radii[i])
			ring_normals.append(n)
		rings.append(ring)
		normals.append(ring_normals)
	for i in RINGS - 1:
		for s in SEGMENTS:
			var s2 := (s + 1) % SEGMENTS
			# A Godot desenha a frente no sentido horário.
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0),
					Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var ring_index := i + corner.y
				var segment := s if corner.x == 0 else s2
				surface.set_normal(normals[ring_index][segment])
				surface.set_uv(Vector2(float(s + corner.x) / SEGMENTS, float(ring_index) / RINGS))
				surface.add_vertex(rings[ring_index][segment])


## O gelo: claro, liso e brilhante, com um relevo fino de geada (a normal da
## neve) e uma borda que acende contra a luz. Opaco: sem ordenar transparência.
static var _ice: StandardMaterial3D

static func _ice_material() -> StandardMaterial3D:
	if _ice == null:
		_ice = StandardMaterial3D.new()
		_ice.albedo_color = Color("9DC3D8")
		_ice.roughness = 0.14
		_ice.metallic_specular = 0.8
		_ice.clearcoat_enabled = true
		_ice.clearcoat = 0.6
		_ice.clearcoat_roughness = 0.08
		_ice.normal_enabled = true
		_ice.normal_texture = CityDecor.pbr_textures("Snow010A")["normal"]
		_ice.normal_scale = 0.5
		_ice.uv1_triplanar = true
		_ice.uv1_scale = Vector3.ONE / 1.4
		_ice.rim_enabled = true
		_ice.rim = 0.35
		_ice.rim_tint = 0.75
	return _ice


func _piece(parent: Node3D, node_name: String, mesh: Mesh, center: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	instance.visibility_range_end = 140.0
	parent.add_child(instance)
	return instance


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
