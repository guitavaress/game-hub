class_name MapView
extends Control
## Desenha a PLANTA do mundo vista de cima (Fase 8.5), a partir do que o mundo
## publica no grupo "world_map" (get_map_data). Serve ao minimapa (segue o
## jogador, perto) e ao mapa grande (mostra tudo). Norte para cima.
##
## Só usa _draw (nenhum nó por prédio): custo quase zero. Redesenha poucas
## vezes por segundo (REFRESH_SECONDS), e não a cada quadro.

signal refreshed

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
## As vagas do bairro (zonas sem prédio): a mesma cor, bem mais fraca.
const VACANT_ALPHA: float = 0.34

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
## O jogador está em casa: a casa fica longe da planta, então no lugar da seta
## o mapa escreve "Você está em casa".
var _indoors: bool = false
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
		_indoors = player.has_method("is_indoors") and player.is_indoors()
	_target = _read_target()
	_layout()
	queue_redraw()
	refreshed.emit()


## Cor do primeiro marco deste tipo; branco enquanto os dados não chegaram.
func get_landmark_color(kind: String) -> Color:
	for landmark: Dictionary in _data.get("landmarks", []):
		if landmark["kind"] == kind:
			return landmark["color"]
	return PLAYER_COLOR


func is_indoors() -> bool:
	return _indoors


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
	var labels: Array[Dictionary] = []

	var plaza: Rect2 = _data["plaza"]
	var plaza_px := _pixel_rect(plaza.grow(-gap / 2.0))
	draw_rect(plaza_px, PLAZA_COLOR)
	draw_circle(plaza_px.get_center(), maxf(plaza_px.size.x * 0.12, 2.0), FOUNTAIN_COLOR)
	if show_labels:
		labels.append({"text": "Praça", "center": plaza_px.get_center() + Vector2(0.0, plaza_px.size.y * 0.3)})
	for area: Dictionary in _data["areas"]:
		var color: Color = area["color"]
		# Primeiro as vagas (a fatia inteira aparece, da praça até a borda).
		var vacant_color := color
		vacant_color.a = VACANT_ALPHA
		var bounds: Rect2 = _data["bounds"]
		for rect: Rect2 in area.get("zones", []):
			# Só o que fica dentro da mureta (a montanha da 15.9 fica de fora).
			if not (area["rects"] as Array).has(rect) and bounds.encloses(rect):
				draw_rect(_pixel_rect(rect.grow(-gap / 2.0)), vacant_color)
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
			labels.append({"text": String(area["name"]).split(" e ")[0], "center": _pixel_rect(label_rect).get_center()})
	for landmark: Dictionary in _data["landmarks"]:
		var at := to_pixel(landmark["pos"])
		draw_symbol(self, landmark["kind"], at, landmark["color"])
		if show_labels and not follow_player and landmark["kind"] == "trilha":
			var text: String = landmark["name"]
			var half_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x / 2.0
			var center: Vector2 = (at + Vector2(0, 22)).clamp(
				Vector2(half_width + 4.0, 14.0), size - Vector2(half_width + 4.0, 14.0))
			labels.append({"text": text, "center": center})

	if _target.get("visible", false):
		var at := _clamp_to_view(to_pixel(_target["pos"]))
		var color: Color = _target["color"]
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -8), at + Vector2(7, 0), at + Vector2(0, 8), at + Vector2(-7, 0)]), color)
		draw_polyline(PackedVector2Array([at + Vector2(0, -8), at + Vector2(7, 0), at + Vector2(0, 8), at + Vector2(-7, 0), at + Vector2(0, -8)]), Color.BLACK, 1.5)

	if _indoors:
		_draw_home_banner(font)
	else:
		# O jogador: uma seta branca virada para onde ele olha.
		var me := _clamp_to_view(to_pixel(_player_xz))
		draw_symbol(self, "player", me, PLAYER_COLOR, _heading)

	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.0)
	if show_area_name and not _area_name.is_empty():
		var width := font.get_string_size(_area_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_rect(Rect2(0.0, size.y - 22.0, size.x, 22.0), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2((size.x - width) / 2.0, size.y - 7.0), _area_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("DDE2EA"))
	# Os nomes ficam por cima de todas as áreas e símbolos da planta.
	for label: Dictionary in labels:
		_draw_label(font, label["text"], label["center"])


## Marco da casa: uma casinha (telhado e paredes) com contorno escuro, maior
## que as bolinhas das estações.
static func _draw_house(canvas: CanvasItem, at: Vector2, color: Color) -> void:
	var house := PackedVector2Array([at + Vector2(0, -8), at + Vector2(7, -1), at + Vector2(5, -1),
			at + Vector2(5, 6), at + Vector2(-5, 6), at + Vector2(-5, -1), at + Vector2(-7, -1)])
	canvas.draw_colored_polygon(house, color)
	house.append(house[0])
	canvas.draw_polyline(house, Color.BLACK, 1.5)


## Mesmos símbolos na planta e na legenda; as coordenadas são locais ao controle.
## Chame apenas durante o desenho do controle recebido.
static func draw_symbol(canvas: CanvasItem, kind: String, at: Vector2, color: Color, heading: float = 0.0) -> void:
	if kind == "home":
		_draw_house(canvas, at, color)
	elif kind == "player":
		var forward := Vector2(sin(heading), -cos(heading))
		var side := Vector2(-forward.y, forward.x)
		var arrow := PackedVector2Array([at + forward * 9.0, at - forward * 6.0 + side * 6.0,
			at - forward * 3.0, at - forward * 6.0 - side * 6.0])
		canvas.draw_colored_polygon(arrow, color)
		arrow.append(arrow[0])
		canvas.draw_polyline(arrow, Color.BLACK, 1.5)
	elif kind == "trilha":
		var peak := PackedVector2Array([at + Vector2(0, -7), at + Vector2(7, 5), at + Vector2(-7, 5)])
		canvas.draw_colored_polygon(peak, color)
		peak.append(peak[0])
		canvas.draw_polyline(peak, Color.BLACK, 1.5)
	else:
		var radius: float = 6.0 if kind == "marco" else 5.0
		canvas.draw_circle(at, radius, Color.BLACK)
		canvas.draw_circle(at, radius - 1.5, color)


## Faixa "Você está em casa" no alto do mapa (no lugar da seta).
func _draw_home_banner(font: Font) -> void:
	var text := "Você está em casa"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var box := Rect2((size.x - width) / 2.0 - 12.0, 10.0, width + 24.0, 28.0)
	draw_rect(box, Color(0, 0, 0, 0.7))
	draw_rect(box, PLAYER_COLOR, false, 1.0)
	draw_string(font, Vector2(box.position.x + 12.0, box.position.y + 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PLAYER_COLOR)


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
