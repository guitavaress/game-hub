class_name FriendNpc
extends Node3D
## Um amigo da Steam "em pessoa", como HOLOGRAMA: uma silhueta translúcida
## (corpo e cabeça) sobre um pequeno projetor, na cor do status, com o avatar
## da Steam no lugar do rosto, e o nome e o status flutuando em cima.
##
## Uso:  var npc := FriendNpc.new();  npc.friend = ficha;  add_child(npc)
## A origem deste nó fica no chão, no centro do projetor.
##
## Olhar para ele (raio da câmera) mostra "Nome — status" no HUD, pelo mesmo
## "contrato" dos portais: o método get_look_label().

const HOLOGRAM_SHADER: Shader = preload("res://components/friend_npc/hologram.gdshader")
const BODY_HEIGHT: float = 1.25
const BODY_RADIUS: float = 0.26
const HEAD_RADIUS: float = 0.19
const FIGURE_BASE: float = 0.12   # a silhueta "flutua" um pouco acima do projetor
const TOTAL_HEIGHT: float = 1.8
const COLLISION_RADIUS: float = 0.35
const AVATAR_SIZE: float = 0.34   # metros
## Largura máxima do texto de status (quebra em linhas se passar disso).
const STATUS_MAX_WIDTH: float = 2.2   # metros
const STATUS_COLOR_PLAYING: Color = Color("5fe3a1")
const STATUS_COLOR_ONLINE: Color = Color("6fb7ff")
const STATUS_COLOR_AWAY: Color = Color("8a96a8")

var friend: SteamFriend
## Mostrar o nome do jogo no rótulo? Na porta do próprio jogo é redundante
## (o letreiro do prédio já diz), então lá o rótulo fica só "Jogando agora".
var show_game_name: bool = true

var _avatar: Sprite3D
var _figure: Node3D
var _phase: float = 0.0


func _ready() -> void:
	_phase = float(posmod(hash(friend.steam_id), 1000)) / 1000.0 * TAU
	_build_collision()
	_build_projector()
	_build_figure()
	_build_labels()


func _process(_delta: float) -> void:
	# Flutua devagar para cima e para baixo (cada amigo num ritmo diferente).
	_figure.position.y = FIGURE_BASE + 0.04 * sin(Time.get_ticks_msec() / 1000.0 * 1.4 + _phase)


## Texto do HUD ao olhar para o amigo.
func get_look_label() -> String:
	return "%s — %s" % [friend.name, friend.status_text()]


func _build_collision() -> void:
	# Colisão: o jogador não atravessa o amigo (camada 1 = mundo; o raio da
	# câmera também enxerga essa camada, então dá para "olhar" para ele).
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = COLLISION_RADIUS
	capsule.height = TOTAL_HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, TOTAL_HEIGHT / 2.0, 0.0)
	body.add_child(shape)
	add_child(body)


## Projetor no chão: um disco de metal escuro com um anel de luz.
func _build_projector() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.07, 0.075, 0.08)
	metal.metallic = 0.85
	metal.roughness = 0.35
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.42
	disc_mesh.bottom_radius = 0.46
	disc_mesh.height = 0.06
	disc.mesh = disc_mesh
	disc.position = Vector3(0.0, 0.03, 0.0)
	disc.material_override = metal
	add_child(disc)

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = _status_color()
	ring_material.emission_enabled = true
	ring_material.emission = _status_color()
	ring_material.emission_energy_multiplier = 3.0
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.33
	ring_mesh.outer_radius = 0.37
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, 0.065, 0.0)
	ring.material_override = ring_material
	add_child(ring)


## A silhueta do holograma (corpo + cabeça) e o avatar no lugar do rosto.
func _build_figure() -> void:
	_figure = Node3D.new()
	add_child(_figure)

	var hologram := ShaderMaterial.new()
	hologram.shader = HOLOGRAM_SHADER
	hologram.set_shader_parameter("color", _status_color())

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = BODY_RADIUS
	torso_mesh.height = BODY_HEIGHT
	torso.mesh = torso_mesh
	torso.position = Vector3(0.0, BODY_HEIGHT / 2.0, 0.0)
	torso.material_override = hologram
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_figure.add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = HEAD_RADIUS
	head_mesh.height = HEAD_RADIUS * 2.0
	head.mesh = head_mesh
	head.position = Vector3(0.0, BODY_HEIGHT + HEAD_RADIUS + 0.04, 0.0)
	head.material_override = hologram
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_figure.add_child(head)

	# Avatar da Steam no lugar do rosto, sempre virado para quem olha.
	_avatar = Sprite3D.new()
	_avatar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_avatar.position = head.position
	_avatar.modulate = Color(1.0, 1.0, 1.0, 0.9)
	_figure.add_child(_avatar)
	var texture := FriendsService.get_avatar(friend)
	if texture != null:
		_show_avatar(texture)
	else:
		FriendsService.avatar_ready.connect(_on_avatar_ready)


func _build_labels() -> void:
	var status := friend.status_text()
	if friend.is_playing() and not show_game_name:
		status = "Jogando agora"
	var status_label := _make_label(status, HubFonts.LIGHT, 40, 0.0045, _status_color())
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.width = STATUS_MAX_WIDTH / status_label.pixel_size
	status_label.position = Vector3(0.0, TOTAL_HEIGHT + 0.25, 0.0)
	add_child(status_label)

	# O nome fica logo acima do status (que pode ter mais de uma linha).
	var status_lines := ceili(status.length() * 0.5 * 40 / status_label.width)
	var name_label := _make_label(friend.name, HubFonts.TEXT, 56, 0.005, Color(0.95, 0.96, 0.98))
	name_label.position = status_label.position + Vector3(0.0, 0.05 + 0.2 * maxi(status_lines, 1), 0.0)
	add_child(name_label)


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
func _make_label(text: String, font: Font, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.6)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label
