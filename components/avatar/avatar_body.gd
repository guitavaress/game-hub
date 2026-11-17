class_name AvatarBody
extends Node3D
## O CORPO de um avatar (Fase 13.6): carrega o modelo, deixa com a altura certa,
## em pé na origem deste nó e olhando para +Z, pinta cada parte com a cor do
## AvatarSpec e toca as animações (Idle e Walk). Os hologramas dos amigos
## (FriendNpc) usam este corpo com o material de holograma por cima, e o seu
## corpo (PlayerAvatar, Fase 20.3: a primeira pessoa e o espelho) usa com as cores.
##
## Fase 20.1: o corpo também anda sozinho pela velocidade (animate), esconde a
## cabeça (set_head_hidden, para a primeira pessoa) e escolhe como faz sombra
## (set_shadow_mode).
##
## Uso (antes do add_child):
##   var body := AvatarBody.new()
##   body.spec = AvatarSpec.from_dict(dados)   # null = cores padrão
##   add_child(body)                            # ajusta e pinta aqui
##   body.play_idle()

## Um modelo por corpo do AvatarSpec.BODIES.
const BODY_SCENES: Dictionary[String, PackedScene] = {
	"human": preload("res://assets/quaternius/animated_human.glb"),
}
const PALETTE_SHADER: Shader = preload("res://components/avatar/avatar_palette.gdshader")
const IDLE_ANIMATION: String = "Human Armature|Idle"
const WALK_ANIMATION: String = "Human Armature|Walk"
const RUN_ANIMATION: String = "Human Armature|Run"
const JUMP_ANIMATION: String = "Human Armature|Jump"
const DEFAULT_HEIGHT: float = 1.7
## Como o corpo faz sombra: normal, nenhuma, ou só a sombra (o corpo some e a
## sombra fica; é como a sombra com cabeça aparece mesmo na primeira pessoa).
enum ShadowMode { NORMAL, OFF, SHADOWS_ONLY }

## Velocidades horizontais (m/s). O jogador anda a 5 e corre a 9.
## Fase 20.3: a corrida começa em 3,5. Com o Walk até 5 m/s, o passo ficava a
## 3,15 vezes a velocidade normal (um desenho animado); a 5 m/s o Run fica a
## 1,32 e a 9 m/s, a 2,38. Andar a 5 m/s é, de fato, um trote.
const MOVE_THRESHOLD: float = 0.6   # abaixo disto: parado (Idle)
const RUN_THRESHOLD: float = 3.5
## Quanto o pé anda por ciclo da animação, na altura padrão de 1,7 m. Medido
## amostrando o osso LeftFoot em 60 quadros de cada ciclo: nos quadros em que o
## pé está no chão (altura a até 4 cm do mínimo), ele corre para trás na
## velocidade do corpo; velocidade do pé x duração do ciclo = passada.
## Walk: 1,585 m/s x 1,0 s = 1,585 m. Run: 3,78 m/s x 0,625 s = 2,362 m.
const WALK_STRIDE: float = 1.585    # metros por ciclo do Walk (ciclo de 1,0 s)
const RUN_STRIDE: float = 2.362     # metros por ciclo do Run (ciclo de 0,625 s)
const WALK_CYCLE: float = 1.0       # segundos do Walk
const RUN_CYCLE: float = 0.625      # segundos do Run
## Limite da cadência: abaixo de 0,5 o passo vira câmera lenta, e acima de 3,2
## (o jogador andando a 5 m/s) vira desenho animado. Fora disso o pé desliza um
## pouco, o que é melhor que um corpo ridículo.
const MIN_SPEED_SCALE: float = 0.5
const MAX_SPEED_SCALE: float = 3.2
## Tempo (s) da mistura entre duas animações, para a pose não dar um pulo.
const BLEND_TIME: float = 0.2
## Tempo (s) no ar antes de trocar para o Jump (Fase 20.3.1). Descer uma guia
## tira o pé do chão por um instante, e o corpo pulava por um quadro.
const AIR_GRACE: float = 0.15
## Quanto o osso da cabeça encolhe ao esconder (não é zero, que quebra a matriz).
const HIDDEN_HEAD_SCALE: float = 0.001
## O osso encolhido ao esconder a cabeça (Fase 20.3): o pescoço, que leva a
## cabeça junto. Só com o Head, olhando para baixo, a câmera via o toco do
## pescoço e a cabeça num ponto em cima dele.
const HIDDEN_HEAD_BONE: String = "Neck"
## Onde termina cada faixa do UV (v), na ordem do AvatarSpec.ZONES: abaixo de
## 0,2 é pele, até 0,36 olhos, até 0,5 cabelo, até 0,72 camiseta, e o resto calça.
const ZONE_LIMITS: Array[float] = [0.2, 0.36, 0.5, 0.72]
## Camada de desenho (1 a 20) do que só aparece no reflexo: o seu próprio corpo
## fica nela, a câmera do espelho a enxerga e a do jogador não.
const REFLECTION_LAYER: int = 19
## Camadas do seu corpo que só a câmera do jogador enxerga (Fase 20.3): a do
## espelho e as das janelas (WindowView) não. Uma para fora de casa (o sol do
## mundo acende) e outra para dentro (o sol do mundo NÃO acende, para não
## atravessar o telhado). A 18 já é das placas dos bairros (DistrictSign).
const VIEW_LAYER: int = 17
const INDOOR_VIEW_LAYER: int = 16

