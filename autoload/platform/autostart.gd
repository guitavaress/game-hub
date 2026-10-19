class_name Autostart
extends RefCounted
## Abrir o hub sozinho quando a sessão começa (Fase 14.10), e a linha do atalho
## de teclado que chama o hub.
##
## No Linux (Omarchy), é um arquivo do padrão XDG: ~/.config/autostart/game-hub.desktop.
## Criar o arquivo liga; apagar desliga. Nos outros sistemas, "não dá": supported()
## é false e nada é escrito (a aba "Sistema" do computador nem aparece).
##
## O atalho (SUPER + H) o hub NUNCA escreve na config do Hyprland: ele só monta a
## linha para o usuário copiar e colar no ~/.config/hypr/bindings.lua.
##
## Tudo o que é de sistema (a pasta do autostart, o .desktop, o comando
## omarchy-launch-or-focus) fica só em autoload/platform/.

const FILE_NAME: String = "game-hub.desktop"
## O nome da janela do hub (config/name do projeto), que o atalho procura.
const WINDOW_PATTERN: String = "Game Hub"
const SHORTCUT_KEY: String = "SUPER + H"

## Pasta do autostart (com "/"). Os testes trocam por uma pasta de exemplo.
var dir: String
## true se este sistema sabe fazer autostart.
var _supported: bool
## O programa e a pasta do projeto que o comando usa. Os testes trocam.
var godot_path: String
var project_path: String


func _init(autostart_dir: String = _default_dir(), linux: bool = OS.get_name() == "Linux",
		godot: String = OS.get_executable_path(),
		project: String = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else "") -> void:
	dir = autostart_dir.trim_suffix("/")
	_supported = linux
	godot_path = godot
	project_path = project.trim_suffix("/")


## Este sistema sabe abrir o hub ao entrar? (Só o Linux, por enquanto.)
func supported() -> bool:
	return _supported


func file_path() -> String:
	return dir.path_join(FILE_NAME)


## O arquivo existe (e não está desligado por dentro).
func is_enabled() -> bool:
	if not _supported or not FileAccess.file_exists(file_path()):
		return false
	var text := FileAccess.get_file_as_string(file_path())
	for line in text.split("\n"):
		var clean := line.strip_edges()
		if clean == "Hidden=true" or clean == "X-GNOME-Autostart-enabled=false":
			return false
	return true


## Liga (cria o arquivo) ou desliga (apaga). Devolve true se deu certo.
func set_enabled(on: bool) -> bool:
	if not _supported:
		return false
	if not on:
		if not FileAccess.file_exists(file_path()):
			return true
		return DirAccess.remove_absolute(file_path()) == OK
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var file := FileAccess.open(file_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(desktop_file_text())
	return true


## O conteúdo do .desktop.
func desktop_file_text() -> String:
	return "[Desktop Entry]\nType=Application\nName=Game Hub\nComment=Abre o hub quando a sessão começa\nExec=%s\nTerminal=false\nX-GNOME-Autostart-enabled=true\n" % exec_line()


## O comando que abre o hub, no formato do campo Exec do .desktop.
func exec_line() -> String:
	var parts: Array[String] = [_desktop_quote(godot_path)]
	if not project_path.is_empty():
		parts.append("--path")
		parts.append(_desktop_quote(project_path))
	return " ".join(parts)


## A linha para colar no ~/.config/hypr/bindings.lua: foca o hub se ele já está
## aberto (mesmo escondido) e abre se não está.
func shortcut_line() -> String:
	var command := _shell_quote(godot_path)
	if not project_path.is_empty():
		command += " --path " + _shell_quote(project_path)
	var launch := "omarchy-launch-or-focus %s %s" % [_shell_quote(WINDOW_PATTERN), _shell_quote(command)]
	return 'o.bind("%s", "Game Hub", "%s")' % [SHORTCUT_KEY, launch.replace("\\", "\\\\").replace('"', '\\"')]


## A linha de EMERGÊNCIA para o ~/.config/hypr/bindings.lua (Fase 14.30): com o
## jogador sentado à mesa, o Hyprland está num submap quase vazio, e esta tecla
## (que vale dentro de qualquer submap) volta tudo ao normal, mesmo se o hub travar.
static func emergency_line() -> String:
	return 'hl.bind("SUPER + SHIFT + ESCAPE", hl.dsp.submap("reset"), { submap_universal = true, description = "Game Hub: sair do submap" })'


## Entre aspas do .desktop: \ " ` $ ganham uma barra, e % vira %%.
static func _desktop_quote(text: String) -> String:
	var out := text.replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`").replace("$", "\\$").replace("%", "%%")
	return '"' + out + '"'


## Entre aspas simples do shell (só se precisar: caminho simples fica como está).
static func _shell_quote(text: String) -> String:
	var plain := RegEx.create_from_string("^[A-Za-z0-9_./:@%+=,-]+$")
	if plain.search(text) != null:
		return text
	return "'" + text.replace("'", "'\\''") + "'"


static func _default_dir() -> String:
	var config_home := OS.get_environment("XDG_CONFIG_HOME")
	if config_home == "":
		config_home = OS.get_environment("HOME").path_join(".config")
	return config_home.path_join("autostart")
