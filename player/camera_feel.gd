class_name CameraFeel
extends Node
## O "peso" da câmera em primeira pessoa (Fase 11.2): balanço ao andar, afundada
## ao pousar e FOV que abre correndo. Fica como filho do Player, que o alimenta
## (velocidade, passada, chão, pouso) e o chama a cada quadro com update().
##
## Tudo é um deslocamento PEQUENO da câmera dentro da cabeça (a posição de
## repouso mais um vetor de poucos centímetros). Durante o foco numa tela 3D
## e na viagem rápida, quem manda na câmera é o Player (active = false): aqui
## nada é mexido, e o estado volta a zero.
##
## A opção "Balanço da câmera" (AppConfig, seção [controls]) desliga tudo.

## Balanço vertical (pico a pico) e lateral, em metros.
const BOB_VERTICAL: float = 0.025
const BOB_LATERAL: float = 0.012
## Quanto o FOV abre correndo (graus) e a rapidez com que acompanha.
const SPRINT_FOV_BONUS: float = 5.0
const FOV_FOLLOW: float = 8.0
## Afundada máxima ao pousar (m), quanto afunda por m/s de queda, e a "mola"
## que a devolve (quanto maior, mais rápido volta: ~0,25 s com 16).
const LAND_DIP_MAX: float = 0.05
const LAND_DIP_PER_SPEED: float = 0.01
const LAND_SPRING: float = 16.0
## A porta carregando: o FOV fecha e a câmera avança (com curva). Vale mesmo
## com o balanço desligado: é parado e pequeno.
const CHARGE_FOV: float = 6.0
const CHARGE_FORWARD: float = 0.12
## Quedas mais lentas que isso (m/s) não afundam a câmera.
const LAND_MIN_SPEED: float = 1.5
## Velocidade (m/s) em que o balanço chega ao máximo; abaixo, ele é proporcional.
const FULL_BOB_SPEED: float = 5.0
## Rapidez com que o balanço entra e sai ao começar ou parar de andar.
const BOB_WEIGHT_FOLLOW: float = 8.0

var _camera: Camera3D
var _rest: Transform3D = Transform3D.IDENTITY
var _base_fov: float = 75.0
var _motion_on: bool = true
## Quanto do balanço está valendo (0 parado, 1 andando), suavizado.
var _bob_weight: float = 0.0
var _side: float = 1.0
var _last_stride: float = 0.0
## Mola do pouso: posição (negativa = câmera baixa) e velocidade.
var _land_offset: float = 0.0
var _land_velocity: float = 0.0
var _offset: Vector3 = Vector3.ZERO
var _sprint_fov: float = 0.0


## O Player entrega a câmera e a posição de repouso dela dentro da cabeça.
func setup(camera: Camera3D, rest: Transform3D) -> void:
	_camera = camera
	_rest = rest
	_base_fov = camera.fov
	_motion_on = AppConfig.get_camera_motion()
	AppConfig.settings_changed.connect(_on_settings_changed)


## O FOV "de descanso" (parado). A 11.4 liga isto à opção do config.
func set_base_fov(fov: float) -> void:
	_base_fov = fov


func get_base_fov() -> float:
	return _base_fov


## O deslocamento atual da câmera (em relação à posição de repouso), em m.
func get_offset() -> Vector3:
	return _offset


## Avisa que o jogador pousou, caindo a "falling_speed" m/s.
func land(falling_speed: float) -> void:
	if not _motion_on or falling_speed < LAND_MIN_SPEED:
		return
	_land_offset = -clampf(falling_speed * LAND_DIP_PER_SPEED, 0.0, LAND_DIP_MAX)
	_land_velocity = 0.0


## Chamado a cada quadro pelo Player.
##   horizontal_speed : velocidade no chão (m/s);
##   stride_fraction  : 0..1, quanto da passada já foi andado;
##   on_floor, sprinting : estado do jogador;
##   active           : false durante foco/viagem (nada é mexido).
func update(delta: float, horizontal_speed: float, stride_fraction: float,
		on_floor: bool, sprinting: bool, active: bool) -> void:
	if _camera == null:
		return
	if not active:
		_reset_state()
		return

	var moving := on_floor and horizontal_speed > 1.0
	var weight_target := clampf(horizontal_speed / FULL_BOB_SPEED, 0.0, 1.0) if moving else 0.0
	_bob_weight = lerpf(_bob_weight, weight_target, 1.0 - exp(-BOB_WEIGHT_FOLLOW * delta))

	# Cada passo troca o lado do balanço lateral (a fração volta a ~0).
	if stride_fraction < _last_stride - 0.5:
		_side = -_side
	_last_stride = stride_fraction

	var target_offset := Vector3.ZERO
	var fov_bonus := 0.0
	if _motion_on:
		var arc := sin(stride_fraction * PI)
		target_offset.y = BOB_VERTICAL * (arc - 0.5) * _bob_weight
		target_offset.x = BOB_LATERAL * _side * (arc - 0.5) * _bob_weight
		# Mola crítica: a câmera afundada volta ao lugar em ~0,25 s.
		var accel := -LAND_SPRING * LAND_SPRING * _land_offset - 2.0 * LAND_SPRING * _land_velocity
		_land_velocity += accel * delta
		_land_offset += _land_velocity * delta
		target_offset.y += _land_offset
		if sprinting and moving:
			fov_bonus = SPRINT_FOV_BONUS
	else:
		_land_offset = 0.0
		_land_velocity = 0.0

	_sprint_fov = lerpf(_sprint_fov, fov_bonus, 1.0 - exp(-FOV_FOLLOW * delta))

	# Porta carregando: o ScreenFade guarda o estado "uma porta carregando".
	var charge := ease(ScreenFade.door_charge.get_progress(), 1.8)
	target_offset += _rest.basis * Vector3(0.0, 0.0, -CHARGE_FORWARD * charge)
	if _offset != Vector3.ZERO or target_offset != Vector3.ZERO:
		_camera.transform = Transform3D(_rest.basis, _rest.origin + target_offset)
	_offset = target_offset
	_camera.fov = _base_fov + _sprint_fov - CHARGE_FOV * charge


## Fora de ação (foco, viagem): zera tudo sem tocar na câmera. O Player já
## devolve a câmera ao repouso quando o foco acaba.
func _reset_state() -> void:
	_bob_weight = 0.0
	_land_offset = 0.0
	_land_velocity = 0.0
	_offset = Vector3.ZERO
	_sprint_fov = 0.0


func _on_settings_changed(section: String, key: String) -> void:
	if section == "controls" and key == "camera_motion":
		_motion_on = AppConfig.get_camera_motion()
		if not _motion_on and _camera != null:
			# Desligou com a câmera fora do lugar: volta já, sem esperar o quadro.
			_camera.transform = _rest
			_offset = Vector3.ZERO
