class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa.
##
## - Mouse gira a visão; W/A/S/D anda; Espaço pula; Shift corre.
## - Esc abre o menu de pausa (PauseMenu) e Tab abre a busca de jogos
##   (GameSearch); os dois vêm junto com o jogador, como o HUD.
## - Um raio invisível (RayCast3D) sai da câmera. Se ele acertar algo que tenha
##   o método get_look_label(), o texto aparece no HUD. É um "contrato" simples:
##   qualquer coisa olhável (portal hoje, NPC de amigo na fase 5) só precisa ter
##   esse método. Quem quiser um cartão mais completo (categoria, amigos, cor
##   da mira) tem get_look_info(), que devolve um dicionário.
##
## A origem (posição) deste nó fica nos PÉS do jogador.

## Avisa que o texto do que estamos olhando mudou ("" = nada).
signal look_target_changed(text: String)
## Igual, mas com tudo que o alvo sabe dizer (veja GamePortal.get_look_info).
signal look_info_changed(info: Dictionary)

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

## Sons (pacotes CC0 da Kenney).
const FOOTSTEP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/kenney/impact-sounds/footstep_concrete_000.ogg"),
	preload("res://assets/kenney/impact-sounds/footstep_concrete_001.ogg"),
	preload("res://assets/kenney/impact-sounds/footstep_concrete_002.ogg"),
	preload("res://assets/kenney/impact-sounds/footstep_concrete_003.ogg"),
	preload("res://assets/kenney/impact-sounds/footstep_concrete_004.ogg"),
]
const JUMP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/kenney/rpg-audio/cloth1.ogg"),
	preload("res://assets/kenney/rpg-audio/cloth2.ogg"),
	preload("res://assets/kenney/rpg-audio/cloth3.ogg"),
	preload("res://assets/kenney/rpg-audio/cloth4.ogg"),
]
const LAND_SOUNDS: Array[AudioStream] = [
	preload("res://assets/kenney/impact-sounds/impactSoft_heavy_000.ogg"),
	preload("res://assets/kenney/impact-sounds/impactSoft_heavy_001.ogg"),
]
## Distância andada entre um passo e outro (metros), andando e correndo.
const WALK_STRIDE: float = 2.2
const SPRINT_STRIDE: float = 3.0
## Só toca o som de aterrissar se estiver caindo mais rápido que isso (m/s).
const LAND_SOUND_MIN_SPEED: float = 4.0

@onready var _head: Node3D = $Head
@onready var _look_ray: RayCast3D = $Head/Camera3D/LookRay
@onready var _hud: Hud = $HUD

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_look_text: String = ""
var _current_look_info: Dictionary = {}
var _pause_menu: PauseMenu
var _game_search: GameSearch
var _world_map: WorldMap
var _transit_panel: TransitPanel
## true durante a abertura (câmera olhando o céu enquanto a cidade monta):
## o jogador fica parado e sem controles.
var in_intro: bool = false
## true durante uma viagem rápida (travel_to): sem andar, sem busca, sem menu.
var _traveling: bool = false

var _steps_player: AudioStreamPlayer
var _body_player: AudioStreamPlayer
## Quanto já andou desde o último passo (metros).
var _stride_progress: float = 0.0
var _was_on_floor: bool = true


func _ready() -> void:
	# O grupo "player" é como os portais reconhecem o jogador.
	add_to_group("player")
	_look_ray.target_position = Vector3(0.0, 0.0, -look_distance)
	look_info_changed.connect(_hud.set_look_info)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# O menu de pausa (Esc) e a busca de jogos (Tab) vêm junto com o jogador,
	# como o HUD.
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_game_search = GameSearch.new()
	add_child(_game_search)
	_world_map = WorldMap.new()
	add_child(_world_map)
	_transit_panel = TransitPanel.new()
	add_child(_transit_panel)

	_steps_player = _make_sound_player(-8.0)
	_body_player = _make_sound_player(-6.0)


func _unhandled_input(event: InputEvent) -> void:
	if in_intro:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		# Girar o corpo inteiro para os lados (eixo Y)...
		rotate_y(-motion.relative.x * mouse_sensitivity)
		# ...e só a "cabeça" para cima/baixo (eixo X).
		_head.rotate_x(-motion.relative.y * mouse_sensitivity)
		var limit := deg_to_rad(MAX_PITCH_DEGREES)
		_head.rotation.x = clampf(_head.rotation.x, -limit, limit)
	elif event is InputEventMouseButton and event.is_pressed() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# O Esc agora abre o menu de pausa (que solta o mouse); um clique na
		# janela prende o mouse de novo.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Gravidade: enquanto estiver no ar, cai.
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _traveling:
		velocity.y = jump_velocity
		_play_random(_body_player, JUMP_SOUNDS)

	# Direção pedida pelo teclado, convertida para "para onde o jogador está virado".
	var input_dir := Vector2.ZERO if _traveling else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir != Vector2.ZERO:
		_hud.on_player_moved()  # o aviso de volta do jogo pode sair
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity := direction * speed

	# Aproxima a velocidade atual da desejada aos poucos (movimento mais suave).
	var blend := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, target_velocity.x, blend)
	velocity.z = lerpf(velocity.z, target_velocity.z, blend)

	var falling_speed := -velocity.y
	move_and_slide()
	_update_footsteps(delta, speed, falling_speed)
	_update_look_target()


