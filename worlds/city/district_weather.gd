class_name DistrictWeather
extends Node3D
## O que CAI num lugar quando o mundo chove (Fase 7.6; chuva refeita na 19.5;
## desde a 19.6 quem decide o tempo é o WeatherDirector).
##
## O tempo é um só para a cidade toda. Este nó recebe dele a força (grupo
## WeatherDirector.GROUP, set_weather(estado, força): 0 = nada, 0,5 = chuva
## fraca, 1 = chuva forte) e mostra do jeito do lugar (o "kind" do WeatherSpec):
##   garoa    a chuva da cidade;
##   neve     neve, e nevasca na chuva forte (a montanha);
##   folhas   a chuva com folhas caindo (a floresta);
##   poeira   poeira levada pelo vento, sem chuva (o deserto).
##
## As partículas ACOMPANHAM o jogador enquanto ele está no lugar: o custo não
## depende do tamanho do bairro. A força muda pelo amount_ratio (a parte das
## partículas que nasce), que não reinicia nada: a passagem do tempo é suave.
##
## A chuva tem camadas, cada uma ligada pela qualidade gráfica
## (GraphicsQuality.rain_layers). Nenhuma acende luz nova:
##   riscos   gotas esticadas na direção da queda, inclinadas pelo vento
##            (rain_streak.gdshader);
##   respingo coroinhas de água no chão, perto do jogador;
##   som      o loop gerado por assets/generated/make_sounds.py. Dentro de
##            casa ele continua, mais baixo, e o canal "Ambiente" abafa (o
##            Player): a casa ouve a chuva pela janela.
## O chão molhado e o céu fechado são da cidade toda: quem cuida é o
## WeatherDirector.
##
## O grupo "city_night" avisa a hora (set_night): a tinta escurece à noite.

## A neve (Fase 15.11) é a "fraca"; a nevasca, a "forte" (na Alta e com
## intensidade 1.0).
const SNOW: Dictionary = {"area": 30.0, "height": 10.0, "size": Vector2(0.09, 0.09),
		"color": Color(0.76, 0.8, 0.84, 0.65)}
const SNOW_STRENGTHS: Dictionary = {
	"fraca": {"amount": 500, "speed_min": 1.5, "speed_max": 2.5,
			"direction": Vector3(0.08, -1.0, 0.04), "spread": 12.0},
	"forte": {"amount": 1600, "speed_min": 2.5, "speed_max": 4.0,
			"direction": Vector3(0.6, -1.0, 0.3), "spread": 18.0},
}

## As duas forças da chuva (na Alta e com intensidade 1.0):
##   streaks/splashes  quantas gotas e respingos ao mesmo tempo (no ar)
##   length/width      tamanho do risco (m)       alpha  opacidade do risco
##   speed             velocidade da queda (m/s)  wind   vento (x, z em m/s)
##   volume_db         volume do som
## Entre a fraca e a forte, tudo passa em linha reta; abaixo da fraca, só a
## quantidade e o volume descem.
const RAIN_STRENGTHS: Dictionary = {
	"fraca": {
		"streaks": 1800, "length": 0.55, "width": 0.009, "alpha": 0.8,
		"speed": 11.0, "wind": Vector2(1.2, 0.5), "splashes": 180, "volume_db": -15.0,
	},
	"forte": {
		"streaks": 5000, "length": 0.85, "width": 0.012, "alpha": 0.7,
		"speed": 14.0, "wind": Vector2(2.8, 1.2), "splashes": 600, "volume_db": -6.0,
	},
}
## As folhas que caem junto com a chuva ("folhas"): quantas (fraca e forte),
## a queda (m/s) e o tamanho (m).
const LEAVES: Dictionary = {"fraca": 40, "forte": 120, "speed": Vector2(0.8, 1.6),
		"size": Vector2(0.09, 0.06), "lifetime": 9.0, "height": 8.0}
