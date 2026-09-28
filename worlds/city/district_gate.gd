class_name DistrictGate
extends Node3D
## Pórtico de entrada de um bairro: dois pilares de metal nas calçadas e uma
## viga a 6 m de altura por cima da rua, com o nome do bairro em néon (dos
## dois lados) e um filete de néon embaixo. É o nome do bairro na altura do
## olhar, onde se lê numa cidade de verdade.
##
## Quem passa por baixo anda no eixo Z local; os pilares ficam em X = ±vão.
## Acende à noite como o resto do néon (grupo "city_night").

const HEIGHT: float = 6.0
const PILLAR_SIZE: Vector3 = Vector3(0.4, HEIGHT, 0.4)
const BEAM_HEIGHT: float = 1.1
const BEAM_DEPTH: float = 0.4
const TEXT_HEIGHT: float = 0.9
const FONT_SIZE: int = 128
const METAL_COLOR: Color = Color("1A1D22")

var _labels: Array[Label3D] = []
var _strip_material: StandardMaterial3D
var _neon: Color = Color.WHITE


## "half_span": metade do vão entre os pilares (m), do meio da rua até cada pilar.
func setup(text: String, neon: Color, half_span: float) -> void:
	_neon = neon
	add_to_group("city_night")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.8
	metal.roughness = 0.35

	for side in [-1.0, 1.0]:
		var pillar := CSGBox3D.new()
		pillar.size = PILLAR_SIZE
		pillar.position = Vector3(side * half_span, HEIGHT / 2.0, 0.0)
		pillar.material = metal
		pillar.use_collision = true
		add_child(pillar)

	var beam_width := half_span * 2.0 + PILLAR_SIZE.x
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(beam_width, BEAM_HEIGHT, BEAM_DEPTH)
	beam.mesh = beam_mesh
	beam.material_override = metal
	beam.position = Vector3(0.0, HEIGHT - BEAM_HEIGHT / 2.0, 0.0)
	add_child(beam)

	# Filete de néon embaixo da viga.
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(beam_width - 0.2, 0.06, BEAM_DEPTH + 0.04)
	strip.mesh = strip_mesh
	_strip_material = StandardMaterial3D.new()
	_strip_material.albedo_color = neon
	_strip_material.emission_enabled = true
	_strip_material.emission = neon
	strip.material_override = _strip_material
	strip.position = Vector3(0.0, HEIGHT - BEAM_HEIGHT - 0.03, 0.0)
	add_child(strip)

	# O nome, dos dois lados da viga (cabe na viga, diminuindo se precisar).
	var pixel_size := TEXT_HEIGHT / FONT_SIZE
	var text_width := HubFonts.SIGN.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * pixel_size
	if text_width > beam_width - 1.0:
		pixel_size *= (beam_width - 1.0) / text_width
	for side in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = text
		label.font = HubFonts.SIGN
		label.font_size = FONT_SIZE
		label.pixel_size = pixel_size
		label.outline_size = 0
		label.double_sided = false
		label.position = Vector3(0.0, HEIGHT - BEAM_HEIGHT / 2.0, side * (BEAM_DEPTH / 2.0 + 0.02))
		label.rotation.y = 0.0 if side > 0.0 else PI
		add_child(label)
		_labels.append(label)
	set_night(0.0)


func get_text() -> String:
	return _labels[0].text if not _labels.is_empty() else ""


## 0 = dia, 1 = noite (mesma regra de todo o néon da cidade).
func set_night(night: float) -> void:
	if _strip_material == null:
		return
	_strip_material.emission_energy_multiplier = CityDecor.neon_energy(night)
	var glow := lerpf(1.0, 1.8, night)
	for label in _labels:
		label.modulate = Color(_neon.r * glow, _neon.g * glow, _neon.b * glow)
