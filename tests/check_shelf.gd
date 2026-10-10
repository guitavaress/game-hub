extends SceneTree
## Teste da estante da biblioteca (Fase 9.4), com 200 jogos FALSOS e Steam falsa:
##   - caixas por página, páginas e filtro por bairro;
##   - o cartão da caixa é igual ao do portal do mesmo jogo;
##   - segurar E chama launch com a origem = estante;
##   - no session_ended o jogador continua em casa, na frente da estante, e a tela clareia.

const COUNT := 200

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library_script: GDScript = load("res://tests/fake_library.gd")
	var games: Array[SteamGame] = library_script.install(root, COUNT)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	var launcher = root.get_node("GameLauncher")
	launcher._poll_timer.paused = true
	var opened: Array = []
	launcher.state_reader = func(_id: int, _check: bool) -> Dictionary:
		return {"running_app_id": 0, "steam_running": true, "app_running": false, "app_updating": false}
	launcher.url_opener = func(url: String) -> int:
		opened.append(url)
		return OK
	var fade = root.get_node("ScreenFade")
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var home = city.get_home()
	var shelf = home.get_node("LibraryShelf")

	print("== Páginas ==")
	_check("a casa tem a estante", shelf != null and shelf.is_in_group("library_shelf"))
	_check("%d jogos na estante" % COUNT, shelf.get_total() == COUNT)
	_check("%d caixas na primeira página" % shelf.PER_PAGE, shelf.get_visible_app_ids().size() == shelf.PER_PAGE)
	_check("o número de páginas bate", shelf.get_page_count() == ceili(COUNT / float(shelf.PER_PAGE)))
	var first_page = shelf.get_visible_app_ids()
	shelf.next_page()
	var second_page = shelf.get_visible_app_ids()
	_check("a página 2 tem outros jogos", shelf.get_page() == 1 and second_page.size() == shelf.PER_PAGE
			and second_page[0] != first_page[0])
	for i in shelf.get_page_count() - 2:
		shelf.next_page()
	var last_expected = COUNT - (shelf.get_page_count() - 1) * shelf.PER_PAGE
	_check("a última página tem o que sobrou (%d)" % last_expected, shelf.get_visible_app_ids().size() == last_expected)
	shelf.next_page()
	_check("passar da última volta à primeira", shelf.get_page() == 0)
	shelf.previous_page()
	_check("e voltar da primeira vai à última", shelf.get_page() == shelf.get_page_count() - 1)
	shelf.next_page()
	var sorted_ok := true
	var last_played := 1 << 60
	for app_id in first_page:
		var played: int = root.get_node("SteamLibrary").get_last_played(app_id)
		if played > last_played:
			sorted_ok = false
		last_played = played
	_check("em ordem de jogado por último", sorted_ok)

	print("== Filtro ==")
	var options = shelf.get_filter_options()
	_check("o filtro tem Todos + os 10 bairros", options.size() == 11 and options[0] == "")
	var counts: Dictionary = library_script.count_by_district(root)
	var category: String = "cartas"
	shelf.set_filter(category)
	_check("filtrar mostra só o bairro (%d jogos)" % int(counts[category]), shelf.get_total() == int(counts[category]))
	var all_in_district := true
	for app_id in shelf.get_visible_app_ids():
		if root.get_node("GameCategories").get_category_id(app_id) != category:
			all_in_district = false
	_check("todas as caixas são do bairro", all_in_district and shelf.get_page() == 0)
	for i in options.size() - options.find(category):
		shelf.next_filter()
	_check("o filtro dá a volta até Todos", shelf.get_filter() == "" and shelf.get_total() == COUNT)

	print("== O cartão ==")
	var app_id: int = shelf.get_visible_app_ids()[0]
	var portal = city.get_node("Building_%d/GamePortal" % app_id)
	var box = shelf.get_box(app_id)
	var box_info: Dictionary = box.get_look_info()
	var portal_info: Dictionary = portal.get_look_info()
	var same := true
	for key in portal_info:
		if box_info.get(key) != portal_info[key]:
			same = false
	_check("o cartão da caixa é igual ao do portal", same)
	_check("a caixa pede para segurar E", box_info.get("action", "") == "Segure E para jogar")

	print("== Olhando a caixa ==")
	player.teleport_to(shelf.get_return_transform())
	player.set_indoors(home.get_environment())
	_aim_at(player, shelf, box)
	await _frames(4)
	_check("o HUD mostra o cartão da caixa", hud.get_look_text().begins_with(portal.get_game_name()))
	_check("e a dica de segurar E", hud.get_look_action() == "Segure E para jogar")

	print("== Segurar E ==")
	Input.action_press("interact")
	await create_timer(0.6).timeout
	_check("no meio da segurada a tela escurece (vinheta)", fade.door_charge.get_progress() > 0.2)
	_check("e nada foi aberto ainda", opened.is_empty())
	await create_timer(0.9).timeout
	Input.action_release("interact")
	_check("ao encher pediu o jogo à Steam", opened.size() == 1 and str(opened[0]).ends_with(str(app_id)))
	_check("a origem é a estante", launcher._source == shelf)
	_check("a cortina está preta", fade.get_amount() > 0.99)

	print("== O jogo fecha ==")
	player.teleport_to(Transform3D(Basis.IDENTITY, home.to_global(Vector3(3.0, 0.1, 3.0))))
	launcher.cancel_launch()
	await create_timer(1.3).timeout
	_check("o jogador continua em casa", player.is_indoors())
	_check("na frente da estante", player.global_position.distance_to(shelf.get_return_transform().origin) < 0.5)
	_check("a tela clareou", fade.get_amount() < 0.05)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Põe o jogador a 1,5 m da caixa, olhando para ela.
func _aim_at(player: Node3D, shelf: Node3D, box: Node3D) -> void:
	var front: Vector3 = shelf.global_basis.z
	player.global_position = Vector3(box.global_position.x, 0.1, box.global_position.z) + front * 1.5
	player.rotation = Vector3(0.0, atan2(front.x, front.z), 0.0)
	var head: Node3D = player.get_node("Head")
	head.rotation.x = atan2(box.global_position.y - head.global_position.y, 1.5)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
