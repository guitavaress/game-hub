class_name TreeImpostor
extends RefCounted
## As árvores "impostoras": só um retângulo com a foto da árvore
## (tree_impostor.gdshader escolhe a foto certa para o ângulo de quem olha).
## As fotos (8 ângulos num atlas) são tiradas por tools/make_tree_impostor.gd.
##
## Fase 15.7: o atlas do pinheiro do bioma, numa MultiMesh. Fase 19.3: não há
## mais árvore que seja SÓ a foto (a jacarandá das floreiras saiu): a foto é a
## árvore de longe, e o modelo do Blender, a de perto (veja TreeModel). Aqui
## ficam só as funções que montam a foto: info_for(), make_quad() e make_material().

const SHADER: Shader = preload("res://worlds/city/tree_impostor.gdshader")


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
