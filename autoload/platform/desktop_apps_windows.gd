class_name DesktopAppsWindows
extends DesktopAppsBackend
## Os programas no Windows: os atalhos (.lnk) do Menu Iniciar.
##
## Pastas, da mais forte para a mais fraca: o Menu Iniciar do usuário
## (%AppData%\Microsoft\Windows\Start Menu\Programs) e o de todos
## (%ProgramData%\...\Programs), com subpastas. Se o mesmo atalho aparece nas
## duas, vale o do usuário.
##
## Não abrimos o .lnk para ler: o nome do app é o nome do arquivo, e abrir é
## entregar o próprio atalho ao Windows (OS.shell_open). Por isso não há ícone
## (a caixa mostra a inicial) nem categoria.
##
## Ficam de fora: desinstaladores, e tudo o que é .url (os jogos da Steam
## criam atalhos .url com steam://, e eles já são prédios).

## Pedaços que, no nome do atalho, indicam um desinstalador.
const UNINSTALL_WORDS: Array[String] = ["uninstall", "desinstal", "unins000", "remover "]

## Pastas "Programs" (com barras "/"), da mais forte para a mais fraca.
var dirs: PackedStringArray


func _init(folders: PackedStringArray = _default_dirs()) -> void:
	dirs = folders


func platform_name() -> String:
	return "windows"


func list_apps() -> Array[DesktopApp]:
	var result: Array[DesktopApp] = []
	var seen: Dictionary[String, bool] = {}
	for dir in dirs:
		var files: Array[String] = []
		_collect(dir.replace("\\", "/").trim_suffix("/"), "", files)
		for relative in files:
			var id := relative.get_basename()
			if seen.has(id.to_lower()):
				continue
			seen[id.to_lower()] = true
			var app_name := id.get_file()
			if _is_uninstaller(app_name):
				continue
			var app := DesktopApp.new()
			app.id = id
			app.name = app_name
			app.source_path = dir.replace("\\", "/").trim_suffix("/").path_join(relative)
			# No Windows, "o comando" é o próprio atalho: vai para o OS.shell_open.
			app.exec_line = app.source_path
			result.append(app)
	return result


## Os .lnk de uma pasta e das subpastas, como caminhos relativos a ela.
func _collect(folder: String, prefix: String, out: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(folder):
		if file_name.get_extension().to_lower() == "lnk":
			out.append(prefix + file_name)
	for sub in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(sub), prefix + sub + "/", out)


static func _is_uninstaller(app_name: String) -> bool:
	var lower := app_name.to_lower()
	for word in UNINSTALL_WORDS:
		if lower.contains(word):
			return true
	return false


static func _default_dirs() -> PackedStringArray:
	var result := PackedStringArray()
	var tail := "Microsoft/Windows/Start Menu/Programs"
	for variable in ["APPDATA", "ProgramData"]:
		var base := OS.get_environment(variable).replace("\\", "/")
		if base != "":
			result.append(base.path_join(tail))
	return result
