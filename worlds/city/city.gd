extends Node3D
## Mundo 1: a cidade, gerada a partir da biblioteca Steam.
##
## Cada jogo instalado vira um prédio (CityBuilding, com um GamePortal na
## porta). Os jogos são agrupados em BAIRROS pela categoria (GameCategories):
## cada bairro ocupa quarteirões inteiros, com o chão na cor dele e uma placa
## flutuante com o nome. A grade de ruas está em CityLayout.
##
## Regra da arquitetura: o mundo só monta cenário e posiciona portais.
## Quem sabe quais jogos existem e de que categoria são são os sistemas
## (SteamLibrary, StoreInfo, GameCategories); aqui só perguntamos a eles.

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

const BORDER_WALL_HEIGHT: float = 3.0
## Onde o jogador nasce: na praça, virado para o norte (-Z).
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0.1, 6.0)
## Quanto tempo esperamos a loja responder na primeira vez (segundos).
const STORE_WAIT_SECONDS: float = 8.0
## Altura dos prédios (sorteada por jogo, mas sempre igual para o mesmo jogo).
const BUILDING_MIN_HEIGHT: float = 13.0
const BUILDING_MAX_HEIGHT: float = 19.0
const BUILDING_FOOTPRINT: float = 10.0
## Altura da placa flutuante com o nome do bairro.
const DISTRICT_SIGN_HEIGHT: float = 25.0


func _ready() -> void:
	ScreenFade.set_amount(1.0)  # tela preta enquanto a cidade é montada
	_build_environment()

	var games := SteamLibrary.get_installed_games()
	await _update_store_info(games)

	var districts := _group_into_districts(games)
	var cells := _build_districts(districts)
	_build_ground_and_walls(CityLayout.half_extent(cells))
	_build_plaza()

	var player := _spawn_player()
	_show_startup_messages(player, games)

	ScreenFade.set_message("")
	ScreenFade.fade_in(0.8)


# --- Dados -------------------------------------------------------------------

## Pede à loja as tags que faltam. Na primeira vez pode demorar um pouco;
## depois, tudo vem do cache e isto termina na hora.
func _update_store_info(games: Array[SteamGame]) -> void:
	var app_ids: Array[int] = []
	for game in games:
		app_ids.append(game.app_id)
	StoreInfo.fetch(app_ids)
	if not StoreInfo.is_fetching():
		return

	ScreenFade.set_message("Organizando a cidade...")
	var waited := 0.0
	while StoreInfo.is_fetching() and waited < STORE_WAIT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()


## Agrupa os jogos por categoria, na ordem da tabela de categorias.
## Devolve uma lista de {"id": "rpg", "games": [SteamGame, ...]} (só bairros com jogos).
func _group_into_districts(games: Array[SteamGame]) -> Array[Dictionary]:
	var games_by_category: Dictionary[String, Array] = {}
	for game in games:
		var category_id := GameCategories.get_category_id(game.app_id)
		if not games_by_category.has(category_id):
			games_by_category[category_id] = []
		games_by_category[category_id].append(game)

	var districts: Array[Dictionary] = []
	for category_id in GameCategories.get_category_ids():
		if games_by_category.has(category_id):
			districts.append({"id": category_id, "games": games_by_category[category_id]})
	return districts


# --- Bairros e prédios -------------------------------------------------------

## Monta todos os bairros. Devolve os quarteirões usados (para medir o mapa).
func _build_districts(districts: Array[Dictionary]) -> Array[Vector2i]:
	var block_count := 0
	for district in districts:
		block_count += ceili(district["games"].size() / float(CityLayout.LOTS_PER_BLOCK))
	var cells := CityLayout.block_cells(block_count)

	var next_cell := 0
	for district in districts:
		var district_games: Array = district["games"]
		# Cada quarteirão recebe até 4 jogos do bairro.
		for first in range(0, district_games.size(), CityLayout.LOTS_PER_BLOCK):
			var block_games := district_games.slice(first, first + CityLayout.LOTS_PER_BLOCK)
			_build_block(cells[next_cell], district["id"], block_games)
			next_cell += 1
	return cells


func _build_block(cell: Vector2i, category_id: String, block_games: Array) -> void:
	var category_color := GameCategories.get_category_color(category_id)
	var center := CityLayout.block_center(cell)

	# Chão do quarteirão na cor do bairro (só visual).
	_add_pad(center, Vector2(CityLayout.BLOCK_SIZE, CityLayout.BLOCK_SIZE),
			category_color.darkened(0.45), 0.03)

	# Placa flutuante com o nome do bairro, sempre virada para quem olha.
	var district_sign := Label3D.new()
	district_sign.text = GameCategories.get_category_name(category_id)
	district_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	district_sign.font_size = 128
	district_sign.pixel_size = 0.025
	district_sign.outline_size = 32
	district_sign.modulate = category_color.lightened(0.35)
	district_sign.position = center + Vector3(0.0, DISTRICT_SIGN_HEIGHT, 0.0)
	add_child(district_sign)

	# Prédios nos terrenos; o que sobrar vira pracinha.
	var lots := CityLayout.lots_facing_center_first(cell)
	for i in lots.size():
		var lot := CityLayout.lot_transform(cell, lots[i])
		if i < block_games.size():
			_build_game_building(lot, block_games[i], category_color)
		else:
			_build_park(lot)


