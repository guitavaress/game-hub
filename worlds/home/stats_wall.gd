class_name StatsWall
extends Node3D
## O QUADRO DE ESTATÍSTICAS (Fase 13.7): a sua história de jogador na parede.
## Horas totais, os 5 mais jogados, as horas por bairro (na cor do bairro) e o
## jogado por último, com a capa. Os números vêm do LibraryStats; aqui só se
## desenha, com Label3D e barras (caixas finas), como o mural.
##
## Sem dados, o quadro explica em vez de quebrar:
##   - biblioteca vazia: "Nenhum jogo instalado ainda...";
##   - horas desconhecidas (Steam sem conta logada): total "—" e uma dica; os
##     bairros mostram quantos jogos têm;
##   - horas conhecidas mas tudo zero: "Nenhuma hora jogada ainda".
##
## Atualiza ao montar e quando o hub volta de um jogo (HubWindow.woke_up).
##
## Convenção: a origem fica no chão, no meio do quadro, e a FRENTE (+Z) aponta
## para dentro da sala.

## Tamanho do quadro (largura, altura) e altura do centro.
const PANEL_SIZE: Vector2 = Vector2(4.4, 2.6)
const CENTER_Y: float = 1.75
## Quantos bairros aparecem, e o comprimento máximo das barras (m).
const DISTRICT_ROWS: int = 5
const TOP_BAR_MAX: float = 0.55
const DISTRICT_BAR_MAX: float = 0.8
const ROW_STEP: float = 0.25
const BOARD_COLOR: Color = Color(0.1, 0.08, 0.11)
const FRAME_WOOD: Color = Color(0.3, 0.19, 0.11)
const TITLE_COLOR: Color = Color(1.0, 0.55, 0.85)
const HEADING_COLOR: Color = Color(0.72, 0.66, 0.78)
const TEXT_COLOR: Color = Color(1.0, 0.9, 0.78)
const BAR_COLOR: Color = Color(0.55, 0.85, 0.35)
const MUTED_COLOR: Color = Color(0.62, 0.58, 0.55)
const NO_GAMES_TEXT: String = "Nenhum jogo instalado ainda.\nInstale um jogo na Steam e ele aparece aqui."
const UNKNOWN_HOURS_TEXT: String = "Entre na sua conta da Steam\npara ver as horas."
const NO_HOURS_TEXT: String = "Nenhuma hora jogada ainda."

## Tudo o que muda a cada atualização (textos, barras, capa).
var _content: Node3D
## A capa do jogado por último, para entrar quando chegar.
var _cover: MeshInstance3D
var _cover_app_id: int = 0
var _stats: Dictionary = {}


func _ready() -> void:
	add_to_group("stats_wall")
	_build_frame()
	_content = Node3D.new()
	_content.name = "Content"
	add_child(_content)
	HubWindow.woke_up.connect(refresh)
	GameArt.art_ready.connect(_on_art_ready)
	refresh()


## Relê os números e redesenha o quadro.
func refresh() -> void:
	_stats = LibraryStats.compute()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_cover = null
	_cover_app_id = 0
	var top := PANEL_SIZE.y / 2.0
	_label("SUA BIBLIOTECA", Vector2(-2.05, top - 0.22), 56, TITLE_COLOR, "Title")
	if int(_stats["game_count"]) == 0:
		_label(NO_GAMES_TEXT, Vector2(-1.5, 0.2), 48, TEXT_COLOR, "Message", 3.0)
		return
	_build_top_games()
	_build_districts()
	_build_total()
	_build_last_played()


## O resultado de LibraryStats.compute() da última atualização (para os testes).
func get_stats() -> Dictionary:
	return _stats


## Todos os textos do quadro, de cima para baixo (para os testes).
func get_texts() -> Array[String]:
	var texts: Array[String] = []
	for node in _content.get_children():
		if node is Label3D:
			texts.append((node as Label3D).text)
	return texts


