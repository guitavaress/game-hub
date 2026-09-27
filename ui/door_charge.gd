class_name DoorCharge
extends Control
## O que aparece enquanto o jogador espera na porta de um jogo (1,5 s):
##   - uma VINHETA que fecha das bordas para o centro (vignette.gdshader);
##   - um ANEL de 80 px em volta da mira, que enche no sentido horário;
##   - "ENTRANDO EM BALATRO" e "recue para cancelar" logo abaixo.
## Com progress = 1 a vinheta cobre tudo de preto, e a tela "Abrindo X…" entra.
## Quem mostra é o ScreenFade (set_door_charge); o portal só manda o progresso.

const RING_DIAMETER: float = 80.0
const RING_WIDTH: float = 4.0
const TEXT_TOP: float = 58.0  # distância do centro da tela até o texto (px)
const HINT_COLOR: Color = Color("B8BFCC")
const VIGNETTE_SHADER: Shader = preload("res://ui/vignette.gdshader")

var _vignette: ColorRect
var _vignette_material: ShaderMaterial
var _ring: Ring
var _title: Label
var _hint: Label
var _text_plate: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = VIGNETTE_SHADER
	_vignette.material = _vignette_material
	add_child(_vignette)

	_ring = Ring.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ring.offset_left = -RING_DIAMETER / 2.0
	_ring.offset_top = -RING_DIAMETER / 2.0
	_ring.offset_right = RING_DIAMETER / 2.0
	_ring.offset_bottom = RING_DIAMETER / 2.0
	add_child(_ring)

	# Os textos ficam numa plaquinha escura: a porta de luz atrás é bem clara.
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.62)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 7.0
	plate.add_theme_stylebox_override("panel", style)
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	plate.anchor_top = 0.5
	plate.anchor_bottom = 0.5
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.offset_top = TEXT_TOP
	add_child(plate)
	_text_plate = plate

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 0)
	plate.add_child(texts)

	# Barlow Condensed com 2 px a mais entre as letras.
	var spaced := FontVariation.new()
	spaced.base_font = HubFonts.SIGN
	spaced.spacing_glyph = 2
	_title = _make_label(spaced, 16, Color.WHITE)
	texts.add_child(_title)
	_hint = _make_label(HubFonts.LIGHT, 14, HINT_COLOR, "recue para cancelar")
	texts.add_child(_hint)


## progress: 0..1 (0 esconde tudo). "game_name" e "color" (a cor do anel)
## só precisam vir quando mudam.
func set_progress(progress: float, game_name: String = "", color: Color = Color.WHITE) -> void:
	progress = clampf(progress, 0.0, 1.0)
	visible = progress > 0.0
	if not visible:
		return
	if not game_name.is_empty():
		_title.text = "ENTRANDO EM %s" % game_name.to_upper()
		_ring.color = color
	_vignette_material.set_shader_parameter("amount", progress)
	_ring.progress = progress
	_ring.queue_redraw()
	# Os textos somem no finalzinho, junto com o preto.
	var text_alpha := 1.0 - smoothstep(0.85, 1.0, progress)
	_text_plate.modulate.a = text_alpha
	_ring.modulate.a = text_alpha


func get_progress() -> float:
	return _ring.progress if visible else 0.0


func get_title() -> String:
	return _title.text


func _make_label(font: Font, font_size: int, color: Color, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Anel de progresso: trilho escuro (aparece em fundo claro ou escuro) e, por
## cima, o arco que enche no sentido horário a partir do topo.
class Ring:
	extends Control

	var progress: float = 0.0
	var color: Color = Color.WHITE

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - RING_WIDTH
		draw_arc(center, radius, 0.0, TAU, 64, Color(0.035, 0.04, 0.05, 0.55), RING_WIDTH + 3.0, true)
		draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.16), RING_WIDTH, true)
		if progress > 0.0:
			var start := -PI / 2.0  # topo
			draw_arc(center, radius, start, start + TAU * progress, 64, color, RING_WIDTH, true)
