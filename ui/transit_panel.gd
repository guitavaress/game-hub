class_name TransitPanel
extends CanvasLayer
## PAINEL DE LINHAS do metrô (Fase 8.6): abre quando o jogador pisa na entrada
## de uma estação (TransitStop). Lista as outras estações, na ordem do mundo,
## com a cor da linha e quantos jogos há no bairro. Escolher leva até lá:
## tela escura, "Metrô → RPG e Fantasia" e o som do trem.
##
## Setas ou números (1 a 9) escolhem, Enter (ou clique) viaja, Esc fecha.
## Pausa o jogo como a busca (Tab). Fica no grupo "transit_panel": as
## estações não conhecem o jogador, só chamam open_for(estação).

signal opened
signal closed

const WIDTH: float = 460.0
const TOP: float = 72.0
const PANEL_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.92)
const TEXT_COLOR: Color = Color("F2F3F5")
const SECONDARY_COLOR: Color = Color("B8BFCC")
const HINT_COLOR: Color = Color("8A92A0")
const SELECTED_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)
const CHOOSE_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/click_003.ogg")
## Som da viagem (gerado por assets/generated/make_sounds.py).
const RIDE_SOUND: AudioStream = preload("res://assets/generated/metro_ride.wav")
## A viagem: escurece, fica no escuro (o trem andando) e clareia (segundos).
const RIDE_FADE: float = 0.5
const RIDE_HOLD: float = 1.6

var _title: Label
var _list: VBoxContainer
var _rows: Array[PanelContainer] = []
## Estações na lista agora (sem a atual) e qual está escolhida.
var _stops: Array[TransitStop] = []
var _selected: int = 0
var _current: TransitStop
var _click: AudioStreamPlayer
var _ride: AudioStreamPlayer


func _ready() -> void:
	layer = 41
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("transit_panel")

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
	column.add_child(_label("METRÔ", HubFonts.LIGHT, 13, SECONDARY_COLOR))
	_title = _label("", HubFonts.TEXT, 20, TEXT_COLOR)
	column.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	column.add_child(_list)
	column.add_child(_hint_row())

	_click = AudioStreamPlayer.new()
	_click.stream = CHOOSE_SOUND
	_click.bus = &"Efeitos"
	_click.volume_db = -12.0
	add_child(_click)
	_ride = AudioStreamPlayer.new()
	_ride.stream = RIDE_SOUND
	_ride.bus = &"Efeitos"
	_ride.volume_db = -6.0
	add_child(_ride)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("release_mouse"):
		close()
	elif event.is_action_pressed("ui_down") and not _stops.is_empty():
		_selected = (_selected + 1) % _stops.size()
		_paint_selection()
	elif event.is_action_pressed("ui_up") and not _stops.is_empty():
		_selected = (_selected - 1 + _stops.size()) % _stops.size()
		_paint_selection()
	elif event.is_action_pressed("ui_accept"):
		choose(_selected)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		choose(event.keycode - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()


## Uma estação pede o painel (o jogador pisou na entrada). Devolve true se abriu.
func open_for(stop: TransitStop) -> bool:
	if visible or not can_open():
		return false
	_current = stop
	_title.text = "Estação " + stop.stop_name
	_stops.clear()
	for node in get_tree().get_nodes_in_group("transit_stop"):
		var other := node as TransitStop
		if other != null and other != stop:
			_stops.append(other)
	_stops.sort_custom(func(a: TransitStop, b: TransitStop) -> bool: return a.order < b.order)
	_build_rows()
	_selected = 0
	_paint_selection()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()
	return true


## Dá para abrir agora? Mesmas regras da busca (sem jogo abrindo, sem outro
## painel aberto, fora da abertura e de uma viagem).
func can_open() -> bool:
	var player := get_parent() as Player
	return not GameLauncher.is_busy() and not HubWindow.is_sleeping \
			and not ScreenFade.door_charge.visible and ScreenFade.get_amount() < 0.5 \
			and not (player != null and (player.in_intro or player.is_traveling() or player.is_overlay_open()))


func close() -> void:
	if not visible:
		return
	visible = false
	if not HubWindow.is_sleeping:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return visible


## Os nomes na lista agora (para os testes).
func get_stop_names() -> PackedStringArray:
	var names := PackedStringArray()
	for stop in _stops:
		names.append(stop.stop_name)
	return names


## Viaja até a estação "index" da lista (igual a apertar Enter nela).
func choose(index: int) -> void:
	if index < 0 or index >= _stops.size():
		return
	var target := _stops[index]
	var player := get_parent() as Player
	close()
	if player == null or GameLauncher.is_busy():
		return
	_click.play()
	_ride.play()
	player.travel_to(target.get_exit_transform(), "Metrô → " + target.stop_name, RIDE_FADE, RIDE_HOLD)


# --- Peças --------------------------------------------------------------------

func _build_rows() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	for i in _stops.size():
		var row := _make_row(_stops[i], i)
		_list.add_child(row)
		_rows.append(row)


func _make_row(stop: TransitStop, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	row.add_child(content)
	var key := _label(str(index + 1) if index < 9 else " ", HubFonts.LIGHT, 14, HINT_COLOR)
	key.custom_minimum_size.x = 14.0
	content.add_child(key)
	var dot := ColorRect.new()
	dot.color = stop.color
	dot.custom_minimum_size = Vector2(10.0, 10.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(dot)
	var stop_label := _label(stop.stop_name, HubFonts.TEXT, 16, TEXT_COLOR)
	stop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(stop_label)
	content.add_child(_label(stop.detail, HubFonts.LIGHT, 14, SECONDARY_COLOR))
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			choose(index)
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


func _hint_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(GameScreen.make_key_cap("↑↓"))
	row.add_child(_label("escolher", HubFonts.LIGHT, 14, HINT_COLOR))
	row.add_child(_spacer(10))
	row.add_child(GameScreen.make_key_cap("Enter"))
	row.add_child(_label("viajar", HubFonts.LIGHT, 14, HINT_COLOR))
	row.add_child(_spacer(10))
	row.add_child(GameScreen.make_key_cap("Esc"))
	row.add_child(_label("ficar", HubFonts.LIGHT, 14, HINT_COLOR))
	return row


func _spacer(width: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.x = width
	return spacer


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
