class_name GameScreen
extends Control
## Tela de um jogo, mostrada por cima de tudo (dentro da "cortina" do ScreenFade)
## enquanto o hub está "dormindo". Dois modos:
##
##   ABRINDO:  o hero do jogo no topo, fundindo no preto, o logo sobre a emenda,
##             um anel girando com "Abrindo pela Steam…" e a tecla Esc.
##             Centralizado.
##   JOGANDO:  hero desfocada ao fundo, "● JOGANDO AGORA", o nome, o tempo desta
##             sessão e o total, e os amigos jogando o mesmo jogo. Alinhado à
##             esquerda (fica claro que é outro estado). Jogo aberto por fora do
##             hub: o rótulo diz "● ABRIU PELA STEAM" nos primeiros segundos.
##
## Arte: hero (1920x620) e logo da Steam, via GameArt. Sem hero: fundo escuro
## e um filete na cor do bairro. Sem logo: o nome em Barlow Condensed.
## Tudo é montado por código; medidas pensadas para 1280x720 (escala junto).

const BACKGROUND: Color = Color("08090C")
const TEXT_SECONDARY: Color = Color("B8BFCC")
const TEXT_HINT: Color = Color("8A92A0")
const SESSION_GREEN: Color = Color("5FE3A1")
## O hero ocupa a largura toda: 1280 x 413 em 1280x720 (proporção de 1920x620).
const HERO_HEIGHT_FRACTION: float = 413.0 / 720.0
const LOGO_MAX_SIZE: Vector2 = Vector2(480.0, 170.0)
const PLAYING_MARGIN: float = 96.0
const AVATAR_SIZE: float = 26.0
## Desfoque do hero: reduz até ~esta largura e amplia de volta até ~esta outra.
const BLUR_SMALL_WIDTH: int = 60
const BLUR_BIG_WIDTH: int = 480

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

# Modo JOGANDO
var _playing: Control
var _blurred_hero: TextureRect
var _playing_tag: Label
var _playing_name: Label
var _session_time: Label
var _total_time: Label
var _friends_row: HBoxContainer
var _friends_label: Label
var _clock: Timer
## Heros desfocados já feitos (app_id -> textura): o desfoque é feito uma vez só.
var _blur_cache: Dictionary[int, Texture2D] = {}


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
	_build_playing()

	# Filete na cor do bairro, na borda de baixo: liga a tela à cidade.
	_accent_line = ColorRect.new()
	_accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_anchors(_accent_line, 0.0, 1.0, 1.0, 1.0)
	_accent_line.offset_top = -3.0
	add_child(_accent_line)

	_clock = Timer.new()
	_clock.wait_time = 1.0
	_clock.timeout.connect(_update_playing_texts)
	add_child(_clock)

	# Um amigo entrou ou saiu do jogo enquanto a tela "Jogando" aparece.
	FriendsService.friends_changed.connect(func() -> void:
		if get_mode() == "jogando":
			_fill_friends(_app_id))


## Mostra a tela "Abrindo X…" desse jogo.
func show_opening(app_id: int) -> void:
	_app_id = app_id
	_mode = "abrindo"
	_fill_common(app_id)
	_status_label.text = "Abrindo a Steam…" if GameLauncher.steam_was_closed else "Abrindo pela Steam…"
	_opening.visible = true
	_playing.visible = false
	_clock.stop()
	visible = true


## Mostra a tela "Jogando X…" desse jogo (o tempo da sessão atualiza sozinho).
func show_playing(app_id: int) -> void:
	_app_id = app_id
	_mode = "jogando"
	_fill_common(app_id)
	_blurred_hero.texture = _blurred(app_id)
	_blurred_hero.visible = _blurred_hero.texture != null
	_playing_name.text = SteamLibrary.get_game_name(app_id).to_upper()
	_fill_friends(app_id)
	_update_playing_texts()
	_opening.visible = false
	_playing.visible = true
	_clock.start()
	visible = true


func get_mode() -> String:
	return _mode if visible else ""


## O nome do jogo que a tela está mostrando.
func get_title() -> String:
	return _playing_name.text if _mode == "jogando" else _name_label.text


## O texto de estado ("Abrindo pela Steam…" ou "● JOGANDO AGORA").
func get_status() -> String:
	return _playing_tag.text if _mode == "jogando" else _status_label.text


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


