class_name BackdropTerrain
extends Node3D
## A montanha de fundo de um bairro (Fase 15.9), atrás da mureta, na cunha
## dele. É o ponto único do terreno: a cidade só conhece este nó (trocar por
## outro gerador no futuro é escrever outro com a mesma API).
##
## Junta as peças da 15.8: as alturas (Heightfield), a trilha (MountainTrail),
## a malha em pedaços (TerrainMesh) e a colisão com os triângulos desenhados
## (TerrainCollision, o plano B da 15.9.1a).
##
## 15.9.1b (greybox): a malha sai cinza (o terrain.gdshader sem texturas), um
## bloco cinza marca o lugar da torre no mirante, e a colisão cobre a trilha,
## o mirante e um pouco de encosta em volta.
## 15.9.2: o mirante sai da linha praça–obelisco (_plan_off_axis), e a
## montanha vira zona do bairro (get_zone_rects).
## 15.9.3: os limites e a sinalização da trilha (TrailDressing: paredes,
## estacas, lampiões, pilares e placa) e o material de neve e rocha (quem
## monta passa com use_material; sem ele, fica o cinza do greybox).
## 15.10: a plataforma de madeira na beirada virada para a praça (LookoutDeck),
## e o bloco cinza sai: a torre de verdade é o marco do bairro, que a cidade
## ancora em tower_spot().
##
## 19.12: os pinheiros e as rochas da encosta. As famílias on_backdrop do
## bioma (biome, posto por quem monta, com a quantidade da qualidade gráfica em
## scatter_amount) são espalhadas pelo MESMO BiomeScatter.plan() da cidade,
## nas células da encosta (SCATTER_CELL), e assentadas no chão da montanha
## (BiomeScatter.add_on_ground). Ficam fora: a trilha (com a walkable_clearance
## da família além das paredes), as paradas, o mirante e a plataforma dele, e a
## vista da luneta (um cone da ocular até a praça). Árvore só onde o chão é de
## neve (TerrainSpec.snow_slope); rocha só no chão inclinado (nem no plano nem
## no paredão), longe do mirante, cada uma com tamanho, achatamento e
## inclinação próprios (_vary_rocks). Mesma
## montanha, mesma encosta: a semente vem do bioma e da família, e a montanha
## não muda com as horas (19.9). Na troca da qualidade, a montanha é refeita, e
## a encosta junto, com a quantidade nova.
##
## Uso: setup(); se der true, chamar build_next() até devolver false (um pedaço
## por chamada, para a montagem não travar o quadro).
##
## Contrato com as ferramentas (tools/medir_desempenho.gd, capturar_pontos.gd):
## o nó fica no grupo "mountain_trail" e responde trail_world_points(),
## lookout_world() e (15.10) view_world(), o ponto da vista na plataforma.

const GROUP: StringName = &"mountain_trail"
## A colisão vai além da trilha e do mirante este tanto (encosta pisável).
const COLLISION_MARGIN: float = 12.0
## O vão da mureta: a largura da trilha mais esta folga de cada lado.
const OPENING_SIDE_GAP: float = 0.5
## Profundidade do retângulo do vão (atravessa a mureta, que tem 0,6 m).
const OPENING_DEPTH: float = 2.0
## Rede de segurança: as paredes da trilha seguram o jogador, mas, se algo
## escapar, ele para aqui, abaixo do chão, em vez de cair para sempre.
const SAFETY_FLOOR_Y: float = -1.0
## Da praça, o mirante (e a torre) fica pelo menos este ângulo fora da
## bissetriz da cunha, para o obelisco do relógio não tapar a torre.
const LOOKOUT_MIN_ANGLE: float = deg_to_rad(18.0)
## Os desvios tentados para a linha da subida, do menor ao maior.
const AIM_SHIFTS: Array[float] = [deg_to_rad(12.0), deg_to_rad(18.0), deg_to_rad(24.0), deg_to_rad(30.0)]
## A torre fica atrás do meio do mirante, do lado longe da praça (a frente
## fica livre para a plataforma e a vista).
const TOWER_BACK_SHARE: float = 0.5
const TERRAIN_SHADER: Shader = preload("res://worlds/city/biome/terrain.gdshader")

