class_name HubTheme
extends RefCounted
## O TEMA DO HUB (Fase 12): um lugar só para as cores, as fontes, os tamanhos e
## os estilos de todas as telas. Ajudante estático, NÃO é autoload.
##
## Uso: quem monta uma tela põe o tema no Control de cima dela
## (`painel.theme = HubTheme.get_theme()`) e escolhe a "variação" de cada peça
## (`label.theme_type_variation = &"HubCaption"`). Nenhuma tela escreve cor,
## fonte, tamanho ou caixa por conta própria. O espaço entre as peças
## ("separation") é de cada tela: é arrumação, não estilo.
##
## As variações (o nome vai em theme_type_variation):
##   Label:          HubCaption (dica), HubBody (texto), HubBodyLight (texto
##                   secundário), HubValue (número ao lado de um deslizador),
##                   HubLead (destaque), HubTitle (título), HubSection (seção),
##                   HubBrand ("GAME HUB"), HubKeyLabel (letra de uma tecla),
##                   HubStatusOk e HubStatusError (linha de situação);
##   Button:         (padrão: botão secundário), HubButtonPrimary, HubTab,
##                   HubSegment (botões lado a lado: Leve | Média | Alta);
##   PanelContainer: HubPanel (HUD, avisos, cartões), HubPanelStrong (menus),
##                   HubSidePanel (menu de pausa, encostado na borda),
##                   HubScreen (fundo da tela do computador), HubKeyCap (tecla).

# --- Cores ------------------------------------------------------------------------

const TEXT_COLOR: Color = Color("E6E9EE")
const SECONDARY_COLOR: Color = Color("B8BFCC")
const HINT_COLOR: Color = Color("8A92A0")
## Texto escuro, em cima de um botão claro.
const DARK_TEXT_COLOR: Color = Color("0B0D11")
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)
const FIELD_COLOR: Color = Color("16181D")
const FIELD_HOVER_COLOR: Color = Color("1F2228")
const FIELD_BORDER: Color = Color("3A3F48")
const KEY_BORDER: Color = Color("5A606B")
const OK_COLOR: Color = Color("5FE3A1")
const ERROR_COLOR: Color = Color("E5534B")
## As duas cores de painel: a leve (HUD, avisos, cartões) e a forte (menus).
const PANEL_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.85)
const PANEL_STRONG_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.94)

# --- Fontes e tamanhos -----------------------------------------------------------

## Os 5 tamanhos de letra do hub.
const SIZE_CAPTION: int = 14  # dica, tecla, seção
const SIZE_BODY: int = 16     # texto, botões, campos
const SIZE_LEAD: int = 20     # destaque
const SIZE_TITLE: int = 28    # título de tela
const SIZE_DISPLAY: int = 46  # título grande (ex.: nome do bairro)
## Só as telas que cobrem tudo (a "Abrindo"/"Jogando" e o splash) usam estes.
const SIZE_FULLSCREEN_NAME: int = 96
const SIZE_FULLSCREEN_PLAYING: int = 72
const SIZE_FULLSCREEN_NUMBER: int = 52

## O raio dos cantos de tudo o que é arredondado.
const RADIUS: int = 6
## Borda do item com foco (teclado ou controle).
const FOCUS_BORDER: int = 2

static var _theme: Theme


