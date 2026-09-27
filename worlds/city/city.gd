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
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0.1, 8.0)
## Quanto tempo esperamos a loja responder na primeira vez (segundos).
const STORE_WAIT_SECONDS: float = 8.0
## Altura dos prédios (sorteada por jogo, mas sempre igual para o mesmo jogo).
const BUILDING_MIN_HEIGHT: float = 13.0
const BUILDING_MAX_HEIGHT: float = 19.0
const BUILDING_FOOTPRINT: float = 10.0
## Altura da placa flutuante com o nome do bairro.
const DISTRICT_SIGN_HEIGHT: float = 25.0
## Amigos na praça: em círculos em volta do chafariz.
const PLAZA_FRIEND_RADIUS: float = 4.5
const PLAZA_FRIEND_RING_STEP: float = 2.0
const PLAZA_FRIENDS_PER_RING: int = 10

## Céus HDRI (Poly Haven, CC0) misturados pelo relógio (sky_blend.gdshader).
const SKY_SHADER: Shader = preload("res://worlds/city/sky_blend.gdshader")
const SKY_DAY: Texture2D = preload("res://assets/polyhaven/hdri/kloofendal_48d_partly_cloudy_puresky_2k.hdr")
const SKY_SUNSET: Texture2D = preload("res://assets/polyhaven/hdri/belfast_sunset_puresky_2k.hdr")
const SKY_NIGHT: Texture2D = preload("res://assets/polyhaven/hdri/rogland_clear_night_2k.hdr")

## Bonequinhos dos amigos que estão na praça.
var _plaza_friends: Array[FriendNpc] = []
## Relógio de dia e noite (sol, céu, luzes).
var _day_night: DayNight
## Asfalto: fica "molhado" (reflete mais) à noite.
var _asphalt: StandardMaterial3D
## Placas dos bairros: o néon fica mais forte à noite.
var _district_signs: Array[Label3D] = []


func _ready() -> void:
	ScreenFade.set_amount(1.0)  # tela preta enquanto a cidade é montada
	_build_environment()

	var games := SteamLibrary.get_installed_games()
	await _update_store_info(games)

	var districts := _group_into_districts(games)
	var cells := _build_districts(districts)
	var half := CityLayout.half_extent(cells)
	_build_ground_and_walls(half)
	CityDecor.add_street_markings(self, cells, half)
	CityDecor.add_plaza(self)

	# Amigos jogando algo da cidade aparecem nos portais (o GamePortal cuida
	# disso); os outros amigos online ficam aqui na praça.
	FriendsService.friends_changed.connect(_update_plaza_friends)
	_update_plaza_friends()

	# Postes e janelas (grupo "city_night") acendem conforme a hora.
	_day_night.night_changed.connect(_on_night_changed)
	_on_night_changed(_day_night.get_night())

	var player := _spawn_player()
	_show_startup_messages(player, games)
	_day_night.clock_advanced.connect(func(hour: float) -> void:
		player.get_hud().show_message("Relógio da cidade: %02d:%02d" \
				% [floori(hour), floori(fmod(hour, 1.0) * 60.0)], "F8 adianta 3 horas.", Toast.Kind.INFO, 4.0))

	ScreenFade.set_message("")
	ScreenFade.fade_in(0.8)


