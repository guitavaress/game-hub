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
## montanha vira zona do bairro (get_zone_rects).
## 15.9.3: os limites e a sinalização da trilha (TrailDressing: paredes,
## estacas, lampiões, pilares e placa) e o material de neve e rocha (quem
## monta passa com use_material; sem ele, fica o cinza do greybox).
## 15.10: a plataforma de madeira na beirada virada para a praça (LookoutDeck),
## e o bloco cinza sai: a torre de verdade é o marco do bairro, que a cidade
## ancora em tower_spot().
##
## Uso: setup(); se der true, chamar build_next() até devolver false (um pedaço
## por chamada, para a montagem não travar o quadro).
##
## Contrato com as ferramentas (tools/medir_desempenho.gd, capturar_pontos.gd):
## o nó fica no grupo "mountain_trail" e responde trail_world_points(),
## lookout_world() e (15.10) view_world(), o ponto da vista na plataforma.

const GROUP: StringName = &"mountain_trail"
## A colisão vai além da trilha e do mirante este tanto (encosta pisável).
const COLLISION_MARGIN: float = 12.0
## O vão da mureta: a largura da trilha mais esta folga de cada lado.
const OPENING_SIDE_GAP: float = 0.5
## Profundidade do retângulo do vão (atravessa a mureta, que tem 0,6 m).
const OPENING_DEPTH: float = 2.0
## Rede de segurança: as paredes da trilha seguram o jogador, mas, se algo
## escapar, ele para aqui, abaixo do chão, em vez de cair para sempre.
const SAFETY_FLOOR_Y: float = -1.0
## Da praça, o mirante (e a torre) fica pelo menos este ângulo fora da
## bissetriz da cunha, para o obelisco do relógio não tapar a torre.
const LOOKOUT_MIN_ANGLE: float = deg_to_rad(18.0)
## Os desvios tentados para a linha da subida, do menor ao maior.
const AIM_SHIFTS: Array[float] = [deg_to_rad(12.0), deg_to_rad(18.0), deg_to_rad(24.0), deg_to_rad(30.0)]
## A torre fica atrás do meio do mirante, do lado longe da praça (a frente
## fica livre para a plataforma e a vista).
const TOWER_BACK_SHARE: float = 0.5
const TERRAIN_SHADER: Shader = preload("res://worlds/city/biome/terrain.gdshader")

## Tamanho do quadrado da grade (m) e se a malha faz sombra (15.14): quem monta
## escolhe pela qualidade (GraphicsQuality), ANTES do setup().
var cell_meters: float = 3.0
var casts_shadow: bool = true

var field: Heightfield
var trail: MountainTrail
## A marca dos passos na colisão (ex.: "snow"). Vazio = sem marca.
var footstep: String = ""
## A pedra dos pilares da entrada (null = cinza).
var stone_material: Material = null

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
	_coords = TerrainMesh.chunk_coords(field, cell_meters)
	_collision_rect = TerrainCollision.aligned_rect(field, trail.bounds().grow(COLLISION_MARGIN), cell_meters)
	_material = ShaderMaterial.new()
	_material.shader = TERRAIN_SHADER
	add_to_group(GROUP)
	return true


## O material da montanha (neve e rocha). Chamar antes do primeiro build_next().
func use_material(material: ShaderMaterial) -> void:
	_material = material


## Monta o próximo pedaço da malha. Falso quando acabou (aí entram a colisão,
## a plataforma do mirante, os limites e a sinalização e a rede de segurança).
func build_next() -> bool:
	if _next < _coords.size():
		var mesh := TerrainMesh.build_chunk(field, _coords[_next], cell_meters, _material)
		if mesh != null:
			var chunk := MeshInstance3D.new()
			chunk.name = "Chunk_%d_%d" % [_coords[_next].x, _coords[_next].y]
			chunk.mesh = mesh
			if not casts_shadow:
				chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(chunk)
			if TerrainMesh.chunk_rect(field, _coords[_next], cell_meters).intersects(_collision_rect):
				_faces.append_array(TerrainCollision.faces_in(mesh, _collision_rect))
		_next += 1
		return true
	if _next == _coords.size():
		_next += 1
		_add_collision()
		# O mirante (17.8): planeja agora e monta um pedaço por chamada.
		var deck := LookoutDeck.new()
		deck.setup(field, trail)
		add_child(deck)
		return true
	var building := get_deck()
	if building != null and building.build_next():
		return true
	if get_dressing() == null:
		var dressing := TrailDressing.new()
		add_child(dressing)
		dressing.setup(field, trail, stone_material)
		_add_safety_floor()
	return false


## Os limites e a sinalização da trilha (null antes de a montagem acabar).
func get_dressing() -> TrailDressing:
	return get_node_or_null("TrailDressing") as TrailDressing


## Os pontos do chão da trilha (no mundo), do vão da mureta até o mirante, de 1 em 1 m.
func trail_world_points() -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in trail.points.size():
		result.append(Vector3(trail.points[i].x, trail.heights[i], trail.points[i].y))
	return result


## O centro do piso do mirante, no mundo.
func lookout_world() -> Vector3:
	return Vector3(trail.lookout_center.x, field.lookout_height, trail.lookout_center.y)


## A plataforma de madeira do mirante (null antes de a montagem acabar, ou se
## ela não coube).
func get_deck() -> LookoutDeck:
	return get_node_or_null("LookoutDeck") as LookoutDeck


## O ponto do chão de onde se olha a vista (no mundo): na ponta da plataforma
## (o centro do disco, se ela não coube). As capturas "mirante" ficam aqui.
func view_world() -> Vector3:
	return LookoutDeck.view_spot(field, trail, LookoutDeck.direction(field, trail))


## Onde fica a base da torre do bairro (no mundo): no mirante, atrás do meio
## do disco, do lado longe da praça. A cidade ancora o marco do bairro aqui.
func tower_spot() -> Vector3:
	var away := trail.lookout_center.normalized()
	var spot := trail.lookout_center + away * field.lookout_radius * TOWER_BACK_SHARE
	return Vector3(spot.x, field.lookout_height, spot.y)


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

