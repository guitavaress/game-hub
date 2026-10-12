class_name DistrictProps
extends RefCounted
## Identidade dos bairros: cada bairro ganha UM elemento seu, feito só com
## formas simples e shader (regra "neutro + luz"), para ser reconhecível mesmo
## de dia, com o néon apagado. Um script por bairro nesta pasta.
##
##   acao    telões nas quinas dos prédios, com os banners do bairro
##   cartas  lâmpadas de cassino em volta do painel, com a luz "correndo"
##   sobrevivencia  néon falhando, névoa baixa e um poste apagado
##   esportes  placar de LED com as horas jogadas e faixa de largada na rua
##   simulacao  obra: guindaste girando no telhado e tela de andaime na fachada
##   estrategia  mesa holográfica no miolo do quarteirão, com uma caixinha por prédio
##   casual  varal de lâmpadas coloridas ligando os postes, por cima das ruas
##   rpg     estandartes de tecido balançando ao vento em cada poste
##   aventura  postes viram lampiões a gás (luz quente que treme) e calçada de pedra
##   (qualquer outro bairro, inclusive Outros)  totem de endereço com a lista dos jogos
##   (mais bairros entram aqui, um por vez)
##
## A cidade chama decorate() para cada quarteirão pronto. No mundo aberto do
## futuro, o mesmo elemento pode marcar a entrada do bioma.


## Enfeita um quarteirão do bairro (se o perfil do bairro tiver enfeite).
## O enfeite é o script indicado em "props_script" do perfil (profiles/districts/).
static func decorate(parent: Node3D, category_id: String, cell: Vector2i, buildings: Array[CityBuilding]) -> void:
	var profile := Profiles.district(category_id)
	if profile == null or profile.props_script.is_empty():
		return
	var script := load(profile.props_script) as GDScript
	if script == null:
		push_warning("O enfeite %s do bairro %s não carregou." % [profile.props_script, category_id])
		return
	var props := script.new() as Node3D
	if props == null:
		return
	props.name = "DistrictProps_%s_%d_%d" % [category_id, cell.x, cell.y]
	props.set("buildings", buildings)
	if "cell" in props:
		props.set("cell", cell)
	if "category_id" in props:
		props.set("category_id", category_id)
	parent.add_child(props)


## Os postes (StreetLight) do quarteirão, para os bairros que mexem neles.
## Procura entre os filhos do mundo (parent) os que ficam dentro do quarteirão.
static func lights_in_block(parent: Node, cell: Vector2i) -> Array[StreetLight]:
	var center := CityLayout.block_center(cell)
	var found: Array[StreetLight] = []
	for node in parent.get_children():
		var light := node as StreetLight
		if light == null:
			continue
		var offset := light.position - center
		if absf(offset.x) > CityLayout.BLOCK_SIZE / 2.0 or absf(offset.z) > CityLayout.BLOCK_SIZE / 2.0:
			continue  # poste de outro quarteirão
		found.append(light)
	return found
