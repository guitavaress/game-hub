extends SceneTree
## Gera profiles/homes/cabana.tres (Fase 13.12) pela própria Godot, do zero,
## e põe a cabana no fim da lista "homes" do profiles/home_catalog.tres (o loft
## continua o primeiro, o padrão). Pode rodar de novo: a cabana antiga do
## catálogo é trocada pela nova.
##
##   godot --headless --path . -s res://tools/gerar_cabana.gd
##
## Depois, o .tres é a fonte: dá para ajustar no inspetor.

const CABIN_PATH: String = "res://profiles/homes/cabana.tres"
const CATALOG_PATH: String = "res://profiles/home_catalog.tres"
const CABIN_ID: String = "cabana"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var cabin := HomeProfile.new()
	cabin.id = CABIN_ID
	cabin.display_name = "Cabana"
	# Piso de tábuas escuras; teto de tábuas mais claras; paredes de tora (as
	# três comuns aceitam a cor escolhida: viram toras pintadas); vigas de madeira.
	cabin.floor = _surface("wood", Color(0.25, 0.15, 0.09), 0.55, true)
	cabin.ceiling = _surface("wood", Color(0.36, 0.24, 0.15), 0.7, true)
	cabin.feature_wall = _surface("wood", Color(0.44, 0.29, 0.17), 0.75, true, false, true)
	cabin.walls = _surface("wood", Color(0.44, 0.29, 0.17), 0.75, true, true, true)
	cabin.skirting = _surface("wood", Color(0.2, 0.12, 0.07), 0.7)
	cabin.beams = _surface("wood", Color(0.28, 0.17, 0.1), 0.75)
	# Luz quente de lampião; de noite, ambiente cor de brasa; de dia, a luz da mata.
	cabin.lamp_color = Color(1.0, 0.68, 0.38)
	cabin.lamp_energy = 1.6
	cabin.background_color = Color(0.01, 0.012, 0.01)
	cabin.ambient_night_color = Color(0.5, 0.36, 0.26)
	cabin.ambient_night_energy = 0.34
	cabin.ambient_day_color = Color(0.6, 0.64, 0.56)
	cabin.ambient_day_energy = 0.65
	cabin.daylight_color = Color(0.96, 0.93, 0.82)
	cabin.daylight_energy = 2.0
	cabin.window_shader = "res://worlds/home/home_window_forest.gdshader"
	cabin.window_frame = _surface("wood", Color(0.25, 0.16, 0.09), 0.7)
	cabin.window_sill = _surface("wood", Color(0.3, 0.2, 0.12), 0.6)
	cabin.door = _surface("wood", Color(0.3, 0.18, 0.1), 0.6)
	cabin.door_frame = _surface("wood", Color(0.2, 0.12, 0.07), 0.7)
	var iron := _surface("metal", Color(0.12, 0.11, 0.1), 0.55)
	cabin.door_handle = iron
	# Néon âmbar e fraco (o usuário ainda pode trocar a cor).
	cabin.neon_color = Color(1.0, 0.6, 0.22)
	cabin.neon_energy = 1.8
	cabin.neon_light_energy = 0.22
	cabin.decor_script = "res://worlds/home/themes/cabin_decor.gd"
	cabin.footstep = "wood"
	_save(cabin, CABIN_PATH)

	var catalog: HomeCatalog = load(CATALOG_PATH)
	var saved: HomeProfile = ResourceLoader.load(CABIN_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	for old in catalog.homes.duplicate():
		if old.id == CABIN_ID:
			catalog.homes.erase(old)
	catalog.homes.append(saved)
	_save(catalog, CATALOG_PATH)
	print("Cabana gravada; o catálogo tem %d temas." % catalog.homes.size())
	quit()


func _surface(kind: String, color: Color, roughness: float = 0.5, planks: bool = false,
		paintable: bool = false, logs: bool = false) -> HomeSurface:
	var surface := HomeSurface.new()
	surface.kind = kind
	surface.color = color
	surface.roughness = roughness
	surface.planks = planks
	surface.paintable = paintable
	surface.logs = logs
	return surface


func _save(resource: Resource, path: String) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Não consegui gravar %s (erro %d)." % [path, error])
