class_name BiomeBuilder
extends RefCounted
## O bioma de um bairro na cidade (Fase 15.6). A cidade só chama isto quando o
## perfil do bairro tem bioma (DistrictProfile.biome); os outros bairros não mudam.
##
## O chão do bioma: calçada de pedra e miolo de neve nos quarteirões e nas
## vagas, e o "setor coberto", uma placa fina sobre as ruas do bairro, com
## colisão e a marca dos passos (ex.: "snow"). As faixas e as poças da cidade
## pulam as zonas cobertas (o CityDecor recebe as zonas de covered_rects).
##
## Fase 15.7: pinheiros e rochas (BiomeScatter) no miolo de neve, e a pedra com
## neve por cima nos arcos (dress_shell) e nas rochas (snow_cover_material).

## Topo do setor coberto: acima do asfalto (y 0) e abaixo das calçadas (0,04).
const COVER_TOP: float = 0.02
## Altura das placas do quarteirão (as mesmas do CityDecor.add_block_ground).
const SIDEWALK_TOP: float = 0.04
const INNER_TOP: float = 0.05
## Tamanho de uma repetição da textura da calçada de pedra, em metros.
const PATH_METERS: float = 2.0
## A neve das ruas é um pouco mais escura (pisada) que a do miolo.
const STREET_DARKEN: float = 0.12
## Pedra com neve por cima (15.7): o shader e o tamanho da textura nos arcos.
const SNOW_COVER_SHADER: Shader = preload("res://worlds/city/biome/snow_cover.gdshader")
const ARCH_METERS: float = 2.0
## Raio livre de pinheiros e rochas em volta de cada porta (cobre o arco, a
## frente dele e a passagem) e do meio de cada escada do metrô, em metros.
const DOOR_CLEARANCE: float = 4.5
const STATION_CLEARANCE: float = 4.0
## Quanto o meio da escada do metrô fica para dentro da boca (metade dela).
const STATION_DEPTH: float = 1.3

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


## A montanha de fundo do bairro (15.9), na fatia dele, atrás da mureta. Só
## faz as contas: quem chama monta os pedaços com build_next(), um por vez.
## null se o bioma não tem terreno ou se a montanha não cabe.
## 15.9.3: a montanha ganha a neve e a rocha do bioma, e os pilares da
## entrada, a pedra dos arcos.
static func add_backdrop(parent: Node3D, category_id: String, biome: BiomeSpec, sector: DistrictSector,
		half: float) -> BackdropTerrain:
	if biome.backdrop == null:
		return null
	var terrain := BackdropTerrain.new()
	terrain.name = "BackdropTerrain_%s" % category_id
	terrain.footstep = biome.footstep
	if not terrain.setup(biome.backdrop, sector, half):
		terrain.free()
		return null
	terrain.use_material(terrain_material(biome))
	if not biome.path_folder.is_empty():
		terrain.stone_material = snow_cover_material(biome, biome.path_folder, biome.path_tint, ARCH_METERS)
	parent.add_child(terrain)
	return terrain


## O material da montanha (terrain.gdshader): a neve do chão do bioma, na
## mesma cor e escala da neve dos quarteirões, e a rocha do terreno. Sem as
## pastas, fica só a cor (o greybox).
static func terrain_material(biome: BiomeSpec) -> ShaderMaterial:
	var terrain := biome.backdrop
	var key := "terrain|%s|%s|%s|%s|%.2f|%.2f" % [biome.id, terrain.snow_folder, terrain.rock_folder,
			biome.ground_tint.to_html(), biome.ground_meters, terrain.snow_slope]
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = BackdropTerrain.TERRAIN_SHADER
	if not terrain.snow_folder.is_empty():
		var snow := CityDecor.pbr_textures(terrain.snow_folder)
		material.set_shader_parameter("snow_albedo", snow["albedo"])
		material.set_shader_parameter("snow_normal", snow["normal"])
		material.set_shader_parameter("snow_roughness", snow["roughness"])
		material.set_shader_parameter("snow_tint", snow_tint(biome.ground_tint))  # Color: a Godot converte de sRGB
		material.set_shader_parameter("snow_meters", biome.ground_meters)
	if not terrain.rock_folder.is_empty():
		var rock := CityDecor.pbr_textures(terrain.rock_folder)
		material.set_shader_parameter("rock_albedo", rock["albedo"])
		material.set_shader_parameter("rock_normal", rock["normal"])
		material.set_shader_parameter("rock_roughness", rock["roughness"])
	material.set_shader_parameter("snow_slope", terrain.snow_slope)
	_materials[key] = material
	return material


