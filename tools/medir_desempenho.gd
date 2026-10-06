extends SceneTree
## Mede o desempenho da cidade andando (Fase 8). Rode COM JANELA, à mão:
##
##   ~/.local/bin/godot --path . -s tools/medir_desempenho.gd -- <jogos> <qualidade> <hora>
##
##   jogos      0 = a biblioteca de verdade; N = N jogos falsos (tests/fake_library.gd)
##   qualidade  leve | media | alta        (padrão: leve)
##   hora       hora da cidade, 0 a 24     (padrão: 22, noite)
##
## A caminhada é sempre a mesma: da praça até a rua mais longe do mapa e de
## volta, a 9 m/s (correndo), olhando para onde anda. Imprime uma linha com o
## FPS médio, o pior quadro, as chamadas de desenho e a memória de textura.
## A qualidade escolhida é só para a medida: a do usuário é devolvida no fim.

const SPEED: float = 9.0
const WARMUP_FRAMES: int = 60


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 0
	var quality := String(args[1]) if args.size() > 1 else "leve"
	var hour := float(args[2]) if args.size() > 2 else 22.0

	var config := root.get_node("AppConfig")
	var original_quality: String = config.get_quality()
	config.set_quality(quality)
	if count > 0:
		var library_script: GDScript = load("res://tests/fake_library.gd")
		library_script.install(root, count)
	var games: int = root.get_node("SteamLibrary").get_installed_games().size()

	var built := Time.get_ticks_msec()
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	var build_ms := Time.get_ticks_msec() - built
	var day_night = city._day_night
	day_night.hour_offset = hour - day_night.current_hour()
	day_night.update_now()

	var player = city.get_node("Player")
	var far := _far_street(city)
	var path: Array[Vector3] = [Vector3(0, 0.1, 19), Vector3(far, 0.1, 19), Vector3(far, 0.1, -far), Vector3(far, 0.1, 19), Vector3(0, 0.1, 19)]
	player.teleport_to(Transform3D(Basis.looking_at(Vector3.RIGHT), path[0]))
	for i in WARMUP_FRAMES:
		await process_frame

	var deltas: Array[float] = []
	var draw_calls := 0
	var samples := 0
	var travelled := 0.0
	var leg := 0
	var position := path[0]
	var last_ms := Time.get_ticks_usec()
	while leg < path.size() - 1:
		await process_frame
		var now_us := Time.get_ticks_usec()
		var delta := (now_us - last_ms) / 1000000.0
		last_ms = now_us
		deltas.append(delta)
		travelled = delta * SPEED
		var target := path[leg + 1]
		var step := position.direction_to(target) * minf(travelled, position.distance_to(target))
		position += step
		if position.distance_to(target) < 0.01:
			leg += 1
		if step.length() > 0.0:
			player.teleport_to(Transform3D(Basis.looking_at(step.normalized()), position))
		if deltas.size() % 10 == 0:
			draw_calls += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			samples += 1

	var total := 0.0
	var worst := 0.0
	for d in deltas:
		total += d
		worst = maxf(worst, d)
	var sorted := deltas.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size() * 0.99)]
	var texture_mb := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var memory_mb := OS.get_static_memory_usage() / 1048576.0
	print("MEDIDA jogos=%d qualidade=%s hora=%.0f | montagem=%d ms | fps_medio=%.1f | quadro_p99=%.0f ms | pior=%.0f ms | desenhos=%d | textura=%.0f MB | memoria=%.0f MB | quadros=%d" % [
		games, quality, hour, build_ms, deltas.size() / total, p99 * 1000.0, worst * 1000.0,
		draw_calls / maxi(samples, 1), texture_mb, memory_mb, deltas.size()])
	config.set_quality(original_quality)
	quit()


## Rua mais longe do mapa (a de fora, entre o último anel e a borda).
func _far_street(city: Node) -> float:
	var half: float = city.get("_half_extent") if city.get("_half_extent") != null else 0.0
	if half <= 0.0:
		var games: int = root.get_node("SteamLibrary").get_installed_games().size()
		half = CityLayout.half_extent(CityLayout.block_cells(maxi(1, int(ceil(games / 4.0)))))
	var ring := roundi((half - CityLayout.BLOCK_SIZE / 2.0 - CityLayout.STREET_WIDTH) / CityLayout.BLOCK_PITCH)
	return maxf(CityLayout.BLOCK_PITCH * (ring - 1) + CityLayout.BLOCK_PITCH / 2.0, CityLayout.BLOCK_PITCH / 2.0)
