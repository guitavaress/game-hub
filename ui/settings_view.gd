class_name SettingsView
extends VBoxContainer
## As configurações do hub: três abas (Som e vídeo, Controles, Amigos) com os
## volumes, tela cheia, "Bússola e mapa", qualidade do 3D, hora da cidade, as
## teclas e a chave da Steam Web API. Cada mudança vale na hora e é gravada no
## config.cfg pelo AppConfig.
##
## É só a parte de dentro: quem decide onde ela aparece é quem a usa (hoje o
## menu de pausa; depois, a tela do computador da casa). Chame `refresh()` ao
## mostrar e `save_pending()` ao esconder. Montado por código.
##
## Cores, fontes e caixas vêm do tema do hub (HubTheme, Fase 12): aqui só se
## escolhe a variação de cada peça.

const API_KEY_URL: String = "https://steamcommunity.com/dev/apikey"
## Espera (s) depois de mexer num volume antes de gravar no arquivo.
const VOLUME_SAVE_DELAY: float = 0.4

const TAB_NAMES: Array[String] = ["Som e vídeo", "Controles", "Amigos"]
## [canal de áudio, nome na tela]
const VOLUME_ROWS: Array[Array] = [["Master", "Geral"], ["Efeitos", "Efeitos"], ["Ambiente", "Ambiente"], ["Música", "Música"]]
## [valor no config.cfg, nome na tela]
const QUALITY_OPTIONS: Array[Array] = [["leve", "Leve"], ["media", "Média"], ["alta", "Alta"]]
const TIME_OPTIONS: Array[Array] = [["relogio", "Relógio"], ["dia", "Dia"], ["noite", "Noite"]]
## [tecla, o que faz]
const CONTROL_ROWS: Array[Array] = [
	["WASD", "andar"],
	["Mouse", "olhar em volta"],
	["Shift", "correr"],
	["Espaço", "pular"],
	["E", "interagir (porta, estante, mural, computador)"],
	["Tab", "achar um jogo (acende o caminho até a porta)"],
	["M", "mapa da cidade (o minimapa fica no canto)"],
	["Shift+Enter", "na busca: ir direto até a porta (sem abrir o jogo)"],
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
## Canais mexidos que ainda esperam gravar (só estes vão para o arquivo).
var _changed_buses: Dictionary[String, bool] = {}
var _controls_changed: bool = false
var _fullscreen_check: CheckButton
var _map_check: CheckButton
var _motion_check: CheckButton
var _sensitivity_slider: HSlider
var _fov_slider: HSlider
var _sensitivity_value: Label
var _fov_value: Label
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
	# O tema vem junto: a tela fica certa sozinha (teste), no menu de pausa e
	# dentro da tela do computador.
	theme = HubTheme.get_theme()
	add_theme_constant_override("separation", 18)
	add_child(_build_tabs())

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(pages)
	for page in [_build_sound_page(), _build_controls_page(), _build_friends_page()]:
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages.add_child(page)
		_pages.append(page)

	_volume_save_timer = Timer.new()
	_volume_save_timer.one_shot = true
	_volume_save_timer.wait_time = VOLUME_SAVE_DELAY
	_volume_save_timer.timeout.connect(_save_volumes)
	add_child(_volume_save_timer)

	FriendsService.friends_changed.connect(_update_friends_status)
	FriendsService.problem.connect(_on_friends_problem)
	_show_page(0)


## Grava já o que ainda espera (volumes mexidos) e tira o foco dos campos.
func save_pending() -> void:
	_save_volumes()


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
		tab.theme_type_variation = &"HubTab"  # sublinhado claro na escolhida
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
		slider.value_changed.connect(_on_volume_changed.bind(bus))
		row.add_child(slider)
		var value := HubTheme.label("", &"HubValue")
		value.custom_minimum_size = Vector2(36.0, 0.0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		page.add_child(row)
		_volume_sliders[bus] = slider
		_volume_values[bus] = value

	page.add_child(HubTheme.spacer(6))
	page.add_child(_section("VÍDEO"))
	var fullscreen_row := _row("Tela cheia")
	fullscreen_row.add_child(HubTheme.expander())
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.focus_mode = Control.FOCUS_NONE
	_fullscreen_check.toggled.connect(func(on: bool) -> void:
		if not _refreshing:
			HubWindow.set_fullscreen(on))
	fullscreen_row.add_child(_fullscreen_check)
	page.add_child(fullscreen_row)

	var map_row := _row("Bússola e mapa")
	map_row.add_child(HubTheme.expander())
	_map_check = CheckButton.new()
	_map_check.focus_mode = Control.FOCUS_NONE
	_map_check.toggled.connect(func(on: bool) -> void:
		if not _refreshing:
			AppConfig.set_show_map(on))
	map_row.add_child(_map_check)
	page.add_child(map_row)

	var quality_row := _row("Qualidade")
	quality_row.add_child(_segmented(QUALITY_OPTIONS, _quality_buttons, _on_quality_chosen))
	page.add_child(quality_row)
	_quality_hint = HubTheme.label("", &"HubCaption")
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
	_changed_buses[bus] = true
	_volume_save_timer.start()                         # ...e grava daqui a pouco


## Grava no config.cfg os volumes mexidos (se algum foi mexido).
func _save_volumes() -> void:
	_volume_save_timer.stop()
	if _volumes_changed:
		_volumes_changed = false
		for bus in _changed_buses:
			AppConfig.set_volume(bus, _volume_sliders[bus].value / 100.0)
		_changed_buses.clear()
	if _controls_changed:
		_controls_changed = false
		AppConfig.set_mouse_sensitivity(_sensitivity_slider.value / 100.0)
		AppConfig.set_fov(_fov_slider.value)


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
		# A frase quebra a linha em vez de alargar o painel.
		var description := HubTheme.label(control_info[1], &"HubBodyLight")
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		page.add_child(row)
	page.add_child(HubTheme.spacer(6))
	page.add_child(_section("CÂMERA"))
	var motion_row := _row("Balanço da câmera")
	motion_row.add_child(HubTheme.expander())
	_motion_check = CheckButton.new()
	_motion_check.focus_mode = Control.FOCUS_NONE
	_motion_check.toggled.connect(func(on: bool) -> void:
		if not _refreshing:
			AppConfig.set_camera_motion(on))
	motion_row.add_child(_motion_check)
	page.add_child(motion_row)
	var motion_hint := HubTheme.label("Balança ao andar, afunda ao pousar e abre a visão correndo. Desligue se der enjoo.",
			&"HubCaption")
	motion_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(motion_hint)
	_sensitivity_slider = _controls_slider(page, "Sensibilidade do mouse",
			AppConfig.MOUSE_SENSITIVITY_RANGE * 100.0, 5.0, _on_sensitivity_changed)
	_sensitivity_value = _last_slider_value
	_fov_slider = _controls_slider(page, "Campo de visão",
			AppConfig.FOV_RANGE, 1.0, _on_fov_changed)
	_fov_value = _last_slider_value
	page.add_child(HubTheme.spacer(6))
	var tip := HubTheme.label("Na porta de um prédio, espere o anel encher para abrir o jogo; recue para cancelar.",
			&"HubCaption")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(tip)
	return page


## Uma linha "nome — deslizador — valor" da aba Controles.
var _last_slider_value: Label

func _controls_slider(page: Control, title: String, limits: Vector2, step: float, on_change: Callable) -> HSlider:
	var row := _row(title)
	var slider := HSlider.new()
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	_last_slider_value = HubTheme.label("", &"HubValue")
	_last_slider_value.custom_minimum_size = Vector2(48.0, 0.0)
	_last_slider_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_last_slider_value)
	page.add_child(row)
	return slider


func _on_sensitivity_changed(value: float) -> void:
	_sensitivity_value.text = "%.2f×" % (value / 100.0)
	if _refreshing:
		return
	AppConfig.set_mouse_sensitivity(value / 100.0, false)  # vale na hora...
	_controls_changed = true
	_volume_save_timer.start()                               # ...e grava daqui a pouco


func _on_fov_changed(value: float) -> void:
	_fov_value.text = "%d°" % int(value)
	if _refreshing:
		return
	AppConfig.set_fov(value, false)
	_controls_changed = true
	_volume_save_timer.start()


# --- Amigos --------------------------------------------------------------------

func _build_friends_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	var intro := HubTheme.label("Com a chave da Steam Web API, seus amigos aparecem na cidade: na porta "
			+ "do jogo que estão jogando, ou na praça.", &"HubBodyLight")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(intro)

	var toggle_row := _row("Mostrar amigos")
	toggle_row.add_child(HubTheme.expander())
	_friends_check = CheckButton.new()
	_friends_check.focus_mode = Control.FOCUS_NONE
	_friends_check.toggled.connect(_on_friends_toggled)
	toggle_row.add_child(_friends_check)
	page.add_child(toggle_row)

	page.add_child(HubTheme.label("Chave da Steam Web API"))
	_key_field = LineEdit.new()
	_key_field.secret = true  # é segredo: aparece como bolinhas
	page.add_child(_key_field)
	var link := LinkButton.new()
	link.text = "Pegar uma chave: steamcommunity.com/dev/apikey"
	link.focus_mode = Control.FOCUS_NONE
	link.pressed.connect(func() -> void: OS.shell_open(API_KEY_URL))
	page.add_child(link)
	var secret_hint := HubTheme.label("É segredo: fica só neste PC. No site, em \"domínio\", escreva localhost.",
			&"HubCaption")
	secret_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(secret_hint)

	page.add_child(HubTheme.spacer(4))
	page.add_child(HubTheme.label("ID Steam (opcional)"))
	_steam_id_field = LineEdit.new()
	_steam_id_field.placeholder_text = "vazio = descobrir sozinho pela Steam"
	page.add_child(_steam_id_field)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var save := HubTheme.button("Salvar e conectar", true)
	save.pressed.connect(_save_friends)
	buttons.add_child(save)
	_forget_key_button = HubTheme.button("Apagar chave")
	_forget_key_button.pressed.connect(_forget_key)
	buttons.add_child(_forget_key_button)
	page.add_child(buttons)

	_friends_status = HubTheme.label("", &"HubCaption")
	_friends_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_friends_status)
	return page


