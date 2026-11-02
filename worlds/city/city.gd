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
## ABERTURA (Fase 9): o jogador nasce DENTRO DE CASA (a Home), com a tela
## "GAME HUB" por um instante, e já pode andar pela casa enquanto a cidade é
## montada lá fora, aos poucos (um pedaço por quadro, sem travar a casa).
## A porta da rua fica trancada, mostrando "Montando a cidade… N%", até a
## cidade ficar pronta. Sem janela (testes), play_intro = false: a tela fica
## preta, a cidade monta de uma vez e o jogador nasce na praça.

## A cidade terminou de montar (e a abertura acabou).
signal city_ready

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

## Borda da cidade: mureta de concreto, grade por cima e, invisível, uma
## barreira mais alta (o pulo chega a ~1,2 m; a grade é só enfeite).
const BORDER_WALL_HEIGHT: float = 1.0
const BORDER_RAILING_HEIGHT: float = 1.1
const BORDER_RAILING_SPACING: float = 0.25
const BORDER_BARRIER_HEIGHT: float = 3.0
## Onde o jogador nasce sem a abertura (testes): na praça, virado para o norte (-Z).
## Com a abertura, ele nasce dentro de casa.
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0.1, 8.0)
## Abertura: a tela "GAME HUB" fica INTRO_SPLASH_SECONDS por cima da casa e
## some em INTRO_FADE_SECONDS.
const INTRO_SPLASH_SECONDS: float = 0.8
const INTRO_FADE_SECONDS: float = 0.4
## Montagem em segundo plano: quanto da montagem cabe num quadro (ms). Passou
## disso, o resto fica para o próximo quadro (a casa continua lisinha).
const BUILD_BUDGET_MS: float = 6.0
## Quanto tempo esperamos a loja responder na primeira vez (segundos).
const STORE_WAIT_SECONDS: float = 8.0
## Base dos prédios (a altura vem do número de andares: BuildingVariant).
const BUILDING_FOOTPRINT: float = 10.0
## Letreiro do bairro: um por bairro, em cima do meio do primeiro quarteirão,
## acima de todos os telhados (o prédio mais alto possível, BuildingVariant,
## mais esta folga até o meio da placa). Na altura do olhar ficam os pórticos.
const DISTRICT_SIGN_CLEARANCE: float = 5.0
const DISTRICT_SIGN_TEXT_HEIGHT: float = 4.0
## Distância (m) da quina do quarteirão até o pórtico, andando pela rua do
## próprio quarteirão (fica antes do cruzamento, longe do pórtico vizinho).
const GATE_SETBACK: float = 3.5
## Estação da praça: a noroeste do chafariz, de frente para o sul (a escada
## desce para o norte). Fica fora do eixo de quem nasce e anda reto para o
## norte: ninguém cai no painel do metrô sem querer.
const METRO_CENTRAL_SPOT: Vector3 = Vector3(-6.0, 0.0, -6.0)
## Nenhuma porta fica a mais disto (m, pelas ruas) da estação do seu bairro:
## 20 s correndo (9 m/s).
const METRO_MAX_WALK: float = 180.0
const METRO_MAX_PER_DISTRICT: int = 4
## A CASA (Fase 9): fica longe da cidade (fora de qualquer tamanho de
## cidade), ao sul. Ninguém a vê de fora: entra-se pela porta "Casa" da praça.
const HOME_ORIGIN: Vector3 = Vector3(0.0, 0.0, 1500.0)
## Porta "Casa" na praça: na beira sul, a leste do eixo, de frente para o
## norte (o chafariz). Fica fora dos caminhos de quem anda pela praça (os
## eixos que levam às quatro ruas e o lado sul do chafariz), longe da estação
## Central (a noroeste) e da roda de amigos. Quem sai de casa aparece um
## pouco à frente dela, olhando para o norte.
const HOME_DOOR_SPOT: Vector3 = Vector3(6.0, 0.0, 12.2)
const HOME_DOOR_ARRIVAL: Vector3 = Vector3(6.0, 0.1, 10.0)
## Amigos na praça: em círculos em volta do chafariz.
const PLAZA_FRIEND_RADIUS: float = 4.5
const PLAZA_FRIEND_RING_STEP: float = 2.0
const PLAZA_FRIENDS_PER_RING: int = 10
## Distância mínima entre o meio de um amigo da praça e um trecho reservado
## (a calçada da estação Central, onde quem sai de casa aparece).
const PLAZA_FRIEND_CLEARANCE: float = 2.0

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
## Som do aviso "A cidade está pronta" (Kenney Music Jingles, CC0).
const CITY_READY_SOUND: AudioStream = preload("res://assets/kenney/music-jingles/jingles_PIZZI00.ogg")

## As cascas que a cidade sabe montar, pelo nome que vai no perfil ("shell").
## (Variável, e não constante: a Godot não aceita classes num dicionário constante.)
var _shells: Dictionary[String, GDScript] = {
	"building": CityBuilding,
	"arch": ArchShell,
}
var _ambience_bed: AudioStreamPlayer
## Bonequinhos dos amigos que estão na praça.
var _plaza_friends: Array[FriendNpc] = []
## Trechos da praça onde nenhum amigo pode ficar, cada um [de, até]: a calçada
## da estação Central (da boca até a saída) e o lugar onde quem sai de casa
## aparece (um ponto: de = até).
var _plaza_reserved: Array[Array] = [[HOME_DOOR_ARRIVAL, HOME_DOOR_ARRIVAL]]
## Relógio de dia e noite (sol, céu, luzes).
var _day_night: DayNight
## Ambiente da cidade (céu, neblina, efeitos), para trocar a qualidade.
var _environment: Environment
## O céu de fotos: o WorldEnvironment, o sol (que de noite vira a "lua") e o
## céu de fotos, guardado para voltar a ele se a opção Céu mudar.
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _photo_sky: Sky
## O céu do addon Sky3D (opção Céu = "sky3d"): ele é o WorldEnvironment e tem
## sol e lua próprios.
var _sky3d: Sky3D
## A casa do jogador e a porta "Casa" da praça.
var _home: Home
var _home_door: TravelDoor
## Abrir dentro de casa, com a cidade montando lá fora? (Nos testes sem
## janela, não: tela preta, cidade de uma vez e jogador na praça.)
var play_intro: bool = DisplayServer.get_name() != "headless"
## Quando o quadro atual começou a montar (para o orçamento BUILD_BUDGET_MS).
var _frame_started_us: int = 0
var _is_ready: bool = false
## Lugares (x, z) que já têm pórtico.
var _gate_spots: Dictionary[Vector2, bool] = {}
## Asfalto: fica "molhado" (reflete mais) à noite.
var _asphalt: StandardMaterial3D
## A planta da cidade (quem ocupa cada quarteirão), para os mapas.
var _map: CityMap
## Quarteirões de cada bairro, na ordem em que foram montados.
var _district_cells: Dictionary[String, Array] = {}
## O setor (fatia) de cada bairro, do SectorLayout.
var _sectors: Dictionary[String, DistrictSector] = {}
## A montanha (15.14): o bairro dela e como foi montada, para refazer na troca
## da qualidade.
var _backdrop_district: String = ""
var _backdrop_half: float = 0.0
var _backdrop_cell: float = 0.0
var _backdrop_rebuilding: bool = false

