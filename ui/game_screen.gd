class_name GameScreen
extends Control
## Tela de um jogo, mostrada por cima de tudo (dentro da "cortina" do ScreenFade)
## enquanto o hub está "dormindo".
##
##   ABRINDO:  o hero do jogo no topo, fundindo no preto, o logo sobre a emenda,
##             um anel girando com "Abrindo pela Steam…" e a tecla Esc.
##
## Arte: hero (1920x620) e logo da Steam, via GameArt. Sem hero: fundo escuro
## e um filete na cor do bairro. Sem logo: o nome em Barlow Condensed.
## Tudo é montado por código; medidas pensadas para 1280x720 (escala junto).

const BACKGROUND: Color = Color("08090C")
const TEXT_SECONDARY: Color = Color("B8BFCC")
const TEXT_HINT: Color = Color("8A92A0")
## O hero ocupa a largura toda: 1280 x 413 em 1280x720 (proporção de 1920x620).
const HERO_HEIGHT_FRACTION: float = 413.0 / 720.0
const LOGO_MAX_SIZE: Vector2 = Vector2(480.0, 170.0)

var _mode: String = ""
var _app_id: int = 0

# Modo ABRINDO
var _opening: Control
var _hero: TextureRect
var _hero_fade: TextureRect
var _logo: TextureRect
var _name_label: Label
var _status_label: Label
var _spinner: Spinner
var _accent_line: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_build_opening()

	# Filete na cor do bairro, na borda de baixo: liga a tela à cidade.
	_accent_line = ColorRect.new()
	_accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_anchors(_accent_line, 0.0, 1.0, 1.0, 1.0)
	_accent_line.offset_top = -3.0
	add_child(_accent_line)


## Mostra a tela "Abrindo X…" desse jogo.
func show_opening(app_id: int) -> void:
	_app_id = app_id
	_mode = "abrindo"
	_fill_common(app_id)
	_status_label.text = "Abrindo a Steam…" if GameLauncher.steam_was_closed else "Abrindo pela Steam…"
	_opening.visible = true
	visible = true


func get_mode() -> String:
	return _mode if visible else ""


## O nome do jogo que a tela está mostrando.
func get_title() -> String:
	return _name_label.text


## O texto de estado ("Abrindo pela Steam…").
func get_status() -> String:
	return _status_label.text


# --- Conteúdo ----------------------------------------------------------------

func _fill_common(app_id: int) -> void:
	var hero := GameArt.get_hero(app_id)
	var logo := GameArt.get_logo(app_id)
	_hero.texture = hero
	_hero.visible = hero != null
	_hero_fade.visible = hero != null
	_logo.texture = logo
	_logo.visible = logo != null
	_name_label.text = SteamLibrary.get_game_name(app_id).to_upper()
	_name_label.visible = logo == null
	_accent_line.color = GameCategories.get_neon_color(GameCategories.get_category_id(app_id))


# --- Montagem ----------------------------------------------------------------

func _build_opening() -> void:
	_opening = Control.new()
	_opening.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_opening)

	# Hero no topo, cobrindo a largura (cortado nas pontas se precisar).
	_hero = TextureRect.new()
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_anchors(_hero, 0.0, 0.0, 1.0, HERO_HEIGHT_FRACTION)
	_opening.add_child(_hero)

	# Degradê: o hero "se funde" no fundo a partir de 30% da altura dele.
	_hero_fade = TextureRect.new()
	_hero_fade.texture = _gradient(Vector2(0.0, 0.0), Vector2(0.0, 1.0), 0.3, 1.0)
	_hero_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_fade.stretch_mode = TextureRect.STRETCH_SCALE
	_hero_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_anchors(_hero_fade, 0.0, 0.0, 1.0, HERO_HEIGHT_FRACTION + 0.002)
	_opening.add_child(_hero_fade)

	# Coluna central: logo (ou nome) sobre a emenda, e o estado embaixo.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_anchors(column, 0.0, HERO_HEIGHT_FRACTION - LOGO_MAX_SIZE.y / 2.0 / 720.0, 1.0, 1.0)
	_opening.add_child(column)

	_logo = TextureRect.new()
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = LOGO_MAX_SIZE
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_logo)

	_name_label = _make_label(HubFonts.SIGN, 96, Color.WHITE)
	_name_label.custom_minimum_size = Vector2(0.0, LOGO_MAX_SIZE.y)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_name_label)

	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 14)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(status_row)
	_spinner = Spinner.new()
	_spinner.custom_minimum_size = Vector2(22.0, 22.0)
	status_row.add_child(_spinner)
	_status_label = _make_label(HubFonts.LIGHT, 24, TEXT_SECONDARY)
	status_row.add_child(_status_label)

	# Dica da tecla Esc, embaixo.
	var hint := HBoxContainer.new()
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.add_theme_constant_override("separation", 10)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_anchors(hint, 0.0, 1.0, 1.0, 1.0)
	hint.offset_top = -80.0
	hint.offset_bottom = -48.0
	_opening.add_child(hint)
	hint.add_child(make_key_cap("Esc"))
	hint.add_child(_make_label(HubFonts.LIGHT, 14, TEXT_HINT, "cancela a espera"))


## Degradê de transparente para o fundo escuro, entre os pontos "from" e "to".
func _gradient(from: Vector2, to: Vector2, start: float, end_alpha: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BACKGROUND, 0.0))
	gradient.set_color(1, Color(BACKGROUND, end_alpha))
	gradient.set_offset(0, start)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	return texture


## "Tecla" desenhada: um quadradinho com borda e o nome da tecla.
static func make_key_cap(key_name: String) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("16181D")
	style.border_color = Color("5A606B")
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", style)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = key_name
	label.add_theme_font_override("font", HubFonts.TEXT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("E6E9EE"))
	cap.add_child(label)
	return cap


func _make_label(font: Font, font_size: int, color: Color, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func _set_anchors(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


## Anel que gira: um arco de 3/4 de volta, desenhado por código.
class Spinner:
	extends Control

	var color: Color = Color("E6E9EE")

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			pivot_offset = size / 2.0
			rotation += delta * TAU * 0.9

	func _draw() -> void:
		var radius := minf(size.x, size.y) / 2.0 - 2.0
		draw_arc(size / 2.0, radius, 0.0, TAU * 0.75, 32, color, 2.5, true)
