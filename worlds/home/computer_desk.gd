class_name ComputerDesk
extends Node3D
## A MESA DO COMPUTADOR da casa (Fase 9): uma mesa com um monitor. A tela do
## monitor é um Screen3D que mostra as configurações (SettingsView, as mesmas
## abas do menu de pausa) e o botão "Sair do hub". E no monitor aproxima a
## câmera; Esc devolve.
##
## Desenho provisório: o acabamento final da mesa é da subetapa 9.9.
##
## Convenção: a origem fica no chão, no meio da mesa, e a FRENTE (+Z) aponta
## para o lado de onde o jogador vem.

## Tampo da mesa (largura, altura do chão até o tampo, profundidade), em metros.
const DESK_SIZE: Vector3 = Vector3(1.6, 0.75, 0.7)
const TOP_THICKNESS: float = 0.05
## Tamanho da tela e altura do meio dela (do chão).
const SCREEN_SIZE: Vector2 = Vector2(0.8, 0.45)
const SCREEN_HEIGHT: float = 1.2
## Borda do monitor em volta da tela e espessura dele.
const BEZEL: float = 0.025
const MONITOR_DEPTH: float = 0.04
## Pixels do conteúdo da tela (mesma proporção da tela).
const SCREEN_RESOLUTION: Vector2i = Vector2i(1152, 648)

const DESK_COLOR: Color = Color(0.24, 0.17, 0.12)
const MONITOR_COLOR: Color = Color(0.05, 0.05, 0.06)
const SCREEN_BACKGROUND: Color = Color("0E1015")

var _screen: Screen3D
var _settings: SettingsView


func _ready() -> void:
	_build_desk()
	_build_monitor()


## A tela do monitor (para os testes e para quem quiser saber se está em uso).
func get_screen() -> Screen3D:
	return _screen


func get_settings() -> SettingsView:
	return _settings


# --- Montagem -------------------------------------------------------------------

## Tampo e duas laterais (com colisão: o jogador não atravessa a mesa).
func _build_desk() -> void:
	var wood := _material(DESK_COLOR, 0.6)
	var top_y := DESK_SIZE.y - TOP_THICKNESS / 2.0
	_add_box("Top", Vector3(DESK_SIZE.x, TOP_THICKNESS, DESK_SIZE.z), Vector3(0.0, top_y, 0.0), wood)
	var leg_height := DESK_SIZE.y - TOP_THICKNESS
	for side in [-1.0, 1.0]:
		var x: float = side * (DESK_SIZE.x / 2.0 - 0.04)
		_add_box("Side", Vector3(0.06, leg_height, DESK_SIZE.z - 0.04), Vector3(x, leg_height / 2.0, 0.0), wood)


## Monitor no fundo da mesa: pé, corpo e a tela (Screen3D) na frente do corpo.
func _build_monitor() -> void:
	var dark := _material(MONITOR_COLOR, 0.4)
	var back_z := -DESK_SIZE.z / 2.0 + 0.15
	var stand_height := SCREEN_HEIGHT - SCREEN_SIZE.y / 2.0 - DESK_SIZE.y
	_add_box("MonitorBase", Vector3(0.28, 0.02, 0.2), Vector3(0.0, DESK_SIZE.y + 0.01, back_z), dark, false)
	_add_box("MonitorStand", Vector3(0.06, stand_height, 0.04), Vector3(0.0, DESK_SIZE.y + stand_height / 2.0, back_z - 0.02), dark, false)
	var body_size := Vector3(SCREEN_SIZE.x + BEZEL * 2.0, SCREEN_SIZE.y + BEZEL * 2.0, MONITOR_DEPTH)
	_add_box("MonitorBody", body_size, Vector3(0.0, SCREEN_HEIGHT, back_z + MONITOR_DEPTH / 2.0), dark, false)

	_screen = Screen3D.new()
	_screen.name = "Screen"
	_screen.screen_name = "Computador"
	_screen.detail = "Configurações"
	_screen.screen_size = SCREEN_SIZE
	_screen.resolution = SCREEN_RESOLUTION
	_screen.position = Vector3(0.0, SCREEN_HEIGHT, back_z + MONITOR_DEPTH + 0.002)
	_screen.set_content(_build_screen_content())
	_screen.focus_changed.connect(_on_focus_changed)
	add_child(_screen)


## O que aparece no monitor: à esquerda, as configurações; à direita, o
## título, uma dica e o botão "Sair do hub".
func _build_screen_content() -> Control:
	var background := PanelContainer.new()
	background.add_theme_stylebox_override("panel", SettingsView.box(SCREEN_BACKGROUND, 0, Color.TRANSPARENT, 0, Vector4(44, 30, 44, 30)))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	background.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(600.0, 0.0)
	left.add_theme_constant_override("separation", 16)
	columns.add_child(left)
	left.add_child(SettingsView.label("CONFIGURAÇÕES", SettingsView.spaced_font(3), 28, SettingsView.TEXT_COLOR))
	_settings = SettingsView.new()
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_settings)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	right.add_child(SettingsView.label("GAME HUB", SettingsView.spaced_font(4), 20, SettingsView.HINT_COLOR))
	var hint := SettingsView.label("Clique para mudar. Cada mudança vale na hora.", HubFonts.LIGHT, 15, SettingsView.SECONDARY_COLOR)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(hint)
	var esc_row := HBoxContainer.new()
	esc_row.add_theme_constant_override("separation", 10)
	esc_row.add_child(GameScreen.make_key_cap("Esc"))
	esc_row.add_child(SettingsView.label("voltar para a sala", HubFonts.LIGHT, 15, SettingsView.SECONDARY_COLOR))
	right.add_child(esc_row)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(filler)
	right.add_child(SettingsView.line())
	var quit_row := HBoxContainer.new()
	quit_row.add_child(SettingsView.expander())
	var quit := SettingsView.button("Sair do hub", false)
	quit.name = "QuitButton"
	quit.pressed.connect(HubWindow.quit_hub)
	quit_row.add_child(quit)
	right.add_child(quit_row)
	return background


## Ao focar, a tela mostra os valores de agora; ao sair, grava o que espera.
func _on_focus_changed(focused: bool) -> void:
	if focused:
		_settings.refresh()
	else:
		_settings.save_pending()


# --- Peças --------------------------------------------------------------------

## Caixa com material e, se "solid", colisão (camada 1, como as paredes).
func _add_box(box_name: String, box_size: Vector3, center: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = box_name
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box_size
		shape.shape = box_shape
		body.add_child(shape)
		mesh.add_child(body)
	return mesh


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
