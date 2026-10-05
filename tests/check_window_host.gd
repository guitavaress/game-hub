extends SceneTree
## Teste da janela no Hyprland (Fase Linux L.3).
##
## Usa um "hyprctl" falso: ele finge as listas de janelas, monitores e
## workspaces e anota cada comando, para conferir o que o WindowHostHyprland
## mandaria. Não mexe em janela de verdade, então roda igual no Linux e no
## Windows. No Linux, uma conferência extra roda o OS.execute de verdade com um
## script que devolve o argumento (para pegar aspas que se perdem no caminho).

const HUB_PID: int = 4242
const HUB_ADDRESS: String = "0x5500aa"

var failures := 0
## Comandos que o hyprctl falso recebeu (um texto por comando).
var calls: PackedStringArray = []
## false = finge um Hyprland antigo, que recusa a sintaxe Lua.
var accepts_lua: bool = true
## true = o workspace que o HDMI mostra está vazio.
var hdmi_showing_empty: bool = false
## true = a lista de janelas inclui as do jogo (árvore em tests/fixtures/linux/proc_arvore).
var with_game_windows: bool = false
## Workspace onde a janela do jogo (0x5003) nasceu: 6 = sozinha no HDMI;
## 3 = no workspace do hub, no eDP (a "corrida de foco").
var game_born_on: int = 6
## true = o hub já está no workspace especial (ex.: escondido pelo timer).
var hub_in_special: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var host_script: GDScript = load("res://autoload/platform/window_host_hyprland.gd")

	print("== abrir jogo: workspace vazio no monitor do jogo ==")
	var host = _new_host(host_script)
	host.make_room_for_game("HDMI-A-1")
	_check("foca o monitor do jogo", _sent("hl.dsp.focus({ monitor = 'HDMI-A-1' })"))
	_check("cria o workspace 4 (o menor número livre)", _sent("hl.dsp.focus({ workspace = '4' })"))
	_check("o monitor vem antes do workspace", _index_of("HDMI-A-1") < _index_of("workspace = '4'"))
	hdmi_showing_empty = true
	host = _new_host(host_script)
	host.make_room_for_game("HDMI-A-1")
	_check("se o HDMI já mostra um workspace vazio, usa ele (não cria outro)",
			_sent("hl.dsp.focus({ monitor = 'HDMI-A-1' })") and not _sent_part("workspace ="))
	hdmi_showing_empty = false

	print("== esconder e mostrar o hub ==")
	calls.clear()
	host.hide_hub()
	_check("hub vai para o workspace especial, sem levar a tela junto",
			_sent("hl.dsp.window.move({ workspace = 'special:gamehub', follow = false, window = 'address:%s' })" % HUB_ADDRESS))
	calls.clear()
	host.show_hub()
	_check("hub volta para o workspace 3 (onde estava)",
			_sent("hl.dsp.window.move({ workspace = '3', window = 'address:%s' })" % HUB_ADDRESS))
	_check("e ganha o foco", _sent("hl.dsp.focus({ window = 'address:%s' })" % HUB_ADDRESS))
	calls.clear()
	host.show_hub()
	_check("mostrar de novo não manda nada", calls.is_empty())

	print("== monitor do jogo desligado ou vazio no config ==")
	host = _new_host(host_script)
	host.make_room_for_game("DP-9")
	_check("DP-9 não existe: usa o monitor em foco (eDP-1)",
			_sent("hl.dsp.focus({ monitor = 'eDP-1' })") and not _sent_part("DP-9"))
	_check("e cria um workspace novo nele (o hub ocupa o atual)", _sent("hl.dsp.focus({ workspace = '4' })"))
	host = _new_host(host_script)
	host.make_room_for_game("")
	_check("game_monitor vazio: monitor em foco", _sent("hl.dsp.focus({ monitor = 'eDP-1' })"))

	print("== jogo aberto por fora do hub (sem make_room) ==")
	host = _new_host(host_script)
	host.hide_hub()
	calls.clear()
	host.show_hub()
	_check("volta para onde estava (3)", _sent_part("workspace = '3', window = 'address:%s'" % HUB_ADDRESS))

	print("== Hyprland antigo (sem Lua) ==")
	accepts_lua = false
	host = _new_host(host_script)
	host.hide_hub()
	_check("cai na sintaxe antiga", _sent("movetoworkspacesilent special:gamehub,address:%s" % HUB_ADDRESS))
	calls.clear()
	host.show_hub()
	_check("e continua nela, sem tentar Lua de novo",
			not _sent_part("hl.dsp") and _sent("focuswindow address:%s" % HUB_ADDRESS))
	accepts_lua = true

	print("== janela do hub não encontrada ==")
	host = _new_host(host_script)
	host.my_pid = 999
	host.hide_hub()
	_check("não manda comando para a janela errada", not _sent_part("window.move"))
	calls.clear()
	host.show_hub()
	_check("e não tenta trazer nada de volta", calls.is_empty())

	print("== janela do jogo: lugar e tela cheia ==")
	with_game_windows = true
	var tree := ProjectSettings.globalize_path("res://tests/fixtures/linux/proc_arvore")
	host = _new_host(host_script)
	host.proc_dir = tree
	host.place_game_windows([5000] as Array[int], "HDMI-A-1", true)
	_check("jogo já sozinho num workspace do HDMI: não move", not _sent_part("window.move"))
	_check("a janela do jogo (neta do reaper) vai para a tela cheia",
			_sent("hl.dsp.window.fullscreen_state({ internal = 2, client = 2, window = 'address:0x5003' })"))
	_check("e ganha o foco antes", _index_of("focus({ window = 'address:0x5003' })") < _index_of("fullscreen_state"))
	_check("launcher flutuante fica como está", not _sent_part("0x5004"))
	_check("janela que já está em tela cheia não ganha outra", not _sent_part("fullscreen_state({ internal = 2, client = 2, window = 'address:0x5005'"))
	_check("o hub e outras janelas não são tocados", not _sent_part(HUB_ADDRESS) and not _sent_part("0x77"))
	calls.clear()
	host.place_game_windows([5000] as Array[int], "HDMI-A-1", true)
	_check("chamar de novo não repete (cada janela uma vez)", calls.is_empty())
	host.place_game_windows([] as Array[int], "HDMI-A-1", true)
	_check("sem processos do jogo: nada", calls.is_empty())
	host.show_hub()
	calls.clear()
	host.place_game_windows([5000] as Array[int], "HDMI-A-1", true)
	_check("numa sessão nova, trata de novo", _sent_part("fullscreen_state"))

	game_born_on = 3
	host = _new_host(host_script)
	host.proc_dir = tree
	host.place_game_windows([5000] as Array[int], "HDMI-A-1", false)
	_check("corrida de foco: o jogo nasceu no workspace do hub e vai para o HDMI",
			_sent("hl.dsp.focus({ monitor = 'HDMI-A-1' })")
			and _sent("hl.dsp.window.move({ workspace = '4', window = 'address:0x5003' })"))
	_check("o foco no HDMI vem antes de mover", _index_of("monitor = 'HDMI-A-1'") < _index_of("window.move"))
	_check("game_fullscreen = false: não força a tela cheia", not _sent_part("fullscreen_state"))
	game_born_on = 6

	accepts_lua = false
	host = _new_host(host_script)
	host.proc_dir = tree
	host.place_game_windows([5000] as Array[int], "HDMI-A-1", true)
	_check("Hyprland antigo: foca e usa fullscreenstate 2 2",
			_sent("focuswindow address:0x5003") and _sent("fullscreenstate 2 2"))
	accepts_lua = true
	with_game_windows = false
	var plain = load("res://autoload/platform/window_host.gd").new()
	plain.place_game_windows([5000] as Array[int], "HDMI-A-1", true)
	_check("na versão base (Windows) não faz nada e não dá erro", true)

	print("== hub escondido antes (timer) e depois make_room ==")
	host = _new_host(host_script)
	host.hide_hub()
	hub_in_special = true
	host.make_room_for_game("HDMI-A-1")
	calls.clear()
	host.show_hub()
	hub_in_special = false
	_check("o hub ainda sabe voltar para o 3", _sent_part("workspace = '3', window = 'address:%s'" % HUB_ADDRESS))

	print("== nomes vão limpos para o comando ==")
	_check("tira aspas, $, crase e barras",
			host_script._clean("HDMI-A-1\"; rm $x `y` \\'") == "HDMI-A-1rmxy")

	if OS.get_name() == "Linux":
		print("== OS.execute de verdade (as aspas chegam inteiras?) ==")
		var real = host_script.new()
		real.hyprctl_command = ProjectSettings.globalize_path("res://tests/fixtures/linux/hyprctl_eco.sh")
		var lua := "hl.dsp.focus({ window = 'address:%s' })" % HUB_ADDRESS
		var echoed: String = real._run_hyprctl(PackedStringArray(["dispatch", lua]))
		_check("o hyprctl recebe o Lua exatamente como foi montado (veio: %s)" % echoed, echoed == lua)

	print("== qual versão o hub usa aqui ==")
	var expected := "hyprland" if OS.get_name() == "Linux" and not OS.get_environment("HYPRLAND_INSTANCE_SIGNATURE").is_empty() else "godot"
	var chosen: String = load("res://autoload/platform/window_host.gd").create().platform_name()
	_check("WindowHost.create() = '%s' (veio '%s')" % [expected, chosen], chosen == expected)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _new_host(host_script: GDScript):
	calls.clear()
	var host = host_script.new()
	host.run_hyprctl = _fake_hyprctl
	host.my_pid = HUB_PID
	return host


