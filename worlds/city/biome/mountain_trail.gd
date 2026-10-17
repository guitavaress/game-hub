class_name MountainTrail
extends RefCounted
## O traçado da trilha da montanha (Fase 15.8): só contas, nenhum nó.
##
## A trilha sai do lado de fora da borda da cidade, vai reta por uns 20 m e
## depois sobe em zigue-zague (curvas suavizadas pelo método de Chaikin) até
## um mirante plano. Ela fica sempre dentro da cunha do bairro, com rampa de
## no máximo "max_grade", e termina exatamente na altura do mirante.
##
## Vista de cima (a cidade embaixo, a montanha em cima):
##
##          ( mirante )
##         /
##     ---´  <- curvas
##     `-----.
##      .---´
##      |   <- reta
##   ===|===  mureta (o vão fica aqui)
##
## Uma trilha a 15% numa encosta de 45° ficaria num cânion. Por isso a trilha
## também molda a montanha: a faixa do zigue-zague vira uma RAMPA, um plano
## inclinado que sobe com a distância da borda na mesma medida da trilha.
## Cada trecho atravessa a rampa na diagonal, rente ao chão. Dos lados e atrás
## do mirante, a montanha volta a subir (ramp_at diz quanto e até onde).
##
## Os pontos são Vector2(x, z) do mundo, de 1 em 1 m, cada um com a sua altura.

## Comprimento da reta do começo.
const STRAIGHT_METERS: float = 24.0
## Os primeiros metros (o vão da mureta e a faixa plana) ficam em y = 0.
const FLAT_METERS: float = 8.0
## Metade do comprimento de um trecho do zigue-zague (no máximo).
const LEG_HALF_MAX: float = 45.0
## Quanto a trilha avança montanha acima a cada trecho: no mínimo a trilha,
## os dois acostamentos e um pouco de chão no meio; no máximo, uma rampa suave.
const LEG_SPACING_EXTRA: float = 2.0
const LEG_SPACING_MAX: float = 30.0
## O zigue-zague usa esta parte do caminho até o raio de fora: o mirante fica
## no meio da subida, com o pico da montanha atrás dele.
const RUN_SHARE: float = 0.55
## A trilha sobe, de preferência, esta parte da rampa máxima (folga para quem anda).
const TARGET_GRADE_SHARE: float = 0.8
const MAX_LEGS: int = 40
const CHAIKIN_ITERATIONS: int = 3
const SAMPLE_METERS: float = 1.0
## Tamanho dos baldes da busca do ponto mais perto da trilha.
const BUCKET_METERS: float = 8.0
## A rampa vai além da trilha esta folga e volta à montanha nestas faixas.
const RAMP_PAD: float = 5.0
const RAMP_SIDE_BLEND: float = 24.0
const RAMP_BACK_BLEND: float = 30.0

## Os pontos da trilha (de 1 em 1 m) e a altura de cada um.
var points: PackedVector2Array = PackedVector2Array()
var heights: PackedFloat64Array = PackedFloat64Array()
## Onde a trilha começa (na borda) e para onde ela sai da cidade.
var start: Vector2 = Vector2.ZERO
var outward: Vector2 = Vector2.UP
var lookout_center: Vector2 = Vector2.ZERO
var lookout_radius: float = 0.0
## Falso quando a trilha não coube (a cidade fica sem montanha).
var valid: bool = false

## Distância de cada ponto até a borda, medida na direção "outward" (só cresce).
var _along: PackedFloat64Array = PackedFloat64Array()
## A faixa da rampa: de lado (_band_low a _band_high) e até onde vai (_band_top).
var _band_low: float = 0.0
var _band_high: float = 0.0
var _band_top: float = 0.0
var _buckets: Dictionary = {}


## A célula de borda mais perto da bissetriz (o meio da cunha).
static func border_cell_nearest(cells: Array[Vector2i], bisector: float) -> Vector2i:
	var best := cells[0]
	var best_offset := INF
	for cell in cells:
		var offset := absf(wrapf(Heightfield.angle_of(Vector2(cell)) - bisector, -PI, PI))
		if offset < best_offset - 0.0001:
			best = cell
			best_offset = offset
	return best


