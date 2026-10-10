class_name Screen3D
extends Node3D
## TELA 3D CLICÁVEL (Fase 9): um quadro no mundo que mostra uma interface 2D
## (qualquer Control) e pode ser usada com o mouse e o teclado, como uma tela
## de verdade. Hoje é o monitor do computador da casa; amanhã, um painel num
## balcão ou um fliperama.
##
## Como funciona:
##   - o conteúdo (set_content) mora num SubViewport, uma "tela 2D escondida";
##     a imagem dele vira a textura de um retângulo no mundo;
##   - olhar para a tela e apertar E chama player.focus_on(tela): a câmera
##     desliza até a frente da tela (get_camera_pose), o mouse aparece e o
##     jogador para de andar;
##   - com o foco, cada evento do mouse vira um raio que sai da câmera; o ponto
##     onde o raio bate no retângulo vira a coordenada em pixels do SubViewport,
##     e o evento é entregue a ele (push_input). As teclas vão direto, para dar
##     para digitar num campo;
##   - Esc: se um campo de texto estiver com o cursor, o primeiro Esc só tira o
##     cursor dele; senão, devolve a câmera (player.leave_focus).
##
## A aparência em volta (moldura, pé, mesa) é de quem usa, como no TravelDoor.
##
## Convenção: a origem fica no MEIO da tela, e a FRENTE (+Z) aponta para quem
## olha. O retângulo tem screen_size metros; o conteúdo tem resolution pixels
## (mesma proporção, para nada ficar esticado).

## Avisa quando o foco começa (true) e termina (false). Quem usa aproveita
## para atualizar o conteúdo ao mostrar e gravar ao sair.
signal focus_changed(focused: bool)

## Nome no cartão ("Computador").
var screen_name: String = "Tela"
## Linha de baixo do cartão ("Configurações").
var detail: String = ""
## Dica do E no cartão.
var action_text: String = "E para usar"
## Tamanho do retângulo, em metros (largura, altura).
var screen_size: Vector2 = Vector2(0.8, 0.45)
## Tamanho do conteúdo, em pixels. Mesma proporção do screen_size.
var resolution: Vector2i = Vector2i(1152, 648)
## Com o foco, quanto da janela a tela ocupa (0 a 1). Perto de 1, o conteúdo
## aparece quase em tamanho real e o texto fica legível.
var focus_fill: float = 0.94

var _viewport: SubViewport
var _quad: MeshInstance3D
var _content: Control
var _player: Node = null
var _focused: bool = false


func _ready() -> void:
	add_to_group("screen_3d")

	# A "tela 2D escondida": só interface, sem 3D. Ela só redesenha quando a
	# textura aparece na câmera (o modo padrão, "quando visível").
	_viewport = SubViewport.new()
	_viewport.name = "Viewport"
	_viewport.size = resolution
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.gui_embed_subwindows = true  # janelinhas (menus) ficam dentro da tela
	add_child(_viewport)
	if _content != null:
		_put_content()

	# O retângulo no mundo, com a imagem do SubViewport. "Sem sombreamento":
	# a tela tem luz própria, as luminárias não a escurecem nem clareiam.
	_quad = MeshInstance3D.new()
	_quad.name = "Surface"
	var quad := QuadMesh.new()  # a frente do QuadMesh já é o +Z
	quad.size = screen_size
	_quad.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_quad.material_override = material
	add_child(_quad)

	# Alvo "olhável" (camada 3): o raio da câmera acha a tela por aqui.
	var look := Area3D.new()
	look.name = "LookArea"
	look.collision_layer = 4
	look.collision_mask = 0
	look.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(screen_size.x + 0.1, screen_size.y + 0.1, 0.1)
	shape.shape = box
	look.add_child(shape)
	add_child(look)


## O que a tela mostra. Pode ser chamado antes ou depois de entrar na árvore.
## O conteúdo ocupa a tela inteira.
func set_content(content: Control) -> void:
	_content = content
	if _viewport != null:
		_put_content()


func get_content() -> Control:
	return _content


func get_viewport_node() -> SubViewport:
	return _viewport


func is_focused() -> bool:
	return _focused


func get_look_info() -> Dictionary:
	return {"title": screen_name, "detail": detail, "action": action_text}


## E apertado olhando para a tela (o jogador já confere se pode interagir).
func interact(player: Node) -> void:
	if player.has_method("focus_on"):
		player.focus_on(self)


