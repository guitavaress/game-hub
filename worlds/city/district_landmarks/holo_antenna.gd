class_name HoloAntenna
extends DistrictLandmark
## Bairro Outros: uma antena com dois anéis holográficos de néon girando em
## sentidos opostos (o resto da cidade é "tudo o que não coube nos outros").

const RING_RADIUS: float = 3.2
const RING_THICKNESS: float = 0.12
const SPIN_SPEED: float = 0.9

var _ring_a: Node3D
var _ring_b: Node3D


func _build(height: float) -> void:
	var mast_h := height - 0.6
	_add_box(Vector3(0.0, mast_h / 2.0, 0.0), Vector3(0.5, mast_h, 0.5), _concrete_material)
	_add_box(Vector3(0.0, 1.0, 0.0), Vector3(1.4, 2.0, 1.4), _concrete_material)
	_add_box(Vector3(0.0, height - 0.3, 0.0), Vector3(0.15, 0.6, 0.15), _neon_material)
	var center := Vector3(0.0, height - RING_RADIUS - 1.0, 0.0)
	_ring_a = _make_ring(center, RING_RADIUS, 70.0)
	_ring_b = _make_ring(center, RING_RADIUS * 0.65, -70.0)


## Um anel de néon inclinado, preso a um eixo (que gira em Y).
func _make_ring(center: Vector3, radius: float, tilt_degrees: float) -> Node3D:
	var axis := Node3D.new()
	axis.position = center
	add_child(axis)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - RING_THICKNESS
	mesh.outer_radius = radius
	ring.mesh = mesh
	ring.rotation.x = deg_to_rad(tilt_degrees)
	ring.material_override = _neon_material
	axis.add_child(ring)
	return axis


func _process(delta: float) -> void:
	if _ring_a != null:
		_ring_a.rotate_y(SPIN_SPEED * delta)
		_ring_b.rotate_y(-SPIN_SPEED * 1.4 * delta)
