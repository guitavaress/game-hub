class_name DistrictSign
extends Node3D
## Letreiro de um bairro: o nome em néon sobre uma PLACA grafite, com um filete
## de néon embaixo. De dia o néon quase apaga (é só tinta) e a placa escura
## garante a leitura contra o céu; à noite o nome e o filete brilham.
##
## O conjunto gira só em volta do eixo Y para ficar de frente para a câmera
## (como um "billboard", mas mantendo placa, filete e texto juntos).
##
## Uso: var s := DistrictSign.new(); s.setup("RPG E FANTASIA", cor); add_child(s)

## Altura das letras (m) e do texto dentro da fonte.
const TEXT_HEIGHT: float = 2.4
const FONT_SIZE: int = 128
## Placa: 1,1 x a largura do texto, 3 m de altura, grafite.
const PLATE_WIDTH_FACTOR: float = 1.1
const PLATE_HEIGHT: float = 3.0
const PLATE_DEPTH: float = 0.15
const PLATE_COLOR: Color = Color("16181D")
const STRIP_HEIGHT: float = 0.12

var _label: Label3D
var _strip_material: StandardMaterial3D
var _neon: Color = Color.WHITE


## "text_height": altura das letras (m); a placa acompanha na mesma proporção.
func setup(text: String, neon: Color, text_height: float = TEXT_HEIGHT) -> void:
	_neon = neon
	var pixel_size := text_height / FONT_SIZE
	var text_width := HubFonts.SIGN.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * pixel_size
	var plate_size := Vector3(text_width * PLATE_WIDTH_FACTOR, PLATE_HEIGHT * text_height / TEXT_HEIGHT, PLATE_DEPTH)

	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = plate_size
	plate.mesh = box
	var metal := StandardMaterial3D.new()
	metal.albedo_color = PLATE_COLOR
	metal.metallic = 0.6
	metal.roughness = 0.4
	plate.material_override = metal
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plate)

	# Filete de néon na borda de baixo, na frente da placa.
	var strip := MeshInstance3D.new()
	var strip_box := BoxMesh.new()
	strip_box.size = Vector3(plate_size.x, STRIP_HEIGHT, 0.04)
	strip.mesh = strip_box
	_strip_material = StandardMaterial3D.new()
	_strip_material.albedo_color = neon
	_strip_material.emission_enabled = true
	_strip_material.emission = neon
	strip.material_override = _strip_material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position = Vector3(0.0, -plate_size.y / 2.0 + STRIP_HEIGHT / 2.0, plate_size.z / 2.0 + 0.02)
	add_child(strip)

	# O nome, colado na frente da placa. Sem contorno: a placa já é o fundo.
	_label = Label3D.new()
	_label.text = text
	_label.font = HubFonts.SIGN
	_label.font_size = FONT_SIZE
	_label.pixel_size = pixel_size
	_label.outline_size = 0
	_label.position = Vector3(0.0, STRIP_HEIGHT / 2.0, plate_size.z / 2.0 + 0.03)
	add_child(_label)

	set_night(0.0)


## 0 = dia, 1 = noite.
func set_night(night: float) -> void:
	if _label == null:
		return
	_strip_material.emission_energy_multiplier = CityDecor.neon_energy(night)
	# O texto não recebe luz (Label3D): de dia é a cor pura; à noite passa de 1
	# e o glow faz o halo.
	var glow := lerpf(1.0, 1.8, night)
	_label.modulate = Color(_neon.r * glow, _neon.g * glow, _neon.b * glow)


func get_text() -> String:
	return _label.text if _label != null else ""


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Gira só em Y, paralelo à tela (acompanha a DIREÇÃO da câmera, não a
	# posição: assim a placa não fica "torta" quando está no canto da visão).
	var forward := -camera.global_transform.basis.z
	if absf(forward.x) + absf(forward.z) > 0.001:
		global_rotation.y = atan2(-forward.x, -forward.z)
