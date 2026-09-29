class_name AdventureLanterns
extends Node3D
## Bairro Aventura e Mistério: os postes do quarteirão viram LAMPIÕES A GÁS
## (StreetLight.lantern): haste de ferro, uma lanterna de vidro no topo e luz
## quente que treme à noite. E a calçada ganha uma camada fina de pedra de
## calçamento (PavingStones070, da ambientCG), como numa rua antiga.
##
## A pedra são quatro faixas em volta do quarteirão, numa MultiMesh só (um
## desenho). Não mexemos no chão da cidade: as faixas ficam por cima da calçada.

## Pedra de calçamento: pasta em assets/ambientcg, metros de uma repetição da
## textura e o tom (levemente quente, para casar com a luz dos lampiões).
const PAVING_FOLDER: String = "PavingStones070"
const PAVING_METERS: float = 1.5
const PAVING_TINT: Color = Color(0.86, 0.8, 0.72)
## Espessura da camada: igual à do miolo do quarteirão (as placas da calçada
## têm 4 cm), então a pedra fica um pouco acima da calçada e rente ao miolo.
const PAVING_HEIGHT: float = 0.05

## Os prédios e o quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []
var cell: Vector2i = Vector2i.ZERO

var _lights: Array[StreetLight] = []
var _paving: MultiMeshInstance3D


func _ready() -> void:
	_lights = DistrictProps.lights_in_block(get_parent(), cell)
	for light in _lights:
		light.lantern = true
	_build_paving()


## Os postes que viraram lampião (para os testes).
func get_lanterns() -> Array[StreetLight]:
	return _lights


## Quantas faixas de pedra tem o quarteirão (para os testes).
func get_paving_count() -> int:
	return _paving.multimesh.instance_count if _paving != null else 0


## Quatro faixas cobrindo a calçada: norte e sul de ponta a ponta e leste e
## oeste só no trecho do meio (os cantos já são das outras duas).
func _build_paving() -> void:
	var block := CityLayout.BLOCK_SIZE
	var width := CityDecor.SIDEWALK_WIDTH
	var middle := block - width * 2.0
	var edge := (block - width) / 2.0  # do centro do quarteirão ao meio da faixa
	var center := CityLayout.block_center(cell) + Vector3(0.0, PAVING_HEIGHT / 2.0, 0.0)
	# Cada faixa: onde fica (em relação ao centro) e o tamanho (x, z).
	var strips: Array[Array] = [
		[Vector3(0.0, 0.0, -edge), Vector2(block, width)],
		[Vector3(0.0, 0.0, edge), Vector2(block, width)],
		[Vector3(-edge, 0.0, 0.0), Vector2(width, middle)],
		[Vector3(edge, 0.0, 0.0), Vector2(width, middle)],
	]

	# Uma caixa de 1 m esticada para cada faixa (a textura é projetada pelo
	# mundo, então esticar não a deforma).
	var box := BoxMesh.new()
	box.size = Vector3(1.0, PAVING_HEIGHT, 1.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = strips.size()
	for i in strips.size():
		var size: Vector2 = strips[i][1]
		var basis := Basis.from_scale(Vector3(size.x, 1.0, size.y))
		multimesh.set_instance_transform(i, Transform3D(basis, center + strips[i][0]))
	_paving = MultiMeshInstance3D.new()
	_paving.name = "Paving"
	_paving.multimesh = multimesh
	_paving.material_override = CityDecor.pbr_material(PAVING_FOLDER, PAVING_METERS, PAVING_TINT)
	_paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_paving)
