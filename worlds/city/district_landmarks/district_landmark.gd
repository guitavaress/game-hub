class_name DistrictLandmark
extends Node3D
## Base dos marcos dos bairros (Fase 11.6): um ponto alto que se vê de longe, no
## quarteirão do pórtico, em cima do prédio mais alto dele (como a grua da
## Simulação). A cidade escolhe o script pelo "landmark_script" do perfil do
## bairro (regra 4) e preenche "category_id" e "buildings" ANTES de adicionar.
##
## A altura é calculada para o topo passar do prédio mais alto que pode existir
## (BuildingVariant.max_total_height() + CLEARANCE): quem herda só desenha a
## forma, com essa altura, em _build(height) (a origem fica no telhado, o eixo Y
## sobe). Só emissão: nenhuma luz nova. O letreiro do bairro fica acima do
## get_top_y().

## Quanto o topo passa do prédio mais alto possível (m).
const CLEARANCE: float = 3.0
## Menor altura aceita (um bairro de prédios muito baixos não vira um marco anão).
const MIN_HEIGHT: float = 8.0
## Onde o marco fica no telhado (fração do tamanho, a partir do centro): o
## canto que os objetos do telhado (caixa d'água, condensador) não usam.
const ROOF_SPOT: Vector2 = Vector2(0.3, -0.3)
const CONCRETE_COLOR: Color = Color(0.2, 0.21, 0.24)

## O bairro e os prédios do quarteirão (a cidade preenche antes de adicionar).
var category_id: String = ""
var buildings: Array[CityBuilding] = []

var _target: CityBuilding
var _height: float = 0.0
var _neon_material: StandardMaterial3D
var _concrete_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("city_night")
	_target = _tallest_building()
	if _target == null:
		return
	_neon_material = StandardMaterial3D.new()
	var neon := GameCategories.get_neon_color(category_id)
	_neon_material.albedo_color = neon
	_neon_material.emission_enabled = true
	_neon_material.emission = neon
	_concrete_material = CityDecor.make_material(CONCRETE_COLOR)
	_height = min_height()
	global_transform = _target.global_transform * Transform3D(Basis.IDENTITY, roof_of_tallest())
	_build(_height)
	set_night(0.0)


## O telhado do prédio mais alto do quarteirão, no espaço do prédio: o recuo
## (se houver) é o telhado de cima. Vector3.ZERO se não houver prédio.
func roof_of_tallest() -> Vector3:
	var target := _target if _target != null else _tallest_building()
	if target == null:
		return Vector3.ZERO
	var roof_y := target.size.y
	var roof_center := Vector2.ZERO
	var roof_size := Vector2(target.size.x, target.size.z)
	if target.variant.setback:
		roof_y += BuildingVariant.SETBACK_HEIGHT
		roof_center = Vector2(0.0, -BuildingVariant.SETBACK_BACK)
		roof_size -= Vector2.ONE * BuildingVariant.SETBACK_INSET * 2.0
	return Vector3(roof_center.x + ROOF_SPOT.x * roof_size.x, roof_y,
			roof_center.y + ROOF_SPOT.y * roof_size.y)


## A altura que o marco precisa ter, do telhado dele, para o topo passar de
## todos os prédios possíveis do bairro.
func min_height() -> float:
	return maxf(MIN_HEIGHT, BuildingVariant.max_total_height() + CLEARANCE - roof_of_tallest().y)


## Altura do topo do marco (y do mundo). 0 = sem marco (quarteirão sem prédio).
func get_top_y() -> float:
	if _target == null:
		return 0.0
	return global_position.y + _height


## 0 = dia, 1 = noite (mesma regra de todo o néon da cidade).
func set_night(night: float) -> void:
	if _neon_material != null:
		_neon_material.emission_energy_multiplier = CityDecor.neon_energy(night)


## Desenha a forma, de y = 0 (telhado) até y = height. Quem herda sobrescreve.
func _build(_marker_height: float) -> void:
	pass


## O prédio mais alto do quarteirão (o de maior size.y; no empate, o de
## telhado mais alto, contando o recuo).
func _tallest_building() -> CityBuilding:
	var best: CityBuilding = null
	for building in buildings:
		if best == null or building.size.y > best.size.y \
				or (is_equal_approx(building.size.y, best.size.y)
				and building.variant.total_height() > best.variant.total_height()):
			best = building
	return best


# --- Peças para quem herda -----------------------------------------------------

## Uma caixa no marco (ou dentro de "parent", se vier).
func _add_box(center: Vector3, box_size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	(parent if parent != null else self).add_child(instance)
	return instance
