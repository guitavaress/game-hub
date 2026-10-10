class_name CityMap
extends Node
## A PLANTA da cidade como dado (Fase 8): quem ocupa cada quarteirão, onde
## ficam o pórtico de cada bairro e a praça. Quem desenha mapas (minimapa,
## mapa grande, bússola) não conhece a cidade: pergunta a quem estiver no
## grupo "world_map" (regras 1 e 2 do CLAUDE.md). Cada mundo publica a sua
## planta; um bioma futuro faz o mesmo.
##
## Tudo é em metros no plano do chão: Vector2(x, z), norte = -Z.
##
## get_map_data() devolve:
##   {"bounds": Rect2,                      limites do mapa
##    "plaza":  Rect2,                      a praça
##    "areas":  [{"id", "name", "color", "neon", "games": int,
##                "rects": Array[Rect2],    quarteirões (com meia rua em volta)
##                "gate": Vector2}],        pórtico (Vector2.INF = sem)
##    "gap": float,                         largura das ruas (quem desenha encolhe os retângulos)
##    "landmarks": [{"kind", "name", "pos": Vector2, "color"}]}   marcos: "metro" (estações), "home" (porta de casa)

const PLAZA_NAME: String = "Praça"

var _bounds: Rect2 = Rect2()
var _plaza: Rect2 = Rect2()
## Bairros na ordem em que apareceram (a ordem do mundo).
var _areas: Array[Dictionary] = []
var _area_index: Dictionary[String, int] = {}
var _landmarks: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("world_map")


## Limites do mapa: um quadrado de "half" metros do centro até a borda.
func set_bounds(half: float) -> void:
	_bounds = Rect2(-half, -half, half * 2.0, half * 2.0)
	_plaza = block_rect(Vector2i.ZERO)


## A área de um quarteirão: ele e metade da rua em volta. Os quarteirões
## vizinhos se encostam sem se sobrepor, então todo ponto da cidade pertence
## a no máximo um deles.
static func block_rect(cell: Vector2i) -> Rect2:
	var center := CityLayout.block_center(cell)
	var half := CityLayout.BLOCK_PITCH / 2.0
	return Rect2(center.x - half, center.z - half, CityLayout.BLOCK_PITCH, CityLayout.BLOCK_PITCH)


## Um quarteirão do bairro "id" (com "games" jogos nele).
func add_block(id: String, cell: Vector2i, games: int) -> void:
	if not _area_index.has(id):
		_area_index[id] = _areas.size()
		_areas.append({
			"id": id,
			"name": GameCategories.get_category_name(id),
			"color": GameCategories.get_category_color(id),
			"neon": GameCategories.get_neon_color(id),
			"games": 0,
			"rects": [] as Array[Rect2],
			"gate": Vector2.INF,
		})
	var area := _areas[_area_index[id]]
	area["games"] = int(area["games"]) + games
	(area["rects"] as Array[Rect2]).append(block_rect(cell))


## Onde fica o pórtico do bairro.
func set_gate(id: String, position: Vector2) -> void:
	if _area_index.has(id):
		_areas[_area_index[id]]["gate"] = position


## Um ponto de interesse ("metro" para estação, "home" para a porta de casa).
func add_landmark(kind: String, landmark_name: String, position: Vector2, color: Color) -> void:
	_landmarks.append({"kind": kind, "name": landmark_name, "pos": position, "color": color})


func get_map_data() -> Dictionary:
	return {"bounds": _bounds, "plaza": _plaza, "areas": _areas, "landmarks": _landmarks,
			"gap": CityLayout.STREET_WIDTH}


## O id do bairro no ponto (x, z) do mundo ("" = praça, rua de fora ou nada).
func area_id_at(position: Vector3) -> String:
	var point := Vector2(position.x, position.z)
	for area in _areas:
		for rect: Rect2 in area["rects"]:
			if rect.has_point(point):
				return area["id"]
	return ""


## O nome para mostrar no ponto: o bairro, "Praça" ou "" (fora do mapa).
func area_name_at(position: Vector3) -> String:
	var id := area_id_at(position)
	if not id.is_empty():
		return _areas[_area_index[id]]["name"]
	if _plaza.has_point(Vector2(position.x, position.z)):
		return PLAZA_NAME
	return ""
