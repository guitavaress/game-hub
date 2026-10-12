extends SceneTree
## Teste da aba "Casa" do computador (Fase 13.8). Guarda o config.cfg antes e
## devolve no fim.
##   - o computador tem a aba Casa (o menu de pausa, não);
##   - um clique de verdade (mouse em 3D) no tema muda o config.cfg e a casa,
##     com o foco mantido;
##   - a amostra de cor pinta a parede e o néon; "Do tema" volta à cor original;
##   - a disposição muda os móveis;
##   - ↓ e → andam por todos os botões, e Enter escolhe.

const CONFIG := "user://config.cfg"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	var original := [app.get_home_theme(), app.get_home_layout(), app.get_home_wall_color(), app.get_home_neon_color()]
	# Começa no padrão, seja qual for o config.cfg de quem roda o teste.
	for setter in [app.set_home_theme, app.set_home_layout, app.set_home_wall_color, app.set_home_neon_color]:
		setter.call("")
	load("res://tests/quiet_friends.gd").install(root)
	# Um segundo tema só para o teste (cópia do loft), antes de a casa montar a aba.
	var catalog := Profiles.home_catalog()
	var loft: HomeProfile = Profiles.home("loft")
	var other: HomeProfile = loft.duplicate(true)
	other.id = "teste"
	other.display_name = "Teste"
	other.floor.color = Color(0.1, 0.5, 0.2)
	catalog.homes.append(other)

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
	var desk = home.get_node("ComputerDesk")
	var screen = desk.get_screen()
	var settings = desk.get_settings()
	var view = desk.get_home_view()

	print("== a aba Casa ==")
	_check("o computador tem 4 abas, a última é Casa", settings._tab_buttons.size() == 4 and settings._tab_buttons[3].text == "Casa")
	_check("a aba Casa tem tema, móveis, paredes e néon",
			view._theme_buttons.size() == catalog.homes.size() and view._theme_buttons.has("teste")
			and view._layout_buttons.size() == 3
			and view._wall_buttons.size() == 9 and view._neon_buttons.size() == 9)
	_check("o menu de pausa não ganha a aba", player.get_pause_menu().get_settings()._tab_buttons.size() == 3)

	# O jogador na frente do monitor, com o foco nele.
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
	await _click(camera, screen, settings._tab_buttons[3])
	_check("um clique na aba Casa mostra a página", settings.get_page() == 3 and settings._pages[3].visible)

	print("== tema e móveis ==")
	_check("de partida: loft e disposição padrão marcados", view._theme_buttons["loft"].button_pressed
			and view._layout_buttons["padrao"].button_pressed)
	await _click(camera, screen, view._theme_buttons["teste"])
	_check("o clique no tema grava no config.cfg", app.get_home_theme() == "teste" and 'theme="teste"' in FileAccess.get_file_as_string(CONFIG))
	await process_frame
	_check("a casa mudou na hora", home.get_profile() == other)
	_check("o foco continua no computador", player.is_focused() and screen.is_focused())
	_check("o botão do tema ficou marcado", view._theme_buttons["teste"].button_pressed and not view._theme_buttons["loft"].button_pressed)
	var shelf_before: Vector3 = home.get_furniture("estante").position
	await _click(camera, screen, view._layout_buttons["espelhada"])
	await process_frame
	_check("a disposição Espelhada moveu a estante", app.get_home_layout() == "espelhada"
			and home.get_furniture("estante").position != shelf_before
			and home.get_furniture("estante").position.is_equal_approx(home.get_anchor_transform("leste").origin))

	print("== cores ==")
	var blue := "#3a6ea5"
	_check("a paleta tem o azul", view._wall_buttons.has(blue))
	await _click(camera, screen, view._wall_buttons[blue])
	await process_frame
	_check("a amostra pinta a parede e grava", app.get_home_wall_color() == blue and _material_color(home, "WallWest").is_equal_approx(Color(blue)))
	var neon_key: String = view._neon_buttons.keys()[1]
	await _click(camera, screen, view._neon_buttons[neon_key])
	await process_frame
	_check("a amostra troca o néon", app.get_home_neon_color() == neon_key
			and _glow_color(home, "NeonStrip").to_html(false) == neon_key.trim_prefix("#"))
	await _click(camera, screen, view._wall_buttons[""])
	await process_frame
	_check("\"Do tema\" volta à parede original", app.get_home_wall_color() == ""
			and not _material_color(home, "WallWest").is_equal_approx(Color(blue)))
	_check("e a amostra azul se desmarca", not view._wall_buttons[blue].button_pressed and view._wall_buttons[""].button_pressed)

	print("== teclado e controle ==")
	var viewport: Viewport = screen.get_viewport_node()
	settings._go_to_page(3)
	await _frames(2)
	_check("o foco está na aba Casa", viewport.gui_get_focus_owner() == settings._tab_buttons[3])
	var rows := {}
	var steps := 0
	await _key(KEY_DOWN)
	while viewport.gui_get_focus_owner() != settings._tab_buttons[3] and steps < 12:
		var focus := viewport.gui_get_focus_owner()
		if focus != null:
			rows[focus.get_parent()] = true
		await _key(KEY_DOWN)
		steps += 1
	# 4 linhas da página + o rodapé (Sair do hub), e então volta para a aba.
	_check("↓ passa pelas 4 linhas e pelo rodapé e volta à aba (%d passos)" % steps, rows.size() == 5 and steps == 5)
	# Na linha do néon, → anda por todas as amostras e para na ponta.
	settings._tab_buttons[3].grab_focus()
	await _key(KEY_UP)  # da aba para o rodapé (o botão Sair)
	var guard := 0
	while viewport.gui_get_focus_owner() != view._neon_buttons[""] and guard < 8:
		await _key(KEY_UP)
		guard += 1
	_check("↑ chega à primeira peça do néon", viewport.gui_get_focus_owner() == view._neon_buttons[""])
	var visited := 1
	for i in 12:
		var before := viewport.gui_get_focus_owner()
		await _key(KEY_RIGHT)
		if viewport.gui_get_focus_owner() != before:
			visited += 1
	_check("→ alcança as 9 peças do néon (%d)" % visited, visited == 9)
	var last_key: String = view._neon_buttons.keys()[8]
	_check("e para na última amostra", viewport.gui_get_focus_owner() == view._neon_buttons[last_key])
	await _key(KEY_ENTER)
	await process_frame
	_check("Enter escolhe a amostra", app.get_home_neon_color() == last_key)

	# Devolve tudo.
	player.leave_focus(true)
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


func _material_color(home: Node, node_name: String) -> Color:
	var mesh := home.find_child(node_name, true, false) as MeshInstance3D
	var material := mesh.material_override
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter("base_color")
	return (material as StandardMaterial3D).albedo_color


func _glow_color(home: Node, node_name: String) -> Color:
	var mesh := home.find_child(node_name, true, false) as MeshInstance3D
	return (mesh.material_override as StandardMaterial3D).emission


## Clique de verdade (mouse) no meio do controle, pela tela 3D.
func _click(camera: Camera3D, screen: Node, control: Control) -> void:
	var pixel := control.get_global_rect().get_center()
	var at: Vector2 = root.get_final_transform() * camera.unproject_position(screen.pixel_to_world(pixel))
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


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
