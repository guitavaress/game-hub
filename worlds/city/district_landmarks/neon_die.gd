class_name NeonDie
extends DistrictLandmark
## Bairro Cartas: um dado gigante de néon girando devagar, inclinado, em cima de
## uma coluna. Cada face tem as suas bolinhas (1 a 6) em néon.

const COLUMN_SIZE: float = 1.2
const DIE_SIZE: float = 4.6
const TILT_DEGREES: float = 22.0
const SPIN_SPEED: float = 0.35
const PIP_SIZE: float = 0.7
## Posições das bolinhas de cada face (-1 a 1, no plano da face).
const PIPS: Array = [
	[Vector2(0, 0)],
	[Vector2(-1, -1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
]

var _spinner: Node3D


func _build(height: float) -> void:
	var column_height := height - DIE_SIZE * 1.2
	_add_box(Vector3(0.0, column_height / 2.0, 0.0), Vector3(COLUMN_SIZE, column_height, COLUMN_SIZE), _concrete_material)
	var tilt := Node3D.new()
	tilt.position = Vector3(0.0, column_height + DIE_SIZE * 0.6, 0.0)
	tilt.rotation.z = deg_to_rad(TILT_DEGREES)
	tilt.rotation.x = deg_to_rad(TILT_DEGREES * 0.6)
	add_child(tilt)
	_spinner = Node3D.new()
	tilt.add_child(_spinner)
	_add_box(Vector3.ZERO, Vector3.ONE * DIE_SIZE, _concrete_material, _spinner)
	var faces: Array[Basis] = [
		Basis.IDENTITY, Basis(Vector3.UP, PI), Basis(Vector3.UP, PI / 2.0),
		Basis(Vector3.UP, -PI / 2.0), Basis(Vector3.RIGHT, -PI / 2.0), Basis(Vector3.RIGHT, PI / 2.0),
	]
	for face in 6:
		var holder := Node3D.new()
		holder.transform = Transform3D(faces[face], faces[face] * Vector3(0.0, 0.0, DIE_SIZE / 2.0))
		_spinner.add_child(holder)
		for pip: Vector2 in PIPS[face]:
			_add_box(Vector3(pip.x, pip.y, 0.02) * (DIE_SIZE * 0.25), Vector3(PIP_SIZE, PIP_SIZE, 0.08),
					_neon_material, holder)


func _process(delta: float) -> void:
	if _spinner != null:
		_spinner.rotate_y(SPIN_SPEED * delta)
