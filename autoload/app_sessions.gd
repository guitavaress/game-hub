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
##     se ainda não houve mouse) e ganha o foco; o DeskLayout (14.29) arruma as
##     janelas do monitor na área útil dele (sem a faixa da barra), no máximo 3
##     por monitor (cheio, vai para o vizinho; tudo cheio, a janela é fechada);
##   - clicar numa janela dá o foco e a põe por cima; o teclado segue a janela em
##     foco (ou o menu e a barra do Omarchy, que o compositor trata);
##   - sem monitores na cena, a janela é fechada (não tem onde mostrar);
##   - ATALHOS DO OMARCHY (14.30): sentado à mesa, o hub liga o submap do
##     Hyprland (pelo HubWindow), as combinações chegam como teclas, e as que
##     estão na tabela do OmarchyBinds viram ação: um comando aberto DENTRO do
##     hub (omarchy-launch-terminal, omarchy-menu...) ou uma ação do arranjo
##     (fechar, tela cheia, foco, mover de monitor). O resto vai para o app.

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
## O monitor "ativo" (-1 = ainda nenhum): o da janela em foco, ou um monitor
## vazio para onde o jogador foi com SUPER + seta ou SUPER + 1/2/3. O zoom da
## câmera segue este.
var _active_output: int = -1
## A saída onde o mouse esteve por último (-1 = ainda nenhuma).
var _pointer_output: int = -1
## Quantas saídas o compositor tem e a fonte de cada monitor (saída -> OutputSource).
var _output_count: int = 0
var _output_sources: Dictionary = {}
## O arranjo das janelas nos monitores.
var _layout := DeskLayout.new()

## Os atalhos do Omarchy (14.30). Os testes trocam os ganchos.
## Lê a tabela de atalhos: func() -> Dictionary (veja OmarchyBinds).
var binds_loader: Callable = OmarchyBinds.read_table
## Abre um comando dentro do hub: func(command: String) -> bool.
var command_runner: Callable = AppCompositor.run_command
## Liga/renova/desliga o submap do Hyprland (pelo HubWindow): sentar liga (devolve
## se deu), a cada KEEPALIVE_SECONDS renova, levantar desliga.
var seat_begin_hook: Callable = func() -> bool: return HubWindow.seat_begin()
var seat_keepalive_hook: Callable = func() -> void: HubWindow.seat_keepalive()
var seat_end_hook: Callable = func() -> void: HubWindow.seat_end()

## O Quickshell do Omarchy de dentro (14.31): sobe junto com o compositor e
## desce com ele. start: func() -> int (o pid, ou -1); stop: func(pid: int).
var shell_starter: Callable = AppCompositor.start_shell
var shell_stopper: Callable = func(pid: int) -> void: OS.kill(pid)
var _shell_pid: int = -1

## Janelas de até este tamanho (em pixels, na largura ou na altura) são
## auxiliares, não apps: o wl-clipboard do Omarchy abre uma de 1×1. O hub não as
## põe nos monitores nem as fecha.
const MIN_WINDOW_SIZE := 8

## De quanto em quanto tempo, sentado, o submap é definido de novo e o vigia renovado.
const KEEPALIVE_SECONDS := 5.0

var _binds: Dictionary = {}
var _binds_loaded: bool = false
## Os atalhos estão valendo (o submap ligou). Fora do Hyprland ficam desligados:
## todas as teclas vão para o app.
var _shortcuts_on: bool = false
var _keepalive_left: float = 0.0
## As teclas cujo "apertou" virou atalho: o "soltou" delas também não vai para o app.
var _swallowed: Dictionary = {}


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
		if _sessions.handle_shortcut(event):
			return  # era um atalho do Omarchy
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

	func get_focus_output() -> int:
		return _sessions.active_output()

	func set_focused(on: bool) -> void:
		_sessions.set_seated(on)

	func pointer_leave() -> void:
		_sessions.compositor_call("pointer_leave", [])


## Com o hub dormindo (um jogo da Steam, ou um app aberto por fora) o
## compositor não roda: sem poll, os apps não recebem "quadro mostrado" e
## ficam ociosos, e nenhuma textura sobe. Ao acordar, volta tudo.
func is_dormant() -> bool:
	return HubWindow.is_sleeping


func _process(delta: float) -> void:
	if _compositor != null and not is_dormant():
		_compositor.call("poll")
	if _shortcuts_on:
		_keepalive_left -= delta
		if _keepalive_left <= 0.0:
			_keepalive_left = KEEPALIVE_SECONDS
			seat_keepalive_hook.call()


