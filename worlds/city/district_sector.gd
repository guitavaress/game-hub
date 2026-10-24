class_name DistrictSector
extends RefCounted
## Plano espacial de um bairro. O primeiro bloco recebe o pórtico.
## No plano por anéis (CityLayout.ring_plan) não há vagas nem cunha; no plano
## por setores (SectorLayout.plan) o território inclui as vagas da fatia.

var blocks: Array[Vector2i] = []
var territory: Array[Vector2i] = []
## Limites angulares em radianos, a partir do norte no sentido horário.
## "x" fica entre 0 e 2π; "y" é maior que "x" e pode passar de 2π.
var wedge: Vector2 = Vector2.ZERO


## Células do território no anel externo da cidade, passado pelo chamador.
## Sem argumento, usa o anel mais distante deste território.
func border_cells(outer_ring: int = -1) -> Array[Vector2i]:
	var ring: int = outer_ring
	if ring < 0:
		for cell: Vector2i in territory:
			ring = maxi(ring, CityLayout.ring_of(cell))
	var result: Array[Vector2i] = []
	for cell: Vector2i in territory:
		if CityLayout.ring_of(cell) == ring:
			result.append(cell)
	return result


## O meio da cunha (de 0 a 2π), a direção "para fora" do bairro.
func bisector() -> float:
	return fposmod((wedge.x + wedge.y) / 2.0, TAU)
