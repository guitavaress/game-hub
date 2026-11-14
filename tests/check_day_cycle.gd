extends SceneTree
## Fase 19.4: o dia em momentos (profiles/day_cycle.tres).
##   - o arquivo é o que o gerador faz (ninguém mexeu à mão);
##   - às 13h e às 22h (e nas horas fixas do menu) a cidade fica como antes;
##   - o "quanto é noite" (o que acende postes e janelas) é igual ao de antes,
##     minuto a minuto, nas 24 horas;
##   - nenhuma passagem tem pulo: de um minuto para o seguinte, nada muda mais
##     que JUMP_LIMIT da faixa de cada valor no dia;
##   - o nascer do sol é rosado e tem o brilho no leste; a manhã é fria e
##     limpa; a tarde é dourada.

## O maior passo permitido entre dois minutos, em fração da faixa do valor no
## dia inteiro (0,05 = a passagem mais curta leva pelo menos 20 minutos).
const JUMP_LIMIT: float = 0.05
const IDS: Array[String] = ["madrugada", "nascer", "manha", "meio-dia", "tarde", "por-do-sol", "anoitecer", "noite"]

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var generator: GDScript = load("res://tools/gerar_ciclo_do_dia.gd")
	var clock_script: GDScript = load("res://worlds/city/day_night.gd")
	var cycle: DayCycleSpec = load("res://profiles/day_cycle.tres") as DayCycleSpec

	print("== o arquivo ==")
	_check("profiles/day_cycle.tres é um DayCycleSpec", cycle != null)
	if cycle == null:
		_finish()
		return
	_check("a lista está certa (%s)" % ", ".join(cycle.problems()), cycle.problems().is_empty())
	var ids: Array[String] = []
	for moment: DayMoment in cycle.moments:
		ids.append(moment.id)
	_check("os momentos, em ordem: %s" % ", ".join(ids), ids == IDS)
	var generated: DayCycleSpec = generator.ciclo()
	var same: bool = generated.moments.size() == cycle.moments.size()
	for i: int in mini(generated.moments.size(), cycle.moments.size()):
		same = same and _differences(generated.moments[i], cycle.moments[i]).is_empty()
	_check("o arquivo é o que o gerador faz (regerar dá o mesmo dado)", same)
	_check("Profiles.day_cycle() lê o mesmo arquivo", Profiles.day_cycle().moments.size() == cycle.moments.size())

	print("\n== às 13h e às 22h, como antes ==")
	for hour: float in [13.0, clock_script.FIXED_DAY_HOUR, 22.0, clock_script.FIXED_NIGHT_HOUR, 0.0, 3.0]:
		var diff: PackedStringArray = _differences(cycle.sample(hour), generator.hoje(hour))
		_check("%.1fh: todos os valores iguais aos de antes %s" % [hour, diff], diff.is_empty())

	print("\n== o quanto é noite, minuto a minuto ==")
	var night_same: bool = true
	for minute: int in 24 * 60 + 1:
		var hour: float = minute / 60.0
		night_same = night_same and clock_script.night_amount(hour) == _old_night_amount(hour)
	_check("night_amount igual ao de antes nas 24 horas (1441 minutos)", night_same)

	print("\n== sem pulo entre dois minutos ==")
	var samples: Array[DayMoment] = []
	for minute: int in 24 * 60 + 1:
		samples.append(cycle.sample(minute / 60.0))
	var weights_ok: bool = true
	for moment: DayMoment in samples:
		weights_ok = weights_ok and absf(moment.sky_day + moment.sky_sunset + moment.sky_night - 1.0) < 0.001
	_check("as três fotos do céu somam 1 em todo minuto", weights_ok)
	for property: String in DayMoment.mixed_properties():
		var worst: Dictionary = _worst_jump(samples, property)
		_check("%s: maior passo %.1f%% da faixa (às %s)" % [property, worst["share"] * 100.0, worst["at"]],
				worst["share"] <= JUMP_LIMIT)
	_check("o dia dá a volta sem pulo (24h = 0h)", _differences(samples[0], samples[24 * 60]).is_empty())

	print("\n== o mesmo, no céu de verdade (DayNight aplicando minuto a minuto) ==")
	_check_applied(clock_script, cycle)

	print("\n== os momentos novos ==")
	var noon: DayMoment = cycle.sample(13.0)
	var dawn: DayMoment = cycle.sample(6.5)
	var morning: DayMoment = cycle.sample(8.5)
	var afternoon: DayMoment = cycle.sample(16.25)
	_check("nascer: a foto do pôr do sol domina", dawn.sky_sunset > 0.5)
	_check("nascer: o céu puxa para o rosa (vermelho acima do verde e do azul)",
			dawn.sky_tint.r > dawn.sky_tint.g + 0.05 and dawn.sky_tint.r > dawn.sky_tint.b + 0.05)
	_check("nascer: o sol mais rosado que o de hoje às 6h30 (menos verde)",
			dawn.sun_color.g < (load("res://tools/gerar_ciclo_do_dia.gd") as GDScript).call("hoje", 6.5).sun_color.g)
	_check("manhã: sol mais frio que o do meio-dia",
			morning.sun_color.b / morning.sun_color.r > noon.sun_color.b / noon.sun_color.r)
	_check("manhã: menos névoa que o meio-dia", morning.fog_density < noon.fog_density)
	_check("tarde: sol mais dourado que o do meio-dia",
			afternoon.sun_color.b / afternoon.sun_color.r < noon.sun_color.b / noon.sun_color.r - 0.15)
	_check("tarde: a sombra mais marcada", afternoon.shadow_opacity > noon.shadow_opacity)
	_check("o momento das 10h é a manhã; das 17h, a tarde; das 22h, a noite",
			cycle.moment_at(10.0).id == "manha" and cycle.moment_at(17.0).id == "tarde"
			and cycle.moment_at(22.0).id == "noite" and cycle.moment_at(3.0).id == "noite")
	_finish()


