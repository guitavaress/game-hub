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
##
## 19.7: --casca=<arch|building> escolhe a casca das portas dos biomas que não
## têm uma fixa (a floresta e o deserto; a montanha é sempre de arcos). Sem ele, vale
## CASCA_PADRAO. Para trocar a casca da floresta:
##   godot --headless --path . -s res://tools/gerar_bioma.gd -- --refazer=floresta --casca=building
## Depois de gravar, cada bioma de BAIRROS é ligado ao perfil do bairro dele
## (profiles/districts/<bairro>.tres), se ainda não estiver: só o campo "biome"
## muda.

const PASTA: String = "res://profiles/biomes"
const PASTA_BAIRROS: String = "res://profiles/districts"
## A casca das portas nos biomas sem casca fixa: "arch" (arcos) ou "building" (prédios).
const CASCA_PADRAO: String = "arch"
## Qual bairro usa cada bioma.
const BAIRROS: Dictionary[String, String] = {
	"montanha": "rpg",
	"floresta": "aventura",
	"deserto": "sobrevivencia",
}

## A casca pedida na linha de comando (vazio = CASCA_PADRAO).
var _casca: String = ""


func _initialize() -> void:
	var refazer: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--refazer="):
			refazer = arg.trim_prefix("--refazer=").split(",", false)
		elif arg.begins_with("--casca="):
			_casca = arg.trim_prefix("--casca=")
	var error: int = DirAccess.make_dir_recursive_absolute(PASTA)
	if not _casca.is_empty() and _casca not in ["arch", "building"]:
		push_error("A casca deve ser arch ou building (veio \"%s\")." % _casca)
		error = ERR_INVALID_PARAMETER
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
	for id: String in biomes:
		if error != OK:
			break
		error = _ligar(id)
	if error != OK:
		push_error("Não consegui gravar os biomas (erro %d)." % error)
	quit(0 if error == OK else 1)


## Os biomas que este script sabe fazer: id -> função que monta o BiomeSpec.
func _biomes() -> Dictionary[String, Callable]:
	return {
		"montanha": _montanha,
		"floresta": _floresta,
		"deserto": _deserto,
	}


## Liga o bioma ao perfil do bairro dele (BAIRROS), se ainda não estiver ligado.
func _ligar(id: String) -> int:
	if not BAIRROS.has(id):
		return OK
	var biome_path: String = "%s/%s.tres" % [PASTA, id]
	var district_path: String = "%s/%s.tres" % [PASTA_BAIRROS, BAIRROS[id]]
	var district := load(district_path) as DistrictProfile
	var biome := load(biome_path) as BiomeSpec
	if district == null or biome == null:
		push_error("Não consegui ligar %s a %s." % [biome_path, district_path])
		return ERR_CANT_OPEN
	if district.biome != null and district.biome.resource_path == biome_path:
		return OK
	district.biome = biome
	var error: int = ResourceSaver.save(district, district_path)
	print("Ligado: %s usa %s (resultado %d)" % [district_path, biome_path, error])
	return error


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
	# Na montanha, a chuva da cidade cai como neve, e a forte como nevasca
	# (19.6; a neve é da 15.11, ligada na 15.6).
	biome.weather = WeatherSpec.new()
	biome.weather.kind = "neve"
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


