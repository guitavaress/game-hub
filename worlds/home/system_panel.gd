class_name SystemPanel
extends Node3D
## O PAINEL DO SISTEMA (Fase 14.9): um painel fixo na parede norte, acima do
## computador, com a hora, a bateria, o Wi-Fi e o volume. Só mostra: não mexe
## em nada do sistema.
##
## Os números vêm do SystemStatus (autoload); a hora vem do relógio do
## computador (Time, que não é código de sistema). O que o sistema não sabe
## some do painel (ex.: desktop sem bateria), e as outras linhas sobem.
##
## Desenho: placa escura com uma borda na cor do néon, Label3D e caixas
## simples, na camada do interior (como o quadro de estatísticas).
##
## Convenção: a origem fica no chão, encostada na parede, e a FRENTE (+Z)
## aponta para dentro da sala.

## Tamanho da placa (largura, altura) e altura do centro (acima do monitor).
const PANEL_SIZE: Vector2 = Vector2(1.7, 1.3)
const CENTER_Y: float = 2.4
## Altura (m) entre uma linha e a próxima.
const ROW_STEP: float = 0.19
## Altura (relativa ao centro da placa) da primeira linha de status.
const FIRST_ROW_Y: float = -0.14
const BOARD_COLOR: Color = Color(0.07, 0.065, 0.09)
const TEXT_COLOR: Color = Color(1.0, 0.9, 0.78)
const MUTED_COLOR: Color = Color(0.62, 0.58, 0.55)
const GOOD_COLOR: Color = Color(0.55, 0.85, 0.35)
const LOW_COLOR: Color = Color(1.0, 0.4, 0.3)
## Bateria abaixo disso (e sem carregar) fica vermelha.
const LOW_BATTERY: int = 20
## Nomes de rede maiores que isso são cortados.
const MAX_NAME: int = 16
const WEEKDAYS: Array[String] = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
const MONTHS: Array[String] = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]

## Quem diz a hora: Callable() -> Dictionary (como Time.get_datetime_dict_from_system).
## Os testes trocam por uma hora de mentira.
var clock: Callable = func() -> Dictionary: return Time.get_datetime_dict_from_system()

## Cor da borda e dos ícones (a casa passa a cor do néon).
var _accent: Color = Color(1.0, 0.55, 0.85)
## Tudo o que muda (linhas de status), refeito a cada mudança do SystemStatus.
var _rows: Node3D
var _time_label: Label3D
var _date_label: Label3D
var _frame_nodes: Array[Node] = []
var _timer: Timer
## Quais linhas estão na tela agora, na ordem (para os testes): "battery", "network", "volume".
var _visible_rows: Array[String] = []


func _ready() -> void:
	add_to_group("system_panel")
	_rows = Node3D.new()
	_rows.name = "Rows"
	add_child(_rows)
	_build_frame()
	_time_label = _make_label("Time", "--:--", 150, TEXT_COLOR, Vector2(0.0, 0.37), HORIZONTAL_ALIGNMENT_CENTER)
	_date_label = _make_label("Date", "", 46, MUTED_COLOR, Vector2(0.0, 0.08), HORIZONTAL_ALIGNMENT_CENTER)
	refresh_clock()
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(refresh_clock)
	add_child(_timer)
	_timer.start()
	SystemStatus.changed.connect(refresh)
	refresh()


## A cor da borda e dos ícones.
func set_accent(color: Color) -> void:
	_accent = color
	if is_inside_tree():
		_build_frame()
		refresh()


## Quais linhas de status aparecem agora, de cima para baixo.
func get_visible_rows() -> Array[String]:
	return _visible_rows


## O texto da hora e o da data (para os testes).
func get_time_text() -> String:
	return _time_label.text


func get_date_text() -> String:
	return _date_label.text


## Os textos das linhas de status, na ordem em que aparecem (para os testes).
func get_row_texts() -> Array[String]:
	var texts: Array[String] = []
	for row in _rows.get_children():
		if row is Label3D:
			texts.append((row as Label3D).text)
	return texts


## Relê a hora (a cada segundo; só mexe no texto se ele mudou).
func refresh_clock() -> void:
	var now: Dictionary = clock.call()
	var text := "%02d:%02d" % [int(now.get("hour", 0)), int(now.get("minute", 0))]
	if _time_label.text != text:
		_time_label.text = text
	var date := "%s, %d %s" % [WEEKDAYS[int(now.get("weekday", 0)) % 7], int(now.get("day", 1)),
			MONTHS[clampi(int(now.get("month", 1)) - 1, 0, 11)]]
	if _date_label.text != date:
		_date_label.text = date


