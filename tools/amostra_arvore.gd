extends "res://tools/capturar_pontos.gd"
## As árvores DE PERTO (Fase 19.2, a amostra; 19.3: as duas espécies do jogo).
## Rode COM JANELA, à mão:
##
##   godot --path . -s tools/amostra_arvore.gd -- <pasta> [jogos] [bairro] [horas] [qualidade]
##
## Os argumentos são os do capturar_pontos.gd (pasta SEMPRE fora do
## repositório). No meio da rua do pórtico (PAIR_ALONG m depois dele), ficam
## DUAS árvores lado a lado, da mesma altura (PAIR_HEIGHT): o pinheiro à
## esquerda e a árvore de rua à direita, no TreeModel do jogo.
## Pontos a mais, além dos do capturar_pontos (ex.: rpg_par_perto_13h.png):
##   par_perto   a 8 m do par
##   par_30m     a 30 m do par
##   par_150m    a 150 m do par, do alto (60 m, por cima dos pórticos), e um
##               recorte do par ampliado 4x (..._par_150m_13h_zoom.png)

const PINE: String = "res://assets/models/trees/pine.glb"
const STREET_TREE: String = "res://assets/models/trees/street_tree.glb"
const PAIR_HEIGHT: float = 9.0
## Distância entre os dois troncos do par, e quanto o par fica para dentro do pórtico.
const PAIR_GAP: float = 7.0
const PAIR_ALONG: float = 22.0

var _pair_center: Vector3 = Vector3.INF
## De que lado do pórtico fica o ponto "portico" (+1 ou -1 no x).
var _side: float = 1.0


func _prepare(city: Node, area: Dictionary) -> void:
	_add_pair(city, area)


## O par lado a lado, no meio da rua do pórtico (a que corre de leste a oeste,
## entre o bairro e a praça), PAIR_ALONG m depois dele: as câmeras olham ao
## longo da rua, e nada fica na frente.
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
	for pick: Array in [[PINE, -1.0, "AmostraPinheiro"], [STREET_TREE, 1.0, "AmostraArvoreDeRua"]]:
		var trees := TreeModel.new()
		trees.name = String(pick[2])
		city.add_child(trees)
		var height := float(TreeModel.species(String(pick[0]))["height"])
		var spot := _pair_center + right * float(pick[1]) * PAIR_GAP / 2.0
		var one: Array[Transform3D] = [Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * PAIR_HEIGHT / height), spot)]
		trees.setup(String(pick[0]), one)


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
