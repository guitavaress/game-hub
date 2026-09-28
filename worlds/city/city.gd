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
##
## ABERTURA: o jogador nasce primeiro, parado e olhando o céu (já na hora
## certa), com a tela "GAME HUB" por cima mostrando o progresso. Quando a
## cidade fica pronta, a tela some e a câmera desce até o horizonte.

## A cidade terminou de montar (e a abertura acabou).
signal city_ready

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

const BORDER_WALL_HEIGHT: float = 3.0
## Onde o jogador nasce: na praça, virado para o norte (-Z).
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0.1, 8.0)
## Abertura: a câmera começa olhando INTRO_PITCH graus para cima; a tela
## "GAME HUB" fica pelo menos INTRO_MIN_SECONDS; depois some em
## INTRO_FADE_SECONDS enquanto a câmera desce em INTRO_DESCENT_SECONDS.
const INTRO_PITCH: float = 70.0
const INTRO_MIN_SECONDS: float = 1.2
const INTRO_FADE_SECONDS: float = 0.4
const INTRO_DESCENT_SECONDS: float = 2.5
## Quanto tempo esperamos a loja responder na primeira vez (segundos).
const STORE_WAIT_SECONDS: float = 8.0
## Altura dos prédios (sorteada por jogo, mas sempre igual para o mesmo jogo).
const BUILDING_MIN_HEIGHT: float = 13.0
const BUILDING_MAX_HEIGHT: float = 19.0
const BUILDING_FOOTPRINT: float = 10.0
## Altura da placa flutuante com o nome do bairro.
const DISTRICT_SIGN_HEIGHT: float = 25.0
## Distância (m) do pórtico até a quina do quarteirão, para dentro do cruzamento.
const GATE_SETBACK: float = 2.0
## Amigos na praça: em círculos em volta do chafariz.
const PLAZA_FRIEND_RADIUS: float = 4.5
const PLAZA_FRIEND_RING_STEP: float = 2.0
const PLAZA_FRIENDS_PER_RING: int = 10

## Céus HDRI (Poly Haven, CC0) misturados pelo relógio (sky_blend.gdshader).
const SKY_SHADER: Shader = preload("res://worlds/city/sky_blend.gdshader")
const SKY_DAY: Texture2D = preload("res://assets/polyhaven/hdri/kloofendal_48d_partly_cloudy_puresky_2k.hdr")
const SKY_SUNSET: Texture2D = preload("res://assets/polyhaven/hdri/qwantani_dusk_2_puresky_2k.hdr")
const SKY_NIGHT: Texture2D = preload("res://assets/polyhaven/hdri/rogland_clear_night_2k.hdr")
## Calibragem da foto do pôr do sol: ela vem ~3,5x mais clara que a do dia
## (ganho), e o brilho do sol fica em u = 0,607 da foto panorâmica.
const SKY_SUNSET_GAIN: float = 0.27
const SKY_SUNSET_GLOW_U: float = 0.607
## Rugosidade do asfalto: seco de dia, "molhado" (reflete o néon) à noite.
const ASPHALT_ROUGHNESS_DAY: float = 0.55
const ASPHALT_ROUGHNESS_NIGHT: float = 0.18

## Bonequinhos dos amigos que estão na praça.
var _plaza_friends: Array[FriendNpc] = []
## Relógio de dia e noite (sol, céu, luzes).
var _day_night: DayNight
## Ambiente da cidade (céu, neblina, efeitos), para trocar a qualidade.
var _environment: Environment
## Tocar a abertura pelo céu? (Nos testes sem janela, pula direto.)
var play_intro: bool = DisplayServer.get_name() != "headless"
var _is_ready: bool = false
## Asfalto: fica "molhado" (reflete mais) à noite.
var _asphalt: StandardMaterial3D
## Placas dos bairros: o néon fica mais forte à noite.
var _district_signs: Array[DistrictSign] = []


