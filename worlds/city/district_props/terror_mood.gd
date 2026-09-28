class_name TerrorMood
extends Node3D
## Bairro Sobrevivência e Terror: o néon dos prédios FALHA (apaga e pisca em
## rajadas, feito no shader da fachada), uma névoa baixa cobre o quarteirão e
## um dos postes está apagado.
##
## A névoa é um FogVolume (névoa volumétrica da Godot): tem volume de verdade,
## é mais densa perto do chão e as luzes (postes, vitrines, néon) acendem nela
## à noite. Ela só aparece nas qualidades Média e Alta (GraphicsQuality liga a
## névoa volumétrica); na Leve, fica de fora para economizar.

const MIST_SIZE: Vector3 = Vector3(30.0, 3.0, 30.0)
const MIST_DENSITY: float = 0.2
const MIST_ALBEDO: Color = Color(0.85, 0.88, 0.9)

## Os prédios e o quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []
var cell: Vector2i = Vector2i.ZERO

var _broken_light: StreetLight


func _ready() -> void:
	for building in buildings:
		building.set_neon_flicker(true)

	var center := CityLayout.block_center(cell)
	var fog := FogVolume.new()
	fog.name = "GroundMist"
	fog.size = MIST_SIZE
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var material := FogMaterial.new()
	material.density = MIST_DENSITY
	material.albedo = MIST_ALBEDO
	material.height_falloff = 1.2  # bem mais densa perto do chão
	material.edge_fade = 0.35      # bordas suaves (não vira uma "caixa")
	fog.material = material
	# A caixa começa um pouco abaixo do chão, para a parte densa ficar rente a ele.
	fog.position = center + Vector3(0.0, MIST_SIZE.y / 2.0 - 0.5, 0.0)
	add_child(fog)

	# Um poste apagado: o da quina noroeste do quarteirão.
	_broken_light = _find_corner_light(center)
	if _broken_light != null:
		_broken_light.broken = true


func get_broken_light() -> StreetLight:
	return _broken_light


func _find_corner_light(center: Vector3) -> StreetLight:
	var best: StreetLight = null
	var best_score := INF
	for node in get_parent().get_children():
		var light := node as StreetLight
		if light == null:
			continue
		var offset := light.position - center
		if absf(offset.x) > CityLayout.BLOCK_SIZE / 2.0 or absf(offset.z) > CityLayout.BLOCK_SIZE / 2.0:
			continue  # poste de outro quarteirão
		var score := offset.x + offset.z  # o mais a noroeste
		if score < best_score:
			best_score = score
			best = light
	return best