## Liga um DayNight fora da cena a um céu de fotos falso e confere, minuto a
## minuto, o que ele põe no ambiente, no céu e no sol.
func _check_applied(clock_script: GDScript, cycle: DayCycleSpec) -> void:
	var clock: Node = clock_script.new()
	clock.cycle = cycle
	var env := Environment.new()
	clock.environment = env
	var sky := ShaderMaterial.new()
	sky.shader = load("res://worlds/city/sky_blend.gdshader")
	clock.sky_material = sky
	var sun := DirectionalLight3D.new()
	clock.sun = sun
	var readings: Dictionary[String, Callable] = {
		"exposição": func() -> float: return env.tonemap_exposure,
		"densidade da névoa": func() -> float: return env.fog_density,
		"luz ambiente": func() -> float: return env.ambient_light_energy,
		"contraste": func() -> float: return env.tonemap_agx_contrast,
		"força do sol": func() -> float: return sun.light_energy,
		"vermelho do sol": func() -> float: return sun.light_color.r,
		"azul do sol": func() -> float: return sun.light_color.b,
		"altura do sol": func() -> float: return sun.rotation.x,
		"foto do pôr do sol": func() -> float: return float(sky.get_shader_parameter("sunset_weight")),
		"tom do céu (verde)": func() -> float: return (sky.get_shader_parameter("tint") as Color).g,
	}
	var values: Dictionary[String, PackedFloat32Array] = {}
	for name: String in readings:
		values[name] = PackedFloat32Array()
	var east_at_dawn: bool = true
	var nights: Array[float] = []
	clock.night_changed.connect(func(night: float) -> void: nights.append(night))
	for minute: int in 24 * 60 + 1:
		var hour: float = minute / 60.0
		clock.apply_hour(hour)
		for name: String in readings:
			values[name].append(readings[name].call())
		if hour >= 5.5 and hour < 9.0:
			# Na foto, o leste fica em u = 0,75: o brilho do pôr do sol vira para lá.
			east_at_dawn = east_at_dawn and is_equal_approx(float(sky.get_shader_parameter("sunset_rotation")),
					clock.sunset_glow_u - 0.75)
	for name: String in readings:
		var series: PackedFloat32Array = values[name]
		var low: float = INF
		var high: float = -INF
		for value: float in series:
			low = minf(low, value)
			high = maxf(high, value)
		var range_size: float = maxf(high - low, 0.0001)
		var worst: float = 0.0
		var at: int = 0
		for i: int in range(1, series.size()):
			var step: float = absf(series[i] - series[i - 1]) / range_size
			if step > worst:
				worst = step
				at = i
		_check("%s: maior passo %.1f%% da faixa (às %s)" % [name, worst * 100.0, _clock_text(at)],
				worst <= JUMP_LIMIT)
	_check("de manhã, o brilho da foto do pôr do sol fica no leste", east_at_dawn)
	# O aviso só sai quando a noite muda mais que 0,005 (como antes): o último
	# valor pode ficar a um passo do 0 ou do 1.
	_check("o aviso de noite ainda chega (night_changed: de 0 a 1)", nights.size() > 10
			and float(nights.min()) < 0.01 and float(nights.max()) > 0.99)
	clock.apply_hour(13.0)
	_check("13h no céu de fotos: tom branco, sol e ambiente do meio-dia",
			(sky.get_shader_parameter("tint") as Color).is_equal_approx(Color.WHITE)
			and is_equal_approx(sun.light_energy, generator_noon().sun_energy)
			and is_equal_approx(env.ambient_light_energy, generator_noon().ambient))
	sun.free()
	clock.free()


