extends SceneTree
## Teste do peso da câmera (Fase 11.2): balanço, afundada ao pousar, FOV
## correndo, a opção que desliga tudo e a câmera parada durante o foco.
## Guarda o config.cfg antes e devolve no fim.

const CONFIG := "user://config.cfg"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var backup := FileAccess.get_file_as_string(CONFIG)
	await process_frame
	var app = root.get_node("AppConfig")
	app.set_camera_motion(true)

	var camera := Camera3D.new()
	camera.fov = 75.0
	root.add_child(camera)
	var rest := camera.transform
	var feel = load("res://player/camera_feel.gd").new()
	root.add_child(feel)
	feel.setup(camera, rest)
	var delta := 1.0 / 60.0

	print("\n== andando ==")
	var max_y := 0.0
	var min_y := 0.0
	var max_x := 0.0
	var min_x := 0.0
	var stride := 0.0
	for i in 600:
		stride = fmod(stride + 5.0 * delta / 2.2, 1.0)
		feel.update(delta, 5.0, stride, true, false, true)
		var offset: Vector3 = feel.get_offset()
		max_y = maxf(max_y, offset.y)
		min_y = minf(min_y, offset.y)
		max_x = maxf(max_x, offset.x)
		min_x = minf(min_x, offset.x)
	print("   vertical %.3f a %.3f | lateral %.3f a %.3f" % [min_y, max_y, min_x, max_x])
	_check("o deslocamento oscila", max_y - min_y > 0.01 and max_x - min_x > 0.005)
	_check("e fica dentro de ±3 cm", absf(min_y) <= 0.03 and absf(max_y) <= 0.03 and absf(min_x) <= 0.03 and absf(max_x) <= 0.03)
	_check("o lateral troca de lado a cada passo", min_x < -0.002 and max_x > 0.002)
	_check("a câmera acompanha o deslocamento", is_equal_approx(camera.position.y, rest.origin.y + feel.get_offset().y))
	_check("andando, o FOV continua o base", is_equal_approx(camera.fov, 75.0))

	print("\n== parando ==")
	for i in 120:
		feel.update(delta, 0.0, 0.7, true, false, true)
	_check("parado, o deslocamento some", feel.get_offset().length() < 0.002)

	print("\n== pousando ==")
	feel.land(8.0)
	var lowest := 0.0
	for i in 12:
		feel.update(delta, 0.0, 0.7, true, false, true)
		lowest = minf(lowest, feel.get_offset().y)
	print("   mais fundo: %.3f" % lowest)
	_check("afunda até ~5 cm", lowest <= -0.04 and lowest >= -0.0501)
	for i in 30:  # +0,5 s
		feel.update(delta, 0.0, 0.7, true, false, true)
	_check("e volta ao lugar", absf(feel.get_offset().y) < 0.003)
	feel.land(0.5)
	feel.update(delta, 0.0, 0.7, true, false, true)
	_check("queda mansa não afunda", absf(feel.get_offset().y) < 0.001)

	print("\n== correndo ==")
	for i in 120:
		stride = fmod(stride + 9.0 * delta / 3.0, 1.0)
		feel.update(delta, 9.0, stride, true, true, true)
	print("   FOV %.2f" % camera.fov)
	_check("FOV = base + 5", absf(camera.fov - 80.0) < 0.1)
	for i in 120:
		feel.update(delta, 0.0, 0.7, true, false, true)
	_check("parou: o FOV volta ao base", absf(camera.fov - 75.0) < 0.1)

	print("\n== opção desligada ==")
	app.set_camera_motion(false)
	for i in 120:
		stride = fmod(stride + 9.0 * delta / 3.0, 1.0)
		feel.update(delta, 9.0, stride, true, true, true)
	feel.land(8.0)
	feel.update(delta, 9.0, stride, true, true, true)
	_check("deslocamento 0 e FOV base", feel.get_offset() == Vector3.ZERO and is_equal_approx(camera.fov, 75.0)
		and camera.transform == rest)
	app.set_camera_motion(true)

	print("\n== inativo (foco / viagem) ==")
	feel.update(delta, 5.0, 0.5, true, false, true)
	var parked := Transform3D(Basis.IDENTITY, Vector3(3.0, 2.0, 1.0))
	camera.transform = parked
	feel.update(delta, 5.0, 0.5, true, true, false)
	_check("com active = false a câmera não é tocada", camera.transform == parked)
	camera.queue_free()
	feel.queue_free()

	print("\n== no jogador ==")
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(0.5).timeout
	var player = city.get_node("Player")
	var pcam: Camera3D = player.get_node("Head/Camera3D")
	var rest_y: float = player._camera_rest.origin.y
	_check("o jogador tem o CameraFeel", player._camera_feel != null)
	_check("AIR_CONTROL de 0,35", is_equal_approx(player.AIR_CONTROL, 0.35))
	# FOV do config e sensibilidade.
	app.set_fov(90.0)
	await process_frame
	await process_frame
	_check("o FOV base segue o config", is_equal_approx(player._camera_feel.get_base_fov(), 90.0)
		and absf(pcam.fov - 90.0) < 0.1)
	var motion := Vector2(100.0, 0.0)
	var before: float = player.rotation.y
	player.look_by(motion)
	var turn_1: float = player.rotation.y - before
	app.set_mouse_sensitivity(2.0)
	before = player.rotation.y
	player.look_by(motion)
	var turn_2: float = player.rotation.y - before
	print("   giro %.4f -> %.4f" % [turn_1, turn_2])
	_check("o giro dobra com o multiplicador 2,0", absf(turn_1) > 0.0 and absf(turn_2 / turn_1 - 2.0) < 0.01)
	app.set_mouse_sensitivity(1.0)
	app.set_fov(75.0)
	# Foco: a câmera fica onde o _slide_camera a deixou.
	var moved := Transform3D(Basis.IDENTITY, Vector3(10.0, 5.0, 10.0))
	player._focus_screen = city  # só para marcar "em foco"
	pcam.global_transform = moved
	player._focus_leaving = true
	for i in 10:
		await process_frame
	_check("em foco, a câmera não é mexida", pcam.global_transform.origin.is_equal_approx(moved.origin))
	player._focus_screen = null
	player._focus_leaving = false
	player._end_focus()
	_check("fim do foco devolve a câmera ao repouso", is_equal_approx(pcam.position.y, rest_y))

	city.queue_free()
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	_check("config.cfg restaurado", FileAccess.get_file_as_string(CONFIG) == backup)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
