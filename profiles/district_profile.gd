class_name DistrictProfile
extends Resource
## O PERFIL de um bairro: tudo o que muda de um bairro para outro, como dado
## (Fase 7). Um arquivo .tres por bairro em profiles/districts/. A ordem dos
## bairros no mundo é a ordem da lista do WorldProfile (profiles/world_profile.tres).
##
## Ninguém lê isto direto: o GameCategories (categoria de cada jogo, cores,
## nome) e os mundos pedem os perfis ao Profiles.
##
## Bairro novo: no editor, botão direito num .tres de profiles/districts/ >
## Duplicar; troque os campos no inspetor e acrescente o arquivo na lista
## "Districts" do profiles/world_profile.tres.

## Identificador: minúsculas, sem espaços nem acentos. É o que se escreve no
## config.cfg para forçar o bairro de um jogo (ex.: "rpg").
@export var id: String = ""
## Nome para mostrar (ex.: "RPG e Fantasia").
@export var display_name: String = ""
## Tom discreto do bairro: chão do quarteirão e um toque na parede dos prédios.
@export var color: Color = Color.GRAY
## Cor de luz: letreiros, faixas, mira, telas. Totalmente transparente =
## calcular a partir de "color" (mesmo tom, saturação 70%, brilho 100%).
@export var neon: Color = Color(0, 0, 0, 0)
## IDs das tags da loja Steam que trazem um jogo para este bairro. Vale a
## primeira tag do jogo (da mais votada para a menos) que aparecer em algum
## bairro. Uma tag só pode estar em um bairro.
@export var tags: PackedInt32Array = PackedInt32Array()
## O nome de cada tag, na mesma ordem de "tags" (só para ler no inspetor).
@export var tag_names: PackedStringArray = PackedStringArray()

@export_group("Som")
## Sons ambientes da porta de cada prédio do bairro (Fase 7.2).
@export var ambience: Array[AmbienceSpec] = []

@export_group("Enfeite")
## Script do elemento de identidade do bairro (um por quarteirão), ex.:
## res://worlds/city/district_props/rpg_banners.gd. Vazio = nenhum (Fase 7.3).
@export_file("*.gd") var props_script: String = ""

@export_group("Clima")
## Clima do bairro (ex.: garoa à noite). Vazio = tempo normal (Fase 7.6).
@export var weather: WeatherSpec

@export_group("Arquitetura")
## Invólucro da porta de cada jogo: "building" (prédio) ou "arch" (arco)
## (Fase 7.4).
@export var shell: String = "building"
## Chance de cada número de andares (3, 4, 5, 6 e 7). Vazio = o padrão da
## cidade (BuildingVariant.FLOOR_WEIGHTS) (Fase 7.5).
@export var floor_weights: PackedFloat32Array = PackedFloat32Array()
## Chance de cada estilo de parede (CityBuilding.WALL_STYLES). Vazio = todos
## com a mesma chance, como sempre foi (Fase 7.5).
@export var wall_weights: PackedFloat32Array = PackedFloat32Array()

@export_group("Reservado (ainda sem efeito)")
## Quantos jogos por quarteirão. Reservado: a cidade ainda usa 4 para todos.
@export var density: int = 4
## Script de um marco do bairro (como o chafariz da praça). Reservado.
@export_file("*.gd") var landmark_script: String = ""


## A cor de luz do bairro (calculada, se "neon" estiver transparente).
func neon_color() -> Color:
	if neon.a > 0.0:
		return neon
	return Color.from_hsv(color.h, 0.7, 1.0)
