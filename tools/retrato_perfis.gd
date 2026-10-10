extends SceneTree
## Grava o "retrato" de tudo o que hoje muda de um bairro para outro, ANTES de
## a Fase 7 mover esses dados para os perfis (profiles/). Os testes das
## subetapas 7.1 a 7.5 comparam o comportamento novo com este retrato, para
## garantir que a cidade continua idêntica.
##
## Foi rodado uma vez, sobre o código da Fase Linux (commit 3b8c3fc), sem janela:
##   godot --headless --path . -s res://tools/retrato_perfis.gd
## Saída: res://tests/fixtures/profiles_atuais.json
##
## Só funciona no código de antes da Fase 7.1 (ele lê a tabela antiga
## GameCategories.CATEGORIES, que deixou de existir). Para regravar, volte ao
## commit 3b8c3fc. Rodar no código novo também não faria sentido: o teste
## passaria a comparar o código novo com ele mesmo.
##
## Os scripts da cidade são carregados com load() DEPOIS que os autoloads
## existem: citar CityBuilding ou DistrictProps direto num script -s faz a
## Godot compilá-los cedo demais, e os enfeites que usam GameCategories falham.

const OUTPUT: String = "res://tests/fixtures/profiles_atuais.json"
## App IDs para o retrato da arquitetura: os jogos usados pelos testes e uma
## amostra larga (os sorteios dependem só do número).
const SAMPLE_APP_IDS: Array[int] = [
	2379780, 489830, 892970, 413150, 391540, 367520, 2334730, 3405690, 431960, 993090, 620,
]


var _city_building: GDScript
var _building_variant: GDScript
var _district_props: GDScript
var _ambience: GDScript


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_city_building = load("res://worlds/city/city_building.gd")
	_building_variant = load("res://worlds/city/building_variant.gd")
	_district_props = load("res://worlds/city/district_props/district_props.gd")
	_ambience = load("res://components/ambient_emitter/category_ambience.gd")
	var categories := root.get_node("GameCategories")
	var portrait := {
		"origem": "Fase Linux, commit 3b8c3fc (antes da Fase 7)",
		"categorias": [],
		"arquitetura": {},
	}

	for category_id: String in categories.get_category_ids():
		var entry: Dictionary = categories._find(category_id)
		portrait["categorias"].append({
			"id": category_id,
			"nome": categories.get_category_name(category_id),
			"cor": _color(categories.get_category_color(category_id)),
			"neon": _color(categories.get_neon_color(category_id)),
			"neon_na_tabela": entry.has("neon"),
			"tags": entry.get("tags", []),
			"som": _sounds(category_id),
			"enfeite": _props(category_id),
		})

	var sample: Array[int] = SAMPLE_APP_IDS.duplicate()
	for app_id in range(10, 4000000, 7919):  # ~505 números espalhados
		sample.append(app_id)
	var buildings := []
	for app_id in sample:
		var variant = _building_variant.from_app_id(app_id)
		# Mesmo sorteio do CityBuilding._make_walls_material (semente = App ID).
		var rng := RandomNumberGenerator.new()
		rng.seed = app_id
		var wall := rng.randi_range(0, _city_building.WALL_STYLES.size() - 1)
		buildings.append({"app_id": app_id, "andares": variant.floors, "parede": wall})
	var walls := []
	for style: Dictionary in _city_building.WALL_STYLES:
		walls.append({"pasta": style["folder"], "metros": style["meters"], "tom": _color(style["tint"])})
	portrait["arquitetura"] = {
		"pesos_andares": Array(_building_variant.FLOOR_WEIGHTS),
		"estilos_parede": walls,
		"predios": buildings,
	}

	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(portrait, "  ", false))
	file.close()
	print(">> retrato gravado em %s: %d categorias, %d prédios" % [OUTPUT, portrait["categorias"].size(), buildings.size()])
	quit()


## Os emissores de som do bairro, como a CategoryAmbience os monta hoje.
func _sounds(category_id: String) -> Array:
	var result := []
	for emitter in _ambience.create(category_id):
		var item := {
			"tipo": "loop" if emitter.loop_stream != null else "avulsos",
			"volume_db": emitter.volume_db,
			"distancia_max": emitter.max_distance,
			"unit_size": emitter.unit_size,
			"intervalo": [emitter.interval.x, emitter.interval.y],
			"tom": [emitter.pitch_range.x, emitter.pitch_range.y],
			"arquivos": [],
		}
		if emitter.loop_stream != null:
			item["arquivos"].append(emitter.loop_stream.resource_path)
		for stream in emitter.one_shots:
			item["arquivos"].append(stream.resource_path)
		result.append(item)
		emitter.free()
	return result


## O enfeite que o DistrictProps escolhe hoje (com um pai FORA da cena: o
## enfeite nasce, mas não roda nada).
func _props(category_id: String) -> Dictionary:
	var parent := Node3D.new()
	# Lista vazia, mas tipada como Array[CityBuilding] (o decorate exige).
	var no_buildings := Array([], TYPE_OBJECT, &"Node3D", _city_building)
	_district_props.decorate(parent, category_id, Vector2i(3, 4), no_buildings)
	var info := {"script": "", "nome_do_no": "", "tem_cell": false}
	if parent.get_child_count() > 0:
		var props := parent.get_child(0)
		info = {
			"script": props.get_script().resource_path,
			"nome_do_no": String(props.name),
			"tem_cell": "cell" in props,
		}
	parent.free()
	return info


func _color(color: Color) -> Dictionary:
	return {
		"html": color.to_html(true),
		"rgba": [snappedf(color.r, 0.0001), snappedf(color.g, 0.0001), snappedf(color.b, 0.0001), snappedf(color.a, 0.0001)],
	}
