class_name MetroEntrance
extends TransitStop
## Estação de METRÔ da cidade (Fase 8): a BOCA da estação em volta de uma
## TransitStop (a lógica de entrar e viajar fica nela).
##
## Peças (origem no chão, na linha da fachada; +Z = para a rua):
##   - a ESCADA que desce para trás (-Z). O chão não é cortado: um shader
##     (metro_stairs.gdshader) desenha os degraus descendo no escuro, como se
##     houvesse um poço ali (mais barato e sem risco de cair no "buraco");
##   - GUARDA-CORPO nos dois lados e no fundo: mureta baixa, postes e
##     corrimão com um filete na cor da linha (sólido: só se entra pela frente);
##   - TOTEM na quina da frente, com a placa "M" e o nome da estação.
## A entrada (pisar e abrir o painel) é o topo da escada.

## Vão da escada: largura e comprimento (para trás).
const OPENING: Vector2 = Vector2(1.6, 2.6)
const STEPS: int = 7
const RAIL_HEIGHT: float = 1.0
const RAIL_THICKNESS: float = 0.08
const CURB_HEIGHT: float = 0.3
const RAIL_POST_SPACING: float = 0.65
## Altura do desenho da escada (acima das calçadas e dos pisos de praça).
const FLOOR_Y: float = 0.085
const POST_SIZE: Vector3 = Vector3(0.22, 2.7, 0.22)
const SIGN_SIZE: Vector3 = Vector3(0.8, 0.8, 0.12)
const METAL_COLOR: Color = Color("1A1D22")
const CURB_COLOR: Color = Color(0.5, 0.5, 0.49)
const NEON_DAY: float = 0.5
const NEON_NIGHT: float = 1.3
## Luz dentro da escada: de dia e de noite.
const STAIRS_DAY: float = 1.0
const STAIRS_NIGHT: float = 0.45
const STAIRS_SHADER: Shader = preload("res://worlds/city/metro_stairs.gdshader")

var _sign_material: StandardMaterial3D
var _strip_material: StandardMaterial3D
var _stairs_material: ShaderMaterial


func _ready() -> void:
	entry_offset = -0.6  # o topo da escada
	super()
	add_to_group("city_night")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.7
	metal.roughness = 0.4
	_strip_material = _neon_material()
	_sign_material = _neon_material()

	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	_build_stairs()
	_build_rails(body, metal)
	_build_totem(body, metal)


## 0 = dia, 1 = noite: placa e filetes acendem mais à noite (grupo "city_night").
func set_night(night: float) -> void:
	var amount := clampf(night, 0.0, 1.0)
	for material in [_sign_material, _strip_material]:
		if material != null:
			material.emission_energy_multiplier = lerpf(NEON_DAY, NEON_NIGHT, amount)
	if _stairs_material != null:
		_stairs_material.set_shader_parameter("light", lerpf(STAIRS_DAY, STAIRS_NIGHT, amount))


## Retângulo (no chão, em coordenadas da estação) que a boca ocupa, com o
## totem. Para os testes conferirem que nada encosta nela.
static func footprint() -> Rect2:
	var half := OPENING.x / 2.0 + RAIL_THICKNESS
	return Rect2(-half - POST_SIZE.x - 0.3, -OPENING.y - RAIL_THICKNESS, (half + POST_SIZE.x + 0.3) * 2.0, OPENING.y + RAIL_THICKNESS + 0.6)


# --- Peças ----------------------------------------------------------------------

## A escada: um retângulo no chão com o shader que desenha o poço e os degraus.
func _build_stairs() -> void:
	var hole := MeshInstance3D.new()
	hole.name = "Stairs"
	var quad := QuadMesh.new()
	quad.size = OPENING
	quad.orientation = PlaneMesh.FACE_Y
	hole.mesh = quad
	_stairs_material = ShaderMaterial.new()
	_stairs_material.shader = STAIRS_SHADER
	_stairs_material.set_shader_parameter("opening", OPENING)
	_stairs_material.set_shader_parameter("step_depth", OPENING.y / STEPS)
	_stairs_material.set_shader_parameter("glow_color", color)
	hole.material_override = _stairs_material
	hole.position = Vector3(0.0, FLOOR_Y, -OPENING.y / 2.0)
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hole)


