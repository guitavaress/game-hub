extends SceneTree
## Tira as CAPTURAS da terceira pessoa (Fase 20.4), pela CÂMERA DO JOGADOR (a
## da ponta do braço). Rode COM JANELA, pela fila:
##
##   bash tools/com_trava.sh <godot> --path . -s tools/capturar_terceira.gd -- <pasta> [jogos] [jeitos] [qualidade]
##
##   pasta      onde salvar os PNG, numa subpasta por jeito (ombro/, livre/).
##              SEMPRE fora do repositório (as capturas mostram capas de jogos)
##   jogos      0 = a biblioteca de verdade; N = N jogos falsos (padrão: 200)
##   jeitos     lista separada por vírgula (padrão: ombro,livre)
##   qualidade  leve | media | alta (padrão: alta). A do usuário volta no fim,
##              e a visão do config.cfg também.
##
## Fotos (PNG), por jeito:
##   praca_parado, praca_andando, praca_correndo (13 h e 22 h): por trás, na praça
##   praca_lado, praca_tras    andando de lado e para trás (onde os jeitos diferem)
##   rua_estreita              no vão entre dois prédios vizinhos
##   costas_predio             encostado de costas na parede de um prédio
##   predio_1m                 de costas para o prédio, a 1 m da parede
##   costas_arvore             encostado de costas numa árvore da floresta
##   floresta                  no bairro Aventura (a floresta)
##   porta_cartao              olhando para a porta de um jogo, com o cartão do HUD
##   casa_meio, casa_parede, casa_teto (olhando para baixo: o braço sobe para o
##   teto), casa_cima (olhando para cima), casa_espelho
##   passagem_1..4             a passagem da primeira para a terceira pessoa

const SIZE: Vector2i = Vector2i(1600, 900)
const SETTLE_FRAMES: int = 40
const HOUR_SETTLE_SECONDS: float = 3.5
const WALK_SECONDS: float = 0.8
## A passagem em câmera lenta (Engine.time_scale), para pegar 4 quadros dela.
const PASSAGE_SLOW: float = 0.08

var _folder: String = ""
var _player: Node3D
var _failed: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Uso: -s tools/capturar_terceira.gd -- <pasta> [jogos] [jeitos] [qualidade]")
		quit(1)
		return
	var base := ProjectSettings.globalize_path(String(args[0])).replace("\\", "/").simplify_path()
	var count := int(args[1]) if args.size() > 1 else 200
	var styles := (String(args[2]) if args.size() > 2 else "ombro,livre").split(",")
	var quality := String(args[3]) if args.size() > 3 else "alta"
	var repo := ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path()
	if (base.to_lower() + "/").begins_with(repo.to_lower() + "/"):
		push_error("A pasta das capturas não pode ficar dentro do repositório.")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("As capturas precisam de janela (sem --headless).")
		quit(1)
		return

	var config := root.get_node("AppConfig")
	var original_quality: String = config.get_quality()
	var original_view: String = config.get_view()
	config.set_quality(quality)
	config.set_view("third")
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
	var day_night: Node = city.get("_day_night")
	var spots := _find_spots(city)

	for style in styles:
		_folder = base + "/" + style
		DirAccess.make_dir_recursive_absolute(_folder)
		_player.set("third_person_style", style)
		for hour: float in [13.0, 22.0]:
			await _set_hour(day_night, hour)
			var tag := "%02dh" % roundi(hour)
			_player.call("set_indoors", null)
			_place(plaza, -8.0)
			await _shot("praca_parado", tag)
			await _walk(plaza, "praca_andando", tag, ["move_forward"])
			await _walk(plaza, "praca_correndo", tag, ["move_forward", "sprint"])
			if hour == 13.0:
				await _walk(plaza, "praca_lado", tag, ["move_right"])
				await _walk(plaza, "praca_tras", tag, ["move_back"])
		var tag := "13h"
		await _set_hour(day_night, 13.0)
		for spot_name: String in ["rua_estreita", "costas_predio", "predio_1m", "costas_arvore", "floresta", "porta_cartao"]:
			if not spots.has(spot_name):
				print("Capturas: sem lugar para ", spot_name)
				continue
			_place(spots[spot_name], -8.0)
			await _shot(spot_name, tag, SETTLE_FRAMES, spot_name == "porta_cartao")
		# Em casa.
		var home: Node3D = city.call("get_home")
		var spawn: Transform3D = home.call("get_spawn_transform")
		_player.call("teleport_to", spawn)
		_player.call("set_indoors", home.call("get_environment"))
		_place(spawn, -8.0)
		await _shot("casa_meio", tag)
		var room: Vector3 = home.get("ROOM_SIZE")
		_place(Transform3D(home.global_basis, home.to_global(Vector3(-1.0, 0.1, room.z / 2.0 - 0.5))), -8.0)
		await _shot("casa_parede", tag)
		_place(spawn, -60.0)
		await _shot("casa_teto", tag)
		_place(spawn, 45.0)
		await _shot("casa_cima", tag)
		var mirror: Node3D = home.call("get_furniture", "espelho")
		var normal: Vector3 = mirror.call("get_normal")
		var feet: Vector3 = mirror.global_position + normal * 1.8
		feet.y = home.global_position.y + 0.1
		_place(Transform3D(Basis.looking_at(-normal), feet), -5.0)
		await _shot("casa_espelho", tag)
		# A passagem da primeira para a terceira, em câmera lenta, na praça.
		_player.call("set_indoors", null)
		_player.call("toggle_view")  # para a primeira
		_place(plaza, -8.0)
		for i in 90:
			await process_frame
		Engine.time_scale = PASSAGE_SLOW
		_player.call("toggle_view")  # para a terceira
		var seconds: float = float(_player.get("VIEW_SWITCH_SECONDS"))
		for i in 4:
			await create_timer(seconds * (0.15 if i == 0 else 0.22)).timeout
			await _shot("passagem_%d" % (i + 1), tag, 0)
		Engine.time_scale = 1.0
		for i in 30:
			await process_frame

	config.set_quality(original_quality)
	config.set_view(original_view)
	quit(1 if _failed else 0)


