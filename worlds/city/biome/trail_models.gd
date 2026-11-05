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
##   - madeira dos bancos: a madeira da casa (home_wood.gdshader), com o veio
##     de cada tábua lido do UV e a cor dos vértices (tom e cantos escuros);
##   - lenha e brasa: as do próprio .glb (a textura assada no Blender: casca,
##     carvão e o brilho da brasa).

const FOLDER: String = "res://assets/models/trail/"
## O Blender grava a cor dos vértices dividida por isto (para caber de 0 a 1
## no glTF, com os tons das pedras mais claros que a textura); aqui ela volta.
const VERTEX_GAIN: float = 1.6

static var _meshes: Dictionary = {}  # "arquivo/nó" -> Mesh
static var _materials: Dictionary = {}


## A malha "part" do arquivo "file" (sem a extensão), ou null.
static func mesh(file: String, part: String) -> Mesh:
	if not _meshes.has(file + "/"):
		_meshes[file + "/"] = true
		var scene: PackedScene = load(FOLDER + file + ".glb")
		if scene != null:
			var root := scene.instantiate()
			for node in root.find_children("*", "MeshInstance3D", true, false):
				_meshes[file + "/" + String(node.name)] = (node as MeshInstance3D).mesh
			root.free()
	return _meshes.get(file + "/" + part)


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


## Um material liso que é só a cor dos vértices (a cinza da fogueira).
static func vertex_only(roughness: float) -> StandardMaterial3D:
	var key := "liso|%.2f" % roughness
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(VERTEX_GAIN, VERTEX_GAIN, VERTEX_GAIN)
		material.vertex_color_use_as_albedo = true
		material.roughness = roughness
		_materials[key] = material
	return _materials[key]


## A madeira dos bancos: a da casa, com o veio pelo UV e a cor dos vértices.
static func wood(color: Color) -> ShaderMaterial:
	var key := "madeira|%s" % color.to_html()
	if not _materials.has(key):
		var material := (HomeMaterials.wood(color, false, 0.85) as ShaderMaterial).duplicate()
		material.set_shader_parameter("grain_from_uv", true)
		material.set_shader_parameter("vertex_gain", VERTEX_GAIN)
		# Ao relento, uma tábua difere mais da outra que num móvel da casa.
		material.set_shader_parameter("variation", 0.22)
		_materials[key] = material
	return _materials[key]
