class_name CityRouteGuide
extends Node3D
## Faixa de luz no chão até a porta de um jogo (busca com Tab).
##
## A rota segue as RUAS da grade (CityLayout): do jogador até a rua mais
## perto, pelas ruas até a rua da porta, e dali até a porta. No caminho, uma
## mancha de luz de 1 x 2 m a cada 2 m, na cor do bairro, projetada no chão
## (Decal). As manchas acendem em onda, a partir do jogador. A faixa some
## quando o jogador chega na porta ou depois de 60 s.
##
## A busca não conhece a cidade: ela chama show_route() em quem estiver no
## grupo "route_guide". Cada mundo pode ter o seu guia (ou nenhum).

## O destino mudou: acendeu uma faixa nova ou a faixa apagou (a bússola e os
## mapas escutam).
signal route_changed

const MARK_SIZE: Vector2 = Vector2(1.0, 2.0)
const MARK_SPACING: float = 2.0
const MARK_ENERGY: float = 2.5
## A onda de acender leva no máximo isto (s), do começo ao fim da faixa.
const WAVE_SECONDS: float = 1.0
const MARK_FADE_SECONDS: float = 0.25
const LIFETIME_SECONDS: float = 60.0
## Chegou: a faixa some quando o jogador fica a menos disto (m) da porta.
const ARRIVAL_DISTANCE: float = 3.0

var _marks: Array[Decal] = []
var _target: Vector3
var _target_color: Color = Color.WHITE
var _player: Node3D
var _started_ms: int = 0
var _mark_texture: Texture2D


func _ready() -> void:
	add_to_group("route_guide")
	_mark_texture = _make_mark_texture()
	set_process(false)


## Acende a faixa do jogador até a porta do portal. Devolve o tamanho da rota (m).
func show_route(player: Node3D, portal: GamePortal) -> float:
	clear_route()
	var color := GameCategories.get_neon_color(GameCategories.get_category_id(portal.app_id))
	var points := route_points(player.global_position, portal)
	var length := 0.0
	var along := MARK_SPACING / 2.0  # a primeira mancha fica um pouco à frente do jogador
	var total := _polyline_length(points)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var segment := a.distance_to(b)
		if segment < 0.01:
			continue
		var direction := (b - a) / segment
		while along <= length + segment:
			var mark := _add_mark(a + direction * (along - length), direction, color)
			# Onda: acende na ordem da rota.
			_fade_mark(mark, 1.0, WAVE_SECONDS * along / maxf(total, 1.0))
			along += MARK_SPACING
		length += segment
	_target = portal.global_position
	_target_color = color
	_player = player
	_started_ms = Time.get_ticks_msec()
	set_process(true)
	route_changed.emit()
	return total


## Apaga a faixa (se houver).
func clear_route() -> void:
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()
	set_process(false)
	route_changed.emit()


func has_route() -> bool:
	return not _marks.is_empty()


## A cor do bairro do destino (só vale com has_route()).
func get_target_color() -> Color:
	return _target_color


## A porta de destino da faixa acesa (só vale com has_route()).
func get_target_position() -> Vector3:
	return _target


func get_mark_count() -> int:
	return _marks.size()


func _process(_delta: float) -> void:
	var arrived := is_instance_valid(_player) \
			and Vector2(_player.global_position.x - _target.x, _player.global_position.z - _target.z).length() < ARRIVAL_DISTANCE
	var expired := (Time.get_ticks_msec() - _started_ms) / 1000.0 > LIFETIME_SECONDS
	if arrived or expired:
		_fade_out()


