extends SceneTree
## Teste dos pórticos e placas de rua (P2.17).

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

	var districts := {}
	var blocks := 0
	var gates: Array = []
	var signs: Array = []
	var district_signs: Array = []
	for child in city.get_children():
		if child.name.begins_with("Building_"):
			districts[cats.get_category_id(child.game.app_id)] = true
		elif child.name.begins_with("DistrictGate_"):
			gates.append(child)
		elif child.get_script() != null and child.get_script().get_global_name() == "StreetSign":
			signs.append(child)
		elif child.name.begins_with("DistrictSign_"):
			district_signs.append(child)
	for cells: Array in city._district_cells.values():
		blocks += cells.size()
	print("bairros: %d | quarteirões: %d | pórticos: %d | placas: %d | letreiros: %d" % [
			districts.size(), blocks, gates.size(), signs.size(), district_signs.size()])
	_check("um pórtico por bairro", gates.size() == districts.size())
	_check("uma placa de rua por quarteirão", signs.size() == blocks)

	# Fase 10.6: um letreiro por bairro, em cima do meio do 1º quarteirão,
	# com a placa inteira acima do prédio mais alto possível.
	_check("um letreiro por bairro", district_signs.size() == districts.size())
	var variant_class: GDScript = load("res://worlds/city/building_variant.gd")
	var sign_class: GDScript = load("res://worlds/city/district_sign.gd")
	var layout: GDScript = load("res://worlds/city/city_layout.gd")
	var plate_half: float = sign_class.PLATE_HEIGHT * city.DISTRICT_SIGN_TEXT_HEIGHT / sign_class.TEXT_HEIGHT / 2.0
	var tallest: float = variant_class.max_total_height()
	var above := true
	var on_first_block := true
	for district_sign in district_signs:
		var id: String = district_sign.name.trim_prefix("DistrictSign_")
		if district_sign.position.y - plate_half <= tallest:
			above = false
		var first_cell: Vector2i = city._district_cells[id][0]
		var center: Vector3 = layout.block_center(first_cell)
		if Vector2(district_sign.position.x, district_sign.position.z).distance_to(Vector2(center.x, center.z)) > 0.01:
			on_first_block = false
	_check("letreiro acima do prédio mais alto possível (%.1f m)" % tallest, above)
	_check("letreiro em cima do meio do 1º quarteirão do bairro", on_first_block)
	# Nenhum enfeite alto (a grua da Simulação) atravessa o letreiro.
	var over_props := true
	for props in city.get_children():
		if props.name.begins_with("DistrictProps_") and props.has_method("get_top_y"):
			var id: String = props.name.split("_")[1]
			var district_sign = city.get_node_or_null("DistrictSign_" + id)
			if district_sign != null and district_sign.position.y - plate_half <= props.get_top_y():
				over_props = false
	_check("letreiro acima dos enfeites altos do bairro", over_props)

	var names_ok := true
	for gate in gates:
		var id: String = gate.name.trim_prefix("DistrictGate_")
		if gate.get_text() != cats.get_category_name(id).to_upper():
			names_ok = false
	_check("nome certo em cada pórtico", names_ok)

	# Os pórticos ficam em cima de uma rua (z no meio de uma rua da grade).
	var on_street := true
	for gate in gates:
		var k: float = gate.position.z / 38.0 - 0.5
		if absf(k - roundf(k)) > 0.001:
			on_street = false
	_check("pórticos sobre o meio de uma rua", on_street)

	# Nada fora do mapa.
	var half: float = 0.0
	for child in city.get_children():
		if child.name.begins_with("Building_"):
			half = maxf(half, maxf(absf(child.position.x), absf(child.position.z)))
	var inside := true
	for node in gates + signs:
		if maxf(absf(node.position.x), absf(node.position.z)) > half + 30.0:
			inside = false
	_check("tudo dentro da cidade", inside)

	# Acendem à noite.
	city._on_night_changed(1.0)
	var gate0 = gates[0]
	_check("néon do pórtico forte à noite", gate0._strip_material.emission_energy_multiplier > 3.0)
	city._on_night_changed(0.0)
	_check("e quase apagado de dia", gate0._strip_material.emission_energy_multiplier < 0.2)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
