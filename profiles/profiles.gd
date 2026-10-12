class_name Profiles
extends RefCounted
## Profiles: a porta de entrada para os perfis (Fase 7). NÃO é um autoload:
## as funções são "static", então qualquer script chama Profiles.district("rpg").
##
## Carrega o mundo (profiles/world_profile.tres) uma vez e guarda. Os sistemas
## (GameCategories) e os mundos (a cidade) leem os perfis por aqui, e ninguém
## precisa saber em que arquivo cada bairro mora.

const WORLD_PATH: String = "res://profiles/world_profile.tres"
const HOME_CATALOG_PATH: String = "res://profiles/home_catalog.tres"

static var _world: WorldProfile = null
static var _by_id: Dictionary[String, DistrictProfile] = {}
static var _ids: Array[String] = []
static var _home_catalog: HomeCatalog = null


## O mundo atual (a cidade).
static func world() -> WorldProfile:
	if _world == null:
		_load_world()
	return _world


## Os perfis dos bairros, em ordem.
static func districts() -> Array[DistrictProfile]:
	var result: Array[DistrictProfile] = []
	for id in district_ids():
		result.append(_by_id[id])
	return result


## Os ids dos bairros, em ordem (ex.: ["esportes", "rpg", ...]).
static func district_ids() -> Array[String]:
	world()
	return _ids.duplicate()


## O perfil de um bairro, ou null se não existir.
static func district(id: String) -> DistrictProfile:
	world()
	return _by_id.get(id)


## O catálogo da casa: temas, disposições e cores prontas (Fase 13).
static func home_catalog() -> HomeCatalog:
	if _home_catalog == null:
		_home_catalog = load(HOME_CATALOG_PATH) as HomeCatalog
		if _home_catalog == null:
			push_error("Profiles: não consegui carregar %s." % HOME_CATALOG_PATH)
			_home_catalog = HomeCatalog.new()
	return _home_catalog


## O tema da casa com esse id. Id vazio ou desconhecido = o primeiro do
## catálogo (o padrão); null só se o catálogo estiver vazio.
static func home(id: String) -> HomeProfile:
	var homes := home_catalog().homes
	for profile in homes:
		if profile != null and profile.id == id:
			return profile
	if not id.is_empty():
		push_warning("Profiles: tema de casa \"%s\" não existe; usando o padrão." % id)
	return homes[0] if not homes.is_empty() else null


## A disposição dos móveis com esse id (vazio ou desconhecido = a primeira),
## ou null se o catálogo ainda não tem disposições.
static func home_layout(id: String) -> HomeLayout:
	var layouts := home_catalog().layouts
	for layout in layouts:
		if layout != null and layout.id == id:
			return layout
	if not id.is_empty():
		push_warning("Profiles: disposição \"%s\" não existe; usando a padrão." % id)
	return layouts[0] if not layouts.is_empty() else null


static func _load_world() -> void:
	_world = load(WORLD_PATH) as WorldProfile
	_by_id.clear()
	_ids.clear()
	if _world == null:
		push_error("Profiles: não consegui carregar %s." % WORLD_PATH)
		_world = WorldProfile.new()
		return
	for profile in _world.districts:
		if profile == null or profile.id.is_empty():
			push_warning("Profiles: um item da lista do mundo está vazio ou sem id.")
			continue
		if _by_id.has(profile.id):
			push_warning("Profiles: o bairro \"%s\" aparece duas vezes na lista do mundo." % profile.id)
			continue
		_by_id[profile.id] = profile
		_ids.append(profile.id)
