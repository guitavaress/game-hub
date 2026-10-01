extends SceneTree
## Teste da abertura pelo céu (P2.21), forçando a abertura mesmo sem janela.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var fade = root.get_node("ScreenFade")
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = true
	var ready_at := [-1]
	var started_ms := Time.get_ticks_msec()
	city.city_ready.connect(func() -> void: ready_at[0] = Time.get_ticks_msec())
	root.add_child(city)
	await process_frame

	print("\n== começo: olhando o céu ==")
	var player = city.get_node("Player")
	var head = player.get_node("Head")
	_check("jogador parado, sem controles", player.in_intro and not player.is_physics_processing())
	_check("olhando 70° para cima", absf(rad_to_deg(head.rotation.x) - 70.0) < 0.5)
	_check("HUD escondido, abertura visível, cortina transparente",
		not player.get_hud().visible and fade.is_splash_visible() and fade.get_amount() < 0.01)
	_check("menu de pausa não abre", not player.get_pause_menu().can_open())
	print("   hora no canto: ", fade.splash._clock.text)

	# Acompanha a abertura até a cidade ficar pronta.
	var saw_building_status := false
	var max_progress := 0.0
	while ready_at[0] == -1 and (Time.get_ticks_msec() - started_ms) < 20000:
		if fade.splash.get_status().begins_with("Construindo bairros…"):
			saw_building_status = true
		max_progress = maxf(max_progress, fade.splash.get_progress())
		await process_frame

	print("\n== durante ==")
	_check("mostrou 'Construindo bairros… N de M jogos'", saw_building_status)
	_check("barra chegou ao fim", max_progress > 0.99)
	_check("etapas BIBLIOTECA, CAPAS e BAIRROS prontas", fade.splash.is_stage_done("biblioteca")
		and fade.splash.is_stage_done("capas") and fade.splash.is_stage_done("bairros"))
	print("   etapa AMIGOS pronta? ", fade.splash.is_stage_done("amigos"))

	print("\n== fim ==")
	var seconds: float = (ready_at[0] - started_ms) / 1000.0
	print("   pronta em %.2f s" % seconds)
	_check("durou pelo menos o mínimo + a descida (~3,7 s)", seconds >= 3.6)
	_check("câmera no horizonte", absf(head.rotation.x) < 0.01)
	_check("jogador livre, HUD de volta", not player.in_intro and player.is_physics_processing() and player.get_hud().visible)
	await create_timer(0.5).timeout
	_check("abertura sumiu", not fade.is_splash_visible())
	_check("cidade montada", city.has_node("Building_2379780") and city.is_city_ready())
	print("   avisos depois da abertura: ", player.get_hud().get_messages())

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
