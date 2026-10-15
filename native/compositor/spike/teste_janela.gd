extends SceneTree
## Spike 14.14, com janela: um quadro 3D mostrando o app que roda dentro do
## compositor. MODO=medida: mede 15 s e sai. MODO=livre: o dono digita e
## clica no quadro; Esc fecha.

const SOCKET := "gamehub-spike"

## Tecla física da Godot → código evdev do Linux (semente da tabela da 14.15).
const EVDEV := {
	KEY_ESCAPE: 1, KEY_1: 2, KEY_2: 3, KEY_3: 4, KEY_4: 5, KEY_5: 6, KEY_6: 7, KEY_7: 8,
	KEY_8: 9, KEY_9: 10, KEY_0: 11, KEY_MINUS: 12, KEY_EQUAL: 13, KEY_BACKSPACE: 14,
	KEY_TAB: 15, KEY_Q: 16, KEY_W: 17, KEY_E: 18, KEY_R: 19, KEY_T: 20, KEY_Y: 21,
	KEY_U: 22, KEY_I: 23, KEY_O: 24, KEY_P: 25, KEY_BRACKETLEFT: 26, KEY_BRACKETRIGHT: 27,
	KEY_ENTER: 28, KEY_CTRL: 29, KEY_A: 30, KEY_S: 31, KEY_D: 32, KEY_F: 33, KEY_G: 34,
	KEY_H: 35, KEY_J: 36, KEY_K: 37, KEY_L: 38, KEY_SEMICOLON: 39, KEY_APOSTROPHE: 40,
	KEY_QUOTELEFT: 41, KEY_SHIFT: 42, KEY_BACKSLASH: 43, KEY_Z: 44, KEY_X: 45, KEY_C: 46,
	KEY_V: 47, KEY_B: 48, KEY_N: 49, KEY_M: 50, KEY_COMMA: 51, KEY_PERIOD: 52,
	KEY_SLASH: 53, KEY_ALT: 56, KEY_SPACE: 57, KEY_CAPSLOCK: 58,
	KEY_F1: 59, KEY_F2: 60, KEY_F3: 61, KEY_F4: 62, KEY_F5: 63, KEY_F6: 64, KEY_F7: 65,
	KEY_F8: 66, KEY_F9: 67, KEY_F10: 68, KEY_F11: 87, KEY_F12: 88,
	KEY_HOME: 102, KEY_UP: 103, KEY_PAGEUP: 104, KEY_LEFT: 105, KEY_RIGHT: 106,
	KEY_END: 107, KEY_DOWN: 108, KEY_PAGEDOWN: 109, KEY_INSERT: 110, KEY_DELETE: 111,
	KEY_KP_ENTER: 96,
}

var comp: Node
var janela: int = -1
var pid_app: int = -1
var quad: MeshInstance3D
var material: StandardMaterial3D
var tempo: float = 0.0
var quadros: int = 0
var pior_ms: float = 0.0
var modo: String = "livre"
var rotulo: Label


func _initialize() -> void:
	modo = OS.get_environment("MODO") if OS.has_environment("MODO") else "livre"
	root.size = Vector2i(1280, 720)
	comp = ClassDB.instantiate("HubCompositor")
	root.add_child(comp)
	comp.start(SOCKET, "br", 1280, 720)
	comp.window_opened.connect(func(id: int, app_id: String, _t: String, _p: int) -> void:
		print("janela aberta: ", app_id)
		if janela < 0:
			janela = id)
	comp.window_closed.connect(func(id: int) -> void:
		if id == janela:
			janela = -1)

	# A cena: luz, câmera e o quadro (16:9) ocupando quase a tela toda.
	var mundo := Node3D.new()
	root.add_child(mundo)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 1.0)
	mundo.add_child(cam)
	quad = MeshInstance3D.new()
	var malha := QuadMesh.new()
	malha.size = Vector2(1.6, 0.9)
	quad.mesh = malha
	quad.rotation_degrees = Vector3(0, 12, 0)  # um pouco de lado, para parecer 3D
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.1, 0.1, 0.15)
	quad.material_override = material
	mundo.add_child(quad)
	root.window_input.connect(_input_evento)
	rotulo = Label.new()
	rotulo.position = Vector2(10, 10)
	root.add_child(rotulo)

	var cmd := OS.get_environment("APP") if OS.has_environment("APP") else "foot"
	var args := PackedStringArray(["WAYLAND_DISPLAY=" + SOCKET, "GDK_BACKEND=wayland"])
	args.append_array(cmd.split(" "))
	pid_app = OS.create_process("env", args)


func _process(delta: float) -> bool:
	var t0 := Time.get_ticks_usec()
	comp.poll()
	var gasto_ms := (Time.get_ticks_usec() - t0) / 1000.0
	if janela >= 0 and material.albedo_texture == null:
		material.albedo_texture = comp.get_texture(janela)
		material.albedo_color = Color.WHITE
	elif janela >= 0:
		material.albedo_texture = comp.get_texture(janela)  # a textura pode ter sido recriada (tamanho novo)
	tempo += delta
	if tempo > 2.0:  # os 2 primeiros segundos são de abertura
		quadros += 1
		pior_ms = maxf(pior_ms, delta * 1000.0)
	rotulo.text = "FPS %d · poll %.1f ms · %s" % [Engine.get_frames_per_second(), gasto_ms, str(comp.stats())]
	if modo == "medida" and tempo > 17.0:
		print("medida: %.1f FPS médios, pior quadro %.1f ms, %s" % [quadros / (tempo - 2.0), pior_ms, str(comp.stats())])
		return _fim()
	return false


func _fim() -> bool:
	if pid_app > 0:
		OS.kill(pid_app)
	comp.stop()
	return true


# --- Entrada: tudo vai para o app; Esc com Shift fecha o spike. ---
func _input_evento(event: InputEvent) -> void:
	if janela < 0:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE and k.shift_pressed:
			quit()
			return
		if k.echo:
			return  # a repetição é do lado do app
		var codigo: int = EVDEV.get(k.physical_keycode, -1)
		if codigo < 0:
			print("tecla sem código evdev: physical=", k.physical_keycode, " (", OS.get_keycode_string(k.physical_keycode), ")")
			return
		comp.key(janela, codigo, k.pressed)
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		var pixel := _pixel_do_mouse((event as InputEventMouse).position)
		if pixel == Vector2.INF:
			return
		comp.pointer_motion(janela, pixel.x, pixel.y)
		if event is InputEventMouseButton:
			var b := event as InputEventMouseButton
			var codigo: int = {MOUSE_BUTTON_LEFT: 0x110, MOUSE_BUTTON_RIGHT: 0x111, MOUSE_BUTTON_MIDDLE: 0x112}.get(b.button_index, -1)
			if codigo > 0:
				comp.pointer_button(codigo, b.pressed)


## O raio da câmera pelo mouse, até o quadro → pixel da janela do app.
func _pixel_do_mouse(pos: Vector2) -> Vector2:
	var cam := root.get_camera_3d()
	var inv := quad.global_transform.affine_inverse()
	var o := inv * cam.project_ray_origin(pos)
	var d := inv.basis * cam.project_ray_normal(pos)
	if absf(d.z) < 0.000001:
		return Vector2.INF
	var hit := o + d * (-o.z / d.z)
	var uv := Vector2(hit.x / 1.6 + 0.5, 0.5 - hit.y / 0.9)
	var tex: Texture2D = comp.get_texture(janela)
	if tex == null:
		return Vector2.INF
	return uv * Vector2(tex.get_width(), tex.get_height())
