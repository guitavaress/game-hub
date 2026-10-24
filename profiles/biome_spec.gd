class_name BiomeSpec
extends Resource
## Aparência e ambiente de um bioma. O perfil só guarda dados.

@export var id: String = ""
@export var display_name: String = ""
@export_group("Chão")
## Pastas relativas a assets/ambientcg/.
@export var ground_folder: String = ""
@export var ground_meters: float = 1.0
@export var ground_tint: Color = Color.WHITE
@export var ground_normal_strength: float = 1.0
@export var path_folder: String = ""
@export var path_tint: Color = Color.WHITE
@export var footstep: String = ""
@export var cover_streets: bool = false
@export_group("Elementos")
## Vazio herda a casca do bairro.
@export var shell: String = ""
@export var scatter: Array[ScatterSpec] = []
@export_range(0.0, 1.0) var snow_cover: float = 0.0
@export var backdrop: TerrainSpec
@export_group("Atmosfera")
## Vazio herda o clima do bairro.
@export var weather: WeatherSpec
@export var ambience_bed: AmbienceSpec
@export var fog_density_scale: float = 1.0
@export var fog_tint: Color = Color.WHITE
@export_range(0.0, 1.0) var fog_tint_amount: float = 0.0
@export var fog_height_density: float = 0.0
@export var fog_blend_meters: float = 12.0
