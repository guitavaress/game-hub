class_name TrailModels
## Os modelos da trilha feitos no Blender (Fase 17.7.1): a fogueira, o
## terraço de pedra, os bancos e o monte de pedras. Cada .glb sai de um script
## refazível em tools/blender/ e tem uma malha por material (um nó por malha,
## com o nome do material: "stone", "wood", "snow"...).
##
## Aqui só se lê: as malhas de cada arquivo são carregadas uma vez e ficam
## guardadas. Quem monta (a fogueira, o TrailDressing) junta as peças por
## material no TrailProps.Batch, como antes.
##
## Materiais:
##   - pedra e neve: as texturas PBR do projeto (projetadas pelo mundo, como o
##     resto da montanha), escurecidas pela cor dos vértices, que o Blender
##     assou com os cantos escuros (oclusão), o tom de cada pedra e a fuligem;
##   - madeira (17.8: bancos, deque, abrigo): a Wood049 da ambientCG, com o
##     veio de cada tábua lido do UV (em metros, ao longo da tábua) e a cor dos
##     vértices (tom e cantos escuros), tingida por quem usa (escura e gasta);
##   - latão e ferro (17.8: a luneta, as lanternas): metal liso, escurecido
##     pela cor dos vértices;
##   - lenha e brasa: as do próprio .glb (a textura assada no Blender: casca,
##     carvão e o brilho da brasa).
##
## 17.8: os modelos de outro grupo vêm com a pasta no nome ("lookout/deck" lê
## assets/models/lookout/deck.glb); sem pasta, são os da trilha.

const FOLDER: String = "res://assets/models/trail/"
const MODELS: String = "res://assets/models/"
## A madeira dos modelos (17.8) e o tamanho de uma repetição dela (m).
const WOOD_TEXTURE: String = "Wood049"
const WOOD_METERS: float = 1.0
## O Blender grava a cor dos vértices dividida por isto (para caber de 0 a 1
## no glTF, com os tons das pedras mais claros que a textura); aqui ela volta.
const VERTEX_GAIN: float = 1.6

static var _meshes: Dictionary = {}  # "arquivo/nó" -> Mesh
static var _materials: Dictionary = {}
static var _arrays: Dictionary = {}  # "arquivo/nó" -> os arrays da malha


## A malha "part" do arquivo "file" (sem a extensão), ou null.
static func mesh(file: String, part: String) -> Mesh:
	if not _meshes.has(file + "/"):
		_meshes[file + "/"] = true
		var path := (MODELS if "/" in file else FOLDER) + file + ".glb"
		var scene: PackedScene = ResourceLoader.load_threaded_get(path) 				if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE 				else load(path)
		if scene != null:
			var root := scene.instantiate()
			for node in root.find_children("*", "MeshInstance3D", true, false):
				_meshes[file + "/" + String(node.name)] = (node as MeshInstance3D).mesh
			root.free()
	return _meshes.get(file + "/" + part)


## Os arrays da malha "part" (lidos uma vez e guardados: com janela, ler a
## malha do servidor de desenho custa). Para o TrailProps.Merge.
static func arrays(file: String, part: String) -> Array:
	var key := file + "/" + part
	if not _arrays.has(key):
		var found := mesh(file, part)
		_arrays[key] = found.surface_get_arrays(0) if found != null else []
	return _arrays[key]


## Começa a carregar os arquivos em segundo plano (o mirante pede os seus no
## planejamento; quando a montagem chega neles, já estão prontos).
static func prefetch(files: Array[String]) -> void:
	for file in files:
		var path := (MODELS if "/" in file else FOLDER) + file + ".glb"
		if not _meshes.has(file + "/") and not ResourceLoader.has_cached(path):
			ResourceLoader.load_threaded_request(path)


## O material que veio no .glb com a malha (a textura assada).
static func own_material(file: String, part: String) -> Material:
	var found := mesh(file, part)
	return found.surface_get_material(0) if found != null else null


