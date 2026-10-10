class_name LibraryShelf
extends Node3D
## A ESTANTE (Fase 9.4): a biblioteca da Steam vira caixas numa parede da casa.
## Olhar uma caixa mostra o mesmo cartão do prédio (GameInfo); segurar E abre o
## jogo. Duas placas passam as páginas e uma troca o filtro (Todos → bairros).
##
## As caixas NÃO são GamePortal: senão a busca, o mapa e o metrô contariam os
## jogos em dobro.
##
## Convenção: a origem fica no chão, no meio da estante, e a FRENTE (+Z) aponta
## para dentro da sala (de onde o jogador olha).

## Caixas por página: COLUMNS x ROWS.
const COLUMNS: int = 8
const ROWS: int = 3
const PER_PAGE: int = COLUMNS * ROWS
## Tamanho da caixa (largura, altura, espessura) e espaço entre os centros.
const BOX_SIZE: Vector3 = Vector3(0.4, 0.6, 0.06)
const BOX_STEP: Vector2 = Vector2(0.52, 0.72)
## Ordem em que as fileiras se enchem (0 = a de baixo): primeiro a da altura
## dos olhos, depois a de cima e por último a de baixo. Assim, com poucos
## jogos, os mais recentes ficam bem na frente de quem olha.
const ROW_ORDER: Array[int] = [1, 2, 0]
## Altura do centro da fileira de baixo; as outras sobem de BOX_STEP.y.
const FIRST_ROW_Y: float = 0.8
## Segundos segurando E até o jogo abrir.
const HOLD_SECONDS: float = 1.2
## Segundos para a tela clarear quando o jogador volta do jogo.
const RETURN_FADE_TIME: float = 0.8
## Onde o jogador reaparece (na frente da estante, olhando para ela).
const RETURN_SPOT: Vector3 = Vector3(0.0, 0.1, 2.5)
const PANEL_COLOR: Color = Color(0.16, 0.11, 0.08)
const FRAME_WOOD: Color = Color(0.3, 0.19, 0.11)
const FILTER_ALL: String = ""

var _page: int = 0
var _filter: String = FILTER_ALL
## App IDs do filtro atual, em ordem de "jogado por último".
var _app_ids: Array[int] = []
var _slots: Node3D
var _page_label: Label3D
var _filter_label: Label3D
## Caixa de cada jogo da página atual (para a capa entrar quando chegar).
var _boxes_by_app: Dictionary[int, ShelfBox] = {}
## true entre chamar GameLauncher.launch() e receber session_ended.
var _waiting_for_game: bool = false


func _ready() -> void:
	add_to_group("library_shelf")
	_build_frame()
	_slots = Node3D.new()
	_slots.name = "Slots"
	add_child(_slots)
	_build_buttons()
	GameLauncher.session_ended.connect(_on_session_ended)
	GameArt.art_ready.connect(_on_art_ready)
	refresh()


# --- Contrato com a casa e com os testes ----------------------------------------

## Monta de novo a lista (jogos, ordem, filtro) e a página atual.
func refresh() -> void:
	_app_ids = _sorted_app_ids(_filter)
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


## App IDs das caixas que aparecem agora.
func get_visible_app_ids() -> Array[int]:
	var ids: Array[int] = []
	for box in _slots.get_children():
		if box is ShelfBox:
			ids.append((box as ShelfBox).app_id)
	return ids


func get_box(app_id: int) -> ShelfBox:
	return _boxes_by_app.get(app_id)


func next_page() -> void:
	_set_page((_page + 1) % get_page_count())


func previous_page() -> void:
	_set_page((_page - 1 + get_page_count()) % get_page_count())


## Passa para o próximo filtro: Todos → cada bairro que existe → Todos.
func next_filter() -> void:
	var options := get_filter_options()
	var index := options.find(_filter)
	set_filter(options[(index + 1) % options.size()])


func set_filter(category_id: String) -> void:
	_filter = category_id
	_page = 0
	refresh()


