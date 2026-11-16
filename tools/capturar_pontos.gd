extends SceneTree
## Tira as CAPTURAS dos pontos de vista de referência de um bairro (Fase 15:
## brief do bioma montanha; depois, a revisão visual). Rode COM JANELA, à mão:
##
##   ~/.local/bin/godot --path . -s tools/capturar_pontos.gd -- <pasta> [jogos] [bairro] [horas] [qualidade] [céu] [tempo] [horas]
##
##   pasta      onde salvar os PNG. SEMPRE fora do repositório (as capturas
##              mostram capas de jogos, e o repositório é público)
##   jogos      0 = a biblioteca de verdade; N = N jogos falsos (padrão: 200)
##   bairro     id do bairro (padrão: rpg)
##   horas      lista separada por vírgula, de 0 a 24 (padrão: 13,22 = dia e noite);
##              hora quebrada vira minutos no nome (6.5 dá rpg_praca_06h30.png)
##   qualidade  leve | media | alta (padrão: alta). A do usuário volta no fim.
##   céu        fotos | sky3d (padrão: o do usuário, que volta no fim; Fase 19.4)
##   tempo      limpo | nublado | chuva_fraca | chuva_forte (Fase 19.6; padrão:
##              limpo). Fixa o tempo da cidade toda (o WeatherDirector), com o
##              céu e o chão já no ponto. "fraca" e "forte" (da 19.5) valem
##              como chuva_fraca e chuva_forte. Fora do limpo, o nome ganha o
##              tempo (sobrevivencia-chuva_forte_praca_13h.png) e entra o ponto
##              "rua". Para pular o céu, use "-" (ex.: alta - chuva_forte).
##   horas      - | falsas (Fase 19.9; padrão: -). Só com jogos falsos: "-" deixa
##              as horas desconhecidas (a planta de antes da 19.9); "falsas" usa
##              as horas falsas da tests/fake_library.gd (o RPG no nível 3).
##              Com "falsas", o nome ganha "-horas" (rpg-horas_cima_13h.png).
##
## Pontos (um PNG por ponto e por hora, ex.: rpg_praca_13h.png):
##   praca    no meio da praça, olhando para o bairro
##   portico  na rua, antes do pórtico do bairro, olhando para dentro
##   cima     do alto (60 m), olhando o bairro inteiro
##   mirante  na ponta da plataforma do mirante, olhando para a praça e a torre
##            do relógio (sem plataforma, o centro do disco)
## O mirante entra quando existir um nó no grupo mountain_trail (Fase 15.9); o
## ponto da vista vem do view_world() dele (15.10), ou do lookout_world().
##
## Para testar uma amostra de assets sem mexer no jogo, escreva um script que
## estende este (extends "res://tools/capturar_pontos.gd"), monte a amostra em
## _prepare() e, se quiser mais pontos, sobrescreva _points().

const SIZE: Vector2i = Vector2i(1600, 900)
const EYE_HEIGHT: float = 1.7
## Quadros de espera depois de mudar a hora ou o lugar (capas carregando,
## sombras e exposição assentando).
const SETTLE_FRAMES: int = 90
## Segundos de espera depois de mudar a hora: o céu Sky3D leva 3 s para trocar a
## luz do céu do dia pela da noite (contribution_tween_time); sem esperar, o
## primeiro ponto saía no meio da troca (Fase 17.5).
const HOUR_SETTLE_SECONDS: float = 3.5

## O tempo fixado (Fase 19.6; "limpo" = como as capturas de antes da chuva).
var _weather: String = "limpo"