## Refaz as linhas de status com o que o SystemStatus sabe agora.
func refresh() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_visible_rows.clear()
	var y := FIRST_ROW_Y
	var battery := SystemStatus.battery()
	if battery["present"]:
		_add_row("battery", _battery_text(battery), y, LOW_COLOR if _is_low(battery) else GOOD_COLOR, battery["percent"])
		y -= ROW_STEP
	var network := SystemStatus.network()
	if network["known"]:
		_add_row("network", _network_text(network), y, GOOD_COLOR if network["connected"] else MUTED_COLOR, -1)
		y -= ROW_STEP
	var volume := SystemStatus.volume()
	if volume["known"]:
		_add_row("volume", _volume_text(volume), y, MUTED_COLOR if volume["muted"] else _accent, -1)


# --- Textos ---------------------------------------------------------------------

static func _is_low(battery: Dictionary) -> bool:
	return not battery["charging"] and int(battery["percent"]) < LOW_BATTERY


static func _battery_text(battery: Dictionary) -> String:
	return "%s %d%%" % ["Carregando" if battery["charging"] else "Bateria", int(battery["percent"])]


static func _network_text(network: Dictionary) -> String:
	if not network["connected"]:
		return "Sem rede"
	var network_name: String = network["name"]
	if network_name.length() > MAX_NAME:
		network_name = network_name.left(MAX_NAME - 1) + "…"
	var prefix := "Cabo" if network["type"] == "ethernet" else "Wi-Fi"
	return prefix if network_name.is_empty() else "%s · %s" % [prefix, network_name]


static func _volume_text(volume: Dictionary) -> String:
	return "Volume mudo" if volume["muted"] else "Volume %d%%" % int(volume["percent"])


# --- Montagem -------------------------------------------------------------------

## A placa escura e a borda na cor do néon (refeita se a cor mudar).
func _build_frame() -> void:
	for node in _frame_nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_frame_nodes.clear()
	var half := PANEL_SIZE / 2.0
	_frame_nodes.append(_box("Board", Vector3(PANEL_SIZE.x, PANEL_SIZE.y, 0.04), Vector3(0.0, CENTER_Y, 0.02),
			HomeMaterials.matte(BOARD_COLOR, 0.7)))
	var glow := HomeMaterials.glow(_accent, 2.5)
	var edge := 0.02
	for y in [-half.y, half.y]:
		_frame_nodes.append(_box("EdgeH", Vector3(PANEL_SIZE.x + edge, edge, 0.05), Vector3(0.0, CENTER_Y + y, 0.025), glow))
	for x in [-half.x, half.x]:
		_frame_nodes.append(_box("EdgeV", Vector3(edge, PANEL_SIZE.y, 0.05), Vector3(x, CENTER_Y, 0.025), glow))


## Uma linha: o ícone à esquerda (para a bateria, um medidor cheio até o %;
## para as outras, um ponto) e o texto. "y" é relativo ao centro da placa.
func _add_row(row_id: String, text: String, y: float, color: Color, battery_percent: int) -> void:
	_visible_rows.append(row_id)
	var x := -PANEL_SIZE.x / 2.0 + 0.12
	if battery_percent >= 0:
		var meter_w := 0.14
		var outline := _box("BatteryBody", Vector3(meter_w, 0.07, 0.01), _at(Vector2(x + meter_w / 2.0, y)),
				HomeMaterials.matte(Color(0.2, 0.19, 0.22), 0.8), _rows)
		outline.set_meta("row", row_id)
		var fill_w := maxf(meter_w * battery_percent / 100.0, 0.005)
		_box("BatteryFill", Vector3(fill_w, 0.05, 0.012), _at(Vector2(x + fill_w / 2.0, y)), HomeMaterials.glow(color, 1.5), _rows)
		_box("BatteryTip", Vector3(0.015, 0.03, 0.01), _at(Vector2(x + meter_w + 0.008, y)), HomeMaterials.matte(Color(0.2, 0.19, 0.22), 0.8), _rows)
	else:
		_box("Dot", Vector3(0.05, 0.05, 0.012), _at(Vector2(x + 0.07, y)), HomeMaterials.glow(color, 1.5), _rows)
	var label := _make_label("Row_" + row_id, text, 52, TEXT_COLOR, Vector2(x + 0.22, y), HORIZONTAL_ALIGNMENT_LEFT, _rows)
	label.set_meta("row", row_id)


## Posição na placa (x, y relativos ao centro) em coordenadas do painel.
func _at(spot: Vector2) -> Vector3:
	return Vector3(spot.x, CENTER_Y + spot.y, 0.045)


func _make_label(label_name: String, text: String, size: int, color: Color, spot: Vector2,
		align: HorizontalAlignment, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0025
	label.modulate = color
	label.outline_size = 0
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = _at(spot)
	label.layers = Home.INTERIOR_LAYER_MASK
	(parent if parent != null else self).add_child(label)
	return label


## Caixa sem colisão (o painel está alto, fora do alcance).
func _box(box_name: String, box_size: Vector3, center: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = box_name
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	mesh.layers = Home.INTERIOR_LAYER_MASK
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(mesh)
	return mesh
