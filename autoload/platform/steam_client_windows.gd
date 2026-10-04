class_name SteamClientWindows
extends SteamClientBackend
## A Steam no Windows: tudo vem do registro (via WinRegistry) e do tasklist.
##
## Chaves usadas, todas em HKCU\Software\Valve\Steam:
##   SteamPath                 onde a Steam está instalada;
##   RunningAppID              o jogo rodando agora (0 = nenhum);
##   ActiveProcess\pid         o processo da Steam (para saber se está aberta);
##   ActiveProcess\ActiveUser  o "account id" de quem está logado;
##   Apps\<appid>              Running e Updating de cada jogo.

const STEAM_REG_KEY: String = "HKCU\\Software\\Valve\\Steam"


func platform_name() -> String:
	return "windows"


func steam_path() -> String:
	var raw := WinRegistry.read_string(STEAM_REG_KEY, "SteamPath")
	return raw.replace("\\", "/").trim_suffix("/")


func active_account_id() -> int:
	return WinRegistry.read_dword(STEAM_REG_KEY + "\\ActiveProcess", "ActiveUser", 0)


func read_state(app_id: int, check_steam: bool) -> Dictionary:
	var result := {
		"running_app_id": WinRegistry.read_dword(STEAM_REG_KEY, "RunningAppID", 0),
		"steam_running": true,
		"app_running": false,
		"app_updating": false,
	}
	if check_steam:
		var pid := WinRegistry.read_dword(STEAM_REG_KEY + "\\ActiveProcess", "pid", 0)
		result["steam_running"] = pid > 0 and _is_process_alive(pid)
	if app_id > 0:
		var app := WinRegistry.read_values("%s\\Apps\\%d" % [STEAM_REG_KEY, app_id])
		result["app_running"] = app.get("Running", 0) == 1
		result["app_updating"] = app.get("Updating", 0) == 1
	return result


## O processo com esse número está vivo? (Usa o "tasklist" do Windows; o
## OS.is_process_running da Godot só enxerga processos abertos por ela.)
func _is_process_alive(pid: int) -> bool:
	var output: Array = []
	OS.execute("tasklist", ["/FI", "PID eq %d" % pid, "/NH", "/FO", "CSV"], output)
	# Formato CSV: "steam.exe","26664",... — procuramos o número entre aspas.
	return not output.is_empty() and String(output[0]).contains("\"%d\"" % pid)
