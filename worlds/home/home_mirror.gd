class_name HomeMirror
extends Node3D
## O ESPELHO da casa (Fase 13.10): você se vê nele, com o avatar escolhido.
##
## Como funciona (resolução baixa e só de perto, decisão 4 do plano da fase):
##   - o jogador é só uma câmera, sem corpo. O espelho põe um corpo (AvatarBody)
##     onde o jogador está, numa camada de desenho que só o espelho enxerga
##     (AvatarBody.REFLECTION_LAYER): o jogador nunca vê o próprio corpo de
##     dentro, mas o reflexo vê;
##   - uma segunda câmera fica no ponto "refletido" da câmera do jogador (atrás
##     da parede), virada de frente para o espelho, e desenha num SubViewport
##     pequeno. O recorte dela (projeção FRUSTUM com deslocamento) bate com a
##     moldura, e o plano de corte fica no vidro: nada atrás da parede aparece;
##   - o vidro mostra essa imagem espelhada na horizontal;
##   - o SubViewport SÓ desenha com o jogador em casa, a até ACTIVE_DISTANCE do
##     vidro, na frente dele e com o vidro na tela. Fora disso fica desligado e
##     o vidro guarda a última imagem. Na Leve, desenha um quadro sim, um não.
##
## O PROVADOR (Fase 13.11): olhar o espelho e apertar E foca nele
## (player.focus_on): a câmera recua e se afasta para o lado, o seu avatar fica
## parado em frente ao vidro e o painel (AvatarPanel) aparece à direita, com os
## visuais e as cores prontas. Esc volta. Quem tem o foco é o espelho, que cumpre
## o mesmo contrato da tela do computador (get_camera_pose e set_focused).
##
## Convenção: a origem fica no chão, no meio do espelho, e a FRENTE (+Z) aponta
## para dentro da sala.

## Avisa quando o foco começa (true) e termina (false).
signal focus_changed(focused: bool)

## Tamanho do vidro (largura, altura) e altura do centro dele. A proporção é a
## mesma das resoluções do GraphicsQuality.mirror_resolution (8:15).
const GLASS_SIZE: Vector2 = Vector2(1.0, 1.875)
const GLASS_CENTER_Y: float = 1.12
const FRAME_WIDTH: float = 0.08
const FRAME_DEPTH: float = 0.06
const FRAME_WOOD: Color = Color(0.22, 0.14, 0.08)
## Até onde (m, da câmera ao vidro) o espelho desenha.
const ACTIVE_DISTANCE: float = 4.5
## Até onde (m) a câmera do espelho enxerga além do vidro.
const MIRROR_FAR: float = 12.0
## Velocidade (m/s) a partir da qual o corpo anda em vez de ficar parado.
const WALK_SPEED: float = 0.6
## Provador: de quanto (m) a câmera recua do vidro, quanto ela se afasta para o
## lado (o espelho fica à esquerda, e o painel à direita) e a altura dela.
const FOCUS_DISTANCE: float = 2.4
const FOCUS_SIDE: float = 1.0
const FOCUS_HEIGHT: float = 1.25
## Onde o avatar fica parado no provador, na frente do vidro.
const FITTING_SPOT: float = 1.1
## Dica do E no cartão.
const ACTION_TEXT: String = "{interact} para trocar de roupa"
const GLASS_SHADER: Shader = preload("res://worlds/home/home_mirror.gdshader")

var _viewport: SubViewport
var _camera: Camera3D
var _environment: Environment
var _glass: MeshInstance3D
var _body: AvatarBody
var _walking: bool = false
var _active: bool = false
var _every_other_frame: bool = false
var _frame: int = 0
var _focused: bool = false
var _player: Node = null
var _panel: AvatarPanel


func _ready() -> void:
	add_to_group("home_mirror")
	_build_frame()
	_build_viewport()
	_build_glass()
	_build_body()
	_build_look_area()
	_panel = AvatarPanel.new()
	_panel.name = "AvatarPanel"
	add_child(_panel)
	_apply_quality()
	AppConfig.settings_changed.connect(_on_settings_changed)
	# A casa põe tudo o que desenha na camada do interior DEPOIS dos móveis
	# ficarem prontos: o corpo volta para a camada do reflexo logo em seguida.
	_body.set_render_layers.call_deferred(AvatarBody.reflection_layers())


## Esc no provador volta para a sala (a tela do computador faz o mesmo).
func _input(event: InputEvent) -> void:
	if not _focused:
		return
	if event.is_action_pressed("release_mouse") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _player != null and _player.has_method("leave_focus"):
			_player.leave_focus()