## Anda por WALK_SECONDS segurando as ações e tira a foto andando.
func _walk(start: Transform3D, shot_name: String, tag: String, actions: Array) -> void:
	_place(start, -8.0)
	for action: String in actions:
		Input.action_press(action)
	await create_timer(WALK_SECONDS).timeout
	await _shot(shot_name, tag, 0)
	for action: String in actions:
		Input.action_release(action)
	await create_timer(0.8).timeout


## Os lugares das fotos, achados na cidade montada.
func _find_spots(city: Node) -> Dictionary:
	var spots := {}
	var space := (city as Node3D).get_world_3d().direct_space_state
	var portals: Array = get_nodes_in_group("game_portal").filter(func(p: Node) -> bool:
		return city.is_ancestor_of(p) and p.has_method("get_return_transform"))
	# A porta com o cartão: 3,5 m na frente da porta, olhando para ela.
	if not portals.is_empty():
		var door: Transform3D = portals[0].call("get_arrival_transform")
		var back := door.basis.z.normalized()  # a frente do transform olha para a porta (-Z)
		spots["porta_cartao"] = Transform3D(door.basis, door.origin + back * 3.5)
	# Encostado num prédio e o vão entre dois vizinhos.
	for portal: Node3D in portals:
		var ret: Transform3D = portal.call("get_return_transform")
		var outward := -ret.basis.z.normalized()  # o ReturnPoint olha para a rua
		outward.y = 0.0
		outward = outward.normalized()
		var side := outward.cross(Vector3.UP).normalized()
		var from := ret.origin + side * 3.0 + Vector3.UP * 1.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - outward * 12.0, 1))
		if hit.is_empty() or spots.has("costas_predio"):
			continue
		var wall: Vector3 = hit["position"]
		var feet := Vector3(wall.x, ret.origin.y, wall.z) + outward * 0.45
		spots["costas_predio"] = Transform3D(Basis.looking_at(outward), feet)
		spots["predio_1m"] = Transform3D(Basis.looking_at(outward), feet + outward * 0.6)
	for a: Node3D in portals:
		if spots.has("rua_estreita"):
			break
		for b: Node3D in portals:
			if a == b:
				continue
			var ra: Transform3D = a.call("get_return_transform")
			var rb: Transform3D = b.call("get_return_transform")
			var gap := ra.origin.distance_to(rb.origin)
			if absf(gap - 14.0) < 0.5 and ra.basis.z.dot(rb.basis.z) > 0.99:
				var outward := -ra.basis.z.normalized()
				outward.y = 0.0
				outward = outward.normalized()
				var middle := (ra.origin + rb.origin) / 2.0
				# Recuado da fachada, para dentro do vão, olhando para dentro.
				var probe := middle + Vector3.UP * 1.5
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe, probe - outward * 20.0, 1))
				var depth := 6.0 if hit.is_empty() else minf(6.0, probe.distance_to(hit["position"]) - 1.5)
				var feet := middle - outward * maxf(depth, 2.0)
				spots["rua_estreita"] = Transform3D(Basis.looking_at(-outward), feet)
				break
	# A floresta (Aventura) e uma árvore dela.
	var area := _find_area("aventura")
	if not area.is_empty():
		var gate: Vector2 = area["gate"]
		var rects: Array = area["rects"]
		var center: Vector2 = (rects[0] as Rect2).get_center()
		if gate != Vector2.INF:
			var inward := Vector3(center.x - gate.x, 0.0, center.y - gate.y).normalized()
			spots["floresta"] = Transform3D(Basis.looking_at(inward), Vector3(gate.x, 0.1, gate.y) + inward * 16.0)
		var best: Vector3 = Vector3.INF
		var best_radius := 0.0
		for body: Node in city.find_children("ScatterCollision_*", "StaticBody3D", true, false):
			for child: Node in body.get_children():
				var shape := child as CollisionShape3D
				if shape == null or not (shape.shape is CylinderShape3D):
					continue
				var cylinder := shape.shape as CylinderShape3D
				var at := shape.global_position
				if cylinder.radius < 0.2 or cylinder.height < 2.5:
					continue
				if not _inside(rects, Vector2(at.x, at.z)):
					continue
				if best == Vector3.INF or Vector2(at.x - gate.x, at.z - gate.y).length() < Vector2(best.x - gate.x, best.z - gate.y).length():
					best = at
					best_radius = cylinder.radius
		if best != Vector3.INF:
			var away := Vector3(gate.x - best.x, 0.0, gate.y - best.z).normalized()
			var feet := Vector3(best.x, 0.1, best.z) + away * (best_radius + 0.45)
			spots["costas_arvore"] = Transform3D(Basis.looking_at(away), feet)
	print("Capturas: lugares ", spots.keys())
	return spots


