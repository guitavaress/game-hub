extends SceneTree
## Teste do tempo da cidade (Fase 19.6): o WeatherDirector e o contrato com o
## céu (DayNight.set_weather_overlay). Guarda o config.cfg e devolve no fim.
##   1. os modos do menu batem com os tempos do diretor;
##   2. mesma semente, mesmo tempo (o sorteio é determinístico);
##   3. as passagens não têm salto e só vão a um tempo vizinho; as durações
##      ficam dentro da tabela; em um dia, todos os tempos aparecem;
##   4. "sempre limpo" desliga tudo; um tempo fixo fica fixo; trocar no menu
##      passa devagar;
##   5. o céu: com 0 tudo fica como sem tempo; fechado, menos sol e mais névoa;
##      o momento do relógio (get_moment e o .tres) não muda;
##   6. na cidade: rodando um teste, o tempo abre limpo; forçar põe o céu e o
##      chão na hora; o fim de uma passagem avisa a janela da casa (adiado);
##      sair da cena devolve o céu aberto e o chão seco.

const CONFIG := "user://config.cfg"

var failures := 0
## Por load: este teste compila antes dos autoloads (o diretor usa o AppConfig).
var WD: GDScript


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	WD = load("res://worlds/city/weather_director.gd")
	var backup := FileAccess.get_file_as_string(CONFIG)
	var app := root.get_node("AppConfig")
	app.set_weather("dinamico")
	_check_modes(app)
	_check_determinism()
	_check_passages()
	_check_fixed_modes(app)
	await _check_sky_contract()
	await _check_city(app)
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Um diretor solto (sem cena), com a semente dada.
func _director(seed_value: int) -> Node:
	var director: Node = WD.new()
	director.start(seed_value)
	return director


## Os tempos de "hours" horas, um por minuto (passos de 1 s).
func _simulate(director: Node, hours: float) -> Array[String]:
	var states: Array[String] = []
	for second in int(hours * 3600.0):
		director.step(1.0)
		if second % 60 == 0:
			states.append(director.current_state())
	return states


func _check_modes(app: Node) -> void:
	print("== os modos do menu ==")
	_check("os modos do AppConfig = os do diretor (%s)" % str(WD.modes()),
			Array(app.WEATHER_MODES) == Array(WD.modes()))
	_check("o padrão é o dinâmico", app.WEATHER_MODES[0] == "dinamico" and app.get_weather() == "dinamico")
	app.set_weather("granizo")
	_check("modo desconhecido é ignorado", app.get_weather() == "dinamico")
	var chances := 0.0
	for state: String in WD.START_CHANCES:
		chances += float(WD.START_CHANCES[state])
	_check("as chances do começo somam 1", is_equal_approx(chances, 1.0))
	var tables_ok := true
	for state: String in WD.STATES:
		var total := 0.0
		for next: String in WD.STATES[state]["next"]:
			total += float(WD.STATES[state]["next"][next])
			tables_ok = tables_ok and WD.STATES.has(next) and next != state
		tables_ok = tables_ok and is_equal_approx(total, 1.0)
	_check("cada tempo leva a outro tempo que existe, com chances que somam 1", tables_ok)


func _check_determinism() -> void:
	print("== mesma semente, mesmo tempo ==")
	var date := {"year": 2026, "month": 11, "day": 14}
	var seed_value: int = WD.seed_for(date, 13.4)
	_check("a semente depende da data e da hora cheia",
			seed_value == WD.seed_for(date, 13.9)
			and seed_value != WD.seed_for(date, 14.0)
			and seed_value != WD.seed_for({"year": 2026, "month": 11, "day": 15}, 13.4))
	var first := _simulate(_director(seed_value), 6.0)
	var again := _simulate(_director(seed_value), 6.0)
	_check("a mesma semente dá o mesmo tempo, minuto a minuto (6 h)", first == again)
	var other_differs := false
	for hour in 24:
		if _simulate(_director(WD.seed_for(date, hour)), 6.0) != first:
			other_differs = true
			break
	_check("outra semente dá outro tempo", other_differs)


