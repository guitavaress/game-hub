class_name DistrictProps
extends RefCounted
## Identidade dos bairros: cada bairro ganha UM elemento seu, feito só com
## formas simples e shader (regra "neutro + luz"), para ser reconhecível mesmo
## de dia, com o néon apagado. Um script por bairro nesta pasta.
##
##   acao    telões nas quinas dos prédios, com os banners do bairro
##   (mais bairros entram aqui, um por vez)
##
## A cidade chama decorate() para cada quarteirão pronto. No mundo aberto do
## futuro, o mesmo elemento pode marcar a entrada do bioma.


## Enfeita um quarteirão do bairro (se o bairro tiver enfeite).
static func decorate(parent: Node3D, category_id: String, cell: Vector2i, buildings: Array[CityBuilding]) -> void:
	var props: Node3D = null
	match category_id:
		"acao":
			props = ActionScreens.new()
	if props == null:
		return
	props.name = "DistrictProps_%s_%d_%d" % [category_id, cell.x, cell.y]
	props.set("buildings", buildings)
	parent.add_child(props)
