class_name TrailBanner
extends Node3D
## Estandarte de tecido com a capa: sem luz própria, física ou processamento.
## A imagem chega pelo GameArt; a trilha espaça os pedidos entre quadros.

const FOOTPRINT: Vector2 = Vector2(1.3, 0.20)
const CLOTH_SIZE: Vector2 = Vector2(0.94, 1.41)
const CLOTH_BOTTOM: float = 1.12
const CLOTH_COLOR: Color = Color("654836")
## Cada estandarte sobe um pouco mais ou menos (0 a 0,45 m, pela ID do jogo):
## de longe, a fileira não vira uma régua.
const LIFT_STEP: float = 0.15
const LIFT_STEPS: int = 4

var app_id: int = 0
var minutes: int = -1
var _cloth: StandardMaterial3D
var _game_art: Node
static var _cloth_geometry: ArrayMesh
## O verso do tecido, liso e igual em todos: sem ele, quem olha por trás via
## a capa espelhada.
static var _cloth_back: StandardMaterial3D


func setup(game: Dictionary) -> void:
	app_id = int(game["app_id"])
	minutes = int(game["minutes"])
	name = "TrailBanner_%d" % app_id
	var lift := lift_of(app_id)
	var wood := HomeMaterials.wood(Color("493426"), false, 0.85)
	_piece("Mast", Vector3(0.10, 3.0 + lift, 0.10), Vector3(-0.57, 1.35 + lift / 2.0, 0.0), wood)
	_piece("Crossbar", Vector3(1.3, 0.065, 0.065), Vector3(0.0, 2.60 + lift, 0.0), wood)
	var metal := HomeMaterials.metal(Color("66513A"), 0.6)
	for x: float in [-0.39, 0.39]:
		_piece("Tie", Vector3(0.04, 0.15, 0.085), Vector3(x, 2.57 + lift, 0.0), metal)
	_piece("Hem", Vector3(0.96, 0.045, 0.065), Vector3(0.0, CLOTH_BOTTOM + lift, 0.0), wood)
	_cloth = StandardMaterial3D.new()
	_cloth.albedo_color = CLOTH_COLOR
	_cloth.roughness = 0.95
	_cloth.cull_mode = BaseMaterial3D.CULL_BACK
	_cloth.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var cloth := MeshInstance3D.new()
	cloth.name = "Cloth"
	if _cloth_geometry == null:
		_cloth_geometry = _cloth_mesh()
	cloth.mesh = _cloth_geometry
	cloth.material_override = _cloth
	cloth.position.y = lift
	cloth.visibility_range_end = 120.0
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED  # tecido fino: sombra dos dois lados
	add_child(cloth)
	if _cloth_back == null:
		_cloth_back = StandardMaterial3D.new()
		_cloth_back.albedo_color = CLOTH_COLOR
		_cloth_back.roughness = 0.95
		_cloth_back.cull_mode = BaseMaterial3D.CULL_FRONT
	var back := MeshInstance3D.new()
	back.name = "ClothBack"
	back.mesh = _cloth_geometry
	back.material_override = _cloth_back
	back.position.y = lift
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a frente já faz a sombra
	back.visibility_range_end = 120.0
	add_child(back)
	_game_art = get_tree().root.get_node("GameArt")
	_game_art.art_ready.connect(_on_art_ready)


## Quanto o estandarte deste jogo sobe (sempre o mesmo para o mesmo jogo).
static func lift_of(id: int) -> float:
	return LIFT_STEP * (absi(hash(id)) % LIFT_STEPS)


func request_art() -> void:
	_on_art_ready(app_id, _game_art.get_art(app_id))


func _exit_tree() -> void:
	if is_instance_valid(_game_art) and _game_art.art_ready.is_connected(_on_art_ready):
		_game_art.art_ready.disconnect(_on_art_ready)


func _on_art_ready(id: int, texture: Texture2D) -> void:
	if id != app_id or texture == null or _cloth == null:
		return
	_cloth.albedo_texture = texture
	_cloth.albedo_color = Color.WHITE


## Dobras pequenas, estáticas: a capa continua legível e não custa shader animado.
static func _cloth_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const COLUMNS: int = 16
	const ROWS: int = 8
	for row in ROWS:
		for column in COLUMNS:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var u := float(column + corner.x) / COLUMNS
				var v := float(row + corner.y) / ROWS
				var fold := sin(u * TAU * 3.0) * 0.028 * (0.3 + 0.7 * v)
				surface.set_uv(Vector2(u, v))
				surface.add_vertex(Vector3((u - 0.5) * CLOTH_SIZE.x,
						CLOTH_BOTTOM + (1.0 - v) * CLOTH_SIZE.y, fold))
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


func _piece(node_name: String, size: Vector3, center: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	instance.visibility_range_end = 120.0
	add_child(instance)
