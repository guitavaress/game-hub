class_name ScatterSpec
extends Resource
## Uma família de elementos espalhados. Alturas e folgas em metros.

@export_file var source: String = ""
@export_enum("impostor", "mesh") var kind: String = "mesh"
## Instâncias por 100 m²; ajuste visual nas etapas de distribuição.
@export var density: float = 1.0
@export var height_range: Vector2 = Vector2(1.0, 1.0)
@export var tint: Color = Color.WHITE
@export var collision_radius: float = 0.0
## Distância mínima da área caminhável, além das exclusões das portas.
@export var walkable_clearance: float = 0.0
@export var in_town: bool = true
@export var on_backdrop: bool = false
