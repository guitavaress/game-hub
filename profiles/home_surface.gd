class_name HomeSurface
extends Resource
## Uma SUPERFÍCIE da casa (Fase 13): de que é feito o chão, a parede, o teto...
## É o dado que o HomeMaterials transforma num material. Faz parte do
## HomeProfile (o tema da casa).

## Tipo de material: "wood" (madeira por shader), "pbr" (textura da ambientCG),
## "matte" (cor fosca), "metal" ou "fabric" (tecido).
@export_enum("wood", "pbr", "matte", "metal", "fabric") var kind: String = "matte"
## Cor (em "pbr", é o tom que escurece ou colore a textura).
@export var color: Color = Color.WHITE
## Só em "pbr": pasta em assets/ambientcg/ (ex.: "Concrete048").
@export var folder: String = ""
## Só em "pbr": tamanho de uma repetição da textura, em metros.
@export var meters: float = 1.0
## Aspereza (0 = espelho, 1 = fosco). Em "pbr", a textura é quem manda.
@export_range(0.0, 1.0, 0.01) var roughness: float = 0.5
## Só em "wood": true = tábuas com fresta (piso); false = veio de móvel.
@export var planks: bool = false
## Só em "wood": true = toras deitadas (paredes de cabana, Fase 13.12).
@export var logs: bool = false
## true = a cor de parede escolhida pelo usuário pinta esta superfície.
@export var paintable: bool = false
