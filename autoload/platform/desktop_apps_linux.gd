class_name DesktopAppsLinux
extends DesktopAppsBackend
## Os programas no Linux: lê os arquivos .desktop das pastas do padrão XDG.
##
## Pastas, da mais forte para a mais fraca: $XDG_DATA_HOME/applications
## (~/.local/share), depois cada $XDG_DATA_DIRS/applications (/usr/share...).
## Se o mesmo id aparece em duas pastas, vale o da primeira.
##
## Entra só quem passa nestes filtros:
##   - Type=Application (não Link nem Directory);
##   - sem NoDisplay=true nem Hidden=true;
##   - OnlyShowIn / NotShowIn de acordo com o desktop atual (XDG_CURRENT_DESKTOP);
##   - TryExec, se houver, aponta para um programa que existe;
##   - não é um jogo da Steam (steam://rungameid): esses já são prédios.

## Pastas "applications" (com barras "/"), da mais forte para a mais fraca.
var dirs: PackedStringArray
## Desktops atuais (ex.: ["Hyprland"]), em minúsculas, para OnlyShowIn/NotShowIn.
var desktops: PackedStringArray
## Idioma, como "pt_BR" ("" = sem tradução).
var lang: String


func _init(folders: PackedStringArray = _default_dirs(), current_desktops: String = OS.get_environment("XDG_CURRENT_DESKTOP"),
		language: String = OS.get_locale()) -> void:
	dirs = folders
	desktops = PackedStringArray()
	for item in current_desktops.split(":", false):
		desktops.append(item.to_lower())
	lang = language


func platform_name() -> String:
	return "linux"


func list_apps() -> Array[DesktopApp]:
	var result: Array[DesktopApp] = []
	var seen: Dictionary[String, bool] = {}
	for dir in dirs:
		var files: Array[Array] = []  # pares [id, caminho]
		_collect(dir.trim_suffix("/"), "", files)
		for pair in files:
			var id: String = pair[0]
			# O primeiro a aparecer vence, mesmo que esteja escondido: é assim
			# que o usuário apaga um app do sistema (um NoDisplay em ~/.local).
			if seen.has(id):
				continue
			seen[id] = true
			var app := parse_file(pair[1], id)
			if app != null:
				result.append(app)
	return result


## Lê um .desktop. Devolve null se o arquivo não vale como app (veja os filtros).
func parse_file(path: String, id: String) -> DesktopApp:
	var entry := _read_entry(path)
	if entry.is_empty() or entry.get("Type", "") != "Application":
		return null
	if _is_true(entry.get("NoDisplay", "")) or _is_true(entry.get("Hidden", "")):
		return null
	if not _desktop_allows(entry):
		return null
	var try_exec: String = entry.get("TryExec", "")
	if try_exec != "" and not _program_exists(try_exec):
		return null
	var exec_line: String = entry.get("Exec", "")
	if exec_line == "" or exec_line.contains("steam://rungameid"):
		return null
	var app_name := _localized(entry, "Name")
	if app_name == "":
		return null
	var app := DesktopApp.new()
	app.id = id
	app.name = app_name
	app.comment = _localized(entry, "Comment")
	app.icon_name = entry.get("Icon", "")
	app.categories = PackedStringArray(_split_list(entry.get("Categories", "")))
	app.wm_class = entry.get("StartupWMClass", "")
	app.exec_line = clean_exec(exec_line)
	app.source_path = path
	return app


## Tira os códigos de campo (%f, %U, %i...) do Exec, que só fazem sentido
## quando alguém passa arquivos ou endereços. "%%" vira "%".
static func clean_exec(exec_line: String) -> String:
	var out := ""
	var i := 0
	while i < exec_line.length():
		var c := exec_line[i]
		if c == "%" and i + 1 < exec_line.length():
			if exec_line[i + 1] == "%":
				out += "%"
			i += 2
			continue
		out += c
		i += 1
	return " ".join(out.split(" ", false))


static func _default_dirs() -> PackedStringArray:
	var result := PackedStringArray()
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home == "":
		data_home = OS.get_environment("HOME").path_join(".local/share")
	result.append(data_home.path_join("applications"))
	var data_dirs := OS.get_environment("XDG_DATA_DIRS")
	if data_dirs == "":
		data_dirs = "/usr/local/share:/usr/share"
	for dir in data_dirs.split(":", false):
		result.append(dir.path_join("applications"))
	return result


## Junta [id, caminho] de todos os .desktop da pasta. Subpasta "a/b.desktop"
## tem o id "a-b" (regra do XDG).
func _collect(folder: String, prefix: String, out: Array[Array]) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	var files := DirAccess.get_files_at(folder)
	files.sort()
	for file_name in files:
		if file_name.ends_with(".desktop"):
			out.append([prefix + file_name.trim_suffix(".desktop"), folder.path_join(file_name)])
	var subs := DirAccess.get_directories_at(folder)
	subs.sort()
	for sub in subs:
		_collect(folder.path_join(sub), prefix + sub + "-", out)


## As linhas "Chave=valor" da seção [Desktop Entry] (outras seções, como as
## [Desktop Action ...], são ignoradas). Chaves traduzidas ficam como "Name[pt_BR]".
func _read_entry(path: String) -> Dictionary:
	var entry := {}
	if not FileAccess.file_exists(path):
		return entry
	var inside := false
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw_line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("["):
			inside = line == "[Desktop Entry]"
			continue
		var eq := line.find("=")
		if inside and eq > 0:
			var key := line.substr(0, eq).strip_edges()
			if not entry.has(key):
				entry[key] = line.substr(eq + 1).strip_edges()
	return entry


## Valor de uma chave no idioma do usuário: "Name[pt_BR]", depois "Name[pt]", depois "Name".
func _localized(entry: Dictionary, key: String) -> String:
	if lang != "":
		var full := lang.get_slice(".", 0)  # tira a codificação ("pt_BR.UTF-8")
		var candidates := [full]
		var short := full.get_slice("_", 0)
		if short != full:
			candidates.append(short)
		for code in candidates:
			var value: String = entry.get("%s[%s]" % [key, code], "")
			if value != "":
				return value
	return entry.get(key, "")


func _desktop_allows(entry: Dictionary) -> bool:
	var only := _split_list(entry.get("OnlyShowIn", ""))
	if not only.is_empty() and not _shares_desktop(only):
		return false
	var not_in := _split_list(entry.get("NotShowIn", ""))
	return not_in.is_empty() or not _shares_desktop(not_in)


func _shares_desktop(names: Array[String]) -> bool:
	for item in names:
		if item.to_lower() in desktops:
			return true
	return false


## O programa existe? Caminho absoluto: o arquivo; senão, procura no PATH.
func _program_exists(program: String) -> bool:
	if program.begins_with("/"):
		return FileAccess.file_exists(program)
	for dir in OS.get_environment("PATH").split(":", false):
		if FileAccess.file_exists(dir.path_join(program)):
			return true
	return false


## Lista separada por ";" (o último ";" é opcional).
static func _split_list(text: String) -> Array[String]:
	var result: Array[String] = []
	for item in text.split(";", false):
		var clean := item.strip_edges()
		if clean != "":
			result.append(clean)
	return result


static func _is_true(value: String) -> bool:
	return value.to_lower() == "true"