func _on_night_changed(night: float) -> void:
	get_tree().call_group("city_night", "set_night", night)
	# Asfalto molhado à noite: menos rugoso = reflete os postes e o néon.
	if _asphalt != null:
		_asphalt.roughness = lerpf(1.0, 0.35, night)
	for district_sign in _district_signs:
		var color: Color = district_sign.get_meta("neon")
		var glow := lerpf(0.9, 1.6, night)
		district_sign.modulate = Color(color.r * glow, color.g * glow, color.b * glow)


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

	# Calçada em volta e o miolo do quarteirão na cor do bairro; postes nos cantos.
	CityDecor.add_block_ground(self, center, category_color)
	CityDecor.add_block_lights(self, center)

	# Letreiro flutuante com o nome do bairro (em néon), sempre virado para quem olha.
	var district_sign := Label3D.new()
	district_sign.text = GameCategories.get_category_name(category_id).to_upper()
	district_sign.font = HubFonts.SIGN
	district_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	district_sign.font_size = 128
	district_sign.pixel_size = 0.018
	district_sign.outline_size = 8
	district_sign.outline_modulate = Color(0.0, 0.0, 0.0, 0.5)
	district_sign.set_meta("neon", Color.from_hsv(category_color.h, 0.8, 1.0))
	district_sign.position = center + Vector3(0.0, DISTRICT_SIGN_HEIGHT, 0.0)
	add_child(district_sign)
	_district_signs.append(district_sign)

	# Prédios nos terrenos; o que sobrar vira pracinha.
	var lots := CityLayout.lots_facing_center_first(cell)
	for i in lots.size():
		var lot := CityLayout.lot_transform(cell, lots[i])
		if i < block_games.size():
			_build_game_building(lot, block_games[i], category_id)
		else:
			CityDecor.add_park(self, lot)


func _build_game_building(lot: Transform3D, game: SteamGame, category_id: String) -> void:
	# Sorteio com "semente" = app_id: o mesmo jogo tem sempre o mesmo prédio.
	var rng := RandomNumberGenerator.new()
	rng.seed = game.app_id
	var category_color := GameCategories.get_category_color(category_id)

	var building := CityBuilding.new()
	building.name = "Building_%d" % game.app_id
	building.game = game
	building.category_id = category_id
	building.size = Vector3(BUILDING_FOOTPRINT,
			rng.randf_range(BUILDING_MIN_HEIGHT, BUILDING_MAX_HEIGHT), BUILDING_FOOTPRINT)
	building.accent_color = category_color
	building.transform = lot
	add_child(building)


# --- Céu, chão e muros -------------------------------------------------------

## Céu (três fotos HDRI misturadas), sol e o relógio de dia e noite.
func _build_environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter("day_sky", SKY_DAY)
	sky_material.set_shader_parameter("sunset_sky", SKY_SUNSET)
	sky_material.set_shader_parameter("night_sky", SKY_NIGHT)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX  # cores mais "de cinema"
	env.glow_enabled = true      # faz o néon e as luzes brilharem
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true      # sombrinhas nos cantos: dá "peso" aos objetos
	env.ssr_enabled = true       # reflexos na tela: vidro e asfalto molhado
	env.fog_enabled = true       # neblina leve (o DayNight ajusta a densidade)
	env.fog_sky_affect = 0.15

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	_day_night = DayNight.new()
	_day_night.environment = env
	_day_night.sky_material = sky_material
	_day_night.sun = sun
	add_child(_day_night)


func _build_ground_and_walls(half: float) -> void:
	# Chão com colisão (cor de asfalto: o que não é quarteirão vira rua).
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(half * 2.0, 1.0, half * 2.0)
	ground.position = Vector3(0.0, -0.5, 0.0)
	# Asfalto realista (ambientCG, CC0), repetido a cada 6 m.
	_asphalt = CityDecor.pbr_material("Road012A", 6.0, Color(0.75, 0.75, 0.75))
	ground.material = _asphalt
	ground.use_collision = true
	add_child(ground)

	# Muros nas bordas para ninguém cair do mapa.
	var y := BORDER_WALL_HEIGHT / 2.0
	var color := Color("3c3d40")
	var length := half * 2.0
	_add_wall(Vector3(0.0, y, -half), Vector3(length, BORDER_WALL_HEIGHT, 1.0), color)
	_add_wall(Vector3(0.0, y, half), Vector3(length, BORDER_WALL_HEIGHT, 1.0), color)
	_add_wall(Vector3(-half, y, 0.0), Vector3(1.0, BORDER_WALL_HEIGHT, length), color)
	_add_wall(Vector3(half, y, 0.0), Vector3(1.0, BORDER_WALL_HEIGHT, length), color)


