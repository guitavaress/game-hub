class_name TerrainMesh
extends RefCounted
## A malha da montanha (Fase 15.8), em pedaços de ~64 m: só contas, nenhum nó.
##
## Cada pedaço é uma ArrayMesh com os vértices em coordenadas do MUNDO (o
## MeshInstance3D fica na origem). A grade é a mesma para todos os pedaços,
## então as beiradas encaixam sem fresta. Os quadrados sem montanha e sem
## trilha (cobertura 0 nos quatro cantos) são descartados.
##
## Cada vértice leva, na cor (COLOR, lida pelo terrain.gdshader):
##   r = quanto é trilha ou mirante; g = quanto escurece no pé da montanha.
##
## O tamanho do quadrado da grade vem da qualidade gráfica (4 m na Leve,
## 3 m na Média, 2 m na Alta). A montagem é de um pedaço por quadro.

const CHUNK_METERS: float = 64.0


## Quantos quadrados da grade cabem num pedaço.
static func cells_per_chunk(cell_meters: float) -> int:
	return maxi(1, roundi(CHUNK_METERS / cell_meters))


## O retângulo (no chão) de um pedaço.
static func chunk_rect(field: Heightfield, coord: Vector2i, cell_meters: float) -> Rect2:
	var span := cells_per_chunk(cell_meters) * cell_meters
	return Rect2(field.grid_origin + Vector2(coord) * span, Vector2(span, span))


## Os pedaços que podem ter montanha ou trilha (os outros nem são montados).
static func chunk_coords(field: Heightfield, cell_meters: float) -> Array[Vector2i]:
	var span := cells_per_chunk(cell_meters) * cell_meters
	var from := Vector2i(floori((-field.outer_radius - field.grid_origin.x) / span),
			floori((-field.outer_radius - field.grid_origin.y) / span))
	var to := Vector2i(floori((field.outer_radius - field.grid_origin.x) / span),
			floori((field.outer_radius - field.grid_origin.y) / span))
	var coords: Array[Vector2i] = []
	for cz in range(from.y, to.y + 1):
		for cx in range(from.x, to.x + 1):
			var coord := Vector2i(cx, cz)
			if _may_cover(field, chunk_rect(field, coord, cell_meters)):
				coords.append(coord)
	return coords


## Monta um pedaço. Devolve null se nada dele tem montanha ou trilha.
static func build_chunk(field: Heightfield, coord: Vector2i, cell_meters: float,
		material: Material = null) -> ArrayMesh:
	var cells := cells_per_chunk(cell_meters)
	var origin := chunk_rect(field, coord, cell_meters).position
	# Amostras com uma volta a mais em cada lado: a normal de um vértice da
	# beirada usa o vizinho do pedaço ao lado (assim a luz não marca a emenda).
	var side := cells + 3
	var samples: Array[Vector4] = []
	samples.resize(side * side)
	for j in side:
		for i in side:
			samples[j * side + i] = field.sample(origin + Vector2(i - 1, j - 1) * cell_meters)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var vertex_of := PackedInt32Array()
	vertex_of.resize((cells + 1) * (cells + 1))
	vertex_of.fill(-1)
	for qz in cells:
		for qx in cells:
			var corners := [Vector2i(qx, qz), Vector2i(qx + 1, qz), Vector2i(qx, qz + 1), Vector2i(qx + 1, qz + 1)]
			var covered := false
			for corner: Vector2i in corners:
				if samples[(corner.y + 1) * side + corner.x + 1].w > 0.0:
					covered = true
					break
			if not covered:
				continue
			var ids := PackedInt32Array()
			for corner: Vector2i in corners:
				var slot := corner.y * (cells + 1) + corner.x
				if vertex_of[slot] < 0:
					vertex_of[slot] = vertices.size()
					var s := samples[(corner.y + 1) * side + corner.x + 1]
					var at := origin + Vector2(corner) * cell_meters
					vertices.append(Vector3(at.x, s.x, at.y))
					var west := samples[(corner.y + 1) * side + corner.x].x
					var east := samples[(corner.y + 1) * side + corner.x + 2].x
					var north := samples[corner.y * side + corner.x + 1].x
					var south := samples[(corner.y + 2) * side + corner.x + 1].x
					normals.append(Vector3(west - east, 2.0 * cell_meters, north - south).normalized())
					colors.append(Color(s.y, s.z, 0.0, 1.0))
				ids.append(vertex_of[slot])
			# Dois triângulos no sentido horário visto de cima (a frente na Godot).
			indices.append_array([ids[0], ids[1], ids[3], ids[0], ids[3], ids[2]])
	if indices.is_empty():
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh


## O pedaço pode ter montanha ou trilha? (Pode responder sim à toa, nunca não à toa.)
static func _may_cover(field: Heightfield, rect: Rect2) -> bool:
	# Longe demais da praça.
	var nearest := Vector2(clampf(0.0, rect.position.x, rect.end.x), clampf(0.0, rect.position.y, rect.end.y))
	if nearest.length() >= field.outer_radius:
		return false
	# Inteiro dentro do quadrado da cidade.
	if maxf(maxf(absf(rect.position.x), absf(rect.end.x)), maxf(absf(rect.position.y), absf(rect.end.y))) <= field.half:
		return false
	# Algum canto dentro da cunha, ou a cunha (as beiradas e o meio) passando por ele.
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		if field.edge_distance(corner) > -Heightfield.SHOULDER:
			return true
	for angle in [field.wedge_center - field.wedge_half, field.wedge_center, field.wedge_center + field.wedge_half]:
		var direction := Heightfield.direction_of(angle)
		var distance := 0.0
		while distance <= field.outer_radius:
			if rect.grow(Heightfield.SHOULDER).has_point(direction * distance):
				return true
			distance += 4.0
	return false