## O tema (montado uma vez só).
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Barlow Condensed com "extra" px entre as letras (títulos e seções).
static func spaced_font(extra: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = HubFonts.SIGN
	font.spacing_glyph = extra
	return font


# --- Peças prontas -------------------------------------------------------------------

## Um texto com a variação dada (veja a lista no topo).
static func label(text: String, variation: StringName = &"HubBody") -> Label:
	var label_node := Label.new()
	label_node.text = text
	label_node.theme_type_variation = variation
	return label_node


## Um botão: "primary" = claro (a ação principal); senão, o escuro de sempre.
static func button(text: String, primary: bool = false) -> Button:
	var button_node := Button.new()
	button_node.text = text
	button_node.focus_mode = Control.FOCUS_NONE
	if primary:
		button_node.theme_type_variation = &"HubButtonPrimary"
	return button_node


## Uma linha fina de separação.
static func line() -> ColorRect:
	var line_node := ColorRect.new()
	line_node.color = LINE_COLOR
	line_node.custom_minimum_size = Vector2(0.0, 1.0)
	line_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line_node


## Um espaço vazio de "height" px.
static func spacer(height: float) -> Control:
	var spacer_node := Control.new()
	spacer_node.custom_minimum_size = Vector2(0.0, height)
	spacer_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer_node


## Um espaço que empurra o resto para a direita (numa fileira).
static func expander() -> Control:
	var expander_node := Control.new()
	expander_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expander_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return expander_node


## Caixa com fundo, cantos, borda e margens (esquerda, topo, direita, baixo).
static func box(background: Color, radius: int, border: Color, border_width: int, margins: Vector4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	return style


# --- Montagem ------------------------------------------------------------------------

static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font = HubFonts.TEXT
	theme.default_font_size = SIZE_BODY
	_build_labels(theme)
	_build_buttons(theme)
	_build_fields(theme)
	_build_panels(theme)
	return theme


static func _build_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", TEXT_COLOR)
	# [variação, fonte, tamanho, cor]
	var labels: Array[Array] = [
		[&"HubCaption", HubFonts.LIGHT, SIZE_CAPTION, HINT_COLOR],
		[&"HubBody", HubFonts.TEXT, SIZE_BODY, TEXT_COLOR],
		[&"HubBodyLight", HubFonts.LIGHT, SIZE_BODY, SECONDARY_COLOR],
		[&"HubValue", HubFonts.TEXT, SIZE_BODY, SECONDARY_COLOR],
		[&"HubLead", HubFonts.TEXT, SIZE_LEAD, TEXT_COLOR],
		[&"HubTitle", spaced_font(3), SIZE_TITLE, TEXT_COLOR],
		[&"HubSection", spaced_font(2), SIZE_CAPTION, HINT_COLOR],
		[&"HubBrand", spaced_font(4), SIZE_LEAD, HINT_COLOR],
		[&"HubKeyLabel", HubFonts.TEXT, SIZE_CAPTION, TEXT_COLOR],
		[&"HubStatusOk", HubFonts.LIGHT, SIZE_CAPTION, OK_COLOR],
		[&"HubStatusError", HubFonts.LIGHT, SIZE_CAPTION, ERROR_COLOR],
	]
	for entry in labels:
		theme.set_type_variation(entry[0], &"Label")
		theme.set_font("font", entry[0], entry[1])
		theme.set_font_size("font_size", entry[0], entry[2])
		theme.set_color("font_color", entry[0], entry[3])


static func _build_buttons(theme: Theme) -> void:
	var focus := _focus_style()

	# Botão padrão (secundário): escuro, com borda.
	var normal := box(FIELD_COLOR, RADIUS, FIELD_BORDER, 1, Vector4(14, 6, 14, 7))
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = FIELD_HOVER_COLOR
	_set_button(theme, &"Button", normal, hover, hover, hover, focus, TEXT_COLOR, TEXT_COLOR, TEXT_COLOR)

	# Primário: claro, letra escura.
	var primary := box(TEXT_COLOR, RADIUS, TEXT_COLOR, 1, Vector4(14, 6, 14, 7))
	var primary_hover := primary.duplicate() as StyleBoxFlat
	primary_hover.bg_color = Color.WHITE
	theme.set_type_variation(&"HubButtonPrimary", &"Button")
	_set_button(theme, &"HubButtonPrimary", primary, primary_hover, primary_hover, primary_hover, focus,
			DARK_TEXT_COLOR, DARK_TEXT_COLOR, DARK_TEXT_COLOR)

	# Aba: só o texto, com um sublinhado claro de 2 px na escolhida.
	var tab_idle := box(Color.TRANSPARENT, 0, Color.TRANSPARENT, 0, Vector4(0, 4, 0, 6))
	tab_idle.border_width_bottom = 2
	var tab_chosen := tab_idle.duplicate() as StyleBoxFlat
	tab_chosen.border_color = TEXT_COLOR
	theme.set_type_variation(&"HubTab", &"Button")
	_set_button(theme, &"HubTab", tab_idle, tab_idle, tab_chosen, tab_chosen, focus,
			HINT_COLOR, SECONDARY_COLOR, TEXT_COLOR)

	# Botões lado a lado (Leve | Média | Alta): o escolhido fica claro.
	var segment := box(FIELD_COLOR, RADIUS, FIELD_BORDER, 1, Vector4(10, 6, 10, 7))
	var segment_hover := segment.duplicate() as StyleBoxFlat
	segment_hover.bg_color = FIELD_HOVER_COLOR
	var segment_chosen := box(TEXT_COLOR, RADIUS, TEXT_COLOR, 1, Vector4(10, 6, 10, 7))
	theme.set_type_variation(&"HubSegment", &"Button")
	_set_button(theme, &"HubSegment", segment, segment_hover, segment_chosen, segment_chosen, focus,
			TEXT_COLOR, TEXT_COLOR, DARK_TEXT_COLOR)

	# Interruptor (CheckButton): fica com as caixas vazias do tema padrão da
	# Godot. Sem isto, ele herdaria a caixa com borda do Button acima.
	var defaults := ThemeDB.get_default_theme()
	for item in defaults.get_stylebox_list("CheckButton"):
		theme.set_stylebox(item, "CheckButton", defaults.get_stylebox(item, "CheckButton"))
	theme.set_stylebox("focus", "CheckButton", focus)

	# Link (ex.: "Pegar uma chave").
	theme.set_font("font", "LinkButton", HubFonts.LIGHT)
	theme.set_font_size("font_size", "LinkButton", SIZE_CAPTION)
	theme.set_color("font_color", "LinkButton", SECONDARY_COLOR)
	theme.set_color("font_hover_color", "LinkButton", TEXT_COLOR)
	theme.set_color("font_pressed_color", "LinkButton", TEXT_COLOR)
	theme.set_color("font_focus_color", "LinkButton", TEXT_COLOR)


## Os estilos e as cores de um tipo de botão. "pressed" é o estado de quem
## está escolhido (aba, botão lado a lado) ou sendo apertado.
static func _set_button(theme: Theme, type: StringName, normal: StyleBox, hover: StyleBox, pressed: StyleBox,
		hover_pressed: StyleBox, focus: StyleBox, color: Color, hover_color: Color, pressed_color: Color) -> void:
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, hover_pressed)
	theme.set_stylebox("disabled", type, normal)
	theme.set_stylebox("focus", type, focus)
	theme.set_font("font", type, HubFonts.TEXT)
	theme.set_font_size("font_size", type, SIZE_BODY)
	theme.set_color("font_color", type, color)
	theme.set_color("font_hover_color", type, hover_color)
	theme.set_color("font_focus_color", type, color)
	theme.set_color("font_pressed_color", type, pressed_color)
	theme.set_color("font_hover_pressed_color", type, pressed_color)
	theme.set_color("font_disabled_color", type, HINT_COLOR)


## O item com foco (teclado ou controle): uma borda clara por cima.
static func _focus_style() -> StyleBoxFlat:
	var focus := box(Color.TRANSPARENT, RADIUS, TEXT_COLOR, FOCUS_BORDER, Vector4.ZERO)
	focus.draw_center = false
	focus.set_expand_margin_all(2.0)
	return focus


static func _build_fields(theme: Theme) -> void:
	# Campo de texto (chave, ID Steam, busca).
	var field := box(FIELD_COLOR, RADIUS, FIELD_BORDER, 1, Vector4(10, 6, 10, 6))
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = SECONDARY_COLOR
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_font("font", "LineEdit", HubFonts.LIGHT)
	theme.set_font_size("font_size", "LineEdit", SIZE_BODY)
	theme.set_color("font_color", "LineEdit", TEXT_COLOR)
	theme.set_color("font_placeholder_color", "LineEdit", HINT_COLOR)
	theme.set_color("caret_color", "LineEdit", TEXT_COLOR)

	# Deslizador: trilho apagado e a parte cheia clara.
	var track := box(Color(1.0, 1.0, 1.0, 0.14), 2, Color.TRANSPARENT, 0, Vector4(0, 2, 0, 2))
	var filled := box(TEXT_COLOR, 2, Color.TRANSPARENT, 0, Vector4(0, 2, 0, 2))
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)


