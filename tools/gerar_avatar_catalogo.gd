extends SceneTree
## Gera profiles/avatar_catalog.tres (Fase 13.11) pela própria Godot, para não
## errar um dígito de cor à mão (como nas fases 7.1 e 13.1).
##   godot --headless --path . -s res://tools/gerar_avatar_catalogo.gd
## Depois é editado no inspetor.

const PATH: String = "res://profiles/avatar_catalog.tres"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var catalog := AvatarCatalog.new()
	catalog.palettes["skin"] = _colors(["#f1c9a5", "#e0ac84", "#c68e64", "#a56f4a", "#7d5236", "#5a3a26"])
	catalog.palettes["eyes"] = _colors(["#2b1d14", "#1f3a5f", "#2f6b3f", "#6b4a2b", "#6f7a86", "#7a2b2b"])
	catalog.palettes["hair"] = _colors(["#14100d", "#3b2a20", "#6b4a2b", "#b8863b", "#d9c07a", "#b5422b", "#8a8f99", "#7a4fd0"])
	catalog.palettes["shirt"] = _colors(["#4a7bd0", "#d04a4a", "#4aa860", "#e3b341", "#8a5fd0", "#e8e2d6", "#2b2b30", "#e0749a"])
	catalog.palettes["pants"] = _colors(["#2f3b52", "#14100d", "#4a4f5a", "#6b4a2b", "#4a6b4f", "#7a2b3b", "#c9b79a", "#3b5f8a"])
	_preset(catalog, "Clássico", {"skin": "#c68e64", "eyes": "#2b1d14", "hair": "#3b2a20", "shirt": "#4a7bd0", "pants": "#2f3b52"})
	_preset(catalog, "Verde", {"skin": "#e0ac84", "eyes": "#2f6b3f", "hair": "#b8863b", "shirt": "#4aa860", "pants": "#4a4f5a"})
	_preset(catalog, "Noturno", {"skin": "#7d5236", "eyes": "#6f7a86", "hair": "#14100d", "shirt": "#2b2b30", "pants": "#14100d"})
	_preset(catalog, "Solar", {"skin": "#f1c9a5", "eyes": "#1f3a5f", "hair": "#b5422b", "shirt": "#e3b341", "pants": "#3b5f8a"})
	_preset(catalog, "Neon", {"skin": "#a56f4a", "eyes": "#7a2b2b", "hair": "#7a4fd0", "shirt": "#e0749a", "pants": "#2f3b52"})
	var error := ResourceSaver.save(catalog, PATH)
	print("Catálogo do avatar gravado (erro %d)." % error)
	quit()


func _colors(list: Array) -> PackedColorArray:
	var result := PackedColorArray()
	for html: String in list:
		result.append(Color(html))
	return result


func _preset(catalog: AvatarCatalog, preset_name: String, colors: Dictionary) -> void:
	catalog.preset_names.append(preset_name)
	catalog.presets.append(AvatarSpec.from_dict({"body": "human", "colors": colors}))