## --- A encosta (19.12) ---
## Lado (m) das células (as "regiões" do BiomeScatter.plan) da encosta.
const SCATTER_CELL: float = 20.0
## Cada célula cresce isto (além da walkable_clearance da família) para o
## sorteio não deixar faixas vazias entre células vizinhas.
const SCATTER_SEAM: float = 1.0
## Na encosta: a montanha cobre o chão pelo menos isto (Heightfield.sample().w)...
const SLOPE_MIN_COVER: float = 0.5
## ...e o chão fica pelo menos isto acima do chão de fora (m): nada no pé liso.
const SLOPE_MIN_GROUND: float = 1.0
## Rochas até este chão inclinado (a normal para cima); árvores, só na neve.
const ROCK_MIN_UP: float = 0.6
## ...e só onde o chão já inclina: no chão quase plano de neve, uma rocha
## sozinha parece uma bola de neve (o rascunho da 19.12).
const ROCK_MAX_UP: float = 0.9
## As rochas ficam pelo menos isto (m) do meio do mirante: a vista de lá
## começa nos pinheiros, e não num monte de pedras embaixo da plataforma.
const ROCK_LOOKOUT_GAP: float = 24.0
## A cara de cada rocha (o sorteio é pela posição dela: a mesma encosta dá as
## mesmas rochas). O tamanho é o do perfil vezes um fator de ROCK_SIZE (a
## maioria perto do menor: muitas pequenas, poucas grandes); a altura ainda é
## achatada por ROCK_FLATTEN, sem ficar abaixo de ROCK_MIN_HEIGHT (m; menor
## que isso, a neve engole a pedra); e a rocha inclina até ROCK_TILT para um lado.
const ROCK_SIZE: Vector2 = Vector2(0.5, 1.0)
const ROCK_FLATTEN: Vector2 = Vector2(0.6, 1.0)
const ROCK_MIN_HEIGHT: float = 0.8
const ROCK_TILT: float = deg_to_rad(12.0)
## Folga mínima de tudo até as paredes da trilha, do anel e das paradas (m).
const TRAIL_GAP: float = 0.5
## A vista da luneta: nada no cone da ocular até o alvo (meio ângulo) nem no
## tubo em volta da linha por onde a câmera anda (raio, m).
const VIEW_CONE: float = deg_to_rad(8.0)
const VIEW_TUBE: float = 3.0
## Pontos conferidos ao longo da altura de cada cópia, contra o cone.
const VIEW_SAMPLES: int = 7
## A distância até a trilha: baldes de TRAIL_BUCKET m com os trechos até
## TRAIL_REACH m (o MountainTrail.closest só enxerga 4,5 m). TRAIL_REACH tem
## que passar da maior folga pedida (parede + walkable_clearance + copa).
const TRAIL_BUCKET: float = 8.0
const TRAIL_REACH: float = 20.0
## Quantas células são sorteadas por chamada do build_next().
const REGIONS_PER_STEP: int = 16
const SCATTER_NAME: String = "SlopeScatter"

## Tamanho do quadrado da grade (m) e se a malha faz sombra (15.14): quem monta
## escolhe pela qualidade (GraphicsQuality), ANTES do setup().
var cell_meters: float = 3.0
var casts_shadow: bool = true

var field: Heightfield
var trail: MountainTrail
## A marca dos passos na colisão (ex.: "snow"). Vazio = sem marca.
var footstep: String = ""
## A pedra dos pilares da entrada (null = cinza).
var stone_material: Material = null
## 19.12: o bioma (as famílias on_backdrop vão para a encosta; null = encosta
## nua) e quanto da densidade fica (GraphicsQuality.scatter_amount). Quem monta
## põe os dois antes do setup().
var biome: BiomeSpec = null
var scatter_amount: float = 1.0

