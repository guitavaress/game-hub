extends SceneTree
## Teste do mirante como destino (Fase 17.8), com 200 jogos falsos (o RPG tem
## jogos). Confere:
##   - os modelos do Blender carregam (uma malha por material) e cabem no orçamento;
##   - o deque cobre o disco (raios para baixo dão "wood" na altura do piso),
##     fora do lugar da torre;
##   - o abrigo, a fogueira (luz com sombra), os bancos e as lanternas (luz sem
##     sombra, poucas) existem e acendem à noite;
##   - a luneta fica no deque, virada para a praça, e E entra no foco (a câmera
##     anda para a cidade, o campo da luneta aparece); Esc e E voltam;
##   - o RPG mais jogado fica na tapeçaria, com o nome embaixo; sem jogos, sem
##     destaque;
##   - nada trava o caminho: o jogador anda da trilha até o meio do deque e
##     de lá até a luneta;
##   - sem a plataforma (como na biblioteca de verdade), a luneta e o abrigo
##     ainda acham lugar no disco, fora dos caminhos;
##   - poucos desenhos no mirante.
## (Scripts que usam autoloads vão por load(), sem o nome da classe.)
var failures: int = 0
var _deck_script: GDScript = load("res://worlds/city/biome/lookout_deck.gd")
var _space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 200, false, true)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await physics_frame
	await physics_frame
	_space = city.get_world_3d().direct_space_state
	var terrain = get_first_node_in_group("mountain_trail")
	var deck: Node3D = terrain.get_deck() if terrain != null else null
	_check("o mirante existe", deck != null)
	if deck == null:
		_finish()
		return
	var field: Heightfield = terrain.field
	var trail: MountainTrail = terrain.trail
	var layout: Dictionary = deck.get_layout()

	_check_models()
	_check_floor(deck, field, trail)
	_check_camp(deck, layout)
	await _check_telescope(city, deck, layout, field)
	_check_highlight(terrain, deck)
	await _check_walk(city, deck, field, trail, layout)
	_check_without_platform(field, trail)
	var meshes := 0
	for node in deck.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
	print("   %d desenhos no mirante" % meshes)
	_check("poucos desenhos no mirante (um por material em cada peça: até 18)", meshes <= 18)
	_finish()


func _check_models() -> void:
	print("\n== os modelos do Blender ==")
	var parts := {"lookout/deck": ["plank_0", "plank_1", "plank_2", "plank_3", "post", "handrail", "board", "beam"],
		"lookout/shelter": ["wood", "snow", "iron"], "lookout/lantern": ["iron", "glass"],
		"lookout/telescope": ["brass", "iron"]}
	var loaded := true
	for file: String in parts:
		for part: String in parts[file]:
			var mesh := TrailModels.mesh(file, part)
			if mesh == null or mesh.get_surface_count() != 1 or mesh.surface_get_array_len(0) == 0:
				print("   faltou: %s/%s" % [file, part])
				loaded = false
	_check("os modelos do mirante carregam (uma malha por material)", loaded)
	var wood := TrailModels.mesh("lookout/deck", "plank_0").surface_get_arrays(0)
	_check("as tábuas têm o veio no UV e a cor dos vértices", wood[Mesh.ARRAY_TEX_UV] != null and wood[Mesh.ARRAY_COLOR] != null)
	var budget := true
	for file: String in parts:
		var size := FileAccess.open("res://assets/models/%s.glb" % file, FileAccess.READ).get_length()
		print("   %s.glb: %d KB" % [file, size / 1024])
		if size > 800 * 1024:
			budget = false
	_check("cada .glb cabe no orçamento (até 800 KB)", budget)
	# Esticar uma peça mantém as normais de pé (unitárias) e o tamanho pedido.
	var board := TrailModels.mesh("lookout/deck", "board")
	var long := TrailModels.stretched(board, Vector3(2.5, 1.0, 1.0))
	var normals: PackedVector3Array = long.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var unit := true
	for n in normals:
		if absf(n.length() - 1.0) > 0.01:
			unit = false
	_check("uma peça esticada tem o tamanho pedido e as normais unitárias",
			unit and absf(long.get_aabb().size.x - board.get_aabb().size.x * 2.5) < 0.01)


