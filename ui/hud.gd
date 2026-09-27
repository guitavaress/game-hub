class_name Hud
extends CanvasLayer
## HUD mínimo e discreto, montado por código:
## - mira no centro da tela;
## - CARTÃO na parte de baixo com o que o jogador está olhando: o nome em
##   destaque e os detalhes numa segunda linha ("23 h jogadas · jogado ontem");
## - AVISOS no topo (Toast): título + frase de ação, com uma barrinha de cor
##   (amarela = info, vermelha = erro, verde = sessão). Até 3 empilhados; um
##   quarto aviso tira o mais antigo. Somem sozinhos.
## A fonte (Barlow) vem do tema do projeto (project.godot).
##
## Os sistemas mandam avisos como um texto só; a PRIMEIRA LINHA vira o título
## e o resto vira a frase ("Balatro não abriu\nAbra a Steam e entre de novo.").

const TITLE_FONT_SIZE: int = 26
const DETAIL_FONT_SIZE: int = 17
const PANEL_COLOR: Color = Color(0.035, 0.04, 0.05, 0.74)
const DETAIL_COLOR: Color = Color(0.72, 0.75, 0.8)
const MAX_TOASTS: int = 3
const TOASTS_TOP: float = 12.0
const TOASTS_GAP: int = 8

## Sons (Kenney, CC0).
const MESSAGE_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/glass_001.ogg")
const ERROR_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/error_004.ogg")
const WELCOME_BACK_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/confirmation_002.ogg")

var _look_card: PanelContainer
var _look_title: Label
var _look_detail: Label
var _toasts: VBoxContainer
var _sound: AudioStreamPlayer

## Avisos que só aparecem uma vez enquanto o hub estiver aberto (ex.: amigos).
## "static": vale para todos os HUDs, mesmo se o mundo for recriado.
static var _shown_once: Dictionary[String, bool] = {}


func _ready() -> void:
	_build_crosshair()
	_build_look_card()
	_build_toasts()

	_sound = AudioStreamPlayer.new()
	_sound.bus = &"Efeitos"
	_sound.volume_db = -10.0
	add_child(_sound)

	# O HUD escuta os sistemas para avisar quando algo dá errado.
	GameLauncher.session_ended.connect(_on_session_ended)
	HubWindow.woke_up.connect(_play_sound.bind(WELCOME_BACK_SOUND))
	# Avisos de amigos: cada um aparece uma vez só por execução do hub.
	FriendsService.problem.connect(show_report_once)
	if not FriendsService.get_problem().is_empty():
		show_report_once(FriendsService.get_problem())  # aviso de antes do HUD existir

	if Engine.is_embedded_in_editor():
		show_message("O hub está rodando dentro do editor",
				"Ele não vai minimizar. Desative \"Embed Game on Next Play\" na aba Game.",
				Toast.Kind.INFO, 12.0)


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


## Mostra um aviso no topo: "title" (o que houve) e "text" (o que fazer).
## "seconds" < 0 usa o tempo do tipo (info 6 s, erro 10 s, sessão 5 s).
## Um aviso igual a outro que já está na tela é ignorado.
func show_message(title: String, text: String = "", kind: Toast.Kind = Toast.Kind.INFO,
		seconds: float = -1.0) -> void:
	if title.is_empty():
		return
	var showing := _visible_toasts()
	for toast in showing:
		if toast.title == title and toast.text == text:
			return
	# Cabem 3: o mais antigo sai para dar lugar ao novo.
	for i in showing.size() - MAX_TOASTS + 1:
		showing[i].close()

	_toasts.add_child(Toast.create(title, text, kind, seconds))
	match kind:
		Toast.Kind.ERROR:
			_play_sound(ERROR_SOUND)
		Toast.Kind.INFO:
			if not _sound.playing:  # não atropela a vinheta nem o som de erro
				_play_sound(MESSAGE_SOUND)


## Aviso num texto só: a primeira linha vira o título, o resto vira a frase.
func show_report(message: String, kind: Toast.Kind = Toast.Kind.INFO, seconds: float = -1.0) -> void:
	var parts := message.strip_edges().split("\n", true, 1)
	show_message(parts[0], parts[1] if parts.size() > 1 else "", kind, seconds)


## Como show_report, mas o mesmo aviso só aparece uma vez por execução do hub.
func show_report_once(message: String, kind: Toast.Kind = Toast.Kind.INFO) -> void:
	if message.is_empty() or _shown_once.has(message):
		return
	_shown_once[message] = true
	show_report(message, kind)


## Os avisos na tela, do mais antigo para o mais novo ("título — frase").
func get_messages() -> PackedStringArray:
	var result := PackedStringArray()
	for toast in _visible_toasts():
		result.append(toast.title if toast.text.is_empty() else "%s — %s" % [toast.title, toast.text])
	return result


## Tira todos os avisos da tela na hora (usado nos prints de teste).
func clear_messages() -> void:
	for toast in _toasts.get_children():
		_toasts.remove_child(toast)
		toast.queue_free()


func _visible_toasts() -> Array[Toast]:
	var result: Array[Toast] = []
	for child in _toasts.get_children():
		var toast := child as Toast
		if toast != null and not toast.is_closing():
			result.append(toast)
	return result


func _on_session_ended(_app_id: int, _source: Node, success: bool, message: String) -> void:
	if not success and not message.is_empty():
		show_report(message, Toast.Kind.ERROR)


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


## Pilha de avisos no topo, centralizada, 500 px de largura.
func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", TOASTS_GAP)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_left = -Toast.WIDTH / 2.0
	_toasts.offset_right = Toast.WIDTH / 2.0
	_toasts.offset_top = TOASTS_TOP
	add_child(_toasts)


func _make_panel_style(left_border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 10.0
	style.border_width_left = left_border
	return style


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
