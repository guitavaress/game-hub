class_name WindowView
extends Node
## A VISTA DE VERDADE de uma janela (Fase 17.3): um "retrato" do mundo, tirado
## de um ponto que o próprio mundo oferece.
##
## Como funciona:
##   - o mundo põe um WindowViewPoint (grupo POINT_GROUP) onde a vista é bonita,
##     quando ele já está pronto. Este componente não conhece nenhum mundo: só
##     procura o ponto no grupo;
##   - achando o ponto, ele monta um SubViewport que divide o World3D da cena,
##     com uma câmera grande-angular no lugar do ponto, e desenha UMA vez
##     (UPDATE_ONCE). A imagem é copiada da placa sem travar o quadro (a cópia
##     chega uns quadros depois), vira uma textura comum, e o SubViewport é
##     desfeito (assim os buffers do 3D não ficam ocupando a placa);
##   - o retrato é refeito só quando a fase do dia muda (dia, pôr do sol,
##     noite), quando o ponto muda ou quando a qualidade gráfica muda. Nunca a
##     cada quadro;
##   - a janela (um ShaderMaterial, em set_material) recebe a textura e amostra
##     o retrato pela direção do olhar, como um céu. Sem ponto, ou enquanto o
##     mundo monta, ela fica com a vista de reserva do próprio shader; quando o
##     primeiro retrato fica pronto, ele entra devagar (FADE_IN_SECONDS).
##
## O shader da janela "usa a vista" se tiver o uniform view_texture; os outros
## uniforms que este componente preenche são view_previous, view_blend,
## view_mix e view_tan_half_fov (veja worlds/home/home_window.gdshader). Um
## shader sem view_texture (a floresta da cabana) deixa o componente parado.
##
## Quem usa diz quais camadas a câmera do retrato não vê (hidden_layers): a
## casa passa a camada dela, para não aparecer no retrato do mundo.

## Um retrato novo ficou pronto (o primeiro ou o de uma fase nova do dia).
signal portrait_ready
## O ponto de vista sumiu: a janela voltou para a vista de reserva.
signal portrait_lost

## Onde ficam os pontos que os mundos oferecem.
const POINT_GROUP: StringName = &"window_view_point"
## Onde ficam as janelas (os pontos avisam por aqui: on_point_changed).
const GROUP: StringName = &"window_view"
## A lente do retrato, como a janela a mostra: 100° de um lado ao outro, numa
## imagem 2:1 (o tamanho em px vem do GraphicsQuality.apply_to_window_view).
## Larga o bastante para quem olha a janela de quase todo canto da sala. Com o
## zoom do ponto (WindowViewPoint.zoom), a câmera fecha a lente e a janela
## mostra o mesmo pedaço maior.
const FOV_X_DEGREES: float = 100.0
const NEAR: float = 0.5
const FAR: float = 4000.0
## As fases do dia, pela "noite" (0 = dia, 1 = noite) que o mundo avisa: o
## pôr do sol começa em DUSK_FROM e a noite em NIGHT_FROM.
const DUSK_FROM: float = 0.25
const NIGHT_FROM: float = 0.85
## A primeira vez, o retrato entra devagar: a cidade "acende" pela janela.
## Na troca de fase do dia, o retrato velho se funde no novo.
const FADE_IN_SECONDS: float = 3.5
const CROSSFADE_SECONDS: float = 1.5
## Quantos quadros, no máximo, se espera a cópia da placa (depois, a cópia
## comum, que trava um pouco).
const READ_WAIT_FRAMES: int = 30

enum Phase { NONE = -1, DAY, DUSK, NIGHT }

## Camadas de render (máscara de bits) que a câmera do retrato NÃO vê.
var hidden_layers: int = 0
## Quantos retratos já foram tirados (os testes conferem).
var capture_count: int = 0

