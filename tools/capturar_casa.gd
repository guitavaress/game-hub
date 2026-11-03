extends SceneTree
## Tira as CAPTURAS da casa por pontos (Fase 17.1b). Rode COM JANELA:
##
##   godot --path . -s tools/capturar_casa.gd -- <pasta> [jogos] [horas] [qualidade] [tema]
##
##   pasta      onde salvar os PNG. SEMPRE fora do repositório (as capturas
##              mostram capas de jogos, e o repositório é público)
##   jogos      0 = biblioteca de verdade; N = N jogos falsos (padrão: 200)
##   horas      lista separada por vírgula, de 0 a 24 (padrão: 13,22)
##   qualidade  leve | media | alta (padrão: alta). A do usuário volta no fim.
##   tema       loft | cabana (padrão: loft). O do usuário volta no fim.
##
## Pontos (um PNG por ponto e hora, ex.: loft_nascer_22h.png):
##   nascer   posição e giro de nascer da disposição atual
##   janela   de frente, a cerca de 3 m, com o janelão inteiro
##   sofa     do meio da sala para o canto de estar do tema
##   estante  de frente para as capas, na âncora da disposição atual
##
## Para montar uma amostra sem mexer no jogo, estenda este script
## (extends "res://tools/capturar_casa.gd"), monte-a em _prepare(city, home)
## e sobrescreva _points(home) se quiser mais pontos.

const SIZE: Vector2i = Vector2i(1600, 900)
const EYE_HEIGHT: float = 1.7
## Capas, sombras e exposição assentam depois de cada troca de hora ou lugar.
const SETTLE_FRAMES: int = 90

var _original_settings: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Uso: -s tools/capturar_casa.gd -- <pasta> [jogos] [horas] [qualidade] [tema]")
		quit(1)
		return
	var folder: String = _absolute_folder(String(args[0]))
	var count: int = int(args[1]) if args.size() > 1 else 200
	var hours: Array[float] = []
	for value: String in (String(args[2]) if args.size() > 2 else "13,22").split(","):
		if not value.is_valid_float() or float(value) < 0.0 or float(value) > 24.0:
			push_error("As horas devem ficar entre 0 e 24.")
			quit(1)
			return
		hours.append(float(value))
	var quality: String = String(args[3]) if args.size() > 3 else "alta"
	var theme: String = String(args[4]) if args.size() > 4 else "loft"
	if not _folder_allowed(folder):
		push_error("A pasta das capturas não pode ficar dentro do repositório.")
		quit(1)
		return
	if count < 0 or quality not in ["leve", "media", "alta"] or theme not in ["loft", "cabana"]:
		push_error("Use jogos >= 0, qualidade leve|media|alta e tema loft|cabana.")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("As capturas precisam de janela (sem --headless).")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("Não consegui criar a pasta das capturas.")
		quit(1)
		return

	_choose_settings(quality, theme)
	if count > 0:
		var library_script: GDScript = load("res://tests/fake_library.gd")
		library_script.install(root, count)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.set("play_intro", false)
	root.add_child(city)
	print("montando a cidade e a casa...")
	while not city.call("is_city_ready"):
		await process_frame
	var home: Node3D = city.call("get_home")
	var player: Node3D = city.get_node("Player")
	var player_camera: Camera3D = player.get_node("Head/Camera3D")
	DisplayServer.window_set_size(SIZE)
	# Quadro próprio: mantém 1600x900 mesmo se o SO limitar a janela; sem HUD.
	var frame: SubViewport = SubViewport.new()
	frame.size = SIZE
	frame.world_3d = root.world_3d
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	load("res://autoload/graphics_quality.gd").apply_to_viewport(frame, quality)
	root.add_child(frame)
	var camera: Camera3D = Camera3D.new()
	camera.fov = player_camera.fov
	camera.far = player_camera.far
	camera.environment = home.call("get_environment")
	frame.add_child(camera)
	camera.make_current()
	# A gêmea na janela também enxerga o ambiente de dentro da casa.
	var twin: Camera3D = Camera3D.new()
	twin.fov = camera.fov
	twin.far = camera.far
	twin.environment = camera.environment
	city.add_child(twin)
	twin.make_current()
	_prepare(city, home)
	var day_night: Node = city.get("_day_night")
	var points: Array[Dictionary] = _points(home)
	var failed: bool = false
	for hour: float in hours:
		_set_hour(day_night, hour)
		for point: Dictionary in points:
			var eye: Vector3 = point["eye"]
			var target: Vector3 = point["target"]
			var spawn: Transform3D = home.call("get_spawn_transform")
			var feet: Vector3 = eye - home.global_basis.y * (EYE_HEIGHT - home.to_local(spawn.origin).y)
			player.call("teleport_to", Transform3D(spawn.basis, feet))
			player.call("set_indoors", camera.environment)
			camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(target, home.global_basis.y)
			twin.global_transform = camera.global_transform
			for i: int in SETTLE_FRAMES:
				await process_frame
			await RenderingServer.frame_post_draw
			var file: String = "%s/%s_%s_%02dh.png" % [folder, theme, point["name"], int(hour)]
			if frame.get_texture().get_image().save_png(file) != OK:
				push_error("Não consegui salvar: " + file)
				failed = true
			else:
				print("Captura: ", file)
	_restore_settings()
	quit(1 if failed else 0)


