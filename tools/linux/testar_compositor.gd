extends SceneTree
## Teste manual do compositor (Fase 14): um quadro 3D com um app dentro.
##
## Abre o app (o foot, se nada for dito) dentro do compositor do hub e mostra
## a janela num quadro meio de lado. O teclado, o mouse e a rodinha vão para o app.
## Shift + Esc fecha. Precisa da extensão compilada
## (bash tools/linux/compilar_compositor.sh).
##
## Uso, da raiz do projeto:
##   godot --path . -s res://tools/linux/testar_compositor.gd
##   APP="brave-origin --ozone-platform=wayland --user-data-dir=/tmp/hub-brave" godot --path . -s res://tools/linux/testar_compositor.gd
##
## Não briga com um hub aberto: usa um socket só dele.

const SOCKET := "gamehub-teste-manual"
const QUAD_SIZE := Vector2(1.6, 0.9)

var comp: Node
var window_id: int = -1
var app_pid: int = -1
var quad: MeshInstance3D
var material: StandardMaterial3D
var label: Label


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	comp = AppCompositor.create(SOCKET)
	if comp == null:
		push_error("Sem o compositor: rode bash tools/linux/compilar_compositor.sh")
		quit(1)
		return
	root.add_child(comp)
	comp.connect("window_opened", func(id: int, app_id: String, title: String, pid: int) -> void:
		print("janela aberta: id=%d app_id=%s título=%s pid=%d" % [id, app_id, title, pid])
		if window_id < 0:
			window_id = id
			comp.call("focus", id))
	comp.connect("title_changed", func(id: int, title: String) -> void:
		print("título novo (janela %d): %s" % [id, title]))
	comp.connect("window_closed", func(id: int) -> void:
		print("janela fechada: ", id)
		if id == window_id:
			window_id = -1)

	# A cena: câmera e o quadro (16:9) quase ocupando a tela.
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 1.0)
	world.add_child(cam)
	quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = QUAD_SIZE
	quad.mesh = mesh
	quad.rotation_degrees = Vector3(0, 12, 0)  # um pouco de lado, para parecer 3D
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.1, 0.1, 0.15)
	quad.material_override = material
	world.add_child(quad)
	root.window_input.connect(_on_input)
	label = Label.new()
	label.position = Vector2(10, 10)
	root.add_child(label)

	# O app, com o ambiente que o manda para dentro do compositor.
	var command := OS.get_environment("APP") if OS.has_environment("APP") else "foot"
	var args := AppCompositor.environment(SOCKET)
	args.append_array(command.split(" ", false))
	app_pid = OS.create_process("env", args)
	print("app aberto (pid %d): %s" % [app_pid, command])


func _process(_delta: float) -> bool:
	comp.call("poll")
	var texture: Texture2D = comp.call("get_texture", window_id) if window_id >= 0 else null
	material.albedo_texture = texture  # a textura pode ser trocada (tamanho novo)
	material.albedo_color = Color.WHITE if texture else Color(0.1, 0.1, 0.15)
	label.text = "FPS %d · %s · Shift+Esc fecha" % [Engine.get_frames_per_second(), str(comp.call("stats"))]
	return false


func _finalize() -> void:
	if app_pid > 0:
		OS.kill(app_pid)


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE and key.shift_pressed:
			quit()
			return
		if key.echo or window_id < 0:
			return  # a repetição de tecla é do lado do app
		var code := AppCompositor.evdev_code(key)
		if code < 0:
			print("tecla sem código evdev: física=%d lógica=%s" % [key.physical_keycode, OS.get_keycode_string(key.keycode)])
			return
		comp.call("key", window_id, code, key.pressed)
	elif (event is InputEventMouseMotion or event is InputEventMouseButton) and window_id >= 0:
		var pixel := _mouse_to_pixel((event as InputEventMouse).position)
		if pixel == Vector2.INF:
			comp.call("pointer_leave")
			return
		comp.call("pointer_motion", window_id, pixel.x, pixel.y)
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			var steps := AppCompositor.wheel_steps(button)
			if steps != Vector2.ZERO:
				comp.call("pointer_axis", steps.x, steps.y, true)
			var code := AppCompositor.mouse_button_code(button.button_index)
			if code > 0:
				comp.call("pointer_button", code, button.pressed)


## O raio da câmera pelo mouse até o quadro → pixel da janela do app.
func _mouse_to_pixel(pos: Vector2) -> Vector2:
	var texture: Texture2D = comp.call("get_texture", window_id)
	if texture == null:
		return Vector2.INF
	var cam := root.get_camera_3d()
	var inv := quad.global_transform.affine_inverse()
	var origin := inv * cam.project_ray_origin(pos)
	var dir := inv.basis * cam.project_ray_normal(pos)
	if absf(dir.z) < 0.000001:
		return Vector2.INF
	var hit := origin + dir * (-origin.z / dir.z)
	var uv := Vector2(hit.x / QUAD_SIZE.x + 0.5, 0.5 - hit.y / QUAD_SIZE.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2.INF  # fora do quadro
	return uv * Vector2(texture.get_width(), texture.get_height())
