extends SceneTree
## Spike 14.14: liga o compositor, abre o foot dentro dele, salva a imagem,
## digita "echo ação" + Enter (teclas evdev do ABNT2) e salva de novo.

const SOCKET := "gamehub-spike"
# evdev: e c h o espaço a ç (~ a) o Enter. No ABNT2, o ç fica no lugar do ";"
# (39) e o til morto no lugar do "'" (40).
const TECLAS: Array[int] = [18, 46, 35, 24, 57, 30, 39, 40, 30, 24, 28]

var comp: Node
var janela: int = -1
var pid_app: int = -1
var quadros: int = 0
var fase: int = 0
var espera: int = 0
var saida: String = ""


func _initialize() -> void:
	saida = OS.get_environment("SAIDA")
	print("HubCompositor existe? ", ClassDB.class_exists("HubCompositor"))
	comp = ClassDB.instantiate("HubCompositor")
	root.add_child(comp)
	var ok: bool = comp.start(SOCKET, "br", 1280, 720)
	print("start: ", ok)
	comp.window_opened.connect(_on_opened)
	comp.window_closed.connect(func(id: int) -> void: print("janela fechou: ", id))
	var cmd := OS.get_environment("APP")
	if cmd.is_empty():
		cmd = "foot"
	var args := PackedStringArray(["WAYLAND_DISPLAY=" + SOCKET, "GDK_BACKEND=wayland"])
	args.append_array(cmd.split(" "))
	pid_app = OS.create_process("env", args)
	print("app aberto, pid ", pid_app, ": ", cmd)


func _on_opened(id: int, app_id: String, title: String, pid: int) -> void:
	print("janela aberta: id=%d app_id=%s titulo=%s pid=%d" % [id, app_id, title, pid])
	if janela < 0:
		janela = id


func _process(_delta: float) -> bool:
	comp.poll()
	quadros += 1
	if quadros > 60 * 40:
		print("tempo esgotado")
		return _fim()
	if janela < 0:
		return false
	espera += 1
	match fase:
		0:
			if espera > int(OS.get_environment("ESPERA") if OS.has_environment("ESPERA") else "90"):
				_salva("antes")
				fase = 1
				espera = 0
		1:
			if espera % 4 == 0:
				var i := espera / 4 - 1
				if i < TECLAS.size():
					comp.key(janela, TECLAS[i], true)
					comp.key(janela, TECLAS[i], false)
				elif espera > TECLAS.size() * 4 + 60:
					_salva("depois")
					fase = 2
		2:
			print("estatisticas: ", comp.stats())
			return _fim()
	return false


func _salva(nome: String) -> void:
	var img: Image = comp.get_image(janela)
	if img == null:
		print("sem imagem")
		return
	var caminho := saida.path_join(nome + ".png")
	img.save_png(caminho)
	print("salvo ", caminho, " (", img.get_width(), "x", img.get_height(), ")")


func _fim() -> bool:
	if pid_app > 0:
		OS.kill(pid_app)
	comp.stop()
	return true