const LEAF_COLORS: PackedColorArray = [Color(0.36, 0.45, 0.2), Color(0.62, 0.55, 0.22), Color(0.5, 0.32, 0.16)]
## A poeira ("poeira"): nuvens grandes e transparentes, rentes ao chão, que o
## vento leva. amount/alpha/speed/volume_db na fraca e na forte.
const DUST_STRENGTHS: Dictionary = {
	"fraca": {"amount": 60, "alpha": 0.1, "speed": 4.0, "volume_db": -16.0},
	"forte": {"amount": 160, "alpha": 0.18, "speed": 8.0, "volume_db": -8.0},
}
const DUST: Dictionary = {"area": 36.0, "size": Vector2(2.6, 2.0), "lifetime": 5.0,
		"color": Color(0.78, 0.67, 0.52)}
## A caixa de onde a chuva cai: lado (m, em volta do jogador) e altura.
const RAIN_AREA: float = 30.0
const RAIN_HEIGHT: float = 10.0
## Quanto uma gota vive: o tempo da queda da chuva FRACA (a mais lenta) da
## caixa até um pouco abaixo do chão. Fica fixo (trocar o lifetime no meio
## bagunça as partículas no ar); na forte, que cai mais rápido, nascem mais
## gotas para o ar ficar tão cheio quanto (veja _streaks_for).
const RAIN_LIFETIME: float = (RAIN_HEIGHT + 3.0) / (11.0 * 0.9)
const SNOW_LIFETIME: float = (10.0 + 6.0) / 1.5
## Os respingos: lado da área no chão (m) e quanto cada um dura (s).
const SPLASH_AREA: float = 24.0
const SPLASH_LIFETIME: float = 0.32
## Segundos para o som chegar (e sair) por inteiro, ao entrar e sair do lugar.
const FADE_SECONDS: float = 4.0
## Quanto do som fica dentro de casa (antes do abafado do canal Ambiente).
const INDOOR_PRESENCE: float = 0.5
## A tinta do risco de dia e à noite (a cor vem mais do que está atrás).
const RAIN_TINT_DAY: Color = Color(0.82, 0.86, 0.92)
const RAIN_TINT_NIGHT: Color = Color(0.55, 0.6, 0.72)
const RAIN_SHADER: Shader = preload("res://worlds/city/rain_streak.gdshader")
const RAIN_SOUND: String = "res://assets/generated/rain_loop.wav"
const WIND_SOUND: String = "res://assets/generated/wind_loop.wav"

## Onde vale (x, z em metros, no mundo): as zonas do bairro no CityMap
## (quarteirões e vagas, cada uma com meia rua em volta). Vazio = em todo
## lugar (a chuva da cidade), menos o que estiver em "exclude".
var areas: Array[Rect2] = []
## Onde NÃO vale (as zonas dos bairros que mostram o tempo do jeito deles).
var exclude: Array[Rect2] = []
var spec: WeatherSpec

var _night: float = 0.0
## O tempo do mundo, como chegou (WeatherDirector).
var _state: String = "limpo"
var _strength: float = 0.0
## O que cai: "Rain" (chuva ou neve) ou "Dust"; e o que vai junto.
var _rain: GPUParticles3D
var _splashes: GPUParticles3D
var _leaves: GPUParticles3D
var _sound: AudioStreamPlayer
var _streak_material: ShaderMaterial
var _splash_material: StandardMaterial3D
var _dust_material: StandardMaterial3D
var _player: Node3D
var _kind: String = "garoa"
## As camadas da qualidade de agora (GraphicsQuality.rain_layers) e o máximo
## de cada sistema (a força escolhe a parte que nasce).
var _layers: Dictionary = {}
var _max: Dictionary = {}
## O som sobe e desce aos poucos (0 a 1).
var _presence: float = 0.0


## O que cai aqui ("garoa", "neve", "folhas" ou "poeira").
func current_kind() -> String:
	return _kind


