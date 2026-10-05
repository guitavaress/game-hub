class_name WindowHostHyprland
extends WindowHost
## A janela do hub no Hyprland (Linux), usando workspaces pelo "hyprctl":
##
##   make_room_for_game (quando o jogo começa): a tela vai para um workspace
##       VAZIO do monitor do jogo, onde a janela dele deve nascer
##       ([window] game_monitor no config.cfg; se ele não estiver ligado, o
##       monitor em foco). Se o workspace ativo desse monitor já está vazio, é
##       ele; senão, criamos um novo (o menor número livre).
##   hide_hub: o hub vai para um workspace especial (oculto), "special:gamehub".
##       É o "minimizar" daqui.
##   show_hub: o hub volta para o workspace onde estava, com foco.
##   place_game_windows: quando a janela do jogo aparece, garante que ela está
##       SOZINHA num workspace do monitor do jogo (se não estiver, move para um
##       vazio, levando a tela junto) e a põe em tela cheia de verdade (sem barra
##       nem bordas; sem isso, o Hyprland a deixaria no tiling). Isso conserta a
##       "corrida de foco": quando a janelinha "Launching..." da Steam fecha, o
##       Hyprland pode devolver o foco ao hub, e o jogo nasceria no workspace
##       dele. Também vale para jogos abertos por fora do hub.
##       Achamos as janelas do jogo pela "árvore" de processos: a janela é de
##       um processo "filho" (ou neto...) do reaper do jogo. Janelas flutuantes
##       (launchers, avisos) ficam como estão, e cada janela é tratada uma vez.
##
## Sintaxe: no Hyprland 0.56 o "hyprctl dispatch" é Lua, ex.:
##     hyprctl dispatch "hl.dsp.focus({ window = 'address:0x55...' })"
## Hyprlands antigos usam outra (ex.: "hyprctl dispatch focuswindow address:0x55...").
## Tentamos a nova; se ela for recusada e a antiga funcionar, passamos a usar a
## antiga. Se nada funcionar, caímos no minimizar da Godot (base).
##
## CUIDADO com aspas: para ler a resposta, a Godot roda o comando por um shell,
## com cada argumento entre aspas DUPLAS. Uma aspa dupla dentro do argumento
## some no caminho. Por isso o Lua aqui usa só aspas SIMPLES, e todo nome que
## entra num comando passa pelo _clean (só letras, números e - _ . :).
##
## Achamos a NOSSA janela na lista do "hyprctl clients -j" pelo número do processo.

const SPECIAL_WORKSPACE: String = "special:gamehub"

## O programa chamado (os testes trocam por um script que devolve o argumento).
var hyprctl_command: String = "hyprctl"
## Quem roda o hyprctl: func(args: PackedStringArray) -> String (a resposta).
## Os testes trocam por um hyprctl falso.
var run_hyprctl: Callable = _run_hyprctl
## Número do processo do hub (os testes trocam).
var my_pid: int = OS.get_process_id()
## Pasta "/proc" (os testes trocam por uma de exemplo).
var proc_dir: String = "/proc"

## Workspace para onde o hub volta ("" = não mexemos em nada).
var _return_workspace: String = ""
## true se o hub foi mesmo para o workspace especial.
var _hidden: bool = false
## true = este Hyprland só entende a sintaxe antiga do dispatch.
var _legacy: bool = false
## Janelas de jogo já tratadas nesta sessão (endereço -> true).
var _handled_game_windows: Dictionary = {}
## Monitor que o make_room_for_game escolheu para o jogo ("" = nenhum ainda).
var _game_monitor_name: String = ""


func platform_name() -> String:
	return "hyprland"


func manages_placement() -> bool:
	return true


func make_room_for_game(game_monitor: String) -> void:
	var me := _my_window()
	if me.is_empty():
		return
	if _return_workspace.is_empty():
		_return_workspace = _workspace_selector(me)  # já guardado se o hub se escondeu antes

	var workspaces := _query("workspaces")
	var monitor := _pick_monitor(_query("monitors"), _clean(game_monitor))
	if monitor.is_empty():
		return
	var monitor_name := _clean(str(monitor.get("name", "")))
	_game_monitor_name = monitor_name
	_dispatch("hl.dsp.focus({ monitor = '%s' })" % monitor_name,
			PackedStringArray(["focusmonitor", monitor_name]))

	var active: Dictionary = monitor.get("activeWorkspace", {})
	if _window_count(workspaces, int(active.get("id", 0))) == 0:
		return  # o workspace que esse monitor mostra já está vazio: o jogo abre nele
	var free_id := _free_workspace_id(workspaces)
	_dispatch("hl.dsp.focus({ workspace = '%d' })" % free_id,
			PackedStringArray(["workspace", str(free_id)]))


