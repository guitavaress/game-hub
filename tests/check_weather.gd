extends SceneTree
## Teste de quem MOSTRA o tempo (DistrictWeather; chuva da 19.5, tempo da
## cidade da 19.6). O tempo vem do WeatherDirector (check_weather_director).
##   1. quem tem clima: a chuva da cidade (em todo lugar menos os bairros com
##      clima próprio), a neve do RPG e as folhas da Aventura (19.7), se existirem;
##   2. com tempo limpo nada cai; com chuva, cai na praça, nas ruas e fora da
##      mureta, mas não no RPG (lá neva); dentro de casa não cai, e o som fica;
##   3. a força muda a quantidade sem reiniciar as partículas, e a forma passa
##      da fraca à forte em linha reta;
##   4. as camadas por qualidade; o chão molha e o céu fecha pela cidade toda;
##      voltar ao limpo devolve tudo (a névoa, o asfalto, as poças, o som);
##   5. neve e nevasca, folhas e poeira; nenhuma luz nova.

const CONFIG := "user://config.cfg"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var backup := FileAccess.get_file_as_string(CONFIG)
	load("res://tests/quiet_friends.gd").install(root)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	for i in 5:
		await process_frame
	var config := root.get_node("AppConfig")
	var original_quality: String = config.get_quality()
	var director: Node = city.get_node("WeatherDirector")
	director.set_process(false)  # o teste anda o tempo à mão

	print("== quem tem clima ==")
	var weather_script: GDScript = load("res://worlds/city/district_weather.gd")
	var weathers: Array[Node] = city.get_children().filter(func(n: Node) -> bool: return n.get_script() == weather_script)
	var names := weathers.map(func(n: Node) -> String: return String(n.name))
	names.sort()
	# Os bairros com clima próprio no perfil (o RPG, com a neve; a Aventura, com as folhas; a Sobrevivência, com a poeira).
	var own: Array[String] = []
	for id: String in city._district_cells:
		var profile = load("res://profiles/profiles.gd").district(id)
		if profile != null and profile.effective_weather() != null:
			own.append(id)
	var expected_names: Array = ["DistrictWeather_cidade"]
	for id in own:
		expected_names.append("DistrictWeather_%s" % id)
	expected_names.sort()
	_check("a chuva da cidade, a neve do RPG, as folhas da Aventura e a poeira da Sobrevivência %s" % str(names), names == expected_names)
	var weather: Node = city.get_node("DistrictWeather_cidade")
	var snow: Node = city.get_node_or_null("DistrictWeather_rpg")
	var leaves: Node = city.get_node_or_null("DistrictWeather_aventura")
	var dust: Node = city.get_node_or_null("DistrictWeather_sobrevivencia")
	_check("a cidade mostra chuva; o RPG, neve; a Aventura, folhas; a Sobrevivência, poeira", weather.current_kind() == "garoa"
			and (snow == null or snow.current_kind() == "neve")
			and (leaves == null or leaves.current_kind() == "folhas")
			and (dust == null or dust.current_kind() == "poeira"))
	var map: Node = get_first_node_in_group("world_map")
	var own_areas := 0
	var all_out := true
	for id in own:
		var areas: Array = city.get_node("DistrictWeather_%s" % id).areas
		own_areas += areas.size()
		for area: Rect2 in areas:
			all_out = all_out and weather.exclude.has(area)
	_check("a chuva da cidade vale em todo lugar, menos nos bairros com clima próprio", weather.areas.is_empty()
			and weather.exclude.size() == own_areas and all_out)
	_check("o perfil do bairro ficou sem a garoa: a Sobrevivência mostra a poeira do deserto (19.8)",
			load("res://profiles/profiles.gd").district("sobrevivencia").effective_weather().kind == "poeira")

	var player: Node3D = city.get_node("Player")
	var bounds: Rect2 = map.get_map_data()["bounds"]
	var plaza := Vector3(4.0, 1.0, 4.0)
	var outside := Vector3(bounds.end.x + 200.0, 1.0, bounds.end.y + 200.0)
	# Uma zona de um bairro sem clima próprio (lá chove a chuva da cidade).
	var district_zone: Rect2 = map.zone_rects(_first_other_district(map, own))[0]
	var street := Vector3(district_zone.get_center().x, 1.0, district_zone.get_center().y)

	print("== tempo limpo: nada cai ==")
	_move(weather, player, plaza)
	_check("limpo: não chove na praça", not weather.is_raining() and weather.current_strength() == 0.0)

	print("== chuva fraca ==")
	director.force("chuva_fraca")
	_check("o tempo chega a quem mostra", weather.current_state() == "chuva_fraca"
			and is_equal_approx(weather.current_strength(), 0.5))
	for spot: Vector3 in [plaza, street, outside]:
		_move(weather, player, spot)
		_check("chove em %s" % str(spot), weather.is_raining())
	if snow != null:
		var mountain: Rect2 = snow.areas[0]
		var in_rpg := Vector3(mountain.get_center().x, 1.0, mountain.get_center().y)
		_move(weather, player, in_rpg)
		_check("no RPG não chove...", not weather.is_raining())
		_move(snow, player, in_rpg)
		_check("...neva", snow.is_raining())
	_move(weather, player, plaza)
	_check("a chuva acompanha o jogador (acima e contra o vento)",
			weather.get_node("Rain").global_position.distance_to(weather.rain_origin(plaza)) < 0.1
			and weather.rain_origin(plaza).y > plaza.y + 9.0)

	print("== a força ==")
	var rain: GPUParticles3D = weather.get_node("Rain")
	var splashes: GPUParticles3D = weather.get_node("Splashes")
	config.set_quality("alta")
	await process_frame
	_move(weather, player, plaza)
	var amount_before := rain.amount
	var process: ParticleProcessMaterial = rain.process_material
	var fraca_speed := process.initial_velocity_max
	var fraca_count: int = weather.emitted("main")
	_check("fraca: 1800 gotas no ar (%d nascem)" % fraca_count, absi(fraca_count - 1800) <= 2)
	_check("fraca: 180 respingos", absi(weather.emitted("splashes") - 180) <= 1)
	var smooth := true
	var last := fraca_count
	for step in range(1, 11):
		weather.set_weather("chuva_forte", 0.5 + step * 0.05)
		smooth = smooth and rain.amount == amount_before and weather.emitted("main") >= last
		last = weather.emitted("main")
	_check("da fraca à forte, a quantidade sobe sem reiniciar as partículas", smooth)
	_check("forte: 5000 gotas no ar, mais as da queda mais rápida (%d)" % last,
			absi(last - roundi(5000.0 * 14.0 / 11.0)) <= 2)
	_check("forte: 600 respingos", absi(weather.emitted("splashes") - 600) <= 1)
	_check("forte: cai mais rápido e mais inclinada", process.initial_velocity_max > fraca_speed
			and absf(process.direction.x) > 0.15)
	var material: ShaderMaterial = (rain.draw_pass_1 as QuadMesh).material
	var fall: Vector3 = material.get_shader_parameter("fall_direction")
	_check("o risco estica na direção da queda", fall.is_equal_approx(process.direction))
	_check("riscos: o shader da chuva", material.shader.resource_path == "res://worlds/city/rain_streak.gdshader")
	weather.set_weather("nublado", 0.0)
	_move(weather, player, plaza)
	_check("força zero: para de cair", not weather.is_raining() and not splashes.emitting)

	print("== qualidade ==")
	var quality_script: GDScript = load("res://autoload/graphics_quality.gd")
	weather.set_weather("chuva_fraca", 0.5)
	for level: String in ["alta", "media", "leve"]:
		config.set_quality(level)
		await process_frame
		_move(weather, player, plaza)
		var layers: Dictionary = quality_script.rain_layers(level)
		var streaks := 1800.0 * float(layers["riscos"])
		var drops := roundi(180 * float(layers["respingo"]))
		_check("%s: %d riscos" % [level, roundi(streaks)], absf(weather.emitted("main") - streaks) <= 2.0)
		_check("%s: respingos %s" % [level, str(drops) if drops > 0 else "desligados"],
				splashes.visible == (drops > 0) and (drops == 0 or absi(weather.emitted("splashes") - drops) <= 1))
	config.set_quality(original_quality)
	_check("sem sombra, partículas no mundo", rain.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and splashes.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and not rain.local_coords and splashes.lifetime < 0.5)

	await _check_world(city, director, weather, player, plaza, config)
	_check_indoors(weather, player, plaza)
	_check_snow(weather_script, city, player, config)
	_check_leaves_and_dust(weather_script, city, player)
	var no_lights := true
	for node: Node in city.get_children():
		if node.get_script() == weather_script:
			no_lights = no_lights and node.find_children("*", "Light3D", true, false).is_empty()
	_check("nenhuma luz nova no clima", no_lights)
	config.set_quality(original_quality)

	city.free()
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