var _coords: Array[Vector2i] = []
var _next: int = 0
var _material: ShaderMaterial
var _collision_rect: Rect2 = Rect2()
var _faces: PackedVector3Array = PackedVector3Array()
var _snow_slope: float = 0.75
## O que a encosta precisa saber, calculado uma vez (_prepare_scatter).
var _scatter_ready: bool = false
var _cells: Array[Rect2] = []
var _trail_buckets: Dictionary = {}
var _stops: Array[Vector3] = []  # (x, z, raio)
var _deck_rect: Rect2 = Rect2()
var _view_eye: Vector3 = Vector3.ZERO
var _view_dir: Vector3 = Vector3.ZERO
var _view_length: float = 0.0
## O espalhamento em andamento no build_next(): a família (posição na lista
## slope_families), a próxima célula, as cópias já sorteadas e o que já foi posto.
var _scatter_family: int = 0
var _scatter_cell: int = 0
var _scatter_items: Array[Dictionary] = []
var _scatter_occupied: Array[Vector3] = []
var _scatter_source: Dictionary = {}


## Calcula a montanha e a trilha para a cunha do bairro. Falso quando não
## cabe (a cidade grande demais para o raio de fora, ou a trilha não coube):
## aí não há montanha e o nó deve ser descartado.
func setup(spec: TerrainSpec, sector: DistrictSector, half: float) -> bool:
	field = Heightfield.new()
	field.apply_spec(spec)
	_snow_slope = spec.snow_slope
	field.configure(half, sector.wedge.x, sector.wedge.y)
	var border := sector.border_cells()
	if not field.fits() or border.is_empty():
		return false
	trail = _plan_off_axis(border)
	if trail == null:
		return false
	field.set_trail(trail)
	_coords = TerrainMesh.chunk_coords(field, cell_meters)
	_collision_rect = TerrainCollision.aligned_rect(field, trail.bounds().grow(COLLISION_MARGIN), cell_meters)
	_material = ShaderMaterial.new()
	_material.shader = TERRAIN_SHADER
	add_to_group(GROUP)
	return true


## O material da montanha (neve e rocha). Chamar antes do primeiro build_next().
func use_material(material: ShaderMaterial) -> void:
	_material = material


## Monta o próximo pedaço da malha. Falso quando acabou (aí entram a colisão,
## a plataforma do mirante, os limites e a sinalização e a rede de segurança).
func build_next() -> bool:
	if _next < _coords.size():
		var mesh := TerrainMesh.build_chunk(field, _coords[_next], cell_meters, _material)
		if mesh != null:
			var chunk := MeshInstance3D.new()
			chunk.name = "Chunk_%d_%d" % [_coords[_next].x, _coords[_next].y]
			chunk.mesh = mesh
			if not casts_shadow:
				chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(chunk)
			if TerrainMesh.chunk_rect(field, _coords[_next], cell_meters).intersects(_collision_rect):
				_faces.append_array(TerrainCollision.faces_in(mesh, _collision_rect))
		_next += 1
		return true
	if _next == _coords.size():
		_next += 1
		_add_collision()
		# O mirante (17.8): planeja agora e monta um pedaço por chamada.
		var deck := LookoutDeck.new()
		deck.setup(field, trail)
		add_child(deck)
		return true
	var building := get_deck()
	if building != null and building.build_next():
		return true
	if get_dressing() == null:
		var dressing := TrailDressing.new()
		add_child(dressing)
		dressing.setup(field, trail, stone_material)
		_add_safety_floor()
		# 19.12: depois, os pinheiros e as rochas da encosta, aos pedaços.
		return _start_scatter()
	return _scatter_next()


## Os limites e a sinalização da trilha (null antes de a montagem acabar).
func get_dressing() -> TrailDressing:
	return get_node_or_null("TrailDressing") as TrailDressing


## Os pontos do chão da trilha (no mundo), do vão da mureta até o mirante, de 1 em 1 m.
func trail_world_points() -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in trail.points.size():
		result.append(Vector3(trail.points[i].x, trail.heights[i], trail.points[i].y))
	return result


## O centro do piso do mirante, no mundo.
func lookout_world() -> Vector3:
	return Vector3(trail.lookout_center.x, field.lookout_height, trail.lookout_center.y)


## A plataforma de madeira do mirante (null antes de a montagem acabar, ou se
## ela não coube).
func get_deck() -> LookoutDeck:
	return get_node_or_null("LookoutDeck") as LookoutDeck


