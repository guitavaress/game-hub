extends Node3D
## Mundo 1: a cidade (por enquanto, uma praça cercada de blocos).
##
## Regra da arquitetura: o mundo só monta o cenário e posiciona portais.
## Nenhuma lógica de Steam mora aqui.
##
## Tudo é criado por código em _ready(), para a cena (.tscn) ficar simples.
## Convenção: Y é "para cima"; a praça fica no centro (0, 0, 0).

## >>> TROQUE AQUI o App ID do jogo do prédio de teste. <<<
## Também dá para trocar no editor: selecione o nó "City" e mude no Inspector.
## (Para achar o App ID: na loja da Steam, é o número na URL do jogo.)
@export var portal_app_id: int = 2379780  # Balatro

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const PORTAL_SCENE: PackedScene = preload("res://components/game_portal/game_portal.tscn")

const GROUND_SIZE: float = 80.0
const PLAZA_SIZE: float = 24.0
const BORDER_WALL_HEIGHT: float = 3.0
## Onde o jogador nasce (um pouco acima do chão para não "enroscar").
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0.1, 6.0)

## Vão da porta do prédio do jogo (largura, altura, profundidade), em metros.
const DOOR_WIDTH: float = 2.4
const DOOR_HEIGHT: float = 3.0
const DOOR_DEPTH: float = 1.6


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_border_walls()
	_build_buildings()
	_build_game_building(Vector3(0.0, 0.0, -22.0), Vector3(12.0, 10.0, 12.0), Color("4f6d8f"), portal_app_id)
	_spawn_player()


# --- Céu e luz ---------------------------------------------------------------

func _build_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true  # faz materiais que "brilham" (emissão) ficarem bonitos

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


# --- Chão, praça e muros -----------------------------------------------------

func _build_ground() -> void:
	# Chão com colisão: uma caixa grande e fina cujo topo fica em y = 0.
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(GROUND_SIZE, 1.0, GROUND_SIZE)
	ground.position = Vector3(0.0, -0.5, 0.0)
	ground.material = _make_material(Color("5f7a4f"))
	ground.use_collision = true
	add_child(ground)

	# Piso da praça: só visual (não precisa de colisão, o chão já tem).
	var plaza := MeshInstance3D.new()
	plaza.name = "Plaza"
	var plaza_mesh := PlaneMesh.new()
	plaza_mesh.size = Vector2(PLAZA_SIZE, PLAZA_SIZE)
	plaza.mesh = plaza_mesh
	plaza.position = Vector3(0.0, 0.01, 0.0)
	plaza.material_override = _make_material(Color("b8b2a4"))
	add_child(plaza)

	# Um "chafariz" no meio da praça, como ponto de referência.
	var fountain := CSGCylinder3D.new()
	fountain.name = "Fountain"
	fountain.radius = 2.0
	fountain.height = 0.6
	fountain.sides = 24
	fountain.position = Vector3(0.0, 0.3, 0.0)
	fountain.material = _make_material(Color("8a8f99"))
	fountain.use_collision = true
	add_child(fountain)


func _build_border_walls() -> void:
	# Quatro muros nas bordas para ninguém cair do mapa.
	var half := GROUND_SIZE / 2.0
	var y := BORDER_WALL_HEIGHT / 2.0
	var color := Color("6b625a")
	_add_block("WallNorth", Vector3(0.0, y, -half), Vector3(GROUND_SIZE, BORDER_WALL_HEIGHT, 1.0), color)
	_add_block("WallSouth", Vector3(0.0, y, half), Vector3(GROUND_SIZE, BORDER_WALL_HEIGHT, 1.0), color)
	_add_block("WallWest", Vector3(-half, y, 0.0), Vector3(1.0, BORDER_WALL_HEIGHT, GROUND_SIZE), color)
	_add_block("WallEast", Vector3(half, y, 0.0), Vector3(1.0, BORDER_WALL_HEIGHT, GROUND_SIZE), color)


# --- Prédios -----------------------------------------------------------------

func _build_buildings() -> void:
	# Blocos no lugar dos prédios, em volta da praça.
	# (posição do centro da base no chão, tamanho, cor)
	_add_building(Vector3(-18.0, 0.0, -22.0), Vector3(8.0, 14.0, 10.0), Color("c77d5a"))
	_add_building(Vector3(18.0, 0.0, -22.0), Vector3(8.0, 8.0, 10.0), Color("d9b36c"))
	_add_building(Vector3(-22.0, 0.0, 0.0), Vector3(10.0, 12.0, 14.0), Color("8e6c9e"))
	_add_building(Vector3(22.0, 0.0, 0.0), Vector3(10.0, 6.0, 14.0), Color("6fa38a"))
	_add_building(Vector3(-18.0, 0.0, 22.0), Vector3(10.0, 9.0, 8.0), Color("b5655f"))
	_add_building(Vector3(0.0, 0.0, 24.0), Vector3(12.0, 16.0, 8.0), Color("7a8591"))
	_add_building(Vector3(18.0, 0.0, 22.0), Vector3(10.0, 11.0, 8.0), Color("c9a27e"))


