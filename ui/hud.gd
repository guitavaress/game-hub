class_name Hud
extends CanvasLayer
## HUD mínimo e discreto, montado por código:
## - mira no centro da tela: um ponto, que vira um anel de 12 px na cor do
##   bairro quando olhamos para um jogo;
## - CARTÃO na parte de baixo com o que o jogador está olhando: a categoria
##   ("CARTAS E TABULEIRO", na cor néon), o nome em destaque, os detalhes
##   ("23 h jogadas · jogado ontem") e os amigos jogando ("● Ana jogando agora").
##   Um clique suave toca quando o alvo muda;
## - AVISOS no topo (Toast): título + frase de ação, com uma barrinha de cor
##   (amarela = info, vermelha = erro, verde = sessão). Até 3 empilhados; um
##   quarto aviso tira o mais antigo. Somem sozinhos.
## A fonte (Barlow) vem do tema do projeto (project.godot).
##
## Os sistemas mandam avisos como um texto só; a PRIMEIRA LINHA vira o título
## e o resto vira a frase ("Balatro não abriu\nAbra a Steam e entre de novo.").

const LABEL_FONT_SIZE: int = 14
const TITLE_FONT_SIZE: int = 26
const DETAIL_FONT_SIZE: int = 17
const FRIENDS_FONT_SIZE: int = 15
const PANEL_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.78)
const DETAIL_COLOR: Color = Color("B8BFCC")
const FRIENDS_COLOR: Color = Color("5FE3A1")
const RING_SIZE: float = 12.0
const MAX_TOASTS: int = 3
## O aviso de volta do jogo fica pelo menos isto (s) antes de sumir ao andar.
const SESSION_MIN_SECONDS: float = 1.5
const TOASTS_TOP: float = 12.0
const TOASTS_GAP: int = 8

## Sons (Kenney, CC0).
const MESSAGE_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/glass_001.ogg")
const ERROR_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/error_004.ogg")
const WELCOME_BACK_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/confirmation_002.ogg")
const LOOK_CLICK_SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/click_002.ogg")

var _crosshair_dot: Control
var _crosshair_ring: Ring
var _look_card: PanelContainer
var _look_label: Label
var _look_title: Label
var _look_detail: Label
var _look_friends: Label
var _toasts: VBoxContainer
## Avisos que chegaram com o HUD escondido: [título, frase, tipo, segundos, rótulo].
var _waiting_messages: Array[Array] = []
var _sound: AudioStreamPlayer
var _click: AudioStreamPlayer

## Avisos que só aparecem uma vez enquanto o hub estiver aberto (ex.: amigos).
## "static": vale para todos os HUDs, mesmo se o mundo for recriado.
static var _shown_once: Dictionary[String, bool] = {}


func _ready() -> void:
	_build_crosshair()
	_build_look_card()
	_build_toasts()
	visibility_changed.connect(_show_waiting_messages)

	_sound = AudioStreamPlayer.new()
	_sound.bus = &"Efeitos"
	_sound.volume_db = -10.0
	add_child(_sound)
	# Player separado: o clique de "olhar" não corta os outros sons.
	_click = AudioStreamPlayer.new()
	_click.stream = LOOK_CLICK_SOUND
	_click.bus = &"Efeitos"
	_click.volume_db = -20.0
	add_child(_click)

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


## Mostra (ou esconde, com {}) o que o jogador está olhando. Chaves (todas
## opcionais menos "title"): label, label_color, title, detail, friends, accent.
func set_look_info(info: Dictionary) -> void:
	var title: String = info.get("title", "")
	if not title.is_empty() and title != _look_title.text:
		_click.play()  # o alvo mudou
	_look_title.text = title
	_set_line(_look_label, str(info.get("label", "")))
	_look_label.add_theme_color_override("font_color", info.get("label_color", DETAIL_COLOR))
	_set_line(_look_detail, str(info.get("detail", "")))
	var friends := str(info.get("friends", ""))
	_set_line(_look_friends, "●  " + friends if not friends.is_empty() else "")
	_look_card.visible = not title.is_empty()

	# Mira: anel na cor do alvo (se ele tiver uma), senão o pontinho.
	var has_accent := info.has("accent") and not title.is_empty()
	_crosshair_ring.visible = has_accent
	_crosshair_dot.visible = not has_accent
	if has_accent:
		_crosshair_ring.color = info["accent"]
		_crosshair_ring.queue_redraw()


