class_name ScatterSpec
extends Resource
## Uma família de elementos espalhados. Alturas e folgas em metros.

@export_file var source: String = ""
@export_enum("impostor", "mesh") var kind: String = "mesh"
## Instâncias por 100 m² da área onde a família pode ficar; ajuste visual nas etapas de distribuição.
@export var density: float = 1.0
@export var height_range: Vector2 = Vector2(1.0, 1.0)
@export var tint: Color = Color.WHITE
## Raio do cilindro de colisão na menor altura de height_range; cresce junto
## com o tamanho de cada cópia. 0 = sem colisão.
@export var collision_radius: float = 0.0
## Distância mínima da área caminhável, além das exclusões das portas.
@export var walkable_clearance: float = 0.0
@export var in_town: bool = true
@export var on_backdrop: bool = false
