extends SceneTree
## Acrescenta ao profiles/home_catalog.tres as três disposições dos móveis
## (Fase 13.4), pela própria Godot (como a Fase 7.1 e tools/gerar_perfis_casa.gd).
##
##   godot --headless --path . -s res://tools/gerar_layouts_casa.gd
##
## Rodado uma vez. Depois, as disposições são editadas no inspetor. Rodar de
## novo troca a lista de disposições pelas três de sempre.

const CATALOG_PATH: String = "res://profiles/home_catalog.tres"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var catalog := load(CATALOG_PATH) as HomeCatalog
	catalog.layouts.clear()
	# O giro de quem nasce é virado para a estante.
	catalog.layouts.append(_layout("padrao", "Padrão", {
		"apps": "norte_esquerda", "estante": "oeste", "mural": "leste", "estatisticas": "sul_esquerda", "espelho": "sul_direita"}, 35.0))
	catalog.layouts.append(_layout("espelhada", "Espelhada", {
		"apps": "norte_esquerda", "estante": "leste", "mural": "oeste", "estatisticas": "sul_direita", "espelho": "sul_esquerda"}, -35.0))
	catalog.layouts.append(_layout("estante_na_entrada", "Estante na entrada", {
		"apps": "norte_esquerda", "estante": "sul_esquerda", "mural": "leste", "estatisticas": "oeste", "espelho": "sul_direita"}, 130.0))
	var error := ResourceSaver.save(catalog, CATALOG_PATH)
	print("Disposições gravadas (erro %d)." % error)
	quit()


func _layout(id: String, display_name: String, placements: Dictionary, turn: float) -> HomeLayout:
	var layout := HomeLayout.new()
	layout.id = id
	layout.display_name = display_name
	for key: String in placements:
		layout.placements[key] = placements[key]
	layout.spawn_turn_degrees = turn
	return layout