var _material: ShaderMaterial
## O shader da janela usa a vista (tem view_texture)?
var _active: bool = false
var _night: float = 0.0
## O retrato da vez, o anterior (durante a fusão), a fase do dia e o ponto de
## onde ele foi tirado.
var _texture: Texture2D
var _previous: Texture2D
var _phase: int = Phase.NONE
var _source: Node3D
## 0 = vista de reserva, 1 = retrato; 0 = anterior, 1 = o da vez.
var _mix: float = 0.0
var _blend: float = 1.0
var _tween: Tween
## Só durante uma captura: o quadro e a câmera.
var _viewport: SubViewport
var _camera: Camera3D
var _capturing: bool = false
## Outro pedido chegou no meio de uma captura (e se ele era forçado).
var _again: bool = false
var _again_forced: bool = false
## A proporção do retrato (largura / altura).
var _aspect: float = 2.0
## Sobe quando o ponto some: uma captura que começou antes disso é jogada fora
## ao terminar (senão o retrato de um ponto que já saiu voltaria à janela).
var _generation: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	AppConfig.settings_changed.connect(_on_settings_changed)
	_refresh.call_deferred()


## A janela que mostra a vista. Pode trocar (a casa refaz a casca ao mudar de
## tema): o estado de agora vai para o material novo, sem fade.
func set_material(material: ShaderMaterial) -> void:
	_material = material
	_active = material != null and uses_view(material.shader)
	_apply_to_material()
	_refresh()


## A hora lá fora (0 = dia, 1 = noite). Só a troca de fase refaz o retrato.
func set_night(night: float) -> void:
	_night = clampf(night, 0.0, 1.0)
	if phase_of(_night) != _phase:
		_refresh()


## Um ponto entrou ou saiu do grupo (quem chama é o WindowViewPoint).
func on_point_changed() -> void:
	_refresh()


static func phase_of(night: float) -> int:
	if night >= NIGHT_FROM:
		return Phase.NIGHT
	if night >= DUSK_FROM:
		return Phase.DUSK
	return Phase.DAY


## O shader mostra a vista de verdade se declarar o uniform view_texture.
static func uses_view(shader: Shader) -> bool:
	if shader == null:
		return false
	for uniform: Dictionary in shader.get_shader_uniform_list():
		if uniform["name"] == "view_texture":
			return true
	return false


## Para os testes (e para quem quiser saber o que a janela mostra).
func has_portrait() -> bool:
	return _texture != null


## Nada mudando: sem captura em andamento e sem fade (ou sem retrato nenhum).
func is_settled() -> bool:
	return not _capturing and (_texture == null or (_mix >= 1.0 and _blend >= 1.0))


func get_phase() -> int:
	return _phase


func get_view_mix() -> float:
	return _mix


## O quadro e a câmera da captura em andamento (null fora dela).
func get_capture_viewport() -> SubViewport:
	return _viewport


func get_capture_camera() -> Camera3D:
	return _camera


## tan(meia abertura) da lente, em x e em y: o shader usa para achar, pela
## direção do olhar, o ponto do retrato.
func tan_half_fov() -> Vector2:
	var half_x := tan(deg_to_rad(FOV_X_DEGREES) / 2.0)
	return Vector2(half_x, half_x / _aspect)


# --- Captura ------------------------------------------------------------------

func _refresh(forced: bool = false) -> void:
	if not is_inside_tree() or not _active:
		return
	var point := _find_point()
	if point == null:
		_forget()
		return
	if _capturing:
		_again = true
		_again_forced = _again_forced or forced
		return
	if forced or point != _source or _texture == null or phase_of(_night) != _phase:
		_capture(point)


func _find_point() -> Node3D:
	for node: Node in get_tree().get_nodes_in_group(POINT_GROUP):
		if node is Node3D and node.is_inside_tree() and not node.is_queued_for_deletion():
			return node as Node3D
	return null


