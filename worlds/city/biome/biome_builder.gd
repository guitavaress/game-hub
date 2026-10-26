class_name BiomeBuilder
extends RefCounted
## O bioma de um bairro na cidade (Fase 15.6). A cidade só chama isto quando o
## perfil do bairro tem bioma (DistrictProfile.biome); os outros bairros não mudam.
##
## O chão do bioma: calçada de pedra e miolo de neve nos quarteirões e nas
## vagas, e o "setor coberto", uma placa fina sobre as ruas do bairro, com
## colisão e a marca dos passos (ex.: "snow"). As faixas e as poças da cidade
## pulam as zonas cobertas (o CityDecor recebe as zonas de covered_rects).

## Topo do setor coberto: acima do asfalto (y 0) e abaixo das calçadas (0,04).
const COVER_TOP: float = 0.02
## Altura das placas do quarteirão (as mesmas do CityDecor.add_block_ground).
const SIDEWALK_TOP: float = 0.04
const INNER_TOP: float = 0.05
## Tamanho de uma repetição da textura da calçada de pedra, em metros.
const PATH_METERS: float = 2.0
## A neve das ruas é um pouco mais escura (pisada) que a do miolo.
const STREET_DARKEN: float = 0.12

## Materiais já feitos (a chave inclui pasta, escala, cor e relevo).
static var _materials: Dictionary = {}


## O bioma do bairro (null = cidade).
static func biome_of(category_id: String) -> BiomeSpec:
	var profile := Profiles.district(category_id)
	return profile.biome if profile != null else null


## O índice do primeiro bairro cujo bioma tem terreno de fundo (a montanha):
## a fatia dele fica centrada no norte (o "focus" do SectorLayout.plan).
## -1 = nenhum (a cidade de sempre).
static func focus_index(ids: Array[String]) -> int:
	for i in ids.size():
		var biome := biome_of(ids[i])
		if biome != null and biome.backdrop != null:
			return i
	return -1


## Chão de um quarteirão (ou de uma vaga) do bioma: calçada de pedra em volta
## e o miolo de neve. Só visual: a colisão é a do setor coberto.
static func add_block_ground(parent: Node3D, center: Vector3, biome: BiomeSpec) -> void:
	var size := CityLayout.BLOCK_SIZE
	CityDecor.add_pad(parent, center, Vector2(size, size),
			CityDecor.pbr_material(biome.path_folder, PATH_METERS, biome.path_tint), SIDEWALK_TOP)
	var inner := size - CityDecor.SIDEWALK_WIDTH * 2.0
	CityDecor.add_pad(parent, center, Vector2(inner, inner), ground_material(biome), INNER_TOP)


## As áreas que o setor coberto ocupa, a partir das zonas do bairro (cada uma
## é um quarteirão com meia rua em volta). Com as ruas cobertas, as zonas da
## borda vão até a mureta (a rua de fora também vira neve); sem elas, só os
## quarteirões.
static func covered_rects(zones: Array[Rect2], half: float, cover_streets: bool) -> Array[Rect2]:
	var result: Array[Rect2] = []
	# Onde termina a zona de um quarteirão da borda: a meia rua antes da mureta.
	var edge := half - CityLayout.STREET_WIDTH
	for zone in zones:
		if not cover_streets:
			result.append(zone.grow(-CityLayout.STREET_WIDTH / 2.0))
			continue
		var left := -half if zone.position.x <= -edge else zone.position.x
		var top := -half if zone.position.y <= -edge else zone.position.y
		var right := half if zone.end.x >= edge else zone.end.x
		var bottom := half if zone.end.y >= edge else zone.end.y
		result.append(Rect2(left, top, right - left, bottom - top))
	return result


## O setor coberto: uma placa fina por área, num só corpo com colisão e com a
## marca dos passos do bioma. Com as ruas descobertas, fica só a colisão (o
## chão do quarteirão já desenha a neve).
static func add_cover(parent: Node3D, category_id: String, biome: BiomeSpec, rects: Array[Rect2]) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "BiomeCover_%s" % category_id
	if not biome.footstep.is_empty():
		body.set_meta("footstep", biome.footstep)
	parent.add_child(body)
	var material := street_material(biome)
	for rect in rects:
		var center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
		var shape := BoxShape3D.new()
		shape.size = Vector3(rect.size.x, COVER_TOP, rect.size.y)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = center + Vector3(0.0, COVER_TOP / 2.0, 0.0)
		body.add_child(collision)
		if biome.cover_streets:
			CityDecor.add_pad(body, center, rect.size, material, COVER_TOP)
	return body


## A névoa e o vento do bioma (15.12) sobre as áreas cobertas. Só um por
## cidade, por enquanto: o DayNight tem uma só mistura de névoa.
static func add_atmosphere(parent: Node, category_id: String, biome: BiomeSpec, rects: Array[Rect2],
		player: Node3D, day_night: DayNight) -> BiomeAtmosphere:
	var atmosphere := BiomeAtmosphere.new()
	atmosphere.name = "BiomeAtmosphere_%s" % category_id
	atmosphere.setup(biome, rects, player, day_night)
	parent.add_child(atmosphere)
	return atmosphere


## A neve do miolo dos quarteirões.
static func ground_material(biome: BiomeSpec) -> StandardMaterial3D:
	return _material(biome.ground_folder, biome.ground_meters, snow_tint(biome.ground_tint),
			biome.ground_normal_strength)


## A neve das ruas cobertas: a mesma, um pouco mais escura.
static func street_material(biome: BiomeSpec) -> StandardMaterial3D:
	return _material(biome.ground_folder, biome.ground_meters,
			snow_tint(biome.ground_tint).darkened(STREET_DARKEN), biome.ground_normal_strength)


## A cor da neve sem estourar o branco: nenhum canal passa de
## BiomeAtmosphere.SNOW_ALBEDO_MAX (a textura vai até 1, então a cor final também fica abaixo).
static func snow_tint(tint: Color) -> Color:
	var top := BiomeAtmosphere.SNOW_ALBEDO_MAX
	return Color(minf(tint.r, top), minf(tint.g, top), minf(tint.b, top), tint.a)


## Um material PBR da ambientCG com a força do relevo do bioma. É uma cópia do
## da cidade (CityDecor.pbr_material), para não mudar o relevo dos outros.
static func _material(folder: String, meters: float, tint: Color, normal_strength: float) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%.2f" % [folder, meters, tint.to_html(), normal_strength]
	if not _materials.has(key):
		var material := CityDecor.pbr_material(folder, meters, tint).duplicate() as StandardMaterial3D
		material.normal_scale = normal_strength
		_materials[key] = material
	return _materials[key]
