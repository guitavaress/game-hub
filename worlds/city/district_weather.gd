class_name DistrictWeather
extends Node3D
## Clima de um bairro: garoa (chuva fina) ou neve (Fase 15.11).
##
## Um só DistrictWeather por bairro, e uma só caixa de partículas que ACOMPANHA
## o jogador enquanto ele está dentro da área do bairro (e é noite, se o clima
## for "só à noite"). Assim o custo não depende do tamanho do bairro. Nunca
## mexe na neblina nem no Environment da cidade: só liga e desliga a precipitação.
##
## A quantidade de partículas segue a qualidade gráfica (GraphicsQuality.weather_amount).
## O grupo "city_night" avisa a hora (set_night).

## Valores originais da garoa, com a qualidade Alta e intensidade 1.0.
const BASE_AMOUNT: int = 900
## Tamanho da caixa de onde a chuva cai (x, z) e altura do ponto de saída.
const RAIN_AREA: float = 30.0
const RAIN_HEIGHT: float = 10.0
const FALL_SPEED: float = 14.0
const DROP_COLOR: Color = Color(0.8, 0.88, 1.0, 0.45)

## Aparência por tipo de clima. O perfil escolhe o tipo, nunca o bairro.
const WEATHER_TYPES: Dictionary = {
	"garoa": {
		"amount": BASE_AMOUNT, "area": RAIN_AREA, "height": RAIN_HEIGHT,
		"speed_min": FALL_SPEED, "speed_max": FALL_SPEED * 1.2,
		"direction": Vector3(0.0, -1.0, 0.0), "spread": 2.0,
		"shape": "box", "size": Vector3(0.015, 0.6, 0.015), "color": DROP_COLOR,
	},
	"neve": {
		"amount": 500, "area": 30.0, "height": 10.0,
		"speed_min": 1.5, "speed_max": 2.5,
		"direction": Vector3(0.08, -1.0, 0.04), "spread": 12.0,
		"shape": "quad", "size": Vector3(0.09, 0.09, 0.0),
		"color": Color(0.76, 0.8, 0.84, 0.65),
	},
}

## Onde o bairro fica (x, z em metros, no mundo): as zonas dele no CityMap
## (quarteirões e vagas, cada uma com meia rua em volta).
var areas: Array[Rect2] = []
var spec: WeatherSpec

var _night: float = 0.0
var _rain: GPUParticles3D
var _player: Node3D
var _kind: String = "garoa"


## Tipo aplicado na criação; spec nulo usa a aparência padrão, sem emitir.
func current_kind() -> String:
	return _kind


## Há precipitação agora (garoa ou neve)? Respeita a área e o horário.
func is_raining() -> bool:
	return _rain != null and _rain.emitting


func set_night(night: float) -> void:
	_night = night
	_refresh()


func _ready() -> void:
	add_to_group("city_night")
	if spec != null and WEATHER_TYPES.has(spec.kind):
		_kind = spec.kind
	var appearance: Dictionary = WEATHER_TYPES[_kind]
	var area: float = appearance["area"]
	var height: float = appearance["height"]
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.emitting = false
	_rain.lifetime = (height + 6.0) / float(appearance["speed_min"])
	_rain.local_coords = false  # as partículas ficam no mundo quando a caixa anda
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.visibility_aabb = AABB(Vector3(-area, -height - 8.0, -area), Vector3(area * 2.0, height * 2.0 + 16.0, area * 2.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(area / 2.0, 0.2, area / 2.0)
	process.direction = appearance["direction"]
	process.spread = appearance["spread"]
	process.initial_velocity_min = appearance["speed_min"]
	process.initial_velocity_max = appearance["speed_max"]
	process.gravity = Vector3.ZERO
	_rain.process_material = process

	var drop: PrimitiveMesh
	var size: Vector3 = appearance["size"]
	if appearance["shape"] == "quad":
		var flake := QuadMesh.new()
		flake.size = Vector2(size.x, size.y)
		drop = flake
	else:
		var streak := BoxMesh.new()
		streak.size = size
		drop = streak
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = appearance["color"]
	if appearance["shape"] == "quad":
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
	_rain.global_position = _player.global_position + Vector3(0.0, WEATHER_TYPES[_kind]["height"], 0.0)
	_refresh()


func _refresh() -> void:
	if _rain == null:
		return
	var inside := _player != null and _is_inside(Vector2(_player.global_position.x, _player.global_position.z))
	var dark := _night > 0.5 or spec == null or not spec.night_only
	_rain.emitting = inside and dark and spec != null


func _is_inside(point: Vector2) -> bool:
	for rect in areas:
		if rect.has_point(point):
			return true
	return false


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		_apply_amount()


func _apply_amount() -> void:
	var intensity := spec.intensity if spec != null else 1.0
	var base_amount: int = WEATHER_TYPES[_kind]["amount"]
	_rain.amount = maxi(1, roundi(base_amount * intensity * GraphicsQuality.weather_amount(AppConfig.get_quality())))
