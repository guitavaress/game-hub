extends SceneTree
## Teste da vista de verdade na janela (Fase 17.3): o WindowView e o ponto que
## o mundo oferece (WindowViewPoint). Guarda o config.cfg e devolve no fim.
##   - sem ponto no grupo, a janela fica com a vista de reserva (procedural);
##   - com ponto, o retrato é tirado UMA vez (SubViewport em UPDATE_ONCE, que
##     divide o mundo da cena, câmera sem a camada da casa), e o quadro é
##     desfeito depois; o retrato entra com fade;
##   - o retrato é refeito só na troca de fase do dia (dia, pôr do sol, noite),
##     nunca a cada aviso de hora; sem ponto, volta a vista de reserva, mesmo
##     se o ponto sair no meio de uma captura;
##   - o shader da floresta (cabana) não usa o retrato;
##   - as camadas escondidas pelo ponto (WindowViewPoint.hidden_layers) também
##     somem da câmera do retrato, junto com a da casa;
##   - na cidade: um ponto só, posto quando ela fica pronta, alto e virado para
##     a montanha; a casa tira um retrato só;
##   - nenhum arquivo de worlds/home nem de components cita worlds/city.

const CONFIG := "user://config.cfg"
const VIEW_SCRIPT := "res://components/window_view/window_view.gd"
const POINT_SCRIPT := "res://components/window_view/window_view_point.gd"
const CITY_SHADER := "res://worlds/home/home_window.gdshader"
const FOREST_SHADER := "res://worlds/home/home_window_forest.gdshader"
## A camada da casa (Home.INTERIOR_LAYER = 20).
const HOME_LAYER_MASK: int = 1 << 19
## Uma camada que o MUNDO esconde do retrato (aqui a 18, como as placas da cidade).
const WORLD_HIDDEN_MASK: int = 1 << 17

var failures := 0
## O que o teste viu no momento em que o quadro do retrato entrou na cena.
var _seen: Array[Dictionary] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	for setter in [app.set_home_theme, app.set_home_layout, app.set_home_wall_color, app.set_home_neon_color]:
		setter.call("")
	app.set_time_of_day("noite")  # hora fixa: o relógio do PC não troca a fase no meio do teste
	load("res://tests/quiet_friends.gd").install(root)

	await _check_component()
	await _check_city()
	_check_no_city_reference()

	_restore(backup)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


# --- O componente, sozinho ------------------------------------------------------

