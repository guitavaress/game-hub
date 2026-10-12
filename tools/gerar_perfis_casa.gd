extends SceneTree
## Gera profiles/homes/loft.tres e profiles/home_catalog.tres (Fase 13.1) pela
## própria Godot, a partir das constantes de worlds/home/home.gd de ANTES da
## 13.2, para não errar um dígito de cor à mão (como na Fase 7.1).
##
##   godot --headless --path . -s res://tools/gerar_perfis_casa.gd
##
## Rodado uma vez. Depois da 13.2 as constantes saem do home.gd e este script
## deixa de funcionar; os .tres passam a ser a fonte, editados no inspetor.

const LOFT_PATH: String = "res://profiles/homes/loft.tres"
const CATALOG_PATH: String = "res://profiles/home_catalog.tres"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var home: GDScript = load("res://worlds/home/home.gd")
	var consts: Dictionary = home.get_script_constant_map()

	var loft := HomeProfile.new()
	loft.id = "loft"
	loft.display_name = "Loft"
	loft.floor = _surface("wood", consts["FLOOR_WOOD"], "", 1.0, 0.42, true)
	loft.ceiling = _surface("pbr", consts["CEILING_TINT"], "Concrete048", 4.0)
	loft.feature_wall = _surface("pbr", Color(0.85, 0.78, 0.74), "Bricks097", 1.6)
	loft.walls = _surface("pbr", consts["PLASTER_TINT"], "Concrete048", 3.0, 0.5, false, true)
	loft.skirting = _surface("matte", Color(0.12, 0.1, 0.09), "", 1.0, 0.6)
	loft.beams = _surface("metal", consts["STEEL_COLOR"], "", 1.0, 0.55)
	loft.lamp_color = consts["LAMP_COLOR"]
	loft.lamp_energy = 1.5
	loft.background_color = Color(0.015, 0.015, 0.02)
	loft.ambient_night_color = Color(0.45, 0.4, 0.36)
	loft.ambient_night_energy = 0.3
	loft.ambient_day_color = Color(0.55, 0.6, 0.68)
	loft.ambient_day_energy = 0.7
	loft.daylight_color = consts["DAYLIGHT_COLOR"]
	loft.daylight_energy = consts["DAYLIGHT_ENERGY"]
	loft.window_shader = "res://worlds/home/home_window.gdshader"
	loft.window_frame = _surface("metal", consts["STEEL_COLOR"], "", 1.0, 0.5)
	loft.window_sill = _surface("pbr", Color(0.7, 0.7, 0.7), "Concrete034", 1.5)
	loft.door = _surface("wood", consts["DOOR_WOOD"], "", 1.0, 0.45)
	loft.door_frame = _surface("matte", Color(0.1, 0.08, 0.07), "", 1.0, 0.5)
	loft.door_handle = _surface("metal", Color(0.75, 0.62, 0.35), "", 1.0, 0.3)
	loft.neon_color = consts["NEON_COLOR"]
	loft.neon_energy = 4.0
	loft.neon_light_energy = 0.45
	loft.decor_script = "res://worlds/home/themes/loft_decor.gd"
	loft.footstep = "wood"
	_save(loft, LOFT_PATH)

	var catalog := HomeCatalog.new()
	# Recarrega do disco: a lista guarda a referência ao arquivo, não uma cópia.
	catalog.homes = [load(LOFT_PATH) as HomeProfile]
	catalog.wall_palette = PackedColorArray([
		Color("#dbcdb8"), Color("#e8e2d6"), Color("#a9b8c6"), Color("#3a6ea5"),
		Color("#6f8f72"), Color("#b5756b"), Color("#8a7ca8"), Color("#4a4a52"),
	])
	catalog.neon_palette = PackedColorArray([
		Color("#f240cc"), Color("#40e0ff"), Color("#5dff7a"), Color("#ffb84a"),
		Color("#ff5a5a"), Color("#9a6bff"), Color("#fff2c2"), Color("#4a8dff"),
	])
	_save(catalog, CATALOG_PATH)
	print("Perfis gravados.")
	quit()


func _surface(kind: String, color: Color, folder: String = "", meters: float = 1.0,
		roughness: float = 0.5, planks: bool = false, paintable: bool = false) -> HomeSurface:
	var surface := HomeSurface.new()
	surface.kind = kind
	surface.color = color
	surface.folder = folder
	surface.meters = meters
	surface.roughness = roughness
	surface.planks = planks
	surface.paintable = paintable
	return surface


func _save(resource: Resource, path: String) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Não consegui gravar %s (erro %d)." % [path, error])