## O ponto do chão de onde se olha a vista (no mundo): na ponta da plataforma
## (o centro do disco, se ela não coube). As capturas "mirante" ficam aqui.
func view_world() -> Vector3:
	return LookoutDeck.view_spot(field, trail, LookoutDeck.direction(field, trail))


## Onde fica a base da torre do bairro (no mundo): no mirante, atrás do meio
## do disco, do lado longe da praça. A cidade ancora o marco do bairro aqui.
func tower_spot() -> Vector3:
	var away := trail.lookout_center.normalized()
	var spot := trail.lookout_center + away * field.lookout_radius * TOWER_BACK_SHARE
	return Vector3(spot.x, field.lookout_height, spot.y)


## Onde a trilha corta a mureta: retângulos (no chão) que a cidade deixa sem
## mureta, sem grade e sem barreira. Hoje, um só.
func get_openings() -> Array[Rect2]:
	var width := field.trail_width + OPENING_SIDE_GAP * 2.0
	var along := Vector2(-trail.outward.y, trail.outward.x).abs()
	var across := trail.outward.abs()
	var size := along * width + across * OPENING_DEPTH
	return [Rect2(trail.start - size / 2.0, size)]


## A altura do chão (montanha, rampa e trilha) num ponto do mundo.
func height_at(point: Vector2) -> float:
	return field.surface_at(point)


## As zonas da montanha no chão (para o clima, a névoa e o vento do bairro):
## a trilha, o mirante e a encosta pisável em volta, só do lado de fora da
## mureta (dentro dela, as zonas são os quarteirões e as vagas).
func get_zone_rects() -> Array[Rect2]:
	var rect := trail.bounds().grow(COLLISION_MARGIN)
	var from := rect.position
	var to := rect.end
	if trail.outward.x > 0.5:
		from.x = maxf(from.x, field.half)
	elif trail.outward.x < -0.5:
		to.x = minf(to.x, -field.half)
	elif trail.outward.y > 0.5:
		from.y = maxf(from.y, field.half)
	else:
		to.y = minf(to.y, -field.half)
	return [Rect2(from, to - from)]


## O ângulo do mirante visto do centro da praça, medido a partir da bissetriz
## da cunha (com sinal).
func lookout_angle() -> float:
	return wrapf(Heightfield.angle_of(trail.lookout_center) - field.wedge_center, -PI, PI)


## A trilha com o mirante fora da linha praça–obelisco: o zigue-zague sobe em
## volta de uma linha desviada da bissetriz, até o mirante ficar a pelo menos
## LOOKOUT_MIN_ANGLE dela (da praça, o obelisco não tapa a torre). Tenta
## primeiro o lado para onde a trilha já tende; sem lugar, fica a trilha na
## bissetriz. null se nem ela couber.
func _plan_off_axis(border: Array[Vector2i]) -> MountainTrail:
	var center := field.wedge_center
	var straight := MountainTrail.plan_from_cell(field, MountainTrail.border_cell_nearest(border, center))
	if not straight.valid:
		return null
	trail = straight
	var natural := lookout_angle()
	if absf(natural) >= LOOKOUT_MIN_ANGLE:
		return straight
	var first_side := 1.0 if natural >= 0.0 else -1.0
	for side: float in [first_side, -first_side]:
		for shift: float in AIM_SHIFTS:
			var aim := center + side * shift
			trail = MountainTrail.plan_from_cell(field, MountainTrail.border_cell_nearest(border, aim), aim)
			if trail.valid and absf(lookout_angle()) >= LOOKOUT_MIN_ANGLE:
				return trail
	return straight


func _add_collision() -> void:
	if _faces.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "TrailCollision"
	if not footstep.is_empty():
		body.set_meta("footstep", footstep)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_faces = PackedVector3Array()


func _add_safety_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "SafetyFloor"
	var collision := CollisionShape3D.new()
	collision.shape = WorldBoundaryShape3D.new()
	body.add_child(collision)
	body.position.y = SAFETY_FLOOR_Y
	add_child(body)



# --- A encosta (19.12) ---------------------------------------------------------

## O BiomeScatter da encosta (null antes de a montagem chegar nele, ou se o
## bioma não tem nada para a encosta).
func get_scatter() -> BiomeScatter:
	return get_node_or_null(SCATTER_NAME) as BiomeScatter