static func _first_other_district(map: Node, skip: Array[String]) -> String:
	for area: Dictionary in map.get_map_data()["areas"]:
		if not skip.has(area["id"]):
			return area["id"]
	return ""


## O chão e o céu são da cidade toda: o tempo molha e fecha; o limpo devolve.
func _check_world(city: Node, director: Node, weather: Node, player: Node3D,
		plaza: Vector3, config: Node) -> void:
	print("== o chão e o céu ==")
	var day_night: Node = city._day_night
	var decor: GDScript = load("res://worlds/city/city_decor.gd")
	var asphalt: StandardMaterial3D = decor.asphalt_material()
	director.force("limpo")
	day_night.apply_hour(13.0)
	city._on_night_changed(0.0)
	var fog_before: float = city._environment.fog_density
	var dry_roughness: float = asphalt.roughness
	config.set_quality("alta")
	director.force("chuva_forte")
	day_night.apply_hour(13.0)
	_check("forte: chão encharcado na hora", is_equal_approx(decor.ground_wetness(), 1.0)
			and asphalt.roughness < dry_roughness and asphalt.albedo_color.v < decor.ASPHALT_TINT.v)
	var puddle: Decal = get_first_node_in_group(decor.PUDDLE_GROUP) as Decal
	_check("as poças crescem e escurecem", puddle != null
			and puddle.size.x > Vector3(puddle.get_meta(&"dry_size")).x
			and puddle.albedo_mix > decor.PUDDLE_ALBEDO_MIX_DRY)
	_check("forte: o céu fecha", is_equal_approx(day_night.get_weather_overlay(), 0.9)
			and city._environment.fog_density > fog_before)
	_move(weather, player, plaza)
	weather.call("_process", 100.0)
	_check("o som toca, mais alto na forte", weather.get_node("RainSound").playing)
	var loud: float = weather.get_node("RainSound").volume_db
	director.force("chuva_fraca")
	weather.call("_process", 0.0)
	_check("fraca: o som mais baixo, o céu e o chão menos", weather.get_node("RainSound").volume_db < loud
			and day_night.get_weather_overlay() < 0.9 and decor.ground_wetness() < 1.0)
	director.force("limpo")
	day_night.apply_hour(13.0)
	weather.call("_process", 100.0)
	_check("limpo: para de chover, sem som", not weather.is_raining() and not weather.get_node("RainSound").playing)
	_check("limpo: chão seco e céu aberto", decor.ground_wetness() == 0.0 and day_night.get_weather_overlay() == 0.0)
	_check("limpo: a névoa de antes (%f, %f)" % [city._environment.fog_density, fog_before],
			is_equal_approx(city._environment.fog_density, fog_before))
	city._on_night_changed(0.0)
	_check("limpo: o asfalto de antes (%f, %s)" % [asphalt.roughness, asphalt.albedo_color],
			is_equal_approx(asphalt.roughness, decor.ASPHALT_ROUGHNESS_DAY)
			and asphalt.albedo_color.is_equal_approx(decor.ASPHALT_TINT))
	_check("as poças voltam ao tamanho", puddle == null or puddle.size.is_equal_approx(puddle.get_meta(&"dry_size")))
	print("== a tinta pela hora ==")
	var material: ShaderMaterial = (weather.get_node("Rain").draw_pass_1 as QuadMesh).material
	weather.set_night(0.0)
	var day_tint: Color = material.get_shader_parameter("tint")
	weather.set_night(1.0)
	var night_tint: Color = material.get_shader_parameter("tint")
	_check("à noite, a gota fica mais escura", night_tint.v < day_tint.v)
	city._on_night_changed(1.0)
	_check("o clima ouve o grupo city_night", weather._night == 1.0)
	city._on_night_changed(0.0)
	await process_frame


