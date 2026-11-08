class_name RpgTower
extends DistrictLandmark
## Bairro RPG e Fantasia: uma torre de castelo (fuste de pedra escura, frestas
## de néon, plataforma com ameias e uma coroa de néon embaixo delas) com uma
## flâmula de néon balançando ao vento no mastro do topo.
##
## Fase 15.10: no telhado, o fuste tem 2,6 m; ancorada no chão (no mirante da
## montanha, ou no meio do quarteirão), a torre fica mais larga (ANCHORED_SHAFT,
## decisão do dono de 2026-10-26: fina, ela sumia a 300 m), com colisão na base.
##
## Fase 15.13.4: quatro braseiros nos vãos das ameias, com a chama de emissão
## (sem luz nova) que cresce à noite e tremula; é o ponto de luz da torre vista
## de longe. Decisão do dono (2026-11-01): braseiro, e não fachos girando.
##
## Fase 17.10: de perto (no mirante da montanha) a torre lia como um bloco
## azul-escuro liso. Agora ela é de pedra de verdade — a PavingStones070 do
## projeto, a mesma pedra em fiadas da chaminé da cabana —, com a cornija em
## degraus embaixo da plataforma e um portal em cada face maior.

## A pedra do fuste: a textura, o tamanho de uma repetição (m) e o cinza claro
## de castelo. A cinta é a mesma pedra, mais escura (a verga da porta, os
## braseiros e os cantos).
const STONE_TEXTURE: String = "PavingStones070"
const STONE_METERS: float = 1.3
const STONE_TINT: Color = Color(0.78, 0.76, 0.73)
const BAND_TINT: Color = Color(0.5, 0.48, 0.46)
## O vão do portal: quase preto, para ler como boca e não como porta pintada.
const DOOR_DARK: Color = Color(0.03, 0.03, 0.035)
## O mastro da flâmula: ferro escuro, e não concreto.
const IRON_COLOR: Color = Color(0.09, 0.09, 0.1)
## O portal (a porta) nas duas faces maiores: medida de gente, e não do fuste
## (por isso não cresce com "k"): 1,8 m de largura, 3 m de altura e a verga de
## pedra escura por cima.
const DOOR_WIDTH: float = 1.8
const DOOR_HEIGHT: float = 3.0
const DOOR_BAND: float = 0.22
## A cornija em degraus embaixo da plataforma: três anéis cada vez mais largos
## (a altura de cada um, × largura_scale).
const CORBEL_STEPS: int = 3
const CORBEL_HEIGHT: float = 0.19

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
## O braseiro (a bacia de pedra e a chama): medidas do telhado, crescem com a torre.
const BRAZIER_RADIUS: float = 0.35
const BRAZIER_HEIGHT: float = 0.45
const FLAME_HEIGHT: float = 2.4
const FLAME_COLOR: Color = Color(1.0, 0.5, 0.12)
## A chama tremula: quanto muda de altura e a que velocidade.
const FLICKER_AMOUNT: float = 0.18
const FLICKER_SPEED: float = 7.0

