class_name CasualWheel
extends DistrictLandmark
## Bairro Casual e Festa: uma roda-gigante girando devagar. Duas pernas em A
## seguram o eixo; a roda tem aro e raios de néon e gôndolas que ficam sempre
## de pé (giram ao contrário da roda).

const SPIN_SPEED: float = 0.09  # rad/s: uma volta em ~70 s
const MAX_RADIUS: float = 8.0
const GONDOLAS: int = 8
const GONDOLA_SIZE: Vector3 = Vector3(0.9, 0.7, 0.9)
const LEG_SPREAD: float = 3.0

var _wheel: Node3D
var _gondolas: Array[Node3D] = []


func _build(height: float) -> void:
	var radius := minf(MAX_RADIUS, (height - 1.0) / 2.2)
	var hub_y := height - radius - 0.3
	# Duas pernas (uma de cada lado da roda) em A, do chão até o eixo.
	for side in [-1.0, 1.0]:
		for lean in [-1.0, 1.0]:
			var leg_length := Vector2(LEG_SPREAD, hub_y).length()
			var leg := _add_box(Vector3(lean * LEG_SPREAD / 2.0, hub_y / 2.0, side * 0.9),
					Vector3(0.35, leg_length, 0.35), _concrete_material)
			leg.rotation.z = lean * atan2(LEG_SPREAD, hub_y)
	_wheel = Node3D.new()
	_wheel.position = Vector3(0.0, hub_y, 0.0)
	add_child(_wheel)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius - 0.12
	ring_mesh.outer_radius = radius
	ring.mesh = ring_mesh
	ring.rotation.x = PI / 2.0
	ring.material_override = _neon_material
	_wheel.add_child(ring)
	# Raios: quatro hastes que cruzam o eixo (oito raios).
	for i in 4:
		var spoke := MeshInstance3D.new()
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(radius * 2.0, 0.08, 0.08)
		spoke.mesh = spoke_mesh
		spoke.rotation.z = i * PI / 4.0
		spoke.material_override = _neon_material
		_wheel.add_child(spoke)
	for i in GONDOLAS:
		var angle := i * TAU / GONDOLAS
		var gondola := Node3D.new()
		gondola.position = Vector3(sin(angle), -cos(angle), 0.0) * radius
		_wheel.add_child(gondola)
		var cabin := MeshInstance3D.new()
		var cabin_mesh := BoxMesh.new()
		cabin_mesh.size = GONDOLA_SIZE
		cabin.mesh = cabin_mesh
		cabin.position = Vector3(0.0, -GONDOLA_SIZE.y / 2.0, 0.0)
		cabin.material_override = _neon_material
		gondola.add_child(cabin)
		_gondolas.append(gondola)


func _process(delta: float) -> void:
	if _wheel == null:
		return
	_wheel.rotation.z += SPIN_SPEED * delta
	for gondola in _gondolas:
		gondola.rotation.z = -_wheel.rotation.z
