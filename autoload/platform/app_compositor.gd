class_name AppCompositor
extends RefCounted
## AppCompositor: a ÚNICA porta para o compositor Wayland do hub (Fase 14, parte 2).
##
## O compositor é código nativo (Rust, em native/compositor/) que dá à Godot
## a classe HubCompositor: os apps abertos pelo hub desenham as janelas lá
## dentro, e o mundo mostra cada uma num telão.
##
## NÃO é um autoload: as funções são "static" (como o SteamClient).
## Só este arquivo carrega a extensão e cria o nó, sempre pelo nome em texto
## (ClassDB), para o GDScript compilar mesmo sem a extensão (no Windows, ou
## no Linux antes de rodar tools/linux/compilar_compositor.sh). Sem ela,
## is_available() é falso e o hub abre os apps fora, como na parte 1.
##
## Aqui também ficam:
##   - a tradução "tecla da Godot → código evdev do Linux", que é o que o
##     compositor manda para o app;
##   - o layout do teclado do Hyprland (ex.: "br"), para os acentos saírem certos;
##   - o ambiente que faz um app abrir dentro do compositor.

## O nome do socket (fica em $XDG_RUNTIME_DIR/gamehub-0).
const SOCKET := "gamehub-0"
## A extensão e a biblioteca compilada. A pasta native/ tem .gdignore: a Godot
## não carrega nada dela sozinha; quem carrega é _load(), só no Linux.
const EXTENSION_FILE := "res://native/hub_compositor.gdextension"
const LIBRARY_FILE := "res://native/bin/libhub_compositor.so"
const NATIVE_CLASS := "HubCompositor"

## Tecla física da Godot → código evdev (o número da tecla no Linux).
## Vale para o driver Wayland da Godot (o do projeto, em display_server/driver.linuxbsd).
## Os nomes seguem a posição no teclado americano; no ABNT2, por exemplo, o
## "ç" fica no lugar do SEMICOLON e o "~" no do APOSTROPHE. Esquisitices da Godot:
## o "´" e o "[" do ABNT2 vêm como BRACELEFT/BRACERIGHT, o "'" como SECTION e
## o "\" (ao lado do Shift esquerdo) como QUOTELEFT.
const EVDEV: Dictionary = {
	KEY_ESCAPE: 1, KEY_1: 2, KEY_2: 3, KEY_3: 4, KEY_4: 5, KEY_5: 6, KEY_6: 7, KEY_7: 8,
	KEY_8: 9, KEY_9: 10, KEY_0: 11, KEY_MINUS: 12, KEY_EQUAL: 13, KEY_BACKSPACE: 14,
	KEY_TAB: 15, KEY_Q: 16, KEY_W: 17, KEY_E: 18, KEY_R: 19, KEY_T: 20, KEY_Y: 21,
	KEY_U: 22, KEY_I: 23, KEY_O: 24, KEY_P: 25, KEY_BRACELEFT: 26, KEY_BRACERIGHT: 27,
	KEY_ENTER: 28, KEY_CTRL: 29, KEY_A: 30, KEY_S: 31, KEY_D: 32, KEY_F: 33, KEY_G: 34,
	KEY_H: 35, KEY_J: 36, KEY_K: 37, KEY_L: 38, KEY_SEMICOLON: 39, KEY_APOSTROPHE: 40,
	KEY_SECTION: 41, KEY_SHIFT: 42, KEY_BACKSLASH: 43, KEY_Z: 44, KEY_X: 45, KEY_C: 46,
	KEY_V: 47, KEY_B: 48, KEY_N: 49, KEY_M: 50, KEY_COMMA: 51, KEY_PERIOD: 52,
	KEY_SLASH: 53, KEY_KP_MULTIPLY: 55, KEY_ALT: 56, KEY_SPACE: 57, KEY_CAPSLOCK: 58,
	KEY_F1: 59, KEY_F2: 60, KEY_F3: 61, KEY_F4: 62, KEY_F5: 63, KEY_F6: 64, KEY_F7: 65,
	KEY_F8: 66, KEY_F9: 67, KEY_F10: 68, KEY_NUMLOCK: 69, KEY_SCROLLLOCK: 70,
	KEY_KP_7: 71, KEY_KP_8: 72, KEY_KP_9: 73, KEY_KP_SUBTRACT: 74, KEY_KP_4: 75,
	KEY_KP_5: 76, KEY_KP_6: 77, KEY_KP_ADD: 78, KEY_KP_1: 79, KEY_KP_2: 80, KEY_KP_3: 81,
	KEY_KP_0: 82, KEY_KP_PERIOD: 83, KEY_QUOTELEFT: 86, KEY_F11: 87, KEY_F12: 88,
	KEY_KP_ENTER: 96, KEY_KP_DIVIDE: 98, KEY_PRINT: 99, KEY_HOME: 102, KEY_UP: 103,
	KEY_PAGEUP: 104, KEY_LEFT: 105, KEY_RIGHT: 106, KEY_END: 107, KEY_DOWN: 108,
	KEY_PAGEDOWN: 109, KEY_INSERT: 110, KEY_DELETE: 111, KEY_PAUSE: 119, KEY_YEN: 124,
	KEY_META: 125, KEY_MENU: 127,
}
## As teclas que existem dos dois lados: o lado direito tem outro código.
## O Alt da direita é o AltGr (no ABNT2, AltGr + Q dá "/").
const EVDEV_RIGHT: Dictionary = {KEY_CTRL: 97, KEY_SHIFT: 54, KEY_ALT: 100, KEY_META: 126}
## A tecla "/?" do ABNT2 (ao lado do Shift direito). A Godot não dá código
## físico para ela, então ela é reconhecida pela letra que produz.
const EVDEV_ABNT2_SLASH := 89

