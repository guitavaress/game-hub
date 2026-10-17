extends Node
## AppSessions: liga "app aberto" a "janela do compositor" (autoload, Fase 14.21)
## e o compositor aos MONITORES DA MESA (Fase 14.28).
##
## É o dono do compositor Wayland do hub (AppCompositor): cria o nó na primeira
## vez que precisa, chama o poll() a cada quadro e escuta as janelas que os
## apps abrem lá dentro.
##
## A mesa tem três monitores (DeskMonitor3D, grupo "desk_monitors"). O
## compositor ganha uma saída para cada um (set_outputs, do tamanho da
## resolução do monitor) e cada monitor ganha uma fonte (OutputSource) que
## traduz o mouse e o teclado dele para a saída certa. Este sistema não conhece
## mundos: acha os monitores pelo grupo (regra 1).
##
## Regras:
##   - a primeira janela nova depois de um open_app() é do app que foi aberto;
##     outra janela do mesmo cliente (mesmo pid) conta como do mesmo app, e uma
##     de um app aberto por fora (apontado para o socket do hub) tem o app_id dela;
##   - janela nova vai para o monitor onde o mouse esteve por último (o do meio
##     se ainda não houve mouse), ocupa a área útil dele (sem a faixa da barra)
##     e ganha o foco. Quem arruma várias janelas é o DeskLayout (14.29);
##   - clicar numa janela dá o foco e a põe por cima; o teclado segue a janela em
##     foco (ou o menu e a barra do Omarchy, que o compositor trata);
##   - sem monitores na cena, a janela é fechada (não tem onde mostrar).

## A janela de um app abriu e já está num monitor.
signal window_ready(id: int, app_id: String)
## A janela fechou.
signal window_gone(id: int)

## Cria o compositor: func() -> Node (o nó nativo do AppCompositor, ou um falso). Os testes trocam.
var compositor_factory: Callable = _create_compositor
## Abre o app no compositor: func(app: DesktopApp) -> bool. Os testes trocam.
var opener: Callable = _open_in_compositor

var _compositor: Node = null
## Já tentamos criar o compositor? (se falhou, não tenta de novo a cada clique)
var _tried: bool = false
## O app que acabou de ser aberto e ainda espera a primeira janela ("" = nenhum).
var _pending_app: String = ""
## pid do cliente -> id do app (para a segunda janela do mesmo programa).
var _app_by_pid: Dictionary = {}
## As janelas abertas: id -> título, id -> app, id -> saída onde estão.
var _titles: Dictionary = {}
var _app_of_window: Dictionary = {}
var _window_output: Dictionary = {}
## Os ids das janelas, da mais de baixo para a mais de cima.
var _stack: Array[int] = []
## A janela com o foco da mesa (0 = nenhuma) e se o jogador está sentado.
var _desk_focus: int = 0
var _seated: bool = false
## A saída onde o mouse esteve por último (-1 = ainda nenhuma).
var _pointer_output: int = -1
## Quantas saídas o compositor tem e a fonte de cada monitor (saída -> OutputSource).
var _output_count: int = 0
var _output_sources: Dictionary = {}


## Um monitor da mesa, visto pelo DeskMonitor3D. Traduz o que o monitor pede
## (pixels da saída, teclas da Godot, rolagem) para o que o compositor entende.
class OutputSource extends DeskMonitorSource:
	var output: int = 0
	var _sessions: Node
	## O último pixel do mouse nesta saída (o clique precisa saber onde caiu).
	var _last: Vector2 = Vector2.ZERO

	func _init(sessions: Node, output_index: int) -> void:
		_sessions = sessions
		output = output_index

	func get_texture() -> Texture2D:
		return _sessions.output_texture(output)

	func send_key(event: InputEventKey) -> void:
		if event.echo:
			return  # a repetição de tecla é feita pelo próprio app
		var code := AppCompositor.evdev_code(event)
		if code >= 0:
			_sessions.compositor_call("key_focused", [code, event.pressed])

	func send_pointer(pixel: Vector2) -> void:
		_last = pixel
		_sessions.pointer_moved(output, pixel)

	func send_button(button: MouseButton, pressed: bool) -> void:
		var code := AppCompositor.mouse_button_code(button)
		if code < 0:
			return
		if pressed:
			_sessions.clicked(output, _last)
		_sessions.compositor_call("pointer_button", [code, pressed])

	## O monitor manda y positivo para cima; o compositor, positivo para baixo.
	func send_scroll(delta: Vector2) -> void:
		_sessions.compositor_call("pointer_axis", [delta.x, -delta.y, true])

	func get_title() -> String:
		return _sessions.focus_title()

	func set_focused(on: bool) -> void:
		_sessions.set_seated(on)

	func pointer_leave() -> void:
		_sessions.compositor_call("pointer_leave", [])