## Versão só com texto: "Balatro — 23 h jogadas · jogado ontem" vira título +
## detalhes.
func set_look_text(text: String) -> void:
	var parts := text.split(" — ", true, 1)
	set_look_info({} if text.is_empty() else
			{"title": parts[0], "detail": parts[1] if parts.size() > 1 else ""})


## As linhas extras do cartão (rótulo do bairro e amigos) sobre o que se olha.
func get_look_extras() -> PackedStringArray:
	return PackedStringArray([_look_label.text, _look_friends.text])


func is_crosshair_ring() -> bool:
	return _crosshair_ring.visible


func _set_line(label: Label, text: String) -> void:
	label.text = text
	label.visible = not text.is_empty()


## O texto completo do que está sendo olhado (o mesmo que set_look_text recebeu).
func get_look_text() -> String:
	if not _look_card.visible:
		return ""
	return _look_title.text if _look_detail.text.is_empty() else "%s — %s" % [_look_title.text, _look_detail.text]


## Mostra um aviso no topo: "title" (o que houve) e "text" (o que fazer).
## "seconds" < 0 usa o tempo do tipo (info 6 s, erro 10 s, sessão 5 s).
## "overline" é um rótulo pequeno opcional acima do título.
## Um aviso igual a outro que já está na tela é ignorado.
func show_message(title: String, text: String = "", kind: Toast.Kind = Toast.Kind.INFO,
		seconds: float = -1.0, overline: String = "") -> void:
	if title.is_empty():
		return
	# HUD escondido (abertura): o aviso espera o HUD aparecer, senão o tempo
	# dele passaria sem ninguém ver.
	if not visible:
		for waiting in _waiting_messages:
			if waiting[0] == title and waiting[1] == text:
				return
		_waiting_messages.append([title, text, kind, seconds, overline])
		return
	var showing := _visible_toasts()
	for toast in showing:
		if toast.title == title and toast.text == text:
			return
	# Cabem 3: o mais antigo sai para dar lugar ao novo.
	for i in showing.size() - MAX_TOASTS + 1:
		showing[i].close()

	_toasts.add_child(Toast.create(title, text, kind, seconds, overline))
	match kind:
		Toast.Kind.ERROR:
			_play_sound(ERROR_SOUND)
		Toast.Kind.INFO:
			if not _sound.playing:  # não atropela a vinheta nem o som de erro
				_play_sound(MESSAGE_SOUND)


## O HUD apareceu: mostra os avisos que estavam esperando.
func _show_waiting_messages() -> void:
	if not visible:
		return
	var waiting := _waiting_messages.duplicate()
	_waiting_messages.clear()
	for message in waiting:
		show_message(message[0], message[1], message[2], message[3], message[4])


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


func _on_session_ended(app_id: int, _source: Node, success: bool, message: String) -> void:
	if not success and not message.is_empty():
		show_report(message, Toast.Kind.ERROR)
	elif success and not HubWindow.is_sleeping:
		# Voltou de um jogo (na troca direta de jogo o hub continua dormindo).
		_show_session_summary(app_id)


