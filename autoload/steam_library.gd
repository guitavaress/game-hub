extends Node
## SteamLibrary: lê os jogos instalados neste PC (autoload).
##
## Como funciona:
##   1. O SteamClient diz onde a Steam está instalada (no Windows, pelo registro).
##   2. <Steam>/steamapps/libraryfolders.vdf lista as bibliotecas (pode haver
##      uma por disco).
##   3. Em cada biblioteca, cada steamapps/appmanifest_<appid>.acf descreve um
##      app instalado (nome, pasta, última vez jogado...).
##   4. Tiramos o que não é jogo: ferramentas da Steam (lista abaixo) e o que o
##      usuário escondeu no config.cfg (AppConfig).
##
## Só LÊ arquivos da Steam; nunca escreve nada nas pastas dela.
## Não conhece nenhum mundo: só responde perguntas.

## Apps da própria Steam que nunca são jogos.
const EXCLUDED_APP_IDS: Array[int] = [
	228980,   # Steamworks Common Redistributables
	250820,   # SteamVR
	1070560,  # Steam Linux Runtime 1.0 (scout)
	1391110,  # Steam Linux Runtime 2.0 (soldier)
	1628350,  # Steam Linux Runtime 3.0 (sniper)
	1493710,  # Proton Experimental
	1826330,  # Proton EasyAntiCheat Runtime
	1161040,  # Proton BattlEye Runtime
]

## Pedaços de nome que indicam "não é jogo" (comparação sem maiúsculas).
const EXCLUDED_NAME_PARTS: Array[String] = [
	"redistributable",
	"steamworks common",
	"steam linux runtime",
	"steamvr",
	"dedicated server",
	"soundtrack",
]

## SteamID64 = este número + o "account id" (o número curto da conta).
const STEAM_ID64_BASE: int = 76561197960265728

## Bit do StateFlags que significa "instalado" (4). Os outros bits indicam
## coisas como "atualização pendente", que não impedem de jogar.
const STATE_FLAG_INSTALLED: int = 4

var _steam_path: String = ""
var _library_folders: PackedStringArray = []
var _games: Array[SteamGame] = []
var _games_by_id: Dictionary[int, SteamGame] = {}
var _games_loaded: bool = false

## Tempo jogado (minutos) e última vez jogado, lidos do localconfig.vdf.
var _playtime_minutes: Dictionary[int, int] = {}
var _local_last_played: Dictionary[int, int] = {}
var _playtimes_loaded: bool = false


func _ready() -> void:
	# Depois de jogar, o tempo jogado muda: relemos quando o hub acorda.
	# (call_deferred: o HubWindow é criado depois deste autoload.)
	(func() -> void: HubWindow.woke_up.connect(reload_playtimes)).call_deferred()


## Caminho da pasta da Steam com barras "/" (ex.: "c:/program files (x86)/steam").
## Devolve "" se a Steam não estiver instalada.
func get_steam_path() -> String:
	if _steam_path.is_empty():
		_steam_path = SteamClient.steam_path()
	return _steam_path


## Todas as pastas de biblioteca da Steam (pode haver uma por disco).
func get_library_folders() -> PackedStringArray:
	if not _library_folders.is_empty():
		return _library_folders

	var steam := get_steam_path()
	if steam.is_empty():
		return _library_folders

	# A pasta da própria Steam sempre é uma biblioteca.
	_add_library_folder(steam)

	var data := Vdf.parse(FileAccess.get_file_as_string(steam + "/steamapps/libraryfolders.vdf"))
	# O arquivo começa com "libraryfolders" (ou "LibraryFolders" em versões antigas).
	for root_key: String in data:
		var folders: Variant = data[root_key]
		if not folders is Dictionary:
			continue
		for key: String in folders:
			var entry: Variant = folders[key]
			if entry is Dictionary and entry.has("path"):
				_add_library_folder(entry["path"])     # formato atual
			elif entry is String and key.is_valid_int():
				_add_library_folder(entry)             # formato antigo: "1" "D:\\Jogos"
	return _library_folders


