class_name DayMoment
extends Resource
## Um MOMENTO do dia (Fase 19.4): a hora e como a cidade fica nela (o sol, o
## céu, a névoa, a exposição e a luz ambiente). O DayCycleSpec guarda a lista
## dos momentos, e o DayNight passa de um para o outro aos poucos.
##
## Os valores padrão são os do meio-dia (os do dia da Fase 17.6): um momento
## novo, sem nada mudado, é um meio-dia.
##
## Toda variável de número (float) ou cor (Color) daqui é misturada sozinha
## entre um momento e o próximo (veja mix). Campo novo de número ou cor já
## entra na mistura sem código a mais.

## Nome curto, sem espaço (ex.: "nascer"). Quem quiser saber o momento do dia
## pergunta ao DayNight.current_moment().
@export var id: String = ""
## Nome para mostrar (ex.: "Nascer do sol").
@export var display_name: String = ""
## A hora em que este momento chega, de 0 a 24 (ex.: 6.5 = 6h30).
@export_range(0.0, 24.0, 0.05) var hour: float = 12.0
## Quantas horas o momento fica parado, depois da hora dele, antes de começar
## a passar para o próximo (ex.: o meio-dia fica igual das 11h às 14h30).
@export_range(0.0, 12.0, 0.05) var hold_hours: float = 0.0

@export_group("Céu de fotos")
## Quanto de cada foto do céu aparece (dia, pôr do sol, noite); somam 1.
@export_range(0.0, 1.0, 0.01) var sky_day: float = 1.0
@export_range(0.0, 1.0, 0.01) var sky_sunset: float = 0.0
@export_range(0.0, 1.0, 0.01) var sky_night: float = 0.0
## Brilho do céu (a foto da noite já é escura).
@export_range(0.0, 2.0, 0.01) var sky_energy: float = 1.0
## Uma cor por cima do céu inteiro: branco não muda nada. O nascer do sol fica
## mais rosado e a tarde mais dourada com ela.
@export var sky_tint: Color = Color.WHITE
## O sol da cena (de noite, a "lua"): cor, força e opacidade da sombra.
@export var sun_color: Color = Color("FFEFD9")
@export_range(0.0, 4.0, 0.01) var sun_energy: float = 1.5
@export_range(0.0, 1.0, 0.01) var shadow_opacity: float = 0.8

@export_group("Sky3D")
## O sol do Sky3D: a força e a cor do alto (perto do horizonte, quem manda é
## a cor de horizonte do próprio Sky3D).
@export_range(0.0, 4.0, 0.01) var sky3d_sun_energy: float = 1.5
@export var sky3d_sun_color: Color = Color("FFEFD9")
## A luz ambiente no Sky3D (à noite o céu dele é quase preto e ela compensa).
@export_range(0.0, 2.0, 0.01) var ambient_sky3d: float = 0.45

@export_group("Os dois céus")
## O luar (0 a 1 da força do luar; veja DayNight.MOONLIGHT_ENERGY).
@export_range(0.0, 1.0, 0.01) var moonlight: float = 0.0
## Exposição da câmera, em "EV" (+1 = dobro de luz).
@export_range(-2.0, 2.0, 0.01) var exposure_ev: float = 0.25
## Névoa: densidade, cor e quanto ela tinge o céu.
@export_range(0.0, 0.02, 0.0001) var fog_density: float = 0.0009
@export var fog_color: Color = Color(0.72, 0.78, 0.86)
@export_range(0.0, 1.0, 0.01) var fog_sky_affect: float = 0.15
## Luz ambiente no céu de fotos (menos luz do céu = sombra mais funda).
@export_range(0.0, 2.0, 0.01) var ambient: float = 0.45
## Contraste do AgX (a curva do tonemap; o padrão da Godot é 1,25) e saturação.
@export_range(0.5, 2.5, 0.01) var agx_contrast: float = 1.55
@export_range(0.0, 2.0, 0.01) var saturation: float = 1.2
## Força do brilho (glow) das luzes fortes.
@export_range(0.0, 2.0, 0.01) var glow: float = 0.6

## Os campos que NÃO se misturam: a hora e a parada são de cada momento.
const NOT_MIXED: Array[String] = ["hour", "hold_hours"]

static var _mixed_names: Array[String] = []


## Um momento no meio do caminho: t = 0 é "a", t = 1 é "b". O nome, a hora e
## a parada são os de "a". Cria um momento novo (não altera nenhum dos dois).
static func mix(a: DayMoment, b: DayMoment, t: float) -> DayMoment:
	var result: DayMoment = a.duplicate() as DayMoment
	for property: String in mixed_properties():
		var from: Variant = a.get(property)
		var to: Variant = b.get(property)
		if from is float:
			result.set(property, lerpf(from, to, t))
		elif from is Color:
			result.set(property, (from as Color).lerp(to, t))
	return result


## Os nomes dos campos de número e de cor que se misturam (calculado uma vez).
static func mixed_properties() -> Array[String]:
	if _mixed_names.is_empty():
		for info: Dictionary in DayMoment.new().get_property_list():
			if not (int(info["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var type: int = int(info["type"])
			var name: String = info["name"]
			if (type == TYPE_FLOAT or type == TYPE_COLOR) and not NOT_MIXED.has(name):
				_mixed_names.append(name)
	return _mixed_names
