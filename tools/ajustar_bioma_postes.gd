extends SceneTree
## Põe a força dos postes (street_light_scale) no bioma da montanha (15.13.5),
## sem editar o .tres à mão. Rodar à mão uma vez:
##   godot --headless --path . -s res://tools/ajustar_bioma_postes.gd
## A neve reflete umas três vezes mais luz que o asfalto: 0,4 deixa a neve
## sob os postes sem estourar à noite.

const FORCA: float = 0.4

func _initialize() -> void:
	var path := "res://profiles/biomes/montanha.tres"
	var biome := load(path) as BiomeSpec
	if biome == null:
		push_error("Não achei o bioma em %s." % path)
		quit(1)
		return
	biome.street_light_scale = FORCA
	var error := ResourceSaver.save(biome, path)
	print("Força dos postes do bioma: ", FORCA, " (resultado ", error, ")")
	quit(error)
