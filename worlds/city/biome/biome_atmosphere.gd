class_name BiomeAtmosphere
extends Node
## Névoa e som de fundo de um bioma, sem conhecer a cidade que o montou.
## setup recebe zonas XZ globais; quem monta inclui as zonas da trilha/mirante
## e põe o fundo da cidade no grupo CITY_AMBIENCE_GROUP.
##
## Fase 19.1: pode haver várias (uma por bairro com bioma), mas o céu tem uma
## mistura de névoa só (DayNight.set_fog_overlay). Por isso só uma "fala" com o
## DayNight: a de maior peso onde o jogador está (a "voz"). As outras cuidam só
## do próprio som. A voz usa o quanto passa da segunda colocada, para a névoa
## não dar degrau na divisa entre dois biomas (lá ela volta à da cidade e
## segue para a do vizinho). Com um bioma só, é o peso dele, como antes.
## O abafamento do fundo da cidade também é da voz.
##
## O som de fundo vem do perfil (BiomeSpec.ambience_bed, o primeiro arquivo,
## em loop); quem não diz nada ganha o vento. A camada do vento alto (mais
## forte perto da cota do mirante) só existe com terreno de fundo.

const UPDATE_INTERVAL: float = 0.1
const CITY_AMBIENCE_GROUP: StringName = &"city_ambience_bed"
## Todas as atmosferas da cena, para escolher a voz.
const GROUP: StringName = &"biome_atmosphere"
## O volume original do fundo da cidade fica guardado no próprio nó: qualquer
## atmosfera que vire a voz sabe para onde voltar.
const BED_BASE_META: StringName = &"biome_bed_base_db"
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
## O som de fundo (camada baixa) e o vento alto (só com terreno de fundo).
var _wind_low: AudioStreamPlayer
var _wind_high: AudioStreamPlayer
## O arquivo original da camada baixa (antes da cópia em loop).
var _bed_source: AudioStream
var _audio_tween: Tween
## Os fundos da cidade que esta atmosfera abaixou (só enquanto é a voz).
var _ducked_beds: Array[AudioStreamPlayer] = []
## Se a última mistura de névoa do DayNight foi escrita por esta.
var _has_voice: bool = false


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
		_sync_streams()
		update_now()


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_wind_low = _make_player("WindLow", 1.0)
	_wind_high = _make_player("WindHigh", 0.9)
	_sync_streams()
	var timer: Timer = Timer.new()
	timer.wait_time = UPDATE_INTERVAL
	timer.timeout.connect(update_now)
	add_child(timer)
	timer.start()
	update_now()


func _exit_tree() -> void:
	_reset_effects()
	remove_from_group(GROUP)
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


## O peso deste bioma num ponto (0 fora dele). Sem perfil, 0.
func weight_at(position: Vector3) -> float:
	if _spec == null:
		return 0.0
	return zone_weight(Vector2(position.x, position.z), _zones, _spec.fog_blend_meters)


## Se esta atmosfera é a que fala com o DayNight agora.
func has_voice() -> bool:
	return _has_voice


## O segundo peso só chega a 1 na cota do mirante e só existe com terreno de
## fundo; fora do bioma ambos zeram.
func wind_weights(position: Vector3) -> Vector2:
	if _spec == null:
		return Vector2.ZERO
	var weight: float = weight_at(position)
	if _spec.backdrop == null:
		return Vector2(weight, 0.0)
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
	var runner_up: float = _runner_up_weight()
	var voice: bool = runner_up >= 0.0
	if voice and is_instance_valid(_day_night):
		# O quanto passa da segunda colocada (sozinha, o próprio peso).
		_day_night.set_fog_overlay(maxf(_weight - runner_up, 0.0),
				_spec.fog_density_scale, _spec.fog_tint, _spec.fog_tint_amount,
				_base_height + _lookout_height() * FOG_HEIGHT_FRACTION, _spec.fog_height_density)
	_has_voice = voice
	_mix_audio(weights, voice)


## O maior peso entre as outras atmosferas no mesmo ponto, ou -1 se outra
## tem a voz (peso maior; no empate, a de menor id). Sem outras, 0.
func _runner_up_weight() -> float:
	var best: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other: BiomeAtmosphere = node as BiomeAtmosphere
		if other == null or other == self or other._spec == null or not other.is_inside_tree():
			continue
		var weight: float = other.weight_at(_player.global_position)
		if weight > _weight or (weight == _weight and other.get_instance_id() < get_instance_id()):
			return -1.0
		best = maxf(best, weight)
	return best