func _check_passages() -> void:
	print("== as passagens ==")
	var director: Node = _director(WD.seed_for({"year": 2026, "month": 11, "day": 14}, 9.0))
	var cover: float = director.current_cover()
	var strength: float = director.current_strength()
	var wet: float = director.current_wetness()
	var biggest := 0.0
	var biggest_wet := 0.0
	var neighbors_only := true
	var seen: Dictionary = {director.current_state(): true}
	var durations_ok := true
	var last_state: String = director.current_state()
	var settled_for := 0.0
	var first_settle := true
	var changes := 0
	for second in 24 * 3600:
		director.step(1.0)
		biggest = maxf(biggest, maxf(absf(director.current_cover() - cover), absf(director.current_strength() - strength)))
		biggest_wet = maxf(biggest_wet, absf(director.current_wetness() - wet))
		cover = director.current_cover()
		strength = director.current_strength()
		wet = director.current_wetness()
		if not director.is_passing():
			settled_for += 1.0
		if director.current_state() != last_state:
			changes += 1
			neighbors_only = neighbors_only and WD.STATES[last_state]["next"].has(director.current_state())
			# A duração assentada do tempo que acabou (o primeiro começa no meio).
			var minutes: Vector2 = WD.STATES[last_state]["minutes"]
			if not first_settle:
				durations_ok = durations_ok and settled_for <= minutes.y * 60.0 + 2.0 and settled_for >= minutes.x * 60.0 - 2.0
			first_settle = false
			settled_for = 0.0
			last_state = director.current_state()
			seen[last_state] = true
	print("  (um dia: %d trocas; maior passo por segundo: %.4f)" % [changes, biggest])
	_check("nenhuma passagem tem salto (a cada segundo, no máximo 3%% do céu e da força)", biggest <= 0.03)
	_check("o chão molha e seca aos poucos (%.3f por segundo)" % biggest_wet,
			biggest_wet <= 1.0 / WD.WET_SECONDS + 0.001)
	_check("só se passa a um tempo vizinho (do limpo não se vai à chuva forte)", neighbors_only)
	_check("cada tempo dura o que a tabela diz", durations_ok)
	_check("em um dia, os quatro tempos aparecem (%s)" % str(seen.keys()), seen.size() == WD.STATES.size())
	_check("o tempo muda várias vezes num dia", changes >= 10)
	_check("o chão molha mais na forte que na fraca",
			WD.wet_for(1.0) == 1.0 and is_equal_approx(WD.wet_for(0.5), 0.6)
			and WD.wet_for(0.0) == 0.0)


func _check_fixed_modes(app: Node) -> void:
	print("== sempre limpo e tempos fixos ==")
	var director: Node = _director(1)
	root.add_child(director)  # no _ready: o modo vem do -s (limpo)
	_check("rodando um teste (-s), o tempo abre limpo", director.current_mode() == "limpo"
			and director.current_state() == "limpo" and director.current_cover() == 0.0
			and director.current_strength() == 0.0)
	var always_clear := true
	for second in 3 * 3600:
		director.step(1.0)
		always_clear = always_clear and director.current_state() == "limpo" and director.current_strength() == 0.0
	_check("sempre limpo: 3 horas sem nuvem nem chuva", always_clear and director.current_wetness() == 0.0)
	director.force("chuva_forte")
	_check("forçar a chuva forte: tudo na hora", director.current_strength() == 1.0
			and is_equal_approx(director.current_cover(), 0.9) and director.current_wetness() == 1.0
			and not director.is_passing())
	for second in 3600:
		director.step(1.0)
	_check("forçado, o tempo fica (1 hora)", director.current_state() == "chuva_forte")
	director.force("")
	_check("soltar volta ao modo (limpo), devagar", director.current_state() == "limpo" and director.is_passing())
	for second in 30:
		director.step(1.0)
	_check("depois da passagem: céu aberto e sem chuva; o chão seca devagar",
			director.current_cover() == 0.0 and director.current_strength() == 0.0
			and director.current_wetness() > 0.0 and director.current_wetness() < 1.0)
	for second in 120:
		director.step(1.0)
	_check("e seca de todo", director.current_wetness() == 0.0)
	director.force("granizo")
	_check("tempo desconhecido é ignorado", director.forced_state() == "")
	# Revisão da 19.6: voltando ao dinâmico, a duração é a do tempo de agora
	# (sobrava a sorteada na abertura, e a chuva forte durava até 20 min).
	director._remaining = 20.0 * 60.0
	director._set_mode("chuva_forte", true)
	director._set_mode("dinamico", false)
	_check("de um tempo fixo ao dinâmico: a chuva forte dura de 2 a 4 min (%.0f s)" % director._remaining,
			director._remaining >= 120.0 and director._remaining <= 240.0)
	director._remaining = 20.0 * 60.0
	director.force("chuva_forte")
	director.force("")
	_check("soltar um tempo forçado no dinâmico: a duração também é sorteada de novo",
			director._remaining >= 120.0 and director._remaining <= 240.0)
	director.free()


