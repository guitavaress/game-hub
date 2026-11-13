extends "res://tools/capturar_pontos.gd"
## A AMOSTRA do pinheiro do Blender (Fase 19.2): capturas do pinheiro de hoje
## (a impostora da Poly Haven) e do novo (o TreeModel, com o pine.glb), sem
## mudar nada do jogo. Rode COM JANELA, à mão:
##
##   godot --path . -s tools/amostra_arvore.gd -- <pasta> [jogos] [bairro] [horas] [qualidade] [modo]
##
## Os cinco primeiros argumentos são os do capturar_pontos.gd (pasta SEMPRE
## fora do repositório). "modo":
##   hoje  o bairro com os pinheiros de hoje (padrão)
##   novo  os pinheiros do bairro trocados, só na memória, pelo TreeModel
##         (mesmos lugares, mesmas alturas)
## Nos dois modos, no meio da rua do pórtico (PAIR_ALONG m depois dele), ficam
## DOIS pinheiros lado a lado, da mesma altura (PAIR_HEIGHT): o de hoje à
## esquerda e o novo à direita.
## Pontos a mais, além dos do capturar_pontos (os arquivos levam o modo no
## nome do bairro, ex.: rpg-novo_par_perto_13h.png):
##   par_perto   a 8 m do par
##   par_30m     a 30 m do par
##   par_150m    a 150 m do par, do alto (60 m, por cima dos pórticos), e um
##               recorte do par ampliado 4x (..._par_150m_13h_zoom.png)
##
## A troca dos pinheiros (swap_pines) também serve à amostra da casa
## (tools/amostra_arvore_casa.gd) e à medida (tools/medir_arvores.gd).

const MODEL: String = "res://assets/models/trees/pine.glb"
const NEW_ATLAS: String = "res://assets/generated/pine_blender_impostor.png"
const OLD_ATLAS: String = "res://assets/generated/pine_impostor.png"
## A tinta e o vento do pinheiro de hoje (profiles/biomes/montanha.tres e BiomeScatter).
const OLD_TINT: Color = Color(0.45, 0.55, 0.55)
const OLD_SWAY: float = 0.18
## A tinta do pinheiro novo (a cor já vem certa da textura).
const NEW_TINT: Color = Color.WHITE
const PAIR_HEIGHT: float = 11.0
## Distância entre os dois troncos do par, e quanto o par fica para dentro do pórtico.
const PAIR_GAP: float = 7.0
const PAIR_ALONG: float = 22.0

var _pair_center: Vector3 = Vector3.INF
## De que lado do pórtico fica o ponto "portico" (+1 ou -1 no x).
var _side: float = 1.0


## Troca, só na memória, os pinheiros impostores do bairro pelo TreeModel
## (mesmos lugares, giros e alturas em metros). Devolve o TreeModel, ou null.
static func swap_pines(city: Node, district: String) -> TreeModel:
	# Sem o tipo BiomeScatter: ele depende dos autoloads, que não existem quando este script compila.
	var scatter: Node = city.find_child("BiomeScatter_" + district, true, false)
	if scatter == null:
		return null
	var old_height := float(TreeImpostor.info_for(OLD_ATLAS)["tree_height"])
	for child: Node in scatter.get_children():
		var instance := child as MultiMeshInstance3D
		if instance == null or not instance.material_override is ShaderMaterial:
			continue
		if (instance.material_override as ShaderMaterial).shader != TreeImpostor.SHADER:
			continue
		var index := int(String(instance.name).get_slice("_", 1))
		var trees := TreeModel.new()
		trees.name = "TreeModel_%d" % index
		scatter.add_child(trees)
		# A altura em metros de cada pinheiro (escala × altura do atlas velho) vira
		# a escala do modelo novo.
		var species := TreeModel.species(MODEL, NEW_ATLAS, NEW_TINT)
		var new_height := float(species["height"])
		var transforms: Array[Transform3D] = []
		var old_transforms: Array[Transform3D] = scatter.call("get_transforms", index)
		for item in old_transforms:
			var meters := item.basis.get_scale().y * old_height
			var basis := item.basis.orthonormalized().scaled(Vector3.ONE * meters / new_height)
			transforms.append(Transform3D(basis, item.origin))
		trees.setup(MODEL, NEW_ATLAS, transforms, NEW_TINT)
		instance.visible = false
		return trees
	return null


