class_name PlayerAvatar
extends Node3D
## O SEU CORPO (Fase 20.3): o "rig" do jogador, filho do Player (criado por
## código). São dois corpos (AvatarBody), no mesmo lugar e andando juntos:
##   - o DE PRIMEIRA PESSOA: sem cabeça (set_head_hidden), sem sombra, numa
##     camada que só a câmera do jogador vê. É o que você vê olhando para baixo;
##   - o INTEIRO: com cabeça. É o que o espelho reflete (camada do reflexo, que a
##     câmera do jogador não vê) e o que faz a sombra. A sombra vem de uma cópia
##     "só sombra" dele (AvatarBody.set_shadow_twin_layers), numa camada que a
##     câmera do jogador vê: a Godot só faz a sombra de quem a câmera enxerga
##     (conferido na 20.3), e a cópia nunca é desenhada, só a sombra dela.
##
## Camadas (AvatarBody): fora de casa, a VIEW_LAYER (o sol do mundo acende);
## em casa, a INDOOR_VIEW_LAYER (o sol do mundo não acende, as luzes da casa
## sim). O Player avisa a troca (set_indoors).
##
## Quem usa:
##   - o Player: animate() a cada quadro, set_indoors() ao entrar e sair, e
##     set_hidden() no foco numa tela, na viagem e na abertura (o corpo de
##     primeira pessoa some; a sombra fica);
##   - o espelho: get_full_body() (para ler e conferir) e, no provador,
##     hold_pose() e release_pose() (o inteiro fica parado na frente do vidro,
##     visto também pela câmera do jogador);
##   - a terceira pessoa (20.4): set_view() troca quais corpos a câmera vê.
## As cores vêm do config.cfg ([avatar]) e mudam na hora.

## Quanto (m) os corpos ficam para trás da câmera na primeira pessoa: olhando
## para baixo, a câmera fica na frente do pescoço, e não dentro dele, e vê o
## peito, os braços, as pernas e os pés.
const FIRST_PERSON_BACK: float = 0.2

var _first: AvatarBody
var _full: AvatarBody
var _view: String = AppConfig.VIEW_FIRST
var _indoors: bool = false
var _hidden: bool = false
var _posed: bool = false


func _ready() -> void:
	var spec := AvatarSpec.from_dict(AppConfig.get_avatar())
	_first = _make_body("FirstPersonBody", spec)
	_first.set_head_hidden(true)
	_full = _make_body("FullBody", spec)
	AppConfig.settings_changed.connect(_on_settings_changed)
	_apply()


## Anda, corre ou pula pela velocidade do jogador (AvatarBody.animate). No
## provador, o inteiro fica parado.
func animate(horizontal_speed: float, on_floor: bool) -> void:
	_first.animate(horizontal_speed, on_floor)
	if _posed:
		_full.animate(0.0, true)
	else:
		_full.animate(horizontal_speed, on_floor)


## Dentro ou fora de casa: troca as camadas (quem acende o corpo muda).
func set_indoors(on: bool) -> void:
	if on != _indoors:
		_indoors = on
		_apply()


func is_indoors() -> bool:
	return _indoors


## Esconde o corpo de primeira pessoa (foco numa tela, viagem, abertura: a
## câmera sai da cabeça, e veria o corpo sem cabeça por fora).
func set_hidden(on: bool) -> void:
	if on != _hidden:
		_hidden = on
		_apply()


func is_hidden() -> bool:
	return _hidden


## A visão (AppConfig.VIEW_FIRST ou VIEW_THIRD). Na terceira pessoa, a câmera
## vê o inteiro (que faz a própria sombra) e o de primeira pessoa some. Quem
## move a câmera é o Player (20.4).
func set_view(view: String) -> void:
	if view != AppConfig.VIEW_FIRST and view != AppConfig.VIEW_THIRD:
		return
	if view != _view:
		_view = view
		_apply()


func get_view() -> String:
	return _view


## PROVADOR: o inteiro fica parado em "spot" (no mundo; o corpo olha para +Z),
## visto pela câmera do jogador e pelo espelho, até o release_pose().
func hold_pose(spot: Transform3D) -> void:
	_posed = true
	_full.top_level = true
	_full.global_transform = spot
	_apply()


## Fim do provador: o inteiro volta a seguir o jogador.
func release_pose() -> void:
	if not _posed:
		return
	_posed = false
	_full.top_level = false
	_apply()


func is_posed() -> bool:
	return _posed


## O inteiro (com cabeça): o do espelho, da sombra e da terceira pessoa.
func get_full_body() -> AvatarBody:
	return _full


func get_first_person_body() -> AvatarBody:
	return _first


func _make_body(body_name: String, spec: AvatarSpec) -> AvatarBody:
	var body := AvatarBody.new()
	body.name = body_name
	body.spec = spec
	body.rotation.y = PI  # o corpo olha para +Z; o jogador, para -Z
	add_child(body)
	body.play_idle()
	return body


## O ÚNICO lugar que decide camadas, sombra, quem aparece e onde.
func _apply() -> void:
	var view_mask := AvatarBody.view_layers(_indoors)
	# O inteiro é visto pela câmera do jogador na terceira pessoa e no provador.
	var full_seen := _view == AppConfig.VIEW_THIRD or _posed
	_first.visible = _view == AppConfig.VIEW_FIRST and not _hidden and not _posed
	_first.set_render_layers(view_mask)
	_first.set_shadow_mode(AvatarBody.ShadowMode.OFF)
	_first.position = Vector3(0.0, 0.0, FIRST_PERSON_BACK)
	if full_seen:
		# Em casa, o espelho também vê (a camada do reflexo vai junto).
		var reflection := AvatarBody.reflection_layers() if _indoors else 0
		_full.set_render_layers(view_mask | reflection)
		_full.set_shadow_mode(AvatarBody.ShadowMode.NORMAL)
		_full.set_shadow_twin_layers(0)
	else:
		_full.set_render_layers(AvatarBody.reflection_layers())
		_full.set_shadow_mode(AvatarBody.ShadowMode.OFF)
		_full.set_shadow_twin_layers(view_mask)
	if not _posed:
		var back := FIRST_PERSON_BACK if _view == AppConfig.VIEW_FIRST else 0.0
		_full.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, back))


func _on_settings_changed(section: String, _key: String) -> void:
	if section == "avatar":
		var spec := AvatarSpec.from_dict(AppConfig.get_avatar())
		_first.apply_spec(spec)
		_full.apply_spec(spec)
