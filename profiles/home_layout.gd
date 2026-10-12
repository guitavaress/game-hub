class_name HomeLayout
extends Resource
## Uma DISPOSIÇÃO pronta dos móveis da casa (Fase 13): em qual lugar fixo da
## parede fica cada móvel. Sem arrastar livre: são lugares prontos.

## Lugares que a casa conhece (as âncoras).
const ANCHORS: Array[String] = ["oeste", "leste", "sul_esquerda", "sul_direita", "norte_esquerda", "norte_direita"]

@export var id: String = ""
@export var display_name: String = ""
## Móvel (id) → lugar (uma das ANCHORS). Ids que a casa conhece: "estante",
## "mural", "estatisticas" e "espelho". O computador fica sempre em "norte_direita".
@export var placements: Dictionary[String, String] = {}
## Quantos graus o jogador gira do norte para o oeste ao nascer.
@export var spawn_turn_degrees: float = 35.0
