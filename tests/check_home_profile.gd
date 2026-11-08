extends SceneTree
## Teste do perfil do tema da casa (Fase 13.1): o catálogo (profiles/home_catalog.tres)
## e o loft (profiles/homes/loft.tres). Nenhum id de tema aparece entre aspas fora
## de profiles/, tests/ e tools/.
## Fase 13.12: a cabana carrega e monta sem erro (com a lareira, o fogo que
## tremula, as poltronas, os lampiões e o vaso), com paredes de tora e a vista
## de floresta.
## Fase 17.2: a luz do loft. Cada pendente faz uma poça (um cone para baixo),
## só o pendente do canto de estar e o abajur fazem sombra, e a luz rebatida
## (SSIL) acompanha a qualidade (só na Alta). O "retrato" fixo da casa de antes
## da 13.2 saiu: ele impediria toda mudança de propósito na casa.
## Fase 17.9.1: a luz do dia nos dois temas. De dia o sol entra pela janela com
## sombra (a parede tem um vão de verdade), o chão o rebate para cima e as
## luminárias ficam mais fracas; à noite tudo volta ao que era. A cabana monta
## com as duas vistas da janela (a floresta e o retrato do mundo).
## Guarda o config.cfg e devolve no fim.

const CONFIG: String = "user://config.cfg"
const HOMES_FOLDER: String = "res://profiles/homes"
## Pastas que podem citar os ids dos temas (os dados, os testes e as ferramentas).
const SCAN_SKIP: Array[String] = ["res://profiles", "res://tests", "res://tools", "res://.godot", "res://assets"]

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app: Node = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	var original: Array = [app.get_home_theme(), app.get_home_layout(), app.get_home_wall_color(), app.get_home_neon_color(), app.get_quality()]
	app.set_home_theme("")
	app.set_home_layout("")
	app.set_home_wall_color("")
	app.set_home_neon_color("")
	app.set_quality("alta")

	print("== o catálogo ==")
	var catalog := Profiles.home_catalog()
	_check("o catálogo carrega, com pelo menos um tema", catalog != null and not catalog.homes.is_empty())
	_check("nenhum item vazio na lista de temas", not catalog.homes.has(null))
	var ids: Array[String] = []
	for profile in catalog.homes:
		ids.append(profile.id)
	var unique := {}
	for id in ids:
		unique[id] = true
	_check("ids únicos e válidos %s" % str(ids), unique.size() == ids.size()
			and ids.all(func(id: String) -> bool: return not id.is_empty() and id == id.to_lower() and not id.contains(" ")))
	var on_disk := Array(DirAccess.get_files_at(HOMES_FOLDER)).filter(func(f: String) -> bool: return f.ends_with(".tres"))
	_check("todo .tres de profiles/homes está no catálogo (%d arquivos)" % on_disk.size(), on_disk.size() == catalog.homes.size())
	_check("as paletas de cores têm cores (parede %d, néon %d)" % [catalog.wall_palette.size(), catalog.neon_palette.size()],
			catalog.wall_palette.size() >= 6 and catalog.neon_palette.size() >= 6)

	print("== o tema padrão e os ids ==")
	var loft := Profiles.home("loft")
	_check("o loft existe e é o primeiro (o padrão)", loft != null and catalog.homes[0] == loft)
	_check("id vazio devolve o loft", Profiles.home("") == loft)
	_check("id desconhecido devolve o loft", Profiles.home("nao_existe") == loft)
	_check("sem disposições no catálogo, home_layout devolve null sem erro",
			catalog.layouts.is_empty() == (Profiles.home_layout("") == null))

	print("== o loft ==")
	_check("nome e superfícies preenchidos", loft.display_name == "Loft" and loft.floor != null and loft.ceiling != null
			and loft.feature_wall != null and loft.walls != null and loft.skirting != null and loft.beams != null
			and loft.window_frame != null and loft.window_sill != null)
	_check("só as paredes comuns são pintáveis", loft.walls.paintable and not loft.floor.paintable
			and not loft.feature_wall.paintable and not loft.ceiling.paintable)
	_check("o shader da janela existe", ResourceLoader.exists(loft.window_shader))
	_check("marca de passos de madeira", loft.footstep == "wood")
	_check("lâmpada quente (mais vermelho que azul)", loft.lamp_color.r > loft.lamp_color.b * 1.8 and loft.lamp_energy > 0.0)
	_check("a sombra da noite puxa para o azul e é mais fraca que a do dia", loft.ambient_night_color.b > loft.ambient_night_color.r
			and loft.ambient_night_energy < loft.ambient_day_energy * 0.5)

	print("== a luz do loft (17.2) ==")
	var home: Node3D = (load("res://worlds/home/home.gd") as GDScript).new()
	root.add_child(home)
	await process_frame
	_check("a casa usa o loft", home.get_profile() == loft)
	var cones := _lights(home).filter(func(l: Node) -> bool: return l.get_meta("loft_piece", "") == "pendente")
	var down := cones.filter(func(l: Node) -> bool: return l is SpotLight3D and (l as Node3D).global_basis.z.dot(Vector3.UP) > 0.99)
	_check("três pendentes, cada um com um cone para baixo (%d)" % cones.size(), cones.size() == 3 and down.size() == 3)
	var shadowed := cones.filter(func(l: Node) -> bool: return (l as SpotLight3D).shadow_enabled)
	# O do canto de estar: em cima da mesinha (17.4b: o canto saiu do meio da sala).
	var table: Node3D = home.find_child("CoffeeTable", false, false)
	var over := Vector2.INF
	if shadowed.size() == 1 and table != null:
		var lamp := (shadowed[0] as Node3D).position
		over = Vector2(lamp.x - table.position.x, lamp.z - table.position.z)
	_check("só um pendente faz sombra, o do canto de estar (em cima da mesinha)", over.length() < 0.3)
	var floor_lamp: OmniLight3D = home.find_child("FloorLampLight", true, false)
	_check("o abajur faz sombra", floor_lamp != null and floor_lamp.shadow_enabled)
	var lamp_shade: GeometryInstance3D = home.find_child("FloorLampShade", true, false)
	_check("a cúpula do abajur não tapa a própria luz", lamp_shade != null
			and lamp_shade.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# O sol do dia (17.9.1) também faz sombra, e tem o teste dele (_check_daylight).
	var sun: Light3D = home.get_sunlight()
	var others := _lights(home).filter(func(l: Light3D) -> bool: return l.shadow_enabled and not shadowed.has(l) and l != floor_lamp and l != sun)
	_check("nenhuma outra luz da casa faz sombra %s" % str(others.map(func(l: Node) -> String: return String(l.name))), others.is_empty())
	var environment: Environment = home.get_environment()
	_check("na Alta, a luz rebatida (SSIL) liga", environment.ssil_enabled)
	app.set_quality("media")
	await process_frame
	_check("na Média, desliga", not environment.ssil_enabled)
	app.set_quality("leve")
	await process_frame
	_check("na Leve, desliga", not environment.ssil_enabled)
	_check_loft_objects(home)
	_check_daylight(home, "o dia no loft (17.9.1)")
	home.queue_free()
	await process_frame

	await _check_cabin()

	print("== nenhum id de tema fora de profiles/ ==")
	var offenders: Array[String] = []
	var scripts := _scripts("res://")
	for path in scripts:
		var code_lines := FileAccess.get_file_as_string(path).split("\n")
		for i in code_lines.size():
			var code := code_lines[i].strip_edges()
			if code.begins_with("#"):
				continue
			for id in ids:
				if code.contains("\"%s\"" % id):
					offenders.append("%s:%d" % [path, i + 1])
	_check("nenhum dos %d scripts cita um id de tema %s" % [scripts.size(), str(offenders)],
			scripts.size() > 50 and offenders.is_empty())

	app.set_home_theme(original[0])
	app.set_home_layout(original[1])
	app.set_home_wall_color(original[2])
	app.set_home_neon_color(original[3])
	app.set_quality(original[4])
	var restored := FileAccess.open(CONFIG, FileAccess.WRITE)
	restored.store_string(backup)
	restored.close()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## Os objetos do loft (17.4): as peças existem, tudo fica na camada da casa e
## nada tampa a passagem (o nascer, a porta e a frente de cada móvel de todas
## as disposições do catálogo).
func _check_loft_objects(home: Node3D) -> void:
	print("== os objetos do loft (17.4) ==")
	var pieces: Dictionary[String, Array] = {}
	for child in home.get_children():
		if child is Node3D and child.has_meta("loft_piece") and not child is Light3D:
			var kind: String = child.get_meta("loft_piece")
			if not pieces.has(kind):
				pieces[kind] = []
			pieces[kind].append(child)
	var counts := {}
	for kind in pieces:
		counts[kind] = pieces[kind].size()
	print("    peças: ", counts)
	_check("sofá, mesinha, tapete, aparador, quadro e 4 plantas", counts.get("sofa", 0) == 1 and counts.get("mesinha", 0) == 1
			and counts.get("tapete", 0) == 1 and counts.get("aparador", 0) == 1 and counts.get("quadro", 0) == 1
			and counts.get("planta", 0) == 4)
	_check("a manta está no sofá", home.find_child("SofaThrow", true, false) != null
			and (home.find_child("SofaThrow", true, false) as Node).get_meta("loft_piece", "") == "manta")
	var leaves := home.find_children("PlantLeaves", "MeshInstance3D", true, false)
	_check("5 plantas com folhas (a pendente do aparador conta) (%d)" % leaves.size(), leaves.size() == 5
			and leaves.all(func(m: MeshInstance3D) -> bool: return m.mesh != null and m.mesh.get_faces().size() > 300))
	_check("a captura do sofá acha o assento", home.get_node_or_null("SofaSeat") != null)

	var outside: Array[String] = []
	var drawn := 0
	for kind in pieces:
		for piece: Node3D in pieces[kind]:
			var parts := piece.find_children("*", "GeometryInstance3D", true, false)
			if piece is GeometryInstance3D:
				parts.append(piece)
			for node in parts:
				drawn += 1
				if (node as GeometryInstance3D).layers != int(home.get("INTERIOR_LAYER_MASK")):
					outside.append(String(node.name))
	_check("as %d malhas dos objetos ficam na camada 20 (o sol do mundo não as acende) %s" % [drawn, str(outside.slice(0, 5))],
			drawn > 20 and outside.is_empty())

	# A passagem, no chão (x, z) da casa.
	var zones: Array[Rect2] = []
	var spawn_spot: Vector3 = home.get("SPAWN_SPOT")
	var room: Vector3 = home.get("ROOM_SIZE")
	var spawn := Vector2(spawn_spot.x, spawn_spot.z)
	zones.append(Rect2(spawn - Vector2(0.5, 0.5), Vector2(1.0, 1.0)))
	# A porta da rua: o batente e mais 5 cm de cada lado, da parede até 1,7 m para dentro.
	var door: Vector3 = home.to_local(home.get_front_door().global_position)
	var door_width: float = float(home.get("DOOR_WIDTH")) + 0.1
	zones.append(Rect2(Vector2(door.x - door_width / 2.0, room.z / 2.0 - 1.7), Vector2(door_width, 1.7)))
	var anchors := {String(home.get("COMPUTER_ANCHOR")): true}
	for layout in Profiles.home_catalog().layouts:
		for id in layout.placements:
			anchors[layout.placements[id]] = true
	for anchor in anchors:
		# Na frente do móvel: 2,4 m de largura, de 0,3 a 1,8 m da parede.
		var place: Transform3D = home.get_anchor_transform(anchor)
		var a := place * Vector3(-1.2, 0.0, 0.3)
		var b := place * Vector3(1.2, 0.0, 1.8)
		zones.append(Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(a.x - b.x), absf(a.z - b.z))))
	var blocking: Array[String] = []
	for kind in pieces:
		if kind == "tapete":
			continue  # o tapete é chão
		for piece: Node3D in pieces[kind]:
			var bounds := _floor_bounds(home, piece)
			for zone in zones:
				if bounds.intersects(zone):
					blocking.append("%s em %s" % [piece.name, zone])
	_check("nada tampa a passagem (%d zonas) %s" % [zones.size(), str(blocking)], zones.size() >= 6 and blocking.is_empty())