func _save_friends() -> void:
	var key := _key_field.text.strip_edges()
	if key.is_empty():
		key = AppConfig.get_web_api_key()  # campo vazio = manter a chave salva
	elif not (key.length() == 32 and key.is_valid_hex_number()):
		_set_friends_status("A chave tem 32 letras e números (0-9 e A-F). Confira e cole de novo.", &"HubStatusError")
		return
	var steam_id := _steam_id_field.text.strip_edges()
	if not steam_id.is_empty() and not (steam_id.length() == 17 and steam_id.is_valid_int()):
		_set_friends_status("O ID Steam tem 17 números (ex.: 7656119…). Ou deixe vazio.", &"HubStatusError")
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
		_set_friends_status("Amigos desligados.", &"HubCaption")
	elif AppConfig.get_web_api_key().is_empty():
		_set_friends_status("Sem chave: cole a sua acima e clique em Salvar.", &"HubCaption")
	elif not FriendsService.get_problem().is_empty():
		_set_friends_status(FriendsService.get_problem().replace("\n", ". "), &"HubStatusError")
	elif FriendsService.is_enabled():
		var online := FriendsService.get_online_friends().size()
		_set_friends_status("Conectado · %d amigo%s online" % [online, "" if online == 1 else "s"], &"HubStatusOk")
	else:
		_set_friends_status("Conectando…", &"HubCaption")


