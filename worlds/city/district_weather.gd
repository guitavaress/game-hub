class_name DistrictWeather
extends Node3D
## Clima de um bairro: chuva (o tipo "garoa" do perfil; refeita em camadas na
## Fase 19.5) ou neve (Fase 15.11).
##
## Um só DistrictWeather por bairro, e as partículas ACOMPANHAM o jogador
## enquanto ele está dentro da área do bairro (e é noite, se o clima for "só à
## noite"). Assim o custo não depende do tamanho do bairro.
##
## A neve é como na 15.11: flocos em volta do jogador, e mais nada.
##
## A chuva tem camadas, cada uma ligada pela qualidade gráfica
## (GraphicsQuality.rain_layers). Nenhuma acende luz nova:
##   riscos   gotas esticadas na direção da queda, inclinadas pelo vento
##            (rain_streak.gdshader);
##   respingo coroinhas de água no chão, perto do jogador;
##   chao     o asfalto fica mais liso e escuro e as poças crescem, aos poucos
##            (CityDecor.set_ground_wetness); seca devagar quando para;
##   som      o loop gerado por assets/generated/make_sounds.py;
##   ceu      o céu fecha: menos sol, mais névoa (DayNight.set_overcast).
## Duas forças: "fraca" (a de sempre, no lugar da garoa) e "forte". Para ver
## sem esperar: F9 (de teste) passa por fraca, forte e normal, em qualquer
## lugar e a qualquer hora; as capturas usam force_rain.
##
## Amostra (19.5): o chão molhado e o céu fechado valem para a cidade toda
## (um material de asfalto, um céu), e só um bairro tem chuva. A 19.6 põe o
## WeatherDirector no comando.
##
## O grupo "city_night" avisa a hora (set_night).

## A neve (Fase 15.11), com a qualidade Alta e intensidade 1.0.
const SNOW: Dictionary = {
	"amount": 500, "area": 30.0, "height": 10.0,
	"speed_min": 1.5, "speed_max": 2.5,
	"direction": Vector3(0.08, -1.0, 0.04), "spread": 12.0,
	"size": Vector2(0.09, 0.09), "color": Color(0.76, 0.8, 0.84, 0.65),
}

## As duas forças da chuva (na Alta e com intensidade 1.0):
##   streaks/splashes  quantas gotas e respingos ao mesmo tempo
##   length/width      tamanho do risco (m)       alpha  opacidade do risco
##   speed             velocidade da queda (m/s)  wind   vento (x, z em m/s)
##   wet               quanto o chão chega a molhar (0 a 1)
##   volume_db         volume do som              overcast  quanto o céu fecha
const RAIN_STRENGTHS: Dictionary = {
	"fraca": {
		"streaks": 1800, "length": 0.55, "width": 0.009, "alpha": 0.8,
		"speed": 11.0, "wind": Vector2(1.2, 0.5), "splashes": 180,
		"wet": 0.6, "volume_db": -15.0, "overcast": 0.55,
	},
	"forte": {
		"streaks": 5000, "length": 0.85, "width": 0.012, "alpha": 0.7,
		"speed": 14.0, "wind": Vector2(2.8, 1.2), "splashes": 600,
		"wet": 1.0, "volume_db": -6.0, "overcast": 0.9,
	},
}
## A força de sempre (sem nada forçado).
const DEFAULT_STRENGTH: String = "fraca"
## A caixa de onde a chuva cai: lado (m, em volta do jogador) e altura.
const RAIN_AREA: float = 30.0
const RAIN_HEIGHT: float = 10.0
## Os respingos: lado da área no chão (m) e quanto cada um dura (s).
const SPLASH_AREA: float = 24.0
const SPLASH_LIFETIME: float = 0.32
## Segundos para o som e o céu chegarem (e voltarem) por inteiro.
const FADE_SECONDS: float = 4.0
## Segundos para o chão molhar por inteiro, e para secar.
const WET_SECONDS: float = 20.0
const DRY_SECONDS: float = 60.0
## A tinta do risco de dia e à noite (a cor vem mais do que está atrás).
const RAIN_TINT_DAY: Color = Color(0.82, 0.86, 0.92)
const RAIN_TINT_NIGHT: Color = Color(0.55, 0.6, 0.72)
const RAIN_SHADER: Shader = preload("res://worlds/city/rain_streak.gdshader")
const RAIN_SOUND: String = "res://assets/generated/rain_loop.wav"

