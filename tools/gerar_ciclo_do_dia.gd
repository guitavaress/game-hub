extends SceneTree
## Gera o dia em momentos (Fase 19.4): profiles/day_cycle.tres.
##
## Rodar à mão:
##   godot --headless --path . -s res://tools/gerar_ciclo_do_dia.gd
##   godot --headless --path . -s res://tools/gerar_ciclo_do_dia.gd -- --refazer
##
## Sem argumento, só grava se o arquivo ainda NÃO existe. Para regravar de
## propósito, passe --refazer. Afinar é aqui, e não no Inspector: o
## check_day_cycle confere que o arquivo é o que este gerador faz.
##
## O ponto de partida é o dia de hoje: hoje(hora) refaz a conta do DayNight
## até a Fase 19.3 (três estados: dia, pôr do sol e noite). Os momentos que já
## existiam (madrugada, meio-dia, pôr do sol, anoitecer, noite) são essa conta
## na hora deles, sem mudar nada; os novos (nascer do sol, manhã e tarde)
## partem dela e mudam só o que os faz diferentes.

const CAMINHO: String = "res://profiles/day_cycle.tres"

## O dia até a 19.3 (worlds/city/day_night.gd), para hoje() refazer a conta.
const DAY_SUN_COLOR: Color = Color("FFEFD9")
const SUNSET_SUN_COLOR: Color = Color("FF9A5C")
const MOON_COLOR: Color = Color(0.55, 0.65, 1.0)
const DAY_SUN_ENERGY: float = 1.5
const SUNSET_SUN_ENERGY: float = 1.2
const MOON_ENERGY: float = 0.45
const SKY3D_SUN_ENERGY: float = 1.5
const DAY_SHADOW_OPACITY: float = 0.8
const SUNSET_SHADOW_OPACITY: float = 0.8
const NIGHT_SHADOW_OPACITY: float = 0.5
const DAY_EXPOSURE_EV: float = 0.25
const SUNSET_EXPOSURE_EV: float = 0.2
const NIGHT_EXPOSURE_EV: float = 0.0
const DAY_SKY_ENERGY: float = 1.0
const NIGHT_SKY_ENERGY: float = 0.45
const DAY_FOG_DENSITY: float = 0.0009
const SUNSET_FOG_DENSITY: float = 0.002
const NIGHT_FOG_DENSITY: float = 0.005
const DAY_FOG_COLOR: Color = Color(0.72, 0.78, 0.86)
const SUNSET_FOG_COLOR: Color = Color("E8A07A")
const NIGHT_FOG_COLOR: Color = Color("1E2C3A")
const DAY_FOG_SKY_AFFECT: float = 0.15
const NIGHT_FOG_SKY_AFFECT: float = 0.35
const NIGHT_AMBIENT: float = 0.3
const SKY3D_NIGHT_AMBIENT: float = 1.1
const DAY_AMBIENT: float = 0.45
const DAY_AGX_CONTRAST: float = 1.55
const NIGHT_AGX_CONTRAST: float = 1.25
const DAY_SATURATION: float = 1.2


func _initialize() -> void:
	var refazer: bool = OS.get_cmdline_user_args().has("--refazer")
	if FileAccess.file_exists(CAMINHO) and not refazer:
		print("%s já existe: fica como está (use --refazer para regravar)." % CAMINHO)
		quit(0)
		return
	var cycle: DayCycleSpec = ciclo()
	var problems: PackedStringArray = cycle.problems()
	if not problems.is_empty():
		push_error("O ciclo tem problemas: %s" % ", ".join(problems))
		quit(1)
		return
	var error: int = ResourceSaver.save(cycle, CAMINHO)
	print("Gravado: %s (resultado %d)" % [CAMINHO, error])
	quit(0 if error == OK else 1)


## Os momentos do dia, em ordem de hora.
static func ciclo() -> DayCycleSpec:
	var cycle := DayCycleSpec.new()
	cycle.moments.append(_momento("madrugada", "Madrugada", 5.5))
	cycle.moments.append(_nascer())
	cycle.moments.append(_manha())
	var noon: DayMoment = _momento("meio-dia", "Meio-dia", 11.0)
	noon.hold_hours = 3.5  # das 11h às 14h30, o dia da Fase 17.6 sem mudança
	cycle.moments.append(noon)
	cycle.moments.append(_tarde())
	cycle.moments.append(_momento("por-do-sol", "Pôr do sol", 18.0))
	cycle.moments.append(_momento("anoitecer", "Anoitecer", 18.5))
	cycle.moments.append(_momento("noite", "Noite", 19.0))
	return cycle


## Um momento com os valores de hoje na hora dele.
static func _momento(id: String, display_name: String, hour: float) -> DayMoment:
	var moment: DayMoment = hoje(hour)
	moment.id = id
	moment.display_name = display_name
	return moment


## O nascer do sol: a foto do pôr do sol com o brilho do lado leste (o
## DayNight já gira a foto de manhã), num tom mais rosado que o pôr do sol.
static func _nascer() -> DayMoment:
	var moment: DayMoment = _momento("nascer", "Nascer do sol", 6.5)
	# Rosa quente, e não lilás: com azul demais o céu de fotos ficava roxo.
	moment.sky_tint = Color(1.0, 0.88, 0.86)
	moment.sun_color = moment.sun_color.lerp(Color("FF9C94"), 0.3)
	moment.fog_color = moment.fog_color.lerp(Color("E8A49C"), 0.35)
	moment.sky3d_sun_color = Color("FFD0CC")
	return moment


