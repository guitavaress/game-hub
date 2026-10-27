class_name BackdropTerrain
extends Node3D
## A montanha de fundo de um bairro (Fase 15.9), atrás da mureta, na cunha
## dele. É o ponto único do terreno: a cidade só conhece este nó (trocar por
## outro gerador no futuro é escrever outro com a mesma API).
##
## Junta as peças da 15.8: as alturas (Heightfield), a trilha (MountainTrail),
## a malha em pedaços (TerrainMesh) e a colisão com os triângulos desenhados
## (TerrainCollision, o plano B da 15.9.1a).
##
## 15.9.1b (greybox): a malha sai cinza (o terrain.gdshader sem texturas), um
## bloco cinza marca o lugar da torre no mirante, e a colisão cobre a trilha,
## o mirante e um pouco de encosta em volta.
## 15.9.2: o mirante sai da linha praça–obelisco (_plan_off_axis), e a
## montanha vira zona do bairro (get_zone_rects). As paredes da trilha e o
## material de neve e rocha vêm na 15.9.3.
##
## Uso: setup(); se der true, chamar build_next() até devolver false (um pedaço
## por chamada, para a montagem não travar o quadro).
##
## Contrato com as ferramentas (tools/medir_desempenho.gd, capturar_pontos.gd):
## o nó fica no grupo "mountain_trail" e responde trail_world_points() e
## lookout_world().

const GROUP: StringName = &"mountain_trail"
## Tamanho do quadrado da grade (m). Na 15.14 vem do GraphicsQuality.
const CELL_METERS: float = 3.0
## A colisão vai além da trilha e do mirante este tanto (encosta pisável).
const COLLISION_MARGIN: float = 12.0
## O vão da mureta: a largura da trilha mais esta folga de cada lado.
const OPENING_SIDE_GAP: float = 0.5
## Profundidade do retângulo do vão (atravessa a mureta, que tem 0,6 m).
const OPENING_DEPTH: float = 2.0
## Rede de segurança do greybox: quem cair da encosta para fora da colisão
## para aqui, abaixo do chão, em vez de cair para sempre (os limites da
## trilha vêm na 15.9.3).
const SAFETY_FLOOR_Y: float = -1.0
## O bloco cinza no lugar da torre (a forma de verdade, com néon, vem na
## 15.10): a torre mais grossa decidida pelo dono (~6 m) e uma altura de referência.
const TOWER_SIZE: Vector3 = Vector3(6.0, 16.0, 6.0)
## Da praça, o mirante (e a torre) fica pelo menos este ângulo fora da
## bissetriz da cunha, para o obelisco do relógio não tapar a torre.
const LOOKOUT_MIN_ANGLE: float = deg_to_rad(18.0)
## Os desvios tentados para a linha da subida, do menor ao maior.
const AIM_SHIFTS: Array[float] = [deg_to_rad(12.0), deg_to_rad(18.0), deg_to_rad(24.0), deg_to_rad(30.0)]
## A torre fica atrás do meio do mirante (a frente fica livre para a vista).
const TOWER_BACK_SHARE: float = 0.5
const GREYBOX_COLOR: Color = Color(0.5, 0.5, 0.52)
const TERRAIN_SHADER: Shader = preload("res://worlds/city/biome/terrain.gdshader")

var field: Heightfield
var trail: MountainTrail
## A marca dos passos na colisão (ex.: "snow"). Vazio = sem marca.
var footstep: String = ""

var _coords: Array[Vector2i] = []
var _next: int = 0
var _material: ShaderMaterial
var _collision_rect: Rect2 = Rect2()
var _faces: PackedVector3Array = PackedVector3Array()


## Calcula a montanha e a trilha para a cunha do bairro. Falso quando não
## cabe (a cidade grande demais para o raio de fora, ou a trilha não coube):
## aí não há montanha e o nó deve ser descartado.
func setup(spec: TerrainSpec, sector: DistrictSector, half: float) -> bool:
	field = Heightfield.new()
	field.apply_spec(spec)
	field.configure(half, sector.wedge.x, sector.wedge.y)
	var border := sector.border_cells()
	if not field.fits() or border.is_empty():
		return false
	trail = _plan_off_axis(border)
	if trail == null:
		return false
	field.set_trail(trail)
	_coords = TerrainMesh.chunk_coords(field, CELL_METERS)
	_collision_rect = TerrainCollision.aligned_rect(field, trail.bounds().grow(COLLISION_MARGIN), CELL_METERS)
	_material = ShaderMaterial.new()
	_material.shader = TERRAIN_SHADER
	add_to_group(GROUP)
	return true