## Botão do mouse da Godot → código do Linux.
const MOUSE_BUTTONS: Dictionary = {
	MOUSE_BUTTON_LEFT: 0x110, MOUSE_BUTTON_RIGHT: 0x111, MOUSE_BUTTON_MIDDLE: 0x112,
	MOUSE_BUTTON_XBUTTON1: 0x113, MOUSE_BUTTON_XBUTTON2: 0x114,
}

## -1: ainda não testou; 0: sem a extensão; 1: pronta.
static var _state: int = -1


## A extensão está compilada e carregou? (Sempre falso fora do Linux.)
static func is_available() -> bool:
	if _state < 0:
		_state = 1 if _load(EXTENSION_FILE, LIBRARY_FILE) else 0
		if _state == 0 and OS.get_name() == "Linux":
			print("AppCompositor: extensão não compilada (bash tools/linux/compilar_compositor.sh); os apps abrem fora do hub.")
	return _state == 1


## Um compositor novo, já ligado no socket e com o layout do teclado do
## Hyprland, ou null (sem a extensão, ou se o socket não abrir). Quem cria
## põe o nó na árvore e chama poll() a cada quadro; ao sair da árvore, ele
## desliga sozinho. Se não for para a árvore, chame free().
static func create(socket: String = SOCKET) -> Node:
	if not is_available():
		return null
	var node := ClassDB.instantiate(NATIVE_CLASS) as Node
	if node == null:
		return null
	var keyboard := keyboard_layout()
	if not node.call("start", socket, keyboard.layout, keyboard.variant):
		node.free()
		return null
	return node


## O ambiente para um app abrir dentro do compositor (no formato do comando
## "env": opções "-u NOME" e depois "NOME=valor"). O DISPLAY (X11) fica como
## está: um app que só fala X11 abre fora, no Hyprland, e o fluxo da parte 1 cuida dele.
##
## Fase 14.30, para os scripts do Omarchy abrirem DENTRO:
##   - sem o HYPRLAND_INSTANCE_SIGNATURE, o hyprctl de dentro não acha o
##     Hyprland de fora (o launch-or-focus não acha "a janela já aberta lá");
##   - os "calços" (uwsm-app, systemd-run, brave-origin) vêm primeiro no PATH.
##     O uwsm-app e o systemd-run de verdade abrem o app numa unidade do systemd,
##     com o ambiente de FORA, e a janela apareceria lá. O brave-origin de dentro
##     usa o perfil só do hub (veja SHIMS).
static func environment(socket: String = SOCKET) -> PackedStringArray:
	var env := PackedStringArray(["-u", "HYPRLAND_INSTANCE_SIGNATURE"])
	env.append_array([
		"WAYLAND_DISPLAY=" + socket,
		"GDK_BACKEND=wayland",
		"QT_QPA_PLATFORM=wayland",
		"SDL_VIDEODRIVER=wayland",
	])
	var shims := ensure_shims()
	if not shims.is_empty():
		env.append("PATH=%s:%s" % [shims, OS.get_environment("PATH")])
		env.append("HUB_BRAVE_PROFILE=" + ProjectSettings.globalize_path("user://apps/brave"))
	return env


