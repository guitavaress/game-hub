class_name Home
extends Node3D
## A CASA (Fase 9): o loft onde o jogador mora. É uma cena própria e não
## conhece nenhum mundo: quem a usa (hoje a cidade) coloca a casa longe do
## resto, liga a porta da rua a algum lugar (get_front_door) e põe o jogador
## no ponto de nascer (get_spawn_transform).
##
## A casa monta tudo por código: chão, paredes, teto, luzes e a porta da rua.
## Os móveis (estante, mural, computador) entram em _build_furniture, um por
## linha.
##
## "Em casa": uma área cobre o interior. Quando o jogador entra nela, a casa
## chama player.set_indoors(ambiente da casa); ao sair, set_indoors(null).
## A câmera passa a usar a luz e o fundo da casa, e não os do mundo lá fora.
##
## Luz de fora: tudo o que a casa desenha fica na camada de render
## INTERIOR_LAYER. O mundo tira essa camada do sol dele (light_cull_mask),
## para o sol não atravessar o telhado.
##
## Convenção: a origem fica no chão, no meio da sala. O norte (-Z) é a parede
## da janela; a porta da rua fica na parede sul (+Z).

## Camada de render do interior (de 1 a 20) e a máscara dela (bit).
const INTERIOR_LAYER: int = 20
const INTERIOR_LAYER_MASK: int = 1 << (INTERIOR_LAYER - 1)
## Tamanho por dentro (largura x, altura, profundidade z), em metros.
const ROOM_SIZE: Vector3 = Vector3(12.0, 3.4, 9.0)
const WALL_THICKNESS: float = 0.3
## Onde o jogador nasce: um pouco ao sul do meio, olhando para a janela (norte).
const SPAWN_SPOT: Vector3 = Vector3(0.0, 0.1, 1.5)

## O janelão na parede norte (largura, altura) e a altura do meio dele.
const WINDOW_SIZE: Vector2 = Vector2(5.2, 2.4)
const WINDOW_CENTER_Y: float = 1.65
const WINDOW_SHADER: Shader = preload("res://worlds/home/home_window.gdshader")
const RUG_SHADER: Shader = preload("res://worlds/home/home_rug.gdshader")

## Cores do loft (noturno e quente; o néon dá o toque de "game").
const FLOOR_WOOD: Color = Color(0.4, 0.25, 0.15)
const FURNITURE_WOOD: Color = Color(0.3, 0.19, 0.11)
const DOOR_WOOD: Color = Color(0.2, 0.12, 0.07)
const PLASTER_TINT: Color = Color(0.86, 0.8, 0.72)
const CEILING_TINT: Color = Color(0.32, 0.32, 0.34)
const STEEL_COLOR: Color = Color(0.09, 0.09, 0.1)
const SOFA_COLOR: Color = Color(0.13, 0.25, 0.3)
const CUSHION_COLOR: Color = Color(0.72, 0.42, 0.2)
const LAMP_COLOR: Color = Color(1.0, 0.74, 0.48)
const NEON_COLOR: Color = Color(0.95, 0.25, 0.8)
const DAYLIGHT_COLOR: Color = Color(0.82, 0.88, 1.0)
## Força da luz do dia que entra pela janela (de dia; à noite, zero).
const DAYLIGHT_ENERGY: float = 2.2

var _environment: Environment
var _front_door: TravelDoor
var _window_material: ShaderMaterial
var _daylight: SpotLight3D
## 0 = dia, 1 = noite (a cidade avisa pelo grupo city_night).
var _night: float = 1.0


func _ready() -> void:
	add_to_group("home")
	# O mundo avisa a hora pelo grupo city_night (set_night): a janela e a luz
	# do dia acompanham.
	add_to_group("city_night")
	_build_environment()
	_build_room()
	_build_window()
	_build_lights()
	_build_front_door()
	_build_decor()
	_build_furniture()
	_build_indoor_area()
	_put_on_interior_layer(self)


