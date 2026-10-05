class_name WeatherSpec
extends Resource
## O clima de um bairro (parte do DistrictProfile, Fase 7.6).

## "garoa": chuva fina em volta do jogador enquanto ele está no bairro.
@export_enum("garoa") var kind: String = "garoa"
## true = só à noite.
@export var night_only: bool = true
## Quanto de chuva (1.0 = normal). A qualidade gráfica ainda reduz isso.
@export_range(0.0, 2.0, 0.05) var intensity: float = 1.0
