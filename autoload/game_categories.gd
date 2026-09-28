extends Node
## GameCategories: decide a CATEGORIA de cada jogo (autoload).
##
## Na cidade, cada categoria vira um bairro; num mundo futuro, pode virar um
## bioma. Por isso isto é um sistema, e não parte da cidade.
##
## A regra:
##   1. Se o usuário forçou uma categoria no config.cfg, vale ela.
##   2. Senão, olhamos as tags do jogo na loja (StoreInfo), da mais votada para
##      a menos votada. A primeira tag que aparecer na tabela abaixo decide.
##      Tags genéricas ("Um Jogador", "Indie", "Multijogador"...) não estão na
##      tabela, então são puladas.
##   3. Se nenhuma tag servir (ou não tivermos as tags), vai para "outros".
##
## Para mudar os bairros, edite a tabela CATEGORIES. Os números são os IDs das
## tags da Steam (o nome em português está no comentário ao lado).
## Cada categoria tem duas cores: "color" (tom discreto, no chão e na parede)
## e "neon" (a cor de luz: letreiros, faixas, mira, telas).

const OTHER_ID: String = "outros"

const CATEGORIES: Array[Dictionary] = [
	{
		"id": "esportes", "name": "Esportes e Corrida", "color": Color("3f8f5a"), "neon": Color("4CFF88"),
		"tags": [
			701,      # Esportes
			1254546,  # Futebol
			1254552,  # Futebol Americano
			699,      # Corrida
			1746,     # Basquete
			7038,     # Golfe
			22955,    # Minigolfe
			1753,     # Skate
			5914,     # Tênis
			5727,     # Beisebol
			324176,   # Hóquei
			12190,    # Boxe
			47827,    # Luta Livre
			19568,    # Ciclismo
			7309,     # Esqui
			28444,    # Snowboard
			17927,    # Pool (sinuca)
			7328,     # Boliche
			1100687,  # Simulador Automobilístico
			7622,     # Estrada de Terra
			15868,    # Motocross
			252854,   # BMX
		],
	},
	{
		"id": "rpg", "name": "RPG e Fantasia", "color": Color("7b5ea7"), "neon": Color("934CFF"),
		"tags": [
			122,      # RPG
			4434,     # JRPG
			4231,     # RPG de Ação
			4474,     # CRPG
			10695,    # RPG de Grupos
			4325,     # Combate em Turnos
			21725,    # RPG Tático
			17305,    # RPG de Estratégia
			1754,     # MMORPG
			29482,    # Soulslike
			1720,     # Explorador de Calabouços
		],
	},
	{
		"id": "sobrevivencia", "name": "Sobrevivência e Terror", "color": Color("8a3c42"), "neon": Color("FF4C5B"),
		"tags": [
			1662,     # Sobrevivência
			1100689,  # Sobrevivência em Mundo Aberto
			1667,     # Terror
			3978,     # Terror de Sobrevivência
			1721,     # Terror Psicológico
			1659,     # Zumbis
			7432,     # Lovecraftiano
		],
	},
	{
		"id": "simulacao", "name": "Simulação e Construção", "color": Color("c9be4a"), "neon": Color("FFF04C"),
		"tags": [
			220585,   # Simulador de Colônias
			7332,     # Construção de Bases
			87918,    # Simulador Rural
			10235,    # Simulador de Vida Real
			12472,    # Gerenciamento
			4328,     # Construção de Cidades
			1643,     # Construção
			255534,   # Automação
			4695,     # Economia
			22602,    # Agricultura
			4520,     # Rural
			16598,    # Simulador Espacial
			15045,    # Voo
			3810,     # Faça o que Quiser (sandbox)
			599,      # Simulação
		],
	},
	{
		"id": "estrategia", "name": "Estratégia e Tática", "color": Color("4a6fa5"), "neon": Color("4C95FF"),
		"tags": [
			9,        # Estratégia
			1676,     # Estratégia em Tempo Real (RTS)
			1741,     # Estratégia em Turnos
			4364,     # Grande Estratégia
			1670,     # 4X
			1645,     # Defesa de Torres
			1708,     # Tático
			4684,     # Jogo de Guerra
			3813,     # Tática em Tempo Real
			14139,    # Tática por Turnos
			1084988,  # Batalha Automática
		],
	},
	{
		"id": "acao", "name": "Ação e Roguelike", "color": Color("c0623a"), "neon": Color("FF824C"),
		"tags": [
			42804,    # Roguelike de Ação
			1716,     # Roguelike
			3959,     # Roguelite
			19,       # Ação
			1774,     # Tiro
			1663,     # Tiro em Primeira Pessoa (FPS)
			3814,     # Tiro em Terceira Pessoa
			1646,     # Hack and Slash
			4885,     # Inferno de Balas
			4637,     # SHMUP com Visão Superior
			4758,     # Controle com Alavanca Dupla
			4255,     # Mandando Bala
			1773,     # Arcade
			1743,     # Luta
			4158,     # Porradaria
			1625,     # Plataforma
			5379,     # Plataforma 2D
			3877,     # Plataforma de Precisão
			1628,     # Metroidvania
			176981,   # Battle Royale
			3955,     # Jogo de Ação Focado em Personagem
			353880,   # Tiro com Saques
			1680,     # Assalto
			1687,     # Furtivo
		],
	},
	{
		"id": "cartas", "name": "Cartas e Tabuleiro", "color": Color("2f8f8a"), "neon": Color("4CFFF6"),
		"tags": [
			1666,     # Cartas
			32322,    # Montagem de Decks
			1091588,  # Montagem de Decks Roguelike
			791774,   # Batalha com Cartas
			9271,     # Jogo de Cartas
			1770,     # Jogo de Tabuleiro
			17389,    # Jogo de Mesa
			4184,     # Xadrez
			13070,    # Solitário
			7556,     # Dados
			33572,    # Mahjong
		],
	},
	{
		"id": "aventura", "name": "Aventura e Mistério", "color": Color("d09a3c"), "neon": Color("FFBD4C"),
		"tags": [
			1664,     # Quebra-Cabeça
			5716,     # Mistério
			5613,     # Detetive
			8369,     # Investigação
			5537,     # Plataforma com Quebra-Cabeça
			1698,     # Apontar e Clicar
			5900,     # Simulador de Caminhada
			3799,     # Romance Visual
			1738,     # Objetos Ocultos
			769306,   # Fuja da Sala
			11014,    # Ficção Interativa
			4486,     # Escolha a sua Aventura
			21,       # Aventura
			3834,     # Exploração
		],
	},
	{
		"id": "casual", "name": "Casual e Festa", "color": Color("d27aa0"), "neon": Color("FF4C9A"),
		"tags": [
			597,      # Casual
			7178,     # Reúna a Galera
			7108,     # Em Grupos
			1654,     # Relaxante
			97376,    # Aconchegante
			1752,     # Ritmo
			1621,     # Música
			10437,    # Perguntas e Respostas
			379975,   # Clicker
			615955,   # Progressão Ociosa
			1665,     # Combinar 3
			5350,     # Para Toda a Família
		],
	},
	{
		"id": OTHER_ID, "name": "Outros", "color": Color("7d8590"), "neon": Color("DDE3EA"),
		"tags": [],
	},
]

