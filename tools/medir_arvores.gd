extends SceneTree
## A MEDIDA das árvores (Fase 19.2; 19.3: o jogo como está, com o TreeModel
## nas floreiras e no bairro do RPG). Rode COM JANELA, à mão, com o PC parado:
##
##   godot --path . -s tools/medir_arvores.gd -- [jogos] [qualidade] [hora] [bairro]
##   (padrão: 200 alta 13 rpg)
##
## Em cada ponto, a câmera dá uma volta de 360° em SPIN_SECONDS e anota o tempo
## de cada quadro, as chamadas de desenho e os triângulos. Os pontos são
## medidos duas vezes ("1" e "2": a segunda mostra quanto a máquina variou).
## Sai uma linha MEDIDA_ARVORES por volta e ponto. O vsync é desligado só aqui.
## Para comparar com as impostoras da 19.2, rode a versão desta ferramenta do
## commit de antes da 19.3 (lá, o modo "hoje").
## Pontos:
##   portico  12 m antes do pórtico, na altura dos olhos
##   dentro   no miolo do bairro, no meio dos pinheiros
##   praca    perto do meio da praça, olhando o bairro

const SPIN_SECONDS: float = 6.0
const WARMUP_FRAMES: int = 90
const EYE_HEIGHT: float = 1.7
const SIZE: Vector2i = Vector2i(1600, 900)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 200
	var quality := String(args[1]) if args.size() > 1 else "alta"
	var hour := float(args[2]) if args.size() > 2 else 13.0
	var district := String(args[3]) if args.size() > 3 else "rpg"
	var config := root.get_node("AppConfig")
	var original_quality: String = config.get_quality()
	config.set_quality(quality)
	if count > 0:
		load("res://tests/fake_library.gd").install(root, count)
	DisplayServer.window_set_size(SIZE)
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	var day_night = city._day_night
	day_night.hour_offset = 0.0
	day_night.hour_offset = hour - day_night.current_hour()
	day_night.update_now()

	var area := {}
	for item: Dictionary in get_first_node_in_group("world_map").get_map_data()["areas"]:
		if item["id"] == district:
			area = item
	if area.is_empty():
		push_error("Bairro %s não existe." % district)
		quit(1)
		return
	# As árvores do jogo: as do bairro (BiomeScatter) e as das floreiras.
	var copies := 0
	for trees: Node in city.find_children("*", "TreeModel", true, false):
		copies += (trees as TreeModel).get_transforms().size()

	var player: Node3D = city.get_node("Player")
	var camera := Camera3D.new()
	camera.fov = (player.get_node("Head/Camera3D") as Camera3D).fov
	camera.far = (player.get_node("Head/Camera3D") as Camera3D).far
	city.add_child(camera)
	camera.make_current()

	var points := _points(area)
	print("MEDIDA_ARVORES_AMBIENTE | %s | %d jogos | %s | %02d h | %d árvores na cidade | %s" % [
			RenderingServer.get_video_adapter_name(), count, quality, int(hour), copies, district])
	for mode in ["1", "2"]:
		for point: Dictionary in points:
			var eye: Vector3 = point["eye"]
			player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(eye.x, 0.1, eye.z)))
			camera.global_transform = Transform3D(Basis.IDENTITY, eye)
			for i in WARMUP_FRAMES:
				camera.rotation.y = TAU * float(i) / WARMUP_FRAMES
				await process_frame
			var frames: Array[float] = []
			var draws := 0
			var primitives := 0
			var started := Time.get_ticks_usec()
			var last := started
			while Time.get_ticks_usec() - started < SPIN_SECONDS * 1000000.0:
				camera.rotation.y = TAU * float(Time.get_ticks_usec() - started) / (SPIN_SECONDS * 1000000.0)
				await process_frame
				var now := Time.get_ticks_usec()
				frames.append((now - last) / 1000.0)
				last = now
				draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			_report(mode, point["name"], frames, draws, primitives)

	DisplayServer.window_set_vsync_mode(vsync)
	config.set_quality(original_quality)
	quit()


func _points(area: Dictionary) -> Array[Dictionary]:
	var gate: Vector2 = area["gate"]
	var rects: Array[Rect2] = area["rects"]
	var middle := Vector2.ZERO
	for rect in rects:
		middle += rect.get_center()
	middle /= rects.size()
	var outward := (gate - middle).normalized()
	var before := gate + outward * 12.0
	var plaza := outward * 6.0
	return [
		{"name": "portico", "eye": Vector3(before.x, EYE_HEIGHT, before.y)},
		{"name": "dentro", "eye": Vector3(middle.x, EYE_HEIGHT, middle.y)},
		{"name": "praca", "eye": Vector3(plaza.x, EYE_HEIGHT, plaza.y)},
	]


func _report(mode: String, point: String, frames: Array[float], draws: int, primitives: int) -> void:
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in frames:
		total += value
	var average := total / frames.size()
	var p99: float = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))]
	print("MEDIDA_ARVORES | %-5s | %-7s | %6.1f FPS | média %5.2f ms | p99 %5.2f ms | %5.0f desenhos | %5.2f M triângulos" % [
			mode, point, 1000.0 / average, average, p99, float(draws) / frames.size(),
			float(primitives) / frames.size() / 1000000.0])
