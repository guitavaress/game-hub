extends Node
## GameLauncher: abre jogos pela Steam e percebe quando eles fecham (autoload).
##
## Como funciona, passo a passo:
##   1. Alguém chama launch(app_id, origem).
##   2. Conferimos se dá para abrir (Steam instalada? jogo ainda instalado?).
##   3. Pedimos à Steam para abrir o jogo (steam://rungameid/<appid>) e o hub
##      "dorme" (HubWindow.sleep): a tela "Abrindo X…" cobre tudo e o mundo
##      pausa. O hub só MINIMIZA quando o jogo aparece (ou depois de 10 s).
##   4. A cada 2 s perguntamos ao SteamClient (que sabe ler a Steam de cada
##      sistema operacional):
##        - running_app_id: o jogo que a Steam diz estar rodando (0 = nenhum);
##        - app_running / app_updating: se o NOSSO jogo está rodando ou atualizando;
##        - steam_running: se a Steam está aberta.
##      Estados: IDLE -> LAUNCHING (esperando abrir) -> RUNNING (jogando) -> IDLE.
##   5. Quando termina (fechou, deu errado ou foi cancelado), o hub acorda
##      (HubWindow.wake) e emitimos session_ended(...).
##
## Com o hub parado (IDLE), olhamos a cada 5 s se algum jogo da cidade foi aberto
## POR FORA do hub (pela Steam, por um atalho...). Se foi, o hub dorme do mesmo
## jeito, e acorda quando o jogo fechar ("sessão externa", sem origem).
##
## REGRA: sempre que você chama launch(), mais cedo ou mais tarde vem UM
## session_ended com a mesma "origem", dando certo ou errado.
##
## Este sistema NÃO conhece mundos nem portais: a "origem" é qualquer Node, e só
## é devolvida no sinal para quem chamou saber que a resposta é para ele.
##
## As consultas rodam numa THREAD separada (no Windows, cada uma leva de 10 a
## 70 ms, e isso travaria a imagem do hub se rodasse na thread principal).

signal state_changed(new_state: State)
## O pedido foi feito à Steam e o hub foi dormir.
signal launch_started(app_id: int, source: Node)
## A Steam confirmou que o jogo está rodando. source = null em sessões externas.
signal game_started(app_id: int, source: Node)
## A sessão desse jogo acabou: fechou (success = true) ou algo deu errado
## (success = false, com uma mensagem explicando: a 1ª linha é o título do
## aviso, o resto diz o que fazer). source = null em sessões externas. Normalmente o hub já acordou quando isso é emitido; a exceção é a
## troca direta de jogo (fechou um e abriu outro), em que ele continua dormindo.
signal session_ended(app_id: int, source: Node, success: bool, message: String)

enum State { IDLE, LAUNCHING, RUNNING }

## De quanto em quanto tempo olhamos a Steam (segundos).
const POLL_INTERVAL_SESSION: float = 2.0
const POLL_INTERVAL_IDLE: float = 5.0
## Quanto esperamos o jogo abrir antes de desistir (segundos).
const LAUNCH_TIMEOUT: float = 90.0
## ...e quanto esperamos se a Steam estava fechada (ela ainda precisa abrir).
const LAUNCH_TIMEOUT_STEAM_CLOSED: float = 180.0
## Jogo que fecha antes disso (segundos) provavelmente deu erro ao abrir.
const QUICK_EXIT_SECONDS: float = 10.0
## A tela "Abrindo X…" fica visível até o jogo aparecer, mas no máximo isso (s).
const MINIMIZE_AFTER_SECONDS: float = 10.0
## Jogo aberto por fora: a tela "abriu pela Steam" aparece por isso (s) antes de minimizar.
const EXTERNAL_NOTICE_SECONDS: float = 1.5

var state: State = State.IDLE
## true se a Steam estava fechada quando o jogo foi pedido (ela ainda vai abrir).
var steam_was_closed: bool = false

