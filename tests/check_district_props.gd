extends SceneTree
## Teste da identidade dos bairros (P2.20).

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame
	var cats = root.get_node("GameCategories")

	var count := {}
	for child in city.get_children():
		if child.name.begins_with("Building_"):
			var id: String = cats.get_category_id(child.game.app_id)
			count[id] = count.get(id, 0) + 1

	print("\n== Ação: telões nas quinas ==")
	var screens := 0
	var action_props: Array = []
	for child in city.get_children():
		if child.name.begins_with("DistrictProps_acao"):
			action_props.append(child)
			screens += child.get_screen_count()
	_check("um telão por prédio do bairro (%d)" % count.get("acao", 0), screens == count.get("acao", 0))
	if not action_props.is_empty():
		var props = action_props[0]
		var material: ShaderMaterial = props._screens[0]
		var before = material.get_shader_parameter("current_art")
		_check("telão com imagem", material.get_shader_parameter("has_art") and before != null)
		props._next()
		await create_timer(0.8).timeout
		var after = material.get_shader_parameter("current_art")
		_check("troca de jogo", props._arts.size() < 2 or after != before)

	print("\n== Cartas: lâmpadas em volta do painel ==")
	var marquee = null
	for child in city.get_children():
		if child.name.begins_with("DistrictProps_cartas"):
			marquee = child
	_check("moldura de lâmpadas em cada prédio", marquee != null and marquee.buildings.size() == count.get("cartas", 0)
		and marquee.buildings.all(func(b) -> bool: return marquee.get_bulb_count(b) > 20))
	if marquee != null:
		var b = marquee.buildings[0]
		print("   lâmpadas no primeiro prédio: %d" % marquee.get_bulb_count(b))
		var before: int = marquee.get_bulb_count(b)
		b.poster_changed.emit()  # o painel "mudou": a moldura é refeita
		await process_frame
		_check("moldura refeita quando o painel muda", marquee.get_bulb_count(b) == before
			and b.get_children().filter(func(c) -> bool: return c.name.begins_with("Marquee")).size() >= 1)

	print("\n== Terror: néon falhando, névoa e poste apagado ==")
	var terror = null
	for child in city.get_children():
		if child.name.begins_with("DistrictProps_sobrevivencia"):
			terror = child
	_check("bairro Terror decorado", terror != null)
	if terror != null:
		var flicker_ok := true
		for b in terror.buildings:
			if b._walls_material.get_shader_parameter("neon_flicker") != 1.0:
				flicker_ok = false
		_check("néon de todos os prédios falhando", flicker_ok)
		_check("névoa (FogVolume)", terror.has_node("GroundMist") and terror.get_node("GroundMist") is FogVolume)
		var broken = terror.get_broken_light()
		city._on_night_changed(1.0)
		_check("um poste apagado à noite", broken != null and not broken._light.visible)
		var others_on := true
		for node in city.get_children():
			if node is StreetLight and node != broken and not node._light.visible:
				others_on = false
		_check("os outros postes acesos", others_on)
		city._on_night_changed(0.0)
		var env: Environment = city._environment
		var app = root.get_node("AppConfig")
		_check("névoa volumétrica ligada na qualidade atual (%s)" % app.get_quality(),
			env.volumetric_fog_enabled == (app.get_quality() != "leve"))

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
