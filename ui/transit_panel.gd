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
	panel.theme = HubTheme.get_theme()
	panel.theme_type_variation = &"HubPanelStrong"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -WIDTH / 2.0
	panel.offset_right = WIDTH / 2.0
	panel.offset_top = TOP
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_label("METRÔ", &"HubSection"))
	_title = _label("", &"HubLead")
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
	if event.is_action_pressed("release_mouse") or event.is_action_pressed("ui_cancel"):
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
	var key := _label(str(index + 1) if index < 9 else " ", &"HubCaption")
	key.custom_minimum_size.x = 14.0
	content.add_child(key)
	var dot := ColorRect.new()
	dot.color = stop.color
	dot.custom_minimum_size = Vector2(10.0, 10.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(dot)
	var stop_label := _label(stop.stop_name, &"HubBody")
	stop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(stop_label)
	content.add_child(_label(stop.detail, &"HubCaption"))
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			choose(index)
		elif event is InputEventMouseMotion and _selected != index:
			_selected = index
			_paint_selection())
	return row


func _paint_selection() -> void:
	for i in _rows.size():
		_rows[i].theme_type_variation = &"HubRowSelected" if i == _selected else &"HubRow"


func _hint_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(KeyHint.create("nav"))
	row.add_child(_label("escolher", &"HubCaption"))
	row.add_child(_spacer(10))
	row.add_child(KeyHint.create("confirm"))
	row.add_child(_label("viajar", &"HubCaption"))
	row.add_child(_spacer(10))
	row.add_child(KeyHint.create("back"))
	row.add_child(_label("ficar", &"HubCaption"))
	return row


func _spacer(width: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.x = width
	return spacer


func _label(text: String, variation: StringName) -> Label:
	var label := HubTheme.label(text, variation)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
