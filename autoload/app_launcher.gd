extends Node
## AppLauncher: abre um app comum (navegador, terminal...) e percebe quando ele
## fecha (autoload). É o irmão do GameLauncher, mas para a estante de apps.
##
## Passo a passo:
##   1. Alguém chama launch(id_do_app, origem).
##   2. Guardamos a "foto" das janelas abertas, pedimos o app ao sistema
##      (DesktopApps.launch) e o hub "dorme": a tela "Abrindo X…" cobre tudo.
##   3. A cada 1 s procuramos a janela NOVA do app (HubWindow.find_new_window;
##      só no Hyprland). Quando ela aparece, o hub se esconde e o app toma o
##      lugar dele. Estados: IDLE -> LAUNCHING -> RUNNING -> IDLE.
##   4. A sessão acaba quando:
##        - a janela do app some (se estávamos acompanhando);
##        - o hub volta a ter foco (HubWindow.focus_returned: o atalho do
##          Omarchy, ou um clique nele) ou acorda por qualquer motivo
##          (HubWindow.woke_up). O app continua aberto;
##        - o jogador aperta Esc enquanto o app abre (cancela a espera).
##      Se a janela não aparece em 10 s (sistema que não acompanha janelas, ou
##      um app que só focou uma janela que já existia), o hub se esconde do
##      mesmo jeito e a sessão só acaba pelo foco de volta ("sem acompanhar").
##
## Fase 14.21 (Linux, com o compositor compilado e telões livres): o app abre
## DENTRO do mundo. O AppSessions abre o app no compositor e o hub NÃO dorme:
## quando a janela chega a um telão (window_ready), a sessão do AppLauncher
## acaba com sucesso (o app segue vivo no telão, é do AppSessions). Se a janela
## não chega em FIND_WINDOW_TIMEOUT (app só X11, por exemplo), vale o plano B:
## o fluxo de fora acima, com a foto das janelas tirada antes de abrir.
##
## REGRA: sempre que você chama launch(), vem UM app_session_ended com a mesma
## "origem", dando certo ou errado.
##
## O GameLauncher e o AppLauncher não rodam juntos: cada um recusa abrir se o
## outro estiver ocupado. Este sistema não conhece mundos nem portais: a
## "origem" é qualquer Node, devolvida no sinal.
##
## A consulta das janelas roda numa THREAD (cada uma é uma chamada ao hyprctl).

## O pedido foi feito e o hub foi dormir.
signal app_launch_started(app_id: String, source: Node)
## A sessão acabou: o app fechou (success = true) ou algo deu errado
## (success = false; a 1ª linha da mensagem é o título do aviso, o resto diz
## o que fazer). O hub já acordou quando isto é emitido.
signal app_session_ended(app_id: String, source: Node, success: bool, message: String)
signal state_changed(new_state: State)

enum State { IDLE, LAUNCHING, RUNNING }

## De quanto em quanto tempo olhamos as janelas (segundos).
const POLL_INTERVAL: float = 1.0
## Quanto esperamos a janela do app aparecer antes de seguir "sem acompanhar" (s).
const FIND_WINDOW_TIMEOUT: float = 10.0

var state: State = State.IDLE

## Pode abrir no mundo (telões)? Os testes do fluxo de fora desligam.
var use_world: bool = true
## A última sessão que acabou foi uma abertura no mundo? (a estante lê)
var last_session_in_world: bool = false

## Quem abre o app: func(app: DesktopApp) -> bool. Os testes trocam.
var opener: Callable = _open_app
## O sistema sabe acompanhar janelas? func() -> bool. Os testes trocam.
var can_track: Callable = _can_track
## A foto das janelas de agora: func() -> PackedStringArray. Os testes trocam.
var list_windows: Callable = _list_windows
## Olha as janelas (roda numa thread):
##   func(before: PackedStringArray, wm_class: String, address: String) -> Dictionary
## com "address" (a janela do app, "" = ainda não apareceu) e "exists" (ela
## ainda está aberta). Os testes trocam.
var window_reader: Callable = _read_windows
## false = a consulta roda na hora, sem thread (os testes ligam isto).
var threaded: bool = true