func get_bars() -> Array[MeshInstance3D]:
	var bars: Array[MeshInstance3D] = []
	for node in _content.get_children():
		if node is MeshInstance3D and node.has_meta("stats_bar"):
			bars.append(node)
	return bars


## Minutos como "2,5 h" / "412 h" / "35 min" (curto, para caber ao lado da barra).
static func format_hours(minutes: int) -> String:
	if minutes < 60:
		return "%d min" % minutes
	var hours := minutes / 60.0
	if hours < 10.0:
		return "%s h" % ("%.1f" % hours).replace(".", ",").trim_suffix(",0")
	return "%d h" % floori(hours)


# --- Seções ---------------------------------------------------------------------

func _build_top_games() -> void:
	_label("MAIS JOGADOS", Vector2(-2.05, 0.78), 36, HEADING_COLOR, "Heading")
	if not bool(_stats["hours_known"]):
		_label(UNKNOWN_HOURS_TEXT, Vector2(-2.05, 0.5), 40, MUTED_COLOR, "Hint", 2.0)
		return
	var top: Array = _stats["top"]
	if top.is_empty():
		_label(NO_HOURS_TEXT, Vector2(-2.05, 0.5), 40, MUTED_COLOR, "Hint", 2.0)
		return
	var best := float(top[0]["minutes"])
	for i in top.size():
		var y := 0.52 - i * ROW_STEP
		var game: Dictionary = top[i]
		_label(_shorten(String(game["name"]), 15), Vector2(-2.05, y), 34, TEXT_COLOR, "TopName")
		var length := TOP_BAR_MAX * float(game["minutes"]) / best
		_bar(Vector2(-1.3, y), length, BAR_COLOR)
		_label(format_hours(int(game["minutes"])), Vector2(-1.3 + length + 0.05, y), 34, TEXT_COLOR, "TopHours")


func _build_districts() -> void:
	var known := bool(_stats["hours_known"]) and bool(_stats["played_any"])
	_label("POR BAIRRO", Vector2(0.1, 0.78), 36, HEADING_COLOR, "Heading")
	var districts: Array = _stats["districts"]
	var key := "minutes" if known else "games"
	var best := 1.0
	for entry: Dictionary in districts:
		best = maxf(best, float(entry[key]))
	for i in mini(districts.size(), DISTRICT_ROWS):
		var entry: Dictionary = districts[i]
		var y := 0.52 - i * ROW_STEP
		_label(_shorten(String(entry["name"]), 12), Vector2(0.1, y), 34, TEXT_COLOR, "DistrictName")
		var length := DISTRICT_BAR_MAX * float(entry[key]) / best
		_bar(Vector2(0.7, y), length, GameCategories.get_neon_color(String(entry["id"])))
		var text := format_hours(int(entry["minutes"])) if known else "%d jogos" % int(entry["games"])
		_label(text, Vector2(0.7 + length + 0.05, y), 34, TEXT_COLOR, "DistrictValue")


func _build_total() -> void:
	_label("HORAS JOGADAS", Vector2(-2.05, -0.74), 32, HEADING_COLOR, "Heading")
	var text := "—"
	if bool(_stats["hours_known"]):
		text = format_hours(int(_stats["total_minutes"])) if bool(_stats["played_any"]) else "0 h"
	_label(text, Vector2(-2.05, -1.04), 96, BAR_COLOR, "Total")


