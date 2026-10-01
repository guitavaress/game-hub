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
	for child in city.get_children():
		if child.name.begins_with("Building_"):
			districts[cats.get_category_id(child.game.app_id)] = true
		elif child.name.begins_with("DistrictGate_"):
			gates.append(child)
		elif child.get_script() != null and child.get_script().get_global_name() == "StreetSign":
			signs.append(child)
		elif child.name.begins_with("DistrictSign_"):
			blocks += 1
	print("bairros: %d | quarteirões: %d | pórticos: %d | placas: %d" % [districts.size(), blocks, gates.size(), signs.size()])
	_check("um pórtico por bairro", gates.size() == districts.size())
	_check("uma placa por quarteirão", signs.size() == blocks)

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