## Onde (e para onde virado) o jogador aparece ao entrar em casa.
func get_spawn_transform() -> Transform3D:
	return Transform3D(global_basis, to_global(SPAWN_SPOT))


## A porta da rua (quem coloca a casa diz para onde ela leva).
func get_front_door() -> TravelDoor:
	return _front_door


## A luz e o fundo de dentro de casa (a câmera usa este no lugar do mundo).
func get_environment() -> Environment:
	return _environment


## A hora lá fora (0 = dia, 1 = noite): o horizonte da janela, a luz do dia que
## entra por ela e a luz ambiente mudam juntos.
func set_night(night: float) -> void:
	_night = clampf(night, 0.0, 1.0)
	if _window_material != null:
		_window_material.set_shader_parameter("night", _night)
	if _daylight != null:
		_daylight.light_energy = DAYLIGHT_ENERGY * (1.0 - _night)
		_daylight.visible = _night < 0.98
	if _environment != null:
		_environment.ambient_light_color = Color(0.45, 0.4, 0.36).lerp(Color(0.55, 0.6, 0.68), 1.0 - _night)
		_environment.ambient_light_energy = lerpf(0.7, 0.3, _night)


func get_night() -> float:
	return _night


# --- Montagem -------------------------------------------------------------------

## Luz de dentro: fundo escuro, luz ambiente quente e fraca (quem ilumina de
## verdade são as luminárias) e o mesmo "filme" de cor da cidade.
func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.015, 0.015, 0.02)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.45, 0.4, 0.36)
	_environment.ambient_light_energy = 0.35
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.glow_enabled = true
	_environment.glow_hdr_threshold = 1.0
	_environment.ssao_enabled = true
	_apply_quality()
	AppConfig.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		_apply_quality()


## A qualidade gráfica vale aqui também. Névoa volumétrica, não: dentro de
## casa ela só deixa o ar enevoado (e custa caro).
func _apply_quality() -> void:
	GraphicsQuality.apply_to_environment(_environment, AppConfig.get_quality())
	_environment.volumetric_fog_enabled = false


## Chão, teto e as quatro paredes (com colisão). As paredes ficam do lado de
## fora do volume interno, então ROOM_SIZE é o espaço livre de verdade.
## Piso de tábuas, tijolo aparente na parede da janela, reboco nas outras,
## teto de concreto com vigas de aço.
func _build_room() -> void:
	var w := ROOM_SIZE.x
	var h := ROOM_SIZE.y
	var d := ROOM_SIZE.z
	var t := WALL_THICKNESS
	_add_box("Floor", Vector3(w + t * 2.0, t, d + t * 2.0), Vector3(0.0, -t / 2.0, 0.0), HomeMaterials.wood(FLOOR_WOOD, true, 0.42))
	_add_box("Ceiling", Vector3(w + t * 2.0, t, d + t * 2.0), Vector3(0.0, h + t / 2.0, 0.0), HomeMaterials.pbr("Concrete048", 4.0, CEILING_TINT))
	var plaster := HomeMaterials.pbr("Concrete048", 3.0, PLASTER_TINT)
	_add_box("WallNorth", Vector3(w + t * 2.0, h, t), Vector3(0.0, h / 2.0, -d / 2.0 - t / 2.0), HomeMaterials.pbr("Bricks097", 1.6, Color(0.85, 0.78, 0.74)))
	_add_box("WallSouth", Vector3(w + t * 2.0, h, t), Vector3(0.0, h / 2.0, d / 2.0 + t / 2.0), plaster)
	_add_box("WallWest", Vector3(t, h, d), Vector3(-w / 2.0 - t / 2.0, h / 2.0, 0.0), plaster)
	_add_box("WallEast", Vector3(t, h, d), Vector3(w / 2.0 + t / 2.0, h / 2.0, 0.0), plaster)

	# Rodapé escuro nas três paredes de reboco.
	var skirting := HomeMaterials.matte(Color(0.12, 0.1, 0.09), 0.6)
	_add_box("SkirtingSouth", Vector3(w, 0.1, 0.02), Vector3(0.0, 0.05, d / 2.0 - 0.01), skirting, false)
	_add_box("SkirtingWest", Vector3(0.02, 0.1, d), Vector3(-w / 2.0 + 0.01, 0.05, 0.0), skirting, false)
	_add_box("SkirtingEast", Vector3(0.02, 0.1, d), Vector3(w / 2.0 - 0.01, 0.05, 0.0), skirting, false)

	# Vigas de aço no teto, de leste a oeste.
	var steel := HomeMaterials.metal(STEEL_COLOR, 0.55)
	for z in [-d / 3.0, 0.0, d / 3.0]:
		_add_box("Beam", Vector3(w, 0.22, 0.16), Vector3(0.0, h - 0.11, z), steel, false)


