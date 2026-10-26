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
	var timer: Timer = atmosphere.get_children().filter(func(n: Node) -> bool: return n is Timer)[0]
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
			and env.fog_light_color.is_equal_approx(base_color.lerp(spec.fog_tint, 0.3)))
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
	world.free()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## Avança só a rampa de áudio para conferir o alvo sem depender do dispositivo.
func _finish_audio(atmosphere: Node) -> void:
	atmosphere._audio_tween.custom_step(0.1)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