## Onde o bairro fica (x, z em metros, no mundo): as zonas dele no CityMap
## (quarteirões e vagas, cada uma com meia rua em volta).
var areas: Array[Rect2] = []
var spec: WeatherSpec
## O relógio da cidade (para o céu fechar). Pode faltar (testes).
var day_night: DayNight

var _night: float = 0.0
var _rain: GPUParticles3D
var _splashes: GPUParticles3D
var _sound: AudioStreamPlayer
var _streak_material: ShaderMaterial
var _splash_material: StandardMaterial3D
var _player: Node3D
var _kind: String = "garoa"
var _strength: String = DEFAULT_STRENGTH
## A força forçada ("" = o tempo do bairro).
var _forced: String = ""
## As camadas da qualidade de agora (GraphicsQuality.rain_layers).
var _layers: Dictionary = {}
## O som e o céu sobem e descem aos poucos (0 a 1); o chão, mais devagar.
var _presence: float = 0.0
var _wet: float = 0.0
## Se esta chuva já mexeu no chão ou no céu (para devolver ao sair).
var _touched_world: bool = false


## Tipo aplicado na criação; spec nulo usa a aparência padrão, sem emitir.
func current_kind() -> String:
	return _kind


## A força da chuva agora ("fraca" ou "forte").
func current_strength() -> String:
	return _strength


## Há precipitação agora (chuva ou neve)? Respeita a área e o horário.
func is_raining() -> bool:
	return _rain != null and _rain.emitting


## Força a chuva ("fraca" ou "forte") em qualquer lugar e a qualquer hora, já
## com o chão molhado e o céu fechado (capturas, medida e o F9). "" volta ao
## tempo do bairro. Só vale para chuva.
func force_rain(strength: String) -> void:
	if _kind != "garoa" or (strength != "" and not RAIN_STRENGTHS.has(strength)):
		return
	_forced = strength
	_set_strength(strength if strength != "" else DEFAULT_STRENGTH)
	if strength != "":
		_refresh()
		_presence = 1.0
		_wet = float(RAIN_STRENGTHS[_strength]["wet"])
		_apply_presence()


func forced_strength() -> String:
	return _forced


func set_night(night: float) -> void:
	_night = night
	_update_tint()
	_refresh()


func _ready() -> void:
	add_to_group("city_night")
	if spec != null and spec.kind == "neve":
		_kind = "neve"
	if _kind == "neve":
		_build_snow()
	else:
		_build_rain()
	AppConfig.settings_changed.connect(_on_settings_changed)
	_apply_amount()
	_update_tint()
	set_process(true)


func _exit_tree() -> void:
	# O chão e o céu são da cidade toda: devolve como estavam.
	if _touched_world:
		CityDecor.set_ground_wetness(0.0)
		if is_instance_valid(day_night):
			day_night.set_overcast(0.0)
		_touched_world = false