func _prepare(city: Node, area: Dictionary) -> void:
	var args := OS.get_cmdline_user_args()
	var mode := String(args[5]) if args.size() > 5 else "hoje"
	var district := String(area["id"])
	if mode == "novo":
		var trees := swap_pines(city, district)
		print("Modo novo: %s pinheiros trocados pelo modelo do Blender." %
				(str(trees.get_transforms().size()) if trees != null else "nenhum"))
	# O nome dos arquivos leva o modo (rpg-novo_praca_13h.png).
	_district_label = "%s-%s" % [district, mode]
	_add_pair(city, area)


## O par lado a lado, no meio da rua do pórtico (a que corre de leste a oeste,
## entre o bairro e a praça), PAIR_ALONG m depois dele: as câmeras olham ao
## longo da rua, e nada fica na frente. O de hoje à esquerda, o novo à direita.
func _add_pair(city: Node, area: Dictionary) -> void:
	var gate: Vector2 = area["gate"]
	var rects: Array[Rect2] = area["rects"]
	# O mesmo lado do ponto "portico" do capturar_pontos.
	_side = signf(gate.x - rects[0].get_center().x)
	if _side == 0.0:
		_side = 1.0
	_pair_center = Vector3(gate.x - _side * PAIR_ALONG, 0.0, gate.y)
	# Quem olha para -_side no x tem a direita em (0, 0, -_side).
	var right := Vector3(0.0, 0.0, -_side)
	# A impostora de hoje, como o BiomeScatter a monta.
	var info := TreeImpostor.info_for(OLD_ATLAS)
	var old := MeshInstance3D.new()
	old.name = "AmostraPinheiroHoje"
	var old_height := float(info["tree_height"])
	old.mesh = TreeImpostor.make_quad(info, old_height)
	old.material_override = TreeImpostor.make_material(load(OLD_ATLAS), info, OLD_TINT, OLD_SWAY, old_height)
	old.extra_cull_margin = (old.mesh as QuadMesh).size.x
	city.add_child(old)
	old.scale = Vector3.ONE * PAIR_HEIGHT / old_height
	old.global_position = _pair_center - right * PAIR_GAP / 2.0
	# O novo.
	var new_trees := TreeModel.new()
	new_trees.name = "AmostraPinheiroNovo"
	city.add_child(new_trees)
	var species := TreeModel.species(MODEL, NEW_ATLAS, NEW_TINT)
	var scale := PAIR_HEIGHT / float(species["height"])
	var spot := _pair_center + right * PAIR_GAP / 2.0
	var one: Array[Transform3D] = [Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), spot)]
	new_trees.setup(MODEL, NEW_ATLAS, one, NEW_TINT)


func _points(area: Dictionary) -> Array[Dictionary]:
	var points: Array[Dictionary] = super._points(area)
	if _pair_center == Vector3.INF:
		return points
	var back := Vector3(_side, 0.0, 0.0)
	points.append({"name": "par_perto", "eye": _pair_center + back * 8.0 + Vector3.UP * EYE_HEIGHT,
			"target": _pair_center + Vector3.UP * 4.0})
	points.append({"name": "par_30m", "eye": _pair_center + back * 30.0 + Vector3.UP * EYE_HEIGHT,
			"target": _pair_center + Vector3.UP * 4.5})
	# A 150 m, do alto (60 m): por cima dos pórticos da rua. Sai também um
	# recorte do par ampliado 4 vezes (os pixels de verdade, só maiores).
	points.append({"name": "par_150m", "eye": _pair_center + back * 150.0 + Vector3.UP * 60.0,
			"target": _pair_center + Vector3.UP * 5.0, "zoom": true})
	return points


## O recorte ampliado do par (só nos pontos com "zoom").
func _after_capture(image: Image, camera: Camera3D, point: Dictionary, file: String) -> void:
	if not point.get("zoom", false):
		return
	var middle := camera.unproject_position(_pair_center + Vector3.UP * PAIR_HEIGHT / 2.0)
	var size := Vector2i(200, 112)
	var corner := Vector2i(middle) - size / 2
	corner = corner.clamp(Vector2i.ZERO, image.get_size() - size)
	var crop := image.get_region(Rect2i(corner, size))
	crop.resize(size.x * 4, size.y * 4, Image.INTERPOLATE_NEAREST)
	var zoom_file := file.get_basename() + "_zoom.png"
	crop.save_png(zoom_file)
	print("Captura: ", zoom_file)
