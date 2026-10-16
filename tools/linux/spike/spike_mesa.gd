extends SceneTree
## SPIKE 14.24 (só na branch do spike): roda comandos dentro do compositor, sem
## janela, e salva a imagem de cada janela e camada num PNG.
##
## Serve para as perguntas (b) e (c) do spike: os scripts do Omarchy abrem
## dentro, com os calços? O Quickshell desenha a barra e o menu aqui dentro?
##
## Uso, da raiz do projeto:
##   CMDS="omarchy-launch-terminal;;omarchy-launch-browser" OUT=/tmp/pasta \
##     godot --headless --path . -s res://tools/linux/spike/spike_mesa.gd
## CMDS: comandos separados por ";;" (cada um roda num bash, com o ambiente de dentro).
## TEMPO: segundos até salvar e sair (padrão 10). DEPOIS: comandos rodados na metade do tempo.

const SOCKET := "gamehub-spike"

var comp: Node
var out_dir := ""
var deadline := 0.0
var later: PackedStringArray = []
var later_done := false
var started := 0.0
var names := {}


func _initialize() -> void:
	comp = AppCompositor.create(SOCKET)
	if comp == null:
		push_error("Sem o compositor: rode bash tools/linux/compilar_compositor.sh")
		quit(1)
		return
	root.add_child(comp)
	comp.connect("window_opened", func(id: int, app_id: String, title: String, pid: int) -> void:
		names[id] = app_id
		print("[%.1fs] aberta: id=%d app_id=%s título=%s pid=%d" % [_t(), id, app_id, title, pid]))
	comp.connect("window_closed", func(id: int) -> void:
		print("[%.1fs] fechada: id=%d (%s)" % [_t(), id, names.get(id, "?")]))
	comp.connect("title_changed", func(id: int, title: String) -> void:
		print("[%.1fs] título (%d): %s" % [_t(), id, title]))
	out_dir = OS.get_environment("OUT") if OS.has_environment("OUT") else OS.get_user_data_dir()
	var seconds := float(OS.get_environment("TEMPO")) if OS.has_environment("TEMPO") else 10.0
	started = Time.get_ticks_msec() / 1000.0
	deadline = started + seconds
	later = OS.get_environment("DEPOIS").split(";;", false)
	for command in OS.get_environment("CMDS").split(";;", false):
		launch(command)


func _t() -> float:
	return Time.get_ticks_msec() / 1000.0 - started


## O ambiente de dentro: o do compositor, os calços no começo do PATH e sem o
## HYPRLAND_INSTANCE_SIGNATURE (o hyprctl de dentro não acha o Hyprland de fora).
static func inner_env() -> PackedStringArray:
	var calcos := ProjectSettings.globalize_path("res://tools/linux/spike/calcos")
	var env := PackedStringArray(["-u", "HYPRLAND_INSTANCE_SIGNATURE"])
	env.append_array(AppCompositor.environment(SOCKET))
	env.append("PATH=%s:%s" % [calcos, OS.get_environment("PATH")])
	env.append("QT_QUICK_BACKEND=software")
	env.append("HUB_BRAVE_PROFILE=" + OS.get_environment("HUB_BRAVE_PROFILE") if OS.has_environment("HUB_BRAVE_PROFILE") \
			else "HUB_BRAVE_PROFILE=" + ProjectSettings.globalize_path("user://apps/brave"))
	return env


func launch(command: String) -> void:
	var args := inner_env()
	args.append_array(["bash", "-c", command])
	var pid := OS.create_process("env", args)
	print("[%.1fs] rodando (pid %d): %s" % [_t(), pid, command])


func _process(_delta: float) -> bool:
	comp.call("poll")
	var now := Time.get_ticks_msec() / 1000.0
	if not later_done and now > (started + deadline) / 2.0:
		later_done = true
		for command in later:
			launch(command)
	if now < deadline:
		return false
	for id: int in names:
		var image: Image = comp.call("get_image", id)
		if image:
			var path := out_dir.path_join("janela_%d_%s.png" % [id, str(names[id]).replace(":", "_").replace("/", "_")])
			image.save_png(path)
			print("salva: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
		else:
			print("sem imagem: id=%d (%s)" % [id, names[id]])
	print("stats: ", comp.call("stats"))
	return true