## Jogos instalados (sem ferramentas nem apps escondidos), em ordem alfabética.
func get_installed_games() -> Array[SteamGame]:
	if not _games_loaded:
		_load_games()
	return _games


## Ficha de um jogo instalado, ou null se não estiver na lista.
func get_game(app_id: int) -> SteamGame:
	if not _games_loaded:
		_load_games()
	return _games_by_id.get(app_id)


## Nome de um app instalado (mesmo que esteja escondido), ou "" se não achar.
func get_game_name(app_id: int) -> String:
	var game := get_game(app_id)
	if game != null:
		return game.name
	for folder in get_library_folders():
		var manifest := "%s/steamapps/appmanifest_%d.acf" % [folder, app_id]
		if FileAccess.file_exists(manifest):
			var found := _read_manifest(manifest, folder)
			if found != null:
				return found.name
	return ""


## Confere AGORA (relendo o arquivo) se o app ainda está instalado.
## Útil antes de abrir um jogo: ele pode ter sido desinstalado com o hub aberto.
func is_installed(app_id: int) -> bool:
	for folder in get_library_folders():
		var manifest := "%s/steamapps/appmanifest_%d.acf" % [folder, app_id]
		if FileAccess.file_exists(manifest) and _read_manifest(manifest, folder) != null:
			return true
	return false


## Minutos jogados nesse app (-1 = não sabemos, por exemplo sem usuário logado).
func get_playtime_minutes(app_id: int) -> int:
	if not _playtimes_loaded:
		_load_playtimes()
	if _playtime_minutes.is_empty():
		return -1
	return _playtime_minutes.get(app_id, 0)


## Última vez que o app foi jogado (segundos desde 1970; 0 = nunca).
func get_last_played(app_id: int) -> int:
	if not _playtimes_loaded:
		_load_playtimes()
	var from_manifest := 0
	var game := get_game(app_id)
	if game != null:
		from_manifest = game.last_played
	return maxi(from_manifest, _local_last_played.get(app_id, 0))


## Esquece o tempo jogado lido (será relido na próxima pergunta).
func reload_playtimes() -> void:
	_playtimes_loaded = false


## Lê <Steam>/userdata/<conta>/config/localconfig.vdf, onde a Steam guarda,
## por app, "Playtime" (minutos jogados) e "LastPlayed".
func _load_playtimes() -> void:
	_playtimes_loaded = true
	_playtime_minutes.clear()
	_local_last_played.clear()

	var steam_id := get_current_steam_id()
	if steam_id.is_empty() or get_steam_path().is_empty():
		return
	var account_id := steam_id.to_int() - STEAM_ID64_BASE
	var path := "%s/userdata/%d/config/localconfig.vdf" % [get_steam_path(), account_id]
	if not FileAccess.file_exists(path):
		return

	var data := Vdf.parse(FileAccess.get_file_as_string(path))
	var keys: Array[String] = ["UserLocalConfigStore", "Software", "Valve", "Steam", "apps"]
	var apps := Vdf.get_nested(data, keys)
	for key: String in apps:
		var app: Variant = apps[key]
		if not (key.is_valid_int() and app is Dictionary):
			continue
		var app_id := key.to_int()
		var playtime: Variant = Vdf.get_ignoring_case(app, "Playtime")
		_playtime_minutes[app_id] = int(playtime) if playtime != null else 0
		var last_played: Variant = Vdf.get_ignoring_case(app, "LastPlayed")
		if last_played != null:
			_local_last_played[app_id] = int(last_played)