## A área no chão (x, z, nas coordenadas da casa) que um objeto ocupa.
func _floor_bounds(home: Node3D, piece: Node3D) -> Rect2:
	var result := Rect2()
	var first := true
	for node in piece.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = home.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		var flat := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		result = flat if first else result.merge(flat)
		first = false
	return result


## A cabana: o perfil e a casa montada com ele.
func _check_cabin() -> void:
	print("== a cabana (13.12) ==")
	var catalog := Profiles.home_catalog()
	var cabin := Profiles.home("cabana")
	_check("a cabana existe e vem depois do loft", cabin != null and cabin.id == "cabana"
			and catalog.homes.find(cabin) > 0 and catalog.homes[0] == Profiles.home("loft"))
	_check("nome, superfícies e enfeite preenchidos", cabin.display_name == "Cabana" and cabin.floor != null
			and cabin.ceiling != null and cabin.beams != null and cabin.window_frame != null
			and load(cabin.decor_script) is GDScript)
	_check("paredes de tora, e só as comuns são pintáveis", cabin.walls.logs and cabin.feature_wall.logs
			and cabin.walls.paintable and not cabin.feature_wall.paintable and not cabin.floor.logs)
	_check("piso, teto e vigas de madeira", cabin.floor.kind == "wood" and cabin.floor.planks
			and cabin.ceiling.kind == "wood" and cabin.beams.kind == "wood")
	var window_shader: Shader = load(cabin.window_shader)
	_check("a vista de floresta tem o \"night\"", window_shader != null
			and window_shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u["name"] == "night"))
	_check("néon âmbar mais fraco que o do loft", cabin.neon_energy > 0.0
			and cabin.neon_energy < Profiles.home("loft").neon_energy and cabin.neon_color.r > cabin.neon_color.b)

	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	var original_theme: String = app.get_home_theme()
	app.set_home_theme("cabana")
	var home: Node3D = (load("res://worlds/home/home.gd") as GDScript).new()
	root.add_child(home)
	await process_frame
	_check("a casa monta com a cabana", home.get_profile() == cabin)
	var kinds := {}
	for child in home.get_children():
		if child.has_meta("cabin_piece"):
			var kind: String = child.get_meta("cabin_piece")
			kinds[kind] = int(kinds.get(kind, 0)) + 1
	print("    peças: ", kinds)
	_check("lareira, 2 poltronas, tapete, 3 lampiões e o vaso", kinds == {"lareira": 1, "tapete": 1, "poltrona": 2, "lampiao": 3, "vaso": 1})
	var walls: MeshInstance3D = home.get_node("WallWest")
	var wall_material := walls.material_override as ShaderMaterial
	_check("as paredes são toras (log_round = 1)", wall_material != null and wall_material.get_shader_parameter("log_round") == 1.0)
	var glass: MeshInstance3D = home.get_node("WindowView")
	_check("a janela mostra a floresta", (glass.material_override as ShaderMaterial).shader == window_shader)
	var fire: OmniLight3D = home.find_child("FireLight", true, false)
	var energies := {}
	for i in 8:
		await process_frame
		energies[snappedf(fire.light_energy, 0.001)] = true
	_check("a luz do fogo é laranja e tremula (%d valores em 8 quadros)" % energies.size(),
			fire.light_color.r > fire.light_color.b * 2.0 and energies.size() > 3)
	var crackle: AudioStreamPlayer3D = home.find_child("FireCrackle", true, false)
	_check("a lenha estala baixinho, no canal Ambiente", crackle != null and crackle.stream != null and crackle.bus == &"Ambiente")
	_check("o arbusto do vaso entrou", home.find_child("PlantBush", true, false) != null)
	_check_daylight(home, "o dia na cabana (17.9.1)")
	_check("o fogo não enfraquece de dia (ele tremula sozinho)", not home.get_lamps().has(fire))
	home.queue_free()
	await process_frame
	await _check_cabin_views(cabin)

	app.set_home_theme(original_theme)
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	_check("config.cfg devolvido", FileAccess.get_file_as_string(CONFIG) == backup)