## Com o hub dormindo (um jogo da Steam, ou um app aberto por fora) o
## compositor não roda: sem poll, os apps não recebem "quadro mostrado" e
## ficam ociosos, e nenhuma textura sobe. Ao acordar, volta tudo.
func is_dormant() -> bool:
	return HubWindow.is_sleeping


func _process(_delta: float) -> void:
	if _compositor != null and not is_dormant():
		_compositor.call("poll")


# --- Perguntas ---------------------------------------------------------------

## Este computador sabe ter um compositor? (Linux, com a extensão compilada.)
func is_supported() -> bool:
	return AppCompositor.is_available()


## Dá para abrir apps no mundo? Precisa do compositor (extensão compilada, só
## Linux) e de um lugar com monitores (a mesa da casa).
func can_open_in_world() -> bool:
	if _monitors().is_empty() or not _ensure_compositor():
		return false
	_attach_sources()
	return true


## Quantas janelas de apps estão abertas nos monitores.
func window_count() -> int:
	return _titles.size()


func get_compositor() -> Node:
	return _compositor


## O app da janela ("" se não existe).
func app_of(window_id: int) -> String:
	return str(_app_of_window.get(window_id, ""))


## A janela com o foco da mesa (0 = nenhuma) e a saída onde ela está.
func focused_window() -> int:
	return _desk_focus


func output_of(window_id: int) -> int:
	return int(_window_output.get(window_id, -1))


## O título da janela em foco ("" = nenhuma).
func focus_title() -> String:
	return str(_titles.get(_desk_focus, ""))


# --- Os monitores da mesa ----------------------------------------------------

## O jogador pediu a mesa (E num monitor ainda sem sinal): liga o compositor,
## cria uma saída por monitor e dá a cada monitor a sua fonte. Devolve false
## se não deu (sem extensão, ou sem monitores).
func attach_monitors() -> bool:
	if _monitors().is_empty() or not _ensure_compositor():
		return false
	if _monitors().size() != _output_count:
		_setup_outputs()
	_attach_sources()
	return true


## Os monitores da cena, na ordem das saídas (esquerda, meio, direita).
func _monitors() -> Array[DeskMonitor3D]:
	var list: Array[DeskMonitor3D] = []
	if not is_inside_tree():
		return list
	for node in get_tree().get_nodes_in_group("desk_monitors"):
		if node is DeskMonitor3D:
			list.append(node)
	list.sort_custom(func(a: DeskMonitor3D, b: DeskMonitor3D) -> bool: return a.output_index < b.output_index)
	return list


## Uma saída para cada monitor, do tamanho da resolução dele.
func _setup_outputs() -> void:
	var sizes: Array[Vector2i] = []
	for monitor in _monitors():
		sizes.append(monitor.resolution)
	if sizes.is_empty() or not bool(_compositor.call("set_outputs", sizes)):
		return
	_output_count = sizes.size()
	# As janelas que estavam numa saída que sumiu perdem o lugar: põe de novo.
	for id: int in _stack:
		_place(id, mini(output_of(id), _output_count - 1))


func _attach_sources() -> void:
	for monitor in _monitors():
		var index := monitor.output_index
		if not _output_sources.has(index):
			_output_sources[index] = OutputSource.new(self, index)
		if monitor.get_source() != _output_sources[index]:
			monitor.set_source(_output_sources[index])


## A imagem da saída (null se ainda não houve quadro).
func output_texture(output: int) -> Texture2D:
	return _compositor.call("get_output_texture", output) as Texture2D if _compositor != null else null


## Para a fonte falar com o compositor sem guardar o nó.
func compositor_call(method: String, args: Array) -> void:
	if _compositor != null:
		_compositor.callv(method, args)


## O jogador sentou (true) ou levantou (false): o teclado vai para a janela em
## foco; levantando, nenhuma janela fica "ativa" e as teclas soltam.
func set_seated(on: bool) -> void:
	if on == _seated:
		return
	_seated = on
	if _compositor != null:
		_compositor.call("focus", _desk_focus if on else 0)


## O mouse andou na saída `output`, no pixel dado.
func pointer_moved(output: int, pixel: Vector2) -> void:
	_pointer_output = output
	if _compositor != null:
		_compositor.call("pointer_motion_output", output, pixel.x, pixel.y)


