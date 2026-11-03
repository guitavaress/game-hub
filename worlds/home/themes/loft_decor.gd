extends HomeDecor
## O enfeite do LOFT (Fase 9.9, virou tema na 13.2): três pendentes quentes nas
## vigas e o canto de estar virado para a janela (tapete, sofá, mesinha e um
## abajur de chão). As cores das lâmpadas vêm do perfil; as dos móveis são
## deste enfeite.
##
## A luz (Fase 17.2) segue as referências do "uau": cada luminária faz uma POÇA
## quente embaixo dela, e entre as poças fica o meio-tom frio do ambiente. Só as
## duas luzes do canto de estar (o pendente em cima da mesinha e o abajur) fazem
## sombra: são as que o olho procura, e sombra custa quadro.
##
## A casa habitada (Fase 17.4): o sofá ganhou forma de sofá (cantos redondos,
## almofadas estufadas, pés) e uma manta; a mesinha, caneca, livros e revistas;
## o tapete, um desenho antigo e gasto; e o canto entre a estante e a janela,
## um aparador com livros e um abajur, um quadro e uma palmeira. Mais três
## plantas pela sala. Tudo por código (HomeShapes, HomePlants), sem nada
## baixado, e fora dos lugares prontos dos móveis (Home.ANCHORS), da porta e da
## passagem. Cada objeto é um nó com a marca "loft_piece" (o teste acha por ela).

const RUG_SHADER: Shader = preload("res://worlds/home/home_rug_vintage.gdshader")
const PICTURE_SHADER: Shader = preload("res://worlds/home/home_picture.gdshader")
const FURNITURE_WOOD: Color = Color(0.3, 0.19, 0.11)
## Nogueira mais clara para o aparador (para ele não sumir no canto escuro).
const SIDEBOARD_WOOD: Color = Color(0.38, 0.23, 0.13)
const LEG_WOOD: Color = Color(0.14, 0.085, 0.05)
const STEEL_COLOR: Color = Color(0.09, 0.09, 0.1)
const BRASS_COLOR: Color = Color(0.72, 0.52, 0.26)
## Sofá de tecido cru (bege acinzentado): pega a luz do abajur, como na referência.
const SOFA_COLOR: Color = Color(0.42, 0.36, 0.3)
## O sofá: largura, altura do assento (em cima da almofada) e profundidade, e a
## altura dos pés.
const SOFA_SIZE: Vector3 = Vector3(2.2, 0.48, 0.92)
const SOFA_SEAT_Y: float = 0.48
const SOFA_LEG: float = 0.1
## Almofadas soltas: azul-ardósia, creme e âmbar (o acento quente).
const PILLOW_COLORS: Array[Color] = [Color(0.25, 0.3, 0.36), Color(0.7, 0.64, 0.54), Color(0.56, 0.32, 0.17)]
## A manta: cinza de tricô, mais fria que o sofá.
const THROW_COLOR: Color = Color(0.17, 0.19, 0.22)
## Tapete antigo cinza com o desenho creme: a madeira e o tecido ficam com o
## calor, ele fica neutro (o miolo do medalhão tem um pouco de ferrugem).
const RUG_FIELD: Color = Color(0.2, 0.21, 0.23)
const RUG_PATTERN: Color = Color(0.5, 0.47, 0.42)
const RUG_DARK: Color = Color(0.1, 0.1, 0.12)
const RUG_ACCENT: Color = Color(0.36, 0.2, 0.14)
## Lombadas de livro: as cores da estante da referência (verde-petróleo, vinho,
## mostarda, creme, marinho, verde-musgo, terracota).
const BOOK_COLORS: Array[Color] = [
	Color(0.12, 0.3, 0.3), Color(0.42, 0.1, 0.12), Color(0.62, 0.46, 0.16), Color(0.72, 0.67, 0.56),
	Color(0.1, 0.14, 0.26), Color(0.18, 0.28, 0.16), Color(0.56, 0.27, 0.16),
]
const MAGAZINE_COLOR: Color = Color(0.1, 0.13, 0.2)
const MUG_COLOR: Color = Color(0.06, 0.06, 0.07)
## Vasos: grafite (as plantas grandes) e cerâmica clara (as pequenas).
const POT_DARK: Color = Color(0.13, 0.13, 0.14)
const POT_LIGHT: Color = Color(0.6, 0.57, 0.52)
const FRAME_COLOR: Color = Color(0.05, 0.05, 0.05)
const PICTURE_MAT: Color = Color(0.8, 0.78, 0.72)
## O aparador: meio em x (encostado na parede norte, entre o canto e a janela)
## e o tamanho (largura, altura, profundidade). A palmeira fica entre ele e a
## janela, em (x, z).
const SIDEBOARD_X: float = -4.85
const SIDEBOARD_SIZE: Vector3 = Vector3(1.7, 0.62, 0.42)
const PALM_SPOT: Vector2 = Vector2(-3.3, -4.05)
## O abajur de mesa: fraco e curto (abaixo de 0,5 a janela não o reflete; ele
## fica fora do vidro).
const TABLE_LAMP_ENERGY: float = 0.49
## Os pendentes: (x, z) na viga e se fazem sombra. O do meio fica em cima da
## mesinha, na frente da janela.
const PENDANTS: Array[Array] = [
	[Vector2(-3.5, 0.0), false],
	[Vector2(0.0, -Home.ROOM_SIZE.z / 3.0), true],
	[Vector2(3.5, 0.0), false],
]
## Abertura do cone do pendente (graus, do eixo à borda) e quanto da força
## sobra para a luz fraca que acende a cúpula por dentro e o teto em volta.
const PENDANT_CONE: float = 40.0
const PENDANT_FILL: float = 0.2
## O abajur: cor da cúpula acesa (acima de 1 acende o brilho) e força da luz.
const FLOOR_LAMP_SHADE: Color = Color(1.5, 0.95, 0.5)
const FLOOR_LAMP_ENERGY: float = 2.4


