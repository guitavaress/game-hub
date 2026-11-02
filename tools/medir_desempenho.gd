extends SceneTree
## Mede o desempenho da cidade andando (Fase 8). Rode COM JANELA, à mão:
##
## ATENÇÃO (revisão de 2026-10-10, item 8.3): no notebook, meça com ele PARADO
## (sem vídeo, navegador ou outro programa pesado) e compare a versão antiga e
## a nova LADO A LADO, no mesmo dia. Com outra coisa rodando, o FPS cai pela
## metade e até os desenhos por quadro mudam, sem nenhuma mudança no código.
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
## Depois da caminhada, um segundo trecho mede DENTRO DE CASA (Fase 9): o
## jogador gira no lugar por ~3 s olhando a sala, e sai uma segunda linha
## MEDIDA_CASA com o mesmo formato.
## Um terceiro trecho (Fase 13.9) mede DE FRENTE PARA O ESPELHO da casa: o
## jogador fica a 1,8 m do lugar do espelho, olhando para ele, e balança a
## câmera por ~3 s. Sai a linha MEDIDA_ESPELHO. Antes da 13.10 (o espelho)
## ela mede só a parede vazia, e é a referência para comparar depois.
## Um quarto trecho sobe a trilha a 9 m/s e gira 360° no mirante em ~3 s.
## Sai MEDIDA_MONTANHA; sem trilha integrada, sai apenas "| sem montanha".
## Antes de tudo sai MEDIDA_AMBIENTE (janela, Hz, vsync, placa, CPU, Godot). Depois,
## MEDIDA_MONTAGEM: quanto o add_child da cidade travou, o 1º quadro (a janela
## desenha pela primeira vez e compila shaders), o pior quadro depois dele (meta
## da Fase 15: até 50 ms no desktop, na Alta) e quantos quadros passaram de 50 ms.
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

	_print_environment()
	var built := Time.get_ticks_msec()
	# Com janela, a cidade abre como no hub de verdade: você em casa e a cidade
	# montando aos poucos lá fora. Sem janela (check_perf_tool), monta de uma vez.
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	var add_child_ms := Time.get_ticks_msec() - built
	# Quadro a quadro até a cidade ficar pronta. Sem janela a montagem inteira
	# cabe no add_child e não sobra quadro nenhum.
	var build_frames: Array[int] = []
	var build_last_us := Time.get_ticks_usec()
	while not city.is_city_ready():
		await process_frame
		var build_now_us := Time.get_ticks_usec()
		build_frames.append((build_now_us - build_last_us) / 1000)
		build_last_us = build_now_us
	var build_ms := Time.get_ticks_msec() - built
	_report_build(games, quality, hour, build_ms, add_child_ms, build_frames)
	var day_night = city._day_night
	day_night.hour_offset = hour - day_night.current_hour()
	day_night.update_now()

	var player = city.get_node("Player")
	# A abertura (tela GAME HUB) termina antes de andar; a caminhada é na rua.
	while player.in_intro:
		await process_frame
	player.set_indoors(null)
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

	_report("MEDIDA", games, quality, hour, build_ms, deltas, draw_calls, samples)

	# Trecho dentro de casa: gira no lugar, uma volta completa em ~3 s.
	var home = city.get_home()
	player.teleport_to(home.get_spawn_transform())
	player.set_indoors(home.get_environment())
	for i in WARMUP_FRAMES:
		await process_frame
	var home_deltas: Array[float] = []
	var home_draws := 0
	var home_samples := 0
	var turned := 0.0
	last_ms = Time.get_ticks_usec()
	while turned < TAU:
		await process_frame
		var now_home := Time.get_ticks_usec()
		var step_seconds := (now_home - last_ms) / 1000000.0
		last_ms = now_home
		home_deltas.append(step_seconds)
		turned += step_seconds * TAU / 3.0
		player.rotation.y = -turned
		if home_deltas.size() % 10 == 0:
			home_draws += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			home_samples += 1
	_report("MEDIDA_CASA", games, quality, hour, build_ms, home_deltas, home_draws, home_samples)

	# Trecho de frente para o espelho: a 1,8 m dele, olhando para ele, balançando a câmera.
	var layout = home.get_layout()
	var anchor: Transform3D = home.get_anchor_transform(layout.placements.get("espelho", "sul_direita"))
	var front: Vector3 = home.global_basis * anchor.basis.z
	var feet: Vector3 = home.to_global(anchor.origin) + front * 1.8
	feet.y = home.global_position.y + 0.1
	var facing := Basis.looking_at(-front)
	player.teleport_to(Transform3D(facing, feet))
	for i in WARMUP_FRAMES:
		await process_frame
	var mirror_deltas: Array[float] = []
	var mirror_draws := 0
	var mirror_samples := 0
	var elapsed := 0.0
	last_ms = Time.get_ticks_usec()
	while elapsed < 3.0:
		await process_frame
		var now_mirror := Time.get_ticks_usec()
		var mirror_step := (now_mirror - last_ms) / 1000000.0
		last_ms = now_mirror
		mirror_deltas.append(mirror_step)
		elapsed += mirror_step
		player.rotation.y = facing.get_euler().y + deg_to_rad(18.0) * sin(elapsed * TAU / 3.0)
		if mirror_deltas.size() % 10 == 0:
			mirror_draws += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			mirror_samples += 1
	_report("MEDIDA_ESPELHO", games, quality, hour, build_ms, mirror_deltas, mirror_draws, mirror_samples)
	await _measure_mountain(city, player, games, quality, hour, build_ms)
	config.set_quality(original_quality)
	quit()


