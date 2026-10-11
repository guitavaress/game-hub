class_name WorldProfile
extends Resource
## Um MUNDO: a lista dos bairros, em ordem (Fase 7). Hoje existe um só, a
## cidade (profiles/world_profile.tres); no futuro, um bioma pode ser outro.
##
## A ordem da lista é a ordem dos bairros na cidade: o primeiro fica mais
## perto da praça. Para acrescentar um bairro, arraste o .tres dele para a
## lista "Districts" no inspetor.

## Nome para mostrar (ex.: "Cidade").
@export var display_name: String = ""
## Os bairros, em ordem.
@export var districts: Array[DistrictProfile] = []
## O fundo do mundo: um som de loop, sem posição, que toca em qualquer lugar
## (canal "Ambiente"). Em casa ele fica abafado, como o resto do canal.
## Só o "loop" faz sentido aqui; a distância e o tamanho são ignorados.
@export var ambience_bed: AmbienceSpec