## O Quickshell do Omarchy (a barra, o fundo, o menu e as notificações) como
## aplicativo DE DENTRO do hub (Fase 14.31). A pasta do shell fica em
## $OMARCHY_PATH/shell (padrão /usr/share/omarchy/shell). Devolve os argumentos
## do comando (programa e opções), ou vazio se o Quickshell ou o shell do Omarchy
## não estão instalados (o hub segue sem barra).
static func shell_arguments(omarchy_dir: String = "") -> PackedStringArray:
	if omarchy_dir.is_empty():
		omarchy_dir = OS.get_environment("OMARCHY_PATH")
	if omarchy_dir.is_empty():
		omarchy_dir = "/usr/share/omarchy"
	var shell_dir := omarchy_dir.path_join("shell")
	if not DirAccess.dir_exists_absolute(shell_dir) or not FileAccess.file_exists(shell_dir.path_join("shell.qml")):
		return PackedStringArray()
	var found: Array = []
	if OS.execute("sh", PackedStringArray(["-c", "command -v quickshell"]), found) != 0:
		return PackedStringArray()
	return PackedStringArray([str(found[0]).strip_edges(), "-n", "-p", shell_dir])


## Sobe o Quickshell do Omarchy dentro do compositor. Devolve o número do
## processo, ou -1 se não deu (ou não há Quickshell). Só o AppSessions chama, e
## só uma vez por compositor.
##   - QT_QUICK_BACKEND=software: o compositor só aceita memória compartilhada (shm);
##   - os serviços repetidos (polkit, notificações, idle) falham sem estrago:
##     o de fora segue com o trabalho.
static func start_shell(socket: String = SOCKET) -> int:
	var command := shell_arguments()
	if command.is_empty():
		return -1
	var args := environment(socket)
	args.append("QT_QUICK_BACKEND=software")
	args.append_array(command)
	var pid := OS.create_process("env", args)
	return pid if pid > 0 else -1


## Abre um comando de shell (ex.: "omarchy-launch-terminal") DENTRO do hub, com o
## ambiente de dentro. Devolve true se o processo começou.
static func run_command(command: String, socket: String = SOCKET) -> bool:
	var args := environment(socket)
	args.append_array(["bash", "-c", command])
	return OS.create_process("env", args) > 0


## Os calços, por nome do arquivo. Nasceram no spike da 14.24: cada um só roda o
## comando, sem a unidade do systemd que levaria o app para fora do hub.
const SHIMS: Dictionary = {
	"uwsm-app": """#!/bin/bash
# Calço do hub (Fase 14.30): o uwsm-app de verdade abre o app numa unidade do
# systemd, que nasce com o ambiente da sessão (o Hyprland de fora). Dentro do
# hub, o app tem de herdar o ambiente de dentro: este calço só roda o comando.
#   uwsm-app [opções] -- comando [args]   ou   uwsm-app comando [args]
args=("$@")
for i in "${!args[@]}"; do
	if [[ ${args[$i]} == "--" ]]; then
		exec "${args[@]:$((i + 1))}"
	fi
done
# Sem "--": pula as opções (-s b, -t service, -a nome, -u unidade, -d desc, -T, -S...).
while [[ $# -gt 0 && $1 == -* ]]; do
	case $1 in
	-[stadu]) shift 2 ;;
	*) shift ;;
	esac
done
exec "$@"
""",
	"systemd-run": """#!/bin/bash
# Calço do hub (Fase 14.30): o systemd-run --user abre o comando fora do hub
# (sem o WAYLAND_DISPLAY de dentro). Aqui ele só pula as opções e roda o comando.
while [[ $# -gt 0 ]]; do
	case $1 in
	--) shift; break ;;
	# opções com o valor separado (as com "=" caem no -* abaixo)
	-p | -E | -M | -H | -u | --property | --setenv | --unit | --slice | --description | --working-directory | --uid | --gid | --nice | --machine | --host)
		shift 2 ;;
	-*) shift ;;
	*) break ;;
	esac
done
exec "$@"
""",
	"brave-origin": """#!/bin/bash
# Calço do hub (Fase 14.30): o Brave de dentro usa um perfil só do hub. Sem isso,
# ele acha o Brave de fora aberto e abre a janela lá ("existing browser session").
# O hub põe o perfil em HUB_BRAVE_PROFILE (o mesmo da 14.21: user://apps/brave).
profile=${HUB_BRAVE_PROFILE:-${XDG_RUNTIME_DIR:-/tmp}/gamehub-brave}
exec /usr/bin/brave-origin --user-data-dir="$profile" --ozone-platform=wayland "$@"
""",
}


