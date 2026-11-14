class_name DayNight
extends Node
## Dia e noite seguindo o RELÓGIO do PC.
##
## A cada segundo, olha a hora e ajusta o sol (posição, cor e força), o céu
## (mistura de três fotos HDRI: dia, pôr do sol e noite, veja sky_blend.gdshader),
## a neblina e a luz ambiente. Quando escurece, avisa pelo sinal night_changed
## (0 = dia, 1 = noite), e a cidade acende os postes, as janelas etc.
##
## O dia é uma lista de MOMENTOS (Fase 19.4; profiles/day_cycle.tres, veja
## DayCycleSpec): madrugada (5h30), nascer do sol (6h30, rosado, com o brilho
## no leste), manhã (8h30, luz fria e limpa), meio-dia (11h às 14h30, o dia da
## Fase 17.6), tarde (16h15, luz dourada), pôr do sol (18h), anoitecer (18h30)
## e noite (19h). Este relógio só mistura o momento de antes com o de depois.
##
## O "quanto é noite" (night_amount) NÃO vem dos momentos e não mudou: os
## postes acendem às 18h e as janelas uma a uma até 18h30, como antes.
##
## F8 adianta o relógio da cidade em 3 horas (para testar sem esperar).
##
## O tempo (nublado, chuva) fecha o céu por cima do momento: veja
## set_weather_overlay (quem chama é o WeatherDirector, Fase 19.6).
##
## Com o céu "sky3d" (opção Céu do menu), o sol, a lua, as estrelas e o céu
## são do addon Sky3D: este relógio repassa a hora a ele, a força e a cor do
## sol do momento, e continua cuidando da neblina, da exposição e do aviso
## night_changed.

## Quanto está de noite: 0.0 = dia claro, 1.0 = noite fechada.
signal night_changed(night: float)
## O relógio da cidade foi adiantado com F8 (hora nova, de 0 a 24).
signal clock_advanced(hour: float)
## Entrou um momento novo do dia (o id do day_cycle.tres, ex.: "tarde"). Não
## sai na primeira hora aplicada, só nas trocas (revisão da 19.4: a janela da
## casa refaz o retrato da cidade).
signal moment_changed(id: String)

const UPDATE_INTERVAL: float = 1.0
const HOURS_PER_F8: float = 3.0
## Quanto tempo as 3 horas do F8 levam para passar (Fase 19.4).
const ADVANCE_SECONDS: float = 2.0
## Horas usadas quando a opção "Hora" é "dia" ou "noite" (menu de pausa).
const FIXED_DAY_HOUR: float = 14.0
const FIXED_NIGHT_HOUR: float = 22.0

## O luar (Fase 17.5): uma luz fraca e fria, do alto, sem sombra, que só existe
## à noite. No Sky3D a lua segue o céu de verdade (fase e hora em que nasce), e
## em muitas noites ela está abaixo do horizonte: sem o luar, a neve e o chão
## ficariam pretos. Quando a lua do Sky3D está no céu, o luar diminui o tanto
## que ela já ilumina (a soma fica parecida). No céu de fotos, a "lua" é o
## próprio sol da cena (a cor e a força da noite no ciclo), e o luar não é usado.
## Quanto dele acende em cada hora é o "moonlight" do momento (0 a 1).
const MOONLIGHT_COLOR: Color = Color(0.62, 0.72, 0.95)
const MOONLIGHT_ENERGY: float = 0.4
## De onde vem o luar: a mesma lua do céu de fotos (50° de altura).
const MOONLIGHT_ELEVATION_DEG: float = 50.0
const MOONLIGHT_YAW_DEG: float = 30.0
## O céu fechado (set_weather_overlay = 1): o que sobra da força do sol, da sombra e
## do brilho do céu; quanto a névoa engrossa e puxa para o cinza; quanto a cor
## perde de saturação.
const OVERCAST_SUN: float = 0.3
const OVERCAST_SHADOW: float = 0.35
const OVERCAST_SKY: float = 0.5
## Quanto a foto do céu perde a cor no céu fechado (0 a 1; sky_blend.gdshader).
const OVERCAST_SKY_GREY: float = 0.9
const OVERCAST_FOG: float = 2.6
const OVERCAST_FOG_GREY: Color = Color(0.56, 0.59, 0.63)
const OVERCAST_FOG_GREY_AMOUNT: float = 0.6
const OVERCAST_SATURATION: float = 0.78
## Quanto da névoa cobre o céu fechado (0 a 1).
const OVERCAST_SKY_FOG: float = 0.85
## No Sky3D, o céu fechado são as nuvens cobrindo quase tudo e o azul do ar
## puxado para o cinza (o reflexo no asfalto molhado vem desse céu).
const OVERCAST_SKY3D_CLOUDS: float = 0.95
const OVERCAST_SKY3D_TINT: Color = Color(0.62, 0.64, 0.67)

