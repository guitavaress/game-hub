class_name FriendsWall
extends Node3D
## O MURAL DOS AMIGOS (Fase 9.5): um cartão por amigo online (foto, nome,
## situação e jogo), com quem está jogando primeiro. Sem chave ou sem amigos
## online, um cartão avisa para configurar os amigos no computador.
##
## E num amigo leva até a porta do jogo dele (GamePortal.get_arrival_transform).
## Se o jogo não está na biblioteca, leva até onde a porta da rua leva (a praça).
##
## Convenção: a origem fica no chão, no meio do mural, e a FRENTE (+Z) aponta
## para dentro da sala.

const COLUMNS: int = 4
const ROWS: int = 3
const MAX_CARDS: int = COLUMNS * ROWS
const CARD_SIZE: Vector3 = Vector3(1.0, 0.56, 0.05)
const CARD_STEP: Vector2 = Vector2(1.15, 0.7)
## Altura do centro da fileira de baixo.
const FIRST_ROW_Y: float = 1.0
const CORK_COLOR: Color = Color(0.52, 0.36, 0.22)
const FRAME_WOOD: Color = Color(0.3, 0.19, 0.11)
const TITLE_COLOR: Color = Color(1.0, 0.55, 0.85)
const PLAYING_COLOR: Color = Color(0.55, 0.85, 0.35)
const ONLINE_COLOR: Color = Color(0.4, 0.7, 1.0)
const AWAY_COLOR: Color = Color(0.9, 0.7, 0.3)
const TEXT_COLOR: Color = Color(1.0, 0.9, 0.78)

## A porta da rua da casa: o destino de quem joga algo fora da biblioteca.
var fallback_door: TravelDoor

var _cards: Node3D
## Avatar de cada cartão, para a foto entrar quando chegar.
var _avatars: Dictionary[String, MeshInstance3D] = {}


func _ready() -> void:
	add_to_group("friends_wall")
	_build_frame()
	_cards = Node3D.new()
	_cards.name = "Cards"
	add_child(_cards)
	FriendsService.friends_changed.connect(refresh)
	FriendsService.avatar_ready.connect(_on_avatar_ready)
	refresh()