## Monta o quadro, desenha uma vez, copia a imagem e desfaz o quadro.
func _capture(point: Node3D) -> void:
	_capturing = true
	capture_count += 1
	var generation := _generation
	var phase := phase_of(_night)
	_viewport = SubViewport.new()
	_viewport.name = "Portrait"
	# Divide o mundo da cena (não é um mundo próprio).
	_viewport.own_world_3d = false
	_viewport.world_3d = get_viewport().find_world_3d()
	_viewport.gui_disable_input = true
	GraphicsQuality.apply_to_window_view(_viewport, AppConfig.get_quality())
	_aspect = float(_viewport.size.x) / float(maxi(_viewport.size.y, 1))
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH  # a abertura é a de um lado ao outro
	var zoom := maxf(float(point.get("zoom")), 1.0) if point is WindowViewPoint else 1.0
	_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(FOV_X_DEGREES) / 2.0) / zoom))
	_camera.near = NEAR
	_camera.far = FAR
	_camera.cull_mask &= ~hidden_layers
	_camera.transform = point.global_transform
	_viewport.add_child(_camera)
	_camera.current = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)

	var image: Image = null
	if DisplayServer.get_name() == "headless":
		# Sem janela (os testes) nada é desenhado de verdade.
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
		image = await _read_image()
	_release_viewport()
	_capturing = false
	if not is_inside_tree():
		return
	# O ponto sumiu (ou foi trocado) durante a captura: o retrato não vale mais.
	var still_valid := generation == _generation and is_instance_valid(point) and point == _find_point()
	if still_valid:
		if image == null or image.is_empty():
			image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		_show(ImageTexture.create_from_image(image), phase, point)
	else:
		_again = true
	if _again:
		var forced := _again_forced
		_again = false
		_again_forced = false
		_refresh(forced)


## Copia a imagem do quadro para a memória. Com a placa (RenderingDevice), a
## cópia é pedida e chega uns quadros depois, sem travar: a cópia comum
## (get_image) espera a placa terminar tudo e custava ~18 ms de tranco.
func _read_image() -> Image:
	if not is_instance_valid(_viewport):
		return null
	var texture := _viewport.get_texture()
	var device := RenderingServer.get_rendering_device()
	var rid := RenderingServer.texture_get_rd_texture(texture.get_rid()) if device != null else RID()
	if not rid.is_valid():
		return texture.get_image()
	var format := device.texture_get_format(rid)
	if format.format not in [RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB]:
		return texture.get_image()
	var arrived: Array[PackedByteArray] = []
	if device.texture_get_data_async(rid, 0, func(data: PackedByteArray) -> void: arrived.append(data)) != OK:
		return texture.get_image()
	for i in READ_WAIT_FRAMES:
		if not arrived.is_empty() or not is_instance_valid(_viewport):
			break
		await get_tree().process_frame
	if arrived.is_empty() or arrived[0].size() != format.width * format.height * 4:
		return texture.get_image() if is_instance_valid(_viewport) else null
	return Image.create_from_data(format.width, format.height, false, Image.FORMAT_RGBA8, arrived[0])


func _release_viewport() -> void:
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_camera = null


## O retrato novo entra: da vista de reserva com fade, ou fundindo no anterior.
func _show(texture: Texture2D, phase: int, point: Node3D) -> void:
	if _tween != null:
		_tween.kill()
	var first := _texture == null or _mix < 1.0
	_previous = null if first else _texture
	_texture = texture
	_phase = phase
	_source = point
	_tween = create_tween()
	if first:
		_blend = 1.0
		_tween.tween_method(_set_mix, _mix, 1.0, FADE_IN_SECONDS * (1.0 - _mix)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_blend = 0.0
		_tween.tween_method(_set_blend, 0.0, 1.0, CROSSFADE_SECONDS).set_trans(Tween.TRANS_SINE)
	_apply_to_material()
	portrait_ready.emit()


## Sem ponto: volta para a vista de reserva (e uma captura em andamento não vale).
func _forget() -> void:
	_generation += 1
	if _texture == null:
		return
	if _tween != null:
		_tween.kill()
	_texture = null
	_previous = null
	_phase = Phase.NONE
	_source = null
	_mix = 0.0
	_blend = 1.0
	_apply_to_material()
	portrait_lost.emit()


func _set_mix(value: float) -> void:
	_mix = value
	_apply_to_material()


func _set_blend(value: float) -> void:
	_blend = value
	if _blend >= 1.0:
		_previous = null
	_apply_to_material()


func _apply_to_material() -> void:
	if _material == null or not _active:
		return
	_material.set_shader_parameter("view_texture", _texture)
	_material.set_shader_parameter("view_previous", _previous if _previous != null else _texture)
	_material.set_shader_parameter("view_blend", _blend)
	_material.set_shader_parameter("view_mix", _mix if _texture != null else 0.0)
	_material.set_shader_parameter("view_tan_half_fov", tan_half_fov())


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		_refresh(true)
