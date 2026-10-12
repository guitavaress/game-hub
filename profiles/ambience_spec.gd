class_name AmbienceSpec
extends Resource
## Um som ambiente de um bairro (parte do DistrictProfile, Fase 7.2).
## Vira um AmbientEmitter pendurado na porta de cada prédio do bairro.

## "loop": um som que toca sem parar (ex.: motor). "avulsos": sons curtos
## sorteados de tempos em tempos (ex.: cartas, moedas).
@export_enum("loop", "avulsos") var kind: String = "avulsos"
## Os arquivos de som (res://...). No "loop", só o primeiro é usado.
@export var files: PackedStringArray = PackedStringArray()
## Volume, em decibéis (0 = original; -10 = bem mais baixo).
@export var volume_db: float = -10.0
## Até que distância (m) o som é ouvido.
@export var max_distance: float = 18.0
## Tamanho do "alto-falante" (quanto maior, mais devagar o som some com a distância).
@export var unit_size: float = 4.0
## Só nos "avulsos": tempo entre um som e outro (mínimo, máximo), em segundos.
@export var interval: Vector2 = Vector2(3.0, 8.0)
## Só nos "avulsos": variação do tom (mínimo, máximo). 1.0 = tom original.
@export var pitch_range: Vector2 = Vector2(0.9, 1.1)
