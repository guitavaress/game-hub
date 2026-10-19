extends SceneTree
## Tira as CAPTURAS dos pontos de vista de referência de um bairro (Fase 15:
## brief do bioma montanha; depois, a revisão visual). Rode COM JANELA, à mão:
##
##   ~/.local/bin/godot --path . -s tools/capturar_pontos.gd -- <pasta> [jogos] [bairro] [horas] [qualidade]
##
##   pasta      onde salvar os PNG. SEMPRE fora do repositório (as capturas
##              mostram capas de jogos, e o repositório é público)
##   jogos      0 = a biblioteca de verdade; N = N jogos falsos (padrão: 200)
##   bairro     id do bairro (padrão: rpg)
##   horas      lista separada por vírgula, de 0 a 24 (padrão: 13,22 = dia e noite)
##   qualidade  leve | media | alta (padrão: alta). A do usuário volta no fim.
##
## Pontos (um PNG por ponto e por hora, ex.: rpg_praca_13h.png):
##   praca    no meio da praça, olhando para o bairro
##   portico  na rua, antes do pórtico do bairro, olhando para dentro
##   cima     do alto (60 m), olhando o bairro inteiro
## O mirante entra quando existir (Fase 15.9).
##
## Para testar uma amostra de assets sem mexer no jogo, escreva um script que
## estende este (extends "res://tools/capturar_pontos.gd"), monte a amostra em
## _prepare() e, se quiser mais pontos, sobrescreva _points().

const SIZE: Vector2i = Vector2i(1600, 900)
const EYE_HEIGHT: float = 1.7
## Quadros de espera depois de mudar a hora ou o lugar (capas carregando,
## sombras e exposição assentando).
const SETTLE_FRAMES: int = 90


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Uso: -s res://tools/capturar_pontos.gd -- <pasta> [jogos] [bairro] [horas] [qualidade]")
		quit(1)
		return
	var folder := String(args[0])
	var count := int(args[1]) if args.size() > 1 else 200
	var district := String(args[2]) if args.size() > 2 else "rpg"
	var hours: Array[float] = []
	for text in (String(args[3]) if args.size() > 3 else "13,22").split(","):
		hours.append(float(text))
	var quality := String(args[4]) if args.size() > 4 else "alta"
	if (ProjectSettings.globalize_path(folder) + "/").begins_with(ProjectSettings.globalize_path("res://")):
		push_error("A pasta das capturas não pode ficar dentro do repositório.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)

	var config := root.get_node("AppConfig")
	var original_quality: String = config.get_quality()
	config.set_quality(quality)
	if count > 0:
		var library_script: GDScript = load("res://tests/fake_library.gd")
		library_script.install(root, count)

	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	print("montando a cidade...")
	while not city.is_city_ready():
		await process_frame

	var area := _find_area(city, district)
	if area.is_empty():
		push_error("O bairro \"%s\" não existe nesta biblioteca." % district)
		config.set_quality(original_quality)
		quit(1)
		return

	# Um quadro só nosso, do tamanho SIZE, que enxerga o mesmo mundo da janela
	# (o gerenciador de janelas pode não deixar a janela mudar de tamanho). Ele
	# tem a qualidade escolhida e uma câmera com a lente da câmera do jogador.
	# O HUD não aparece: ele é desenhado só na janela.
	var frame := SubViewport.new()
	frame.size = SIZE
	frame.world_3d = root.world_3d
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	load("res://autoload/graphics_quality.gd").apply_to_viewport(frame, quality)
	root.add_child(frame)
	var player: Node3D = city.get_node("Player")
	var player_camera: Camera3D = player.get_node("Head/Camera3D")
	var camera := Camera3D.new()
	camera.fov = player_camera.fov
	camera.far = player_camera.far
	frame.add_child(camera)
	camera.current = true
	# Uma gêmea na janela: o que se vira para "a câmera" (como o letreiro do
	# bairro) pergunta à janela, e não ao nosso quadro.
	var twin := Camera3D.new()
	twin.fov = camera.fov
	twin.far = camera.far
	city.add_child(twin)
	twin.make_current()

	_prepare(city, area)
	var day_night = city._day_night
	for hour in hours:
		day_night.hour_offset = hour - day_night.current_hour()
		day_night.update_now()
		for point in _points(area):
			var eye: Vector3 = point["eye"]
			var target: Vector3 = point["target"]
			# O jogador vai junto (som, LOD e o que depende de onde ele está).
			player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(eye.x, 0.1, eye.z)))
			camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(target)
			twin.global_transform = camera.global_transform
			for i in SETTLE_FRAMES:
				await process_frame
			await RenderingServer.frame_post_draw
			var file := "%s/%s_%s_%02dh.png" % [folder, district, point["name"], int(hour)]
			frame.get_texture().get_image().save_png(file)
			print("Captura: ", file)

	config.set_quality(original_quality)
	quit()


## Ponto de extensão: um script de amostra (que estende este) põe aqui o que
## quer ver na cidade antes das capturas. Aqui não faz nada.
func _prepare(_city: Node, _area: Dictionary) -> void:
	pass


## Os dados do bairro na planta (CityMap), ou {} se ele não existe.
func _find_area(city: Node, district: String) -> Dictionary:
	var map = get_first_node_in_group("world_map")  # sem tipo: CityMap depende dos autoloads
	if map == null:
		return {}
	for area: Dictionary in map.get_map_data()["areas"]:
		if area["id"] == district:
			return area
	return {}


## Onde fica a câmera e para onde ela olha, em cada ponto.
func _points(area: Dictionary) -> Array[Dictionary]:
	var rects: Array[Rect2] = area["rects"]
	var middle := Vector2.ZERO
	for rect in rects:
		middle += rect.get_center()
	middle /= rects.size()
	var points: Array[Dictionary] = []

	# Praça: um pouco antes do centro, do lado oposto ao bairro, e de lado
	# para o obelisco da torre do relógio não tampar a vista.
	var toward := middle.normalized() if middle.length() > 0.01 else Vector2(0.0, -1.0)
	var plaza := -toward * 6.0 + toward.orthogonal() * 5.0
	points.append({"name": "praca", "eye": Vector3(plaza.x, EYE_HEIGHT, plaza.y),
			"target": Vector3(middle.x, EYE_HEIGHT + 6.0, middle.y)})

	# Pórtico: a rua corre de leste a oeste; fica-se do lado da praça.
	var gate: Vector2 = area["gate"]
	if gate != Vector2.INF:
		var side := signf(gate.x - rects[0].get_center().x)
		if side == 0.0:
			side = 1.0
		points.append({"name": "portico", "eye": Vector3(gate.x + side * 12.0, EYE_HEIGHT, gate.y),
				"target": Vector3(gate.x - side * 30.0, EYE_HEIGHT + 2.0, gate.y)})

	# Do alto, do lado da praça: o bairro inteiro com a cidade em volta.
	var above := middle - toward * 50.0
	points.append({"name": "cima", "eye": Vector3(above.x, 60.0, above.y),
			"target": Vector3(middle.x, 0.0, middle.y)})
	return points