func _check_sky_contract() -> void:
	print("== o contrato com o céu ==")
	var environment := Environment.new()
	environment.fog_enabled = true
	var sun := DirectionalLight3D.new()
	var sky := ShaderMaterial.new()
	sky.shader = load("res://worlds/city/sky_blend.gdshader")
	var clock: Node = load("res://worlds/city/day_night.gd").new()
	clock.environment = environment
	clock.sun = sun
	clock.sky_material = sky
	root.add_child(sun)
	clock.apply_hour(13.0)
	var before := _sky_values(environment, sun)
	var cycle: Resource = clock.get_cycle()
	var noon: Resource = cycle.moment_at(13.0)
	var noon_fog: float = noon.fog_density
	var noon_sun: float = noon.sun_energy
	clock.set_weather_overlay(1.0)
	clock.apply_hour(13.0)
	var closed := _sky_values(environment, sun)
	_check("fechado: menos sol e sombra mais fraca", closed["sun"] < before["sun"] and closed["shadow"] < before["shadow"])
	_check("fechado: mais névoa, cobrindo mais o céu", closed["fog"] > before["fog"] and closed["fog_sky"] > before["fog_sky"])
	_check("fechado: cor menos viva", closed["saturation"] < before["saturation"])
	_check("o momento do relógio não muda (get_moment e o .tres)",
			clock.get_moment().fog_density == noon_fog and clock.get_moment().sun_energy == noon_sun
			and noon.fog_density == noon_fog and noon.sun_energy == noon_sun)
	_check("o céu fechado é o que se pediu", clock.get_weather_overlay() == 1.0)
	clock.set_weather_overlay(5.0)
	_check("fora da faixa: fica em 1", clock.get_weather_overlay() == 1.0)
	clock.set_weather_overlay(0.0)
	clock.apply_hour(13.0)
	_check("com 0, tudo exatamente como antes", _sky_values(environment, sun) == before)
	clock.free()
	sun.free()


func _sky_values(environment: Environment, sun: DirectionalLight3D) -> Dictionary:
	return {"sun": sun.light_energy, "shadow": sun.shadow_opacity, "fog": environment.fog_density,
			"fog_color": environment.fog_light_color, "fog_sky": environment.fog_sky_affect,
			"saturation": environment.adjustment_saturation}


