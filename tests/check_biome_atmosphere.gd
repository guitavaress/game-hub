extends SceneTree
## Fase 15.12: zonas, névoa e vento, sem biblioteca Steam nem alteração de config.

var failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var atmosphere_script: GDScript = load("res://worlds/city/biome/biome_atmosphere.gd")
	var zones: Array[Rect2] = [Rect2(0.0, 0.0, 20.0, 20.0), Rect2(40.0, 0.0, 10.0, 10.0)]
	print("== distância à união de zonas ==")
	_check("dentro de cada zona: peso 1", atmosphere_script.zone_weight(Vector2(10, 10), zones, 12.0) == 1.0
			and atmosphere_script.zone_weight(Vector2(45, 5), zones, 12.0) == 1.0)
	_check("bordas inclusivas: sem costura", atmosphere_script.zone_weight(Vector2(20, 20), zones, 12.0) == 1.0)
	_check("fora da faixa: peso 0", atmosphere_script.zone_weight(Vector2(-12, 5), zones, 12.0) == 0.0)
	_check("metade da transição: peso 0,5", is_equal_approx(atmosphere_script.zone_weight(Vector2(-6, 5), zones, 12.0), 0.5))
	_check("canto mede distância diagonal", is_equal_approx(atmosphere_script.zone_weight(Vector2(-3.6, -4.8), zones, 12.0), 0.5))
	var empty: Array[Rect2] = []
	_check("sem zonas: sem atmosfera", atmosphere_script.zone_weight(Vector2.ZERO, empty, 12.0) == 0.0)
	_check("transição zero não divide por zero", atmosphere_script.zone_weight(Vector2.ONE, zones, 0.0) == 1.0
			and atmosphere_script.zone_weight(Vector2(-1, 1), zones, 0.0) == 0.0)
	var previous: float = 0.0
	var monotonic: bool = true
	var max_step: float = 0.0
	for i: int in range(121):
		var weight: float = atmosphere_script.zone_weight(Vector2(-12.0 + i * 0.1, 5), zones, 12.0)
		monotonic = monotonic and weight >= previous and weight >= 0.0 and weight <= 1.0
		max_step = maxf(max_step, weight - previous)
		previous = weight
	_check("transição monotônica e sem salto (amostras a cada 10 cm)", monotonic and max_step < 0.013)
	_check("derivada suave nas duas extremidades", atmosphere_script.zone_weight(Vector2(-11.99, 5), zones, 12.0) < 0.00001
			and atmosphere_script.zone_weight(Vector2(-0.01, 5), zones, 12.0) > 0.99999)
	var overlapping: Array[Rect2] = [zones[0], zones[0]]
	_check("sobreposição não soma névoa", is_equal_approx(atmosphere_script.zone_weight(Vector2(-6, 5), overlapping, 12.0), 0.5))

	print("== ambiente e duas camadas de vento ==")
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var player: Node3D = Node3D.new()
	world.add_child(player)
	player.position = Vector3(-30, 10, 5)
	var clock: Node = load("res://worlds/city/day_night.gd").new()
	var env: Environment = Environment.new()
	env.fog_enabled = true
	clock.environment = env
	clock.sun = DirectionalLight3D.new()
	clock.add_child(clock.sun)
	var sky: ShaderMaterial = ShaderMaterial.new()
	sky.shader = load("res://worlds/city/sky_blend.gdshader")
	clock.sky_material = sky
	world.add_child(clock)
	clock.hour_offset += 13.0 - clock.current_hour()
	clock.update_now()
	var base_density: float = env.fog_density
	var base_color: Color = env.fog_light_color
	var spec: BiomeSpec = BiomeSpec.new()
	spec.fog_density_scale = 2.0
	spec.fog_tint = Color(0.65, 0.72, 0.82)
	spec.fog_tint_amount = 0.3
	spec.fog_height_density = 0.01
	spec.backdrop = TerrainSpec.new()
	spec.backdrop.lookout_height = 40.0
	spec.ambience_bed = AmbienceSpec.new()
	spec.ambience_bed.volume_db = -24.0
	var atmosphere: Node = atmosphere_script.new()
	atmosphere.setup(spec, zones, player, clock, 10.0)
	world.add_child(atmosphere)
	var low: AudioStreamPlayer = atmosphere.get_node("WindLow")
	var high: AudioStreamPlayer = atmosphere.get_node("WindHigh")
	# O relógio da atualização (o outro, de um tiro só, é o dos sons avulsos da 19.7).
	var timer: Timer = atmosphere.get_children().filter(func(n: Node) -> bool: return n is Timer and not n.one_shot)[0]
	_check("atualização a 10 Hz", is_equal_approx(timer.wait_time, 0.1) and not timer.is_stopped())
	_finish_audio(atmosphere)
	_check("sem grupo de fundo também funciona", atmosphere.get_weight() == 0.0 and env.fog_density == base_density)
	_check("fora: vento em silêncio", low.volume_linear == 0.0 and high.volume_linear == 0.0)
	_check("dois loops separados, no canal Ambiente", low.playing and high.playing
			and low.bus == &"Ambiente" and high.bus == &"Ambiente"
			and low.stream != high.stream and low.stream != atmosphere_script.WIND_STREAM
			and (low.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
			and (high.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	var bed: AudioStreamPlayer = AudioStreamPlayer.new()
	bed.volume_db = -18.0
	bed.add_to_group(atmosphere_script.CITY_AMBIENCE_GROUP)
	world.add_child(bed)
	var unrelated: AudioStreamPlayer = AudioStreamPlayer.new()
	unrelated.volume_db = -9.0
	world.add_child(unrelated)
	player.position = Vector3(10, 10, 5)
	# Só o Timer deve detectar a entrada (sem chamar update_now neste trecho).
	await create_timer(0.15).timeout
	_finish_audio(atmosphere)
	_check("Timer detecta entrada na zona", atmosphere.get_weight() == 1.0)
	_check("névoa usa escala e tinta do spec", is_equal_approx(env.fog_density, base_density * 2.0)
			and env.fog_light_color.is_equal_approx(base_color.lerp(clock.tint_keeping_brightness(base_color, spec.fog_tint), 0.3)))
	# 15.13.3: a tinta muda o tom, não o brilho da hora (a noite não clareia, o pôr do sol não vira areia).
	var night: Color = Color("080A12")
	var sunset: Color = Color("E8A07A")
	var night_tinted: Color = clock.tint_keeping_brightness(night, spec.fog_tint)
	var sunset_tinted: Color = clock.tint_keeping_brightness(sunset, spec.fog_tint)
	_check("a tinta não clareia a névoa da noite (%.3f)" % night_tinted.get_luminance(),
			absf(night_tinted.get_luminance() - night.get_luminance()) < 0.01
			and night.lerp(night_tinted, 0.3).get_luminance() < 0.06)
	_check("a tinta mantém o brilho do pôr do sol, só muda o tom",
			absf(sunset_tinted.get_luminance() - sunset.get_luminance()) < 0.02
			and sunset_tinted.b > sunset_tinted.r)
	_check("bruma fixa abaixo do mirante, densidade do spec", is_equal_approx(env.fog_height, 20.0)
			and is_equal_approx(env.fog_height_density, 0.01))
	_check("no chão: só camada baixa no volume do perfil", is_equal_approx(low.volume_db, -24.0) and high.volume_linear == 0.0)
	_check("fundo atenuado em 6 dB, demais sons intactos", is_equal_approx(bed.volume_db, -24.0) and unrelated.volume_db == -9.0)
	for i: int in range(4):
		atmosphere.update_now()
		_finish_audio(atmosphere)
	_check("atenuação não acumula nas atualizações", is_equal_approx(bed.volume_db, -24.0))
	player.position.y = 30.0
	atmosphere.update_now()
	_finish_audio(atmosphere)
	var middle_gain: float = high.volume_linear
	_check("meia subida: camada alta pela metade", is_equal_approx(middle_gain, db_to_linear(-18.0) * 0.5))
	player.position.y = 50.0
	atmosphere.update_now()
	_finish_audio(atmosphere)
	_check("mirante: camada alta mais forte, baixa constante", is_equal_approx(high.volume_db, -18.0)
			and is_equal_approx(low.volume_db, -24.0) and high.volume_linear > middle_gain)
	_check("altura do jogador não arrasta a bruma", is_equal_approx(env.fog_height, 20.0))
	player.position.x = -6.0
	atmosphere.update_now()
	_finish_audio(atmosphere)
	_check("meia transição reduz ambas as camadas e fundo proporcionalmente", is_equal_approx(atmosphere.get_weight(), 0.5)
			and is_equal_approx(low.volume_linear, db_to_linear(-24.0) * 0.5)
			and is_equal_approx(high.volume_linear, db_to_linear(-18.0) * 0.5) and is_equal_approx(bed.volume_db, -21.0))
	player.position.x = -30.0
	atmosphere.update_now()
	_finish_audio(atmosphere)
	_check("sair restaura névoa e fundo, silencia ambos os ventos", env.fog_density == base_density
			and env.fog_light_color == base_color and env.fog_height_density == 0.0 and env.fog_height == 0.0
			and is_equal_approx(bed.volume_db, -18.0) and low.volume_linear == 0.0 and high.volume_linear == 0.0)
	player.position = Vector3(10, 50, 5)
	atmosphere.update_now()
	_finish_audio(atmosphere)
	atmosphere.setup(spec, empty, player, clock, 10.0)
	_finish_audio(atmosphere)
	_check("remontar zonas vazias limpa os efeitos", atmosphere.get_weight() == 0.0 and is_equal_approx(bed.volume_db, -18.0))
	atmosphere.setup(spec, zones, player, clock, 10.0)
	_finish_audio(atmosphere)
	player.free()
	atmosphere.update_now()
	_check("jogador removido restaura o ambiente", atmosphere.get_weight() == 0.0 and env.fog_density == base_density
			and is_equal_approx(bed.volume_db, -18.0))
	player = Node3D.new()
	world.add_child(player)
	player.position = Vector3(10, 50, 5)
	atmosphere.setup(spec, zones, player, clock, 10.0)
	_finish_audio(atmosphere)
	world.remove_child(atmosphere)
	_check("remover atmosfera restaura fundo e névoa e para loops", is_equal_approx(bed.volume_db, -18.0)
			and env.fog_density == base_density and env.fog_height_density == 0.0 and not low.playing and not high.playing)
	atmosphere.free()
	_check("limite público de albedo da neve ≤ 0,85", atmosphere_script.SNOW_ALBEDO_MAX <= 0.85)
	await _check_two_biomes(world, clock, env, bed)
	await _check_shots(world, clock)
	world.free()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## 19.1: dois biomas lado a lado, cada um com a sua atmosfera. Só a de maior
## peso fala com o céu; a névoa passa de um para o outro sem degrau; o som de
## fundo vem do perfil; o vento alto só existe com terreno de fundo.
func _check_two_biomes(world: Node3D, clock: Node, env: Environment, bed: AudioStreamPlayer) -> void:
	print("== dois biomas, uma voz no céu (19.1) ==")
	var atmosphere_script: GDScript = load("res://worlds/city/biome/biome_atmosphere.gd")
	var player: Node3D = Node3D.new()
	world.add_child(player)
	# No fundo de A, a 18 m de B (a transição é de 12 m): B não pesa nada.
	player.position = Vector3(2, 0, 10)
	var base_density: float = env.fog_density
	# A: a montanha de teste (com terreno de fundo e sem som no perfil = vento).
	var snow: BiomeSpec = BiomeSpec.new()
	snow.id = "teste_neve"
	snow.fog_density_scale = 1.4
	snow.fog_tint = Color(0.65, 0.72, 0.82)
	snow.fog_tint_amount = 0.3
	snow.backdrop = TerrainSpec.new()
	# B: um bioma sem terreno de fundo e com o som de fundo do perfil.
	var other: BiomeSpec = BiomeSpec.new()
	other.id = "teste_outro"
	other.fog_density_scale = 3.0
	other.fog_tint = Color(0.9, 0.7, 0.4)
	other.fog_tint_amount = 0.5
	other.ambience_bed = AmbienceSpec.new()
	other.ambience_bed.kind = "loop"
	other.ambience_bed.files = PackedStringArray(["res://assets/generated/city_bed.wav"])
	other.ambience_bed.volume_db = -20.0
	var zones_a: Array[Rect2] = [Rect2(0, 0, 20, 20)]
	var zones_b: Array[Rect2] = [Rect2(20, 0, 20, 20)]
	var a: Node = atmosphere_script.new()
	a.setup(snow, zones_a, player, clock)
	world.add_child(a)
	var b: Node = atmosphere_script.new()
	b.setup(other, zones_b, player, clock)
	world.add_child(b)
	var both: Array[Node] = [a, b]
	_update_all(both)
	_check("dentro de A: só A tem a voz", a.has_voice() and not b.has_voice())
	_check("dentro de A: a névoa é a de A, inteira", is_equal_approx(clock._fog_overlay_weight, 1.0)
			and is_equal_approx(clock._fog_overlay_scale, 1.4) and is_equal_approx(env.fog_density, base_density * 1.4))
	_check("o fundo da cidade abaixa uma vez só (%.1f dB)" % bed.volume_db, is_equal_approx(bed.volume_db, -24.0))
	player.position = Vector3(38, 0, 10)
	_update_all(both)
	_check("dentro de B: a voz passa para B", b.has_voice() and not a.has_voice())
	_check("dentro de B: a névoa é a de B", is_equal_approx(clock._fog_overlay_scale, 3.0)
			and is_equal_approx(env.fog_density, base_density * 3.0))
	_check("e o fundo continua abaixado uma vez só", is_equal_approx(bed.volume_db, -24.0))
	player.position = Vector3(10, 0, 80)
	_update_all(both)
	_check("longe dos dois: uma voz só, sem névoa de bioma", int(a.has_voice()) + int(b.has_voice()) == 1
			and clock._fog_overlay_weight == 0.0 and env.fog_density == base_density)
	_check("e o fundo volta ao volume original", is_equal_approx(bed.volume_db, -18.0))

	# A divisa: de dentro de A até dentro de B, a cada 10 cm.
	var max_step: float = 0.0
	var previous: float = -1.0
	var at_border: float = -1.0
	for i: int in range(301):
		player.position = Vector3(5.0 + i * 0.1, 0, 10)
		_update_all(both)
		var voices: int = int(a.has_voice()) + int(b.has_voice())
		if voices != 1:
			max_step = INF
		if previous >= 0.0:
			max_step = maxf(max_step, absf(env.fog_density - previous))
		previous = env.fog_density
		if i == 150:
			at_border = clock._fog_overlay_weight
	_check("na divisa a névoa volta à da cidade (%.4f)" % at_border, at_border >= 0.0 and at_border < 0.001)
	_check("da névoa de A para a de B sem degrau (maior passo %.5f)" % max_step,
			max_step < base_density * 0.05)

	print("== o som de fundo vem do perfil ==")
	var low_a: AudioStreamPlayer = a.get_node("WindLow")
	var high_a: AudioStreamPlayer = a.get_node("WindHigh")
	var low_b: AudioStreamPlayer = b.get_node("WindLow")
	var high_b: AudioStreamPlayer = b.get_node("WindHigh")
	_check("sem som no perfil: o vento", a._bed_source == atmosphere_script.WIND_STREAM and low_a.playing)
	_check("com som no perfil: o arquivo do perfil, em loop", b._bed_source == load("res://assets/generated/city_bed.wav")
			and low_b.playing and (low_b.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	_check("com terreno de fundo: o vento alto toca", high_a.stream != null and high_a.playing)
	_check("sem terreno de fundo: sem vento alto", high_b.stream == null and not high_b.playing)
	player.position = Vector3(30, 200, 10)
	_update_all(both)
	_check("sem terreno de fundo, nem no alto há vento alto", b.wind_weights(player.position).y == 0.0
			and high_b.volume_linear == 0.0)
	_check("no alto, o som de fundo de B no volume do perfil", is_equal_approx(low_b.volume_db, -20.0))
	var missing: BiomeSpec = other.duplicate() as BiomeSpec
	missing.ambience_bed = other.ambience_bed.duplicate() as AmbienceSpec
	missing.ambience_bed.files = PackedStringArray(["res://nao_existe.wav"])
	b.setup(missing, zones_b, player, clock)
	_check("som que não carrega: volta o vento", b._bed_source == atmosphere_script.WIND_STREAM and low_b.playing)

	print("== quem sai deixa a voz para a outra ==")
	player.position = Vector3(10, 0, 10)
	_update_all(both)
	_check("A fala de novo", a.has_voice())
	world.remove_child(a)
	_check("sair de cena limpa a névoa de quem falava", clock._fog_overlay_weight == 0.0)
	b.update_now()
	_finish_audio(b)
	# Em A, B pesa pouco (a borda dele fica a 10 m): a névoa de B entra só um pouco.
	_check("e a outra assume a voz, com o peso dela (%.3f)" % b.get_weight(), b.has_voice()
			and b.get_weight() < 0.2 and is_equal_approx(clock._fog_overlay_weight, b.get_weight()))
	a.free()
	world.remove_child(b)
	b.free()
	player.free()
	_check("sem atmosferas, o fundo volta ao original", is_equal_approx(bed.volume_db, -18.0))


## Atualiza todas as atmosferas (cada uma no seu tique) e termina as rampas.
## 19.7: um fundo "avulsos" (os pássaros da floresta) toca um arquivo de cada
## vez, de tempos em tempos, sem loop, com o tom sorteado na faixa do perfil;
## longe do bioma, não toca nada. Trocar para um loop volta ao loop.
func _check_shots(world: Node3D, clock: Node) -> void:
	print("== fundo avulso (19.7) ==")
	var zones: Array[Rect2] = [Rect2(0, 0, 10, 10)]
	var player: Node3D = Node3D.new()
	world.add_child(player)
	player.position = Vector3(5, 0, 5)
	var spec: BiomeSpec = BiomeSpec.new()
	spec.id = "teste_avulsos"
	spec.ambience_bed = AmbienceSpec.new()
	spec.ambience_bed.kind = "avulsos"
	spec.ambience_bed.files = PackedStringArray(["res://assets/generated/bird_chirp_1.wav",
			"res://assets/generated/bird_chirp_2.wav"])
	spec.ambience_bed.interval = Vector2(0.05, 0.1)
	spec.ambience_bed.pitch_range = Vector2(0.9, 1.2)
	var atmosphere: Node = load("res://worlds/city/biome/biome_atmosphere.gd").new()
	atmosphere.setup(spec, zones, player, clock)
	world.add_child(atmosphere)
	var low: AudioStreamPlayer = atmosphere.get_node("WindLow")
	var chirps: Array[String] = [spec.ambience_bed.files[0], spec.ambience_bed.files[1]]
	await create_timer(0.8).timeout
	var played: int = atmosphere.shots_played
	var stream_ok: bool = low.stream != null and chirps.has(low.stream.resource_path)
	_check("no bioma, os sons avulsos tocam (%d em 0,8 s)" % played, played >= 3)
	_check("cada som é um dos arquivos do perfil, sem loop, com o tom na faixa",
			stream_ok and (low.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED
			and low.pitch_scale >= 0.9 - 0.001 and low.pitch_scale <= 1.2 + 0.001)
	player.position = Vector3(200, 0, 200)
	atmosphere.update_now()
	var before: int = atmosphere.shots_played
	await create_timer(0.5).timeout
	_check("longe do bioma, não toca", atmosphere.shots_played == before)
	spec.ambience_bed = AmbienceSpec.new()
	spec.ambience_bed.kind = "loop"
	spec.ambience_bed.files = PackedStringArray(["res://assets/generated/wind_loop.wav"])
	atmosphere.setup(spec, zones, player, clock)
	var loop_stream: AudioStreamWAV = low.stream as AudioStreamWAV
	_check("trocar para um loop volta ao loop, no tom normal", loop_stream != null
			and loop_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and is_equal_approx(low.pitch_scale, 1.0)
			and low.playing)
	world.remove_child(atmosphere)
	atmosphere.free()
	player.free()


func _update_all(atmospheres: Array[Node]) -> void:
	for atmosphere: Node in atmospheres:
		atmosphere.update_now()
	for atmosphere: Node in atmospheres:
		_finish_audio(atmosphere)


## Avança só a rampa de áudio para conferir o alvo sem depender do dispositivo.
func _finish_audio(atmosphere: Node) -> void:
	atmosphere._audio_tween.custom_step(0.1)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