## Quem lê o estado da Steam: func(app_id: int, check_steam: bool) -> Dictionary
## com "running_app_id", "steam_running", "app_running" e "app_updating".
## Os testes trocam isto por um leitor falso (para simular a Steam).
var state_reader: Callable = _read_steam_state
## Quem abre o endereço steam://. Os testes trocam para não abrir jogo de verdade.
var url_opener: Callable = Callable(OS, "shell_open")

var _app_id: int = 0
var _source: Node = null
var _external: bool = false
var _launch_started_ms: int = 0
var _running_since_ms: int = 0
var _launch_timeout: float = LAUNCH_TIMEOUT
var _last_state: Dictionary = {}

## Jogo que estava rodando na última olhada com o hub parado (para perceber
## quando um jogo NOVO abre por fora). -1 = ainda não olhamos nenhuma vez.
var _last_seen_running: int = -1

var _poll_timer: Timer
var _poll_task: int = -1
## Número da sessão atual: um "minimizar depois" de uma sessão velha não vale.
var _session_number: int = 0
## Minutos jogados (segundo a Steam) quando o jogo atual começou.
var _playtime_at_start: int = 0
## Resumo da última sessão que acabou (veja get_last_session).
var _last_session: Dictionary = {}


func _ready() -> void:
	# ALWAYS = continua rodando mesmo com a árvore pausada (senão o Timer pararia).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL_IDLE
	_poll_timer.timeout.connect(_poll)
	add_child(_poll_timer)
	_poll_timer.start()


func _unhandled_input(event: InputEvent) -> void:
	# Se a pessoa voltar ao hub enquanto o jogo ainda está abrindo, Esc cancela.
	if state == State.LAUNCHING and event.is_action_pressed("ui_cancel"):
		cancel_launch()


func is_busy() -> bool:
	return state != State.IDLE


## Há quantos segundos o jogo atual está rodando (0 se nenhum está).
func get_session_seconds() -> float:
	return _seconds_since(_running_since_ms) if state == State.RUNNING else 0.0


## O jogo atual foi aberto por fora do hub (pela Steam, ou trocado lá dentro)?
func is_external_session() -> bool:
	return state == State.RUNNING and _external


## A última sessão que acabou: {"app_id", "seconds" (tempo jogado agora; 0 se
## o jogo nem chegou a rodar) e "playtime_before" (minutos que a Steam tinha
## antes)}. O HUD usa no aviso "Bem-vindo de volta".
func get_last_session() -> Dictionary:
	return _last_session


func _remember_session(app_id: int) -> void:
	var seconds := _seconds_since(_running_since_ms) if state == State.RUNNING else 0.0
	_last_session = {"app_id": app_id, "seconds": seconds, "playtime_before": _playtime_at_start}


## Pede para abrir o jogo. Devolve true se o pedido foi feito.
## Em qualquer caso, a resposta final chega pelo sinal session_ended.
func launch(app_id: int, source: Node = null) -> bool:
	var problem := _check_can_launch(app_id)
	if not problem.is_empty():
		session_ended.emit(app_id, source, false, problem)
		return false

	# Com a Steam fechada, o pedido abre a Steam primeiro: esperamos mais.
	var steam_running: bool = state_reader.call(0, true).get("steam_running", true)
	_launch_timeout = LAUNCH_TIMEOUT if steam_running else LAUNCH_TIMEOUT_STEAM_CLOSED

	var error: int = url_opener.call("steam://rungameid/%d" % app_id)
	if error != OK:
		session_ended.emit(app_id, source, false,
				"Não consegui pedir à Steam para abrir o jogo (erro %d)." % error)
		return false

	_app_id = app_id
	_source = source
	_external = false
	steam_was_closed = not steam_running
	_launch_started_ms = Time.get_ticks_msec()
	_set_state(State.LAUNCHING)

	# O hub dorme mas continua visível (tela "Abrindo X…"); minimiza quando o
	# jogo aparecer ou, no máximo, depois de MINIMIZE_AFTER_SECONDS.
	HubWindow.sleep(false)
	_minimize_after(MINIMIZE_AFTER_SECONDS)
	launch_started.emit(app_id, source)
	return true


