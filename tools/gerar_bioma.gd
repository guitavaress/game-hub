extends SceneTree
## Gera a amostra aprovada como dado; não liga o bioma a nenhum bairro.
## Rodar à mão: godot --headless --path . -s res://tools/gerar_bioma.gd
## Após a geração inicial, o .tres é a fonte editável no Inspector.

func _initialize() -> void:
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
	biome.shell = "arch"
	biome.backdrop = TerrainSpec.new()
	biome.backdrop.snow_folder = "Snow010A"
	biome.backdrop.rock_folder = "Rock058"
	# Valores iniciais: densidades, névoa e cobertura serão afinados visualmente.
	biome.snow_cover = 0.7
	biome.fog_density_scale = 1.4
	biome.fog_tint = Color(0.65, 0.72, 0.82)
	biome.fog_tint_amount = 0.3
	biome.fog_height_density = 0.01
	biome.ambience_bed = AmbienceSpec.new()
	biome.ambience_bed.kind = "loop"
	biome.ambience_bed.files = PackedStringArray(["res://assets/generated/wind_loop.wav"])
	biome.ambience_bed.volume_db = -22.0
	for outside: bool in [false, true]:
		var pine := ScatterSpec.new()
		pine.source = "res://assets/generated/pine_impostor.png"
		pine.kind = "impostor"
		pine.height_range = Vector2(10, 18) if outside else Vector2(8, 14)
		pine.tint = Color(0.45, 0.55, 0.55)
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
		biome.scatter.append(rock)
	var error := DirAccess.make_dir_recursive_absolute("res://profiles/biomes")
	if error == OK:
		error = ResourceSaver.save(biome, "res://profiles/biomes/montanha.tres")
	if error != OK:
		push_error("Não consegui gravar o bioma (erro %d)." % error)
	quit(0 if error == OK else 1)
