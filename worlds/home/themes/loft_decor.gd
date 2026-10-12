extends HomeDecor
## O enfeite do LOFT (Fase 9.9, virou tema na 13.2): três pendentes quentes nas
## vigas e o canto de estar virado para a janela (tapete, sofá, mesinha e um
## abajur de chão). As cores das lâmpadas vêm do perfil; as dos móveis são
## deste enfeite.

const RUG_SHADER: Shader = preload("res://worlds/home/home_rug.gdshader")
const FURNITURE_WOOD: Color = Color(0.3, 0.19, 0.11)
const STEEL_COLOR: Color = Color(0.09, 0.09, 0.1)
const SOFA_COLOR: Color = Color(0.13, 0.25, 0.3)
const CUSHION_COLOR: Color = Color(0.72, 0.42, 0.2)


func build() -> void:
	for spot in [Vector2(-3.0, 0.0), Vector2(1.6, -Home.ROOM_SIZE.z / 3.0), Vector2(3.0, 0.0)]:
		_add_pendant(Vector3(spot.x, 0.0, spot.y))
	_add_rug(Vector3(0.0, 0.0, -2.9), Vector2(3.2, 2.4))
	_add_sofa(Vector3(0.0, 0.0, -1.9))
	_add_coffee_table(Vector3(0.0, 0.0, -3.2))
	_add_floor_lamp(Vector3(-1.6, 0.0, -1.9))


## Pendente: fio, cúpula de metal, lâmpada e a luz.
func _add_pendant(at: Vector3) -> void:
	var bulb_y := Home.ROOM_SIZE.y - 0.95
	var cord := MeshInstance3D.new()
	cord.name = "PendantCord"
	var cord_mesh := CylinderMesh.new()
	cord_mesh.top_radius = 0.008
	cord_mesh.bottom_radius = 0.008
	cord_mesh.height = 0.8
	cord.mesh = cord_mesh
	cord.material_override = HomeMaterials.matte(Color(0.05, 0.05, 0.05))
	cord.position = Vector3(at.x, Home.ROOM_SIZE.y - 0.4, at.z)
	add_node(cord)
	var shade := MeshInstance3D.new()
	shade.name = "PendantShade"
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius = 0.06
	shade_mesh.bottom_radius = 0.26
	shade_mesh.height = 0.22
	shade_mesh.cap_bottom = false
	shade.mesh = shade_mesh
	shade.material_override = HomeMaterials.metal(Color(0.12, 0.1, 0.08), 0.4)
	shade.position = Vector3(at.x, bulb_y + 0.06, at.z)
	add_node(shade)
	var bulb := MeshInstance3D.new()
	bulb.name = "PendantBulb"
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.06
	bulb_mesh.height = 0.12
	bulb.mesh = bulb_mesh
	bulb.material_override = HomeMaterials.glow(profile.lamp_color, 6.0)
	bulb.position = Vector3(at.x, bulb_y, at.z)
	add_node(bulb)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = profile.lamp_color
	lamp.light_energy = profile.lamp_energy
	lamp.omni_range = 7.0
	lamp.omni_attenuation = 1.1
	lamp.position = Vector3(at.x, bulb_y - 0.1, at.z)
	add_node(lamp)


func _add_rug(center: Vector3, rug_size: Vector2) -> void:
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var plane := PlaneMesh.new()
	plane.size = rug_size
	rug.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = RUG_SHADER
	rug.material_override = material
	rug.position = center + Vector3(0.0, 0.006, 0.0)
	add_node(rug)


## Sofá de três lugares com a frente para o norte (a janela): assento, encosto,
## braços e duas almofadas. Tem colisão (o jogador dá a volta).
func _add_sofa(center: Vector3) -> void:
	var cloth := HomeMaterials.fabric(SOFA_COLOR)
	var width := 2.2
	var depth := 0.9
	var x := center.x
	var z := center.z
	add_box("SofaBase", Vector3(width, 0.25, depth), Vector3(x, 0.17, z), cloth)
	add_box("SofaSeat", Vector3(width - 0.4, 0.14, depth - 0.2), Vector3(x, 0.36, z - 0.07), cloth, false)
	add_box("SofaBack", Vector3(width, 0.55, 0.22), Vector3(x, 0.57, z + depth / 2.0 - 0.11), cloth)
	for side in [-1.0, 1.0]:
		add_box("SofaArm", Vector3(0.2, 0.32, depth), Vector3(x + side * (width / 2.0 - 0.1), 0.45, z), cloth, false)
		add_box("SofaFoot", Vector3(0.05, 0.05, 0.05), Vector3(x + side * (width / 2.0 - 0.08), 0.025, z - depth / 2.0 + 0.08), HomeMaterials.metal(STEEL_COLOR), false)
	var cushion := HomeMaterials.fabric(CUSHION_COLOR)
	for side in [-1.0, 1.0]:
		var pillow := add_box("SofaCushion", Vector3(0.42, 0.38, 0.12), Vector3(x + side * 0.6, 0.62, z + depth / 2.0 - 0.3), cushion, false)
		pillow.rotation = Vector3(deg_to_rad(-12.0), side * deg_to_rad(8.0), 0.0)


func _add_coffee_table(center: Vector3) -> void:
	var wood := HomeMaterials.wood(FURNITURE_WOOD, false, 0.35)
	add_box("CoffeeTable", Vector3(1.1, 0.06, 0.55), center + Vector3(0.0, 0.38, 0.0), wood)
	var steel := HomeMaterials.metal(STEEL_COLOR)
	for sx in [-0.5, 0.5]:
		for sz in [-0.22, 0.22]:
			add_box("CoffeeTableLeg", Vector3(0.04, 0.35, 0.04), center + Vector3(sx, 0.175, sz), steel, false)
	# Um controle de videogame em cima da mesa.
	add_box("Gamepad", Vector3(0.16, 0.03, 0.1), center + Vector3(0.2, 0.425, 0.05), HomeMaterials.matte(Color(0.08, 0.08, 0.09), 0.4), false)


## Abajur de chão ao lado do sofá: pé de metal, cúpula de tecido e luz quente.
func _add_floor_lamp(at: Vector3) -> void:
	var steel := HomeMaterials.metal(STEEL_COLOR)
	add_box("FloorLampBase", Vector3(0.3, 0.03, 0.3), at + Vector3(0.0, 0.015, 0.0), steel)
	add_box("FloorLampPole", Vector3(0.03, 1.45, 0.03), at + Vector3(0.0, 0.75, 0.0), steel, false)
	var shade := MeshInstance3D.new()
	shade.name = "FloorLampShade"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.22
	mesh.height = 0.3
	mesh.cap_top = false
	mesh.cap_bottom = false
	shade.mesh = mesh
	var cloth := HomeMaterials.glow(Color(1.0, 0.86, 0.66), 0.9).duplicate() as StandardMaterial3D
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	shade.material_override = cloth
	shade.position = at + Vector3(0.0, 1.55, 0.0)
	add_node(shade)
	var light := OmniLight3D.new()
	light.name = "FloorLampLight"
	light.light_color = profile.lamp_color
	light.light_energy = 0.9
	light.omni_range = 4.0
	light.position = at + Vector3(0.0, 1.5, 0.0)
	add_node(light)
