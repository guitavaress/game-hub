extends SceneTree
## Teste da câmera em terceira pessoa (Fase 20.4). Guarda o config.cfg e
## devolve no fim.
##   - a visão volta do config.cfg ao criar o jogador (já pronta, sem passagem);
##   - V (toggle_view) alterna, grava no config.cfg e troca quais corpos a câmera
##     vê; a opção em Esc › Controles (settings_changed) troca na hora;
##   - durante a passagem, com o braço curto, a câmera não vê o corpo (nem a
##     cabeça por dentro);
##   - não alterna na abertura, na viagem, com painel aberto nem no foco;
##   - o braço encurta contra uma parede e a câmera não passa dela; colado
##     nela, o corpo some da câmera;
##   - o E acha o alvo na terceira pessoa, com o alcance medido do avatar, e o
##     que está entre a câmera e o avatar não conta;
##   - em casa o braço é mais curto e a câmera fica dentro da sala (paredes e
##     teto);
##   - na terceira pessoa o balanço de andar desliga (o pouso e o FOV ficam);
##   - o jeito "ombro" (padrão): o avatar fica de costas; andando para trás,
##     o passo toca ao contrário; o jeito "livre": o avatar vira para onde anda.

const CONFIG := "user://config.cfg"


## Alvo falso olhável que responde ao E (como o do check_interact).
class FakeTarget extends Area3D:
	var interacts: int = 0
	var title: String = "Alvo"

	func interact(_player: Node) -> void:
		interacts += 1

	func get_look_info() -> Dictionary:
		return {"title": title, "action": "E para testar"}


