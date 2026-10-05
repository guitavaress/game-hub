extends SceneTree
## Teste do backend Linux da Steam (Fase Linux L.2).
##
## Usa as pastas de exemplo de tests/fixtures/linux/ (uma "home" e um /proc
## falsos), então roda igual no Linux e no Windows, sem Steam de verdade.
## Também confere quem o SteamLibrary acha que está logado no loginusers.vdf.

const FIXTURES: String = "res://tests/fixtures/linux"
const BALATRO: int = 2379780
const UNDERTALE: int = 391540

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var backend_script: GDScript = load("res://autoload/platform/steam_client_linux.gd")
	var home := ProjectSettings.globalize_path(FIXTURES + "/home")
	var proc := ProjectSettings.globalize_path(FIXTURES + "/proc")
	var linux = backend_script.new(home, proc)

	print("== pasta da Steam e conta ==")
	_check("acha ~/.local/share/Steam (veio '%s')" % linux.steam_path(),
			linux.steam_path() == home + "/.local/share/Steam")
	_check("conta ativa do registry.vdf = 16", linux.active_account_id() == 16)
	var nowhere = backend_script.new(ProjectSettings.globalize_path(FIXTURES + "/nao_existe"), proc)
	_check("sem Steam: caminho vazio", nowhere.steam_path() == "")
	_check("sem Steam: conta 0", nowhere.active_account_id() == 0)

	print("== jogo rodando (reaper) ==")
	var state: Dictionary = linux.read_state(BALATRO, true)
	print("   ", state)
	_check("Balatro rodando (reaper com AppId)", state["app_running"] and state["running_app_id"] == BALATRO)
	_check("Steam aberta (processo 'steam')", state["steam_running"])
	state = linux.read_state(UNDERTALE, true)
	_check("reaper com Install=1 NÃO conta como jogo", not state["app_running"])
	_check("sem o nosso jogo, running_app_id é o que roda", state["running_app_id"] == BALATRO)
	state = linux.read_state(0, false)
	_check("bash e steam-launch-wrapper com o texto não contam",
			state["running_app_id"] == BALATRO and not _games_in(linux).has(99) and not _games_in(linux).has(77))
	_check("só 1 jogo achado (o Balatro)", _games_in(linux) == [BALATRO])
	_check("processos do Balatro = o reaper 5000", linux.game_process_ids(BALATRO) == [5000])
	_check("Install=1 não conta como processo do jogo", linux.game_process_ids(UNDERTALE).is_empty())

	print("== nada rodando ==")
	var idle = backend_script.new(home, ProjectSettings.globalize_path(FIXTURES + "/proc_vazio"))
	state = idle.read_state(BALATRO, true)
	_check("sem reaper: running_app_id 0", state["running_app_id"] == 0 and not state["app_running"])
	_check("sem processo 'steam': Steam fechada", not state["steam_running"])
	_check("sem check_steam: Steam conta como aberta", idle.read_state(0, false)["steam_running"])

	print("== linha de comando ==")
	# Bytes de "a", 0, "b c", 0 (uma String da Godot não guarda o byte 0).
	var raw := PackedByteArray([97, 0, 98, 32, 99, 0])
	_check("separa argumentos pelo byte 0",
			backend_script._split_args(raw) == PackedStringArray(["a", "b c"]))
	_check("ignora AppId depois do '--'",
			backend_script._game_app_id(PackedStringArray(["reaper", "SteamLaunch", "--", "AppId=5"])) == 0)

	print("== quem está logado (loginusers.vdf) ==")
	var library := root.get_node("SteamLibrary")
	var by_time := '"users" { "76561190000000001" { "Timestamp" "100" } "76561190000000002" { "Timestamp" "200" } }'
	_check("sem MostRecent: o maior Timestamp", library._most_recent_user(by_time) == "76561190000000002")
	var by_flag := '"users" { "76561190000000001" { "MostRecent" "1" "Timestamp" "100" } "76561190000000002" { "Timestamp" "200" } }'
	_check("com MostRecent: ele ganha", library._most_recent_user(by_flag) == "76561190000000001")
	_check("arquivo vazio: ninguém", library._most_recent_user("") == "")

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _games_in(backend) -> Array[int]:
	return backend._scan_processes()["games"]


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
