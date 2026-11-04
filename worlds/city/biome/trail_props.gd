class_name TrailProps
## Peças da trilha da montanha (Fase 17.7), sem nó: pedras irregulares prontas
## e a junção de muitas peças numa malha só por material (um desenho por
## material, em vez de um por pedra).

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


## Um tronco (cilindro) de "from" a "to", com o raio dado.
static func log_transform(from: Vector3, to: Vector3) -> Transform3D:
	var axis := (to - from).normalized()
	var basis := Basis(Quaternion(Vector3.UP, axis)) if absf(axis.dot(Vector3.UP)) < 0.999 else Basis.IDENTITY
	return Transform3D(basis, (from + to) / 2.0)


static func cylinder(radius_bottom: float, radius_top: float, height: float, segments: int = 10) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius_bottom
	mesh.top_radius = radius_top
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
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