## Onde a câmera fica com o foco: na frente da tela, olhando para ela, longe o
## bastante para a tela ocupar "focus_fill" da janela. "fov_degrees" é o campo
## de visão vertical da câmera e "aspect" é largura / altura da janela (numa
## janela estreita, quem limita é a largura).
func get_camera_pose(fov_degrees: float, aspect: float) -> Transform3D:
	var half_tan := tan(deg_to_rad(fov_degrees) / 2.0)
	var by_height := (screen_size.y / 2.0) / half_tan
	var by_width := (screen_size.x / 2.0) / (half_tan * maxf(aspect, 0.1))
	var distance := maxf(by_height, by_width) / focus_fill
	return Transform3D(global_basis.orthonormalized(), to_global(Vector3(0.0, 0.0, distance)))


## O jogador avisa que o foco começou (com quem focou) ou terminou.
func set_focused(on: bool, player: Node = null) -> void:
	if on == _focused:
		return
	_focused = on
	_player = player if on else null
	if not on:
		_release_text_focus()
		# Tira o "mouse em cima" do último botão: o mouse "sai" da tela.
		var away := InputEventMouseMotion.new()
		away.position = Vector2(-10000.0, -10000.0)
		away.global_position = away.position
		_viewport.push_input(away, true)
	focus_changed.emit(on)


## De um raio no mundo (origem e direção) para o pixel do conteúdo onde ele
## bate. Fora do retângulo dá números negativos ou maiores que a resolução
## (serve para arrastar um controle até a borda). Raio paralelo à tela ou que
## aponta para trás dela: Vector2.INF.
func ray_to_pixel(origin: Vector3, direction: Vector3) -> Vector2:
	var to_local := _quad.global_transform.affine_inverse()
	var local_origin := to_local * origin
	var local_direction := to_local.basis * direction
	if absf(local_direction.z) < 0.000001:
		return Vector2.INF
	var distance := -local_origin.z / local_direction.z
	if distance < 0.0:
		return Vector2.INF
	var hit := local_origin + local_direction * distance
	var uv := Vector2(hit.x / screen_size.x + 0.5, 0.5 - hit.y / screen_size.y)
	return uv * Vector2(resolution)


## O contrário: de um pixel do conteúdo para o ponto no mundo (os testes usam
## para saber onde "clicar").
func pixel_to_world(pixel: Vector2) -> Vector3:
	var uv := pixel / Vector2(resolution)
	return _quad.to_global(Vector3((uv.x - 0.5) * screen_size.x, (0.5 - uv.y) * screen_size.y, 0.0))


## Com o foco, a tela fica com o mouse e o teclado. Roda em _input, antes dos
## painéis e do jogador, e marca o que usou como "já tratado".
func _input(event: InputEvent) -> void:
	if not _focused:
		return
	if event.is_action_pressed("release_mouse"):
		get_viewport().set_input_as_handled()
		if _viewport.gui_get_focus_owner() != null:
			_release_text_focus()  # 1º Esc: só tira o cursor do campo
		elif _player != null and _player.has_method("leave_focus"):
			_player.leave_focus()  # 2º Esc: devolve a câmera
		return
	if event is InputEventMouse:
		var mapped := _to_viewport_event(event as InputEventMouse)
		if mapped != null:
			_viewport.push_input(mapped, true)
		# O mouse é todo da tela durante o foco (mesmo fora dela): um clique
		# não pode "prender" o mouse de volta no jogador.
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		_viewport.push_input(event, true)
		# Só fica com a tecla se a tela usou (ex.: digitar num campo). As
		# outras seguem (ex.: F11 para tela cheia).
		if _viewport.is_input_handled():
			get_viewport().set_input_as_handled()


## Copia o evento do mouse trocando a posição na janela pela posição no
## conteúdo (o raio da câmera que passa pelo mouse, até a tela).
func _to_viewport_event(event: InputEventMouse) -> InputEventMouse:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var pixel := ray_to_pixel(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
	if pixel == Vector2.INF:
		return null
	var mapped := event.duplicate() as InputEventMouse
	mapped.position = pixel
	mapped.global_position = pixel
	return mapped


func _release_text_focus() -> void:
	var owner := _viewport.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _put_content() -> void:
	if _content.get_parent() != null:
		_content.get_parent().remove_child(_content)
	_viewport.add_child(_content)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
