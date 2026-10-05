class_name ArchShell
extends PortalShell
## Casca de ARCO (Fase 7.4): um arco de pedra simples na frente do espaço, com
## a porta do jogo na passagem. Prova de que o GamePortal não depende de prédio
## e semente para biomas (portão de vila, entrada de caverna...).
##
## Peças: dois pilares e uma viga, todos sólidos (o jogador não atravessa), um
## filete de néon do bairro embaixo da viga e o nome do jogo em cima.
## Nenhum bairro usa ainda: para experimentar, ponha shell = "arch" num perfil
## (profiles/districts/*.tres).

## Vão livre da passagem (largura e altura), em metros. A área de entrada do
## GamePortal (2,0 x 2,6) cabe com folga.
const OPENING: Vector2 = Vector2(2.4, 3.2)
const PILLAR_WIDTH: float = 0.9
const LINTEL_HEIGHT: float = 0.9
## Espessura do arco (de frente para trás).
const DEPTH: float = 1.6
const STONE_COLOR: Color = Color(0.42, 0.40, 0.37)
const NAME_HEIGHT: float = 0.45
## Brilho do néon de dia e de noite.
const NEON_DAY: float = 0.3
const NEON_NIGHT: float = 3.0

var _neon_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("city_night")
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE_COLOR
	stone.roughness = 0.95
	var front := size.z / 2.0
	var middle_z := front - DEPTH / 2.0
	var outer_width := OPENING.x + 2.0 * PILLAR_WIDTH
	var pillar_x := OPENING.x / 2.0 + PILLAR_WIDTH / 2.0

	var body := StaticBody3D.new()
	body.name = "Stone"
	add_child(body)
	for side in [-1.0, 1.0]:
		_add_block(body, Vector3(side * pillar_x, OPENING.y / 2.0, middle_z),
				Vector3(PILLAR_WIDTH, OPENING.y, DEPTH), stone)
	_add_block(body, Vector3(0.0, OPENING.y + LINTEL_HEIGHT / 2.0, middle_z),
			Vector3(outer_width, LINTEL_HEIGHT, DEPTH), stone)

	# Filete de néon na borda de baixo da viga, na frente.
	_neon_material = StandardMaterial3D.new()
	_neon_material.albedo_color = neon_color()
	_neon_material.emission_enabled = true
	_neon_material.emission = neon_color()
	_neon_material.emission_energy_multiplier = NEON_DAY
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(OPENING.x, 0.06, 0.06)
	strip.mesh = strip_mesh
	strip.material_override = _neon_material
	strip.position = Vector3(0.0, OPENING.y - 0.03, front + 0.03)
	add_child(strip)

	var label := Label3D.new()
	label.name = "Name"
	label.text = game.name if game != null else ""
	label.modulate = neon_color()
	label.pixel_size = 0.01
	label.font_size = 48
	label.width = outer_width * 100.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector3(0.0, OPENING.y + LINTEL_HEIGHT + NAME_HEIGHT, front)
	add_child(label)

	build_portal()


## Alvo "olhável": o arco inteiro (e não o terreno todo, como num prédio).
func portal_look_size() -> Vector3:
	return Vector3(OPENING.x + 2.0 * PILLAR_WIDTH, OPENING.y + LINTEL_HEIGHT, 1.0)


## 0 = dia, 1 = noite: o néon fica mais forte à noite.
func set_night(night: float) -> void:
	if _neon_material != null:
		_neon_material.emission_energy_multiplier = lerpf(NEON_DAY, NEON_NIGHT, clampf(night, 0.0, 1.0))


## Um bloco de pedra que se vê e que bloqueia o jogador.
func _add_block(body: StaticBody3D, center: Vector3, block_size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = block_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = center
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = block_size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