## Traça a trilha saindo do meio do lado de fora da célula de borda "cell".
## Numa célula de canto (dois lados para fora), usa o lado mais virado para a bissetriz.
static func plan_from_cell(field: Heightfield, cell: Vector2i) -> MountainTrail:
	var bisector_dir := Heightfield.direction_of(field.wedge_center)
	var sides: Array[Vector2] = []
	var ring := maxi(absi(cell.x), absi(cell.y))
	if absi(cell.x) == ring:
		sides.append(Vector2(signf(cell.x), 0.0))
	if absi(cell.y) == ring:
		sides.append(Vector2(0.0, signf(cell.y)))
	var out_dir := sides[0]
	for side in sides:
		if side.dot(bisector_dir) > out_dir.dot(bisector_dir):
			out_dir = side
	# O ponto da borda (a mureta) na frente da célula.
	var from := Vector2(cell) * CityLayout.BLOCK_PITCH
	if out_dir.x != 0.0:
		from.x = out_dir.x * field.half
	else:
		from.y = out_dir.y * field.half
	return plan(field, from, out_dir)


## Traça a trilha a partir de "from" (na borda da cidade), saindo na direção
## "out_dir". Devolve uma trilha com valid = false se ela não couber na cunha.
static func plan(field: Heightfield, from: Vector2, out_dir: Vector2) -> MountainTrail:
	var trail := MountainTrail.new()
	trail.start = from
	trail.outward = out_dir.normalized()
	trail.lookout_radius = field.lookout_radius
	var forward := trail.outward
	var lateral := Vector2(-forward.y, forward.x)
	var margin := field.trail_width / 2.0 + Heightfield.SHOULDER + 1.0
	var max_radius := field.outer_radius - field.lookout_radius - Heightfield.SHOULDER - 2.0
	var target_grade := field.max_grade * TARGET_GRADE_SHARE
	var min_spacing := field.trail_width + 2.0 * Heightfield.SHOULDER + LEG_SPACING_EXTRA

	# Quanto cabe montanha acima (até o raio de fora, menos o mirante) e de
	# lado (até a beirada da cunha, no meio do caminho).
	var to_edge := from.dot(forward)
	var room := -to_edge + sqrt(maxf(to_edge * to_edge - from.length_squared() + max_radius * max_radius, 0.0))
	var budget := room * RUN_SHARE - STRAIGHT_METERS - 2.0 * field.lookout_radius
	var middle := STRAIGHT_METERS + budget / 2.0
	var leg_half := minf(_room_to_side(field, from, forward, lateral, middle, 1.0, margin),
			_room_to_side(field, from, forward, lateral, middle, -1.0, margin))
	leg_half = clampf(leg_half, 1.0, LEG_HALF_MAX)
	var needed := field.lookout_height / target_grade + FLAT_METERS
	var legs_guess := maxi(1, ceili((needed * 1.15 - STRAIGHT_METERS) / (2.0 * leg_half)))
	var spacing := clampf(budget / legs_guess, min_spacing, LEG_SPACING_MAX)

	# Os pontos-chave: o começo, a reta e a ponta de cada trecho do zigue-zague.
	var keys := PackedVector2Array([from, from + forward * 4.0, from + forward * STRAIGHT_METERS])
	var along := STRAIGHT_METERS
	var side := 1.0 if _bisector_lateral(field, from, forward, lateral, along) >= 0.0 else -1.0
	for leg in MAX_LEGS:
		along += spacing
		var end := _leg_end(field, from, forward, lateral, along, side, leg_half, margin)
		if end.length() > max_radius or field.edge_distance(end) < margin:
			# Não cabe mais um trecho: aceita a trilha até aqui, se a rampa
			# ficar dentro do máximo.
			trail._finish(field, keys, field.max_grade)
			return trail
		keys.append(end)
		side = -side
		# Já dá para subir até o mirante sem passar da rampa desejada?
		if trail._finish(field, keys, target_grade):
			return trail
	return trail


## Comprimento da trilha, em metros.
func length() -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


