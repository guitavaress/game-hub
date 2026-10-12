extends SceneTree
## Teste da bússola (Fase 8.4):
##   - o rumo acompanha para onde o jogador olha (N = -Z, L = +X);
##   - o marcador do destino só aparece com a faixa de luz acesa, no ângulo
##     e com a distância certos;
##   - a opção "Bússola e mapa" liga e desliga;
##   - os avisos ficam abaixo da bússola.

const BALATRO := 2379780

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var config := root.get_node("AppConfig")
	var original_show: bool = config.get_show_map()
	config.set_show_map(true)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var compass = hud.get_compass()
	var guide = city.get_node("RouteGuide")
	var portal = city.get_node("Building_%d/GamePortal" % BALATRO)

	print("== rumo ==")
	_check("a bússola existe e aparece", compass != null and compass.visible)
	for pair in [[0.0, 0.0], [-PI / 2.0, 90.0], [PI, 180.0], [PI / 2.0, 270.0]]:
		player.rotation.y = pair[0]
		await process_frame
		await process_frame
		_check("olhando para %.0f°: bússola em %.0f°" % [pair[1], compass.get_heading()], absf(compass.get_heading() - pair[1]) < 0.5 or absf(absf(compass.get_heading() - pair[1]) - 360.0) < 0.5)
	player.rotation.y = 0.0
	await process_frame
	await process_frame
	_check("o norte aparece no meio da faixa", absf(compass.x_for_bearing(0.0) - compass.size.x / 2.0) < 1.0)
	_check("o sul fica fora da faixa", compass.x_for_bearing(180.0) < 0.0)

	print("== destino ==")
	_check("sem faixa de luz: sem marcador", not compass.get_target_info()["visible"])
	guide.show_route(player, portal)
	await process_frame
	await process_frame
	var info: Dictionary = compass.get_target_info()
	var delta: Vector3 = portal.global_position - player.global_position
	var expected_bearing: float = Compass.bearing_of(Vector3(delta.x, 0.0, delta.z))
	_check("com a faixa acesa: marcador visível", info["visible"])
	_check("rumo do destino %.0f° (esperado %.0f°)" % [info.get("bearing", -1.0), expected_bearing], absf(float(info.get("bearing", -1.0)) - expected_bearing) < 0.5)
	_check("distância %.0f m (esperado %.0f)" % [info.get("distance", -1.0), Vector2(delta.x, delta.z).length()], absf(float(info.get("distance", -1.0)) - Vector2(delta.x, delta.z).length()) < 0.5)
	_check("a cor é a do bairro", info.get("color", Color.BLACK) == guide.get_target_color())
	# Olhando direto para a porta, o marcador fica no meio.
	player.rotation.y = deg_to_rad(-expected_bearing)
	await process_frame
	await process_frame
	_check("olhando para a porta: marcador no meio (%.1f°)" % compass.get_target_info()["offset"], absf(float(compass.get_target_info()["offset"])) < 1.0)
	guide.clear_route()
	await process_frame
	await process_frame
	_check("faixa apagada: marcador some", not compass.get_target_info()["visible"])

	print("== opção e avisos ==")
	var toasts: Control = hud._toasts
	_check("avisos abaixo da bússola", toasts.offset_top >= Compass.TOP + Compass.SIZE_PX.y)
	config.set_show_map(false)
	_check("opção desligada: bússola escondida", not compass.visible)
	_check("os avisos voltam ao topo", toasts.offset_top < Compass.TOP + Compass.SIZE_PX.y)
	config.set_show_map(true)
	_check("ligada de novo: bússola volta", compass.visible and toasts.offset_top >= Compass.TOP + Compass.SIZE_PX.y)
	config.set_show_map(original_show)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
