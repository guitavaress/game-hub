class_name TrailProps
## Peças da trilha da montanha (Fase 17.7), sem nó: pedras irregulares prontas
## (as da queda congelada; a fogueira, os bancos e o monte de pedras são
## modelos do Blender desde a 17.7.1, em TrailModels) e a junção de muitas
## peças numa malha só por material (um desenho por material, em vez de um
## por peça).

## A ondulação das pedras: um ruído só para todas, com a semente de cada uma.
static var _noise: FastNoiseLite


## Uma pedra irregular do tamanho "size" (metros), com a base achatada para
## pousar no chão. "angular" (0 a 1) deixa as faces mais quebradas; a semente
## muda o desenho. As normais já saem com o tamanho final (sem escala depois).
static func rock(size: Vector3, seed: int, angular: float = 0.35) -> ArrayMesh:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14 if angular < 0.5 else 9
	sphere.rings = 7 if angular < 0.5 else 5
	var arrays := sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var offset := Vector3(seed * 3.17, seed * 1.73, seed * 2.41)
	for i in vertices.size():
		var p := vertices[i]
		var bump := 1.0 + angular * 0.45 * _noise.get_noise_3dv(p * 2.2 + offset) \
				+ 0.08 * _noise.get_noise_3dv(p * 6.0 + offset)
		p *= bump
		p.y = maxf(p.y, -0.32)  # base achatada
		vertices[i] = p * size
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var surface := SurfaceTool.new()
	surface.create_from_arrays(arrays)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


static func cylinder(radius_bottom: float, radius_top: float, height: float, segments: int = 10) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius_bottom
	mesh.top_radius = radius_top
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


## Junta peças (malha + lugar) por material e cria um MeshInstance3D por
## material. As peças não podem ter escala (as normais não seriam corrigidas).
class Batch:
	var _parts: Dictionary = {}  # Material -> SurfaceTool

	func add(mesh: Mesh, transform: Transform3D, material: Material) -> void:
		# Toda peça entra com índice: se a primeira viesse sem e as outras com,
		# o SurfaceTool só desenharia as que têm (a primeira sumia).
		if mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == null:
			var indexed := SurfaceTool.new()
			indexed.create_from(mesh, 0)
			indexed.index()
			mesh = indexed.commit()
		if not _parts.has(material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			_parts[material] = tool
		(_parts[material] as SurfaceTool).append_from(mesh, 0, transform)

	## Cria os nós em "parent" (nomes "<prefixo>0", "<prefixo>1"...).
	func build(parent: Node3D, prefix: String, visibility_end: float) -> Array[MeshInstance3D]:
		var result: Array[MeshInstance3D] = []
		for material: Material in _parts:
			var instance := MeshInstance3D.new()
			instance.name = "%s%d" % [prefix, result.size()]
			instance.mesh = (_parts[material] as SurfaceTool).commit()
			instance.material_override = material
			instance.visibility_range_end = visibility_end
			parent.add_child(instance)
			result.append(instance)
		_parts.clear()
		return result


## Junta peças direto em arrays (17.8), sem ler a malha de volta a cada peça:
## cada peça entra como os arrays de uma malha (TrailModels.arrays, lidos uma
## vez), com lugar, esticão (as normais corrigidas), deslocamento do UV e tom
## da cor dos vértices. Com janela, ler uma malha do servidor de desenho custa:
## o deque tem centenas de tábuas, e o Batch lia cada uma.
class Merge:
	var _vertices := PackedVector3Array()
	var _normals := PackedVector3Array()
	var _tangents := PackedFloat32Array()
	var _uvs := PackedVector2Array()
	var _colors := PackedColorArray()
	var _indices := PackedInt32Array()

	func add(source: Array, transform: Transform3D, scale: Vector3 = Vector3.ONE,
			uv_shift: Vector2 = Vector2.ZERO, tone: float = 1.0) -> void:
		var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = source[Mesh.ARRAY_TANGENT] if source[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var uvs: PackedVector2Array = source[Mesh.ARRAY_TEX_UV] if source[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var colors: PackedColorArray = source[Mesh.ARRAY_COLOR] if source[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var first := _vertices.size()
		var count := vertices.size()
		var inverse := Vector3(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z)
		var basis := transform.basis
		var has_tangents := tangents.size() == count * 4
		_vertices.resize(first + count)
		_normals.resize(first + count)
		_tangents.resize((first + count) * 4)
		_uvs.resize(first + count)
		_colors.resize(first + count)
		for i in count:
			_vertices[first + i] = transform * (vertices[i] * scale)
			var normal := (basis * (normals[i] * inverse)).normalized()
			_normals[first + i] = normal
			var tangent := Vector3.RIGHT
			var sign := 1.0
			if has_tangents:
				tangent = basis * (Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2]) * scale)
				sign = tangents[i * 4 + 3]
			tangent = (tangent - normal * normal.dot(tangent)).normalized()
			var t := (first + i) * 4
			_tangents[t] = tangent.x
			_tangents[t + 1] = tangent.y
			_tangents[t + 2] = tangent.z
			_tangents[t + 3] = sign
			_uvs[first + i] = (uvs[i] + uv_shift) if not uvs.is_empty() else Vector2.ZERO
			var color := colors[i] if not colors.is_empty() else Color.WHITE
			_colors[first + i] = Color(color.r * tone, color.g * tone, color.b * tone, color.a)
		var base := _indices.size()
		_indices.resize(base + indices.size())
		for i in indices.size():
			_indices[base + i] = indices[i] + first

	func is_empty() -> bool:
		return _vertices.is_empty()

	## Cria o nó em "parent" com a malha juntada (null se não entrou nada).
	func build(parent: Node3D, node_name: String, material: Material, visibility_end: float) -> MeshInstance3D:
		if _vertices.is_empty():
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_TANGENT] = _tangents
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
		arrays[Mesh.ARRAY_COLOR] = _colors
		arrays[Mesh.ARRAY_INDEX] = _indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.name = node_name
		instance.mesh = mesh
		instance.material_override = material
		instance.visibility_range_end = visibility_end
		parent.add_child(instance)
		return instance