func hide_hub() -> void:
	var me := _my_window()
	if not me.is_empty():
		if _return_workspace.is_empty():
			_return_workspace = _workspace_selector(me)  # ex.: jogo aberto por fora
		var address := _clean(str(me.get("address", "")))
		_hidden = _dispatch(
				"hl.dsp.window.move({ workspace = '%s', follow = false, window = 'address:%s' })" % [SPECIAL_WORKSPACE, address],
				PackedStringArray(["movetoworkspacesilent", "%s,address:%s" % [SPECIAL_WORKSPACE, address]]))
	if not _hidden:
		push_warning("Hyprland: não consegui esconder o hub; usando o minimizar da Godot.")
		super.hide_hub()


func place_game_windows(game_pids: Array[int], game_monitor: String, fullscreen: bool) -> void:
	if game_pids.is_empty():
		return
	var clients := _query("clients")
	for client: Variant in clients:
		if not client is Dictionary:
			continue
		var address := _clean(str(client.get("address", "")))
		if address.is_empty() or _handled_game_windows.has(address):
			continue
		if client.get("floating", false):
			continue  # launcher ou aviso: fica do jeito que abriu
		if not _descends_from(int(client.get("pid", -1)), game_pids):
			continue
		_handled_game_windows[address] = true
		_put_on_game_workspace(client, clients, game_monitor)
		_dispatch("hl.dsp.focus({ window = 'address:%s' })" % address,
				PackedStringArray(["focuswindow", "address:%s" % address]))
		if fullscreen and int(client.get("fullscreen", 0)) < 2:
			# fullscreen_state DEFINE o estado (2 = tela cheia). O "fullscreen"
			# comum alterna, e tiraria da tela cheia um jogo que já estivesse nela.
			_dispatch("hl.dsp.window.fullscreen_state({ internal = 2, client = 2, window = 'address:%s' })" % address,
					PackedStringArray(["fullscreenstate", "2 2"]))


## Se a janela do jogo não está sozinha (entre as janelas do tiling) num
## workspace do monitor do jogo, move para um workspace vazio desse monitor.
func _put_on_game_workspace(window: Dictionary, clients: Array, game_monitor: String) -> void:
	var wanted := _game_monitor_name if not _game_monitor_name.is_empty() else _clean(game_monitor)
	var monitor := _pick_monitor(_query("monitors"), wanted)
	if monitor.is_empty():
		return
	var workspace_id := int(window.get("workspace", {}).get("id", 0))
	var on_game_monitor := int(window.get("monitor", -1)) == int(monitor.get("id", -2))
	if on_game_monitor and workspace_id > 0 and _other_tiled_windows(clients, workspace_id, window) == 0:
		return  # já está sozinho num workspace do monitor certo
	var monitor_name := _clean(str(monitor.get("name", "")))
	# Foco no monitor antes: um workspace que ainda não existe nasce no monitor em foco.
	_dispatch("hl.dsp.focus({ monitor = '%s' })" % monitor_name,
			PackedStringArray(["focusmonitor", monitor_name]))
	var workspaces := _query("workspaces")
	var target := int(monitor.get("activeWorkspace", {}).get("id", 0))
	if target <= 0 or _window_count(workspaces, target) != 0:
		target = _free_workspace_id(workspaces)
	var address := _clean(str(window.get("address", "")))
	# Sem "follow = false": a tela vai junto para o workspace do jogo.
	_dispatch("hl.dsp.window.move({ workspace = '%d', window = 'address:%s' })" % [target, address],
			PackedStringArray(["movetoworkspace", "%d,address:%s" % [target, address]]))


## Quantas OUTRAS janelas do tiling (não flutuantes) estão nesse workspace.
static func _other_tiled_windows(clients: Array, workspace_id: int, window: Dictionary) -> int:
	var count := 0
	for client: Variant in clients:
		if not client is Dictionary or client.get("address") == window.get("address"):
			continue
		if client.get("floating", false):
			continue
		if int(client.get("workspace", {}).get("id", 0)) == workspace_id:
			count += 1
	return count


func show_hub() -> void:
	_handled_game_windows.clear()
	_game_monitor_name = ""
	if _return_workspace.is_empty():
		return
	var me := _my_window()
	if not me.is_empty():
		var address := _clean(str(me.get("address", "")))
		# Sem "follow = false": a tela vai junto para o workspace do hub.
		_dispatch("hl.dsp.window.move({ workspace = '%s', window = 'address:%s' })" % [_return_workspace, address],
				PackedStringArray(["movetoworkspace", "%s,address:%s" % [_return_workspace, address]]))
		_dispatch("hl.dsp.focus({ window = 'address:%s' })" % address,
				PackedStringArray(["focuswindow", "address:%s" % address]))
	_return_workspace = ""
	_hidden = false