func _unhandled_input(event: InputEvent) -> void:
	# F9 (só de teste, até o menu "Clima" da 19.6): fraca → forte → normal.
	var key := event as InputEventKey
	if _kind != "garoa" or key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F9:
		return
	var next: String = {"": "fraca", "fraca": "forte", "forte": ""}[_forced]
	force_rain(next)
	var hud: Variant = _player.call("get_hud") if _player != null and _player.has_method("get_hud") else null
	if hud != null:
		var title := "Chuva: %s" % next if next != "" else "Chuva: o tempo do bairro"
		hud.call("show_message", title, "F9 (teste) troca a chuva.", Toast.Kind.INFO, 3.0)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	var feet := _player.global_position
	if _kind == "neve":
		_rain.global_position = feet + Vector3(0.0, SNOW["height"], 0.0)
		_refresh()
		return
	_rain.global_position = rain_origin(feet)
	_splashes.global_position = feet + Vector3(0.0, -0.02, 0.0)
	_refresh()
	# O som e o céu acompanham a chuva; o chão molha e seca mais devagar.
	var raining := is_raining()
	_presence = move_toward(_presence, 1.0 if raining else 0.0, delta / FADE_SECONDS)
	var wet_target: float = RAIN_STRENGTHS[_strength]["wet"] if raining else 0.0
	_wet = move_toward(_wet, wet_target, delta / (WET_SECONDS if _wet < wet_target else DRY_SECONDS))
	_apply_presence()


## De onde a chuva cai, para os pés dados: acima deles e um pouco contra o
## vento (a gota anda de lado enquanto cai e chega em volta do jogador).
func rain_origin(feet: Vector3) -> Vector3:
	var rain: Dictionary = RAIN_STRENGTHS[_strength]
	var wind: Vector2 = rain["wind"]
	var fall_seconds := (RAIN_HEIGHT - 1.7) / float(rain["speed"])
	return feet + Vector3(-wind.x * fall_seconds, RAIN_HEIGHT, -wind.y * fall_seconds)


func _refresh() -> void:
	if _rain == null:
		return
	if _forced != "":
		var indoors := _player != null and _player.has_method("is_indoors") and bool(_player.call("is_indoors"))
		_rain.emitting = not indoors
	else:
		var inside := _player != null and _is_inside(Vector2(_player.global_position.x, _player.global_position.z))
		var dark := _night > 0.5 or spec == null or not spec.night_only
		_rain.emitting = inside and dark and spec != null
	if _splashes != null:
		_splashes.emitting = _rain.emitting and _splashes.amount > 1 and float(_layers.get("respingo", 0.0)) > 0.0


func _is_inside(point: Vector2) -> bool:
	for rect in areas:
		if rect.has_point(point):
			return true
	return false


## O som, o chão e o céu na medida de agora (cada um só se a qualidade ligar).
func _apply_presence() -> void:
	if _kind != "garoa":
		return
	var rain: Dictionary = RAIN_STRENGTHS[_strength]
	if _sound != null:
		var audible := _presence > 0.001 and bool(_layers.get("som", true))
		if audible:
			_sound.volume_db = float(rain["volume_db"]) + linear_to_db(_presence)
			if not _sound.playing:
				_sound.play()
		elif _sound.playing:
			_sound.stop()
	var wet := _wet if bool(_layers.get("chao", true)) else 0.0
	if wet != CityDecor.ground_wetness() and (wet > 0.0 or _touched_world):
		CityDecor.set_ground_wetness(wet)
		_touched_world = true
	var overcast: float = float(rain["overcast"]) * _presence if bool(_layers.get("ceu", true)) else 0.0
	if is_instance_valid(day_night) and overcast != day_night.get_overcast() and (overcast > 0.0 or _touched_world):
		day_night.set_overcast(overcast)
		_touched_world = true


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		_apply_amount()


func _apply_amount() -> void:
	var intensity := spec.intensity if spec != null else 1.0
	var quality := AppConfig.get_quality()
	if _kind == "neve":
		_rain.amount = maxi(1, roundi(int(SNOW["amount"]) * intensity * GraphicsQuality.weather_amount(quality)))
		return
	_layers = GraphicsQuality.rain_layers(quality)
	var rain: Dictionary = RAIN_STRENGTHS[_strength]
	_rain.amount = maxi(1, roundi(int(rain["streaks"]) * intensity * float(_layers["riscos"])))
	var splashes := roundi(int(rain["splashes"]) * intensity * float(_layers["respingo"]))
	_splashes.amount = maxi(1, splashes)
	_splashes.visible = splashes > 0
	_refresh()
	_apply_presence()


