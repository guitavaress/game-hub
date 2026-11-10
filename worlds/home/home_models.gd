class_name HomeModels
extends RefCounted
## Os modelos da casa feitos no Blender (Fase 17.9.2): a poltrona e a lareira
## da cabana (assets/models/home/, gerados por tools/blender/). O contrato está
## no README.md da pasta: cada .glb tem uma malha por material, com o nome dele
## ("wood", "fabric", "stone", "soot", "iron"), já no referencial da peça.
##
## Aqui só se lê. Cada arquivo é aberto UMA vez e as malhas ficam guardadas: a
## mesma malha serve a todas as cópias (as duas poltronas usam a mesma), sem
## ler os vértices de volta da placa (a lição da 17.8). Quem monta põe cada
## malha num MeshInstance3D com o material da casa: um desenho por material.
##
## A cor dos vértices: o Blender grava o tom × a oclusão (os cantos escuros)
## dividido por VERTEX_GAIN, em cor LINEAR. O material multiplica o tom dele
## pelo ganho, e assim a peça sai com o tom que a casa escolher.
##
## Nada daqui conhece a cidade (o leitor da trilha, TrailModels, é dela).

const FOLDER: String = "res://assets/models/home/"
const AMBIENTCG: String = "res://assets/ambientcg/"
const VERTEX_GAIN: float = 1.6
## A madeira dos modelos: a Wood049, com o veio pelo UV (em metros, ao longo
## da peça): uma repetição por metro.
const WOOD_TEXTURE: String = "Wood049"
const WOOD_METERS: float = 1.0
## A pedra: a Rock058, projetada pelo mundo (triplanar).
const STONE_TEXTURE: String = "Rock058"

static var _meshes: Dictionary = {}  # "arquivo/parte" -> Mesh
static var _materials: Dictionary = {}


## A malha "part" do arquivo "file" (sem a extensão), ou null.
static func mesh(file: String, part: String) -> Mesh:
	if not _meshes.has(file + "/"):
		_meshes[file + "/"] = true
		var scene := load(FOLDER + file + ".glb") as PackedScene
		if scene != null:
			var root := scene.instantiate()
			for node in root.find_children("*", "MeshInstance3D", true, false):
				_meshes[file + "/" + String(node.name)] = (node as MeshInstance3D).mesh
			root.free()
	return _meshes.get(file + "/" + part)


## Põe a malha "part" de "file" dentro de "parent", com o material dado. A
## peça faz sombra (é um móvel de verdade).
static func place(parent: Node3D, file: String, part: String, material: Material,
		at: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var found := mesh(file, part)
	if found == null:
		push_warning("HomeModels: não achei %s em %s.glb." % [part, file])
		return null
	var node := MeshInstance3D.new()
	node.name = "%s_%s" % [file.capitalize().replace(" ", ""), part.capitalize()]
	node.mesh = found
	node.material_override = material
	node.transform = at
	node.set_meta("home_model", file + "/" + part)
	parent.add_child(node)
	return node


## A madeira dos modelos: a Wood049 pelo UV, vezes a cor dos vértices; "tint"
## (linear) é o tom, "roughness" abaixo de 1 deixa mais lisa (encerada).
static func wood(tint: Color, roughness: float = 0.6) -> StandardMaterial3D:
	var key := "wood|%s|%.2f" % [tint.to_html(), roughness]
	if not _materials.has(key):
		var material := _with_vertex_color(StandardMaterial3D.new(), tint)
		var base := "%s%s/%s_1K-JPG_" % [AMBIENTCG, WOOD_TEXTURE, WOOD_TEXTURE]
		material.albedo_texture = load(base + "Color.jpg")
		material.normal_enabled = true
		material.normal_texture = load(base + "NormalGL.jpg")
		material.normal_scale = 0.9
		material.roughness_texture = load(base + "Roughness.jpg")
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.roughness = roughness
		material.uv1_scale = Vector3.ONE / WOOD_METERS
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials[key] = material
	return _materials[key]


## A pedra: a Rock058 projetada pelo mundo (HomeMaterials.pbr), vezes a cor dos
## vértices (o tom de cada pedra e as juntas escuras). "meters" = o tamanho de
## uma repetição; "normal" = a força do relevo da textura.
static func stone(tint: Color, meters: float = 1.0, normal: float = 1.0) -> StandardMaterial3D:
	var key := "stone|%s|%.2f|%.2f" % [tint.to_html(), meters, normal]
	if not _materials.has(key):
		var material := HomeMaterials.pbr(STONE_TEXTURE, meters).duplicate() as StandardMaterial3D
		material.normal_scale = normal
		_materials[key] = _with_vertex_color(material, tint)
	return _materials[key]


## O tecido (o mesmo relevo de trama da casa), vezes a cor dos vértices.
## "weave" = a força da trama (a padrão, com luz rasante, parece áspera).
static func fabric(tint: Color, weave: float = 0.5) -> StandardMaterial3D:
	var key := "fabric|%s|%.2f" % [tint.to_html(), weave]
	if not _materials.has(key):
		var material := HomeMaterials.fabric(Color.WHITE).duplicate() as StandardMaterial3D
		material.normal_scale = weave
		_materials[key] = _with_vertex_color(material, tint)
	return _materials[key]


## Fosco liso (a fuligem do fundo da lareira), vezes a cor dos vértices.
static func matte(tint: Color, roughness: float = 1.0) -> StandardMaterial3D:
	var key := "matte|%s|%.2f" % [tint.to_html(), roughness]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.roughness = roughness
		_materials[key] = _with_vertex_color(material, tint)
	return _materials[key]


## Metal (o ferro da grade), vezes a cor dos vértices.
static func metal(tint: Color, roughness: float = 0.65, metallic: float = 0.7) -> StandardMaterial3D:
	var key := "metal|%s|%.2f|%.2f" % [tint.to_html(), roughness, metallic]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.metallic = metallic
		material.roughness = roughness
		_materials[key] = _with_vertex_color(material, tint)
	return _materials[key]


## Liga a cor dos vértices (linear) e põe o tom vezes o ganho no albedo.
static func _with_vertex_color(material: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	material.albedo_color = Color(tint.r * VERTEX_GAIN, tint.g * VERTEX_GAIN, tint.b * VERTEX_GAIN)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	return material
