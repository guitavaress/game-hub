class_name CategoryAmbience
extends RefCounted
## Tabela "categoria de jogo -> som ambiente".
##
## Na cidade, cada portal ganha o som do bairro dele. Num mundo futuro, a mesma
## tabela pode dar som a um bioma (por isso ela não fica dentro da cidade).
##
## Uso:  for emissor in CategoryAmbience.create("cartas"): portal.add_child(emissor)
##
## Sons: pacotes CC0 da Kenney (assets/kenney) e sons gerados por
## assets/generated/make_sounds.py (vento e passarinhos).

const KENNEY: String = "res://assets/kenney/"
const GENERATED: String = "res://assets/generated/"


## Cria os emissores de som de uma categoria ([] = categoria sem som).
static func create(category_id: String) -> Array[AmbientEmitter]:
	var emitters: Array[AmbientEmitter] = []
	match category_id:
		"esportes":
			# Motor em loop, ouvido de longe (como uma pista de corrida).
			emitters.append(_loop(KENNEY + "sci-fi-sounds/engineCircular_000.ogg", -16.0, 32.0))
		"rpg":
			emitters.append(_one_shots(KENNEY + "rpg-audio/", ["bookFlip1", "bookFlip2", "bookFlip3",
					"handleCoins", "handleCoins2", "metalClick", "metalLatch", "drawKnife1",
					"drawKnife2", "drawKnife3"], Vector2(2.0, 6.0), -10.0))
		"sobrevivencia":
			emitters.append(_loop(GENERATED + "wind_loop.wav", -12.0, 22.0))
			var rumble := _one_shots(KENNEY + "sci-fi-sounds/", ["lowFrequency_explosion_001"],
					Vector2(10.0, 20.0), -18.0)
			rumble.pitch_range = Vector2(0.5, 0.7)  # mais grave = mais sinistro
			emitters.append(rumble)
		"simulacao":
			emitters.append(_one_shots(KENNEY + "impact-sounds/", ["impactWood_light_000",
					"impactWood_light_001", "impactWood_light_002", "impactWood_light_003",
					"impactWood_light_004", "impactPlank_medium_000", "impactPlank_medium_001",
					"impactPlank_medium_002"], Vector2(0.6, 3.0), -12.0))
		"estrategia":
			emitters.append(_one_shots(KENNEY + "interface-sounds/", ["click_001", "click_002",
					"click_003"], Vector2(1.5, 5.0), -14.0))
		"acao":
			emitters.append(_one_shots(KENNEY + "sci-fi-sounds/", ["laserSmall_000", "laserSmall_001",
					"laserSmall_002", "laserSmall_003", "laserSmall_004"], Vector2(1.5, 5.0), -18.0))
		"cartas":
			emitters.append(_one_shots(KENNEY + "casino-audio/", ["card-shuffle", "card-slide-1",
					"card-slide-2", "card-slide-3", "card-slide-4", "card-shove-1", "card-shove-2",
					"chips-stack-1", "chips-stack-2", "chips-stack-3", "dice-throw-1"],
					Vector2(1.5, 5.0), -8.0))
		"aventura":
			var birds := _one_shots(GENERATED, [], Vector2(1.0, 4.0), -14.0)
			for n in range(1, 5):
				birds.one_shots.append(load(GENERATED + "bird_chirp_%d.wav" % n))
			birds.pitch_range = Vector2(0.85, 1.25)
			emitters.append(birds)
		"casual":
			emitters.append(_one_shots(KENNEY + "music-jingles/", ["jingles_PIZZI00", "jingles_PIZZI04"],
					Vector2(8.0, 16.0), -14.0))
	return emitters


static func _loop(path: String, volume_db: float, max_distance: float) -> AmbientEmitter:
	var emitter := AmbientEmitter.new()
	emitter.loop_stream = load(path)
	emitter.volume_db = volume_db
	emitter.max_distance = max_distance
	emitter.unit_size = 6.0
	return emitter


static func _one_shots(folder: String, names: Array, interval: Vector2, volume_db: float) -> AmbientEmitter:
	var emitter := AmbientEmitter.new()
	for sound_name: String in names:
		emitter.one_shots.append(load(folder + sound_name + ".ogg"))
	emitter.interval = interval
	emitter.volume_db = volume_db
	emitter.max_distance = 18.0
	emitter.unit_size = 4.0
	return emitter
