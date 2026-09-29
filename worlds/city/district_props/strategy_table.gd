class_name StrategyTable
extends Node3D
## Bairro Estratégia: uma MESA HOLOGRÁFICA de 4 x 4 m, como a mesa de guerra de
## um general. Fica no miolo do quarteirão: o encontro das ruelas de 4 m entre
## os prédios, que está sempre livre (os prédios ocupam 10 m de cada terreno de
## 14 m, e as pracinhas têm bancos e floreiras que não deixariam a mesa caber).
##
## A mesa tem uma base escura e baixa, um tampo holográfico de grade
## (estrategia_grid.gdshader) e, flutuando por cima, uma caixinha holográfica por
## prédio do quarteirão: escala 1:25 e na posição dele dentro do quarteirão,
## como se fosse o mapa do bairro visto de cima.

## Lado da mesa e altura do tampo (do piso do quarteirão).
const TABLE_SIZE: float = 4.0
const TABLE_HEIGHT: float = 0.9
## Altura do piso do miolo do quarteirão (veja CityDecor.add_block_ground).
const FLOOR_Y: float = 0.05
const SLAB_THICKNESS: float = 0.14
## O plano holográfico paira um pouco acima do tampo; as caixinhas, um pouco
## acima do plano.
const PLANE_GAP: float = 0.1
const BOX_FLOAT: float = 0.03
## Escala do mapa: 1 m na mesa = 25 m na cidade.
const MAP_SCALE: float = 25.0
const CATEGORY_ID: String = "estrategia"
const METAL_COLOR: Color = Color("1A1D22")
const GRID_SHADER: Shader = preload("res://worlds/city/district_props/estrategia_grid.gdshader")
const HOLOGRAM_SHADER: Shader = preload("res://components/friend_npc/hologram.gdshader")

## Os prédios e o quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []
var cell: Vector2i = Vector2i.ZERO

var _grid_material: ShaderMaterial
var _box_material: ShaderMaterial
var _neon_material: StandardMaterial3D
var _boxes: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("city_night")
	var center := CityLayout.block_center(cell)
	position = center  # a mesa fica no meio do quarteirão
	var neon := GameCategories.get_neon_color(CATEGORY_ID)
	_build_base(neon)
	_build_hologram(neon)
	_build_boxes(center)
	set_night(0.0)


## Base escura e baixa (pedestal largo, tampo em balanço e um filete de néon na
## borda do tampo), com colisão: ninguém atravessa a mesa.
func _build_base(neon: Color) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.8
	metal.roughness = 0.35

	var slab_y := FLOOR_Y + TABLE_HEIGHT - SLAB_THICKNESS / 2.0
	_add_box(Vector3(2.8, 0.1, 2.8), Vector3(0.0, FLOOR_Y + 0.05, 0.0), metal)   # sapata
	_add_box(Vector3(2.2, TABLE_HEIGHT - SLAB_THICKNESS - 0.1, 2.2),             # pedestal
			Vector3(0.0, FLOOR_Y + 0.1 + (TABLE_HEIGHT - SLAB_THICKNESS - 0.1) / 2.0, 0.0), metal)
	_add_box(Vector3(TABLE_SIZE, SLAB_THICKNESS, TABLE_SIZE), Vector3(0.0, slab_y, 0.0), metal)  # tampo

	# Filete de néon: uma faixa 1 cm maior que o tampo, que só aparece nas laterais.
	_neon_material = StandardMaterial3D.new()
	_neon_material.albedo_color = neon
	_neon_material.emission_enabled = true
	_neon_material.emission = neon
	_add_box(Vector3(TABLE_SIZE + 0.02, 0.03, TABLE_SIZE + 0.02), Vector3(0.0, slab_y, 0.0), _neon_material)

	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TABLE_SIZE, TABLE_HEIGHT, TABLE_SIZE)
	shape.shape = box
	body.position = Vector3(0.0, FLOOR_Y + TABLE_HEIGHT / 2.0, 0.0)
	body.add_child(shape)
	add_child(body)


## O tampo holográfico: um plano de 4 x 4 m com a grade.
func _build_hologram(neon: Color) -> void:
	_grid_material = ShaderMaterial.new()
	_grid_material.shader = GRID_SHADER
	_grid_material.set_shader_parameter("color", neon)
	_grid_material.set_shader_parameter("plane_size", TABLE_SIZE)
	_grid_material.set_shader_parameter("block_half", CityLayout.BLOCK_SIZE / MAP_SCALE / 2.0)
	var plane := MeshInstance3D.new()
	plane.name = "HoloGrid"
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(TABLE_SIZE, TABLE_SIZE)
	plane.mesh = plane_mesh
	plane.material_override = _grid_material
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.position = Vector3(0.0, _plane_y(), 0.0)
	add_child(plane)


## Uma caixinha holográfica por prédio: tamanho e posição divididos por 25.
func _build_boxes(center: Vector3) -> void:
	_box_material = ShaderMaterial.new()
	_box_material.shader = HOLOGRAM_SHADER
	_box_material.set_shader_parameter("color", GameCategories.get_neon_color(CATEGORY_ID))
	for building in buildings:
		var box_size := building.size / MAP_SCALE
		var offset := (building.position - center) / MAP_SCALE
		var box := MeshInstance3D.new()
		box.name = "Mini_%d" % _boxes.size()
		var box_mesh := BoxMesh.new()
		box_mesh.size = box_size
		box.mesh = box_mesh
		box.material_override = _box_material
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box.position = Vector3(offset.x, _plane_y() + BOX_FLOAT + box_size.y / 2.0, offset.z)
		box.rotation.y = building.rotation.y
		add_child(box)
		_boxes.append(box)


## Mais forte à noite (o holograma é luz: de dia ele precisa de mais força para aparecer).
func set_night(night: float) -> void:
	if _grid_material == null:
		return
	_grid_material.set_shader_parameter("intensity", lerpf(1.3, 2.4, night))
	_box_material.set_shader_parameter("intensity", lerpf(1.8, 3.0, night))
	_neon_material.emission_energy_multiplier = CityDecor.neon_energy(night)


## Quantas caixinhas a mesa tem (para os testes).
func get_box_count() -> int:
	return _boxes.size()


## Metade do lado da mesa (para os testes conferirem se ela cabe no quarteirão).
func get_half_size() -> float:
	return TABLE_SIZE / 2.0


func _plane_y() -> float:
	return FLOOR_Y + TABLE_HEIGHT + PLANE_GAP


## Caixa só visual (sem colisão).
func _add_box(box_size: Vector3, box_position: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	box.mesh = mesh
	box.position = box_position
	box.material_override = material
	add_child(box)
