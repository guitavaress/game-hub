extends "res://tools/capturar_pontos.gd"
## Spike do Jev nas capturas (C.2): as capturas do capturar_pontos.gd com um DEFEITO
## CONHECIDO montado na cena, mais a régua geométrica da torre. Roda SÓ na cópia
## descartável do gerar_capturas.py (user:// próprio, biblioteca falsa sem capas).
##
##   godot --path <cópia> -s <este arquivo> -- <pasta> 200 rpg <horas> alta <variante> [deslocar]
##
## Variantes: normal, torre_escondida, sem_pinheiros, neve_estourada, tela_preta.
## (O "pinheiro preto" saiu: o pinheiro do hub já é quase preto, e a variante mudava só
## 1-3% da imagem. "Sem pinheiros" é o defeito real de o espalhamento falhar.)
## "deslocar" tira a câmera um pouco do lugar (as capturas do portão não repetem o ajuste).
## Grava <pasta>/geometria.json: a torre vista de cada ponto e o "night_amount" de cada hora.

## Quanto a exposição muda (multiplicador da câmera; o DayNight não mexe nele).
const EXPOSICAO_ESTOURADA: float = 3.5
const EXPOSICAO_ESCURA: float = 0.02
## Quanto a câmera sai do lugar no portão (m).
const DESLOCAMENTO: Vector3 = Vector3(2.0, 0.0, 2.0)
const DESLOCAMENTO_MIRANTE: Vector3 = Vector3(0.5, 0.0, 0.5)
## Um raio "chega" na torre se bater a menos disto do ponto mirado (m).
const FOLGA_DO_RAIO: float = 1.5


func _variante() -> String:
	var args := OS.get_cmdline_user_args()
	return String(args[5]) if args.size() > 5 else "normal"


func _deslocar() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.size() > 6 and String(args[6]) == "deslocar"


func _points(area: Dictionary) -> Array[Dictionary]:
	var points: Array[Dictionary] = super(area)
	if not _deslocar():
		return points
	for point in points:
		var passo: Vector3 = DESLOCAMENTO_MIRANTE if point["name"] == "mirante" else DESLOCAMENTO
		point["eye"] = (point["eye"] as Vector3) + passo
		point["target"] = (point["target"] as Vector3) + Vector3(3.0, 0.0, 0.0)
	return points


func _prepare(city: Node, area: Dictionary) -> void:
	var variante := _variante()
	var district := String(OS.get_cmdline_user_args()[2])
	var torre := city.get_node_or_null("DistrictLandmark_%s" % district) as Node3D
	# O defeito foi montado de verdade? Sem ele, o rótulo (que vem do nome da variante)
	# seria falso: o gerar_capturas.py lê o "variante_aplicada" e recusa a rodada (C.2.2).
	# Sem quit() aqui: o capturar_pontos.gd segue esperando quadros depois do _prepare, e
	# fechar a Godot no meio disso a travava (10 min até o tempo esgotar).
	var aplicada := true
	match variante:
		"normal":
			pass
		"torre_escondida":
			# Sem torre no bairro, a captura já não mostra torre: o rótulo "não" continua certo.
			if torre != null:
				torre.visible = false
		"sem_pinheiros":
			aplicada = _esconder_pinheiros(city)
		"neve_estourada":
			aplicada = _mudar_exposicao(city, EXPOSICAO_ESTOURADA)
		"tela_preta":
			aplicada = _mudar_exposicao(city, EXPOSICAO_ESCURA)
		_:
			push_error("Variante desconhecida: %s" % variante)
			aplicada = false
	_gravar_geometria(city, area, torre, variante, aplicada)


## Os pinheiros do bioma são a família de impostores (TreeImpostor, com "atlas") do
## BiomeScatter: some só ela. As rochas e as árvores da cidade ficam.
func _esconder_pinheiros(city: Node) -> bool:
	var escondidos := 0
	# As famílias do BiomeScatter se chamam "Scatter_<n>" (biome_scatter.gd, _add_family).
	for node in city.find_children("Scatter_*", "MultiMeshInstance3D", true, false):
		var pai_script := node.get_parent().get_script() as Script
		if pai_script == null or not pai_script.resource_path.ends_with("biome_scatter.gd"):
			continue
		var instance := node as MultiMeshInstance3D
		var material := instance.material_override as ShaderMaterial
		if material != null and material.get_shader_parameter("atlas") != null:
			instance.visible = false
			escondidos += 1
	print("pinheiros escondidos: ", escondidos)
	if escondidos == 0:
		push_error("Nenhum pinheiro achado: a variante sem_pinheiros não vale.")
	return escondidos > 0


