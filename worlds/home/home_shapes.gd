class_name HomeShapes
extends RefCounted
## Formas feitas por código para os móveis e objetos da casa (Fase 17.4), sem
## nada baixado:
##   - soft_box: caixa de cantos arredondados e faces estufadas (sofá, almofada,
##     tampo de mesa). É o que tira a cara de "caixa" dos móveis;
##   - drape: um pano caído sobre uma linha (a manta no sofá), com dobras;
##   - book: um livro (capas, lombada, miolo de papel);
##   - tube: um cano fino sobre uma linha (caule, galho, alça).
## As peças pequenas entram num Batch: várias formas viram UMA malha, com a cor
## em cada vértice, e a placa desenha tudo de uma vez (um desenho, e não um por
## peça). Nada daqui conhece a cidade nem o tema.

static var _cache: Dictionary[String, ArrayMesh] = {}


## Junta várias formas numa malha só, com cor por vértice. O material de quem
## usa precisa ler a cor do vértice (HomeMaterials.vertex_colored e afins).
class Batch:
	extends RefCounted
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func vertex(at: Vector3, normal: Vector3, color: Color, uv: Vector2 = Vector2.ZERO) -> int:
		verts.append(at)
		normals.append(normal.normalized())
		colors.append(color)
		uvs.append(uv)
		return verts.size() - 1

	## Um triângulo. A Godot desenha a frente no sentido horário; a ordem é
	## acertada pela normal dos vértices, então quem chama não precisa pensar nisso.
	func triangle(a: int, b: int, c: int) -> void:
		var front := (verts[c] - verts[a]).cross(verts[b] - verts[a])
		if front.dot(normals[a] + normals[b] + normals[c]) < 0.0:
			indices.append_array([a, c, b])
		else:
			indices.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int) -> void:
		triangle(a, b, c)
		triangle(a, c, d)

	## Copia uma malha pronta (BoxMesh, CylinderMesh, soft_box...) para dentro,
	## na posição "xform" e pintada de "color". Sem espelhar (escala negativa).
	func add_mesh(mesh: Mesh, xform: Transform3D, color: Color) -> void:
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var src_uvs = arrays[Mesh.ARRAY_TEX_UV]
			var src_indices = arrays[Mesh.ARRAY_INDEX]
			var offset := verts.size()
			var normal_basis := xform.basis.inverse().transposed()
			for i in src_verts.size():
				verts.append(xform * src_verts[i])
				normals.append((normal_basis * src_normals[i]).normalized())
				colors.append(color)
				uvs.append(src_uvs[i] if src_uvs != null else Vector2.ZERO)
			if src_indices == null:
				for i in src_verts.size():
					indices.append(offset + i)
			else:
				for index in src_indices:
					indices.append(offset + index)

	## Uma caixa reta (BoxMesh) já posicionada.
	func add_box(box_size: Vector3, xform: Transform3D, color: Color) -> void:
		var box := BoxMesh.new()
		box.size = box_size
		add_mesh(box, xform, color)

	func is_empty() -> bool:
		return verts.is_empty()

	## A malha pronta. "tangents": calcula as tangentes (para material com relevo
	## pelo UV, como o tapete).
	func commit(tangents: bool = false) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if not tangents:
			return mesh
		var tool := SurfaceTool.new()
		tool.create_from(mesh, 0)
		tool.generate_tangents()
		return tool.commit()


## Caixa de cantos arredondados, com origem no meio.
##   - "radius": o raio dos cantos (limitado à metade do lado menor);
##   - "puff": quanto o meio de cada face sai para fora, por eixo (x = as faces
##     da esquerda e da direita, y = em cima e embaixo, z = frente e trás).
##     Almofada: Vector3(0.01, 0.01, 0.05). As bordas não se mexem.
## A malha é guardada: caixas iguais usam a mesma.
static func soft_box(box_size: Vector3, radius: float, puff: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var key := "soft|%s|%.4f|%s" % [box_size, radius, puff]
	if _cache.has(key):
		return _cache[key]
	var half := box_size / 2.0
	var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.999)
	var inner := half - Vector3.ONE * r
	var batch := Batch.new()
	for axis in 3:
		for sign_value in [-1.0, 1.0]:
			_soft_face(batch, axis, sign_value, half, inner, r, puff)
	var mesh := batch.commit(true)
	_cache[key] = mesh
	return mesh


