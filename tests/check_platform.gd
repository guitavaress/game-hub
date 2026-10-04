extends SceneTree
## Teste da interface de plataforma (Fase Linux L.1).
##
## Confere que:
##   - o SteamClient escolhe o backend certo para este sistema operacional;
##   - o estado da Steam sempre volta com as 4 chaves que o GameLauncher usa;
##   - nenhum arquivo fora de autoload/platform/ usa código de sistema
##     operacional (registro do Windows, tasklist).
## Não precisa de Steam nem de cidade.

## Backend esperado em cada sistema (o resto cai no "nenhum").
const EXPECTED_BACKEND: Dictionary = {"Windows": "windows", "Linux": "linux"}
## Pedaços de código que só podem aparecer em autoload/platform/.
## (Para o hyprctl, só a execução: o config.cfg cita "hyprctl monitors" num comentário.)
const PLATFORM_ONLY: Array[String] = ["WinRegistry", "tasklist", "OS.execute(\"reg\"", "\"/proc", "OS.execute(\"hyprctl\""]
## Pastas que a varredura pula (os testes citam esses nomes de propósito).
const SKIP_DIRS: Array[String] = ["res://autoload/platform", "res://tests", "res://.godot"]

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var client: GDScript = load("res://autoload/platform/steam_client.gd")

	print("== backend deste sistema ==")
	var expected: String = EXPECTED_BACKEND.get(OS.get_name(), "nenhum")
	var actual: String = client.platform_name()
	_check("%s usa o backend '%s' (veio '%s')" % [OS.get_name(), expected, actual], actual == expected)

	print("== contrato do read_state ==")
	var state: Dictionary = client.read_state(0, true)
	for key: String in ["running_app_id", "steam_running", "app_running", "app_updating"]:
		_check("read_state traz '%s'" % key, state.has(key))
	_check("running_app_id é número", state.get("running_app_id") is int)

	print("== código de sistema só em autoload/platform/ ==")
	var offenders: Array[String] = []
	_scan("res://", offenders)
	for line in offenders:
		print("   ", line)
	_check("nenhum arquivo fora de autoload/platform/ usa %s" % str(PLATFORM_ONLY), offenders.is_empty())

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Procura, em todos os .gd do projeto (menos SKIP_DIRS), os pedaços proibidos.
func _scan(folder: String, offenders: Array[String]) -> void:
	for skip in SKIP_DIRS:
		if folder.trim_suffix("/") == skip:
			return
	for file_name in DirAccess.get_files_at(folder):
		if not file_name.ends_with(".gd"):
			continue
		var path := folder.path_join(file_name)
		var text := FileAccess.get_file_as_string(path)
		for token in PLATFORM_ONLY:
			if text.contains(token):
				offenders.append("%s cita %s" % [path, token])
	for sub in DirAccess.get_directories_at(folder):
		_scan(folder.path_join(sub), offenders)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