## O momento de agora (a mistura do de antes com o de depois). Antes da
## primeira hora, um meio-dia (os valores padrão do DayMoment).
var _moment: DayMoment = DayMoment.new()
## O céu fechado pelo tempo (0 a 1; Fase 19.6). Veja set_weather_overlay.
var _overcast: float = 0.0
## As nuvens e o tom do Sky3D antes do céu fechado (para voltar a eles).
var _sky3d_base: Dictionary = {}
var _fog_overlay_weight: float = 0.0
var _fog_overlay_scale: float = 1.0
var _fog_overlay_tint: Color = Color.WHITE
var _fog_overlay_tint_amount: float = 0.0
var _fog_overlay_height: float = 0.0
var _fog_overlay_height_density: float = 0.0
var _base_fog_height: float = 0.0
var _base_fog_height_density: float = 0.0

## Quem este relógio controla (a cidade preenche antes de adicionar à cena).
## Ao substituir o ambiente, mantém a mistura e guarda a altura original dele.
var environment: Environment:
	set(value):
		if environment == value:
			return
		environment = value
		if environment != null:
			_base_fog_height = environment.fog_height
			_base_fog_height_density = environment.fog_height_density
			_apply_fog()
var sky_material: ShaderMaterial
var sun: DirectionalLight3D
## O céu do addon Sky3D, quando é ele o céu (aí sky_material e sun ficam vazios).
var sky3d: Sky3D
## O luar (veja MOONLIGHT_ENERGY): a cidade cria junto com o Sky3D e põe aqui.
## Este relógio só regula a força e a direção.
var moonlight: DirectionalLight3D
## O dia em momentos. Vazio = o do perfil (Profiles.day_cycle()); um teste
## pode pôr outro.
var cycle: DayCycleSpec

## Horas somadas ao relógio do PC com F8. Quem muda de fora (o menu, um teste,
## a captura) interrompe a passagem do F8 que estiver andando.
var hour_offset: float = 0.0:
	set(value):
		hour_offset = value
		if not _advancing and _advance_tween != null:
			_advance_tween.kill()
			_advance_tween = null
## Onde fica o brilho do sol na foto do pôr do sol (0 a 1, da esquerda para a
## direita da foto panorâmica). O céu gira essa foto para o brilho ficar do lado
## do sol: oeste à tarde, leste de manhã. Quem escolhe a foto informa.
var sunset_glow_u: float = 0.5

var _night: float = -1.0
## O id do momento da última hora aplicada ("" antes da primeira).
var _moment_id: String = ""
## A passagem do F8 (veja advance_clock): o deslocamento sem dar a volta nas
## 24 h, até onde ele vai, e se é a própria passagem que mexe no hour_offset.
var _advance_tween: Tween
var _advance_value: float = 0.0
var _advance_target: float = 0.0
var _advancing: bool = false


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
		advance_clock(HOURS_PER_F8)


