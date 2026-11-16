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
## Fase 20.5 (o que depende da visão):
##   - a camada só da câmera (CameraBlock, a 4): o braço bate nela, o jogador
##     e o raio do olhar não; as árvores têm volume de copa e as luminárias
##     penduradas da casa também;
##   - teleporte: a câmera chega no lugar certo já no primeiro quadro (sem
##     passar de uma parede, sem o braço preso curto);
##   - a porta carregando na terceira pessoa (FOV e avanço);
##   - os passos: um som por pé no chão, no ponto de contato da animação;
##   - foco nas duas visões (uma "luneta" falsa, o computador e o provador):
##     indo e voltando, a câmera nunca vê o corpo de perto; na pose o corpo
##     some (no provador, fica parado e à vista); volta ao repouso da visão
##     sem pulo; um jogo abrindo no foco deixa tudo no lugar;
##   - entrar e sair de casa: o braço muda aos poucos; far, HUD e som de casa.

const CONFIG := "user://config.cfg"


## Alvo falso olhável que responde ao E (como o do check_interact).
class FakeTarget extends Area3D:
	var interacts: int = 0
	var title: String = "Alvo"

	func interact(_player: Node) -> void:
		interacts += 1

	func get_look_info() -> Dictionary:
		return {"title": title, "action": "E para testar"}