func _build_last_played() -> void:
	var last: Dictionary = _stats["last_played"]
	if last.is_empty():
		return
	_label("JOGADO POR ÚLTIMO", Vector2(0.1, -0.74), 32, HEADING_COLOR, "Heading")
	_cover_app_id = int(last["app_id"])
	_cover = MeshInstance3D.new()
	_cover.name = "Cover"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.26, 0.39)
	_cover.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.18, 0.22)
	material.roughness = 0.6
	var art := GameArt.get_art(_cover_app_id)
	if art != null:
		material.albedo_texture = art
		material.albedo_color = Color.WHITE
	_cover.material_override = material
	_cover.position = _at(Vector2(0.23, -1.04), 0.01)
	_cover.layers = Home.INTERIOR_LAYER_MASK
	_content.add_child(_cover)
	_label(_shorten(String(last["name"]), 22), Vector2(0.45, -0.96), 38, TEXT_COLOR, "LastName")
	_label(GameInfo.format_last_played(int(last["time"])), Vector2(0.45, -1.16), 32, MUTED_COLOR, "LastWhen")


# --- Peças ----------------------------------------------------------------------

## Posição no quadro (x à direita, y para cima, do centro) em coordenadas do nó.
func _at(spot: Vector2, depth: float = 0.0) -> Vector3:
	return Vector3(spot.x, CENTER_Y + spot.y, 0.065 + depth)


func _label(text: String, spot: Vector2, size: int, color: Color, label_name: String, width: float = 0.0) -> void:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0025
	label.modulate = color
	label.outline_size = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if width > 0.0:
		label.width = width / label.pixel_size
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = _at(spot)
	label.layers = Home.INTERIOR_LAYER_MASK
	_content.add_child(label)


## Barra fina que começa em "spot" (borda esquerda) e vai para a direita.
func _bar(spot: Vector2, length: float, color: Color) -> void:
	var bar := MeshInstance3D.new()
	bar.set_meta("stats_bar", true)  # os nomes repetidos viram "@Classe@N": a marca é que identifica
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(length, 0.01), 0.07, 0.02)
	bar.mesh = mesh
	bar.material_override = HomeMaterials.glow(color, 1.2)
	bar.position = _at(spot + Vector2(mesh.size.x / 2.0, 0.0), 0.0)
	bar.layers = Home.INTERIOR_LAYER_MASK
	_content.add_child(bar)


func _shorten(text: String, max_chars: int) -> String:
	return text if text.length() <= max_chars else text.left(max_chars - 1).strip_edges() + "…"


func _on_art_ready(app_id: int, texture: Texture2D) -> void:
	if _cover != null and app_id == _cover_app_id and texture != null:
		var material := _cover.material_override as StandardMaterial3D
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE


## O quadro escuro com moldura de madeira (colisão: o jogador não entra nele).
func _build_frame() -> void:
	var panel := MeshInstance3D.new()
	panel.name = "Panel"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(PANEL_SIZE.x, PANEL_SIZE.y, 0.06)
	panel.mesh = mesh
	panel.material_override = HomeMaterials.matte(BOARD_COLOR, 0.8)
	panel.position = Vector3(0.0, CENTER_Y, 0.03)
	panel.layers = Home.INTERIOR_LAYER_MASK
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	body.add_child(shape)
	panel.add_child(body)
	add_child(panel)

	var wood := HomeMaterials.wood(FRAME_WOOD, false, 0.45)
	var bar := 0.07
	for y in [CENTER_Y - PANEL_SIZE.y / 2.0, CENTER_Y + PANEL_SIZE.y / 2.0]:
		_frame_bar(Vector3(PANEL_SIZE.x + bar * 2.0, bar, 0.08), Vector3(0.0, y, 0.04), wood)
	for x in [-PANEL_SIZE.x / 2.0 - bar / 2.0, PANEL_SIZE.x / 2.0 + bar / 2.0]:
		_frame_bar(Vector3(bar, PANEL_SIZE.y, 0.08), Vector3(x, CENTER_Y, 0.04), wood)


func _frame_bar(bar_size: Vector3, center: Vector3, material: Material) -> void:
	var bar := MeshInstance3D.new()
	bar.name = "FrameBar"
	var mesh := BoxMesh.new()
	mesh.size = bar_size
	bar.mesh = mesh
	bar.material_override = material
	bar.position = center
	bar.layers = Home.INTERIOR_LAYER_MASK
	add_child(bar)
