class_name Hud
extends CanvasLayer
## HUD mínimo e discreto, montado por código:
## - mira no centro da tela;
## - CARTÃO na parte de baixo com o que o jogador está olhando: o nome em
##   destaque e os detalhes numa segunda linha ("23 h jogadas · jogado ontem");
## - AVISOS no topo, num painel escuro com uma barrinha de cor (amarela = info,
##   vermelha = erro), que somem sozinhos (vários avisos entram numa fila).
## A fonte (Barlow) vem do tema do projeto (project.godot).

const MESSAGE_SECONDS: float = 6.0
const TITLE_FONT_SIZE: int = 26
const DETAIL_FONT_SIZE: int = 17
const MESSAGE_FONT_SIZE: int = 18
const PANEL_COLOR: Color = Color(0.035, 0.04, 0.05, 0.74)
const INFO_ACCENT: Color = Color("f2c14e")
const ERROR_ACCENT: Color = Color("e5534b")
const DETAIL_COLOR: Color = Color(0.72, 0.75, 0.8)

## Sons (Kenney, CC0).
const MESSAGE_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/glass_001.ogg")
const ERROR_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/error_004.ogg")
const WELCOME_BACK_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/confirmation_002.ogg")

var _look_card: PanelContainer
var _look_title: Label
var _look_detail: Label
var _message_panel: PanelContainer
var _message_style: StyleBoxFlat
var _message_label: Label
var _message_timer: Timer
## Avisos esperando a vez: [texto, segundos, é_erro].
var _message_queue: Array[Array] = []
var _sound: AudioStreamPlayer


func _ready() -> void:
	_build_crosshair()
	_build_look_card()
	_build_message_panel()

	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(_show_next_message)
	add_child(_message_timer)

	_sound = AudioStreamPlayer.new()
	_sound.bus = &"Efeitos"
	_sound.volume_db = -10.0
	add_child(_sound)

	# O HUD escuta os sistemas para avisar quando algo dá errado.
	GameLauncher.session_ended.connect(_on_session_ended)
	HubWindow.woke_up.connect(_play_sound.bind(WELCOME_BACK_SOUND))
	FriendsService.problem.connect(show_message)
	if not FriendsService.get_problem().is_empty():
		show_message(FriendsService.get_problem())  # aviso de antes do HUD existir

	if Engine.is_embedded_in_editor():
		show_message("O jogo está rodando DENTRO do editor: o hub não vai minimizar. "
				+ "Desative \"Embed Game on Next Play\" na aba Game.", 12.0)


## Mostra (ou esconde, com "") o que o jogador está olhando.
## "Balatro — 23 h jogadas · jogado ontem" vira título + detalhes.
func set_look_text(text: String) -> void:
	var parts := text.split(" — ", true, 1)
	_look_title.text = parts[0]
	_look_detail.text = parts[1] if parts.size() > 1 else ""
	_look_detail.visible = not _look_detail.text.is_empty()
	_look_card.visible = not text.is_empty()


## O texto completo do que está sendo olhado (o mesmo que set_look_text recebeu).
func get_look_text() -> String:
	if not _look_card.visible:
		return ""
	return _look_title.text if _look_detail.text.is_empty() else "%s — %s" % [_look_title.text, _look_detail.text]


## Mostra um aviso no topo da tela por alguns segundos. Se já houver um aviso
## na tela, este espera a vez. Avisos repetidos são ignorados.
func show_message(text: String, seconds: float = MESSAGE_SECONDS, is_error: bool = false) -> void:
	if text.is_empty() or text == _message_label.text:
		return
	for queued in _message_queue:
		if queued[0] == text:
			return
	if _message_label.text.is_empty():
		_message_label.text = text
		_message_style.border_color = ERROR_ACCENT if is_error else INFO_ACCENT
		_message_panel.visible = true
		_message_timer.start(seconds)
		if not _sound.playing:  # não atropela a vinheta nem o som de erro
			_play_sound(MESSAGE_SOUND)
	else:
		_message_queue.append([text, seconds, is_error])


func _show_next_message() -> void:
	_message_label.text = ""
	_message_panel.visible = false
	if not _message_queue.is_empty():
		var next: Array = _message_queue.pop_front()
		show_message(next[0], next[1], next[2])


func _on_session_ended(_app_id: int, _source: Node, success: bool, message: String) -> void:
	if not success and not message.is_empty():
		_play_sound(ERROR_SOUND)
		show_message(message, MESSAGE_SECONDS, true)


func _play_sound(stream: AudioStream) -> void:
	_sound.stream = stream
	_sound.play()


# --- Montagem ----------------------------------------------------------------

func _build_crosshair() -> void:
	# Um pontinho branco com borda escura, bem no centro.
	var border := ColorRect.new()
	border.color = Color(0.0, 0.0, 0.0, 0.55)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	border.offset_left = -2.5
	border.offset_top = -2.5
	border.offset_right = 2.5
	border.offset_bottom = 2.5
	add_child(border)

	var dot := ColorRect.new()
	dot.color = Color(1.0, 1.0, 1.0, 0.9)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.position = Vector2(1.0, 1.0)
	dot.size = Vector2(3.0, 3.0)
	border.add_child(dot)


## Cartão de baixo: título (nome) e detalhes, num painel escuro arredondado.
func _build_look_card() -> void:
	_look_card = PanelContainer.new()
	_look_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look_card.add_theme_stylebox_override("panel", _make_panel_style(0))
	_look_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_look_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_look_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_look_card.offset_bottom = -48.0
	_look_card.visible = false
	add_child(_look_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look_card.add_child(column)
	_look_title = _make_label(TITLE_FONT_SIZE, Color(0.97, 0.97, 0.98))
	column.add_child(_look_title)
	_look_detail = _make_label(DETAIL_FONT_SIZE, DETAIL_COLOR)
	column.add_child(_look_detail)


## Painel de avisos no topo, com uma barrinha colorida à esquerda.
func _build_message_panel() -> void:
	_message_panel = PanelContainer.new()
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_style = _make_panel_style(4)
	_message_panel.add_theme_stylebox_override("panel", _message_style)
	_message_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_panel.offset_top = 24.0
	_message_panel.custom_minimum_size = Vector2(0.0, 0.0)
	_message_panel.visible = false
	add_child(_message_panel)

	_message_label = _make_label(MESSAGE_FONT_SIZE, Color(0.94, 0.95, 0.97))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size = Vector2(520.0, 0.0)
	_message_panel.add_child(_message_label)


func _make_panel_style(left_border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 10.0
	style.border_width_left = left_border
	style.border_color = INFO_ACCENT
	return style


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
