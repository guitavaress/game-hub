class_name Player
extends CharacterBody3D
## Jogador em primeira ou terceira pessoa.
##
## - Mouse gira a visão; W/A/S/D anda; Espaço pula; Shift corre.
## - Esc abre o menu de pausa (PauseMenu) e Tab abre a busca de jogos
##   (GameSearch); os dois vêm junto com o jogador, como o HUD.
## - E numa tela 3D (Screen3D) aproxima a câmera dela (focus_on); Esc devolve
##   (leave_focus).
## - Um raio invisível (RayCast3D) sai da câmera. Se ele acertar algo que tenha
##   o método get_look_label(), o texto aparece no HUD. É um "contrato" simples:
##   qualquer coisa olhável (portal hoje, NPC de amigo na fase 5) só precisa ter
##   esse método. Quem quiser um cartão mais completo (categoria, amigos, cor
##   da mira) tem get_look_info(), que devolve um dicionário.
## - O seu corpo (Fase 20.3) é um PlayerAvatar, filho deste nó: olhando para
##   baixo, você vê o tronco, os braços, as pernas e os pés, e ele faz sombra.
## - TERCEIRA PESSOA (Fase 20.4): V (ou R3) alterna a visão. A câmera é a mesma;
##   ela sai para a ponta de um braço (SpringArm3D, criado por código e preso à
##   cabeça), atrás do ombro direito. O braço bate no mundo (prédios, árvores,
##   paredes e teto da casa) e encolhe: a câmera se aproxima e não atravessa.
##   Encolhido demais (ARM_CLOSE), o corpo some da câmera até haver espaço.
##   A escolha fica no config.cfg ([controls] view).
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
## Radianos girados por pixel de movimento do mouse (vezes a opção do config).
@export var mouse_sensitivity: float = 0.0025
## Alcance do raio de "olhar", em metros.
@export var look_distance: float = 30.0

## Giro do analógico direito, no máximo (rad/s, com a sensibilidade em 1,0):
## uma volta inteira em ~2 s.
const STICK_TURN_SPEED: float = 3.2

## Limite para olhar para cima/baixo (evita dar cambalhota com a câmera).
const MAX_PITCH_DEGREES: float = 89.0
## Em casa a câmera enxerga só até aqui (m): o mundo lá fora nem é desenhado.
const INDOOR_CAMERA_FAR: float = 60.0
## Em casa o som do mundo (canal "Ambiente") fica abafado: só os graves
## passam (filtro passa-baixa) e o volume cai um pouco.
const INDOOR_AMBIENCE_CUTOFF_HZ: float = 900.0
const INDOOR_AMBIENCE_DB: float = -10.0
## Quanto tempo (s) a câmera leva para chegar à tela 3D e para voltar.
const FOCUS_SLIDE_SECONDS: float = 0.45

## TERCEIRA PESSOA (Fase 20.4). O braço da câmera:
## comprimento (m) fora e dentro de casa (a sala tem 9 x 7 m e teto de 3 m);
const ARM_LENGTH_OUTDOOR: float = 3.0
const ARM_LENGTH_INDOOR: float = 1.8
## de onde ele sai, a partir do meio da cabeça: à direita (o ombro) e acima.
## O ombro mais o raio da ponta (ARM_RADIUS) cabem na cápsula do jogador (0,4 m
## de raio): encostado de lado numa parede, a ponta não começa dentro dela;
const ARM_SHOULDER: float = 0.3
const ARM_HEIGHT: float = 0.25
## a ponta é uma bolinha deste raio (m), maior que o canto do plano "near" da
## câmera, e para a esta folga (m) do que acertar;
const ARM_RADIUS: float = 0.08
const ARM_MARGIN: float = 0.05
## com o braço mais curto que isto (m), o corpo some da câmera (a sombra
## fica) até haver espaço. Fase 20.5: era 0,5, e encostado de costas numa
## parede (o braço fica com ~0,37 m) o corpo sumia. Como o braço sai do ombro
## (0,3 m à direita e 0,25 m acima), mesmo com ele em 0 a câmera fica a ~0,39 m
## do meio da cabeça: com 0,2 a nuca aparece no canto da tela, sem entrar nela;
const ARM_CLOSE: float = 0.2
## quão rápido (m/s) o braço muda de comprimento ao entrar e sair de casa (de
## 3,0 para 1,8 m em ~0,4 s: sem pulo da câmera);
const ARM_REACH_SPEED: float = 3.0
## no foco (tela, luneta, provador), enquanto a câmera desliza, o corpo
## aparece só com ela a mais que isto (m) do eixo dele (dos pés à cabeça):
## ela passa perto da cabeça no caminho, e o corpo some ali.
const FOCUS_BODY_CLEARANCE: float = 0.6
## quanto tempo (s) leva a passagem de uma visão para a outra;
const VIEW_SWITCH_SECONDS: float = 0.35
## na terceira pessoa, o limite para olhar para cima e para baixo é menor
## (olhando quase reto para cima, a câmera iria parar debaixo do corpo).
const THIRD_MAX_PITCH_DEGREES: float = 70.0
## O JEITO da terceira pessoa (a decisão do dono, na amostra da 20.4). Para
## testar o outro, troque o valor de THIRD_PERSON_STYLE aqui:
##   STYLE_SHOULDER ("ombro", o padrão): o avatar fica de costas para a câmera
##     e gira com o mouse, como na primeira pessoa. Andando de lado, ele vira
##     para o lado; para trás, anda de ré (o passo ao contrário);
##   STYLE_FREE ("livre"): o mouse gira só a câmera, em volta do avatar, e o
##     avatar vira para onde anda.
const STYLE_SHOULDER: String = "ombro"
const STYLE_FREE: String = "livre"
const THIRD_PERSON_STYLE: String = STYLE_SHOULDER
## Rapidez com que o avatar vira para onde anda na terceira pessoa.
const AVATAR_TURN_FOLLOW: float = 10.0
## Andando para trás: a parte "para trás" do movimento passa desta fração.
## Abaixo disso (de lado), o avatar vira para o lado e anda para a frente.
const BACKWARD_SHARE: float = 0.3