## Uma face da soft_box: uma grade com mais pontos perto das bordas (onde a
## curva do canto precisa) e alguns no meio (onde a face estufa).
static func _soft_face(batch: Batch, axis: int, sign_value: float, half: Vector3, inner: Vector3, r: float, puff: Vector3) -> void:
	var b := (axis + 1) % 3
	var c := (axis + 2) % 3
	var samples_b := _soft_samples(half[b], r)
	var samples_c := _soft_samples(half[c], r)
	var rows := samples_b.size()
	var cols := samples_c.size()
	var grid: Array[Vector3] = []
	var round_normals: Array[Vector3] = []
	for i in rows:
		for j in cols:
			var p := Vector3.ZERO
			p[axis] = sign_value * half[axis]
			p[b] = samples_b[i]
			p[c] = samples_c[j]
			var core := p.clamp(-inner, inner)
			var n := (p - core).normalized()
			var at := core + n * r
			# A face estufa no meio; (1 - t²)² chega a zero na borda sem quina.
			var wb := 1.0 - pow(samples_b[i] / half[b], 2.0)
			var wc := 1.0 - pow(samples_c[j] / half[c], 2.0)
			at[axis] += sign_value * puff[axis] * wb * wb * wc * wc
			grid.append(at)
			round_normals.append(n)
	var first := batch.verts.size()
	for i in rows:
		for j in cols:
			var n: Vector3 = round_normals[i * cols + j]
			if i > 0 and i < rows - 1 and j > 0 and j < cols - 1 and puff[axis] > 0.0:
				# No meio da face estufada, a normal vem da própria forma.
				var du: Vector3 = grid[(i + 1) * cols + j] - grid[(i - 1) * cols + j]
				var dv: Vector3 = grid[i * cols + j + 1] - grid[i * cols + j - 1]
				var shaped := du.cross(dv).normalized()
				n = shaped if shaped.dot(n) > 0.0 else -shaped
			var uv := Vector2((samples_c[j] + half[c]) / (2.0 * half[c]), (samples_b[i] + half[b]) / (2.0 * half[b]))
			batch.vertex(grid[i * cols + j], n, Color.WHITE, uv)
	for i in rows - 1:
		for j in cols - 1:
			var a := first + i * cols + j
			batch.quad(a, a + cols, a + cols + 1, a + 1)


## Os pontos de um lado da face: 4 em cada curva de canto e 5 no meio reto.
static func _soft_samples(h: float, r: float) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	const ARC: int = 4
	const MIDDLE: int = 5
	for i in ARC + 1:
		values.append(-h + r * float(i) / ARC)
	var inner := h - r
	for i in range(1, MIDDLE):
		values.append(-inner + 2.0 * inner * float(i) / MIDDLE)
	for i in ARC + 1:
		values.append(h - r + r * float(i) / ARC)
	return values


## Cano fino sobre uma linha (caule, galho): "radii" dá o raio em cada ponto
## (um valor só = o mesmo em todos). Poucos lados: é coisa fina.
static func tube(batch: Batch, points: PackedVector3Array, radii: PackedFloat32Array, color: Color, sides: int = 5) -> void:
	if points.size() < 2:
		return
	var rings: Array[PackedInt32Array] = []
	var side := Vector3.RIGHT
	for i in points.size():
		var ahead := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		var forward := ahead.normalized()
		# Um lado que não gira de um ponto para o outro (sem "torcer" o cano).
		side = (side - forward * side.dot(forward))
		if side.length() < 0.01:
			side = forward.cross(Vector3.UP if absf(forward.y) < 0.9 else Vector3.RIGHT)
		side = side.normalized()
		var up := forward.cross(side)
		var radius: float = radii[mini(i, radii.size() - 1)]
		var ring := PackedInt32Array()
		for k in sides:
			var angle := TAU * k / sides
			var n := side * cos(angle) + up * sin(angle)
			ring.append(batch.vertex(points[i] + n * radius, n, color))
		rings.append(ring)
	for i in points.size() - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			batch.quad(rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k])