func _check_floor(deck: Node3D, field: Heightfield, trail: MountainTrail) -> void:
	print("\n== o deque ==")
	var where = _deck_script.site(field, trail)
	var top: float = _deck_script.deck_top(field)
	var rays := 0
	var wood := 0
	var level := 0
	for k in 48:
		for radius: float in [2.0, 4.5, 7.0, 8.6]:
			var p := trail.lookout_center + Heightfield.direction_of(TAU * k / 48.0 + radius) * radius
			if not where.covers(p):
				continue
			rays += 1
			var hit := _ray(Vector3(p.x, top + 3.0, p.y), Vector3(p.x, top - 1.0, p.y))
			if hit.is_empty():
				continue
			if hit["collider"].get_meta("footstep", "") == "wood":
				wood += 1
			if absf(hit["position"].y - top) < 0.015:
				level += 1
	print("   %d raios no deque: %d na madeira, %d na altura do piso" % [rays, wood, level])
	# Os raios que caem no abrigo, na fogueira ou na luneta param antes: contam só os da madeira.
	_check("o deque cobre o disco (raios no piso: madeira)", rays > 120 and wood >= rays * 0.85)
	_check("e o piso fica na altura do deque (±1,5 cm)", level >= rays * 0.85)
	var room: PackedVector2Array = where.holes[0]
	_check("o piso tem um buraco para a torre", room.size() == 4
			and Geometry2D.is_point_in_polygon(where.local(trail.lookout_center + trail.lookout_center.normalized() * 4.5), room))
	_check("e o piso é um desenho só, sem sombra", deck.get_node_or_null("Planks0") != null
			and deck.get_node_or_null("Planks1") == null
			and (deck.get_node("Planks0") as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func _check_camp(deck: Node3D, layout: Dictionary) -> void:
	print("\n== o abrigo, a fogueira e as lanternas ==")
	_check("o abrigo e a fogueira acharam lugar", layout["has_camp"] and deck.get_shelter() != null
			and deck.get_campfire() != null)
	if not layout["has_camp"]:
		return
	var fire: Campfire = deck.get_campfire()
	_check("a fogueira é a luz principal: com sombra", fire.light.shadow_enabled)
	var shelter: Node3D = deck.get_shelter()
	var front := shelter.global_basis.z
	var to_fire: Vector3 = (fire.global_position - shelter.global_position).normalized()
	_check("a fogueira fica na frente do abrigo", front.dot(to_fire) > 0.95)
	_check("dois bancos em volta do fogo", (layout["benches"] as Array).size() == 2)
	_check("o abrigo, o fogo e os bancos têm colisão", shelter.get_node_or_null("ShelterBody") != null
			and fire.get_node_or_null("FireBody") != null)
	var lights: Array = deck.get_lantern_lights()
	_check("lanternas: entre 4 e 6, nenhuma com sombra (%d)" % lights.size(), lights.size() >= 4 and lights.size() <= 6
			and lights.all(func(l: OmniLight3D) -> bool: return not l.shadow_enabled))
	deck.set_night(1.0)
	_check("à noite, as lanternas e o fogo acendem", lights.all(func(l: OmniLight3D) -> bool: return l.visible)
			and fire.light.visible)
	deck.set_night(0.0)
	_check("de dia, apagados", lights.all(func(l: OmniLight3D) -> bool: return not l.visible) and not fire.light.visible)


func _check_telescope(city: Node, deck: Node3D, layout: Dictionary, field: Heightfield) -> void:
	print("\n== a luneta ==")
	var scope: Node3D = deck.get_telescope()
	_check("a luneta existe, no lugar do plano", scope != null
			and scope.global_position.is_equal_approx((layout["telescope"] as Transform3D).origin))
	if scope == null:
		return
	var p := scope.global_position
	var hit := _ray(Vector3(p.x + 0.35, p.y + 3.0, p.z), Vector3(p.x + 0.35, p.y - 1.0, p.z))
	_check("e fica em cima do deque", not hit.is_empty() and hit["collider"].get_meta("footstep", "") == "wood")
	var aim := -Vector2(scope.global_basis.z.x, scope.global_basis.z.z).normalized()
	var to_plaza := (-Vector2(p.x, p.z)).normalized()
	_check("virada para a praça", aim.dot(to_plaza) > 0.99)
	_check("o cartão diz o que o E faz", String(scope.get_look_info().get("action", "")).contains("{interact}"))

	var player = city.get_node("Player")
	player.set_indoors(null)
	var stand: Vector2 = layout["stand"]
	player.teleport_to(Transform3D(Basis.looking_at(Vector3(aim.x, 0.0, aim.y)), Vector3(stand.x, p.y + 0.1, stand.y)))
	for i in 5:
		await physics_frame
	var eye: Vector3 = scope.to_global(scope.EYEPIECE)
	var pose: Transform3D = scope.get_camera_pose(75.0, 16.0 / 9.0)
	var target: Vector3 = scope.target
	_check("no foco, a câmera chega mais perto da cidade (%.0f m → %.0f m)" % [eye.distance_to(target), pose.origin.distance_to(target)],
			pose.origin.distance_to(target) < eye.distance_to(target) * 0.7
			and (-pose.basis.z).dot((target - pose.origin).normalized()) > 0.99)
	scope.interact(player)
	await process_frame
	_check("E entra no foco da luneta", player.is_focused() and player.get_focused_screen() == scope)
	_check("e o campo da luneta aparece", scope.is_focused() and scope.get_overlay() != null)
	await create_timer(0.8).timeout
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await create_timer(1.0).timeout
	_check("Esc volta para o mirante", not player.is_focused() and not scope.is_focused() and scope.get_overlay() == null)
	scope.interact(player)
	await create_timer(0.8).timeout
	var key := InputEventAction.new()
	key.action = "interact"
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(1.0).timeout
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	_check("E também volta", not player.is_focused())


func _check_highlight(terrain: Node, deck: Node3D) -> void:
	print("\n== o RPG mais jogado ==")
	var dressing: Node = terrain.get_dressing()
	var library: Node = root.get_node("SteamLibrary")
	var games: Array = terrain.get_parent().get("_backdrop_games")
	var best_id := 0
	var best_minutes := -2
	for game: SteamGame in games:
		var minutes: int = library.get_playtime_minutes(game.app_id)
		if minutes > best_minutes or minutes == best_minutes and game.app_id > best_id:
			best_minutes = minutes
			best_id = game.app_id
	print("   %d jogos de RPG; o mais jogado: %d (%d min)" % [games.size(), best_id, best_minutes])
	_check("a tapeçaria mostra o RPG mais jogado", games.size() > 0 and deck.get_highlight_id() == best_id
			and deck.get_shelter().get_node_or_null("Tapestry") != null)
	_check("com o nome embaixo", deck.get_plaque_text().begins_with(_name_of(games, best_id)))
	dressing.set_games([])
	_check("sem jogos de RPG, sem destaque", deck.get_highlight_id() == 0)
	dressing.set_games(games)
	_check("e o destaque volta com os jogos", deck.get_highlight_id() == best_id)


func _name_of(games: Array, id: int) -> String:
	for game: SteamGame in games:
		if game.app_id == id:
			return game.name
	return "?"


## O jogador anda da trilha até o meio do deque e de lá até a luneta (física
## de verdade, entrada simulada).
func _check_walk(city: Node, deck: Node3D, field: Heightfield, trail: MountainTrail, layout: Dictionary) -> void:
	print("\n== nada trava o caminho ==")
	var player = city.get_node("Player")
	var last := trail.points.size() - 1
	var start := trail.points[last - 8]
	var top: float = _deck_script.deck_top(field)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(start.x, field.surface_at(start) + 0.2, start.y)))
	for i in 10:
		await physics_frame
	var center := trail.lookout_center
	var route: Array[Vector2] = [trail.points[last - 4], trail.points[last], center, layout["stand"]]
	var reached := 0
	Input.action_press("move_forward")
	for goal in route:
		for frame in 60 * 6:
			await physics_frame
			var here := Vector2(player.global_position.x, player.global_position.z)
			var to_goal := goal - here
			if to_goal.length() < 0.5:
				reached += 1
				break
			player.rotation.y = atan2(-to_goal.x, -to_goal.y)
	Input.action_release("move_forward")
	await physics_frame
	print("   chegou a %d de %d pontos; altura no fim %.2f (o piso: %.2f)" % [reached, route.size(), player.global_position.y, top])
	_check("da trilha ao meio do deque e até a luneta, sem travar", reached == route.size())
	_check("e o jogador fica em cima do piso", absf(player.global_position.y - top) < 0.1)