## Uma "tela" falsa que segue o contrato do foco (como a luneta: a pose fica
## na frente do jogador, longe dele).
class FakeScreen extends Node3D:
	var pose: Transform3D
	var focused: bool = false

	func get_camera_pose(_fov: float, _aspect: float) -> Transform3D:
		return pose

	func set_focused(on: bool, _player: Node = null) -> void:
		focused = on


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
	# 20.5: encostado, o braço fica com ~0,37 m (a cápsula não deixa chegar
	# mais perto) e o corpo continua à vista: a câmera sai do ombro, longe da
	# cabeça (antes, com ARM_CLOSE de 0,5, ele sumia).
	_check("colado na parede: braço curto (%.2f m), mas acima de ARM_CLOSE (%.2f)" % [player.get_arm_length(), close],
			player.get_arm_length() < 0.5 and player.get_arm_length() > close)
	_check("e o corpo continua à vista, com a câmera longe da cabeça (%.2f m)" % camera.global_position.distance_to(head.global_position),
			_seen(full, camera) and camera.global_position.distance_to(head.global_position) > 0.35)
	_check("a câmera continua do lado de cá", camera.global_position.z < wall.global_position.z - 0.2)
	# Um volume só da câmera colado no ombro: o braço fica abaixo de ARM_CLOSE.
	var tight := CameraBlock.make_body("TightBlock")
	var tight_shape := CollisionShape3D.new()
	tight_shape.shape = BoxShape3D.new()
	(tight_shape.shape as BoxShape3D).size = Vector3(4.0, 4.0, 0.2)
	tight.add_child(tight_shape)
	city.add_child(tight)
	tight.global_position = open_spot.origin + Vector3(0.0, 2.0, 0.25)
	await create_timer(0.3).timeout
	await _frames(4)
	_check("sem espaço nenhum: braço mais curto que ARM_CLOSE (%.2f m)" % player.get_arm_length(), player.get_arm_length() < close)
	_check("e a câmera não vê o corpo (nem a cabeça por dentro)", not _seen(full, camera) and not _seen(first, camera))
	_check("a sombra continua", full.get_shadow_twin_layers() != 0)
	tight.queue_free()
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

	print("== a camada só da câmera (20.5) ==")
	var block_mask: int = CameraBlock.mask()
	_check("a camada é a 4, com nome no project.godot", CameraBlock.LAYER == 4 and block_mask == 1 << 3
			and str(ProjectSettings.get_setting("layer_names/3d_physics/layer_4", "")) == "so_camera")
	_check("o braço bate nela", player.get_camera_arm().collision_mask & block_mask != 0
			and player.get_camera_arm().collision_mask & 1 != 0)
	var look_ray: RayCast3D = camera.get_node("LookRay")
	_check("o jogador e o raio do olhar, não", player.collision_mask & block_mask == 0
			and look_ray.collision_mask & block_mask == 0)
	var block := CameraBlock.make_body("TestBlock")
	var block_shape := CollisionShape3D.new()
	block_shape.shape = BoxShape3D.new()
	(block_shape.shape as BoxShape3D).size = Vector3(4.0, 4.0, 0.4)
	block.add_child(block_shape)
	city.add_child(block)
	block.global_position = open_spot.origin + Vector3(0.0, 2.0, 1.5 + 0.2)
	# Folga: numa rodada em cinco, 4 quadros não bastaram para a física pôr o
	# corpo novo no lugar (criado e movido agora; os do mundo nascem prontos).
	await create_timer(0.3).timeout
	await _frames(4)
	_check("um volume dela atrás: o braço encurta (%.2f m)" % player.get_arm_length(),
			player.get_arm_length() < 1.6 and camera.global_position.z < block.global_position.z - 0.2)
	Input.action_press("move_back")
	await create_timer(0.7).timeout
	Input.action_release("move_back")
	_check("e o jogador atravessa o volume andando (z %.1f > %.1f)" % [player.global_position.z, block.global_position.z],
			player.global_position.z > block.global_position.z + 0.5)
	block.queue_free()
	var crowns := 0
	var crown_layer_ok := true
	var crown_hit := false
	for trees: Node in city.find_children("*", "TreeModel", true, false):
		crowns += trees.get_camera_block_count()
		for body: Node in trees.find_children("CameraBlock", "StaticBody3D", true, false):
			crown_layer_ok = crown_layer_ok and (body as StaticBody3D).collision_layer == block_mask \
					and (body as StaticBody3D).collision_mask == 0
		var list: Array[Transform3D] = trees.get_transforms()
		if not crown_hit and not list.is_empty():
			# Um raio de cima para baixo no meio da copa da 1ª árvore acerta o volume.
			var top: Vector3 = (trees as Node3D).global_transform * list[0].origin
			var height: float = trees.model_height() * list[0].basis.get_scale().y
			var query := PhysicsRayQueryParameters3D.create(top + Vector3.UP * (height + 2.0), top + Vector3.UP * 0.1, block_mask)
			crown_hit = not city.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	_check("as árvores têm volume de copa (%d), só nesta camada" % crowns, crowns > 50 and crown_layer_ok)
	_check("e o raio de cima acerta a copa", crown_hit)
	# Pela camada (os pendentes têm o mesmo nome; a Godot renomeia os repetidos).
	var lamps: Array[Node] = home.find_children("*", "StaticBody3D", true, false).filter(
			func(b: Node) -> bool: return (b as StaticBody3D).collision_layer == block_mask)
	_check("as luminárias penduradas da casa têm volume (%d)" % lamps.size(), lamps.size() >= 3)
	player.teleport_to(open_spot)
	await _frames(4)

	print("== teleporte (20.5) ==")
	var far_spot := Transform3D(Basis.IDENTITY, open_spot.origin + Vector3(20.0, 0.0, 0.0))
	var near_wall := _make_wall(city, Vector3(4.0, 4.0, 0.4))
	near_wall.global_position = far_spot.origin + Vector3(0.0, 2.0, 1.2 + 0.2)
	await _frames(4)
	_check("antes: o braço esticado (%.2f m)" % player.get_arm_length(), absf(player.get_arm_length() - outdoor) < 0.05)
	player.teleport_to(far_spot)
	_check("logo depois do teleporte, a câmera já não passa da parede (%.2f < %.2f)" % [camera.global_position.z, near_wall.global_position.z - 0.2],
			camera.global_position.z < near_wall.global_position.z - 0.2)
	await process_frame
	_check("e no primeiro quadro também", camera.global_position.z < near_wall.global_position.z - 0.2)
	player.teleport_to(open_spot)
	await process_frame
	_check("de volta ao aberto: o braço não fica preso curto (%.2f m)" % player.get_arm_length(),
			absf(player.get_arm_length() - outdoor) < 0.05)
	near_wall.queue_free()
	await _frames(2)

	print("== a porta carregando (20.5) ==")
	var fade = root.get_node("ScreenFade")
	var base_fov: float = camera.fov
	var resting: Vector3 = _local_camera(player, camera)
	fade.set_door_charge(1.0, "Teste", Color.WHITE, "")
	await _frames(3)
	var charged: Vector3 = _local_camera(player, camera)
	_check("carregando: o FOV fecha (%.1f → %.1f)" % [base_fov, camera.fov], camera.fov < base_fov - 5.0)
	_check("e a câmera avança (%.2f m)" % (resting.z - charged.z), resting.z - charged.z > 0.08 and _seen(full, camera))
	fade.set_door_charge(0.0)
	await _frames(3)
	_check("soltou: tudo volta", absf(camera.fov - base_fov) < 0.5 and _local_camera(player, camera).distance_to(resting) < 0.02)

	print("== os passos casam com o pé (20.5) ==")
	var before: int = player.steps_played
	var off_beat := 0
	var counted := 0
	Input.action_press("move_forward")
	await create_timer(0.5).timeout
	before = player.steps_played
	for i in 120:
		await physics_frame
		if player.steps_played != before:
			counted += player.steps_played - before
			before = player.steps_played
			var anim: AnimationPlayer = full.get_animation_player()
			var phase: float = fposmod(anim.current_animation_position / anim.current_animation_length, 1.0)
			var contacts: Array = avatar.STEP_CONTACTS.get(String(anim.current_animation), [])
			var near := contacts.any(func(c: float) -> bool: return absf(wrapf(phase - c, -0.5, 0.5)) < 0.12)
			if not near:
				off_beat += 1
	Input.action_release("move_forward")
	# A 5 m/s toca o Run a ~1,3: um pé no chão a cada ~0,24 s (antes: um som a cada 2,2 m = 0,44 s).
	_check("andando 2 s: %d passos (um por pé no chão)" % counted, counted >= 6 and counted <= 11)
	_check("cada som cai com o pé no chão (%d fora)" % off_beat, off_beat == 0)
	player.teleport_to(open_spot)
	await create_timer(0.5).timeout

	print("== foco nas duas visões (20.5) ==")
	var fake := FakeScreen.new()
	city.add_child(fake)
	fake.pose = Transform3D(Basis.IDENTITY, open_spot.origin + Vector3(0.4, 1.6, -5.0))
	await _focus_round(player, fake, "third", "luneta (falsa)")
	await _focus_round(player, fake, "first", "luneta (falsa)")
	player.toggle_view()
	await _settle_view(player)
	# Um jogo abre no meio do caminho (leave_focus(true)).
	player.focus_on(fake)
	await create_timer(0.15).timeout
	player.leave_focus(true)
	await _frames(2)
	var rest_now: Transform3D = head.global_transform * player._view_rest()
	_check("jogo abrindo no foco: a câmera volta já para a ponta do braço",
			not player.is_focused() and camera.global_position.distance_to(rest_now.origin) < 0.05)
	_check("e o corpo volta a aparecer", _seen(full, camera) and not avatar.is_hidden())
	fake.queue_free()

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

	print("== entrar e sair de casa: o braço muda aos poucos (20.5) ==")
	player.teleport_to(open_spot)
	await _frames(4)
	player.set_indoors(home.get_environment())
	await _frames(3)
	var mid: float = player.get_arm_length()
	_check("logo depois de entrar, o braço ainda está encolhendo (%.2f m)" % mid, mid > indoor + 0.1 and mid < outdoor - 0.01)
	_check("o far da câmera, o HUD e o som abafado são os de casa",
			camera.far == player.INDOOR_CAMERA_FAR and player.get_hud()._indoors and _ambience_muffled())
	await create_timer(0.7).timeout
	_check("e chega ao de casa (%.2f m)" % player.get_arm_length(), absf(player.get_arm_length() - indoor) < 0.02)
	player.set_indoors(null)
	await _frames(3)
	_check("saindo, ele estica aos poucos (%.2f m)" % player.get_arm_length(),
			player.get_arm_length() > indoor + 0.01 and player.get_arm_length() < outdoor - 0.1)
	_check("e o resto volta ao de fora", camera.far > player.INDOOR_CAMERA_FAR and not player.get_hud()._indoors
			and not _ambience_muffled())
	await create_timer(0.7).timeout
	_check("até o de fora (%.2f m)" % player.get_arm_length(), absf(player.get_arm_length() - outdoor) < 0.02)

	print("== em casa ==")
	player.teleport_to(home.get_spawn_transform())
	player.set_indoors(home.get_environment())
	await create_timer(0.7).timeout
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

	print("== o computador e o provador nas duas visões (20.5) ==")
	var fixture = load("res://tests/settings_screen.gd").install(home)
	var desk_front: Vector3 = fixture.screen.global_position + fixture.screen.global_basis.z * 1.6
	desk_front.y = home.global_position.y + 0.1
	player.teleport_to(Transform3D(Basis.looking_at(-fixture.screen.global_basis.z), desk_front))
	await _frames(4)
	await _focus_round(player, fixture.screen, "third", "computador")
	await _focus_round(player, fixture.screen, "first", "computador")
	player.teleport_to(Transform3D(Basis.looking_at(-normal), feet))
	await _frames(4)
	await _focus_round(player, mirror, "first", "provador", true)
	await _focus_round(player, mirror, "third", "provador", true)

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


