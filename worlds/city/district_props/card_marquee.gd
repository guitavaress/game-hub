class_name CardMarquee
extends Node3D
## Bairro Cartas: moldura de lâmpadas em volta do painel de cada prédio, como
## o letreiro de um cassino. As lâmpadas "correm" em volta (a luz anda de uma
## para a outra), feito no shader: todas as lâmpadas de um prédio são UMA
## MultiMesh (um só desenho). Acompanha o painel quando o hero chega depois.

const BULB_SPACING: float = 0.36
const BULB_RADIUS: float = 0.08
## Distância da moldura de lâmpadas até a borda do painel.
const MARGIN: float = 0.35
const SHADER: Shader = preload("res://worlds/city/district_props/bulb_chase.gdshader")

## Os prédios do quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []

var _material: ShaderMaterial
var _bulbs: Dictionary[CityBuilding, MultiMeshInstance3D] = {}


func _ready() -> void:
	add_to_group("city_night")
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	for building in buildings:
		_build_frame(building)
		building.poster_changed.connect(_build_frame.bind(building))
	set_night(0.0)


## (Re)monta a moldura em volta do painel do prédio.
func _build_frame(building: CityBuilding) -> void:
	if _bulbs.has(building):
		var old := _bulbs[building]
		old.get_parent().remove_child(old)  # sai já (senão a nova ganharia outro nome)
		old.queue_free()
	var rect: Dictionary = building.get_poster_rect()
	var center: Vector3 = rect["center"]
	var half: Vector2 = rect["size"] / 2.0 + Vector2(MARGIN, MARGIN)
	# Contorno do retângulo, no sentido horário, começando no canto de cima.
	var corners: Array[Vector2] = [Vector2(-half.x, half.y), Vector2(half.x, half.y),
			Vector2(half.x, -half.y), Vector2(-half.x, -half.y)]
	var spots: Array[Vector3] = []
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var steps := maxi(1, roundi(a.distance_to(b) / BULB_SPACING))
		for s in steps:
			var p := a.lerp(b, float(s) / steps)
			spots.append(center + Vector3(p.x, p.y, 0.06))

	var sphere := SphereMesh.new()
	sphere.radius = BULB_RADIUS
	sphere.height = BULB_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = sphere
	multimesh.instance_count = spots.size()
	for i in spots.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, spots[i]))
	var bulbs := MultiMeshInstance3D.new()
	bulbs.name = "Marquee"
	bulbs.multimesh = multimesh
	bulbs.material_override = _material
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	building.add_child(bulbs)
	bulbs.set_instance_shader_parameter("bulb_count", float(spots.size()))
	_bulbs[building] = bulbs


## Lâmpadas acesas de dia também (é um letreiro), mais fortes à noite.
func set_night(night: float) -> void:
	_material.set_shader_parameter("energy", lerpf(1.2, 3.5, night))


## Quantas lâmpadas tem a moldura do prédio (para os testes).
func get_bulb_count(building: CityBuilding) -> int:
	return _bulbs[building].multimesh.instance_count if _bulbs.has(building) else 0
