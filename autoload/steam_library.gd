extends Node
## SteamLibrary: lê informações da Steam instalada neste PC (autoload).
##
## FASE 2, versão mínima:
##   - get_steam_path(): onde a Steam está instalada (lido do registro);
##   - get_game_name(app_id): nome do jogo, lido do appmanifest_<appid>.acf.
## Na FASE 3 este arquivo ganha o parser VDF completo e a lista de todos os jogos.
##
## Não conhece nenhum mundo nem portal: só responde perguntas.

const STEAM_REG_KEY: String = "HKCU\\Software\\Valve\\Steam"

var _steam_path: String = ""
var _library_folders: PackedStringArray = []
## Guarda nomes já lidos, para não abrir o arquivo toda hora.
var _name_cache: Dictionary[int, String] = {}


## Caminho da pasta da Steam com barras "/" (ex.: "c:/program files (x86)/steam").
## Devolve "" se a Steam não estiver instalada.
func get_steam_path() -> String:
	if _steam_path.is_empty():
		var raw := WinRegistry.read_string(STEAM_REG_KEY, "SteamPath")
		_steam_path = raw.replace("\\", "/").trim_suffix("/")
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

	# O libraryfolders.vdf lista as outras, em linhas como:
	#     "path"		"D:\\SteamLibrary"
	# (Versão simples com expressão regular; o parser VDF de verdade vem na fase 3.)
	var vdf_text := FileAccess.get_file_as_string(steam + "/steamapps/libraryfolders.vdf")
	var path_regex := RegEx.create_from_string("\"path\"\\s+\"([^\"]+)\"")
	for found in path_regex.search_all(vdf_text):
		# No arquivo, "\" aparece duplicado ("\\"); trocamos tudo por "/".
		var folder := found.get_string(1).replace("\\\\", "/").replace("\\", "/")
		_add_library_folder(folder)
	return _library_folders


## Nome do jogo instalado com esse appid, ou "" se não encontrar.
func get_game_name(app_id: int) -> String:
	if _name_cache.has(app_id):
		return _name_cache[app_id]

	var game_name := ""
	var name_regex := RegEx.create_from_string("\"name\"\\s+\"([^\"]*)\"")
	for folder in get_library_folders():
		var manifest := "%s/steamapps/appmanifest_%d.acf" % [folder, app_id]
		if FileAccess.file_exists(manifest):
			var found := name_regex.search(FileAccess.get_file_as_string(manifest))
			if found:
				game_name = found.get_string(1)
				break

	_name_cache[app_id] = game_name
	return game_name


func _add_library_folder(folder: String) -> void:
	folder = folder.trim_suffix("/")
	# Evita duplicatas ("C:/Program Files" e "c:/program files" são a mesma pasta).
	for existing in _library_folders:
		if existing.to_lower() == folder.to_lower():
			return
	_library_folders.append(folder)