func _lookout_height() -> float:
	if _spec.backdrop != null:
		return maxf(_spec.backdrop.lookout_height, 0.001)
	return DEFAULT_LOOKOUT_HEIGHT


func _make_player(node_name: String, pitch: float) -> AudioStreamPlayer:
	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	audio.name = node_name
	audio.bus = &"Ambiente"
	audio.pitch_scale = pitch
	audio.volume_linear = 0.0
	add_child(audio)
	return audio


## Põe os sons do perfil nos dois tocadores: o fundo do bioma (ou o vento) na
## camada baixa, e o vento alto só com terreno de fundo.
func _sync_streams() -> void:
	if _wind_low == null:
		return
	var source: AudioStream = _bed_stream()
	if source != _bed_source:
		_bed_source = source
		_wind_low.stream = AmbientEmitter.looping(source)
		_wind_low.play()
	var wants_high: bool = _spec != null and _spec.backdrop != null
	if wants_high and _wind_high.stream == null:
		_wind_high.stream = AmbientEmitter.looping(WIND_STREAM)
		# Tom e ponto inicial diferentes evitam duas cópias tocando em coro.
		_wind_high.play(WIND_STREAM.get_length() * 0.5)
	elif not wants_high and _wind_high.stream != null:
		_wind_high.stop()
		_wind_high.stream = null


## O som de fundo do perfil (o primeiro arquivo); sem ele, o vento.
func _bed_stream() -> AudioStream:
	if _spec == null or _spec.ambience_bed == null or _spec.ambience_bed.files.is_empty():
		return WIND_STREAM
	var path: String = _spec.ambience_bed.files[0]
	var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("O som de fundo %s do bioma %s não carregou; fica o vento." % [path, _spec.id])
		return WIND_STREAM
	return stream


func _mix_audio(weights: Vector2, voice: bool) -> void:
	if _audio_tween != null:
		_audio_tween.kill()
	_audio_tween = create_tween().set_parallel(true)
	var low_db: float = DEFAULT_WIND_DB
	if _spec.ambience_bed != null:
		low_db = _spec.ambience_bed.volume_db
	# Ganho linear permite silêncio exato; a rampa evita degraus entre amostras.
	_audio_tween.tween_property(_wind_low, "volume_linear", db_to_linear(low_db) * weights.x, UPDATE_INTERVAL)
	if _wind_high.stream != null:
		_audio_tween.tween_property(_wind_high, "volume_linear",
				db_to_linear(low_db + HIGH_WIND_BOOST_DB) * weights.y, UPDATE_INTERVAL)
	if not voice:
		# Quem perdeu a voz deixa o fundo com a nova voz (sem restaurar: ela abaixa).
		_ducked_beds.clear()
		return
	for node: Node in get_tree().get_nodes_in_group(CITY_AMBIENCE_GROUP):
		var bed: AudioStreamPlayer = node as AudioStreamPlayer
		if bed == null:
			continue
		if not bed.has_meta(BED_BASE_META):
			bed.set_meta(BED_BASE_META, bed.volume_db)
		if not _ducked_beds.has(bed):
			_ducked_beds.append(bed)
		_audio_tween.tween_property(bed, "volume_db",
				float(bed.get_meta(BED_BASE_META)) + CITY_DUCK_DB * weights.x, UPDATE_INTERVAL)


func _reset_effects() -> void:
	if _audio_tween != null:
		_audio_tween.kill()
	_weight = 0.0
	# Só a voz limpa a névoa: as outras não mexem na mistura de quem fala.
	if _has_voice and is_instance_valid(_day_night):
		_day_night.set_fog_overlay(0.0, 1.0, Color.WHITE, 0.0)
	_has_voice = false
	for bed: AudioStreamPlayer in _ducked_beds:
		if is_instance_valid(bed) and bed.has_meta(BED_BASE_META):
			bed.volume_db = float(bed.get_meta(BED_BASE_META))
	_ducked_beds.clear()
	if is_instance_valid(_wind_low):
		_wind_low.volume_linear = 0.0
	if is_instance_valid(_wind_high):
		_wind_high.volume_linear = 0.0