static func _build_panels(theme: Theme) -> void:
	# [variação, cor, raio, margens]
	var panels: Array[Array] = [
		[&"HubPanel", PANEL_COLOR, RADIUS, Vector4(14, 12, 14, 12)],
		[&"HubPanelStrong", PANEL_STRONG_COLOR, RADIUS, Vector4(14, 12, 14, 12)],
		[&"HubSidePanel", PANEL_STRONG_COLOR, 0, Vector4(36, 34, 36, 28)],
		# A tela do computador: a cor forte, sem transparência (é um monitor).
		[&"HubScreen", Color(PANEL_STRONG_COLOR, 1.0), 0, Vector4(44, 30, 44, 30)],
	]
	for entry in panels:
		theme.set_type_variation(entry[0], &"PanelContainer")
		theme.set_stylebox("panel", entry[0], box(entry[1], entry[2], Color.TRANSPARENT, 0, entry[3]))

	# Tecla desenhada ("Esc", "E"): fundo de campo e a borda de baixo mais grossa.
	var key := box(FIELD_COLOR, RADIUS, KEY_BORDER, 1, Vector4(8, 2, 8, 2))
	key.border_width_bottom = 2
	theme.set_type_variation(&"HubKeyCap", &"PanelContainer")
	theme.set_stylebox("panel", &"HubKeyCap", key)
