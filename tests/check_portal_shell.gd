extends SceneTree
## Teste do PortalShell (Fase 7.4): o invólucro da porta de um jogo.
##   1. o prédio da cidade é uma PortalShell, com o portal no lugar de sempre;
##   2. um arco (ArchShell) tem um GamePortal que funciona: entrar pela porta
##      pede o jogo à Steam (FALSA: nada abre de verdade);
##   3. o perfil escolhe a casca: com shell = "arch", a cidade monta um arco.

const BALATRO := 2379780

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = await _new_city()
	var launcher = root.get_node("GameLauncher")
	var opened: Array = []
	launcher._poll_timer.paused = true
	launcher.state_reader = func(_id: int, _check: bool) -> Dictionary:
		return {"running_app_id": 0, "steam_running": true, "app_running": false, "app_updating": false}
	launcher.url_opener = func(url: String) -> int:
		opened.append(url)
		return OK
	var shell_script: GDScript = load("res://components/portal_shell/portal_shell.gd")
	var arch_script: GDScript = load("res://components/portal_shell/arch_shell.gd")

	print("== 1. o prédio é uma casca ==")
	var building: Node3D = city.get_node("Building_%d" % BALATRO)
	_check("o prédio estende PortalShell", building.get_script().get_base_script() == shell_script)
	var portal = building.get_node("GamePortal")
	_check("o portal é o filho GamePortal e fica na casca", portal != null and building.portal == portal)
	_check("porta no meio da frente (z = profundidade / 2)", portal.position.is_equal_approx(Vector3(0, 0, building.size.z / 2.0)))
	_check("alvo de olhar = a fachada inteira", portal.look_size.is_equal_approx(Vector3(building.size.x, building.size.y, 1.0)))

	print("== 2. um arco ==")
	var floor := StaticBody3D.new()  # chão só para o teste, longe da cidade
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(30, 1, 30)
	floor_shape.shape = floor_box
	floor.add_child(floor_shape)
	floor.position = Vector3(500, -0.5, 500)
	city.add_child(floor)
	var game = load("res://autoload/steam_game.gd").new()
	game.app_id = BALATRO
	game.name = "Balatro"
	var arch = arch_script.new()
	arch.name = "TestArch"
	arch.game = game
	arch.category_id = "cartas"
	arch.size = Vector3(10, 4, 10)
	arch.position = Vector3(500, 0, 500)
	city.add_child(arch)
	await process_frame
	var arch_portal = arch.get_node_or_null("GamePortal")
	_check("o arco é uma PortalShell e tem um GamePortal", arch.get_script().get_base_script() == shell_script and arch_portal != null)
	_check("o portal tem o jogo certo", arch_portal.app_id == BALATRO)
	_check("porta na frente do arco", arch_portal.position.is_equal_approx(Vector3(0, 0, 5)))
	_check("alvo de olhar = o arco (e não o terreno)", arch_portal.look_size.x < arch.size.x and arch_portal.look_size.y > 3.0)
	var stone: StaticBody3D = arch.get_node("Stone")
	_check("pilares e viga sólidos (3 colisões)", stone.get_children().filter(func(n): return n is CollisionShape3D).size() == 3)
	_check("a passagem é maior que a área de entrada",
			arch_script.OPENING.x > arch_portal.entry_size.x and arch_script.OPENING.y > arch_portal.entry_size.y)
	_check("som do bairro pendurado na porta",
			arch_portal.get_children().filter(func(n): return n is AmbientEmitter).size() == 1)
	var outward: Vector3 = arch_portal.get_return_transform().origin - arch_portal.global_position
	_check("o jogador volta do lado de fora do arco", outward.dot(arch_portal.global_basis.z) > 1.0)

	# A placa com a arte (15.5): existe, sem colisão, e recebe o hero do GameArt.
	var poster: MeshInstance3D = arch.get_node_or_null("Poster")
	_check("o arco tem a placa Poster", poster != null)
	_check("a placa não tem colisão própria", poster.get_children().is_empty())
	var hero := ImageTexture.create_from_image(Image.create_empty(1920, 620, false, Image.FORMAT_RGB8))
	root.get_node("GameArt").hero_ready.emit(BALATRO, hero)
	_check("o hero do jogo vira a textura da placa", poster.visible and arch.get_art_texture() == hero)
	var poster_size: Vector2 = (poster.mesh as QuadMesh).size
	_check("a placa cabe na largura do arco e fica acima da passagem",
			poster_size.x <= arch_script.OPENING.x + 2.0 * arch_script.PILLAR_WIDTH + 0.01
			and poster.position.y - poster_size.y / 2.0 >= arch_script.OPENING.y + arch_script.LINTEL_HEIGHT - 0.01)
	_check("o nome fica acima da placa", arch.get_node("Name").position.y > poster.position.y + poster_size.y / 2.0)
	var other_tex := ImageTexture.create_from_image(Image.create_empty(64, 64, false, Image.FORMAT_RGB8))
	root.get_node("GameArt").hero_ready.emit(BALATRO + 1, other_tex)
	_check("hero de outro jogo é ignorado", arch.get_art_texture() == hero)

	# O filete acende na carga (15.5) e combina com o dia/noite.
	var neon: StandardMaterial3D = arch._neon_material
	arch.set_night(0.0)
	var base_energy := neon.emission_energy_multiplier
	arch._on_portal_charge(1.0)
	var charged := neon.emission_energy_multiplier
	_check("a carga aumenta o brilho do filete", charged > base_energy * 1.5)
	arch.set_night(1.0)
	_check("carga e noite se somam", neon.emission_energy_multiplier > charged)
	arch._on_portal_charge(0.0)
	arch.set_night(0.0)
	_check("carga 0 volta ao brilho normal", is_equal_approx(neon.emission_energy_multiplier, base_energy)
			and is_equal_approx(base_energy, arch_script.NEON_DAY))

	var player = city.get_node("Player")
	player.global_position = arch_portal.global_transform * Vector3(0, 0.1, -0.8)
	await create_timer(1.8).timeout
	_check("entrar pela porta do arco pede o jogo à Steam", opened == ["steam://rungameid/%d" % BALATRO])
	launcher.cancel_launch()
	await create_timer(0.3).timeout

	print("== 3. o perfil escolhe a casca ==")
	city.queue_free()
	await process_frame
	var profile = load("res://profiles/profiles.gd").district("cartas")
	profile.shell = "arch"  # só na memória, para este teste
	city = await _new_city()
	var chosen: Node3D = city.get_node_or_null("Building_%d" % BALATRO)
	_check("com shell = \"arch\", o Balatro ganha um arco", chosen != null and chosen.get_script() == arch_script)
	_check("e o portal continua em Building_<id>/GamePortal", city.get_node_or_null("Building_%d/GamePortal" % BALATRO) != null)
	# Os outros bairros sem bioma continuam com prédio (o RPG, com o bioma da
	# montanha, tem arcos desde a 15.6).
	var others := 0
	var others_ok := true
	for child: Node in city.get_children():
		if not String(child.name).begins_with("Building_") or child.category_id == "cartas":
			continue
		if load("res://profiles/profiles.gd").district(child.category_id).biome != null:
			continue
		others += 1
		others_ok = others_ok and child.get_script().resource_path.ends_with("city_building.gd")
	_check("os outros bairros continuam com prédio (%d)" % others, others > 0 and others_ok)
	profile.shell = "building"

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _new_city() -> Node:
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	for i in 20:
		await process_frame
	return city


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
