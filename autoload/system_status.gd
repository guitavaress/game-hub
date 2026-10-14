extends Node
## SystemStatus: o estado do computador (bateria, rede, volume) para quem
## quiser mostrar (autoload).
##
## Pergunta ao SystemInfo (em autoload/platform/) a cada CHECK_EVERY segundos,
## numa thread separada, e só avisa `changed` quando algo mudou. Não pergunta
## nada enquanto o hub dorme (um jogo ou app aberto).

## A cada quantos segundos perguntamos.
const CHECK_EVERY: float = 5.0

## Algo no estado mudou (veja o formato em system_info_backend.gd).
signal changed

## O último estado lido. Antes da primeira leitura, "não sei".
var state: Dictionary = SystemInfoBackend.unknown()
## Quem lê o sistema: Callable() -> Dictionary. Os testes trocam por um falso.
var reader: Callable = SystemInfo.read

var _timer: Timer
var _task: int = -1


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = CHECK_EVERY
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()
	HubWindow.woke_up.connect(refresh)  # ao voltar, não espera os 5 s
	refresh()


## Bateria: {present, percent, charging}.
func battery() -> Dictionary:
	return state["battery"]


## Rede: {known, type, connected, name}.
func network() -> Dictionary:
	return state["network"]


## Volume: {known, percent, muted}.
func volume() -> Dictionary:
	return state["volume"]


## Pergunta agora (numa thread). Ignorado se a pergunta anterior não terminou
## ou se o hub está dormindo.
func refresh() -> void:
	if _task != -1 or HubWindow.is_sleeping:
		return
	var read := reader
	_task = WorkerThreadPool.add_task(func() -> void:
		_on_read.call_deferred(read.call()))


## Define o estado direto (a leitura que voltou da thread, ou um de teste).
func apply(new_state: Dictionary) -> void:
	if new_state == state:
		return
	state = new_state
	changed.emit()


func _on_read(result: Dictionary) -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	apply(result)


func _exit_tree() -> void:
	# Fechando o hub no meio de uma leitura: espera ela acabar, para a thread
	# não chamar um nó que já foi embora.
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