## Guarda-corpo nos dois lados e no fundo: mureta, postes e corrimão (com o
## filete da linha). A colisão é uma parede inteira, invisível: não dá para
## pular para dentro do poço pelos lados.
func _build_rails(body: StaticBody3D, metal: Material) -> void:
	var curb := StandardMaterial3D.new()
	curb.albedo_color = CURB_COLOR
	curb.roughness = 0.9
	var half := OPENING.x / 2.0 + RAIL_THICKNESS / 2.0
	var length := OPENING.y + RAIL_THICKNESS
	var sides: Array[Array] = [
		# [centro, comprimento, girado 90°?]
		[Vector3(-half, 0.0, -length / 2.0), length, false],
		[Vector3(half, 0.0, -length / 2.0), length, false],
		[Vector3(0.0, 0.0, -OPENING.y - RAIL_THICKNESS / 2.0), OPENING.x + RAIL_THICKNESS * 2.0, true],
	]
	for side in sides:
		var center: Vector3 = side[0]
		var run: float = side[1]
		var across: bool = side[2]
		var size_of := func(along: float, height: float) -> Vector3:
			return Vector3(along, height, RAIL_THICKNESS) if across else Vector3(RAIL_THICKNESS, height, along)
		_add_collision(body, center + Vector3(0.0, RAIL_HEIGHT / 2.0, 0.0), size_of.call(run, RAIL_HEIGHT))
		_add_mesh(center + Vector3(0.0, CURB_HEIGHT / 2.0, 0.0), size_of.call(run, CURB_HEIGHT) + Vector3(0.04, 0.0, 0.04), curb)
		_add_mesh(center + Vector3(0.0, RAIL_HEIGHT - 0.03, 0.0), size_of.call(run, 0.06), metal)
		_add_mesh(center + Vector3(0.0, RAIL_HEIGHT + 0.01, 0.0), size_of.call(run, 0.03) + Vector3(0.01, 0.0, 0.01), _strip_material)
		var posts := maxi(2, roundi(run / RAIL_POST_SPACING) + 1)
		for i in posts:
			var along := -run / 2.0 + run * float(i) / float(posts - 1)
			var offset := Vector3(along, 0.0, 0.0) if across else Vector3(0.0, 0.0, along)
			_add_mesh(center + offset + Vector3(0.0, (RAIL_HEIGHT + CURB_HEIGHT) / 2.0, 0.0),
					Vector3(0.04, RAIL_HEIGHT - CURB_HEIGHT, 0.04), metal)


## Totem na quina da frente: poste, placa "M" (dos dois lados) e o nome.
func _build_totem(body: StaticBody3D, metal: Material) -> void:
	var x := OPENING.x / 2.0 + RAIL_THICKNESS + POST_SIZE.x / 2.0 + 0.1
	var post_at := Vector3(x, POST_SIZE.y / 2.0, 0.15)
	_add_box(body, post_at, POST_SIZE, metal, true)
	var sign_y := POST_SIZE.y + SIGN_SIZE.y / 2.0 - 0.05
	_add_box(body, Vector3(x, sign_y, 0.15), SIGN_SIZE, _sign_material, false)
	for side in [1.0, -1.0]:
		var letter := Label3D.new()
		letter.text = "M"
		letter.font_size = 96
		letter.pixel_size = 0.0055
		letter.outline_size = 0
		# Letra clara na placa colorida; escura se a placa for clara (a Central).
		letter.modulate = Color(0.06, 0.06, 0.08) if color.get_luminance() > 0.6 else Color.WHITE
		letter.double_sided = false  # a de trás não vaza pela placa
		letter.position = Vector3(x, sign_y, 0.15 + side * (SIGN_SIZE.z / 2.0 + 0.01))
		letter.rotation.y = 0.0 if side > 0.0 else PI
		add_child(letter)
	# O nome da estação, dos dois lados do poste (na frente dele, não atrás).
	for side in [1.0, -1.0]:
		var title := Label3D.new()
		title.name = "StationName" if side > 0.0 else "StationNameBack"
		title.text = stop_name
		title.font_size = 36
		title.pixel_size = 0.0045
		title.outline_size = 10
		title.modulate = Color("F2F4F7")
		title.double_sided = false  # cada lado do poste mostra só o seu
		title.position = Vector3(x, POST_SIZE.y - 0.4, 0.15 + side * (POST_SIZE.z / 2.0 + 0.02))
		title.rotation.y = 0.0 if side > 0.0 else PI
		add_child(title)


func _neon_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = NEON_DAY
	return material


func _add_mesh(center: Vector3, box_size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = center
	add_child(mesh_instance)


func _add_collision(body: StaticBody3D, center: Vector3, box_size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	shape.position = center
	body.add_child(shape)


func _add_box(body: StaticBody3D, center: Vector3, box_size: Vector3, material: Material, solid: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = center
	body.add_child(mesh_instance)
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = box_size
		shape.shape = box
		shape.position = center
		body.add_child(shape)