## Nome do bairro nos arquivos; uma amostra pode trocar no _prepare (Fase 19.2:
## "rpg-novo"). Vazio = o id do bairro.
var _district_label: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Uso: -s res://tools/capturar_pontos.gd -- <pasta> [jogos] [bairro] [horas] [qualidade] [céu] [tempo] [horas]")
		quit(1)
		return
	var folder := String(args[0])
	var count := int(args[1]) if args.size() > 1 else 200
	var district := String(args[2]) if args.size() > 2 else "rpg"
	var hours: Array[float] = []
	for text in (String(args[3]) if args.size() > 3 else "13,22").split(","):
		hours.append(float(text))
	var quality := String(args[4]) if args.size() > 4 else "alta"
	var sky := String(args[5]) if args.size() > 5 else ""
	if sky == "-":
		sky = ""
	if sky not in ["", "fotos", "sky3d"]:
		push_error("O céu deve ser fotos ou sky3d.")
		quit(1)
		return
	_weather = String(args[6]) if args.size() > 6 else "limpo"
	_weather = {"fraca": "chuva_fraca", "forte": "chuva_forte"}.get(_weather, _weather)
	if _weather not in ["limpo", "nublado", "chuva_fraca", "chuva_forte"]:
		push_error("O tempo deve ser limpo, nublado, chuva_fraca ou chuva_forte.")
		quit(1)
		return
	var fake_hours := String(args[7]) if args.size() > 7 else "-"
	if fake_hours not in ["-", "falsas"]:
		push_error("As horas devem ser - (desconhecidas) ou falsas.")
		quit(1)
		return
	if (ProjectSettings.globalize_path(folder) + "/").begins_with(ProjectSettings.globalize_path("res://")):
		push_error("A pasta das capturas não pode ficar dentro do repositório.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)

	var config := root.get_node("AppConfig")
	var original_quality: String = config.get_quality()
	var original_sky: String = config.get_sky()
	config.set_quality(quality)
	if not sky.is_empty():
		config.set_sky(sky)
	if count > 0:
		var library_script: GDScript = load("res://tests/fake_library.gd")
		library_script.install(root, count, fake_hours == "falsas")

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
		config.set_sky(original_sky)
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
	# O corpo do jogador (Fase 20.3) fica fora: estas fotos são do cenário, de
	# uma câmera que não é a do jogador.
	if player.has_method("get_avatar"):
		(player.call("get_avatar") as Node3D).visible = false
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
	_force_weather(city, _weather)
	if _weather != "limpo":
		if _district_label.is_empty():
			_district_label = "%s-%s" % [district, _weather]
	if fake_hours == "falsas":
		_district_label = "%s-horas" % (_district_label if not _district_label.is_empty() else district)
	var day_night = city._day_night
	# Calcula uma vez: o aviso de mirante ausente também sai só uma vez.
	var points: Array[Dictionary] = _points(area)
	for hour in hours:
		_set_hour(day_night, hour)
		await create_timer(HOUR_SETTLE_SECONDS).timeout
		for point in points:
			var eye: Vector3 = point["eye"]
			var target: Vector3 = point["target"]
			# O jogador vai junto (som, LOD e o que depende de onde ele está).
			var feet := Vector3(eye.x, 0.1, eye.z)
			if point["name"] == "mirante":
				feet = eye - Vector3.UP * (EYE_HEIGHT - 0.1)
			player.teleport_to(Transform3D(Basis.IDENTITY, feet))
			camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(target)
			twin.global_transform = camera.global_transform
			for i in SETTLE_FRAMES:
				await process_frame
			await RenderingServer.frame_post_draw
			var label := _district_label if not _district_label.is_empty() else district
			var file := "%s/%s_%s_%s.png" % [folder, label, point["name"], hour_label(hour)]
			var image := frame.get_texture().get_image()
			image.save_png(file)
			print("Captura: ", file)
			_after_capture(image, camera, point, file)

	config.set_quality(original_quality)
	config.set_sky(original_sky)
	quit()


## Ponto de extensão: um script de amostra (que estende este) põe aqui o que
## quer ver na cidade antes das capturas. Aqui não faz nada.
func _prepare(_city: Node, _area: Dictionary) -> void:
	pass


## O tempo fixado (19.6): o WeatherDirector da cidade põe o céu, o chão e a
## chuva na hora. Uma amostra pode trocar.
func _force_weather(city: Node, state: String) -> void:
	var director: Node = city.get_node_or_null("WeatherDirector")
	if director != null:
		director.call("force", state)


## Ponto de extensão (19.2): depois de cada captura, a amostra pode salvar
## mais alguma coisa da mesma imagem (ex.: um recorte ampliado). Aqui, nada.
func _after_capture(_image: Image, _camera: Camera3D, _point: Dictionary, _file: String) -> void:
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
		if _weather != "limpo":
			points.append({"name": "rua", "eye": Vector3(gate.x + side * 12.0, EYE_HEIGHT, gate.y),
					"target": Vector3(gate.x + side * 6.0, 0.0, gate.y + 1.5)})

	# Do alto, do lado da praça: o bairro inteiro com a cidade em volta.
	var above := middle - toward * 50.0
	points.append({"name": "cima", "eye": Vector3(above.x, 60.0, above.y),
			"target": Vector3(middle.x, 0.0, middle.y)})
	for trail: Node in get_nodes_in_group(&"mountain_trail"):
		if trail.has_method("trail_world_points") and trail.has_method("lookout_world"):
			var view := "view_world" if trail.has_method("view_world") else "lookout_world"
			var floor_position: Vector3 = trail.call(view)
			points.append({"name": "mirante", "eye": floor_position + Vector3.UP * EYE_HEIGHT,
					"target": Vector3(0.0, EYE_HEIGHT, 0.0)})
			return points
	print("Capturas: sem montanha; ponto mirante omitido.")
	return points


## A hora no nome do arquivo: "13h" (hora cheia) ou "06h30" (Fase 19.4).
static func hour_label(hour: float) -> String:
	var minutes := roundi(hour * 60.0)
	if minutes % 60 == 0:
		return "%02dh" % floori(minutes / 60.0)
	return "%02dh%02d" % [floori(minutes / 60.0), minutes % 60]


## current_hour já inclui o deslocamento: zera antes de calcular a próxima hora.
func _set_hour(day_night: Node, hour: float) -> void:
	day_night.set("hour_offset", 0.0)
	day_night.set("hour_offset", hour - float(day_night.call("current_hour")))
	day_night.call("update_now")

