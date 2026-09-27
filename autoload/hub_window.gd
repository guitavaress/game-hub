extends Node
## HubWindow: cuida da JANELA do hub (autoload).
##
##   sleep(mensagem): o hub "dorme" enquanto um jogo roda. Guarda como a janela
##       está (monitor, posição, tamanho, tela cheia...), escurece a tela, solta
##       o mouse, pausa o mundo, economiza energia e minimiza.
##   wake(): desfaz tudo e traz o hub de volta para a frente, NO MESMO MONITOR,
##       mesmo que o jogo tenha mudado a resolução da tela.
##
## Também:
##   - lembra onde a janela estava entre uma abertura e outra (user://window.cfg);
##     se aquele monitor não existir mais, abre no monitor principal;
##   - F11 alterna tela cheia.
##
## Não conhece jogos nem mundos: quem decide QUANDO dormir é o GameLauncher.

## O hub acabou de acordar (um jogo fechou).
signal woke_up

const PLACEMENT_PATH: String = "user://window.cfg"
## FPS máximo enquanto dorme (economiza CPU/GPU para o jogo).
const SLEEP_MAX_FPS: int = 5
## Depois de acordar, esperamos isso (s) e, se o Windows não tiver deixado o hub
## vir para a frente, piscamos o ícone na barra de tarefas.
const FOCUS_CHECK_DELAY: float = 0.6
const WAKE_FADE_TIME: float = 1.0

var is_sleeping: bool = false

## Como a janela estava antes de dormir: {mode, screen, position, size}.
var _placement: Dictionary = {}
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _saved_max_fps: int = 0
var _saved_low_processor: bool = false
var _did_minimize: bool = false


func _ready() -> void:
	# ALWAYS = funciona mesmo com o mundo pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Nós mesmos fechamos o hub (em _notification), para arrumar a casa antes.
	get_tree().auto_accept_quit = false
	if _can_control_window():
		_load_saved_placement()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not is_sleeping and _can_control_window():
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_hub()


## Fecha o hub com calma (X ou Alt+F4): guarda onde a janela está, para todos
## os sons e espera dois quadros antes de sair. Sem essa espera, o servidor de
## áudio ainda estaria segurando os sons e a Godot reclamaria ao fechar.
func _close_hub() -> void:
	if _can_control_window():
		_save_placement(_placement if is_sleeping else _capture_placement())
	for sound: Node in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		(sound as AudioStreamPlayer3D).stop()
	for sound: Node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(sound as AudioStreamPlayer).stop()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


## O hub "dorme": tela preta com a mensagem, mundo pausado, janela minimizada.
func sleep(message: String = "") -> void:
	if is_sleeping:
		ScreenFade.set_message(message)
		return
	is_sleeping = true

	ScreenFade.set_amount(1.0)
	ScreenFade.set_message(message)

	_saved_mouse_mode = Input.mouse_mode
	_saved_max_fps = Engine.max_fps
	_saved_low_processor = OS.low_processor_usage_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # solta o mouse para o jogo
	get_tree().paused = true
	OS.low_processor_usage_mode = true
	Engine.max_fps = SLEEP_MAX_FPS

	_did_minimize = _can_control_window()
	if _did_minimize:
		_placement = _capture_placement()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


## O hub "acorda": tudo volta como estava, e a tela clareia.
func wake() -> void:
	if not is_sleeping:
		return
	is_sleeping = false

	Engine.max_fps = _saved_max_fps
	OS.low_processor_usage_mode = _saved_low_processor
	get_tree().paused = false

	if _did_minimize:
		_did_minimize = false
		_apply_placement(_placement)
		DisplayServer.window_move_to_foreground()
		# O Windows às vezes não deixa um programa "roubar" a frente da tela.
		# Nesse caso, pelo menos piscamos o ícone na barra de tarefas.
		get_tree().create_timer(FOCUS_CHECK_DELAY).timeout.connect(func() -> void:
			if not is_sleeping and not DisplayServer.window_is_focused():
				DisplayServer.window_request_attention())

	Input.mouse_mode = _saved_mouse_mode
	ScreenFade.set_message("")
	ScreenFade.fade_in(WAKE_FADE_TIME)
	woke_up.emit()


# --- Posição da janela -------------------------------------------------------

func _capture_placement() -> Dictionary:
	return {
		"mode": DisplayServer.window_get_mode(),
		"screen": DisplayServer.window_get_current_screen(),
		"position": DisplayServer.window_get_position(),
		"size": DisplayServer.window_get_size(),
	}


## Coloca a janela no monitor, posição, tamanho e modo guardados. Se o monitor
## não existir mais (ou a posição ficar fora da tela), usa o monitor principal.
func _apply_placement(placement: Dictionary) -> void:
	if placement.is_empty():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return

	var screen: int = placement.get("screen", -1)
	if screen < 0 or screen >= DisplayServer.get_screen_count():
		screen = DisplayServer.get_primary_screen()
	var mode: DisplayServer.WindowMode = placement.get("mode", DisplayServer.WINDOW_MODE_WINDOWED)
	if mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		mode = DisplayServer.WINDOW_MODE_WINDOWED

	# Primeiro volta para "janela" no monitor certo...
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_current_screen(screen)

	# ...depois aplica o modo guardado.
	match mode:
		DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(mode)
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			DisplayServer.window_set_mode(mode)
		_:
			var usable := DisplayServer.screen_get_usable_rect(screen)
			var size: Vector2i = placement.get("size", Vector2i(1280, 720))
			size = size.clamp(Vector2i(640, 360), usable.size)
			var position: Vector2i = placement.get("position", usable.position)
			# Se a janela ficaria fora do monitor, centraliza.
			if not usable.encloses(Rect2i(position, size)):
				position = usable.position + (usable.size - size) / 2
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(position)


func _save_placement(placement: Dictionary) -> void:
	var config := ConfigFile.new()
	for key: String in placement:
		config.set_value("window", key, placement[key])
	config.save(PLACEMENT_PATH)


func _load_saved_placement() -> void:
	var config := ConfigFile.new()
	if config.load(PLACEMENT_PATH) != OK:
		return  # primeira vez: fica o tamanho padrão do projeto
	var placement := {}
	for key in config.get_section_keys("window"):
		placement[key] = config.get_value("window", key)
	_apply_placement(placement)


## Dá para mexer na janela? Não quando roda sem tela (testes) nem dentro da
## aba "Game" do editor (lá a janela pertence ao editor).
func _can_control_window() -> bool:
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()
