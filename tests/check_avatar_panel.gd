extends SceneTree
## Teste do provador (Fase 13.11): escolher o avatar no espelho. Guarda o
## config.cfg e devolve no fim.
##   - olhar o espelho mostra o cartão; E foca, a câmera chega à pose e o painel aparece;
##   - um clique de verdade numa amostra muda a cor do corpo do espelho e o config.cfg;
##   - um visual pronto troca as 5 cores de uma vez;
##   - teclado: ↓ passa pelas 6 linhas, → anda pelas amostras, Enter escolhe;
##   - Esc fecha o painel e devolve a câmera; o menu de pausa não abre durante o foco;
##   - ao reabrir a casa (cena nova), o avatar escolhido continua.

const CONFIG := "user://config.cfg"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	for setter in ["set_home_theme", "set_home_layout", "set_home_wall_color", "set_home_neon_color"]:
		app.call(setter, "")
	app.set_avatar(AvatarSpec.new().to_dict())  # começa no avatar padrão
	load("res://tests/quiet_friends.gd").install(root)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	root.get_node("GameLauncher")._poll_timer.paused = true
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var home = city.get_home()
	var mirror = home.get_furniture("espelho")
	var panel = mirror.get_panel()
	var catalog := load("res://profiles/avatar_catalog.tres") as AvatarCatalog

	print("== o catálogo ==")
	_check("5 visuais prontos, com nome", catalog.presets.size() == 5 and catalog.preset_names.size() == 5)
	var palettes_ok := true
	for zone in AvatarSpec.ZONES:
		palettes_ok = palettes_ok and catalog.palette_of(zone).size() >= 6
	_check("cada uma das 5 partes tem pelo menos 6 cores prontas", palettes_ok)
	var different := {}
	for preset in catalog.presets:
		different[JSON.stringify(preset.to_dict())] = true
	_check("os visuais são diferentes entre si", different.size() == 5)

	print("== olhar e apertar E ==")
	var normal: Vector3 = mirror.get_normal()
	var feet: Vector3 = mirror.global_position + normal * 1.6
	feet.y = home.global_position.y + 0.1
	player.teleport_to(Transform3D(Basis.looking_at(-normal), feet))
	player.get_node("Head").rotation.x = 0.0
	await _frames(5)
	_check("em casa", player.is_indoors())
	_check("o cartão mostra o espelho com a dica do E", hud.get_look_text().begins_with("Espelho") and hud.get_look_action() != "")
	_check("o painel está escondido", not panel.visible)
	await _press_e()
	await create_timer(0.8).timeout
	_check("está com o foco no espelho", player.is_focused() and mirror.is_focused())
	var pose: Transform3D = mirror.get_camera_pose(camera.fov, 1.78)
	_check("a câmera chegou à pose", camera.global_position.distance_to(pose.origin) < 0.01)
	_check("a câmera olha para o espelho", (-camera.global_basis.z).dot(-mirror.get_normal()) > 0.999)
	_check("o painel apareceu", panel.visible)
	_check("o corpo está parado na frente do vidro, de frente para ele",
			mirror.get_body().global_position.distance_to(mirror.to_global(Vector3(0.0, 0.0, mirror.FITTING_SPOT))) < 0.01
			and (mirror.get_body().global_basis.z).dot(-mirror.get_normal()) > 0.999)
	_check("o espelho desenha", mirror.is_active())
	var focus_owner := root.gui_get_focus_owner()
	_check("o foco do teclado começa no primeiro visual", focus_owner == panel.get_preset_buttons()[0])

	print("== clicar numa amostra ==")
	var shirts: Array = panel.get_swatches("shirt")
	var green: Button = null
	for swatch: Button in shirts:
		if swatch.tooltip_text == "#4aa860":
			green = swatch
	_check("a paleta tem o verde", green != null)
	await _click(camera, green)
	var shirt: Color = mirror.get_body().get_palette().get_shader_parameter("shirt_color")
	_check("a camiseta do corpo do espelho ficou verde", shirt.to_html(false) == "4aa860")
	_check("e gravou no config.cfg", app.get_avatar()["colors"]["shirt"] == "#4aa860" and "shirt=" in FileAccess.get_file_as_string(CONFIG))
	_check("a amostra ficou marcada", green.button_pressed)
	_check("a calça não mudou", (mirror.get_body().get_palette().get_shader_parameter("pants_color") as Color).to_html(false) == "2f3b52")

	print("== um visual pronto ==")
	await _click(camera, panel.get_preset_buttons()[3])  # "Solar"
	var solar: AvatarSpec = catalog.presets[3]
	var all_zones := true
	for zone in AvatarSpec.ZONES:
		var painted: Color = mirror.get_body().get_palette().get_shader_parameter(zone + "_color")
		all_zones = all_zones and painted.to_html(false) == solar.get_color(zone).to_html(false)
	_check("as 5 cores trocaram de uma vez", all_zones)
	_check("o config.cfg tem o visual", AvatarSpec.from_dict(app.get_avatar()).to_dict() == solar.to_dict())
	_check("o botão do visual ficou marcado", panel.get_preset_buttons()[3].button_pressed and not panel.get_preset_buttons()[0].button_pressed)

	print("== teclado ==")
	panel.get_preset_buttons()[0].grab_focus()
	var rows := {}
	for i in 6:
		await _key(KEY_DOWN)
		var owner := root.gui_get_focus_owner()
		if owner != null:
			rows[owner.get_parent()] = true
	_check("↓ passa pelas 6 linhas e volta ao primeiro visual", root.gui_get_focus_owner() == panel.get_preset_buttons()[0])
	await _key(KEY_DOWN)  # primeira peça da linha da pele
	var skin: Array = panel.get_swatches("skin")
	_check("↓ chega na primeira amostra da pele", root.gui_get_focus_owner() == skin[0])
	for i in 3:
		await _key(KEY_RIGHT)
	_check("→ anda pelas amostras", root.gui_get_focus_owner() == skin[3])
	await _key(KEY_ENTER)
	_check("Enter escolhe a amostra (e é diferente do visual anterior)", app.get_avatar()["colors"]["skin"] == "#" + catalog.palette_of("skin")[3].to_html(false)
			and catalog.palette_of("skin")[3].to_html(false) != solar.get_color("skin").to_html(false))

	print("== Esc e o menu de pausa ==")
	_check("o menu de pausa não abre durante o foco", not player.get_pause_menu().is_open())
	await _key(KEY_ESCAPE)
	await create_timer(0.8).timeout
	_check("o Esc devolve a câmera", not player.is_focused() and not mirror.is_focused())
	_check("o painel some", not panel.visible)
	_check("o menu de pausa não abriu com esse Esc", not player.get_pause_menu().is_open())
	_check("o corpo voltou a seguir o jogador", mirror.get_body().global_position.distance_to(player.global_position) < 0.05)

	print("== reabrir a casa ==")
	var saved := AvatarSpec.from_dict(app.get_avatar())
	city.queue_free()
	await _frames(3)
	var again: Node3D = (load("res://worlds/home/home.gd") as GDScript).new()
	root.add_child(again)
	await _frames(3)
	var color: Color = again.get_furniture("espelho").get_body().get_palette().get_shader_parameter("skin_color")
	_check("o avatar escolhido continua (pele %s)" % color.to_html(false), color.to_html(false) == saved.get_color("skin").to_html(false))

	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	app.set_avatar(AvatarSpec.from_dict(app.get_avatar()).to_dict())  # só para a memória reler o arquivo logo abaixo
	var restore := FileAccess.open(CONFIG, FileAccess.WRITE)
	restore.store_string(backup)
	restore.close()
	_check("config.cfg restaurado", FileAccess.get_file_as_string(CONFIG) == backup)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## Clique de verdade (mouse) no meio do botão: o painel é 2D, na janela.
func _click(camera: Camera3D, control: Control) -> void:
	var at: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		root.push_input(click)
	await _frames(2)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event)
	await _frames(2)


func _press_e() -> void:
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
