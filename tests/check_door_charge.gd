extends SceneTree
## Teste do anel de progresso na porta (P1.7). Steam FALSA: nada abre de verdade.

const BALATRO := 2379780

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	for i in 30:
		await process_frame

	var launcher = root.get_node("GameLauncher")
	var opened: Array = []
	launcher._poll_timer.paused = true
	launcher.state_reader = func(_id: int, _check: bool) -> Dictionary:
		return {"running_app_id": 0, "steam_running": true, "app_running": false, "app_updating": false}
	launcher.url_opener = func(url: String) -> int:
		opened.append(url)
		return OK

	var fade = root.get_node("ScreenFade")
	var door = fade.door_charge
	var player = city.get_node("Player")
	var portal = city.get_node("Building_%d/GamePortal" % BALATRO)
	var outside: Vector3 = portal.get_return_transform().origin

	print("\n== entrando na porta ==")
	player.global_position = portal.global_transform * Vector3(0, 0.1, -0.8)
	await create_timer(0.6).timeout
	print("   progresso: %.2f | título: %s" % [door.get_progress(), door.get_title()])
	_check("vinheta + anel aparecem", door.visible and door.get_progress() > 0.2 and door.get_progress() < 0.7)
	_check("título 'ENTRANDO EM BALATRO'", door.get_title() == "ENTRANDO EM BALATRO")
	var neon: Color = root.get_node("GameCategories").get_neon_color("cartas")
	_check("anel na cor do bairro", door._ring.color.is_equal_approx(neon))
	_check("vinheta acompanha o progresso (com a curva)", is_equal_approx(door._vignette_material.get_shader_parameter("amount"), door.vignette_amount(door.get_progress())))
	_check("sem preto uniforme", fade.get_amount() < 0.01)

	print("\n== a porta pesa (câmera, vão e som) ==")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var base_fov: float = player._camera_feel.get_base_fov()
	var building = city.get_node("Building_%d" % BALATRO)
	print("   FOV %.1f (base %.1f) | brilho do vão %.2f" % [camera.fov, base_fov, building._door_glow_material.emission_energy_multiplier])
	_check("o FOV fecha com a carga", camera.fov < base_fov - 0.5)
	_check("a câmera avança um pouco", player._camera_feel.get_offset().length() > 0.001)
	_check("o vão acende (o sinal chegou à casca)", building._charge_ratio > 0.2
		and building._door_glow_material.emission_energy_multiplier > building.DOOR_GLOW_ENERGY * 1.3)
	var hum: String = load("res://components/friend_npc/friend_npc.gd").HUM_SOUND.resource_path
	_check("o som da carga não é o dos hologramas", portal._charge_sound.stream.resource_path != hum
		and portal.CHARGE_SOUND.resource_path != hum)

	print("\n== recuando (cancela) ==")
	player.global_position = outside
	await create_timer(0.5).timeout
	_check("anel e vinheta somem", not door.visible and door.get_progress() == 0.0 and portal._charge == 0.0)
	for i in 30:
		await process_frame
	_check("o FOV volta à base", absf(camera.fov - base_fov) < 0.05)
	_check("o vão volta ao normal", is_equal_approx(building._door_glow_material.emission_energy_multiplier, building.DOOR_GLOW_ENERGY))
	_check("não abriu nada", opened.is_empty())

	print("\n== esperando até o fim ==")
	player.global_position = portal.global_transform * Vector3(0, 0.1, -0.8)
	await create_timer(1.8).timeout
	_check("pediu o jogo à Steam", opened.size() == 1)
	_check("vinheta trocada pela cortina preta", not door.visible and fade.get_amount() > 0.99)
	_check("tela 'Abrindo' na frente", fade.game_screen.get_mode() == "abrindo")
	launcher.cancel_launch()

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