## A exposição pelo multiplicador da câmera do ambiente: o DayNight reescreve a
## tonemap_exposure a cada hora, mas não toca no camera_attributes.
func _mudar_exposicao(city: Node, multiplicador: float) -> bool:
	var ambiente := city.get("_world_env") as WorldEnvironment
	if ambiente == null:
		push_error("Sem WorldEnvironment: a variante de exposição não vale.")
		return false
	var atributos := CameraAttributesPractical.new()
	atributos.exposure_multiplier = multiplicador
	ambiente.camera_attributes = atributos
	print("exposição x", multiplicador)
	return true


## A régua geométrica: de cada ponto, a torre cai na tela? Quantos pixels de altura
## (numa imagem de 720 px)? Algum raio do olho até ela chega sem bater em nada antes?
func _gravar_geometria(city: Node, area: Dictionary, torre: Node3D, variante: String, aplicada: bool) -> void:
	var args := OS.get_cmdline_user_args()
	var pasta := String(args[0])
	var player_camera: Camera3D = city.get_node("Player/Head/Camera3D")
	var fov := deg_to_rad(player_camera.fov)
	var aspecto := float(SIZE.x) / float(SIZE.y)
	var pontos := {}
	for point in _points(area):
		pontos[point["name"]] = _torre_vista(city, torre, point["eye"], point["target"], fov, aspecto)
	var noite := {}
	for text in String(args[3]).split(","):
		noite[text] = city.get("_day_night").night_amount(float(text))
	var dados := {"variante": variante, "variante_aplicada": aplicada, "deslocar": _deslocar(),
			"noite": noite, "pontos": pontos}
	var arquivo := FileAccess.open(pasta + "/geometria.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(dados, "  "))
	arquivo.close()


func _torre_vista(city: Node, torre: Node3D, olho: Vector3, alvo: Vector3, fov: float, aspecto: float) -> Dictionary:
	var vazio := {"torre_na_tela": false, "torre_altura_px": 0.0, "torre_desobstruida": false}
	if torre == null or not torre.is_visible_in_tree():
		return vazio
	var topo_y: float = torre.call("get_top_y")
	var base := torre.global_position
	if topo_y <= base.y:
		return vazio
	# A câmera: o mesmo "looking_at" do capturar_pontos.gd; fov vertical (KEEP_HEIGHT).
	var visao := Transform3D(Basis.IDENTITY, olho).looking_at(alvo)
	var amostras: Array[Vector3] = []
	for k in 5:
		amostras.append(Vector3(base.x, lerpf(base.y, topo_y, float(k) / 4.0), base.z))
	var tan_meio := tan(fov / 2.0)
	var ys: Array[float] = []
	var na_tela := false
	var desobstruida := false
	var espaco := (city as Node3D).get_world_3d().direct_space_state
	# O corpo do jogador fica fora do raio (ele está na praça, perto do olho).
	var excluir: Array[RID] = []
	var jogador := city.get_node_or_null("Player") as CollisionObject3D
	if jogador != null:
		excluir.append(jogador.get_rid())
	for ponto in amostras:
		var local := visao.affine_inverse() * ponto
		if local.z >= -0.1:
			continue  # atrás da câmera
		var x := (local.x / -local.z) / (tan_meio * aspecto)
		var y := (local.y / -local.z) / tan_meio
		if absf(x) > 1.0:
			continue
		ys.append(clampf(y, -1.0, 1.0))
		if absf(y) <= 1.0:
			na_tela = true
			var raio := PhysicsRayQueryParameters3D.create(olho, ponto, 0xFFFFFFFF, excluir)
			var batida := espaco.intersect_ray(raio)
			if batida.is_empty() or (batida["position"] as Vector3).distance_to(ponto) <= FOLGA_DO_RAIO:
				desobstruida = true
	var altura := 0.0
	if na_tela and ys.size() >= 2:
		altura = (ys.max() - ys.min()) / 2.0 * 720.0
	return {"torre_na_tela": na_tela, "torre_altura_px": snappedf(altura, 0.1), "torre_desobstruida": desobstruida}
