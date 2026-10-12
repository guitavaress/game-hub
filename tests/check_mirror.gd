extends SceneTree
## Teste do espelho da casa (Fase 13.10). Guarda o config.cfg e devolve no fim.
##   - longe do espelho, ou de costas para ele, o reflexo fica desligado; de
##     perto e olhando, liga (e o corpo aparece);
##   - a resolução segue a qualidade; na Leve, desenha um quadro sim, um não;
##   - a câmera do jogador não vê a camada do reflexo, e a do espelho vê;
##   - a câmera do espelho fica no reflexo do olho (simétrico ao plano do vidro),
##     com o corte no vidro;
##   - fora de casa, desligado;
##   - trocar as cores do avatar no config.cfg pinta o corpo do reflexo.

const CONFIG := "user://config.cfg"
const REFLECTION_MASK := 1 << 18

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	for setter in ["set_home_theme", "set_home_layout", "set_home_wall_color", "set_home_neon_color"]:
		app.call(setter, "")
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	root.get_node("GameLauncher")._poll_timer.paused = true
	var player = city.get_node("Player")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var home = city.get_home()
	var mirror = home.get_furniture("espelho")
	var viewport: SubViewport = mirror.get_viewport_node()
	var mirror_camera: Camera3D = mirror.get_mirror_camera()

	print("== montagem ==")
	_check("a casa tem o espelho, na âncora da disposição", mirror != null
			and mirror.position.is_equal_approx(home.get_anchor_transform(home.get_layout().placements["espelho"]).origin))
	_check("a câmera do jogador não vê o reflexo", camera.cull_mask & REFLECTION_MASK == 0)
	_check("a câmera do espelho vê o reflexo e o interior", mirror_camera.cull_mask & REFLECTION_MASK != 0
			and mirror_camera.cull_mask & (1 << 19) != 0 and mirror_camera.cull_mask & 1 == 0)
	_check("o corpo do reflexo está só na camada do reflexo", _body_layers(mirror) == REFLECTION_MASK)

	print("== ligado só quando importa ==")
	player.teleport_to(home.get_spawn_transform())
	player.set_indoors(home.get_environment())
	await _frames(4)
	_check("no ponto de nascer (longe), desligado", not mirror.is_active()
			and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not mirror.get_body().visible)
	_stand_in_front(player, home, mirror, 1.8, false)
	await _frames(4)
	_check("a 1,8 m e olhando, ligado", mirror.is_active() and mirror.get_body().visible)
	_check("o corpo está onde o jogador está", Vector2(mirror.get_body().global_position.x, mirror.get_body().global_position.z)
			.distance_to(Vector2(player.global_position.x, player.global_position.z)) < 0.01)
	_stand_in_front(player, home, mirror, 1.8, true)
	await _frames(4)
	_check("de costas para o espelho, desligado", not mirror.is_active())
	_stand_in_front(player, home, mirror, 1.8, false)
	await _frames(4)
	player.set_indoors(null)
	await _frames(3)
	_check("fora de casa, desligado", not mirror.is_active())
	player.set_indoors(home.get_environment())
	await _frames(3)
	_check("de volta em casa, liga de novo", mirror.is_active())

	print("== a conta do reflexo ==")
	var eye := camera.global_position
	var mirrored: Vector3 = mirror.reflect_point(eye)
	var middle := (eye + mirrored) / 2.0
	var normal: Vector3 = mirror.get_normal()
	_check("o meio entre o olho e o reflexo fica no plano do vidro", absf((middle - mirror.get_glass_center()).dot(normal)) < 0.001)
	_check("o olho e o reflexo estão na mesma reta da normal", (mirrored - eye).normalized().cross(normal).length() < 0.001)
	_check("a câmera do espelho fica no reflexo do olho", mirror_camera.global_position.distance_to(mirrored) < 0.01)
	_check("ela olha para dentro da sala", (-mirror_camera.global_basis.z).dot(normal) > 0.999)
	_check("projeção recortada na moldura (FRUSTUM)", mirror_camera.projection == Camera3D.PROJECTION_FRUSTUM
			and is_equal_approx(mirror_camera.size, mirror.GLASS_SIZE.y))
	var distance: float = (eye - mirror.get_glass_center()).dot(normal)
	_check("o corte fica no vidro (perto = %.2f m)" % mirror_camera.near, absf(mirror_camera.near - distance) < 0.01)
	var corner: Vector3 = mirror.to_global(Vector3(mirror.GLASS_SIZE.x / 2.0, mirror.GLASS_CENTER_Y + mirror.GLASS_SIZE.y / 2.0, mirror.FRAME_DEPTH + 0.004))
	var on_screen: Vector2 = mirror_camera.unproject_position(corner) / Vector2(viewport.size)
	_check("o canto do vidro cai no canto da imagem (%.2f, %.2f)" % [on_screen.x, on_screen.y],
			on_screen.distance_to(Vector2(0.0, 0.0)) < 0.03 or on_screen.distance_to(Vector2(1.0, 0.0)) < 0.03)

	print("== qualidade ==")
	var quality_before: String = app.get_quality()
	app.set_quality("alta")
	await _frames(2)
	_check("Alta: 480 × 900", viewport.size == Vector2i(480, 900))
	var modes_high := await _modes(6)
	_check("Alta: desenha todo quadro", not modes_high.has(SubViewport.UPDATE_DISABLED))
	app.set_quality("leve")
	await _frames(2)
	_check("Leve: 240 × 450", viewport.size == Vector2i(240, 450))
	var modes_low := await _modes(6)
	_check("Leve: um quadro sim, um não %s" % str(modes_low), modes_low.count(SubViewport.UPDATE_DISABLED) == 3
			and modes_low.count(SubViewport.UPDATE_ONCE) == 3)
	app.set_quality(quality_before)

	print("== cores do avatar ==")
	var avatar_before: Dictionary = app.get_avatar()
	var data: Dictionary = avatar_before.duplicate(true)
	data["colors"] = (data.get("colors", {}) as Dictionary).duplicate()
	data["colors"]["shirt"] = "#2fbf4a"
	app.set_avatar(data)
	await _frames(2)
	var shirt: Color = mirror.get_body().get_palette().get_shader_parameter("shirt_color")
	_check("a camiseta do reflexo ficou verde", shirt.to_html(false) == "2fbf4a")
	app.set_avatar(avatar_before)

	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## O jogador a "meters" do vidro, olhando para ele (ou de costas).
func _stand_in_front(player: Node3D, home: Node3D, mirror: Node3D, meters: float, backwards: bool) -> void:
	var normal: Vector3 = mirror.get_normal()
	var feet: Vector3 = mirror.global_position + normal * meters
	feet.y = home.global_position.y + 0.1
	var look := normal if backwards else -normal
	player.teleport_to(Transform3D(Basis.looking_at(look), feet))
	player.get_node("Head").rotation.x = 0.0


## O modo de desenho do reflexo, quadro a quadro.
func _modes(count: int) -> Array:
	var modes := []
	var viewport: SubViewport = null
	for node in root.find_children("Reflection", "SubViewport", true, false):
		viewport = node
	for i in count:
		await process_frame
		modes.append(viewport.render_target_update_mode)
	return modes


func _body_layers(mirror: Node) -> int:
	var layers := -1
	for mesh in mirror.get_body().find_children("*", "MeshInstance3D", true, false):
		layers = (mesh as MeshInstance3D).layers if layers == -1 or layers == (mesh as MeshInstance3D).layers else -2
	return layers


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