## Sons (pacotes CC0 da Kenney).
## Passos por SUPERFÍCIE. Quem monta um chão diz do que ele é com
## set_meta("footstep", "wood") no corpo de colisão; sem a marca, é concreto.
const FOOTSTEP_SURFACES: Dictionary[String, Array] = {
	"concrete": [
		preload("res://assets/kenney/impact-sounds/footstep_concrete_000.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_concrete_001.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_concrete_002.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_concrete_003.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_concrete_004.ogg"),
	],
	"wood": [
		preload("res://assets/kenney/impact-sounds/footstep_wood_000.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_wood_001.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_wood_002.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_wood_003.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_wood_004.ogg"),
	],
	"snow": [
		preload("res://assets/kenney/impact-sounds/footstep_snow_000.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_snow_001.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_snow_002.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_snow_003.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_snow_004.ogg"),
	],
	# A grama do bioma da floresta (19.7).
	"grass": [
		preload("res://assets/kenney/impact-sounds/footstep_grass_000.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_grass_001.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_grass_002.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_grass_003.ogg"),
		preload("res://assets/kenney/impact-sounds/footstep_grass_004.ogg"),
	],
}
const DEFAULT_SURFACE: String = "concrete"
## Eco dos passos em casa (canal "Passos"): sala pequena, pouco eco.
const INDOOR_ECHO_ROOM: float = 0.35
const INDOOR_ECHO_WET: float = 0.12
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
## No ar o controle é menor: a velocidade horizontal muda neste tanto (0..1)
## do que mudaria no chão.
const AIR_CONTROL: float = 0.35

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _look_ray: RayCast3D = $Head/Camera3D/LookRay
@onready var _hud: Hud = $HUD

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_look_text: String = ""
var _current_look_info: Dictionary = {}
var _pause_menu: PauseMenu
var _game_search: GameSearch
var _world_map: WorldMap
var _transit_panel: TransitPanel
## true durante a abertura (a tela "GAME HUB" por cima da casa): o jogador
## fica parado, sem controles e sem HUD.
var in_intro: bool = false
## true enquanto o mundo ainda está montando (o jogador já anda pela casa):
## a busca e o mapa não abrem (o mundo lá fora ainda não existe inteiro).
var world_loading: bool = false
## true durante uma viagem rápida (travel_to): sem andar, sem busca, sem menu.
var _traveling: bool = false
## Dentro de casa (veja set_indoors).
var _indoors: bool = false
## Até onde a câmera enxerga fora de casa (o valor da cena).
var _outdoor_camera_far: float = 4000.0

## FOCO numa tela 3D (veja focus_on): a tela focada (null = sem foco), se a
## câmera está voltando, a animação da câmera e a posição normal da câmera
## dentro da cabeça.
var _focus_screen: Node3D = null
var _focus_leaving: bool = false
## No foco, na terceira pessoa: o corpo ainda aparece (a câmera longe dele)?
## Indo, ele some de vez quando a câmera chega perto ou na pose; voltando,
## aparece quando ela se afasta (veja _update_focus_body).
var _focus_body_shown: bool = false
## O deslizar da câmera no foco (_slide_camera): de onde, para onde, o tempo
## andado, o andamento (0 a 1; 1 = parada) e quem chamar no fim.
var _slide_from: Transform3D
var _slide_to: Transform3D
var _slide_elapsed: float = 0.0
var _slide_t: float = 1.0
var _slide_done: Callable = Callable()
var _camera_rest: Transform3D = Transform3D.IDENTITY

## TERCEIRA PESSOA (veja as constantes ARM_*): o braço, a visão escolhida, o
## andamento da passagem (0 = primeira pessoa, 1 = terceira), o comprimento do
## braço para este lugar (fora ou dentro de casa), o comprimento de verdade
## agora (já encolhido pelo que o braço acertou) e o jeito (ombro ou livre;
## começa no THIRD_PERSON_STYLE, e as ferramentas de captura podem trocar).
var _arm: SpringArm3D
var _view: String = AppConfig.VIEW_FIRST
var _view_progress: float = 0.0
var _arm_reach: float = ARM_LENGTH_OUTDOOR
var _arm_now: float = 0.0
## O comprimento do lugar AGORA: anda até _arm_reach aos poucos (ARM_REACH_SPEED).
var _arm_reach_now: float = ARM_LENGTH_OUTDOOR
## Depois de um teleporte, o braço (que mede na física) ainda tem a medida do
## lugar velho: por estes quadros de física, o Player mede o braço ele mesmo
## (_cast_arm), e a câmera chega no lugar certo já no primeiro quadro.
var _arm_fresh_frames: int = 0
var third_person_style: String = THIRD_PERSON_STYLE
## Para onde o avatar olha no mundo (giro no Y) e se ele anda de ré agora.
var _facing: float = 0.0
var _backwards: bool = false

