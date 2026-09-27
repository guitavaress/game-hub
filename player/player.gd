class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa.
##
## - Mouse gira a visão; W/A/S/D anda; Espaço pula; Shift corre.
## - Esc solta o mouse; clicar na janela prende de novo.
## - Um raio invisível (RayCast3D) sai da câmera. Se ele acertar algo que tenha
##   o método get_look_label(), o texto aparece no HUD. É um "contrato" simples:
##   qualquer coisa olhável (portal hoje, NPC de amigo na fase 5) só precisa ter
##   esse método.
##
## A origem (posição) deste nó fica nos PÉS do jogador.

## Avisa que o texto do que estamos olhando mudou ("" = nada).
signal look_target_changed(text: String)

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 4.8
## Quão rápido o jogador chega na velocidade desejada (maior = mais "seco").
@export var acceleration: float = 12.0
## Radianos girados por pixel de movimento do mouse.
@export var mouse_sensitivity: float = 0.0025
## Alcance do raio de "olhar", em metros.
@export var look_distance: float = 30.0

## Limite para olhar para cima/baixo (evita dar cambalhota com a câmera).
const MAX_PITCH_DEGREES: float = 89.0

@onready var _head: Node3D = $Head
@onready var _look_ray: RayCast3D = $Head/Camera3D/LookRay
@onready var _hud: Hud = $HUD

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_look_text: String = ""


func _ready() -> void:
	# O grupo "player" é como os portais reconhecem o jogador.
	add_to_group("player")
	_look_ray.target_position = Vector3(0.0, 0.0, -look_distance)
	look_target_changed.connect(_hud.set_look_text)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		# Girar o corpo inteiro para os lados (eixo Y)...
		rotate_y(-motion.relative.x * mouse_sensitivity)
		# ...e só a "cabeça" para cima/baixo (eixo X).
		_head.rotate_x(-motion.relative.y * mouse_sensitivity)
		var limit := deg_to_rad(MAX_PITCH_DEGREES)
		_head.rotation.x = clampf(_head.rotation.x, -limit, limit)
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Gravidade: enquanto estiver no ar, cai.
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Direção pedida pelo teclado, convertida para "para onde o jogador está virado".
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity := direction * speed

	# Aproxima a velocidade atual da desejada aos poucos (movimento mais suave).
	var blend := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, target_velocity.x, blend)
	velocity.z = lerpf(velocity.z, target_velocity.z, blend)

	move_and_slide()
	_update_look_target()


## O HUD do jogador (para o mundo mostrar avisos, por exemplo).
func get_hud() -> Hud:
	return _hud


## Coloca o jogador num ponto e o vira para a "frente" (-Z) do transform dado.
## Usado pelos portais para reaparecer na porta quando o jogo fecha.
func teleport_to(target: Transform3D) -> void:
	global_position = target.origin
	var forward := -target.basis.z
	forward.y = 0.0
	if forward.length() > 0.001:
		rotation.y = atan2(-forward.x, -forward.z)
	_head.rotation.x = 0.0
	velocity = Vector3.ZERO


func _update_look_target() -> void:
	var text := ""
	if _look_ray.is_colliding():
		text = _find_look_label(_look_ray.get_collider())
	if text != _current_look_text:
		_current_look_text = text
		look_target_changed.emit(text)


## Sobe pela árvore de nós a partir do que o raio acertou, procurando alguém
## que saiba dizer seu nome (método get_look_label).
func _find_look_label(hit: Object) -> String:
	var node := hit as Node
	while node != null:
		if node.has_method("get_look_label"):
			return node.get_look_label()
		node = node.get_parent()
	return ""