## Placas dos bairros: o néon fica mais forte à noite.
var _district_signs: Array[DistrictSign] = []


func _ready() -> void:
	_build_environment()
	_build_home()
	_home.set_night(_day_night.get_night())  # a janela da casa já nasce na hora certa
	# O jogador nasce antes da cidade: dentro de casa (na abertura).
	var player := _spawn_player()
	_frame_started_us = Time.get_ticks_usec()
	if play_intro:
		_open_at_home(player)  # sem await: a casa abre enquanto a cidade monta
	else:
		ScreenFade.set_amount(1.0)  # tela preta enquanto a cidade é montada

	_report_progress("Lendo a biblioteca…", 0.05)
	var games := SteamLibrary.get_installed_games()
	ScreenFade.splash.complete_stage("biblioteca")
	_report_progress("Buscando capas e categorias…", 0.12)
	await _update_store_info(games)
	ScreenFade.splash.complete_stage("capas")

	var districts := _group_into_districts(games)
	var cells := await _build_districts(districts, games.size())
	var half := CityLayout.half_extent(cells)
	_map.set_bounds(half)
	await _build_metro(districts)
	# A porta "Casa" vira um marco nos mapas (depois das estações: fica por cima).
	_map.add_landmark("home", "Casa", Vector2(HOME_DOOR_SPOT.x, HOME_DOOR_SPOT.z), HomeDoorFacade.NEON_COLOR)
	await _keep_frame_light()
	# A montanha vem antes da mureta: a trilha abre um vão nela.
	var openings := await _build_backdrop(districts, half)
	# Os marcos sem telhado (a torre do RPG) vêm depois da montanha (eles ficam
	# no mirante) e antes dos pinheiros (que não nascem na base deles).
	_build_anchored_landmarks(districts)
	_build_ground_and_walls(half, openings)
	# O clima vem com todos os bairros e a montanha prontos: ele cobre as zonas
	# do bairro (quarteirões, vagas e a montanha).
	for district in districts:
		_build_weather(district["id"])
	await _keep_frame_light()
	# O chão dos biomas cobre as ruas dos bairros deles: faixas e poças pulam essas zonas.
	var covered := _build_biome_covers(districts, half, player)
	CityDecor.add_street_markings(self, cells, half, covered)
	CityDecor.add_puddles(self, half, covered)
	await _keep_frame_light()
	CityDecor.add_plaza(self)
	_build_clock_tower()
	_build_ambience_bed()
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
		# A cidade lá fora está pronta: a porta da rua destranca.
		_report_progress("Pronto!", 1.0)
		player.world_loading = false
		_home.get_front_door().locked_reason = ""
		player.get_hud().show_message("A cidade está pronta", "A porta da rua já abre.",
				Toast.Kind.INFO, -1.0, "", CITY_READY_SOUND, &"Música")
	else:
		ScreenFade.set_message("")
		ScreenFade.fade_in(0.8)

	# Os avisos só agora, com a cidade pronta (e o HUD já de volta).
	_show_startup_messages(player, games)
	_day_night.clock_advanced.connect(func(hour: float) -> void:
		player.get_hud().show_message("Relógio da cidade: %02d:%02d" \
				% [floori(hour), floori(fmod(hour, 1.0) * 60.0)], "F8 adianta 3 horas.", Toast.Kind.INFO, 4.0))
	_is_ready = true
	city_ready.emit()
	# Uma troca de qualidade feita durante a montagem foi ignorada: confere agora.
	_rebuild_backdrop()


func is_city_ready() -> bool:
	return _is_ready


# --- Abertura ----------------------------------------------------------------

## ABERTURA EM CASA: o jogador aparece no ponto de nascer da casa, com a tela
## "GAME HUB" por um instante (sem andar e sem HUD). Depois a tela some e ele
## anda pela casa. Enquanto a cidade monta, a porta da rua fica trancada e a
## busca e o mapa não abrem (player.world_loading).
func _open_at_home(player: Player) -> void:
	player.teleport_to(_home.get_spawn_transform())
	player.set_indoors(_home.get_environment())  # já no primeiro quadro
	player.world_loading = true
	player.start_intro()
	_home.get_front_door().locked_reason = "Montando a cidade…"
	ScreenFade.show_splash(_clock_text())
	await get_tree().create_timer(INTRO_SPLASH_SECONDS).timeout
	ScreenFade.hide_splash(INTRO_FADE_SECONDS)
	player.finish_intro()


## Progresso da montagem: na tela "GAME HUB" (enquanto ela aparece) e na
## porta da rua ("Montando a cidade… 40%").
func _report_progress(text: String, progress: float) -> void:
	if not play_intro:
		return
	ScreenFade.splash.set_status(text)
	ScreenFade.splash.set_progress(progress)
	if _is_ready:
		return
	_home.get_front_door().locked_reason = "Montando a cidade… %d%%" % roundi(progress * 100.0)


## Montagem em segundo plano: espera (quadro a quadro) a arte do prédio ficar
## pronta nas threads do GameArt. Sem a abertura, não espera: o get_hero
## termina o carregamento na hora.
func _wait_for_art(app_id: int) -> void:
	if not play_intro:
		return
	while not GameArt.is_world_art_ready(app_id):
		await get_tree().process_frame
		_frame_started_us = Time.get_ticks_usec()


## Montagem em segundo plano: se este quadro já gastou BUILD_BUDGET_MS
## montando, espera o próximo quadro (a casa continua andando lisinha).
func _keep_frame_light() -> void:
	if not play_intro:
		return
	if Time.get_ticks_usec() - _frame_started_us >= int(BUILD_BUDGET_MS * 1000.0):
		await get_tree().process_frame
		_frame_started_us = Time.get_ticks_usec()


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
		for light in _sky_lights():
			GraphicsQuality.apply_to_sun(light, AppConfig.get_quality())
		_rebuild_backdrop()
	elif section == "video" and key == "sky" and _environment != null:
		_apply_sky(AppConfig.get_sky())