## A força que chegou do mundo (0 a 1).
func current_strength() -> float:
	return _strength


## O tempo do mundo que chegou (um dos WeatherDirector.STATES).
func current_state() -> String:
	return _state


## Cai alguma coisa agora, em volta do jogador?
func is_raining() -> bool:
	return _rain != null and _rain.emitting


## O tempo do mundo (WeatherDirector.GROUP). A força vai de 0 a 1.
func set_weather(state: String, strength: float) -> void:
	_state = state
	_strength = clampf(strength, 0.0, 1.0)
	_apply_shape()
	_refresh()


func set_night(night: float) -> void:
	_night = night
	_update_tint()


func _ready() -> void:
	add_to_group("city_night")
	add_to_group(WeatherDirector.GROUP)
	if spec != null:
		_kind = spec.kind
	match _kind:
		"neve":
			_build_snow()
		"poeira":
			_build_dust()
		_:
			_build_rain()
			if _kind == "folhas":
				_build_leaves()
	AppConfig.settings_changed.connect(_on_settings_changed)
	_apply_amount()
	_update_tint()
	set_process(true)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	var feet := _player.global_position
	_rain.global_position = rain_origin(feet)
	if _splashes != null:
		_splashes.global_position = feet + Vector3(0.0, -0.02, 0.0)
	if _leaves != null:
		_leaves.global_position = feet + Vector3(0.0, float(LEAVES["height"]), 0.0)
	_refresh()
	# O som acompanha o lugar: entra e sai devagar; dentro de casa, mais baixo.
	var target := 0.0
	if _strength > 0.0 and _covers(Vector2(feet.x, feet.z)):
		target = INDOOR_PRESENCE if _indoors() else 1.0
	_presence = move_toward(_presence, target, delta / FADE_SECONDS)
	_apply_sound()


## De onde cai, para os pés dados: acima deles e um pouco contra o vento (a
## gota anda de lado enquanto cai e chega em volta do jogador). A poeira nasce
## rente ao chão, contra o vento.
func rain_origin(feet: Vector3) -> Vector3:
	var t := _shape_t()
	var wind := _wind()
	match _kind:
		"neve":
			return feet + Vector3(0.0, float(SNOW["height"]), 0.0)
		"poeira":
			var speed := lerpf(DUST_STRENGTHS["fraca"]["speed"], DUST_STRENGTHS["forte"]["speed"], t)
			var away := wind.normalized() * speed * float(DUST["lifetime"]) * 0.5
			return feet + Vector3(-away.x, 1.5, -away.y)
	var fall_seconds := (RAIN_HEIGHT - 1.7) / _rain_value("speed")
	return feet + Vector3(-wind.x * fall_seconds, RAIN_HEIGHT, -wind.y * fall_seconds)


## Quantas gotas nascem por ciclo na força dada (sem qualidade nem
## intensidade): a quantidade da tabela, mais a parte que a queda mais rápida
## pede (a gota fica menos tempo no ar).
static func _streaks_for(strength: float) -> float:
	var fraca: Dictionary = RAIN_STRENGTHS["fraca"]
	var forte: Dictionary = RAIN_STRENGTHS["forte"]
	var t := clampf((strength - 0.5) / 0.5, 0.0, 1.0)
	var speed := lerpf(fraca["speed"], forte["speed"], t)
	return WeatherDirector.mix(strength, fraca["streaks"], forte["streaks"]) * speed / float(fraca["speed"])


static func _flakes_for(strength: float) -> float:
	var fraca: Dictionary = SNOW_STRENGTHS["fraca"]
	var forte: Dictionary = SNOW_STRENGTHS["forte"]
	var t := clampf((strength - 0.5) / 0.5, 0.0, 1.0)
	var speed := lerpf(fraca["speed_min"], forte["speed_min"], t)
	return WeatherDirector.mix(strength, fraca["amount"], forte["amount"]) * speed / float(fraca["speed_min"])


