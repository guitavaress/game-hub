extends SceneTree
## Teste do título ao entrar num bairro (Fase 11.11).

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(0.5).timeout
	var player = city.get_node("Player")
	var title = player.get_hud().get_district_title()
	var map = get_first_node_in_group("world_map")
	var areas: Array = map.get_map_data()["areas"]
	_check("há bairros e o título existe", not areas.is_empty() and title != null)
	var area: Dictionary = areas[0]
	var rect: Rect2 = area["rects"][0]
	var inside := Vector3(rect.get_center().x, 0.5, rect.get_center().y)

	print("== praça: nada ==")
	player.global_position = Vector3(0.0, 0.5, 0.0)
	title.poll()
	_check("na praça não mostra", not title.is_showing())

	print("== entrando no bairro %s ==" % area["name"])
	player.global_position = inside
	title.poll()
	var games: int = map.area_games(area["id"])
	_check("mostra o título com o nome", title.is_showing() and title.get_title() == str(area["name"]).to_upper())
	_check("e a contagem de jogos (%d)" % games, title.get_subtitle() == "%d %s" % [games, "jogo" if games == 1 else "jogos"])
	_check("area_games bate com o mapa", games == int(area["games"]))
	await create_timer(0.6).timeout
	_check("aparece com fade e continua na tela", title._column.modulate.a > 0.9 and title.is_showing())

	print("== sair e voltar logo: não repete ==")
	player.global_position = Vector3(0.0, 0.5, 0.0)
	title.poll()
	title._tween.kill()
	title._showing = false
	player.global_position = inside
	title.poll()
	_check("voltar ao mesmo bairro antes de 20 s não mostra", not title.is_showing())

	print("== depois do tempo, mostra de novo ==")
	player.global_position = Vector3(0.0, 0.5, 0.0)
	title.poll()
	title._last_shown_ms[area["id"]] -= int(title.REPEAT_SECONDS * 1000.0) + 10
	player.global_position = inside
	title.poll()
	_check("passados 20 s, mostra", title.is_showing())

	print("== termina sozinho ==")
	await create_timer(title.FADE_IN_SECONDS + title.HOLD_SECONDS + title.FADE_OUT_SECONDS + 0.4).timeout
	_check("o título some depois de ~2,5 s", not title.is_showing() and not title._column.visible)

	print("== faixa própria: abaixo do espaço de 2 avisos (16.2) ==")
	var hud = player.get_hud()
	title._tween.kill()
	title._hide()
	hud.clear_messages()
	for i in 2:
		hud.show_message("Aviso %d" % i, "Uma frase de uma linha só")
	await process_frame
	title.show_title("Teste", 3, Color.WHITE)
	await create_timer(title.FADE_IN_SECONDS + 0.2).timeout
	var toasts_rect: Rect2 = hud._toasts.get_global_rect()
	var title_rect: Rect2 = title._column.get_global_rect()
	var screen_h: float = title.get_viewport_rect().size.y
	print("   pilha: %s | título: %s | faixa: %.0f | tela: %.0f" % [toasts_rect, title_rect, title.get_band_top(), screen_h])
	_check("a faixa vem da conta do HUD", is_equal_approx(title.get_band_top(), hud.get_title_band_top()))
	_check("com 2 avisos, título e avisos não se cruzam", title.is_showing()
			and not toasts_rect.intersects(title_rect))
	_check("o título fica longe da mira (acima de 85% da meia tela)", title_rect.end.y < screen_h / 2.0 * 0.85)

	print("== um 3º aviso chega: o título cede ==")
	hud.show_message("Aviso 3", "Uma frase de uma linha só")
	await create_timer(title.YIELD_SECONDS + 0.2).timeout
	_check("o título que estava na tela saiu", not title.is_showing() and not title._column.visible)
	title.show_title("Teste", 3, Color.WHITE)
	_check("com 3 avisos, um título novo não aparece", not title.is_showing())

	print("== 2 avisos longos também passam da faixa ==")
	hud.clear_messages()
	for i in 2:
		hud.show_message("Aviso longo %d" % i,
				"Uma frase bem comprida que quebra em duas linhas no aviso, para passar da altura comum")
	await process_frame
	await process_frame
	title.show_title("Teste", 3, Color.WHITE)
	_check("o título não aparece", not title.is_showing())
	hud.clear_messages()
	await process_frame

	print("== carga da porta: o título cede ==")
	var fade = root.get_node("ScreenFade")
	fade.set_door_charge(0.5, "Jogo", Color.WHITE)
	title.show_title("Teste", 3, Color.WHITE)
	_check("com a carga na tela, não aparece", not title.is_showing())
	fade.set_door_charge(0.0)
	title.show_title("Teste", 3, Color.WHITE)
	_check("sem a carga, aparece", title.is_showing())
	fade.set_door_charge(0.5, "Jogo", Color.WHITE)
	await create_timer(title.YIELD_SECONDS + 0.2).timeout
	_check("a carga começa com o título na tela: ele some rápido", not title.is_showing() and not title._column.visible)
	fade.set_door_charge(0.0)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