## INTERAGIR (E): quem está sendo olhado e responde ao E, há quanto tempo o E
## está segurado nele, e se o E já disparou nesta segurada.
var _interact_target: Node = null
var _interact_hold: float = 0.0
var _interact_fired: bool = false
var _interact_was_pressed: bool = false

var _steps_player: AudioStreamPlayer
var _body_player: AudioStreamPlayer
## Quanto já andou desde o último passo (metros).
var _stride_progress: float = 0.0
## Quantos passos tocaram desde que o jogador nasceu (os testes contam).
var steps_played: int = 0
var _was_on_floor: bool = true
## Balanço, afundada e FOV da câmera (veja CameraFeel).
var _camera_feel: CameraFeel
## O seu corpo (veja PlayerAvatar).
var _avatar: PlayerAvatar
## Correndo agora (andando com Shift apertado)?
var _sprinting: bool = false
## Multiplicador da sensibilidade (Esc › Controles).
var _sensitivity_scale: float = 1.0
## Idem, para o analógico direito do controle.
var _stick_scale: float = 1.0
var _stride_length: float = WALK_STRIDE
## Do que é o chão em que se pisa (a marca "footstep" do corpo de colisão).
var _surface: String = DEFAULT_SURFACE


func _ready() -> void:
	# O grupo "player" é como os portais reconhecem o jogador.
	add_to_group("player")
	_look_ray.target_position = Vector3(0.0, 0.0, -look_distance)
	_outdoor_camera_far = _camera.far
	# O corpo inteiro só aparece no espelho (Fase 13.10): a câmera não vê essa
	# camada. Ela vê o corpo de primeira pessoa (Fase 20.3).
	_camera.cull_mask &= ~AvatarBody.reflection_layers()
	_camera_rest = _camera.transform
	_avatar = PlayerAvatar.new()
	_avatar.name = "Avatar"
	add_child(_avatar)
	_build_arm()
	# A visão volta do config.cfg já pronta, sem a passagem.
	_view = AppConfig.get_view()
	_view_progress = 1.0 if _view == AppConfig.VIEW_THIRD else 0.0
	_facing = rotation.y
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
	# Com um painel aberto, o HUD sai de baixo dele (Fase 16.2).
	for panel: Node in [_pause_menu, _game_search, _world_map, _transit_panel]:
		panel.opened.connect(_update_hud_visibility)
		panel.closed.connect(_update_hud_visibility)

	_camera_feel = CameraFeel.new()
	add_child(_camera_feel)
	_camera_feel.setup(_camera, _camera_rest)
	_sensitivity_scale = AppConfig.get_mouse_sensitivity()
	_stick_scale = AppConfig.get_stick_sensitivity()
	AppConfig.settings_changed.connect(func(section: String, key: String) -> void:
		if section == "controls" and key == "mouse_sensitivity":
			_sensitivity_scale = AppConfig.get_mouse_sensitivity()
		elif section == "controls" and key == "stick_sensitivity":
			_stick_scale = AppConfig.get_stick_sensitivity()
		elif section == "controls" and key == "view":
			# A opção em Esc › Controles (ou o V): a passagem começa já (com o
			# menu aberto o mundo está pausado, e ela anda quando ele fecha).
			_view = AppConfig.get_view())

	_steps_player = _make_sound_player(-8.0)
	_body_player = _make_sound_player(-6.0)

	# Um jogo que abre (por exemplo, por fora do hub) tira o foco na hora,
	# como fecha o menu de pausa.
	GameLauncher.game_started.connect(func(_app_id: int, _source: Node) -> void:
		leave_focus(true))
	AppLauncher.app_launch_started.connect(func(_app_id: String, _source: Node) -> void:
		leave_focus(true))


func _unhandled_input(event: InputEvent) -> void:
	if in_intro or _focus_screen != null:
		return
	if event.is_action_pressed("toggle_view") and not event.is_echo():
		if toggle_view():
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative: o movimento em pixels da TELA. O "relative" vem na
		# escala da UI (que cresce com a janela), e o mouse ficaria mais lento
		# em telas grandes.
		look_by((event as InputEventMouseMotion).screen_relative)
	elif event is InputEventMouseButton and event.is_pressed() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# O Esc agora abre o menu de pausa (que solta o mouse); um clique na
		# janela prende o mouse de novo.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Gira a visão por um movimento do mouse em pixels da tela, vezes a
## sensibilidade (a da cena vezes a opção de Esc › Controles).
func look_by(screen_motion: Vector2) -> void:
	var sensitivity := mouse_sensitivity * _sensitivity_scale
	# Girar o corpo inteiro para os lados (eixo Y)...
	rotate_y(-screen_motion.x * sensitivity)
	# ...e só a "cabeça" para cima/baixo (eixo X).
	_head.rotate_x(-screen_motion.y * sensitivity)
	_clamp_pitch()