## A floresta da Aventura (19.7): chão de grama, calçada de pedra com musgo,
## árvores altas de mata (forest_tree.glb) com árvores novas por baixo (a de
## rua, menor), rochas com musgo por cima, pássaros de fundo, folhas caindo na
## chuva e uma névoa verde leve. A casca das portas vem de --casca.
func _floresta() -> BiomeSpec:
	var biome := BiomeSpec.new()
	biome.id = "floresta"
	biome.display_name = "Floresta"
	biome.ground_folder = "Grass001"
	biome.ground_meters = 2.5
	biome.ground_tint = Color(0.6, 0.66, 0.5)
	biome.ground_normal_strength = 1.2
	biome.path_folder = "PavingStones070"
	biome.path_tint = Color(0.62, 0.62, 0.55)
	biome.footstep = "grass"
	biome.cover_streets = true
	biome.shell = _casca if not _casca.is_empty() else CASCA_PADRAO
	# O musgo por cima da pedra (nos arcos e nas rochas).
	biome.snow_cover = 0.4
	biome.fog_density_scale = 1.25
	biome.fog_tint = Color(0.55, 0.68, 0.5)
	biome.fog_tint_amount = 0.22
	biome.fog_height_density = 0.006
	# Na floresta, a chuva da cidade traz folhas caindo (19.6).
	biome.weather = WeatherSpec.new()
	biome.weather.kind = "folhas"
	biome.ambience_bed = AmbienceSpec.new()
	biome.ambience_bed.kind = "avulsos"
	biome.ambience_bed.files = PackedStringArray([
		"res://assets/generated/bird_chirp_1.wav",
		"res://assets/generated/bird_chirp_2.wav",
		"res://assets/generated/bird_chirp_3.wav",
		"res://assets/generated/bird_chirp_4.wav",
	])
	biome.ambience_bed.volume_db = -16.0
	biome.ambience_bed.interval = Vector2(1.5, 5.0)
	biome.ambience_bed.pitch_range = Vector2(0.85, 1.25)
	# As árvores altas: o tronco a 1,5 m da calçada (a copa passa por cima de
	# quem anda, acima de 3,5 m) e a copa longe dos prédios, das portas e do
	# metrô (BiomeScatter.CROWN_GAP).
	var tree := ScatterSpec.new()
	tree.source = "res://assets/models/trees/forest_tree.glb"
	tree.kind = "tree"
	tree.height_range = Vector2(10, 16)
	tree.density = 2.6
	tree.walkable_clearance = 1.5
	tree.collision_radius = 0.3
	biome.scatter.append(tree)
	# As árvores novas, por baixo das altas: a árvore de rua, menor.
	var young := ScatterSpec.new()
	young.source = "res://assets/models/trees/street_tree.glb"
	young.kind = "tree"
	young.height_range = Vector2(3.5, 5.5)
	young.density = 1.2
	young.walkable_clearance = 1.2
	young.collision_radius = 0.12
	biome.scatter.append(young)
	var rock := ScatterSpec.new()
	rock.source = "res://assets/polyhaven/models/moon_rock_02/moon_rock_02_1k.gltf"
	rock.material_folder = "Rock058"
	rock.tint = Color(0.72, 0.7, 0.64)
	rock.height_range = Vector2(0.5, 1.4)
	rock.density = 0.5
	rock.collision_radius = 0.3
	biome.scatter.append(rock)
	return biome


## O deserto da Sobrevivência (19.8): chão de areia (Ground093C), calçada de
## pedra com areia por cima, nenhuma árvore, rochas maiores de pedra com areia
## nas faces de cima, vento de fundo, poeira no lugar da chuva e uma névoa
## quente e leve. Os passos são os da neve (não há som de areia CC0 no
## projeto). A casca das portas vem de --casca, como na floresta.
func _deserto() -> BiomeSpec:
	var biome := BiomeSpec.new()
	biome.id = "deserto"
	biome.display_name = "Deserto"
	biome.ground_folder = "Ground093C"
	biome.ground_meters = 3.0
	biome.ground_tint = Color(0.95, 0.85, 0.68)
	biome.ground_normal_strength = 1.3
	biome.path_folder = "PavingStones070"
	biome.path_tint = Color(0.78, 0.68, 0.52)
	biome.footstep = "snow"
	biome.cover_streets = true
	biome.shell = _casca if not _casca.is_empty() else CASCA_PADRAO
	# A areia por cima da pedra (nos arcos e nas rochas), nas faces de cima.
	biome.snow_cover = 0.5
	# A névoa é quente e leve: o ar seco do deserto.
	biome.fog_density_scale = 0.9
	biome.fog_tint = Color(0.9, 0.74, 0.52)
	biome.fog_tint_amount = 0.25
	biome.fog_height_density = 0.004
	# No deserto, a chuva da cidade vira poeira levada pelo vento (19.6).
	biome.weather = WeatherSpec.new()
	biome.weather.kind = "poeira"
	biome.ambience_bed = AmbienceSpec.new()
	biome.ambience_bed.kind = "loop"
	biome.ambience_bed.files = PackedStringArray(["res://assets/generated/wind_loop.wav"])
	biome.ambience_bed.volume_db = -20.0
	# Sem árvores. Só rochas, maiores que as da floresta, com a pedra do
	# Rock058 e a areia por cima (ScatterSpec.material_folder, da 19.7).
	var rock := ScatterSpec.new()
	rock.source = "res://assets/polyhaven/models/moon_rock_02/moon_rock_02_1k.gltf"
	rock.material_folder = "Rock058"
	rock.tint = Color(0.9, 0.78, 0.62)
	rock.height_range = Vector2(0.9, 2.4)
	rock.density = 0.55
	rock.collision_radius = 0.5
	biome.scatter.append(rock)
	return biome