## O ponto da trilha mais perto de "p": x = a distância, y = a altura da trilha
## ali. Longe da trilha (fora do alcance do acostamento), x = INF.
func closest(p: Vector2) -> Vector2:
	var key := Vector2i(floori(p.x / BUCKET_METERS), floori(p.y / BUCKET_METERS))
	if not _buckets.has(key):
		return Vector2(INF, 0.0)
	var best := Vector2(INF, 0.0)
	for i: int in _buckets[key]:
		var a := points[i]
		var b := points[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		var distance := p.distance_to(a + ab * t)
		if distance < best.x:
			best = Vector2(distance, lerpf(heights[i], heights[i + 1], t))
	return best


## A rampa: x = quanto ela manda neste ponto (0 a 1), y = a altura dela, que
## é a altura da trilha na mesma distância da borda.
func ramp_at(p: Vector2) -> Vector2:
	var local := p - start
	var forward := local.dot(outward)
	var side := local.dot(Vector2(-outward.y, outward.x))
	var outside := maxf(_band_low - side, side - _band_high)
	var weight := 1.0 - smoothstep(0.0, RAMP_SIDE_BLEND, outside)
	weight *= 1.0 - smoothstep(0.0, RAMP_BACK_BLEND, forward - _band_top)
	weight *= smoothstep(-RAMP_BACK_BLEND, 0.0, forward)
	if weight <= 0.0:
		return Vector2.ZERO
	return Vector2(weight, height_along(forward))


## A altura da trilha a "forward" metros da borda (0 antes, a do mirante depois).
func height_along(forward: float) -> float:
	var count := _along.size()
	if count == 0 or forward <= _along[0]:
		return 0.0
	if forward >= _along[count - 1]:
		return heights[count - 1]
	var i := _along.bsearch(forward)
	var t := (forward - _along[i - 1]) / maxf(_along[i] - _along[i - 1], 0.000001)
	return lerpf(heights[i - 1], heights[i], t)


## Um retângulo que cobre a trilha e o mirante (com o acostamento).
func bounds() -> Rect2:
	var rect := Rect2(lookout_center, Vector2.ZERO).grow(lookout_radius)
	for p in points:
		rect = rect.expand(p)
	return rect.grow(Heightfield.SHOULDER + 1.0)


## Põe o mirante, suaviza as curvas e calcula as alturas, subindo no máximo
## "grade". Falso se não couber ou se o caminho ainda for curto demais.
func _finish(field: Heightfield, keys: PackedVector2Array, grade: float) -> bool:
	if keys.size() < 4:
		return false
	# O mirante: na frente da ponta da trilha (montanha acima) ou, se não
	# couber, seguindo o último trecho.
	var finish := keys[keys.size() - 1]
	var candidates: Array[Vector2] = [outward, (finish - keys[keys.size() - 2]).normalized()]
	var found := false
	for direction in candidates:
		var center := finish + direction * field.lookout_radius
		if field.edge_distance(center) >= field.lookout_radius + Heightfield.SHOULDER \
				and center.length() + field.lookout_radius + Heightfield.SHOULDER < field.outer_radius:
			lookout_center = center
			found = true
			break
	if not found:
		return false

	# Curvas suaves e pontos de 1 em 1 m.
	var line := _resample(_chaikin(keys, CHAIKIN_ITERATIONS), SAMPLE_METERS)
	var count := line.size()
	var total := 0.0
	var distances := PackedFloat64Array([0.0])
	for i in range(1, count):
		total += line[i].distance_to(line[i - 1])
		distances.append(total)
	if (total - FLAT_METERS) * grade < field.lookout_height:
		return false

	# As alturas: plano no começo e depois uma subida constante até o mirante.
	var climb := field.lookout_height / (total - FLAT_METERS)
	points = line
	heights.resize(count)
	_along.resize(count)
	var lateral := Vector2(-outward.y, outward.x)
	_band_low = INF
	_band_high = -INF
	for i in count:
		heights[i] = maxf(0.0, distances[i] - FLAT_METERS) * climb
		_along[i] = (points[i] - start).dot(outward)
		var side := (points[i] - start).dot(lateral)
		_band_low = minf(_band_low, side)
		_band_high = maxf(_band_high, side)
	heights[count - 1] = field.lookout_height
	var lookout_side := (lookout_center - start).dot(lateral)
	_band_low = minf(_band_low, lookout_side - field.lookout_radius) - RAMP_PAD
	_band_high = maxf(_band_high, lookout_side + field.lookout_radius) + RAMP_PAD
	_band_top = (lookout_center - start).dot(outward) + field.lookout_radius + RAMP_PAD

	_build_buckets(field.trail_width / 2.0 + Heightfield.SHOULDER)
	valid = true
	return true


func _build_buckets(reach: float) -> void:
	_buckets.clear()
	for i in points.size() - 1:
		var box := Rect2(points[i], Vector2.ZERO).expand(points[i + 1]).grow(reach)
		var from := Vector2i(floori(box.position.x / BUCKET_METERS), floori(box.position.y / BUCKET_METERS))
		var to := Vector2i(floori(box.end.x / BUCKET_METERS), floori(box.end.y / BUCKET_METERS))
		for bx in range(from.x, to.x + 1):
			for bz in range(from.y, to.y + 1):
				var key := Vector2i(bx, bz)
				if not _buckets.has(key):
					_buckets[key] = PackedInt32Array()
				_buckets[key].append(i)


## A ponta de um trecho: a "along" metros da borda, indo para o lado "side" até
## "leg_half" da bissetriz ou até a beirada da cunha (menos a margem).
static func _leg_end(field: Heightfield, from: Vector2, forward: Vector2, lateral: Vector2,
		along: float, side: float, leg_half: float, margin: float) -> Vector2:
	var center := _bisector_lateral(field, from, forward, lateral, along)
	var reach := minf(leg_half, _room_to_side(field, from, forward, lateral, along, side, margin))
	return from + forward * along + lateral * (center + side * reach)


## Quantos metros cabem para o lado "side", a partir da bissetriz, antes da
## beirada da cunha (menos a margem).
static func _room_to_side(field: Heightfield, from: Vector2, forward: Vector2, lateral: Vector2,
		along: float, side: float, margin: float) -> float:
	var center := _bisector_lateral(field, from, forward, lateral, along)
	var reach := 0.0
	while reach < LEG_HALF_MAX:
		var p := from + forward * along + lateral * (center + side * (reach + 1.0))
		if field.edge_distance(p) < margin:
			break
		reach += 1.0
	return reach


## Onde a bissetriz da cunha cruza a linha a "along" metros da borda, medido
## de lado a partir da reta do começo.
static func _bisector_lateral(field: Heightfield, from: Vector2, forward: Vector2, lateral: Vector2,
		along: float) -> float:
	var bisector := Heightfield.direction_of(field.wedge_center)
	var facing := bisector.dot(forward)
	if facing < 0.2:
		return 0.0
	var distance := (along + from.dot(forward)) / facing
	return (bisector * distance - from).dot(lateral)


## Chaikin: corta cada canto em 1/4 e 3/4, deixando o primeiro e o último ponto no lugar.
static func _chaikin(source: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var result := source
	for iteration in iterations:
		var smooth := PackedVector2Array([result[0]])
		var last := result.size() - 1
		for i in last:
			var a := result[i]
			var b := result[i + 1]
			if i > 0:
				smooth.append(a.lerp(b, 0.25))
			if i < last - 1:
				smooth.append(a.lerp(b, 0.75))
		smooth.append(result[last])
		result = smooth
	return result


## Pontos de "spacing" em "spacing" metros ao longo da linha (o último é o fim).
static func _resample(line: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var result := PackedVector2Array([line[0]])
	var carried := 0.0
	for i in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		var segment := a.distance_to(b)
		var at := spacing - carried
		while at <= segment:
			result.append(a.lerp(b, at / segment))
			at += spacing
		carried = segment - (at - spacing)
	if result[result.size() - 1].distance_to(line[line.size() - 1]) > 0.01:
		result.append(line[line.size() - 1])
	else:
		result[result.size() - 1] = line[line.size() - 1]
	return result