## O limite para olhar para cima e para baixo: o da primeira pessoa, ou o
## menor da terceira (mistura os dois durante a passagem).
func _clamp_pitch() -> void:
	var limit := deg_to_rad(lerpf(MAX_PITCH_DEGREES, THIRD_MAX_PITCH_DEGREES, _view_blend()))
	_head.rotation.x = clampf(_head.rotation.x, -limit, limit)


func _physics_process(delta: float) -> void:
	# Gravidade: enquanto estiver no ar, cai.
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_movement_locked():
		velocity.y = jump_velocity
		_play_random(_body_player, JUMP_SOUNDS)

	# Direção pedida pelo teclado, convertida para "para onde o jogador está virado".
	var input_dir := Vector2.ZERO if _is_movement_locked() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir != Vector2.ZERO:
		_hud.on_player_moved()  # o aviso de volta do jogo pode sair
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity := direction * speed

	# Aproxima a velocidade atual da desejada aos poucos (movimento mais suave).
	var blend := 1.0 - exp(-acceleration * delta)
	if not is_on_floor():
		blend *= AIR_CONTROL
	_sprinting = speed > walk_speed and input_dir != Vector2.ZERO
	velocity.x = lerpf(velocity.x, target_velocity.x, blend)
	velocity.z = lerpf(velocity.z, target_velocity.z, blend)

	var falling_speed := -velocity.y
	move_and_slide()
	_update_surface()
	_update_footsteps(delta, speed, falling_speed)
	_update_look_target()
	_update_interact(delta)
	if _arm_fresh_frames > 0:
		_arm_fresh_frames -= 1


## OLHAR COM O ANALÓGICO DIREITO: a cada quadro, vira a visão pela inclinação
## do analógico (zona morta de 0,2 vinda das ações look_*). A curva é
## quadrática: perto do centro vira devagar (precisão) e na ponta, rápido.
## Trava nos mesmos casos que o mouse: abertura, foco numa tela 3D e painel
## aberto.
func _look_with_stick(delta: float) -> void:
	if in_intro or _focus_screen != null or is_overlay_open():
		return
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick == Vector2.ZERO:
		return
	stick *= stick.length()  # curva quadrática
	var speed := STICK_TURN_SPEED * _stick_scale * delta
	rotate_y(-stick.x * speed)
	_head.rotate_x(-stick.y * speed)
	_clamp_pitch()


## A câmera ganha o balanço a cada quadro de tela (e não de física), para não
## engasgar em monitores de taxa alta. Parada durante o foco e a viagem.
func _process(delta: float) -> void:
	# O deslizar do foco primeiro: o resto (o corpo aparece?) já vê a câmera
	# no lugar deste quadro.
	_advance_slide(delta)
	_look_with_stick(delta)
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var free := _focus_screen == null and not _traveling and not in_intro
	_update_arm(delta)
	var rest := _view_rest()
	_camera_feel.set_rest(rest, 1.0 - _view_blend())
	_camera_feel.update(delta, horizontal_speed, _stride_progress / _stride_length,
			is_on_floor(), _sprinting, free)
	if _focus_screen == null and not free:
		# Viagem e abertura: o CameraFeel não mexe, mas a câmera acompanha o
		# braço (sem isto, chegando perto de uma parede ela ficaria dentro).
		_camera.transform = rest
	# O raio do olhar sai do ombro, e não da câmera: o que está entre a câmera
	# e o avatar não conta (na primeira pessoa, o braço é 0 e nada muda).
	_look_ray.position = Vector3(0.0, 0.0, -_arm_now)
	# O corpo anda junto. No foco, na viagem e na abertura ele some da câmera
	# (ela sai do lugar); na terceira pessoa, também com o braço curto demais.
	_update_facing(delta)
	_avatar.animate(horizontal_speed, is_on_floor(), _backwards)
	_avatar.set_view(AppConfig.VIEW_THIRD if _view_progress > 0.0 else AppConfig.VIEW_FIRST)
	var hidden := not free or _is_camera_close()
	if _focus_screen != null:
		hidden = not _update_focus_body()
	_avatar.set_hidden(hidden)


# --- Terceira pessoa ----------------------------------------------------------

## O braço da câmera (SpringArm3D: a peça da Godot que encolhe quando bate em
## algo). Ele não carrega a câmera (ela continua em Head/Camera3D, onde todo
## mundo a procura): o Player lê o comprimento dele e põe a câmera na ponta.
## Bate no mundo (camada 1) e nos volumes só da câmera (CameraBlock, Fase
## 20.5: a copa das árvores e as luminárias penduradas), e ignora a própria
## cápsula.
func _build_arm() -> void:
	_arm = SpringArm3D.new()
	_arm.name = "CameraArm"
	var tip := SphereShape3D.new()
	tip.radius = ARM_RADIUS
	_arm.shape = tip
	_arm.margin = ARM_MARGIN
	_arm.collision_mask = 1 | CameraBlock.mask()
	_arm.spring_length = _arm_reach
	_arm.add_excluded_object(get_rid())
	# Na primeira pessoa o braço fica parado (não gasta nada).
	_arm.process_mode = Node.PROCESS_MODE_DISABLED
	_head.add_child(_arm)


