class_name BiomeAtmosphere
extends Node
## Névoa e vento de um bioma, sem conhecer a cidade que o montou.
## Uma instância controla a mistura do DayNight; setup recebe zonas XZ globais.
## Quem monta inclui as zonas da trilha/mirante e põe o fundo da cidade no grupo.

const UPDATE_INTERVAL: float = 0.1
const CITY_AMBIENCE_GROUP: StringName = &"city_ambience_bed"
const CITY_DUCK_DB: float = -6.0
const SNOW_ALBEDO_MAX: float = 0.85
const WIND_STREAM: AudioStream = preload("res://assets/generated/wind_loop.wav")
const DEFAULT_WIND_DB: float = -22.0
const HIGH_WIND_BOOST_DB: float = 6.0
const DEFAULT_LOOKOUT_HEIGHT: float = 32.0
## Bruma até um quarto da subida: a cota não acompanha o jogador.
const FOG_HEIGHT_FRACTION: float = 0.25

var _spec: BiomeSpec
var _zones: Array[Rect2] = []
var _player: Node3D
var _day_night: DayNight
var _base_height: float = 0.0
var _weight: float = 0.0
var _wind_low: AudioStreamPlayer
var _wind_high: AudioStreamPlayer
var _audio_tween: Tween
var _bed_volumes: Dictionary[AudioStreamPlayer, float] = {}


## base_height é o Y global do chão do bairro (0 na cidade atual).
## Pode ser chamado antes/depois de add_child e novamente ao refazer as zonas.
func setup(spec: BiomeSpec, zones: Array[Rect2], player: Node3D,
		day_night: DayNight, base_height: float = 0.0) -> void:
	_reset_effects()
	_spec = spec
	_zones = zones.duplicate()
	_player = player
	_day_night = day_night
	_base_height = base_height
	if is_inside_tree():
		update_now()


func _ready() -> void:
	_wind_low = _make_wind("WindLow", 1.0, 0.0)
	# Tom e ponto inicial diferentes evitam duas cópias tocando em coro.
	_wind_high = _make_wind("WindHigh", 0.9, WIND_STREAM.get_length() * 0.5)
	var timer: Timer = Timer.new()
	timer.wait_time = UPDATE_INTERVAL
	timer.timeout.connect(update_now)
	add_child(timer)
	timer.start()
	update_now()


func _exit_tree() -> void:
	_reset_effects()
	_wind_low.stop()
	_wind_high.stop()


## Distância euclidiana à união dos retângulos. A borda pertence ao bioma;
## fora dela, smoothstep chega a zero sem degrau em fog_blend_meters.
static func zone_weight(position_xz: Vector2, zones: Array[Rect2], blend_meters: float) -> float:
	var distance: float = INF
	for zone: Rect2 in zones:
		var rect: Rect2 = zone.abs()
		if not rect.has_area():
			continue
		var nearest: Vector2 = position_xz.clamp(rect.position, rect.end)
		distance = minf(distance, position_xz.distance_to(nearest))
	if distance == INF:
		return 0.0
	# Mesmo um perfil com transição zero evita divisão por zero.
	return 1.0 - smoothstep(0.0, maxf(blend_meters, 0.001), distance)


func get_weight() -> float:
	return _weight


## O segundo peso só chega a 1 na cota do mirante; fora do bioma ambos zeram.
func wind_weights(position: Vector3) -> Vector2:
	if _spec == null:
		return Vector2.ZERO
	var weight: float = zone_weight(Vector2(position.x, position.z), _zones, _spec.fog_blend_meters)
	var height_weight: float = smoothstep(_base_height, _base_height + _lookout_height(), position.y)
	return Vector2(weight, weight * height_weight)


func update_now() -> void:
	if not is_inside_tree():
		return
	if _spec == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		_reset_effects()
		return
	var weights: Vector2 = wind_weights(_player.global_position)
	_weight = weights.x
	if is_instance_valid(_day_night):
		_day_night.set_fog_overlay(_weight, _spec.fog_density_scale, _spec.fog_tint,
				_spec.fog_tint_amount, _base_height + _lookout_height() * FOG_HEIGHT_FRACTION,
				_spec.fog_height_density)
	_mix_audio(weights)


func _lookout_height() -> float:
	if _spec.backdrop != null:
		return maxf(_spec.backdrop.lookout_height, 0.001)
	return DEFAULT_LOOKOUT_HEIGHT


func _make_wind(node_name: String, pitch: float, offset: float) -> AudioStreamPlayer:
	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	audio.name = node_name
	audio.bus = &"Ambiente"
	audio.stream = AmbientEmitter.looping(WIND_STREAM)
	audio.pitch_scale = pitch
	audio.volume_linear = 0.0
	add_child(audio)
	audio.play(offset)
	return audio


func _mix_audio(weights: Vector2) -> void:
	if _audio_tween != null:
		_audio_tween.kill()
	_audio_tween = create_tween().set_parallel(true)
	var low_db: float = DEFAULT_WIND_DB
	if _spec.ambience_bed != null:
		low_db = _spec.ambience_bed.volume_db
	# Ganho linear permite silêncio exato; a rampa evita degraus entre amostras.
	_audio_tween.tween_property(_wind_low, "volume_linear", db_to_linear(low_db) * weights.x, UPDATE_INTERVAL)
	_audio_tween.tween_property(_wind_high, "volume_linear",
			db_to_linear(low_db + HIGH_WIND_BOOST_DB) * weights.y, UPDATE_INTERVAL)
	for node: Node in get_tree().get_nodes_in_group(CITY_AMBIENCE_GROUP):
		var bed: AudioStreamPlayer = node as AudioStreamPlayer
		if bed == null:
			continue
		if not _bed_volumes.has(bed):
			_bed_volumes[bed] = bed.volume_db
		_audio_tween.tween_property(bed, "volume_db",
				_bed_volumes[bed] + CITY_DUCK_DB * weights.x, UPDATE_INTERVAL)


func _reset_effects() -> void:
	if _audio_tween != null:
		_audio_tween.kill()
	_weight = 0.0
	if is_instance_valid(_day_night):
		_day_night.set_fog_overlay(0.0, 1.0, Color.WHITE, 0.0)
	for bed: AudioStreamPlayer in _bed_volumes:
		if is_instance_valid(bed):
			bed.volume_db = _bed_volumes[bed]
	_bed_volumes.clear()
	if is_instance_valid(_wind_low):
		_wind_low.volume_linear = 0.0
	if is_instance_valid(_wind_high):
		_wind_high.volume_linear = 0.0
