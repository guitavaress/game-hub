class_name WorldMap
extends CanvasLayer
## MAPA GRANDE (tecla M, Fase 8.5): a planta inteira do mundo, com os nomes
## dos bairros, você, o destino da busca e as estações. Pausa o jogo como a
## busca (Tab). M ou Esc fecham.

signal opened
signal closed

const PANEL_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.92)
const HINT_COLOR: Color = Color("8C93A0")
const MARGIN: float = 48.0

var _view: MapView
var _hint: Label


func _ready() -> void:
	layer = 38
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = MARGIN
	panel.offset_right = -MARGIN
	panel.offset_top = MARGIN
	panel.offset_bottom = -MARGIN
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_view = MapView.new()
	_view.follow_player = false
	_view.show_labels = true
	_view.custom_minimum_size = Vector2(480.0, 320.0)
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_view)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(GameScreen.make_key_cap("M"))
	_hint = Label.new()
	_hint.text = "fechar o mapa"
	_hint.add_theme_font_override("font", HubFonts.LIGHT)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", HINT_COLOR)
	row.add_child(_hint)
	column.add_child(row)


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("release_mouse") or event.is_action_pressed("open_map")):
		close()
		get_viewport().set_input_as_handled()
	elif not visible and event.is_action_pressed("open_map") and can_open():
		open()
		get_viewport().set_input_as_handled()


## Dá para abrir agora? Mesmas regras da busca.
func can_open() -> bool:
	var player := get_parent() as Player
	return not GameLauncher.is_busy() and not HubWindow.is_sleeping \
			and not ScreenFade.door_charge.visible and ScreenFade.get_amount() < 0.5 \
			and not (player != null and (player.in_intro or player.is_traveling() \
			or player.get_pause_menu().is_open() or player.get_game_search().is_open()))


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# O controle só tem tamanho depois de aparecer: desenha no quadro seguinte.
	_view.refresh.call_deferred()
	opened.emit()


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


func get_view() -> MapView:
	return _view
