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
##   - 07:00 a 17:30: dia (exposição -0,3 EV, sombras suaves)
##   - 17:30 a 19:00: pôr do sol (sol #FF9A5C, neblina quente, +0,2 EV);
##     as janelas acendem uma a uma até 18h30 e os postes às 18h
##   - 19:00 a 05:30: noite (luz fraca e azulada da "lua", neblina densa)
##
## F8 adianta o relógio da cidade em 3 horas (para testar sem esperar).

## Quanto está de noite: 0.0 = dia claro, 1.0 = noite fechada.
signal night_changed(night: float)
## O relógio da cidade foi adiantado com F8 (hora nova, de 0 a 24).
signal clock_advanced(hour: float)

const UPDATE_INTERVAL: float = 1.0
const HOURS_PER_F8: float = 3.0
## Horas usadas quando a opção "Hora" é "dia" ou "noite" (menu de pausa).
const FIXED_DAY_HOUR: float = 14.0
const FIXED_NIGHT_HOUR: float = 22.0

## Os três "climas" do dia. Cada valor da cena é uma mistura dos três,
## com os mesmos pesos que misturam as fotos do céu.
const DAY_SUN_COLOR: Color = Color("FFF4E5")
const SUNSET_SUN_COLOR: Color = Color("FF9A5C")
const MOON_COLOR: Color = Color(0.55, 0.65, 1.0)
const DAY_SUN_ENERGY: float = 1.0
const SUNSET_SUN_ENERGY: float = 1.2
const MOON_ENERGY: float = 0.25
## Opacidade das sombras: suaves de dia, longas e marcadas no pôr do sol.
const DAY_SHADOW_OPACITY: float = 0.4
const SUNSET_SHADOW_OPACITY: float = 0.8
const NIGHT_SHADOW_OPACITY: float = 0.5
## Exposição da câmera, em "EV" (+1 = dobro de luz): o dia estava lavado.
const DAY_EXPOSURE_EV: float = -0.3
const SUNSET_EXPOSURE_EV: float = 0.2
const NIGHT_EXPOSURE_EV: float = 0.0
## Brilho do céu de dia e de noite (a foto da noite já é escura).
const DAY_SKY_ENERGY: float = 1.0
const NIGHT_SKY_ENERGY: float = 0.45
## Neblina: leve de dia, quente no pôr do sol, densa e azulada à noite.
const DAY_FOG_DENSITY: float = 0.0015
const SUNSET_FOG_DENSITY: float = 0.002
const NIGHT_FOG_DENSITY: float = 0.006
const DAY_FOG_COLOR: Color = Color(0.72, 0.78, 0.86)
const SUNSET_FOG_COLOR: Color = Color("E8A07A")
const NIGHT_FOG_COLOR: Color = Color("080A12")

## Quem este relógio controla (a cidade preenche antes de adicionar à cena).
var environment: Environment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D

## Horas somadas ao relógio do PC com F8.
var hour_offset: float = 0.0
## Onde fica o brilho do sol na foto do pôr do sol (0 a 1, da esquerda para a
## direita da foto panorâmica). O céu gira essa foto para o brilho ficar do lado
## do sol: oeste à tarde, leste de manhã. Quem escolhe a foto informa.
var sunset_glow_u: float = 0.5

var _night: float = -1.0


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = UPDATE_INTERVAL
	timer.timeout.connect(update_now)
	add_child(timer)
	timer.start()
	AppConfig.settings_changed.connect(_on_settings_changed)
	update_now()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advance_time"):
		hour_offset = fposmod(hour_offset + HOURS_PER_F8, 24.0)
		update_now()
		clock_advanced.emit(current_hour())


## Hora da cidade, de 0.0 a 24.0 (ex.: 18.5 = 18:30). Segue o relógio do PC,
## ou fica fixa de dia/de noite (menu de pausa, opção "Hora"); F8 soma horas.
func current_hour() -> float:
	var hour: float
	match AppConfig.get_time_of_day():
		"dia":
			hour = FIXED_DAY_HOUR
		"noite":
			hour = FIXED_NIGHT_HOUR
		_:
			var now := Time.get_time_dict_from_system()
			hour = now["hour"] + now["minute"] / 60.0 + now["second"] / 3600.0
	return fposmod(hour + hour_offset, 24.0)


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "time_of_day":
		hour_offset = 0.0  # trocou o modo: começa do zero (sem as horas do F8)
		update_now()


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

	# Céu: quanto de cada foto (dia, pôr do sol, noite) aparece agora.
	# As estrelas só entram quando a noite já está pela metade (senão elas
	# apareceriam no meio do pôr do sol); o resto fica com o pôr do sol.
	var day_weight := maxf(daylight - sunset, 0.0)
	var night_weight := smoothstep(0.5, 1.0, night)
	var sunset_weight := maxf(1.0 - day_weight - night_weight, 0.0)
	var weights := Vector3(day_weight, sunset_weight, night_weight)
	sky_material.set_shader_parameter("day_weight", day_weight)
	sky_material.set_shader_parameter("sunset_weight", sunset_weight)
	sky_material.set_shader_parameter("night_weight", night_weight)
	sky_material.set_shader_parameter("energy", lerpf(NIGHT_SKY_ENERGY, DAY_SKY_ENERGY, daylight))
	# Na foto, o oeste (-X) fica em u = 0,25 e o leste (+X) em u = 0,75.
	var sun_side_u := 0.25 if hour >= 12.0 else 0.75
	sky_material.set_shader_parameter("sunset_rotation", sunset_glow_u - sun_side_u)

	# Sol (ou "lua", à noite).
	var moon_elevation := deg_to_rad(50.0)
	var moon_yaw := deg_to_rad(30.0)
	sun.rotation = Vector3(-lerpf(moon_elevation, elevation, daylight), lerp_angle(moon_yaw, sun_yaw, daylight), 0.0)
	sun.light_color = MOON_COLOR.lerp(DAY_SUN_COLOR.lerp(SUNSET_SUN_COLOR, sunset), daylight)
	sun.light_energy = lerpf(MOON_ENERGY, lerpf(DAY_SUN_ENERGY, SUNSET_SUN_ENERGY, sunset), daylight)
	sun.shadow_opacity = _mix3(weights, DAY_SHADOW_OPACITY, SUNSET_SHADOW_OPACITY, NIGHT_SHADOW_OPACITY)

	# Exposição, neblina, luz ambiente e brilho (glow).
	environment.tonemap_exposure = pow(2.0, _mix3(weights, DAY_EXPOSURE_EV, SUNSET_EXPOSURE_EV, NIGHT_EXPOSURE_EV))
	environment.fog_density = _mix3(weights, DAY_FOG_DENSITY, SUNSET_FOG_DENSITY, NIGHT_FOG_DENSITY)
	environment.fog_light_color = DAY_FOG_COLOR * weights.x + SUNSET_FOG_COLOR * weights.y \
			+ NIGHT_FOG_COLOR * weights.z
	environment.ambient_light_energy = lerpf(0.2, 1.0, daylight)
	environment.glow_intensity = lerpf(1.1, 0.6, daylight)

	if absf(night - _night) > 0.005:
		_night = night
		night_changed.emit(night)


func get_night() -> float:
	return maxf(_night, 0.0)


## Mistura três valores (dia, pôr do sol, noite) com os pesos do céu.
static func _mix3(weights: Vector3, day: float, sunset: float, night: float) -> float:
	var total := maxf(weights.x + weights.y + weights.z, 0.0001)
	return (day * weights.x + sunset * weights.y + night * weights.z) / total
