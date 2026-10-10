extends SceneTree
## Teste da casa e das portas (Fase 9.2):
##   - E na porta "Casa" da praça leva para dentro de casa;
##   - em casa: ambiente da casa na câmera, câmera curta, sem bússola nem
##     minimapa, som do mundo abafado;
##   - E na porta da rua devolve à praça, e tudo volta ao normal;
##   - nenhuma porta abre com um jogo abrindo/rodando, nem trancada;
##   - o sol da cidade não ilumina a camada do interior;
##   - o loft (9.9): nada fica fora da sala, dá para andar do ponto de nascer
##     até cada móvel e até a porta, e a janela acompanha a hora.

const INTERIOR_MASK := 1 << 19  # camada de render 20 (Home.INTERIOR_LAYER)

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout  # a tela termina de clarear
	var launcher = root.get_node("GameLauncher")
	launcher._poll_timer.paused = true
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var home = city.get_home()
	var plaza_door = city.get_home_door()
	var front_door = home.get_front_door()
	var outdoor_far := camera.far
	var show_map: bool = root.get_node("AppConfig").get_show_map()

	print("== Montagem ==")
	_check("a casa existe, no grupo home, longe da cidade", home != null and home.is_in_group("home")
			and home.global_position.length() > 1000.0)
	var sun: DirectionalLight3D = city.get_node("Sun")
	_check("o sol não ilumina a camada do interior", sun.light_cull_mask & INTERIOR_MASK == 0)
	_check("o sol continua iluminando a cidade (camada 1)", sun.light_cull_mask & 1 == 1)
	var meshes := _geometry(home)
	var all_interior := not meshes.is_empty()
	for mesh in meshes:
		if mesh.layers != INTERIOR_MASK:
			all_interior = false
	_check("tudo o que a casa desenha está na camada do interior (%d peças)" % meshes.size(), all_interior)
	_check("as duas portas estão abertas", plaza_door.is_open() and front_door.is_open())

	print("== Jogo rodando: a porta não abre ==")
	_look_at(player, plaza_door, 3.0)
	await _frames(3)
	launcher.state = launcher.State.RUNNING
	await _press_e()
	await create_timer(1.2).timeout
	launcher.state = launcher.State.IDLE
	_check("com jogo rodando, continua na praça", not player.is_indoors()
			and player.global_position.distance_to(plaza_door.global_position) < 5.0)

	print("== Trancada: a porta não abre ==")
	plaza_door.locked_reason = "Em obras"
	await _frames(3)
	_check("o cartão mostra o motivo, sem dica de E", hud.get_look_text().contains("Em obras") and hud.get_look_action() == "")
	await _press_e()
	await create_timer(1.2).timeout
	_check("trancada, continua na praça", not player.is_indoors())
	plaza_door.locked_reason = ""
	await _frames(3)

	print("== Praça → casa ==")
	_check("o cartão da porta tem a dica do E", hud.get_look_action() != "")
	await _press_e()
	await create_timer(0.2).timeout
	_check("viajando", player.is_traveling())
	await create_timer(1.3).timeout
	var spawn: Transform3D = home.get_spawn_transform()
	_check("chegou no ponto de nascer da casa", player.global_position.distance_to(spawn.origin) < 0.5)
	_check("está em casa", player.is_indoors())
	_check("a câmera usa o ambiente da casa", camera.environment == home.get_environment())
	_check("a câmera enxerga pouco (o mundo lá fora não é desenhado)", camera.far < 100.0)
	_check("sem bússola", not hud.get_compass().visible)
	_check("sem minimapa", not hud.get_minimap().visible)
	_check("som do mundo abafado", _ambience_muffled())
	var forward: Vector3 = -player.global_basis.z
	_check("olhando para a janela (norte)", forward.dot(Vector3(0.0, 0.0, -1.0)) > 0.95)

	print("== Casa → praça ==")
	player.rotation.y = PI  # vira para a porta da rua (sul)
	await _frames(3)
	_check("olhando a porta da rua", hud.get_look_text().begins_with(front_door.door_name))
	await _press_e()
	await create_timer(1.5).timeout
	_check("voltou para a praça, na frente da porta Casa",
			player.global_position.distance_to(city.HOME_DOOR_ARRIVAL) < 0.5)
	_check("não está mais em casa", not player.is_indoors())
	_check("a câmera voltou ao ambiente da cidade", camera.environment == null)
	_check("a câmera voltou a enxergar longe", is_equal_approx(camera.far, outdoor_far))
	_check("a bússola volta (se a opção estiver ligada)", hud.get_compass().visible == show_map)
	_check("o minimapa volta (se a opção estiver ligada)", hud.get_minimap().visible == show_map)
	_check("o som do mundo volta ao normal", not _ambience_muffled())
	forward = -player.global_basis.z
	_check("olhando para o chafariz (norte)", forward.dot(Vector3(0.0, 0.0, -1.0)) > 0.95)

	await _check_loft(home, player)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Coloca o jogador a "distance" metros na frente da porta, olhando para ela.
