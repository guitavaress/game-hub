class_name DayNight
extends Node
## Dia e noite seguindo o RELÓGIO do PC.
##
## A cada segundo, olha a hora e ajusta o sol (posição, cor e força), as cores
## do céu e a luz ambiente. Quando escurece, avisa pelo sinal night_changed
## (0 = dia, 1 = noite), e a cidade acende os postes, as janelas etc.
##
##   - 06:00 a 07:00: amanhecer (sol baixo e alaranjado)
##   - 07:00 a 17:30: dia
##   - 17:30 a 19:00: entardecer
##   - 19:00 a 05:30: noite (luz fraca e azulada da "lua")
##
## F8 adianta o relógio da cidade em 3 horas (para testar sem esperar).

## Quanto está de noite: 0.0 = dia claro, 1.0 = noite fechada.
signal night_changed(night: float)
## O relógio da cidade foi adiantado com F8 (hora nova, de 0 a 24).
signal clock_advanced(hour: float)

const UPDATE_INTERVAL: float = 1.0
const HOURS_PER_F8: float = 3.0

# Cores do céu: dia, pôr do sol e noite.
const DAY_SKY_TOP: Color = Color(0.36, 0.53, 0.84)
const DAY_SKY_HORIZON: Color = Color(0.66, 0.76, 0.9)
const SUNSET_SKY_HORIZON: Color = Color(0.98, 0.58, 0.34)
const NIGHT_SKY_TOP: Color = Color(0.02, 0.03, 0.08)
const NIGHT_SKY_HORIZON: Color = Color(0.07, 0.09, 0.17)
const DAY_SUN_COLOR: Color = Color(1.0, 0.97, 0.9)
const SUNSET_SUN_COLOR: Color = Color(1.0, 0.62, 0.35)
const MOON_COLOR: Color = Color(0.6, 0.7, 1.0)

## Quem este relógio controla (a cidade preenche antes de adicionar à cena).
var environment: Environment
var sky_material: ProceduralSkyMaterial
var sun: DirectionalLight3D

## Horas somadas ao relógio do PC com F8.
var hour_offset: float = 0.0

var _night: float = -1.0


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = UPDATE_INTERVAL
	timer.timeout.connect(update_now)
	add_child(timer)
	timer.start()
	update_now()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advance_time"):
		hour_offset = fposmod(hour_offset + HOURS_PER_F8, 24.0)
		update_now()
		clock_advanced.emit(current_hour())


## Hora da cidade, de 0.0 a 24.0 (ex.: 18.5 = 18:30).
func current_hour() -> float:
	var now := Time.get_time_dict_from_system()
	var hour: float = now["hour"] + now["minute"] / 60.0 + now["second"] / 3600.0
	return fposmod(hour + hour_offset, 24.0)


## Quanto está de noite (0 a 1) na hora dada.
static func night_amount(hour: float) -> float:
	var daylight := smoothstep(5.5, 7.0, hour) - smoothstep(17.5, 19.0, hour)
	return 1.0 - clampf(daylight, 0.0, 1.0)


func update_now() -> void:
	var hour := current_hour()
	var night := night_amount(hour)
	var daylight := 1.0 - night

	# Sol: nasce no leste às 6h, fica no alto ao meio-dia e se põe no oeste às 18h.
	var arc := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var elevation := deg_to_rad(8.0 + 57.0 * sin(arc * PI))
	var sun_yaw := lerpf(deg_to_rad(90.0), deg_to_rad(-90.0), arc)
	# Perto do horizonte (amanhecer/entardecer), a luz fica alaranjada.
	var low_sun := 1.0 - sin(arc * PI)
	var sunset := clampf(low_sun * 1.4, 0.0, 1.0) * daylight

	var moon_elevation := deg_to_rad(50.0)
	var moon_yaw := deg_to_rad(30.0)
	sun.rotation = Vector3(-lerpf(moon_elevation, elevation, daylight), lerp_angle(moon_yaw, sun_yaw, daylight), 0.0)
	sun.light_color = MOON_COLOR.lerp(DAY_SUN_COLOR.lerp(SUNSET_SUN_COLOR, sunset), daylight)
	sun.light_energy = lerpf(0.25, 1.0, daylight)

	# Céu.
	sky_material.sky_top_color = NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, daylight)
	var horizon := DAY_SKY_HORIZON.lerp(SUNSET_SKY_HORIZON, sunset)
	sky_material.sky_horizon_color = NIGHT_SKY_HORIZON.lerp(horizon, daylight)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = Color(0.05, 0.05, 0.06).lerp(Color(0.2, 0.17, 0.13), daylight)

	# Luz ambiente mais fraca e brilho (glow) mais forte à noite.
	environment.ambient_light_energy = lerpf(0.35, 1.0, daylight)
	environment.glow_intensity = lerpf(1.2, 0.8, daylight)

	if absf(night - _night) > 0.005:
		_night = night
		night_changed.emit(night)


func get_night() -> float:
	return maxf(_night, 0.0)