## Refaz a montanha com a grade e a sombra da qualidade nova (15.14). A nova é
## montada à parte, escondida, enquanto a velha continua no lugar (e segurando
## quem está na trilha); só no fim a velha sai e a nova aparece, no mesmo
## quadro. A torre, o vão da mureta, as zonas e o marco do mapa não dependem
## da grade e não são refeitos.
func _rebuild_backdrop() -> void:
	if _backdrop_district.is_empty() or _backdrop_rebuilding or not _is_ready:
		return
	_backdrop_rebuilding = true
	while true:
		var level := AppConfig.get_quality()
		var old := get_node_or_null("BackdropTerrain_%s" % _backdrop_district) as BackdropTerrain
		var biome := BiomeBuilder.biome_of(_backdrop_district)
		if old == null or biome == null:
			break
		if is_equal_approx(GraphicsQuality.terrain_cell_meters(level), _backdrop_cell) \
				and old.casts_shadow == GraphicsQuality.terrain_casts_shadow(level):
			break
		var fresh := BiomeBuilder.add_backdrop(self, _backdrop_district, biome,
				_sectors[_backdrop_district], _backdrop_half, level)
		if fresh == null:
			break
		fresh.visible = false
		while fresh.build_next():
			await get_tree().process_frame
		# A montagem é a mesma de antes, então o nome e o lugar não mudam.
		remove_child(old)
		old.queue_free()
		fresh.name = "BackdropTerrain_%s" % _backdrop_district
		fresh.visible = true
		fresh.get_dressing().set_night(_day_night.get_night())
		_backdrop_cell = fresh.cell_meters
	_backdrop_rebuilding = false


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

## Monta todos os bairros. Cada um ganha uma fatia da cidade, da praça até a
## borda (SectorLayout): os quarteirões com prédios e, perto da borda, as vagas.
## Devolve as células de todos os territórios (para medir o mapa).
## Na abertura, monta um quarteirão por quadro, para a barra de progresso andar.
func _build_districts(districts: Array[Dictionary], total_games: int) -> Array[Vector2i]:
	var counts: Array[int] = []
	var ids: Array[String] = []
	for district in districts:
		counts.append(ceili(district["games"].size() / float(CityLayout.LOTS_PER_BLOCK)))
		ids.append(district["id"])
	# O bairro com terreno de fundo (a montanha) fica com a fatia no norte.
	var sectors: Array[DistrictSector] = SectorLayout.plan(counts, BiomeBuilder.focus_index(ids))
	var cells: Array[Vector2i] = []
	# Hero e logo de todos os jogos, em threads, na ordem em que os prédios
	# vão ser montados: quando chegar a vez de cada prédio, a arte já está pronta.
	var app_ids: Array[int] = []
	for district in districts:
		for game: SteamGame in district["games"]:
			app_ids.append(game.app_id)
	GameArt.preload_world_art(app_ids)

	_map = CityMap.new()
	_map.name = "CityMap"
	add_child(_map)

	var built := 0
	for district_index in districts.size():
		var district: Dictionary = districts[district_index]
		var sector: DistrictSector = sectors[district_index]
		_sectors[district["id"]] = sector
		cells.append_array(sector.territory)
		# O território todo (quarteirões e vagas) vira zona do bairro no mapa.
		for cell in sector.territory:
			_map.add_zone(district["id"], cell)
		var district_games: Array = district["games"]
		var block_index: int = 0
		# Cada quarteirão recebe até 4 jogos do bairro.
		for first in range(0, district_games.size(), CityLayout.LOTS_PER_BLOCK):
			var cell: Vector2i = sector.blocks[block_index]
			var block_games := district_games.slice(first, first + CityLayout.LOTS_PER_BLOCK)
			await _build_block(cell, district["id"], block_games)
			_map.add_block(district["id"], cell, block_games.size())
			if not _district_cells.has(district["id"]):
				_district_cells[district["id"]] = [] as Array[Vector2i]
			_district_cells[district["id"]].append(cell)
			if first == 0:
				# O pórtico fica no primeiro quarteirão do bairro (o mais perto da praça).
				_build_gate(cell, district["id"])
			block_index += 1
			built += block_games.size()
			_report_progress("Construindo bairros… %d de %d jogos" % [built, total_games],
					lerpf(0.2, 0.9, float(built) / maxf(total_games, 1.0)))
		# As vagas (o resto da fatia, perto da borda) ganham só o chão.
		for cell in sector.territory:
			if not sector.blocks.has(cell):
				_build_vacant(cell, district["id"])
		await _keep_frame_light()
		# O letreiro vem com o bairro inteiro pronto: ele fica acima dos enfeites
		# altos de todos os quarteirões (a grua de um vizinho alcança a ponta dele).
		_build_district_sign(sector.blocks, district["id"])
	return cells


## Uma vaga: um quarteirão do bairro sem jogo, perto da borda. Fica só o chão
## (calçada e miolo na cor do bairro, ou o do bioma), sem postes nem enfeites.
## O nó se chama Vacant_<bairro>_<x>_<z>.
func _build_vacant(cell: Vector2i, category_id: String) -> void:
	var vacant := Node3D.new()
	vacant.name = "Vacant_%s_%d_%d" % [category_id, cell.x, cell.y]
	add_child(vacant)
	_add_block_ground(vacant, cell, category_id)


## O chão de um quarteirão: o do bioma do bairro, se houver; senão, o da cidade.
func _add_block_ground(parent: Node3D, cell: Vector2i, category_id: String) -> void:
	var biome := BiomeBuilder.biome_of(category_id)
	if biome != null:
		BiomeBuilder.add_block_ground(parent, CityLayout.block_center(cell), biome)
	else:
		CityDecor.add_block_ground(parent, CityLayout.block_center(cell), GameCategories.get_category_color(category_id))


## O setor coberto de cada bairro com bioma (neve nas ruas, com colisão e
## passos), os pinheiros e as rochas, e a névoa e o vento do primeiro deles.
## Roda depois do metrô: as estações e as portas ficam livres dos enfeites.
## Devolve as áreas cobertas de todos.
func _build_biome_covers(districts: Array[Dictionary], half: float, player: Player) -> Array[Rect2]:
	var covered: Array[Rect2] = []
	var has_atmosphere := false
	var inside := Rect2(-half, -half, half * 2.0, half * 2.0)
	for district in districts:
		var biome := BiomeBuilder.biome_of(district["id"])
		if biome == null:
			continue
		# O chão e os enfeites só dentro da mureta; a montanha tem os dela.
		var town: Array[Rect2] = []
		var mountain: Array[Rect2] = []
		for zone in _map.zone_rects(district["id"]):
			(town if inside.encloses(zone) else mountain).append(zone)
		var rects := BiomeBuilder.covered_rects(town, half, biome.cover_streets)
		BiomeBuilder.add_cover(self, district["id"], biome, rects)
		# Os enfeites só mudam ao abrir a cidade (não se refazem na troca da qualidade).
		BiomeBuilder.add_scatter(self, district["id"], biome, town,
				GraphicsQuality.scatter_amount(AppConfig.get_quality()))
		if not has_atmosphere:
			# A névoa e o vento valem também na trilha e no mirante.
			BiomeBuilder.add_atmosphere(self, district["id"], biome, rects + mountain, player, _day_night)
			has_atmosphere = true
		if biome.cover_streets:
			covered.append_array(rects)
	return covered


