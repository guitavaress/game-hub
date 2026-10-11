class_name SportsFloodlights
extends DistrictLandmark
## Bairro Esportes: uma torre de refletores de estádio. Um mastro de concreto
## com um painel de lâmpadas (duas fileiras de quatro), inclinado para baixo.
## As lâmpadas são brancas e brilham mais à noite; a faixa de néon é do bairro.

const MAST_SIZE: float = 0.9
const PANEL_SIZE: Vector2 = Vector2(8.0, 4.0)
const LAMP_COLOR: Color = Color(1.0, 0.97, 0.88)
const PANEL_TILT_DEGREES: float = 12.0

var _lamp_material: StandardMaterial3D


func _build(height: float) -> void:
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = LAMP_COLOR
	_lamp_material.emission_enabled = true
	_lamp_material.emission = LAMP_COLOR
	set_night(0.0)
	var panel_center := height - PANEL_SIZE.y / 2.0 - 0.1
	_add_box(Vector3(0.0, panel_center / 2.0, 0.0), Vector3(MAST_SIZE, panel_center, MAST_SIZE), _concrete_material)
	# Painel inclinado: caixa escura com as lâmpadas e uma faixa de néon embaixo.
	var panel := Node3D.new()
	panel.position = Vector3(0.0, panel_center, 0.0)
	panel.rotation.x = deg_to_rad(PANEL_TILT_DEGREES)
	add_child(panel)
	_add_box(Vector3.ZERO, Vector3(PANEL_SIZE.x, PANEL_SIZE.y, 0.3), _concrete_material, panel)
	# Lâmpadas nas duas faces (o painel não sabe para que lado o prédio olha).
	for face in [-1.0, 1.0]:
		for row in 2:
			for column in 4:
				_add_box(Vector3(-PANEL_SIZE.x / 2.0 + PANEL_SIZE.x * (column + 0.5) / 4.0,
						PANEL_SIZE.y / 4.0 * (1.0 if row == 0 else -1.0), face * 0.18),
						Vector3(1.6, 1.4, 0.1), _lamp_material, panel)
	_add_box(Vector3(0.0, -PANEL_SIZE.y / 2.0 - 0.15, 0.1), Vector3(PANEL_SIZE.x, 0.15, 0.3), _neon_material, panel)


func set_night(night: float) -> void:
	super.set_night(night)
	if _lamp_material != null:
		_lamp_material.emission_energy_multiplier = lerpf(1.0, 5.0, night)
