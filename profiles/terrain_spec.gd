class_name TerrainSpec
extends Resource
## Dimensões em metros e materiais do terreno. Não conhece o gerador do mundo.

@export var peak_height: float = 90.0
@export var lookout_height: float = 32.0
@export var max_grade: float = 0.15
@export var trail_width: float = 3.0
@export var apron: float = 8.0
@export var outer_radius: float = 370.0
@export var edge_fade_degrees: float = 10.0
@export var lookout_radius: float = 9.0
@export var noise_seed: int = 1515
@export var noise_frequency: float = 0.006
## Nomes das pastas em assets/ambientcg/.
@export var snow_folder: String = ""
@export var rock_folder: String = ""
@export_range(0.0, 1.0) var snow_slope: float = 0.75