func _inside(rects: Array, point: Vector2) -> bool:
	for rect: Rect2 in rects:
		if rect.has_point(point):
			return true
	return false


func _find_area(district: String) -> Dictionary:
	var map = get_first_node_in_group("world_map")
	if map == null:
		return {}
	for area: Dictionary in map.get_map_data()["areas"]:
		if area["id"] == district:
			return area
	return {}


func _set_hour(day_night: Node, hour: float) -> void:
	day_night.set("hour_offset", 0.0)
	day_night.set("hour_offset", hour - float(day_night.call("current_hour")))
	day_night.call("update_now")
	await create_timer(HOUR_SETTLE_SECONDS).timeout


## Põe o jogador num lugar, virado para a frente do transform, com a cabeça
## inclinada "pitch" graus (negativo = para baixo).
func _place(spot: Transform3D, pitch: float) -> void:
	_player.call("teleport_to", spot)
	_player.get_node("Head").rotation.x = deg_to_rad(pitch)


## Uma foto da janela, depois de "settle" quadros. Sem o HUD, salvo "hud".
func _shot(shot_name: String, tag: String, settle: int = SETTLE_FRAMES, hud: bool = false) -> void:
	for i in settle:
		await process_frame
	(_player.call("get_hud") as CanvasLayer).visible = hud
	await process_frame
	await RenderingServer.frame_post_draw
	var file := "%s/%s_%s.png" % [_folder, shot_name, tag]
	if root.get_texture().get_image().save_png(file) != OK:
		push_error("Não consegui salvar: " + file)
		_failed = true
	else:
		print("Captura: ", file)
	(_player.call("get_hud") as CanvasLayer).visible = true