## A montanha atrás do primeiro bairro com terreno de fundo (o da fatia no
## norte), um pedaço da malha por vez. A montanha vira zona do bairro (o
## clima, a névoa e o vento valem nela) e a entrada da trilha, um marco no
## mapa. Devolve os vãos que a trilha abre na mureta (nenhum se não houver
## montanha ou ela não couber).
func _build_backdrop(districts: Array[Dictionary], half: float) -> Array[Rect2]:
	for district in districts:
		var biome := BiomeBuilder.biome_of(district["id"])
		if biome == null or biome.backdrop == null:
			continue
		var terrain := BiomeBuilder.add_backdrop(self, district["id"], biome, _sectors[district["id"]], half,
				AppConfig.get_quality())
		if terrain == null:
			return []
		_backdrop_district = district["id"]
		_backdrop_half = half
		_backdrop_cell = terrain.cell_meters
		while terrain.build_next():
			await _keep_frame_light()
		for zone in terrain.get_zone_rects():
			_map.add_zone_rect(district["id"], zone)
		_map.add_landmark("trilha", TrailDressing.SIGN_TEXT, terrain.trail.start,
				GameCategories.get_neon_color(district["id"]))
		return terrain.get_openings()
	return []


## Clima do bairro (garoa etc.), se o perfil tiver. Um só por bairro; vale em
## todas as zonas dele (quarteirões e vagas, cada uma com meia rua em volta).
func _build_weather(category_id: String) -> void:
	var profile := Profiles.district(category_id)
	var zones := _map.zone_rects(category_id)
	if profile == null or profile.effective_weather() == null or zones.is_empty():
		return
	var weather := DistrictWeather.new()
	weather.name = "DistrictWeather_%s" % category_id
	weather.spec = profile.effective_weather()
	weather.areas = zones.duplicate()
	add_child(weather)


# --- Metrô ----------------------------------------------------------------------

## Estações de metrô: a "Central" na praça e uma por bairro, no quarteirão
## do pórtico (o primeiro do bairro, o mais perto da praça).
## Se alguma porta do bairro ficar a mais de METRO_MAX_WALK metros (pelas
## ruas) da estação mais perto, o bairro ganha outra estação, no quarteirão
## dessa porta, até todas ficarem perto.
func _build_metro(districts: Array[Dictionary]) -> void:
	var central := _add_metro_stop("Central", Color("F2F4F7"), 0, "Praça", METRO_CENTRAL_SPOT, Vector3(0.0, 0.0, 1.0))
	# Quem chega pelo metrô sai da boca e aparece na saída: nenhum amigo da
	# praça fica nesse caminho.
	_plaza_reserved.append([central.global_position, central.get_exit_transform().origin])
	var portals_by_district: Dictionary[String, Array] = {}
	for node in get_tree().get_nodes_in_group("game_portal"):
		var portal := node as GamePortal
		if portal != null and portal.app_id > 0 and is_ancestor_of(portal):
			var id := GameCategories.get_category_id(portal.app_id)
			if not portals_by_district.has(id):
				portals_by_district[id] = []
			portals_by_district[id].append(portal)

	for i in districts.size():
		var id: String = districts[i]["id"]
		var cells: Array = _district_cells.get(id, [])
		if cells.is_empty():
			continue
		var stop_name := GameCategories.get_category_name(id)
		var neon := GameCategories.get_neon_color(id)
		var stops: Array[TransitStop] = []
		var first: Array = _block_station_spot(cells[0])
		stops.append(_add_metro_stop(stop_name, neon, (i + 1) * 10, "", first[0], first[1]))
		var portals: Array = portals_by_district.get(id, [])
		while stops.size() < METRO_MAX_PER_DISTRICT:
			var farthest: GamePortal = null
			var farthest_length := METRO_MAX_WALK
			for portal: GamePortal in portals:
				var length := _nearest_stop_walk(stops, portal)
				if length > farthest_length:
					farthest_length = length
					farthest = portal
			if farthest == null:
				break
			var spot: Array = _block_station_spot(_cell_of(farthest.global_position))
			stops.append(_add_metro_stop(stop_name, neon,
					(i + 1) * 10 + stops.size(), "", spot[0], spot[1]))
		_describe_metro_stops(stops, portals)
		await _keep_frame_light()  # com 200 jogos, as contas do metrô pesam: um bairro por vez


## Escreve o "detail" de cada estação do bairro: onde ela fica e quantas portas
## ela atende (as que têm esta estação como a mais perto, andando pelas ruas).
## Cada porta é medida uma vez só, depois que todas as estações existem.
## Como o nome é o mesmo em todas, é o detail que diferencia uma da outra.
## A distância da praça é em linha reta (plano XZ) até a Central, de 10 em 10 m.
func _describe_metro_stops(stops: Array[TransitStop], portals: Array) -> void:
	var served: Array[int] = []
	served.resize(stops.size())
	served.fill(0)
	for portal: GamePortal in portals:
		var best := INF
		var best_index := 0
		for k in stops.size():
			var length := _nearest_stop_walk([stops[k]] as Array[TransitStop], portal)
			if length < best:
				best = length
				best_index = k
		served[best_index] += 1
	for k in stops.size():
		var near := "%d %s perto" % [served[k], "jogo" if served[k] == 1 else "jogos"]
		if k == 0:
			stops[k].detail = "perto da praça · " + near
		else:
			var from_plaza := Vector2(stops[k].position.x - METRO_CENTRAL_SPOT.x,
					stops[k].position.z - METRO_CENTRAL_SPOT.z).length()
			stops[k].detail = "a ~%d m da praça · %s" % [roundi(from_plaza / 10.0) * 10, near]


## Quanto se anda pelas ruas da estação mais perto (das dadas) até a porta.
static func _nearest_stop_walk(stops: Array[TransitStop], portal: GamePortal) -> float:
	var best := INF
	for stop in stops:
		var points := CityRouteGuide.route_points(stop.get_exit_transform().origin, portal)
		var length := 0.0
		for k in points.size() - 1:
			length += points[k].distance_to(points[k + 1])
		best = minf(best, length)
	return best


