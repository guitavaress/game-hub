extends SceneTree
## Teste da busca com Tab e da faixa de luz até a porta (P2.18).

const BALATRO := 2379780
const PITCH := 38.0  # CityLayout.BLOCK_PITCH

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout  # a tela termina de clarear
	var player = city.get_node("Player")
	var search = player.get_game_search()
	var menu = player.get_pause_menu()
	var guide = city.get_node("RouteGuide")

	print("\n== Tab abre, Tab e Esc fecham ==")
	await _press("search_game")
	_check("abriu e pausou", search.is_open() and paused)
	print("   sem texto (mais perto primeiro): ", search.get_result_names().slice(0, 4))
	await _press("search_game")
	_check("Tab fechou", not search.is_open() and not paused)
	await _press("search_game")
	await _press("release_mouse")
	_check("Esc fechou a busca sem abrir o menu", not search.is_open() and not menu.is_open() and not paused)

	print("\n== filtro ==")
	search.open()
	search.set_query("bal")
	_check("'bal' -> Balatro primeiro", search.get_result_names().size() > 0 and search.get_result_names()[0] == "Balatro")
	search.set_query("BALATRO")
	_check("sem ligar para maiúsculas", search.get_result_names().size() == 1)
	_check("sem ligar para acentos", search._fold("Pokémon Açaí") == "pokemon acai")
	search.set_query("zzzz")
	_check("nada encontrado -> aviso", search.get_result_names().is_empty() and search._empty.visible)

	print("\n== escolher acende a faixa pelas ruas ==")
	search.set_query("balatro")
	search.choose_selected()
	await process_frame
	_check("fechou e acendeu a faixa", not search.is_open() and guide.has_route())
	var portal = city.get_node("Building_%d/GamePortal" % BALATRO)
	var points: PackedVector3Array = guide.route_points(player.global_position, portal)
	print("   rota: ", points)
	var straight := true
	for i in range(1, points.size() - 2):
		var a := points[i]
		var b := points[i + 1]
		if absf(a.x - b.x) > 0.01 and absf(a.z - b.z) > 0.01:
			straight = false
	_check("trechos pelas ruas só em linha reta (norte-sul ou leste-oeste)", straight)
	var on_streets := true
	for i in range(1, points.size() - 1):
		var p := points[i]
		if not (_on_street(p.x) or _on_street(p.z)):
			on_streets = false
	_check("pontos do meio no meio de uma rua", on_streets)
	var length: float = 0.0
	for i in points.size() - 1:
		length += points[i].distance_to(points[i + 1])
	print("   %.0f m, %d manchas" % [length, guide.get_mark_count()])
	_check("uma mancha a cada 2 m", absi(guide.get_mark_count() - roundi(length / 2.0)) <= 1)
	var mark: Decal = guide.get_child(0)
	var neon: Color = root.get_node("GameCategories").get_neon_color("cartas")
	_check("na cor do bairro", Color(mark.modulate, 1.0).is_equal_approx(neon))

	print("\n== some ao chegar ==")
	player.global_position = portal.global_position + portal.global_transform.basis.z * 1.0
	for i in 30:
		await process_frame
	_check("faixa apagou", not guide.has_route())

	print("\n== some depois de 60 s ==")
	guide.show_route(player, city.get_node("Building_413150/GamePortal"))
	guide._started_ms -= 61000
	for i in 5:
		await process_frame
	_check("faixa apagou", not guide.has_route())

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _on_street(value: float) -> bool:
	var k := value / PITCH - 0.5
	return absf(k - roundf(k)) < 0.001


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
