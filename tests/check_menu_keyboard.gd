extends SceneTree
## Teste do menu pelo teclado (Fase 12.4). Guarda o config.cfg antes e devolve
## no fim. Nunca grava uma chave de API.
##   - ao abrir a pausa, o foco começa na aba;
##   - setas e Enter fazem tudo: ↓ vai até o volume Geral, → sobe o volume;
##     ←/→ numa aba trocam de aba; Enter liga e desliga uma opção;
##   - Esc fecha; Tab e as setas não vazam para o jogo (a busca não abre);
##   - B (ui_cancel) fecha a busca, o mapa e o menu;
##   - no computador da casa, o teclado também navega, e o primeiro Esc só
##     tira o foco de um campo de texto (senão, devolve a câmera).

const CONFIG := "user://config.cfg"

var failures := 0
var backup := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	backup = FileAccess.get_file_as_string(CONFIG)
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	var launcher = root.get_node("GameLauncher")
	launcher._poll_timer.paused = true
	var app = root.get_node("AppConfig")
	var player = city.get_node("Player")
	var menu = player.get_pause_menu()
	var settings = menu.get_settings()

	print("== Foco ao abrir ==")
	await _key(KEY_ESCAPE)
	_check("o menu abriu", menu.is_open())
	_check("o foco começa na aba da página de agora", _focus() == settings._tab_buttons[0])

	print("== Setas e Enter ==")
	var volume_before: float = settings._volume_sliders["Master"].value
	await _key(KEY_DOWN)
	_check("↓ vai até o volume Geral", _focus() == settings._volume_sliders["Master"])
	await _key(KEY_LEFT)
	_check("← baixa o volume", settings._volume_sliders["Master"].value == volume_before - 1.0)
	_check("e vale na hora (config)", is_equal_approx(app.get_volume("Master"), (volume_before - 1.0) / 100.0))
	await _key(KEY_RIGHT)
	_check("→ sobe de volta", settings._volume_sliders["Master"].value == volume_before)
	await _key(KEY_UP)
	_check("↑ volta para a aba", _focus() == settings._tab_buttons[0])
	await _key(KEY_RIGHT)
	_check("→ na aba troca para Controles", settings.get_page() == 1 and settings._pages[1].visible
			and _focus() == settings._tab_buttons[1])
	var motion_before: bool = app.get_camera_motion()
	var steps := 0
	while _focus() != settings._motion_check and steps < 12:
		await _key(KEY_DOWN)
		steps += 1
	_check("↓ chega no 'Balanço da câmera' (em %d passos)" % steps, _focus() == settings._motion_check)
	await _key(KEY_ENTER)
	_check("Enter liga e desliga a opção", app.get_camera_motion() == (not motion_before))
	await _key(KEY_ENTER)
	_check("e de novo, volta", app.get_camera_motion() == motion_before)
	await _go_to(settings, settings._tab_buttons[1], KEY_UP)
	await _key(KEY_LEFT)
	_check("← na aba volta para Som e vídeo", settings.get_page() == 0)
	var quality_before: String = app.get_quality()
	var target := "media" if quality_before != "media" else "leve"
	steps = 0
	while not _is_quality_button(settings, _focus()) and steps < 12:
		await _key(KEY_DOWN)
		steps += 1
	_check("↓ chega na linha de qualidade (em %d passos)" % steps, _is_quality_button(settings, _focus()))
	steps = 0
	while _focus() != settings._quality_buttons[target] and steps < 4:
		await _key(KEY_RIGHT if _focus() == settings._quality_buttons["leve"] or target == "alta" else KEY_LEFT)
		steps += 1
	_check("←/→ chegam no botão '%s'" % target, _focus() == settings._quality_buttons[target])
	await _key(KEY_ENTER)
	_check("Enter escolhe a qualidade", app.get_quality() == target)
	app.set_quality(quality_before)

	print("== Tab e fechar ==")
	var search = player.get_game_search()
	await _key(KEY_TAB)
	_check("Tab não abre a busca com o menu aberto", not search.is_open())
	await _key(KEY_ESCAPE)
	_check("Esc fecha o menu", not menu.is_open())
	_check("e ninguém fica com o foco", _focus() == null)

	print("== Rodapé ==")
	menu.open()
	await process_frame
	var footer: Array = settings._footer_controls
	steps = 0
	while _focus() != footer[0] and steps < 30:
		await _key(KEY_DOWN)
		steps += 1
	_check("↓ da última linha chega em 'Continuar' (em %d passos)" % steps, _focus() == footer[0])
	await _key(KEY_DOWN)
	_check("↓ do rodapé dá a volta até a aba", _focus() == settings._tab_buttons[0])
	await _key(KEY_UP)
	_check("↑ da aba vai para o rodapé", _focus() == footer[0])
	await _key(KEY_ENTER)
	_check("Enter em 'Continuar' fecha o menu", not menu.is_open())

	print("== B (ui_cancel) fecha os painéis ==")
	menu.open()
	await process_frame
	await _action("ui_cancel")
	_check("B fecha o menu de pausa", not menu.is_open())
	search.open()
	await _action("ui_cancel")
	_check("B fecha a busca", not search.is_open())
	player.get_world_map().open()
	await _action("ui_cancel")
	_check("B fecha o mapa", not player.get_world_map().is_open())
	_check("sem painel aberto, B não abre o menu", not menu.is_open())

	print("== Computador da casa ==")
	var home = city.get_home()
	var desk = home.get_node("ComputerDesk")
	var screen = desk.get_screen()
	var desk_settings = desk.get_settings()
	player.teleport_to(home.get_spawn_transform())
	player.set_indoors(home.get_environment())
	await _frames(3)
	player.focus_on(screen)
	await create_timer(1.0).timeout
	_check("o jogador está focado na tela", player.is_focused())
	var viewport: Viewport = screen._viewport
	_check("o foco do teclado começa na aba, dentro da tela", viewport.gui_get_focus_owner() == desk_settings._tab_buttons[0])
	var show_map_before: bool = app.get_show_map()
	steps = 0
	while viewport.gui_get_focus_owner() != desk_settings._map_check and steps < 12:
		await _key(KEY_DOWN)
		steps += 1
	_check("↓ chega no 'Bússola e mapa' (em %d passos)" % steps, viewport.gui_get_focus_owner() == desk_settings._map_check)
	await _key(KEY_ENTER)
	_check("Enter troca a opção", app.get_show_map() == (not show_map_before))
	await _key(KEY_ENTER)
	app.set_show_map(show_map_before)
	_check("o menu de pausa não abriu por baixo", not menu.is_open())
	await _key(KEY_ESCAPE)
	await create_timer(1.0).timeout
	_check("Esc sem campo de texto devolve a câmera de uma vez", not player.is_focused())
	_check("e o foco da tela foi solto", viewport.gui_get_focus_owner() == null)

	# Devolve o config.cfg como estava.
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## A tecla apertada e solta, entregue pela janela (como o teclado de verdade).
func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event)
	await _frames(2)


## O toque de uma ação (como o botão B do controle): um evento de ação entregue
## à janela, igual ao que um InputEventJoypadButton vira.
func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)
	await _frames(2)


## Aperta "keycode" até o foco chegar em "target" (no máximo 10 vezes).
func _go_to(_settings, target: Control, keycode: Key) -> void:
	var steps := 0
	while _focus() != target and steps < 10:
		await _key(keycode)
		steps += 1


## O botão está entre os de qualidade? (Sem usar "has" na lista tipada: o foco pode ser um deslizador.)
func _is_quality_button(settings, control: Control) -> bool:
	for button in settings._quality_buttons.values():
		if button == control:
			return true
	return false


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