## SteamID64 (17 dígitos, em texto) de quem está logado na Steam, ou "" se não souber.
func get_current_steam_id() -> String:
	# Com a Steam aberta, ela diz o "account id" de quem está logado.
	var account_id := SteamClient.active_account_id()
	if account_id > 0:
		return str(STEAM_ID64_BASE + account_id)

	# Senão (Steam fechada, ou o Linux): o usuário mais recente do loginusers.vdf.
	var steam := get_steam_path()
	if steam.is_empty():
		return ""
	return _most_recent_user(FileAccess.get_file_as_string(steam + "/config/loginusers.vdf"))


## Quem entrou por último, segundo o texto do loginusers.vdf: quem tem
## "MostRecent" = 1 ou, se ninguém tiver (a Steam nova não grava mais isso),
## o maior "Timestamp". Devolve o SteamID64 ou "".
func _most_recent_user(loginusers_text: String) -> String:
	var users: Variant = Vdf.get_ignoring_case(Vdf.parse(loginusers_text), "users")
	if not users is Dictionary:
		return ""
	var newest_id := ""
	var newest_time := -1
	for steam_id: String in users:
		var user: Variant = users[steam_id]
		if not user is Dictionary:
			continue
		if str(Vdf.get_ignoring_case(user, "MostRecent")) == "1":
			return steam_id
		var timestamp := str(Vdf.get_ignoring_case(user, "Timestamp")).to_int()
		if timestamp > newest_time:
			newest_time = timestamp
			newest_id = steam_id
	return newest_id


## Esquece o que já foi lido (para ler tudo de novo na próxima pergunta).
func reload() -> void:
	_steam_path = ""
	_library_folders = []
	_games = []
	_games_by_id = {}
	_games_loaded = false


func _load_games() -> void:
	_games_loaded = true
	var user_excluded := AppConfig.get_excluded_app_ids()

	for folder in get_library_folders():
		var steamapps := folder + "/steamapps"
		if not DirAccess.dir_exists_absolute(steamapps):
			continue  # ex.: biblioteca num disco externo desconectado
		for file_name in DirAccess.get_files_at(steamapps):
			if not (file_name.begins_with("appmanifest_") and file_name.ends_with(".acf")):
				continue
			var game := _read_manifest(steamapps + "/" + file_name, folder)
			if game == null or _games_by_id.has(game.app_id):
				continue
			if _is_tool(game) or game.app_id in user_excluded:
				continue
			_games.append(game)
			_games_by_id[game.app_id] = game

	_games.sort_custom(func(a: SteamGame, b: SteamGame) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)


## Lê um appmanifest_<appid>.acf. Devolve null se não for um app instalado.
func _read_manifest(path: String, library: String) -> SteamGame:
	var data := Vdf.parse(FileAccess.get_file_as_string(path))
	var state: Dictionary = data.get("AppState", {})
	if state.is_empty():
		return null
	if (int(state.get("StateFlags", "0")) & STATE_FLAG_INSTALLED) == 0:
		return null  # ainda baixando, ou desinstalado pela metade

	var game := SteamGame.new()
	game.app_id = int(state.get("appid", "0"))
	game.name = state.get("name", "")
	game.install_dir = state.get("installdir", "")
	game.library_path = library
	game.last_played = int(state.get("LastPlayed", "0"))
	game.size_on_disk = int(state.get("SizeOnDisk", "0"))
	if game.app_id <= 0 or game.name.is_empty():
		return null
	return game


## true para ferramentas da Steam (Proton, redistribuíveis, SteamVR...).
func _is_tool(game: SteamGame) -> bool:
	if game.app_id in EXCLUDED_APP_IDS:
		return true
	var lower_name := game.name.to_lower()
	if lower_name.begins_with("proton "):
		return true
	for part in EXCLUDED_NAME_PARTS:
		if lower_name.contains(part):
			return true
	return false


func _add_library_folder(folder: String) -> void:
	folder = folder.replace("\\", "/").trim_suffix("/")
	# Evita duplicatas ("C:/Program Files" e "c:/program files" são a mesma pasta).
	for existing in _library_folders:
		if existing.to_lower() == folder.to_lower():
			return
	_library_folders.append(folder)
