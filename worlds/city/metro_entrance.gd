class_name MetroEntrance
extends TransitStop
## Estação de METRÔ da cidade (Fase 8): a aparência em volta de uma
## TransitStop (a lógica de entrar e viajar fica nela).
##
## Por enquanto (8.6) é um totem simples: um poste escuro com uma placa "M"
## na cor da linha, que acende à noite. A boca de escada vem na 8.7.

const POST_SIZE: Vector3 = Vector3(0.35, 2.6, 0.35)
const SIGN_SIZE: Vector3 = Vector3(0.9, 0.9, 0.14)
const METAL_COLOR: Color = Color("1A1D22")
const NEON_DAY: float = 0.6
const NEON_NIGHT: float = 3.0

var _sign_material: StandardMaterial3D


func _ready() -> void:
	super()
	add_to_group("city_night")
	var body := StaticBody3D.new()
	body.name = "Post"
	add_child(body)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.7
	metal.roughness = 0.4
	_add_box(body, Vector3(0.0, POST_SIZE.y / 2.0, 0.0), POST_SIZE, metal, true)

	_sign_material = StandardMaterial3D.new()
	_sign_material.albedo_color = color
	_sign_material.emission_enabled = true
	_sign_material.emission = color
	_sign_material.emission_energy_multiplier = NEON_DAY
	_add_box(body, Vector3(0.0, POST_SIZE.y + SIGN_SIZE.y / 2.0 - 0.1, 0.0), SIGN_SIZE, _sign_material, false)

	for side in [1.0, -1.0]:
		var letter := Label3D.new()
		letter.text = "M"
		letter.font_size = 96
		letter.pixel_size = 0.006
		letter.outline_size = 0
		letter.modulate = Color(0.05, 0.05, 0.07)
		letter.position = Vector3(0.0, POST_SIZE.y + SIGN_SIZE.y / 2.0 - 0.1, side * (SIGN_SIZE.z / 2.0 + 0.01))
		letter.rotation.y = 0.0 if side > 0.0 else PI
		add_child(letter)


## 0 = dia, 1 = noite: a placa acende mais à noite (grupo "city_night").
func set_night(night: float) -> void:
	if _sign_material != null:
		_sign_material.emission_energy_multiplier = lerpf(NEON_DAY, NEON_NIGHT, clampf(night, 0.0, 1.0))


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
