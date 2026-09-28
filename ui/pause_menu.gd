class_name PauseMenu
extends CanvasLayer
## Menu de pausa (Esc): um painel de 460 px à esquerda, com a cidade atrás
## desfocada e escurecida, e três abas:
##   Som e vídeo: volumes (Geral, Efeitos, Ambiente), tela cheia, qualidade do
##                3D (Leve/Média/Alta) e hora da cidade (Relógio/Dia/Noite);
##   Controles:   as teclas;
##   Amigos:      chave da Steam Web API e ID Steam (assim ninguém precisa
##                abrir o config.cfg).
## Cada mudança vale na hora e é gravada no config.cfg pelo AppConfig.
##
## Com o menu aberto o mundo fica pausado. Ele não abre durante a espera na
## porta nem com um jogo abrindo ou rodando (aí o Esc é de outra coisa).
## Montado por código; medidas pensadas para 1280x720 (escala junto).

signal opened
signal closed

const PANEL_WIDTH: float = 460.0
const PANEL_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.94)
const TEXT_COLOR: Color = Color("E6E9EE")
const SECONDARY_COLOR: Color = Color("B8BFCC")
const HINT_COLOR: Color = Color("8A92A0")
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)
const FIELD_COLOR: Color = Color("16181D")
const FIELD_BORDER: Color = Color("3A3F48")
const OK_COLOR: Color = Color("5FE3A1")
const ERROR_COLOR: Color = Color("E5534B")
const BACKDROP_SHADER: Shader = preload("res://ui/pause_backdrop.gdshader")
const API_KEY_URL: String = "https://steamcommunity.com/dev/apikey"
## Espera (s) depois de mexer num volume antes de gravar no arquivo.
const VOLUME_SAVE_DELAY: float = 0.4

const TAB_NAMES: Array[String] = ["Som e vídeo", "Controles", "Amigos"]
## [canal de áudio, nome na tela]
const VOLUME_ROWS: Array[Array] = [["Master", "Geral"], ["Efeitos", "Efeitos"], ["Ambiente", "Ambiente"]]
## [valor no config.cfg, nome na tela]
const QUALITY_OPTIONS: Array[Array] = [["leve", "Leve"], ["media", "Média"], ["alta", "Alta"]]
const TIME_OPTIONS: Array[Array] = [["relogio", "Relógio"], ["dia", "Dia"], ["noite", "Noite"]]
## [tecla, o que faz]
const CONTROL_ROWS: Array[Array] = [
	["WASD", "andar"],
	["Mouse", "olhar em volta"],
	["Shift", "correr"],
	["Espaço", "pular"],
	["F8", "adiantar o relógio da cidade em 3 horas"],
	["F11", "tela cheia"],
	["Esc", "pausa (este menu)"],
]

var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _volume_sliders: Dictionary[String, HSlider] = {}
var _volume_values: Dictionary[String, Label] = {}
var _volume_save_timer: Timer
var _volumes_changed: bool = false
var _fullscreen_check: CheckButton
var _quality_buttons: Dictionary[String, Button] = {}
var _quality_hint: Label
var _time_buttons: Dictionary[String, Button] = {}
var _friends_check: CheckButton
var _key_field: LineEdit
var _steam_id_field: LineEdit
var _forget_key_button: Button
var _friends_status: Label
## true enquanto os controles estão sendo preenchidos (não é o usuário mexendo).
var _refreshing: bool = false


func _ready() -> void:
	layer = 50
	# Continua funcionando com o mundo pausado (que é justamente quando aparece).
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = BACKDROP_SHADER
	backdrop.material = backdrop_material
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, 0, Color.TRANSPARENT, 0, Vector4(36, 34, 36, 28)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = PANEL_WIDTH
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	column.add_child(_label("PAUSA", _spaced_font(3), 30, TEXT_COLOR))
	column.add_child(_build_tabs())

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pages)
	for page in [_build_sound_page(), _build_controls_page(), _build_friends_page()]:
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages.add_child(page)
		_pages.append(page)

	column.add_child(_line())
	column.add_child(_build_bottom_row())

	_volume_save_timer = Timer.new()
	_volume_save_timer.one_shot = true
	_volume_save_timer.wait_time = VOLUME_SAVE_DELAY
	_volume_save_timer.timeout.connect(_save_volumes)
	add_child(_volume_save_timer)

	FriendsService.friends_changed.connect(_update_friends_status)
	FriendsService.problem.connect(_on_friends_problem)
	GameLauncher.game_started.connect(_on_game_started)
	_show_page(0)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("release_mouse"):
		return
	if visible:
		close()
		get_viewport().set_input_as_handled()
	elif can_open():
		open()
		get_viewport().set_input_as_handled()


