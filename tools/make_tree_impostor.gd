extends SceneTree
## Gera o ATLAS das árvores impostoras: fotografa uma árvore realista (modelo
## glTF pesado, que NÃO entra no projeto) em 8 ângulos e junta as fotos numa
## imagem só (4 x 2 quadros de 512 px, fundo transparente). No jogo, cada
## árvore é só um retângulo (2 triângulos) que mostra a foto do ângulo certo
## (veja worlds/city/tree_impostor.gd).
##
## Roda uma vez, COM janela (precisa da placa de vídeo), a partir da pasta do
## projeto:
##   Godot --path . -s res://tools/make_tree_impostor.gd -- <arquivo.gltf> [saída.png]
## Saída padrão: res://assets/generated/tree_impostor.png (+ .json com as medidas).

const FRAMES: int = 8
const COLUMNS: int = 4
const FRAME_SIZE: int = 512
const DEFAULT_OUTPUT: String = "res://assets/generated/tree_impostor.png"


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Uso: -s res://tools/make_tree_impostor.gd -- <arquivo.gltf> [saída.png]")
		quit(1)
		return
	var source: String = args[0]
	var output: String = args[1] if args.size() > 1 else DEFAULT_OUTPUT
	await process_frame  # a janela principal precisa estar pronta

	# Um "estúdio" separado do resto: fundo transparente, luz neutra.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(FRAME_SIZE, FRAME_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.82, 0.84, 0.88)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	# Luz de cima e um pouco da frente (a mesma em todos os quadros, porque é
	# a árvore que gira): as folhas de dentro ficam na sombra, e a copa ganha volume.
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(20.0), 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	viewport.add_child(sun)

	print("Carregando ", source, " (pode demorar)...")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(source, state)
	if error != OK:
		push_error("Não consegui ler %s (erro %d)." % [source, error])
		quit(1)
		return
	var tree := document.generate_scene(state) as Node3D
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	pivot.add_child(tree)

	# Folhas opacas (no modelo elas vêm com "transparência", que só pesa aqui).
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null:
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Medidas da árvore e o "eixo" dela (para girar em volta do tronco).
	var box := _bounds(tree)
	var axis := Vector3(box.get_center().x, 0.0, box.get_center().z)
	tree.position = -axis
	# Copa mais ou menos redonda: o raio é a metade do lado maior da caixa (a
	# diagonal da caixa deixaria a árvore pequena no quadro).
	var radius := maxf(box.size.x, box.size.z) / 2.0
	var frame_meters := maxf(radius * 2.0, box.size.y) * 1.04
	var center_y := box.position.y + box.size.y / 2.0

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = frame_meters
	camera.near = 0.1
	camera.far = radius * 4.0 + 10.0
	camera.position = Vector3(0.0, center_y, radius * 2.0 + 5.0)
	viewport.add_child(camera)
	camera.current = true

	var atlas := Image.create(FRAME_SIZE * COLUMNS, FRAME_SIZE * (FRAMES / COLUMNS), false, Image.FORMAT_RGBA8)
	for frame in FRAMES:
		# Quadro N = a árvore vista de N x 45° (girar a árvore para trás = a
		# câmera dar a volta para frente).
		pivot.rotation.y = -frame * TAU / FRAMES
		for i in 4:
			await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()),
				Vector2i((frame % COLUMNS) * FRAME_SIZE, (frame / COLUMNS) * FRAME_SIZE))
		print("  quadro %d de %d" % [frame + 1, FRAMES])

	# Pinta a cor das bordas por baixo do transparente: de longe (mipmaps) as
	# folhas não ficam com contorno escuro.
	atlas.fix_alpha_edges()
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	atlas.save_png(absolute)

	# Medidas, para o jogo montar o retângulo do tamanho certo.
	var info := {
		"frames": FRAMES,
		"columns": COLUMNS,
		"frame_meters": frame_meters,
		"tree_height": box.size.y,
		"tree_base": (box.position.y - (center_y - frame_meters / 2.0)) / frame_meters,
		"source": source.get_file(),
	}
	var file := FileAccess.open(absolute.get_basename() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(info, "  "))
	file.close()
	print("Pronto: ", absolute, " | ", info)
	quit()


## Caixa que envolve todas as malhas (em coordenadas do mundo).
func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var child_box := mesh_instance.global_transform * mesh_instance.get_aabb()
		box = child_box if first else box.merge(child_box)
		first = false
	return box