func _exit_tree() -> void:
	_stop_shell()
	if _shortcuts_on:
		_shortcuts_on = false
		seat_end_hook.call()


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


## Quantas janelas ainda cabem nos monitores (0 = cheio).
func free_slots() -> int:
	return _layout.free_slots() if _output_count > 0 else DeskLayout.MAX_PER_OUTPUT

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


## O monitor ativo (veja _active_output): onde está a janela em foco ou o
## monitor vazio escolhido; -1 se nenhum.
func active_output() -> int:
	if _active_output >= 0 and _active_output < _output_count:
		return _active_output
	return output_of(_desk_focus)


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
	_sync_areas()


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
	if on:
		if not _binds_loaded:
			_binds_loaded = true
			_binds = binds_loader.call()
		_shortcuts_on = not _binds.is_empty() and bool(seat_begin_hook.call())
		_keepalive_left = KEEPALIVE_SECONDS
	elif _shortcuts_on:
		_shortcuts_on = false
		seat_end_hook.call()
	_swallowed.clear()


## Uma tecla do jogador sentado: se for um atalho do Omarchy, executa e devolve
## true (a tecla não vai para o app); senão false. O "soltou" de uma tecla que
## virou atalho também é engolido.
func handle_shortcut(event: InputEventKey) -> bool:
	if not _shortcuts_on:
		return false
	if not event.pressed:
		return _swallowed.erase(event.keycode)
	var actions: Array = _binds.get(OmarchyBinds.key_id(event), [])
	if actions.is_empty():
		return false
	_swallowed[event.keycode] = true
	if not event.echo:  # segurar a tecla não repete o atalho
		for action: Dictionary in actions:
			_run_shortcut(action)
	return true