func build() -> void:
	for pendant in PENDANTS:
		var spot: Vector2 = pendant[0]
		_add_pendant(Vector3(spot.x, 0.0, spot.y), pendant[1])
	_add_rug(Vector3(0.0, 0.0, -2.9), Vector2(3.2, 2.4))
	_add_sofa(Vector3(0.0, 0.0, -1.9))
	_add_coffee_table(Vector3(0.0, 0.0, -3.2))
	# Atrás do braço esquerdo do sofá: acende o encosto (o que se vê ao entrar)
	# e a sombra do sofá cai para a frente, no tapete.
	_add_floor_lamp(Vector3(-1.45, 0.0, -1.25))
	_add_reading_corner()
	_add_plants()


## Pendente: fio, cúpula de metal, lâmpada e duas luzes: um cone para baixo
## (a poça no chão) e uma luz fraca e curta (a cúpula e o teto em volta).
## Nenhuma peça do pendente faz sombra (a luz está dentro dele).
func _add_pendant(at: Vector3, shadow: bool) -> void:
	var bulb_y := Home.ROOM_SIZE.y - 0.95
	var cord := MeshInstance3D.new()
	cord.name = "PendantCord"
	var cord_mesh := CylinderMesh.new()
	cord_mesh.top_radius = 0.008
	cord_mesh.bottom_radius = 0.008
	cord_mesh.height = 0.8
	cord.mesh = cord_mesh
	cord.material_override = HomeMaterials.matte(Color(0.05, 0.05, 0.05))
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cord.position = Vector3(at.x, Home.ROOM_SIZE.y - 0.4, at.z)
	add_node(cord)
	var shade := MeshInstance3D.new()
	shade.name = "PendantShade"
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius = 0.06
	shade_mesh.bottom_radius = 0.26
	shade_mesh.height = 0.22
	shade_mesh.cap_bottom = false
	shade.mesh = shade_mesh
	# Dos dois lados: de baixo se vê o lado de dentro da cúpula, aceso.
	var metal := HomeMaterials.metal(Color(0.12, 0.1, 0.08), 0.4).duplicate() as StandardMaterial3D
	metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	shade.material_override = metal
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.position = Vector3(at.x, bulb_y + 0.06, at.z)
	add_node(shade)
	var bulb := MeshInstance3D.new()
	bulb.name = "PendantBulb"
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.06
	bulb_mesh.height = 0.12
	bulb.mesh = bulb_mesh
	bulb.material_override = HomeMaterials.glow(profile.lamp_color, 6.0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.position = Vector3(at.x, bulb_y, at.z)
	add_node(bulb)
	var cone := SpotLight3D.new()
	cone.name = "PendantLight"
	cone.light_color = profile.lamp_color
	cone.light_energy = profile.lamp_energy
	cone.spot_range = 5.0
	cone.spot_angle = PENDANT_CONE
	cone.spot_angle_attenuation = 1.6  # borda macia
	cone.shadow_enabled = shadow
	cone.shadow_blur = 1.5
	cone.position = Vector3(at.x, bulb_y - 0.04, at.z)
	cone.rotation.x = -PI / 2.0  # o cone aponta para baixo
	cone.set_meta("loft_piece", "pendente")  # os testes acham por aqui (nomes repetidos viram "@")
	add_node(cone)
	var fill := OmniLight3D.new()
	fill.name = "Lamp"
	fill.light_color = profile.lamp_color
	fill.light_energy = profile.lamp_energy * PENDANT_FILL
	fill.omni_range = 5.0
	fill.position = Vector3(at.x, bulb_y + 0.02, at.z)
	add_node(fill)


## Um nó-pai para as peças de um objeto, com a marca do teste ("loft_piece").
func _piece(piece_name: String, kind: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = piece_name
	pivot.position = at
	pivot.rotation.y = yaw
	pivot.set_meta("loft_piece", kind)
	return add_node(pivot)


## Uma malha pronta dentro de um nó-pai.
func _mesh(parent: Node3D, mesh_name: String, mesh: Mesh, material: Material, at: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = mesh_name
	node.mesh = mesh
	node.material_override = material
	node.transform = at
	parent.add_child(node)
	return node


## Colisão de caixa (sem desenho) dentro de um nó-pai.
func _solid(parent: Node3D, box_size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.set_meta("footstep", profile.footstep)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	parent.add_child(body)


func _at(x: float, y: float, z: float, rotation: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rotation), Vector3(x, y, z))


## O tapete antigo, gasto, embaixo do canto de estar.
func _add_rug(center: Vector3, rug_size: Vector2) -> void:
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var plane := PlaneMesh.new()
	plane.size = rug_size
	rug.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = RUG_SHADER
	material.set_shader_parameter("field_color", RUG_FIELD)
	material.set_shader_parameter("pattern_color", RUG_PATTERN)
	material.set_shader_parameter("dark_color", RUG_DARK)
	material.set_shader_parameter("accent_color", RUG_ACCENT)
	material.set_shader_parameter("rug_size", rug_size)
	rug.material_override = material
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rug.position = center + Vector3(0.0, 0.006, 0.0)
	rug.set_meta("loft_piece", "tapete")
	add_node(rug)


## Sofá de três lugares com a frente para o norte (a janela), como um sofá de
## verdade: pés de madeira, base, braços e encosto de cantos redondos, dois
## assentos e duas almofadas de encosto estufados, três almofadas soltas e a
## manta jogada. O estofado é uma malha só (um desenho); as almofadas soltas,
## outra (cada uma com a sua cor). Tem colisão (o jogador dá a volta).
func _add_sofa(center: Vector3) -> void:
	var sofa := _piece("Sofa", "sofa", center)
	var w := SOFA_SIZE.x
	var d := SOFA_SIZE.z
	var body := HomeShapes.Batch.new()
	body.add_mesh(HomeShapes.soft_box(Vector3(w, 0.22, d), 0.05), _at(0.0, SOFA_LEG + 0.11, 0.0), Color.WHITE)
	for side in [-1.0, 1.0]:
		body.add_mesh(HomeShapes.soft_box(Vector3(0.22, 0.52, d), 0.08, Vector3(0.012, 0.0, 0.0)),
				_at(side * (w / 2.0 - 0.11), SOFA_LEG + 0.26, 0.0), Color.WHITE)
	# O encosto desce até a base: visto de trás (de onde se entra), é uma peça só.
	body.add_mesh(HomeShapes.soft_box(Vector3(w - 0.04, 0.74, 0.22), 0.07), _at(0.0, SOFA_LEG + 0.37, d / 2.0 - 0.11), Color.WHITE)
	for side in [-1.0, 1.0]:
		# Os assentos e as almofadas do encosto (estas inclinadas para trás).
		body.add_mesh(HomeShapes.soft_box(Vector3(0.87, 0.16, 0.68), 0.055, Vector3(0.006, 0.02, 0.006)),
				_at(side * 0.44, SOFA_SEAT_Y - 0.08, -d / 2.0 + 0.355), Color.WHITE)
		body.add_mesh(HomeShapes.soft_box(Vector3(0.86, 0.46, 0.18), 0.07, Vector3(0.006, 0.006, 0.035)),
				_at(side * 0.44, SOFA_SEAT_Y + 0.21, 0.14, Vector3(0.2, 0.0, 0.0)), Color.WHITE)
	# A trama mais suave: com a luz rasante do abajur, a padrão parecia reboco.
	var cloth := HomeMaterials.fabric(SOFA_COLOR).duplicate() as StandardMaterial3D
	cloth.normal_scale = 0.3
	_mesh(sofa, "SofaBody", body.commit(), cloth)
	var legs := HomeShapes.Batch.new()
	var leg := CylinderMesh.new()
	leg.top_radius = 0.022
	leg.bottom_radius = 0.015
	leg.height = SOFA_LEG
	leg.radial_segments = 10
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			legs.add_mesh(leg, _at(sx * (w / 2.0 - 0.12), SOFA_LEG / 2.0, sz * (d / 2.0 - 0.12)), LEG_WOOD)
	_mesh(sofa, "SofaLegs", legs.commit(), HomeMaterials.vertex_colored(0.5))
	# As almofadas soltas: uma no canto esquerdo e duas à direita.
	var pillows := HomeShapes.Batch.new()
	var pillow := HomeShapes.soft_box(Vector3(0.44, 0.44, 0.14), 0.08, Vector3(0.006, 0.006, 0.05))
	var small := HomeShapes.soft_box(Vector3(0.38, 0.38, 0.13), 0.07, Vector3(0.006, 0.006, 0.045))
	pillows.add_mesh(pillow, _at(-0.66, SOFA_SEAT_Y + 0.2, 0.0, Vector3(0.32, 0.3, 0.06)), PILLOW_COLORS[0])
	pillows.add_mesh(small, _at(0.4, SOFA_SEAT_Y + 0.17, -0.02, Vector3(0.3, -0.12, -0.05)), PILLOW_COLORS[1])
	pillows.add_mesh(pillow, _at(0.68, SOFA_SEAT_Y + 0.2, 0.02, Vector3(0.34, -0.32, -0.08)), PILLOW_COLORS[2])
	_mesh(sofa, "SofaPillows", pillows.commit(true), HomeMaterials.fabric_tinted())
	_add_throw(sofa)
	_solid(sofa, Vector3(w, SOFA_SEAT_Y, d), Vector3(0.0, SOFA_SEAT_Y / 2.0, 0.0))
	_solid(sofa, Vector3(w, 0.9, 0.24), Vector3(0.0, 0.45, d / 2.0 - 0.12))
	# O assento: a captura do canto de estar mira aqui (tools/capturar_casa.gd).
	var seat := Node3D.new()
	seat.name = "SofaSeat"
	seat.position = center + Vector3(0.0, 0.36, -0.07)
	add_node(seat)


## A manta de tricô jogada no sofá: sai da beira do assento, sobe pela almofada
## do encosto, passa por cima dele e cai pelas costas do sofá (o lado que se vê
## ao entrar), com as dobras crescendo. Fica um pouco à esquerda do meio, entre
## as almofadas.
func _add_throw(sofa: Node3D) -> void:
	var x := -0.14
	# O meio da manta, de trás para a frente, em (z, y) do sofá (a frente é -z).
	var line: Array[Vector2] = [
		Vector2(-0.475, 0.38), Vector2(-0.46, 0.47), Vector2(-0.38, 0.512), Vector2(-0.2, 0.518),
		Vector2(-0.04, 0.535), Vector2(0.005, 0.7), Vector2(0.08, 0.925), Vector2(0.2, 0.968),
		Vector2(0.3, 0.935), Vector2(0.41, 0.875), Vector2(0.478, 0.79), Vector2(0.485, 0.6),
		Vector2(0.49, 0.42), Vector2(0.5, 0.27),
	]
	var path := PackedVector3Array()
	for i in line.size():
		# Ela desce um pouco na diagonal, como uma manta jogada de verdade.
		path.append(Vector3(x + float(i) / line.size() * 0.12, line[i].y, line[i].x))
	var mesh := HomeShapes.drape(path, Vector3.RIGHT, Vector3(x, 0.35, 0.05), 0.66, 3.5, Vector2(0.008, 0.032), THROW_COLOR)
	var throw := _mesh(sofa, "SofaThrow", mesh, HomeMaterials.fabric_tinted(true))
	throw.set_meta("loft_piece", "manta")


## Mesinha de centro: tampo de madeira, armação de aço com uma prateleira
## embaixo (com livros), e em cima a caneca, dois livros, as revistas e o
## controle de videogame.
func _add_coffee_table(center: Vector3) -> void:
	var table := _piece("CoffeeTable", "mesinha", center)
	var top_y := 0.42
	_mesh(table, "TableTop", HomeShapes.soft_box(Vector3(1.15, 0.045, 0.6), 0.012), HomeMaterials.wood(FURNITURE_WOOD, false, 0.35),
			_at(0.0, top_y, 0.0))
	_mesh(table, "TableShelf", HomeShapes.soft_box(Vector3(1.04, 0.025, 0.5), 0.006), HomeMaterials.wood(FURNITURE_WOOD, false, 0.45),
			_at(0.0, 0.1, 0.0))
	var frame := HomeShapes.Batch.new()
	for sx in [-0.53, 0.53]:
		for sz in [-0.26, 0.26]:
			frame.add_box(Vector3(0.03, top_y - 0.02, 0.03), _at(sx, (top_y - 0.02) / 2.0, sz), Color.WHITE)
		frame.add_box(Vector3(0.025, 0.025, 0.52), _at(sx, top_y - 0.035, 0.0), Color.WHITE)
	for sz in [-0.26, 0.26]:
		frame.add_box(Vector3(1.06, 0.025, 0.025), _at(0.0, top_y - 0.035, sz), Color.WHITE)
	_mesh(table, "TableFrame", frame.commit(), HomeMaterials.metal(STEEL_COLOR))
	_solid(table, Vector3(1.15, top_y, 0.6), Vector3(0.0, top_y / 2.0, 0.0))
	var surface := top_y + 0.0225
	var items := HomeShapes.Batch.new()
	# Em cima: dois livros deitados e as revistas abertas em leque.
	HomeShapes.book(items, Vector3(0.035, 0.24, 0.17), _at(-0.18, surface + 0.0175, 0.06, Vector3(0.0, 0.25, PI / 2.0)), BOOK_COLORS[3])
	HomeShapes.book(items, Vector3(0.028, 0.2, 0.14), _at(-0.2, surface + 0.035 + 0.014, 0.05, Vector3(0.0, 0.05, PI / 2.0)), BOOK_COLORS[0])
	items.add_mesh(HomeShapes.soft_box(Vector3(0.21, 0.004, 0.28), 0.0015), _at(0.04, surface + 0.002, 0.03, Vector3(0.0, -0.35, 0.0)), Color(0.82, 0.8, 0.76))
	items.add_mesh(HomeShapes.soft_box(Vector3(0.21, 0.004, 0.28), 0.0015), _at(0.07, surface + 0.006, 0.0, Vector3(0.0, 0.2, 0.0)), MAGAZINE_COLOR)
	# A capa da revista: o título e uma foto.
	var cover := _at(0.07, surface + 0.0085, 0.0, Vector3(0.0, 0.2, 0.0))
	items.add_box(Vector3(0.16, 0.001, 0.03), cover * _at(0.0, 0.0, -0.11), Color(0.78, 0.74, 0.66))
	items.add_box(Vector3(0.16, 0.001, 0.14), cover * _at(0.0, 0.0, 0.01), Color(0.36, 0.24, 0.16))
	# Embaixo, na prateleira: uma pilha de livros grandes e uma caixa de jogo.
	for i in 3:
		var size := Vector3(0.04, 0.3 - i * 0.03, 0.22 - i * 0.015)
		HomeShapes.book(items, size, _at(-0.1 + i * 0.01, 0.1125 + i * 0.04 + 0.02, 0.0, Vector3(0.0, 0.1 - i * 0.12, PI / 2.0)),
				BOOK_COLORS[(i + 4) % BOOK_COLORS.size()])
	items.add_mesh(HomeShapes.soft_box(Vector3(0.3, 0.07, 0.3), 0.006), _at(0.22, 0.1125 + 0.035, 0.0, Vector3(0.0, -0.08, 0.0)), Color(0.42, 0.14, 0.12))
	_mesh(table, "TableItems", items.commit(), HomeMaterials.vertex_colored(0.6))
	# A caneca de café (cerâmica escura) e o controle, que brilham um pouco.
	var glossy := HomeShapes.Batch.new()
	var mug := CylinderMesh.new()
	mug.top_radius = 0.042
	mug.bottom_radius = 0.04
	mug.height = 0.095
	mug.radial_segments = 20
	mug.cap_top = false
	glossy.add_mesh(mug, _at(0.36, surface + 0.0475, -0.1), MUG_COLOR)
	var coffee := CylinderMesh.new()
	coffee.top_radius = 0.039
	coffee.bottom_radius = 0.039
	coffee.height = 0.002
	coffee.radial_segments = 20
	glossy.add_mesh(coffee, _at(0.36, surface + 0.085, -0.1), Color(0.09, 0.05, 0.03))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.02
	handle.outer_radius = 0.031
	handle.rings = 14
	handle.ring_segments = 6
	glossy.add_mesh(handle, _at(0.405, surface + 0.05, -0.1, Vector3(PI / 2.0, 0.0, 0.0)), MUG_COLOR)
	# O controle: o corpo, as duas pegas e os dois direcionais.
	var pad := _at(0.2, surface, 0.14, Vector3(0.0, 0.4, 0.0))
	var plastic := Color(0.07, 0.07, 0.08)
	glossy.add_mesh(HomeShapes.soft_box(Vector3(0.11, 0.026, 0.06), 0.012), pad * _at(0.0, 0.018, 0.0), plastic)
	for side in [-1.0, 1.0]:
		glossy.add_mesh(HomeShapes.soft_box(Vector3(0.045, 0.03, 0.07), 0.015), pad * _at(side * 0.05, 0.016, 0.022, Vector3(0.0, side * 0.35, 0.0)), plastic)
		var stick := CylinderMesh.new()
		stick.top_radius = 0.008
		stick.bottom_radius = 0.009
		stick.height = 0.012
		stick.radial_segments = 10
		glossy.add_mesh(stick, pad * _at(side * 0.025, 0.035, 0.01), Color(0.13, 0.13, 0.14))
	_mesh(table, "TableGloss", glossy.commit(), HomeMaterials.vertex_colored(0.28))


## O canto entre a estante e a janela (livre em todas as disposições): um
## aparador baixo de madeira com livros, uma esfera de latão e um abajur de
## mesa, o quadro na parede de tijolo em cima, a palmeira grande ao lado da
## janela e uma planta pendente caindo do aparador.
func _add_reading_corner() -> void:
	var inner_z := -Home.ROOM_SIZE.z / 2.0
	var at := Vector3(SIDEBOARD_X, 0.0, inner_z + SIDEBOARD_SIZE.z / 2.0 + 0.02)
	var board := _piece("Sideboard", "aparador", at)
	var w := SIDEBOARD_SIZE.x
	var h := SIDEBOARD_SIZE.y
	var d := SIDEBOARD_SIZE.z
	var leg := 0.14
	var wood := HomeMaterials.wood(SIDEBOARD_WOOD, false, 0.4)
	var body_height := h - leg - 0.03
	_mesh(board, "SideboardBody", HomeShapes.soft_box(Vector3(w, body_height, d), 0.012), wood, _at(0.0, leg + body_height / 2.0, 0.0))
	_mesh(board, "SideboardTop", HomeShapes.soft_box(Vector3(w + 0.03, 0.03, d + 0.02), 0.008), wood, _at(0.0, h - 0.015, 0.0))
	# Três portas um pouco para fora, com uma fresta entre elas.
	var door_width := (w - 0.04) / 3.0 - 0.012
	var doors := HomeShapes.Batch.new()
	for i in 3:
		var x := -w / 2.0 + 0.02 + (door_width + 0.012) * (i + 0.5)
		doors.add_mesh(HomeShapes.soft_box(Vector3(door_width, body_height - 0.05, 0.016), 0.004), _at(x, leg + body_height / 2.0, d / 2.0 + 0.006), Color.WHITE)
	_mesh(board, "SideboardDoors", doors.commit(), HomeMaterials.wood(FURNITURE_WOOD, false, 0.35))
	var brass := HomeShapes.Batch.new()
	for i in 3:
		var x := -w / 2.0 + 0.02 + (door_width + 0.012) * (i + 0.5) + door_width * 0.38
		brass.add_box(Vector3(0.012, 0.11, 0.014), _at(x, leg + body_height * 0.62, d / 2.0 + 0.021), Color.WHITE)
	_mesh(board, "SideboardHandles", brass.commit(), HomeMaterials.metal(BRASS_COLOR, 0.3))
	var legs := HomeShapes.Batch.new()
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.022
	leg_mesh.bottom_radius = 0.013
	leg_mesh.height = leg
	leg_mesh.radial_segments = 10
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			legs.add_mesh(leg_mesh, _at(sx * (w / 2.0 - 0.08), leg / 2.0, sz * (d / 2.0 - 0.07)), LEG_WOOD)
	_mesh(board, "SideboardLegs", legs.commit(), HomeMaterials.vertex_colored(0.5))
	_solid(board, Vector3(w, h, d), Vector3(0.0, h / 2.0, 0.0))

	# Em cima: uma fileira de livros em pé (o último encostado), uma pilha
	# deitada com uma esfera de latão, o abajur e a planta pendente.
	var books := HomeShapes.Batch.new()
	var x := -w / 2.0 + 0.1
	var heights: Array[float] = [0.25, 0.27, 0.22, 0.26, 0.24, 0.21, 0.25]
	for i in heights.size():
		var thick := 0.028 + 0.012 * float((i * 7) % 3) / 2.0
		var lean := 0.0 if i < heights.size() - 1 else 0.32
		var place := _at(x + thick / 2.0 + (0.09 if lean != 0.0 else 0.0), h, -0.02, Vector3(0.0, 0.0, lean))
		HomeShapes.book(books, Vector3(thick, heights[i], 0.16), place, BOOK_COLORS[i % BOOK_COLORS.size()])
		x += thick + 0.003
	for i in 3:
		var size := Vector3(0.035, 0.26 - i * 0.025, 0.19 - i * 0.015)
		HomeShapes.book(books, size, _at(-0.1, h + i * 0.035 + 0.0175, 0.0, Vector3(0.0, 0.15 - i * 0.2, PI / 2.0)),
				BOOK_COLORS[(i + 2) % BOOK_COLORS.size()])
	_mesh(board, "SideboardBooks", books.commit(), HomeMaterials.vertex_colored(0.65))
	var ball := SphereMesh.new()
	ball.radius = 0.04
	ball.height = 0.08
	ball.radial_segments = 16
	ball.rings = 8
	_mesh(board, "SideboardBrassBall", ball, HomeMaterials.metal(BRASS_COLOR, 0.25), _at(-0.23, h + 0.105 + 0.04, 0.0))
	_add_table_lamp(board, Vector3(0.2, h, -0.04))
	var trailing := HomePlants.make("pendente", 0.45, 0.075, 0.13, POT_LIGHT, 7, false, Vector3.BACK, d / 2.0 + 0.02)
	trailing.position = Vector3(w / 2.0 - 0.17, h, 0.04)
	board.add_child(trailing)

	_add_picture(Vector3(SIDEBOARD_X, 1.62, inner_z))
	var palm := HomePlants.make("palmeira", 1.75, 0.2, 0.38, POT_DARK, 11)
	palm.position = Vector3(PALM_SPOT.x, 0.0, PALM_SPOT.y)
	_piece("PalmPlant", "planta", Vector3.ZERO).add_child(palm)
	_keep_inside(palm)


## Abajur de mesa no aparador: base de cerâmica, cúpula acesa e uma luz fraca e
## curta, sem sombra, que faz a poça do canto (o tijolo, o quadro e a palmeira).
func _add_table_lamp(parent: Node3D, at: Vector3) -> void:
	var base := HomeShapes.Batch.new()
	var belly := SphereMesh.new()
	belly.radius = 0.075
	belly.height = 0.17
	belly.radial_segments = 18
	belly.rings = 9
	base.add_mesh(belly, _at(at.x, at.y + 0.085, at.z), POT_LIGHT)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.012
	neck.bottom_radius = 0.012
	neck.height = 0.12
	base.add_mesh(neck, _at(at.x, at.y + 0.22, at.z), BRASS_COLOR)
	_mesh(parent, "TableLampBase", base.commit(), HomeMaterials.vertex_colored(0.35))
	var shade := MeshInstance3D.new()
	shade.name = "TableLampShade"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 0.14
	cone.height = 0.17
	cone.cap_top = false
	cone.cap_bottom = false
	shade.mesh = cone
	var cloth := StandardMaterial3D.new()
	cloth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloth.albedo_color = FLOOR_LAMP_SHADE * 0.85
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	shade.material_override = cloth
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.position = at + Vector3(0.0, 0.34, 0.0)
	parent.add_child(shade)
	var light := OmniLight3D.new()
	light.name = "TableLampLight"
	light.light_color = profile.lamp_color
	light.light_energy = TABLE_LAMP_ENERGY
	light.omni_range = 3.5
	light.omni_attenuation = 0.5  # cai devagar: fraquinha, mas acende o canto todo
	light.position = at + Vector3(0.0, 0.36, 0.12)
	parent.add_child(light)


## O quadro na parede de tijolo: moldura preta fina, o passe-partout claro e a
## gravura de montanhas (um shader, sem imagem baixada).
func _add_picture(at: Vector3) -> void:
	var picture := _piece("Picture", "quadro", at + Vector3(0.0, 0.0, 0.03))
	var outer := Vector2(0.8, 0.6)
	var bar := 0.03
	var frame := HomeShapes.Batch.new()
	for sy in [-1.0, 1.0]:
		frame.add_box(Vector3(outer.x, bar, 0.035), _at(0.0, sy * (outer.y - bar) / 2.0, 0.0), FRAME_COLOR)
	for sx in [-1.0, 1.0]:
		frame.add_box(Vector3(bar, outer.y - bar * 2.0, 0.035), _at(sx * (outer.x - bar) / 2.0, 0.0, 0.0), FRAME_COLOR)
	frame.add_box(Vector3(outer.x - bar * 2.0, outer.y - bar * 2.0, 0.006), _at(0.0, 0.0, -0.01), PICTURE_MAT)
	_mesh(picture, "PictureFrame", frame.commit(), HomeMaterials.vertex_colored(0.45))
	var art := QuadMesh.new()
	art.size = Vector2(0.54, 0.36)
	var material := ShaderMaterial.new()
	material.shader = PICTURE_SHADER
	_mesh(picture, "PictureArt", art, material, _at(0.0, 0.0, -0.006))
	for child in picture.get_children():
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## As outras plantas: uma folha larga no canto do computador, uma espada ao lado
## do sofá e uma pequena no peitoril da janela.
func _add_plants() -> void:
	var corner := HomePlants.make("costela", 1.15, 0.2, 0.34, POT_DARK, 23)
	corner.position = Vector3(5.45, 0.0, -3.95)
	_piece("CornerPlant", "planta", Vector3.ZERO).add_child(corner)
	_keep_inside(corner)
	var sword := HomePlants.make("espada", 0.85, 0.13, 0.3, POT_LIGHT, 5)
	sword.position = Vector3(1.55, 0.0, -1.55)
	_piece("SofaPlant", "planta", Vector3.ZERO).add_child(sword)
	var sill_y := Home.WINDOW_CENTER_Y - Home.WINDOW_SIZE.y / 2.0
	var sill := HomePlants.make("costela", 0.34, 0.075, 0.11, POT_LIGHT, 31, false)
	sill.position = Vector3(-1.75, sill_y, -Home.ROOM_SIZE.z / 2.0 + 0.12)
	_piece("SillPlant", "planta", Vector3.ZERO).add_child(sill)
	_keep_inside(sill)


## Abajur de chão ao lado do sofá: pé de metal, cúpula de tecido acesa e a
## luz quente de dentro, que faz sombra (o sofá desenha a sombra no chão).
func _add_floor_lamp(at: Vector3) -> void:
	var steel := HomeMaterials.metal(STEEL_COLOR)
	add_box("FloorLampBase", Vector3(0.3, 0.03, 0.3), at + Vector3(0.0, 0.015, 0.0), steel)
	add_box("FloorLampPole", Vector3(0.03, 1.45, 0.03), at + Vector3(0.0, 0.75, 0.0), steel, false)
	var shade := MeshInstance3D.new()
	shade.name = "FloorLampShade"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.22
	mesh.height = 0.3
	mesh.cap_top = false
	mesh.cap_bottom = false
	shade.mesh = mesh
	# Sem sombreamento: a luz de dentro não estoura a cúpula em branco; ela
	# fica âmbar, com o brilho em volta.
	var cloth := StandardMaterial3D.new()
	cloth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloth.albedo_color = FLOOR_LAMP_SHADE
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	shade.material_override = cloth
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.position = at + Vector3(0.0, 1.55, 0.0)
	add_node(shade)
	var light := OmniLight3D.new()
	light.name = "FloorLampLight"
	light.light_color = profile.lamp_color
	light.light_energy = FLOOR_LAMP_ENERGY
	light.omni_range = 6.0
	light.shadow_enabled = true
	light.shadow_blur = 1.5
	light.position = at + Vector3(0.0, 1.5, 0.0)
	add_node(light)


## A folhagem que passaria da parede (ou do vidro) é achatada só nesse eixo, a
## partir do meio do vaso: uma planta encostada na parede fica assim. "plant" já
## está no lugar, dentro da casa.
func _keep_inside(plant: Node3D) -> void:
	var leaves := plant.get_node("PlantLeaves") as MeshInstance3D
	var box := leaves.mesh.get_aabb()
	var center := target.to_local(plant.global_position)
	var limit := Home.ROOM_SIZE / 2.0 - Vector3.ONE * 0.02
	for axis in [0, 2]:
		var squeeze := 1.0
		if center[axis] + box.end[axis] > limit[axis]:
			squeeze = minf(squeeze, (limit[axis] - center[axis]) / box.end[axis])
		if center[axis] + box.position[axis] < -limit[axis]:
			squeeze = minf(squeeze, (-limit[axis] - center[axis]) / box.position[axis])
		leaves.scale[axis] = maxf(squeeze, 0.05)