## Os amigos que aparecem: online, jogando primeiro, depois por nome.
static func sorted_friends(friends: Array[SteamFriend]) -> Array[SteamFriend]:
	var result: Array[SteamFriend] = []
	result.append_array(friends)
	result.sort_custom(func(a: SteamFriend, b: SteamFriend) -> bool:
		if a.is_playing() != b.is_playing():
			return a.is_playing()
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return result.slice(0, MAX_CARDS)


func refresh() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_avatars.clear()
	var friends := sorted_friends(FriendsService.get_online_friends())
	if friends.is_empty():
		_add_empty_card()
		return
	for i in friends.size():
		var card := FriendCard.new()
		card.wall = self
		card.friend = friends[i]
		card.position = _slot(i, friends.size())
		_cards.add_child(card)


## Nomes dos cartões de amigo, na ordem do mural.
func get_friend_names() -> Array[String]:
	var names: Array[String] = []
	for card in _cards.get_children():
		if card is FriendCard:
			names.append((card as FriendCard).friend.name)
	return names


func get_card(friend_name: String) -> FriendCard:
	for card in _cards.get_children():
		if card is FriendCard and (card as FriendCard).friend.name == friend_name:
			return card
	return null


func has_empty_card() -> bool:
	return _cards.get_node_or_null("EmptyCard") != null


## Para onde o amigo leva: a porta do jogo dele ou a praça. Ainda sem destino
## (cidade montando) devolve false em "found".
func get_destination(friend: SteamFriend) -> Dictionary:
	if friend.game_id > 0:
		for node in get_tree().get_nodes_in_group("game_portal"):
			var portal := node as GamePortal
			if portal != null and portal.app_id == friend.game_id:
				return {"found": true, "transform": portal.get_arrival_transform(),
						"message": portal.get_game_name(), "to_game": true}
	if fallback_door != null and fallback_door.is_open():
		return {"found": true, "transform": fallback_door.destination, "message": "Praça", "to_game": false}
	return {"found": false}


# --- Montagem -------------------------------------------------------------------

## Posição do cartão número "index": as fileiras se enchem de cima para baixo e
## cada fileira fica centralizada.
func _slot(index: int, total: int) -> Vector3:
	var row := floori(index / float(COLUMNS))
	var in_row := mini(COLUMNS, total - row * COLUMNS)
	var column := index % COLUMNS
	var x := (column - (in_row - 1) / 2.0) * CARD_STEP.x
	return Vector3(x, FIRST_ROW_Y + (ROWS - 1 - row) * CARD_STEP.y, CARD_SIZE.z / 2.0 + 0.04)


func _add_empty_card() -> void:
	var card := EmptyCard.new()
	card.name = "EmptyCard"
	card.problem = FriendsService.get_problem()
	card.position = Vector3(0.0, FIRST_ROW_Y + CARD_STEP.y, CARD_SIZE.z / 2.0 + 0.04)
	_cards.add_child(card)


func _on_avatar_ready(steam_id: String, texture: Texture2D) -> void:
	var quad: MeshInstance3D = _avatars.get(steam_id)
	if quad != null:
		(quad.material_override as StandardMaterial3D).albedo_texture = texture


## O quadro de cortiça com moldura de madeira e o título em cima. O quadro
## tem colisão (o jogador não entra nele).
func _build_frame() -> void:
	var width := (COLUMNS - 1) * CARD_STEP.x + 1.4
	var bottom := FIRST_ROW_Y - CARD_SIZE.y / 2.0 - 0.2
	var top := FIRST_ROW_Y + (ROWS - 1) * CARD_STEP.y + CARD_SIZE.y / 2.0 + 0.32
	var height := top - bottom
	var cork := HomeMaterials.fabric(CORK_COLOR)
	var panel := MeshInstance3D.new()
	panel.name = "Panel"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, 0.06)
	panel.mesh = mesh
	panel.material_override = cork
	panel.position = Vector3(0.0, bottom + height / 2.0, 0.03)
	panel.layers = Home.INTERIOR_LAYER_MASK
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	body.add_child(shape)
	panel.add_child(body)
	add_child(panel)

	# Moldura: quatro ripas de madeira em volta do quadro.
	var wood := HomeMaterials.wood(FRAME_WOOD, false, 0.45)
	var bar := 0.07
	for y in [bottom, top]:
		_frame_bar(Vector3(width + bar * 2.0, bar, 0.08), Vector3(0.0, y, 0.04), wood)
	for x in [-width / 2.0 - bar / 2.0, width / 2.0 + bar / 2.0]:
		_frame_bar(Vector3(bar, height, 0.08), Vector3(x, bottom + height / 2.0, 0.04), wood)

	var title := Label3D.new()
	title.name = "Title"
	title.text = "AMIGOS ONLINE"
	title.font_size = 64
	title.pixel_size = 0.003
	title.modulate = TITLE_COLOR
	title.outline_size = 10
	title.outline_modulate = Color(0.05, 0.03, 0.05)
	title.position = Vector3(0.0, top - 0.17, 0.065)
	title.layers = Home.INTERIOR_LAYER_MASK
	add_child(title)


func _frame_bar(bar_size: Vector3, center: Vector3, material: Material) -> void:
	var bar := MeshInstance3D.new()
	bar.name = "FrameBar"
	var mesh := BoxMesh.new()
	mesh.size = bar_size
	bar.mesh = mesh
	bar.material_override = material
	bar.position = center
	bar.layers = Home.INTERIOR_LAYER_MASK
	add_child(bar)


## Cartões e rótulos: a base (área olhável na camada 3, placa e texto).
static func _look_area(card: Area3D) -> void:
	card.collision_layer = 4
	card.collision_mask = 0
	card.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = CARD_SIZE + Vector3(0.0, 0.0, 0.08)
	shape.shape = box
	card.add_child(shape)