## As cores (null = as padrão do AvatarSpec).
var spec: AvatarSpec
## Altura do topo da cabeça até a sola, em metros.
var height: float = DEFAULT_HEIGHT
## Se tiver, troca a paleta (o holograma de um amigo sem avatar).
var override_material: Material
## Se tiver, é desenhado por cima da paleta (o holograma de um amigo com avatar).
var overlay_material: Material
## Falso = sem sombra (o FriendNpc). Para o resto, set_shadow_mode.
var cast_shadows: bool = true

var _shadow_mode: ShadowMode = ShadowMode.NORMAL
var _head_hidden: bool = false
var _head_modifier: HeadHider
var _model: Node3D
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
## As cópias "só sombra" das malhas (set_shadow_twin_layers), criadas na
## primeira vez que alguém pede.
var _shadow_twins: Array[MeshInstance3D] = []
var _palette: ShaderMaterial
## Quando (ms, Time.get_ticks_msec) o corpo saiu do chão; -1 = no chão.
var _air_since: int = -1


## A máscara de "layers" que deixa o corpo só no reflexo.
static func reflection_layers() -> int:
	return 1 << (REFLECTION_LAYER - 1)


## A camada do seu corpo que só a câmera do jogador vê, em casa ou fora.
static func view_layers(indoors: bool) -> int:
	return 1 << ((INDOOR_VIEW_LAYER if indoors else VIEW_LAYER) - 1)


## As camadas do seu corpo que ficam "dentro de casa": o sol e a lua do mundo
## não as acendem (o mundo tira estas da luz do céu; a casa as acende).
static func indoor_layers() -> int:
	return view_layers(true) | reflection_layers()


## Todas as camadas do seu corpo: quem tira um retrato do mundo (a janela da
## casa) esconde estas.
static func player_layers() -> int:
	return view_layers(false) | indoor_layers()


## Em qual parte (índice no AvatarSpec.ZONES) cai a coordenada v do UV.
static func zone_index(v: float) -> int:
	for i in ZONE_LIMITS.size():
		if v < ZONE_LIMITS[i]:
			return i
	return ZONE_LIMITS.size()


func _ready() -> void:
	var body_id := spec.body if spec != null else "human"
	var scene: PackedScene = BODY_SCENES.get(body_id, BODY_SCENES["human"])
	_model = scene.instantiate() as Node3D
	add_child(_model)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_animation_player = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer

	_palette = ShaderMaterial.new()
	_palette.shader = PALETTE_SHADER
	_palette.set_shader_parameter("zone_limits", Vector4(ZONE_LIMITS[0], ZONE_LIMITS[1],
			ZONE_LIMITS[2], ZONE_LIMITS[3]))
	apply_spec(spec)
	for mesh in _meshes:
		mesh.material_override = override_material if override_material != null else _palette
		mesh.material_overlay = overlay_material
	if not cast_shadows and _shadow_mode == ShadowMode.NORMAL:
		_shadow_mode = ShadowMode.OFF
	_apply_shadow_mode()
	_head_modifier = HeadHider.new()
	_head_modifier.bone = _skeleton.find_bone(HIDDEN_HEAD_BONE)
	_head_modifier.active = _head_hidden
	_skeleton.add_child(_head_modifier)
	_fit()


