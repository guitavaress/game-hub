extends SceneTree
## Teste da estante de apps da casa (Fase 14.7), com 40 apps FALSOS e um abridor falso:
##   - caixas por página, páginas e filtro por categoria;
##   - o cartão da caixa ("Nome" + categoria) e a dica de segurar E;
##   - segurar E chama o AppLauncher com a origem = estante;
##   - no fim da sessão o jogador continua em casa, na frente da estante, e a tela clareia.

const COUNT := 40

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library_script: GDScript = load("res://tests/fake_library.gd")
	library_script.install(root, 20)
	var library: Node = root.get_node("AppLibrary")
	var config: Node = root.get_node("AppConfig")
	var config_backup := FileAccess.get_file_as_string(config.CONFIG_PATH)

	# 40 apps inventados: 25 de Internet, 10 de Sistema, 5 sem categoria.
	var apps: Array[DesktopApp] = []
	for i in COUNT:
		var app := DesktopApp.new()
		app.id = "app%02d" % i
		app.name = "App %02d" % i
		app.comment = "Um app de teste" if i == 0 else ""
		if i == 0:
			app.icon_name = ProjectSettings.globalize_path("res://tests/fixtures/icons/hicolor/48x48/apps/pequeno.png")
		app.categories = PackedStringArray(["Network"] if i < 25 else (["System"] if i < 35 else []))
		apps.append(app)
	library.set_apps(apps)

	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout

	var launcher = root.get_node("AppLauncher")
	var opened: Array[String] = []
	launcher.threaded = false
	launcher.opener = func(app: DesktopApp) -> bool:
		opened.append(app.id)
		return true
	launcher.can_track = func() -> bool: return false
	var fade = root.get_node("ScreenFade")
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var home = city.get_home()
	var shelf = home.get_node("AppShelf")

	print("== A casa ==")
	_check("a casa tem a estante de apps", shelf != null and shelf.is_in_group("app_shelf"))
	_check("o móvel entrou em 'apps' e está na âncora norte_esquerda",
			home.get_furniture("apps") == shelf
			and shelf.position.is_equal_approx(home.get_anchor_transform("norte_esquerda").origin))

	print("== Páginas ==")
	_check("%d apps na estante" % COUNT, shelf.get_total() == COUNT)
	_check("%d caixas na primeira página" % shelf.PER_PAGE, shelf.get_visible_app_ids().size() == shelf.PER_PAGE)
	_check("o número de páginas bate", shelf.get_page_count() == ceili(COUNT / float(shelf.PER_PAGE)))
	var first_page: Array[String] = shelf.get_visible_app_ids()
	shelf.next_page()
	var second_page: Array[String] = shelf.get_visible_app_ids()
	_check("a página 2 tem outros apps", shelf.get_page() == 1 and second_page[0] != first_page[0])
	shelf.next_page()
	_check("a última página tem o que sobrou (%d)" % (COUNT - 2 * shelf.PER_PAGE),
			shelf.get_visible_app_ids().size() == COUNT - 2 * shelf.PER_PAGE)
	shelf.next_page()
	_check("passar da última volta à primeira", shelf.get_page() == 0)
	shelf.previous_page()
	_check("e voltar da primeira vai à última", shelf.get_page() == shelf.get_page_count() - 1)
	shelf.next_page()
	_check("a ordem é a da AppLibrary (por nome)", first_page[0] == "app00" and first_page[1] == "app01")

	print("== Filtro ==")
	var options: Array[String] = shelf.get_filter_options()
	_check("o filtro tem Todos + as 3 categorias que existem", options == ["", "internet", "sistema", "diversos"])
	shelf.set_filter("sistema")
	_check("filtrar mostra só a categoria (10 apps)", shelf.get_total() == 10 and shelf.get_page() == 0)
	var all_system := true
	for id in shelf.get_visible_app_ids():
		all_system = all_system and library.category_of(library.get_app(id)) == "sistema"
	_check("todas as caixas são de Sistema", all_system)
	for i in options.size() - options.find("sistema"):
		shelf.next_filter()
	_check("o filtro dá a volta até Todos", shelf.get_filter() == "" and shelf.get_total() == COUNT)

	print("== O cartão ==")
	var box = shelf.get_box("app00")
	var info: Dictionary = box.get_look_info()
	_check("título = nome do app", info.get("title") == "App 00")
	_check("categoria no alto, em maiúsculas", info.get("label") == "INTERNET")
	_check("o detalhe é o comentário do app", info.get("detail") == "Um app de teste")
	_check("a ação pede para segurar E", info.get("action") == "Segure {interact} para abrir")
	var plain_box = shelf.get_box("app01")
	_check("a caixa sem ícone mostra a inicial", plain_box._letter.visible and not plain_box._icon.visible and plain_box._letter.text == "A")

	print("== O ícone entra quando chega ==")
	for i in 120:
		if library.has_icon_result("app00"):
			break
		await process_frame
		OS.delay_msec(10)
	await process_frame
	_check("com o ícone pronto, a caixa o mostra no lugar da inicial", box._icon.visible and not box._letter.visible)

	print("== Olhando a caixa ==")
	player.teleport_to(shelf.get_return_transform())
	player.set_indoors(home.get_environment())
	_aim_at(player, shelf, box)
	await _frames(4)
	_check("o HUD mostra o cartão da caixa", hud.get_look_text().begins_with("App 00"))
	_check("e a dica de segurar E", hud.get_look_action() == "Segure E para abrir")

	print("== Segurar E ==")
	Input.action_press("interact")
	await create_timer(0.6).timeout
	_check("no meio da segurada a tela escurece (vinheta)", fade.door_charge.get_progress() > 0.2)
	_check("e nada foi aberto ainda", opened.is_empty())
	await create_timer(0.9).timeout
	Input.action_release("interact")
	_check("ao encher pediu o app", opened == ["app00"])
	_check("a origem é a estante", launcher._source == shelf)
	_check("a cortina está preta", fade.get_amount() > 0.99)
	_check("o app aberto sobe na estante", library.apps[0].id == "app00")

	print("== O app fecha ==")
	player.teleport_to(Transform3D(Basis.IDENTITY, home.to_global(Vector3(3.0, 0.1, 3.0))))
	launcher.cancel_launch()
	await create_timer(1.3).timeout
	_check("o jogador continua em casa", player.is_indoors())
	_check("na frente da estante", player.global_position.distance_to(shelf.get_return_transform().origin) < 0.5)
	_check("a tela clareou", fade.get_amount() < 0.05)
	_check("a estante pode abrir outro app (não ficou esperando)", not shelf._waiting_for_app)

	var file := FileAccess.open(config.CONFIG_PATH, FileAccess.WRITE)
	file.store_string(config_backup)
	file.close()
	config._config.load(config.CONFIG_PATH)

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
