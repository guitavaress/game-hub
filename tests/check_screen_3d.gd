extends SceneTree
## Teste da tela 3D e do computador da casa (Fase 9.7):
##   - E no monitor foca: a câmera chega à pose, o mouse fica visível e o
##     jogador não anda;
##   - um clique simulado (mouse na janela → raio → pixel da tela) no
##     "Bússola e mapa" troca a opção;
##   - digitar num campo funciona;
##   - o primeiro Esc tira o cursor do campo e o segundo devolve a câmera;
##   - o menu de pausa (e a busca) não abrem durante o foco.
## Guarda o config.cfg antes e devolve no fim. Nunca digita uma chave de API.

const CONFIG := "user://config.cfg"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var backup := FileAccess.get_file_as_string(CONFIG)
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout  # a tela termina de clarear
	var launcher = root.get_node("GameLauncher")
	launcher._poll_timer.paused = true
	var app = root.get_node("AppConfig")
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var home = city.get_home()
	var desk = home.get_node("ComputerDesk")
	var screen = desk.get_screen()
	var settings = desk.get_settings()

	print("== Montagem ==")
	_check("o computador está na casa", desk != null and screen != null and settings != null)
	_check("a tela fica na camada do interior", screen.get_node("Surface").layers == 1 << 19)
	var size: Vector2i = screen.get_viewport_node().size
	_check("o conteúdo tem a resolução da tela (%dx%d)" % [size.x, size.y], size == screen.resolution)
	print("  (janela do teste: %s)" % str(root.get_visible_rect().size))

	# Jogador 1 m na frente do monitor, olhando para o meio da tela.
	var front: Vector3 = screen.global_basis.z
	front.y = 0.0
	front = front.normalized()
	var feet: Vector3 = screen.global_position + front * 1.0
	feet.y = home.global_position.y + 0.1
	player.teleport_to(Transform3D(Basis.looking_at(-front), feet))
	await _frames(4)
	var eye: Vector3 = player.get_node("Head").global_position
	var to_screen: Vector3 = screen.global_position - eye
	player.get_node("Head").rotation.x = atan2(to_screen.y, Vector2(to_screen.x, to_screen.z).length())
	await _frames(3)
	_check("em casa", player.is_indoors())
	_check("o cartão mostra o computador com a dica do E", hud.get_look_text().begins_with("Computador")
			and hud.get_look_action() != "")

	print("== E foca ==")
	await _press_e()
	await create_timer(0.8).timeout
	var window := root.get_visible_rect().size
	var pose: Transform3D = screen.get_camera_pose(camera.fov, window.x / window.y)
	_check("está com o foco na tela", player.is_focused() and screen.is_focused())
	_check("a câmera chegou à pose", camera.global_position.distance_to(pose.origin) < 0.01)
	_check("a câmera olha para a tela", (-camera.global_basis.z).dot(-screen.global_basis.z) > 0.999)
	_check_mouse("o mouse fica visível", Input.MOUSE_MODE_VISIBLE)
	_check("o HUD some", not hud.visible)
	var before: Vector3 = player.global_position
	Input.action_press("move_forward")
	await create_timer(0.5).timeout
	Input.action_release("move_forward")
	await _frames(2)
	_check("o jogador não anda", player.global_position.distance_to(before) < 0.05)
	# A tela cobre quase a janela: o canto de cima da tela fica dentro dela e
	# perto de uma borda (a de cima numa janela larga; a do lado numa estreita,
	# como a de 64x64 do teste sem janela).
	var corner: Vector2 = camera.unproject_position(screen.pixel_to_world(Vector2.ZERO))
	_check("a tela ocupa quase a janela inteira (canto em %s)" % str(corner.round()),
			corner.x > -1.0 and corner.y > -1.0 and minf(corner.x / window.x, corner.y / window.y) < 0.06)

	print("== Clique na tela ==")
	var shown: bool = app.get_show_map()
	_click(camera, screen, settings._map_check)
	await _frames(2)
	_check("um clique no \"Bússola e mapa\" troca a opção", app.get_show_map() == (not shown))
	_check("e grava no config.cfg", ("show_map=%s" % str(not shown).to_lower()) in FileAccess.get_file_as_string(CONFIG))
	_click(camera, screen, settings._map_check)
	await _frames(2)
	_check("outro clique desfaz", app.get_show_map() == shown)
	# Um clique fora da tela não prende o mouse de novo.
	_push_click(Vector2(2.0, 2.0))
	await _frames(2)
	_check("clique fora da tela não tira o foco", player.is_focused())
	_check_mouse("e o mouse continua solto", Input.MOUSE_MODE_VISIBLE)

	print("== Digitar ==")
	_click(camera, screen, settings._tab_buttons[2])  # aba Amigos
	await _frames(2)
	_check("um clique na aba Amigos mostra a página", settings._pages[2].visible)
	var field: LineEdit = settings._steam_id_field
	field.text = ""
	_click(camera, screen, field)
	await _frames(2)
	_check("o campo do ID ganha o cursor", field.has_focus())
	for digit in "765":
		_push_key(OS.find_keycode_from_string(digit), digit.unicode_at(0))
	await _frames(2)
	_check("as teclas viram texto no campo (\"%s\")" % field.text, field.text == "765")
	_push_key(KEY_TAB, 0)
	await _frames(2)
	_check("Tab não abre a busca durante o foco", not player.get_game_search().is_open())

	print("== Esc ==")
	_push_key(KEY_ESCAPE, 0)
	await _frames(2)
	_check("1º Esc: o campo perde o cursor", not field.has_focus())
	_check("1º Esc: continua focado", player.is_focused())
	_check("1º Esc: o menu de pausa não abre", not player.get_pause_menu().is_open())
	_push_key(KEY_ESCAPE, 0)
	await _frames(2)
	_check("2º Esc: o menu de pausa não abre", not player.get_pause_menu().is_open())
	await create_timer(0.8).timeout
	_check("2º Esc: a câmera voltou para a cabeça", camera.position.length() < 0.001
			and camera.rotation.length() < 0.001)
	_check("sem foco", not player.is_focused() and not screen.is_focused())
	_check_mouse("o mouse é preso de novo", Input.MOUSE_MODE_CAPTURED)
	_check("o HUD volta", hud.visible)
	_check("o texto digitado não foi salvo", app.get_steam_id_override() != "765")
	_push_key(KEY_ESCAPE, 0)
	await _frames(2)
	_check("sem foco, o Esc abre o menu de pausa", player.get_pause_menu().is_open())
	player.get_pause_menu().close()
	await _frames(2)

	print("== Jogo abrindo tira o foco ==")
	await _press_e()
	await create_timer(0.8).timeout
	_check("focado de novo", player.is_focused())
	launcher.game_started.emit(1, null)
	await _frames(2)
	_check("um jogo que abre tira o foco na hora", not player.is_focused() and camera.position.length() < 0.001)

	root.remove_child(city)
	city.free()
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	_check("config.cfg restaurado", FileAccess.get_file_as_string(CONFIG) == backup)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Clica no meio de um controle da tela: do pixel do conteúdo para o ponto no
## mundo, do ponto para a posição na janela, e daí um clique de verdade na
## janela (que a tela converte de volta).
func _click(camera: Camera3D, screen: Node, control: Control) -> void:
	var pixel := control.get_global_rect().get_center()
	_push_click(camera.unproject_position(screen.pixel_to_world(pixel)))


func _push_click(at: Vector2) -> void:
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


func _push_key(keycode: Key, unicode: int) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.unicode = unicode if pressed else 0
		key.pressed = pressed
		root.push_input(key)


func _press_e() -> void:
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


## Sem janela (--headless) o modo do mouse não muda: aí só avisa.
func _check_mouse(label: String, mode: Input.MouseMode) -> void:
	if DisplayServer.get_name() == "headless":
		print("  [--] %s (sem janela: conferir na mão)" % label)
	else:
		_check(label, Input.mouse_mode == mode)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