func _process(_delta: float) -> void:
	var player := _find_player()
	var camera := player.get_viewport().get_camera_3d() if player != null else null
	var on := camera != null and _should_draw(player, camera)
	_set_active(on)
	if not on:
		return
	if _focused:
		_stand_in_fitting_spot()
	else:
		_follow(player)
	_place_camera(camera.global_position)
	_environment.background_color = _home_environment_value("background_color", Color.BLACK)
	_environment.ambient_light_color = _home_environment_value("ambient_light_color", Color.WHITE)
	_environment.ambient_light_energy = _home_environment_value("ambient_light_energy", 0.3)
	_frame += 1
	if _every_other_frame and _frame % 2 == 1:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


# --- Provador (o contrato do player.focus_on) ------------------------------------

func get_look_info() -> Dictionary:
	return {"title": "Espelho", "detail": "Escolher o seu visual", "action": ACTION_TEXT}


## E apertado olhando para o espelho (o jogador já confere se pode interagir).
func interact(player: Node) -> void:
	if player.has_method("focus_on"):
		player.focus_on(self)


## Onde a câmera fica no provador: de frente para o vidro, recuada e deslocada
## para o lado, para o painel não cobrir o espelho.
func get_camera_pose(_fov_degrees: float, _aspect: float) -> Transform3D:
	var spot := to_global(Vector3(FOCUS_SIDE, FOCUS_HEIGHT, FOCUS_DISTANCE))
	return Transform3D(global_basis.orthonormalized(), spot)


func set_focused(on: bool, player: Node = null) -> void:
	if on == _focused:
		return
	_focused = on
	_player = player if on else null
	_panel.show_panel(on)
	focus_changed.emit(on)


func is_focused() -> bool:
	return _focused


func get_panel() -> AvatarPanel:
	return _panel


## O avatar fica parado na frente do vidro, de frente para ele (o jogador está
## com a câmera noutro lugar).
func _stand_in_fitting_spot() -> void:
	_body.global_position = to_global(Vector3(0.0, 0.0, FITTING_SPOT))
	_body.global_basis = Basis.looking_at(get_normal())  # +Z do corpo = para o vidro
	if _walking:
		_walking = false
		_body.play_idle()


## O espelho está desenhando agora?
func is_active() -> bool:
	return _active


func get_viewport_node() -> SubViewport:
	return _viewport


func get_mirror_camera() -> Camera3D:
	return _camera


func get_body() -> AvatarBody:
	return _body


## Meio do vidro e a frente dele (o lado da sala), no mundo.
func get_glass_center() -> Vector3:
	return to_global(Vector3(0.0, GLASS_CENTER_Y, FRAME_DEPTH + 0.004))


func get_normal() -> Vector3:
	return global_basis.z.normalized()


## Onde fica, do outro lado do vidro, o reflexo de um ponto da sala.
func reflect_point(point: Vector3) -> Vector3:
	var normal := get_normal()
	return point - 2.0 * (point - get_glass_center()).dot(normal) * normal


## Desenhar ou não: em casa, perto, na frente do vidro e com ele na tela.
func _should_draw(player: Node, camera: Camera3D) -> bool:
	if not player.has_method("is_indoors") or not player.is_indoors():
		return false
	var eye := camera.global_position
	var distance := (eye - get_glass_center()).dot(get_normal())
	if distance < 0.1 or eye.distance_to(get_glass_center()) > ACTIVE_DISTANCE:
		return false
	for corner in _glass_corners():
		if camera.is_position_in_frustum(corner):
			return true
	return false


## O meio e os quatro cantos do vidro, no mundo.
func _glass_corners() -> Array[Vector3]:
	var half := GLASS_SIZE / 2.0
	var z := FRAME_DEPTH + 0.004
	var corners: Array[Vector3] = [to_global(Vector3(0.0, GLASS_CENTER_Y, z))]
	for x in [-half.x, half.x]:
		for y in [-half.y, half.y]:
			corners.append(to_global(Vector3(x, GLASS_CENTER_Y + y, z)))
	return corners


func _set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	_body.visible = on
	_body.get_animation_player().active = on
	if not on:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## O corpo vai para onde o jogador está, virado para onde ele olha, andando
## ou parado conforme a velocidade.
func _follow(player: Node3D) -> void:
	var forward: Vector3 = -player.global_basis.z
	forward.y = 0.0
	_body.global_position = player.global_position
	if forward.length() > 0.001:
		_body.global_basis = Basis.looking_at(-forward.normalized())  # o corpo olha para +Z
	var velocity: Vector3 = player.get("velocity") if player.get("velocity") != null else Vector3.ZERO
	var walking := Vector2(velocity.x, velocity.z).length() > WALK_SPEED
	if walking != _walking:
		_walking = walking
		if walking:
			_body.play_walk()
		else:
			_body.play_idle()