## Os índices (no BiomeSpec.scatter) das famílias que vão para a encosta.
func slope_families() -> Array[int]:
	var result: Array[int] = []
	if biome == null:
		return result
	for i in biome.scatter.size():
		if biome.scatter[i].on_backdrop:
			result.append(i)
	return result


## A semente de uma família da encosta: o bioma e a família, nada da
## biblioteca (a mesma montanha dá sempre a mesma encosta).
func scatter_seed(index: int) -> int:
	return hash([biome.id, "encosta", index])


## As cópias de cada família da encosta, sem montar nada: índice -> as cópias
## do BiomeScatter.plan (no chão em y = 0). É a mesma conta da montagem, de
## uma vez só ("amount" faz o papel do scatter_amount).
func scatter_plan(amount: float) -> Dictionary:
	_prepare_scatter()
	var result := {}
	var occupied: Array[Vector3] = []
	for index in slope_families():
		var source := BiomeScatter.source_of(biome.scatter[index], biome)
		if not source.is_empty():
			result[index] = _plan_cells(index, source, 0, _cells.size(), occupied, amount)
	return result


## A linha da vista da luneta: [ocular, direção unitária, comprimento até o
## alvo]. Vazia se não houver luneta.
func view_line() -> Array:
	_prepare_scatter()
	if _view_dir == Vector3.ZERO:
		return []
	return [_view_eye, _view_dir, _view_length]


## Um lugar serve para uma cópia desta família na encosta? (o "accept" do
## BiomeScatter.plan). "crown" é a copa com a folga (0 na rocha).
func slope_accepts(spot: Vector2, footprint: float, crown: float, height: float, spec: ScatterSpec) -> bool:
	if not _scatter_ready:
		_prepare_scatter()
	# Na encosta: a montanha embaixo da peça inteira, fora do pé liso.
	if not _on_slope(spot):
		return false
	for k in 4:
		if not _on_slope(spot + Vector2.from_angle(TAU * k / 4.0) * footprint):
			return false
	# Árvore só na neve (o chão que não é paredão de rocha); rocha, até o íngreme.
	var rock := spec.kind == "mesh"
	var up := BiomeScatter.ground_normal(field.surface_at, spot, maxf(footprint, 1.0)).y
	if up < (ROCK_MIN_UP if rock else _snow_slope) or (rock and up > ROCK_MAX_UP):
		return false
	# Longe de onde se anda: a folga da família além das paredes, e a copa
	# (com a CROWN_GAP) sem passar por cima delas.
	var reach := maxf(maxf(spec.walkable_clearance, TRAIL_GAP) + footprint, crown)
	if _trail_distance(spot) < TrailDressing.WALL_OFFSET + reach:
		return false
	var lookout_gap := field.lookout_radius + TrailDressing.RING_GAP + reach
	if rock:
		lookout_gap = maxf(lookout_gap, ROCK_LOOKOUT_GAP)
	if spot.distance_to(trail.lookout_center) < lookout_gap:
		return false
	if _deck_rect.has_area() and BiomeScatter.area_distance(_deck_rect, spot) < reach:
		return false
	for stop in _stops:
		if spot.distance_to(Vector2(stop.x, stop.y)) < stop.z + reach:
			return false
	return not _in_view(spot, height, crown if crown > 0.0 else footprint)


## Começa a encosta (no fim da montagem). Falso se não houver o que espalhar.
func _start_scatter() -> bool:
	if slope_families().is_empty():
		return false
	var node := BiomeScatter.new()
	node.name = SCATTER_NAME
	add_child(node)
	_scatter_family = 0
	_scatter_cell = 0
	_scatter_items = []
	_scatter_occupied = []
	_scatter_source = {}
	return true


