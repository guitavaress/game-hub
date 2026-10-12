extends Node
## HubWindow: cuida da JANELA do hub (autoload).
##
##   sleep(minimizar): o hub "dorme" enquanto um jogo abre/roda. Guarda como a
##       janela está (monitor, posição, tamanho, tela cheia...), cobre a tela
##       com a cortina, solta o mouse, pausa o mundo, para de desenhar o 3D e
##       economiza energia. Com minimizar = false, a janela continua visível
##       (mostrando a tela "Abrindo X…") até alguém chamar minimize_now().
##   wake(): desfaz tudo e traz o hub de volta para a frente, NO MESMO MONITOR,
##       mesmo que o jogo tenha mudado a resolução da tela.
##
## Também:
##   - lembra onde a janela estava entre uma abertura e outra (user://window.cfg);
##     se aquele monitor não existir mais, abre no monitor principal;
##   - F11 alterna tela cheia.
##
## COMO esconder e mostrar a janela depende do sistema, e quem sabe é o
## WindowHost (autoload/platform/): no Windows, minimizar; no Hyprland, um
## workspace oculto (lá quem cuida de monitor, posição e tamanho é o Hyprland,
## então não guardamos nada disso).
##
## Não conhece jogos nem mundos: quem decide QUANDO dormir é o GameLauncher.

## O hub acabou de acordar (um jogo fechou).
signal woke_up

const PLACEMENT_PATH: String = "user://window.cfg"
## FPS máximo enquanto dorme: minimizado, e ainda visível (tela "Abrindo X…").
const SLEEP_MAX_FPS: int = 5
const COVERED_MAX_FPS: int = 30
## Depois de acordar, esperamos isso (s) e, se o Windows não tiver deixado o hub
## vir para a frente, piscamos o ícone na barra de tarefas.
const FOCUS_CHECK_DELAY: float = 0.6
const WAKE_FADE_TIME: float = 0.8
## Procuramos a janela do jogo (para pô-la no lugar e em tela cheia) a cada
## GAME_WINDOW_CHECK segundos, durante GAME_WINDOW_CHECK_FOR segundos (ela pode
## demorar a aparecer, e alguns jogos abrem antes um launcher).
const GAME_WINDOW_CHECK: float = 0.5
const GAME_WINDOW_CHECK_FOR: float = 90.0

var is_sleeping: bool = false

## Como a janela estava antes de dormir: {mode, screen, position, size}.
var _placement: Dictionary = {}
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _saved_max_fps: int = 0
var _saved_low_processor: bool = false
var _did_minimize: bool = false
var _window_host: WindowHost = WindowHost.create()
## Processos do jogo atual (para achar a janela dele) e até quando procurar.
var _game_pids: Array[int] = []
var _game_window_until_ms: int = 0
var _game_window_timer: Timer


