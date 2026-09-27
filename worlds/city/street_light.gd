class_name StreetLight
extends Node3D
## Poste de rua moderno, feito por código: haste fina de metal escuro, braço
## reto e uma luminária de LED que acende à noite (um spot apontado para baixo,
## que desenha o "círculo de luz" no chão).
##
## O braço aponta para a frente (-Z deste nó): gire o nó para a luminária
## ficar sobre a rua. set_night(0..1) acende e apaga aos poucos.

const POLE_HEIGHT: float = 5.6
const ARM_LENGTH: float = 1.7
const LIGHT_COLOR: Color = Color(1.0, 0.9, 0.76)
const LIGHT_ENERGY: float = 14.0
const LIGHT_RANGE: float = 12.0
const LIGHT_ANGLE: float = 62.0  # graus
const METAL_COLOR: Color = Color(0.09, 0.095, 0.1)

var _light: SpotLight3D
var _led_material: StandardMaterial3D


func _ready() -> void:
	# O relógio da cidade (DayNight) acende todo mundo nesse grupo.
	add_to_group("city_night")

	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.85
	metal.roughness = 0.35

	# Haste (um pouco mais fina em cima).
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = POLE_HEIGHT
	pole_mesh.radial_segments = 12
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, POLE_HEIGHT / 2.0, 0.0)
	pole.material_override = metal
	add_child(pole)

	# Braço horizontal e a luminária na ponta.
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.08, 0.08, ARM_LENGTH)
	arm.mesh = arm_mesh
	arm.position = Vector3(0.0, POLE_HEIGHT - 0.05, -ARM_LENGTH / 2.0)
	arm.material_override = metal
	add_child(arm)

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.32, 0.07, 0.8)
	head.mesh = head_mesh
	head.position = Vector3(0.0, POLE_HEIGHT - 0.06, -ARM_LENGTH + 0.2)
	head.material_override = metal
	add_child(head)

	# A "lente" de LED embaixo da luminária (brilha à noite).
	_led_material = StandardMaterial3D.new()
	_led_material.albedo_color = LIGHT_COLOR
	_led_material.emission_enabled = true
	_led_material.emission = LIGHT_COLOR
	var led := MeshInstance3D.new()
	var led_mesh := BoxMesh.new()
	led_mesh.size = Vector3(0.24, 0.01, 0.68)
	led.mesh = led_mesh
	led.position = head.position - Vector3(0.0, 0.04, 0.0)
	led.material_override = _led_material
	add_child(led)

	# Spot apontado para baixo (por padrão ele aponta para -Z; giramos -90° em X).
	_light = SpotLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.spot_range = LIGHT_RANGE
	_light.spot_angle = LIGHT_ANGLE
	_light.spot_attenuation = 0.8
	_light.position = led.position - Vector3(0.0, 0.05, 0.0)
	_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(_light)
	set_night(0.0)


## 0 = dia (apagado), 1 = noite (aceso).
func set_night(night: float) -> void:
	var on := smoothstep(0.3, 0.8, night)
	_light.visible = on > 0.01
	_light.light_energy = LIGHT_ENERGY * on
	_led_material.emission_energy_multiplier = 5.0 * on
