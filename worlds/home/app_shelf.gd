class_name AppShelf
extends Node3D
## A ESTANTE DE APPS (Fase 14.7): os programas instalados (navegador, terminal...)
## viram caixas quadradas com o ícone, numa parede da casa. Olhar uma caixa
## mostra o cartão ("Brave Origin · Internet"); segurar E abre o app pelo
## AppLauncher. Duas placas passam as páginas e uma troca o filtro (Todos →
## categorias dos apps).
##
## É a irmã MAIS ESTREITA da estante de jogos (LibraryShelf): 5 x 3 caixas, para
## caber entre a parede e o janelão. Reaproveita as placas dela (ShelfButton).
##
## Convenção (igual à estante de jogos): a origem fica no chão, no meio da
## estante, e a FRENTE (+Z) aponta para dentro da sala.

const COLUMNS: int = 5
const ROWS: int = 3
const PER_PAGE: int = COLUMNS * ROWS
## Tamanho da caixa (largura, altura, espessura) e espaço entre os centros.
const BOX_SIZE: Vector3 = Vector3(0.4, 0.4, 0.06)
const BOX_STEP: Vector2 = Vector2(0.52, 0.52)
## Ordem em que as fileiras se enchem (0 = a de baixo): primeiro a da altura
## dos olhos, depois a de cima e por último a de baixo.
const ROW_ORDER: Array[int] = [1, 2, 0]
## Altura do centro da fileira de baixo; as outras sobem de BOX_STEP.y.
const FIRST_ROW_Y: float = 0.85
## Segundos segurando E até o app abrir.
const HOLD_SECONDS: float = 1.2
## Segundos para a tela clarear quando o jogador volta.
const RETURN_FADE_TIME: float = 0.8
## Onde o jogador reaparece (na frente da estante, olhando para ela).
const RETURN_SPOT: Vector3 = Vector3(0.0, 0.1, 2.2)
const PANEL_COLOR: Color = Color(0.15, 0.17, 0.22)
const FRAME_WOOD: Color = Color(0.22, 0.2, 0.24)
const FILTER_ALL: String = ""
## Cor de cada categoria de app (no cartão e na inicial das caixas sem ícone).
const CATEGORY_COLORS: Dictionary[String, Color] = {
	"internet": Color("4FA3FF"),
	"escritorio": Color("F2C94C"),
	"midia": Color("F2994A"),
	"graficos": Color("BB6BD9"),
	"programacao": Color("6FCF97"),
	"sistema": Color("9AA5B1"),
	"jogos": Color("EB5757"),
	"diversos": Color("56CCF2"),
}

var _page: int = 0
var _filter: String = FILTER_ALL
## Ids dos apps do filtro atual, na ordem da AppLibrary.
var _app_ids: Array[String] = []
var _slots: Node3D
var _page_label: Label3D
var _filter_label: Label3D
## Caixa de cada app da página atual (para o ícone entrar quando chegar).
var _boxes_by_app: Dictionary[String, AppBox] = {}
## true entre chamar AppLauncher.launch() e receber app_session_ended.
var _waiting_for_app: bool = false


func _ready() -> void:
	add_to_group("app_shelf")
	_build_frame()
	_slots = Node3D.new()
	_slots.name = "Slots"
	add_child(_slots)
	_build_buttons()
	AppLauncher.app_session_ended.connect(_on_session_ended)
	AppLibrary.icon_ready.connect(_on_icon_ready)
	AppLibrary.apps_changed.connect(refresh)
	refresh()


# --- Contrato com a casa e com os testes ----------------------------------------

## Monta de novo a lista (apps, ordem, filtro) e a página atual.
func refresh() -> void:
	_app_ids = []
	for app in AppLibrary.apps_in(_filter):
		_app_ids.append(app.id)
	_page = clampi(_page, 0, get_page_count() - 1)
	_build_page()


func get_page() -> int:
	return _page


func get_page_count() -> int:
	return maxi(1, ceili(_app_ids.size() / float(PER_PAGE)))


func get_filter() -> String:
	return _filter


func get_total() -> int:
	return _app_ids.size()


## Ids das caixas que aparecem agora.
func get_visible_app_ids() -> Array[String]:
	var ids: Array[String] = []
	for box in _slots.get_children():
		if box is AppBox:
			ids.append((box as AppBox).app_id)
	return ids


func get_box(app_id: String) -> AppBox:
	return _boxes_by_app.get(app_id)


func next_page() -> void:
	_set_page((_page + 1) % get_page_count())


func previous_page() -> void:
	_set_page((_page - 1 + get_page_count()) % get_page_count())