## Lugar da estação num quarteirão: no vão de 4 m entre os dois prédios da
## rua das portas (a do lado da praça), com a frente na linha das fachadas,
## virada para a rua. A escada desce para dentro do vão: não ocupa a calçada
## e fica longe das portas, dos postes e do pórtico. Devolve [posição, frente].
func _block_station_spot(cell: Vector2i) -> Array:
	var center := CityLayout.block_center(cell)
	var street_z := _door_street_z(cell)
	var side := signf(center.z - street_z)
	var facade := CityLayout.STREET_WIDTH / 2.0 + (CityLayout.LOT_SIZE - BUILDING_FOOTPRINT) / 2.0
	return [Vector3(center.x, 0.0, street_z + side * facade), Vector3(0.0, 0.0, -side)]


## Quarteirão onde fica um ponto do mundo.
static func _cell_of(position: Vector3) -> Vector2i:
	return Vector2i(roundi(position.x / CityLayout.BLOCK_PITCH), roundi(position.z / CityLayout.BLOCK_PITCH))


func _add_metro_stop(stop_name: String, color: Color, order: int, detail: String,
		position: Vector3, front: Vector3) -> TransitStop:
	var stop := MetroEntrance.new()
	stop.name = "Metro_%d" % order
	stop.stop_name = stop_name
	stop.color = color
	stop.order = order
	stop.detail = detail
	stop.position = position
	stop.basis = Basis.looking_at(-front)  # a frente (+Z) da estação aponta para "front"
	add_child(stop)
	_map.add_landmark("metro", stop_name, Vector2(position.x, position.z), color)
	return stop


## Pórtico do bairro: por cima da rua das portas do quarteirão (a do lado da
## praça), na ponta mais perto do centro. Quem vem da praça passa por baixo.
func _build_gate(cell: Vector2i, category_id: String) -> void:
	var sx := _toward_center(cell.x)
	var center_x := CityLayout.block_center(cell).x
	# Um pouco antes da quina, sobre a rua do quarteirão: os pilares não
	# batem no poste da esquina e cada bairro tem o seu trecho de rua.
	var reach := CityLayout.BLOCK_SIZE / 2.0 - GATE_SETBACK
	# Lugares possíveis, do melhor para o pior: rua das portas do lado da praça
	# (ponta perto do centro, depois a outra ponta) e a rua das portas do
	# outro lado. Quarteirões vizinhos podem disputar a mesma esquina.
	var candidates: Array[Vector2] = [
		Vector2(center_x + sx * reach, _door_street_z(cell)),
		Vector2(center_x - sx * reach, _door_street_z(cell)),
		Vector2(center_x + sx * reach, _door_street_z(cell, true)),
	]
	var spot := Vector2.INF
	for candidate in candidates:
		if not _gate_spots.has(candidate):
			spot = candidate
			break
	if spot == Vector2.INF:
		push_warning("O pórtico do bairro %s não coube em nenhuma esquina." % category_id)
		return
	_gate_spots[spot] = true
	_map.set_gate(category_id, spot)
	var gate := DistrictGate.new()
	gate.name = "DistrictGate_%s" % category_id
	gate.setup(GameCategories.get_category_name(category_id).to_upper(),
			GameCategories.get_neon_color(category_id), CityLayout.STREET_WIDTH / 2.0 + 0.3)
	gate.position = Vector3(spot.x, 0.0, spot.y)
	gate.rotation.y = PI / 2.0  # a rua corre de leste a oeste: passa-se por baixo no eixo X
	add_child(gate)


## Letreiro do bairro (néon sobre placa escura, sempre virado para quem olha),
## um só por bairro, em cima do meio do primeiro quarteirão: acima do prédio
## mais alto possível, e também dos enfeites que sobem acima dos telhados nos
## quarteirões do bairro (a grua da Simulação diz até onde vai pelo
## get_top_y). Assim ele aparece de longe, por cima da cidade.
func _build_district_sign(district_cells: Array, category_id: String) -> void:
	if district_cells.is_empty():
		return
	var cell: Vector2i = district_cells[0]
	var district_sign := DistrictSign.new()
	district_sign.name = "DistrictSign_%s" % category_id
	district_sign.setup(GameCategories.get_category_name(category_id).to_upper(),
			GameCategories.get_neon_color(category_id), DISTRICT_SIGN_TEXT_HEIGHT)
	district_sign.position = CityLayout.block_center(cell) + Vector3(0.0, _district_sign_height(district_cells, category_id), 0.0)
	add_child(district_sign)
	_district_signs.append(district_sign)


## A altura do letreiro do bairro: acima do prédio mais alto possível, dos
## enfeites altos dos quarteirões e do marco, se ele ficar nos quarteirões (a
## torre no mirante da montanha fica longe do letreiro e não conta).
func _district_sign_height(district_cells: Array, category_id: String) -> float:
	var top := BuildingVariant.max_total_height()
	for cell: Vector2i in district_cells:
		var props := get_node_or_null("DistrictProps_%s_%d_%d" % [category_id, cell.x, cell.y])
		if props != null and props.has_method("get_top_y"):
			top = maxf(top, props.get_top_y())
	var landmark := get_node_or_null("DistrictLandmark_%s" % category_id) as DistrictLandmark
	if landmark != null:
		var spot := Vector2(landmark.global_position.x, landmark.global_position.z)
		var half_block := CityLayout.BLOCK_SIZE / 2.0
		for cell: Vector2i in district_cells:
			var center := CityLayout.block_center(cell)
			if absf(spot.x - center.x) <= half_block and absf(spot.y - center.z) <= half_block:
				top = maxf(top, landmark.get_top_y())
				break
	return top + DISTRICT_SIGN_CLEARANCE


## O marco alto do bairro (torre, roda-gigante...), se o perfil tiver um
## "landmark_script": em cima do prédio mais alto do quarteirão do pórtico.
## Com "anchor" (15.10), no chão, nesse ponto. Sem âncora, o bairro sem prédio
## (arcos) ou com montanha fica para _build_anchored_landmarks. null = sem marco.
func _build_landmark(category_id: String, buildings: Array[CityBuilding],
		anchor: Vector3 = Vector3.INF) -> DistrictLandmark:
	var profile := Profiles.district(category_id)
	if profile == null or profile.landmark_script.is_empty():
		return null
	if not anchor.is_finite() and (buildings.is_empty() or _has_backdrop(category_id)):
		return null
	var script := load(profile.landmark_script) as GDScript
	var landmark := script.new() as DistrictLandmark if script != null else null
	if landmark == null:
		push_warning("O marco %s do bairro %s não carregou." % [profile.landmark_script, category_id])
		return null
	landmark.name = "DistrictLandmark_%s" % category_id
	landmark.category_id = category_id
	landmark.buildings = buildings
	landmark.anchor = anchor
	add_child(landmark)
	return landmark