## Troca as cores na hora (o espelho chama a cada amostra clicada).
func apply_spec(new_spec: AvatarSpec) -> void:
	spec = new_spec
	var colors := spec if spec != null else AvatarSpec.new()
	for zone in AvatarSpec.ZONES:
		_palette.set_shader_parameter(zone + "_color", colors.get_color(zone))


## O material das cores (para o teste conferir cada parte).
func get_palette() -> ShaderMaterial:
	return _palette


func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_animation_player() -> AnimationPlayer:
	return _animation_player


## Em quais camadas o corpo é desenhado (ex.: reflection_layers()).
func set_render_layers(layers: int) -> void:
	for mesh in _meshes:
		mesh.layers = layers


## Parado, respirando. start = de onde começar (0 a 1), para dois corpos
## lado a lado não respirarem juntos.
func play_idle(start: float = 0.0) -> void:
	_play_loop(IDLE_ANIMATION, start)


func play_walk(start: float = 0.0) -> void:
	_play_loop(WALK_ANIMATION, start)


## Escolhe a animação pelo estado e acerta a cadência pela velocidade real.
## horizontal_speed = m/s no plano (sem a vertical); on_floor falso = no ar.
## Pode ser chamada todo quadro: só troca a animação quando o estado muda.
## No ar, o Jump só entra depois de AIR_GRACE segundos (uma queda curta, como
## descer uma guia, segue no passo).
func animate(horizontal_speed: float, on_floor: bool) -> void:
	if _animation_player == null:
		return
	var now := Time.get_ticks_msec()
	if on_floor:
		_air_since = -1
	elif _air_since < 0:
		_air_since = now
	var animation := IDLE_ANIMATION
	var cadence := 1.0
	if not on_floor and now - _air_since >= int(AIR_GRACE * 1000.0):
		animation = JUMP_ANIMATION
	elif horizontal_speed >= RUN_THRESHOLD:
		animation = RUN_ANIMATION
		cadence = horizontal_speed / (RUN_STRIDE / RUN_CYCLE)
	elif horizontal_speed >= MOVE_THRESHOLD:
		animation = WALK_ANIMATION
		cadence = horizontal_speed / (WALK_STRIDE / WALK_CYCLE)
	cadence = clampf(cadence, MIN_SPEED_SCALE, MAX_SPEED_SCALE) if animation != IDLE_ANIMATION \
			and animation != JUMP_ANIMATION else 1.0
	if _animation_player.has_animation(animation) and _animation_player.current_animation != animation:
		var anim := _animation_player.get_animation(animation)
		# O pulo toca uma vez e segura a pose; o resto fica em loop.
		anim.loop_mode = Animation.LOOP_NONE if animation == JUMP_ANIMATION else Animation.LOOP_LINEAR
		_animation_player.play(animation, BLEND_TIME)
	_animation_player.speed_scale = cadence


## Esconde a cabeça (a primeira pessoa não pode ver o próprio pescoço por dentro):
## encolhe o osso do pescoço (HIDDEN_HEAD_BONE), que leva a cabeça. A animação
## escreve a pose do osso a cada quadro e desfaria a escala, por isso quem
## encolhe é um SkeletonModifier3D, que roda depois da animação (HeadHider, no
## fim do arquivo). O efeito vale só para o desenho do quadro (a pose guardada
## do osso não muda); desligar volta ao normal no quadro seguinte.
func set_head_hidden(on: bool) -> void:
	_head_hidden = on
	if _head_modifier != null:
		_head_modifier.active = on


func is_head_hidden() -> bool:
	return _head_hidden


