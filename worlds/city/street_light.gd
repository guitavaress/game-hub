class_name StreetLight
extends Node3D
## Poste de rua (modelo CC0 da Kenney) com uma luz que acende à noite.
##
## O braço do poste aponta para a frente (-Z deste nó): gire o nó para a
## lâmpada ficar sobre a rua. set_night(0..1) acende e apaga aos poucos.

const MODEL: PackedScene = preload("res://assets/kenney/city-kit-roads/light-square.glb")
## O modelo original tem 0,6 de altura; com esta escala o poste fica com ~4,8 m.
const MODEL_SCALE: float = 8.0
## Onde fica a lâmpada, no modelo já escalado.
const LAMP_POSITION: Vector3 = Vector3(0.0, 4.55, -1.5)
const LIGHT_COLOR: Color = Color(1.0, 0.82, 0.55)
const LIGHT_RANGE: float = 13.0
const LIGHT_ENERGY: float = 2.2

var _light: OmniLight3D
var _bulb_material: StandardMaterial3D


func _ready() -> void:
	# O relógio da cidade (DayNight) acende todo mundo nesse grupo.
	add_to_group("city_night")
	var model := MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)

	# "Lâmpada": uma bolinha que brilha, embaixo da cabeça do poste.
	_bulb_material = StandardMaterial3D.new()
	_bulb_material.albedo_color = LIGHT_COLOR
	_bulb_material.emission_enabled = true
	_bulb_material.emission = LIGHT_COLOR
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	bulb.mesh = sphere
	bulb.material_override = _bulb_material
	bulb.position = LAMP_POSITION - Vector3(0.0, 0.2, 0.0)
	add_child(bulb)

	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.position = LAMP_POSITION - Vector3(0.0, 0.4, 0.0)
	add_child(_light)
	set_night(0.0)


## 0 = dia (apagado), 1 = noite (aceso).
func set_night(night: float) -> void:
	var on := smoothstep(0.3, 0.8, night)
	_light.visible = on > 0.01
	_light.light_energy = LIGHT_ENERGY * on
	_bulb_material.emission_energy_multiplier = 4.0 * on