## O ponto entre a força fraca (0) e a forte (1).
func _shape_t() -> float:
	return clampf((_strength - 0.5) / 0.5, 0.0, 1.0)


func _rain_value(key: String) -> float:
	return lerpf(RAIN_STRENGTHS["fraca"][key], RAIN_STRENGTHS["forte"][key], _shape_t())


func _wind() -> Vector2:
	var fraca: Vector2 = RAIN_STRENGTHS["fraca"]["wind"]
	var forte: Vector2 = RAIN_STRENGTHS["forte"]["wind"]
	return fraca.lerp(forte, _shape_t())


func _indoors() -> bool:
	return _player != null and _player.has_method("is_indoors") and bool(_player.call("is_indoors"))


func _covers(point: Vector2) -> bool:
	for rect in exclude:
		if rect.has_point(point):
			return false
	if areas.is_empty():
		return true
	for rect in areas:
		if rect.has_point(point):
			return true
	return false


## Liga o que cai se houver força, o jogador estiver no lugar e na rua; a
## força escolhe quanto nasce.
func _refresh() -> void:
	if _rain == null:
		return
	var here := _player != null and _covers(Vector2(_player.global_position.x, _player.global_position.z))
	var active := _strength > 0.001 and here and not _indoors()
	_set_part(_rain, active, _part_ratio("main"))
	if _splashes != null:
		_set_part(_splashes, active and float(_layers.get("respingo", 0.0)) > 0.0, _part_ratio("splashes"))
	if _leaves != null:
		_set_part(_leaves, active, _part_ratio("leaves"))


func _set_part(particles: GPUParticles3D, on: bool, ratio: float) -> void:
	on = on and ratio > 0.0
	if particles.emitting != on:
		particles.emitting = on
	if on and not is_equal_approx(particles.amount_ratio, ratio):
		particles.amount_ratio = ratio


## A parte de cada sistema que nasce na força de agora (0 a 1 do máximo).
func _part_ratio(part: String) -> float:
	var top: float = _max.get(part, 0.0)
	if top <= 0.0:
		return 0.0
	var wanted := 0.0
	match part:
		"main":
			match _kind:
				"neve":
					wanted = _flakes_for(_strength) / _flakes_for(1.0)
				"poeira":
					wanted = WeatherDirector.mix(_strength, DUST_STRENGTHS["fraca"]["amount"],
							DUST_STRENGTHS["forte"]["amount"]) / float(DUST_STRENGTHS["forte"]["amount"])
				_:
					wanted = _streaks_for(_strength) / _streaks_for(1.0)
		"splashes":
			wanted = WeatherDirector.mix(_strength, RAIN_STRENGTHS["fraca"]["splashes"],
					RAIN_STRENGTHS["forte"]["splashes"]) / float(RAIN_STRENGTHS["forte"]["splashes"])
		"leaves":
			wanted = WeatherDirector.mix(_strength, LEAVES["fraca"], LEAVES["forte"]) / float(LEAVES["forte"])
	return clampf(wanted, 0.0, 1.0)


## Quantas partículas nascem agora (o que o amount_ratio deixa; os testes
## conferem).
func emitted(part: String = "main") -> int:
	var particles: GPUParticles3D = {"main": _rain, "splashes": _splashes, "leaves": _leaves}.get(part)
	if particles == null:
		return 0
	return roundi(particles.amount * _part_ratio(part))


func _apply_sound() -> void:
	if _sound == null:
		return
	var audible := _presence > 0.001 and _strength > 0.0 and bool(_layers.get("som", true))
	if not audible:
		if _sound.playing:
			_sound.stop()
		return
	var table: Dictionary = DUST_STRENGTHS if _kind == "poeira" else RAIN_STRENGTHS
	var light: float = table["fraca"]["volume_db"]
	var volume := lerpf(light, table["forte"]["volume_db"], _shape_t())
	if _strength < 0.5:
		volume = light + linear_to_db(_strength / 0.5)
	_sound.volume_db = volume + linear_to_db(_presence)
	if not _sound.playing:
		_sound.play()


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		_apply_amount()