## Garante os calços em user://shims/ (cria ou atualiza, executáveis) e devolve a
## pasta, ou "" se não deu para criar. Só no Linux.
static func ensure_shims(dir: String = "user://shims") -> String:
	if OS.get_name() != "Linux":
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	for shim_name: String in SHIMS:
		var path := dir.path_join(shim_name)
		if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == SHIMS[shim_name]:
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return ""
		file.store_string(SHIMS[shim_name])
		file.close()
		FileAccess.set_unix_permissions(path, 0x1ED)  # rwxr-xr-x (0755)
	return ProjectSettings.globalize_path(dir)


## O código evdev da tecla do evento, ou -1 se a tecla não tiver tradução.
static func evdev_code(event: InputEventKey) -> int:
	return evdev_for_key(event.physical_keycode, event.location, event.keycode)


## A tradução em si (separada para o teste): a tecla física, o lado
## (esquerdo/direito) e a tecla "lógica" (a letra que ela produz no layout).
static func evdev_for_key(physical: Key, location: KeyLocation, logical: Key) -> int:
	if location == KEY_LOCATION_RIGHT and EVDEV_RIGHT.has(physical):
		return EVDEV_RIGHT[physical]
	if physical == KEY_NONE:
		return EVDEV_ABNT2_SLASH if logical in [KEY_SLASH, KEY_QUESTION] else -1
	return EVDEV.get(physical, -1)


## O código do Linux para o botão do mouse, ou -1 (ex.: a rodinha, que é "rolar").
static func mouse_button_code(button: MouseButton) -> int:
	return MOUSE_BUTTONS.get(button, -1)


## Quanto a rodinha rolou, em "dentes" (positivo: para baixo / para a direita),
## para o pointer_axis do compositor. Vector2.ZERO se o evento não for de rolar.
static func wheel_steps(event: InputEventMouseButton) -> Vector2:
	if not event.pressed:
		return Vector2.ZERO  # a Godot manda "apertou" e "soltou" para cada dente
	# Alguns mouses e touchpads mandam frações de dente no "factor" (0 = um dente).
	var amount := event.factor if event.factor > 0.0 else 1.0
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			return Vector2(0, -amount)
		MOUSE_BUTTON_WHEEL_DOWN:
			return Vector2(0, amount)
		MOUSE_BUTTON_WHEEL_LEFT:
			return Vector2(-amount, 0)
		MOUSE_BUTTON_WHEEL_RIGHT:
			return Vector2(amount, 0)
	return Vector2.ZERO


## O layout do teclado do Hyprland: {"layout": "br", "variant": ""}.
## Sem Hyprland (ou sem resposta), fica o americano ("us").
static func keyboard_layout() -> Dictionary:
	return parse_keyboard_layout(_hyprctl_option("input:kb_layout"), _hyprctl_option("input:kb_variant"))


## Lê as respostas do "hyprctl getoption ... -j" (separado para o teste).
## Com vários layouts ("br,us"), vale o primeiro.
static func parse_keyboard_layout(layout_json: String, variant_json: String) -> Dictionary:
	var layout := _option_text(layout_json).get_slice(",", 0).strip_edges()
	var variant := _option_text(variant_json).get_slice(",", 0).strip_edges()
	if layout.is_empty():
		return {"layout": "us", "variant": ""}
	return {"layout": layout, "variant": variant}


## Carrega a extensão (separado para o teste, que passa caminhos que não existem).
static func _load(extension_file: String, library_file: String) -> bool:
	if OS.get_name() != "Linux":
		return false
	if ClassDB.class_exists(NATIVE_CLASS):
		return true
	if not FileAccess.file_exists(extension_file) or not FileAccess.file_exists(library_file):
		return false
	var status := GDExtensionManager.load_extension(extension_file)
	if status != GDExtensionManager.LOAD_STATUS_OK and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		push_warning("AppCompositor: a extensão não carregou (status %d); os apps abrem fora do hub." % status)
		return false
	return ClassDB.class_exists(NATIVE_CLASS)


static func _hyprctl_option(option: String) -> String:
	var output: Array = []
	if OS.execute("hyprctl", ["getoption", option, "-j"], output) != 0 or output.is_empty():
		return ""
	return str(output[0])


## O campo "str" da resposta JSON do hyprctl ("" se não der para ler).
static func _option_text(json_text: String) -> String:
	# JSON.new().parse() não enche o log de erro quando a resposta é estranha.
	var json := JSON.new()
	if json.parse(json_text) != OK or not json.data is Dictionary:
		return ""
	return str((json.data as Dictionary).get("str", ""))