## Dentro de casa não cai nada, mas a chuva se ouve (o canal Ambiente abafa).
func _check_indoors(weather: Node, player: Node3D, plaza: Vector3) -> void:
	print("== dentro de casa ==")
	weather.set_weather("chuva_forte", 1.0)
	_move(weather, player, plaza)
	weather.call("_process", 100.0)
	var outdoor_volume: float = weather.get_node("RainSound").volume_db
	player._indoors = true
	_move(weather, player, Vector3(0.0, 1.0, 1500.0))
	weather.call("_process", 100.0)
	_check("em casa, nada cai", not weather.is_raining())
	_check("em casa, a chuva se ouve, mais baixo", weather.get_node("RainSound").playing
			and weather.get_node("RainSound").volume_db < outdoor_volume)
	player._indoors = false
	weather.set_weather("limpo", 0.0)
	weather.call("_process", 100.0)


func _check_snow(weather_script: GDScript, city: Node, player: Node3D, config: Node) -> void:
	print("== neve e nevasca ==")
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
	_check("a neve não tem respingo nem som", snow.get_node_or_null("Splashes") == null
			and snow.get_node_or_null("RainSound") == null)
	_check("flocos pequenos em quad", flake != null and flake.size == Vector2(0.09, 0.09))
	snow.set_weather("chuva_fraca", 0.5)
	_check("neve: queda lenta com deriva lateral leve", is_equal_approx(process.initial_velocity_min, 1.5)
			and is_equal_approx(process.initial_velocity_max, 2.5) and process.direction.y < -0.99
			and process.direction.x > 0.0 and process.direction.x <= 0.1 and process.spread > 2.0
			and process.spread <= 15.0 and process.gravity == Vector3.ZERO)
	_check("neve sem sombra, partículas no mundo", particles.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not particles.local_coords)
	var material: StandardMaterial3D = flake.material
	var color: Color = material.albedo_color
	_check("neve fria sem estourar o branco", color.r <= 0.85 and color.g <= 0.85 and color.b <= 0.85 and color.b > color.r and color.a > 0.0 and color.a < 1.0)
	_check("billboard sem luz e com transparência", material.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
	var texture: GradientTexture2D = material.albedo_texture as GradientTexture2D
	_check("máscara radial com borda transparente", texture != null and texture.fill == GradientTexture2D.FILL_RADIAL and texture.gradient.get_color(0).a == 1.0 and texture.gradient.get_color(1).a == 0.0)
	for zone: Rect2 in snow.areas:
		_move(snow, player, Vector3(zone.get_center().x, 1.0, zone.get_center().y))
		_check("neva dentro da zona %s" % str(zone), snow.is_raining())
		_check("emissor acompanha o jogador", particles.global_position.is_equal_approx(player.global_position + Vector3(0.0, 10.0, 0.0)))
	for point: Vector2 in [Vector2(1030.0, 1010.0), Vector2(1100.0, 1100.0)]:
		_move(snow, player, Vector3(point.x, 1.0, point.y))
		_check("não neva fora das zonas %s" % str(point), not snow.is_raining())
	_move(snow, player, Vector3(1010.0, 1.0, 1010.0))
	for pair: Array in [["alta", 1.0], ["media", 0.6], ["leve", 0.25]]:
		config.set_quality(pair[0])
		snow.set_weather("chuva_fraca", 0.5)  # a troca de qualidade reenvia o tempo da cidade (limpo)
		var expected: float = 500.0 * 0.7 * float(pair[1])
		_check("neve %s: intensidade e qualidade = %d (%d)" % [pair[0], roundi(expected), snow.emitted("main")],
				absf(snow.emitted("main") - expected) <= 2.0)
	config.set_quality("alta")
	snow.set_weather("chuva_forte", 1.0)
	_check("nevasca: mais flocos, mais rápidos e mais de lado",
			absf(snow.emitted("main") - 1600.0 * 0.7 * 2.5 / 1.5) <= 2.0
			and process.initial_velocity_min > 2.0 and process.direction.x > 0.3)
	snow.set_weather("limpo", 0.0)
	_move(snow, player, Vector3(1010.0, 1.0, 1010.0))
	_check("limpo: não neva", not snow.is_raining())
	snow_spec.intensity = 0.0
	snow.call("_apply_amount")
	_check("intensidade zero mantém mínimo seguro de uma partícula", particles.amount == 1)
	snow.free()


func _check_leaves_and_dust(weather_script: GDScript, city: Node, player: Node3D) -> void:
	print("== folhas e poeira ==")
	var spot := Vector3(1010.0, 1.0, 1010.0)
	var leaves_spec := WeatherSpec.new()
	leaves_spec.kind = "folhas"
	var forest: Node = weather_script.new()
	forest.spec = leaves_spec
	forest.areas = [Rect2(1000.0, 1000.0, 20.0, 20.0)] as Array[Rect2]
	city.add_child(forest)
	forest.set_process(false)
	forest.set_weather("chuva_forte", 1.0)
	_move(forest, player, spot)
	var leaves: GPUParticles3D = forest.get_node_or_null("Leaves")
	_check("folhas: a chuva de sempre, com folhas caindo", forest.is_raining() and leaves != null
			and leaves.emitting and forest.get_node_or_null("RainSound") != null)
	_check("folhas: 120 na forte", absi(forest.emitted("leaves") - 120) <= 1)
	forest.set_weather("chuva_fraca", 0.5)
	_check("folhas: 40 na fraca", absi(forest.emitted("leaves") - 40) <= 1)
	forest.free()

	var dust_spec := WeatherSpec.new()
	dust_spec.kind = "poeira"
	var desert: Node = weather_script.new()
	desert.spec = dust_spec
	desert.areas = [Rect2(1000.0, 1000.0, 20.0, 20.0)] as Array[Rect2]
	city.add_child(desert)
	desert.set_process(false)
	desert.set_weather("chuva_forte", 1.0)
	_move(desert, player, spot)
	var dust: GPUParticles3D = desert.get_node_or_null("Dust")
	_check("poeira: nuvens de poeira, sem gota nem respingo", dust != null and desert.is_raining()
			and desert.get_node_or_null("Rain") == null and desert.get_node_or_null("Splashes") == null)
	var dust_process: ParticleProcessMaterial = dust.process_material if dust != null else null
	_check("poeira: o vento leva de lado, rente ao chão", dust_process != null
			and absf(dust_process.direction.y) < 0.2 and desert.rain_origin(spot).y < spot.y + 2.0)
	desert.call("_process", 100.0)
	var sound: AudioStreamPlayer = desert.get_node_or_null("DustSound")
	_check("poeira: o som do vento", sound != null and sound.playing)
	_check("poeira: 160 nuvens na forte", absi(desert.emitted("main") - 160) <= 1)
	desert.free()


func _move(weather: Node, player: Node3D, point: Vector3) -> void:
	player.global_position = point
	# Atualização direta evita que a física mova o jogador entre as conferências.
	weather.call("_process", 0.0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