func _check_component() -> void:
	print("== o componente, sem mundo ==")
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	var view = load(VIEW_SCRIPT).new()
	view.hidden_layers = HOME_LAYER_MASK
	view.child_entered_tree.connect(_on_view_child)
	world.add_child(view)
	var material := ShaderMaterial.new()
	material.shader = load(CITY_SHADER)
	view.set_material(material)
	view.set_night(1.0)
	await _frames(3)
	_check("sem ponto: nenhum retrato, a janela fica com a vista de reserva",
			view.capture_count == 0 and not view.has_portrait() and float(material.get_shader_parameter("view_mix")) == 0.0)
	var WindowViewScript: GDScript = load(VIEW_SCRIPT)
	_check("o shader da cidade usa o retrato; o da floresta, não",
			WindowViewScript.uses_view(load(CITY_SHADER)) and not WindowViewScript.uses_view(load(FOREST_SHADER)))

	print("== com ponto ==")
	var point = load(POINT_SCRIPT).new()
	point.zoom = 1.2
	point.hidden_layers = WORLD_HIDDEN_MASK
	point.position = Vector3(0.0, 60.0, 150.0)
	world.add_child(point)
	await _frames(3)
	_check("com ponto: um retrato", view.capture_count == 1 and view.has_portrait() and _seen.size() == 1)
	if not _seen.is_empty():
		var first: Dictionary = _seen[0]
		_check("o quadro do retrato desenha uma vez só (UPDATE_ONCE)", first["mode"] == SubViewport.UPDATE_ONCE)
		_check("o quadro divide o mundo da cena", first["shares_world"])
		_check("a câmera do retrato não vê a camada da casa", first["mask"] & HOME_LAYER_MASK == 0 and first["mask"] != 0)
		_check("a câmera do retrato não vê as camadas que o ponto esconde (e segue sem a da casa)",
				first["mask"] & WORLD_HIDDEN_MASK == 0 and first["mask"] & HOME_LAYER_MASK == 0 and first["mask"] & 1 == 1)
		_check("a câmera fica no ponto e fecha a lente com o zoom",
				first["origin"].is_equal_approx(point.global_position) and first["fov"] < view.FOV_X_DEGREES)
	_check("depois do retrato, o quadro é desfeito", _portrait_viewports(view) == 0)
	_check("o retrato entra com fade (começa na vista de reserva)", float(material.get_shader_parameter("view_mix")) < 1.0)
	await create_timer(view.FADE_IN_SECONDS + 0.4).timeout
	_check("no fim do fade, a janela mostra o retrato", is_equal_approx(float(material.get_shader_parameter("view_mix")), 1.0)
			and material.get_shader_parameter("view_texture") != null)

	print("== a fase do dia ==")
	for night in [0.86, 0.9, 0.95, 1.0, 0.88]:
		view.set_night(night)
		await process_frame
	await _frames(2)
	_check("avisos de hora dentro da noite não refazem o retrato", view.capture_count == 1)
	view.set_night(0.5)
	await _frames(3)
	_check("noite → pôr do sol: um retrato novo", view.capture_count == 2 and view.get_phase() == view.Phase.DUSK)
	for night in [0.45, 0.4, 0.3, 0.6]:
		view.set_night(night)
		await process_frame
	await _frames(2)
	_check("avisos dentro do pôr do sol não refazem", view.capture_count == 2)
	view.set_night(0.0)
	await _frames(3)
	view.set_night(0.1)
	await _frames(3)
	_check("pôr do sol → dia: mais um, e só um", view.capture_count == 3 and view.get_phase() == view.Phase.DAY)
	_check("a troca de fase funde o retrato velho no novo (view_blend < 1 logo depois)",
			float(material.get_shader_parameter("view_blend")) < 1.0)
	_check("cada retrato teve o próprio quadro, sempre em UPDATE_ONCE",
			_seen.size() == 3 and _seen.all(func(seen: Dictionary) -> bool: return seen["mode"] == SubViewport.UPDATE_ONCE))

	print("== sem ponto de novo, e a cabana ==")
	# Uma captura começa (troca de fase) e o ponto sai no meio dela.
	var captures: int = view.capture_count
	view.set_night(1.0)
	var started: bool = view.get_capture_viewport() != null
	world.remove_child(point)
	await _frames(4)
	_check("o ponto saiu no meio de uma captura: o retrato velho não volta, fica a vista de reserva",
			started and view.capture_count == captures + 1 and not view.has_portrait()
			and float(material.get_shader_parameter("view_mix")) == 0.0)
	point.free()
	captures = view.capture_count
	var forest := ShaderMaterial.new()
	forest.shader = load(FOREST_SHADER)
	view.set_material(forest)
	var point2 = load(POINT_SCRIPT).new()
	world.add_child(point2)
	view.set_night(1.0)
	await _frames(3)
	_check("com o shader da floresta, nenhum retrato", view.capture_count == captures)
	world.queue_free()
	await _frames(2)


func _on_view_child(node: Node) -> void:
	if not node is SubViewport:
		return
	var viewport := node as SubViewport
	var camera: Camera3D = null
	for child in viewport.get_children():
		if child is Camera3D:
			camera = child
	_seen.append({
		"mode": viewport.render_target_update_mode,
		"shares_world": not viewport.own_world_3d and viewport.world_3d == root.world_3d,
		"mask": camera.cull_mask if camera != null else 0,
		"origin": camera.transform.origin if camera != null else Vector3.INF,
		"fov": camera.fov if camera != null else 999.0,
	})