var _pennant: Node3D
var _flame_material: StandardMaterial3D
var _flames: Array[Node3D] = []
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
	var stone := CityDecor.pbr_material(STONE_TEXTURE, STONE_METERS, STONE_TINT)
	var band := CityDecor.pbr_material(STONE_TEXTURE, STONE_METERS, BAND_TINT)
	var dark := CityDecor.make_material(DOOR_DARK)
	var iron := CityDecor.make_material(IRON_COLOR)
	_add_box(Vector3(0.0, platform_y / 2.0, 0.0), Vector3(shaft, platform_y, shaft), stone)
	if is_anchored():
		# Ao alcance do jogador: a base é sólida (até acima do pulo).
		_add_solid(Vector3(0.0, 2.0, 0.0), Vector3(shaft, 4.0, shaft))
	# A cornija em degraus (17.10): do fuste para a plataforma, três anéis cada
	# vez mais largos. É o degrau que a silhueta da torre precisava.
	var corbel := CORBEL_HEIGHT * k
	for step in CORBEL_STEPS:
		var level := CORBEL_STEPS - step  # 3 = o de baixo, 1 = o de cima
		var width := shaft + (platform - shaft) * float(CORBEL_STEPS + 1 - level) / float(CORBEL_STEPS + 1)
		_add_box(Vector3(0.0, platform_y - corbel * float(level) + corbel * 0.5, 0.0),
				Vector3(width, corbel, width), stone)
	# Frestas de néon no fuste: uma a cada 4 m, em duas faces. Ancorada, elas
	# começam acima do portal.
	var crown_y := platform_y - corbel * CORBEL_STEPS - CROWN_HEIGHT * k * 0.5
	var y := 5.0 if is_anchored() else 3.0
	while y < crown_y - CROWN_HEIGHT * k * 0.5 - 0.6:
		for side in [-1.0, 1.0]:
			_add_box(Vector3(0.0, y, side * (shaft / 2.0 + 0.02)), Vector3(0.3 * k, 1.0, 0.05), _neon_material)
		y += 4.0
	# A coroa de néon: as quatro faces do fuste, logo abaixo da cornija.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.0, crown_y, side * (shaft / 2.0 + 0.03)),
				Vector3(shaft + 0.06, CROWN_HEIGHT * k, 0.05), _neon_material)
		_add_box(Vector3(side * (shaft / 2.0 + 0.03), crown_y, 0.0),
				Vector3(0.05, CROWN_HEIGHT * k, shaft + 0.06), _neon_material)
	_add_box(Vector3(0.0, platform_y + platform_height / 2.0, 0.0),
			Vector3(platform, platform_height, platform), stone)
	# O portal (17.10): a torre fica ao alcance do jogador e uma parede cega de
	# 6 m lia como caixa. O vão é escuro e a verga é de pedra escura, nas duas
	# faces maiores (a da praça e a de trás, por onde a trilha chega).
	if is_anchored():
		for side in [-1.0, 1.0]:
			var face: float = side * (shaft / 2.0 - 0.09)
			_add_box(Vector3(0.0, DOOR_HEIGHT / 2.0, face), Vector3(DOOR_WIDTH, DOOR_HEIGHT, 0.22), dark)
			_add_box(Vector3(0.0, DOOR_HEIGHT + DOOR_BAND / 2.0, face + side * 0.02),
					Vector3(DOOR_WIDTH + DOOR_BAND * 2.0, DOOR_BAND, 0.26), band)
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
					Vector3(merlon, merlon_height, merlon), stone)
	_build_braziers(platform_y + platform_height, reach, k, band)
	var pole_base := platform_y + platform_height
	_add_box(Vector3(0.0, pole_base + (merlon_height + POLE_LENGTH) / 2.0, 0.0),
			Vector3(0.12 * k, merlon_height + POLE_LENGTH, 0.12 * k), iron)
	# A flâmula: gira um pouco em torno do mastro; a ponta fica solta.
	_pennant = Node3D.new()
	_pennant.position = Vector3(0.0, pole_base + merlon_height + POLE_LENGTH - PENNANT_SIZE.y * k, 0.0)
	add_child(_pennant)
	_add_box(Vector3(PENNANT_SIZE.x * k / 2.0, 0.0, 0.0),
			Vector3(PENNANT_SIZE.x * k, PENNANT_SIZE.y * k, 0.04), _neon_material, _pennant)


## Quatro braseiros, um no vão do meio de cada lado da plataforma.
func _build_braziers(top_y: float, reach: float, k: float, bowl_material: Material) -> void:
	_flame_material = StandardMaterial3D.new()
	_flame_material.albedo_color = FLAME_COLOR
	_flame_material.emission_enabled = true
	_flame_material.emission = FLAME_COLOR
	var bowl := BRAZIER_HEIGHT * k
	for spot: Vector2 in [Vector2(0.0, -reach), Vector2(0.0, reach), Vector2(-reach, 0.0), Vector2(reach, 0.0)]:
		var base := Vector3(spot.x, top_y, spot.y)
		_add_cylinder(base, BRAZIER_RADIUS * k, BRAZIER_RADIUS * k * 0.6, bowl, bowl_material)
		var flame := Node3D.new()
		flame.position = base + Vector3(0.0, bowl, 0.0)
		add_child(flame)
		_add_cylinder(Vector3.ZERO, 0.0, BRAZIER_RADIUS * k * 1.1, FLAME_HEIGHT * k, _flame_material, flame, 8)
		_flames.append(flame)


## A chama é emissão: fraca de dia (um brilho), forte de noite.
func set_night(night: float) -> void:
	super.set_night(night)
	if _flame_material != null:
		_flame_material.emission_energy_multiplier = lerpf(0.8, 5.0, night)


func _process(delta: float) -> void:
	_time += delta
	for i in _flames.size():
		# Cada chama tremula fora de compasso com as outras.
		var wobble := sin(_time * FLICKER_SPEED + i * 1.7) * sin(_time * FLICKER_SPEED * 0.37 + i)
		_flames[i].scale.y = 1.0 + FLICKER_AMOUNT * wobble
	if _pennant == null:
		return
	_pennant.rotation.y = deg_to_rad(SWAY_DEGREES) * sin(_time * SWAY_SPEED)
