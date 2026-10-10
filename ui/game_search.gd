class_name GameSearch
extends CanvasLayer
## Busca de jogos (Tab): um campo de 500 px no alto da tela e, embaixo, os
## jogos que combinam com o que foi digitado ("Balatro · Cartas · 140 m").
## Setas escolhem, Enter (ou clique) confirma, Esc ou Tab fecham.
## Shift+Enter (ou Shift+clique) viaja direto até a porta, sem abrir o jogo.
##
## Ao escolher, o mundo desenha uma faixa de luz no chão até a porta: a busca
## chama show_route() em quem estiver no grupo "route_guide" (na cidade, o
## CityRouteGuide). Os jogos vêm dos portais (grupo "game_portal"), então a
## busca funciona em qualquer mundo.
##
## Com a busca aberta o mundo fica pausado (o que se digita não anda).

signal opened
signal closed
## Um jogo foi escolhido (e a faixa foi acesa, se o mundo tiver guia).
signal game_chosen(portal: GamePortal)

const WIDTH: float = 500.0
const TOP: float = 72.0
const MAX_RESULTS: int = 8
const PANEL_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.92)
const TEXT_COLOR: Color = Color("F2F3F5")
const SECONDARY_COLOR: Color = Color("B8BFCC")
const HINT_COLOR: Color = Color("8A92A0")
const SELECTED_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)
const CHOOSE_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/click_003.ogg")
## Letras com acento -> sem acento (para "pokemon" achar "Pokémon").
const ACCENTS: Dictionary[String, String] = {
	"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ì": "i", "î": "i", "ï": "i", "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o",
	"ú": "u", "ù": "u", "û": "u", "ü": "u", "ç": "c", "ñ": "n",
}

var _field: LineEdit
var _list: VBoxContainer
var _empty: Label
## Jogos na lista agora (na ordem mostrada) e qual está escolhido.
var _results: Array[GamePortal] = []
var _rows: Array[PanelContainer] = []
var _selected: int = 0
## Distância (m) do jogador até cada portal, medida ao abrir.
var _distances: Dictionary[GamePortal, float] = {}
var _sound: AudioStreamPlayer
## Texto do Enter na dica (em casa vira "ir até a porta").
var _enter_hint: Label


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -WIDTH / 2.0
	panel.offset_right = WIDTH / 2.0
	panel.offset_top = TOP
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_field = LineEdit.new()
	_field.placeholder_text = "Buscar um jogo…"
	var field_style := StyleBoxFlat.new()
	field_style.bg_color = Color("16181D")
	field_style.border_color = Color("5A606B")
	field_style.set_border_width_all(1)
	field_style.set_corner_radius_all(4)
	field_style.content_margin_left = 12.0
	field_style.content_margin_right = 12.0
	field_style.content_margin_top = 8.0
	field_style.content_margin_bottom = 8.0
	_field.add_theme_stylebox_override("normal", field_style)
	_field.add_theme_stylebox_override("focus", field_style)
	_field.add_theme_font_override("font", HubFonts.TEXT)
	_field.add_theme_font_size_override("font_size", 18)
	_field.add_theme_color_override("font_color", TEXT_COLOR)
	_field.add_theme_color_override("font_placeholder_color", HINT_COLOR)
	_field.text_changed.connect(func(_text: String) -> void: _update_results())
	_field.text_submitted.connect(func(_text: String) -> void:
		if Input.is_key_pressed(KEY_SHIFT) or _is_indoors():
			travel_to_selected()
		else:
			_choose(_selected))
	_field.gui_input.connect(_on_field_input)
	column.add_child(_field)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	column.add_child(_list)
	_empty = _label("Nenhum jogo com esse nome.", HubFonts.LIGHT, 15, HINT_COLOR)
	column.add_child(_empty)
	column.add_child(_hint_row())

	_sound = AudioStreamPlayer.new()
	_sound.stream = CHOOSE_SOUND
	_sound.bus = &"Efeitos"
	_sound.volume_db = -12.0
	add_child(_sound)


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("release_mouse") or event.is_action_pressed("search_game")):
		close()
		get_viewport().set_input_as_handled()
	elif not visible and event.is_action_pressed("search_game") and can_open():
		open()
		get_viewport().set_input_as_handled()


## Dá para abrir agora? Não com um jogo abrindo/rodando, na porta, na
## abertura ou com o menu de pausa aberto.
func can_open() -> bool:
	var player := get_parent() as Player
	return not GameLauncher.is_busy() and not HubWindow.is_sleeping \
			and not ScreenFade.door_charge.visible and ScreenFade.get_amount() < 0.5 \
			and not (player != null and (player.in_intro or player.world_loading or player.is_traveling() or player.is_overlay_open()))


func open() -> void:
	_measure_distances()
	_update_hint()
	_field.text = ""
	_update_results()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_field.grab_focus()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	_field.release_focus()
	if not HubWindow.is_sleeping:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return visible


## Os nomes na lista agora (para os testes).
func get_result_names() -> PackedStringArray:
	var names := PackedStringArray()
	for portal in _results:
		names.append(portal.get_game_name())
	return names


## Digita (usado nos testes, e igual a digitar no campo).
func set_query(text: String) -> void:
	_field.text = text
	_update_results()


## Confirma o jogo escolhido na lista (igual a apertar Enter).
func choose_selected() -> void:
	_choose(_selected)


