class_name AdventureLighthouse
extends DistrictLandmark
## Bairro Aventura: um farol. Torre afinada com faixas de néon, galeria, lanterna
## quente no topo e um feixe de luz que gira à noite (só faixa de luz).

const LANTERN_COLOR: Color = Color(1.0, 0.72, 0.35)
const STONE_COLOR: Color = Color(0.74, 0.7, 0.62)
const BEAM_LENGTH: float = 16.0
const BEAM_WIDTH: float = 0.7
const BEAM_SPEED: float = 0.8

var _lantern_material: StandardMaterial3D


func _build(height: float) -> void:
	var stone := CityDecor.make_material(STONE_COLOR)
	var lantern_h := 1.4
	var gallery_y := height - lantern_h - 1.4 - 0.4
	_add_cylinder(Vector3.ZERO, 1.2, 2.1, gallery_y, stone, null, 20)
	# Faixas de néon em volta da torre (listras de farol).
	var bands := 3
	for i in bands:
		var y := gallery_y * (i + 0.7) / (bands + 0.4)
		var r := lerpf(2.1, 1.2, y / gallery_y) + 0.05
		_add_cylinder(Vector3(0.0, y, 0.0), r, r, 0.5, _neon_material, null, 20)
	_add_cylinder(Vector3(0.0, gallery_y, 0.0), 1.9, 1.9, 0.4, _concrete_material, null, 20)
	# Lanterna: cilindro quente (a luz) com telhado em cone e uma ponta.
	_lantern_material = StandardMaterial3D.new()
	_lantern_material.albedo_color = LANTERN_COLOR
	_lantern_material.emission_enabled = true
	_lantern_material.emission = LANTERN_COLOR
	var lantern_base := gallery_y + 0.4
	_add_cylinder(Vector3(0.0, lantern_base, 0.0), 0.9, 0.9, lantern_h, _lantern_material, null, 16)
	_add_cylinder(Vector3(0.0, lantern_base + lantern_h, 0.0), 0.1, 1.15, 1.4 - 0.4, _concrete_material, null, 16)
	_add_box(Vector3(0.0, height - 0.2, 0.0), Vector3(0.12, 0.4, 0.12), _concrete_material)
	_add_sweeping_beams(Vector3(0.0, lantern_base + lantern_h / 2.0, 0.0), 2, BEAM_LENGTH, BEAM_WIDTH, 4.0, BEAM_SPEED)
	set_night(0.0)


func set_night(night: float) -> void:
	super.set_night(night)
	if _lantern_material != null:
		_lantern_material.emission_energy_multiplier = lerpf(1.2, 5.0, night)
