extends SceneTree
## Tira as CAPTURAS do seu corpo em primeira pessoa (Fase 20.3). Diferente do
## capturar_pontos e do capturar_casa, a foto sai da CÂMERA DO JOGADOR (é ela
## que vê o corpo de primeira pessoa, e o corpo fica preso ao jogador). Rode
## COM JANELA, pela fila:
##
##   bash tools/com_trava.sh <godot> --path . -s tools/capturar_corpo.gd -- <pasta> [jogos] [horas] [qualidade]
##
##   pasta      onde salvar os PNG. SEMPRE fora do repositório (as capturas
##              podem mostrar capas de jogos, e o repositório é público)
##   jogos      0 = a biblioteca de verdade; N = N jogos falsos (padrão: 200)
##   horas      lista separada por vírgula, de 0 a 24 (padrão: 13,22)
##   qualidade  leve | media | alta (padrão: alta). A do usuário volta no fim.
##
## Fotos (um PNG por foto e hora, ex.: praca_baixo_13h.png), na praça e em casa:
##   baixo       parado, olhando para baixo (55°): tronco, braços, pernas e pés
##   pes         parado, olhando quase reto para baixo (85°): o pescoço não pode aparecer
##   andando     andando (W), olhando para baixo, duas fotos
##   correndo    correndo (Shift+W), olhando para baixo
##   frente_andando, frente_correndo
##               olhando reto para a frente, andando e correndo, duas fotos cada
##               (20.3.1: nada do corpo no meio nem na metade de cima da tela)
##   sombra      de costas para o sol, olhando para a sombra (com cabeça)
## Só em casa:
##   espelho     de frente para o espelho, a 1,6 m
##   provador    o foco no espelho (o avatar parado na frente do vidro)

const SIZE: Vector2i = Vector2i(1600, 900)
## Quadros de espera depois de mudar o lugar (sombras e exposição assentando).
const SETTLE_FRAMES: int = 40
## Segundos de espera depois de mudar a hora (o céu troca a luz devagar).
const HOUR_SETTLE_SECONDS: float = 3.5
## Quanto tempo (s) andando antes da foto, e entre as duas fotos andando.
const WALK_SECONDS: float = 0.7
const WALK_GAP_SECONDS: float = 0.18

var _folder: String = ""
var _player: Node3D
var _failed: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Uso: -s tools/capturar_corpo.gd -- <pasta> [jogos] [horas] [qualidade]")
		quit(1)
		return
	_folder = ProjectSettings.globalize_path(String(args[0])).replace("\\", "/").simplify_path()
	var count := int(args[1]) if args.size() > 1 else 200
	var hours: Array[float] = []
	for text in (String(args[2]) if args.size() > 2 else "13,22").split(","):
		hours.append(float(text))
	var quality := String(args[3]) if args.size() > 3 else "alta"
	var repo := ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path()
	if (_folder.to_lower() + "/").begins_with(repo.to_lower() + "/"):
		push_error("A pasta das capturas não pode ficar dentro do repositório.")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("As capturas precisam de janela (sem --headless).")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_folder)

	var config := root.get_node("AppConfig")
	var original_quality: String = config.get_quality()
	config.set_quality(quality)
	load("res://tests/quiet_friends.gd").install(root)
	if count > 0:
		load("res://tests/fake_library.gd").install(root, count)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	print("montando a cidade...")
	while not city.is_city_ready():
		await process_frame
	DisplayServer.window_set_size(SIZE)
	var director: Node = city.get_node_or_null("WeatherDirector")
	if director != null:
		director.call("force", "limpo")
	_player = city.get_node("Player")
	var plaza: Transform3D = _player.global_transform
	var home: Node3D = city.call("get_home")
	var mirror: Node3D = home.call("get_furniture", "espelho")
	var day_night: Node = city.get("_day_night")

	for hour in hours:
		day_night.set("hour_offset", 0.0)
		day_night.set("hour_offset", hour - float(day_night.call("current_hour")))
		day_night.call("update_now")
		await create_timer(HOUR_SETTLE_SECONDS).timeout
		var tag := "%02dh" % roundi(hour)
		# Na praça.
		_player.call("set_indoors", null)
		await _shots("praca", tag, plaza, _sky_travel(city), plaza.origin)
		# Em casa, a partir do ponto de nascer.
		_player.call("teleport_to", home.call("get_spawn_transform"))
		_player.call("set_indoors", home.call("get_environment"))
		var spawn: Transform3D = home.call("get_spawn_transform")
		var travel: Vector3 = home.call("sun_direction")
		# O meio da mancha de sol no chão (o mesmo cálculo do rebote, em Home._build_sun).
		var window := Vector3(float(home.get("WINDOW_CENTER_X")), float(home.get("WINDOW_CENTER_Y")), -(home.get("ROOM_SIZE") as Vector3).z / 2.0)
		var patch: Vector3 = window + travel * (window.y / -travel.y)
		await _shots("casa", tag, Transform3D(spawn.basis, _player.global_position), home.global_basis * travel,
				home.to_global(Vector3(patch.x, 0.05, patch.z)))
		# O espelho e o provador.
		var normal: Vector3 = mirror.call("get_normal")
		var feet: Vector3 = mirror.global_position + normal * 1.6
		feet.y = _player.global_position.y
		_place(Transform3D(Basis.looking_at(-normal), feet), -5.0)
		await _shot("casa_espelho", tag)
		_player.call("focus_on", mirror)
		await create_timer(1.0).timeout
		await _shot("casa_provador", tag)
		_player.call("leave_focus", true)
		await process_frame

	config.set_quality(original_quality)
	quit(1 if _failed else 0)


