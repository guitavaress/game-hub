class_name ComputerDesk
extends Node3D
## A MESA DO COMPUTADOR da casa: uma mesa larga com TRÊS MONITORES (Fase 14.25),
## o do meio de frente e os dos lados um pouco virados para dentro. Por enquanto
## os três mostram "Sem sinal": a 14.28 liga cada um a uma saída do compositor.
## As configurações (Casa, Sistema...) moraram aqui até a 14.24; agora são abas
## do menu de pausa (Esc).
##
## Convenção: a origem fica no chão, no meio da mesa, e a FRENTE (+Z) aponta
## para o lado de onde o jogador vem.

## Tampo da mesa (largura, altura do chão até o tampo, profundidade), em metros.
const DESK_SIZE: Vector3 = Vector3(2.8, 0.75, 0.7)
const TOP_THICKNESS: float = 0.05
## Tamanho da tela e altura do meio dela (do chão).
const SCREEN_SIZE: Vector2 = Vector2(0.8, 0.45)
const SCREEN_HEIGHT: float = 1.2
## Borda do monitor em volta da tela e espessura dele.
const BEZEL: float = 0.025
const MONITOR_DEPTH: float = 0.04
## Pixels do conteúdo da tela (mesma proporção da tela).
const SCREEN_RESOLUTION: Vector2i = Vector2i(1152, 648)
## Os monitores dos lados: quanto ficam afastados do meio (x) e quanto giram para dentro.
const SIDE_OFFSET: float = 0.88
const SIDE_TURN_DEGREES: float = 22.0

const DESK_COLOR: Color = Color(0.3, 0.19, 0.11)
const LAMP_COLOR: Color = Color(1.0, 0.74, 0.48)
const MONITOR_COLOR: Color = Color(0.05, 0.05, 0.06)

## Um monitor sem nada ligado: mostra "Sem sinal" e não aceita foco.
class MonitorScreen extends Screen3D:
	func get_look_info() -> Dictionary:
		return {"title": screen_name, "detail": "Sem sinal", "action": ""}

	func interact(_player: Node) -> void:
		pass

## Esquerda, meio, direita.
var _screens: Array[Screen3D] = []


func _ready() -> void:
	_build_desk()
	_build_monitors()


## A tela do monitor do MEIO (para os testes).
func get_screen() -> Screen3D:
	return _screens[1] if _screens.size() == 3 else null


## Os três monitores: esquerda, meio, direita.
func get_screens() -> Array[Screen3D]:
	return _screens


# --- Montagem -------------------------------------------------------------------

## Tampo de madeira em pés de aço (com colisão: o jogador não atravessa a
## mesa), um teclado, um mouse e uma luminária de mesa.
func _build_desk() -> void:
	var wood := HomeMaterials.wood(DESK_COLOR, false, 0.4)
	var steel := HomeMaterials.metal(Color(0.09, 0.09, 0.1))
	var top_y := DESK_SIZE.y - TOP_THICKNESS / 2.0
	_add_box("Top", Vector3(DESK_SIZE.x, TOP_THICKNESS, DESK_SIZE.z), Vector3(0.0, top_y, 0.0), wood)
	var leg_height := DESK_SIZE.y - TOP_THICKNESS
	for side in [-1.0, 1.0]:
		var x: float = side * (DESK_SIZE.x / 2.0 - 0.06)
		_add_box("Side", Vector3(0.04, leg_height, DESK_SIZE.z - 0.08), Vector3(x, leg_height / 2.0, 0.0), steel)
		_add_box("Foot", Vector3(0.06, 0.03, DESK_SIZE.z - 0.04), Vector3(x, 0.015, 0.0), steel, false)
	var dark := _material(Color(0.07, 0.07, 0.08), 0.5)
	_add_box("Keyboard", Vector3(0.44, 0.02, 0.14), Vector3(-0.05, DESK_SIZE.y + 0.01, 0.2), dark, false)
	_add_box("Mouse", Vector3(0.06, 0.02, 0.1), Vector3(0.3, DESK_SIZE.y + 0.01, 0.2), dark, false)
	_build_desk_lamp(Vector3(-DESK_SIZE.x / 2.0 + 0.18, DESK_SIZE.y, -0.12))


