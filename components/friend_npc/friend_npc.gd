class_name FriendNpc
extends Node3D
## Um amigo da Steam "em pessoa": um personagem (Kenney Mini Characters, CC0)
## parado e se mexendo de leve (animação "idle"), com o avatar e o nome
## flutuando em cima e uma linha de status ("Jogando Balatro").
##
## Uso:  var npc := FriendNpc.new();  npc.friend = ficha;  add_child(npc)
## A origem deste nó fica nos PÉS do personagem, que olha para +Z.
##
## Olhar para ele (raio da câmera) mostra "Nome — status" no HUD, pelo mesmo
## "contrato" dos portais: o método get_look_label().

## As 12 variações de personagem; cada amigo ganha sempre a mesma (pelo SteamID).
const CHARACTER_MODELS: Array[PackedScene] = [
	preload("res://assets/kenney/mini-characters/character-female-a.glb"),
	preload("res://assets/kenney/mini-characters/character-female-b.glb"),
	preload("res://assets/kenney/mini-characters/character-female-c.glb"),
	preload("res://assets/kenney/mini-characters/character-female-d.glb"),
	preload("res://assets/kenney/mini-characters/character-female-e.glb"),
	preload("res://assets/kenney/mini-characters/character-female-f.glb"),
	preload("res://assets/kenney/mini-characters/character-male-a.glb"),
	preload("res://assets/kenney/mini-characters/character-male-b.glb"),
	preload("res://assets/kenney/mini-characters/character-male-c.glb"),
	preload("res://assets/kenney/mini-characters/character-male-d.glb"),
	preload("res://assets/kenney/mini-characters/character-male-e.glb"),
	preload("res://assets/kenney/mini-characters/character-male-f.glb"),
]
## Os modelos têm ~0,78 de altura; com esta escala ficam com ~1,75 m.
const MODEL_SCALE: float = 2.25
const MODEL_HEIGHT: float = 1.75
const COLLISION_RADIUS: float = 0.35
const AVATAR_SIZE: float = 0.5   # metros
## Largura máxima do texto de status (quebra em linhas se passar disso).
const STATUS_MAX_WIDTH: float = 2.2   # metros
const STATUS_COLOR_PLAYING: Color = Color("8fd66b")
const STATUS_COLOR_ONLINE: Color = Color("6fb7ff")
const STATUS_COLOR_AWAY: Color = Color("b0b0b0")

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
	capsule.radius = COLLISION_RADIUS
	capsule.height = MODEL_HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, MODEL_HEIGHT / 2.0, 0.0)
	body.add_child(shape)
	add_child(body)

	# O sorteio usa o SteamID como semente: cada amigo tem sempre o mesmo visual.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(friend.steam_id)
	var model := CHARACTER_MODELS[rng.randi_range(0, CHARACTER_MODELS.size() - 1)].instantiate() as Node3D
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)

	var animation := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null and animation.has_animation("idle"):
		# As animações vêm do modelo sem repetir; "idle" precisa ficar em loop.
		animation.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		animation.play("idle")
		# Cada um começa num ponto diferente, para não "respirarem" juntos.
		animation.seek(rng.randf() * animation.current_animation_length)


func _build_labels() -> void:
	var status := friend.status_text()
	if friend.is_playing() and not show_game_name:
		status = "Jogando agora"
	var status_label := _make_label(status, 48, 0.004, _status_color())
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.width = STATUS_MAX_WIDTH / status_label.pixel_size
	status_label.position = Vector3(0.0, MODEL_HEIGHT + AVATAR_SIZE + 0.25, 0.0)
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
	_avatar.position = Vector3(0.0, MODEL_HEIGHT + AVATAR_SIZE / 2.0 + 0.15, 0.0)
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
