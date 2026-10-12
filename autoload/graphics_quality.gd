class_name GraphicsQuality
extends RefCounted
## As três qualidades do 3D (ajudante estático, NÃO é autoload):
##
##   alta:  tudo ligado (reflexos na tela, sombreamento extra nos cantos,
##          névoa volumétrica); bordas lisas com MSAA 2x + SMAA.
##   media: sem os reflexos na tela (SSR), que são o efeito mais caro; bordas
##          com SMAA.
##   leve:  sem reflexos, sem sombreamento extra (SSAO) e sem névoa
##          volumétrica; o 3D é desenhado em 50% da resolução e ampliado com
##          FSR; bordas com FXAA (o mais barato); sombra do sol mais curta e
##          com menos detalhe. Para PCs fracos.
##
## A neblina e o brilho (glow) ficam em todas: são baratos e fazem o clima.
## O AppConfig aplica a parte da janela (resolução do 3D, anti-aliasing e o
## tamanho da sombra do sol); cada mundo aplica a parte do seu Environment e
## do seu sol (e escuta AppConfig.settings_changed).

const LOW_3D_SCALE: float = 0.5
## Até onde (m) o sol faz sombra, e o tamanho (px) da imagem da sombra do sol.
const SUN_SHADOW_DISTANCE: float = 120.0
const LOW_SUN_SHADOW_DISTANCE: float = 70.0
const SUN_SHADOW_ATLAS: int = 4096
const LOW_SUN_SHADOW_ATLAS: int = 2048


## Liga e desliga os efeitos do Environment de um mundo.
static func apply_to_environment(environment: Environment, level: String) -> void:
	environment.ssr_enabled = level == "alta"
	environment.ssao_enabled = level != "leve"
	# Névoa volumétrica: só onde o mundo pôs um FogVolume (ex.: névoa baixa do
	# bairro Terror). Na Leve fica desligada.
	environment.volumetric_fog_enabled = level != "leve"


## Na janela: resolução do 3D (o HUD continua nítido: ele não é 3D), o
## anti-aliasing (tira os "degraus" das bordas) e o tamanho da imagem da
## sombra do sol (vale para todos os mundos).
static func apply_to_viewport(viewport: Viewport, level: String) -> void:
	match level:
		"leve":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			viewport.scaling_3d_scale = LOW_3D_SCALE
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"media":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
		_:
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	RenderingServer.directional_shadow_atlas_set_size(
			LOW_SUN_SHADOW_ATLAS if level == "leve" else SUN_SHADOW_ATLAS, true)


## O sol de um mundo: na Leve, a sombra vai só até LOW_SUN_SHADOW_DISTANCE.
static func apply_to_sun(light: DirectionalLight3D, level: String) -> void:
	light.directional_shadow_max_distance = LOW_SUN_SHADOW_DISTANCE if level == "leve" else SUN_SHADOW_DISTANCE


## Quanto do clima (chuva, por exemplo) fica ligado: 100% na Alta, 60% na
## Média, 25% na Leve (partículas transparentes pesam em PCs fracos).
static func weather_amount(level: String) -> float:
	match level:
		"leve":
			return 0.25
		"media":
			return 0.6
	return 1.0


## Tamanho (px) da imagem do espelho da casa (Fase 13.10). Mesma proporção do
## vidro (8:15): na Leve, 240 × 450.
static func mirror_resolution(level: String) -> Vector2i:
	match level:
		"leve":
			return Vector2i(240, 450)
		"media":
			return Vector2i(320, 600)
	return Vector2i(480, 900)


## Na Leve, o espelho desenha um quadro sim, um não (30 vezes por segundo).
static func mirror_every_other_frame(level: String) -> bool:
	return level == "leve"


## Nome para mostrar ("Média") e uma frase explicando.
static func describe(level: String) -> String:
	match level:
		"leve":
			return "Sem reflexos nem sombreamento extra; 3D em 50%, bordas com FXAA e sombra curta. Para PCs fracos."
		"media":
			return "Sem os reflexos na tela; bordas lisas com SMAA. Mais leve, quase igual."
	return "Tudo ligado: reflexos, sombreamento, neblina e bordas lisas (MSAA 2x + SMAA)."