## O bairro tem montanha de fundo no bioma (a torre dele vai para o mirante)?
static func _has_backdrop(category_id: String) -> bool:
	var biome := BiomeBuilder.biome_of(category_id)
	return biome != null and biome.backdrop != null


## Os marcos que não ficam num telhado (15.10): no mirante da montanha do
## bairro (BackdropTerrain.tower_spot) ou, sem montanha (ela não coube),
## no meio do primeiro quarteirão, o do pórtico. Quando o marco fica nos
## quarteirões, o letreiro do bairro sobe para ficar acima dele.
func _build_anchored_landmarks(districts: Array[Dictionary]) -> void:
	for district in districts:
		var id: String = district["id"]
		if not _district_cells.has(id) or get_node_or_null("DistrictLandmark_%s" % id) != null:
			continue
		var terrain := get_node_or_null("BackdropTerrain_%s" % id) as BackdropTerrain
		var cells: Array[Vector2i] = _district_cells[id]
		var anchor := terrain.tower_spot() if terrain != null else CityLayout.block_center(cells[0])
		if _build_landmark(id, [] as Array[CityBuilding], anchor) == null:
			continue
		var district_sign := get_node_or_null("DistrictSign_%s" % id) as Node3D
		if district_sign != null:
			district_sign.position.y = _district_sign_height(_sectors[id].blocks, id)


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
## para norte e para sul; empate: a do norte). far = true: a outra.
func _door_street_z(cell: Vector2i, far: bool = false) -> float:
	var north := (cell.y - 0.5) * CityLayout.BLOCK_PITCH
	var south := (cell.y + 0.5) * CityLayout.BLOCK_PITCH
	var near_north := absf(north) <= absf(south)
	return north if near_north != far else south


## Para que lado (-1 ou +1) fica o centro da cidade nesse eixo (0 = oeste).
static func _toward_center(value: int) -> float:
	if value > 0:
		return -1.0
	return 1.0 if value < 0 else -1.0


func _build_block(cell: Vector2i, category_id: String, block_games: Array) -> void:
	var center := CityLayout.block_center(cell)
	var biome := BiomeBuilder.biome_of(category_id)

	# Calçada em volta e o miolo do quarteirão (na cor do bairro, ou o chão do
	# bioma); postes nos cantos.
	_add_block_ground(self, cell, category_id)
	CityDecor.add_block_lights(self, center, biome.street_light_scale if biome != null else 1.0)
	await _keep_frame_light()

	_build_street_sign(cell, category_id)

	# Prédios nos terrenos; o que sobrar vira pracinha (no bioma, fica o chão dele).
	var lots := CityLayout.lots_facing_center_first(cell)
	# Os enfeites só recebem as cascas que são prédios (eles usam a fachada,
	# o cartaz e o néon do prédio).
	var buildings: Array[CityBuilding] = []
	for i in lots.size():
		var lot := CityLayout.lot_transform(cell, lots[i])
		if i < block_games.size():
			await _wait_for_art(block_games[i].app_id)
			var shell := _build_game_building(lot, block_games[i], category_id)
			if shell is CityBuilding:
				buildings.append(shell)
			await _keep_frame_light()  # um prédio (com as capas) pesa: divide os quadros
		elif biome == null:
			CityDecor.add_park(self, lot)
	# O elemento que dá cara ao bairro (telões, letreiros...), se houver.
	DistrictProps.decorate(self, category_id, cell, buildings)
	# O marco do bairro fica no primeiro quarteirão (o do pórtico).
	if not _district_cells.has(category_id):
		_build_landmark(category_id, buildings)
	await _keep_frame_light()


## A porta de um jogo num terreno: a casca que o perfil do bairro pede
## ("building" = prédio, o padrão; "arch" = arco). O nó se chama sempre
## Building_<app_id>, qualquer que seja a casca.
func _build_game_building(lot: Transform3D, game: SteamGame, category_id: String) -> PortalShell:
	# Sorteio com "semente" = app_id: o mesmo jogo tem sempre o mesmo prédio
	# (andares, recuo, janelas etc.: veja BuildingVariant).
	var profile := Profiles.district(category_id)
	var variant := BuildingVariant.from_app_id(game.app_id, profile.floor_weights if profile != null else PackedFloat32Array())
	var kind := profile.effective_shell() if profile != null else "building"
	var shell_script: GDScript = _shells.get(kind, CityBuilding)

	var shell := shell_script.new() as PortalShell
	shell.name = "Building_%d" % game.app_id
	shell.game = game
	shell.category_id = category_id
	shell.size = Vector3(BUILDING_FOOTPRINT, variant.body_height(), BUILDING_FOOTPRINT)
	shell.accent_color = GameCategories.get_category_color(category_id)
	if shell is CityBuilding:
		shell.variant = variant
	var biome := BiomeBuilder.biome_of(category_id)
	if biome != null:
		BiomeBuilder.dress_shell(shell, biome)  # a pedra do bioma (arcos com neve por cima)
	shell.transform = lot
	add_child(shell)
	return shell


# --- Céu, chão e muros -------------------------------------------------------

## Céu, sol e o relógio de dia e noite. O céu é o de fotos (três HDRI
## misturadas) ou o do addon Sky3D, pela opção Céu do menu (veja _apply_sky).
func _build_environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter("day_sky", SKY_DAY)
	sky_material.set_shader_parameter("sunset_sky", SKY_SUNSET)
	sky_material.set_shader_parameter("sunset_gain", SKY_SUNSET_GAIN)
	sky_material.set_shader_parameter("night_sky", SKY_NIGHT)
	_photo_sky = Sky.new()
	_photo_sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX  # cores mais "de cinema"
	env.glow_enabled = true      # faz o néon e as luzes brilharem
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true      # sombrinhas nos cantos: dá "peso" aos objetos
	env.ssr_enabled = true       # reflexos na tela: vidro e asfalto molhado
	env.fog_enabled = true       # neblina leve (o DayNight ajusta a densidade)
	env.fog_sky_affect = 0.15
	# Névoa volumétrica: densidade 0 no ar; só aparece dentro de FogVolumes
	# (ex.: névoa baixa do bairro Terror). O céu e as luzes iluminam ela.
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 110.0
	env.volumetric_fog_ambient_inject = 0.8
	# Qualidade escolhida no menu de pausa (Leve/Média/Alta) liga ou desliga
	# os efeitos caros; troca na hora se o menu mudar.
	_environment = env
	GraphicsQuality.apply_to_environment(env, AppConfig.get_quality())
	AppConfig.settings_changed.connect(_on_settings_changed)

	_day_night = DayNight.new()
	_day_night.environment = env
	_day_night.sunset_glow_u = SKY_SUNSET_GLOW_U
	_apply_sky(AppConfig.get_sky())
	add_child(_day_night)