## Dá para abrir agora? Não durante a espera na porta, nem com o hub dormindo
## ou um jogo abrindo/rodando, nem com a tela ainda escura (abertura).
func can_open() -> bool:
	return not GameLauncher.is_busy() and not HubWindow.is_sleeping \
			and not ScreenFade.door_charge.visible and ScreenFade.get_amount() < 0.5


func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()


func close() -> void:
	if not visible:
		return
	_save_volumes()
	visible = false
	# Se o hub foi dormir com o menu aberto (jogo aberto por fora), quem cuida
	# da pausa e do mouse é o HubWindow.
	if not HubWindow.is_sleeping:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return visible


func _on_game_started(_app_id: int, _source: Node) -> void:
	close()


# --- Abas ----------------------------------------------------------------------

func _build_tabs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var group := ButtonGroup.new()
	for i in TAB_NAMES.size():
		var tab := Button.new()
		tab.text = TAB_NAMES[i]
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_override("font", HubFonts.TEXT)
		tab.add_theme_font_size_override("font_size", 16)
		tab.add_theme_color_override("font_color", HINT_COLOR)
		tab.add_theme_color_override("font_hover_color", SECONDARY_COLOR)
		tab.add_theme_color_override("font_pressed_color", TEXT_COLOR)
		tab.add_theme_color_override("font_hover_pressed_color", TEXT_COLOR)
		# Aba escolhida: sublinhado claro de 2 px (as outras, sublinhado invisível).
		var idle := _box(Color.TRANSPARENT, 0, Color.TRANSPARENT, 0, Vector4(0, 4, 0, 6))
		idle.border_width_bottom = 2
		var chosen := idle.duplicate() as StyleBoxFlat
		chosen.border_color = TEXT_COLOR
		for state in ["normal", "hover", "focus"]:
			tab.add_theme_stylebox_override(state, idle)
		for state in ["pressed", "hover_pressed"]:
			tab.add_theme_stylebox_override(state, chosen)
		tab.pressed.connect(_show_page.bind(i))
		row.add_child(tab)
		_tab_buttons.append(tab)
	return row


func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].set_pressed_no_signal(i == index)


## Marca só o botão "value" num grupo de botões lado a lado.
func _choose(buttons: Dictionary[String, Button], value: String) -> void:
	for key in buttons:
		buttons[key].set_pressed_no_signal(key == value)


# --- Som e vídeo -----------------------------------------------------------------

func _build_sound_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.add_child(_section("SOM"))
	for row_info in VOLUME_ROWS:
		var bus: String = row_info[0]
		var row := _row(row_info[1])
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE
		_style_slider(slider)
		slider.value_changed.connect(_on_volume_changed.bind(bus))
		row.add_child(slider)
		var value := _label("", HubFonts.TEXT, 15, SECONDARY_COLOR)
		value.custom_minimum_size = Vector2(36.0, 0.0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		page.add_child(row)
		_volume_sliders[bus] = slider
		_volume_values[bus] = value

	page.add_child(_spacer(6))
	page.add_child(_section("VÍDEO"))
	var fullscreen_row := _row("Tela cheia")
	fullscreen_row.add_child(_expander())
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.focus_mode = Control.FOCUS_NONE
	_fullscreen_check.toggled.connect(func(on: bool) -> void:
		if not _refreshing:
			HubWindow.set_fullscreen(on))
	fullscreen_row.add_child(_fullscreen_check)
	page.add_child(fullscreen_row)

	var quality_row := _row("Qualidade")
	quality_row.add_child(_segmented(QUALITY_OPTIONS, _quality_buttons, _on_quality_chosen))
	page.add_child(quality_row)
	_quality_hint = _label("", HubFonts.LIGHT, 14, HINT_COLOR)
	_quality_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_quality_hint)

	var time_row := _row("Hora")
	time_row.add_child(_segmented(TIME_OPTIONS, _time_buttons, _on_time_chosen))
	page.add_child(time_row)
	return page