var _app_id: String = ""
## true enquanto esperamos a janela chegar a um telão (abertura no mundo).
var _in_world: bool = false
var _source: Node = null
var _launch_started_ms: int = 0
var _tracking: bool = false
var _before: PackedStringArray = PackedStringArray()
var _wm_class: String = ""
## A janela do app, se já achamos ("" = não achamos / sem acompanhar).
var _window: String = ""
var _poll_timer: Timer
var _poll_task: int = -1
## Número da sessão: o resultado de uma consulta de uma sessão velha não vale.
var _session_number: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.timeout.connect(_poll)
	add_child(_poll_timer)
	HubWindow.focus_returned.connect(_on_hub_called_back)
	HubWindow.woke_up.connect(_on_hub_called_back)
	AppSessions.window_ready.connect(_on_world_window_ready)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.LAUNCHING and not _in_world and event.is_action_pressed("ui_cancel"):
		cancel_launch()


## O próximo app vai abrir num telão (e não fora, com o hub dormindo)?
func opens_in_world() -> bool:
	return use_world and AppSessions.can_open_in_world()


func is_busy() -> bool:
	return state != State.IDLE


## O id do app da sessão atual ("" = nenhum).
func get_app_id() -> String:
	return _app_id


## Estamos acompanhando a janela do app (e não só esperando o hub voltar)?
func is_tracking_window() -> bool:
	return not _window.is_empty()


## Pede para abrir o app. Devolve true se o pedido foi feito. Em qualquer caso,
## a resposta final chega pelo sinal app_session_ended.
func launch(app_id: String, source: Node = null) -> bool:
	last_session_in_world = false
	var app := AppLibrary.get_app(app_id)
	var problem := _check_can_launch(app)
	if not problem.is_empty():
		app_session_ended.emit(app_id, source, false, problem)
		return false

	var in_world := opens_in_world()
	if in_world and AppSessions.free_screens() == 0:
		app_session_ended.emit(app_id, source, false,
				"Os telões estão cheios\nFeche um dos apps abertos nos telões para abrir outro.")
		return false

	_tracking = bool(can_track.call())
	_before = list_windows.call() if _tracking else PackedStringArray()
	_wm_class = app.wm_class
	var opened: bool = AppSessions.open_app(app) if in_world else bool(opener.call(app))
	if not opened:
		app_session_ended.emit(app_id, source, false,
				"Não consegui abrir %s\nConfira se o programa ainda está instalado." % app.name)
		return false

	AppLibrary.mark_opened(app_id)
	_app_id = app_id
	_source = source
	_window = ""
	_launch_started_ms = Time.get_ticks_msec()
	_session_number += 1
	_in_world = in_world
	_set_state(State.LAUNCHING)
	if in_world:
		return true  # o hub fica acordado: a janela vai aparecer num telão
	# O hub dorme mas continua visível (tela "Abrindo X…") até a janela do app
	# aparecer (ou até FIND_WINDOW_TIMEOUT).
	HubWindow.sleep(false)
	app_launch_started.emit(app_id, source)
	return true


## Desiste de esperar o app abrir (se ele abrir depois, fica aberto ao lado).
func cancel_launch() -> void:
	if state == State.LAUNCHING:
		_end_session(false, "Você cancelou a espera por %s\n" % _app_name(_app_id)
				+ "Se o app abrir depois, ele fica aberto ao lado do hub.")


func _check_can_launch(app: DesktopApp) -> String:
	if is_busy() or GameLauncher.is_busy():
		return "Já existe um jogo ou app abrindo\nEspere ele fechar para abrir outro."
	if app == null:
		return "Esse app não está mais na lista\nO hub lê os programas de novo quando abre."
	return ""


# --- Olhando as janelas ------------------------------------------------------

func _poll() -> void:
	match state:
		State.LAUNCHING:
			if _in_world:
				if _seconds_since(_launch_started_ms) >= FIND_WINDOW_TIMEOUT:
					_fall_back_to_outside()
			elif _tracking:
				_query_windows()
			elif _seconds_since(_launch_started_ms) >= FIND_WINDOW_TIMEOUT:
				_hide_hub_untracked()
		State.RUNNING:
			if not _window.is_empty():
				_query_windows()


