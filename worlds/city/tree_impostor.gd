class_name TreeImpostor
extends MeshInstance3D
## Uma árvore da cidade, feita como "impostora": só um retângulo com a foto da
## árvore (tree_impostor.gdshader escolhe a foto certa para o ângulo de quem
## olha). A árvore de verdade (jacarandá da Poly Haven, CC0, ~4 milhões de
## triângulos) só foi usada para tirar as fotos, com tools/make_tree_impostor.gd.
##
## Uso:  var tree := TreeImpostor.new();  tree.height = 6.0;  add_child(tree)
## A origem do nó fica no chão, na base do tronco. Gire o nó para variar a
## árvore (cada giro mostra outro lado).
##
## Fase 15.7: outro atlas (ex.: o pinheiro do bioma, numa MultiMesh) usa as
## funções estáticas info_for(), make_quad() e make_material(). O nó de sempre
## continua com a jacarandá, sem tinta e sem vento.

const ATLAS: Texture2D = preload("res://assets/generated/tree_impostor.png")
## Medidas gravadas pelo gerador junto com a imagem.
const INFO: JSON = preload("res://assets/generated/tree_impostor.json")
const SHADER: Shader = preload("res://worlds/city/tree_impostor.gdshader")

## Altura da árvore, em metros.
var height: float = 6.0

static var _material: ShaderMaterial


func _ready() -> void:
	var info: Dictionary = INFO.data
	var quad := make_quad(info, height)
	mesh = quad
	material_override = _shared_material(info)
	# Um retângulo que gira pode sair do "volume" que a Godot calcula para
	# decidir se desenha: aumentamos a margem.
	extra_cull_margin = quad.size.x / 2.0


## As medidas de um atlas: o .json que o gerador grava ao lado da imagem
## (mesmo nome, outra extensão). {} se não existir.
static func info_for(atlas_path: String) -> Dictionary:
	var json := load(atlas_path.get_basename() + ".json") as JSON
	return json.data if json != null else {}


## O retângulo de uma árvore com "tree_height" metros de altura, com a base do
## tronco na origem.
static func make_quad(info: Dictionary, tree_height: float) -> QuadMesh:
	# O quadro da foto é quadrado e maior que a árvore: descobrimos o tamanho
	# dele (em metros) para a árvore ficar com "tree_height" de altura.
	var frame_size := tree_height * float(info["frame_meters"]) / float(info["tree_height"])
	var quad := QuadMesh.new()
	quad.size = Vector2(frame_size, frame_size)
	# A base do tronco fica na origem do nó.
	quad.center_offset = Vector3(0.0, frame_size / 2.0 - float(info["tree_base"]) * frame_size, 0.0)
	return quad


## Material de um atlas, com tinta e vento. "sway_height": a altura da árvore
## no retângulo (sem a escala da instância); "sway": quanto a ponta anda (m).
static func make_material(atlas: Texture2D, info: Dictionary, tint: Color = Color.WHITE,
		sway: float = 0.0, sway_height: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("atlas", atlas)
	material.set_shader_parameter("frames", float(info["frames"]))
	material.set_shader_parameter("columns", float(info["columns"]))
	material.set_shader_parameter("tint", tint)  # Color: a Godot converte de sRGB (source_color)
	material.set_shader_parameter("sway_amount", sway)
	material.set_shader_parameter("sway_height", maxf(sway_height, 0.01))
	return material


static func _shared_material(info: Dictionary) -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("atlas", ATLAS)
		_material.set_shader_parameter("frames", float(info["frames"]))
		_material.set_shader_parameter("columns", float(info["columns"]))
	return _material