## Monta o próximo pedaço da malha. Falso quando acabou (aí entram a colisão,
## a rede de segurança e o bloco da torre).
func build_next() -> bool:
	if _next < _coords.size():
		var mesh := TerrainMesh.build_chunk(field, _coords[_next], CELL_METERS, _material)
		if mesh != null:
			var chunk := MeshInstance3D.new()
			chunk.name = "Chunk_%d_%d" % [_coords[_next].x, _coords[_next].y]
			chunk.mesh = mesh
			add_child(chunk)
			if TerrainMesh.chunk_rect(field, _coords[_next], CELL_METERS).intersects(_collision_rect):
				_faces.append_array(TerrainCollision.faces_in(mesh, _collision_rect))
		_next += 1
		return true
	if _next == _coords.size():
		_next += 1
		_add_collision()
		_add_safety_floor()
		_add_tower_marker()
	return false


## Os pontos do chão da trilha (no mundo), do vão da mureta até o mirante, de 1 em 1 m.
func trail_world_points() -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in trail.points.size():
		result.append(Vector3(trail.points[i].x, trail.heights[i], trail.points[i].y))
	return result


## O centro do piso do mirante, no mundo.
func lookout_world() -> Vector3:
	return Vector3(trail.lookout_center.x, field.lookout_height, trail.lookout_center.y)


## Onde a trilha corta a mureta: retângulos (no chão) que a cidade deixa sem
## mureta, sem grade e sem barreira. Hoje, um só.
func get_openings() -> Array[Rect2]:
	var width := field.trail_width + OPENING_SIDE_GAP * 2.0
	var along := Vector2(-trail.outward.y, trail.outward.x).abs()
	var across := trail.outward.abs()
	var size := along * width + across * OPENING_DEPTH
	return [Rect2(trail.start - size / 2.0, size)]


## A altura do chão (montanha, rampa e trilha) num ponto do mundo.
func height_at(point: Vector2) -> float:
	return field.surface_at(point)


## As zonas da montanha no chão (para o clima, a névoa e o vento do bairro):
## a trilha, o mirante e a encosta pisável em volta, só do lado de fora da
## mureta (dentro dela, as zonas são os quarteirões e as vagas).
func get_zone_rects() -> Array[Rect2]:
	var rect := trail.bounds().grow(COLLISION_MARGIN)
	var from := rect.position
	var to := rect.end
	if trail.outward.x > 0.5:
		from.x = maxf(from.x, field.half)
	elif trail.outward.x < -0.5:
		to.x = minf(to.x, -field.half)
	elif trail.outward.y > 0.5:
		from.y = maxf(from.y, field.half)
	else:
		to.y = minf(to.y, -field.half)
	return [Rect2(from, to - from)]


## O ângulo do mirante visto do centro da praça, medido a partir da bissetriz
## da cunha (com sinal).
func lookout_angle() -> float:
	return wrapf(Heightfield.angle_of(trail.lookout_center) - field.wedge_center, -PI, PI)


## A trilha com o mirante fora da linha praça–obelisco: o zigue-zague sobe em
## volta de uma linha desviada da bissetriz, até o mirante ficar a pelo menos
## LOOKOUT_MIN_ANGLE dela (da praça, o obelisco não tapa a torre). Tenta
## primeiro o lado para onde a trilha já tende; sem lugar, fica a trilha na
## bissetriz. null se nem ela couber.
func _plan_off_axis(border: Array[Vector2i]) -> MountainTrail:
	var center := field.wedge_center
	var straight := MountainTrail.plan_from_cell(field, MountainTrail.border_cell_nearest(border, center))
	if not straight.valid:
		return null
	trail = straight
	var natural := lookout_angle()
	if absf(natural) >= LOOKOUT_MIN_ANGLE:
		return straight
	var first_side := 1.0 if natural >= 0.0 else -1.0
	for side: float in [first_side, -first_side]:
		for shift: float in AIM_SHIFTS:
			var aim := center + side * shift
			trail = MountainTrail.plan_from_cell(field, MountainTrail.border_cell_nearest(border, aim), aim)
			if trail.valid and absf(lookout_angle()) >= LOOKOUT_MIN_ANGLE:
				return trail
	return straight


func _add_collision() -> void:
	if _faces.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "TrailCollision"
	if not footstep.is_empty():
		body.set_meta("footstep", footstep)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_faces = PackedVector3Array()


func _add_safety_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "SafetyFloor"
	var collision := CollisionShape3D.new()
	collision.shape = WorldBoundaryShape3D.new()
	body.add_child(collision)
	body.position.y = SAFETY_FLOOR_Y
	add_child(body)


func _add_tower_marker() -> void:
	var away := trail.lookout_center.normalized()
	var spot := trail.lookout_center + away * field.lookout_radius * TOWER_BACK_SHARE
	var mesh := BoxMesh.new()
	mesh.size = TOWER_SIZE
	var tower := MeshInstance3D.new()
	tower.name = "TowerMarker"
	tower.mesh = mesh
	tower.material_override = CityDecor.make_material(GREYBOX_COLOR)
	tower.position = Vector3(spot.x, field.lookout_height + TOWER_SIZE.y / 2.0, spot.y)
	add_child(tower)