## O máximo de cada sistema na qualidade de agora (a força forte, com a
## intensidade do perfil). Trocar o amount reinicia as partículas: só aqui.
func _apply_amount() -> void:
	var intensity := spec.intensity if spec != null else 1.0
	var quality := AppConfig.get_quality()
	_layers = GraphicsQuality.rain_layers(quality)
	match _kind:
		"neve":
			_max["main"] = _flakes_for(1.0) * intensity * GraphicsQuality.weather_amount(quality)
		"poeira":
			_max["main"] = float(DUST_STRENGTHS["forte"]["amount"]) * intensity * float(_layers["riscos"])
		_:
			_max["main"] = _streaks_for(1.0) * intensity * float(_layers["riscos"])
			_max["splashes"] = float(RAIN_STRENGTHS["forte"]["splashes"]) * intensity * float(_layers["respingo"])
			if _leaves != null:
				_max["leaves"] = float(LEAVES["forte"]) * intensity * float(_layers["riscos"])
	_rain.amount = maxi(1, roundi(_max["main"]))
	if _splashes != null:
		_splashes.amount = maxi(1, roundi(_max["splashes"]))
		_splashes.visible = roundi(_max["splashes"]) > 0
	if _leaves != null:
		_leaves.amount = maxi(1, roundi(_max["leaves"]))
	_refresh()


# --- A forma (muda com a força, sem reiniciar) -------------------------------------

func _apply_shape() -> void:
	if _rain == null:
		return
	var t := _shape_t()
	var process := _rain.process_material as ParticleProcessMaterial
	match _kind:
		"neve":
			var fraca: Dictionary = SNOW_STRENGTHS["fraca"]
			var forte: Dictionary = SNOW_STRENGTHS["forte"]
			process.direction = (fraca["direction"] as Vector3).lerp(forte["direction"], t).normalized()
			process.spread = lerpf(fraca["spread"], forte["spread"], t)
			process.initial_velocity_min = lerpf(fraca["speed_min"], forte["speed_min"], t)
			process.initial_velocity_max = lerpf(fraca["speed_max"], forte["speed_max"], t)
		"poeira":
			var wind := _wind().normalized()
			var speed := lerpf(DUST_STRENGTHS["fraca"]["speed"], DUST_STRENGTHS["forte"]["speed"], t)
			process.direction = Vector3(wind.x, 0.05, wind.y).normalized()
			process.initial_velocity_min = speed * 0.8
			process.initial_velocity_max = speed * 1.2
		_:
			var wind := _wind()
			var velocity := Vector3(wind.x, -_rain_value("speed"), wind.y)
			process.direction = velocity.normalized()
			process.initial_velocity_min = velocity.length() * 0.9
			process.initial_velocity_max = velocity.length() * 1.1
			_streak_material.set_shader_parameter("fall_direction", velocity.normalized())
			_streak_material.set_shader_parameter("streak_length", _rain_value("length"))
			_streak_material.set_shader_parameter("streak_width", _rain_value("width"))
			if _leaves != null:
				var leaf_process := _leaves.process_material as ParticleProcessMaterial
				var speed: Vector2 = LEAVES["speed"]
				leaf_process.direction = Vector3(wind.x * 0.5, -1.0, wind.y * 0.5).normalized()
				leaf_process.initial_velocity_min = speed.x
				leaf_process.initial_velocity_max = speed.y
	_update_tint()


