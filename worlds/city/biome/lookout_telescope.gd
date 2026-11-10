class_name LookoutTelescope
extends Node3D
## A luneta de latão do mirante (Fase 17.8; o modelo é do Blender:
## tools/blender/gerar_luneta.py). Olhar para ela e apertar E aproxima a vista
## da cidade: o jogador entra no foco (player.focus_on, o mesmo contrato da
## tela do computador e do espelho), e a câmera desliza da ocular para a
## frente, pela linha até o alvo (a praça e a torre do relógio), até
## ZOOM_SHARE do caminho, parando antes do que estiver no meio. Por cima, o
## campo da luneta (um círculo, com a borda escura) e a dica de voltar.
## Esc ou E volta.
##
## Por que a câmera anda, e não muda o FOV: o CameraFeel do jogador refaz o
## FOV a cada quadro (a corrida, a porta carregando), e o contrato do foco dá
## só a pose da câmera. Andar pela linha da vista dá o mesmo "chegar perto"
## sem mudar o contrato do player.gd.
##
## Convenção: a origem no chão, no meio da base; o tubo aponta para -Z.

## Avisa quando o foco começa (true) e termina (false).
signal focus_changed(focused: bool)

const MODEL: String = "lookout/telescope"
## A ocular, no espaço do nó (gerar_luneta.py).
const EYEPIECE: Vector3 = Vector3(0.0, 1.43, 0.44)
const BRASS_COLOR: Color = Color(0.74, 0.53, 0.25)
const IRON_COLOR: Color = Color(0.07, 0.07, 0.075)
## Quanto do caminho até o alvo a câmera anda (0 = fica na ocular).
const ZOOM_SHARE: float = 0.55
## A câmera para isto antes do que estiver no caminho (um prédio, a torre).
const CLEARANCE: float = 12.0
## O raio que procura o que está no caminho começa depois do guarda-corpo e
## das paredes invisíveis do mirante.
const RAY_START: float = 10.0
## O corpo (só a coluna e a base: o tubo fica acima da cabeça de quem passa).
const BODY_RADIUS: float = 0.22
const BODY_HEIGHT: float = 1.45
const ACTION_TEXT: String = "{interact} para olhar a cidade"
const VIEW_SHADER: Shader = preload("res://worlds/city/biome/telescope_view.gdshader")

## Para onde a luneta olha (no mundo). Quem monta põe o alvo (a praça).
var target: Vector3 = Vector3(0.0, 8.0, 0.0)
var _focused: bool = false
var _player: Node = null
var _overlay: CanvasLayer


## Monta a luneta. Chamar depois de pôr o nó no lugar (virado para o alvo).
func build() -> void:
	name = "LookoutTelescope"
	# As malhas do modelo como vieram (uma por material).
	var parts: Array[Array] = [["brass", TrailModels.metal(BRASS_COLOR, 0.32)],
			["iron", TrailModels.metal(IRON_COLOR, 0.55, 0.4)]]
	for part in parts:
		var instance := MeshInstance3D.new()
		instance.name = "Telescope_%s" % part[0]
		instance.mesh = TrailModels.mesh(MODEL, part[0])
		instance.material_override = part[1]
		instance.visibility_range_end = 160.0
		add_child(instance)
	var body := StaticBody3D.new()
	body.name = "TelescopeBody"
	body.set_meta("footstep", "wood")
	var column := CylinderShape3D.new()
	column.radius = BODY_RADIUS
	column.height = BODY_HEIGHT
	var shape := CollisionShape3D.new()
	shape.shape = column
	shape.position.y = BODY_HEIGHT / 2.0
	body.add_child(shape)
	add_child(body)
	# A área que o raio da mira acerta (camada 3, como o espelho): o tubo e a coluna.
	var look := Area3D.new()
	look.name = "LookArea"
	look.collision_layer = 4
	look.collision_mask = 0
	look.monitoring = false
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 1.6, 1.4)
	var look_shape := CollisionShape3D.new()
	look_shape.shape = box
	look_shape.position = Vector3(0.0, 0.85, -0.05)
	look.add_child(look_shape)
	add_child(look)


# --- O contrato do player.focus_on ------------------------------------------------

func get_look_info() -> Dictionary:
	return {"title": "Luneta", "detail": "Ver a cidade de perto", "action": ACTION_TEXT}


## E apertado olhando para a luneta (o jogador já confere se pode interagir).
func interact(player: Node) -> void:
	if player.has_method("focus_on"):
		player.focus_on(self)


## A pose da câmera no foco: na linha da ocular até o alvo, ZOOM_SHARE do
## caminho à frente, parando CLEARANCE antes do que estiver no meio.
func get_camera_pose(_fov_degrees: float, _aspect: float) -> Transform3D:
	var eye := to_global(EYEPIECE)
	var travel := zoom_travel(eye, target)
	var direction := (target - eye).normalized()
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(eye + direction * RAY_START, eye + direction * travel)
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			travel = maxf(RAY_START * 0.5, eye.distance_to(hit["position"]) - CLEARANCE)
	return Transform3D(Basis.looking_at(direction), eye + direction * travel)


## Quanto a câmera anda da ocular até o alvo, sem nada no caminho (m).
static func zoom_travel(eye: Vector3, to: Vector3) -> float:
	return eye.distance_to(to) * ZOOM_SHARE


func set_focused(on: bool, player: Node = null) -> void:
	if on == _focused:
		return
	_focused = on
	_player = player if on else null
	_show_overlay(on)
	focus_changed.emit(on)


func is_focused() -> bool:
	return _focused


## Esc ou E na luneta voltam para o mirante.
func _input(event: InputEvent) -> void:
	if not _focused:
		return
	if event.is_action_pressed("release_mouse") or event.is_action_pressed("ui_cancel") \
			or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _player != null and _player.has_method("leave_focus"):
			_player.leave_focus()


## O campo da luneta e a dica de voltar, por cima da vista (só no foco).
func _show_overlay(on: bool) -> void:
	if not on:
		if _overlay != null:
			_overlay.queue_free()
			_overlay = null
		return
	_overlay = CanvasLayer.new()
	_overlay.name = "TelescopeView"
	_overlay.layer = 4
	var field := ColorRect.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = VIEW_SHADER
	field.material = material
	_overlay.add_child(field)
	# A dica por load(): a KeyHint usa o InputDevice (um autoload), e o nome da
	# classe aqui puxaria os autoloads antes da hora nos testes (-s).
	var theme_script: GDScript = load("res://ui/hub_theme.gd")
	var key_script: GDScript = load("res://ui/key_hint.gd")
	var hint := HBoxContainer.new()
	hint.theme = theme_script.get_theme()
	hint.add_theme_constant_override("separation", 10)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_bottom = -36.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(key_script.create("back"))
	hint.add_child(theme_script.label("voltar para o mirante", &"HubBodyLight"))
	_overlay.add_child(hint)
	add_child(_overlay)
	# Um quadro de fade, para o círculo não "estalar" na tela.
	var tween := create_tween()
	material.set_shader_parameter("strength", 0.0)
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("strength", v),
			0.0, 1.0, 0.35)


func get_overlay() -> CanvasLayer:
	return _overlay
