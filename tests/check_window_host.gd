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
			return JSON.stringify([
				{"address": "0x77", "pid": 77, "workspace": {"id": 5, "name": "5"}},
				{"address": HUB_ADDRESS, "pid": HUB_PID, "workspace": {"id": 3, "name": "3"}},
			])
		"monitors":
			return JSON.stringify([
				{"name": "eDP-1", "focused": true, "activeWorkspace": {"id": 3, "name": "3"}},
				{"name": "HDMI-A-1", "focused": false,
					"activeWorkspace": {"id": 6 if hdmi_showing_empty else 2, "name": "6" if hdmi_showing_empty else "2"}},
			])
		"workspaces":
			var list := [
				{"id": 1, "windows": 1}, {"id": 2, "windows": 1}, {"id": 3, "windows": 1}, {"id": 5, "windows": 1},
			]
			if hdmi_showing_empty:
				list.append({"id": 6, "windows": 0})
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