## A tinta pela hora (à noite, bem mais escura) e pela força.
func _update_tint() -> void:
	if _streak_material != null:
		var color := RAIN_TINT_DAY.lerp(RAIN_TINT_NIGHT, _night)
		color.a = _rain_value("alpha")
		_streak_material.set_shader_parameter("tint", color)
		var splash := color
		splash.a = lerpf(0.4, 0.3, _night)
		_splash_material.albedo_color = splash
	if _dust_material != null:
		var dust: Color = (DUST["color"] as Color).darkened(0.7 * _night)
		dust.a = lerpf(DUST_STRENGTHS["fraca"]["alpha"], DUST_STRENGTHS["forte"]["alpha"], _shape_t())
		_dust_material.albedo_color = dust


# --- Montagem -------------------------------------------------------------------

func _build_snow() -> void:
	var area: float = SNOW["area"]
	var height: float = SNOW["height"]
	_rain = _make_particles("Rain", SNOW_LIFETIME,
			AABB(Vector3(-area, -height - 30.0, -area), Vector3(area * 2.0, height * 2.0 + 38.0, area * 2.0)))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(area / 2.0, 0.2, area / 2.0)
	process.gravity = Vector3.ZERO
	_rain.process_material = process
	var flake := QuadMesh.new()
	flake.size = SNOW["size"]
	var material := _soft_material(SNOW["color"])
	flake.material = material
	_rain.draw_pass_1 = flake
	add_child(_rain)
	_apply_shape()


func _build_dust() -> void:
	var area: float = DUST["area"]
	_rain = _make_particles("Dust", DUST["lifetime"],
			AABB(Vector3(-area * 2.0, -4.0, -area * 2.0), Vector3(area * 4.0, 12.0, area * 4.0)))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(area / 2.0, 1.2, area / 2.0)
	process.spread = 10.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 1.4
	# Nasce e some aos poucos (nada pisca).
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	_rain.process_material = process
	var cloud := QuadMesh.new()
	cloud.size = DUST["size"]
	_dust_material = _soft_material(DUST["color"])
	_dust_material.vertex_color_use_as_albedo = true
	cloud.material = _dust_material
	_rain.draw_pass_1 = cloud
	add_child(_rain)
	_sound = _make_sound("DustSound", WIND_SOUND)
	_apply_shape()


## Um material sem luz, transparente, virado para a câmera, com a borda macia
## (máscara radial gerada em memória: sem baixar textura).
static func _soft_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	material.albedo_texture = texture
	return material


func _build_rain() -> void:
	# Riscos. A forma da queda (direção, velocidade) é posta por _apply_shape.
	_rain = _make_particles("Rain", RAIN_LIFETIME, AABB(Vector3(-RAIN_AREA, -RAIN_HEIGHT - 12.0, -RAIN_AREA),
			Vector3(RAIN_AREA * 2.0, RAIN_HEIGHT * 2.0 + 20.0, RAIN_AREA * 2.0)))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(RAIN_AREA / 2.0, 0.5, RAIN_AREA / 2.0)
	process.spread = 1.5
	process.gravity = Vector3.ZERO
	_rain.process_material = process
	var quad := QuadMesh.new()
	_streak_material = ShaderMaterial.new()
	_streak_material.shader = RAIN_SHADER
	quad.material = _streak_material
	_rain.draw_pass_1 = quad
	add_child(_rain)

	# Respingos: coroinhas que nascem no chão em volta do jogador e somem rápido.
	_splashes = _make_particles("Splashes", SPLASH_LIFETIME,
			AABB(Vector3(-SPLASH_AREA, -1.0, -SPLASH_AREA), Vector3(SPLASH_AREA * 2.0, 2.0, SPLASH_AREA * 2.0)))
	_splashes.randomness = 1.0
	var splash_process := ParticleProcessMaterial.new()
	splash_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	splash_process.emission_box_extents = Vector3(SPLASH_AREA / 2.0, 0.0, SPLASH_AREA / 2.0)
	splash_process.gravity = Vector3.ZERO
	splash_process.initial_velocity_min = 0.0
	splash_process.initial_velocity_max = 0.0
	splash_process.scale_min = 0.6
	splash_process.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.35, 1.0))
	grow.add_point(Vector2(1.0, 1.1))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	splash_process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	splash_process.color_ramp = fade_texture
	_splashes.process_material = splash_process
	var crown := QuadMesh.new()
	crown.size = Vector2(0.16, 0.1)
	crown.center_offset = Vector3(0.0, 0.05, 0.0)  # a base fica no chão
	_splash_material = StandardMaterial3D.new()
	_splash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_splash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_splash_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_splash_material.billboard_keep_scale = true
	_splash_material.vertex_color_use_as_albedo = true
	_splash_material.albedo_texture = _crown_texture()
	crown.material = _splash_material
	_splashes.draw_pass_1 = crown
	add_child(_splashes)

	_sound = _make_sound("RainSound", RAIN_SOUND)
	_apply_shape()