## Manda um comando ao Hyprland. Devolve true se ele respondeu "ok".
func _dispatch(lua: String, legacy: PackedStringArray) -> bool:
	if not _legacy:
		var reply: String = run_hyprctl.call(PackedStringArray(["dispatch", lua]))
		if reply == "ok":
			return true
		if run_hyprctl.call(PackedStringArray(["dispatch"]) + legacy) == "ok":
			_legacy = true
			return true
		push_warning("Hyprland recusou o comando (%s): %s" % [lua, reply])
		return false
	return run_hyprctl.call(PackedStringArray(["dispatch"]) + legacy) == "ok"


## Lista do Hyprland em JSON ("clients", "monitors", "workspaces"); [] se falhar.
func _query(kind: String) -> Array:
	var parsed: Variant = JSON.parse_string(run_hyprctl.call(PackedStringArray([kind, "-j"])))
	return parsed if parsed is Array else []


## A janela do hub na lista do Hyprland ({} se não achar).
func _my_window() -> Dictionary:
	for client: Variant in _query("clients"):
		if client is Dictionary and int(client.get("pid", -1)) == my_pid:
			return client
	return {}


## O processo "pid" é um dos "roots" ou descende de um deles?
func _descends_from(pid: int, roots: Array[int]) -> bool:
	for _step in 64:  # limite de segurança
		if pid in roots:
			return true
		pid = _parent_pid(pid)
		if pid <= 1:
			return false
	return false


## O processo pai, lido de /proc/<pid>/stat ("pid (nome) estado pai ...").
## O nome pode ter espaços e parênteses, então olhamos depois do último ")".
## (Os arquivos de /proc dizem ter tamanho 0: por isso get_buffer.)
func _parent_pid(pid: int) -> int:
	var file := FileAccess.open("%s/%d/stat" % [proc_dir, pid], FileAccess.READ)
	if file == null:
		return 0
	var text := file.get_buffer(1024).get_string_from_utf8()
	var after_name := text.substr(text.rfind(")") + 1).strip_edges().split(" ", false)
	return after_name[1].to_int() if after_name.size() > 1 else 0


## O monitor do jogo, se estiver ligado; senão, o que está em foco.
static func _pick_monitor(monitors: Array, wanted: String) -> Dictionary:
	var focused: Dictionary = {}
	for monitor: Variant in monitors:
		if not monitor is Dictionary:
			continue
		if not wanted.is_empty() and str(monitor.get("name", "")) == wanted:
			return monitor
		if monitor.get("focused", false):
			focused = monitor
	return focused


static func _window_count(workspaces: Array, workspace_id: int) -> int:
	for workspace: Variant in workspaces:
		if workspace is Dictionary and int(workspace.get("id", 0)) == workspace_id:
			return int(workspace.get("windows", 0))
	return -1  # não achou: tratamos como "não está vazio"


## O menor número de workspace que ainda não existe (ele nasce no monitor em foco).
static func _free_workspace_id(workspaces: Array) -> int:
	var used: Array[int] = []
	for workspace: Variant in workspaces:
		if workspace is Dictionary:
			used.append(int(workspace.get("id", 0)))
	var candidate := 1
	while candidate in used:
		candidate += 1
	return candidate


## Como apontar o workspace atual de uma janela num comando: "3" para os
## numerados; "name:<nome>" para os que têm nome.
static func _workspace_selector(window: Dictionary) -> String:
	var workspace: Dictionary = window.get("workspace", {})
	var id := int(workspace.get("id", 0))
	if id > 0:
		return str(id)
	var workspace_name := _clean(str(workspace.get("name", "")))
	if workspace_name.is_empty() or workspace_name.begins_with("special:"):
		return ""  # sem um lugar bom para voltar: não mexemos
	return "name:" + workspace_name


## Deixa só letras, números e - _ . : (o texto vai dentro de um comando de shell).
static func _clean(text: String) -> String:
	var result := ""
	for character in text.strip_edges():
		if character.is_valid_identifier() or character.is_valid_int() or character in "-.:":
			result += character
	return result


func _run_hyprctl(args: PackedStringArray) -> String:
	var output: Array = []
	OS.execute(hyprctl_command, args, output, true)
	return "" if output.is_empty() else String(output[0]).strip_edges()