## O contrato é só o grupo e os métodos: a ferramenta não depende da classe do terreno.
func _measure_mountain(city: Node, player: Node3D, games: int, quality: String, hour: float, build_ms: int) -> void:
	var trail: Node = null
	for candidate: Node in get_nodes_in_group(&"mountain_trail"):
		if city.is_ancestor_of(candidate) and candidate.has_method("trail_world_points") and candidate.has_method("lookout_world"):
			trail = candidate
			break
	var path: PackedVector3Array = trail.call("trail_world_points") if trail != null else PackedVector3Array()
	if path.size() < 2:
		print("MEDIDA_MONTANHA jogos=%d qualidade=%s hora=%.0f | sem montanha" % [games, quality, hour])
		return

	# Os pontos são do chão; a mesma folga dos outros percursos evita nascer no piso.
	var lookout: Vector3 = trail.call("lookout_world")
	if not path[path.size() - 1].is_equal_approx(lookout):
		path.append(lookout)
	var position: Vector3 = path[0]
	var facing: Basis = Basis.IDENTITY
	for point: Vector3 in path:
		var forward := Vector3(point.x - position.x, 0.0, point.z - position.z)
		if forward.length_squared() > 0.000001:
			facing = Basis.looking_at(forward.normalized())
			break
	player.set_indoors(null)
	player.teleport_to(Transform3D(facing, position + Vector3.UP * 0.1))
	for i in WARMUP_FRAMES:
		await process_frame

	var deltas: Array[float] = []
	var draws: int = 0
	var samples: int = 0
	var leg: int = 0
	var turned: float = 0.0
	var last_us: int = Time.get_ticks_usec()
	while leg < path.size() - 1 or turned < TAU:
		await process_frame
		var now_us: int = Time.get_ticks_usec()
		var delta: float = (now_us - last_us) / 1000000.0
		last_us = now_us
		deltas.append(delta)
		if leg < path.size() - 1:
			# Consome a distância restante entre pontos, mesmo se um quadro cruzar vários.
			var remaining: float = delta * SPEED
			while remaining > 0.0 and leg < path.size() - 1:
				var target: Vector3 = path[leg + 1]
				var distance: float = position.distance_to(target)
				if distance > 0.0001:
					var forward := Vector3(target.x - position.x, 0.0, target.z - position.z)
					if forward.length_squared() > 0.000001:
						facing = Basis.looking_at(forward.normalized())
				var step: float = minf(remaining, distance)
				position = position.move_toward(target, step)
				remaining -= step
				if position.distance_to(target) < 0.0001:
					leg += 1
			player.teleport_to(Transform3D(facing, position + Vector3.UP * 0.1))
		else:
			# Mantém os pés no mirante durante o giro, sem queda nem entrada do usuário.
			turned = minf(TAU, turned + delta * TAU / 3.0)
			player.teleport_to(Transform3D(Basis(Vector3.UP, facing.get_euler().y - turned), lookout + Vector3.UP * 0.1))
		if deltas.size() % 10 == 0:
			draws += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			samples += 1
	_report("MEDIDA_MONTANHA", games, quality, hour, build_ms, deltas, draws, samples)


func _report(label: String, games: int, quality: String, hour: float, build_ms: int, deltas: Array[float], draw_calls: int, samples: int) -> void:
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
	print("%s jogos=%d qualidade=%s hora=%.0f | montagem=%d ms | fps_medio=%.1f | quadro_p99=%.0f ms | pior=%.0f ms | desenhos=%d | textura=%.0f MB | memoria=%.0f MB | quadros=%d" % [
		label, games, quality, hour, build_ms, deltas.size() / total, p99 * 1000.0, worst * 1000.0,
		draw_calls / maxi(samples, 1), texture_mb, memory_mb, deltas.size()])


## A linha da montagem: o 1º quadro fica à parte do pior (é a janela abrindo).
func _report_build(games: int, quality: String, hour: float, build_ms: int, add_child_ms: int, frames: Array[int]) -> void:
	var first: int = frames[0] if frames.size() > 0 else 0
	var worst: int = 0
	var over: int = 0
	for i in range(1, frames.size()):
		worst = maxi(worst, frames[i])
		if frames[i] > 50:
			over += 1
	print("MEDIDA_MONTAGEM jogos=%d qualidade=%s hora=%.0f | montagem=%d ms | add_child=%d ms | primeiro_quadro=%d ms | pior=%d ms | acima_50ms=%d | quadros=%d" % [
		games, quality, hour, build_ms, add_child_ms, first, worst, over, frames.size()])


## Uma linha com a máquina e a janela, para registrar junto da medida.
func _print_environment() -> void:
	var window := root.get_window()
	var vsync: String = "sim" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "nao"
	print("MEDIDA_AMBIENTE janela=%dx%d | tela_hz=%.0f | vsync=%s | gpu=%s | cpu=%s | godot=%s" % [
		window.size.x, window.size.y, DisplayServer.screen_get_refresh_rate(), vsync,
		RenderingServer.get_video_adapter_name(), OS.get_processor_name(),
		Engine.get_version_info().string])


## Rua mais longe do mapa (a de fora, entre o último anel e a borda).
func _far_street(city: Node) -> float:
	var half: float = city.get("_half_extent") if city.get("_half_extent") != null else 0.0
	if half <= 0.0:
		var games: int = root.get_node("SteamLibrary").get_installed_games().size()
		half = CityLayout.half_extent(CityLayout.block_cells(maxi(1, int(ceil(games / 4.0)))))
	var ring := roundi((half - CityLayout.BLOCK_SIZE / 2.0 - CityLayout.STREET_WIDTH) / CityLayout.BLOCK_PITCH)
	return maxf(CityLayout.BLOCK_PITCH * (ring - 1) + CityLayout.BLOCK_PITCH / 2.0, CityLayout.BLOCK_PITCH / 2.0)