## Clique apertado na saída: a janela embaixo ganha o foco e vai para cima
## (uma camada, como a barra, não muda o foco das janelas).
func clicked(output: int, pixel: Vector2) -> void:
	if _compositor == null:
		return
	var id := int(_compositor.call("window_at", output, pixel.x, pixel.y))
	if id > 0 and _titles.has(id):
		_focus_window(id)


func _focus_window(id: int) -> void:
	_desk_focus = id
	_stack.erase(id)
	_stack.append(id)
	_compositor.call("raise", id)
	if _seated:
		_compositor.call("focus", id)


## Põe a janela na área útil da saída (sem a faixa da barra), do tamanho dela.
func _place(id: int, output: int) -> void:
	if _compositor == null or output < 0:
		return
	var area := _compositor.call("get_usable_area", output) as Rect2i
	if area.size.x <= 0 or area.size.y <= 0:
		return
	_window_output[id] = output
	_compositor.call("place", id, output, area.position.x, area.position.y, area.size.x, area.size.y)


## A barra (ou outra camada) mudou a área útil: as janelas da saída se ajustam.
func _on_usable_area_changed(output: int, _rect: Rect2i) -> void:
	for id: int in _stack:
		if output_of(id) == output:
			_place(id, output)


# --- Abrir -------------------------------------------------------------------

## Abre o app dentro do compositor. true = o processo começou; a janela chega
## depois, pelo sinal window_ready. false = não deu para abrir.
func open_app(app: DesktopApp) -> bool:
	if not _ensure_compositor():
		return false
	if not bool(opener.call(app)):
		return false
	_pending_app = app.id
	return true


## O app esperado desistiu (não veio janela a tempo): a próxima janela não é dele.
func cancel_pending() -> void:
	_pending_app = ""


## Fecha a janela (o app recebe o pedido de fechar).
func close_window(window_id: int) -> void:
	if _compositor != null:
		_compositor.call("close", window_id)


# --- O compositor ------------------------------------------------------------

func _ensure_compositor() -> bool:
	if _compositor != null:
		return true
	if _tried:
		return false
	_tried = true
	var node := compositor_factory.call() as Node
	if node == null:
		return false
	_compositor = node
	node.name = "Compositor"
	add_child(node)
	node.connect("window_opened", _on_window_opened)
	node.connect("window_closed", _on_window_closed)
	node.connect("title_changed", _on_title_changed)
	node.connect("usable_area_changed", _on_usable_area_changed)
	_setup_outputs()
	_attach_sources()
	return true


func _on_window_opened(id: int, wl_app_id: String, title: String, pid: int) -> void:
	if _monitors().is_empty():
		close_window(id)  # sem monitor: não tem onde mostrar
		return
	var app_id := _pending_app
	if not app_id.is_empty():
		_pending_app = ""
		if pid > 0:
			_app_by_pid[pid] = app_id
	elif _app_by_pid.has(pid):
		app_id = _app_by_pid[pid]
	else:
		app_id = wl_app_id  # um app aberto por fora, apontado para o socket do hub
	_titles[id] = title
	_app_of_window[id] = app_id
	_stack.append(id)
	_place(id, _target_output())
	_focus_window(id)
	window_ready.emit(id, app_id)


## A saída da janela nova: onde o mouse esteve por último, ou a do meio.
@warning_ignore("integer_division")
func _target_output() -> int:
	if _pointer_output >= 0 and _pointer_output < _output_count:
		return _pointer_output
	return _output_count / 2


func _on_window_closed(id: int) -> void:
	if not _titles.has(id):
		return
	_titles.erase(id)
	_app_of_window.erase(id)
	_window_output.erase(id)
	_stack.erase(id)
	if _desk_focus == id:
		_desk_focus = _stack.back() if not _stack.is_empty() else 0
		if _seated and _compositor != null:
			_compositor.call("focus", _desk_focus)
	window_gone.emit(id)


func _on_title_changed(id: int, title: String) -> void:
	if _titles.has(id):
		_titles[id] = title


# --- Os de verdade (os testes trocam) ----------------------------------------

func _create_compositor() -> Node:
	return AppCompositor.create()


func _open_in_compositor(app: DesktopApp) -> bool:
	var profile := ProjectSettings.globalize_path("user://apps/brave")
	DirAccess.make_dir_recursive_absolute(profile)
	return DesktopApps.launch_in_compositor(app, AppCompositor.environment(), profile)
