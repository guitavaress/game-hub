class_name AvatarCatalog
extends Resource
## O CATÁLOGO do provador (Fase 13.11): as cores prontas de cada parte do
## avatar e as combinações prontas ("visuais"). Arquivo: profiles/avatar_catalog.tres.
## O formato do avatar em si é o AvatarSpec; aqui só estão as opções que o
## espelho oferece.

## Cores prontas de cada parte (as chaves são as AvatarSpec.ZONES).
@export var palettes: Dictionary[String, PackedColorArray] = {}
## Os visuais prontos e o nome de cada um (mesma ordem).
@export var preset_names: PackedStringArray = PackedStringArray()
@export var presets: Array[AvatarSpec] = []


## As cores prontas de uma parte (vazio se não houver).
func palette_of(zone: String) -> PackedColorArray:
	return palettes.get(zone, PackedColorArray())
