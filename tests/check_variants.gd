extends SceneTree
## Teste da variação dos prédios (P2.16).

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

	var buildings: Array = []
	for child in city.get_children():
		if child.name.begins_with("Building_"):
			buildings.append(child)
	var floors := {}
	var styles := {}
	var setbacks := 0
	var parapets := 0
	var canopies := 0
	var roofs := 0
	var heights_ok := true
	var same_again := true
	for b in buildings:
		var v = b.variant
		floors[v.floors] = true
		styles[v.window_style] = true
		setbacks += int(v.setback)
		parapets += int(v.parapet)
		canopies += int(v.canopy)
		roofs += int(not v.roof_items.is_empty())
		if not is_equal_approx(b.size.y, v.body_height()) or v.floors < 3 or v.floors > 7:
			heights_ok = false
		# Mesmo App ID -> mesmo prédio.
		var again = v.get_script().from_app_id(b.game.app_id)
		if again.floors != v.floors or again.setback != v.setback or again.window_style != v.window_style \
				or again.roof_items != v.roof_items:
			same_again = false
	print("%d prédios | andares %s | estilos de janela %s | recuo %d, platibanda %d, marquise %d, telhado %d" % [
		buildings.size(), floors.keys(), styles.keys(), setbacks, parapets, canopies, roofs])
	_check("andares de 3 a 7 e altura certa", heights_ok)
	_check("mesmo jogo, mesmo prédio", same_again)
	_check("prédios variados (3+ alturas e 2+ estilos de janela)", floors.size() >= 3 and styles.size() >= 2)
	_check("aparece cada peça em algum prédio", setbacks > 0 and parapets > 0 and canopies > 0 and roofs > 0)

	# O recuo acende as janelas junto com o corpo.
	var with_setback = null
	for b in buildings:
		if b.variant.setback:
			with_setback = b
			break
	if with_setback != null:
		city._on_night_changed(1.0)
		var top: ShaderMaterial = with_setback.variant.top_walls_material
		_check("janelas do recuo acendem à noite", top != null and top.get_shader_parameter("windows_on") > 0.99)
		city._on_night_changed(0.0)
		_check("e apagam de dia", top.get_shader_parameter("windows_on") < 0.01)

	# Letreiros dos bairros não ficam dentro de prédios.
	var inside := false
	for child in city.get_children():
		if child.name.begins_with("DistrictSign_"):
			for b in buildings:
				var local: Vector3 = b.to_local(child.global_position)
				if absf(local.x) < b.size.x / 2.0 and absf(local.z) < b.size.z / 2.0 \
						and local.y < b.variant.total_height() + 1.0:
					inside = true
	_check("nenhum letreiro dentro de prédio", not inside)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
