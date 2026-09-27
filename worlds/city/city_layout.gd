class_name CityLayout
extends RefCounted
## Matemática da grade de ruas da cidade: só contas, nenhum nó.
##
## A cidade é uma grade de QUARTEIRÕES separados por RUAS. Cada quarteirão tem
## 2x2 TERRENOS. O quarteirão do meio, (0, 0), é a praça.
##
##   Vista de cima (norte = -Z, para cima; leste = +X, para a direita):
##
##          rua          rua
##     +---------+  +---------+
##     | [0] [1] |  |         |     [0] e [1]: porta virada para o NORTE
##     | [2] [3] |  |  praça  |     [2] e [3]: porta virada para o SUL
##     +---------+  +---------+
##          rua          rua
##
## Os quarteirões são usados em "anéis" em volta da praça: primeiro os 8
## vizinhos (anel 1), depois os 16 seguintes (anel 2), e assim por diante.
## Dentro de um anel, começamos no norte e giramos no sentido horário.

const LOT_SIZE: float = 14.0
const STREET_WIDTH: float = 10.0
const BLOCK_SIZE: float = LOT_SIZE * 2.0
## Distância entre os centros de dois quarteirões vizinhos.
const BLOCK_PITCH: float = BLOCK_SIZE + STREET_WIDTH
const LOTS_PER_BLOCK: int = 4


## Posições na grade dos primeiros "count" quarteirões, do centro para fora.
## (A praça, (0, 0), nunca entra na lista.)
static func block_cells(count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var ring := 1
	while cells.size() < count:
		var ring_cells: Array[Vector2i] = []
		for x in range(-ring, ring + 1):
			for z in range(-ring, ring + 1):
				if maxi(absi(x), absi(z)) == ring:
					ring_cells.append(Vector2i(x, z))
		ring_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _clockwise_angle(a) < _clockwise_angle(b))
		for cell in ring_cells:
			if cells.size() < count:
				cells.append(cell)
		ring += 1
	return cells


## Centro de um quarteirão, no chão.
static func block_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * BLOCK_PITCH, 0.0, cell.y * BLOCK_PITCH)


## Posição e direção de um terreno (0 a 3). A "frente" (+Z local) do transform
## aponta para a rua onde fica a porta.
static func lot_transform(cell: Vector2i, lot_index: int) -> Transform3D:
	var offset_x := -LOT_SIZE / 2.0 if lot_index % 2 == 0 else LOT_SIZE / 2.0
	var north_row := lot_index < 2
	var offset_z := -LOT_SIZE / 2.0 if north_row else LOT_SIZE / 2.0
	# Fileira norte: gira 180° para a porta (+Z local) apontar para o norte (-Z).
	var basis := Basis(Vector3.UP, PI) if north_row else Basis.IDENTITY
	return Transform3D(basis, block_center(cell) + Vector3(offset_x, 0.0, offset_z))


## Terrenos de um quarteirão, começando pelos que olham para o centro da
## cidade (assim os primeiros jogos ficam de frente para a praça).
static func lots_facing_center_first(cell: Vector2i) -> Array[int]:
	var lots: Array[int] = [0, 1, 2, 3]
	lots.sort_custom(func(a: int, b: int) -> bool:
		return _door_distance(cell, a) < _door_distance(cell, b) - 0.01)
	return lots


## Metade do tamanho do mapa (do centro até a borda), para caber os quarteirões.
static func half_extent(cells: Array[Vector2i]) -> float:
	var ring := 0
	for cell in cells:
		ring = maxi(ring, maxi(absi(cell.x), absi(cell.y)))
	return ring * BLOCK_PITCH + BLOCK_SIZE / 2.0 + STREET_WIDTH


## Ângulo a partir do norte, no sentido horário (de 0 a 2π).
static func _clockwise_angle(cell: Vector2i) -> float:
	return fposmod(atan2(float(cell.x), float(-cell.y)), TAU)


static func _door_distance(cell: Vector2i, lot_index: int) -> float:
	var lot := lot_transform(cell, lot_index)
	var door := lot.origin + lot.basis.z * (LOT_SIZE / 2.0)
	return Vector2(door.x, door.z).length()
