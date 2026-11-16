extends SceneTree
## Teste do canto da divisa e da torre de dia (Fase 19.11):
##   - covered_rects: no cruzamento cercado por três zonas (o canto côncavo) a
##     neve cobre o cruzamento inteiro, sem sobra (um quarto solto) e sem
##     buraco, e sem retângulos sobrepostos (o brilho duplo);
##   - os casos que já funcionavam (quatro zonas, duas, diagonal, uma, e as
##     ruas descobertas) dão o mesmo resultado de antes;
##   - a torre do RPG tem a bandeira grande de pano (de dia, sem emissão).

var failures: int = 0
## A mesma medida da cidade: a zona é o quarteirão com meia rua em volta.
const PITCH: float = 38.0
const HALF: float = 200.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# (BiomeBuilder usa autoloads: no teste vai por load(), sem o nome da classe.)
	var builder: GDScript = load("res://worlds/city/biome/biome_builder.gd")
	var curb: float = 5.0  # meia rua (STREET_WIDTH / 2)
	_check("a rua tem 10 m e a zona 38 m (o teste usa essas medidas)",
			is_equal_approx(CityLayout.STREET_WIDTH, 10.0) and is_equal_approx(CityLayout.BLOCK_PITCH, PITCH))

	print("\n== o canto côncavo (três zonas) ==")
	# O cruzamento fica em (0, 0). A zona que falta muda de diagonal em cada caso.
	for missing: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var zones: Array[Rect2] = []
		for dir: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			if dir != missing:
				zones.append(_zone_at(dir))
		var rects: Array[Rect2] = builder.covered_rects(zones, HALF, true)
		var uncovered := 0
		var doubled := 0
		# O cruzamento (10 × 10 m, em passos de 1 m, no meio de cada metro).
		for ix in 10:
			for iy in 10:
				var point := Vector2(-curb + ix + 0.5, -curb + iy + 0.5)
				var count := _count(rects, point)
				if count == 0:
					uncovered += 1
				elif count > 1:
					doubled += 1
		_check("faltando a diagonal %s: o cruzamento todo é neve (buracos: %d)" % [missing, uncovered], uncovered == 0)
		_check("faltando a diagonal %s: nada coberto duas vezes (%d)" % [missing, doubled], doubled == 0)
		# A rua que segue para a diagonal vazia continua de asfalto (não vira neve).
		var beyond := Vector2(missing.x * (curb + 3.0), missing.y * 20.0)
		_check("faltando a diagonal %s: a rua depois do cruzamento segue de asfalto" % missing,
				_count(rects, beyond) == 0)
		# E o quarteirão das três zonas ainda é neve.
		var any_zone := zones[0]
		_check("faltando a diagonal %s: o miolo da zona segue coberto" % missing,
				_count(rects, any_zone.get_center()) == 1)

	print("\n== o que já funcionava continua igual ==")
	var four: Array[Rect2] = []
	for dir: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		four.append(_zone_at(dir))
	var four_rects: Array[Rect2] = builder.covered_rects(four, HALF, true)
	_check("quatro zonas: um retângulo por zona (%d)" % four_rects.size(), four_rects.size() == 4)
	_check("quatro zonas: o cruzamento no meio todo coberto",
			_count(four_rects, Vector2(0.5, 0.5)) == 1 and _count(four_rects, Vector2(-0.5, 3.5)) == 1)
	var row: Array[Rect2] = [_zone_at(Vector2(-1, -1)), _zone_at(Vector2(1, -1))]
	var row_rects: Array[Rect2] = builder.covered_rects(row, HALF, true)
	_check("duas zonas lado a lado: dois retângulos", row_rects.size() == 2)
	_check("duas zonas lado a lado: a rua entre elas é neve e a de fora, asfalto",
			_count(row_rects, Vector2(0.0, -19.0)) == 1 and _count(row_rects, Vector2(0.0, 1.0)) == 0)
	var diagonal: Array[Rect2] = [_zone_at(Vector2(-1, -1)), _zone_at(Vector2(1, 1))]
	_check("duas zonas na diagonal: dois retângulos, sem cruzamento extra",
			builder.covered_rects(diagonal, HALF, true).size() == 2)
	var single: Array[Rect2] = [_zone_at(Vector2(1, 1))]
	var single_rects: Array[Rect2] = builder.covered_rects(single, HALF, true)
	_check("uma zona: só o quarteirão (zona menos a meia rua)",
			single_rects.size() == 1 and single_rects[0].is_equal_approx(single[0].grow(-curb)))
	var three: Array[Rect2] = [_zone_at(Vector2(-1, -1)), _zone_at(Vector2(1, -1)), _zone_at(Vector2(-1, 1))]
	_check("sem cobrir as ruas, três zonas dão só os três quarteirões",
			builder.covered_rects(three, HALF, false).size() == 3)
	# Na borda (zonas que vão até a mureta) não há cruzamento côncavo de dentro.
	var edge_list: Array[Rect2] = [Rect2(-HALF, -HALF, PITCH, PITCH)]
	var edge_rects: Array[Rect2] = builder.covered_rects(edge_list, HALF, true)
	_check("na borda a neve vai até a mureta, como antes",
			edge_rects.size() == 1 and is_equal_approx(edge_rects[0].position.x, -HALF)
			and is_equal_approx(edge_rects[0].position.y, -HALF))

	print("\n== a torre de dia ==")
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 200, false, true)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame
	var tower: Node = city.get_node_or_null("DistrictLandmark_rpg")
	_check("o RPG tem a torre", tower != null)
	var banner: Node3D = tower.get_node_or_null("Banner") if tower != null else null
	_check("a torre tem a bandeira grande", banner != null)
	if banner != null:
		var cloth := banner.get_child(0) as MeshInstance3D
		var material := cloth.material_override as StandardMaterial3D if cloth != null else null
		_check("o pano é opaco e sem emissão (de dia é cor, não brilho)",
				material != null and not material.emission_enabled)
		var size: Vector3 = (cloth.mesh as BoxMesh).size if cloth != null else Vector3.ZERO
		_check("o pano é grande (%.1f × %.1f m)" % [size.x, size.y], size.x >= 2.5 and size.y >= 8.0)
		_check("a bandeira tem uma faixa por face (4 panos, 8 faixas e 4 vergas)", banner.get_child_count() == 16)
		tower.set_night(1.0)
		_check("de noite o pano continua sem emissão", material != null and not material.emission_enabled)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## A zona do quadrante "dir" em volta do cruzamento (0, 0).
func _zone_at(dir: Vector2) -> Rect2:
	return Rect2(0.0 if dir.x > 0.0 else -PITCH, 0.0 if dir.y > 0.0 else -PITCH, PITCH, PITCH)


## Em quantos retângulos o ponto cai.
func _count(rects: Array[Rect2], point: Vector2) -> int:
	var count := 0
	for rect in rects:
		if rect.has_point(point):
			count += 1
	return count


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
