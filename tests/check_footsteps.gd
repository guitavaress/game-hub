extends SceneTree
## Teste dos passos por superfície e do eco em casa (Fase 11.10).

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
	await create_timer(0.5).timeout
	var player = city.get_node("Player")
	var home = city.get_home()

	print("== canal Passos ==")
	var bus := AudioServer.get_bus_index("Passos")
	_check("o canal Passos existe e envia para Efeitos", bus > 0 and AudioServer.get_bus_send(bus) == &"Efeitos")
	_check("passos e pulo tocam no canal Passos", player._steps_player.bus == &"Passos" and player._body_player.bus == &"Passos")

	print("\n== chão da casa: madeira ==")
	player.global_position = home.global_position + Vector3(0.0, 0.3, 1.5)
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	_check("a superfície em casa é \"wood\"", player.get_surface() == "wood")
	Input.action_press("move_forward")
	var wood_ok := false
	for i in 90:
		await physics_frame
		if player.FOOTSTEP_SURFACES["wood"].has(player._steps_player.stream):
			wood_ok = true
	Input.action_release("move_forward")
	_check("o passo sai da lista de madeira", wood_ok)

	print("\n== eco ==")
	var reverb_on := func() -> bool:
		for i in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) is AudioEffectReverb:
				return AudioServer.is_bus_effect_enabled(bus, i)
		return false
	player.set_indoors(Environment.new())
	_check("set_indoors(ambiente) liga o eco", reverb_on.call())
	player.set_indoors(null)
	_check("set_indoors(null) desliga o eco", not reverb_on.call())

	print("\n== chão da cidade: concreto ==")
	player.teleport_to(city.get_node("Player").global_transform)
	player.global_position = Vector3(0.0, 0.5, 40.0)
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	print("   superfície: ", player.get_surface())
	_check("na rua a superfície é \"concrete\"", player.get_surface() == "concrete")

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