# --- Montagem -------------------------------------------------------------------

func _build_snow() -> void:
	var area: float = SNOW["area"]
	var height: float = SNOW["height"]
	_rain = _make_particles("Rain", (height + 6.0) / float(SNOW["speed_min"]),
			AABB(Vector3(-area, -height - 8.0, -area), Vector3(area * 2.0, height * 2.0 + 16.0, area * 2.0)))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(area / 2.0, 0.2, area / 2.0)
	process.direction = SNOW["direction"]
	process.spread = SNOW["spread"]
	process.initial_velocity_min = SNOW["speed_min"]
	process.initial_velocity_max = SNOW["speed_max"]
	process.gravity = Vector3.ZERO
	_rain.process_material = process
	var flake := QuadMesh.new()
	flake.size = SNOW["size"]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = SNOW["color"]
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Máscara radial gerada em memória: borda macia sem baixar uma textura.
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
	flake.material = material
	_rain.draw_pass_1 = flake
	add_child(_rain)


func _build_rain() -> void:
	# Riscos. A forma da queda (direção, velocidade) é posta por _set_strength.
	_rain = _make_particles("Rain", 1.0, AABB(Vector3(-RAIN_AREA, -RAIN_HEIGHT - 8.0, -RAIN_AREA),
			Vector3(RAIN_AREA * 2.0, RAIN_HEIGHT * 2.0 + 16.0, RAIN_AREA * 2.0)))
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

	_sound = AudioStreamPlayer.new()
	_sound.name = "RainSound"
	_sound.stream = AmbientEmitter.looping(load(RAIN_SOUND))
	_sound.bus = &"Ambiente"
	add_child(_sound)
	_set_strength(DEFAULT_STRENGTH)


func _make_particles(node_name: String, lifetime: float, bounds: AABB) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.emitting = false
	particles.lifetime = lifetime
	particles.local_coords = false  # as partículas ficam no mundo quando a caixa anda
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = bounds
	return particles


## Põe a forma da chuva da força dada (queda, vento, risco, quantidade).
func _set_strength(strength: String) -> void:
	if _kind != "garoa" or _rain == null:
		return
	var changed := strength != _strength
	_strength = strength
	var rain: Dictionary = RAIN_STRENGTHS[strength]
	var wind: Vector2 = rain["wind"]
	var speed: float = rain["speed"]
	var velocity := Vector3(wind.x, -speed, wind.y)
	var process := _rain.process_material as ParticleProcessMaterial
	process.direction = velocity.normalized()
	process.initial_velocity_min = velocity.length() * 0.9
	process.initial_velocity_max = velocity.length() * 1.1
	# Cai da caixa até um pouco abaixo do chão.
	_rain.lifetime = (RAIN_HEIGHT + 3.0) / (speed * 0.9)
	_streak_material.set_shader_parameter("fall_direction", velocity.normalized())
	_streak_material.set_shader_parameter("streak_length", rain["length"])
	_streak_material.set_shader_parameter("streak_width", rain["width"])
	_update_tint()
	if changed and is_inside_tree():
		_apply_amount()


## A tinta dos riscos e dos respingos pela hora (à noite, bem mais escura).
func _update_tint() -> void:
	if _streak_material == null:
		return
	var color := RAIN_TINT_DAY.lerp(RAIN_TINT_NIGHT, _night)
	color.a = RAIN_STRENGTHS[_strength]["alpha"]
	_streak_material.set_shader_parameter("tint", color)
	var splash := color
	splash.a = lerpf(0.4, 0.3, _night)
	_splash_material.albedo_color = splash


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
