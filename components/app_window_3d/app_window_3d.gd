class_name AppWindow3D
extends Screen3D
## O TELÃO DE APP (Fase 14.19): uma Screen3D que mostra a janela de um app.
## Em vez de empurrar eventos para um SubViewport de interface, ele entrega
## tudo a uma "fonte de janela" (AppWindowSource):
##   - a imagem vem de source.get_texture(), desenhada por um AppWindowView
##     (com o cursor por cima, desenhado pelo hub);
##   - o mouse vira pixel da janela (send_pointer, send_button, send_scroll);
##   - as teclas vão para send_key;
##   - Esc curto vai para o app; SEGURAR o Esc (EXIT_HOLD_TIME) sai do telão.
##     O botão B do controle segue a mesma regra;
##   - a fonte recebe o tamanho do telão (resize) ao ser ligada e ao focar.
## Não toca no compositor: a fonte é quem fala com ele.

## Quanto tempo segurar o Esc (ou o B) para sair, em segundos.
const EXIT_HOLD_TIME := 0.6

var _source: AppWindowSource = null
var _view: AppWindowView
var _hold_time: float = 0.0
var _holding: bool = false
var _hold_is_joypad: bool = false


func _init() -> void:
	screen_name = "Telão"
	detail = ""
	action_text = "{interact} para usar"
	screen_size = Vector2(1.6, 0.9)
	resolution = Vector2i(1280, 720)


func _ready() -> void:
	_view = AppWindowView.new()
	set_content(_view)
	super._ready()
	set_process(true)


## Liga (ou troca) a janela mostrada. null deixa o telão livre.
func set_source(source: AppWindowSource) -> void:
	if _source != null and _source != source:
		_source.pointer_leave()
		_source.set_focused(false)
	_source = source
	_cancel_hold()
	if _source != null:
		_source.resize(resolution)
		_source.set_focused(is_focused())
	_update_view()


func get_source() -> AppWindowSource:
	return _source


## 0 a 1: quanto do Esc longo já passou (a barrinha e os testes leem).
func get_exit_progress() -> float:
	return clampf(_hold_time / EXIT_HOLD_TIME, 0.0, 1.0) if _holding else 0.0


func get_look_info() -> Dictionary:
	var title := _source.get_title() if _source != null else ""
	return {
		"title": title if title != "" else screen_name,
		"detail": detail if _source == null else "Segure Esc para sair",
		"action": action_text,
	}


func set_focused(on: bool, player: Node = null) -> void:
	var changed := on != is_focused()
	super.set_focused(on, player)
	if not changed:
		return
	_cancel_hold()
	if _source != null:
		if on:
			_source.resize(resolution)
		else:
			_source.pointer_leave()
		_source.set_focused(on)
	_update_view()


func _process(delta: float) -> void:
	if _holding:
		_hold_time += delta
		if _hold_time >= EXIT_HOLD_TIME:
			_cancel_hold()
			if _player != null and _player.has_method("leave_focus"):
				_player.leave_focus()
	_update_view()


func _input(event: InputEvent) -> void:
	if not is_focused():
		return
	if _is_exit_key(event):
		get_viewport().set_input_as_handled()
		_handle_exit_key(event)
		return
	if event is InputEventMouse:
		_handle_mouse(event as InputEventMouse)
		# O mouse é todo do telão durante o foco, como na Screen3D.
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_F11:
			return  # tela cheia continua sendo do hub
		if _source != null:
			_source.send_key(key)
		get_viewport().set_input_as_handled()


func _is_exit_key(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	return false


## Esc/B apertado começa a contar; solto antes da hora é um Esc curto e vai
## para o app (apertar e soltar de uma vez). Segurar até a hora sai (no _process).
func _handle_exit_key(event: InputEvent) -> void:
	if event.is_echo():
		return
	var pressed := event.is_pressed()
	var is_joypad := event is InputEventJoypadButton
	if pressed:
		_holding = true
		_hold_is_joypad = is_joypad
		_hold_time = 0.0
	elif _holding and _hold_is_joypad == is_joypad:
		_cancel_hold()
		_send_short_escape()


func _send_short_escape() -> void:
	if _source == null:
		return
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = pressed
		_source.send_key(key)


func _handle_mouse(event: InputEventMouse) -> void:
	if _source == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var pixel := ray_to_pixel(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
	if pixel == Vector2.INF:
		_source.pointer_leave()  # a mira saiu do telão
		return
	var inside := Rect2(Vector2.ZERO, Vector2(resolution)).has_point(pixel)
	var clamped := pixel.clamp(Vector2.ZERO, Vector2(resolution) - Vector2.ONE)
	if event is InputEventMouseMotion:
		_source.send_pointer(clamped)
		_view.cursor = clamped
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not inside and button.pressed:
			return  # clique fora do telão não vira clique no app
		_source.send_pointer(clamped)
		_view.cursor = clamped
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_source.send_scroll(Vector2(0.0, 1.0))
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_source.send_scroll(Vector2(0.0, -1.0))
			MOUSE_BUTTON_WHEEL_LEFT:
				if button.pressed:
					_source.send_scroll(Vector2(-1.0, 0.0))
			MOUSE_BUTTON_WHEEL_RIGHT:
				if button.pressed:
					_source.send_scroll(Vector2(1.0, 0.0))
			_:
				_source.send_button(button.button_index, button.pressed)


func _cancel_hold() -> void:
	_holding = false
	_hold_time = 0.0


func _update_view() -> void:
	if _view == null:
		return
	_view.texture = _source.get_texture() if _source != null else null
	_view.idle_text = "Livre" if _source == null else ""
	_view.exit_progress = get_exit_progress()
	if not is_focused():
		_view.cursor = Vector2.INF
	_view.queue_redraw()