## A manhã: luz fria e limpa (sol branco-azulado, menos névoa, cor um pouco
## menos carregada que a do meio-dia).
static func _manha() -> DayMoment:
	var moment: DayMoment = _momento("manha", "Manhã", 8.5)
	moment.sky_tint = Color(0.96, 0.99, 1.03)
	moment.sun_color = Color("F3F4FF")
	moment.sun_energy = 1.45
	moment.sky3d_sun_color = Color("F3F4FF")
	moment.sky3d_sun_energy = 1.45
	moment.fog_density = 0.0006
	moment.fog_color = Color(0.7, 0.78, 0.9)
	moment.saturation = 1.15
	return moment


## A tarde: luz dourada e sombras longas (o sol já está baixo; a sombra fica
## mais marcada, a névoa e o céu esquentam).
static func _tarde() -> DayMoment:
	var moment: DayMoment = _momento("tarde", "Tarde", 16.25)
	moment.sky_tint = Color(1.04, 0.98, 0.88)
	moment.sun_color = Color("FFD49A")
	moment.sun_energy = 1.55
	moment.shadow_opacity = 0.85
	moment.sky3d_sun_color = Color("FFD49A")
	moment.sky3d_sun_energy = 1.55
	moment.fog_density = 0.0011
	moment.fog_color = Color(0.82, 0.78, 0.7)
	moment.saturation = 1.25
	return moment


## O dia até a Fase 19.3, na hora dada: a mesma conta que o DayNight fazia
## (três estados misturados pelos pesos das fotos do céu). Serve de ponto de
## partida aqui e de referência no tests/check_day_cycle.gd.
static func hoje(hour: float) -> DayMoment:
	var night: float = 1.0 - clampf(smoothstep(5.5, 7.0, hour) - smoothstep(17.5, 19.0, hour), 0.0, 1.0)
	var daylight: float = 1.0 - night
	var arc: float = clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var low_sun: float = 1.0 - sin(arc * PI)
	var sunset: float = clampf((low_sun - 0.6) / 0.35, 0.0, 1.0) * daylight
	var day_weight: float = maxf(daylight - sunset, 0.0)
	var night_weight: float = smoothstep(0.5, 1.0, night)
	var sunset_weight: float = maxf(1.0 - day_weight - night_weight, 0.0)
	var weights := Vector3(day_weight, sunset_weight, night_weight)

	var moment := DayMoment.new()
	moment.hour = hour
	moment.sky_day = day_weight
	moment.sky_sunset = sunset_weight
	moment.sky_night = night_weight
	moment.sky_energy = lerpf(NIGHT_SKY_ENERGY, DAY_SKY_ENERGY, daylight)
	moment.sky_tint = Color.WHITE
	moment.sun_color = MOON_COLOR.lerp(DAY_SUN_COLOR.lerp(SUNSET_SUN_COLOR, sunset), daylight)
	moment.sun_energy = lerpf(MOON_ENERGY, lerpf(DAY_SUN_ENERGY, SUNSET_SUN_ENERGY, sunset), daylight)
	moment.shadow_opacity = _mix3(weights, DAY_SHADOW_OPACITY, SUNSET_SHADOW_OPACITY, NIGHT_SHADOW_OPACITY)
	moment.sky3d_sun_energy = lerpf(1.0, SKY3D_SUN_ENERGY, day_weight)
	moment.sky3d_sun_color = Color.WHITE.lerp(DAY_SUN_COLOR, day_weight)
	moment.ambient_sky3d = lerpf(SKY3D_NIGHT_AMBIENT, 1.0, daylight) * lerpf(1.0, DAY_AMBIENT, day_weight)
	moment.moonlight = night_weight
	moment.exposure_ev = _mix3(weights, DAY_EXPOSURE_EV, SUNSET_EXPOSURE_EV, NIGHT_EXPOSURE_EV)
	moment.fog_density = _mix3(weights, DAY_FOG_DENSITY, SUNSET_FOG_DENSITY, NIGHT_FOG_DENSITY)
	moment.fog_color = DAY_FOG_COLOR * day_weight + SUNSET_FOG_COLOR * sunset_weight + NIGHT_FOG_COLOR * night_weight
	moment.fog_sky_affect = lerpf(DAY_FOG_SKY_AFFECT, NIGHT_FOG_SKY_AFFECT, night_weight)
	moment.ambient = lerpf(NIGHT_AMBIENT, 1.0, daylight) * lerpf(1.0, DAY_AMBIENT, day_weight)
	moment.agx_contrast = lerpf(NIGHT_AGX_CONTRAST, DAY_AGX_CONTRAST, day_weight)
	moment.saturation = lerpf(1.0, DAY_SATURATION, day_weight)
	moment.glow = lerpf(1.1, 0.6, daylight)
	return moment


static func _mix3(weights: Vector3, day: float, sunset: float, night: float) -> float:
	var total: float = maxf(weights.x + weights.y + weights.z, 0.0001)
	return (day * weights.x + sunset * weights.y + night * weights.z) / total