## O janelão da parede norte: o vidro mostra o horizonte (home_window.gdshader)
## e a moldura de aço o divide em quadros, como num galpão antigo. De dia, uma
## luz fria entra por ele.
func _build_window() -> void:
	var inner_z := -ROOM_SIZE.z / 2.0
	_window_material = ShaderMaterial.new()
	_window_material.shader = WINDOW_SHADER
	var glass := MeshInstance3D.new()
	glass.name = "WindowView"
	var quad := QuadMesh.new()
	quad.size = WINDOW_SIZE
	glass.mesh = quad
	glass.material_override = _window_material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = Vector3(0.0, WINDOW_CENTER_Y, inner_z + 0.01)
	add_child(glass)

	var steel := HomeMaterials.metal(STEEL_COLOR, 0.5)
	var half := WINDOW_SIZE / 2.0
	var bar := 0.06
	var depth := 0.06
	var z := inner_z + depth / 2.0
	# Bordas e travessas (horizontais) e montantes (verticais).
	for y in [-half.y, half.y, half.y - 0.7]:
		_add_box("WindowBar", Vector3(WINDOW_SIZE.x + bar, bar, depth), Vector3(0.0, WINDOW_CENTER_Y + y, z), steel, false)
	for i in 5:
		var x := -half.x + i * WINDOW_SIZE.x / 4.0
		_add_box("WindowPost", Vector3(bar, WINDOW_SIZE.y, depth), Vector3(x, WINDOW_CENTER_Y, z), steel, false)
	# Peitoril de concreto embaixo.
	_add_box("WindowSill", Vector3(WINDOW_SIZE.x + 0.3, 0.06, 0.22),
			Vector3(0.0, WINDOW_CENTER_Y - half.y - 0.03, inner_z + 0.11), HomeMaterials.pbr("Concrete034", 1.5, Color(0.7, 0.7, 0.7)))

	_daylight = SpotLight3D.new()
	_daylight.name = "Daylight"
	_daylight.light_color = DAYLIGHT_COLOR
	_daylight.spot_range = 12.0
	_daylight.spot_angle = 70.0
	_daylight.spot_attenuation = 0.8
	_daylight.position = Vector3(0.0, WINDOW_CENTER_Y + 0.6, inner_z + 0.2)
	_daylight.rotation = Vector3(deg_to_rad(-30.0), 0.0, 0.0)  # para dentro (sul) e para baixo
	add_child(_daylight)
	set_night(_night)


## Três pendentes quentes nas vigas: fio, cúpula de metal, lâmpada e a luz.
func _build_lights() -> void:
	for spot in [Vector2(-3.0, 0.0), Vector2(1.6, -ROOM_SIZE.z / 3.0), Vector2(3.0, 0.0)]:
		_add_pendant(Vector3(spot.x, 0.0, spot.y))