func _on_volume_changed(value: float, bus: String) -> void:
	_volume_values[bus].text = str(int(value))
	if _refreshing:
		return
	AppConfig.set_volume(bus, value / 100.0, false)  # ouve na hora...
	_volumes_changed = true
	_volume_save_timer.start()                         # ...e grava daqui a pouco


## Grava no config.cfg os volumes mexidos (se algum foi mexido).
func _save_volumes() -> void:
	_volume_save_timer.stop()
	if not _volumes_changed:
		return
	_volumes_changed = false
	for bus in _volume_sliders:
		AppConfig.set_volume(bus, _volume_sliders[bus].value / 100.0)


func _on_quality_chosen(level: String) -> void:
	AppConfig.set_quality(level)
	_quality_hint.text = GraphicsQuality.describe(level)


func _on_time_chosen(mode: String) -> void:
	AppConfig.set_time_of_day(mode)


# --- Controles -----------------------------------------------------------------

func _build_controls_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.add_child(_section("TECLAS"))
	for control_info in CONTROL_ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var cap_box := HBoxContainer.new()
		cap_box.custom_minimum_size = Vector2(84.0, 0.0)
		cap_box.add_child(GameScreen.make_key_cap(control_info[0]))
		row.add_child(cap_box)
		row.add_child(_label(control_info[1], HubFonts.LIGHT, 15, SECONDARY_COLOR))
		page.add_child(row)
	page.add_child(_spacer(6))
	var tip := _label("Na porta de um prédio, espere o anel encher para abrir o jogo; recue para cancelar.",
			HubFonts.LIGHT, 14, HINT_COLOR)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(tip)
	return page


# --- Amigos --------------------------------------------------------------------

func _build_friends_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	var intro := _label("Com a chave da Steam Web API, seus amigos aparecem na cidade: na porta "
			+ "do jogo que estão jogando, ou na praça.", HubFonts.LIGHT, 15, SECONDARY_COLOR)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(intro)

	var toggle_row := _row("Mostrar amigos")
	toggle_row.add_child(_expander())
	_friends_check = CheckButton.new()
	_friends_check.focus_mode = Control.FOCUS_NONE
	_friends_check.toggled.connect(_on_friends_toggled)
	toggle_row.add_child(_friends_check)
	page.add_child(toggle_row)

	page.add_child(_label("Chave da Steam Web API", HubFonts.TEXT, 15, TEXT_COLOR))
	_key_field = _field()
	_key_field.secret = true  # é segredo: aparece como bolinhas
	page.add_child(_key_field)
	var link := LinkButton.new()
	link.text = "Pegar uma chave: steamcommunity.com/dev/apikey"
	link.focus_mode = Control.FOCUS_NONE
	link.add_theme_font_override("font", HubFonts.LIGHT)
	link.add_theme_font_size_override("font_size", 14)
	link.add_theme_color_override("font_color", SECONDARY_COLOR)
	link.pressed.connect(func() -> void: OS.shell_open(API_KEY_URL))
	page.add_child(link)
	var secret_hint := _label("É segredo: fica só neste PC. No site, em \"domínio\", escreva localhost.",
			HubFonts.LIGHT, 14, HINT_COLOR)
	secret_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(secret_hint)

	page.add_child(_spacer(4))
	page.add_child(_label("ID Steam (opcional)", HubFonts.TEXT, 15, TEXT_COLOR))
	_steam_id_field = _field()
	_steam_id_field.placeholder_text = "vazio = descobrir sozinho pela Steam"
	page.add_child(_steam_id_field)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var save := _button("Salvar e conectar", true)
	save.pressed.connect(_save_friends)
	buttons.add_child(save)
	_forget_key_button = _button("Apagar chave", false)
	_forget_key_button.pressed.connect(_forget_key)
	buttons.add_child(_forget_key_button)
	page.add_child(buttons)

	_friends_status = _label("", HubFonts.LIGHT, 14, HINT_COLOR)
	_friends_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_friends_status)
	return page


