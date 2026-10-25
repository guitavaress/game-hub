extends SceneTree
## Teste do clima por bairro: garoa no Terror e neve criada por código (15.11).
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
	var weather: Node = weathers[0]
	var player: Node3D = city.get_node("Player")
	var zones: Array[Rect2] = get_first_node_in_group("world_map").zone_rects("sobrevivencia")
	_check("a área do clima = as zonas do bairro (%d)" % zones.size(), not zones.is_empty() and weather.areas == zones)
	var inside := Vector3(weather.areas[0].get_center().x, 1.0, weather.areas[0].get_center().y)
	var bounds: Rect2 = get_first_node_in_group("world_map").get_map_data()["bounds"]
	var outside := Vector3(bounds.end.x + 200.0, 1.0, bounds.end.y + 200.0)

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
	var rains_in_every_zone := true
	for zone: Rect2 in weather.areas:
		player.global_position = Vector3(zone.get_center().x, 1.0, zone.get_center().y)
		await process_frame
		await process_frame
		rains_in_every_zone = rains_in_every_zone and weather.is_raining()
	_check("chove em todas as zonas do bairro (quarteirões e vagas)", rains_in_every_zone)
	# Uma zona de outro bairro: lá não chove.
	var neighbor := Vector3.INF
	for area: Dictionary in get_first_node_in_group("world_map").get_map_data()["areas"]:
		if area["id"] != "sobrevivencia" and neighbor == Vector3.INF:
			var rect: Rect2 = area["zones"][0]
			neighbor = Vector3(rect.get_center().x, 1.0, rect.get_center().y)
	player.global_position = neighbor
	await process_frame
	await process_frame
	_check("noutro bairro: não chove", not weather.is_raining())
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
	_check_rain_appearance(weather, rain)
	for pair in [["alta", 1.0], ["media", 0.6], ["leve", 0.25]]:
		config.set_quality(pair[0])
		await process_frame
		var expected := roundi(weather.BASE_AMOUNT * pair[1])
		_check("%s: %d gotas" % [pair[0], expected], rain.amount == expected)
	config.set_quality(original_quality)
	_check("sem sombra e sem luz", rain.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_check_snow(weather_script, city, player, config)
	config.set_quality(original_quality)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check_rain_appearance(weather: Node, rain: GPUParticles3D) -> void:
	print("== garoa preservada ==")
	var process: ParticleProcessMaterial = rain.process_material
	var drop: BoxMesh = rain.draw_pass_1 as BoxMesh
	_check("tipo padrão é garoa", weather.current_kind() == "garoa" and WeatherSpec.new().kind == "garoa")
	_check("padrões do perfil preservados", WeatherSpec.new().night_only and WeatherSpec.new().intensity == 1.0)
	_check("base continua com 900 gotas", weather.WEATHER_TYPES["garoa"]["amount"] == 900)
	_check("caixa de emissão e direção preservadas", process.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX and process.emission_box_extents == Vector3(15.0, 0.2, 15.0) and process.direction == Vector3.DOWN)
	_check("queda e dispersão preservadas", is_equal_approx(process.initial_velocity_min, 14.0) and is_equal_approx(process.initial_velocity_max, 16.8) and is_equal_approx(process.spread, 2.0) and process.gravity == Vector3.ZERO)
	_check("duração e limites preservados", is_equal_approx(rain.lifetime, 16.0 / 14.0) and rain.visibility_aabb == AABB(Vector3(-30.0, -18.0, -30.0), Vector3(60.0, 36.0, 60.0)) and not rain.local_coords)
	_check("mesma caixa fina", drop != null and drop.size == Vector3(0.015, 0.6, 0.015))
	if drop != null:
		var material: StandardMaterial3D = drop.material
		_check("mesma cor, transparência e material sem luz", material.albedo_color.is_equal_approx(Color(0.8, 0.88, 1.0, 0.45)) and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)


func _check_snow(weather_script: GDScript, city: Node, player: Node3D, config: Node) -> void:
	print("== neve sem alterar perfis compartilhados ==")
	var snow_spec := WeatherSpec.new()
	snow_spec.kind = "neve"
	snow_spec.intensity = 0.7
	var snow: Node = weather_script.new()
	snow.spec = snow_spec
	# Zonas separadas: o espaço entre elas também precisa ficar sem neve.
	snow.areas = [Rect2(1000.0, 1000.0, 20.0, 20.0), Rect2(1040.0, 1000.0, 20.0, 20.0)] as Array[Rect2]
	city.add_child(snow)
	snow.set_process(false)
	var particles: GPUParticles3D = snow.get_node("Rain")
	var process: ParticleProcessMaterial = particles.process_material
	var flake: QuadMesh = particles.draw_pass_1 as QuadMesh
	_check("consulta informa neve", snow.current_kind() == "neve")
	_check("flocos pequenos em quad", flake != null and flake.size == Vector2(0.09, 0.09))
	_check("queda lenta com deriva lateral leve", is_equal_approx(process.initial_velocity_min, 1.5) and is_equal_approx(process.initial_velocity_max, 2.5) and process.direction.y == -1.0 and process.direction.x > 0.0 and process.direction.x <= 0.1 and process.spread > 2.0 and process.spread <= 15.0 and process.gravity == Vector3.ZERO)
	_check("neve sem sombra, partículas no mundo", particles.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not particles.local_coords)
	if flake != null:
		var material: StandardMaterial3D = flake.material
		var color: Color = material.albedo_color
		_check("neve fria sem estourar o branco", color.r <= 0.85 and color.g <= 0.85 and color.b <= 0.85 and color.b > color.r and color.a > 0.0 and color.a < 1.0)
		_check("billboard sem luz e com transparência", material.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
		var texture: GradientTexture2D = material.albedo_texture as GradientTexture2D
		_check("máscara radial com borda transparente", texture != null and texture.fill == GradientTexture2D.FILL_RADIAL and texture.gradient.get_color(0).a == 1.0 and texture.gradient.get_color(1).a == 0.0)

	snow.set_night(1.0)
	for zone: Rect2 in snow.areas:
		_move_weather(snow, player, zone.get_center())
		_check("neva dentro da zona %s" % str(zone), snow.is_raining())
		_check("emissor acompanha o jogador", particles.global_position.is_equal_approx(player.global_position + Vector3(0.0, 10.0, 0.0)))
	for point: Vector2 in [Vector2(1030.0, 1010.0), Vector2(1100.0, 1100.0)]:
		_move_weather(snow, player, point)
		_check("não neva fora das zonas %s" % str(point), not snow.is_raining())
	_move_weather(snow, player, Vector2(1010.0, 1010.0))
	snow.set_night(0.5)
	_check("night_only bloqueia até o limiar noturno", not snow.is_raining())
	snow.set_night(1.0)
	_check("night_only permite neve à noite", snow.is_raining())
	snow_spec.night_only = false
	snow.set_night(0.0)
	_check("neve também de dia quando o perfil permite", snow.is_raining())
	for pair: Array in [["alta", 1.0], ["media", 0.6], ["leve", 0.25]]:
		config.set_quality(pair[0])
		var expected: int = roundi(500 * 0.7 * float(pair[1]))
		_check("neve %s: intensidade e qualidade = %d" % [pair[0], expected], particles.amount == expected)
	snow_spec.intensity = 0.0
	snow.call("_apply_amount")
	_check("intensidade zero mantém mínimo seguro de uma partícula", particles.amount == 1)

	var no_spec: Node = weather_script.new()
	no_spec.areas = snow.areas
	city.add_child(no_spec)
	no_spec.set_process(false)
	no_spec.set_night(1.0)
	_move_weather(no_spec, player, Vector2(1010.0, 1010.0))
	var idle_particles: GPUParticles3D = no_spec.get_node("Rain")
	_check("spec nulo usa garoa sem emitir", no_spec.current_kind() == "garoa" and not no_spec.is_raining())
	_check("spec nulo mantém quantidade padrão pela qualidade", idle_particles.amount == roundi(900 * 0.25))
	snow.free()
	no_spec.free()


func _move_weather(weather: Node, player: Node3D, point: Vector2) -> void:
	player.global_position = Vector3(point.x, 1.0, point.y)
	# Atualização direta evita que a física mova o jogador entre as conferências.
	weather.call("_process", 0.0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
