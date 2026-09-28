class_name FriendNpc
extends Node3D
## Um amigo da Steam "em pessoa", como HOLOGRAMA: um corpo de gente (modelo
## CC0 da Quaternius) translúcido, na cor do status, parado e "respirando"
## (animação Idle), flutuando 4 cm sobre um pequeno projetor. O avatar da Steam
## vira o rosto; quem não tem avatar próprio fica com a cabeça lisa. Em cima,
## o nome e o status numa plaquinha escura (legível de dia; some de longe).
## O projetor faz um zumbido baixinho, que só se ouve de perto.
##
## Uso:  var npc := FriendNpc.new();  npc.friend = ficha;  add_child(npc)
## A origem deste nó fica no chão, no centro do projetor; o amigo olha para +Z.
##
## Olhar para ele (raio da câmera) mostra "Nome — status" no HUD, pelo mesmo
## "contrato" dos portais: o método get_look_label().

const HOLOGRAM_SHADER: Shader = preload("res://components/friend_npc/hologram.gdshader")
const BODY_SCENE: PackedScene = preload("res://assets/quaternius/animated_human.glb")
const HUM_SOUND: AudioStream = preload("res://assets/kenney/sci-fi-sounds/forceField_000.ogg")
const IDLE_ANIMATION: String = "Human Armature|Idle"
## Altura do corpo (m) e quanto ele flutua acima do projetor.
const FIGURE_HEIGHT: float = 1.7
const FIGURE_BASE: float = 0.105  # topo do projetor (0,065) + 4 cm
const TOTAL_HEIGHT: float = 1.8
const COLLISION_RADIUS: float = 0.35
const AVATAR_SIZE: float = 0.22   # metros
## O avatar fica um pouco à frente do centro da cabeça.
const AVATAR_FORWARD: float = 0.12
## Largura máxima do texto de status (quebra em linhas se passar disso).
const STATUS_MAX_WIDTH: float = 2.2   # metros
## Nome e plaquinha somem a partir desta distância (m).
const LABEL_MAX_DISTANCE: float = 20.0
const PLATE_COLOR: Color = Color(9.0 / 255.0, 10.0 / 255.0, 13.0 / 255.0, 0.72)
const PLATE_PADDING: Vector2 = Vector2(0.12, 0.06)
const STATUS_COLOR_PLAYING: Color = Color("5fe3a1")
const STATUS_COLOR_ONLINE: Color = Color("6fb7ff")
const STATUS_COLOR_AWAY: Color = Color("8a96a8")

var friend: SteamFriend
## Mostrar o nome do jogo no rótulo? Na porta do próprio jogo é redundante
## (o letreiro do prédio já diz), então lá o rótulo fica só "Jogando agora".
var show_game_name: bool = true

var _avatar: Sprite3D
var _figure: Node3D
var _skeleton: Skeleton3D
var _head_bone: int = -1
var _phase: float = 0.0


func _ready() -> void:
	_phase = float(posmod(hash(friend.steam_id), 1000)) / 1000.0 * TAU
	_build_collision()
	_build_projector()
	_build_figure()
	_build_labels()
	_build_hum()


func _process(_delta: float) -> void:
	# Flutua bem pouquinho (cada amigo num ritmo diferente); a respiração vem
	# da animação.
	_figure.position.y = FIGURE_BASE + 0.015 * sin(Time.get_ticks_msec() / 1000.0 * 1.2 + _phase)
	# O rosto (avatar) acompanha a cabeça, que mexe com a respiração.
	if _head_bone != -1 and _avatar.visible:
		var head := _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone)
		_avatar.global_position = head.origin + global_basis.z * AVATAR_FORWARD


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
	metal.albedo_color = Color("1A1D22")
	metal.metallic = 0.8
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


