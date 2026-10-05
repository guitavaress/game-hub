class_name Profiles
extends RefCounted
## Profiles: a porta de entrada para os perfis (Fase 7). NÃO é um autoload:
## as funções são "static", então qualquer script chama Profiles.district("rpg").
##
## Carrega o mundo (profiles/world_profile.tres) uma vez e guarda. Os sistemas
## (GameCategories) e os mundos (a cidade) leem os perfis por aqui, e ninguém
## precisa saber em que arquivo cada bairro mora.

const WORLD_PATH: String = "res://profiles/world_profile.tres"

static var _world: WorldProfile = null
static var _by_id: Dictionary[String, DistrictProfile] = {}
static var _ids: Array[String] = []


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