## As fotos de um lugar: parado, andando, correndo e a sombra. "sun_travel" =
## para onde andam os raios do sol (a sombra cai para esse lado); "sunny" =
## onde o jogador fica para as fotos da sombra.
func _shots(place: String, tag: String, start: Transform3D, sun_travel: Vector3, sunny: Vector3) -> void:
	_place(start, -55.0)
	await _shot(place + "_baixo", tag)
	_place(start, -85.0)
	await _shot(place + "_pes", tag)
	_place(start, -55.0)
	Input.action_press("move_forward")
	await create_timer(WALK_SECONDS).timeout
	await _shot(place + "_andando1", tag, 0)
	await create_timer(WALK_GAP_SECONDS).timeout
	await _shot(place + "_andando2", tag, 0)
	Input.action_release("move_forward")
	_place(start, -40.0)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await create_timer(WALK_SECONDS).timeout
	await _shot(place + "_correndo", tag, 0)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await create_timer(0.6).timeout
	for sprint in [false, true]:
		var kind := "correndo" if sprint else "andando"
		_place(start, 0.0)
		if sprint:
			Input.action_press("sprint")
		Input.action_press("move_forward")
		await create_timer(WALK_SECONDS).timeout
		await _shot(place + "_frente_" + kind + "1", tag, 0)
		await create_timer(WALK_GAP_SECONDS).timeout
		await _shot(place + "_frente_" + kind + "2", tag, 0)
		Input.action_release("move_forward")
		Input.action_release("sprint")
		await create_timer(0.6).timeout
	var away := Vector3(sun_travel.x, 0.0, sun_travel.z)
	if away.length() > 0.01:
		_place(Transform3D(Basis.looking_at(away.normalized()), sunny), -35.0)
		await _shot(place + "_sombra", tag)
		await _shadow_from_outside(place + "_sombra_fora", tag)


## A sombra vista de fora: uma câmera ao lado e acima do jogador, com a mesma
## máscara e o mesmo ambiente da câmera dele (a sombra do inteiro só existe
## para quem enxerga a camada dela). O corpo de primeira pessoa (sem cabeça)
## some só nesta foto, para a sombra com cabeça ficar clara.
func _shadow_from_outside(shot_name: String, tag: String) -> void:
	var player_camera: Camera3D = _player.get_node("Head/Camera3D")
	var first: Node3D = _player.call("get_avatar").call("get_first_person_body")
	var camera := Camera3D.new()
	camera.cull_mask = player_camera.cull_mask
	camera.environment = player_camera.environment
	camera.fov = player_camera.fov
	root.add_child(camera)
	var forward := -_player.global_basis.z
	var side := _player.global_basis.x
	camera.global_position = _player.global_position + side * 2.0 - forward * 0.6 + Vector3.UP * 2.2
	camera.look_at(_player.global_position + forward * 1.0, Vector3.UP)
	camera.make_current()
	first.visible = false
	await _shot(shot_name, tag)
	first.visible = true
	player_camera.make_current()
	camera.queue_free()


## Põe o jogador num lugar, virado para a frente do transform, com a cabeça
## inclinada "pitch" graus (negativo = para baixo).
func _place(spot: Transform3D, pitch: float) -> void:
	_player.call("teleport_to", spot)
	_player.get_node("Head").rotation.x = deg_to_rad(pitch)


## Uma foto da janela (sem o HUD), depois de "settle" quadros.
func _shot(shot_name: String, tag: String, settle: int = SETTLE_FRAMES) -> void:
	for i in settle:
		await process_frame
	(_player.call("get_hud") as CanvasLayer).visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var file := "%s/%s_%s.png" % [_folder, shot_name, tag]
	if root.get_texture().get_image().save_png(file) != OK:
		push_error("Não consegui salvar: " + file)
		_failed = true
	else:
		print("Captura: ", file)


## Para onde andam os raios da luz do céu mais forte agora (sol ou lua).
func _sky_travel(city: Node) -> Vector3:
	var best: DirectionalLight3D = null
	for node in city.find_children("*", "DirectionalLight3D", true, false):
		var light := node as DirectionalLight3D
		if light.visible and (best == null or light.light_energy > best.light_energy):
			best = light
	return -best.global_basis.z if best != null else Vector3.ZERO
