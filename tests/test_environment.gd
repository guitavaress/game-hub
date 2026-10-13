extends RefCounted
## Instala dados sintéticos antes do teste. Só o runner chama este helper;
## nenhum autoload de produção conhece o ambiente de testes.

class FixtureSteam extends SteamClientBackend:
	var path: String

	func steam_path() -> String:
		return path

	func active_account_id() -> int:
		return 1

	func read_state(_app_id: int, _check_steam: bool) -> Dictionary:
		return {"running_app_id": 0, "steam_running": true, "app_running": false, "app_updating": false}


static func install(root: Node) -> void:
	# Falha antes de criar qualquer fixture se alguém esquecer o isolamento.
	var expected := OS.get_environment("GAME_HUB_TEST_DATA")
	assert(not expected.is_empty() and OS.get_user_data_dir().replace("\\", "/").begins_with(expected + "/"),
			"O runner deve isolar user:// antes de instalar as fixtures")
	var backend := FixtureSteam.new()
	backend.path = ProjectSettings.globalize_path("user://steam_fixture")
	SteamClient._backend = backend
	var library := root.get_node("SteamLibrary")
	library._steam_path = backend.path
	var store := root.get_node("StoreInfo")
	var art := root.get_node("GameArt")
	art.allow_downloads = false
	var launcher := root.get_node("GameLauncher")
	launcher.state_reader = backend.read_state
	launcher.url_opener = func(_url: String) -> int: return OK
	# Mesmo com janela, testes nunca minimizam nem trocam workspaces reais.
	root.get_node("HubWindow")._window_host = WindowHost.new()
	root.get_node("FriendsService").set_process(false)
	var games: Array[Array] = [
		[2379780, "Balatro", "cartas"],
		[489830, "The Elder Scrolls V: Skyrim Special Edition", "rpg"],
		[413150, "Stardew Valley", "simulacao"],
		[892970, "Valheim", "terror"],
		[9000001, "Jogo de Sobrevivência", "sobrevivencia"],
		[9000002, "Jogo de Esportes", "esportes"],
	]
	_write(backend.path + "/steamapps/libraryfolders.vdf", '"libraryfolders" {}')
	_write(backend.path + "/config/loginusers.vdf", '"users" {}')
	_write(backend.path + "/userdata/1/config/localconfig.vdf", '"UserLocalConfigStore" { "Software" { "Valve" { "Steam" { "apps" {} } } } }')
	for entry in games:
		var id: int = entry[0]
		_write(backend.path + "/steamapps/appmanifest_%d.acf" % id,
				'"AppState" { "appid" "%d" "name" "%s" "installdir" "fixture_%d" "StateFlags" "4" }' % [id, entry[1], id])
		var profile := Profiles.district(entry[2])
		assert(profile != null, "Categoria inválida na fixture")
		store._cache[str(id)] = {"fetched": int(Time.get_unix_time_from_system()),
			"tags": Array(profile.tags), "capsule": "", "capsule_2x": "", "hero": "", "header": ""}
		var folder := backend.path + "/appcache/librarycache/%d" % id
		DirAccess.make_dir_recursive_absolute(folder)
		var cover := Image.create(600, 900, false, Image.FORMAT_RGB8)
		cover.fill(Color(0.2, 0.4, 0.6))
		cover.save_jpg(folder + "/library_600x900.jpg")
		var hero := Image.create(960, 310, false, Image.FORMAT_RGB8)
		hero.fill(Color(0.6, 0.3, 0.2))
		hero.save_jpg(folder + "/library_hero.jpg")
	_write("user://cache/store_info.json", JSON.stringify(store._cache))


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Não foi possível preparar a fixture")
	file.store_string(text)