func _ready() -> void:
	_build_environment()
	# O jogador nasce antes da cidade, olhando o céu (na abertura).
	var player := _spawn_player()
	var started_ms := Time.get_ticks_msec()
	if play_intro:
		player.start_intro(INTRO_PITCH)
		ScreenFade.show_splash(_clock_text())
	else:
		ScreenFade.set_amount(1.0)  # tela preta enquanto a cidade é montada

	_splash_status("Lendo a biblioteca…", 0.05)
	var games := SteamLibrary.get_installed_games()
	ScreenFade.splash.complete_stage("biblioteca")
	_splash_status("Buscando capas e categorias…", 0.12)
	await _update_store_info(games)
	ScreenFade.splash.complete_stage("capas")

	var districts := _group_into_districts(games)
	var cells := await _build_districts(districts, games.size())
	var half := CityLayout.half_extent(cells)
	_build_ground_and_walls(half)
	CityDecor.add_street_markings(self, cells, half)
	CityDecor.add_plaza(self)
	# Faixa de luz até a porta de um jogo (busca com Tab).
	var route_guide := CityRouteGuide.new()
	route_guide.name = "RouteGuide"
	add_child(route_guide)
	ScreenFade.splash.complete_stage("bairros")
	_watch_friends_stage()

	# Amigos jogando algo da cidade aparecem nos portais (o GamePortal cuida
	# disso); os outros amigos online ficam aqui na praça.
	FriendsService.friends_changed.connect(_update_plaza_friends)
	_update_plaza_friends()

	# Postes e janelas (grupo "city_night") acendem conforme a hora.
	_day_night.night_changed.connect(_on_night_changed)
	_on_night_changed(_day_night.get_night())

	if play_intro:
		_splash_status("Pronto!", 1.0)
		while (Time.get_ticks_msec() - started_ms) / 1000.0 < INTRO_MIN_SECONDS:
			await get_tree().process_frame
		ScreenFade.hide_splash(INTRO_FADE_SECONDS)
		await player.finish_intro(INTRO_DESCENT_SECONDS)
	else:
		ScreenFade.set_message("")
		ScreenFade.fade_in(0.8)

	# Os avisos só agora: durante a abertura o HUD está escondido.
	_show_startup_messages(player, games)
	_day_night.clock_advanced.connect(func(hour: float) -> void:
		player.get_hud().show_message("Relógio da cidade: %02d:%02d" \
				% [floori(hour), floori(fmod(hour, 1.0) * 60.0)], "F8 adianta 3 horas.", Toast.Kind.INFO, 4.0))
	_is_ready = true
	city_ready.emit()


func is_city_ready() -> bool:
	return _is_ready


# --- Abertura ----------------------------------------------------------------

## Frase e barra de progresso da abertura (se ela estiver na tela).
func _splash_status(text: String, progress: float) -> void:
	if play_intro:
		ScreenFade.splash.set_status(text)
		ScreenFade.splash.set_progress(progress)


## A etapa "AMIGOS" fica pronta quando a lista de amigos chega (ou na hora,
## se os amigos estiverem desligados). A abertura não espera por ela.
func _watch_friends_stage() -> void:
	if not FriendsService.is_enabled() or not FriendsService.get_online_friends().is_empty():
		ScreenFade.splash.complete_stage("amigos")
		return
	FriendsService.friends_changed.connect(func() -> void:
		ScreenFade.splash.complete_stage("amigos"), CONNECT_ONE_SHOT)


## "22:14 · noite" (a hora da cidade, para o canto da abertura).
func _clock_text() -> String:
	var hour := _day_night.current_hour()
	var night := DayNight.night_amount(hour)
	var period := "dia"
	if night > 0.9:
		period = "noite"
	elif night > 0.1:
		period = "pôr do sol" if hour >= 12.0 else "amanhecer"
	return "%02d:%02d · %s" % [floori(hour), floori(fmod(hour, 1.0) * 60.0), period]


## Uma opção mudou no menu de pausa: a qualidade do 3D é da cidade.
func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality" and _environment != null:
		GraphicsQuality.apply_to_environment(_environment, AppConfig.get_quality())


func _on_night_changed(night: float) -> void:
	get_tree().call_group("city_night", "set_night", night)
	# Asfalto molhado à noite: menos rugoso = reflete os postes e o néon.
	if _asphalt != null:
		_asphalt.roughness = lerpf(ASPHALT_ROUGHNESS_DAY, ASPHALT_ROUGHNESS_NIGHT, night)
	for district_sign in _district_signs:
		district_sign.set_night(night)


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

	if not play_intro:
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
## Na abertura, monta um quarteirão por quadro, para a barra de progresso andar.
func _build_districts(districts: Array[Dictionary], total_games: int) -> Array[Vector2i]:
	var block_count := 0
	for district in districts:
		block_count += ceili(district["games"].size() / float(CityLayout.LOTS_PER_BLOCK))
	var cells := CityLayout.block_cells(block_count)

	var next_cell := 0
	var built := 0
	for district in districts:
		var district_games: Array = district["games"]
		# Cada quarteirão recebe até 4 jogos do bairro.
		for first in range(0, district_games.size(), CityLayout.LOTS_PER_BLOCK):
			var block_games := district_games.slice(first, first + CityLayout.LOTS_PER_BLOCK)
			_build_block(cells[next_cell], district["id"], block_games)
			if first == 0:
				# O pórtico fica no primeiro quarteirão do bairro (o mais perto da praça).
				_build_gate(cells[next_cell], district["id"])
			next_cell += 1
			built += block_games.size()
			if play_intro:
				_splash_status("Construindo bairros… %d de %d jogos" % [built, total_games],
						lerpf(0.2, 0.9, float(built) / maxf(total_games, 1.0)))
				await get_tree().process_frame
	return cells


