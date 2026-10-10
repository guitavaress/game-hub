class_name DistrictWeather
extends Node3D
## Clima de um bairro (Fase 7.6): hoje, a GAROA (chuva fina).
##
## Um só DistrictWeather por bairro, e uma só caixa de partículas que ACOMPANHA
## o jogador enquanto ele está dentro da área do bairro (e é noite, se o clima
## for "só à noite"). Assim o custo não depende do tamanho do bairro. Nunca
## mexe na neblina nem no Environment da cidade: só liga e desliga as gotas.
##
## A quantidade de gotas segue a qualidade gráfica (GraphicsQuality.weather_amount).
## O grupo "city_night" avisa a hora (set_night).

## Gotas com a qualidade Alta e intensidade 1.0.
const BASE_AMOUNT: int = 900
## Tamanho da caixa de onde a chuva cai (x, z) e altura do ponto de saída.
const RAIN_AREA: float = 30.0
const RAIN_HEIGHT: float = 10.0
const FALL_SPEED: float = 14.0
const DROP_COLOR: Color = Color(0.8, 0.88, 1.0, 0.45)

## Onde o bairro fica (x, z em metros, no mundo).
var area: Rect2 = Rect2()
var spec: WeatherSpec

var _night: float = 0.0
var _rain: GPUParticles3D
var _player: Node3D


## Chove agora? (dentro da área, e à noite se o clima pedir.)
func is_raining() -> bool:
	return _rain != null and _rain.emitting


func set_night(night: float) -> void:
	_night = night
	_refresh()


func _ready() -> void:
	add_to_group("city_night")
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.emitting = false
	_rain.lifetime = (RAIN_HEIGHT + 6.0) / FALL_SPEED
	_rain.local_coords = false  # as gotas ficam no mundo quando a caixa anda
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.visibility_aabb = AABB(Vector3(-RAIN_AREA, -RAIN_HEIGHT - 8.0, -RAIN_AREA), Vector3(RAIN_AREA * 2.0, RAIN_HEIGHT * 2.0 + 16.0, RAIN_AREA * 2.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(RAIN_AREA / 2.0, 0.2, RAIN_AREA / 2.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 2.0
	process.initial_velocity_min = FALL_SPEED
	process.initial_velocity_max = FALL_SPEED * 1.2
	process.gravity = Vector3.ZERO
	_rain.process_material = process

	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.6, 0.015)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = DROP_COLOR
	drop.material = material
	_rain.draw_pass_1 = drop
	add_child(_rain)

	AppConfig.settings_changed.connect(_on_settings_changed)
	_apply_amount()
	set_process(true)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	_rain.global_position = _player.global_position + Vector3(0.0, RAIN_HEIGHT, 0.0)
	_refresh()


func _refresh() -> void:
	if _rain == null:
		return
	var inside := _player != null and area.has_point(Vector2(_player.global_position.x, _player.global_position.z))
	var dark := _night > 0.5 or spec == null or not spec.night_only
	_rain.emitting = inside and dark and spec != null


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		_apply_amount()


func _apply_amount() -> void:
	var intensity := spec.intensity if spec != null else 1.0
	_rain.amount = maxi(1, roundi(BASE_AMOUNT * intensity * GraphicsQuality.weather_amount(AppConfig.get_quality())))
