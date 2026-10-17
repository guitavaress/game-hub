class_name DeskMonitor3D
extends Screen3D
## UM MONITOR DA MESA (Fase 14.28): uma Screen3D que mostra uma SAÍDA do
## compositor (o "Linux de dentro": a barra, as janelas dos apps). A mesa tem
## três, no grupo "desk_monitors", e eles se comportam como UM assento:
##   - E em qualquer um deles "senta": a câmera enquadra os TRÊS (get_camera_pose);
##   - sentado, o mouse anda pelos três: o raio da câmera acha o monitor e o
##     pixel (cada monitor tem a sua fonte, DeskMonitorSource, que fala com a
##     saída certa) e o cursor é desenhado pelo hub, só no monitor onde está;
##   - o teclado vai para quem tem o teclado lá dentro (o menu, a barra ou a
##     janela em foco), pela fonte;
##   - Esc curto vai para o app; SEGURAR o Esc (EXIT_HOLD_TIME) levanta. O botão
##     B do controle segue a mesma regra.
## Quem recebe o E é o "líder" do assento: o monitor que ganhou o foco do
## jogador. Ele cuida de todo o mouse e do teclado; os outros só desenham.
## Não toca no compositor: a fonte é quem fala com ele.

## O jogador apertou E num monitor ainda sem fonte (o compositor não ligou):
## quem usa pode ligar e dar a fonte (set_source) antes do foco.
signal seat_requested

## Quanto tempo segurar o Esc (ou o B) para levantar, em segundos.
const EXIT_HOLD_TIME := 0.6

## Qual saída do compositor este monitor mostra (0 = esquerda, 1 = meio...).
var output_index: int = 0
## Dá para ligar um compositor aqui? (O mundo diz; sem ele o monitor explica.)
var available: bool = false:
	set = set_available

var _source: DeskMonitorSource = null
var _view: DeskMonitorView
## O monitor que está cuidando do assento (null = ninguém sentado).
var _leader: DeskMonitor3D = null
var _hold_time: float = 0.0
var _holding: bool = false
var _hold_is_joypad: bool = false
## Só no líder: o monitor onde o mouse está, o pixel nele, o monitor onde o
## clique começou (o botão apertado "prende" o mouse nele) e quantos botões
## estão apertados.
var _under: DeskMonitor3D = null
var _cursor: Vector2 = Vector2.INF
var _capture: DeskMonitor3D = null
var _buttons_down: int = 0
## O desenho do monitor sem sinal já está atualizado.
var _idle_drawn: bool = false


func _init() -> void:
	screen_name = "Monitor"
	action_text = "{interact} para sentar"
	screen_size = Vector2(0.8, 0.45)
	resolution = Vector2i(1920, 1080)
	focus_fill = 0.9


func _ready() -> void:
	_view = DeskMonitorView.new()
	set_content(_view)
	super._ready()
	add_to_group("desk_monitors")
	set_process(true)
	_update_view()


## Liga (ou troca) a saída mostrada. null deixa o monitor sem sinal.
func set_source(source: DeskMonitorSource) -> void:
	if _source != null and _source != source:
		_source.pointer_leave()
		_source.set_focused(false)
	_source = source
	if _source != null:
		_source.set_focused(is_focused())
	_update_view()


func get_source() -> DeskMonitorSource:
	return _source


func set_available(value: bool) -> void:
	available = value
	_idle_drawn = false
	_update_view()


## 0 a 1: quanto do Esc longo já passou (a barrinha e os testes leem).
func get_exit_progress() -> float:
	return clampf(_hold_time / EXIT_HOLD_TIME, 0.0, 1.0) if _holding else 0.0


func get_look_info() -> Dictionary:
	if _source == null:
		return {
			"title": screen_name,
			"detail": "Sem sinal" if available else "O Linux do hub precisa do compositor (só no Linux)",
			"action": action_text if available else "",
		}
	var title := _source.get_title()
	return {"title": title if title != "" else screen_name, "detail": "Segure Esc para levantar", "action": action_text}


