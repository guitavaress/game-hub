class_name ChessKing
extends DistrictLandmark
## Bairro Estratégia: o rei do xadrez, gigante, de concreto claro com um filete
## de néon no colar e na base. Fica em pé em cima do telhado.

const KING_COLOR: Color = Color(0.78, 0.78, 0.76)


func _build(height: float) -> void:
	var stone := CityDecor.make_material(KING_COLOR)
	stone.roughness = 0.7
	var base_h := 0.07 * height
	var body_top := 0.62 * height
	_add_cylinder(Vector3.ZERO, 2.0, 2.3, base_h, stone, null, 24)
	_add_cylinder(Vector3(0.0, base_h, 0.0), 0.9, 1.8, body_top - base_h, stone, null, 24)
	_add_cylinder(Vector3(0.0, base_h + 0.05, 0.0), 2.35, 2.35, 0.18, _neon_material, null, 24)
	# Colar: disco largo com filete de néon por cima.
	_add_cylinder(Vector3(0.0, body_top, 0.0), 1.5, 1.5, 0.45, stone, null, 24)
	_add_cylinder(Vector3(0.0, body_top + 0.45, 0.0), 1.55, 1.55, 0.12, _neon_material, null, 24)
	# Pescoço e cabeça (um bulbo achatado).
	var neck_top := 0.78 * height
	_add_cylinder(Vector3(0.0, body_top + 0.57, 0.0), 0.75, 0.95, neck_top - body_top - 0.57, stone, null, 24)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 1.35
	head_mesh.height = 2.2
	head.mesh = head_mesh
	head.position = Vector3(0.0, neck_top + 0.7, 0.0)
	head.material_override = stone
	add_child(head)
	# A cruz do rei: vertical e horizontal, com néon.
	var cross_base := neck_top + 1.7
	var cross_h := height - cross_base
	_add_box(Vector3(0.0, cross_base + cross_h / 2.0, 0.0), Vector3(0.5, cross_h, 0.5), _neon_material)
	_add_box(Vector3(0.0, cross_base + cross_h * 0.65, 0.0), Vector3(1.8, 0.5, 0.5), _neon_material)
