class_name Compass
extends Control
## BÚSSOLA (Fase 8): uma faixa no topo da tela com os pontos cardeais (N, L,
## S, O) que correm conforme o jogador gira, e o marcador do DESTINO da busca
## (a porta que a faixa de luz mostra), com a distância.
##
## Ela não conhece a cidade: o destino vem de quem estiver no grupo
## "route_guide" (get_target_position, has_route). Norte = -Z do mundo.
## Some junto com o minimapa pela opção "Bússola e mapa" do menu de pausa.

const SIZE_PX: Vector2 = Vector2(480.0, 30.0)
const TOP: float = 12.0
## Quantos graus cabem na faixa, de ponta a ponta.
const SPAN_DEGREES: float = 160.0
const PANEL_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.78)
const TICK_COLOR: Color = Color(0.72, 0.75, 0.8, 0.7)
const LABEL_COLOR: Color = Color("B8BFCC")
const NORTH_COLOR: Color = Color("FF6B6B")
const NOTCH_COLOR: Color = Color.WHITE
const MARK_STEP: int = 15
const CARDINALS: Dictionary = {0: "N", 45: "NE", 90: "L", 135: "SE", 180: "S", 225: "SO", 270: "O", 315: "NO"}

var _heading: float = 0.0
var _target: Dictionary = {"visible": false}
var _last_signature: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_left = -SIZE_PX.x / 2.0
	offset_right = SIZE_PX.x / 2.0
	offset_top = TOP
	offset_bottom = TOP + SIZE_PX.y


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	_heading = bearing_of(-player.global_basis.z)
	_target = _read_target(player)
	var signature := "%d|%s|%d" % [roundi(_heading * 2.0), str(_target.get("visible")), roundi(float(_target.get("bearing", 0.0)) * 2.0) + int(_target.get("distance", 0.0))]
	if signature != _last_signature:
		_last_signature = signature
		queue_redraw()


## Rumo (0 a 360, sentido horário a partir do norte) de uma direção do mundo.
static func bearing_of(direction: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(direction.x, -direction.z)), 360.0)


## Para onde o jogador está olhando, em graus (0 = norte, 90 = leste).
func get_heading() -> float:
	return _heading


## O marcador do destino: {"visible": bool, "bearing": graus, "distance": m,
## "offset": graus em relação ao olhar, "color": Color}.
func get_target_info() -> Dictionary:
	return _target


## Posição x (px, dentro da faixa) de um rumo, ou -1 se estiver fora da faixa.
func x_for_bearing(bearing: float) -> float:
	var offset := _signed_offset(bearing)
	if absf(offset) > SPAN_DEGREES / 2.0:
		return -1.0
	return size.x / 2.0 + offset / SPAN_DEGREES * size.x


func _read_target(player: Node3D) -> Dictionary:
	for guide in get_tree().get_nodes_in_group("route_guide"):
		if guide.has_method("has_route") and guide.has_route():
			var spot: Vector3 = guide.get_target_position()
			var delta := spot - player.global_position
			delta.y = 0.0
			var bearing := bearing_of(delta)
			return {"visible": true, "bearing": bearing, "distance": delta.length(),
					"offset": _signed_offset(bearing), "color": guide.get_target_color()}
	return {"visible": false}


## Diferença entre um rumo e o olhar do jogador, de -180 a 180.
func _signed_offset(bearing: float) -> float:
	return fposmod(bearing - _heading + 180.0, 360.0) - 180.0


func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_COLOR
	panel.set_corner_radius_all(6)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))

	var font := get_theme_default_font()
	var mid := size.x / 2.0
	for step in range(0, 360, MARK_STEP):
		var x := x_for_bearing(float(step))
		if x < 0.0:
			continue
		var label: String = CARDINALS.get(step, "")
		if label.is_empty():
			draw_line(Vector2(x, size.y - 9.0), Vector2(x, size.y - 3.0), TICK_COLOR, 1.0)
			continue
		var is_main := label.length() == 1
		var color := NORTH_COLOR if label == "N" else LABEL_COLOR
		var font_size := 16 if is_main else 12
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(x - width / 2.0, 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	# Marca do olhar: um triângulo branco embaixo, no meio.
	draw_colored_polygon(PackedVector2Array([Vector2(mid - 5.0, size.y), Vector2(mid + 5.0, size.y), Vector2(mid, size.y - 6.0)]), NOTCH_COLOR)

	if _target.get("visible", false):
		var offset: float = _target["offset"]
		var clamped := clampf(offset, -SPAN_DEGREES / 2.0 + 6.0, SPAN_DEGREES / 2.0 - 6.0)
		var tx := mid + clamped / SPAN_DEGREES * size.x
		var color: Color = _target["color"]
		draw_colored_polygon(PackedVector2Array([Vector2(tx, 3.0), Vector2(tx + 6.0, 10.0), Vector2(tx, 17.0), Vector2(tx - 6.0, 10.0)]), color)
		var text := "%d m" % (roundi(float(_target["distance"]) / 5.0) * 5)
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var text_x := clampf(tx - text_width / 2.0, 4.0, size.x - text_width - 4.0)
		draw_string(font, Vector2(text_x, size.y - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