func _add_pendant(at: Vector3) -> void:
	var bulb_y := ROOM_SIZE.y - 0.95
	var cord := MeshInstance3D.new()
	cord.name = "PendantCord"
	var cord_mesh := CylinderMesh.new()
	cord_mesh.top_radius = 0.008
	cord_mesh.bottom_radius = 0.008
	cord_mesh.height = 0.8
	cord.mesh = cord_mesh
	cord.material_override = HomeMaterials.matte(Color(0.05, 0.05, 0.05))
	cord.position = Vector3(at.x, ROOM_SIZE.y - 0.4, at.z)
	add_child(cord)
	var shade := MeshInstance3D.new()
	shade.name = "PendantShade"
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius = 0.06
	shade_mesh.bottom_radius = 0.26
	shade_mesh.height = 0.22
	shade_mesh.cap_bottom = false
	shade.mesh = shade_mesh
	shade.material_override = HomeMaterials.metal(Color(0.12, 0.1, 0.08), 0.4)
	shade.position = Vector3(at.x, bulb_y + 0.06, at.z)
	add_child(shade)
	var bulb := MeshInstance3D.new()
	bulb.name = "PendantBulb"
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.06
	bulb_mesh.height = 0.12
	bulb.mesh = bulb_mesh
	bulb.material_override = HomeMaterials.glow(LAMP_COLOR, 6.0)
	bulb.position = Vector3(at.x, bulb_y, at.z)
	add_child(bulb)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = LAMP_COLOR
	lamp.light_energy = 1.5
	lamp.omni_range = 7.0
	lamp.omni_attenuation = 1.1
	lamp.position = Vector3(at.x, bulb_y - 0.1, at.z)
	add_child(lamp)


## Porta da rua, na parede sul, com a frente para dentro da sala (de onde o
## jogador vem). Para onde ela leva quem decide é o mundo.
func _build_front_door() -> void:
	var z := ROOM_SIZE.z / 2.0
	var wood := HomeMaterials.wood(DOOR_WOOD, false, 0.45)
	_add_box("DoorPanel", Vector3(1.1, 2.2, 0.06), Vector3(0.0, 1.1, z - 0.03), wood, false)
	# Batente em volta e a maçaneta.
	var frame := HomeMaterials.matte(Color(0.1, 0.08, 0.07), 0.5)
	for x in [-0.6, 0.6]:
		_add_box("DoorJamb", Vector3(0.1, 2.3, 0.1), Vector3(x, 1.15, z - 0.05), frame, false)
	_add_box("DoorHead", Vector3(1.3, 0.1, 0.1), Vector3(0.0, 2.3, z - 0.05), frame, false)
	_add_box("DoorHandle", Vector3(0.12, 0.03, 0.05), Vector3(-0.4, 1.0, z - 0.09), HomeMaterials.metal(Color(0.75, 0.62, 0.35), 0.3), false)
	# Arandela quente em cima da porta: a saída fica fácil de achar.
	_add_box("DoorSconce", Vector3(0.36, 0.08, 0.1), Vector3(0.0, 2.55, z - 0.05), HomeMaterials.glow(LAMP_COLOR, 4.0), false)
	var sconce := OmniLight3D.new()
	sconce.name = "DoorLight"
	sconce.light_color = LAMP_COLOR
	sconce.light_energy = 0.9
	sconce.omni_range = 3.5
	sconce.position = Vector3(0.0, 2.4, z - 0.35)
	add_child(sconce)
	_front_door = TravelDoor.new()
	_front_door.name = "FrontDoor"
	_front_door.door_name = "Porta da rua"
	_front_door.position = Vector3(0.0, 0.0, z - 0.1)
	_front_door.rotation.y = PI  # a frente (+Z) da porta aponta para dentro da sala
	add_child(_front_door)


## O canto de estar, virado para a janela: tapete, sofá, mesinha e um abajur
## de chão. Mais a faixa de néon perto do teto, nas paredes do lado.
func _build_decor() -> void:
	_add_rug(Vector3(0.0, 0.0, -2.9), Vector2(3.2, 2.4))
	_add_sofa(Vector3(0.0, 0.0, -1.9))
	_add_coffee_table(Vector3(0.0, 0.0, -3.2))
	_add_floor_lamp(Vector3(-1.6, 0.0, -1.9))
	_add_neon()