## Um pedaço da encosta: a preparação, ou REGIONS_PER_STEP células de uma
## família; quando a família acaba, ela vai para o chão. Falso quando acabou.
func _scatter_next() -> bool:
	var node := get_scatter()
	var families := slope_families()
	if node == null or _scatter_family >= families.size():
		return false
	if not _scatter_ready:
		_prepare_scatter()
		return true
	var index := families[_scatter_family]
	var spec := biome.scatter[index]
	if _scatter_source.is_empty():
		_scatter_source = BiomeScatter.source_of(spec, biome)
	if _scatter_source.is_empty():
		push_warning("O elemento %s do bioma %s não carregou." % [spec.source, biome.id])
		_scatter_cell = _cells.size()
	else:
		var to := mini(_scatter_cell + REGIONS_PER_STEP, _cells.size())
		_scatter_items.append_array(_plan_cells(index, _scatter_source, _scatter_cell, to,
				_scatter_occupied, scatter_amount))
		_scatter_cell = to
	if _scatter_cell < _cells.size():
		return true
	if not _scatter_source.is_empty():
		if spec.kind == "mesh":
			_vary_rocks(index, _scatter_items)
		node.add_on_ground(index, spec, _scatter_source, _scatter_items, field.surface_at)
	_scatter_items = []
	_scatter_source = {}
	_scatter_cell = 0
	_scatter_family += 1
	return _scatter_family < families.size()


## Cada rocha da encosta com a cara dela (tamanho, achatamento e inclinação),
## sorteada pela posição. Só diminui a rocha: o lugar que o plan() reservou
## continua cobrindo a pedra inteira. A inclinação vai em "tilt" (direção e
## ângulo), que o BiomeScatter._seat soma à inclinação do chão.
func _vary_rocks(index: int, items: Array[Dictionary]) -> void:
	for item in items:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([scatter_seed(index), item["position"]])
		# Ao quadrado: a maioria fica perto do menor fator.
		var size := lerpf(ROCK_SIZE.x, ROCK_SIZE.y, pow(rng.randf(), 2.0))
		var flat := rng.randf_range(ROCK_FLATTEN.x, ROCK_FLATTEN.y)
		var height := float(item["height"])
		# Pequena demais: cresce de volta até a altura mínima (sem passar do perfil).
		var shrink := minf(maxf(size * flat, ROCK_MIN_HEIGHT / height), 1.0)
		size = minf(maxf(size, shrink / flat), 1.0)
		flat = shrink / size
		var item_scale: Vector3 = item["scale"] * size
		item_scale.y *= flat
		item["scale"] = item_scale
		item["height"] = height * size * flat
		item["radius"] = float(item["radius"]) * size
		item["tilt"] = Vector2(rng.randf() * TAU, rng.randf() * ROCK_TILT)


## O sorteio de uma família nas células [from, to). Cada célula cresce a folga
## da família: o plan() tira a walkable_clearance da beira da região (na
## cidade, a calçada), e na encosta quem anda está na trilha (slope_accepts).
func _plan_cells(index: int, source: Dictionary, from: int, to: int, occupied: Array[Vector3],
		amount: float) -> Array[Dictionary]:
	var spec := biome.scatter[index]
	var regions: Array[Rect2] = []
	for k in range(from, to):
		regions.append(_cells[k].grow(spec.walkable_clearance + SCATTER_SEAM))
	return BiomeScatter.plan(spec, regions, [], occupied, scatter_seed(index),
			float(source["height"]), float(source["radius"]), [], amount,
			float(source.get("crown", 0.0)), slope_accepts.bind(spec))