## E: senta (e liga o compositor, se ainda não ligou). Sem compositor, nada.
func interact(player: Node) -> void:
	if _source == null and available:
		seat_requested.emit()
	if _source == null:
		return
	super.interact(player)


## Onde a câmera fica ao sentar: de frente para o monitor do meio, longe o
## bastante para os TRÊS caberem na janela (os cantos dos lados incluídos).
@warning_ignore("integer_division")
func get_camera_pose(fov_degrees: float, aspect: float) -> Transform3D:
	var seat := _seat()
	var middle: DeskMonitor3D = seat[seat.size() / 2]
	var basis := middle.global_basis.orthonormalized()
	var to_local := Transform3D(basis, middle.global_position).affine_inverse()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var nearest := 0.0  # o canto mais perto da câmera (z maior) precisa caber também
	for monitor in seat:
		for corner in monitor._corners():
			var p: Vector3 = to_local * corner
			low = low.min(Vector2(p.x, p.y))
			high = high.max(Vector2(p.x, p.y))
			nearest = maxf(nearest, p.z)
	var half_tan := tan(deg_to_rad(fov_degrees) / 2.0)
	var by_height := ((high.y - low.y) / 2.0) / half_tan
	var by_width := ((high.x - low.x) / 2.0) / (half_tan * maxf(aspect, 0.1))
	var distance := maxf(by_height, by_width) / focus_fill + nearest
	var center := Vector3((low.x + high.x) / 2.0, (low.y + high.y) / 2.0, distance)
	return Transform3D(basis, middle.global_position + basis * center)


func set_focused(on: bool, player: Node = null) -> void:
	var changed := on != is_focused()
	super.set_focused(on, player)
	if not changed:
		return
	_cancel_hold()
	_under = null
	_capture = null
	_buttons_down = 0
	_cursor = Vector2.INF
	for monitor in _seat():
		monitor._leader = self if on else null
		if monitor._source != null:
			monitor._source.set_focused(on)
			if not on:
				monitor._source.pointer_leave()
		monitor._update_view()


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
		# O mouse é todo da mesa durante o assento, como na Screen3D.
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_F11:
			return  # tela cheia continua sendo do hub
		var source := _seat_source()
		if source != null:
			source.send_key(key)
		get_viewport().set_input_as_handled()