func _add_rug(center: Vector3, rug_size: Vector2) -> void:
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var plane := PlaneMesh.new()
	plane.size = rug_size
	rug.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = RUG_SHADER
	rug.material_override = material
	rug.position = center + Vector3(0.0, 0.006, 0.0)
	add_child(rug)


## Sofá de três lugares com a frente para o norte (a janela): assento, encosto,
## braços e duas almofadas. Tem colisão (o jogador dá a volta).
func _add_sofa(center: Vector3) -> void:
	var cloth := HomeMaterials.fabric(SOFA_COLOR)
	var width := 2.2
	var depth := 0.9
	var x := center.x
	var z := center.z
	_add_box("SofaBase", Vector3(width, 0.25, depth), Vector3(x, 0.17, z), cloth)
	_add_box("SofaSeat", Vector3(width - 0.4, 0.14, depth - 0.2), Vector3(x, 0.36, z - 0.07), cloth, false)
	_add_box("SofaBack", Vector3(width, 0.55, 0.22), Vector3(x, 0.57, z + depth / 2.0 - 0.11), cloth)
	for side in [-1.0, 1.0]:
		_add_box("SofaArm", Vector3(0.2, 0.32, depth), Vector3(x + side * (width / 2.0 - 0.1), 0.45, z), cloth, false)
		_add_box("SofaFoot", Vector3(0.05, 0.05, 0.05), Vector3(x + side * (width / 2.0 - 0.08), 0.025, z - depth / 2.0 + 0.08), HomeMaterials.metal(STEEL_COLOR), false)
	var cushion := HomeMaterials.fabric(CUSHION_COLOR)
	for side in [-1.0, 1.0]:
		var pillow := _add_box("SofaCushion", Vector3(0.42, 0.38, 0.12), Vector3(x + side * 0.6, 0.62, z + depth / 2.0 - 0.3), cushion, false)
		pillow.rotation = Vector3(deg_to_rad(-12.0), side * deg_to_rad(8.0), 0.0)


func _add_coffee_table(center: Vector3) -> void:
	var wood := HomeMaterials.wood(FURNITURE_WOOD, false, 0.35)
	_add_box("CoffeeTable", Vector3(1.1, 0.06, 0.55), center + Vector3(0.0, 0.38, 0.0), wood)
	var steel := HomeMaterials.metal(STEEL_COLOR)
	for sx in [-0.5, 0.5]:
		for sz in [-0.22, 0.22]:
			_add_box("CoffeeTableLeg", Vector3(0.04, 0.35, 0.04), center + Vector3(sx, 0.175, sz), steel, false)
	# Um controle de videogame em cima da mesa.
	_add_box("Gamepad", Vector3(0.16, 0.03, 0.1), center + Vector3(0.2, 0.425, 0.05), HomeMaterials.matte(Color(0.08, 0.08, 0.09), 0.4), false)


## Abajur de chão ao lado do sofá: pé de metal, cúpula de tecido e luz quente.
func _add_floor_lamp(at: Vector3) -> void:
	var steel := HomeMaterials.metal(STEEL_COLOR)
	_add_box("FloorLampBase", Vector3(0.3, 0.03, 0.3), at + Vector3(0.0, 0.015, 0.0), steel)
	_add_box("FloorLampPole", Vector3(0.03, 1.45, 0.03), at + Vector3(0.0, 0.75, 0.0), steel, false)
	var shade := MeshInstance3D.new()
	shade.name = "FloorLampShade"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.22
	mesh.height = 0.3
	mesh.cap_top = false
	mesh.cap_bottom = false
	shade.mesh = mesh
	var cloth := HomeMaterials.glow(Color(1.0, 0.86, 0.66), 0.9).duplicate() as StandardMaterial3D
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	shade.material_override = cloth
	shade.position = at + Vector3(0.0, 1.55, 0.0)
	add_child(shade)
	var light := OmniLight3D.new()
	light.name = "FloorLampLight"
	light.light_color = LAMP_COLOR
	light.light_energy = 0.9
	light.omni_range = 4.0
	light.position = at + Vector3(0.0, 1.5, 0.0)
	add_child(light)


