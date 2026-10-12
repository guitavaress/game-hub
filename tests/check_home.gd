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
## E da fachada da porta "Casa" na praça (Fase 9.10):
##   - fica dentro da praça, longe do chafariz, da estação Central, dos postes
##     e da roda de amigos (até 40 amigos), e fora dos caminhos da praça;
##   - é sólida, e o ponto de chegada (quem sai de casa) fica livre, na frente;
##   - o néon e a luz acendem à noite; a casa é um marco no mapa.

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

	_check_facade(city, plaza_door)

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
	_check("o cartão da porta tem a dica do E (\"%s\")" % hud.get_look_action(), hud.get_look_action() == "E para entrar")
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
	# Fase 10.8: virado ~35° do norte para o oeste, entre a janela e a estante.
	var from_north := absf(rad_to_deg(Vector2(forward.x, forward.z).angle_to(Vector2(0.0, -1.0))))
	_check("entre a janela e a estante (%.0f° do norte para o oeste)" % from_north,
			forward.x < 0.0 and from_north > 20.0 and from_north < 50.0)

	print("== Casa → praça ==")
	player.rotation.y = PI  # vira para a porta da rua (sul)
	await _frames(3)
	_check("olhando a porta da rua", hud.get_look_text().begins_with(front_door.door_name))
	_check("de dentro, a porta diz \"E para sair\"", hud.get_look_action() == "E para sair")
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
	player.rotation.y = PI  # vira para trás (sul): a porta "Casa" está ali
	await _frames(3)
	_check("virando para trás, a porta Casa está ali", hud.get_look_text().begins_with(plaza_door.door_name))

	await _check_loft(home, player)
	await _check_layouts(home, player)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## A fachada da porta "Casa" (HomeDoorFacade): lugar, folgas, sólida, néon e mapa.
func _check_facade(city: Node, door: Node3D) -> void:
	print("== Fachada da porta Casa na praça ==")
	var facade: Node3D = city.get_node("HomeDoorFacade")
	_check("a fachada fica na porta, virada para o mesmo lado",
			facade.global_transform.is_equal_approx(door.global_transform))
	var rect := _world_rect(facade, load("res://worlds/city/home_door_facade.gd").footprint())
	var plaza := Rect2(-14.0, -14.0, 28.0, 28.0)  # o quarteirão da praça
	_check("dentro da praça %s" % rect, plaza.encloses(rect))
	var fountain_gap := _rect_distance(rect, Vector2.ZERO) - 2.0  # a bacia tem 2 m de raio
	_check("longe do chafariz (%.1f m da bacia)" % fountain_gap, fountain_gap >= 3.0)
	var central: Node3D = city.get_node("Metro_0")
	var metro_rect := _world_rect(central, load("res://worlds/city/metro_entrance.gd").footprint())
	var metro_gap := _rects_distance(rect, metro_rect)
	_check("longe da estação Central (%.1f m)" % metro_gap, metro_gap >= 3.0)

	# Roda de amigos: de 1 a 40 amigos na praça, ninguém a menos de 1 m.
	var friend_gap := INF
	for total in range(1, 41):
		for i in total:
			var spot: Vector3 = city._plaza_friend_position(i, total)
			friend_gap = minf(friend_gap, _rect_distance(rect, Vector2(spot.x, spot.z)))
	_check("longe da roda de amigos, até 40 amigos (%.1f m)" % friend_gap, friend_gap >= 1.0)

	# Caminhos: os eixos do chafariz até as quatro ruas (5 m de largura; o de
	# norte a sul passa por onde se nasce) e a travessia ao sul do chafariz
	# (a linha z = 6 do teste de passos).
	var paths := {"eixo norte-sul": Rect2(-2.5, -14.0, 5.0, 28.0), "eixo leste-oeste": Rect2(-14.0, -2.5, 28.0, 5.0),
			"travessia ao sul do chafariz": Rect2(-14.0, 5.0, 28.0, 2.0)}
	for path_name: String in paths:
		_check("fora do caminho: %s" % path_name, not rect.intersects(paths[path_name]))

	# Nada sólido encosta no quiosque (floreiras, chafariz, estação) e nenhum poste perto.
	var space: PhysicsDirectSpaceState3D = facade.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x + 0.6, 2.0, rect.size.y + 0.6)
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, Vector3(rect.get_center().x, 1.2, rect.get_center().y))
	query.collision_mask = 1
	query.exclude = [facade.get_node("Body").get_rid()]
	var touching := space.intersect_shape(query, 4).size()
	_check("nada sólido a menos de 30 cm do quiosque (%d)" % touching, touching == 0)
	var light_gap := INF
	for node in city.find_children("*", "Node3D", true, false):
		if node.get_script() == null or node.get_script().get_global_name() != "StreetLight":
			continue
		light_gap = minf(light_gap, _rect_distance(rect, Vector2(node.global_position.x, node.global_position.z)))
	_check("longe dos postes (%.1f m)" % light_gap, light_gap >= 1.5)

	# Sólida: um raio da chegada até a porta bate no quiosque.
	var arrival: Vector3 = city.HOME_DOOR_ARRIVAL
	var ray := PhysicsRayQueryParameters3D.create(arrival + Vector3(0, 1.0, 0), door.global_position + Vector3(0, 1.0, 0))
	ray.collision_mask = 1
	var hit := space.intersect_ray(ray)
	_check("o quiosque é sólido", not hit.is_empty() and hit["collider"] == facade.get_node("Body"))
	var free := PhysicsShapeQueryParameters3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(0.8, 1.6, 0.8)
	free.shape = body_box
	free.transform = Transform3D(Basis.IDENTITY, arrival + Vector3(0, 1.0, 0))
	free.collision_mask = 1
	var front: Vector3 = door.global_basis.z
	var ahead := (arrival - door.global_position).dot(front)
	_check("a chegada fica livre, %.1f m na frente da porta" % ahead,
			space.intersect_shape(free, 1).is_empty() and ahead > 1.5 and ahead < 3.0)

	# Néon e luz: acendem à noite, apagam de dia.
	var neon: Label3D = facade.get_node("Neon")
	city._on_night_changed(0.0)
	var day_lamp: float = facade.get_lamp_energy()
	var day_neon := neon.modulate.get_luminance()
	city._on_night_changed(1.0)
	_check("à noite a luz da marquise acende (dia %.1f, noite %.1f)" % [day_lamp, facade.get_lamp_energy()],
			day_lamp == 0.0 and facade.get_lamp_energy() > 1.0)
	_check("à noite o néon CASA brilha mais", neon.modulate.get_luminance() > day_neon * 2.0)
	city._on_night_changed(city._day_night.get_night())

	# Mapa: um marco "home" na porta.
	var homes: Array = get_first_node_in_group("world_map").get_map_data()["landmarks"] \
			.filter(func(landmark: Dictionary) -> bool: return landmark["kind"] == "home")
	_check("a porta Casa é um marco no mapa", homes.size() == 1
			and (homes[0]["pos"] as Vector2).distance_to(Vector2(door.global_position.x, door.global_position.z)) < 0.1)