## Sem a plataforma (a trilha chega pela frente, como na biblioteca de verdade):
## a mesma montanha, com a plataforma desligada nas contas.
func _check_without_platform(field: Heightfield, trail: MountainTrail) -> void:
	print("\n== sem a plataforma ==")
	var where = _deck_script.site(field, trail)
	where.along = Vector2.ZERO
	where.view = -trail.lookout_center.normalized()
	var center := trail.lookout_center
	where.frame = Transform3D(Basis.looking_at(Vector3(where.view.x, 0.0, where.view.y)),
			Vector3(center.x, _deck_script.deck_top(field), center.y))
	where.inverse = where.frame.affine_inverse()
	where.outline = _deck_script._floor_outline(where)
	where.holes.clear()
	where.holes.append(_deck_script._tower_room(where, _deck_script.TOWER_HOLE_HALF - _deck_script.TOWER_ROOM_HALF))
	where.holes.append_array(_deck_script._arrival_cut(where))
	where.room = _deck_script._tower_room(where, 0.3)
	var layout: Dictionary = _deck_script.layout(where)
	var spot: Vector3 = (layout["telescope"] as Transform3D).origin
	_check("a luneta fica no disco, no deque", Vector2(spot.x, spot.z).distance_to(center) < _deck_script.FLOOR_RADIUS
			and where.covers(Vector2(spot.x, spot.z)))
	_check("o abrigo e a fogueira acham lugar", layout["has_camp"])
	if not layout["has_camp"]:
		return
	var lanes: Array = layout["lanes"]
	var fire: Vector3 = layout["fire"]
	var clear := true
	for i in range(0, lanes.size(), 2):
		var a := Vector2(lanes[i].x, lanes[i].y)
		var b := Vector2(lanes[i + 1].x, lanes[i + 1].y)
		if _deck_script._segment_distance(Vector2(fire.x, fire.z), a, b) < lanes[i].z + _deck_script.CAMP_RADIUS - 0.01:
			clear = false
	_check("a fogueira fica fora dos caminhos", clear)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


func _finish() -> void:
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