## "" (todos) e os bairros que têm pelo menos um jogo instalado.
func get_filter_options() -> Array[String]:
	var options: Array[String] = [FILTER_ALL]
	var present := {}
	for game in SteamLibrary.get_installed_games():
		present[GameCategories.get_category_id(game.app_id)] = true
	for id in GameCategories.get_category_ids():
		if present.has(id):
			options.append(id)
	return options


## Onde o jogador fica ao voltar de um jogo aberto daqui.
func get_return_transform() -> Transform3D:
	return Transform3D(global_basis, to_global(RETURN_SPOT))


# --- Caixas ---------------------------------------------------------------------

## Os jogos instalados do bairro (ou de todos), do jogado mais recente ao mais
## antigo; empate (ou nunca jogado) por nome.
func _sorted_app_ids(category_id: String) -> Array[int]:
	var games: Array[SteamGame] = []
	for game in SteamLibrary.get_installed_games():
		if category_id.is_empty() or GameCategories.get_category_id(game.app_id) == category_id:
			games.append(game)
	games.sort_custom(func(a: SteamGame, b: SteamGame) -> bool:
		var played_a := SteamLibrary.get_last_played(a.app_id)
		var played_b := SteamLibrary.get_last_played(b.app_id)
		if played_a != played_b:
			return played_a > played_b
		return a.name.naturalnocasecmp_to(b.name) < 0)
	var ids: Array[int] = []
	for game in games:
		ids.append(game.app_id)
	return ids


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
		var box := ShelfBox.new()
		box.shelf = self
		box.app_id = _app_ids[first + i]
		box.position = Vector3(-width / 2.0 + column * BOX_STEP.x, FIRST_ROW_Y + row * BOX_STEP.y, BOX_SIZE.z / 2.0 + 0.04)
		_slots.add_child(box)
		_boxes_by_app[box.app_id] = box
	_page_label.text = "%d / %d" % [_page + 1, get_page_count()]
	_filter_label.text = "TODOS OS JOGOS" if _filter.is_empty() else GameCategories.get_category_name(_filter).to_upper()


func _on_art_ready(app_id: int, _texture: Texture2D) -> void:
	var box: ShelfBox = _boxes_by_app.get(app_id)
	if box != null:
		box.show_art()


# --- Abrir o jogo ---------------------------------------------------------------

## A caixa está sendo segurada: a vinheta escurece na cor do bairro.
func _on_box_hold(box: ShelfBox, ratio: float) -> void:
	if _waiting_for_game:
		return
	var neon := GameCategories.get_neon_color(GameCategories.get_category_id(box.app_id))
	ScreenFade.set_door_charge(ratio, GameInfo.game_name(box.app_id), neon)


func _on_box_opened(box: ShelfBox) -> void:
	if _waiting_for_game:
		return
	_waiting_for_game = true
	ScreenFade.set_door_charge(0.0)  # a vinheta já está toda preta: troca pela cortina
	ScreenFade.set_amount(1.0)
	GameLauncher.launch(box.app_id, self)


func _on_session_ended(_app_id: int, source: Node, _success: bool, _message: String) -> void:
	if source != self:
		return
	_waiting_for_game = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.teleport_to(get_return_transform())
	# Se o hub nem chegou a dormir (ex.: o jogo não está mais instalado),
	# quem escureceu a tela foi a estante, então ela mesma clareia.
	if not HubWindow.is_sleeping:
		ScreenFade.fade_in(RETURN_FADE_TIME)


# --- Montagem -------------------------------------------------------------------

## O móvel: fundo, laterais, tampo, rodapé e uma prateleira embaixo de cada
## fileira de caixas, em madeira. O fundo e as laterais têm colisão (o
## jogador não atravessa a estante); as prateleiras não, para não esconder as
## capas do raio do olhar.
func _build_frame() -> void:
	var width := (COLUMNS - 1) * BOX_STEP.x + 0.8
	var top := FIRST_ROW_Y + (ROWS - 1) * BOX_STEP.y + BOX_SIZE.y / 2.0 + 0.12
	var depth := 0.26
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
## alto da estante, o nome do filtro de agora ("TODOS OS JOGOS", "CARTAS…").
func _build_buttons() -> void:
	_page_label = _make_label("1 / 1", Vector3(0.0, 0.3, 0.1))
	var top := FIRST_ROW_Y + (ROWS - 1) * BOX_STEP.y + BOX_SIZE.y / 2.0 + 0.12
	_filter_label = _make_label("TODOS OS JOGOS", Vector3(0.0, top + 0.03, 0.29))
	_filter_label.font_size = 40
	_add_button("PrevPage", "<", "Página anterior", Vector3(-0.55, 0.3, 0.1), previous_page)
	_add_button("NextPage", ">", "Próxima página", Vector3(0.55, 0.3, 0.1), next_page)
	_add_button("Filter", "Bairro", "Trocar o bairro", Vector3(1.55, 0.3, 0.1), next_filter)


