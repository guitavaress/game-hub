class_name AvatarBody
extends Node3D
## O CORPO de um avatar (Fase 13.6): carrega o modelo, deixa com a altura certa,
## em pé na origem deste nó e olhando para +Z, pinta cada parte com a cor do
## AvatarSpec e toca as animações (Idle e Walk). Os hologramas dos amigos
## (FriendNpc) usam este corpo com o material de holograma por cima, e o seu
## avatar no espelho usa com as cores.
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
const DEFAULT_HEIGHT: float = 1.7
## Onde termina cada faixa do UV (v), na ordem do AvatarSpec.ZONES: abaixo de
## 0,2 é pele, até 0,36 olhos, até 0,5 cabelo, até 0,72 camiseta, e o resto calça.
const ZONE_LIMITS: Array[float] = [0.2, 0.36, 0.5, 0.72]
## Camada de desenho (1 a 20) do que só aparece no reflexo: o seu próprio corpo
## fica nela, a câmera do espelho a enxerga e a do jogador não.
const REFLECTION_LAYER: int = 19

## As cores (null = as padrão do AvatarSpec).
var spec: AvatarSpec
## Altura do topo da cabeça até a sola, em metros.
var height: float = DEFAULT_HEIGHT
## Se tiver, troca a paleta (o holograma de um amigo sem avatar).
var override_material: Material
## Se tiver, é desenhado por cima da paleta (o holograma de um amigo com avatar).
var overlay_material: Material
var cast_shadows: bool = true

var _model: Node3D
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _palette: ShaderMaterial


## A máscara de "layers" que deixa o corpo só no reflexo.
static func reflection_layers() -> int:
	return 1 << (REFLECTION_LAYER - 1)


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
		if not cast_shadows:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


func _play_loop(animation: String, start: float) -> void:
	if not _animation_player.has_animation(animation):
		return
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
