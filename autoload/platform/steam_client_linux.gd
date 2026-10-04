class_name SteamClientLinux
extends SteamClientBackend
## A Steam no Linux: arquivos da pasta da Steam e os processos em /proc.
##
## Por que não o registry.vdf? No Linux ele NÃO guarda o jogo rodando (testado
## na Fase Linux L.0: nem com o jogo aberto aparece RunningAppID). Então olhamos
## os processos, e uma varredura de /proc responde a tudo:
##
##   - Jogo rodando: a Steam abre cada jogo (nativo ou Proton) por um processo
##     chamado "reaper", com esta linha de comando:
##         reaper SteamLaunch AppId=2379780 -- <comando do jogo>
##     Ele vive enquanto o jogo roda e some quando o jogo fecha.
##     CUIDADO: na primeira vez que um jogo Proton abre, a Steam roda antes o
##     script de instalação com outro reaper, que tem "Install=1". Esse não é
##     o jogo, e é ignorado.
##   - Steam aberta: existe um processo chamado "steam".
##
## Pasta da Steam, na ordem: o atalho ~/.steam/root (a própria Steam o mantém
## apontando para a instalação), ~/.local/share/Steam e as pastas do Flatpak.
##
## Detalhe da Godot: os arquivos de /proc dizem ter tamanho 0, então
## FileAccess.get_file_as_string devolve "". Por isso lemos com get_buffer.

## Pasta "home" e pasta "/proc". Os testes trocam pelas pastas de exemplo.
var home_dir: String
var proc_dir: String


func _init(home: String = OS.get_environment("HOME"), proc: String = "/proc") -> void:
	home_dir = home.trim_suffix("/")
	proc_dir = proc.trim_suffix("/")


func platform_name() -> String:
	return "linux"


func steam_path() -> String:
	for candidate in _steam_dir_candidates():
		if DirAccess.dir_exists_absolute(candidate + "/steamapps"):
			return candidate
	return ""


## Com a Steam aberta, algumas versões guardam ActiveProcess/ActiveUser no
## registry.vdf. Se não houver, devolve 0 e o SteamLibrary usa o loginusers.vdf.
func active_account_id() -> int:
	for dot_steam in _dot_steam_dirs():
		var path := dot_steam + "/registry.vdf"
		if not FileAccess.file_exists(path):
			continue
		var keys: Array[String] = ["Registry", "HKCU", "Software", "Valve", "Steam", "ActiveProcess"]
		var active := Vdf.get_nested(Vdf.parse(FileAccess.get_file_as_string(path)), keys)
		var user: Variant = Vdf.get_ignoring_case(active, "ActiveUser")
		if user != null and str(user).to_int() > 0:
			return str(user).to_int()
	return 0


func read_state(app_id: int, check_steam: bool) -> Dictionary:
	var scan := _scan_processes()
	var games: Array[int] = scan["games"]
	# Se o NOSSO jogo está entre os que rodam, ele é a resposta. Senão, o mais
	# novo (o GameLauncher usa isso para perceber jogo aberto por fora do hub).
	var running := 0
	if app_id > 0 and app_id in games:
		running = app_id
	elif not games.is_empty():
		running = games[0]
	return {
		"running_app_id": running,
		"steam_running": scan["steam"] if check_steam else true,
		"app_running": app_id > 0 and app_id in games,
		# O Linux não diz isso de um jeito simples (no Windows vem do registro).
		# Sem isso, a mensagem de "não abriu" só fica mais genérica.
		"app_updating": false,
	}


## Uma volta por /proc: {"games": [app ids rodando, do mais novo ao mais
## velho], "steam": existe um processo "steam"?}
func _scan_processes() -> Dictionary:
	var pids: Array[int] = []
	for entry in DirAccess.get_directories_at(proc_dir):
		if entry.is_valid_int():
			pids.append(entry.to_int())
	pids.sort()
	pids.reverse()  # número maior = processo mais novo (quase sempre)

	var games: Array[int] = []
	var steam_seen := false
	for pid in pids:
		var command_name := _read_small("%s/%d/comm" % [proc_dir, pid]).get_string_from_utf8().strip_edges()
		if command_name == "steam":
			steam_seen = true
		elif command_name == "reaper":
			var app := _game_app_id(_split_args(_read_small("%s/%d/cmdline" % [proc_dir, pid])))
			if app > 0 and not app in games:
				games.append(app)
	return {"games": games, "steam": steam_seen}


## O app id de um reaper de jogo, ou 0 se não for jogo (ex.: Install=1).
## Só olha o que vem antes do "--" (depois dele é o comando do jogo).
static func _game_app_id(args: PackedStringArray) -> int:
	var app := 0
	var is_launch := false
	for arg in args:
		if arg == "--":
			break
		if arg == "SteamLaunch":
			is_launch = true
		elif arg == "Install=1":
			return 0
		elif arg.begins_with("AppId="):
			app = arg.trim_prefix("AppId=").to_int()
	return app if is_launch else 0


## O /proc/<pid>/cmdline separa os argumentos com o byte 0.
static func _split_args(bytes: PackedByteArray) -> PackedStringArray:
	var args := PackedStringArray()
	var start := 0
	for i in bytes.size():
		if bytes[i] == 0:
			args.append(bytes.slice(start, i).get_string_from_utf8())
			start = i + 1
	if start < bytes.size():
		args.append(bytes.slice(start).get_string_from_utf8())
	return args


## Lê até 4 KB de um arquivo (funciona em /proc). Vazio se não der para abrir
## (o processo pode ter acabado no meio da varredura).
static func _read_small(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	return file.get_buffer(4096)


## Pastas ".steam" possíveis: a normal e a do Flatpak.
func _dot_steam_dirs() -> PackedStringArray:
	return PackedStringArray([
		home_dir + "/.steam",
		home_dir + "/.var/app/com.valvesoftware.Steam/.steam",
	])


func _steam_dir_candidates() -> PackedStringArray:
	var candidates := PackedStringArray()
	for dot_steam in _dot_steam_dirs():
		for link_name: String in ["root", "steam"]:
			var target := _resolve(dot_steam, link_name)
			if not target.is_empty():
				candidates.append(target)
	candidates.append(home_dir + "/.local/share/Steam")
	candidates.append(home_dir + "/.var/app/com.valvesoftware.Steam/.local/share/Steam")
	return candidates


## Caminho real de dir/name: segue o atalho (symlink) se for um. "" se não existir.
static func _resolve(dir: String, name: String) -> String:
	var access := DirAccess.open(dir)
	if access == null:
		return ""
	if access.is_link(name):
		var target := access.read_link(name)
		if target.is_relative_path():
			target = dir.path_join(target)
		return target.simplify_path().trim_suffix("/")
	if access.dir_exists(name):
		return dir.path_join(name)
	return ""
