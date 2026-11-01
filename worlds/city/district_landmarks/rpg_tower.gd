class_name RpgTower
extends DistrictLandmark
## Bairro RPG e Fantasia: uma torre de castelo (fuste de pedra escura, frestas
## de néon, plataforma com ameias e uma coroa de néon embaixo delas) com uma
## flâmula de néon balançando ao vento no mastro do topo.
##
## Fase 15.10: no telhado, o fuste tem 2,6 m; ancorada no chão (no mirante da
## montanha, ou no meio do quarteirão), a torre fica mais larga (ANCHORED_SHAFT,
## decisão do dono de 2026-10-26: fina, ela sumia a 300 m), com colisão na base.

const SHAFT_SIZE: float = 2.6
## O fuste da torre ancorada (m). As outras medidas crescem na mesma proporção.
const ANCHORED_SHAFT: float = 6.0
const PLATFORM_SIZE: float = 3.6
const PLATFORM_HEIGHT: float = 0.6
const MERLON_HEIGHT: float = 1.0
const MERLON_SIZE: float = 0.7
## A coroa de néon: uma faixa em volta do fuste, logo abaixo da plataforma.
const CROWN_HEIGHT: float = 0.35
## Do alto da plataforma ao topo do mastro (m).
const POLE_LENGTH: float = 4.4
const PENNANT_SIZE: Vector2 = Vector2(2.0, 1.1)
const SWAY_DEGREES: float = 14.0
const SWAY_SPEED: float = 1.6

var _pennant: Node3D
var _time: float = 0.0


## Quanto as medidas da torre crescem (1 no telhado).
func width_scale() -> float:
	return ANCHORED_SHAFT / SHAFT_SIZE if is_anchored() else 1.0


## A largura do fuste (m).
func shaft_size() -> float:
	return SHAFT_SIZE * width_scale()


func footprint() -> Rect2:
	if not is_anchored():
		return Rect2()
	var half := shaft_size() / 2.0
	return Rect2(-half, -half, half * 2.0, half * 2.0)


func _build(height: float) -> void:
	var k := width_scale()
	var shaft := shaft_size()
	var platform := PLATFORM_SIZE * k
	var platform_height := PLATFORM_HEIGHT * k
	var merlon := MERLON_SIZE * k
	var merlon_height := MERLON_HEIGHT * k
	var platform_y := height - POLE_LENGTH - merlon_height - platform_height
	_add_box(Vector3(0.0, platform_y / 2.0, 0.0), Vector3(shaft, platform_y, shaft), _concrete_material)
	if is_anchored():
		# Ao alcance do jogador: a base é sólida (até acima do pulo).
		_add_solid(Vector3(0.0, 2.0, 0.0), Vector3(shaft, 4.0, shaft))
	# Frestas de néon no fuste: uma a cada 4 m, em duas faces.
	var y := 3.0
	while y < platform_y - 1.5:
		for side in [-1.0, 1.0]:
			_add_box(Vector3(0.0, y, side * (shaft / 2.0 + 0.02)), Vector3(0.3 * k, 1.0, 0.05), _neon_material)
		y += 4.0
	# A coroa de néon: as quatro faces do fuste, logo abaixo da plataforma.
	var crown_y := platform_y - CROWN_HEIGHT * k
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.0, crown_y, side * (shaft / 2.0 + 0.03)),
				Vector3(shaft + 0.06, CROWN_HEIGHT * k, 0.05), _neon_material)
		_add_box(Vector3(side * (shaft / 2.0 + 0.03), crown_y, 0.0),
				Vector3(0.05, CROWN_HEIGHT * k, shaft + 0.06), _neon_material)
	_add_box(Vector3(0.0, platform_y + platform_height / 2.0, 0.0),
			Vector3(platform, platform_height, platform), _concrete_material)
	# Ameias: três por lado, nos quatro lados (os cantos contam para dois lados).
	var merlon_y := platform_y + platform_height + merlon_height / 2.0
	var reach := platform / 2.0 - merlon / 2.0
	for ix in 3:
		for iz in 3:
			if ix == 1 and iz == 1:
				continue  # o meio fica livre (o mastro)
			if (ix + iz) % 2 == 1:
				continue  # vão entre as ameias
			_add_box(Vector3((ix - 1) * reach, merlon_y, (iz - 1) * reach),
					Vector3(merlon, merlon_height, merlon), _concrete_material)
	var pole_base := platform_y + platform_height
	_add_box(Vector3(0.0, pole_base + (merlon_height + POLE_LENGTH) / 2.0, 0.0),
			Vector3(0.12 * k, merlon_height + POLE_LENGTH, 0.12 * k), _concrete_material)
	# A flâmula: gira um pouco em torno do mastro; a ponta fica solta.
	_pennant = Node3D.new()
	_pennant.position = Vector3(0.0, pole_base + merlon_height + POLE_LENGTH - PENNANT_SIZE.y * k, 0.0)
	add_child(_pennant)
	_add_box(Vector3(PENNANT_SIZE.x * k / 2.0, 0.0, 0.0),
			Vector3(PENNANT_SIZE.x * k, PENNANT_SIZE.y * k, 0.04), _neon_material, _pennant)


func _process(delta: float) -> void:
	if _pennant == null:
		return
	_time += delta
	_pennant.rotation.y = deg_to_rad(SWAY_DEGREES) * sin(_time * SWAY_SPEED)