func _is_exit_key(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	return false


## Esc/B apertado começa a contar; solto antes da hora é um Esc curto e vai
## para o app (apertar e soltar de uma vez). Segurar até a hora levanta (no _process).
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
	var source := _seat_source()
	if source == null:
		return
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = pressed
		source.send_key(key)


# --- O mouse pelos três monitores -----------------------------------------------

func _handle_mouse(event: InputEventMouse) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := camera.project_ray_origin(event.position)
	var direction := camera.project_ray_normal(event.position)
	var hit := _pick(origin, direction)
	if event is InputEventMouseMotion:
		# Com um botão apertado o mouse fica preso no monitor do clique (dá para arrastar para fora).
		var target: DeskMonitor3D = _capture if _capture != null else hit.get("monitor")
		if target == null:
			_leave_pointer()
			return
		var pixel: Vector2 = target._clamped_pixel(origin, direction) if _capture != null else hit["pixel"]
		_move_pointer(target, pixel)
	elif event is InputEventMouseButton:
		_handle_button(event as InputEventMouseButton, origin, direction, hit)


func _handle_button(button: InputEventMouseButton, origin: Vector3, direction: Vector3, hit: Dictionary) -> void:
	var wheel := button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
			MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	var target: DeskMonitor3D = _capture if _capture != null else hit.get("monitor")
	if target == null or (button.pressed and hit.is_empty() and _capture == null):
		return  # clique fora dos monitores não vira clique no app
	var pixel: Vector2 = target._clamped_pixel(origin, direction) if _capture != null else hit["pixel"]
	_move_pointer(target, pixel)
	var source := target._source
	if source == null:
		return
	if wheel:
		if button.pressed:
			match button.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					source.send_scroll(Vector2(0.0, 1.0))
				MOUSE_BUTTON_WHEEL_DOWN:
					source.send_scroll(Vector2(0.0, -1.0))
				MOUSE_BUTTON_WHEEL_LEFT:
					source.send_scroll(Vector2(-1.0, 0.0))
				_:
					source.send_scroll(Vector2(1.0, 0.0))
		return
	if button.pressed:
		_buttons_down += 1
		_capture = target
	else:
		_buttons_down = maxi(_buttons_down - 1, 0)
		if _buttons_down == 0:
			_capture = null
	source.send_button(button.button_index, button.pressed)


func _move_pointer(target: DeskMonitor3D, pixel: Vector2) -> void:
	_under = target
	_cursor = pixel
	if target._source != null:
		target._source.send_pointer(pixel)


## A mira saiu de todos os monitores.
func _leave_pointer() -> void:
	if _under != null and _under._source != null:
		_under._source.pointer_leave()
	_under = null
	_cursor = Vector2.INF


## O monitor do assento que o raio acerta (o mais perto) e o pixel nele:
## {"monitor": DeskMonitor3D, "pixel": Vector2}, ou {} se errar todos.
func _pick(origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INF
	for monitor in _seat():
		var pixel := monitor.ray_to_pixel(origin, direction)
		if pixel == Vector2.INF or not Rect2(Vector2.ZERO, Vector2(monitor.resolution)).has_point(pixel):
			continue
		var distance := origin.distance_to(monitor.pixel_to_world(pixel))
		if distance < best_distance:
			best_distance = distance
			best = {"monitor": monitor, "pixel": pixel}
	return best


## O pixel deste monitor onde o raio bate, preso à borda (para arrastar até fora).
func _clamped_pixel(origin: Vector3, direction: Vector3) -> Vector2:
	var pixel := ray_to_pixel(origin, direction)
	if pixel == Vector2.INF:
		return _cursor if _cursor != Vector2.INF else Vector2.ZERO
	return pixel.clamp(Vector2.ZERO, Vector2(resolution) - Vector2.ONE)


# --- O assento ---------------------------------------------------------------------

## Os monitores da mesa, na ordem das saídas (esquerda, meio, direita).
func _seat() -> Array[DeskMonitor3D]:
	var list: Array[DeskMonitor3D] = []
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group("desk_monitors"):
			if node is DeskMonitor3D:
				list.append(node)
	if not list.has(self):
		list.append(self)
	list.sort_custom(func(a: DeskMonitor3D, b: DeskMonitor3D) -> bool: return a.output_index < b.output_index)
	return list


## Quem recebe o teclado: a fonte deste monitor, ou a primeira da mesa.
func _seat_source() -> DeskMonitorSource:
	if _source != null:
		return _source
	for monitor in _seat():
		if monitor._source != null:
			return monitor._source
	return null


## Os quatro cantos da tela, no mundo.
func _corners() -> Array[Vector3]:
	var size := Vector2(resolution)
	return [pixel_to_world(Vector2.ZERO), pixel_to_world(Vector2(size.x, 0.0)),
			pixel_to_world(size), pixel_to_world(Vector2(0.0, size.y))]


func _cancel_hold() -> void:
	_holding = false
	_hold_time = 0.0


func _update_view() -> void:
	if _view == null:
		return
	_view.texture = _source.get_texture() if _source != null else null
	_view.idle_detail = "" if available or _source != null else "O Linux do hub precisa do compositor (só no Linux)"
	var leader := _leader
	_view.exit_progress = leader.get_exit_progress() if leader != null else 0.0
	_view.cursor = leader._cursor if leader != null and leader._under == self else Vector2.INF
	# Sem fonte e sem ninguém sentado, basta desenhar uma vez (não gasta a cada quadro).
	if _source != null or leader != null or not _idle_drawn:
		_idle_drawn = _source == null and leader == null
		_view.queue_redraw()