## Monta o céu escolhido (e desmonta o outro, se a opção mudou com o hub aberto).
## O Environment é o mesmo nos dois: neblina, efeitos e qualidade não mudam.
func _apply_sky(mode: String) -> void:
	for old: Node in [_world_env, _sun, _sky3d]:
		if old != null:
			remove_child(old)  # sai já, para não haver dois céus num quadro
			old.queue_free()
	_world_env = null
	_sun = null
	_sky3d = null
	_day_night.sky_material = null
	_day_night.sun = null
	_day_night.sky3d = null

	if mode == "sky3d":
		_environment.sky = null  # vazio: o Sky3D cria o céu dele
		_sky3d = Sky3D.new()
		_sky3d.name = "Sky3D"
		# set_environment, e não "environment =": o Sky3D só aceita a troca
		# de Environment depois de entrar na cena.
		_sky3d.set_environment(_environment)
		add_child(_sky3d)
		_sky3d.game_time_enabled = false  # quem anda com a hora é o DayNight
		_sky3d.fog_enabled = false        # a neblina continua a do DayNight
		# À noite, menos luz do céu (quase preto) e mais luz ambiente; lua mais forte.
		_sky3d.night_sky_contribution = 0.4
		_sky3d.moon_energy = 0.45
		_set_sky3d_place(_sky3d.tod)
		for light in _sky_lights():
			_setup_sky_light(light)
		_day_night.sky3d = _sky3d
	else:
		_environment.sky = _photo_sky
		_environment.ambient_light_sky_contribution = 1.0  # o Sky3D mexe nela
		_world_env = WorldEnvironment.new()
		_world_env.environment = _environment
		add_child(_world_env)
		_sun = DirectionalLight3D.new()
		_sun.name = "Sun"
		_sun.shadow_enabled = true
		_setup_sky_light(_sun)
		add_child(_sun)
		_day_night.sky_material = _photo_sky.sky_material
		_day_night.sun = _sun
	if _day_night.is_inside_tree():
		_day_night.update_now()


## O sol e a lua do céu atual (no céu de fotos, é uma luz só).
func _sky_lights() -> Array[DirectionalLight3D]:
	if _sky3d != null:
		return [_sky3d.sun, _sky3d.moon]
	if _sun != null:
		return [_sun]
	return []


## Toda luz do céu: sombra conforme a qualidade (mais curta na Leve) e sem
## entrar na casa nem no corpo do espelho (que ficam "dentro de casa").
func _setup_sky_light(light: DirectionalLight3D) -> void:
	GraphicsQuality.apply_to_sun(light, AppConfig.get_quality())
	light.light_cull_mask &= ~Home.INTERIOR_LAYER_MASK
	light.light_cull_mask &= ~AvatarBody.reflection_layers()


## Onde e quando fica a cidade, para o Sky3D pôr o sol, a lua (com a fase
## certa) e as estrelas: Brasil (latitude de São Paulo) e a data do PC. A
## longitude acompanha o fuso (-3 h × 15°), e o sol fica no alto ao meio-dia.
func _set_sky3d_place(tod: TimeOfDay) -> void:
	tod.latitude = deg_to_rad(-23.5)
	tod.longitude = deg_to_rad(-45.0)
	tod.utc = -3.0
	var today := Time.get_date_dict_from_system()
	tod.year = today["year"]
	tod.month = today["month"]
	tod.day = today["day"]


## O fundo da cidade (vento e trânsito ao longe): um loop 2D, sem posição, no
## canal "Ambiente", vindo do perfil do mundo. Em casa o canal fica abafado.
func _build_ambience_bed() -> void:
	var spec := Profiles.world().ambience_bed
	if spec == null or spec.files.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.name = "AmbienceBed"
	player.stream = AmbientEmitter.looping(load(spec.files[0]))
	player.bus = &"Ambiente"
	player.volume_db = spec.volume_db
	# A atmosfera do bioma (BiomeAtmosphere) acha o fundo por este grupo para abaixá-lo.
	player.add_to_group(&"city_ambience_bed")
	add_child(player)
	player.play()
	_ambience_bed = player


func get_ambience_bed() -> AudioStreamPlayer:
	return _ambience_bed


# --- Casa ----------------------------------------------------------------------

## A casa fica longe, em HOME_ORIGIN, e a porta "Casa" fica na praça. As duas
## portas se ligam: a da praça leva para dentro de casa, e a da casa traz de
## volta para a frente da porta da praça. O sol da cidade não ilumina dentro.
func _build_home() -> void:
	_home = Home.new()
	_home.name = "Home"
	_home.position = HOME_ORIGIN
	add_child(_home)
	# O sol da cidade não entra em casa: veja _setup_sky_light.

	_home_door = TravelDoor.new()
	_home_door.name = "HomeDoor"
	_home_door.door_name = "Casa"
	_home_door.detail = "A sua casa: estante, amigos e configurações"
	_home_door.travel_message = "Casa"
	_home_door.position = HOME_DOOR_SPOT
	_home_door.rotation.y = PI  # a frente (+Z) da porta aponta para o chafariz (norte)
	add_child(_home_door)
	_home_door.set_destination(_home.get_spawn_transform())
	# A aparência é da cidade (o TravelDoor só tem a lógica): o quiosque com o
	# néon "CASA", no mesmo lugar e virado para o mesmo lado.
	var facade := HomeDoorFacade.new()
	facade.name = "HomeDoorFacade"
	facade.position = HOME_DOOR_SPOT
	facade.rotation.y = PI
	add_child(facade)

	var front_door := _home.get_front_door()
	front_door.detail = "Sair para a praça"
	front_door.travel_message = "Praça"
	# Chegando na praça: na frente da porta "Casa", olhando para o norte (-Z).
	front_door.set_destination(Transform3D(Basis.IDENTITY, HOME_DOOR_ARRIVAL))


func get_home() -> Home:
	return _home


func get_home_door() -> TravelDoor:
	return _home_door


func _build_ground_and_walls(half: float, openings: Array[Rect2] = []) -> void:
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

	# Mureta com grade nas bordas (baixa: deixa ver o horizonte) e uma barreira
	# invisível para ninguém pular para fora do mapa. Os vãos (a trilha da
	# montanha) ficam sem mureta, sem barreira e sem grade.
	var y := BORDER_WALL_HEIGHT / 2.0
	for side in _border_sides(half):
		for span in _wall_spans(half, side, openings):
			var center := _border_point(side, (span.x + span.y) / 2.0)
			var length := span.y - span.x
			var along_x := is_zero_approx(side.x)
			var wall_size := Vector3(length if along_x else 0.6, BORDER_WALL_HEIGHT, 0.6 if along_x else length)
			_add_wall(center + Vector3(0.0, y, 0.0), wall_size)
			_add_barrier(center, Vector3(wall_size.x, BORDER_BARRIER_HEIGHT, wall_size.z))
	_add_railing(half, openings)

	# O horizonte: anel de silhuetas a 400 m e o chão escuro até lá.
	var skyline := CitySkyline.new()
	skyline.name = "Skyline"
	skyline.environment = _environment
	add_child(skyline)


