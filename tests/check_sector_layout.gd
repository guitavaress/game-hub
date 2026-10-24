extends SceneTree
## Teste da 15.3: a planta em setores (SectorLayout), só contas, sem a cidade.
## Confere casos fixos, os 200 jogos falsos (com e sem foco) e listas
## sorteadas, e imprime o mapa ASCII da planta dos 200 falsos.

const FIXTURE := "res://tests/fixtures/planta_atual.json"
const RANDOM_LISTS := 300
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("-- casos fixos")
	var fixed: Dictionary = {
		"[1]": [1],
		"[1,1,1,1]": [1, 1, 1, 1],
		"[1,2]": [1, 2],
		"10 x [1]": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		"[30,1,...]": [30, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		"zeros no meio": [4, 0, 7, 0, 2],
		"só zeros": [0, 0],
	}
	for label: String in fixed:
		var counts: Array[int] = []
		counts.assign(fixed[label])
		_check_report(label, _verify(counts, -1))
	_check("lista vazia dá planta vazia", SectorLayout.plan([]).is_empty())

	print("\n-- 200 jogos falsos")
	var ids: Array[String] = []
	for profile: DistrictProfile in Profiles.world().districts:
		ids.append(profile.id)
	var fake: Array[int] = _fake_200_counts(ids)
	var total: int = 0
	for count: int in fake:
		total += count
	_check("contagens lidas do retrato (54 quarteirões)", total == 54)
	var rpg: int = ids.find("rpg")
	var largest: int = fake.find(fake.max())
	_check_report("200 falsos", _verify(fake, -1))
	_check_report("200 falsos, foco no RPG", _verify(fake, rpg))
	for focus: int in [-1, rpg]:
		var plan: Array[DistrictSector] = SectorLayout.plan(fake, focus)
		# Só informativo: os quarteirões crescem de dentro para fora e as vagas
		# ficam perto da borda, então o maior bairro pode parar antes dela.
		print("  200 falsos%s: o maior bairro (%s) %s à borda" % [" com foco" if focus >= 0 else "",
				ids[largest], "chega" if _reaches_border(plan, largest) else "não chega (vagas no anel de fora)"])
		_print_map("200 falsos%s" % (", foco no RPG (norte em cima)" if focus >= 0 else ", sem foco"), plan, ids, fake)

	print("\n-- %d listas sorteadas" % RANDOM_LISTS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	var problems: Dictionary = {}
	var growth: Dictionary = {}
	var reached: int = 0
	var started_us: int = Time.get_ticks_usec()
	for i: int in RANDOM_LISTS:
		var counts: Array[int] = []
		for d: int in rng.randi_range(1, 10):
			counts.append(0 if rng.randf() < 0.1 else rng.randi_range(1, 40))
		var focus: int = rng.randi_range(0, counts.size() - 1) if i % 2 == 1 else -1
		var result: Dictionary = _verify(counts, focus)
		for property: String in result["checks"]:
			if not result["checks"][property]:
				problems[property] = int(problems.get(property, 0)) + 1
				if int(problems[property]) == 1:
					print("  exemplo que falhou (%s): %s, foco %d" % [property, counts, focus])
		growth[result["growth"]] = int(growth.get(result["growth"], 0)) + 1
		if counts.max() > 0 and _reaches_border(result["plan"], counts.find(counts.max())):
			reached += 1
	for property: String in _property_names():
		_check("%d listas: %s" % [RANDOM_LISTS, property], not problems.has(property))
	var keys: Array = growth.keys()
	keys.sort()
	for extra: int in keys:
		print("  R cresceu %d vez(es): %d listas" % [extra, growth[extra]])
	print("  o maior bairro chegou à borda em %d de %d listas (só informativo)" % [reached, RANDOM_LISTS])
	print("  tempo: %.0f ms" % ((Time.get_ticks_usec() - started_us) / 1000.0))

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


func _property_names() -> Array[String]:
	return ["um setor por bairro, vazio onde a contagem é 0",
			"contagens certas e nenhuma célula repetida",
			"quarteirões dentro do território",
			"territórios cobrem os anéis 1..R sem sobra",
			"quarteirões e território contínuos",
			"pórtico no menor anel do bairro",
			"todo território com borda no anel R",
			"bissetrizes em ordem horária",
			"mesma lista, mesma planta",
			"R cresceu no máximo 2",
			"foco centrado no norte"]


## Confere todas as propriedades de uma planta. Devolve {"checks", "growth", "plan"}.
func _verify(counts: Array[int], focus: int) -> Dictionary:
	var names: Array[String] = _property_names()
	var checks: Dictionary = {}
	for name: String in names:
		checks[name] = true
	var plan: Array[DistrictSector] = SectorLayout.plan(counts, focus)
	var base: int = SectorLayout.base_ring(counts)
	var ring: int = 0
	for sector: DistrictSector in plan:
		for cell: Vector2i in sector.territory:
			ring = maxi(ring, CityLayout.ring_of(cell))

	# Formato: um setor por entrada; contagem 0 dá setor vazio.
	var shape_ok: bool = plan.size() == counts.size()
	var counts_ok: bool = true
	var inside_ok: bool = true
	var connected_ok: bool = true
	var gate_ok: bool = true
	var border_ok: bool = true
	var all_blocks: Dictionary[Vector2i, bool] = {}
	var all_territory: Dictionary[Vector2i, bool] = {}
	var territory_cells: int = 0
	var bisectors: Array[float] = []
	for i: int in mini(plan.size(), counts.size()):
		var sector: DistrictSector = plan[i]
		if counts[i] <= 0:
			shape_ok = shape_ok and sector.blocks.is_empty() and sector.territory.is_empty() and sector.wedge == Vector2.ZERO
			continue
		counts_ok = counts_ok and sector.blocks.size() == counts[i]
		for cell: Vector2i in sector.blocks:
			counts_ok = counts_ok and not all_blocks.has(cell) and cell != Vector2i.ZERO
			all_blocks[cell] = true
			inside_ok = inside_ok and sector.territory.has(cell)
		for cell: Vector2i in sector.territory:
			all_territory[cell] = true
		territory_cells += sector.territory.size()
		connected_ok = connected_ok and _connected(sector.blocks) and _connected(sector.territory)
		var lowest: int = ring
		for cell: Vector2i in sector.blocks:
			lowest = mini(lowest, CityLayout.ring_of(cell))
		gate_ok = gate_ok and CityLayout.ring_of(sector.blocks[0]) == lowest
		border_ok = border_ok and not sector.border_cells(ring).is_empty()
		bisectors.append(sector.bisector())
	checks[names[0]] = shape_ok
	checks[names[1]] = counts_ok
	checks[names[2]] = inside_ok
	checks[names[3]] = all_territory.size() == territory_cells and territory_cells == 4 * ring * ring + 4 * ring
	checks[names[4]] = connected_ok
	checks[names[5]] = gate_ok
	checks[names[6]] = border_ok
	# Em ordem horária: dando a volta, o ângulo só "cai" uma vez (ao passar pelo norte).
	var drops: int = 0
	for i: int in bisectors.size():
		if bisectors[(i + 1) % bisectors.size()] < bisectors[i]:
			drops += 1
	checks[names[7]] = bisectors.size() < 2 or drops == 1
	checks[names[8]] = _same_plan(plan, SectorLayout.plan(counts, focus))
	checks[names[9]] = ring - base <= 2
	if focus >= 0 and focus < counts.size() and counts[focus] > 0:
		var off_north: float = absf(wrapf(plan[focus].bisector(), -PI, PI))
		checks[names[10]] = off_north <= atan2(0.5, float(ring)) + 1e-4
	return {"checks": checks, "growth": ring - base, "plan": plan}


func _check_report(label: String, result: Dictionary) -> void:
	for property: String in result["checks"]:
		_check("%s: %s" % [label, property], result["checks"][property])
	print("  %s: R cresceu %d vez(es)" % [label, result["growth"]])


## Células ligadas pelo lado ou pelo canto (8 vizinhos)?
func _connected(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return true
	var pending: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		pending[cell] = true
	var queue: Array[Vector2i] = [cells[0]]
	pending.erase(cells[0])
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in NEIGHBORS:
			if pending.has(cell + step):
				pending.erase(cell + step)
				queue.append(cell + step)
	return pending.is_empty()


func _same_plan(a: Array[DistrictSector], b: Array[DistrictSector]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if a[i].blocks != b[i].blocks or a[i].territory != b[i].territory or a[i].wedge != b[i].wedge:
			return false
	return true


func _reaches_border(plan: Array[DistrictSector], index: int) -> bool:
	var ring: int = 0
	for sector: DistrictSector in plan:
		for cell: Vector2i in sector.territory:
			ring = maxi(ring, CityLayout.ring_of(cell))
	for cell: Vector2i in plan[index].blocks:
		if CityLayout.ring_of(cell) == ring:
			return true
	return false


## Quarteirões por bairro com 200 jogos falsos, lidos do retrato da 15.2, na
## ordem do world_profile (bairro sem jogos = 0).
func _fake_200_counts(ids: Array[String]) -> Array[int]:
	var portrait: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var districts: Dictionary = portrait["cases"]["200"]["districts"]
	var counts: Array[int] = []
	for id: String in ids:
		counts.append(districts[id]["blocks"].size() if districts.has(id) else 0)
	return counts


## Planta vista de cima (norte em cima): maiúscula = quarteirão, minúscula =
## vaga, # = pórtico, + = praça.
func _print_map(label: String, plan: Array[DistrictSector], ids: Array[String], counts: Array[int]) -> void:
	var symbol: Dictionary[Vector2i, String] = {}
	var ring: int = 0
	for i: int in plan.size():
		var letter: String = LETTERS[i % LETTERS.length()]
		for cell: Vector2i in plan[i].territory:
			symbol[cell] = letter.to_lower()
			ring = maxi(ring, CityLayout.ring_of(cell))
		for cell: Vector2i in plan[i].blocks:
			symbol[cell] = letter
		if not plan[i].blocks.is_empty():
			symbol[plan[i].blocks[0]] = "#"
	print("\n  Mapa: %s" % label)
	for z: int in range(-ring, ring + 1):
		var row: PackedStringArray = []
		for x: int in range(-ring, ring + 1):
			row.append("+" if Vector2i(x, z) == Vector2i.ZERO else symbol.get(Vector2i(x, z), "."))
		print("    " + " ".join(row))
	var legend: PackedStringArray = []
	for i: int in plan.size():
		legend.append("%s=%s(%d)" % [LETTERS[i % LETTERS.length()], ids[i] if i < ids.size() else "?", counts[i]])
	print("    " + "  ".join(legend))


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