## O corpo do holograma (modelo com animação) e o avatar no lugar do rosto.
func _build_figure() -> void:
	_figure = Node3D.new()
	_figure.position.y = FIGURE_BASE
	add_child(_figure)

	var body := BODY_SCENE.instantiate() as Node3D
	_figure.add_child(body)
	var hologram := ShaderMaterial.new()
	hologram.shader = HOLOGRAM_SHADER
	hologram.set_shader_parameter("color", _status_color())
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = hologram
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_head_bone = _skeleton.find_bone("Head")
	_fit_body(body)

	# Respirando: a animação Idle, em loop, cada amigo começando num ponto.
	var player := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if player.has_animation(IDLE_ANIMATION):
		player.get_animation(IDLE_ANIMATION).loop_mode = Animation.LOOP_LINEAR
		player.play(IDLE_ANIMATION)
		player.seek(_phase / TAU * player.current_animation_length, true)

	# Avatar da Steam no lugar do rosto, sempre virado para quem olha.
	_avatar = Sprite3D.new()
	_avatar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_avatar.modulate = Color(1.0, 1.0, 1.0, 0.9)
	_avatar.visible = false
	add_child(_avatar)
	if not friend.has_custom_avatar():
		return  # sem avatar próprio: a cabeça fica lisa (nada de "?")
	var texture := FriendsService.get_avatar(friend)
	if texture != null:
		_show_avatar(texture)
	else:
		FriendsService.avatar_ready.connect(_on_avatar_ready)


## Deixa o corpo com FIGURE_HEIGHT de altura, em pé no chão do _figure e
## olhando para +Z (o modelo vem noutra escala e virado para o lado).
func _fit_body(body: Node3D) -> void:
	var top := _bone_position(_skeleton.find_bone("HeadTop_End"))
	var foot := _bone_position(_skeleton.find_bone("LeftToe_End"))
	var height := top.y - minf(foot.y, _figure.global_position.y)
	if height > 0.01:
		body.scale *= FIGURE_HEIGHT / height
	# Frente = do braço direito para o esquerdo, girado 90° (esquerda x cima).
	var left := _bone_position(_skeleton.find_bone("LeftArm"))
	var right := _bone_position(_skeleton.find_bone("RightArm"))
	var forward := (left - right).cross(Vector3.UP)
	forward.y = 0.0
	if forward.length() > 0.001:
		var local_forward := global_basis.inverse() * forward.normalized()
		body.rotation.y -= atan2(local_forward.x, local_forward.z)


func _bone_position(bone: int) -> Vector3:
	return (_skeleton.global_transform * _skeleton.get_bone_global_rest(bone)).origin


## Nome e status sobre uma plaquinha escura, sempre virados para quem olha.
## Sem contorno (o fundo já dá a leitura) e somem a partir de 20 m.
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
	var status_size := HubFonts.LIGHT.get_multiline_string_size(status, HORIZONTAL_ALIGNMENT_CENTER,
			status_label.width, 40) * status_label.pixel_size
	var name_label := _make_label(friend.name, HubFonts.TEXT, 56, 0.005, Color(0.95, 0.96, 0.98))
	name_label.position = status_label.position + Vector3(0.0, status_size.y + 0.02, 0.0)
	add_child(name_label)
	var name_size := HubFonts.TEXT.get_string_size(friend.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 56) \
			* name_label.pixel_size

	# Plaquinha atrás dos dois textos.
	var plate_size := Vector2(maxf(name_size.x, status_size.x), name_size.y + status_size.y + 0.02) \
			+ PLATE_PADDING * 2.0
	var plate := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = plate_size
	plate.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = PLATE_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.render_priority = -1  # desenhada antes dos textos
	plate.material_override = material
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.visibility_range_end = LABEL_MAX_DISTANCE
	plate.position = status_label.position + Vector3(0.0, plate_size.y / 2.0 - PLATE_PADDING.y, 0.0)
	add_child(plate)


## Zumbido do projetor: bem baixo (-24 dB) e só de perto (até 4 m).
func _build_hum() -> void:
	var hum := AudioStreamPlayer3D.new()
	hum.stream = AmbientEmitter.looping(HUM_SOUND)
	hum.bus = &"Ambiente"
	hum.volume_db = -24.0
	hum.pitch_scale = 0.55
	hum.max_distance = 4.0
	hum.unit_size = 1.0
	hum.autoplay = true
	hum.position = Vector3(0.0, 0.1, 0.0)
	add_child(hum)


func _show_avatar(texture: Texture2D) -> void:
	_avatar.texture = texture
	_avatar.pixel_size = AVATAR_SIZE / float(texture.get_width())
	_avatar.visible = true


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
	label.outline_size = 0
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.render_priority = 1
	label.visibility_range_end = LABEL_MAX_DISTANCE
	return label