## Uma textura PBR do projeto (Rock058, Snow010A...) que se multiplica pela cor
## dos vértices. "meters" = o tamanho de uma repetição da textura.
static func vertex_tinted(folder: String, meters: float, tint: Color) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [folder, meters, tint.to_html()]
	if not _materials.has(key):
		var material: StandardMaterial3D = CityDecor.pbr_material(folder, meters, tint).duplicate()
		material.albedo_color = Color(tint.r * VERTEX_GAIN, tint.g * VERTEX_GAIN, tint.b * VERTEX_GAIN)
		material.vertex_color_use_as_albedo = true
		_materials[key] = material
	return _materials[key]


## Um material liso que é só a cor dos vértices (a cinza da fogueira), tingido
## por quem usa (17.10: a cinza escurece e esfria).
static func vertex_only(roughness: float, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "liso|%.2f|%s" % [roughness, tint.to_html()]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(tint.r * VERTEX_GAIN, tint.g * VERTEX_GAIN, tint.b * VERTEX_GAIN)
		material.vertex_color_use_as_albedo = true
		material.roughness = roughness
		_materials[key] = material
	return _materials[key]


## A madeira dos modelos (17.8): a Wood049, com o veio pelo UV (o x de cada
## tábua) e a cor dos vértices; "color" escurece e esquenta o castanho
## acinzentado da textura (a madeira escura e gasta da referência 04);
## "roughness" abaixo de 1 deixa a madeira mais lisa, como molhada (o deque).
static func wood(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
	var key := "madeira|%s|%.2f" % [color.to_html(), roughness]
	if not _materials.has(key):
		var textures := CityDecor.pbr_textures(WOOD_TEXTURE)
		var material := StandardMaterial3D.new()
		material.albedo_texture = textures["albedo"]
		material.albedo_color = Color(color.r * VERTEX_GAIN, color.g * VERTEX_GAIN, color.b * VERTEX_GAIN)
		material.vertex_color_use_as_albedo = true
		material.normal_enabled = true
		material.normal_texture = textures["normal"]
		material.normal_scale = 0.9
		material.roughness_texture = textures["roughness"]
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.roughness = roughness
		material.uv1_scale = Vector3.ONE / WOOD_METERS
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials[key] = material
	return _materials[key]


## Metal liso (o latão da luneta, o ferro das lanternas e das ferragens),
## escurecido pela cor dos vértices (os cantos).
static func metal(color: Color, roughness: float, metallic: float = 1.0) -> StandardMaterial3D:
	var key := "metal|%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color.r * VERTEX_GAIN, color.g * VERTEX_GAIN, color.b * VERTEX_GAIN)
		material.vertex_color_use_as_albedo = true
		material.metallic = metallic
		material.metallic_specular = 0.6
		material.roughness = roughness
		_materials[key] = material
	return _materials[key]


## Uma cópia da malha esticada por "scale" (as normais corrigidas, para a peça
## poder entrar no TrailProps.Batch sem escala), com o UV deslocado ("uv_shift":
## cada tábua mostra outro pedaço do veio) e a cor dos vértices vezes "tone".
static func stretched(mesh: Mesh, scale: Vector3, uv_shift: Vector2 = Vector2.ZERO, tone: float = 1.0) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null 			else PackedFloat32Array()
	var inverse := Vector3(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z)
	for i in vertices.size():
		vertices[i] *= scale
		var normal := (normals[i] * inverse).normalized()
		normals[i] = normal
		if tangents.size() == vertices.size() * 4:
			# A tangente segue a peça (como uma direção) e fica de pé na normal nova.
			var tangent := Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2]) * scale
			tangent = (tangent - normal * normal.dot(tangent)).normalized()
			tangents[i * 4] = tangent.x
			tangents[i * 4 + 1] = tangent.y
			tangents[i * 4 + 2] = tangent.z
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents if not tangents.is_empty() else null
	if uv_shift != Vector2.ZERO and arrays[Mesh.ARRAY_TEX_UV] != null:
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in uvs.size():
			uvs[i] += uv_shift
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if tone != 1.0 and arrays[Mesh.ARRAY_COLOR] != null:
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in colors.size():
			colors[i] = Color(colors[i].r * tone, colors[i].g * tone, colors[i].b * tone, colors[i].a)
		arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