## Passos: um som a cada "passada" (mais longa correndo); e um "tum" ao cair.
func _update_footsteps(delta: float, speed: float, falling_speed: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and falling_speed > LAND_SOUND_MIN_SPEED:
		_play_random(_body_player, LAND_SOUNDS)
	_was_on_floor = on_floor

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var stride := SPRINT_STRIDE if speed > walk_speed else WALK_STRIDE
	if on_floor and horizontal_speed > 1.0:
		_stride_progress += horizontal_speed * delta
		if _stride_progress >= stride:
			_stride_progress = 0.0
			_play_random(_steps_player, FOOTSTEP_SOUNDS)
	else:
		# Parado: o primeiro passo ao voltar a andar sai logo.
		_stride_progress = stride * 0.7


func _make_sound_player(volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.bus = &"Efeitos"
	sound.volume_db = volume_db
	add_child(sound)
	return sound


## Toca um dos sons da lista, com o tom levemente diferente a cada vez.
func _play_random(sound: AudioStreamPlayer, streams: Array[AudioStream]) -> void:
	sound.stream = streams.pick_random()
	sound.pitch_scale = randf_range(0.9, 1.1)
	sound.play()


## O HUD do jogador (para o mundo mostrar avisos, por exemplo).
func get_hud() -> Hud:
	return _hud


func get_pause_menu() -> PauseMenu:
	return _pause_menu


func get_transit_panel() -> TransitPanel:
	return _transit_panel


## Algum painel por cima do jogo (menu, busca, mapa, metrô) está aberto?
## Cada painel confere isto antes de abrir: só um de cada vez.
func is_overlay_open() -> bool:
	return _pause_menu.is_open() or _game_search.is_open() or _world_map.is_open() \
			or _transit_panel.is_open()


func get_world_map() -> WorldMap:
	return _world_map


func get_game_search() -> GameSearch:
	return _game_search


## Abertura: parado (sem gravidade: o chão ainda nem existe), sem controles,
## sem HUD e olhando "pitch_degrees" para cima (só céu).
func start_intro(pitch_degrees: float) -> void:
	in_intro = true
	set_physics_process(false)
	_hud.visible = false
	_head.rotation.x = deg_to_rad(pitch_degrees)


## Fim da abertura: a câmera desce até o horizonte em "seconds" segundos e
## aí o jogador ganha os controles e o HUD. Dá para esperar com await.
func finish_intro(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_head, "rotation:x", 0.0, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	in_intro = false
	set_physics_process(true)
	_hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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


func is_traveling() -> bool:
	return _traveling


## VIAGEM RÁPIDA: escurece a tela, leva o jogador até "target" (ele fica
## virado para a frente do transform, como no teleport_to), apaga a faixa de
## luz e clareia. Espere com "await". Durante a viagem o jogador não anda e a
## busca e o menu não abrem. Não abre jogo nenhum.
func travel_to(target: Transform3D, message: String = "", fade_seconds: float = 0.35, hold_seconds: float = 0.15) -> void:
	if _traveling:
		return
	_traveling = true
	velocity = Vector3.ZERO
	ScreenFade.set_message(message)
	ScreenFade.fade_out(fade_seconds)
	await get_tree().create_timer(fade_seconds).timeout
	teleport_to(target)
	get_tree().call_group("route_guide", "clear_route")
	await get_tree().create_timer(hold_seconds).timeout
	ScreenFade.set_message("")
	ScreenFade.fade_in(fade_seconds)
	await get_tree().create_timer(fade_seconds).timeout
	_traveling = false


func _update_look_target() -> void:
	var info := {}
	if _look_ray.is_colliding():
		info = _find_look_info(_look_ray.get_collider())
	if info != _current_look_info:
		_current_look_info = info
		look_info_changed.emit(info)
		var text: String = info.get("title", "")
		if not str(info.get("detail", "")).is_empty():
			text += " — " + str(info["detail"])
		if text != _current_look_text:
			_current_look_text = text
			look_target_changed.emit(text)


## Sobe pela árvore de nós a partir do que o raio acertou, procurando alguém
## que saiba se descrever: get_look_info() (completo) ou get_look_label()
## (só o texto "Nome — detalhes", que vira title e detail).
func _find_look_info(hit: Object) -> Dictionary:
	var node := hit as Node
	while node != null:
		if node.has_method("get_look_info"):
			return node.get_look_info()
		if node.has_method("get_look_label"):
			var parts: PackedStringArray = str(node.get_look_label()).split(" — ", true, 1)
			return {"title": parts[0], "detail": parts[1] if parts.size() > 1 else ""}
		node = node.get_parent()
	return {}