func _check_city(app: Node) -> void:
	print("== na cidade ==")
	load("res://tests/quiet_friends.gd").install(root)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame
	var director: Node = city.get_node_or_null("WeatherDirector")
	_check("a cidade tem um WeatherDirector, ligado ao relógio", director != null and director.day_night == city._day_night)
	if director == null:
		city.free()
		return
	var day_night: Node = city._day_night
	var decor: GDScript = load("res://worlds/city/city_decor.gd")
	_check("rodando um teste, a cidade abre com o tempo limpo", director.current_state() == "limpo"
			and day_night.get_weather_overlay() == 0.0 and decor.ground_wetness() == 0.0)
	var weathers: Array[Node] = get_nodes_in_group(WD.GROUP)
	_check("quem mostra o tempo está no grupo city_weather (%d)" % weathers.size(), weathers.size() >= 1)
	_check("o tempo da cidade abre parado (o menu é dinâmico, mas o teste fixa)", director.current_mode() == "limpo")
	director.force("chuva_forte")
	_check("forçar: o céu fecha e o chão encharca na hora",
			is_equal_approx(day_night.get_weather_overlay(), 0.9) and decor.ground_wetness() == 1.0)
	var all_got_it := true
	for node: Node in weathers:
		all_got_it = all_got_it and node.current_state() == "chuva_forte" and node.current_strength() == 1.0
	_check("todos os lugares receberam o tempo", all_got_it)

	director.force("")
	director.step(WD.MENU_PASSAGE_SECONDS + 1.0)
	_check("soltar: volta ao limpo", director.current_state() == "limpo" and not director.is_passing()
			and day_night.get_weather_overlay() == 0.0)

	print("== a luz de dentro de casa ==")
	# Revisão da 19.6: com o céu fechado, o sol não pode entrar forte pela janela.
	var home: Node = city._home
	home.set_night(0.0)
	var sun: Light3D = home.get_sunlight()
	var clear_energy := sun.light_energy if sun != null else 0.0
	_check("a casa tem sol entrando pela janela de dia", sun != null and clear_energy > 0.0)
	director.force("chuva_forte")
	_check("chuva forte: o sol de dentro de casa quase some (%.2f de %.2f)" % [sun.light_energy, clear_energy],
			sun.light_energy < clear_energy * 0.3)
	director.force("")
	director.step(WD.MENU_PASSAGE_SECONDS + 1.0)
	_check("tempo limpo de novo: o sol volta inteiro", is_equal_approx(sun.light_energy, clear_energy))
	home.set_night(day_night.get_night())

	print("== a janela da casa ==")
	var fake := Node.new()
	fake.set_script(_window_probe())
	fake.add_to_group(&"window_view")  # WindowView.GROUP
	root.add_child(fake)
	fake.set_meta(&"calls", 0)
	app.set_weather("nublado")
	_check("trocar no menu: passa devagar", director.is_passing() and director.current_state() == "nublado")
	director.step(WD.MENU_PASSAGE_SECONDS / 2.0)
	_check("no meio da passagem, a janela ainda não refaz", int(fake.get_meta(&"calls")) == 0)
	director.step(WD.MENU_PASSAGE_SECONDS)
	_check("o fim da passagem não chama a janela na hora (é adiado)", int(fake.get_meta(&"calls")) == 0)
	await process_frame
	_check("...e chama uma vez, logo depois", int(fake.get_meta(&"calls")) == 1)
	_check("nublado: o céu fecha um pouco e não chove", is_equal_approx(day_night.get_weather_overlay(), 0.45)
			and director.current_strength() == 0.0)
	fake.free()
	app.set_weather("dinamico")

	print("== o dinâmico na cena ==")
	# Revisão da 19.6: o sorteio só era testado num diretor solto. Aqui ele anda
	# na cidade, do nublado ao tempo seguinte, e o céu e os lugares acompanham
	# em passos pequenos.
	_check("no menu, dinâmico", director.current_mode() == "dinamico" and director.current_state() == "nublado")
	var last_cover: float = day_night.get_weather_overlay()
	var biggest := 0.0
	var followed := true
	var moved := false
	for second in 10 * 60:
		director.step(1.0)
		var cover_now: float = day_night.get_weather_overlay()
		biggest = maxf(biggest, absf(cover_now - last_cover))
		last_cover = cover_now
		moved = moved or director.current_state() != "nublado"
		for node: Node in weathers:
			followed = followed and absf(node.current_strength() - director.current_strength()) <= WD.PUBLISH_STEP
	_check("em 10 min o tempo mudou sozinho (%s)" % director.current_state(), moved)
	_check("o céu acompanhou sem pulo (maior passo %.3f por segundo)" % biggest, biggest > 0.0 and biggest <= 0.03)
	_check("os lugares receberam a força, inclusive no meio da passagem", followed)
	_check("o céu está onde o diretor diz", absf(day_night.get_weather_overlay() - director.current_cover()) <= WD.PUBLISH_STEP)

	print("== sair da cena ==")
	director.force("chuva_forte")
	city.queue_free()
	await process_frame
	await process_frame
	_check("sem a cidade: o chão volta seco", decor.ground_wetness() == 0.0)


## Um ouvinte de mentira no grupo da janela: conta as chamadas.
func _window_probe() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc on_world_changed() -> void:\n\tset_meta(&\"calls\", int(get_meta(&\"calls\", 0)) + 1)\n"
	script.reload()
	return script


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
