class_name HomeSettingsView
extends VBoxContainer
## A aba "CASA" do menu de pausa (Fase 13.8; veio do computador na 14.25): tema, posição dos móveis e as cores
## das paredes e do néon. Cada clique grava no AppConfig ([home]) e a casa muda
## na hora, atrás do menu. É uma página do SettingsView (add_page).
##
## As opções vêm do catálogo (profiles/home_catalog.tres): temas, disposições e
## as paletas de cores. O teclado e o controle andam pelos botões como no resto
## do SettingsView (a ordem do foco é montada por ele).

const SWATCH_SIZE: Vector2 = Vector2(38.0, 30.0)
## Valor de "voltar à cor do tema".
const FROM_THEME: String = ""

var _theme_buttons: Dictionary[String, Button] = {}
var _layout_buttons: Dictionary[String, Button] = {}
var _wall_buttons: Dictionary[String, Button] = {}
var _neon_buttons: Dictionary[String, Button] = {}
## true enquanto as escolhas estão sendo marcadas (não é o usuário mexendo).
var _refreshing: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var catalog := Profiles.home_catalog()
	add_child(HubTheme.label("TEMA", &"HubSection"))
	var themes: Array[Array] = []
	for profile in catalog.homes:
		themes.append([profile.id, profile.display_name])
	add_child(_segmented(themes, _theme_buttons, func(id: String) -> void: AppConfig.set_home_theme(id)))

	add_child(HubTheme.label("MÓVEIS", &"HubSection"))
	var layouts: Array[Array] = []
	for layout in catalog.layouts:
		layouts.append([layout.id, layout.display_name])
	add_child(_segmented(layouts, _layout_buttons, func(id: String) -> void: AppConfig.set_home_layout(id)))

	add_child(HubTheme.label("PAREDES", &"HubSection"))
	add_child(_swatches(catalog.wall_palette, _wall_buttons, func(html: String) -> void: AppConfig.set_home_wall_color(html)))
	add_child(HubTheme.label("NÉON", &"HubSection"))
	add_child(_swatches(catalog.neon_palette, _neon_buttons, func(html: String) -> void: AppConfig.set_home_neon_color(html)))
	AppConfig.settings_changed.connect(_on_settings_changed)
	refresh()


## Marca o que está valendo agora (o SettingsView chama ao mostrar a tela).
func refresh() -> void:
	_refreshing = true
	var catalog := Profiles.home_catalog()
	_choose(_theme_buttons, _current_id(AppConfig.get_home_theme(), catalog.homes[0].id if not catalog.homes.is_empty() else "",
			_theme_buttons))
	_choose(_layout_buttons, _current_id(AppConfig.get_home_layout(), catalog.layouts[0].id if not catalog.layouts.is_empty() else "",
			_layout_buttons))
	_choose(_wall_buttons, _normalized(AppConfig.get_home_wall_color(), _wall_buttons))
	_choose(_neon_buttons, _normalized(AppConfig.get_home_neon_color(), _neon_buttons))
	_refreshing = false


func _on_settings_changed(section: String, _key: String) -> void:
	if section == "home" and is_inside_tree():
		refresh()


## O id marcado: o escolhido, ou o padrão se estiver vazio ou desconhecido.
func _current_id(chosen: String, default_id: String, buttons: Dictionary[String, Button]) -> String:
	return chosen if buttons.has(chosen) and not chosen.is_empty() else default_id


## A cor marcada: a da paleta que for igual à escolhida, ou "do tema".
func _normalized(html: String, buttons: Dictionary[String, Button]) -> String:
	for key in buttons:
		if not key.is_empty() and html.is_valid_html_color() and Color.html(key).is_equal_approx(Color.html(html)):
			return key
	return FROM_THEME


func _choose(buttons: Dictionary[String, Button], value: String) -> void:
	for key in buttons:
		buttons[key].set_pressed_no_signal(key == value)


## Botões lado a lado em que só um fica escolhido (como no SettingsView).
func _segmented(options: Array[Array], buttons: Dictionary[String, Button], on_choose: Callable) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for option in options:
		var button := Button.new()
		button.text = option[1]
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = &"HubSegment"
		var value: String = option[0]
		button.pressed.connect(func() -> void:
			if not _refreshing:
				on_choose.call(value))
		box.add_child(button)
		buttons[value] = button
	return box


## Uma fileira de amostras de cor, mais "Do tema" no começo.
func _swatches(palette: PackedColorArray, buttons: Dictionary[String, Button], on_choose: Callable) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	var default_button := Button.new()
	default_button.text = "Do tema"
	default_button.toggle_mode = true
	default_button.button_group = group
	default_button.theme_type_variation = &"HubSegment"
	default_button.pressed.connect(func() -> void:
		if not _refreshing:
			on_choose.call(FROM_THEME))
	box.add_child(default_button)
	buttons[FROM_THEME] = default_button
	for color in palette:
		var html := color.to_html(false)
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.button_group = group
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.tooltip_text = "#" + html
		swatch.set_meta("hub_data_color", true)  # a cor vem da paleta (dado), não é estilo solto
		swatch.add_theme_stylebox_override("normal", HubTheme.box(color, 6, Color(0, 0, 0, 0.35), 2, Vector4(0, 0, 0, 0)))
		swatch.add_theme_stylebox_override("hover", HubTheme.box(color.lightened(0.15), 6, Color(1, 1, 1, 0.6), 2, Vector4(0, 0, 0, 0)))
		swatch.add_theme_stylebox_override("pressed", HubTheme.box(color, 6, Color.WHITE, 4, Vector4(0, 0, 0, 0)))
		swatch.add_theme_stylebox_override("focus", HubTheme.box(color, 6, Color(1.0, 0.8, 0.3), 4, Vector4(0, 0, 0, 0)))
		swatch.pressed.connect(func() -> void:
			if not _refreshing:
				on_choose.call("#" + html))
		box.add_child(swatch)
		buttons["#" + html] = swatch
	return box
