class_name GraphicsQuality
extends RefCounted
## As três qualidades do 3D (ajudante estático, NÃO é autoload):
##
##   alta:  tudo ligado (reflexos na tela, sombreamento extra nos cantos,
##          névoa volumétrica).
##   media: sem os reflexos na tela (SSR), que são o efeito mais caro.
##   leve:  sem reflexos, sem sombreamento extra (SSAO) e sem névoa
##          volumétrica; o 3D é desenhado em 50% da resolução e ampliado com
##          FSR. Para PCs fracos.
##
## A neblina e o brilho (glow) ficam em todas: são baratos e fazem o clima.
## O AppConfig aplica a parte da janela (resolução do 3D); cada mundo aplica a
## parte do seu Environment (e escuta AppConfig.settings_changed).

const LOW_3D_SCALE: float = 0.5


## Liga e desliga os efeitos do Environment de um mundo.
static func apply_to_environment(environment: Environment, level: String) -> void:
	environment.ssr_enabled = level == "alta"
	environment.ssao_enabled = level != "leve"
	# Névoa volumétrica: só onde o mundo pôs um FogVolume (ex.: névoa baixa do
	# bairro Terror). Na Leve fica desligada.
	environment.volumetric_fog_enabled = level != "leve"


## Resolução do 3D na janela (o HUD continua nítido: ele não é 3D).
static func apply_to_viewport(viewport: Viewport, level: String) -> void:
	if level == "leve":
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = LOW_3D_SCALE
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = 1.0


## Quanto do clima (chuva, por exemplo) fica ligado: 100% na Alta, 60% na
## Média, 25% na Leve (partículas transparentes pesam em PCs fracos).
static func weather_amount(level: String) -> float:
	match level:
		"leve":
			return 0.25
		"media":
			return 0.6
	return 1.0


## Nome para mostrar ("Média") e uma frase explicando.
static func describe(level: String) -> String:
	match level:
		"leve":
			return "Sem reflexos nem sombreamento extra; 3D em 50%. Para PCs fracos."
		"media":
			return "Sem os reflexos na tela. Mais leve, quase igual."
	return "Tudo ligado: reflexos, sombreamento e neblina."