func _save_friends() -> void:
	var key := _key_field.text.strip_edges()
	if key.is_empty():
		key = AppConfig.get_web_api_key()  # campo vazio = manter a chave salva
	elif not (key.length() == 32 and key.is_valid_hex_number()):
		_set_friends_status("A chave tem 32 letras e números (0-9 e A-F). Confira e cole de novo.", ERROR_COLOR)
		return
	var steam_id := _steam_id_field.text.strip_edges()
	if not steam_id.is_empty() and not (steam_id.length() == 17 and steam_id.is_valid_int()):
		_set_friends_status("O ID Steam tem 17 números (ex.: 7656119…). Ou deixe vazio.", ERROR_COLOR)
		return
	AppConfig.set_friends_settings(key, steam_id, _friends_check.button_pressed)
	_key_field.text = ""
	FriendsService.restart()
	_refresh_friends_fields()
	_update_friends_status()


## "Mostrar amigos" vale na hora (não precisa clicar em Salvar).
func _on_friends_toggled(on: bool) -> void:
	if _refreshing:
		return
	AppConfig.set_friends_settings(AppConfig.get_web_api_key(), AppConfig.get_steam_id_override(), on)
	FriendsService.restart()
	_update_friends_status()


func _forget_key() -> void:
	AppConfig.set_friends_settings("", AppConfig.get_steam_id_override(), AppConfig.are_friends_enabled())
	FriendsService.restart()
	_refresh_friends_fields()
	_update_friends_status()


func _on_friends_problem(_message: String) -> void:
	_update_friends_status()


## Uma linha dizendo como estão os amigos agora.
func _update_friends_status() -> void:
	if _friends_status == null:
		return
	if not AppConfig.are_friends_enabled():
		_set_friends_status("Amigos desligados.", HINT_COLOR)
	elif AppConfig.get_web_api_key().is_empty():
		_set_friends_status("Sem chave: cole a sua acima e clique em Salvar.", HINT_COLOR)
	elif not FriendsService.get_problem().is_empty():
		_set_friends_status(FriendsService.get_problem().replace("\n", ". "), ERROR_COLOR)
	elif FriendsService.is_enabled():
		var online := FriendsService.get_online_friends().size()
		_set_friends_status("Conectado · %d amigo%s online" % [online, "" if online == 1 else "s"], OK_COLOR)
	else:
		_set_friends_status("Conectando…", HINT_COLOR)


func _set_friends_status(text: String, color: Color) -> void:
	_friends_status.text = text
	_friends_status.add_theme_color_override("font_color", color)


# --- Rodapé --------------------------------------------------------------------

func _build_bottom_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var resume := _button("Continuar", true)
	resume.pressed.connect(close)
	row.add_child(resume)
	row.add_child(GameScreen.make_key_cap("Esc"))
	row.add_child(_expander())
	var quit := _button("Sair do hub", false)
	quit.pressed.connect(HubWindow.quit_hub)
	row.add_child(quit)
	return row


# --- Preencher com os valores atuais -----------------------------------------------

func _refresh() -> void:
	_refreshing = true
	for bus in _volume_sliders:
		_volume_sliders[bus].value = roundf(AppConfig.get_volume(bus) * 100.0)
		_volume_values[bus].text = str(int(_volume_sliders[bus].value))
	_fullscreen_check.button_pressed = HubWindow.is_fullscreen()
	var quality := AppConfig.get_quality()
	_choose(_quality_buttons, quality)
	_quality_hint.text = GraphicsQuality.describe(quality)
	_choose(_time_buttons, AppConfig.get_time_of_day())
	_refresh_friends_fields()
	_update_friends_status()
	_refreshing = false


