extends Node
## GameLauncher: abre jogos pela Steam, minimiza o hub e percebe quando o jogo fecha (autoload).
##
## Como funciona, passo a passo:
##   1. Alguém chama launch(app_id, origem).
##   2. Pedimos à Steam para abrir o jogo (steam://rungameid/<appid>),
##      minimizamos o hub e pausamos tudo para gastar pouco PC.
##   3. A cada 2 s olhamos o valor "RunningAppID" no registro do Windows.
##      A Steam coloca ali o appid do jogo que está rodando (ou 0 se nenhum).
##        - LAUNCHING: esperando o valor virar o nosso appid (limite: 90 s).
##        - RUNNING: esperando o valor deixar de ser o nosso appid (= jogo fechou).
##   4. Quando termina (fechou ou deu errado), restauramos o hub e emitimos
##      session_ended(...).
##
## REGRA: sempre que você chama launch(), mais cedo ou mais tarde vem UM
## session_ended com a mesma "origem", dando certo ou errado.
##
## Este sistema NÃO conhece mundos nem portais: a "origem" é qualquer Node, e só
## é devolvida no sinal para quem chamou saber que a resposta é para ele.

signal state_changed(new_state: State)
## O pedido foi feito à Steam e o hub foi minimizado.
signal launch_started(app_id: int, source: Node)
## A Steam confirmou que o jogo está rodando.
signal game_started(app_id: int, source: Node)
## Acabou: o jogo fechou (success = true) ou algo deu errado (success = false,
## com uma mensagem explicando). O hub já está restaurado quando isso é emitido.
signal session_ended(app_id: int, source: Node, success: bool, message: String)

enum State { IDLE, LAUNCHING, RUNNING }

const STEAM_REG_KEY: String = "HKCU\\Software\\Valve\\Steam"
## De quanto em quanto tempo consultamos o registro (segundos).
const POLL_INTERVAL: float = 2.0
## Quanto esperamos o jogo abrir antes de desistir (segundos).
const LAUNCH_TIMEOUT: float = 90.0
## FPS máximo enquanto o hub está minimizado (economiza CPU/GPU para o jogo).
const MINIMIZED_MAX_FPS: int = 5

var state: State = State.IDLE

var _app_id: int = 0
var _source: Node = null
var _launch_started_ms: int = 0
var _poll_timer: Timer

# Como estava o hub antes de minimizar, para restaurar igualzinho depois.
var _saved_window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _saved_max_fps: int = 0
var _saved_low_processor: bool = false
var _did_minimize: bool = false


func _ready() -> void:
	# ALWAYS = continua rodando mesmo com a árvore pausada (senão o Timer pararia).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.timeout.connect(_on_poll_timer_timeout)
	add_child(_poll_timer)


func is_busy() -> bool:
	return state != State.IDLE


## Pede para abrir o jogo. Devolve true se o pedido foi feito.
## Em qualquer caso, a resposta final chega pelo sinal session_ended.
func launch(app_id: int, source: Node = null) -> bool:
	if is_busy():
		session_ended.emit(app_id, source, false, "Já existe um jogo sendo aberto ou rodando.")
		return false
	if app_id <= 0:
		session_ended.emit(app_id, source, false, "App ID inválido: %d." % app_id)
		return false

	var error := OS.shell_open("steam://rungameid/%d" % app_id)
	if error != OK:
		session_ended.emit(app_id, source, false,
				"Não consegui pedir à Steam para abrir o jogo (erro %d). A Steam está instalada?" % error)
		return false

	_app_id = app_id
	_source = source
	_launch_started_ms = Time.get_ticks_msec()
	_set_state(State.LAUNCHING)
	_minimize_hub()
	_poll_timer.start()
	launch_started.emit(app_id, source)
	return true


func _on_poll_timer_timeout() -> void:
	var running_app_id := WinRegistry.read_dword(STEAM_REG_KEY, "RunningAppID", 0)

	match state:
		State.LAUNCHING:
			if running_app_id == _app_id:
				_set_state(State.RUNNING)
				game_started.emit(_app_id, _get_source())
			elif _seconds_since_launch() >= LAUNCH_TIMEOUT:
				_end_session(false, "O jogo não abriu em %d s. A Steam mostrou alguma janela ou erro?" \
						% int(LAUNCH_TIMEOUT))
		State.RUNNING:
			if running_app_id != _app_id:
				_end_session(true, "")


func _end_session(success: bool, message: String) -> void:
	_poll_timer.stop()
	var app_id := _app_id
	var source := _get_source()
	_app_id = 0
	_source = null
	_restore_hub()
	_set_state(State.IDLE)
	session_ended.emit(app_id, source, success, message)


func _minimize_hub() -> void:
	_saved_window_mode = DisplayServer.window_get_mode()
	_saved_mouse_mode = Input.mouse_mode
	_saved_max_fps = Engine.max_fps
	_saved_low_processor = OS.low_processor_usage_mode

	# Solta o mouse para o jogo poder usá-lo.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Pausa o mundo e reduz o consumo enquanto o jogo roda.
	get_tree().paused = true
	OS.low_processor_usage_mode = true
	Engine.max_fps = MINIMIZED_MAX_FPS

	# Rodando embutido na aba "Game" do editor, a janela não é nossa para minimizar.
	_did_minimize = not Engine.is_embedded_in_editor()
	if _did_minimize:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func _restore_hub() -> void:
	Engine.max_fps = _saved_max_fps
	OS.low_processor_usage_mode = _saved_low_processor
	get_tree().paused = false

	if _did_minimize:
		var mode := _saved_window_mode
		if mode == DisplayServer.WINDOW_MODE_MINIMIZED:
			mode = DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
		DisplayServer.window_move_to_foreground()
		_did_minimize = false

	Input.mouse_mode = _saved_mouse_mode


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)


func _seconds_since_launch() -> float:
	return (Time.get_ticks_msec() - _launch_started_ms) / 1000.0


## A origem pode ter sido apagada enquanto o jogo rodava (ex.: troca de mundo).
func _get_source() -> Node:
	return _source if is_instance_valid(_source) else null
