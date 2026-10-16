extends Node
## AppSessions: liga "app aberto" a "janela do compositor" (autoload, Fase 14.21).
##
## É o dono do compositor Wayland do hub (AppCompositor): cria o nó na primeira
## vez que precisa, chama o poll() a cada quadro e escuta as janelas que os
## apps abrem lá dentro. Cada janela vai para um TELÃO livre do mundo.
##
## Este sistema não conhece mundos. Os telões são achados pelo grupo
## "app_screens" (o nó que os guarda tem free_count(), offer(source),
## release(screen) e screen_of(source); a 14.28 põe aqui os monitores da mesa).
##
## Regras:
##   - a primeira janela nova depois de um open_app() é do app que foi aberto;
##   - outra janela do mesmo cliente (mesmo pid, ex.: segunda janela do Brave)
##     vai para o próximo telão livre, e conta como do mesmo app;
##   - com todos os telões ocupados, a janela é fechada (o app recebe o pedido
##     de fechar), porque não tem onde mostrar.

## A janela de um app abriu e já está num telão.
signal window_ready(id: int, app_id: String)
## A janela fechou e o telão ficou livre.
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
## id da janela -> WindowSource.
var _sources: Dictionary = {}
var _app_of_window: Dictionary = {}


## Uma janela do compositor, vista pelo telão. Traduz o que o telão pede
## (pixels, teclas da Godot, rolagem) para o que o compositor entende.
class WindowSource extends AppWindowSource:
	var id: int = 0
	var title: String = ""
	var _compositor: Node
	## O tamanho que o telão pediu (para converter o mouse).
	var _requested: Vector2i = Vector2i(1280, 720)

	func _init(compositor: Node, window_id: int, window_title: String) -> void:
		_compositor = compositor
		id = window_id
		title = window_title

	func get_texture() -> Texture2D:
		return _compositor.call("get_texture", id) as Texture2D

	func resize(size: Vector2i) -> void:
		_requested = size
		_compositor.call("resize", id, size.x, size.y)

	func send_key(event: InputEventKey) -> void:
		if event.echo:
			return  # a repetição de tecla é feita pelo próprio app
		var code := AppCompositor.evdev_code(event)
		if code >= 0:
			_compositor.call("key", id, code, event.pressed)

	## O pixel chega na resolução do telão; a imagem do app pode ter outro
	## tamanho (o Brave não fica menor que 800×600), então converte pela proporção.
	func send_pointer(pixel: Vector2) -> void:
		var texture := get_texture()
		var size := Vector2(texture.get_size()) if texture != null else Vector2(_requested)
		var asked := Vector2(_requested)
		if asked.x <= 0.0 or asked.y <= 0.0:
			asked = size
		_compositor.call("pointer_motion", id, pixel.x * size.x / asked.x, pixel.y * size.y / asked.y)

	func send_button(button: MouseButton, pressed: bool) -> void:
		var code := AppCompositor.mouse_button_code(button)
		if code >= 0:
			_compositor.call("pointer_button", code, pressed)

	## O telão manda y positivo para cima; o compositor, positivo para baixo.
	func send_scroll(delta: Vector2) -> void:
		_compositor.call("pointer_axis", delta.x, -delta.y, true)

	func get_title() -> String:
		return title

	func set_focused(on: bool) -> void:
		_compositor.call("focus", id if on else 0)

	func pointer_leave() -> void:
		_compositor.call("pointer_leave")


## Com o hub dormindo (um jogo da Steam, ou um app aberto por fora) o
## compositor não roda: sem poll, os apps não recebem "quadro mostrado" e
## ficam ociosos, e nenhuma textura sobe. Ao acordar, volta tudo.
func is_dormant() -> bool:
	return HubWindow.is_sleeping


func _process(_delta: float) -> void:
	if _compositor != null and not is_dormant():
		_compositor.call("poll")


# --- Perguntas ---------------------------------------------------------------

## Dá para abrir apps no mundo? Precisa do compositor (extensão compilada, só
## Linux) e de um lugar com telões (a casa).
func can_open_in_world() -> bool:
	return _get_host() != null and _ensure_compositor()


## Quantos telões estão livres (0 sem lugar com telões).
func free_screens() -> int:
	var host := _get_host()
	return int(host.call("free_count")) if host != null else 0


## Quantas janelas de apps estão abertas nos telões.
func window_count() -> int:
	return _sources.size()


func get_compositor() -> Node:
	return _compositor


## O app da janela ("" se não existe).
func app_of(window_id: int) -> String:
	return str(_app_of_window.get(window_id, ""))


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
	return true


func _on_window_opened(id: int, wl_app_id: String, title: String, pid: int) -> void:
	var host := _get_host()
	var app_id := _pending_app
	if not app_id.is_empty():
		_pending_app = ""
		if pid > 0:
			_app_by_pid[pid] = app_id
	elif _app_by_pid.has(pid):
		app_id = _app_by_pid[pid]
	else:
		app_id = wl_app_id  # um app aberto por fora, apontado para o socket do hub
	var source := WindowSource.new(_compositor, id, title)
	if host == null or host.call("offer", source) == null:
		close_window(id)  # sem telão livre: não tem onde mostrar
		return
	_sources[id] = source
	_app_of_window[id] = app_id
	window_ready.emit(id, app_id)


func _on_window_closed(id: int) -> void:
	var source := _sources.get(id) as WindowSource
	if source == null:
		return
	_sources.erase(id)
	_app_of_window.erase(id)
	var host := _get_host()
	if host != null:
		var screen = host.call("screen_of", source)
		if screen != null:
			host.call("release", screen)
	window_gone.emit(id)


func _on_title_changed(id: int, title: String) -> void:
	var source := _sources.get(id) as WindowSource
	if source != null:
		source.title = title


## O nó que guarda os telões, ou null.
func _get_host() -> Node:
	return get_tree().get_first_node_in_group("app_screens") if is_inside_tree() else null


# --- Os de verdade (os testes trocam) ----------------------------------------

func _create_compositor() -> Node:
	return AppCompositor.create()


func _open_in_compositor(app: DesktopApp) -> bool:
	var profile := ProjectSettings.globalize_path("user://apps/brave")
	DirAccess.make_dir_recursive_absolute(profile)
	return DesktopApps.launch_in_compositor(app, AppCompositor.environment(), profile)
