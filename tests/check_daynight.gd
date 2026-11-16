extends SceneTree
## Fase 6, etapa 4: relógio de dia e noite.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app := root.get_node("AppConfig")
	var original_sky: String = app.get_sky()
	app.set_sky("fotos")  # o teste mede o sol do céu de fotos (no Sky3D ele fica vazio)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	var day_night = city._day_night
	var script = load("res://worlds/city/day_night.gd")

	print("== quanto é noite em cada hora ==")
	var line := ""
	for h in [0, 3, 5, 5.5, 6, 6.5, 7, 12, 17, 17.5, 18, 18.5, 19, 21, 23]:
		line += "%s h=%.2f  " % [str(h), script.night_amount(h)]
	print("   ", line)
	_check("meio-dia é dia (0)", script.night_amount(12.0) == 0.0)
	_check("meia-noite é noite (1)", script.night_amount(0.0) == 1.0)
	_check("18h30 está escurecendo (entre 0 e 1)", script.night_amount(18.5) > 0.0 and script.night_amount(18.5) < 1.0)

	print("\n== F8 adianta 3 horas ==")
	var before: float = day_night.current_hour()
	var messages := []
	day_night.clock_advanced.connect(func(h): messages.append(h))
	var f8 := InputEventAction.new()
	f8.action = "advance_time"
	f8.pressed = true
	Input.parse_input_event(f8)
	await process_frame
	await process_frame
	# Desde a 19.4 as 3 horas passam em ADVANCE_SECONDS (a luz não pula).
	var halfway: float = day_night.current_hour()
	_check("o F8 passa as horas aos poucos (ainda andando)", day_night.is_advancing()
			and fposmod(halfway - before, 24.0) < 2.9)
	_check("o aviso já sai com a hora de chegada", messages.size() == 1
			and absf(fposmod(float(messages[0]) - before, 24.0) - 3.0) < 0.05)
	await create_timer(script.ADVANCE_SECONDS + 0.3).timeout
	var after: float = day_night.current_hour()
	print("   antes %.2f h -> depois %.2f h | HUD: '%s'" % [before, after, city.get_node("Player").get_hud().get_messages()])
	_check("relógio andou 3 h", absf(fposmod(after - before, 24.0) - 3.0) < 0.05 and not day_night.is_advancing())
	# Mudar a hora por fora (menu, captura) interrompe a passagem.
	day_night.advance_clock(3.0)
	day_night.hour_offset = 0.0
	_check("mudar a hora por fora para a passagem do F8", not day_night.is_advancing())

	print("\n== à noite, postes e janelas acendem ==")
	_set_hour(day_night, city, 23.0)
	# (postes queimados de propósito, como o do bairro Terror, não contam; nem
	# a luz do dia que entra pela janela da casa, que faz o contrário)
	var home: Node = city.get_home()
	var lights := root.find_children("*", "SpotLight3D", true, false).filter(func(l): return not l.get_parent().get("broken") and not home.is_ancestor_of(l))
	var lit := lights.filter(func(l): return l.visible and l.light_energy > 0.5).size()
	var building = city.get_node("Building_2379780")
	print("   23h: %d de %d postes acesos | janelas: brilho %.2f | sol %.2f" % [lit, lights.size(), building._walls_material.get_shader_parameter("night"), day_night.sun.light_energy])
	_check("todos os postes acesos às 23h", lit == lights.size() and lights.size() > 0)
	_check("janelas brilhando às 23h", building._walls_material.get_shader_parameter("night") > 0.9)
	_set_hour(day_night, city, 13.0)
	lit = lights.filter(func(l): return l.visible).size()
	print("   13h: %d postes acesos | janelas: brilho %.2f | sol %.2f" % [lit, building._walls_material.get_shader_parameter("night"), day_night.sun.light_energy])
	_check("tudo apagado às 13h", lit == 0 and building._walls_material.get_shader_parameter("night") == 0.0)

	print("\n== o dia com contraste (17.6), sem mexer na noite (17.5) ==")
	# Desde a 19.4 os valores são dado (profiles/day_cycle.tres): o meio-dia e a
	# noite do ciclo são os da 17.6 e da 17.5 (o check_day_cycle confere).
	var env: Environment = day_night.environment
	var noon: DayMoment = Profiles.day_cycle().sample(13.0)
	var midnight: DayMoment = Profiles.day_cycle().sample(23.0)
	_check("o meio-dia do ciclo tem o contraste da 17.6 (menos luz do céu, curva em S, cor viva)",
			noon.ambient < 1.0 and noon.agx_contrast > Environment.new().tonemap_agx_contrast and noon.saturation > 1.0)
	for sky: String in ["fotos", "sky3d"]:
		city._apply_sky(sky)
		var night_ambient: float = midnight.ambient_sky3d if sky == "sky3d" else midnight.ambient
		var day_ambient: float = noon.ambient_sky3d if sky == "sky3d" else noon.ambient
		_set_hour(day_night, city, 13.0)
		print("   %s 13h: ambiente %.2f | contraste %.2f | saturação %.2f | momento %s" % [sky, env.ambient_light_energy,
				env.tonemap_agx_contrast, env.adjustment_saturation, day_night.current_moment()])
		_check("%s: de dia, menos luz do céu, curva em S e cor viva" % sky,
				is_equal_approx(env.ambient_light_energy, day_ambient)
				and is_equal_approx(env.tonemap_agx_contrast, noon.agx_contrast)
				and env.adjustment_enabled and is_equal_approx(env.adjustment_saturation, noon.saturation))
		_check("%s: às 13h o momento é o meio-dia" % sky, day_night.current_moment() == "meio-dia")
		if sky == "sky3d":
			_check("sky3d: o sol do dia mais forte", is_equal_approx(day_night.sky3d.sun_energy, noon.sky3d_sun_energy)
					and noon.sky3d_sun_energy > 1.0)
		_set_hour(day_night, city, 23.0)
		print("   %s 23h: ambiente %.2f | contraste %.2f | saturação %.2f" % [sky, env.ambient_light_energy,
				env.tonemap_agx_contrast, env.adjustment_saturation])
		_check("%s: à noite, os valores da 17.5 (contraste padrão, cor sem ajuste)" % sky,
				is_equal_approx(env.ambient_light_energy, night_ambient)
				and is_equal_approx(env.tonemap_agx_contrast, Environment.new().tonemap_agx_contrast)
				and is_equal_approx(env.adjustment_saturation, 1.0)
				and is_equal_approx(env.tonemap_exposure, pow(2.0, midnight.exposure_ev)))
		if sky == "sky3d":
			_check("sky3d: à noite, o sol volta ao padrão", is_equal_approx(day_night.sky3d.sun_energy, 1.0))
	city._apply_sky("fotos")

	print("\n== o dia em momentos (19.4): a tarde é dourada também no Sky3D ==")
	for sky: String in ["fotos", "sky3d"]:
		city._apply_sky(sky)
		_set_hour(day_night, city, 16.25)
		var gold: Color = day_night.sky3d.sky.sun_light_color if sky == "sky3d" else day_night.sun.light_color
		_check("%s: às 16h15 o momento é a tarde e o sol é dourado" % sky,
				day_night.current_moment() == "tarde" and gold.b < gold.r * 0.75)
		_set_hour(day_night, city, 9.0)
		_check("%s: às 9h, a manhã, com a névoa mais leve que a do meio-dia" % sky,
				day_night.current_moment() == "manha" and env.fog_density < noon.fog_density)
	city._apply_sky("fotos")

	print("\n== mistura da névoa do bioma ==")
	for hour: float in [6.0, 13.0, 18.25, 23.0]:
		_set_hour(day_night, city, hour)
		var original: Array = _fog_snapshot(env)
		day_night.set_fog_overlay(0.0, 3.0, Color.RED, 1.0, 12.0, 0.03)
		_check("peso zero preserva exatamente a névoa às %.2fh" % hour, _fog_snapshot(env) == original)
		day_night.set_fog_overlay(0.6, 2.0, Color(0.65, 0.72, 0.82), 0.3, 8.0, 0.01)
		_check_overlay(day_night, "aplicada imediatamente às %.2fh" % hour)
		day_night.set_fog_overlay(0.0, 1.0, Color.WHITE, 0.0)
		_check("sair do bioma restaura a névoa às %.2fh" % hour, _fog_snapshot(env) == original)
		# O relógio real pode virar o segundo: confira a nova base separadamente.
		day_night.set_fog_overlay(0.6, 2.0, Color(0.65, 0.72, 0.82), 0.3, 8.0, 0.01)
		day_night.update_now()
		_check_overlay(day_night, "relógio não acumula nem apaga a mistura")
		day_night.set_fog_overlay(0.0, 1.0, Color.WHITE, 0.0)
	day_night.set_fog_overlay(0.6, 2.0, Color(0.65, 0.72, 0.82), 0.3, 8.0, 0.01)
	day_night._unhandled_input(f8)
	_check_overlay(day_night, "F8 mantém a mistura na mesma chamada")
	for sky: String in ["sky3d", "fotos"]:
		city._apply_sky(sky)
		_check_overlay(day_night, "troca de céu para %s mantém a mistura" % sky)
	for quality: String in ["leve", "media", "alta"]:
		GraphicsQuality.apply_to_environment(env, quality)
		day_night.update_now()
		_check_overlay(day_night, "qualidade %s mantém a mistura" % quality)
		_check("névoa comum segue ligada em %s" % quality, env.fog_enabled)
		if quality == "leve":
			_check("bruma funciona sem névoa volumétrica", not env.volumetric_fog_enabled and env.fog_height_density > 0.0)
	# Um Environment novo também recebe a mistura imediatamente.
	var replacement: Environment = Environment.new()
	replacement.fog_height = 2.0
	replacement.fog_height_density = 0.002
	day_night.environment = replacement
	_check("ambiente substituído mantém densidade e cor", replacement.fog_density == env.fog_density
			and replacement.fog_light_color == env.fog_light_color)
	_check("altura mistura sobre a base do ambiente novo", is_equal_approx(replacement.fog_height, 5.6)
			and is_equal_approx(replacement.fog_height_density, 0.0068))
	day_night.set_fog_overlay(0.0, 1.0, Color.WHITE, 0.0)
	_check("peso zero restaura altura própria do ambiente novo", is_equal_approx(replacement.fog_height, 2.0)
			and is_equal_approx(replacement.fog_height_density, 0.002))
	city.queue_free()
	await process_frame
	app.set_sky(original_sky)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _fog_snapshot(env: Environment) -> Array:
	return [env.fog_density, env.fog_light_color, env.fog_height, env.fog_height_density]


func _check_overlay(day_night: Node, label: String) -> void:
	var env: Environment = day_night.environment
	var observed: Array = _fog_snapshot(env)
	day_night.set_fog_overlay(0.0, 1.0, Color.WHITE, 0.0)
	_check(label, is_equal_approx(observed[0], env.fog_density * 1.6)
			and (observed[1] as Color).is_equal_approx(env.fog_light_color.lerp(
					day_night.tint_keeping_brightness(env.fog_light_color, Color(0.65, 0.72, 0.82)), 0.18))
			and is_equal_approx(observed[2], 4.8) and is_equal_approx(observed[3], 0.006))
	day_night.set_fog_overlay(0.6, 2.0, Color(0.65, 0.72, 0.82), 0.3, 8.0, 0.01)


func _set_hour(day_night, city, hour: float) -> void:
	day_night.hour_offset += hour - day_night.current_hour()
	day_night.update_now()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