## Aviso verde da volta: "BEM-VINDO DE VOLTA · 1 h 12 min de Balatro ·
## 24 h no total · Bruno ainda está jogando".
func _show_session_summary(app_id: int) -> void:
	var session := GameLauncher.get_last_session()
	if int(session.get("app_id", 0)) != app_id or float(session.get("seconds", 0.0)) <= 0.0:
		return
	var minutes := maxi(1, roundi(float(session["seconds"]) / 60.0))
	var title := "%s de %s" % [format_duration(minutes), SteamLibrary.get_game_name(app_id)]
	# A Steam às vezes demora para gravar o total novo: no mínimo, o de antes
	# mais esta sessão.
	var total := maxi(SteamLibrary.get_playtime_minutes(app_id), int(session.get("playtime_before", 0)) + minutes)
	var parts := PackedStringArray(["%s no total" % format_duration(total, true)])
	var friends := FriendsService.get_friends_playing(app_id)
	if not friends.is_empty():
		parts.append(SteamFriend.join_names(friends)
				+ (" ainda estão jogando" if friends.size() > 1 else " ainda está jogando"))
	show_message(title, " · ".join(parts), Toast.Kind.SESSION, -1.0, "BEM-VINDO DE VOLTA")


## "12 min", "1 h 12 min", "2 h" (only_hours: "24 h" a partir de 1 hora).
static func format_duration(minutes: int, only_hours: bool = false) -> String:
	if minutes < 60:
		return "%d min" % minutes
	var hours := floori(minutes / 60.0)
	var rest := minutes - hours * 60
	if only_hours or rest == 0:
		return "%d h" % hours
	return "%d h %d min" % [hours, rest]


## O jogador começou a andar: o aviso de volta do jogo já cumpriu o papel e
## sai (se já ficou pelo menos um pouco na tela).
func on_player_moved() -> void:
	for toast in _visible_toasts():
		if toast.kind == Toast.Kind.SESSION and toast.get_age() > SESSION_MIN_SECONDS:
			toast.close()


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
	_crosshair_dot = border

	var dot := ColorRect.new()
	dot.color = Color(1.0, 1.0, 1.0, 0.9)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.position = Vector2(1.0, 1.0)
	dot.size = Vector2(3.0, 3.0)
	border.add_child(dot)

	# O anel (aparece no lugar do ponto quando olhamos para um jogo).
	_crosshair_ring = Ring.new()
	_crosshair_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair_ring.offset_left = -RING_SIZE / 2.0
	_crosshair_ring.offset_top = -RING_SIZE / 2.0
	_crosshair_ring.offset_right = RING_SIZE / 2.0
	_crosshair_ring.offset_bottom = RING_SIZE / 2.0
	_crosshair_ring.visible = false
	add_child(_crosshair_ring)


## Cartão de baixo: categoria, nome, detalhes e amigos, num painel escuro.
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

	# Rótulo da categoria: Barlow Condensed com 2 px a mais entre as letras.
	var spaced := FontVariation.new()
	spaced.base_font = HubFonts.SIGN
	spaced.spacing_glyph = 2
	_look_label = _make_label(LABEL_FONT_SIZE, DETAIL_COLOR, spaced)
	column.add_child(_look_label)
	_look_title = _make_label(TITLE_FONT_SIZE, Color(0.97, 0.97, 0.98), HubFonts.TEXT)
	column.add_child(_look_title)
	_look_detail = _make_label(DETAIL_FONT_SIZE, DETAIL_COLOR, HubFonts.LIGHT)
	column.add_child(_look_detail)
	_look_friends = _make_label(FRIENDS_FONT_SIZE, FRIENDS_COLOR, HubFonts.LIGHT)
	column.add_child(_look_friends)


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
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 12.0
	style.border_width_left = left_border
	return style


func _make_label(font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Anel da mira: um círculo vazado com contorno escuro (aparece em qualquer fundo).
class Ring:
	extends Control

	var color: Color = Color.WHITE

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 1.0
		draw_arc(center, radius, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 0.5), 3.5, true)
		draw_arc(center, radius, 0.0, TAU, 32, color, 2.0, true)