## As folhas: cartõezinhos que caem girando, em tons de verde e marrom.
func _build_leaves() -> void:
	var lifetime: float = LEAVES["lifetime"]
	_leaves = _make_particles("Leaves", lifetime,
			AABB(Vector3(-RAIN_AREA, -12.0, -RAIN_AREA), Vector3(RAIN_AREA * 2.0, 24.0, RAIN_AREA * 2.0)))
	_leaves.randomness = 1.0
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(RAIN_AREA / 2.0, 1.0, RAIN_AREA / 2.0)
	process.spread = 25.0
	process.gravity = Vector3.ZERO
	process.angle_min = 0.0
	process.angle_max = 360.0
	process.angular_velocity_min = -160.0
	process.angular_velocity_max = 160.0
	process.scale_min = 0.7
	process.scale_max = 1.3
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	colors.colors = LEAF_COLORS
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = colors
	process.color_initial_ramp = color_texture
	_leaves.process_material = process
	var leaf := QuadMesh.new()
	leaf.size = LEAVES["size"]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = _leaf_texture()
	leaf.material = material
	_leaves.draw_pass_1 = leaf
	add_child(_leaves)


func _make_sound(node_name: String, path: String) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.name = node_name
	sound.stream = AmbientEmitter.looping(load(path))
	sound.bus = &"Ambiente"
	add_child(sound)
	return sound


func _make_particles(node_name: String, lifetime: float, bounds: AABB) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.emitting = false
	particles.lifetime = lifetime
	particles.local_coords = false  # as partículas ficam no mundo quando a caixa anda
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = bounds
	return particles


## A coroinha do respingo, desenhada em memória: uma mancha achatada na base e
## gotinhas subindo em leque (o alfa é o desenho; a cor vem do material).
static func _crown_texture() -> ImageTexture:
	var width := 64
	var height := 48
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var angles: Array[float] = [-58.0, -32.0, -12.0, 10.0, 30.0, 56.0]
	for y in height:
		for x in width:
			var u := (x + 0.5) / width * 2.0 - 1.0
			var v := 1.0 - (y + 0.5) / height  # 0 = base, 1 = topo
			var p := Vector2(u, v * 1.3)
			var alpha := exp(-((u / 0.5) * (u / 0.5) + (v / 0.12) * (v / 0.12)) * 2.5) * 0.6
			for degrees in angles:
				var d := Vector2(sin(deg_to_rad(degrees)), cos(deg_to_rad(degrees)))
				var along := p.dot(d)
				if along > 0.0 and along < 0.7:
					var across := absf(p.cross(d))
					alpha += exp(-pow(across / 0.06, 2.0)) * (1.0 - along / 0.7) * 0.35
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## A folha, desenhada em memória: um losango arredondado (a cor vem da partícula).
static func _leaf_texture() -> ImageTexture:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (x + 0.5) / size * 2.0 - 1.0
			var v := (y + 0.5) / size * 2.0 - 1.0
			var inside := absf(u) / (1.0 - absf(v) * 0.55) + absf(v) < 1.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 if inside else 0.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