## Faixa de néon rosa perto do teto, nas paredes oeste e leste (por cima da
## estante e do mural), com uma luz fraca da mesma cor.
func _add_neon() -> void:
	var y := ROOM_SIZE.y - 0.32
	for side in [-1.0, 1.0]:
		var x: float = side * (ROOM_SIZE.x / 2.0 - 0.04)
		_add_box("NeonStrip", Vector3(0.03, 0.03, ROOM_SIZE.z - 1.0), Vector3(x, y, 0.0), HomeMaterials.glow(NEON_COLOR, 4.0), false)
		var light := OmniLight3D.new()
		light.name = "NeonLight"
		light.light_color = NEON_COLOR
		light.light_energy = 0.45
		light.omni_range = 4.5
		light.position = Vector3(x - side * 0.4, y - 0.2, 0.0)
		add_child(light)


## Os móveis, um por linha (cada um é um script em worlds/home/).
func _build_furniture() -> void:
	_add_shelf()
	_add_friends_wall()
	_add_computer()


## A estante da biblioteca, na parede oeste, de frente para o leste.
func _add_shelf() -> void:
	var shelf := LibraryShelf.new()
	shelf.name = "LibraryShelf"
	shelf.position = Vector3(-ROOM_SIZE.x / 2.0, 0.0, -0.5)
	shelf.rotation.y = PI / 2.0  # a frente (+Z) da estante aponta para o leste
	add_child(shelf)


## O mural dos amigos, na parede leste, de frente para o oeste. Amigo que não
## joga nada da biblioteca leva até onde a porta da rua leva (a praça).
func _add_friends_wall() -> void:
	var wall := FriendsWall.new()
	wall.name = "FriendsWall"
	wall.position = Vector3(ROOM_SIZE.x / 2.0, 0.0, -0.5)
	wall.rotation.y = -PI / 2.0  # a frente (+Z) do mural aponta para o oeste
	wall.fallback_door = _front_door
	add_child(wall)


## A mesa do computador, encostada na parede norte, à direita da janela, de
## frente para a sala.
func _add_computer() -> void:
	var desk := ComputerDesk.new()
	desk.name = "ComputerDesk"
	desk.position = Vector3(3.6, 0.0, -ROOM_SIZE.z / 2.0 + ComputerDesk.DESK_SIZE.z / 2.0 + 0.05)
	add_child(desk)


## Área "em casa": avisa o jogador quando ele entra e quando sai.
func _build_indoor_area() -> void:
	var area := Area3D.new()
	area.name = "IndoorArea"
	area.collision_layer = 0
	area.collision_mask = 2  # o jogador
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ROOM_SIZE
	shape.shape = box
	shape.position = Vector3(0.0, ROOM_SIZE.y / 2.0, 0.0)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("set_indoors"):
			body.set_indoors(_environment))
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.has_method("set_indoors"):
			body.set_indoors(null))


# --- Peças --------------------------------------------------------------------

## Caixa com material e, se "solid", colisão (camada 1, o chão e as paredes).
func _add_box(box_name: String, box_size: Vector3, center: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = box_name
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box_size
		shape.shape = box_shape
		body.add_child(shape)
		mesh.add_child(body)
	return mesh


## Tudo o que a casa desenha vai para a camada do interior (o sol do mundo
## não ilumina essa camada).
func _put_on_interior_layer(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = INTERIOR_LAYER_MASK
	for child in node.get_children():
		_put_on_interior_layer(child)