## Guarda as escolhas antes da amostra; a restauração serve também aos testes.
func _choose_settings(quality: String, theme: String) -> void:
	var config: Node = root.get_node("AppConfig")
	_original_settings = {"quality": config.call("get_quality"), "theme": config.call("get_home_theme")}
	config.call("set_quality", quality)
	config.call("set_home_theme", theme)


func _restore_settings() -> void:
	if _original_settings.is_empty():
		return
	var config: Node = root.get_node("AppConfig")
	config.call("set_quality", _original_settings["quality"])
	config.call("set_home_theme", _original_settings["theme"])
	_original_settings.clear()


## Compara caminhos absolutos normalizados, incluindo a própria raiz e ../.
func _folder_allowed(folder: String) -> bool:
	var path: String = _absolute_folder(folder).trim_suffix("/")
	var repo: String = ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/")
	if OS.get_name() == "Windows":
		path = path.to_lower()
		repo = repo.to_lower()
	return path != repo and not path.begins_with(repo + "/")


func _absolute_folder(folder: String) -> String:
	var path: String = ProjectSettings.globalize_path(folder).replace("\\", "/")
	if not path.is_absolute_path():
		path = ProjectSettings.globalize_path("res://").path_join(path)
	return path.simplify_path()


## Ponto de extensão para montar uma amostra antes das fotos.
func _prepare(_city: Node, _home: Node3D) -> void:
	pass


## Coordenadas no mundo, calculadas da casa e dos móveis já posicionados.
func _points(home: Node3D) -> Array[Dictionary]:
	var room: Vector3 = home.get("ROOM_SIZE")
	var spawn: Transform3D = home.call("get_spawn_transform")
	var eye: Vector3 = spawn.origin + home.global_basis.y * (EYE_HEIGHT - home.to_local(spawn.origin).y)
	var points: Array[Dictionary] = [{"name": "nascer", "eye": eye, "target": eye - spawn.basis.z}]
	var window: Vector3 = Vector3(0.0, float(home.get("WINDOW_CENTER_Y")), -room.z / 2.0)
	# Um terço da profundidade atual dá 3 m e enquadra toda a janela.
	points.append({"name": "janela", "eye": home.to_global(window + Vector3.BACK * (room.z / 3.0)),
		"target": home.to_global(window + Vector3.BACK * float(home.get("WALL_THICKNESS")))})
	# A geometria do tema fornece o destino: sofá no loft; poltronas na cabana.
	var seating: Vector3 = Vector3.ZERO
	for child: Node in home.get_children():
		if child is Node3D and (child.name == &"SofaSeat" or child.get_meta("cabin_piece", "") == "poltrona"):
			seating = (child as Node3D).position
			break
	points.append({"name": "sofa", "eye": home.to_global(Vector3(room.x / 6.0, EYE_HEIGHT, 0.0)),
		"target": home.to_global(seating)})
	var shelf: Node3D = home.call("get_furniture", "estante")
	# +Z é a frente da estante; a âncora já inclui o giro da disposição.
	var shelf_eye: Vector3 = shelf.to_global(Vector3(0.0, EYE_HEIGHT, room.z / 3.0))
	# Nas âncoras de canto, limita o olho ao interior sem mudar a frente.
	var local_eye: Vector3 = home.to_local(shelf_eye)
	local_eye.x = clampf(local_eye.x, -room.x / 2.0 + float(home.get("WALL_THICKNESS")), room.x / 2.0 - float(home.get("WALL_THICKNESS")))
	points.append({"name": "estante", "eye": home.to_global(local_eye),
		"target": shelf.to_global(Vector3(0.0, EYE_HEIGHT, float(home.get("WALL_THICKNESS"))))})
	return points


## Mesmo caminho do capturar_pontos: o relógio avisa a casa via city_night.
func _set_hour(day_night: Node, hour: float) -> void:
	day_night.set("hour_offset", 0.0)
	day_night.set("hour_offset", hour - float(day_night.call("current_hour")))
	day_night.call("update_now")