## Tag -> id da categoria. Montado a partir da tabela, para buscar rápido.
var _category_by_tag: Dictionary[int, String] = {}


func _ready() -> void:
	for category in CATEGORIES:
		for tag: int in category["tags"]:
			if _category_by_tag.has(tag):
				push_warning("GameCategories: a tag %d está em duas categorias." % tag)
				continue
			_category_by_tag[tag] = category["id"]


## Id da categoria do jogo (ex.: "rpg"). Nunca devolve vazio.
func get_category_id(app_id: int) -> String:
	var forced := AppConfig.get_category_override(app_id)
	if not forced.is_empty():
		if has_category(forced):
			return forced
		push_warning("config.cfg: o bairro \"%s\" (jogo %d) não existe." % [forced, app_id])

	for tag in StoreInfo.get_tags(app_id):
		if _category_by_tag.has(tag):
			return _category_by_tag[tag]
	return OTHER_ID


## Todos os ids de categoria, na ordem da tabela.
func get_category_ids() -> Array[String]:
	var ids: Array[String] = []
	for category in CATEGORIES:
		ids.append(category["id"])
	return ids


func has_category(category_id: String) -> bool:
	return category_id in get_category_ids()


## Nome para mostrar (ex.: "RPG e Fantasia").
func get_category_name(category_id: String) -> String:
	return _find(category_id).get("name", category_id)


## Cor de néon da categoria (a cor "de luz" do bairro). Escolhidas à mão
## (saturação 70%, brilho 100%) para que dois bairros não fiquem com cores
## parecidas; "Outros" é um branco frio.
func get_neon_color(category_id: String) -> Color:
	var category := _find(category_id)
	if category.has("neon"):
		return category["neon"]
	return Color.from_hsv(get_category_color(category_id).h, 0.7, 1.0)


## Cor da categoria (usada nos bairros da cidade, por exemplo).
func get_category_color(category_id: String) -> Color:
	return _find(category_id).get("color", Color.GRAY)


func _find(category_id: String) -> Dictionary:
	for category in CATEGORIES:
		if category["id"] == category_id:
			return category
	return {}