## Pinheiros e rochas do bairro (15.7), no miolo de neve de cada zona, longe
## das portas e das estações. Chamar com as portas e o metrô já montados.
## null se o bioma não tem nada para o bairro.
static func add_scatter(parent: Node3D, category_id: String, biome: BiomeSpec, zones: Array[Rect2]) -> BiomeScatter:
	var has_town := false
	for spec in biome.scatter:
		has_town = has_town or spec.in_town
	if not has_town:
		return null
	var scatter := BiomeScatter.new()
	scatter.setup(category_id, biome, scatter_regions(zones), keep_out_points(parent))
	parent.add_child(scatter)
	return scatter


## O miolo de neve de cada zona (quarteirão ou vaga): o quadrado dentro da
## calçada, onde não se anda por caminho nenhum.
static func scatter_regions(zones: Array[Rect2]) -> Array[Rect2]:
	var inner := CityLayout.BLOCK_SIZE - CityDecor.SIDEWALK_WIDTH * 2.0
	var result: Array[Rect2] = []
	for zone in zones:
		result.append(Rect2(zone.get_center() - Vector2(inner, inner) / 2.0, Vector2(inner, inner)))
	return result


## Os pontos que ficam livres (x, z, raio): as portas dos jogos e o meio da
## escada de cada estação do metrô, achados pelos grupos.
static func keep_out_points(parent: Node) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var tree := parent.get_tree()
	for node in tree.get_nodes_in_group("game_portal"):
		var portal := node as Node3D
		if portal != null and parent.is_ancestor_of(portal):
			points.append(Vector3(portal.global_position.x, portal.global_position.z, DOOR_CLEARANCE))
	for node in tree.get_nodes_in_group("transit_stop"):
		var stop := node as Node3D
		if stop != null and parent.is_ancestor_of(stop):
			# A frente (+Z) da estação aponta para a rua; a escada desce para trás.
			var middle := stop.global_transform * Vector3(0.0, 0.0, -STATION_DEPTH)
			points.append(Vector3(middle.x, middle.z, STATION_CLEARANCE))
	return points


## Veste a casca da porta com a pedra do bioma (15.7): nos arcos, a pedra da
## calçada com neve por cima. Cascas sem "stone_material" ficam como estão.
static func dress_shell(shell: Node, biome: BiomeSpec) -> void:
	if "stone_material" in shell and not biome.path_folder.is_empty():
		shell.set("stone_material", snow_cover_material(biome, biome.path_folder, biome.path_tint, ARCH_METERS))


## Pedra com neve por cima (15.7): a textura da pasta "folder" (ambientCG) na
## cor "tint", e a neve do chão do bioma onde a superfície aponta para cima,
## no quanto do snow_cover. Um material por combinação (todas as cópias usam o mesmo).
static func snow_cover_material(biome: BiomeSpec, folder: String, tint: Color, meters: float) -> ShaderMaterial:
	var key := "cover|%s|%s|%.2f|%s|%s|%.2f|%.2f" % [biome.id, folder, meters, tint.to_html(),
			biome.ground_folder, biome.ground_meters, biome.snow_cover]
	if _materials.has(key):
		return _materials[key]
	var stone := CityDecor.pbr_textures(folder)
	var snow := CityDecor.pbr_textures(biome.ground_folder)
	var snow_color := snow_tint(biome.ground_tint)
	var material := ShaderMaterial.new()
	material.shader = SNOW_COVER_SHADER
	material.set_shader_parameter("stone_albedo", stone["albedo"])
	material.set_shader_parameter("stone_normal", stone["normal"])
	material.set_shader_parameter("stone_roughness", stone["roughness"])
	material.set_shader_parameter("stone_tint", tint)  # Color: a Godot converte de sRGB (source_color)
	material.set_shader_parameter("stone_meters", meters)
	material.set_shader_parameter("snow_albedo", snow["albedo"])
	material.set_shader_parameter("snow_normal", snow["normal"])
	material.set_shader_parameter("snow_roughness", snow["roughness"])
	material.set_shader_parameter("snow_tint", snow_color)
	material.set_shader_parameter("snow_meters", biome.ground_meters)
	material.set_shader_parameter("snow_cover", biome.snow_cover)
	_materials[key] = material
	return material


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
