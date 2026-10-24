class_name DistrictSector
extends RefCounted
## Plano espacial de um bairro. O primeiro bloco recebe o pórtico.
## Nos anéis não há vagas nem cunha; a 15.3 preencherá esses dados.

var blocks: Array[Vector2i] = []
var territory: Array[Vector2i] = []
## Limites angulares em radianos, a partir do norte no sentido horário.
var wedge: Vector2 = Vector2.ZERO


## Células do território no anel externo da cidade, passado pelo chamador.
## Sem argumento, usa o anel mais distante deste território.
func border_cells(outer_ring: int = -1) -> Array[Vector2i]:
	var ring: int = outer_ring
	if ring < 0:
		for cell: Vector2i in territory:
			ring = maxi(ring, maxi(absi(cell.x), absi(cell.y)))
	var result: Array[Vector2i] = []
	for cell: Vector2i in territory:
		if maxi(absi(cell.x), absi(cell.y)) == ring:
			result.append(cell)
	return result