# --- Torre do relógio ----------------------------------------------------------

## A torre do meio do chafariz: marca a hora da cidade e vira um ponto nos mapas.
func _build_clock_tower() -> void:
	var tower := PlazaClockTower.new()
	tower.name = "ClockTower"
	tower.day_night = _day_night
	add_child(tower)
	_map.add_landmark("marco", "Torre do relógio", Vector2.ZERO, PlazaClockTower.NEON_COLOR)


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
## Um ponto reservado no caminho (veja _plaza_reserved): o amigo anda um pouco
## pela roda até sair de cima dele.
func _plaza_friend_position(index: int, total: int) -> Vector3:
	var ring := floori(index / float(PLAZA_FRIENDS_PER_RING))
	var in_ring := index % PLAZA_FRIENDS_PER_RING
	var count_in_ring := mini(PLAZA_FRIENDS_PER_RING, total - ring * PLAZA_FRIENDS_PER_RING)
	var step := TAU / float(maxi(count_in_ring, 6))
	# 0, +1, -1, +2, -2... passos a partir do norte.
	var steps_from_north := ceili(in_ring / 2.0) * (1 if in_ring % 2 == 1 else -1)
	var angle := steps_from_north * step
	var radius := PLAZA_FRIEND_RADIUS + ring * PLAZA_FRIEND_RING_STEP
	var spot := Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius)
	for attempt in 8:
		if not _is_plaza_reserved(spot):
			break
		angle += PLAZA_FRIEND_CLEARANCE / radius  # ~2 m pela roda
		spot = Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius)
	return spot


func _is_plaza_reserved(spot: Vector3) -> bool:
	var point := Vector2(spot.x, spot.z)
	for reserved in _plaza_reserved:
		var from := Vector2(reserved[0].x, reserved[0].z)
		var to := Vector2(reserved[1].x, reserved[1].z)
		var closest := Geometry2D.get_closest_point_to_segment(point, from, to)
		if point.distance_to(closest) < PLAZA_FRIEND_CLEARANCE:
			return true
	return false


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

## Mureta de concreto (com colisão).
func _add_wall(center: Vector3, wall_size: Vector3) -> void:
	var wall := CSGBox3D.new()
	wall.name = "Wall"
	wall.size = wall_size
	wall.position = center
	wall.material = CityDecor.pbr_material("Concrete034", 2.0, Color(0.5, 0.51, 0.53))
	wall.use_collision = true
	add_child(wall, true)  # true = a Godot numera nomes repetidos (Wall2, Wall3...)


## Parede invisível (só colisão), de "base" até a altura do tamanho.
func _add_barrier(base: Vector3, barrier_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Barrier"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = barrier_size
	shape.shape = box
	body.add_child(shape)
	body.position = base + Vector3(0.0, barrier_size.y / 2.0, 0.0)
	add_child(body, true)


## Grade de metal em cima da mureta: barras finas a cada 25 cm e um corrimão.
## Todas as barras são UMA MultiMesh (milhares de cópias, um só desenho).
## Nos vãos não há barra nem corrimão.
func _add_railing(half: float, openings: Array[Rect2] = []) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("1A1D22")
	metal.metallic = 0.8
	metal.roughness = 0.35
	var bar := BoxMesh.new()
	bar.size = Vector3(0.04, BORDER_RAILING_HEIGHT, 0.04)
	bar.material = metal

	var per_side := int(half * 2.0 / BORDER_RAILING_SPACING)
	var y := BORDER_WALL_HEIGHT + BORDER_RAILING_HEIGHT / 2.0
	var spots: Array[Vector3] = []
	for side in _border_sides(half):
		var spans := _wall_spans(half, side, openings)
		for i in per_side:
			var t := -half + (i + 0.5) * BORDER_RAILING_SPACING
			for span in spans:
				if t >= span.x and t <= span.y:
					spots.append(_border_point(side, t) + Vector3(0.0, y, 0.0))
					break
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = bar
	multimesh.instance_count = spots.size()
	for index in spots.size():
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, spots[index]))
	var bars := MultiMeshInstance3D.new()
	bars.name = "Railing"
	bars.multimesh = multimesh
	add_child(bars)

	# Corrimão em cima das barras: um por trecho de mureta.
	var top_y := BORDER_WALL_HEIGHT + BORDER_RAILING_HEIGHT
	for side in _border_sides(half):
		var along_x := is_zero_approx(side.x)
		for span in _wall_spans(half, side, openings):
			var length := span.y - span.x
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(length, 0.06, 0.08) if along_x else Vector3(0.08, 0.06, length)
			rail.mesh = rail_mesh
			rail.material_override = metal
			rail.position = _border_point(side, (span.x + span.y) / 2.0) + Vector3(0.0, top_y, 0.0)
			add_child(rail)


## O meio de cada lado da borda (norte, sul, oeste, leste), no chão.
static func _border_sides(half: float) -> Array[Vector2]:
	return [Vector2(0.0, -half), Vector2(0.0, half), Vector2(-half, 0.0), Vector2(half, 0.0)]


## Um ponto do lado "side" da borda, "t" metros ao longo dele (de -half a half).
static func _border_point(side: Vector2, t: float) -> Vector3:
	if is_zero_approx(side.x):
		return Vector3(t, 0.0, side.y)
	return Vector3(side.x, 0.0, t)


## Os trechos de mureta de um lado, de -half a half, sem os vãos que o cortam.
## Cada trecho é Vector2(de, até), ao longo do lado.
static func _wall_spans(half: float, side: Vector2, openings: Array[Rect2]) -> Array[Vector2]:
	var along_x := is_zero_approx(side.x)
	var cuts: Array[Vector2] = []
	for rect in openings:
		if along_x and rect.position.y <= side.y and side.y <= rect.end.y:
			cuts.append(Vector2(rect.position.x, rect.end.x))
		elif not along_x and rect.position.x <= side.x and side.x <= rect.end.x:
			cuts.append(Vector2(rect.position.y, rect.end.y))
	cuts.sort()
	var spans: Array[Vector2] = []
	var from := -half
	for cut in cuts:
		if cut.x > from:
			spans.append(Vector2(from, minf(cut.x, half)))
		from = maxf(from, cut.y)
	if from < half:
		spans.append(Vector2(from, half))
	return spans