## Passa para o próximo filtro: Todos → cada categoria que tem app → Todos.
func next_filter() -> void:
	var options := get_filter_options()
	var index := options.find(_filter)
	set_filter(options[(index + 1) % options.size()])


func set_filter(category_id: String) -> void:
	_filter = category_id
	_page = 0
	refresh()


## "" (todos) e as categorias que têm pelo menos um app.
func get_filter_options() -> Array[String]:
	var options: Array[String] = [FILTER_ALL]
	options.append_array(AppLibrary.used_categories())
	return options


## Onde o jogador fica ao voltar de um app aberto daqui.
func get_return_transform() -> Transform3D:
	return Transform3D(global_basis, to_global(RETURN_SPOT))


static func category_color(category_id: String) -> Color:
	return CATEGORY_COLORS.get(category_id, CATEGORY_COLORS["diversos"])


# --- Caixas ---------------------------------------------------------------------

func _set_page(page: int) -> void:
	_page = page
	_build_page()


func _build_page() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	_boxes_by_app.clear()
	var first := _page * PER_PAGE
	var width := (COLUMNS - 1) * BOX_STEP.x
	for i in mini(PER_PAGE, _app_ids.size() - first):
		var column := i % COLUMNS
		var row := ROW_ORDER[floori(i / float(COLUMNS))]
		var box := AppBox.new()
		box.shelf = self
		box.app_id = _app_ids[first + i]
		box.position = Vector3(-width / 2.0 + column * BOX_STEP.x, FIRST_ROW_Y + row * BOX_STEP.y, BOX_SIZE.z / 2.0 + 0.04)
		_slots.add_child(box)
		_boxes_by_app[box.app_id] = box
	_page_label.text = "%d / %d" % [_page + 1, get_page_count()]
	_filter_label.text = "TODOS OS APPS" if _filter.is_empty() else str(AppLibrary.CATEGORIES.get(_filter, _filter)).to_upper()


func _on_icon_ready(app_id: String) -> void:
	var box: AppBox = _boxes_by_app.get(app_id)
	if box != null:
		box.show_icon()


# --- Abrir o app ----------------------------------------------------------------

## A caixa está sendo segurada: a vinheta escurece na cor da categoria.
func _on_box_hold(box: AppBox, ratio: float) -> void:
	if _waiting_for_app:
		return
	ScreenFade.set_door_charge(ratio, box.get_app_name(), category_color(box.get_category()))


func _on_box_opened(box: AppBox) -> void:
	if _waiting_for_app:
		return
	_waiting_for_app = true
	ScreenFade.set_door_charge(0.0)  # a vinheta já está toda preta: troca pela cortina
	ScreenFade.set_amount(1.0)
	AppLauncher.launch(box.app_id, self)


func _on_session_ended(_app_id: String, source: Node, _success: bool, _message: String) -> void:
	if source != self:
		return
	_waiting_for_app = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.teleport_to(get_return_transform())
	# Se o hub nem chegou a dormir (ex.: o app não abriu), quem escureceu a
	# tela foi a estante, então ela mesma clareia.
	if not HubWindow.is_sleeping:
		ScreenFade.fade_in(RETURN_FADE_TIME)


# --- Montagem -------------------------------------------------------------------

## O móvel: fundo, laterais, tampo, rodapé e uma prateleira embaixo de cada
## fileira. O fundo e as laterais têm colisão; as prateleiras não, para não
## esconder as caixas do raio do olhar.
func _build_frame() -> void:
	var width := (COLUMNS - 1) * BOX_STEP.x + 0.7
	var top := FIRST_ROW_Y + (ROWS - 1) * BOX_STEP.y + BOX_SIZE.y / 2.0 + 0.12
	var depth := 0.22
	var wood := HomeMaterials.wood(FRAME_WOOD, false, 0.45)
	var back := HomeMaterials.wood(PANEL_COLOR, false, 0.7)
	_add_part("Panel", Vector3(width, top, 0.04), Vector3(0.0, top / 2.0, 0.02), back, true)
	for side in [-1.0, 1.0]:
		_add_part("Side", Vector3(0.05, top, depth), Vector3(side * (width / 2.0 + 0.025), top / 2.0, depth / 2.0), wood, true)
	_add_part("Top", Vector3(width + 0.1, 0.16, depth + 0.02), Vector3(0.0, top + 0.03, depth / 2.0), wood, false)
	_add_part("Plinth", Vector3(width, 0.1, depth - 0.02), Vector3(0.0, 0.05, depth / 2.0), wood, false)
	for row in ROWS:
		var board_y := FIRST_ROW_Y + row * BOX_STEP.y - BOX_SIZE.y / 2.0 - 0.015
		_add_part("Board", Vector3(width, 0.03, depth - 0.02), Vector3(0.0, board_y, depth / 2.0), wood, false)


