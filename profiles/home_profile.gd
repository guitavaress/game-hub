class_name HomeProfile
extends Resource
## O PERFIL de um tema da casa (Fase 13): tudo o que muda de um tema para outro
## (loft, cabana...), como dado. Um arquivo .tres por tema em profiles/homes/.
## A lista dos temas é o profiles/home_catalog.tres; o primeiro é o padrão.
##
## Ninguém lê isto direto: a casa (worlds/home/) pede o perfil ao Profiles.
##
## Tema novo: no editor, botão direito num .tres de profiles/homes/ > Duplicar;
## troque os campos no inspetor e acrescente o arquivo na lista "Homes" do
## profiles/home_catalog.tres. A sala tem o mesmo tamanho em todos os temas.

## Identificador: minúsculas, sem espaços nem acentos (vai para o config.cfg).
@export var id: String = ""
## Nome para mostrar (ex.: "Loft").
@export var display_name: String = ""

@export_group("Superfícies")
@export var floor: HomeSurface
@export var ceiling: HomeSurface
## A parede da janela (norte).
@export var feature_wall: HomeSurface
## As outras três paredes.
@export var walls: HomeSurface
@export var skirting: HomeSurface
## Vigas do teto. Vazio = sem vigas.
@export var beams: HomeSurface

@export_group("Luz")
## Cor e força das lâmpadas dos pendentes.
@export var lamp_color: Color = Color(1.0, 0.74, 0.48)
@export var lamp_energy: float = 1.5
## Cor do fundo (o que se vê além das paredes).
@export var background_color: Color = Color(0.015, 0.015, 0.02)
## Luz ambiente de noite e de dia (cor e força).
@export var ambient_night_color: Color = Color(0.45, 0.4, 0.36)
@export var ambient_night_energy: float = 0.3
@export var ambient_day_color: Color = Color(0.55, 0.6, 0.68)
@export var ambient_day_energy: float = 0.7
## A luz do dia que entra pela janela.
@export var daylight_color: Color = Color(0.82, 0.88, 1.0)
@export var daylight_energy: float = 2.2

@export_group("Janela")
## Shader da vista (recebe o "night" de 0 a 1).
@export_file("*.gdshader") var window_shader: String = ""
## Moldura da janela e peitoril.
@export var window_frame: HomeSurface
@export var window_sill: HomeSurface

@export_group("Porta")
## A folha da porta da rua, o batente e a maçaneta.
@export var door: HomeSurface
@export var door_frame: HomeSurface
@export var door_handle: HomeSurface

@export_group("Néon")
## Cor padrão da faixa de néon (o usuário pode trocar) e quanto ela brilha.
@export var neon_color: Color = Color(0.95, 0.25, 0.8)
## 0 = sem néon.
@export var neon_energy: float = 4.0
## Força da luz que sai da faixa.
@export var neon_light_energy: float = 0.45

@export_group("Decoração")
## Script do enfeite do tema (móveis de enfeite e luminárias), ex.:
## res://worlds/home/themes/loft_decor.gd. Vazio = nenhum.
@export_file("*.gd") var decor_script: String = ""

@export_group("Som")
## Marca de passos do piso (a "footstep" lida pelo jogador).
@export var footstep: String = "wood"
