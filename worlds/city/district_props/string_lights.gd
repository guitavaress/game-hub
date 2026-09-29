class_name StringLights
extends Node3D
## Bairro Casual e Festa: VARAL DE LÂMPADAS. Fios em curva ("barriga" de 0,8 m)
## ligam os postes do quarteirão, a uns 5 m de altura, com lâmpadas coloridas
## penduradas a cada 0,7 m, como numa festa junina.
##
## Onde há um quarteirão vizinho, o fio atravessa a rua até o poste "equivalente"
## dele; onde não há, o fio liga os dois postes do próprio quarteirão ao longo
## da rua. Quando um vizinho aparece depois (a cidade monta um quarteirão por
## vez), o varal se refaz sozinho.
##
## Todas as lâmpadas são UMA MultiMesh (cada uma com a sua cor) e todos os
## pedaços de fio são outra: são dois desenhos só, e nenhuma luz de verdade.

const CORD_HEIGHT: float = 5.0
## "Barriga" do fio: no mínimo 0,8 m, mais nos fios longos.
const SAG: float = 0.8
const SAG_PER_METER: float = 0.04
const BULB_SPACING: float = 0.7
const BULB_RADIUS: float = 0.09
## As lâmpadas ficam penduradas um pouquinho abaixo do fio.
const BULB_DROP: float = 0.1
const WIRE_THICKNESS: float = 0.025
## O fio é feito de pedacinhos retos de mais ou menos este tamanho.
const WIRE_PIECE: float = 1.0
## Onde ficam os postes, a partir do centro do quarteirão (veja CityDecor.add_block_lights).
const POLE_OFFSET: float = CityLayout.BLOCK_SIZE / 2.0 - 0.7
const BULB_COLORS: Array[Color] = [
	Color(1.0, 0.82, 0.3),   # amarelo
	Color(1.0, 0.5, 0.2),    # laranja
	Color(1.0, 0.35, 0.55),  # rosa
	Color(0.55, 0.95, 0.4),  # verde
	Color(0.4, 0.8, 1.0),    # azul claro
]
## Brilho das lâmpadas: fraquinhas de dia, fortes à noite.
const ENERGY_DAY: float = 0.6
const ENERGY_NIGHT: float = 3.0
const SHADER: Shader = preload("res://worlds/city/district_props/string_lights.gdshader")
## Os quatro lados do quarteirão: para onde fica o vizinho.
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

## Os prédios e o quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []
var cell: Vector2i = Vector2i.ZERO

var _bulb_material: ShaderMaterial
var _wire_material: StandardMaterial3D
var _bulbs: MultiMeshInstance3D
var _wires: MultiMeshInstance3D
var _rebuild_queued: bool = false


func _ready() -> void:
	add_to_group("city_night")
	_bulb_material = ShaderMaterial.new()
	_bulb_material.shader = SHADER
	_wire_material = StandardMaterial3D.new()
	_wire_material.albedo_color = Color(0.06, 0.06, 0.07)
	_wire_material.roughness = 0.8
	_rebuild()
	# Poste novo perto daqui (quarteirão vizinho que a cidade acabou de montar):
	# o varal se refaz para atravessar a rua.
	get_parent().child_entered_tree.connect(_on_world_child_added)
	set_night(0.0)


func _on_world_child_added(node: Node) -> void:
	var light := node as StreetLight
	if light == null or _rebuild_queued:
		return
	var offset := light.position - CityLayout.block_center(cell)
	if absf(offset.x) > CityLayout.BLOCK_PITCH * 1.5 or absf(offset.z) > CityLayout.BLOCK_PITCH * 1.5:
		return  # poste longe demais para ser de um vizinho
	_rebuild_queued = true
	_rebuild.call_deferred()


