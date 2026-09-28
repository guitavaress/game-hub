class_name CitySkyline
extends Node3D
## O horizonte da cidade: um anel de silhuetas de prédios a 400 m, que cobre
## os morros da foto do céu, e um chão escuro até lá (a cidade deixa de
## parecer uma maquete flutuando na vista de cima).
##
## A imagem das silhuetas é desenhada por código uma vez (2048 x 256): prédios
## de alturas e larguras sorteadas, com janelinhas. O shader (skyline.gdshader)
## pinta tudo numa cor só, tirada da neblina da hora (azul-acinzentado de dia,
## quente no pôr do sol, quase preto à noite) e acende algumas janelas à noite.
##
## É só cenário: um cilindro sem tampa, sem luz, sem sombra e sem colisão.

const RADIUS: float = 400.0
const HEIGHT: float = 120.0
## Altura do chão, contada do topo do cilindro (o resto fica abaixo do chão).
const TOP: float = 70.0
const TEXTURE_SIZE: Vector2i = Vector2i(2048, 256)
const BUILDING_HEIGHT_RANGE: Vector2 = Vector2(14.0, 62.0)
const BUILDING_WIDTH_RANGE: Vector2i = Vector2i(10, 36)  # em pixels (1 px = 1,2 m)
## Parte das janelas da skyline que acende à noite.
const LIT_WINDOWS: float = 0.1
const NIGHT_COLOR: Color = Color("0B0D14")
const OUTSKIRTS_SIZE: float = RADIUS * 2.2
const OUTSKIRTS_COLOR: Color = Color("15171C")
const SHADER: Shader = preload("res://worlds/city/skyline.gdshader")
const COLOR_UPDATE_SECONDS: float = 0.5

## A neblina da cidade dá a cor do horizonte (a cidade preenche antes).
var environment: Environment

var _material: ShaderMaterial
var _since_update: float = 0.0
var _night: float = 0.0


func _ready() -> void:
	add_to_group("city_night")
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("silhouettes", _make_texture())
	_material.set_shader_parameter("night_color", NIGHT_COLOR)
	_material.set_shader_parameter("ring_height", HEIGHT)

	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = HEIGHT
	mesh.radial_segments = 64
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	ring.mesh = mesh
	ring.material_override = _material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, TOP - HEIGHT / 2.0, 0.0)
	add_child(ring)

	# Chão escuro até o anel (fica um pouco abaixo do chão da cidade).
	var outskirts := MeshInstance3D.new()
	outskirts.name = "Outskirts"
	var plane := PlaneMesh.new()
	plane.size = Vector2(OUTSKIRTS_SIZE, OUTSKIRTS_SIZE)
	outskirts.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = OUTSKIRTS_COLOR
	ground.roughness = 1.0
	outskirts.material_override = ground
	outskirts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outskirts.position = Vector3(0.0, -0.05, 0.0)
	add_child(outskirts)
	_update_color()


## Cor das silhouetas acompanha a neblina (que muda com a hora).
func _process(delta: float) -> void:
	_since_update += delta
	if _since_update >= COLOR_UPDATE_SECONDS:
		_since_update = 0.0
		_update_color()


func set_night(night: float) -> void:
	_night = night
	_update_color()


func _update_color() -> void:
	if _material == null:
		return
	var haze := Color(0.62, 0.66, 0.72)
	if environment != null:
		haze = environment.fog_light_color
	# Mais escuro e menos colorido que a neblina: silhuetas contra o céu (no
	# pôr do sol, sem virar prédios cor de laranja).
	var gray := Color(haze.get_luminance(), haze.get_luminance(), haze.get_luminance())
	_material.set_shader_parameter("haze_color", haze.lerp(gray, 0.5).darkened(0.4))
	_material.set_shader_parameter("night", smoothstep(0.3, 0.9, _night))


## Desenha a imagem: vermelho = tem prédio; verde = janela (acesa à noite se
## o azul também for 1). A parte de baixo (abaixo do chão) é toda "prédio".
static func _make_texture() -> ImageTexture:
	var image := Image.create(TEXTURE_SIZE.x, TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))
	var meters_per_pixel_y := HEIGHT / TEXTURE_SIZE.y
	var ground_row := int(TOP / meters_per_pixel_y)
	# Abaixo do chão: tudo coberto.
	image.fill_rect(Rect2i(0, ground_row, TEXTURE_SIZE.x, TEXTURE_SIZE.y - ground_row), Color(1.0, 0.0, 0.0, 1.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var x := 0
	while x < TEXTURE_SIZE.x:
		var width := rng.randi_range(BUILDING_WIDTH_RANGE.x, BUILDING_WIDTH_RANGE.y)
		width = mini(width, TEXTURE_SIZE.x - x)
		# Alturas: a maioria baixa, poucas torres.
		var height_m := lerpf(BUILDING_HEIGHT_RANGE.x, BUILDING_HEIGHT_RANGE.y, pow(rng.randf(), 1.6))
		var top_row := ground_row - int(height_m / meters_per_pixel_y)
		image.fill_rect(Rect2i(x, top_row, width, ground_row - top_row), Color(1.0, 0.0, 0.0, 1.0))
		# Janelas: 2 x 3 px a cada 4 x 7 px, deixando uma borda.
		for wy in range(top_row + 3, ground_row - 4, 7):
			for wx in range(x + 2, x + width - 3, 4):
				var lit := 1.0 if rng.randf() < LIT_WINDOWS else 0.0
				image.fill_rect(Rect2i(wx, wy, 2, 3), Color(1.0, 1.0, lit, 1.0))
		# Um vão entre alguns prédios.
		x += width + (rng.randi_range(1, 6) if rng.randf() < 0.35 else 0)
	return ImageTexture.create_from_image(image)
