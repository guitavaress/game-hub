extends SceneTree
## Gera os biomas como dado (profiles/biomes/<id>.tres), uma função por bioma.
## Não liga o bioma a nenhum bairro (isso é do perfil do bairro).
##
## Rodar à mão:
##   godot --headless --path . -s res://tools/gerar_bioma.gd
##   godot --headless --path . -s res://tools/gerar_bioma.gd -- --refazer=montanha
##
## Sem argumento, só grava os biomas que ainda NÃO existem: um .tres que já
## existe nunca é regravado (ele pode ter sido afinado no Inspector). Para
## regravar um de propósito, passe --refazer=<id> (vários: --refazer=a,b).
## Bioma novo (Fase 19.1): escreva a função dele e ponha em _biomes().

const PASTA: String = "res://profiles/biomes"


func _initialize() -> void:
	var refazer: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--refazer="):
			refazer = arg.trim_prefix("--refazer=").split(",", false)
	var error: int = DirAccess.make_dir_recursive_absolute(PASTA)
	var biomes: Dictionary[String, Callable] = _biomes()
	for id: String in refazer:
		if not biomes.has(id):
			push_error("Não conheço o bioma \"%s\" (tem: %s)." % [id, ", ".join(biomes.keys())])
			error = ERR_INVALID_PARAMETER
	for id: String in biomes:
		if error != OK:
			break
		var path: String = "%s/%s.tres" % [PASTA, id]
		if FileAccess.file_exists(path) and not refazer.has(id):
			print("%s já existe: fica como está (use --refazer=%s para regravar)." % [path, id])
			continue
		var biome: BiomeSpec = biomes[id].call()
		error = ResourceSaver.save(biome, path)
		print("Gravado: %s (resultado %d)" % [path, error])
	if error != OK:
		push_error("Não consegui gravar os biomas (erro %d)." % error)
	quit(0 if error == OK else 1)


## Os biomas que este script sabe fazer: id -> função que monta o BiomeSpec.
func _biomes() -> Dictionary[String, Callable]:
	return {
		"montanha": _montanha,
	}


## A montanha nevada do RPG (15.6; ligada na 15.6, afinada até a 15.13).
## Os valores são os do montanha.tres de hoje: regravar dá o mesmo dado.
## 19.3: os pinheiros passam a ser o modelo do Blender (tipo "tree"; a foto de
## longe é a do mesmo modelo). A cor já vem certa do modelo: tinta branca.
func _montanha() -> BiomeSpec:
	var biome := BiomeSpec.new()
	biome.id = "montanha"
	biome.display_name = "Montanha nevada"
	biome.ground_folder = "Snow010A"
	biome.ground_meters = 3.0
	biome.ground_tint = Color("#BCC5D2")
	biome.ground_normal_strength = 1.6
	biome.path_folder = "PavingStones070"
	biome.path_tint = Color(0.7, 0.73, 0.78)
	biome.footstep = "snow"
	biome.cover_streets = true
	# A neve reflete umas três vezes mais luz que o asfalto (15.13.5).
	biome.street_light_scale = 0.4
	biome.shell = "arch"
	biome.backdrop = TerrainSpec.new()
	biome.backdrop.snow_folder = "Snow010A"
	biome.backdrop.rock_folder = "Rock058"
	biome.snow_cover = 0.7
	biome.fog_density_scale = 1.4
	biome.fog_tint = Color(0.65, 0.72, 0.82)
	biome.fog_tint_amount = 0.3
	biome.fog_height_density = 0.01
	# Neve o dia todo (15.11; ligada na 15.6).
	biome.weather = WeatherSpec.new()
	biome.weather.kind = "neve"
	biome.weather.night_only = false
	biome.ambience_bed = AmbienceSpec.new()
	biome.ambience_bed.kind = "loop"
	biome.ambience_bed.files = PackedStringArray(["res://assets/generated/wind_loop.wav"])
	biome.ambience_bed.volume_db = -22.0
	for outside: bool in [false, true]:
		var pine := ScatterSpec.new()
		pine.source = "res://assets/models/trees/pine.glb"
		pine.kind = "tree"
		pine.height_range = Vector2(10, 18) if outside else Vector2(8, 14)
		pine.tint = Color.WHITE
		pine.walkable_clearance = 6.0
		pine.collision_radius = 0.4
		pine.in_town = not outside
		pine.on_backdrop = outside
		biome.scatter.append(pine)
		var rock := ScatterSpec.new()
		rock.source = "res://assets/polyhaven/models/moon_rock_02/moon_rock_02_1k.gltf"
		rock.height_range = Vector2(1.5, 4.0) if outside else Vector2(0.6, 1.5)
		rock.in_town = not outside
		rock.on_backdrop = outside
		if not outside:
			# No bairro (15.7): 2 a 3 pinheiros atrás dos arcos e ~3 rochas por
			# quarteirão; a rocha tem colisão (o jogador anda no miolo de neve).
			pine.density = 1.5
			rock.density = 0.6
			rock.collision_radius = 0.35
		biome.scatter.append(rock)
	return biome
