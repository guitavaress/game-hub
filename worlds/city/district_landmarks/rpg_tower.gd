class_name RpgTower
extends DistrictLandmark
## Bairro RPG e Fantasia: uma torre de castelo (fuste de pedra escura, frestas
## de néon, plataforma com ameias) com uma flâmula de néon balançando ao vento
## no mastro do topo.

const SHAFT_SIZE: float = 2.6
const PLATFORM_SIZE: float = 3.6
const PLATFORM_HEIGHT: float = 0.6
const MERLON_HEIGHT: float = 1.0
const MERLON_SIZE: float = 0.7
## Do alto da plataforma ao topo do mastro (m).
const POLE_LENGTH: float = 4.4
const PENNANT_SIZE: Vector2 = Vector2(2.0, 1.1)
const SWAY_DEGREES: float = 14.0
const SWAY_SPEED: float = 1.6

var _pennant: Node3D
var _time: float = 0.0


func _build(height: float) -> void:
	var platform_y := height - POLE_LENGTH - MERLON_HEIGHT - PLATFORM_HEIGHT
	_add_box(Vector3(0.0, platform_y / 2.0, 0.0), Vector3(SHAFT_SIZE, platform_y, SHAFT_SIZE), _concrete_material)
	# Frestas de néon no fuste: uma a cada 4 m, em duas faces.
	var y := 3.0
	while y < platform_y - 1.5:
		for side in [-1.0, 1.0]:
			_add_box(Vector3(0.0, y, side * (SHAFT_SIZE / 2.0 + 0.02)), Vector3(0.3, 1.0, 0.05), _neon_material)
		y += 4.0
	_add_box(Vector3(0.0, platform_y + PLATFORM_HEIGHT / 2.0, 0.0),
			Vector3(PLATFORM_SIZE, PLATFORM_HEIGHT, PLATFORM_SIZE), _concrete_material)
	# Ameias: três por lado, nos quatro lados (os cantos contam para dois lados).
	var merlon_y := platform_y + PLATFORM_HEIGHT + MERLON_HEIGHT / 2.0
	var reach := PLATFORM_SIZE / 2.0 - MERLON_SIZE / 2.0
	for ix in 3:
		for iz in 3:
			if ix == 1 and iz == 1:
				continue  # o meio fica livre (o mastro)
			if (ix + iz) % 2 == 1:
				continue  # vão entre as ameias
			_add_box(Vector3((ix - 1) * reach, merlon_y, (iz - 1) * reach),
					Vector3(MERLON_SIZE, MERLON_HEIGHT, MERLON_SIZE), _concrete_material)
	var pole_base := platform_y + PLATFORM_HEIGHT
	_add_box(Vector3(0.0, pole_base + (MERLON_HEIGHT + POLE_LENGTH) / 2.0, 0.0),
			Vector3(0.12, MERLON_HEIGHT + POLE_LENGTH, 0.12), _concrete_material)
	# A flâmula: gira um pouco em torno do mastro; a ponta fica solta.
	_pennant = Node3D.new()
	_pennant.position = Vector3(0.0, pole_base + MERLON_HEIGHT + POLE_LENGTH - PENNANT_SIZE.y, 0.0)
	add_child(_pennant)
	_add_box(Vector3(PENNANT_SIZE.x / 2.0, 0.0, 0.0),
			Vector3(PENNANT_SIZE.x, PENNANT_SIZE.y, 0.04), _neon_material, _pennant)


func _process(delta: float) -> void:
	if _pennant == null:
		return
	_time += delta
	_pennant.rotation.y = deg_to_rad(SWAY_DEGREES) * sin(_time * SWAY_SPEED)