## Desiste de esperar o jogo abrir (o jogo pode abrir mesmo assim depois; aí
## ele vira uma sessão externa).
func cancel_launch() -> void:
	if state == State.LAUNCHING:
		_end_session(false, "Você cancelou a espera por %s\n" % _game_name(_app_id)
				+ "Se o jogo abrir depois, o hub sai do caminho sozinho.")


## Mensagens: 1ª linha = o que houve (título do aviso); 2ª = o que fazer.
func _check_can_launch(app_id: int) -> String:
	if is_busy():
		return "Já existe um jogo abrindo ou rodando\nEspere ele fechar para abrir outro."
	if app_id <= 0:
		return "App ID inválido: %d\nConfira o número do jogo." % app_id
	if SteamLibrary.get_steam_path().is_empty():
		return "Não encontrei a Steam neste PC\nInstale a Steam e abra o hub de novo."
	if not SteamLibrary.is_installed(app_id):
		return "%s não está mais instalado\nInstale pela Steam e abra o hub de novo." % _game_name(app_id)
	return ""


# --- Olhando a Steam ---------------------------------------------------------

## Dispara uma consulta à Steam numa thread separada.
func _poll() -> void:
	if _poll_task != -1:
		return  # a consulta anterior ainda não terminou
	var app_id := _app_id
	var check_steam := state != State.IDLE
	var reader := state_reader
	_poll_task = WorkerThreadPool.add_task(func() -> void:
		var result: Dictionary = reader.call(app_id, check_steam)
		_on_poll_result.call_deferred(result, app_id))


## Volta para a thread principal com o resultado da consulta.
func _on_poll_result(result: Dictionary, polled_app_id: int) -> void:
	WorkerThreadPool.wait_for_task_completion(_poll_task)
	_poll_task = -1
	if polled_app_id != _app_id:
		return  # a sessão mudou enquanto a consulta rodava: resultado velho
	_apply_state(result)


## Decide o que fazer com o que a Steam disse.
func _apply_state(steam: Dictionary) -> void:
	_last_state = steam
	var running_app_id: int = steam.get("running_app_id", 0)

	match state:
		State.IDLE:
			_check_external_game(running_app_id)

		State.LAUNCHING:
			if running_app_id == _app_id or steam.get("app_running", false):
				_running_since_ms = Time.get_ticks_msec()
				_playtime_at_start = SteamLibrary.get_playtime_minutes(_app_id)
				_set_state(State.RUNNING)
				# O jogo começou: agora sim, o lugar dele (no Hyprland, um workspace
				# vazio no monitor do jogo) e o hub sai da frente. Trocar de
				# workspace só agora, e não no clique, evita que as janelinhas da
				# Steam ("Launching...") devolvam o foco ao hub no meio do caminho.
				HubWindow.make_room_for_game()
				HubWindow.minimize_now()
				_place_game_window(_app_id)
				game_started.emit(_app_id, _get_source())
			elif _seconds_since(_launch_started_ms) >= _launch_timeout:
				_end_session(false, _timeout_message(steam))

		State.RUNNING:
			if running_app_id == _app_id or (running_app_id != 0 and steam.get("app_running", false)):
				# Ainda rodando. (Se outro app "tomou" o RunningAppID, como o
				# Lossless Scaling, confiamos no Apps\<appid>\Running.)
				if not steam.get("steam_running", true):
					_end_session(false, "A Steam fechou enquanto %s rodava\n" % _game_name(_app_id)
							+ "Voltei para o hub. Abra a Steam para jogar de novo.")
			elif _is_city_game(running_app_id):
				_switch_to_game(running_app_id)
			elif not _external and _seconds_since(_running_since_ms) < QUICK_EXIT_SECONDS:
				_end_session(false, "%s fechou logo depois de abrir\n" % _game_name(_app_id)
						+ "Tente abrir pela Steam para ver se aparece algum erro.")
			else:
				_end_session(true, "")


## Com o hub parado: um jogo da cidade começou a rodar por fora do hub?
func _check_external_game(running_app_id: int) -> void:
	var previous := _last_seen_running
	_last_seen_running = running_app_id
	if previous == -1:
		return  # primeira olhada: um jogo que já estava aberto antes do hub não conta
	if running_app_id != previous and _is_city_game(running_app_id):
		_begin_external_session(running_app_id)