func _ready() -> void:
	# ALWAYS = funciona mesmo com o mundo pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Nós mesmos fechamos o hub (em _notification), para arrumar a casa antes.
	get_tree().auto_accept_quit = false
	if _can_place_window():
		_load_saved_placement()
	_game_window_timer = Timer.new()
	_game_window_timer.wait_time = GAME_WINDOW_CHECK
	_game_window_timer.timeout.connect(_check_game_window)
	add_child(_game_window_timer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not is_sleeping:
		set_fullscreen(not is_fullscreen())


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## Liga/desliga a tela cheia (F11 ou o menu de pausa).
func set_fullscreen(fullscreen: bool) -> void:
	if _can_control_window():
		DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Fecha o hub (botão "Sair do hub" do menu de pausa), do mesmo jeito calmo
## que o X da janela.
func quit_hub() -> void:
	_close_hub()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_hub()


## Fecha o hub com calma (X ou Alt+F4): guarda onde a janela está, para todos
## os sons e espera dois quadros antes de sair. Sem essa espera, o servidor de
## áudio ainda estaria segurando os sons e a Godot reclamaria ao fechar.
func _close_hub() -> void:
	if _can_place_window():
		_save_placement(_placement if is_sleeping else _capture_placement())
	for sound: Node in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		(sound as AudioStreamPlayer3D).stop()
	for sound: Node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(sound as AudioStreamPlayer).stop()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


## O hub "dorme": cortina por cima, mundo pausado, 3D desligado, pouca energia.
## minimize = true minimiza já; false deixa a janela visível até minimize_now().
func sleep(minimize: bool = true) -> void:
	if is_sleeping:
		if minimize:
			minimize_now()
		return
	is_sleeping = true

	ScreenFade.set_amount(1.0)

	_saved_mouse_mode = Input.mouse_mode
	_saved_max_fps = Engine.max_fps
	_saved_low_processor = OS.low_processor_usage_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # solta o mouse para o jogo
	get_tree().paused = true
	# A cortina cobre tudo: não precisa desenhar a cidade (economiza a placa de vídeo).
	get_viewport().disable_3d = true
	OS.low_processor_usage_mode = true
	Engine.max_fps = COVERED_MAX_FPS
	if _can_place_window():
		_placement = _capture_placement()

	if minimize:
		minimize_now()


## O GameLauncher acabou de pedir o jogo à Steam: prepara o lugar onde ele vai
## abrir (no Hyprland, um workspace novo no monitor do jogo; no Windows, nada).
func make_room_for_game() -> void:
	if _can_control_window():
		_window_host.make_room_for_game(AppConfig.get_game_monitor())


## O jogo está rodando (GameLauncher): no Hyprland, a janela dele vai para um
## workspace dele no monitor do jogo e para a tela cheia ([window] no
## config.cfg). game_pids = os processos do jogo; a janela é de um deles ou de
## um "filho". No Windows, nada.
func place_game(game_pids: Array[int]) -> void:
	if not _can_control_window() or game_pids.is_empty():
		return
	_game_pids = game_pids
	_game_window_until_ms = Time.get_ticks_msec() + int(GAME_WINDOW_CHECK_FOR * 1000.0)
	_check_game_window()
	_game_window_timer.start()


func _check_game_window() -> void:
	if _game_pids.is_empty() or Time.get_ticks_msec() > _game_window_until_ms:
		_stop_game_window_checks()
		return
	_window_host.place_game_windows(_game_pids, AppConfig.get_game_monitor(), AppConfig.get_game_fullscreen())


func _stop_game_window_checks() -> void:
	_game_pids = []
	if _game_window_timer:
		_game_window_timer.stop()


## Minimiza (esconde) o hub que já está dormindo (ex.: o jogo acabou de aparecer).
func minimize_now() -> void:
	if not is_sleeping or _did_minimize:
		return
	Engine.max_fps = SLEEP_MAX_FPS
	_did_minimize = _can_control_window()
	if _did_minimize:
		_window_host.hide_hub()


## O hub "acorda": tudo volta como estava, e a tela clareia.
func wake() -> void:
	if not is_sleeping:
		return
	is_sleeping = false

	Engine.max_fps = _saved_max_fps
	OS.low_processor_usage_mode = _saved_low_processor
	get_tree().paused = false
	get_viewport().disable_3d = false
	_stop_game_window_checks()

	if _can_control_window() and _window_host.manages_placement():
		# Hyprland: o hub volta ao workspace de antes, com foco. Vale mesmo sem
		# ter escondido (ex.: desistiu de esperar o jogo), porque a tela pode
		# ter ido para o workspace do jogo.
		_did_minimize = false
		_window_host.show_hub()
	elif _did_minimize:
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


## Guardamos e restauramos monitor, posição e tamanho? Só onde o sistema não
## cuida disso sozinho (no Hyprland, ele cuida).
func _can_place_window() -> bool:
	return _can_control_window() and not _window_host.manages_placement()
