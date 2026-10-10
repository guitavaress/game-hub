class_name HomeDoorFacade
extends Node3D
## A FACHADA da porta "Casa" na praça (Fase 9.10): um quiosque de tijolo, do
## tamanho de uma entrada de prédio, com a porta de madeira, uma marquise com
## luz quente e uma placa de néon "CASA" em cima dela. A lógica de entrar fica
## no TravelDoor (no mesmo lugar); aqui é só a aparência e a colisão.
##
## Convenção (igual à do TravelDoor): a origem fica no CHÃO, no meio da porta,
## e a FRENTE (+Z) aponta para a praça. O quiosque fica para trás (-Z).
## set_night(0..1) acende o néon, a janelinha da porta e a luz da marquise
## (grupo "city_night", como os postes).

## Corpo de tijolo: largura, altura e profundidade (para trás da porta).
const BODY_SIZE: Vector3 = Vector3(2.6, 3.0, 1.6)
## Porta de madeira e o batente de pedra em volta.
const DOOR_SIZE: Vector2 = Vector2(1.2, 2.3)
const TRIM_WIDTH: float = 0.16
## Marquise: largura, espessura, quanto avança para a frente e a altura de baixo.
const CANOPY_SIZE: Vector3 = Vector3(3.0, 0.12, 1.1)
const CANOPY_BOTTOM: float = 2.7
## Placa de néon em cima da marquise: altura das letras.
const SIGN_TEXT_HEIGHT: float = 0.42
const SIGN_FONT_SIZE: int = 96
const NEON_COLOR: Color = Color("FFB347")  # âmbar: a luz de casa
const PLATE_COLOR: Color = Color("16181D")
const WOOD_COLOR: Color = Color(0.24, 0.15, 0.09)
const METAL_COLOR: Color = Color("1A1D22")
## Luz quente embaixo da marquise (só à noite).
const LAMP_COLOR: Color = Color(1.0, 0.78, 0.5)
const LAMP_ENERGY: float = 2.2
const LAMP_RANGE: float = 5.5
## Brilho da janelinha da porta: de dia (quase apagada) e de noite.
const WINDOW_DAY: float = 0.15
const WINDOW_NIGHT: float = 2.5

var _label: Label3D
var _strip_material: StandardMaterial3D
var _window_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D
var _lamp: OmniLight3D


func _ready() -> void:
	add_to_group("city_night")
	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	_build_body(body)
	_build_door()
	_build_canopy(body)
	_build_sign()
	set_night(0.0)


## Retângulo (no chão, em coordenadas da fachada) que o quiosque ocupa, com a
## marquise e a cornija. Para os testes conferirem que nada encosta nele.
static func footprint() -> Rect2:
	var back := BODY_SIZE.z + 0.1  # a cornija passa 10 cm do corpo
	return Rect2(-CANOPY_SIZE.x / 2.0, -back, CANOPY_SIZE.x, back + CANOPY_SIZE.z - 0.1)


## 0 = dia, 1 = noite: o néon, a janelinha e a luz da marquise acendem.
func set_night(night: float) -> void:
	if _label == null:
		return
	var amount := clampf(night, 0.0, 1.0)
	var on := smoothstep(0.3, 0.8, amount)  # a luz acende junto com os postes
	_strip_material.emission_energy_multiplier = CityDecor.neon_energy(amount)
	# O texto não recebe luz (Label3D): de dia, o tubo apagado (mais escuro);
	# à noite passa de 1 e o glow faz o halo.
	var glow := lerpf(0.55, 1.8, amount)
	_label.modulate = Color(NEON_COLOR.r * glow, NEON_COLOR.g * glow, NEON_COLOR.b * glow)
	_window_material.emission_energy_multiplier = lerpf(WINDOW_DAY, WINDOW_NIGHT, on)
	_lamp_material.emission_energy_multiplier = lerpf(0.2, 4.0, on)
	_lamp.visible = on > 0.01
	_lamp.light_energy = LAMP_ENERGY * on


## Força da luz da marquise agora (0 = apagada). Para os testes.
func get_lamp_energy() -> float:
	return _lamp.light_energy if _lamp.visible else 0.0


## Corpo de tijolo (o mesmo dos prédios) e a cornija de concreto em cima.
func _build_body(body: StaticBody3D) -> void:
	var bricks := CityDecor.pbr_material("Bricks097", 2.2, Color(0.9, 0.88, 0.86))
	_add_box(self, BODY_SIZE, Vector3(0.0, BODY_SIZE.y / 2.0, -BODY_SIZE.z / 2.0), bricks)
	var concrete := CityDecor.pbr_material("Concrete034", 2.0, Color(0.72, 0.72, 0.72))
	_add_box(self, Vector3(BODY_SIZE.x + 0.2, 0.15, BODY_SIZE.z + 0.2),
			Vector3(0.0, BODY_SIZE.y + 0.075, -BODY_SIZE.z / 2.0), concrete)
	# Degrau de concreto na frente da porta (fino: não precisa de colisão).
	_add_box(self, Vector3(DOOR_SIZE.x + 0.6, 0.06, 0.6), Vector3(0.0, 0.03, 0.3), concrete)
	# Colisão: o corpo inteiro, até a frente do batente.
	var depth := BODY_SIZE.z + TRIM_WIDTH
	_add_shape(body, Vector3(BODY_SIZE.x, BODY_SIZE.y, depth), Vector3(0.0, BODY_SIZE.y / 2.0, TRIM_WIDTH - depth / 2.0))