func _begin_external_session(app_id: int) -> void:
	_app_id = app_id
	_source = null
	_external = true
	_running_since_ms = Time.get_ticks_msec()
	_playtime_at_start = SteamLibrary.get_playtime_minutes(app_id)
	_set_state(State.RUNNING)
	# Mostra rapidinho "abriu pela Steam" e depois minimiza.
	HubWindow.sleep(false)
	_minimize_after(EXTERNAL_NOTICE_SECONDS)
	_place_game_window(app_id)
	game_started.emit(app_id, null)


## Fechou um jogo e abriu outro direto: encerra a sessão do primeiro, mas o hub
## continua dormindo e passa a acompanhar o segundo (como sessão externa).
func _switch_to_game(new_app_id: int) -> void:
	_remember_session(_app_id)
	session_ended.emit(_app_id, _get_source(), true, "")
	_app_id = new_app_id
	_source = null
	_external = true
	_running_since_ms = Time.get_ticks_msec()
	_playtime_at_start = SteamLibrary.get_playtime_minutes(new_app_id)
	_place_game_window(new_app_id)
	game_started.emit(new_app_id, null)


func _end_session(success: bool, message: String) -> void:
	var app_id := _app_id
	var source := _get_source()
	_remember_session(app_id)
	_app_id = 0
	_source = null
	_external = false
	# O que estiver rodando agora não conta como "jogo novo aberto por fora".
	_last_seen_running = _last_state.get("running_app_id", 0)
	_set_state(State.IDLE)
	HubWindow.wake()
	session_ended.emit(app_id, source, success, message)


## Explica, do jeito mais útil possível, por que o jogo não abriu.
func _timeout_message(steam: Dictionary) -> String:
	var game_name := _game_name(_app_id)
	if not steam.get("steam_running", true):
		return "%s não abriu\nA Steam não abriu. Abra a Steam e entre pela porta de novo." % game_name
	if steam.get("app_updating", false):
		return "A Steam está atualizando %s\n" % game_name \
				+ "Quando terminar e o jogo abrir, o hub sai do caminho sozinho."
	return "%s não abriu em %d s\n" % [game_name, int(_launch_timeout)] \
			+ "A Steam mostrou alguma janela ou erro? Confira e entre pela porta de novo."


## Lê o estado da Steam (o leitor de verdade). Roda na thread separada!
func _read_steam_state(app_id: int, check_steam: bool) -> Dictionary:
	return SteamClient.read_state(app_id, check_steam)


# --- Utilidades --------------------------------------------------------------

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_poll_timer.wait_time = POLL_INTERVAL_IDLE if new_state == State.IDLE else POLL_INTERVAL_SESSION
	_poll_timer.start()
	state_changed.emit(new_state)


func _is_city_game(app_id: int) -> bool:
	return app_id > 0 and SteamLibrary.get_game(app_id) != null


## Minimiza o hub daqui a "seconds" segundos, se esta mesma sessão ainda estiver
## acontecendo (o timer ignora a pausa do mundo).
func _minimize_after(seconds: float) -> void:
	_session_number += 1
	var session := _session_number
	get_tree().create_timer(seconds, true).timeout.connect(func() -> void:
		if session == _session_number and is_busy():
			HubWindow.minimize_now())


## No Hyprland, a janela do jogo vai para um workspace dele e para a tela
## cheia (no Windows, nada).
func _place_game_window(app_id: int) -> void:
	HubWindow.place_game(SteamClient.game_process_ids(app_id))


func _game_name(app_id: int) -> String:
	var game_name := SteamLibrary.get_game_name(app_id)
	return game_name if not game_name.is_empty() else "o jogo %d" % app_id


func _seconds_since(ticks_ms: int) -> float:
	return (Time.get_ticks_msec() - ticks_ms) / 1000.0


## A origem pode ter sido apagada enquanto o jogo rodava (ex.: troca de mundo).
func _get_source() -> Node:
	return _source if is_instance_valid(_source) else null
