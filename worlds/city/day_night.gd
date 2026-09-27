class_name DayNight
extends Node
## Dia e noite seguindo o RELÓGIO do PC.
##
## A cada segundo, olha a hora e ajusta o sol (posição, cor e força), o céu
## (mistura de três fotos HDRI: dia, pôr do sol e noite, veja sky_blend.gdshader),
## a neblina e a luz ambiente. Quando escurece, avisa pelo sinal night_changed
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

const DAY_SUN_COLOR: Color = Color(1.0, 0.96, 0.9)
const SUNSET_SUN_COLOR: Color = Color(1.0, 0.6, 0.35)
const MOON_COLOR: Color = Color(0.55, 0.65, 1.0)
## Brilho do céu de dia e de noite (a foto da noite já é escura).
const DAY_SKY_ENERGY: float = 1.0
const NIGHT_SKY_ENERGY: float = 0.45
## Neblina: leve de dia, mais densa e azulada à noite (dá "clima" às luzes).
const DAY_FOG_DENSITY: float = 0.0015
const NIGHT_FOG_DENSITY: float = 0.006
const DAY_FOG_COLOR: Color = Color(0.72, 0.78, 0.86)
const NIGHT_FOG_COLOR: Color = Color(0.03, 0.04, 0.07)

## Quem este relógio controla (a cidade preenche antes de adicionar à cena).
var environment: Environment
var sky_material: ShaderMaterial
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
	# "sunset" sobe só na última hora e meia de sol (e na primeira da manhã).
	var low_sun := 1.0 - sin(arc * PI)
	var sunset := clampf((low_sun - 0.6) / 0.35, 0.0, 1.0) * daylight

	var moon_elevation := deg_to_rad(50.0)
	var moon_yaw := deg_to_rad(30.0)
	sun.rotation = Vector3(-lerpf(moon_elevation, elevation, daylight), lerp_angle(moon_yaw, sun_yaw, daylight), 0.0)
	sun.light_color = MOON_COLOR.lerp(DAY_SUN_COLOR.lerp(SUNSET_SUN_COLOR, sunset), daylight)
	sun.light_energy = lerpf(0.25, 1.0, daylight)

	# Céu: quanto de cada foto (dia, pôr do sol, noite) aparece agora.
	# As estrelas só entram quando a noite já está pela metade (senão elas
	# apareceriam no meio do pôr do sol); o resto fica com o pôr do sol.
	var day_weight := maxf(daylight - sunset, 0.0)
	var night_weight := smoothstep(0.5, 1.0, night)
	var sunset_weight := maxf(1.0 - day_weight - night_weight, 0.0)
	sky_material.set_shader_parameter("day_weight", day_weight)
	sky_material.set_shader_parameter("sunset_weight", sunset_weight)
	sky_material.set_shader_parameter("night_weight", night_weight)
	sky_material.set_shader_parameter("energy", lerpf(NIGHT_SKY_ENERGY, DAY_SKY_ENERGY, daylight))

	# Neblina, luz ambiente e brilho (glow).
	environment.fog_density = lerpf(NIGHT_FOG_DENSITY, DAY_FOG_DENSITY, daylight)
	environment.fog_light_color = NIGHT_FOG_COLOR.lerp(DAY_FOG_COLOR.lerp(SUNSET_SUN_COLOR, sunset * 0.5), daylight)
	environment.ambient_light_energy = lerpf(0.2, 1.0, daylight)
	environment.glow_intensity = lerpf(1.1, 0.6, daylight)

	if absf(night - _night) > 0.005:
		_night = night
		night_changed.emit(night)


func get_night() -> float:
	return maxf(_night, 0.0)
