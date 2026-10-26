class_name TerrainCollision
extends RefCounted
## Colisão limitada ao retângulo da trilha/mirante, com a geometria desenhada.
## O HeightMap padrão usa outra diagonal por célula; a fita evita essa diferença.
## Vértices em coordenadas do mundo, como TerrainMesh: corpo e forma na origem,
## sem rotação nem escala. Use em StaticBody3D, nunca em um corpo dinâmico.


## Expande para linhas da MESMA grade da malha (não para múltiplos de zero).
## A expansão é menor que uma célula em cada lado. O chamador usa este retângulo
## para saber o limite efetivo; não há recorte de triângulos no meio de células.
static func aligned_rect(field: Heightfield, area: Rect2, cell_meters: float) -> Rect2:
	assert(cell_meters > 0.0, "O passo da colisão precisa ser positivo.")
	var rect: Rect2 = area.abs()
	if not rect.has_area():
		return Rect2()
	var first: Vector2 = ((rect.position - field.grid_origin) / cell_meters).floor()
	var last: Vector2 = ((rect.end - field.grid_origin) / cell_meters).ceil()
	return Rect2(field.grid_origin + first * cell_meters, (last - first) * cell_meters)


## Monta só os triângulos desenhados dentro do retângulo alinhado. Reutiliza
## TerrainMesh para manter diagonal, altura afundada e descarte por cobertura.
## Retorna null quando a região não tem nenhum triângulo desenhado.
static func build(field: Heightfield, area: Rect2, cell_meters: float) -> ConcavePolygonShape3D:
	var rect: Rect2 = aligned_rect(field, area, cell_meters)
	if not rect.has_area():
		return null
	var span: float = TerrainMesh.cells_per_chunk(cell_meters) * cell_meters
	var first: Vector2i = Vector2i(((rect.position - field.grid_origin) / span).floor())
	var last: Vector2i = Vector2i(((rect.end - field.grid_origin) / span).ceil())
	var faces: PackedVector3Array = PackedVector3Array()
	for z: int in range(first.y, last.y):
		for x: int in range(first.x, last.x):
			var mesh: ArrayMesh = TerrainMesh.build_chunk(field, Vector2i(x, z), cell_meters)
			if mesh == null:
				continue
			var triangles: PackedVector3Array = mesh.get_faces()
			for i: int in range(0, triangles.size(), 3):
				var center: Vector3 = (triangles[i] + triangles[i + 1] + triangles[i + 2]) / 3.0
				# A borda já está na grade: o centro decide sem cortar uma face.
				if rect.has_point(Vector2(center.x, center.z)):
					faces.append(triangles[i])
					faces.append(triangles[i + 1])
					faces.append(triangles[i + 2])
	if faces.is_empty():
		return null
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape
