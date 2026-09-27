extends Node3D
## Mundo 1: a cidade (por enquanto, uma praça cercada de blocos).
##
## Regra da arquitetura: o mundo só monta o cenário e posiciona portais.
## Nenhuma lógica de Steam mora aqui.
##
## Tudo é criado por código em _ready(), para a cena (.tscn) ficar simples.
## Convenção: Y é "para cima"; a praça fica no centro (0, 0, 0).

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

const GROUND_SIZE: float = 80.0
const PLAZA_SIZE: float = 24.0
const BORDER_WALL_HEIGHT: float = 3.0
## Onde o jogador nasce (um pouco acima do chão para não "enroscar").
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0.1, 6.0)


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_border_walls()
	_build_buildings()
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
	_add_building(Vector3(0.0, 0.0, -22.0), Vector3(12.0, 10.0, 12.0), Color("4f6d8f"))
	_add_building(Vector3(-18.0, 0.0, -22.0), Vector3(8.0, 14.0, 10.0), Color("c77d5a"))
	_add_building(Vector3(18.0, 0.0, -22.0), Vector3(8.0, 8.0, 10.0), Color("d9b36c"))
	_add_building(Vector3(-22.0, 0.0, 0.0), Vector3(10.0, 12.0, 14.0), Color("8e6c9e"))
	_add_building(Vector3(22.0, 0.0, 0.0), Vector3(10.0, 6.0, 14.0), Color("6fa38a"))
	_add_building(Vector3(-18.0, 0.0, 22.0), Vector3(10.0, 9.0, 8.0), Color("b5655f"))
	_add_building(Vector3(0.0, 0.0, 24.0), Vector3(12.0, 16.0, 8.0), Color("7a8591"))
	_add_building(Vector3(18.0, 0.0, 22.0), Vector3(10.0, 11.0, 8.0), Color("c9a27e"))


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