## Adianta o relógio da cidade (F8). As horas passam em ADVANCE_SECONDS por
## toque, e não de uma vez: a luz atravessa os momentos no caminho, sem pulo
## (Fase 19.4). Outro toque no meio soma mais horas ao fim da passagem. O aviso
## clock_advanced sai na hora, com a hora em que o relógio vai parar.
func advance_clock(hours: float) -> void:
	if _advance_tween != null and _advance_tween.is_valid():
		_advance_tween.kill()
		_advance_target += hours
	else:
		_advance_value = hour_offset
		_advance_target = hour_offset + hours
	clock_advanced.emit(fposmod(current_hour() + _advance_target - _advance_value, 24.0))
	if not is_inside_tree():
		_set_advance(_advance_target)
		return
	var seconds := ADVANCE_SECONDS * (_advance_target - _advance_value) / HOURS_PER_F8
	_advance_tween = create_tween()
	_advance_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_advance_tween.tween_method(_set_advance, _advance_value, _advance_target, seconds)
	_advance_tween.finished.connect(func() -> void: _advance_tween = null)


## Um passo da passagem do F8: põe o relógio no ponto e refaz a luz.
func _set_advance(value: float) -> void:
	_advance_value = value
	_advancing = true
	hour_offset = fposmod(value, 24.0)
	_advancing = false
	update_now()


## true enquanto o F8 está passando as horas.
func is_advancing() -> bool:
	return _advance_tween != null and _advance_tween.is_valid()


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
	apply_hour(current_hour())


## O dia em momentos que este relógio usa.
func get_cycle() -> DayCycleSpec:
	if cycle == null:
		cycle = Profiles.day_cycle()
	return cycle


## O momento do dia em que se está, ou o último que passou (ex.: "manha" às
## 10h, "tarde" às 17h). Os ids estão em profiles/day_cycle.tres.
func current_moment() -> String:
	return get_cycle().moment_at(current_hour()).id


## Como a cidade está agora: a mistura dos momentos na última hora aplicada
## (só leitura).
func get_moment() -> DayMoment:
	return _moment


## Põe a cidade na hora dada (0 a 24): o update_now usa a hora do relógio; um
## teste pode chamar direto, minuto a minuto.
func apply_hour(hour: float) -> void:
	var night := night_amount(hour)
	var daylight := 1.0 - night
	var moment := get_cycle().sample(hour)
	_moment = moment

	if sky3d != null:
		# O Sky3D calcula o sol, a lua e as estrelas pela hora e pela data.
		sky3d.current_time = hour
		sky3d.sun_energy = moment.sky3d_sun_energy * lerpf(1.0, OVERCAST_SUN, _overcast)
		_apply_sky3d_overcast()
		if sky3d.sky != null:
			sky3d.sky.sun_light_color = moment.sky3d_sun_color
	elif sky_material != null and sun != null:
		_apply_photo_sky(hour, daylight, moment)
	_apply_moonlight(moment.moonlight)

	# Exposição, neblina, luz ambiente e brilho (glow).
	environment.tonemap_exposure = pow(2.0, moment.exposure_ev)
	_apply_fog()
	environment.ambient_light_energy = moment.ambient_sky3d if sky3d != null else moment.ambient
	_apply_day_contrast(moment)
	environment.glow_intensity = moment.glow
	# Céu fechado: a névoa cinza cobre a maior parte da foto do céu.
	environment.fog_sky_affect = lerpf(moment.fog_sky_affect, OVERCAST_SKY_FOG, _overcast)

	if absf(night - _night) > 0.005:
		_night = night
		night_changed.emit(night)

	var id := get_cycle().moment_at(hour).id
	if id != _moment_id:
		var first := _moment_id.is_empty()
		_moment_id = id
		if not first:
			moment_changed.emit(id)