func _material(surface: HomeSurface) -> Material:
	return HomeMaterials.from_surface(surface)


## A luz do dia (17.9.1), num tema já montado: o sol com sombra fora da sala,
## mirando a janela pelo vão da parede; a mancha no chão; as luminárias mais
## fracas de dia e inteiras à noite; e, à noite, nenhuma luz do dia.
func _check_daylight(home: Node3D, title: String) -> void:
	print("== %s ==" % title)
	var profile: HomeProfile = home.get_profile()
	var room: Vector3 = home.ROOM_SIZE
	var sun: SpotLight3D = home.get_sunlight()
	var bounce: SpotLight3D = home.find_child("SunBounce", false, false)
	var sky: SpotLight3D = home.get_node("Daylight")
	_check("o sol existe, faz sombra e só acende a casa", sun != null and sun.shadow_enabled
			and sun.light_cull_mask == home.INTERIOR_LAYER_MASK and bounce != null and not bounce.shadow_enabled)
	var travel: Vector3 = -sun.transform.basis.z if sun != null else Vector3.ZERO
	_check("o sol fica do lado de fora e entra para baixo e para dentro", sun != null
			and sun.position.z < -room.z / 2.0 - 1.0 and travel.y < -0.3 and travel.z > 0.3)
	# O raio do meio do sol passa pelo meio da janela.
	var window := Vector3(home.WINDOW_CENTER_X, home.WINDOW_CENTER_Y, -room.z / 2.0)
	var to_window := (window - sun.position).normalized() if sun != null else Vector3.ZERO
	_check("o sol mira o meio da janela", to_window.dot(travel) > 0.999)
	# O vão: nenhum pedaço de parede tapa a janela, e uma colisão sem desenho
	# segura quem anda; o vidro não faz sombra.
	var opening := AABB(Vector3(home.WINDOW_LEFT, home.WINDOW_SILL_Y, -room.z / 2.0 - home.WALL_THICKNESS),
			Vector3(home.WINDOW_SIZE.x, home.WINDOW_SIZE.y, home.WALL_THICKNESS)).grow(-0.02)
	var blocking: Array[String] = []
	for child in home.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Wall"):
			var box: AABB = (child as MeshInstance3D).transform * (child as MeshInstance3D).get_aabb()
			if box.intersects(opening):
				blocking.append(String(child.name))
	_check("a parede tem o vão da janela %s" % str(blocking), blocking.is_empty()
			and home.find_child("WallNorthTop", false, false) != null)
	var block: StaticBody3D = home.find_child("WindowBlock", false, false)
	_check("uma colisão tapa o vão", block != null and block.get_child_count() == 1
			and absf(block.position.x - home.WINDOW_CENTER_X) < 0.01)
	var glass: GeometryInstance3D = home.get_node("WindowView")
	_check("o vidro não faz sombra", glass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# A mancha: o meio dela cai no chão da sala, longe das paredes.
	var patch: Vector3 = bounce.position if bounce != null else Vector3.INF
	_check("a mancha de sol fica no chão da sala (%.1f; %.1f)" % [patch.x, patch.z], absf(patch.x) < room.x / 2.0 - 1.0
			and absf(patch.z) < room.z / 2.0 - 1.0 and patch.y < 0.1)
	var rug: Node3D = home.find_child("Rug", false, false)
	if rug != null and rug.has_meta("loft_piece"):
		var rug_box: AABB = (rug as MeshInstance3D).transform * (rug as MeshInstance3D).get_aabb()
		_check("a mancha fica fora do tapete do canto de estar",
				not rug_box.grow(0.3).has_point(Vector3(patch.x, rug_box.position.y, patch.z)))

	var lamps: Array[Light3D] = home.get_lamps()
	var night_before: float = home.get_night()
	home.set_night(0.0)
	_check("de dia o sol, a luz rebatida e o céu acendem", sun.visible and bounce.visible and sky.visible
			and is_equal_approx(sun.light_energy, profile.sun_energy)
			and is_equal_approx(bounce.light_energy, profile.sun_energy * profile.sun_bounce))
	var dimmed := lamps.all(func(l: Light3D) -> bool:
			return is_equal_approx(l.light_energy, float(l.get_meta(home.NIGHT_ENERGY_META)) * profile.lamp_day_scale))
	_check("de dia as %d luminárias ficam de apoio (%.0f%%)" % [lamps.size(), profile.lamp_day_scale * 100.0],
			lamps.size() >= 3 and dimmed and profile.lamp_day_scale < 1.0)
	_check("nenhuma luz do dia está entre as luminárias", not lamps.has(sun) and not lamps.has(bounce) and not lamps.has(sky))
	_check("o sol de dia é mais neutro que as lâmpadas",
			profile.sun_color.b / profile.sun_color.r > profile.lamp_color.b / profile.lamp_color.r)
	home.set_night(1.0)
	var full := lamps.all(func(l: Light3D) -> bool:
			return is_equal_approx(l.light_energy, float(l.get_meta(home.NIGHT_ENERGY_META))))
	_check("à noite nenhuma luz do dia, e as luminárias inteiras", not sun.visible and not bounce.visible
			and not sky.visible and full)
	home.set_night(night_before)


## As duas vistas da cabana (17.9.1), para o dono escolher: a floresta do
## shader (a do perfil) e o retrato do mundo (o mesmo do loft). As duas
## carregam, a casa monta com cada uma, e só o retrato liga o WindowView.
func _check_cabin_views(cabin: HomeProfile) -> void:
	print("== as vistas da cabana (17.9.1) ==")
	var original := cabin.window_shader
	var portrait := "res://worlds/home/home_window.gdshader"
	for path: String in [original, portrait]:
		cabin.window_shader = path
		var home: Node3D = (load("res://worlds/home/home.gd") as GDScript).new()
		root.add_child(home)
		await process_frame
		var shader: Shader = (home.get_node("WindowView").material_override as ShaderMaterial).shader
		# Pelo load: citar a classe direto compila o WindowView antes dos autoloads.
		var uses: bool = load("res://components/window_view/window_view.gd").uses_view(shader)
		_check("%s: a janela monta (%s)" % [path.get_file(), "retrato" if uses else "desenho"],
				shader != null and shader.resource_path == path and uses == (path == portrait))
		home.queue_free()
		await process_frame
	cabin.window_shader = original
	_check("o perfil da cabana segue com a floresta", cabin.window_shader.ends_with("home_window_forest.gdshader"))


## Todos os .gd do projeto, menos as pastas de SCAN_SKIP.
func _scripts(folder: String) -> Array[String]:
	var result: Array[String] = []
	for sub in DirAccess.get_directories_at(folder):
		var path := folder.path_join(sub)
		if not SCAN_SKIP.has(path) and not sub.begins_with("."):
			result.append_array(_scripts(path))
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			result.append(folder.path_join(file))
	return result


## Todas as luzes da casa (filhos e netos).
func _lights(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		if child is Light3D:
			result.append(child)
		result.append_array(_lights(child))
	return result


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