func _query_windows() -> void:
	if not threaded:
		_on_windows_read(_read_windows_with(_before, _wm_class, _window), _session_number)
		return
	if _poll_task != -1:
		return  # a consulta anterior ainda não terminou
	# Método com bind, e não função anônima: uma lambda que usa o "self" e roda
	# em thread corrompe a memória ao fechar a Godot (visto na 14.3).
	_poll_task = WorkerThreadPool.add_task(_poll_in_thread.bind(_before, _wm_class, _window, _session_number))


## Roda numa thread: olha as janelas e entrega o resultado à thread principal.
func _poll_in_thread(before: PackedStringArray, wm_class: String, address: String, session: int) -> void:
	_on_windows_read.call_deferred(_read_windows_with(before, wm_class, address), session)


func _read_windows_with(before: PackedStringArray, wm_class: String, address: String) -> Dictionary:
	return window_reader.call(before, wm_class, address)


func _on_windows_read(result: Dictionary, session: int) -> void:
	if _poll_task != -1:
		WorkerThreadPool.wait_for_task_completion(_poll_task)
		_poll_task = -1
	if session != _session_number:
		return  # a sessão mudou enquanto a consulta rodava
	match state:
		State.LAUNCHING:
			var address: String = result.get("address", "")
			if not address.is_empty():
				_window = address
				_set_state(State.RUNNING)
				HubWindow.minimize_now()  # o app toma o lugar do hub
			elif _seconds_since(_launch_started_ms) >= FIND_WINDOW_TIMEOUT:
				_hide_hub_untracked()
		State.RUNNING:
			if not _window.is_empty() and not result.get("exists", true):
				_end_session(true, "")


## A janela chegou a um telão: o AppLauncher cumpriu o papel dele.
func _on_world_window_ready(_id: int, app_id: String) -> void:
	if state != State.LAUNCHING or not _in_world or app_id != _app_id:
		return
	var finished_app := _app_id
	var source := _source if is_instance_valid(_source) else null
	_app_id = ""
	_source = null
	_in_world = false
	_session_number += 1
	last_session_in_world = true
	_set_state(State.IDLE)
	app_session_ended.emit(finished_app, source, true, "")


## Plano B: o app não mostrou janela no compositor a tempo (provavelmente só
## fala X11 e abriu fora). Segue como na parte 1: o hub dorme e acompanha a
## janela de fora.
func _fall_back_to_outside() -> void:
	AppSessions.cancel_pending()
	_in_world = false
	_launch_started_ms = Time.get_ticks_msec()
	HubWindow.sleep(false)
	app_launch_started.emit(_app_id, _source)


## A janela não apareceu a tempo: o hub se esconde mesmo assim, e a sessão só
## acaba quando ele voltar a ter foco.
func _hide_hub_untracked() -> void:
	_set_state(State.RUNNING)
	HubWindow.minimize_now()


## O hub foi chamado de volta (foco, ou acordou): a sessão do app acaba.
func _on_hub_called_back() -> void:
	if state == State.RUNNING:
		_end_session(true, "")


func _end_session(success: bool, message: String) -> void:
	var app_id := _app_id
	var source := _source if is_instance_valid(_source) else null
	_app_id = ""
	_source = null
	_window = ""
	_in_world = false
	last_session_in_world = false
	_session_number += 1
	_set_state(State.IDLE)
	HubWindow.wake()  # se já estava acordado, não faz nada
	app_session_ended.emit(app_id, source, success, message)


# --- Utilidades --------------------------------------------------------------

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	if new_state == State.IDLE:
		_poll_timer.stop()
	elif _poll_timer.is_stopped():
		_poll_timer.start()
	state_changed.emit(new_state)


func _app_name(app_id: String) -> String:
	var app := AppLibrary.get_app(app_id)
	return app.name if app != null else app_id


func _seconds_since(ticks_ms: int) -> float:
	return (Time.get_ticks_msec() - ticks_ms) / 1000.0


# --- Os de verdade (os testes trocam) ----------------------------------------

func _open_app(app: DesktopApp) -> bool:
	return DesktopApps.launch(app)


func _can_track() -> bool:
	return HubWindow.can_track_windows()


func _list_windows() -> PackedStringArray:
	return HubWindow.list_window_addresses()


## Roda na thread.
func _read_windows(before: PackedStringArray, wm_class: String, address: String) -> Dictionary:
	if address.is_empty():
		return {"address": HubWindow.find_new_window(before, wm_class), "exists": true}
	return {"address": address, "exists": HubWindow.window_exists(address)}
