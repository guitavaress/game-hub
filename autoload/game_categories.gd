extends Node
## GameCategories: decide a CATEGORIA de cada jogo (autoload).
##
## Na cidade, cada categoria vira um bairro; num mundo futuro, pode virar um
## bioma. Por isso isto é um sistema, e não parte da cidade.
##
## A regra:
##   1. Se o usuário forçou uma categoria no config.cfg, vale ela.
##   2. Senão, olhamos as tags do jogo na loja (StoreInfo), da mais votada para
##      a menos votada. A primeira tag que aparecer em algum bairro decide.
##      Tags genéricas ("Um Jogador", "Indie", "Multijogador"...) não estão em
##      nenhum bairro, então são puladas.
##   3. Se nenhuma tag servir (ou não tivermos as tags), vai para "outros".
##
## Os bairros (nome, cores, tags...) moram nos PERFIS, um arquivo .tres por
## bairro em profiles/districts/ (Fase 7). Este autoload só responde perguntas
## sobre eles, com as mesmas funções de antes. Para mudar ou criar um bairro,
## edite os perfis (veja profiles/district_profile.gd).
## Cada bairro tem duas cores: a discreta (no chão e na parede) e a de néon (a
## cor de luz: letreiros, faixas, mira, telas).

const OTHER_ID: String = "outros"

## Tag -> id da categoria. Montado a partir dos perfis, para buscar rápido.
var _category_by_tag: Dictionary[int, String] = {}


func _ready() -> void:
	for profile in Profiles.districts():
		for tag: int in profile.tags:
			if _category_by_tag.has(tag):
				push_warning("GameCategories: a tag %d está em dois bairros." % tag)
				continue
			_category_by_tag[tag] = profile.id


## Id da categoria do jogo (ex.: "rpg"). Nunca devolve vazio.
func get_category_id(app_id: int) -> String:
	var forced := AppConfig.get_category_override(app_id)
	if not forced.is_empty():
		if has_category(forced):
			return forced
		push_warning("config.cfg: o bairro \"%s\" (jogo %d) não existe." % [forced, app_id])

	for tag in StoreInfo.get_tags(app_id):
		if _category_by_tag.has(tag):
			return _category_by_tag[tag]
	return OTHER_ID


## Todos os ids de categoria, na ordem do mundo (a ordem dos bairros na cidade).
func get_category_ids() -> Array[String]:
	return Profiles.district_ids()


func has_category(category_id: String) -> bool:
	return Profiles.district(category_id) != null


## Nome para mostrar (ex.: "RPG e Fantasia").
func get_category_name(category_id: String) -> String:
	var profile := Profiles.district(category_id)
	return profile.display_name if profile != null else category_id


## Cor de néon da categoria (a cor "de luz" do bairro). As do perfil foram
## escolhidas à mão (saturação 70%, brilho 100%) para que dois bairros não
## fiquem com cores parecidas; "Outros" é um branco frio.
func get_neon_color(category_id: String) -> Color:
	var profile := Profiles.district(category_id)
	if profile != null:
		return profile.neon_color()
	return Color.from_hsv(get_category_color(category_id).h, 0.7, 1.0)


## Cor da categoria (usada nos bairros da cidade, por exemplo).
func get_category_color(category_id: String) -> Color:
	var profile := Profiles.district(category_id)
	return profile.color if profile != null else Color.GRAY
