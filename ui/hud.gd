class_name Hud
extends CanvasLayer
## HUD mínimo, montado por código:
## - mira no centro da tela;
## - nome do que o jogador está olhando, logo abaixo da mira;
## - linha de avisos no topo, que some sozinha depois de alguns segundos.

const MESSAGE_SECONDS: float = 6.0
const LOOK_FONT_SIZE: int = 22
const MESSAGE_FONT_SIZE: int = 20

var _look_label: Label
var _message_label: Label
var _message_timer: Timer


func _ready() -> void:
	_build_crosshair()
	_look_label = _make_label(LOOK_FONT_SIZE, Color.WHITE)
	_look_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# Faixa larga logo abaixo da mira, com o texto centralizado.
	_look_label.offset_left = -400.0
	_look_label.offset_right = 400.0
	_look_label.offset_top = 18.0
	_look_label.offset_bottom = 50.0

	_message_label = _make_label(MESSAGE_FONT_SIZE, Color(1.0, 0.85, 0.3))
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message_label.offset_left = -500.0
	_message_label.offset_right = 500.0
	_message_label.offset_top = 24.0
	_message_label.offset_bottom = 80.0
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func() -> void: _message_label.text = "")
	add_child(_message_timer)


## Mostra (ou apaga, com "") o nome do que o jogador está olhando.
func set_look_text(text: String) -> void:
	_look_label.text = text


## Mostra um aviso no topo da tela por alguns segundos.
func show_message(text: String, seconds: float = MESSAGE_SECONDS) -> void:
	_message_label.text = text
	_message_timer.start(seconds)


func _build_crosshair() -> void:
	# Um quadradinho branco com borda preta, bem no centro.
	var border := ColorRect.new()
	border.color = Color(0.0, 0.0, 0.0, 0.7)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	border.offset_left = -3.0
	border.offset_top = -3.0
	border.offset_right = 3.0
	border.offset_bottom = 3.0
	add_child(border)

	var dot := ColorRect.new()
	dot.color = Color.WHITE
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.position = Vector2(1.0, 1.0)
	dot.size = Vector2(4.0, 4.0)
	border.add_child(dot)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	# Contorno preto para ler o texto em qualquer fundo.
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label