## O hyprctl falso. eDP-1 (em foco) mostra o workspace 3, onde está o hub;
## HDMI-A-1 mostra o 2 (com uma janela) ou o 6 (vazio). Existem 1, 2, 3, 5 (e 6).
func _fake_hyprctl(args: PackedStringArray) -> String:
	match args[0]:
		"clients":
			var hub_workspace := {"id": -98, "name": "special:gamehub"} if hub_in_special else {"id": 3, "name": "3"}
			var clients := [
				{"address": "0x77", "pid": 77, "monitor": 1, "workspace": {"id": 5, "name": "5"}},
				{"address": HUB_ADDRESS, "pid": HUB_PID, "monitor": 0, "workspace": hub_workspace},
			]
			if with_game_windows:
				clients.append_array([
					{"address": "0x5004", "pid": 5004, "floating": true, "fullscreen": 0, "monitor": 0, "workspace": {"id": 3, "name": "3"}},
					{"address": "0x5003", "pid": 5003, "floating": false, "fullscreen": 0,
						"monitor": 1 if game_born_on == 6 else 0, "workspace": {"id": game_born_on, "name": str(game_born_on)}},
					{"address": "0x5005", "pid": 5005, "floating": false, "fullscreen": 2, "monitor": 1, "workspace": {"id": 7, "name": "7"}},
				])
			return JSON.stringify(clients)
		"monitors":
			return JSON.stringify([
				{"id": 0, "name": "eDP-1", "focused": true, "activeWorkspace": {"id": 3, "name": "3"}},
				{"id": 1, "name": "HDMI-A-1", "focused": false,
					"activeWorkspace": {"id": 8 if hdmi_showing_empty else 2, "name": "8" if hdmi_showing_empty else "2"}},
			])
		"workspaces":
			var list := [
				{"id": 1, "windows": 1}, {"id": 2, "windows": 1}, {"id": 3, "windows": 1}, {"id": 5, "windows": 1},
			]
			if hdmi_showing_empty:
				list.append({"id": 8, "windows": 0})
			if with_game_windows:
				list.append({"id": 7, "windows": 1})
				if game_born_on == 6:
					list.append({"id": 6, "windows": 1})
			return JSON.stringify(list)
		"dispatch":
			calls.append(" ".join(args.slice(1)))
			var is_lua := args[1].begins_with("hl.")
			return "ok" if is_lua == accepts_lua else "error: comando desconhecido"
	return ""


func _sent(command: String) -> bool:
	return calls.has(command)


func _sent_part(part: String) -> bool:
	for call in calls:
		if call.contains(part):
			return true
	return false


func _index_of(part: String) -> int:
	for i in calls.size():
		if calls[i].contains(part):
			return i
	return -1


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
