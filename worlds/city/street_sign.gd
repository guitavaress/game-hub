class_name StreetSign
extends Node3D
## Placa de rua presa num poste de esquina: nome curto do bairro em branco
## sobre metal escuro (#1A1D22), uma seta para o lado das portas e um filete
## de néon na cor do bairro embaixo. Fica a 2,6 m do chão.
##
## A placa é lida de frente pelo +Z local (quem está na rua, olhando para ela).

const HEIGHT: float = 2.6
const TEXT_HEIGHT: float = 0.22
const FONT_SIZE: int = 64
const PLATE_PADDING: Vector2 = Vector2(0.24, 0.12)
const PLATE_DEPTH: float = 0.04
const PLATE_COLOR: Color = Color("1A1D22")
const TEXT_COLOR: Color = Color("F2F3F5")

var _strip_material: StandardMaterial3D


## "arrow_right": a seta aponta para a direita de quem lê (senão, esquerda).
func setup(district_name: String, neon: Color, arrow_right: bool) -> void:
	add_to_group("city_night")
	var text := ("%s  →" % district_name) if arrow_right else ("←  %s" % district_name)
	var pixel_size := TEXT_HEIGHT / FONT_SIZE
	var text_width := HubFonts.SIGN.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * pixel_size
	var plate_size := Vector2(text_width + PLATE_PADDING.x * 2.0, TEXT_HEIGHT + PLATE_PADDING.y * 2.0)

	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(plate_size.x, plate_size.y, PLATE_DEPTH)
	plate.mesh = plate_mesh
	var metal := StandardMaterial3D.new()
	metal.albedo_color = PLATE_COLOR
	metal.metallic = 0.8
	metal.roughness = 0.35
	plate.material_override = metal
	plate.position = Vector3(0.0, HEIGHT, 0.0)
	add_child(plate)

	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(plate_size.x, 0.03, PLATE_DEPTH + 0.01)
	strip.mesh = strip_mesh
	_strip_material = StandardMaterial3D.new()
	_strip_material.albedo_color = neon
	_strip_material.emission_enabled = true
	_strip_material.emission = neon
	strip.material_override = _strip_material
	strip.position = Vector3(0.0, HEIGHT - plate_size.y / 2.0 - 0.015, 0.0)
	add_child(strip)

	var label := Label3D.new()
	label.text = text
	label.font = HubFonts.SIGN
	label.font_size = FONT_SIZE
	label.pixel_size = pixel_size
	label.outline_size = 0
	label.double_sided = false
	label.modulate = TEXT_COLOR
	label.position = Vector3(0.0, HEIGHT, PLATE_DEPTH / 2.0 + 0.01)
	add_child(label)
	set_night(0.0)


func set_night(night: float) -> void:
	if _strip_material != null:
		_strip_material.emission_energy_multiplier = CityDecor.neon_energy(night)