## Luminária de mesa: base, haste e cabeça acesa, com uma luz quente pequena.
func _build_desk_lamp(at: Vector3) -> void:
	var steel := HomeMaterials.metal(Color(0.09, 0.09, 0.1))
	_add_box("LampBase", Vector3(0.14, 0.02, 0.14), at + Vector3(0.0, 0.01, 0.0), steel, false)
	_add_box("LampArm", Vector3(0.02, 0.42, 0.02), at + Vector3(0.0, 0.22, 0.0), steel, false)
	var head := _add_box("LampHead", Vector3(0.16, 0.05, 0.08), at + Vector3(0.04, 0.44, 0.04), steel, false)
	head.rotation.z = deg_to_rad(-15.0)
	_add_box("LampGlow", Vector3(0.12, 0.01, 0.06), at + Vector3(0.045, 0.41, 0.04), HomeMaterials.glow(LAMP_COLOR, 5.0), false)
	var light := OmniLight3D.new()
	light.name = "DeskLight"
	light.light_color = LAMP_COLOR
	light.light_energy = 0.6
	light.omni_range = 1.8
	light.position = at + Vector3(0.05, 0.35, 0.05)
	add_child(light)


## Os três monitores no fundo da mesa. O do meio fica de frente; os dos lados
## recuam um pouco e giram para dentro.
func _build_monitors() -> void:
	var back_z := -DESK_SIZE.z / 2.0 + 0.15
	var names: Array[String] = ["Monitor esquerdo", "Monitor do meio", "Monitor direito"]
	for i in 3:
		var side := float(i - 1)  # -1, 0, 1
		var turn := -side * deg_to_rad(SIDE_TURN_DEGREES)
		var holder := Node3D.new()
		holder.name = "Monitor%d" % (i + 1)
		holder.position = Vector3(side * SIDE_OFFSET, 0.0, back_z + absf(side) * 0.1)
		holder.rotation.y = turn
		add_child(holder)
		_build_monitor(holder, names[i])


## Um monitor: pé, corpo e a tela (Screen3D) na frente do corpo. A origem do
## "holder" é o pé do monitor, no tampo.
func _build_monitor(holder: Node3D, screen_name: String) -> void:
	var dark := _material(MONITOR_COLOR, 0.4)
	var stand_height := SCREEN_HEIGHT - SCREEN_SIZE.y / 2.0 - DESK_SIZE.y
	_add_box_to(holder, "Base", Vector3(0.28, 0.02, 0.2), Vector3(0.0, DESK_SIZE.y + 0.01, 0.0), dark)
	_add_box_to(holder, "Stand", Vector3(0.06, stand_height, 0.04), Vector3(0.0, DESK_SIZE.y + stand_height / 2.0, -0.02), dark)
	var body_size := Vector3(SCREEN_SIZE.x + BEZEL * 2.0, SCREEN_SIZE.y + BEZEL * 2.0, MONITOR_DEPTH)
	_add_box_to(holder, "Body", body_size, Vector3(0.0, SCREEN_HEIGHT, MONITOR_DEPTH / 2.0 - 0.02), dark)

	var screen := MonitorScreen.new()
	screen.name = "Screen"
	screen.screen_name = screen_name
	screen.screen_size = SCREEN_SIZE
	screen.resolution = SCREEN_RESOLUTION
	screen.position = Vector3(0.0, SCREEN_HEIGHT, MONITOR_DEPTH - 0.02 + 0.002)
	screen.set_content(_build_no_signal())
	holder.add_child(screen)
	_screens.append(screen)


## O que aparece num monitor sem nada ligado.
func _build_no_signal() -> Control:
	var background := PanelContainer.new()
	# A tela 3D é um SubViewport: o tema do hub não chega sozinho até aqui.
	background.theme = HubTheme.get_theme()
	background.theme_type_variation = &"HubScreen"
	var label := HubTheme.label("SEM SINAL", &"HubTitle")
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	background.add_child(label)
	return background


# --- Peças --------------------------------------------------------------------

## Caixa com material e, se "solid", colisão (a mesma peça da casa).
func _add_box(box_name: String, box_size: Vector3, center: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	return HomeDecor.make_box(self, box_name, box_size, center, material, solid)


## O mesmo, dentro de um nó (um monitor).
func _add_box_to(parent: Node3D, box_name: String, box_size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	return HomeDecor.make_box(parent, box_name, box_size, center, material, false)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
