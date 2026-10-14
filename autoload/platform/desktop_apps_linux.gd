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
## Pastas "icons" (com os temas dentro), da mais forte para a mais fraca.
var icon_dirs: PackedStringArray
## Temas de ícone, do preferido ao último recurso.
var icon_themes: PackedStringArray
## Pastas de ícones soltos (/usr/share/pixmaps).
var pixmap_dirs: PackedStringArray
## Quem começa um programa: func(programa: String, argumentos: PackedStringArray) -> int
## (o número do processo, ou -1). Os testes trocam para não abrir nada.
var start_process: Callable = OS.create_process
## Quem diz se um programa existe no PATH: func(nome: String) -> bool. Os testes trocam.
var program_exists: Callable = _program_exists

## Tamanhos tentados, nesta ordem ("scalable" = SVG).
const ICON_EXTENSIONS: PackedStringArray = ["png", "svg"]
const ICON_SIZES: PackedStringArray = ["256x256", "128x128", "scalable", "48x48", "64x64", "96x96", "192x192", "512x512", "32x32"]


func _init(folders: PackedStringArray = _default_dirs(), current_desktops: String = OS.get_environment("XDG_CURRENT_DESKTOP"),
		language: String = OS.get_locale(), icon_folders: PackedStringArray = _default_icon_dirs(),
		themes: PackedStringArray = _default_icon_themes(), pixmaps: PackedStringArray = _default_pixmap_dirs()) -> void:
	dirs = folders
	icon_dirs = icon_folders
	icon_themes = themes
	pixmap_dirs = pixmaps
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


## Abre o app, do jeito que o Omarchy abre: "uwsm-app -- <id>.desktop" (o app
## nasce dentro da sessão do desktop). Sem o uwsm-app, "gtk-launch <id>"; sem
## ele também, o próprio Exec do arquivo. true = o processo começou.
## (O app herda a saída do hub: rodando num terminal, o log dele aparece junto.)
func launch(app: DesktopApp) -> bool:
	if program_exists.call("uwsm-app"):
		return int(start_process.call("uwsm-app", PackedStringArray(["--", app.id + ".desktop"]))) > 0
	if program_exists.call("gtk-launch"):
		return int(start_process.call("gtk-launch", PackedStringArray([app.id]))) > 0
	var words := split_command(app.exec_line)
	if words.is_empty() or not program_exists.call(words[0]):
		return false
	return int(start_process.call(words[0], words.slice(1))) > 0


## Separa um comando em palavras, respeitando aspas ("a b" e 'a b') e a barra
## invertida. Ex.: sh -c "echo oi" -> ["sh", "-c", "echo oi"].
static func split_command(line: String) -> PackedStringArray:
	var words := PackedStringArray()
	var current := ""
	var quote := ""
	var has_word := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "\\" and i + 1 < line.length() and quote != "'":
			i += 1
			current += line[i]
			has_word = true
		elif quote != "":
			if c == quote:
				quote = ""
			else:
				current += c
		elif c == "\"" or c == "'":
			quote = c
			has_word = true
		elif c == " " or c == "\t":
			if has_word:
				words.append(current)
				current = ""
				has_word = false
		else:
			current += c
			has_word = true
		i += 1
	if has_word:
		words.append(current)
	return words


## Acha o arquivo do ícone. O nome pode ser um caminho absoluto; senão
## procura nos temas (<tema>/<tamanho>/apps/<nome>.png ou .svg) e, por último,
## nas pastas de ícones soltos.
func find_icon(icon_name: String) -> String:
	if icon_name == "":
		return ""
	if icon_name.begins_with("/"):
		return icon_name if FileAccess.file_exists(icon_name) else ""
	for theme in icon_themes:
		for size in ICON_SIZES:
			for dir in icon_dirs:
				var base := dir.trim_suffix("/").path_join(theme).path_join(size).path_join("apps").path_join(icon_name)
				if FileAccess.file_exists(base + ".png"):
					return base + ".png"
				if FileAccess.file_exists(base + ".svg"):
					return base + ".svg"
	for dir in pixmap_dirs:
		var base := dir.trim_suffix("/").path_join(icon_name)
		if FileAccess.file_exists(base + ".png"):
			return base + ".png"
		if FileAccess.file_exists(base + ".svg"):
			return base + ".svg"
		if FileAccess.file_exists(base) and base.get_extension() in ICON_EXTENSIONS:
			return base
	return ""


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


static func _default_icon_dirs() -> PackedStringArray:
	var result := PackedStringArray()
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home == "":
		data_home = OS.get_environment("HOME").path_join(".local/share")
	result.append(data_home.path_join("icons"))
	result.append(OS.get_environment("HOME").path_join(".icons"))
	var data_dirs := OS.get_environment("XDG_DATA_DIRS")
	if data_dirs == "":
		data_dirs = "/usr/local/share:/usr/share"
	for dir in data_dirs.split(":", false):
		result.append(dir.path_join("icons"))
	return result


## O tema do sistema (gtk-icon-theme-name do GTK 3/4), depois os temas que
## quase todo Linux tem.
static func _default_icon_themes() -> PackedStringArray:
	var result := PackedStringArray()
	var config_home := OS.get_environment("XDG_CONFIG_HOME")
	if config_home == "":
		config_home = OS.get_environment("HOME").path_join(".config")
	for gtk in ["gtk-3.0", "gtk-4.0"]:
		for line in FileAccess.get_file_as_string(config_home.path_join(gtk).path_join("settings.ini")).split("\n"):
			if line.strip_edges().begins_with("gtk-icon-theme-name"):
				var theme := line.get_slice("=", 1).strip_edges()
				if theme != "" and not theme in result:
					result.append(theme)
	for fallback in ["hicolor", "Adwaita", "Yaru"]:
		if not fallback in result:
			result.append(fallback)
	return result


static func _default_pixmap_dirs() -> PackedStringArray:
	return PackedStringArray(["/usr/share/pixmaps"])


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