func _update_playing_texts() -> void:
	if _mode != "jogando":
		return
	var seconds := GameLauncher.get_session_seconds()
	# Jogo aberto por fora: nos primeiros segundos, avisa que foi pela Steam.
	var just_opened_outside := GameLauncher.is_external_session() \
			and seconds < GameLauncher.EXTERNAL_NOTICE_SECONDS + 0.5
	_playing_tag.text = "●  ABRIU PELA STEAM" if just_opened_outside else "●  JOGANDO AGORA"
	_session_time.text = "%d:%02d:%02d" % [floori(seconds / 3600.0), floori(seconds / 60.0) % 60, floori(seconds) % 60]
	var minutes := SteamLibrary.get_playtime_minutes(_app_id)
	_total_time.text = "%d h" % floori(minutes / 60.0) if minutes >= 60 else "%d min" % maxi(minutes, 0)


func _fill_friends(app_id: int) -> void:
	for child in _friends_row.get_children():
		if child != _friends_label:
			_friends_row.remove_child(child)
			child.queue_free()
	var friends := FriendsService.get_friends_playing(app_id)
	_friends_row.visible = not friends.is_empty()
	if friends.is_empty():
		return
	for friend in friends.slice(0, 5):
		var avatar := TextureRect.new()
		avatar.texture = FriendsService.get_avatar(friend)
		avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_friends_row.add_child(avatar)
		_friends_row.move_child(avatar, _friends_row.get_child_count() - 2)
	_friends_label.text = SteamFriend.join_names(friends) \
			+ (" também estão jogando" if friends.size() > 1 else " também está jogando")


## Hero bem desfocado, feito uma vez por jogo: reduz pela metade até ficar
## pequeno (cada redução tira a média de 4 pixels) e amplia de volta em passos
## de 2x com interpolação cúbica. Ampliar tudo de uma vez deixaria "degraus".
func _blurred(app_id: int) -> Texture2D:
	if _blur_cache.has(app_id):
		return _blur_cache[app_id]
	var hero := GameArt.get_hero(app_id)
	if hero == null:
		return null
	var image := hero.get_image().duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	while image.get_width() > BLUR_SMALL_WIDTH:
		image.resize(maxi(1, floori(image.get_width() / 2.0)), maxi(1, floori(image.get_height() / 2.0)),
				Image.INTERPOLATE_BILINEAR)
	while image.get_width() < BLUR_BIG_WIDTH:
		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_CUBIC)
	var texture := ImageTexture.create_from_image(image)
	_blur_cache[app_id] = texture
	return texture


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


func _build_playing() -> void:
	_playing = Control.new()
	_playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_playing)

	# Hero desfocada (50%) ao fundo + degradê escuro da esquerda para a direita.
	_blurred_hero = TextureRect.new()
	_blurred_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_blurred_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_blurred_hero.modulate = Color(1.0, 1.0, 1.0, 0.5)
	_blurred_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blurred_hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_playing.add_child(_blurred_hero)
	var shade := TextureRect.new()
	shade.texture = _gradient(Vector2(1.0, 0.0), Vector2(0.0, 0.0), 0.0, 0.95)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_playing.add_child(shade)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = PLAYING_MARGIN
	column.offset_right = -PLAYING_MARGIN
	_playing.add_child(column)

	# Rótulo: Barlow Condensed com 2 px a mais entre as letras.
	var spaced := FontVariation.new()
	spaced.base_font = HubFonts.SIGN
	spaced.spacing_glyph = 2
	_playing_tag = _make_label(spaced, 15, SESSION_GREEN)
	_playing_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_playing_tag)
	_playing_name = _make_label(HubFonts.SIGN, 72, Color.WHITE)
	_playing_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_playing_name)

	var numbers := HBoxContainer.new()
	numbers.add_theme_constant_override("separation", 48)
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(numbers)
	_session_time = _add_number(numbers, "nesta sessão")
	_total_time = _add_number(numbers, "no total")

	_friends_row = HBoxContainer.new()
	_friends_row.add_theme_constant_override("separation", 6)
	_friends_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_friends_row)
	_friends_label = _make_label(HubFonts.LIGHT, 15, TEXT_SECONDARY)
	_friends_row.add_child(_friends_label)

	var footer := _make_label(HubFonts.LIGHT, 14, TEXT_HINT, "O hub volta sozinho quando o jogo fechar.")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_set_anchors(footer, 0.0, 1.0, 1.0, 1.0)
	footer.offset_left = PLAYING_MARGIN
	footer.offset_top = -72.0
	footer.offset_bottom = -48.0
	_playing.add_child(footer)


## Um número grande (Barlow Condensed 52) com uma legenda pequena ao lado.
func _add_number(parent: HBoxContainer, caption: String) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var number := _make_label(HubFonts.SIGN, 52, Color.WHITE)
	box.add_child(number)
	var label := _make_label(HubFonts.LIGHT, 15, TEXT_SECONDARY, caption)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_child(label)
	return number


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