func _run_shortcut(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"exec":
			command_runner.call(str(action.get("cmd", "")))
		"desk":
			match str(action.get("name", "")):
				"close":
					close_focused()
				"fullscreen":
					toggle_fullscreen()
				"focus_dir":
					var directions := {"l": Vector2i.LEFT, "r": Vector2i.RIGHT, "u": Vector2i.UP, "d": Vector2i.DOWN}
					focus_direction(directions.get(str(action.get("dir", "")), Vector2i.ZERO))
				"focus_output":
					focus_output(int(action.get("output", -1)))
				"move_output":
					move_focused_to(int(action.get("output", -1)))


## Foco para a janela de cima do monitor `output` (0, 1, 2). Num monitor vazio,
## só o marca como ativo (a câmera do zoom vai para lá). false se o monitor não existe.
func focus_output(output: int) -> bool:
	if output < 0 or output >= _output_count:
		return false
	for i in range(_stack.size() - 1, -1, -1):
		if output_of(_stack[i]) == output:
			_focus_window(_stack[i])
			return true
	_active_output = output  # monitor vazio: só a câmera (o zoom) vai para lá
	return true


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
	_active_output = output_of(id)
	_stack.erase(id)
	_stack.append(id)
	_compositor.call("raise", id)
	if _seated:
		_compositor.call("focus", id)


## Passa as áreas úteis de todas as saídas ao arranjo e arruma tudo. As janelas
## de saídas que sumiram e não couberam em outra são fechadas.
func _sync_areas() -> void:
	var areas: Array[Rect2i] = []
	for o in _output_count:
		areas.append(_usable(o))
	for id in _layout.set_areas(areas):
		close_window(id)
		_forget(id)
	for o in _output_count:
		_apply(o)


func _usable(output: int) -> Rect2i:
	var area := _compositor.call("get_usable_area", output) as Rect2i
	return area if area.size.x > 0 and area.size.y > 0 else Rect2i(Vector2i.ZERO, Vector2i(1920, 1080))


## Manda para o compositor o lugar de cada janela da saída (a em tela cheia vai por cima).
func _apply(output: int) -> void:
	if _compositor == null:
		return
	var rects := _layout.rects(output)
	for id: int in _layout.windows_on(output):
		var rect: Rect2i = rects[id]
		_window_output[id] = output
		_compositor.call("place", id, output, rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	var full := _layout.fullscreen_of(output)
	if full != 0:
		_compositor.call("raise", full)


## A barra (ou outra camada) mudou a área útil: as janelas da saída se ajustam.
func _on_usable_area_changed(output: int, _rect: Rect2i) -> void:
	if output >= 0 and output < _output_count:
		_layout.set_area(output, _usable(output))
		_apply(output)


# --- Ações do teclado (os atalhos do Omarchy chamam, 14.30) ------------------

## Foco para a janela vizinha na direção (Vector2i.LEFT, RIGHT, UP, DOWN),
## inclusive em outro monitor. true se mudou.
func focus_direction(direction: Vector2i) -> bool:
	if _compositor == null:
		return false
	# Num monitor vazio (a janela em foco está em outro), as setas andam de monitor em monitor.
	if direction.x != 0 and _active_output >= 0 and _active_output != output_of(_desk_focus):
		return _step_monitor(direction.x)
	var next := _layout.neighbor(_desk_focus, direction)
	if next != 0:
		_focus_window(next)
		return true
	# Sem janela naquela direção: vai para o monitor do lado, mesmo vazio.
	return direction.x != 0 and _step_monitor(direction.x)


## Anda `step` monitores (-1 esquerda, 1 direita) a partir do ativo: foca a janela
## de cima dele, ou só o marca como ativo se estiver vazio. false na borda.
@warning_ignore("integer_division")
func _step_monitor(step: int) -> bool:
	var from := active_output()
	if from < 0:
		from = _output_count / 2
	var target := clampi(from + step, 0, _output_count - 1)
	if target == from or _output_count == 0:
		return false
	return focus_output(target)


## Tela cheia na janela em foco (liga/desliga). true se ficou em tela cheia.
func toggle_fullscreen() -> bool:
	if _desk_focus == 0:
		return false
	var on := _layout.toggle_fullscreen(_desk_focus)
	_apply(_layout.output_of(_desk_focus))
	return on


## Manda a janela em foco para o monitor `output` (0, 1, 2). false se não deu
## (não existe, já está lá ou está cheio).
func move_focused_to(output: int) -> bool:
	var from := _layout.output_of(_desk_focus)
	if not _layout.move_to(_desk_focus, output):
		return false
	_apply(from)
	_apply(output)
	return true


## Pede para fechar a janela em foco.
func close_focused() -> void:
	if _desk_focus != 0:
		close_window(_desk_focus)


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
	_shell_pid = int(shell_starter.call())
	return true


## Desce o Quickshell de dentro (o compositor some junto, e ele perderia a conexão de qualquer jeito).
func _stop_shell() -> void:
	if _shell_pid > 0:
		shell_stopper.call(_shell_pid)
	_shell_pid = -1


## O Quickshell de dentro está rodando? (os testes e o menu de pausa podem perguntar)
func has_shell() -> bool:
	return _shell_pid > 0


func _on_window_opened(id: int, wl_app_id: String, title: String, pid: int) -> void:
	if _monitors().is_empty():
		close_window(id)  # sem monitor: não tem onde mostrar
		return
	if _is_helper_window(id):
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
	var output := _layout.add(id, _target_output())
	if output < 0:
		close_window(id)  # todos os monitores cheios
		return
	_titles[id] = title
	_app_of_window[id] = app_id
	_stack.append(id)
	_apply(output)
	_focus_window(id)
	window_ready.emit(id, app_id)


## A janela é minúscula (um auxiliar, como o wl-clipboard)?
func _is_helper_window(id: int) -> bool:
	var texture := _compositor.call("get_texture", id) as Texture2D
	return texture != null and (texture.get_width() <= MIN_WINDOW_SIZE or texture.get_height() <= MIN_WINDOW_SIZE)


## A saída da janela nova: onde o mouse esteve por último, ou a do meio.
@warning_ignore("integer_division")
func _target_output() -> int:
	if _pointer_output >= 0 and _pointer_output < _output_count:
		return _pointer_output
	return _output_count / 2


func _on_window_closed(id: int) -> void:
	if not _titles.has(id):
		return
	var output := _layout.remove(id)
	_forget(id)
	if output >= 0:
		_apply(output)
	if _desk_focus == id:
		_desk_focus = _stack.back() if not _stack.is_empty() else 0
		if _desk_focus != 0:
			_active_output = output_of(_desk_focus)
		if _seated and _compositor != null:
			_compositor.call("focus", _desk_focus)
	window_gone.emit(id)


func _forget(id: int) -> void:
	_titles.erase(id)
	_app_of_window.erase(id)
	_window_output.erase(id)
	_stack.erase(id)


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