func _add_part(part_name: String, part_size: Vector3, center: Vector3, material: Material, solid: bool) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = part_size
	part.mesh = mesh
	part.material_override = material
	part.position = center
	part.layers = Home.INTERIOR_LAYER_MASK
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = part_size
		shape.shape = box_shape
		body.add_child(shape)
		part.add_child(body)
	add_child(part)


## As placas embaixo das caixas (página anterior, próxima e filtro) e, no
## alto da estante, o nome do filtro de agora.
func _build_buttons() -> void:
	_page_label = _make_label("1 / 1", Vector3(0.0, 0.3, 0.1))
	var top := FIRST_ROW_Y + (ROWS - 1) * BOX_STEP.y + BOX_SIZE.y / 2.0 + 0.12
	_filter_label = _make_label("TODOS OS APPS", Vector3(0.0, top + 0.03, 0.23))
	_filter_label.font_size = 40
	_add_button("PrevPage", "<", "Página anterior", Vector3(-0.5, 0.3, 0.1), previous_page)
	_add_button("NextPage", ">", "Próxima página", Vector3(0.5, 0.3, 0.1), next_page)
	_add_button("Filter", "Tipo", "Trocar o tipo de app", Vector3(1.0, 0.3, 0.1), next_filter)


func _make_label(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0035
	label.modulate = Color(0.75, 0.88, 1.0)
	label.outline_size = 8
	label.position = at
	label.layers = Home.INTERIOR_LAYER_MASK
	add_child(label)
	return label


func _add_button(button_name: String, text: String, hint: String, at: Vector3, action: Callable) -> void:
	var button := LibraryShelf.ShelfButton.new()
	button.name = button_name
	button.text = text
	button.hint = hint
	button.action = action
	button.position = at
	add_child(button)


# --- Peças ----------------------------------------------------------------------

## Uma caixa de app: o ícone na frente (ou a inicial, na cor da categoria), o
## cartão ao olhar e E segurado para abrir. Camada 3 (olhável).
class AppBox extends Area3D:
	var shelf: AppShelf
	var app_id: String = ""
	var _tile: MeshInstance3D
	var _icon: MeshInstance3D
	var _letter: Label3D

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = BOX_SIZE + Vector3(0.0, 0.0, 0.08)
		shape.shape = box
		add_child(shape)
		var color := AppShelf.category_color(get_category())
		_tile = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = BOX_SIZE
		_tile.mesh = mesh
		var tile_material := StandardMaterial3D.new()
		tile_material.albedo_color = color.darkened(0.55)
		tile_material.roughness = 0.6
		_tile.material_override = tile_material
		add_child(_tile)
		var front := BOX_SIZE.z / 2.0 + 0.004
		_icon = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(BOX_SIZE.x * 0.78, BOX_SIZE.y * 0.78)
		_icon.mesh = quad
		_icon.position = Vector3(0.0, 0.0, front)
		_tile.add_child(_icon)
		_letter = Label3D.new()
		_letter.font_size = 96
		_letter.pixel_size = 0.0035
		_letter.modulate = color
		_letter.outline_size = 6
		_letter.position = Vector3(0.0, 0.0, front)
		_letter.text = get_app_name().left(1).to_upper()
		_tile.add_child(_letter)
		for node: GeometryInstance3D in [_tile, _icon, _letter]:
			node.layers = Home.INTERIOR_LAYER_MASK
		show_icon()

	func get_app_name() -> String:
		var app := AppLibrary.get_app(app_id)
		return app.name if app != null else app_id

	func get_category() -> String:
		var app := AppLibrary.get_app(app_id)
		return AppLibrary.category_of(app) if app != null else "diversos"

	## Põe o ícone (se já carregou); sem ele, a caixa mostra a inicial.
	func show_icon() -> void:
		var texture := AppLibrary.get_icon(app_id)
		_icon.visible = texture != null
		_letter.visible = texture == null
		if texture != null:
			var material := StandardMaterial3D.new()
			material.albedo_texture = texture
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_icon.material_override = material

	func get_look_info() -> Dictionary:
		var app := AppLibrary.get_app(app_id)
		var category := get_category()
		var color := AppShelf.category_color(category)
		return {
			"label": str(AppLibrary.CATEGORIES.get(category, "")).to_upper(),
			"label_color": color,
			"title": get_app_name(),
			"detail": app.comment if app != null else "",
			"friends": "",
			"accent": color,
			"action": "Segure {interact} para abrir",
		}

	func get_hold_seconds() -> float:
		return HOLD_SECONDS

	func set_hold(ratio: float) -> void:
		shelf._on_box_hold(self, ratio)

	func interact(_player: Node) -> void:
		shelf._on_box_opened(self)