## Calcula uma vez o que a encosta precisa: as células com montanha, os baldes
## da trilha, as paradas, o retângulo da plataforma e a linha da luneta.
func _prepare_scatter() -> void:
	if _scatter_ready:
		return
	_scatter_ready = true
	_cells.clear()
	var outer := field.outer_radius
	var steps := ceili(outer * 2.0 / SCATTER_CELL)
	for i in steps:
		for j in steps:
			var cell := Rect2(Vector2(-outer + i * SCATTER_CELL, -outer + j * SCATTER_CELL),
					Vector2(SCATTER_CELL, SCATTER_CELL))
			var center := cell.get_center()
			# Longe do anel ou da cunha da montanha: nem confere.
			var far := center.length() > outer + SCATTER_CELL or field.square_distance(center) < -SCATTER_CELL
			if far or field.edge_distance(center) < -SCATTER_CELL:
				continue
			if _cell_has_slope(cell):
				_cells.append(cell)

	_trail_buckets.clear()
	for i in trail.points.size() - 1:
		var box := Rect2(trail.points[i], Vector2.ZERO).expand(trail.points[i + 1]).grow(TRAIL_REACH)
		for bx in range(floori(box.position.x / TRAIL_BUCKET), floori(box.end.x / TRAIL_BUCKET) + 1):
			for bz in range(floori(box.position.y / TRAIL_BUCKET), floori(box.end.y / TRAIL_BUCKET) + 1):
				var key := Vector2i(bx, bz)
				if not _trail_buckets.has(key):
					_trail_buckets[key] = PackedInt32Array()
				_trail_buckets[key].append(i)

	# As paradas: o meio e o raio que cobre a peça e o que ela põe lá fora.
	_stops.clear()
	for spot in TrailDressing.stop_spots(field, trail):
		var place: Transform3D = spot["transform"]
		var middle := Vector2(place.origin.x, place.origin.z)
		var reach := (spot["size"] as Vector2).x / 2.0
		for p in TrailDressing.outer_points(spot):
			reach = maxf(reach, p.distance_to(middle))
		_stops.append(Vector3(middle.x, middle.y, reach))

	# A plataforma do mirante (com os pés, que descem a encosta embaixo dela).
	_deck_rect = Rect2()
	var outline := LookoutDeck.outline(field, trail, LookoutDeck.direction(field, trail))
	if outline.size() >= 2:
		_deck_rect = Rect2(Vector2(outline[0].x, outline[0].z), Vector2.ZERO)
		for p in outline:
			_deck_rect = _deck_rect.expand(Vector2(p.x, p.z))

	# A luneta: da ocular até o alvo (a praça).
	var deck := get_deck()
	var layout: Dictionary = deck.get_layout() if deck != null else LookoutDeck.layout(LookoutDeck.site(field, trail))
	_view_dir = Vector3.ZERO
	if layout.has("telescope"):
		_view_eye = (layout["telescope"] as Transform3D) * LookoutTelescope.EYEPIECE
		var to := LookoutDeck.TELESCOPE_TARGET - _view_eye
		_view_length = to.length()
		if _view_length > 0.0:
			_view_dir = to / _view_length


## A célula tem encosta? (algum ponto de uma grade 3 x 3 dentro dela)
func _cell_has_slope(cell: Rect2) -> bool:
	for u: float in [0.17, 0.5, 0.83]:
		for v: float in [0.17, 0.5, 0.83]:
			if _on_slope(cell.position + cell.size * Vector2(u, v)):
				return true
	return false


## O ponto fica na encosta: com montanha embaixo e acima do pé liso.
func _on_slope(point: Vector2) -> bool:
	var sample := field.sample(point)
	return sample.w >= SLOPE_MIN_COVER and sample.x >= SLOPE_MIN_GROUND


## A distância (no chão) até a linha do meio da trilha; INF além de TRAIL_REACH.
func _trail_distance(point: Vector2) -> float:
	var key := Vector2i(floori(point.x / TRAIL_BUCKET), floori(point.y / TRAIL_BUCKET))
	if not _trail_buckets.has(key):
		return INF
	var best := INF
	for i: int in _trail_buckets[key]:
		var nearest := Geometry2D.get_closest_point_to_segment(point, trail.points[i], trail.points[i + 1])
		best = minf(best, point.distance_to(nearest))
	return best


## Uma cópia (de "height" m e raio "radius") entra na vista da luneta? Confere
## pontos ao longo da altura dela contra o cone e o tubo da linha da vista.
func _in_view(spot: Vector2, height: float, radius: float) -> bool:
	if _view_dir == Vector3.ZERO:
		return false
	var ground := field.surface_at(spot)
	var spread := tan(VIEW_CONE)
	for k in VIEW_SAMPLES:
		var point := Vector3(spot.x, ground + height * k / float(VIEW_SAMPLES - 1), spot.y)
		var offset := point - _view_eye
		var along := offset.dot(_view_dir)
		if along <= 0.0 or along > _view_length:
			continue
		if (offset - _view_dir * along).length() - radius < along * spread + VIEW_TUBE:
			return true
	return false