## A porta de madeira, a janelinha (luz de dentro, à noite), a maçaneta e o
## batente de pedra em volta.
func _build_door() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD_COLOR
	wood.roughness = 0.6
	_add_box(self, Vector3(DOOR_SIZE.x, DOOR_SIZE.y, 0.06), Vector3(0.0, DOOR_SIZE.y / 2.0, 0.02), wood)

	_window_material = StandardMaterial3D.new()
	_window_material.albedo_color = LAMP_COLOR.darkened(0.5)
	_window_material.roughness = 0.15
	_window_material.emission_enabled = true
	_window_material.emission = LAMP_COLOR
	_add_box(self, Vector3(0.5, 0.62, 0.02), Vector3(0.0, 1.62, 0.06), _window_material)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.62, 0.38)
	metal.metallic = 0.9
	metal.roughness = 0.3
	_add_box(self, Vector3(0.05, 0.05, 0.08), Vector3(DOOR_SIZE.x / 2.0 - 0.12, 1.05, 0.09), metal)

	var trim := CityDecor.pbr_material("Concrete034", 2.0, Color(0.82, 0.8, 0.76))
	var jamb_height := DOOR_SIZE.y + TRIM_WIDTH
	for side in [-1.0, 1.0]:
		_add_box(self, Vector3(TRIM_WIDTH, jamb_height, TRIM_WIDTH),
				Vector3(side * (DOOR_SIZE.x + TRIM_WIDTH) / 2.0, jamb_height / 2.0, TRIM_WIDTH / 2.0), trim)
	_add_box(self, Vector3(DOOR_SIZE.x + TRIM_WIDTH * 2.0, TRIM_WIDTH, TRIM_WIDTH),
			Vector3(0.0, DOOR_SIZE.y + TRIM_WIDTH / 2.0, TRIM_WIDTH / 2.0), trim)


## Marquise de metal sobre a porta, com a luminária quente embaixo.
func _build_canopy(body: StaticBody3D) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.7
	metal.roughness = 0.4
	var center := Vector3(0.0, CANOPY_BOTTOM + CANOPY_SIZE.y / 2.0, CANOPY_SIZE.z / 2.0 - 0.1)
	_add_box(self, CANOPY_SIZE, center, metal)
	_add_shape(body, CANOPY_SIZE, center)

	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = LAMP_COLOR
	_lamp_material.emission_enabled = true
	_lamp_material.emission = LAMP_COLOR
	var lamp_spot := Vector3(0.0, CANOPY_BOTTOM - 0.01, 0.45)
	var panel := _add_box(self, Vector3(1.2, 0.02, 0.25), lamp_spot, _lamp_material)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Uma luz pequena, sem sombra (barata): ilumina a porta e o chão da frente.
	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.light_color = LAMP_COLOR
	_lamp.omni_range = LAMP_RANGE
	_lamp.omni_attenuation = 1.2
	_lamp.position = lamp_spot + Vector3(0.0, -0.25, 0.2)
	add_child(_lamp)


## Placa grafite em cima da marquise, na beira da frente, com "CASA" em néon e
## um filete de néon embaixo (como as placas dos bairros).
func _build_sign() -> void:
	var pixel_size := SIGN_TEXT_HEIGHT / SIGN_FONT_SIZE
	var text_width := HubFonts.SIGN.get_string_size("CASA", HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT_SIZE).x * pixel_size
	var plate_size := Vector3(text_width + 0.5, SIGN_TEXT_HEIGHT + 0.26, 0.1)
	var front_z := CANOPY_SIZE.z - 0.1 - 0.12  # quase na beira da marquise
	var plate_center := Vector3(0.0, CANOPY_BOTTOM + CANOPY_SIZE.y + plate_size.y / 2.0, front_z - plate_size.z / 2.0)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = PLATE_COLOR
	metal.metallic = 0.6
	metal.roughness = 0.4
	var plate := _add_box(self, plate_size, plate_center, metal)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_strip_material = StandardMaterial3D.new()
	_strip_material.albedo_color = NEON_COLOR
	_strip_material.emission_enabled = true
	_strip_material.emission = NEON_COLOR
	var strip := _add_box(self, Vector3(plate_size.x, 0.05, 0.04),
			Vector3(0.0, plate_center.y - plate_size.y / 2.0 + 0.04, front_z + 0.02), _strip_material)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_label = Label3D.new()
	_label.name = "Neon"
	_label.text = "CASA"
	_label.font = HubFonts.SIGN
	_label.font_size = SIGN_FONT_SIZE
	_label.pixel_size = pixel_size
	_label.outline_size = 0
	_label.position = Vector3(0.0, plate_center.y + 0.03, front_z + 0.01)
	add_child(_label)


func _add_box(parent: Node3D, box_size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	parent.add_child(mesh)
	return mesh


func _add_shape(body: StaticBody3D, box_size: Vector3, center: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
