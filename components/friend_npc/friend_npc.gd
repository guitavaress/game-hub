class_name FriendNpc
extends Node3D
## Um amigo da Steam "em pessoa": um bonequinho feito de formas simples, com o
## avatar e o nome flutuando em cima e uma linha de status ("Jogando Balatro").
##
## Uso:  var npc := FriendNpc.new();  npc.friend = ficha;  add_child(npc)
## A origem deste nó fica nos PÉS do boneco.
##
## Olhar para ele (raio da câmera) mostra "Nome — status" no HUD, pelo mesmo
## "contrato" dos portais: o método get_look_label().

const BODY_RADIUS: float = 0.35
const BODY_HEIGHT: float = 1.3
const HEAD_RADIUS: float = 0.25
const AVATAR_SIZE: float = 0.5   # metros
const STATUS_COLOR_PLAYING: Color = Color("8fd66b")
const STATUS_COLOR_ONLINE: Color = Color("6fb7ff")
const STATUS_COLOR_AWAY: Color = Color("b0b0b0")

## Largura máxima do texto de status (quebra em linhas se passar disso).
const STATUS_MAX_WIDTH: float = 2.2   # metros

var friend: SteamFriend
## Mostrar o nome do jogo no rótulo? Na porta do próprio jogo é redundante
## (a placa do prédio já diz), então lá o rótulo fica só "Jogando agora".
var show_game_name: bool = true

var _avatar: Sprite3D


func _ready() -> void:
	_build_body()
	_build_labels()
	_build_avatar()


## Texto do HUD ao olhar para o amigo.
func get_look_label() -> String:
	return "%s — %s" % [friend.name, friend.status_text()]


func _build_body() -> void:
	# Colisão: o jogador não atravessa o amigo (camada 1 = mundo; o raio da
	# câmera também enxerga essa camada, então dá para "olhar" para ele).
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT + HEAD_RADIUS * 2.0
	shape.shape = capsule
	shape.position = Vector3(0.0, capsule.height / 2.0, 0.0)
	body.add_child(shape)
	add_child(body)

	# Corpo: a cor vem do SteamID, então cada amigo tem sempre a mesma cor.
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = BODY_RADIUS
	torso_mesh.height = BODY_HEIGHT
	torso.mesh = torso_mesh
	torso.position = Vector3(0.0, BODY_HEIGHT / 2.0, 0.0)
	torso.material_override = _make_material(_color_from_id(friend.steam_id))
	add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = HEAD_RADIUS
	head_mesh.height = HEAD_RADIUS * 2.0
	head.mesh = head_mesh
	head.position = Vector3(0.0, BODY_HEIGHT + HEAD_RADIUS - 0.05, 0.0)
	head.material_override = _make_material(Color("f1d3b3"))
	add_child(head)


func _build_labels() -> void:
	var status := friend.status_text()
	if friend.is_playing() and not show_game_name:
		status = "Jogando agora"
	var status_label := _make_label(status, 48, 0.004, _status_color())
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.width = STATUS_MAX_WIDTH / status_label.pixel_size
	status_label.position = Vector3(0.0, BODY_HEIGHT + HEAD_RADIUS * 2.0 + AVATAR_SIZE + 0.2, 0.0)
	add_child(status_label)

	# O nome fica logo acima do status (que pode ter mais de uma linha).
	var status_lines := ceili(status.length() * 0.55 * 48 / status_label.width)
	var name_label := _make_label(friend.name, 64, 0.005, Color.WHITE)
	name_label.position = status_label.position + Vector3(0.0, 0.05 + 0.2 * maxi(status_lines, 1), 0.0)
	add_child(name_label)


func _build_avatar() -> void:
	# Quadrinho com o avatar da Steam, sempre virado para quem olha.
	_avatar = Sprite3D.new()
	_avatar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_avatar.position = Vector3(0.0, BODY_HEIGHT + HEAD_RADIUS * 2.0 + AVATAR_SIZE / 2.0 + 0.1, 0.0)
	add_child(_avatar)

	var texture := FriendsService.get_avatar(friend)
	if texture != null:
		_show_avatar(texture)
	else:
		FriendsService.avatar_ready.connect(_on_avatar_ready)


func _show_avatar(texture: Texture2D) -> void:
	_avatar.texture = texture
	_avatar.pixel_size = AVATAR_SIZE / float(texture.get_width())


func _on_avatar_ready(steam_id: String, texture: Texture2D) -> void:
	if steam_id == friend.steam_id:
		_show_avatar(texture)
		FriendsService.avatar_ready.disconnect(_on_avatar_ready)


func _status_color() -> Color:
	if friend.is_playing():
		return STATUS_COLOR_PLAYING
	if friend.status in [SteamFriend.Status.AWAY, SteamFriend.Status.SNOOZE]:
		return STATUS_COLOR_AWAY
	return STATUS_COLOR_ONLINE


## Texto flutuante, sempre virado para quem olha, com a base na altura dada.
func _make_label(text: String, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.outline_size = 12
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


## Uma cor viva diferente para cada SteamID (sempre a mesma para o mesmo amigo).
## O sorteador "embaralha" o número, para IDs parecidos darem cores bem diferentes.
func _color_from_id(steam_id: String) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(steam_id)
	return Color.from_hsv(rng.randf(), 0.6, 0.85)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