## Como o corpo faz sombra (ShadowMode). Vale para todas as malhas.
func set_shadow_mode(mode: ShadowMode) -> void:
	_shadow_mode = mode
	cast_shadows = mode != ShadowMode.OFF
	_apply_shadow_mode()


func get_shadow_mode() -> ShadowMode:
	return _shadow_mode


## A SOMBRA À PARTE (Fase 20.3): uma cópia "só sombra" de cada malha, no mesmo
## esqueleto, desenhada nas camadas "layers" (0 = sem cópia). Serve para o corpo
## ficar numa camada que a câmera não vê (o espelho) e mesmo assim fazer sombra
## para ela: a Godot só faz a sombra de quem está numa camada que a câmera vê.
## A cópia anda junto (é o mesmo esqueleto) e nunca é desenhada, só a sombra.
## Só vale DEPOIS do _ready (do add_child): antes, as malhas ainda não existem e
## a chamada não faz nada, sem aviso.
func set_shadow_twin_layers(layers: int) -> void:
	if layers != 0 and _shadow_twins.is_empty():
		for mesh in _meshes:
			var twin := mesh.duplicate() as MeshInstance3D
			twin.name = mesh.name + "Shadow"
			twin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			mesh.add_sibling(twin)
			_shadow_twins.append(twin)
	for twin in _shadow_twins:
		twin.visible = layers != 0
		twin.layers = layers if layers != 0 else twin.layers


## As camadas da sombra à parte (0 = sem ela).
func get_shadow_twin_layers() -> int:
	if _shadow_twins.is_empty() or not _shadow_twins[0].visible:
		return 0
	return _shadow_twins[0].layers


## As malhas desenhadas (sem as cópias da sombra), para os testes.
func get_meshes() -> Array[MeshInstance3D]:
	return _meshes


func get_shadow_twins() -> Array[MeshInstance3D]:
	return _shadow_twins


func _apply_shadow_mode() -> void:
	var setting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _shadow_mode == ShadowMode.OFF:
		setting = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif _shadow_mode == ShadowMode.SHADOWS_ONLY:
		setting = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for mesh in _meshes:
		mesh.cast_shadow = setting


func _play_loop(animation: String, start: float) -> void:
	if not _animation_player.has_animation(animation):
		return
	_animation_player.speed_scale = 1.0
	_animation_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(animation)
	_animation_player.seek(start * _animation_player.current_animation_length, true)


## Deixa o corpo com "height" de altura, em pé na origem deste nó e olhando
## para +Z (o modelo vem noutra escala e virado para o lado). Era o _fit_body
## do FriendNpc até a Fase 13.5.
func _fit() -> void:
	var top := _bone_position(_skeleton.find_bone("HeadTop_End"))
	var foot := _bone_position(_skeleton.find_bone("LeftToe_End"))
	var measured := top.y - minf(foot.y, global_position.y)
	if measured > 0.01:
		_model.scale *= height / measured
	# Frente = do braço direito para o esquerdo, girado 90° (esquerda x cima).
	var left := _bone_position(_skeleton.find_bone("LeftArm"))
	var right := _bone_position(_skeleton.find_bone("RightArm"))
	var forward := (left - right).cross(Vector3.UP)
	forward.y = 0.0
	if forward.length() > 0.001:
		var local_forward := global_basis.inverse() * forward.normalized()
		_model.rotation.y -= atan2(local_forward.x, local_forward.z)


func _bone_position(bone: int) -> Vector3:
	return (_skeleton.global_transform * _skeleton.get_bone_global_rest(bone)).origin


## Encolhe um osso depois da animação (o AnimationPlayer reescreve a pose do osso
## a cada quadro; um SkeletonModifier3D roda depois dele e vence).
class HeadHider extends SkeletonModifier3D:
	var bone: int = -1

	func _process_modification_with_delta(_delta: float) -> void:
		if bone < 0:
			return
		var skeleton := get_skeleton()
		if skeleton != null:
			skeleton.set_bone_pose_scale(bone, Vector3.ONE * AvatarBody.HIDDEN_HEAD_SCALE)
