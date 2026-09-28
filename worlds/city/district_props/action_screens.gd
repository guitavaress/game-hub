class_name ActionScreens
extends Node3D
## Bairro Ação: telões de LED nas quinas dos prédios (3 x 6 m, virados 45°
## para a rua), mostrando os banners dos jogos do bairro. A cada 8 s cada
## telão troca de jogo (com uma transição rápida); a imagem anda devagar de um
## lado para o outro e tem as linhas de um telão (scanlines).
## Reusa o hero (ou a capa) que o prédio já baixou.

const SCREEN_SIZE: Vector2 = Vector2(3.0, 6.0)
const SCREEN_BOTTOM: float = 4.4
const SWITCH_SECONDS: float = 8.0
const BLEND_SECONDS: float = 0.6
const SHADER: Shader = preload("res://worlds/city/district_props/led_screen.gdshader")

## Os prédios do quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []

var _screens: Array[ShaderMaterial] = []
var _arts: Array[Texture2D] = []
var _turn: int = 0


func _ready() -> void:
	add_to_group("city_night")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("1A1D22")
	metal.metallic = 0.8
	metal.roughness = 0.35
	for i in buildings.size():
		var building := buildings[i]
		# Quinas alternadas (direita, esquerda...), na frente do prédio.
		var side := 1.0 if i % 2 == 0 else -1.0
		var corner := Vector3(side * building.size.x / 2.0, 0.0, building.size.z / 2.0)
		var outward := Vector3(side, 0.0, 1.0).normalized()
		var screen_base := Node3D.new()
		screen_base.position = corner + outward * 0.35
		screen_base.rotation.y = atan2(outward.x, outward.z)
		building.add_child(screen_base)

		var frame := MeshInstance3D.new()
		var frame_mesh := BoxMesh.new()
		frame_mesh.size = Vector3(SCREEN_SIZE.x + 0.2, SCREEN_SIZE.y + 0.2, 0.2)
		frame.mesh = frame_mesh
		frame.material_override = metal
		frame.position = Vector3(0.0, SCREEN_BOTTOM + SCREEN_SIZE.y / 2.0, -0.12)
		screen_base.add_child(frame)

		var screen := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = SCREEN_SIZE
		screen.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("pan_offset", float(i) * 2.1)
		screen.material_override = material
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		screen.position = Vector3(0.0, SCREEN_BOTTOM + SCREEN_SIZE.y / 2.0, 0.0)
		screen_base.add_child(screen)
		_screens.append(material)
		building.poster_changed.connect(_collect_arts)

	var timer := Timer.new()
	timer.wait_time = SWITCH_SECONDS
	timer.timeout.connect(_next)
	add_child(timer)
	timer.start()
	_collect_arts()
	set_night(0.0)


## Junta as imagens dos jogos do quarteirão (as que já chegaram).
func _collect_arts() -> void:
	_arts.clear()
	for building in buildings:
		var art := building.get_art_texture()
		if art != null:
			_arts.append(art)
	for i in _screens.size():
		_show(i, false)


## Próximo jogo em cada telão.
func _next() -> void:
	if _arts.size() < 2:
		return
	_turn += 1
	for i in _screens.size():
		_show(i, true)


func _show(index: int, animate: bool) -> void:
	var material := _screens[index]
	if _arts.is_empty():
		material.set_shader_parameter("has_art", false)
		return
	material.set_shader_parameter("has_art", true)
	var art := _arts[(_turn + index) % _arts.size()]
	var aspect := float(art.get_width()) / maxf(art.get_height(), 1.0)
	if not animate:
		material.set_shader_parameter("current_art", art)
		material.set_shader_parameter("current_aspect", aspect)
		material.set_shader_parameter("blend", 0.0)
		return
	material.set_shader_parameter("next_art", art)
	material.set_shader_parameter("next_aspect", aspect)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("blend", value),
			0.0, 1.0, BLEND_SECONDS)
	tween.tween_callback(func() -> void:
		material.set_shader_parameter("current_art", art)
		material.set_shader_parameter("current_aspect", aspect)
		material.set_shader_parameter("blend", 0.0))


func set_night(night: float) -> void:
	for material in _screens:
		material.set_shader_parameter("brightness", lerpf(0.95, 1.3, night))


## Quantos telões este quarteirão tem (para os testes).
func get_screen_count() -> int:
	return _screens.size()