var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	for setter in ["set_home_theme", "set_home_layout", "set_home_wall_color", "set_home_neon_color"]:
		app.call(setter, "")
	app.set_camera_motion(true)
	# A visão volta do config.cfg: grava "third" antes de criar o jogador.
	app.set_view("third")
	load("res://tests/quiet_friends.gd").install(root)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	root.get_node("GameLauncher")._poll_timer.paused = true
	var player = city.get_node("Player")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var head: Node3D = player.get_node("Head")
	var avatar = player.get_avatar()
	var first = avatar.get_first_person_body()
	var full = avatar.get_full_body()
	var home = city.get_home()
	var outdoor: float = player.ARM_LENGTH_OUTDOOR
	var indoor: float = player.ARM_LENGTH_INDOOR
	var close: float = player.ARM_CLOSE

	# Um lugar aberto, sem nada em volta: um chão de mentira bem no alto (a 30 m
	# na frente, na cidade, sempre haveria um prédio ou um poste no caminho).
	var platform := _make_wall(city, Vector3(120.0, 0.4, 120.0))
	platform.global_position = Vector3(30.0, 99.8, 30.0)
	var open_spot := Transform3D(Basis.IDENTITY, Vector3(30.0, 100.1, 30.0))
	player.set_indoors(null)
	player.teleport_to(open_spot)
	await _frames(4)

	print("== a visão volta do config.cfg ==")
	_check("o jogador nasce na terceira pessoa, já pronta", player.get_view() == "third"
			and player.is_view_settled() and avatar.get_view() == "third")
	_check("o braço está esticado (%.2f m)" % player.get_arm_length(), absf(player.get_arm_length() - outdoor) < 0.05)
	_check("a câmera vê o corpo inteiro e não o de primeira pessoa",
			_seen(full, camera) and not first.visible)
	_check("a câmera está atrás do jogador, à direita e acima",
			_local_camera(player, camera).z > outdoor - 0.1 and _local_camera(player, camera).x > 0.2
			and camera.global_position.y > head.global_position.y)
	_check("o corpo faz a própria sombra", full.get_shadow_twin_layers() == 0
			and full.get_meshes().all(func(m: MeshInstance3D) -> bool: return m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON))

	print("== alternar (V) ==")
	_check("V passa para a primeira pessoa", player.toggle_view() and player.get_view() == "first")
	_check("e grava no config.cfg", app.get_view() == "first")
	var head_seen := false
	var samples := 0
	var frames := 0
	while not player.is_view_settled() and frames < 300:
		await process_frame
		frames += 1
		if player.get_arm_length() < close:
			samples += 1
			head_seen = head_seen or _seen(full, camera)
	_check("a passagem termina (%d quadros)" % frames, player.is_view_settled())
	_check("com o braço curto, a câmera não vê o corpo inteiro (%d quadros)" % samples, samples > 0 and not head_seen)
	await _frames(1)
	_check("primeira pessoa: o braço é 0 e a câmera está na cabeça", player.get_arm_length() == 0.0
			and camera.global_position.distance_to(head.global_position) < 0.05)
	_check("e vê o de primeira pessoa, e não o inteiro", first.visible and not _seen(full, camera))
	# Um V de verdade (evento da ação), e não só a função.
	var press := InputEventAction.new()
	press.action = "toggle_view"
	press.pressed = true
	root.push_input(press)
	await process_frame
	_check("o evento do V volta para a terceira", player.get_view() == "third" and app.get_view() == "third")
	head_seen = false
	samples = 0
	frames = 0
	while not player.is_view_settled() and frames < 300:
		await process_frame
		frames += 1
		if player.get_arm_length() < close:
			samples += 1
			head_seen = head_seen or _seen(full, camera) or _seen(first, camera)
	await _frames(1)
	_check("na ida também, com o braço curto, nenhum corpo aparece", samples > 0 and not head_seen)
	_check("terceira de novo: o inteiro visto", _seen(full, camera) and not first.visible)

	print("== a opção do menu ==")
	app.set_view("first")
	_check("Esc › Controles troca a visão na hora", player.get_view() == "first")
	app.set_view("third")
	_check("e volta", player.get_view() == "third")
	await _settle_view(player)

	print("== travas ==")
	player.get_pause_menu().open()
	await process_frame
	_check("com painel aberto, não alterna", not player.toggle_view() and player.get_view() == "third")
	root.push_input(press)
	await process_frame
	_check("nem pelo V", player.get_view() == "third")
	player.get_pause_menu().close()
	await process_frame
	player.start_intro()
	_check("na abertura, não alterna", not player.toggle_view() and player.get_view() == "third")
	player.finish_intro()
	player._traveling = true
	_check("na viagem, não alterna", not player.toggle_view() and player.get_view() == "third")
	player._traveling = false
	_check("o config.cfg ficou na terceira", app.get_view() == "third")

	print("== parede ==")
	var wall := _make_wall(city, Vector3(4.0, 4.0, 0.4))
	# A parede 1,5 m atrás do jogador (ele olha para -Z; o braço vai para +Z).
	wall.global_position = open_spot.origin + Vector3(0.0, 2.0, 1.5 + 0.2)
	await _frames(4)
	var wall_front: float = wall.global_position.z - 0.2
	_check("o braço encurta (%.2f m)" % player.get_arm_length(), player.get_arm_length() < 1.6 and player.get_arm_length() > close)
	_check("a câmera não passa da parede (%.2f < %.2f)" % [camera.global_position.z, wall_front],
			camera.global_position.z < wall_front - 0.05)
	_check("e o corpo continua visto", _seen(full, camera))
	wall.global_position = open_spot.origin + Vector3(0.0, 2.0, 0.45 + 0.2)
	await _frames(4)
	_check("colado na parede: braço curto (%.2f m)" % player.get_arm_length(), player.get_arm_length() < close)
	_check("e a câmera não vê o corpo (nem a cabeça por dentro)", not _seen(full, camera) and not _seen(first, camera))
	_check("a sombra continua", full.get_shadow_twin_layers() != 0)
	_check("a câmera continua do lado de cá", camera.global_position.z < wall.global_position.z - 0.2)
	wall.global_position = open_spot.origin + Vector3(0.0, 2.0, 30.0)
	await _frames(4)
	_check("sem a parede, o braço estica de novo", absf(player.get_arm_length() - outdoor) < 0.05 and _seen(full, camera))

	print("== o E na terceira pessoa ==")
	var target := _make_target(city, "Na frente")
	target.global_position = open_spot.origin + Vector3(0.0, 1.6, -3.0)
	await _frames(4)
	_check("o cartão mostra o alvo", player.get_hud().get_look_action() == "E para testar")
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)
	_check("o E chama interact", target.interacts == 1)
	# Atrás do jogador, entre ele e a câmera: não conta.
	var behind := _make_target(city, "Atrás")
	behind.global_position = open_spot.origin + Vector3(0.0, 1.6, 1.5)
	await _frames(4)
	_check("o que está entre a câmera e o avatar não conta", player._current_look_info.get("title", "") == "Na frente")
	behind.queue_free()
	var reach: float = player.look_distance
	target.global_position = open_spot.origin + Vector3(0.0, 1.6, -(reach - 1.0))
	await _frames(4)
	_check("a %.0f m do avatar (e %.0f da câmera), ainda acha" % [reach - 1.0, reach - 1.0 + outdoor],
			player._current_look_info.get("title", "") == "Na frente")
	target.global_position = open_spot.origin + Vector3(0.0, 1.6, -(reach + 0.5))
	await _frames(4)
	_check("a %.1f m do avatar, não acha (o alcance é o da primeira pessoa)" % (reach + 0.5),
			player._current_look_info.is_empty())
	target.queue_free()

	print("== balanço ==")
	var feel = player._camera_feel
	Input.action_press("move_forward")
	var bob_max := 0.0
	for i in 60:
		await process_frame
		bob_max = maxf(bob_max, Vector2(feel.get_offset().x, feel.get_offset().y).length())
	Input.action_release("move_forward")
	_check("andando na terceira pessoa, sem balanço (%.4f m)" % bob_max, bob_max < 0.001)
	player.teleport_to(open_spot)
	await create_timer(0.5).timeout

	print("== o jeito ombro (padrão) ==")
	_check("o padrão é o ombro", player.THIRD_PERSON_STYLE == player.STYLE_SHOULDER
			and player.third_person_style == player.STYLE_SHOULDER)
	_check("parado: o avatar de costas para a câmera", absf(avatar.rotation.y) < 0.01)
	Input.action_press("move_back")
	await create_timer(0.8).timeout
	var animation: AnimationPlayer = full.get_animation_player()
	_check("andando para trás: de costas, o passo ao contrário (%.2f)" % animation.speed_scale,
			absf(avatar.rotation.y) < 0.05 and animation.speed_scale < 0.0)
	Input.action_release("move_back")
	Input.action_press("move_right")
	await create_timer(0.8).timeout
	_check("andando de lado: vira para o lado (%.0f°), o passo para a frente" % rad_to_deg(avatar.rotation.y),
			absf(absf(avatar.rotation.y) - PI / 2.0) < 0.15 and animation.speed_scale > 0.0)
	Input.action_release("move_right")
	await create_timer(1.0).timeout
	_check("parou: de costas de novo", absf(avatar.rotation.y) < 0.05)

	print("== o jeito livre ==")
	player.third_person_style = player.STYLE_FREE
	player.teleport_to(open_spot)
	Input.action_press("move_right")
	await create_timer(0.8).timeout
	var walk: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
	var faces: Vector3 = full.global_basis.z.normalized()  # o corpo olha para +Z dele
	_check("o avatar vira para onde anda", faces.dot(walk) > 0.95)
	Input.action_release("move_right")
	await create_timer(0.8).timeout
	var kept: Vector3 = full.global_basis.z.normalized()
	player.look_by(Vector2(400.0, 0.0))
	await _frames(2)
	_check("parado, o mouse gira a câmera e o avatar fica", full.global_basis.z.normalized().dot(kept) > 0.99)
	player.third_person_style = player.STYLE_SHOULDER
	player.teleport_to(open_spot)
	await _frames(2)

	print("== em casa ==")
	player.teleport_to(home.get_spawn_transform())
	player.set_indoors(home.get_environment())
	await _frames(6)
	_check("o braço é mais curto (%.2f m, no máximo %.1f)" % [player.get_arm_length(), indoor],
			player.get_arm_length() <= indoor + 0.01 and indoor < outdoor)
	var size: Vector3 = home.ROOM_SIZE
	_check("a câmera fica dentro da sala", _inside_room(home, camera.global_position, size))
	head.rotation.x = deg_to_rad(-65.0)  # olhando para baixo: o braço sobe para o teto
	await _frames(4)
	var ceiling: float = home.global_position.y + size.y
	_check("olhando para baixo, a câmera fica abaixo do teto (%.2f < %.2f)" % [camera.global_position.y, ceiling],
			camera.global_position.y < ceiling - 0.05)
	head.rotation.x = deg_to_rad(-89.0)
	await _frames(2)
	_check("o limite para olhar para baixo é menor (%.0f°)" % rad_to_deg(head.rotation.x),
			absf(rad_to_deg(head.rotation.x)) <= player.THIRD_MAX_PITCH_DEGREES + 0.1)
	head.rotation.x = 0.0
	# De costas para a parede do sul (a da porta fica à direita dela).
	var against: Vector3 = home.to_global(Vector3(-1.0, 0.1, size.z / 2.0 - 0.5))
	player.teleport_to(Transform3D(home.global_basis, against))
	await _frames(4)
	_check("de costas para a parede, a câmera não sai da sala", _inside_room(home, camera.global_position, size))

	print("== espelho e foco ==")
	var mirror = home.get_furniture("espelho")
	var normal: Vector3 = mirror.get_normal()
	var feet: Vector3 = mirror.global_position + normal * 3.2
	feet.y = home.global_position.y + 0.1
	player.teleport_to(Transform3D(Basis.looking_at(-normal), feet))
	await _frames(6)
	_check("a 3,2 m do espelho (a câmera mais longe), ele desenha", mirror.is_active())
	feet = mirror.global_position + normal * 1.8
	feet.y = home.global_position.y + 0.1
	player.teleport_to(Transform3D(Basis.looking_at(-normal), feet))
	await _frames(4)
	player.focus_on(mirror)
	await create_timer(0.6).timeout
	_check("no foco, não alterna", player.is_focused() and not player.toggle_view() and player.get_view() == "third")
	player.leave_focus(true)
	await _frames(2)
	var rest: Transform3D = head.global_transform * player._view_rest()
	_check("saindo do foco, a câmera volta para a ponta do braço",
			camera.global_position.distance_to(rest.origin) < 0.05 and player.get_arm_length() > close)

	print("== de volta à primeira pessoa ==")
	player.toggle_view()
	await _settle_view(player)
	_check("primeira pessoa em casa: o inteiro sai da câmera", first.visible and not _seen(full, camera))
	_check("e o braço para", player.get_camera_arm().process_mode == Node.PROCESS_MODE_DISABLED)

	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## A câmera vê este corpo? (visível e numa camada que ela enxerga)
