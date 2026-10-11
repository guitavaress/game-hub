class_name RustyWaterTank
extends DistrictLandmark
## Bairro Sobrevivência e Terror: uma caixa d'água enferrujada, alta, sobre
## pernas de ferro, com uma luz vermelha piscando no topo (e que falha de vez
## em quando, como o néon do bairro).

const RUST_COLOR: Color = Color(0.45, 0.2, 0.09)
const IRON_COLOR: Color = Color(0.1, 0.09, 0.09)
const BEACON_COLOR: Color = Color(1.0, 0.1, 0.05)
const TANK_RADIUS: float = 2.6
const TANK_HEIGHT: float = 4.4
const BLINK_PERIOD: float = 1.4

var _beacon_material: StandardMaterial3D
var _time: float = 0.0
var _night: float = 0.0


func _build(height: float) -> void:
	var rust := CityDecor.make_material(RUST_COLOR)
	var iron := CityDecor.make_material(IRON_COLOR)
	var top_of_tank := height - 2.4
	var tank_base := top_of_tank - TANK_HEIGHT
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_box(Vector3(sx * 1.7, tank_base / 2.0, sz * 1.7), Vector3(0.25, tank_base, 0.25), iron)
	# Travessas em X entre as pernas (uma no meio da altura).
	_add_box(Vector3(0.0, tank_base * 0.5, 0.0), Vector3(3.8, 0.15, 0.15), iron)
	_add_box(Vector3(0.0, tank_base * 0.5, 0.0), Vector3(0.15, 0.15, 3.8), iron)
	_add_cylinder(Vector3(0.0, tank_base, 0.0), TANK_RADIUS, TANK_RADIUS, TANK_HEIGHT, rust)
	# Aros de ferro e o telhado em cone.
	for ring_y in [0.5, TANK_HEIGHT - 0.5]:
		_add_cylinder(Vector3(0.0, tank_base + ring_y - 0.08, 0.0), TANK_RADIUS + 0.06, TANK_RADIUS + 0.06, 0.16, iron)
	_add_cylinder(Vector3(0.0, top_of_tank, 0.0), 0.15, TANK_RADIUS + 0.2, 1.0, iron)
	_add_box(Vector3(0.0, top_of_tank + 1.5, 0.0), Vector3(0.1, 1.0, 0.1), iron)
	_beacon_material = StandardMaterial3D.new()
	_beacon_material.albedo_color = BEACON_COLOR
	_beacon_material.emission_enabled = true
	_beacon_material.emission = BEACON_COLOR
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.3
	bulb_mesh.height = 0.6
	bulb.mesh = bulb_mesh
	bulb.position = Vector3(0.0, height - 0.3, 0.0)
	bulb.material_override = _beacon_material
	add_child(bulb)
	_apply_beacon()


func set_night(night: float) -> void:
	super.set_night(night)
	_night = night
	_apply_beacon()


func _process(delta: float) -> void:
	_time = fmod(_time + delta, BLINK_PERIOD)
	_apply_beacon()


## Acesa em 1/4 do ciclo; mais forte à noite.
func _apply_beacon() -> void:
	if _beacon_material == null:
		return
	var on := _time < BLINK_PERIOD * 0.25
	_beacon_material.emission_energy_multiplier = lerpf(2.0, 6.0, _night) if on else 0.05
