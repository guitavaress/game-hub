class_name MapView
extends Control
## Desenha a PLANTA do mundo vista de cima (Fase 8.5), a partir do que o mundo
## publica no grupo "world_map" (get_map_data). Serve ao minimapa (segue o
## jogador, perto) e ao mapa grande (mostra tudo). Norte para cima.
##
## Só usa _draw (nenhum nó por prédio): custo quase zero. Redesenha poucas
## vezes por segundo (REFRESH_SECONDS), e não a cada quadro.

const REFRESH_SECONDS: float = 0.2
const BACKGROUND: Color = Color(0.05, 0.055, 0.07, 0.86)
## A praça: cor de pedra clara, diferente de qualquer bairro (o cinza é do
## bairro "Outros"), com o chafariz no meio.
const PLAZA_COLOR: Color = Color(0.86, 0.80, 0.68, 0.9)
const FOUNTAIN_COLOR: Color = Color(0.35, 0.62, 0.85)
const LABEL_COLOR: Color = Color("F2F4F7")
const LABEL_OUTLINE: Color = Color(0, 0, 0, 0.9)
const BORDER_COLOR: Color = Color(1, 1, 1, 0.18)
const PLAYER_COLOR: Color = Color("FFFFFF")
const AREA_ALPHA: float = 0.85

## true = o centro acompanha o jogador, com "pixels_per_meter"; false = o mapa
## inteiro cabe no controle.
var follow_player: bool = true
var pixels_per_meter: float = 1.4
## Escreve o nome dos bairros em cima deles.
var show_labels: bool = false
## Escreve embaixo o nome do bairro onde o jogador está.
var show_area_name: bool = false

var _center: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _elapsed: float = 0.0
var _data: Dictionary = {}
var _area_name: String = ""
var _heading: float = 0.0
var _player_xz: Vector2 = Vector2.ZERO
var _target: Dictionary = {"visible": false}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	process_mode = Node.PROCESS_MODE_ALWAYS  # o mapa grande desenha com o jogo pausado


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= REFRESH_SECONDS and is_visible_in_tree():
		_elapsed = 0.0
		refresh()


## Lê o estado (jogador, destino, planta) e redesenha.
func refresh() -> void:
	var map := get_tree().get_first_node_in_group("world_map")
	_data = map.get_map_data() if map != null else {}
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		_player_xz = Vector2(player.global_position.x, player.global_position.z)
		_heading = deg_to_rad(Compass.bearing_of(-player.global_basis.z))
		_area_name = map.area_name_at(player.global_position) if map != null else ""
	_target = _read_target()
	_layout()
	queue_redraw()


func get_area_name() -> String:
	return _area_name


## Onde o jogador aparece, em pixels dentro do controle.
func get_player_pixel() -> Vector2:
	return to_pixel(_player_xz)


## O destino da busca: {"visible": bool, "pos": Vector2, "color": Color}.
func get_target_info() -> Dictionary:
	return _target


func to_pixel(world: Vector2) -> Vector2:
	return size / 2.0 + (world - _center) * _scale


func get_scale_pixels() -> float:
	return _scale


func _layout() -> void:
	if follow_player or _data.is_empty():
		_scale = pixels_per_meter
		_center = _player_xz
	else:
		var bounds: Rect2 = _data["bounds"]
		_scale = minf(size.x, size.y) / maxf(bounds.size.x, 1.0) * 0.94
		_center = bounds.get_center()


func _read_target() -> Dictionary:
	for guide in get_tree().get_nodes_in_group("route_guide"):
		if guide.has_method("has_route") and guide.has_route():
			var spot: Vector3 = guide.get_target_position()
			return {"visible": true, "pos": Vector2(spot.x, spot.z), "color": guide.get_target_color()}
	return {"visible": false}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if _data.is_empty():
		return
	var gap: float = _data.get("gap", 0.0)
	var font := get_theme_default_font()

	var plaza: Rect2 = _data["plaza"]
	var plaza_px := _pixel_rect(plaza.grow(-gap / 2.0))
	draw_rect(plaza_px, PLAZA_COLOR)
	draw_circle(plaza_px.get_center(), maxf(plaza_px.size.x * 0.12, 2.0), FOUNTAIN_COLOR)
	if show_labels:
		_draw_label(font, "Praça", plaza_px.get_center() + Vector2(0.0, plaza_px.size.y * 0.3))
	for area: Dictionary in _data["areas"]:
		var color: Color = area["color"]
		color.a = AREA_ALPHA
		var mean := Vector2.ZERO
		for rect: Rect2 in area["rects"]:
			draw_rect(_pixel_rect(rect.grow(-gap / 2.0)), color)
			mean += rect.get_center()
		if show_labels and not (area["rects"] as Array).is_empty():
			# O nome vai no quarteirão do bairro mais perto do meio dele (assim
			# nunca cai em cima de outro bairro).
			mean /= float((area["rects"] as Array).size())
			var label_rect: Rect2 = area["rects"][0]
			for rect: Rect2 in area["rects"]:
				if rect.get_center().distance_to(mean) < label_rect.get_center().distance_to(mean):
					label_rect = rect
			# Texto claro com contorno escuro: lê bem em cima de qualquer cor de bairro.
			_draw_label(font, String(area["name"]).split(" e ")[0], _pixel_rect(label_rect).get_center())
	for landmark: Dictionary in _data["landmarks"]:
		var at := to_pixel(landmark["pos"])
		draw_circle(at, 5.0, Color.BLACK)
		draw_circle(at, 3.5, landmark["color"])

	if _target.get("visible", false):
		var at := _clamp_to_view(to_pixel(_target["pos"]))
		var color: Color = _target["color"]
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -8), at + Vector2(7, 0), at + Vector2(0, 8), at + Vector2(-7, 0)]), color)
		draw_polyline(PackedVector2Array([at + Vector2(0, -8), at + Vector2(7, 0), at + Vector2(0, 8), at + Vector2(-7, 0), at + Vector2(0, -8)]), Color.BLACK, 1.5)

	# O jogador: uma seta branca virada para onde ele olha.
	var me := _clamp_to_view(to_pixel(_player_xz))
	var forward := Vector2(sin(_heading), -cos(_heading))
	var side := Vector2(-forward.y, forward.x)
	var arrow := PackedVector2Array([me + forward * 9.0, me - forward * 6.0 + side * 6.0, me - forward * 3.0, me - forward * 6.0 - side * 6.0])
	draw_colored_polygon(arrow, PLAYER_COLOR)
	arrow.append(arrow[0])
	draw_polyline(arrow, Color.BLACK, 1.5)  # contorno: aparece até sobre a praça clara

	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.0)
	if show_area_name and not _area_name.is_empty():
		var width := font.get_string_size(_area_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_rect(Rect2(0.0, size.y - 22.0, size.x, 22.0), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2((size.x - width) / 2.0, size.y - 7.0), _area_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("DDE2EA"))


## Nome centrado no ponto, em texto claro com contorno.
func _draw_label(font: Font, text: String, center: Vector2) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var at := center + Vector2(-width / 2.0, 5.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, LABEL_OUTLINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, LABEL_COLOR)


func _pixel_rect(world: Rect2) -> Rect2:
	return Rect2(to_pixel(world.position), world.size * _scale)


func _clamp_to_view(point: Vector2) -> Vector2:
	return point.clamp(Vector2(8.0, 8.0), size - Vector2(8.0, 8.0))