func _refresh_friends_fields() -> void:
	_friends_check.set_pressed_no_signal(AppConfig.are_friends_enabled())
	var has_key := not AppConfig.get_web_api_key().is_empty()
	# A chave salva NUNCA volta para a tela: o campo fica vazio e avisa.
	_key_field.text = ""
	_key_field.placeholder_text = "chave salva (deixe vazio para manter)" if has_key else "cole a chave aqui"
	_forget_key_button.visible = has_key
	_steam_id_field.text = AppConfig.get_steam_id_override()


# --- Peças de interface --------------------------------------------------------------

func _section(text: String) -> Label:
	return _label(text, _spaced_font(2), 14, HINT_COLOR)


## Linha "Nome ....... [controle]": o nome tem largura fixa.
func _row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _label(title, HubFonts.TEXT, 15, TEXT_COLOR)
	name_label.custom_minimum_size = Vector2(96.0, 0.0)
	row.add_child(name_label)
	return row


## Botões lado a lado em que só um fica escolhido (ex.: Leve | Média | Alta).
func _segmented(options: Array[Array], buttons: Dictionary[String, Button], on_choose: Callable) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var group := ButtonGroup.new()
	for option in options:
		var button := Button.new()
		button.text = option[1]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(button, false)
		var chosen := _box(TEXT_COLOR, 4, TEXT_COLOR, 1, Vector4(10, 5, 10, 6))
		button.add_theme_stylebox_override("pressed", chosen)
		button.add_theme_stylebox_override("hover_pressed", chosen)
		button.add_theme_color_override("font_pressed_color", Color("0B0D11"))
		button.add_theme_color_override("font_hover_pressed_color", Color("0B0D11"))
		var value: String = option[0]
		button.pressed.connect(func() -> void:
			if not _refreshing:
				on_choose.call(value))
		box.add_child(button)
		buttons[value] = button
	return box


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button, primary)
	return button


func _style_button(button: Button, primary: bool) -> void:
	var background := Color("E6E9EE") if primary else FIELD_COLOR
	var normal := _box(background, 4, TEXT_COLOR if primary else FIELD_BORDER, 1, Vector4(14, 6, 14, 7))
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color.WHITE if primary else Color("1F2228")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", HubFonts.TEXT)
	button.add_theme_font_size_override("font_size", 15)
	var font_color := Color("0B0D11") if primary else TEXT_COLOR
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, font_color)


func _field() -> LineEdit:
	var field := LineEdit.new()
	var normal := _box(FIELD_COLOR, 4, FIELD_BORDER, 1, Vector4(10, 6, 10, 6))
	var focused := normal.duplicate() as StyleBoxFlat
	focused.border_color = SECONDARY_COLOR
	field.add_theme_stylebox_override("normal", normal)
	field.add_theme_stylebox_override("focus", focused)
	field.add_theme_font_override("font", HubFonts.LIGHT)
	field.add_theme_font_size_override("font_size", 15)
	field.add_theme_color_override("font_color", TEXT_COLOR)
	field.add_theme_color_override("font_placeholder_color", HINT_COLOR)
	return field


func _style_slider(slider: HSlider) -> void:
	var track := _box(Color(1.0, 1.0, 1.0, 0.14), 2, Color.TRANSPARENT, 0, Vector4(0, 2, 0, 2))
	var filled := _box(TEXT_COLOR, 2, Color.TRANSPARENT, 0, Vector4(0, 2, 0, 2))
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Barlow Condensed com "extra" px entre as letras (títulos e seções).
func _spaced_font(extra: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = HubFonts.SIGN
	font.spacing_glyph = extra
	return font


func _line() -> ColorRect:
	var line := ColorRect.new()
	line.color = LINE_COLOR
	line.custom_minimum_size = Vector2(0.0, 1.0)
	return line


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer


func _expander() -> Control:
	var expander := Control.new()
	expander.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return expander


## Caixa com fundo, cantos, borda e margens (esquerda, topo, direita, baixo).
func _box(background: Color, radius: int, border: Color, border_width: int, margins: Vector4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	return box
