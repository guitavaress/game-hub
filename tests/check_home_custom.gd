extends SceneTree
## Teste das escolhas da casa (Fase 13.3): a seção [home] do config.cfg
## (tema, cores da parede e do néon) e a troca na hora.
##   - o config guarda e devolve os textos;
##   - um segundo tema (cópia do loft com outras cores, feita aqui) refaz a
##     casca na hora; os móveis continuam os mesmos nós;
##   - a cor da parede pinta só o que é "paintable"; a do néon troca a faixa e a luz;
##   - tema desconhecido cai no loft; "" volta às cores do tema;
##   - com a câmera focada no computador, trocar o tema não tira o foco;
##   - tudo o que foi refeito fica na camada do interior e leva a marca de passos.
## Guarda o config.cfg antes e devolve no fim.

const CONFIG := "user://config.cfg"
const INTERIOR_MASK := 1 << 19

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	var original := [app.get_home_theme(), app.get_home_layout(), app.get_home_wall_color(), app.get_home_neon_color()]
	var catalog := Profiles.home_catalog()

	print("== o config guarda e devolve ==")
	app.set_home_theme("Teste")
	app.set_home_wall_color("#3a6ea5")
	_check("tema volta em minúsculas", app.get_home_theme() == "teste")
	_check("cor da parede volta igual", app.get_home_wall_color() == "#3a6ea5")
	_check("gravou no config.cfg", 'wall_color="#3a6ea5"' in FileAccess.get_file_as_string(CONFIG))
	app.set_home_theme("")
	app.set_home_wall_color("")

	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	var player = city.get_node("Player")
	var home = city.get_home()
	var loft: HomeProfile = Profiles.home("loft")
	var shelf = home.get_node("LibraryShelf")
	var desk = home.get_node("ComputerDesk")
	var front_door = home.get_front_door()
	var env: Environment = home.get_environment()

	# Um segundo tema: cópia do loft com outras cores (só existe neste teste).
	var other: HomeProfile = loft.duplicate(true)
	other.id = "teste"
	other.display_name = "Teste"
	other.floor.color = Color(0.1, 0.5, 0.2)
	other.background_color = Color(0.3, 0.0, 0.0)
	other.neon_color = Color(0.1, 0.9, 0.2)
	catalog.homes.append(other)

	print("== tema na hora ==")
	var wall_before := _material_color(home, "WallWest")
	app.set_home_theme("teste")
	await process_frame
	_check("o piso mudou de cor", _material_color(home, "Floor").is_equal_approx(other.floor.color))
	_check("o fundo da casa mudou", env.background_color.is_equal_approx(other.background_color))
	_check("a faixa de néon mudou", _glow_color(home, "NeonStrip").is_equal_approx(other.neon_color))
	_check("os móveis são os mesmos nós", home.get_node("LibraryShelf") == shelf and home.get_node("ComputerDesk") == desk)
	_check("a porta da rua é a mesma", home.get_front_door() == front_door and is_instance_valid(front_door))
	_check("o tema de agora é o novo", home.get_profile() == other)
	_check("não ficou casca velha (um Floor só)", _count(home, "Floor") == 1 and _count(home, "WindowView") == 1)

	print("== cores escolhidas ==")
	app.set_home_wall_color("#3a6ea5")
	await process_frame
	var blue := Color("#3a6ea5")
	_check("a parede comum ficou azul", _material_color(home, "WallWest").is_equal_approx(blue))
	_check("o piso (não pintável) continua do tema", _material_color(home, "Floor").is_equal_approx(other.floor.color))
	_check("a parede da janela (tijolo) não mudou", not _material_color(home, "WallNorth").is_equal_approx(blue))
	app.set_home_neon_color("#ff0000")
	await process_frame
	_check("a faixa de néon ficou vermelha", _glow_color(home, "NeonStrip").is_equal_approx(Color.RED))
	var neon_light: OmniLight3D = home.find_child("NeonLight", true, false)
	_check("a luz do néon ficou vermelha", neon_light.light_color.is_equal_approx(Color.RED))
	app.set_home_wall_color("")
	app.set_home_neon_color("")
	await process_frame
	_check("\"\" volta à parede do tema", _material_color(home, "WallWest").is_equal_approx(wall_before))
	_check("\"\" volta ao néon do tema", _glow_color(home, "NeonStrip").is_equal_approx(other.neon_color))
	app.set_home_wall_color("isso não é cor")
	await process_frame
	_check("cor inválida vale como a do tema", _material_color(home, "WallWest").is_equal_approx(wall_before))
	app.set_home_wall_color("")

	print("== tema desconhecido ==")
	app.set_home_theme("nao_existe")
	await process_frame
	_check("cai no loft", home.get_profile() == loft)
	_check("o piso voltou ao do loft", _material_color(home, "Floor").is_equal_approx(loft.floor.color))

	print("== com o foco no computador ==")
	var screen = load("res://tests/settings_screen.gd").install(home).screen
	var front: Vector3 = screen.global_basis.z
	front.y = 0.0
	front = front.normalized()
	var feet: Vector3 = screen.global_position + front * 1.0
	feet.y = home.global_position.y + 0.1
	player.teleport_to(Transform3D(Basis.looking_at(-front), feet))
	for i in 4:
		await process_frame
	player.focus_on(screen)
	await create_timer(0.8).timeout
	_check("está com o foco no computador", player.is_focused() and screen.is_focused())
	var camera_before: Vector3 = player.get_node("Head/Camera3D").global_position
	app.set_home_theme("teste")
	await process_frame
	await process_frame
	_check("trocar o tema não tirou o foco", player.is_focused() and screen.is_focused())
	_check("a câmera não se mexeu", player.get_node("Head/Camera3D").global_position.distance_to(camera_before) < 0.01)
	_check("o tema trocou mesmo", home.get_profile() == other)
	player.leave_focus(true)
	await process_frame

	print("== camada do interior e passos ==")
	var wrong := 0
	var steps := 0
	for node in home.find_children("*", "GeometryInstance3D", true, false):
		var layers := (node as GeometryInstance3D).layers
		if layers != INTERIOR_MASK and layers != 1 << 18:  # 1 << 18 = o corpo do espelho (só no reflexo)
			wrong += 1
	for body in home.find_children("*", "StaticBody3D", true, false):
		if body.get_meta("footstep", "") == "wood":
			steps += 1
	_check("todo desenho da casa está na camada do interior (%d fora)" % wrong, wrong == 0)
	_check("os sólidos refeitos têm a marca de passos (%d)" % steps, steps > 10)

	# Devolve tudo.
	catalog.homes.erase(other)
	app.set_home_theme(original[0])
	app.set_home_layout(original[1])
	app.set_home_wall_color(original[2])
	app.set_home_neon_color(original[3])
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	_check("config.cfg restaurado", FileAccess.get_file_as_string(CONFIG) == backup)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## Cor do material (madeira: base_color; textura/fosco: albedo) da peça com esse nome.
func _material_color(home: Node, node_name: String) -> Color:
	var mesh := home.find_child(node_name, true, false) as MeshInstance3D
	var material := mesh.material_override
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter("base_color")
	return (material as StandardMaterial3D).albedo_color


func _glow_color(home: Node, node_name: String) -> Color:
	var mesh := home.find_child(node_name, true, false) as MeshInstance3D
	return (mesh.material_override as StandardMaterial3D).emission


func _count(home: Node, node_name: String) -> int:
	return home.find_children(node_name, "", true, false).size()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