## Um livro com a lombada virada para +Z (para quem olha a estante): duas capas
## de "color", a lombada com uma faixa clara (o título) e o miolo de papel.
## "book_size" = (espessura, altura, profundidade). A origem fica embaixo, no meio.
static func book(batch: Batch, book_size: Vector3, xform: Transform3D, color: Color, paper: Color = Color(0.86, 0.82, 0.72)) -> void:
	var t := book_size.x
	var h := book_size.y
	var d := book_size.z
	const COVER: float = 0.003
	for side in [-1.0, 1.0]:
		batch.add_box(Vector3(COVER, h, d), xform * Transform3D(Basis(), Vector3(side * (t - COVER) / 2.0, h / 2.0, 0.0)), color)
	batch.add_box(Vector3(t, h, COVER), xform * Transform3D(Basis(), Vector3(0.0, h / 2.0, d / 2.0 - COVER / 2.0)), color)
	# A faixa do título, um pouco para fora da lombada.
	var band := color.lightened(0.45) if color.get_luminance() < 0.35 else color.darkened(0.45)
	batch.add_box(Vector3(t * 0.7, h * 0.12, 0.002), xform * Transform3D(Basis(), Vector3(0.0, h * 0.72, d / 2.0 + 0.001)), band)
	batch.add_box(Vector3(t - COVER * 2.0, h - 0.008, d - COVER - 0.004),
			xform * Transform3D(Basis(), Vector3(0.0, h / 2.0, -0.002)), paper)


## Um pano caído (manta) sobre uma linha "path": a linha é o meio do pano, de uma
## ponta à outra (já um pouco acima do que ele cobre), e "across" é a direção
## da largura. "core" é um ponto DENTRO do que o pano cobre (no sofá: no meio
## do estofado); as dobras só saem para longe dele, para não entrar no
## estofado. As dobras crescem ao longo do pano ("folds": quantas na largura;
## "fold_depth": a altura no começo e no fim). Material dos dois lados.
static func drape(path: PackedVector3Array, across: Vector3, core: Vector3, width: float, folds: float,
		fold_depth: Vector2, color: Color) -> ArrayMesh:
	var smooth := _catmull(path, 6)
	var rows := smooth.size()
	const COLS: int = 16
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, rows):
		lengths.append(lengths[i - 1] + smooth[i].distance_to(smooth[i - 1]))
	var total := lengths[rows - 1]
	var grid: Array[Vector3] = []
	var outs: Array[Vector3] = []
	var side := across.normalized()
	for i in rows:
		var t := lengths[i] / total
		var forward := (smooth[mini(i + 1, rows - 1)] - smooth[maxi(i - 1, 0)]).normalized()
		var out := forward.cross(side).normalized()
		if out.dot(smooth[i] - core) < 0.0:
			out = -out
		outs.append(out)
		var depth := lerpf(fold_depth.x, fold_depth.y, smoothstep(0.3, 1.0, t))
		for j in COLS:
			var u := float(j) / (COLS - 1) * 2.0 - 1.0
			# Dobras com a fase andando ao longo do pano (não ficam retas); a borda
			# encosta um pouco no que o pano cobre.
			var wave := (0.5 + 0.5 * sin(u * folds * PI + t * 6.0)) * depth - pow(absf(u), 4.0) * depth * 0.4
			grid.append(smooth[i] + side * u * width / 2.0 + out * wave)
	var batch := Batch.new()
	for i in rows:
		for j in COLS:
			var du := grid[mini(i + 1, rows - 1) * COLS + j] - grid[maxi(i - 1, 0) * COLS + j]
			var dv := grid[i * COLS + mini(j + 1, COLS - 1)] - grid[i * COLS + maxi(j - 1, 0)]
			var n := dv.cross(du).normalized()
			if n.dot(outs[i]) < 0.0:
				n = -n
			var shade := 0.92 + 0.08 * sin(float(j) * 1.7 + float(i) * 0.6)
			batch.vertex(grid[i * COLS + j], n, Color(color.r * shade, color.g * shade, color.b * shade),
					Vector2(float(j) / (COLS - 1), lengths[i] / total))
	for i in rows - 1:
		for j in COLS - 1:
			var a := i * COLS + j
			batch.quad(a, a + COLS, a + COLS + 1, a + 1)
	return batch.commit()


## A linha passando suave pelos pontos (Catmull-Rom), "steps" pedaços entre dois pontos.
static func _catmull(points: PackedVector3Array, steps: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	var count := points.size()
	for i in count - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, count - 1)]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	result.append(points[count - 1])
	return result