## Os pontos da rota pelas ruas: jogador, rua mais perto, esquinas, rua da
## porta e a porta.
static func route_points(from: Vector3, portal: GamePortal) -> PackedVector3Array:
	var door := portal.global_position
	var outward := portal.global_transform.basis.z
	outward.y = 0.0
	outward = outward.normalized()
	# A rua da porta: o meio dela fica meia rua à frente da porta.
	var approach := door + outward * (CityLayout.STREET_WIDTH / 2.0)
	var door_on_horizontal := absf(outward.z) >= absf(outward.x)  # rua "leste-oeste" (z fixo)
	if door_on_horizontal:
		approach.z = street_line(approach.z)
	else:
		approach.x = street_line(approach.x)

	# Entrada na rua mais perto do jogador.
	var line_x := street_line(from.x)
	var line_z := street_line(from.z)
	var start_on_horizontal := absf(from.z - line_z) <= absf(from.x - line_x)
	var start := Vector3(from.x, 0.0, line_z) if start_on_horizontal else Vector3(line_x, 0.0, from.z)

	var points := PackedVector3Array([Vector3(from.x, 0.0, from.z), start])
	if door_on_horizontal:
		if start_on_horizontal:
			if not is_equal_approx(start.z, approach.z):
				# Pela rua atual até uma rua "norte-sul" no meio do caminho.
				var cross_x := street_line((start.x + approach.x) / 2.0)
				points.append(Vector3(cross_x, 0.0, start.z))
				points.append(Vector3(cross_x, 0.0, approach.z))
		else:
			points.append(Vector3(start.x, 0.0, approach.z))
	else:
		if not start_on_horizontal:
			if not is_equal_approx(start.x, approach.x):
				var cross_z := street_line((start.z + approach.z) / 2.0)
				points.append(Vector3(start.x, 0.0, cross_z))
				points.append(Vector3(approach.x, 0.0, cross_z))
		else:
			points.append(Vector3(approach.x, 0.0, start.z))
	points.append(approach)
	points.append(Vector3(door.x, 0.0, door.z))
	return points


## O meio de rua mais perto de uma coordenada (as ruas ficam entre os
## quarteirões: meio passo da grade para cada lado).
static func street_line(value: float) -> float:
	var pitch := CityLayout.BLOCK_PITCH
	return (floorf(value / pitch) + 0.5) * pitch


static func _polyline_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


## Uma mancha de luz projetada no chão, comprida no sentido da rota.
func _add_mark(where: Vector3, direction: Vector3, color: Color) -> Decal:
	var mark := Decal.new()
	mark.size = Vector3(MARK_SIZE.x, 2.0, MARK_SIZE.y)
	mark.texture_albedo = _mark_texture
	mark.texture_emission = _mark_texture
	mark.emission_energy = MARK_ENERGY
	mark.modulate = Color(color, 0.0)
	mark.albedo_mix = 1.0
	mark.cull_mask = 1  # só o mundo (camada 1), não os hologramas
	add_child(mark)
	mark.global_position = Vector3(where.x, 0.5, where.z)
	mark.rotation.y = atan2(direction.x, direction.z)
	_marks.append(mark)
	return mark


func _fade_mark(mark: Decal, alpha: float, delay: float) -> void:
	var tween := mark.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(mark, "modulate:a", alpha, MARK_FADE_SECONDS)


func _fade_out() -> void:
	set_process(false)
	var marks: Array[Decal] = _marks.duplicate()
	_marks.clear()
	for mark in marks:
		if is_instance_valid(mark):
			var tween := mark.create_tween()
			tween.tween_property(mark, "modulate:a", 0.0, MARK_FADE_SECONDS * 2.0)
			tween.tween_callback(mark.queue_free)
	route_changed.emit()


## Textura da mancha: um retângulo de pontas arredondadas com borda suave.
static func _make_mark_texture() -> Texture2D:
	var image := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 32:
			# Distância até a "cápsula" (0 dentro, cresce para fora).
			var px := (x + 0.5) / 32.0 * 2.0 - 1.0
			var py := (y + 0.5) / 64.0 * 2.0 - 1.0
			var dy := maxf(absf(py) - 0.5, 0.0) * 2.0
			var distance := sqrt(px * px + dy * dy)
			var alpha := 1.0 - smoothstep(0.55, 1.0, distance)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