## (Re)monta o varal inteiro: descobre os fios e desenha fios e lâmpadas.
func _rebuild() -> void:
	_rebuild_queued = false
	_clear()
	var cords := _find_cords()
	if cords.is_empty():
		return

	var wire_transforms: Array[Transform3D] = []
	var bulb_transforms: Array[Transform3D] = []
	var bulb_colors: Array[Color] = []
	for cord_index in cords.size():
		var start: Vector3 = cords[cord_index][0]
		var end: Vector3 = cords[cord_index][1]
		var length := start.distance_to(end)
		var sag := maxf(SAG, length * SAG_PER_METER)
		# Fio: pedacinhos retos entre pontos da curva.
		var pieces := maxi(6, ceili(length / WIRE_PIECE))
		for i in pieces:
			var a := _cord_point(start, end, sag, float(i) / pieces)
			var b := _cord_point(start, end, sag, float(i + 1) / pieces)
			var basis := Basis.looking_at(b - a, Vector3.UP) \
					* Basis.from_scale(Vector3(WIRE_THICKNESS, WIRE_THICKNESS, a.distance_to(b)))
			wire_transforms.append(Transform3D(basis, (a + b) / 2.0))
		# Lâmpadas: uma a cada 0,7 m, sem encostar nos postes das pontas.
		var bulbs := maxi(1, roundi(length / BULB_SPACING))
		for i in bulbs:
			var spot := _cord_point(start, end, sag, (i + 0.5) / bulbs) - Vector3(0.0, BULB_DROP, 0.0)
			bulb_transforms.append(Transform3D(Basis.IDENTITY, spot))
			bulb_colors.append(BULB_COLORS[(i + cord_index) % BULB_COLORS.size()])

	_wires = _make_multimesh("Wires", BoxMesh.new(), wire_transforms, [], _wire_material, false)
	var sphere := SphereMesh.new()
	sphere.radius = BULB_RADIUS
	sphere.height = BULB_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_bulbs = _make_multimesh("Bulbs", sphere, bulb_transforms, bulb_colors, _bulb_material, true)


## Os fios do quarteirão: uma lista de [ponta A, ponta B] (na altura do poste).
func _find_cords() -> Array[Array]:
	var cords: Array[Array] = []
	var world := get_parent()
	var center := CityLayout.block_center(cell)
	var mine := DistrictProps.lights_in_block(world, cell)
	for side in SIDES:
		var poles := _poles_on_side(mine, center, side)
		if poles.size() < 2:
			continue
		var neighbor := cell + side
		var neighbor_poles := DistrictProps.lights_in_block(world, neighbor)
		if neighbor_poles.is_empty():
			# Sem vizinho: liga os dois postes deste lado, ao longo da rua.
			cords.append([_top(poles[0].position), _top(poles[1].position)])
		elif _owns_crossing(world, side, neighbor):
			# Com vizinho: cada poste liga ao "equivalente" do outro lado da rua.
			var neighbor_center := CityLayout.block_center(neighbor)
			for pole in poles:
				var offset := pole.position - center
				# O poste equivalente é o espelho deste, do outro lado da rua.
				var mirrored := Vector3(-offset.x, 0.0, offset.z) if side.x != 0 else Vector3(offset.x, 0.0, -offset.z)
				var partner := _pole_near(neighbor_poles, neighbor_center + mirrored)
				if partner != null:
					cords.append([_top(pole.position), _top(partner.position)])
	return cords


## Quem desenha o fio que atravessa a rua entre dois quarteirões? Se o vizinho
## também é Casual, só um dos dois (o do lado oeste/norte), para não duplicar.
func _owns_crossing(world: Node, side: Vector2i, neighbor: Vector2i) -> bool:
	if side.x > 0 or side.y > 0:
		return true
	return not world.has_node("DistrictProps_casual_%d_%d" % [neighbor.x, neighbor.y])


## Os postes deste lado do quarteirão (norte, sul, oeste ou leste).
func _poles_on_side(lights: Array[StreetLight], center: Vector3, side: Vector2i) -> Array[StreetLight]:
	var found: Array[StreetLight] = []
	for light in lights:
		var offset := light.position - center
		if offset.x * side.x + offset.z * side.y > 0.0:
			found.append(light)
	return found


func _pole_near(lights: Array[StreetLight], spot: Vector3) -> StreetLight:
	for light in lights:
		if light.position.distance_to(spot) < 0.6:
			return light
	return null


## Altura em que o fio prende no poste.
func _top(pole_position: Vector3) -> Vector3:
	return Vector3(pole_position.x, CORD_HEIGHT, pole_position.z)


## Ponto do fio em t (0 a 1): reto por cima do chão, com a barriga no meio.
## y = y0 - barriga * (1 - (2t - 1)^2)
func _cord_point(start: Vector3, end: Vector3, sag: float, t: float) -> Vector3:
	var point := start.lerp(end, t)
	point.y = start.y - sag * (1.0 - pow(2.0 * t - 1.0, 2.0))
	return point


func _make_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D],
		colors: Array[Color], material: Material, use_colors: bool) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = use_colors  # antes de definir o número de cópias
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if use_colors:
			multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _clear() -> void:
	for old in [_bulbs, _wires]:
		if old != null:
			remove_child(old)  # sai já (senão o novo ganharia outro nome)
			old.queue_free()
	_bulbs = null
	_wires = null


## Lâmpadas fraquinhas de dia e fortes à noite.
func set_night(night: float) -> void:
	_bulb_material.set_shader_parameter("energy", lerpf(ENERGY_DAY, ENERGY_NIGHT, night))


## Quantas lâmpadas tem o varal (para os testes).
func get_bulb_count() -> int:
	return _bulbs.multimesh.instance_count if _bulbs != null else 0