func _look_at(player: Node3D, door: Node3D, distance: float) -> void:
	var front: Vector3 = door.global_basis.z
	front.y = 0.0
	front = front.normalized()
	player.global_position = door.global_position + front * distance + Vector3(0.0, 0.1, 0.0)
	player.rotation = Vector3(0.0, atan2(front.x, front.z), 0.0)


func _press_e() -> void:
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)


func _ambience_muffled() -> bool:
	var bus := AudioServer.get_bus_index(&"Ambiente")
	var muffled := AudioServer.get_bus_effect_count(bus) > 0
	for i in AudioServer.get_bus_effect_count(bus):
		if not AudioServer.is_bus_effect_enabled(bus, i):
			muffled = false
	return muffled


## O loft (9.9): tudo dentro da sala, passagens livres e a janela com a hora.
func _check_loft(home: Node3D, player: CharacterBody3D) -> void:
	print("== O loft ==")
	var room: Vector3 = home.ROOM_SIZE
	var inner := AABB(Vector3(-room.x / 2.0, 0.0, -room.z / 2.0), room).grow(0.03)
	var outside: Array[String] = []
	var pieces := 0
	for mesh in _geometry(home):
		if mesh.name.begins_with("Floor") or mesh.name.begins_with("Ceiling") or mesh.name.begins_with("Wall"):
			continue  # a casca da sala fica do lado de fora de propósito
		pieces += 1
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		box.position -= home.global_position
		if not inner.encloses(box):
			outside.append(String(mesh.name))
	if not outside.is_empty():
		print("   fora da sala: ", outside)
	_check("nada fica fora da sala (%d peças)" % pieces, outside.is_empty())

	# Passagens: o corpo do jogador anda em linha reta de ponto em ponto
	# (coordenadas da casa, em x e z), sem bater em nada.
	var shape: Shape3D = player.get_node("CollisionShape3D").shape
	var routes := {
		"estante": [Vector2(0.0, 1.5), Vector2(-3.5, 1.5), Vector2(-3.5, -0.5)],
		"mural": [Vector2(0.0, 1.5), Vector2(3.5, 1.5), Vector2(3.5, -0.5)],
		"computador": [Vector2(0.0, 1.5), Vector2(3.6, 1.5), Vector2(3.6, -3.1)],
		"janela": [Vector2(0.0, 1.5), Vector2(-2.4, 1.5), Vector2(-2.4, -3.8)],
		"porta da rua": [Vector2(0.0, 1.5), Vector2(0.0, 3.9)],
	}
	var space := player.get_world_3d().direct_space_state
	for target in routes:
		var points: Array = routes[target]
		var free := true
		for i in points.size() - 1:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.collision_mask = 1
			query.exclude = [player.get_rid()]
			var from: Vector2 = points[i]
			var to: Vector2 = points[i + 1]
			query.transform = Transform3D(Basis.IDENTITY, home.to_global(Vector3(from.x, 1.05, from.y)))
			query.motion = home.global_basis * Vector3(to.x - from.x, 0.0, to.y - from.y)
			if space.cast_motion(query)[0] < 1.0:
				free = false
		_check("passagem livre até: %s" % target, free)

	_check("a casa ouve a hora (grupo city_night)", home.is_in_group("city_night"))
	var night_before: float = home.get_night()
	var window: ShaderMaterial = home.get_node("WindowView").material_override
	var daylight: SpotLight3D = home.get_node("Daylight")
	home.set_night(0.0)
	_check("de dia: janela clara e luz do dia entrando", window.get_shader_parameter("night") == 0.0
			and daylight.visible and daylight.light_energy > 1.0)
	home.set_night(1.0)
	_check("de noite: janela escura e sem luz do dia", window.get_shader_parameter("night") == 1.0
			and not daylight.visible)
	home.set_night(night_before)


func _geometry(node: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	if node is GeometryInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_geometry(child))
	return found


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
