extends SceneTree
## Fase 6, etapa 4: relógio de dia e noite.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
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
	var after: float = day_night.current_hour()
	print("   antes %.2f h -> depois %.2f h | HUD: '%s'" % [before, after, city.get_node("Player").get_hud().get_messages()])
	_check("relógio andou 3 h", absf(fposmod(after - before, 24.0) - 3.0) < 0.05)

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

	print("\n== mistura da névoa do bioma ==")
	var env: Environment = day_night.environment
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
