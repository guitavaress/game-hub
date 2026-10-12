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
## Faixas de luz que varrem o céu (só à noite): o eixo que gira e o material.
var _beam_pivot: Node3D
var _beam_material: StandardMaterial3D
var _beam_speed: float = 0.0


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


func _process(delta: float) -> void:
	if _beam_pivot != null and _beam_pivot.visible:
		_beam_pivot.rotate_y(_beam_speed * delta)


## 0 = dia, 1 = noite (mesma regra de todo o néon da cidade).
func set_night(night: float) -> void:
	if _neon_material != null:
		_neon_material.emission_energy_multiplier = CityDecor.neon_energy(night)
	if _beam_pivot != null:
		# Soma de luz (sem sombra, sem luz de verdade): só existe de noite.
		_beam_pivot.visible = night > 0.05
		var glow := _neon_material.albedo_color * (0.55 * night)
		_beam_material.albedo_color = Color(glow.r, glow.g, glow.b)


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


## Um cilindro (ou cone: raio de cima menor) com a base em "base" (y), no marco
## ou dentro de "parent".
func _add_cylinder(base: Vector3, radius_top: float, radius_bottom: float, cylinder_height: float,
		material: Material, parent: Node3D = null, sides: int = 16) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_top
	mesh.bottom_radius = radius_bottom
	mesh.height = cylinder_height
	mesh.radial_segments = sides
	mesh.rings = 1
	instance.mesh = mesh
	instance.position = base + Vector3(0.0, cylinder_height / 2.0, 0.0)
	instance.material_override = material
	(parent if parent != null else self).add_child(instance)
	return instance


## Faixas de luz (como holofotes) saindo de "at", espalhadas em roda, que
## giram a "speed" rad/s. Só aparecem de noite (veja set_night).
func _add_sweeping_beams(at: Vector3, count: int, length: float, width: float,
		tilt_degrees: float, speed: float) -> void:
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_material.albedo_color = Color.BLACK
	_beam_speed = speed
	_beam_pivot = Node3D.new()
	_beam_pivot.position = at
	add_child(_beam_pivot)
	for i in count:
		var arm := Node3D.new()
		arm.rotation.y = i * TAU / count
		_beam_pivot.add_child(arm)
		var tilt := Node3D.new()
		tilt.rotation.x = deg_to_rad(tilt_degrees)
		arm.add_child(tilt)
		_add_box(Vector3(0.0, 0.0, -length / 2.0), Vector3(width, width, length), _beam_material, tilt)