## "variation": HubCaption (neutro), HubStatusOk ou HubStatusError.
func _set_friends_status(text: String, variation: StringName) -> void:
	_friends_status.text = text
	_friends_status.theme_type_variation = variation


# --- Preencher com os valores atuais -----------------------------------------------

func refresh() -> void:
	_refreshing = true
	for bus in _volume_sliders:
		_volume_sliders[bus].value = roundf(AppConfig.get_volume(bus) * 100.0)
		_volume_values[bus].text = str(int(_volume_sliders[bus].value))
	_fullscreen_check.button_pressed = HubWindow.is_fullscreen()
	_map_check.button_pressed = AppConfig.get_show_map()
	_motion_check.button_pressed = AppConfig.get_camera_motion()
	_sensitivity_slider.value = roundf(AppConfig.get_mouse_sensitivity() * 100.0)
	_fov_slider.value = AppConfig.get_fov()
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
	return HubTheme.label(text, &"HubSection")


## Linha "Nome ....... [controle]": o nome tem largura fixa.
func _row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := HubTheme.label(title)
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
		button.theme_type_variation = &"HubSegment"  # o escolhido fica claro
		var value: String = option[0]
		button.pressed.connect(func() -> void:
			if not _refreshing:
				on_choose.call(value))
		box.add_child(button)
		buttons[value] = button
	return box