## Prédio de um jogo: bloco com vão de porta, moldura, placa com o nome e um
## GamePortal no vão. "base" é o centro do prédio no chão; a porta fica na
## face +Z (virada para a praça). Para virar o prédio, gire o nó "GameBuilding".
func _build_game_building(base: Vector3, size: Vector3, color: Color, app_id: int) -> void:
	# Nó raiz do prédio: tudo abaixo dele usa coordenadas locais.
	var building := Node3D.new()
	building.name = "GameBuilding"
	building.position = base
	add_child(building)

	var front_z := size.z / 2.0  # a fachada (face da frente) fica em z = front_z

	# Corpo do prédio com o vão da porta recortado.
	# CSG = "somar e subtrair formas": caixa grande MENOS uma caixa no lugar da porta.
	var body := CSGCombiner3D.new()
	body.name = "Body"
	body.use_collision = true
	building.add_child(body)

	var walls := CSGBox3D.new()
	walls.size = size
	walls.position = Vector3(0.0, size.y / 2.0, 0.0)
	walls.material = _make_material(color)
	body.add_child(walls)

	var doorway := CSGBox3D.new()
	doorway.operation = CSGShape3D.OPERATION_SUBTRACTION
	# 10 cm maior para baixo e para fora, para o recorte ficar limpo.
	doorway.size = Vector3(DOOR_WIDTH, DOOR_HEIGHT + 0.1, DOOR_DEPTH + 0.1)
	doorway.position = Vector3(0.0, (DOOR_HEIGHT - 0.1) / 2.0, front_z - DOOR_DEPTH / 2.0 + 0.05)
	doorway.material = _make_material(color.darkened(0.35))  # paredes internas do vão
	body.add_child(doorway)

	# "Porta" brilhante no fundo do vão (só visual).
	var door_glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(DOOR_WIDTH, DOOR_HEIGHT)
	door_glow.mesh = quad
	door_glow.position = Vector3(0.0, DOOR_HEIGHT / 2.0, front_z - DOOR_DEPTH + 0.01)
	door_glow.material_override = _make_glow_material(Color("3fa9f5"), 1.5)
	building.add_child(door_glow)

	# Moldura da porta: dois pilares e uma viga (só visual).
	var frame_material := _make_glow_material(Color("ffb347"), 0.8)
	var post_size := Vector3(0.3, DOOR_HEIGHT + 0.3, 0.3)
	var post_x := DOOR_WIDTH / 2.0 + 0.15
	_add_visual_box(building, Vector3(-post_x, post_size.y / 2.0, front_z + 0.1), post_size, frame_material)
	_add_visual_box(building, Vector3(post_x, post_size.y / 2.0, front_z + 0.1), post_size, frame_material)
	_add_visual_box(building, Vector3(0.0, DOOR_HEIGHT + 0.15, front_z + 0.1),
			Vector3(DOOR_WIDTH + 0.9, 0.3, 0.3), frame_material)

	# O portal propriamente dito, no chão, no meio do vão, com +Z para fora.
	var portal := PORTAL_SCENE.instantiate() as GamePortal
	portal.name = "GamePortal"
	portal.app_id = app_id
	portal.look_size = Vector3(size.x, size.y, 1.0)  # olhar para a fachada inteira mostra o nome
	portal.position = Vector3(0.0, 0.0, front_z)
	building.add_child(portal)

	# Placa com o nome do jogo, acima da porta.
	var name_sign := Label3D.new()
	name_sign.name = "Sign"
	name_sign.text = portal.get_look_label()
	name_sign.font_size = 128   # resolução do texto (mais alto = mais nítido)
	name_sign.pixel_size = 0.008  # metros por pixel: 128 px x 0,008 = ~1 m de altura
	name_sign.outline_size = 24
	name_sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_sign.width = (size.x - 1.0) / name_sign.pixel_size  # largura máxima (em pixels do texto)
	name_sign.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_sign.position = Vector3(0.0, DOOR_HEIGHT + 0.7, front_z + 0.05)
	building.add_child(name_sign)


## Caixa só visual (sem colisão), presa ao nó "parent".
func _add_visual_box(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = center
	box.material_override = material
	parent.add_child(box)


## Cria um prédio simples. "base" é o centro do prédio no nível do chão.
func _add_building(base: Vector3, size: Vector3, color: Color) -> void:
	var center := base + Vector3(0.0, size.y / 2.0, 0.0)
	_add_block("Building", center, size, color)


## Cria uma caixa sólida (com colisão) centrada em "center".
func _add_block(block_name: String, center: Vector3, size: Vector3, color: Color) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = block_name
	box.size = size
	box.position = center
	box.material = _make_material(color)
	box.use_collision = true
	add_child(box, true)  # true = a Godot numera nomes repetidos (Building2, Building3...)
	return box


# --- Jogador -----------------------------------------------------------------

func _spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = PLAYER_SPAWN
	add_child(player)


# --- Utilidades --------------------------------------------------------------

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


## Material que "brilha" (emite luz própria).
func _make_glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _make_material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