## O céu de fotos: mistura as três fotos e move o sol (ou a "lua") à mão.
func _apply_photo_sky(hour: float, daylight: float, moment: DayMoment) -> void:
	sky_material.set_shader_parameter("day_weight", moment.sky_day)
	sky_material.set_shader_parameter("sunset_weight", moment.sky_sunset)
	sky_material.set_shader_parameter("night_weight", moment.sky_night)
	sky_material.set_shader_parameter("energy", moment.sky_energy * lerpf(1.0, OVERCAST_SKY, _overcast))
	sky_material.set_shader_parameter("overcast_grey", OVERCAST_SKY_GREY * _overcast)
	sky_material.set_shader_parameter("tint", moment.sky_tint)
	# O brilho da foto do pôr do sol fica do lado do sol: leste de manhã (o
	# nascer do sol), oeste à tarde. Na foto, o oeste (-X) fica em u = 0,25 e o
	# leste (+X) em u = 0,75. A troca ao meio-dia não aparece: o peso da foto
	# do pôr do sol é zero lá.
	var sun_side_u := 0.25 if hour >= 12.0 else 0.75
	sky_material.set_shader_parameter("sunset_rotation", sunset_glow_u - sun_side_u)

	# Sol: nasce no leste às 6h, fica no alto ao meio-dia e se põe no oeste às
	# 18h (à tarde ele já está baixo: as sombras ficam longas). À noite, a
	# "lua" fica parada no alto; a passagem segue o "quanto é noite".
	var arc := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var elevation := deg_to_rad(8.0 + 57.0 * sin(arc * PI))
	var sun_yaw := lerpf(deg_to_rad(90.0), deg_to_rad(-90.0), arc)
	var moon_elevation := deg_to_rad(MOONLIGHT_ELEVATION_DEG)
	var moon_yaw := deg_to_rad(MOONLIGHT_YAW_DEG)
	sun.rotation = Vector3(-lerpf(moon_elevation, elevation, daylight), lerp_angle(moon_yaw, sun_yaw, daylight), 0.0)
	sun.light_color = moment.sun_color
	sun.light_energy = moment.sun_energy * lerpf(1.0, OVERCAST_SUN, _overcast)
	sun.shadow_opacity = moment.shadow_opacity * lerpf(1.0, OVERCAST_SHADOW, _overcast)


## O contraste e a saturação do momento (o dia com contraste é da Fase 17.6,
## a C2 da revisão: curva do AgX mais em "S" e cor viva; à noite, os valores
## padrão). O ajuste fica sempre ligado: ligar e desligar troca a variante do
## shader do tonemap, e a troca no meio do pôr do sol podia dar um tranco.
func _apply_day_contrast(moment: DayMoment) -> void:
	environment.tonemap_agx_contrast = moment.agx_contrast
	environment.adjustment_enabled = true
	environment.adjustment_saturation = moment.saturation * lerpf(1.0, OVERCAST_SATURATION, _overcast)


## O luar: acende com a noite (o "moonlight" do momento, que segue o peso das
## estrelas) e desconta a lua do Sky3D, se ela estiver no céu. Apagado, fica
## invisível (não custa nada).
func _apply_moonlight(weight: float) -> void:
	if moonlight == null:
		return
	var real_moon := 0.0
	if sky3d != null and sky3d.moon != null:
		real_moon = sky3d.moon.light_energy
	var energy := maxf(MOONLIGHT_ENERGY * weight - real_moon, 0.0)
	moonlight.light_energy = energy
	moonlight.light_color = MOONLIGHT_COLOR
	moonlight.rotation = Vector3(-deg_to_rad(MOONLIGHT_ELEVATION_DEG), deg_to_rad(MOONLIGHT_YAW_DEG), 0.0)
	moonlight.visible = energy > 0.001


## O TEMPO por cima do céu do momento (Fase 19.6; 0 = o céu do momento, 1 =
## fechado): menos sol e sombra mais fraca, céu mais escuro e cinza (nas fotos
## e no Sky3D, onde as nuvens cobrem quase tudo), névoa mais grossa e cinza,
## cor menos viva. Quem chama é o WeatherDirector (o tempo da cidade toda), que
## sobe e desce o valor aos poucos.
## O contrato: NÃO escreve no momento (get_moment() continua sendo o do
## relógio; no meio-dia parado ele é o próprio momento do day_cycle.tres) e com
## 0 tudo fica exatamente como sem tempo nenhum. A névoa do bioma
## (set_fog_overlay) vem por cima desta. A janela da casa refaz o retrato pelo
## aviso do WeatherDirector (weather_changed), e não por aqui.
func set_weather_overlay(cover: float) -> void:
	cover = clampf(cover, 0.0, 1.0)
	if cover == _overcast:
		return
	_overcast = cover
	if environment != null:
		apply_hour(current_hour())