func generator_noon() -> DayMoment:
	return (load("res://tools/gerar_ciclo_do_dia.gd") as GDScript).call("hoje", 13.0)


## A conta do "quanto é noite" até a Fase 19.3, copiada: o contrato do grupo
## city_night é este, e não pode mudar.
func _old_night_amount(hour: float) -> float:
	var daylight := smoothstep(5.5, 7.0, hour) - smoothstep(17.5, 19.0, hour)
	return 1.0 - clampf(daylight, 0.0, 1.0)


## O maior passo de um valor entre minutos seguidos, em fração da faixa dele.
func _worst_jump(samples: Array[DayMoment], property: String) -> Dictionary:
	var series: Array[Variant] = []
	for moment: DayMoment in samples:
		series.append(moment.get(property))
	var worst: float = 0.0
	var at: int = 0
	var channels: int = 4 if series[0] is Color else 1
	for channel: int in channels:
		var low: float = INF
		var high: float = -INF
		for value: Variant in series:
			var number: float = _channel(value, channel)
			low = minf(low, number)
			high = maxf(high, number)
		var range_size: float = high - low
		if range_size < 0.000001:
			continue
		for i: int in range(1, series.size()):
			var step: float = absf(_channel(series[i], channel) - _channel(series[i - 1], channel)) / range_size
			if step > worst:
				worst = step
				at = i
	return {"share": worst, "at": _clock_text(at)}


func _channel(value: Variant, channel: int) -> float:
	if value is Color:
		var color: Color = value
		return [color.r, color.g, color.b, color.a][channel]
	return float(value)


## Os campos de número e de cor que diferem entre dois momentos.
func _differences(a: DayMoment, b: DayMoment) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for property: String in DayMoment.mixed_properties():
		var x: Variant = a.get(property)
		var y: Variant = b.get(property)
		var equal: bool = (x as Color).is_equal_approx(y) if x is Color else is_equal_approx(float(x), float(y))
		if not equal:
			found.append(property)
	return found


func _clock_text(minute: int) -> String:
	return "%02d:%02d" % [floori(minute / 60.0), minute % 60]


func _finish() -> void:
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