## A visão atual (AppConfig.VIEW_FIRST ou VIEW_THIRD).
func get_view() -> String:
	return _view


func is_third_person() -> bool:
	return _view == AppConfig.VIEW_THIRD


## ALTERNA A VISÃO (V / R3): grava a outra no config.cfg, e a passagem anima.
## Não alterna na abertura, na viagem, com painel aberto nem no foco numa tela.
## Devolve se alternou.
func toggle_view() -> bool:
	if in_intro or _traveling or is_overlay_open():
		return false
	var other := AppConfig.VIEW_FIRST if is_third_person() else AppConfig.VIEW_THIRD
	AppConfig.set_view(other)
	_view = other
	return true


func get_camera_arm() -> SpringArm3D:
	return _arm


## O comprimento do braço agora (m): 0 na primeira pessoa; na terceira, o do
## lugar (fora ou dentro de casa), encolhido pelo que o braço acertou.
func get_arm_length() -> float:
	return _arm_now


## A passagem já terminou (a câmera chegou à visão escolhida)?
func is_view_settled() -> bool:
	return _view_progress == (1.0 if is_third_person() else 0.0)


## A passagem, com curva suave: 0 na primeira pessoa, 1 na terceira.
func _view_blend() -> float:
	return smoothstep(0.0, 1.0, _view_progress)


## Na terceira pessoa (ou passando para ela), com o braço curto demais?
func _is_camera_close() -> bool:
	return _view_progress > 0.0 and _arm_now < ARM_CLOSE


## A cada quadro: anda a passagem e mede o braço. O ombro e o comprimento
## crescem juntos com a curva da passagem; o que o braço acertou corta o
## comprimento. O braço sempre mede o comprimento inteiro do lugar (assim a
## passagem não espera a física).
func _update_arm(delta: float) -> void:
	var target := 1.0 if is_third_person() else 0.0
	_view_progress = move_toward(_view_progress, target, delta / VIEW_SWITCH_SECONDS)
	_arm_reach_now = move_toward(_arm_reach_now, _arm_reach, ARM_REACH_SPEED * delta)
	var blend := _view_blend()
	var active := _view_progress > 0.0
	_arm.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_arm.position = Vector3(ARM_SHOULDER, ARM_HEIGHT, 0.0) * blend
	_arm.spring_length = _arm_reach_now
	_arm_now = blend * _arm_reach_now
	if active:
		var hit := _cast_arm() if _arm_fresh_frames > 0 else _arm.get_hit_length()
		_arm_now = minf(_arm_now, hit)
	_clamp_pitch()


## Mede o braço agora, como o SpringArm3D mede (a bolinha da ponta andando ao
## longo dele), sem esperar a física. Só logo depois de um teleporte.
func _cast_arm() -> float:
	if not is_inside_tree():
		return _arm.spring_length
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _arm.shape
	query.collision_mask = _arm.collision_mask
	query.exclude = [get_rid()]
	var from := _arm.global_transform
	query.transform = Transform3D(Basis.IDENTITY, from.origin)
	query.motion = from.basis.z.normalized() * _arm.spring_length
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return _arm.spring_length * result[0]


## Onde a câmera fica em repouso agora (no espaço da cabeça): dentro dela na
## primeira pessoa; na ponta do braço na terceira.
func _view_rest() -> Transform3D:
	return Transform3D(_camera_rest.basis, _camera_rest.origin + _arm.position + Vector3(0.0, 0.0, _arm_now))


## Para onde o corpo olha. Na primeira pessoa, para a frente do jogador. Na
## terceira:
##   - ombro: de costas para a câmera; andando de lado, vira para o lado; para
##     trás, olha para a frente e anda de ré;
##   - livre: vira para onde anda e fica assim parado (a câmera gira em volta).
func _update_facing(delta: float) -> void:
	_backwards = false
	if _view_progress <= 0.0 or _avatar.is_posed():
		_facing = rotation.y
		_avatar.rotation.y = 0.0
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var moving := flat.length() > AvatarBody.MOVE_THRESHOLD
	var follow := 1.0 - exp(-AVATAR_TURN_FOLLOW * delta)
	if third_person_style == STYLE_FREE:
		if moving:
			_facing = lerp_angle(_facing, atan2(-flat.x, -flat.z), follow)
		_avatar.rotation.y = wrapf(_facing - rotation.y, -PI, PI)
		return
	var local_yaw := 0.0
	if moving:
		var local := global_basis.inverse() * flat  # no espaço do jogador: -Z = frente
		if local.z > BACKWARD_SHARE * local.length():
			_backwards = true
			local = -local
		local_yaw = atan2(-local.x, -local.z)
	_avatar.rotation.y = lerp_angle(_avatar.rotation.y, local_yaw, follow)
	_facing = rotation.y + _avatar.rotation.y