# --- Amigos na praça ---------------------------------------------------------

## Amigos online que NÃO estão num portal da cidade (sem jogar, ou jogando
## algo que não está na sua biblioteca) ficam em volta do chafariz.
func _update_plaza_friends() -> void:
	for npc in _plaza_friends:
		npc.queue_free()
	_plaza_friends.clear()

	var plaza_friends: Array[SteamFriend] = []
	for friend in FriendsService.get_online_friends():
		var at_a_portal := friend.game_id > 0 and SteamLibrary.get_game(friend.game_id) != null
		if not at_a_portal:
			plaza_friends.append(friend)

	for i in plaza_friends.size():
		var npc := FriendNpc.new()
		npc.friend = plaza_friends[i]
		npc.position = _plaza_friend_position(i, plaza_friends.size())
		# Virado para o chafariz, como quem conversa em roda (o personagem olha para +Z).
		npc.rotation.y = atan2(-npc.position.x, -npc.position.z)
		add_child(npc)
		_plaza_friends.append(npc)


## Posição do amigo número "index" em volta do chafariz. O primeiro fica ao
## norte (de frente para quem nasce na praça) e os seguintes se alternam para
## os dois lados; o lado sul, perto de onde o jogador nasce, é o último a encher.
## Se não couber, abre um círculo maior.
func _plaza_friend_position(index: int, total: int) -> Vector3:
	var ring := floori(index / float(PLAZA_FRIENDS_PER_RING))
	var in_ring := index % PLAZA_FRIENDS_PER_RING
	var count_in_ring := mini(PLAZA_FRIENDS_PER_RING, total - ring * PLAZA_FRIENDS_PER_RING)
	var step := TAU / float(maxi(count_in_ring, 6))
	# 0, +1, -1, +2, -2... passos a partir do norte.
	var steps_from_north := ceili(in_ring / 2.0) * (1 if in_ring % 2 == 1 else -1)
	var angle := steps_from_north * step
	var radius := PLAZA_FRIEND_RADIUS + ring * PLAZA_FRIEND_RING_STEP
	return Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius)


# --- Jogador e avisos --------------------------------------------------------

func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = PLAYER_SPAWN
	add_child(player)
	return player


func _show_startup_messages(player: Player, games: Array[SteamGame]) -> void:
	var hud := player.get_hud()
	if not AppConfig.load_problem.is_empty():
		hud.show_report(AppConfig.load_problem, Toast.Kind.ERROR)
	if SteamLibrary.get_steam_path().is_empty():
		hud.show_message("Não encontrei a Steam neste PC", "Instale a Steam e abra o hub de novo.",
				Toast.Kind.ERROR)
		return
	if games.is_empty():
		hud.show_message("Nenhum jogo instalado na Steam",
				"Instale um jogo pela Steam e abra o hub de novo.", Toast.Kind.INFO, 10.0)
		return

	var without_info := 0
	for game in games:
		if not StoreInfo.has_info(game.app_id):
			without_info += 1
	if without_info > 0:
		hud.show_message("A loja da Steam não respondeu",
				"%d jogo(s) ficaram no bairro \"Outros\". Na próxima vez, tento de novo." % without_info,
				Toast.Kind.INFO, 10.0)


# --- Utilidades --------------------------------------------------------------

## Caixa sólida (com colisão).
func _add_wall(center: Vector3, wall_size: Vector3, wall_color: Color) -> void:
	var wall := CSGBox3D.new()
	wall.name = "Wall"
	wall.size = wall_size
	wall.position = center
	wall.material = CityDecor.make_material(wall_color)
	wall.use_collision = true
	add_child(wall, true)  # true = a Godot numera nomes repetidos (Wall2, Wall3...)