## Uma volta de foco (indo, na pose, voltando) numa visão. Confere: a câmera
## chega na pose e volta ao repouso DA VISÃO, sem pulo; perto do corpo, a
## câmera nunca o vê (nem a cabeça por dentro); na primeira pessoa o corpo não
## aparece no foco; "posed" (o provador): o inteiro fica parado e à vista.
func _focus_round(player: Node, target: Node3D, view: String, label: String, posed: bool = false) -> void:
	if player.get_view() != view:
		player.toggle_view()
		await _settle_view(player)
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var head: Node3D = player.get_node("Head")
	var avatar = player.get_avatar()
	var full = avatar.get_full_body()
	var first = avatar.get_first_person_body()
	var tag := "%s, %s pessoa" % [label, "1ª" if view == "first" else "3ª"]
	player.focus_on(target)
	var bad := 0
	var frames := 0
	while player._slide_t < 1.0 and frames < 120:
		await process_frame
		frames += 1
		bad += _body_too_close(player, camera, full, first, view, posed)
	await _frames(2)
	var window := Vector2(camera.get_viewport().get_visible_rect().size)
	var pose: Transform3D = target.get_camera_pose(camera.fov, window.x / maxf(window.y, 1.0))
	_check("%s: a câmera chega na pose (%d quadros)" % [tag, frames], player.is_focused()
			and camera.global_position.distance_to(pose.origin) < 0.05)
	if posed:
		_check("%s: o corpo parado e à vista" % tag, avatar.is_posed() and _seen(full, camera) and not first.visible)
	else:
		_check("%s: na pose, o corpo some" % tag, not _seen(full, camera) and not _seen(first, camera))
	_check("%s: no foco, não troca de visão" % tag, not player.toggle_view() and player.get_view() == view)
	player.leave_focus()
	var last := camera.global_position
	frames = 0
	while player.is_focused() and frames < 120:
		await process_frame
		frames += 1
		if player.is_focused():
			last = camera.global_position
			bad += _body_too_close(player, camera, full, first, view, posed and avatar.is_posed())
	_check("%s: indo e voltando, a câmera não vê o corpo de perto (%d quadros)" % [tag, bad], bad == 0)
	await process_frame
	var rest: Transform3D = head.global_transform * player._view_rest()
	_check("%s: volta ao repouso da visão (%.3f m), sem pulo (%.3f m)" % [tag, camera.global_position.distance_to(rest.origin),
			camera.global_position.distance_to(last)], camera.global_position.distance_to(rest.origin) < 0.05
			and camera.global_position.distance_to(last) < 0.15)
	if view == "third":
		_check("%s: o corpo inteiro de volta" % tag, not avatar.is_posed() and not first.visible
				and (_seen(full, camera) or player.get_arm_length() < player.ARM_CLOSE))
	else:
		_check("%s: o corpo de primeira pessoa de volta" % tag, not avatar.is_posed() and first.visible
				and not _seen(full, camera))


## 1 se a câmera vê um corpo quando não devia: na primeira pessoa, qualquer um
## (fora do provador); na terceira, com a câmera perto do eixo do corpo.
func _body_too_close(player: Node, camera: Camera3D, full: Node3D, first: Node3D, view: String, posed: bool) -> int:
	var seen := _seen(first, camera) or (not posed and _seen(full, camera))
	if not seen:
		return 0
	if view == "first" or player._camera_body_distance() <= player.FOCUS_BODY_CLEARANCE:
		return 1
	return 0


## O canal "Ambiente" está abafado (o filtro de casa ligado)?
func _ambience_muffled() -> bool:
	var bus := AudioServer.get_bus_index(&"Ambiente")
	if bus < 0:
		return true
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
			return AudioServer.is_bus_effect_enabled(bus, i)
	return false


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
