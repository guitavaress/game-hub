extends SceneTree
## Fase 6, etapas 2 e 3: sons (verificados "por dentro", sem ouvir).

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	for i in 10:
		await physics_frame
	var player = city.get_node("Player")

	print("== canais de áudio e volumes ==")
	for bus_name in ["Master", "Efeitos", "Ambiente"]:
		var bus := AudioServer.get_bus_index(bus_name)
		print("   %-8s índice %d | %.1f dB" % [bus_name, bus, AudioServer.get_bus_volume_db(bus) if bus >= 0 else 0.0])
	_check("três canais existem", AudioServer.get_bus_index("Efeitos") > 0 and AudioServer.get_bus_index("Ambiente") > 0)
	_check("volume geral 0.8 aplicado (~ -1.9 dB)", absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.8)) < 0.1)
	var config_text := FileAccess.get_file_as_string("user://config.cfg")
	_check("config.cfg ganhou [audio]", config_text.contains("[audio]") and config_text.contains("[steam]"))

	print("\n== som ambiente por portal ==")
	var cats = root.get_node("GameCategories")
	for child in city.get_children():
		if not child.name.begins_with("Building_"):
			continue
		var portal = child.get_node("GamePortal")
		var emitters := portal.get_children().filter(func(n): return n is AmbientEmitter)
		var desc := emitters.map(func(e): return ("loop %s (loop=%s, tocando=%s)" % [e.stream.resource_path.get_file() if e.stream.resource_path else e.loop_stream.resource_path.get_file(), _is_looping(e.stream), e.playing]) if e.loop_stream else "%d sons avulsos" % e.one_shots.size())
		print("   %-45s [%s] %s" % [child.game.name, cats.get_category_id(child.game.app_id), desc])
	# O motor do bairro de esportes: num prédio de esportes da biblioteca, se
	# houver algum; senão (ex.: um PC sem jogos de esporte), num emissor criado
	# aqui pela mesma tabela do bairro (CategoryAmbience), que dá na mesma.
	var engine: AmbientEmitter = null
	for child in city.get_children():
		if child.name.begins_with("Building_") and cats.get_category_id(child.game.app_id) == "esportes":
			engine = child.get_node("GamePortal").get_children().filter(func(n): return n is AmbientEmitter)[0]
			break
	var temp_engine: AmbientEmitter = null
	if engine == null:
		print("   (nenhum jogo de esportes instalado: conferindo o motor pela tabela do bairro)")
		temp_engine = CategoryAmbience.create("esportes")[0]
		city.add_child(temp_engine)
		await process_frame
		engine = temp_engine
	_check("motor do bairro de esportes em loop, tocando, ouvido até 32 m", _is_looping(engine.stream) and engine.playing and engine.max_distance == 32.0)
	var engine_bus_ok: bool = engine.bus == &"Ambiente"
	if temp_engine != null:
		temp_engine.queue_free()
	var survival = city.get_node("Building_892970/GamePortal")  # Valheim
	var wind = survival.get_children().filter(func(n): return n is AmbientEmitter)[0]
	_check("vento (WAV gerado) em loop", _is_looping(wind.stream))
	_check("todos no canal Ambiente", engine_bus_ok and wind.bus == &"Ambiente")

	print("\n== passos ==")
	# Atravessa a praça de oeste para leste, ao sul do chafariz: linha livre de
	# floreiras, postes e da estação de metrô (que fica no vão entre os prédios).
	player.global_position = Vector3(-13, 0.1, 6)
	player.rotation.y = -PI / 2.0  # olhando para o leste (+X)
	for i in 10:
		await physics_frame
	var steps := await _count_steps(player, 2.0, false)
	var sprint_steps := await _count_steps(player, 2.0, true)
	print("   andando 2 s: %d passos | correndo 2 s: %d passos" % [steps, sprint_steps])
	_check("andando: 4 a 6 passos em 2 s", steps >= 4 and steps <= 6)
	_check("correndo: passos mais rápidos (5 a 7)", sprint_steps >= 5 and sprint_steps <= 7)

	print("\n== zumbido do portal ==")
	var balatro = city.get_node("Building_2379780/GamePortal")
	# Garantia dupla de que nenhum jogo abre de verdade neste teste.
	root.get_node("GameLauncher").url_opener = func(_url: String) -> int: return ERR_UNAVAILABLE
	balatro.enter_time = 1000.0
	player.global_position = balatro.global_transform * Vector3(0, 0.1, -0.8)
	for i in 30:
		await physics_frame
	var hum: AudioStreamPlayer3D = balatro._charge_sound
	var pitch_start: float = hum.pitch_scale
	balatro.enter_time = 1.0  # agora a "carga" já passou da metade
	balatro._charge = 0.6
	await process_frame
	await process_frame
	await process_frame
	print("   tocando=%s | tom com pouca carga %.2f -> com 60%% de carga %.2f" % [hum.playing, pitch_start, hum.pitch_scale])
	_check("zumbido tocando e subindo de tom", hum.playing and hum.pitch_scale > pitch_start)
	balatro.enter_time = 1000.0
	player.global_position = balatro.global_transform * Vector3(0, 0.1, 6)
	for i in 60:
		await physics_frame
	_check("zumbido para ao sair da porta", not hum.playing)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _count_steps(player, seconds: float, sprint: bool) -> int:
	var steps_player: AudioStreamPlayer = player._steps_player
	var count := 0
	var was_playing := false
	var last_stream = null
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await physics_frame
		# um passo novo = começou a tocar, ou trocou o som
		if (steps_player.playing and not was_playing) or (steps_player.playing and steps_player.stream != last_stream):
			count += 1
		was_playing = steps_player.playing
		last_stream = steps_player.stream if steps_player.playing else null
	Input.action_release("move_forward")
	Input.action_release("sprint")
	for i in 20:
		await physics_frame
	return count


func _is_looping(stream: AudioStream) -> bool:
	if stream is AudioStreamOggVorbis:
		return stream.loop
	if stream is AudioStreamWAV:
		return stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 0
	return false


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