## O retângulo (x, z) do mundo ocupado por um retângulo local de um nó (girado
## só em Y): os quatro cantos levados ao mundo.
func _world_rect(node: Node3D, local: Rect2) -> Rect2:
	var rect := Rect2()
	for i in 4:
		var corner := Vector3(local.position.x + local.size.x * (i % 2), 0.0, local.position.y + local.size.y * floori(i / 2.0))
		var world := node.global_transform * corner
		if i == 0:
			rect = Rect2(Vector2(world.x, world.z), Vector2.ZERO)
		else:
			rect = rect.expand(Vector2(world.x, world.z))
	return rect


func _rect_distance(rect: Rect2, point: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(dx, dy).length()


func _rects_distance(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, 0.0), b.position.x - a.end.x)
	var dy := maxf(maxf(a.position.y - b.end.y, 0.0), b.position.y - a.end.y)
	return Vector2(dx, dy).length()


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


## As disposições dos móveis (13.4): para cada uma, trocar em jogo move os
## móveis, nada sai da sala, ninguém cobre a porta, a janela ou o outro, e há
## passagem livre até a frente de cada móvel (e até o ponto de volta da estante).
func _check_layouts(home: Node3D, player: CharacterBody3D) -> void:
	print("== Disposições dos móveis ==")
	var app = root.get_node("AppConfig")
	var original: String = app.get_home_layout()
	var catalog := Profiles.home_catalog()
	_check("o catálogo tem as 3 disposições", catalog.layouts.size() == 3)
	var room: Vector3 = home.ROOM_SIZE
	var inner := AABB(Vector3(-room.x / 2.0, 0.0, -room.z / 2.0), room).grow(0.03)
	# A porta da rua e a janela (coordenadas da casa).
	var door_zone := AABB(Vector3(-0.7, 0.0, 3.9), Vector3(1.4, 2.4, 0.8))
	var window_zone := AABB(Vector3(-2.7, 0.0, -4.6), Vector3(5.4, 3.4, 0.6))
	var shape: Shape3D = player.get_node("CollisionShape3D").shape
	var space := player.get_world_3d().direct_space_state
	var positions := {}
	for layout in catalog.layouts:
		app.set_home_layout(layout.id)
		await process_frame
		_check("[%s] a casa usa a disposição" % layout.id, home.get_layout() == layout)
		var boxes := {}
		for id in ["estante", "mural", "estatisticas"]:
			var piece: Node3D = home.get_furniture(id)
			var anchor: Transform3D = home.get_anchor_transform(layout.placements[id])
			_check("[%s] %s está na âncora %s" % [layout.id, id, layout.placements[id]],
					piece.position.is_equal_approx(anchor.origin) and piece.transform.basis.is_equal_approx(anchor.basis))
			positions["%s|%s" % [layout.id, id]] = piece.position
			var box := _bounds(piece, home)
			boxes[id] = box
			_check("[%s] %s fica dentro da sala" % [layout.id, id], inner.encloses(box))
			_check("[%s] %s não cobre a porta nem a janela" % [layout.id, id],
					not box.intersects(door_zone) and not box.intersects(window_zone))
		var desk_box := _bounds(home.get_node("ComputerDesk"), home)
		var ids: Array = boxes.keys()
		var overlap := false
		for i in ids.size():
			overlap = overlap or boxes[ids[i]].intersects(desk_box)
			for j in range(i + 1, ids.size()):
				overlap = overlap or boxes[ids[i]].intersects(boxes[ids[j]])
		_check("[%s] os móveis não se tocam, nem a mesa" % layout.id, not overlap)
		_check("[%s] o computador não saiu de norte_direita" % layout.id,
				home.get_node("ComputerDesk").position.is_equal_approx(home.get_anchor_transform("norte_direita").origin))
		# Passagem: do ponto de nascer, ao longo de x e depois de z, até 1,4 m na frente de cada móvel.
		var spawn := Vector2(home.SPAWN_SPOT.x, home.SPAWN_SPOT.z)
		for id in ["estante", "mural", "estatisticas"]:
			var anchor: Transform3D = home.get_anchor_transform(layout.placements[id])
			var front := anchor.origin + anchor.basis.z * 1.4
			var points: Array[Vector2] = [spawn, Vector2(front.x, spawn.y), Vector2(front.x, front.z)]
			_check("[%s] passagem livre até: %s" % [layout.id, id], _walk_is_free(home, space, shape, player, points))
		var back: Vector3 = home.to_local(home.get_furniture("estante").get_return_transform().origin)
		_check("[%s] o ponto de volta da estante está dentro e livre" % layout.id, inner.has_point(Vector3(back.x, 1.0, back.z))
				and _walk_is_free(home, space, shape, player, [Vector2(back.x, back.z), Vector2(back.x, back.z + 0.01)] as Array[Vector2]))
		var spawn_tf: Transform3D = home.get_spawn_transform()
		_check("[%s] o giro de quem nasce é o da disposição" % layout.id,
				absf(rad_to_deg(Basis(Vector3.UP, deg_to_rad(layout.spawn_turn_degrees)).get_euler().y - (home.global_basis.inverse() * spawn_tf.basis).get_euler().y)) < 0.5)
	_check("trocar a disposição moveu a estante", positions["padrao|estante"] != positions["espelhada|estante"]
			and positions["padrao|estante"] != positions["estante_na_entrada|estante"])
	app.set_home_layout("nao_existe")
	await process_frame
	_check("disposição desconhecida cai na padrão", home.get_layout() == catalog.layouts[0])
	app.set_home_layout(original)
	await process_frame


## Caixa de tudo o que o móvel desenha, em coordenadas da casa.
func _bounds(piece: Node3D, home: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh in _geometry(piece):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		box.position -= home.global_position
		result = box if first else result.merge(box)
		first = false
	return result


## O corpo do jogador anda de ponto em ponto (x, z da casa) sem bater em nada.
func _walk_is_free(home: Node3D, space: PhysicsDirectSpaceState3D, shape: Shape3D, player: CharacterBody3D, points: Array[Vector2]) -> bool:
	for i in points.size() - 1:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 1
		query.exclude = [player.get_rid()]
		query.transform = Transform3D(Basis.IDENTITY, home.to_global(Vector3(points[i].x, 1.05, points[i].y)))
		var step := points[i + 1] - points[i]
		query.motion = home.global_basis * Vector3(step.x, 0.0, step.y)
		if space.cast_motion(query)[0] < 1.0:
			return false
	return true


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