func _portrait_viewports(view: Node) -> int:
	var count := 0
	for child in view.get_children():
		if child is SubViewport and not child.is_queued_for_deletion():
			count += 1
	return count


# --- Na cidade ----------------------------------------------------------------

func _check_city() -> void:
	print("== na cidade ==")
	load("res://tests/fake_library.gd").install(root, 120)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	var home = city.get_home()
	var view = home.get_window_view()
	var before_ready := 0
	while not city.is_city_ready():
		before_ready = maxi(before_ready, get_nodes_in_group(&"window_view_point").size())
		await process_frame
	await _frames(4)
	var points := get_nodes_in_group(&"window_view_point")
	_check("o ponto só entra com a cidade pronta", before_ready == 0)
	_check("a cidade oferece um ponto só", points.size() == 1)
	_check("a casa tirou um retrato só (e a janela usa o da cidade)", view.capture_count == 1 and view.has_portrait())
	_check("a câmera do retrato não vê a casa", view.hidden_layers == home.INTERIOR_LAYER_MASK)
	if points.size() == 1:
		var point: Node3D = points[0]
		_check("o ponto fica alto, acima dos letreiros dos bairros", point.global_position.y >= 30.0)
		_check("o ponto esconde a camada das placas dos bairros", point.hidden_layers == DistrictSign.RENDER_LAYER_MASK)
		var trails := get_nodes_in_group(&"mountain_trail")
		if not trails.is_empty():
			var tower: Vector3 = trails[0].tower_spot()
			var to_tower := Vector2(tower.x - point.global_position.x, tower.z - point.global_position.z).normalized()
			var forward := -point.global_basis.z
			_check("o ponto olha para a montanha",
					Vector2(forward.x, forward.z).normalized().dot(to_tower) > 0.9)
		else:
			print("  (sem montanha nesta biblioteca: a direção não foi conferida)")
	# A hora muda de fase: um retrato a mais, e só um.
	home.set_night(0.0)
	await _frames(3)
	home.set_night(0.02)
	await _frames(3)
	_check("a casa refaz o retrato só na troca de fase", view.capture_count == 2)
	_check_sign_layers(city)
	city.queue_free()
	await _frames(3)


## Toda a geometria de uma placa de bairro fica só na camada das placas.
func _check_sign_layers(city: Node) -> void:
	var signs := city.find_children("DistrictSign_*", "Node3D", false, false)
	var meshes := 0
	var all_on_layer := true
	for district_sign in signs:
		for node in district_sign.get_children():
			if node is GeometryInstance3D:
				meshes += 1
				if (node as GeometryInstance3D).layers != DistrictSign.RENDER_LAYER_MASK:
					all_on_layer = false
	_check("há placas de bairro, cada uma com placa, filete e nome (3 peças)", not signs.is_empty() and meshes == signs.size() * 3)
	_check("toda a geometria das placas fica só na camada das placas",
			all_on_layer and DistrictSign.RENDER_LAYER_MASK == 1 << 17)
	_check("a camada das placas não é a da casa nem a do espelho",
			DistrictSign.RENDER_LAYER_MASK & (HOME_LAYER_MASK | (1 << 18)) == 0)


# --- A regra 1 ------------------------------------------------------------------

func _check_no_city_reference() -> void:
	print("== a casa e os componentes não conhecem a cidade ==")
	var offenders: Array[String] = []
	for folder in ["res://worlds/home", "res://components"]:
		_scan(folder, offenders)
	_check("nenhum arquivo de worlds/home nem de components cita worlds/city %s" % [offenders], offenders.is_empty())


func _scan(folder: String, offenders: Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd", "gdshader", "tscn", "tres"]:
			var path := folder.path_join(file)
			if FileAccess.get_file_as_string(path).contains("worlds/city"):
				offenders.append(path)
	for sub in DirAccess.get_directories_at(folder):
		_scan(folder.path_join(sub), offenders)


# --- Ajudantes -------------------------------------------------------------------

func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _restore(backup: String) -> void:
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	if file != null:
		file.store_string(backup)
		file.close()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