## Pórtico do bairro: por cima da rua das portas do quarteirão (a do lado da
## praça), na ponta mais perto do centro. Quem vem da praça passa por baixo.
func _build_gate(cell: Vector2i, category_id: String) -> void:
	var gate := DistrictGate.new()
	gate.name = "DistrictGate_%s" % category_id
	gate.setup(GameCategories.get_category_name(category_id).to_upper(),
			GameCategories.get_neon_color(category_id), CityLayout.STREET_WIDTH / 2.0 + 0.3)
	var street_z := _door_street_z(cell)
	var sx := _toward_center(cell.x)
	# Um pouco para dentro do cruzamento, para os pilares não baterem no poste
	# da esquina (nem taparem a placa de rua).
	var edge_x := CityLayout.block_center(cell).x + sx * (CityLayout.BLOCK_SIZE / 2.0 + GATE_SETBACK)
	gate.position = Vector3(edge_x, 0.0, street_z)
	gate.rotation.y = PI / 2.0  # a rua corre de leste a oeste: passa-se por baixo no eixo X
	add_child(gate)


## Placa de rua no poste da esquina do quarteirão mais perto da praça,
## virada para a rua das portas, com a seta apontando para o quarteirão.
func _build_street_sign(cell: Vector2i, category_id: String) -> void:
	var sx := _toward_center(cell.x)
	var street_z := _door_street_z(cell)
	var center := CityLayout.block_center(cell)
	var sz := signf(street_z - center.z)  # de que lado do quarteirão fica essa rua
	var corner := CityLayout.BLOCK_SIZE / 2.0 - 0.7  # onde ficam os postes
	var street_sign := StreetSign.new()
	# Quem lê está na rua (lado sz) olhando para o poste: a direita dele é sz*X.
	# O quarteirão fica para o lado -sx a partir do poste.
	street_sign.setup(GameCategories.get_category_name(category_id).split(" e ")[0].to_upper(),
			GameCategories.get_neon_color(category_id), -sx * sz > 0.0)
	street_sign.position = center + Vector3(sx * corner, 0.0, sz * (corner + 0.12))
	street_sign.rotation.y = 0.0 if sz > 0.0 else PI
	add_child(street_sign)


## A rua das portas de um quarteirão mais perto do centro (as portas olham
## para norte e para sul; empate: a do norte).
func _door_street_z(cell: Vector2i) -> float:
	var north := (cell.y - 0.5) * CityLayout.BLOCK_PITCH
	var south := (cell.y + 0.5) * CityLayout.BLOCK_PITCH
	return north if absf(north) <= absf(south) else south


## Para que lado (-1 ou +1) fica o centro da cidade nesse eixo (0 = oeste).
static func _toward_center(value: int) -> float:
	if value > 0:
		return -1.0
	return 1.0 if value < 0 else -1.0


func _build_block(cell: Vector2i, category_id: String, block_games: Array) -> void:
	var category_color := GameCategories.get_category_color(category_id)
	var center := CityLayout.block_center(cell)

	# Calçada em volta e o miolo do quarteirão na cor do bairro; postes nos cantos.
	CityDecor.add_block_ground(self, center, category_color)
	CityDecor.add_block_lights(self, center)

	# Letreiro flutuante com o nome do bairro (néon sobre placa escura), sempre
	# virado para quem olha.
	var district_sign := DistrictSign.new()
	district_sign.name = "DistrictSign_%s" % category_id
	district_sign.setup(GameCategories.get_category_name(category_id).to_upper(),
			GameCategories.get_neon_color(category_id))
	district_sign.position = center + Vector3(0.0, DISTRICT_SIGN_HEIGHT, 0.0)
	add_child(district_sign)
	_district_signs.append(district_sign)
	_build_street_sign(cell, category_id)

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
	sky_material.set_shader_parameter("sunset_gain", SKY_SUNSET_GAIN)
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
	# Qualidade escolhida no menu de pausa (Leve/Média/Alta) liga ou desliga
	# os efeitos caros; troca na hora se o menu mudar.
	_environment = env
	GraphicsQuality.apply_to_environment(env, AppConfig.get_quality())
	AppConfig.settings_changed.connect(_on_settings_changed)

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
	_day_night.sunset_glow_u = SKY_SUNSET_GLOW_U
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