func _build_game_building(lot: Transform3D, game: SteamGame, category_color: Color) -> void:
	# Sorteio com "semente" = app_id: o mesmo jogo tem sempre o mesmo prédio.
	var rng := RandomNumberGenerator.new()
	rng.seed = game.app_id

	var building := CityBuilding.new()
	building.name = "Building_%d" % game.app_id
	building.game = game
	building.size = Vector3(BUILDING_FOOTPRINT,
			rng.randf_range(BUILDING_MIN_HEIGHT, BUILDING_MAX_HEIGHT), BUILDING_FOOTPRINT)
	building.color = category_color.lerp(Color.WHITE, rng.randf_range(0.0, 0.3))
	building.transform = lot
	add_child(building)


## Terreno vazio: gramado com algumas árvores.
func _build_park(lot: Transform3D) -> void:
	_add_pad(lot.origin, Vector2(CityLayout.LOT_SIZE - 2.0, CityLayout.LOT_SIZE - 2.0),
			Color("4f7a3a"), 0.07)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lot.origin)
	for i in 3:
		var spot := Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
		_add_tree(lot.origin + spot, rng.randf_range(0.8, 1.2))


func _add_tree(base: Vector3, scale_factor: float) -> void:
	var trunk := CSGCylinder3D.new()
	trunk.radius = 0.25 * scale_factor
	trunk.height = 2.5 * scale_factor
	trunk.position = base + Vector3(0.0, trunk.height / 2.0, 0.0)
	trunk.material = _make_material(Color("6b4a2f"))
	trunk.use_collision = true
	add_child(trunk)

	var canopy := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.6 * scale_factor
	sphere.height = 3.2 * scale_factor
	canopy.mesh = sphere
	canopy.position = base + Vector3(0.0, 3.2 * scale_factor, 0.0)
	canopy.material_override = _make_material(Color("3f7d3a"))
	add_child(canopy)


# --- Céu, chão, praça e muros ------------------------------------------------

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
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_ground_and_walls(half: float) -> void:
	# Chão com colisão (cor de asfalto: o que não é quarteirão vira rua).
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(half * 2.0, 1.0, half * 2.0)
	ground.position = Vector3(0.0, -0.5, 0.0)
	ground.material = _make_material(Color("3a3d42"))
	ground.use_collision = true
	add_child(ground)

	# Muros nas bordas para ninguém cair do mapa.
	var y := BORDER_WALL_HEIGHT / 2.0
	var color := Color("6b625a")
	var length := half * 2.0
	_add_wall(Vector3(0.0, y, -half), Vector3(length, BORDER_WALL_HEIGHT, 1.0), color)
	_add_wall(Vector3(0.0, y, half), Vector3(length, BORDER_WALL_HEIGHT, 1.0), color)
	_add_wall(Vector3(-half, y, 0.0), Vector3(1.0, BORDER_WALL_HEIGHT, length), color)
	_add_wall(Vector3(half, y, 0.0), Vector3(1.0, BORDER_WALL_HEIGHT, length), color)


func _build_plaza() -> void:
	_add_pad(Vector3.ZERO, Vector2(CityLayout.BLOCK_SIZE, CityLayout.BLOCK_SIZE), Color("b8b2a4"), 0.03)

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


# --- Jogador e avisos --------------------------------------------------------

func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = PLAYER_SPAWN
	add_child(player)
	return player


func _show_startup_messages(player: Player, games: Array[SteamGame]) -> void:
	if SteamLibrary.get_steam_path().is_empty():
		player.get_hud().show_message("Não encontrei a Steam neste PC.", 10.0)
		return
	if games.is_empty():
		player.get_hud().show_message("Nenhum jogo instalado encontrado na Steam.", 10.0)
		return

	var without_info := 0
	for game in games:
		if not StoreInfo.has_info(game.app_id):
			without_info += 1
	if without_info > 0:
		player.get_hud().show_message(
				"Não consegui falar com a loja da Steam: %d jogo(s) ficaram no bairro \"Outros\". " % without_info
				+ "Na próxima vez que abrir o hub, eu tento de novo.", 10.0)


# --- Utilidades --------------------------------------------------------------

## Placa fina de chão, só visual (a colisão é do chão de baixo).
func _add_pad(center: Vector3, pad_size: Vector2, pad_color: Color, height: float) -> void:
	var pad := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(pad_size.x, height, pad_size.y)
	pad.mesh = mesh
	pad.position = center + Vector3(0.0, height / 2.0, 0.0)
	pad.material_override = _make_material(pad_color)
	add_child(pad)


## Caixa sólida (com colisão).
func _add_wall(center: Vector3, wall_size: Vector3, wall_color: Color) -> void:
	var wall := CSGBox3D.new()
	wall.name = "Wall"
	wall.size = wall_size
	wall.position = center
	wall.material = _make_material(wall_color)
	wall.use_collision = true
	add_child(wall, true)  # true = a Godot numera nomes repetidos (Wall2, Wall3...)


func _make_material(material_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = material_color
	material.roughness = 0.9
	return material
