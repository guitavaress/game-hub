class_name AvatarSpec
extends Resource
## O AVATAR como dado (Fase 13.6): qual corpo e a cor de cada parte. Vale para
## você e para os amigos (os hologramas), e o dicionário do to_dict() é o que a
## V4 ao vivo vai mandar e receber:
##   {"version": 1, "body": "human", "colors": {"skin": "#c68e64", ...}}
##
## Quem desenha é o AvatarBody (components/avatar/). No config.cfg, a seção
## [avatar] guarda o mesmo dado, uma cor por linha (AppConfig.get_avatar).

## Versão do formato do dicionário.
const FORMAT_VERSION: int = 1
## Corpos conhecidos (o AvatarBody sabe carregar cada um).
const BODIES: Array[String] = ["human"]
## As 5 partes com cor, na ordem das faixas do UV do modelo (confirmadas por
## captura na 13.6): pele (rosto, braços, mãos e pés), olhos (com as
## sobrancelhas), cabelo, camiseta e calça. O modelo não tem sapatos: os pés
## são da pele.
const ZONES: Array[String] = ["skin", "eyes", "hair", "shirt", "pants"]
## Nome de cada parte para mostrar.
const ZONE_NAMES: Dictionary[String, String] = {
	"skin": "Pele", "eyes": "Olhos", "hair": "Cabelo", "shirt": "Camiseta", "pants": "Calça",
}
## Cor de quem não escolheu (ou escreveu uma cor inválida).
const DEFAULT_COLORS: Dictionary[String, Color] = {
	"skin": Color("c68e64"), "eyes": Color("2b1d14"), "hair": Color("3b2a20"),
	"shirt": Color("4a7bd0"), "pants": Color("2f3b52"),
}

@export var body: String = "human"
@export var skin_color: Color = DEFAULT_COLORS["skin"]
@export var eyes_color: Color = DEFAULT_COLORS["eyes"]
@export var hair_color: Color = DEFAULT_COLORS["hair"]
@export var shirt_color: Color = DEFAULT_COLORS["shirt"]
@export var pants_color: Color = DEFAULT_COLORS["pants"]


func get_color(zone: String) -> Color:
	if not zone in ZONES:
		return Color.WHITE
	return get(zone + "_color")


func set_color(zone: String, color: Color) -> void:
	if zone in ZONES:
		set(zone + "_color", color)


## O dicionário que vai para a rede e para o config.cfg (cores em "#rrggbb").
func to_dict() -> Dictionary:
	var colors := {}
	for zone in ZONES:
		colors[zone] = "#" + get_color(zone).to_html(false)
	return {"version": FORMAT_VERSION, "body": body, "colors": colors}


## Lê o dicionário sem confiar nele (pode vir da rede ou de um config.cfg
## editado à mão): corpo desconhecido vira "human"; parte que falta, cor vazia
## ou inválida fica com a cor padrão; chaves a mais são ignoradas.
static func from_dict(data: Dictionary) -> AvatarSpec:
	var spec := AvatarSpec.new()
	var wanted_body := str(data.get("body", "")).strip_edges().to_lower()
	if wanted_body in BODIES:
		spec.body = wanted_body
	var colors: Variant = data.get("colors", {})
	if colors is Dictionary:
		for zone in ZONES:
			var html := str(colors.get(zone, "")).strip_edges()
			if Color.html_is_valid(html):
				spec.set_color(zone, Color.html(html))
	return spec