func _seen(body: Node3D, camera: Camera3D) -> bool:
	if not body.is_visible_in_tree():
		return false
	for mesh: MeshInstance3D in body.get_meshes():
		if mesh.is_visible_in_tree() and mesh.layers & camera.cull_mask != 0 \
				and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			return true
	return false


## A posição da câmera no espaço do jogador (+Z = para trás, +X = à direita).
func _local_camera(player: Node3D, camera: Camera3D) -> Vector3:
	return player.global_transform.affine_inverse() * camera.global_position


func _inside_room(home: Node3D, point: Vector3, size: Vector3) -> bool:
	var local: Vector3 = home.to_local(point)
	return absf(local.x) < size.x / 2.0 and absf(local.z) < size.z / 2.0 and local.y > 0.0 and local.y < size.y


## Uma parede de mentira (camada 1, a do mundo).
func _make_wall(parent: Node, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	parent.add_child(wall)
	return wall


func _make_target(parent: Node, title: String) -> FakeTarget:
	var target := FakeTarget.new()
	target.title = title
	target.collision_layer = 4
	target.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, 0.5)
	shape.shape = box
	target.add_child(shape)
	parent.add_child(target)
	return target


func _settle_view(player: Node) -> void:
	var frames := 0
	while not player.is_view_settled() and frames < 300:
		await process_frame
		frames += 1
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
