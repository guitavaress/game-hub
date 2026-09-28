class_name SplashScreen
extends Control
## Abertura: enquanto a cidade monta, a câmera olha o céu (na hora certa) e
## esta tela transparente mostra por cima:
##   - "GAME HUB" (Barlow Condensed 104, letras espaçadas), um filete verde e
##     a frase "Sua biblioteca Steam, em forma de cidade";
##   - embaixo, o que está acontecendo ("Construindo bairros… 14 de 18 jogos"),
##     uma barra fina de progresso e as 4 etapas (as prontas ficam verdes, com ✓);
##   - no canto, a hora da cidade ("22:14 · noite").
## Um degradê escuro de baixo para cima deixa o texto legível contra o céu.
## Quem manda nela é o ScreenFade (show_splash, hide_splash); quem conta o
## progresso é o mundo (a cidade).

const TEXT_COLOR: Color = Color("F2F3F5")
const SECONDARY_COLOR: Color = Color("B8BFCC")
const HINT_COLOR: Color = Color("8A92A0")
const DONE_COLOR: Color = Color("5FE3A1")
const BAR_SIZE: Vector2 = Vector2(400.0, 3.0)
const BAR_BOTTOM: float = 88.0
## [id, nome na tela]
const STAGES: Array[Array] = [
	["biblioteca", "BIBLIOTECA"], ["capas", "CAPAS"], ["bairros", "BAIRROS"], ["amigos", "AMIGOS"],
]

var _status: Label
var _bar_fill: ColorRect
var _clock: Label
var _stage_labels: Dictionary[String, Label] = {}
var _done: Dictionary[String, bool] = {}
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# Degradê escuro de baixo para cima (o céu continua aparecendo no alto).
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.025, 0.035, 0.0))
	gradient.set_color(1, Color(0.02, 0.025, 0.035, 0.88))
	gradient.set_offset(0, 0.25)
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0.0, 0.0)
	shade_texture.fill_to = Vector2(0.0, 1.0)
	var shade := TextureRect.new()
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	# Marca, no meio da tela.
	var brand := VBoxContainer.new()
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.add_theme_constant_override("separation", 14)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brand.offset_bottom = -120.0
	add_child(brand)
	brand.add_child(_label("GAME HUB", _spaced(14), 104, TEXT_COLOR))
	var accent_row := CenterContainer.new()
	accent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent := ColorRect.new()
	accent.color = DONE_COLOR
	accent.custom_minimum_size = Vector2(140.0, 3.0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_row.add_child(accent)
	brand.add_child(accent_row)
	brand.add_child(_label("Sua biblioteca Steam, em forma de cidade", HubFonts.LIGHT, 20, SECONDARY_COLOR))

	# Progresso, embaixo: frase, barra e etapas.
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -BAR_BOTTOM + 34.0
	add_child(bottom)
	_status = _label("", HubFonts.LIGHT, 16, SECONDARY_COLOR)
	bottom.add_child(_status)
	var bar_row := CenterContainer.new()
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := ColorRect.new()
	track.color = Color(1.0, 1.0, 1.0, 0.15)
	track.custom_minimum_size = BAR_SIZE
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill = ColorRect.new()
	_bar_fill.color = TEXT_COLOR
	_bar_fill.size = Vector2(0.0, BAR_SIZE.y)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_bar_fill)
	bar_row.add_child(track)
	bottom.add_child(bar_row)
	var stages := HBoxContainer.new()
	stages.alignment = BoxContainer.ALIGNMENT_CENTER
	stages.add_theme_constant_override("separation", 26)
	stages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for stage in STAGES:
		var stage_label := _label(stage[1], _spaced(2), 14, HINT_COLOR)
		stages.add_child(stage_label)
		_stage_labels[stage[0]] = stage_label
	bottom.add_child(stages)

	_clock = _label("", _spaced(2), 14, HINT_COLOR)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_clock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_clock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_clock.offset_right = -36.0
	_clock.offset_bottom = -28.0
	add_child(_clock)


## Mostra a abertura do zero (tudo pendente, barra vazia).
func show_splash(clock_text: String = "") -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_done.clear()
	for stage in STAGES:
		_paint_stage(stage[0], stage[1])
	set_progress(0.0)
	_status.text = ""
	_clock.text = clock_text
	modulate.a = 1.0
	visible = true


## Some aos poucos (a câmera começa a descer ao mesmo tempo).
func hide_splash(seconds: float = 0.4) -> void:
	if not visible:
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, seconds)
	_tween.finished.connect(func() -> void: visible = false)


## O que está acontecendo agora ("Construindo bairros… 14 de 18 jogos").
func set_status(text: String) -> void:
	_status.text = text


func get_status() -> String:
	return _status.text


## Barra de progresso: 0.0 a 1.0.
func set_progress(fraction: float) -> void:
	_bar_fill.size = Vector2(BAR_SIZE.x * clampf(fraction, 0.0, 1.0), BAR_SIZE.y)


func get_progress() -> float:
	return _bar_fill.size.x / BAR_SIZE.x


## Marca uma etapa como pronta (fica verde, com ✓).
func complete_stage(stage_id: String) -> void:
	_done[stage_id] = true
	for stage in STAGES:
		if stage[0] == stage_id:
			_paint_stage(stage[0], stage[1])


func is_stage_done(stage_id: String) -> bool:
	return _done.get(stage_id, false)


func _paint_stage(stage_id: String, stage_name: String) -> void:
	var stage_label := _stage_labels[stage_id]
	var done: bool = _done.get(stage_id, false)
	stage_label.text = stage_name + (" ✓" if done else "")
	stage_label.add_theme_color_override("font_color", DONE_COLOR if done else HINT_COLOR)


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Barlow Condensed com "extra" px entre as letras.
func _spaced(extra: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = HubFonts.SIGN
	font.spacing_glyph = extra
	return font
