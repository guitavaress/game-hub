extends SceneTree
## Teste do clima por bairro (Fase 7.6): garoa no Terror.
##   1. só o bairro Terror tem DistrictWeather;
##   2. chove só com o jogador dentro do bairro e só à noite;
##   3. a quantidade de gotas segue a qualidade (100/60/25%);
##   4. o clima não mexe na neblina; trocar a qualidade atualiza em jogo.

func _initialize() -> void:
	_run()


var failures := 0


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	for i in 5:
		await process_frame
	var config := root.get_node("AppConfig")
	var original_quality: String = config.get_quality()

	print("== quem tem clima ==")
	var weather_script: GDScript = load("res://worlds/city/district_weather.gd")
	var weathers: Array[Node] = city.get_children().filter(func(n: Node) -> bool: return n.get_script() == weather_script)
	var names := weathers.map(func(n: Node) -> String: return String(n.name))
	_check("só o Terror tem DistrictWeather %s" % str(names), names == ["DistrictWeather_sobrevivencia"])
	if weathers.is_empty():
		print("\nRESULTADO: 1 FALHA(S)")
		quit()
		return
	var weather = weathers[0]
	var player: Node3D = city.get_node("Player")
	var inside := Vector3(weather.area.get_center().x, 1.0, weather.area.get_center().y)
	var outside := Vector3(weather.area.end.x + 200.0, 1.0, weather.area.end.y + 200.0)

	print("== a hora chega pelo relógio da cidade ==")
	city._on_night_changed(1.0)
	_check("o clima ouve o grupo city_night", weather._night == 1.0)
	city._on_night_changed(0.0)

	print("== quando chove ==")
	var fog_before: float = city._environment.fog_density
	weather.set_night(1.0)
	player.global_position = inside
	await process_frame
	await process_frame
	_check("noite + dentro do bairro: chove", weather.is_raining())
	player.global_position = outside
	await process_frame
	await process_frame
	_check("fora do bairro: não chove", not weather.is_raining())
	player.global_position = inside
	weather.set_night(0.0)
	await process_frame
	await process_frame
	_check("de dia: não chove", not weather.is_raining())
	weather.set_night(1.0)
	await process_frame
	_check("a chuva acompanha o jogador", weather.get_node("Rain").global_position.distance_to(inside + Vector3(0, weather.RAIN_HEIGHT, 0)) < 0.1)
	_check("não mexe na neblina da cidade", is_equal_approx(city._environment.fog_density, fog_before))

	print("== qualidade ==")
	var rain: GPUParticles3D = weather.get_node("Rain")
	for pair in [["alta", 1.0], ["media", 0.6], ["leve", 0.25]]:
		config.set_quality(pair[0])
		await process_frame
		var expected := roundi(weather.BASE_AMOUNT * pair[1])
		_check("%s: %d gotas" % [pair[0], expected], rain.amount == expected)
	config.set_quality(original_quality)
	_check("sem sombra e sem luz", rain.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
