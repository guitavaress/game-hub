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
const SPAWN_SPOT: Vector3 = Vector3(0.0, 0.1, 1.0)

## Cores provisórias (o acabamento final é da subetapa 9.9).
const FLOOR_COLOR: Color = Color(0.32, 0.22, 0.15)
const WALL_COLOR: Color = Color(0.55, 0.52, 0.48)
const CEILING_COLOR: Color = Color(0.2, 0.2, 0.21)
const DOOR_COLOR: Color = Color(0.18, 0.12, 0.08)
const WINDOW_COLOR: Color = Color(0.1, 0.16, 0.3)
const LAMP_COLOR: Color = Color(1.0, 0.78, 0.55)

var _environment: Environment
var _front_door: TravelDoor


func _ready() -> void:
	add_to_group("home")
	_build_environment()
	_build_room()
	_build_lights()
	_build_front_door()
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
	GraphicsQuality.apply_to_environment(_environment, AppConfig.get_quality())
	AppConfig.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		GraphicsQuality.apply_to_environment(_environment, AppConfig.get_quality())


## Chão, teto e as quatro paredes (com colisão). As paredes ficam do lado de
## fora do volume interno, então ROOM_SIZE é o espaço livre de verdade.
func _build_room() -> void:
	var w := ROOM_SIZE.x
	var h := ROOM_SIZE.y
	var d := ROOM_SIZE.z
	var t := WALL_THICKNESS
	_add_box("Floor", Vector3(w + t * 2.0, t, d + t * 2.0), Vector3(0.0, -t / 2.0, 0.0), _material(FLOOR_COLOR, 0.7))
	_add_box("Ceiling", Vector3(w + t * 2.0, t, d + t * 2.0), Vector3(0.0, h + t / 2.0, 0.0), _material(CEILING_COLOR, 0.9))
	var wall := _material(WALL_COLOR, 0.85)
	_add_box("WallNorth", Vector3(w + t * 2.0, h, t), Vector3(0.0, h / 2.0, -d / 2.0 - t / 2.0), wall)
	_add_box("WallSouth", Vector3(w + t * 2.0, h, t), Vector3(0.0, h / 2.0, d / 2.0 + t / 2.0), wall)
	_add_box("WallWest", Vector3(t, h, d), Vector3(-w / 2.0 - t / 2.0, h / 2.0, 0.0), wall)
	_add_box("WallEast", Vector3(t, h, d), Vector3(w / 2.0 + t / 2.0, h / 2.0, 0.0), wall)

	# Janela provisória na parede norte: um painel azul-escuro que brilha de
	# leve (o horizonte de verdade vem na 9.9).
	var window_material := _material(WINDOW_COLOR, 0.2)
	window_material.emission_enabled = true
	window_material.emission = WINDOW_COLOR
	window_material.emission_energy_multiplier = 0.6
	_add_box("Window", Vector3(5.0, 1.8, 0.04), Vector3(0.0, 1.7, -d / 2.0 + 0.02), window_material, false)


## Duas luminárias quentes no teto.
func _build_lights() -> void:
	for x in [-ROOM_SIZE.x / 4.0, ROOM_SIZE.x / 4.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp"
		lamp.light_color = LAMP_COLOR
		lamp.light_energy = 1.6
		lamp.omni_range = 8.0
		lamp.omni_attenuation = 1.2
		lamp.position = Vector3(x, ROOM_SIZE.y - 0.4, 0.0)
		add_child(lamp)
		var bulb_material := _material(LAMP_COLOR, 0.5)
		bulb_material.emission_enabled = true
		bulb_material.emission = LAMP_COLOR
		bulb_material.emission_energy_multiplier = 3.0
		_add_box("LampShade", Vector3(0.5, 0.08, 0.5), Vector3(x, ROOM_SIZE.y - 0.04, 0.0), bulb_material, false)


## Porta da rua, na parede sul, com a frente para dentro da sala (de onde o
## jogador vem). Para onde ela leva quem decide é o mundo.
func _build_front_door() -> void:
	var z := ROOM_SIZE.z / 2.0
	_add_box("DoorPanel", Vector3(1.1, 2.2, 0.06), Vector3(0.0, 1.1, z - 0.03), _material(DOOR_COLOR, 0.6), false)
	_front_door = TravelDoor.new()
	_front_door.name = "FrontDoor"
	_front_door.door_name = "Porta da rua"
	_front_door.position = Vector3(0.0, 0.0, z - 0.1)
	_front_door.rotation.y = PI  # a frente (+Z) da porta aponta para dentro da sala
	add_child(_front_door)


## Os móveis, um por linha (cada um é um script em worlds/home/).
func _build_furniture() -> void:
	_add_shelf()
	# 9.5: mural (parede leste) · 9.7: computador (perto da janela)


## A estante da biblioteca, na parede oeste, de frente para o leste.
func _add_shelf() -> void:
	var shelf := LibraryShelf.new()
	shelf.name = "LibraryShelf"
	shelf.position = Vector3(-ROOM_SIZE.x / 2.0, 0.0, -0.5)
	shelf.rotation.y = PI / 2.0  # a frente (+Z) da estante aponta para o leste
	add_child(shelf)


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


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


## Tudo o que a casa desenha vai para a camada do interior (o sol do mundo
## não ilumina essa camada).
func _put_on_interior_layer(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = INTERIOR_LAYER_MASK
	for child in node.get_children():
		_put_on_interior_layer(child)
