extends SceneTree
## Teste do backend Windows da Steam com o reg.exe e o tasklist DE VERDADE
## (Fase Linux L.7). Só roda no Windows; nos outros sistemas imprime "pulado".
##
## Em vez da chave real da Steam, usa uma chave de mentira
## (HKCU\Software\GameHubTest\Steam) que o próprio teste cria e apaga no fim.
## Por isso é seguro rodar no PC de quem tem a Steam: a chave real não é tocada.
## Roda também no GitHub Actions (windows-latest), onde não existe Steam.

const TEST_ROOT: String = "HKCU\\Software\\GameHubTest"
const TEST_KEY: String = "HKCU\\Software\\GameHubTest\\Steam"
const BALATRO: int = 2379780
## O Steam do Windows guarda o caminho com barras normais; o nome tem espaço
## de propósito, para conferir que as aspas do reg.exe chegam inteiras.
const FAKE_STEAM_PATH: String = "C:/Game Hub Test/Steam"
## Um número de processo que não existe.
const DEAD_PID: int = 999999999

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if OS.get_name() != "Windows":
		print("pulado: este teste é só do Windows (aqui: %s)" % OS.get_name())
		print("\nRESULTADO: TUDO OK")
		quit()
		return

	var backend_script: GDScript = load("res://autoload/platform/steam_client_windows.gd")
	var windows = backend_script.new()
	_check("a chave do teste não é a chave real da Steam", TEST_KEY != backend_script.STEAM_REG_KEY)
	windows.reg_key = TEST_KEY

	_reg(["delete", TEST_ROOT, "/f"], false)  # sobra de uma rodada que travou
	var set_up := _build_fake_steam()
	_check("criou a chave de mentira com o reg.exe", set_up)
	if set_up:
		print("== leitura pelo SteamClientWindows ==")
		_check("caminho da Steam (veio '%s')" % windows.steam_path(), windows.steam_path() == FAKE_STEAM_PATH)
		_check("conta ativa = 16", windows.active_account_id() == 16)

		var state: Dictionary = windows.read_state(BALATRO, true)
		print("   ", state)
		_check("RunningAppID lido como número", state["running_app_id"] == BALATRO)
		_check("Apps\\<id>\\Running = 1 -> app_running", state["app_running"])
		_check("Apps\\<id>\\Updating = 0 -> não está atualizando", not state["app_updating"])
		_check("o PID da Steam (esta Godot) está vivo (tasklist)", state["steam_running"])

		var other: Dictionary = windows.read_state(123, false)
		_check("outro jogo: app_running falso", not other["app_running"])
		_check("sem check_steam: steam_running verdadeiro", other["steam_running"])

		_check("registra que o jogo parou de rodar", _reg(["add", TEST_KEY, "/v", "RunningAppID", "/t", "REG_DWORD", "/d", "0", "/f"])
				and windows.read_state(BALATRO, false)["running_app_id"] == 0)

		_check("PID morto no registro", _reg(["add", TEST_KEY + "\\ActiveProcess", "/v", "pid", "/t", "REG_DWORD",
				"/d", str(DEAD_PID), "/f"]))
		_check("processo que não existe: Steam fechada (tasklist)", not windows.read_state(0, true)["steam_running"])

	_reg(["delete", TEST_ROOT, "/f"], false)
	_check("apagou a chave de mentira", not _reg(["query", TEST_ROOT], false))

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Cria os valores que a Steam teria. Devolve false se algum comando falhar.
func _build_fake_steam() -> bool:
	var active := TEST_KEY + "\\ActiveProcess"
	var app := "%s\\Apps\\%d" % [TEST_KEY, BALATRO]
	return (_reg(["add", TEST_KEY, "/v", "SteamPath", "/t", "REG_SZ", "/d", FAKE_STEAM_PATH, "/f"])
			and _reg(["add", TEST_KEY, "/v", "RunningAppID", "/t", "REG_DWORD", "/d", str(BALATRO), "/f"])
			and _reg(["add", active, "/v", "pid", "/t", "REG_DWORD", "/d", str(OS.get_process_id()), "/f"])
			and _reg(["add", active, "/v", "ActiveUser", "/t", "REG_DWORD", "/d", "16", "/f"])
			and _reg(["add", app, "/v", "Running", "/t", "REG_DWORD", "/d", "1", "/f"])
			and _reg(["add", app, "/v", "Updating", "/t", "REG_DWORD", "/d", "0", "/f"])
			and _reg(["add", app, "/v", "Name", "/t", "REG_SZ", "/d", "Balatro", "/f"]))


## Roda o reg.exe. Devolve true se terminou bem (código 0). Com report = true,
## mostra a saída de um comando que falhou (para entender o erro no log do CI).
func _reg(args: PackedStringArray, report: bool = true) -> bool:
	var output: Array = []
	var code := OS.execute("reg", args, output, true)
	if code != 0 and report:
		print("   reg %s -> código %d: %s" % [" ".join(args), code, String(output[0]).strip_edges() if not output.is_empty() else ""])
	return code == 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
