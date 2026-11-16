class_name ScatterSpec
extends Resource
## Uma família de elementos espalhados. Alturas e folgas em metros.

## O que é espalhado, pelo tipo ("kind"):
##   impostor  "source" é o atlas de uma árvore só de foto (TreeImpostor)
##   mesh      "source" é um glTF (a primeira malha dele: as rochas)
##   tree      "source" é um modelo de árvore do Blender (tools/blender/gerar_arvore.py):
##             o modelo de perto e a foto dele de longe (TreeModel, Fase 19.3);
##             o atlas é TreeModel.impostor_path(source)
@export_file var source: String = ""
@export_enum("impostor", "mesh", "tree") var kind: String = "mesh"
## Instâncias por 100 m² da área onde a família pode ficar; ajuste visual nas etapas de distribuição.
@export var density: float = 1.0
@export var height_range: Vector2 = Vector2(1.0, 1.0)
@export var tint: Color = Color.WHITE
## Raio do cilindro de colisão na menor altura de height_range; cresce junto
## com o tamanho de cada cópia. 0 = sem colisão.
@export var collision_radius: float = 0.0
## Distância mínima da área caminhável, além das exclusões das portas.
@export var walkable_clearance: float = 0.0
## Só no tipo "mesh" (19.7): a pasta da ambientCG do material da peça (ex.:
## "Rock058"), com o chão do bioma por cima (BiomeSpec.snow_cover). Vazio = a
## rocha do terreno de fundo (TerrainSpec.rock_folder), se o bioma tiver; senão,
## o material que veio no glTF.
@export var material_folder: String = ""
@export var in_town: bool = true
@export var on_backdrop: bool = false