## Câmera do espelho no reflexo do olho, de frente para o vidro (olhando para
## dentro da sala), com o recorte na moldura e o corte no plano do vidro.
func _place_camera(eye: Vector3) -> void:
	var normal := get_normal()
	var distance := maxf((eye - get_glass_center()).dot(normal), 0.05)
	var mirrored := reflect_point(eye)
	# -Z da câmera = a normal (olha para a sala); o "para cima" é o do espelho.
	var up := global_basis.y.normalized()
	var z_axis := -normal
	var x_axis := up.cross(z_axis).normalized()
	_camera.global_transform = Transform3D(Basis(x_axis, up, z_axis), mirrored)
	var local := _camera.global_transform.affine_inverse() * get_glass_center()
	_camera.set_frustum(GLASS_SIZE.y, Vector2(local.x, local.y), distance, distance + MIRROR_FAR)


func _home_environment_value(property: String, fallback: Variant) -> Variant:
	var home := get_parent()
	if home != null and home.has_method("get_environment") and home.get_environment() != null:
		return home.get_environment().get(property)
	return fallback


func _find_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		_apply_quality()
	elif section == "avatar":
		_body.apply_spec(AvatarSpec.from_dict(AppConfig.get_avatar()))


## Resolução do reflexo e o "um quadro sim, um não" vêm da qualidade.
func _apply_quality() -> void:
	var level := AppConfig.get_quality()
	_viewport.size = GraphicsQuality.mirror_resolution(level)
	_every_other_frame = GraphicsQuality.mirror_every_other_frame(level)


# --- Montagem -------------------------------------------------------------------

## A moldura de madeira escura em volta do vidro, com colisão (o jogador não
## entra no espelho).
func _build_frame() -> void:
	var wood := HomeMaterials.wood(FRAME_WOOD, false, 0.4)
	var outer := GLASS_SIZE + Vector2(FRAME_WIDTH * 2.0, FRAME_WIDTH * 2.0)
	var back := HomeDecor.make_box(self, "MirrorBack", Vector3(outer.x, outer.y, 0.02),
			Vector3(0.0, GLASS_CENTER_Y, 0.01), wood, true)
	back.set_meta("mirror_part", true)
	var half := GLASS_SIZE / 2.0
	for y in [-half.y - FRAME_WIDTH / 2.0, half.y + FRAME_WIDTH / 2.0]:
		HomeDecor.make_box(self, "MirrorFrame", Vector3(outer.x, FRAME_WIDTH, FRAME_DEPTH),
				Vector3(0.0, GLASS_CENTER_Y + y, FRAME_DEPTH / 2.0), wood, false)
	for x in [-half.x - FRAME_WIDTH / 2.0, half.x + FRAME_WIDTH / 2.0]:
		HomeDecor.make_box(self, "MirrorFrame", Vector3(FRAME_WIDTH, GLASS_SIZE.y, FRAME_DEPTH),
				Vector3(x, GLASS_CENTER_Y, FRAME_DEPTH / 2.0), wood, false)


## A "tela escondida" do reflexo e a câmera dela. Sem sombras, sem MSAA e com
## um ambiente próprio, sem SSAO, brilho nem névoa (o mais barato possível).
func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Reflection"
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.positional_shadow_atlas_size = 0
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Filme neutro: a imagem do vidro passa de novo pelo "filme de cor" da tela
	# (AgX). Com o AgX aqui também, o reflexo sairia escuro demais.
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_camera = Camera3D.new()
	_camera.name = "MirrorCamera"
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.environment = _environment
	# Vê o interior da casa e o corpo do reflexo; nada da cidade.
	_camera.cull_mask = Home.INTERIOR_LAYER_MASK | AvatarBody.reflection_layers()
	_viewport.add_child(_camera)


## O vidro: a imagem do reflexo, espelhada na horizontal, sem luz própria.
func _build_glass() -> void:
	_glass = MeshInstance3D.new()
	_glass.name = "MirrorGlass"
	var quad := QuadMesh.new()
	quad.size = GLASS_SIZE
	_glass.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = GLASS_SHADER
	material.set_shader_parameter("reflection", _viewport.get_texture())
	_glass.material_override = material
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glass.position = Vector3(0.0, GLASS_CENTER_Y, FRAME_DEPTH + 0.004)
	add_child(_glass)


## Alvo "olhável" (camada 3): o raio da câmera acha o espelho por aqui.
func _build_look_area() -> void:
	var look := Area3D.new()
	look.name = "LookArea"
	look.collision_layer = 4
	look.collision_mask = 0
	look.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GLASS_SIZE.x + 0.2, GLASS_SIZE.y + 0.2, 0.2)
	shape.shape = box
	shape.position = Vector3(0.0, GLASS_CENTER_Y, 0.1)
	look.add_child(shape)
	add_child(look)


## O seu corpo, com as cores do config.cfg ([avatar]). Escondido e sem
## animar enquanto o espelho não desenha.
func _build_body() -> void:
	_body = AvatarBody.new()
	_body.name = "ReflectionBody"
	_body.spec = AvatarSpec.from_dict(AppConfig.get_avatar())
	_body.cast_shadows = false
	_body.position = Vector3(0.0, 0.0, 1.0)
	add_child(_body)
	_body.play_idle()
	_body.visible = false
	_body.get_animation_player().active = false