static func _plate(card: Node3D, color: Color) -> void:
	var plate := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = CARD_SIZE
	plate.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	plate.material_override = material
	plate.layers = Home.INTERIOR_LAYER_MASK
	card.add_child(plate)


static func _text(card: Node3D, text: String, at: Vector2, size: int, color: Color, width: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0025
	label.modulate = color
	label.width = width
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector3(at.x, at.y, CARD_SIZE.z / 2.0 + 0.005)
	label.layers = Home.INTERIOR_LAYER_MASK
	card.add_child(label)


# --- Peças ----------------------------------------------------------------------

## Um amigo online: foto, nome, situação (na cor) e jogo.
class FriendCard extends Area3D:
	var wall: FriendsWall
	var friend: SteamFriend

	func _ready() -> void:
		FriendsWall._look_area(self)
		FriendsWall._plate(self, Color(0.2, 0.19, 0.22))
		var accent := _status_color()
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(0.05, CARD_SIZE.y, 0.01)
		bar.mesh = bar_mesh
		var bar_material := StandardMaterial3D.new()
		bar_material.albedo_color = accent
		bar_material.emission_enabled = true
		bar_material.emission = accent
		bar.material_override = bar_material
		bar.position = Vector3(-CARD_SIZE.x / 2.0 + 0.025, 0.0, CARD_SIZE.z / 2.0 + 0.003)
		bar.layers = Home.INTERIOR_LAYER_MASK
		add_child(bar)
		var avatar := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.3, 0.3)
		avatar.mesh = quad
		var avatar_material := StandardMaterial3D.new()
		avatar_material.albedo_color = Color(0.5, 0.5, 0.55)
		avatar_material.albedo_texture = FriendsService.get_avatar(friend)
		avatar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		avatar.material_override = avatar_material
		avatar.position = Vector3(-0.3, 0.09, CARD_SIZE.z / 2.0 + 0.004)
		avatar.layers = Home.INTERIOR_LAYER_MASK
		add_child(avatar)
		wall._avatars[friend.steam_id] = avatar
		FriendsWall._text(self, friend.name, Vector2(-0.12, 0.17), 40, FriendsWall.TEXT_COLOR, 340.0)
		FriendsWall._text(self, friend.status_text(), Vector2(-0.42, -0.14), 30, accent, 340.0)

	func _status_color() -> Color:
		if friend.is_playing():
			return FriendsWall.PLAYING_COLOR
		if friend.status == SteamFriend.Status.AWAY or friend.status == SteamFriend.Status.SNOOZE:
			return FriendsWall.AWAY_COLOR
		return FriendsWall.ONLINE_COLOR

	func get_look_info() -> Dictionary:
		var info := {"title": friend.name, "detail": friend.status_text(), "accent": _status_color()}
		var destination := wall.get_destination(friend)
		if not destination["found"]:
			info["friends"] = "Montando a cidade…"
		elif destination["to_game"]:
			info["action"] = "E para ir até a porta"
		else:
			info["action"] = "E para ir até a praça"
		return info

	func interact(player: Node) -> void:
		var destination := wall.get_destination(friend)
		if destination["found"] and player.has_method("travel_to"):
			player.travel_to(destination["transform"], destination["message"])


## O cartão de "ninguém aqui": sem chave ou sem amigos online.
class EmptyCard extends Area3D:
	var problem: String = ""

	func _ready() -> void:
		FriendsWall._look_area(self)
		FriendsWall._plate(self, Color(0.2, 0.19, 0.22))
		FriendsWall._text(self, "Configure os amigos no computador", Vector2(-0.42, 0.1), 36, FriendsWall.TEXT_COLOR, 340.0)
		FriendsWall._text(self, "Nenhum amigo online", Vector2(-0.42, -0.15), 28, Color(0.7, 0.7, 0.75), 340.0)

	func get_look_info() -> Dictionary:
		return {"title": "Configure os amigos no computador", "detail": "Nenhum amigo online" if problem.is_empty() else problem}