## Quanto o tempo fecha o céu agora (0 a 1).
func get_weather_overlay() -> float:
	return _overcast


## O céu fechado no Sky3D: guarda as nuvens e o tom dele na primeira vez (de
## cada Sky3D) e mistura com os do céu fechado. Com 0, volta aos guardados.
func _apply_sky3d_overcast() -> void:
	var dome := sky3d.sky
	if dome == null:
		return
	if _sky3d_base.get("owner") != sky3d:
		if _overcast == 0.0:
			return
		_sky3d_base = {"owner": sky3d, "clouds": dome.cumulus_coverage, "tint": dome.atm_day_tint}
	var clouds := lerpf(_sky3d_base["clouds"], OVERCAST_SKY3D_CLOUDS, _overcast)
	if dome.cumulus_coverage != clouds:
		dome.cumulus_coverage = clouds
	var tint: Color = (_sky3d_base["tint"] as Color).lerp(OVERCAST_SKY3D_TINT, _overcast)
	if dome.atm_day_tint != tint:
		dome.atm_day_tint = tint


## Mistura sobre a névoa do relógio, sem multiplicar o resultado anterior.
## Os quatro primeiros argumentos bastam para névoa de profundidade.
## height é a cota global da bruma; density positiva concentra névoa embaixo.
func set_fog_overlay(weight: float, density_scale: float, tint: Color,
		tint_amount: float, height: float = 0.0, height_density: float = 0.0) -> void:
	_fog_overlay_weight = clampf(weight, 0.0, 1.0)
	_fog_overlay_scale = maxf(density_scale, 0.0)
	_fog_overlay_tint = tint
	_fog_overlay_tint_amount = clampf(tint_amount, 0.0, 1.0)
	_fog_overlay_height = height
	_fog_overlay_height_density = maxf(height_density, 0.0)
	_apply_fog()


## A tinta do bioma muda o tom da névoa, mas não o brilho da hora (15.13.3):
## de noite a névoa continua escura, e no pôr do sol não puxa para uma cor fixa.
static func tint_keeping_brightness(base: Color, tint: Color) -> Color:
	var tint_luma := maxf(tint.get_luminance(), 0.001)
	var scale := base.get_luminance() / tint_luma
	return Color(minf(tint.r * scale, 1.0), minf(tint.g * scale, 1.0), minf(tint.b * scale, 1.0))


func _apply_fog() -> void:
	if environment == null:
		return
	var density: float = _moment.fog_density * lerpf(1.0, OVERCAST_FOG, _overcast)
	var color: Color = _moment.fog_color
	if _overcast > 0.0:
		color = color.lerp(tint_keeping_brightness(color, OVERCAST_FOG_GREY),
				OVERCAST_FOG_GREY_AMOUNT * _overcast)
	# Peso zero restaura os valores exatos, inclusive a névoa de altura original.
	environment.fog_density = density
	environment.fog_light_color = color
	environment.fog_height = _base_fog_height
	environment.fog_height_density = _base_fog_height_density
	if _fog_overlay_weight <= 0.0:
		return
	environment.fog_density = density * lerpf(1.0, _fog_overlay_scale, _fog_overlay_weight)
	environment.fog_light_color = color.lerp(tint_keeping_brightness(color, _fog_overlay_tint),
			_fog_overlay_tint_amount * _fog_overlay_weight)
	environment.fog_height = lerpf(_base_fog_height, _fog_overlay_height, _fog_overlay_weight)
	environment.fog_height_density = lerpf(_base_fog_height_density,
			_fog_overlay_height_density, _fog_overlay_weight)


func get_night() -> float:
	return maxf(_night, 0.0)
