class_name PortalShell
extends Node3D
## O "INVÓLUCRO" da porta de um jogo (Fase 7.4): o que se vê em volta do
## GamePortal. Hoje, na cidade, é um prédio (CityBuilding); pode ser um arco
## de pedra (ArchShell) e, no futuro, um boxe de corrida ou uma caverna.
##
## A casca cuida só da aparência. Toda a lógica de abrir o jogo continua no
## GamePortal, que não sabe em que casca está (regra 3 do CLAUDE.md).
##
## Convenção: a casca ocupa "size" (largura, altura, profundidade) centrada na
## origem, e a FRENTE fica na face +Z (em z = size.z / 2). É ali que fica a
## porta. Para virar a casca, gire este nó.
##
## Quem cria a casca preenche "game", "category_id", "accent_color" e "size"
## ANTES de adicioná-la à cena; no _ready, cada casca monta a sua aparência e
## chama build_portal().

const PORTAL_SCENE: PackedScene = preload("res://components/game_portal/game_portal.tscn")
## Onde o som do bairro fica, em relação à porta: um pouco acima e à frente.
const AMBIENCE_OFFSET: Vector3 = Vector3(0.0, 2.0, 0.5)

## O jogo desta porta.
var game: SteamGame
## Espaço que a casca ocupa (largura, altura, profundidade), em metros.
var size: Vector3 = Vector3(10.0, 14.0, 10.0)
## Cor do bairro (tom discreto).
var accent_color: Color = Color.GRAY
## Categoria do jogo: dá a cor de néon e o som ambiente da porta.
var category_id: String = ""
## O GamePortal criado por build_portal().
var portal: GamePortal = null


## Cor viva do néon do bairro (a mesma dos letreiros, da mira e das telas).
func neon_color() -> Color:
	if not category_id.is_empty():
		return GameCategories.get_neon_color(category_id)
	return Color.from_hsv(accent_color.h, 0.7, 1.0)


## Onde fica a porta, no espaço da casca (origem no chão, +Z para fora).
## Padrão: no meio da frente. Uma casca pode trocar.
func portal_position() -> Vector3:
	return Vector3(0.0, 0.0, size.z / 2.0)


## Tamanho do alvo "olhável": olhar para ele mostra o nome do jogo no HUD.
## Padrão: a frente inteira. Uma casca pode trocar.
func portal_look_size() -> Vector3:
	return Vector3(size.x, size.y, 1.0)


## Cria o GamePortal na porta (nome do nó: "GamePortal") e pendura nele o som
## ambiente do bairro.
func build_portal() -> GamePortal:
	portal = PORTAL_SCENE.instantiate() as GamePortal
	portal.name = "GamePortal"
	portal.app_id = game.app_id
	portal.display_name = game.name
	portal.look_size = portal_look_size()
	portal.position = portal_position()
	add_child(portal)

	for emitter in CategoryAmbience.create(category_id):
		emitter.position = AMBIENCE_OFFSET
		portal.add_child(emitter)
	return portal
