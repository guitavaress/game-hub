class_name Toast
extends Control
## Um AVISO do HUD: painel escuro com uma barrinha colorida à esquerda, um
## título (o que houve) e uma frase (o que fazer). Some sozinho. Pode ter um
## rótulo pequeno acima do título ("BEM-VINDO DE VOLTA").
##
##   Tipos:  INFO    amarelo, 6 s
##           ERROR   vermelho, 10 s
##           SESSION verde, 5 s (a "volta do jogo")
##
## Entra descendo 12 px e aparecendo em 0,2 s; sai sumindo em 0,2 s.
## Quem empilha os avisos é o HUD (um VBoxContainer no topo da tela).
## Montado por código: Toast (vaga na pilha) › PanelContainer › VBox › Labels.

## Avisou que saiu da tela (já pode ser apagado).
signal closed

enum Kind { INFO, ERROR, SESSION }

const WIDTH: float = 500.0
const PANEL_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.78)
const ACCENTS: Dictionary[Kind, Color] = {
	Kind.INFO: Color("F2C14E"),
	Kind.ERROR: Color("E5534B"),
	Kind.SESSION: Color("5FE3A1"),
}
const SECONDS: Dictionary[Kind, float] = {
	Kind.INFO: 6.0,
	Kind.ERROR: 10.0,
	Kind.SESSION: 5.0,
}
const TITLE_COLOR: Color = Color("F2F3F5")
const TEXT_COLOR: Color = Color("B8BFCC")
const ANIMATION_TIME: float = 0.2
const SLIDE_PIXELS: float = 12.0

var kind: Kind = Kind.INFO
var title: String = ""
var text: String = ""
## Rótulo pequeno opcional acima do título (ex.: "BEM-VINDO DE VOLTA").
var overline: String = ""

var _panel: PanelContainer
var _closing: bool = false
var _shown_ms: int = 0


## Cria um aviso. "seconds" < 0 usa o tempo padrão do tipo.
static func create(toast_title: String, toast_text: String, toast_kind: Kind = Kind.INFO,
		seconds: float = -1.0, toast_overline: String = "") -> Toast:
	var toast := Toast.new()
	toast.title = toast_title
	toast.text = toast_text
	toast.kind = toast_kind
	toast.overline = toast_overline
	toast.set_meta("seconds", seconds if seconds > 0.0 else SECONDS[toast_kind])
	return toast


## Há quantos segundos o aviso está na tela.
func get_age() -> float:
	return (Time.get_ticks_msec() - _shown_ms) / 1000.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _make_style(ACCENTS[kind]))
	_panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_shown_ms = Time.get_ticks_msec()
	if not overline.is_empty():
		# Rótulo: Barlow Condensed com 2 px a mais entre as letras, na cor do tipo.
		var spaced := FontVariation.new()
		spaced.base_font = HubFonts.SIGN
		spaced.spacing_glyph = 2
		column.add_child(_make_label(overline, spaced, 14, ACCENTS[kind]))
	# Sessão: o título (a duração) é um pouco maior.
	column.add_child(_make_label(title, HubFonts.TEXT, 20 if kind == Kind.SESSION else 18, TITLE_COLOR))
	if not text.is_empty():
		column.add_child(_make_label(text, HubFonts.LIGHT, 15, TEXT_COLOR))

	# A "vaga" na pilha tem o tamanho do painel.
	_panel.minimum_size_changed.connect(_fit_to_panel)
	_fit_to_panel()

	# Entrada: desce 12 px e aparece.
	_panel.position.y = -SLIDE_PIXELS
	modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "position:y", 0.0, ANIMATION_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_TIME)

	get_tree().create_timer(get_meta("seconds"), false).timeout.connect(close)


## Tira o aviso da tela (sumindo aos poucos).
func close() -> void:
	if _closing or not is_inside_tree():
		return
	_closing = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_TIME)
	tween.finished.connect(func() -> void:
		closed.emit()
		queue_free())


func is_closing() -> bool:
	return _closing


func _fit_to_panel() -> void:
	custom_minimum_size = _panel.get_combined_minimum_size()
	_panel.size = custom_minimum_size


func _make_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(6)
	style.border_width_left = 4
	style.border_color = accent
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 11.0
	return style


func _make_label(label_text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