## Lê a marca do chão em que o jogador pisa (a colisão de baixo do
## move_and_slide). Sem marca, é concreto; no ar (ou sem tocar o chão neste quadro), vale a última.
func _update_surface() -> void:
	if not is_on_floor():
		return
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if hit.get_normal().y > 0.7:
			var floor_surface := DEFAULT_SURFACE
			var collider := hit.get_collider() as Node
			if collider != null and collider.has_meta("footstep"):
				floor_surface = str(collider.get_meta("footstep"))
			_surface = floor_surface if FOOTSTEP_SURFACES.has(floor_surface) else DEFAULT_SURFACE
			return


## A superfície em que o jogador pisa agora ("concrete", "wood"...).
func get_surface() -> String:
	return _surface


## Passos: um som a cada "passada" (mais longa correndo); e um "tum" ao cair.
func _update_footsteps(delta: float, speed: float, falling_speed: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_camera_feel.land(falling_speed)
		if falling_speed > LAND_SOUND_MIN_SPEED:
			_play_random(_body_player, LAND_SOUNDS)
	_was_on_floor = on_floor

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var stride := SPRINT_STRIDE if speed > walk_speed else WALK_STRIDE
	_stride_length = stride
	# Na terceira pessoa o pé está na tela: o som sai quando o pé da animação
	# toca o chão (PlayerAvatar.take_step), e não pela distância andada.
	var by_animation := _view_progress >= 0.5
	var foot_down := _avatar.take_step()
	if on_floor and horizontal_speed > 1.0:
		_stride_progress += horizontal_speed * delta
		if _stride_progress >= stride:
			_stride_progress = 0.0
			if not by_animation:
				_play_step()
		if by_animation and foot_down:
			_play_step()
	else:
		# Parado: o primeiro passo ao voltar a andar sai logo.
		_stride_progress = stride * 0.7


## O som de um passo, na superfície em que se pisa (os testes contam).
func _play_step() -> void:
	steps_played += 1
	_play_random(_steps_player, FOOTSTEP_SURFACES[_surface])


func _make_sound_player(volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.bus = &"Passos"
	sound.volume_db = volume_db
	add_child(sound)
	return sound


## Toca um dos sons da lista, com o tom levemente diferente a cada vez.
func _play_random(sound: AudioStreamPlayer, streams: Array) -> void:
	sound.stream = streams.pick_random()
	sound.pitch_scale = randf_range(0.9, 1.1)
	sound.play()


## O seu corpo (o espelho reflete o inteiro e pede a pose do provador).
func get_avatar() -> PlayerAvatar:
	return _avatar


## O HUD do jogador (para o mundo mostrar avisos, por exemplo).
func get_hud() -> Hud:
	return _hud


func get_pause_menu() -> PauseMenu:
	return _pause_menu


func get_transit_panel() -> TransitPanel:
	return _transit_panel


## Algum painel por cima do jogo (menu, busca, mapa, metrô) está aberto, ou o
## jogador está usando uma tela 3D? Cada painel confere isto antes de abrir:
## só um de cada vez.
func is_overlay_open() -> bool:
	return _pause_menu.is_open() or _game_search.is_open() or _world_map.is_open() \
			or _transit_panel.is_open() or _focus_screen != null


## O ÚNICO lugar que decide se o HUD aparece: fora da abertura, sem foco numa
## tela 3D e sem painel aberto (menu, busca, mapa, metrô). Quem muda um desses
## estados chama esta função. Os avisos que chegam com o HUD escondido esperam
## na fila dele e aparecem quando ele volta.
func _update_hud_visibility() -> void:
	_hud.visible = not in_intro and not is_overlay_open()


func get_world_map() -> WorldMap:
	return _world_map


func get_game_search() -> GameSearch:
	return _game_search


## Abertura: a tela "GAME HUB" por cima (o mundo pode estar montando). O
## jogador fica parado, sem controles e sem HUD.
func start_intro() -> void:
	in_intro = true
	set_physics_process(false)
	_update_hud_visibility()


## Fim da abertura: o jogador ganha os controles e o HUD. Na primeira vez,
## o cartão de controles aparece antes do HUD (os avisos esperam ele sair).
func finish_intro() -> void:
	in_intro = false
	set_physics_process(true)
	if not AppConfig.get_seen_controls_hint():
		_hud.show_controls_hint()
	_update_hud_visibility()
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
	# O avatar chega virado para a frente (na terceira pessoa "livre", também).
	_facing = rotation.y
	_avatar.rotation.y = 0.0
	# O braço chega medido no lugar novo, e a câmera vai junto já (sem um
	# quadro dentro de um prédio, nem preso curto na medida do lugar velho).
	_arm_fresh_frames = 2
	if _arm != null and _focus_screen == null:
		_update_arm(0.0)
		_camera.transform = _view_rest()


## EM CASA: quem cobre um interior (a Home) chama isto quando o jogador entra
## (com o ambiente de dentro) e quando sai (null). Dentro:
##   - a câmera usa o ambiente de dentro, e não o do mundo;
##   - a câmera enxerga só INDOOR_CAMERA_FAR metros (o mundo lá fora fica longe
##     e nem é desenhado);
##   - o HUD esconde a bússola e o minimapa;
##   - o som do mundo fica abafado;
##   - o corpo troca de camada (em casa, quem o acende são as luzes da casa);
##   - o braço da terceira pessoa fica mais curto (ARM_LENGTH_INDOOR), aos
##     poucos (ARM_REACH_SPEED).
func set_indoors(environment: Environment) -> void:
	_indoors = environment != null
	_avatar.set_indoors(_indoors)
	# O braço vai até o novo comprimento aos poucos (_update_arm).
	_arm_reach = ARM_LENGTH_INDOOR if _indoors else ARM_LENGTH_OUTDOOR
	_camera.environment = environment
	_camera.far = INDOOR_CAMERA_FAR if _indoors else _outdoor_camera_far
	_hud.set_indoors(_indoors)
	_muffle_ambience(_indoors)
	_echo_footsteps(_indoors)


func is_indoors() -> bool:
	return _indoors


## Liga ou desliga o "abafado" no canal "Ambiente". Os dois efeitos são
## criados uma vez só e depois só ligados e desligados.
func _muffle_ambience(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Ambiente")
	if bus < 0:
		return
	var low_pass := -1
	var quieter := -1
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectLowPassFilter:
			low_pass = i
		elif effect is AudioEffectAmplify:
			quieter = i
	if low_pass < 0:
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = INDOOR_AMBIENCE_CUTOFF_HZ
		AudioServer.add_bus_effect(bus, filter)
		low_pass = AudioServer.get_bus_effect_count(bus) - 1
	if quieter < 0:
		var amplify := AudioEffectAmplify.new()
		amplify.volume_db = INDOOR_AMBIENCE_DB
		AudioServer.add_bus_effect(bus, amplify)
		quieter = AudioServer.get_bus_effect_count(bus) - 1
	AudioServer.set_bus_effect_enabled(bus, low_pass, on)
	AudioServer.set_bus_effect_enabled(bus, quieter, on)


## Liga ou desliga o eco no canal "Passos" (criado uma vez só, como o abafado).
func _echo_footsteps(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Passos")
	if bus < 0:
		return
	var reverb := -1
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectReverb:
			reverb = i
	if reverb < 0:
		var effect := AudioEffectReverb.new()
		effect.room_size = INDOOR_ECHO_ROOM
		effect.wet = INDOOR_ECHO_WET
		effect.dry = 1.0
		AudioServer.add_bus_effect(bus, effect)
		reverb = AudioServer.get_bus_effect_count(bus) - 1
	AudioServer.set_bus_effect_enabled(bus, reverb, on)


func is_traveling() -> bool:
	return _traveling


## Viajando ou usando uma tela 3D: o jogador não anda nem pula.
func _is_movement_locked() -> bool:
	return _traveling or _focus_screen != null


## FOCO NUMA TELA 3D: a câmera desliza até a frente da tela
## (screen.get_camera_pose), o mouse aparece, o jogador para e o HUD some. A
## tela recebe set_focused(true, jogador) e passa a cuidar do mouse e do
## teclado; o Esc dela chama leave_focus. Enquanto isso, is_overlay_open() é
## true: o menu de pausa, a busca e o mapa não abrem.
func focus_on(screen: Node3D) -> void:
	if _focus_screen != null or not _can_interact() or not screen.has_method("get_camera_pose"):
		return
	_focus_screen = screen
	_focus_leaving = false
	_update_hud_visibility()
	_reset_interact_hold()
	velocity = Vector3(0.0, velocity.y, 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var window := get_viewport().get_visible_rect().size
	var pose: Transform3D = screen.get_camera_pose(_camera.fov, window.x / maxf(window.y, 1.0))
	# Na terceira pessoa o corpo ainda aparece no começo do caminho.
	_focus_body_shown = is_third_person() and not _is_camera_close()
	_slide_camera(pose)
	screen.set_focused(true, self)


## Com o foco numa tela, desliza a câmera para outra pose (ex.: o zoom num
## monitor da mesa). Não faz nada fora do foco ou saindo dele.
func move_focus_camera(pose: Transform3D) -> void:
	if _focus_screen != null and not _focus_leaving:
		_slide_camera(pose)


## Sai do foco: a câmera volta para o repouso da visão atual (a cabeça, ou a
## ponta do braço) e o jogador ganha os controles
## de novo. "instant" pula a animação (ex.: um jogo abriu).
func leave_focus(instant: bool = false) -> void:
	if _focus_screen == null or (_focus_leaving and not instant):
		return
	_focus_leaving = true
	if is_instance_valid(_focus_screen):
		_focus_screen.set_focused(false)
	if instant:
		_end_focus()
	else:
		_slide_camera(_head.global_transform * _view_rest(), _end_focus)


func is_focused() -> bool:
	return _focus_screen != null


func get_focused_screen() -> Node3D:
	return _focus_screen


## Anima a câmera da posição atual até "target" (no mundo), suavizando a
## partida e a chegada (curva seno). "on_done" é chamado no fim. Quem anda é
## o _advance_slide, no _process do jogador (Fase 20.5: antes era um Tween,
## que mexia na câmera DEPOIS de o jogador decidir se o corpo aparece, e o
## corpo ficava um quadro a mais à vista com a câmera já perto dele).
func _slide_camera(target: Transform3D, on_done: Callable = Callable()) -> void:
	_slide_from = _camera.global_transform
	_slide_to = target
	_slide_done = on_done
	_slide_t = 0.0
	_slide_elapsed = 0.0


## Um quadro do deslizar da câmera (no foco).
func _advance_slide(delta: float) -> void:
	if _slide_t >= 1.0:
		return
	_slide_elapsed += delta
	var x := clampf(_slide_elapsed / FOCUS_SLIDE_SECONDS, 0.0, 1.0)
	_slide_t = x
	_camera.global_transform = _slide_from.interpolate_with(_slide_to, (1.0 - cos(PI * x)) / 2.0)
	if x >= 1.0 and _slide_done.is_valid():
		var done := _slide_done
		_slide_done = Callable()
		done.call()


## No foco, o corpo aparece? (true = sim). Primeira pessoa: nunca (a câmera
## veria o corpo sem cabeça por fora). Terceira: indo, até a câmera chegar
## perto dele ou na pose (e aí some de vez); voltando, quando ela se afasta.
func _update_focus_body() -> bool:
	if not is_third_person():
		_focus_body_shown = false
		return false
	var far := _camera_body_distance() > FOCUS_BODY_CLEARANCE
	if _focus_leaving:
		_focus_body_shown = far
	elif not far or _slide_t >= 1.0:
		_focus_body_shown = false
	return _focus_body_shown


## A distância (m) da câmera ao eixo do corpo (dos pés ao alto da cabeça).
func _camera_body_distance() -> float:
	var feet := global_position + Vector3.UP * 0.2
	var top := _head.global_position + Vector3.UP * 0.2
	var point := _camera.global_position
	var axis := top - feet
	var t := clampf((point - feet).dot(axis) / maxf(axis.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(feet + axis * t)


## Fim do foco: câmera no lugar, HUD de volta e mouse preso (se o hub não foi
## dormir por causa de um jogo; aí quem cuida do mouse é o HubWindow).
func _end_focus() -> void:
	_slide_t = 1.0
	_slide_done = Callable()
	_camera.transform = _view_rest()
	_focus_screen = null
	_focus_leaving = false
	_update_hud_visibility()
	if not HubWindow.is_sleeping:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	# Com o foco numa tela, o cartão some (o raio continua preso à câmera).
	var hit := _look_target()
	if _focus_screen == null and hit != null:
		info = _find_look_info(hit)
	if info != _current_look_info:
		_current_look_info = info
		look_info_changed.emit(info)
		var text: String = info.get("title", "")
		if not str(info.get("detail", "")).is_empty():
			text += " — " + str(info["detail"])
		if text != _current_look_text:
			_current_look_text = text
			look_target_changed.emit(text)


## INTERAGIR com E. Contrato de quem quer responder (o jogador sobe pela
## árvore a partir do que o raio acertou, como no cartão):
##   interact(player)      : chamado num toque de E (ou quando a segurada enche);
##   get_hold_seconds()    : opcional; > 0 = precisa SEGURAR o E por esse tempo;
##   set_hold(ratio)       : opcional; avisa o progresso (0 a 1) da segurada,
##                           e 0 quando solta ou o jogador olha para outro lado.
## O cartão mostra a dica pela chave "action" do get_look_info().
func _update_interact(delta: float) -> void:
	var pressed := Input.is_action_pressed("interact")
	var target: Node = null
	var hit := _look_target()
	if _can_interact() and hit != null:
		target = _find_interactable(hit)
	if target != _interact_target:
		_reset_interact_hold()
		_interact_target = target
	if target != null:
		var hold_seconds: float = target.get_hold_seconds() if target.has_method("get_hold_seconds") else 0.0
		if hold_seconds <= 0.0:
			if pressed and not _interact_was_pressed:
				target.interact(self)
		elif pressed:
			if not _interact_fired:
				_interact_hold += delta
				_set_interact_hold(_interact_hold / hold_seconds)
				if _interact_hold >= hold_seconds:
					_interact_fired = true
					_set_interact_hold(0.0)
					target.interact(self)
		else:
			_reset_interact_hold()
	_interact_was_pressed = pressed


## Dá para interagir agora? Não na abertura, em viagem, com painel aberto ou
## com um jogo abrindo/rodando.
func _can_interact() -> bool:
	return not in_intro and not _traveling and not is_overlay_open() \
			and not GameLauncher.is_busy() and not AppLauncher.is_busy()


## O que o raio do olhar acertou, se estiver ao alcance (look_distance)
## medido a partir da cabeça do jogador, e não da câmera: na terceira pessoa,
## não dá para interagir de mais longe que na primeira. null = nada.
func _look_target() -> Object:
	if not _look_ray.is_colliding():
		return null
	if _look_ray.get_collision_point().distance_to(_head.global_position) > look_distance:
		return null
	return _look_ray.get_collider()


func _find_interactable(hit: Object) -> Node:
	var node := hit as Node
	while node != null:
		if node.has_method("interact"):
			return node
		node = node.get_parent()
	return null


func _reset_interact_hold() -> void:
	if _interact_hold > 0.0:
		_set_interact_hold(0.0)
	_interact_hold = 0.0
	_interact_fired = false


func _set_interact_hold(ratio: float) -> void:
	if is_instance_valid(_interact_target) and _interact_target.has_method("set_hold"):
		_interact_target.set_hold(clampf(ratio, 0.0, 1.0))


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