## Viaja até a porta do jogo escolhido (igual a apertar Shift+Enter).
func travel_to_selected() -> void:
	_travel(_selected)


## O jogador está em casa? Lá não há ruas, então a faixa de luz não serve:
## o Enter vira "ir até a porta" (igual ao Shift+Enter).
func _is_indoors() -> bool:
	var player := get_parent() as Player
	return player != null and player.is_indoors()


func _update_hint() -> void:
	_enter_hint.text = "ir até a porta" if _is_indoors() else "acender o caminho"


# --- Resultados ------------------------------------------------------------------

func _measure_distances() -> void:
	_distances.clear()
	var player := get_parent() as Node3D
	for node in get_tree().get_nodes_in_group("game_portal"):
		var portal := node as GamePortal
		if portal != null and portal.app_id > 0 and player != null:
			_distances[portal] = player.global_position.distance_to(portal.get_return_transform().origin)


## Filtra pelo nome (sem ligar para maiúsculas e acentos). Os que COMEÇAM com
## o texto vêm primeiro; depois, os mais perto.
func _update_results() -> void:
	var query := _fold(_field.text.strip_edges())
	var matches: Array[GamePortal] = []
	for portal in _distances:
		if query.is_empty() or _fold(portal.get_game_name()).contains(query):
			matches.append(portal)
	matches.sort_custom(func(a: GamePortal, b: GamePortal) -> bool:
		var a_starts := not query.is_empty() and _fold(a.get_game_name()).begins_with(query)
		var b_starts := not query.is_empty() and _fold(b.get_game_name()).begins_with(query)
		if a_starts != b_starts:
			return a_starts
		return _distances[a] < _distances[b])
	_results = matches.slice(0, MAX_RESULTS)
	_selected = 0
	_rebuild_rows()


func _rebuild_rows() -> void:
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_rows.clear()
	for i in _results.size():
		var row := _make_row(_results[i], i)
		_list.add_child(row)
		_rows.append(row)
	_empty.visible = _results.is_empty()
	_paint_selection()


func _make_row(portal: GamePortal, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	row.add_child(content)
	var game_name := _label(portal.get_game_name(), HubFonts.TEXT, 16, TEXT_COLOR)
	game_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_name.clip_text = true
	game_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(game_name)
	var category_id := GameCategories.get_category_id(portal.app_id)
	var district := GameCategories.get_category_name(category_id).split(" e ")[0]
	var district_label := _label(district, HubFonts.LIGHT, 14, GameCategories.get_neon_color(category_id))
	content.add_child(district_label)
	content.add_child(_label("· %d m" % (roundi(_distances[portal] / 10.0) * 10), HubFonts.LIGHT, 14, SECONDARY_COLOR))
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.shift_pressed:
				_travel(index)
			else:
				_choose(index)
		elif event is InputEventMouseMotion and _selected != index:
			_selected = index
			_paint_selection())
	return row


func _paint_selection() -> void:
	for i in _rows.size():
		var style := StyleBoxFlat.new()
		style.bg_color = SELECTED_COLOR if i == _selected else Color.TRANSPARENT
		style.set_corner_radius_all(4)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		_rows[i].add_theme_stylebox_override("panel", style)


func _on_field_input(event: InputEvent) -> void:
	if _results.is_empty():
		return
	if event.is_action_pressed("ui_down"):
		_selected = (_selected + 1) % _results.size()
		_paint_selection()
		_field.accept_event()
	elif event.is_action_pressed("ui_up"):
		_selected = (_selected - 1 + _results.size()) % _results.size()
		_paint_selection()
		_field.accept_event()


func _choose(index: int) -> void:
	if index < 0 or index >= _results.size():
		return
	if _is_indoors():
		_travel(index)
		return
	var portal := _results[index]
	close()
	_sound.play()
	get_tree().call_group("route_guide", "show_route", get_parent(), portal)
	game_chosen.emit(portal)


## Viagem rápida: leva o jogador à frente da porta, virado para ela. Não abre o jogo.
func _travel(index: int) -> void:
	if index < 0 or index >= _results.size():
		return
	var portal := _results[index]
	var player := get_parent() as Player
	close()
	if player == null or GameLauncher.is_busy():
		return
	_sound.play()
	player.travel_to(portal.get_arrival_transform(), portal.get_game_name())


# --- Peças --------------------------------------------------------------------

func _hint_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(GameScreen.make_key_cap("↑↓"))
	row.add_child(_label("escolher", HubFonts.LIGHT, 14, HINT_COLOR))
	row.add_child(_spacer(10))
	row.add_child(GameScreen.make_key_cap("Enter"))
	_enter_hint = _label("acender o caminho", HubFonts.LIGHT, 14, HINT_COLOR)
	row.add_child(_enter_hint)
	row.add_child(_spacer(10))
	row.add_child(GameScreen.make_key_cap("Shift+Enter"))
	row.add_child(_label("ir até lá", HubFonts.LIGHT, 14, HINT_COLOR))
	row.add_child(_spacer(10))
	row.add_child(GameScreen.make_key_cap("Esc"))
	row.add_child(_label("fechar", HubFonts.LIGHT, 14, HINT_COLOR))
	return row


func _spacer(width: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(width, 0.0)
	return spacer


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Minúsculas e sem acentos.
static func _fold(text: String) -> String:
	var folded := text.to_lower()
	for accented in ACCENTS:
		folded = folded.replace(accented, ACCENTS[accented])
	return folded