func _make_label(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0035
	label.modulate = Color(1.0, 0.85, 0.65)
	label.outline_size = 8
	label.position = at
	label.layers = Home.INTERIOR_LAYER_MASK
	add_child(label)
	return label


func _add_button(button_name: String, text: String, hint: String, at: Vector3, action: Callable) -> void:
	var button := ShelfButton.new()
	button.name = button_name
	button.text = text
	button.hint = hint
	button.action = action
	button.position = at
	add_child(button)


# --- Peças ----------------------------------------------------------------------

## Uma caixa de jogo: a capa na frente, o cartão do jogo ao olhar e E segurado
## para abrir. Fica na camada 3 (olhável), como o LookArea do portal.
class ShelfBox extends Area3D:
	var shelf: LibraryShelf
	var app_id: int = 0
	var _front: MeshInstance3D
	var _title: Label3D

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = BOX_SIZE + Vector3(0.0, 0.0, 0.08)
		shape.shape = box
		add_child(shape)
		_front = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = BOX_SIZE
		_front.mesh = mesh
		add_child(_front)
		_title = Label3D.new()
		_title.font_size = 32
		_title.pixel_size = 0.0035
		_title.width = 100.0
		_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_title.position = Vector3(0.0, 0.0, BOX_SIZE.z / 2.0 + 0.005)
		_title.text = GameInfo.game_name(app_id)
		_front.add_child(_title)
		for node: GeometryInstance3D in [_front, _title]:
			node.layers = Home.INTERIOR_LAYER_MASK
		show_art()

	## Põe a capa (se já tivermos); sem capa, a caixa mostra o nome em texto.
	func show_art() -> void:
		var material := StandardMaterial3D.new()
		material.roughness = 0.6
		var art := GameArt.get_art(app_id)
		if art != null:
			material.albedo_texture = art
			_title.visible = false
		else:
			var neon := GameCategories.get_neon_color(GameCategories.get_category_id(app_id))
			material.albedo_color = neon.darkened(0.6)
			_title.visible = true
		_front.material_override = material

	func get_look_info() -> Dictionary:
		var info := GameInfo.look_info(app_id)
		info["action"] = "Segure E para jogar"
		return info

	func get_hold_seconds() -> float:
		return HOLD_SECONDS

	func set_hold(ratio: float) -> void:
		shelf._on_box_hold(self, ratio)

	func interact(_player: Node) -> void:
		shelf._on_box_opened(self)


## Uma placa de apertar E (passar página, trocar filtro).
class ShelfButton extends Area3D:
	var text: String = ""
	var hint: String = ""
	var action: Callable

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		var size := Vector3(0.4, 0.22, 0.05)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size + Vector3(0.0, 0.0, 0.08)
		shape.shape = box
		add_child(shape)
		var plate := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		plate.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.25, 0.2, 0.15)
		plate.material_override = material
		plate.layers = Home.INTERIOR_LAYER_MASK
		add_child(plate)
		var label := Label3D.new()
		label.text = text
		label.font_size = 48
		label.pixel_size = 0.0035
		label.modulate = Color(1.0, 0.85, 0.65)
		label.position = Vector3(0.0, 0.0, size.z / 2.0 + 0.005)
		label.layers = Home.INTERIOR_LAYER_MASK
		add_child(label)

	func get_look_info() -> Dictionary:
		return {"title": hint, "action": "E para usar"}

	func interact(_player: Node) -> void:
		action.call()
