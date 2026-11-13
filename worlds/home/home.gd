class_name Home
extends Node3D
## A CASA (Fase 9): o loft onde o jogador mora. É uma cena própria e não
## conhece nenhum mundo: quem a usa (hoje a cidade) coloca a casa longe do
## resto, liga a porta da rua a algum lugar (get_front_door) e põe o jogador
## no ponto de nascer (get_spawn_transform).
##
## A casa monta tudo por código, em duas partes (Fase 13):
##   - a CASCA: chão, paredes, teto, janela, néon, a aparência da porta, a luz
##     e o enfeite do tema. Tudo vem do perfil do tema (HomeProfile, em
##     profiles/homes/), e a casca pode ser refeita ao trocar de tema;
##   - os MÓVEIS (estante, mural, computador), que entram em _build_furniture,
##     um por linha, e não são refeitos.
##
## "Em casa": uma área cobre o interior. Quando o jogador entra nela, a casa
## chama player.set_indoors(ambiente da casa); ao sair, set_indoors(null).
## A câmera passa a usar a luz e o fundo da casa, e não os do mundo lá fora.
##
## Luz de fora: tudo o que a casa desenha fica na camada de render
## INTERIOR_LAYER. O mundo tira essa camada do sol dele (light_cull_mask),
## para o sol não atravessar o telhado.
##
## A vista da janela (Fase 17.3): um WindowView (components/window_view/) tira
## um retrato do mundo de um ponto que o próprio mundo oferece (grupo
## window_view_point), sem a camada da casa. A casa não sabe que mundo é esse;
## sem ponto, a janela mostra a vista de reserva do shader.
##
## Convenção: a origem fica no chão, no meio da sala. O norte (-Z) é a parede
## da janela; a porta da rua fica na parede sul (+Z).

## Camada de render do interior (de 1 a 20) e a máscara dela (bit).
const INTERIOR_LAYER: int = 20
const INTERIOR_LAYER_MASK: int = 1 << (INTERIOR_LAYER - 1)
## Tamanho por dentro (largura x, altura, profundidade z), em metros (Fase
## 17.4b: 9 x 7 m com teto de 3 m, o tamanho de uma sala aconchegante; antes,
## 12 x 9 m com 3,4 m). TUDO o que encosta numa parede sai daqui: os lugares
## prontos, a janela, a porta, o néon, as vigas e o ponto de nascer. Trocar o
## tamanho não pede mexer em mais nenhum número.
const ROOM_SIZE: Vector3 = Vector3(9.0, 3.0, 7.0)
const WALL_THICKNESS: float = 0.3
## Folga entre um móvel e a parede do lado (ou o móvel vizinho).
const WALL_GAP: float = 0.03
## O móvel mais largo que vai na parede sul: a estante e o quadro de
## estatísticas têm 4,54 m. Os dois lugares da parede sul cabem um destes e o
## espelho, em qualquer ordem.
const WIDE_PIECE: float = 4.6

## A porta da rua, na parede sul, perto do canto sudeste (centrada, ela
## deixaria só 3,85 m de cada lado, e a estante não caberia): a largura por fora
## do batente e a folga até a parede leste.
const DOOR_WIDTH: float = 1.3
const DOOR_CORNER_GAP: float = 0.15
const DOOR_X: float = ROOM_SIZE.x / 2.0 - DOOR_CORNER_GAP - DOOR_WIDTH / 2.0
## A placa da porta (set_door_status): na altura dos olhos, quase da largura
## da folha, em letras que se leem do meio da sala.
const DOOR_STATUS_HEIGHT: float = 1.55
const DOOR_STATUS_WIDTH: float = 0.95
const DOOR_STATUS_FONT_SIZE: int = 36
const DOOR_STATUS_PIXEL_SIZE: float = 0.0025
const DOOR_STATUS_COLOR: Color = Color(1.0, 0.93, 0.8)

## A parede norte, de oeste para leste: o CANTO DE ESTAR do tema (no loft, o
## sofá; na cabana, a lareira), a janela e o computador. A mesa fica a
## DESK_WALL_GAP da parede leste e um tiquinho afastada da parede norte.
const LIVING_CORNER_WIDTH: float = 3.0
const DESK_WALL_GAP: float = 0.1
const DESK_BACK_GAP: float = 0.05
const COMPUTER_SPOT: Vector2 = Vector2(ROOM_SIZE.x / 2.0 - DESK_WALL_GAP - ComputerDesk.DESK_SIZE.x / 2.0,
		-ROOM_SIZE.z / 2.0 + DESK_BACK_GAP + ComputerDesk.DESK_SIZE.z / 2.0)

## A janela da parede norte: do fim do canto de estar até perto da mesa, do
## peitoril (WINDOW_SILL_Y) até WINDOW_HEAD_GAP abaixo do teto.
const WINDOW_DESK_GAP: float = 0.15
const WINDOW_SILL_Y: float = 0.8
const WINDOW_HEAD_GAP: float = 0.3
const WINDOW_LEFT: float = -ROOM_SIZE.x / 2.0 + LIVING_CORNER_WIDTH
const WINDOW_RIGHT: float = COMPUTER_SPOT.x - ComputerDesk.DESK_SIZE.x / 2.0 - WINDOW_DESK_GAP
## O janelão (largura, altura), o meio dele em x e a altura do meio.
const WINDOW_SIZE: Vector2 = Vector2(WINDOW_RIGHT - WINDOW_LEFT, ROOM_SIZE.y - WINDOW_HEAD_GAP - WINDOW_SILL_Y)
const WINDOW_CENTER_X: float = (WINDOW_LEFT + WINDOW_RIGHT) / 2.0
const WINDOW_CENTER_Y: float = WINDOW_SILL_Y + WINDOW_SIZE.y / 2.0
## Quantas lâmpadas da sala aparecem refletidas no vidro (o shader aceita 4).
const WINDOW_REFLECTED_LAMPS: int = 4
## Largura, mais ou menos, de cada quadro do vidro, e a travessa de cima (do topo).
const WINDOW_PANE: float = 0.75
const WINDOW_TRANSOM: float = 0.6

## O SOL de dia (Fase 17.9.1). A casa não sabe onde fica o sol do mundo: ele
## entra sempre do mesmo jeito, alto (SUN_ELEVATION_DEGREES acima do horizonte)
## e de lado (SUN_SIDE_DEGREES do norte para o oeste), e cai para dentro da
## sala, puxando para o leste: a mancha clara da janela fica no chão de
## madeira, entre o aparador e quem nasce, fora do tapete do canto de estar (o
## pelo do tapete, no sol, vira chuvisco). A luz fica a SUN_DISTANCE m da
## janela, do lado de fora, para os raios saírem quase paralelos (como os do
## sol), e mira só a janela: a parede faz o resto.
const SUN_ELEVATION_DEGREES: float = 40.0
const SUN_SIDE_DEGREES: float = 14.0
const SUN_DISTANCE: float = 14.0
## A cor do sol no fim da tarde (o pôr do sol puxa para ela).
const SUN_DUSK_COLOR: Color = Color(1.0, 0.62, 0.36)
## A luz rebatida: do chão claro para cima, aberta (graus) e curta (m).
const SUN_BOUNCE_ANGLE: float = 80.0
const SUN_BOUNCE_RANGE: float = 6.0
## De dia (noite abaixo disto) as luzes do dia acendem; acima, somem de vez.
const DAY_LIGHTS_UNTIL: float = 0.98

## As vigas do teto (se o tema tiver): de leste a oeste, em três linhas, com
## esta largura e altura. Os móveis altos das paredes ficam abaixo delas.
const BEAM_Z: Array[float] = [-ROOM_SIZE.z / 3.0, 0.0, ROOM_SIZE.z / 3.0]
const BEAM_SIZE: Vector2 = Vector2(0.14, 0.16)
## O néon corre nas paredes oeste e leste, entre as vigas, acima dos móveis.
const NEON_Y: float = ROOM_SIZE.y - BEAM_SIZE.y / 2.0
const NEON_END_GAP: float = 0.5

## Os lugares das paredes oeste e leste ficam um pouco ao sul do meio: o canto
## de estar e a mesa respiram.
const SIDE_ANCHOR_Z: float = 0.3

## Onde o jogador nasce: um pouco ao sul e a leste do meio da sala, olhando
## para o canto noroeste (a estante à esquerda, o canto de estar à frente e a
## janela à direita, como na referência): SPAWN_TURN_DEGREES girado do norte
## para o oeste. Cada disposição pode ter o seu giro.
const SPAWN_SPOT: Vector3 = Vector3(ROOM_SIZE.x / 10.0, 0.1, ROOM_SIZE.z / 7.0)
const SPAWN_TURN_DEGREES: float = 35.0

## O tema da casa (cores, materiais, luz, enfeite).
var _profile: HomeProfile
## A disposição dos móveis (lugares prontos).
var _layout: HomeLayout
## As peças da casca (filhos diretos da casa), para refazer ao trocar de tema.
var _shell_nodes: Array[Node] = []
## Cores escolhidas pelo usuário (transparente = a do tema).
var _wall_override: Color = Color(0, 0, 0, 0)
var _neon_override: Color = Color(0, 0, 0, 0)
var _environment: Environment
var _front_door: TravelDoor
## A placa da porta da rua (Fase 18.3): o que está acontecendo lá fora.
var _door_status: Label3D
var _window_material: ShaderMaterial
var _window_glass: MeshInstance3D
## O retrato do mundo para a janela (Fase 17.3).
var _window_view: WindowView
## As luzes do dia (Fase 17.9.1): o céu (espalhado, sem sombra), o sol (com
## sombra, pela janela) e a luz que o chão ensolarado rebate para cima.
var _daylight: SpotLight3D
var _sunlight: SpotLight3D
var _sun_bounce: SpotLight3D
## As luminárias da sala (tudo o que acende, menos as luzes do dia e o fogo):
## de dia ficam mais fracas (HomeProfile.lamp_day_scale). A força de noite fica
## guardada em cada uma (meta NIGHT_ENERGY_META).
var _lamps: Array[Light3D] = []
const NIGHT_ENERGY_META: StringName = &"night_energy"
## 0 = dia, 1 = noite (a cidade avisa pelo grupo city_night).
var _night: float = 1.0


func _ready() -> void:
	add_to_group("home")
	# O mundo avisa a hora pelo grupo city_night (set_night): a janela e a luz
	# do dia acompanham.
	add_to_group("city_night")
	_read_choices()
	_build_environment()
	_build_window_view()
	_build_front_door()
	_build_shell()
	_build_furniture()
	_build_indoor_area()
	_put_on_interior_layer(self)
	_reflect_lamps_in_window()
	_collect_lamps()
	set_night(_night)


## Onde (e para onde virado) o jogador aparece ao entrar em casa.
func get_spawn_transform() -> Transform3D:
	# Girar +Y leva a frente (-Z, o norte) para o oeste (-X).
	var degrees := _layout.spawn_turn_degrees if _layout != null else SPAWN_TURN_DEGREES
	var turn := Basis(Vector3.UP, deg_to_rad(degrees))
	return Transform3D(global_basis * turn, to_global(SPAWN_SPOT))


## A porta da rua (quem coloca a casa diz para onde ela leva).
func get_front_door() -> TravelDoor:
	return _front_door


## Escreve na porta da rua o que está acontecendo lá fora ("Montando a
## cidade… 40%", "Não encontrei a Steam…"), para quem está em casa entender
## sem precisar olhar o aviso do topo. Texto vazio = a placa some. Quem decide o texto é o mundo.
func set_door_status(text: String) -> void:
	_door_status.text = text
	_door_status.visible = not text.is_empty()


## O que a placa da porta diz agora ("" = nada).
func get_door_status() -> String:
	return _door_status.text if _door_status.visible else ""


## A luz e o fundo de dentro de casa (a câmera usa este no lugar do mundo).
func get_environment() -> Environment:
	return _environment


## A hora lá fora (0 = dia, 1 = noite): o horizonte da janela, a luz do dia que
## entra por ela e a luz ambiente mudam juntos.
func set_night(night: float) -> void:
	_night = clampf(night, 0.0, 1.0)
	if _window_material != null:
		_window_material.set_shader_parameter("night", _night)
	if _window_view != null:
		_window_view.set_night(_night)  # na troca de fase do dia, o retrato é refeito
	var day := 1.0 - _night
	var lit := _night < DAY_LIGHTS_UNTIL
	if _daylight != null:
		_daylight.light_energy = _profile.daylight_energy * day
		_daylight.visible = lit
	if _sunlight != null:
		# No pôr do sol (noite perto de 0,5) o sol esquenta.
		var dusk := 1.0 - absf(_night * 2.0 - 1.0)
		_sunlight.light_color = _profile.sun_color.lerp(SUN_DUSK_COLOR, dusk)
		_sunlight.light_energy = _profile.sun_energy * day
		_sunlight.visible = lit
		_sun_bounce.light_color = _sunlight.light_color
		_sun_bounce.light_energy = _profile.sun_energy * _profile.sun_bounce * day
		_sun_bounce.visible = lit
	# As luminárias: inteiras à noite; de dia, só o apoio quente.
	var lamp_scale := lerpf(_profile.lamp_day_scale, 1.0, _night)
	for lamp in _lamps:
		if is_instance_valid(lamp):
			lamp.light_energy = _night_energy(lamp) * lamp_scale
	if _environment != null:
		_environment.ambient_light_color = _profile.ambient_night_color.lerp(_profile.ambient_day_color, 1.0 - _night)
		_environment.ambient_light_energy = lerpf(_profile.ambient_day_energy, _profile.ambient_night_energy, _night)


func get_night() -> float:
	return _night


## O sol que entra pela janela de dia (Fase 17.9.1; os testes conferem).
func get_sunlight() -> SpotLight3D:
	return _sunlight


## As luminárias que enfraquecem de dia.
func get_lamps() -> Array[Light3D]:
	return _lamps


## O retrato do mundo que a janela mostra (Fase 17.3).
func get_window_view() -> WindowView:
	return _window_view


## O tema de agora.
func get_profile() -> HomeProfile:
	return _profile


# --- Montagem -------------------------------------------------------------------

## Luz de dentro: fundo escuro, luz ambiente fraca (quem ilumina de verdade são
## as luminárias, em poças quentes; entre elas fica o meio-tom frio do ambiente)
## e o mesmo "filme" de cor da cidade. O sombreamento dos cantos (SSAO) é mais
## forte que o padrão: é ele que assenta os móveis no chão.
func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_energy = 0.35
	_apply_profile_to_environment()
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.glow_enabled = true
	_environment.glow_hdr_threshold = 1.0
	_environment.ssao_enabled = true
	_environment.ssao_radius = 1.2
	_environment.ssao_intensity = 2.5
	_apply_quality()
	AppConfig.settings_changed.connect(_on_settings_changed)


## Fundo e luz ambiente do tema (a hora lá fora acerta o resto em set_night).
func _apply_profile_to_environment() -> void:
	_environment.background_color = _profile.background_color
	_environment.ambient_light_color = _profile.ambient_night_color


## Lê do config.cfg o tema e as cores escolhidas. Tema desconhecido cai no padrão.
func _read_choices() -> void:
	_profile = Profiles.home(AppConfig.get_home_theme())
	_layout = Profiles.home_layout(AppConfig.get_home_layout())
	_wall_override = _parse_color(AppConfig.get_home_wall_color())
	_neon_override = _parse_color(AppConfig.get_home_neon_color())


## "#rrggbb" vira cor; vazio ou inválido vira transparente (= a do tema).
func _parse_color(html: String) -> Color:
	if html.is_empty() or not html.is_valid_html_color():
		return Color(0, 0, 0, 0)
	return Color.html(html)


## Algo do config.cfg mudou ([home]): refaz só a casca, na hora. Os móveis, a
## porta que funciona e a área "em casa" ficam onde estão (quem está olhando
## o computador continua olhando).
func _apply_choices() -> void:
	_read_choices()
	for node in _shell_nodes:
		if is_instance_valid(node):
			remove_child(node)  # sai já, para os nomes novos não ganharem "@"
			node.queue_free()
	_shell_nodes.clear()
	_window_material = null
	_window_glass = null
	_daylight = null
	_sunlight = null
	_sun_bounce = null
	_apply_profile_to_environment()
	_build_shell()
	for node in _shell_nodes:
		_put_on_interior_layer(node)
	_place_furniture()
	_reflect_lamps_in_window()
	_collect_lamps()
	if _system_panel != null:
		_system_panel.set_accent(_neon_color())
	set_night(_night)


## A superfície vira material; a cor de parede escolhida pinta as "paintable".
func _material_of(surface: HomeSurface) -> Material:
	return HomeMaterials.from_surface(surface, _wall_override if surface.paintable else Color(0, 0, 0, 0))


func _neon_color() -> Color:
	return _neon_override if _neon_override.a > 0.0 else _profile.neon_color


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "quality":
		_apply_quality()
	elif section == "home":
		_apply_choices()


## A qualidade gráfica vale aqui também. Névoa volumétrica, não: dentro de
## casa ela só deixa o ar enevoado (e custa caro). A luz rebatida (SSIL) quem
## decide é o GraphicsQuality (só na Alta).
func _apply_quality() -> void:
	var level := AppConfig.get_quality()
	GraphicsQuality.apply_to_environment(_environment, level)
	GraphicsQuality.apply_indoor_light(_environment, level)
	_environment.volumetric_fog_enabled = false


## A casca do tema: sala, janela, aparência da porta, néon e o enfeite.
## Tudo entra direto na casa; a lista _shell_nodes guarda o que é casca.
func _build_shell() -> void:
	var before := get_children()
	_build_room()
	_build_window()
	_build_door_look()
	_add_neon()
	_build_decor()
	for child in get_children():
		if not before.has(child):
			_shell_nodes.append(child)


## Chão, teto e as quatro paredes (com colisão). As paredes ficam do lado de
## fora do volume interno, então ROOM_SIZE é o espaço livre de verdade.
## No loft: piso de tábuas, tijolo aparente na parede da janela, reboco nas
## outras, teto de concreto com vigas de aço.
func _build_room() -> void:
	var w := ROOM_SIZE.x
	var h := ROOM_SIZE.y
	var d := ROOM_SIZE.z
	var t := WALL_THICKNESS
	_add_box("Floor", Vector3(w + t * 2.0, t, d + t * 2.0), Vector3(0.0, -t / 2.0, 0.0), _material_of(_profile.floor))
	_add_box("Ceiling", Vector3(w + t * 2.0, t, d + t * 2.0), Vector3(0.0, h + t / 2.0, 0.0), _material_of(_profile.ceiling))
	var walls := _material_of(_profile.walls)
	_build_north_wall(_material_of(_profile.feature_wall))
	_add_box("WallSouth", Vector3(w + t * 2.0, h, t), Vector3(0.0, h / 2.0, d / 2.0 + t / 2.0), walls)
	_add_box("WallWest", Vector3(t, h, d), Vector3(-w / 2.0 - t / 2.0, h / 2.0, 0.0), walls)
	_add_box("WallEast", Vector3(t, h, d), Vector3(w / 2.0 + t / 2.0, h / 2.0, 0.0), walls)

	# Rodapé nas três paredes comuns.
	var skirting := _material_of(_profile.skirting)
	_add_box("SkirtingSouth", Vector3(w, 0.1, 0.02), Vector3(0.0, 0.05, d / 2.0 - 0.01), skirting, false)
	_add_box("SkirtingWest", Vector3(0.02, 0.1, d), Vector3(-w / 2.0 + 0.01, 0.05, 0.0), skirting, false)
	_add_box("SkirtingEast", Vector3(0.02, 0.1, d), Vector3(w / 2.0 - 0.01, 0.05, 0.0), skirting, false)

	# Vigas no teto, de leste a oeste (se o tema tiver).
	if _profile.beams != null:
		var beams := _material_of(_profile.beams)
		for z in BEAM_Z:
			_add_box("Beam", Vector3(w, BEAM_SIZE.y, BEAM_SIZE.x), Vector3(0.0, h - BEAM_SIZE.y / 2.0, z), beams, false)


## A parede da janela (norte) em quatro pedaços em volta do vão (Fase 17.9.1):
## embaixo do peitoril, em cima da janela e dos dois lados. Pelo vão passa o sol
## de dia, e a parede faz a sombra em volta (o desenho da janela no chão). O
## vidro tapa o vão para quem olha de dentro, e uma colisão sem desenho tapa
## para quem anda. As texturas são projetadas pela posição no mundo: os pedaços
## se emendam sem costura.
func _build_north_wall(material: Material) -> void:
	var w := ROOM_SIZE.x
	var h := ROOM_SIZE.y
	var t := WALL_THICKNESS
	var z := -ROOM_SIZE.z / 2.0 - t / 2.0
	var outer_left := -w / 2.0 - t
	var outer_right := w / 2.0 + t
	var head := WINDOW_SILL_Y + WINDOW_SIZE.y
	_add_box("WallNorth", Vector3(w + t * 2.0, WINDOW_SILL_Y, t), Vector3(0.0, WINDOW_SILL_Y / 2.0, z), material)
	_add_box("WallNorthTop", Vector3(w + t * 2.0, h - head, t), Vector3(0.0, (head + h) / 2.0, z), material)
	_add_box("WallNorthWest", Vector3(WINDOW_LEFT - outer_left, WINDOW_SIZE.y, t),
			Vector3((outer_left + WINDOW_LEFT) / 2.0, WINDOW_CENTER_Y, z), material)
	_add_box("WallNorthEast", Vector3(outer_right - WINDOW_RIGHT, WINDOW_SIZE.y, t),
			Vector3((WINDOW_RIGHT + outer_right) / 2.0, WINDOW_CENTER_Y, z), material)
	var block := StaticBody3D.new()
	block.name = "WindowBlock"
	block.set_meta("footstep", _profile.footstep)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WINDOW_SIZE.x, WINDOW_SIZE.y, t)
	shape.shape = box
	block.add_child(shape)
	block.position = Vector3(WINDOW_CENTER_X, WINDOW_CENTER_Y, z)
	add_child(block)


## O janelão da parede norte: o vidro mostra a vista (o shader do tema; no
## loft, o horizonte da cidade) e a moldura o divide em quadros de mais ou
## menos WINDOW_PANE. De dia, uma luz fria entra por ele.
func _build_window() -> void:
	var inner_z := -ROOM_SIZE.z / 2.0
	_window_material = ShaderMaterial.new()
	_window_material.shader = load(_profile.window_shader) as Shader
	var glass := MeshInstance3D.new()
	glass.name = "WindowView"
	var quad := QuadMesh.new()
	quad.size = WINDOW_SIZE
	glass.mesh = quad
	glass.material_override = _window_material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = Vector3(WINDOW_CENTER_X, WINDOW_CENTER_Y, inner_z + 0.01)
	add_child(glass)
	_window_glass = glass
	_window_view.set_material(_window_material)  # o tema da floresta não usa o retrato
	# O enquadramento do tema (17.9.2): a cabana olha mais para cima e mais perto.
	_window_view.set_framing(_profile.window_view_zoom, _profile.window_view_pitch_degrees)

	var steel := _material_of(_profile.window_frame)
	var half := WINDOW_SIZE / 2.0
	var bar := 0.06
	var depth := 0.06
	var z := inner_z + depth / 2.0
	# Bordas e travessas (horizontais) e montantes (verticais).
	var panes := maxi(roundi(WINDOW_SIZE.x / WINDOW_PANE), 1)
	for y in [-half.y, half.y, half.y - WINDOW_TRANSOM]:
		_add_box("WindowBar", Vector3(WINDOW_SIZE.x + bar, bar, depth), Vector3(WINDOW_CENTER_X, WINDOW_CENTER_Y + y, z), steel, false)
	for i in panes + 1:
		var x := WINDOW_CENTER_X - half.x + i * WINDOW_SIZE.x / panes
		_add_box("WindowPost", Vector3(bar, WINDOW_SIZE.y, depth), Vector3(x, WINDOW_CENTER_Y, z), steel, false)
	# Peitoril embaixo.
	_add_box("WindowSill", Vector3(WINDOW_SIZE.x + 0.3, 0.06, 0.22),
			Vector3(WINDOW_CENTER_X, WINDOW_CENTER_Y - half.y - 0.03, inner_z + 0.11), _material_of(_profile.window_sill))

	# A luz do céu: espalhada, sem sombra, do alto da janela para dentro.
	_daylight = SpotLight3D.new()
	_daylight.name = "Daylight"
	_daylight.light_color = _profile.daylight_color
	_daylight.spot_range = ROOM_SIZE.z + 2.0
	_daylight.spot_angle = 70.0
	_daylight.spot_attenuation = 0.4  # cai devagar: chega até a parede do fundo
	_daylight.position = Vector3(WINDOW_CENTER_X, WINDOW_CENTER_Y + 0.6, inner_z + 0.2)
	_daylight.rotation = Vector3(deg_to_rad(-30.0), 0.0, 0.0)  # para dentro (sul) e para baixo
	add_child(_daylight)
	_build_sun()
	set_night(_night)


## O sol de dia (Fase 17.9.1): uma luz de cone estreito do lado de fora, longe,
## mirando a janela, com sombra. Sem perder força com a distância (como o sol),
## ela só passa pelo vão: a parede e os quadros da janela desenham a sombra, e a
## mancha clara cai no chão da sala. Ela só acende a camada da casa. Uma
## segunda luz, sem sombra, sobe do meio da mancha: é o chão ensolarado
## devolvendo luz para o teto e para a parede da janela (sem ela, em volta da
## janela ficava quase preto de dia).
func _build_sun() -> void:
	var travel := sun_direction()
	var window := Vector3(WINDOW_CENTER_X, WINDOW_CENTER_Y, -ROOM_SIZE.z / 2.0)
	_sunlight = SpotLight3D.new()
	_sunlight.name = "Sunlight"
	_sunlight.light_cull_mask = INTERIOR_LAYER_MASK
	_sunlight.spot_attenuation = 0.0  # não enfraquece com a distância
	_sunlight.spot_range = SUN_DISTANCE + ROOM_SIZE.z * 2.0
	# Abre o bastante para pegar a janela inteira (a meia diagonal, vista de
	# longe) e uma folga: a borda do cone fica na parede, nunca no vão.
	_sunlight.spot_angle = rad_to_deg(atan(WINDOW_SIZE.length() / 2.0 / SUN_DISTANCE)) + 4.0
	_sunlight.spot_angle_attenuation = 0.2
	_sunlight.shadow_enabled = true
	_sunlight.shadow_blur = 0.6  # a sombra do sol é quase nítida
	_sunlight.transform = Transform3D(Basis.looking_at(travel), window - travel * SUN_DISTANCE)
	add_child(_sunlight)
	# Onde o raio do meio da janela bate no chão: o meio da mancha.
	var patch := window + travel * (WINDOW_CENTER_Y / -travel.y)
	_sun_bounce = SpotLight3D.new()
	_sun_bounce.name = "SunBounce"
	_sun_bounce.light_cull_mask = INTERIOR_LAYER_MASK
	_sun_bounce.spot_angle = SUN_BOUNCE_ANGLE
	_sun_bounce.spot_range = SUN_BOUNCE_RANGE
	_sun_bounce.spot_angle_attenuation = 0.8
	_sun_bounce.spot_attenuation = 0.5  # cai devagar: chega ao teto
	_sun_bounce.position = Vector3(patch.x, 0.05, patch.z)
	_sun_bounce.rotation.x = PI / 2.0  # o cone aponta para cima
	add_child(_sun_bounce)


## Para onde os raios do sol andam, já dentro da sala (para baixo, para o sul
## e um pouco para o leste).
static func sun_direction() -> Vector3:
	var elevation := deg_to_rad(SUN_ELEVATION_DEGREES)
	var side := deg_to_rad(SUN_SIDE_DEGREES)
	return Vector3(sin(side) * cos(elevation), -sin(elevation), cos(side) * cos(elevation)).normalized()


## As luminárias da sala: todas as luzes, menos as do dia e o fogo (que tremula
## sozinho e fica igual de dia). Guarda a força de noite de cada uma, uma vez.
func _collect_lamps() -> void:
	_lamps.clear()
	for node: Node in find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light in [_daylight, _sunlight, _sun_bounce] or "base_energy" in light:
			continue
		if not light.has_meta(NIGHT_ENERGY_META):
			light.set_meta(NIGHT_ENERGY_META, light.light_energy)
		_lamps.append(light)


## A força de uma luminária à noite (a de agora, se ela ainda não foi guardada).
func _night_energy(light: Light3D) -> float:
	return float(light.get_meta(NIGHT_ENERGY_META, light.light_energy))


## O retrato do mundo para a janela: não faz parte da casca (fica entre as
## trocas de tema, e o material novo recebe o retrato de agora). A câmera do
## retrato não vê a camada da casa.
func _build_window_view() -> void:
	_window_view = WindowView.new()
	_window_view.name = "WindowPortrait"
	_window_view.hidden_layers = INTERIOR_LAYER_MASK
	add_child(_window_view)


## As lâmpadas da sala refletidas no vidro: as WINDOW_REFLECTED_LAMPS luzes mais
## perto da janela (sem a luz do dia, que entra por ela), no espaço do vidro.
## Uma luminária com duas luzes no mesmo lugar conta uma vez só.
func _reflect_lamps_in_window() -> void:
	if _window_material == null or _window_glass == null:
		return
	var lamps: Array[Vector3] = []
	for light: Node in find_children("*", "Light3D", true, false):
		var lamp := light as Light3D
		# A força de noite: de dia as luminárias estão mais fracas, e o reflexo
		# não pode mudar com a hora em que o tema foi trocado.
		if lamp in [_daylight, _sunlight, _sun_bounce] or not lamp.visible or _night_energy(lamp) < 0.5:
			continue
		var spot := _window_glass.to_local(lamp.global_position)
		if spot.z <= 0.2:
			continue  # atrás do vidro (ou encostada nele)
		var repeated := false
		for other in lamps:
			repeated = repeated or other.distance_to(spot) < 0.5
		if not repeated:
			lamps.append(spot)
	lamps.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.length() < b.length())
	var packed := PackedVector4Array()
	for i in WINDOW_REFLECTED_LAMPS:
		packed.append(Vector4(lamps[i].x, lamps[i].y, lamps[i].z, 1.0) if i < lamps.size() else Vector4.ZERO)
	_window_material.set_shader_parameter("reflection_lights", packed)
	_window_material.set_shader_parameter("reflection_light_color", _profile.lamp_color)


## Porta da rua, na parede sul, com a frente para dentro da sala (de onde o
## jogador vem). Para onde ela leva quem decide é o mundo. Esta é a porta que
## funciona (não é refeita ao trocar de tema); a aparência é da casca.
func _build_front_door() -> void:
	_front_door = TravelDoor.new()
	_front_door.name = "FrontDoor"
	_front_door.door_name = "Porta da rua"
	_front_door.action_text = "{interact} para sair"  # vista de dentro, ela leva para fora
	_front_door.position = Vector3(DOOR_X, 0.0, ROOM_SIZE.z / 2.0 - 0.1)
	_front_door.rotation.y = PI  # a frente (+Z) da porta aponta para dentro da sala
	add_child(_front_door)
	# A placa fica na folha da porta, na altura dos olhos, virada para a sala
	# (a origem da porta já fica uns centímetros à frente da folha).
	_door_status = Label3D.new()
	_door_status.name = "DoorStatus"
	_door_status.font_size = DOOR_STATUS_FONT_SIZE
	_door_status.pixel_size = DOOR_STATUS_PIXEL_SIZE
	_door_status.width = DOOR_STATUS_WIDTH / DOOR_STATUS_PIXEL_SIZE
	_door_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_door_status.modulate = DOOR_STATUS_COLOR
	_door_status.outline_size = 8
	_door_status.outline_modulate = Color(0.05, 0.04, 0.05)
	_door_status.position = Vector3(0.0, DOOR_STATUS_HEIGHT, 0.01)
	_door_status.layers = INTERIOR_LAYER_MASK
	_door_status.visible = false
	_front_door.add_child(_door_status)


## A aparência da porta da rua: folha, batente, maçaneta e uma arandela
## quente em cima (a saída fica fácil de achar).
func _build_door_look() -> void:
	var z := ROOM_SIZE.z / 2.0
	var x := DOOR_X
	var jamb := 0.1
	_add_box("DoorPanel", Vector3(DOOR_WIDTH - jamb * 2.0, 2.2, 0.06), Vector3(x, 1.1, z - 0.03), _material_of(_profile.door), false)
	var frame := _material_of(_profile.door_frame)
	for side in [-1.0, 1.0]:
		_add_box("DoorJamb", Vector3(jamb, 2.3, 0.1), Vector3(x + side * (DOOR_WIDTH - jamb) / 2.0, 1.15, z - 0.05), frame, false)
	_add_box("DoorHead", Vector3(DOOR_WIDTH, 0.1, 0.1), Vector3(x, 2.3, z - 0.05), frame, false)
	_add_box("DoorHandle", Vector3(0.12, 0.03, 0.05), Vector3(x - 0.4, 1.0, z - 0.09), _material_of(_profile.door_handle), false)
	_add_box("DoorSconce", Vector3(0.36, 0.08, 0.1), Vector3(x, 2.55, z - 0.05), HomeMaterials.glow(_profile.lamp_color, 4.0), false)
	var sconce := OmniLight3D.new()
	sconce.name = "DoorLight"
	sconce.light_color = _profile.lamp_color
	sconce.light_energy = 0.9
	sconce.omni_range = 3.5
	sconce.position = Vector3(x, 2.4, z - 0.35)
	add_child(sconce)


## O enfeite do tema (o script do perfil): no loft, os pendentes e o canto
## de estar virado para a janela.
func _build_decor() -> void:
	if _profile.decor_script.is_empty():
		return
	var script := load(_profile.decor_script) as GDScript
	if script == null:
		push_warning("Home: não consegui carregar o enfeite %s." % _profile.decor_script)
		return
	var decor: HomeDecor = script.new()
	decor.target = self
	decor.profile = _profile
	decor.build()


## Faixa de néon junto do teto, nas paredes oeste e leste (por cima da
## estante e do mural), com uma luz fraca da mesma cor. Brilho 0 = sem néon.
## As vigas encostam nessas paredes: a faixa corre entre elas, em pedaços que
## viram uma malha só por parede.
func _add_neon() -> void:
	if _profile.neon_energy <= 0.0:
		return
	var y := NEON_Y
	var half := ROOM_SIZE.z / 2.0 - NEON_END_GAP
	# As pontas de cada pedaço, de sul a norte, pulando as vigas.
	var cuts: Array[float] = [-half]
	if _profile.beams != null:
		for z in BEAM_Z:
			cuts.append_array([z - BEAM_SIZE.x / 2.0, z + BEAM_SIZE.x / 2.0])
	cuts.append(half)
	for side in [-1.0, 1.0]:
		var x: float = side * (ROOM_SIZE.x / 2.0 - 0.04)
		var strip := HomeShapes.Batch.new()
		for i in range(0, cuts.size(), 2):
			strip.add_box(Vector3(0.03, 0.03, cuts[i + 1] - cuts[i]),
					Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, (cuts[i] + cuts[i + 1]) / 2.0)), Color.WHITE)
		var neon := MeshInstance3D.new()
		neon.name = "NeonStrip"
		neon.mesh = strip.commit()
		neon.material_override = HomeMaterials.glow(_neon_color(), _profile.neon_energy)
		neon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		neon.position = Vector3(x, y, 0.0)
		add_child(neon)
		var light := OmniLight3D.new()
		light.name = "NeonLight"
		light.light_color = _neon_color()
		light.light_energy = _profile.neon_light_energy
		light.omni_range = ROOM_SIZE.z / 2.0 + 1.0
		light.position = Vector3(x - side * 0.4, y - 0.3, 0.0)
		add_child(light)


## Os lugares prontos da sala (Fase 13.4): onde o móvel encosta na parede.
## [posição (x, z), giro em Y]. A frente (+Z) do móvel aponta para dentro da
## sala. Os nomes são os de HomeLayout.ANCHORS. Tudo sai do tamanho da sala
## (17.4b): na parede sul, um lugar começa no canto oeste e o outro acaba na
## porta, cada um com espaço para um WIDE_PIECE; "norte_esquerda" é o meio do
## canto de estar, e "norte_direita", a mesa do computador.
const ANCHORS: Dictionary[String, Array] = {
	"oeste": [Vector2(-ROOM_SIZE.x / 2.0, SIDE_ANCHOR_Z), PI / 2.0],
	"leste": [Vector2(ROOM_SIZE.x / 2.0, SIDE_ANCHOR_Z), -PI / 2.0],
	"sul_esquerda": [Vector2(-ROOM_SIZE.x / 2.0 + WALL_GAP + WIDE_PIECE / 2.0, ROOM_SIZE.z / 2.0), PI],
	"sul_direita": [Vector2(DOOR_X - DOOR_WIDTH / 2.0 - WALL_GAP - WIDE_PIECE / 2.0, ROOM_SIZE.z / 2.0), PI],
	"norte_esquerda": [Vector2(-ROOM_SIZE.x / 2.0 + LIVING_CORNER_WIDTH / 2.0, -ROOM_SIZE.z / 2.0), 0.0],
	"norte_direita": [COMPUTER_SPOT, 0.0],
}
## Os móveis que mudam de lugar com a disposição: id (o mesmo de
## HomeLayout.placements) → [script, nome do nó]. Um móvel que a disposição cita
## e que ainda não está aqui é ignorado.
const MOVABLE: Dictionary[String, Array] = {
	"estante": [preload("res://worlds/home/library_shelf.gd"), "LibraryShelf"],
	"mural": [preload("res://worlds/home/friends_wall.gd"), "FriendsWall"],
	"estatisticas": [preload("res://worlds/home/stats_wall.gd"), "StatsWall"],
	"espelho": [preload("res://worlds/home/home_mirror.gd"), "HomeMirror"],
}
## O computador não muda de lugar: a troca de tema e de disposição é feita por
## ele, e a mesa não pode sair de baixo da câmera.
const COMPUTER_ANCHOR: String = "norte_direita"

## Os móveis que já existem (id → nó), para a disposição só movê-los.
var _furniture: Dictionary[String, Node3D] = {}
var _system_panel: SystemPanel


## Os móveis: cada um é um script em worlds/home/. Os que mudam de lugar
## (MOVABLE) são criados uma vez e só se movem quando a disposição muda.
func _build_furniture() -> void:
	for id in MOVABLE:
		var node := (MOVABLE[id][0] as GDScript).new() as Node3D
		node.name = MOVABLE[id][1]
		if "fallback_door" in node:
			node.set("fallback_door", _front_door)  # amigo que não joga nada da biblioteca leva à porta da rua
		add_child(node)
		_furniture[id] = node
	var desk := ComputerDesk.new()
	desk.name = "ComputerDesk"
	add_child(desk)
	_place_on_anchor(desk, COMPUTER_ANCHOR)
	# O painel do sistema (Fase 14.9) é fixo, na parede norte, acima do computador.
	_system_panel = SystemPanel.new()
	_system_panel.name = "SystemPanel"
	# A altura: no meio entre o alto dos monitores e o teto.
	_system_panel.center_y = (ComputerDesk.SCREEN_HEIGHT + ComputerDesk.SCREEN_SIZE.y / 2.0 + ComputerDesk.BEZEL + ROOM_SIZE.y) / 2.0
	_system_panel.position = Vector3(get_anchor_transform(COMPUTER_ANCHOR).origin.x, 0.0, -ROOM_SIZE.z / 2.0)
	add_child(_system_panel)
	_system_panel.set_accent(_neon_color())
	_place_furniture()


## O painel do sistema (hora, bateria, Wi-Fi, volume), fixo na parede norte.
func get_system_panel() -> SystemPanel:
	return _system_panel


## Põe cada móvel no lugar que a disposição manda.
func _place_furniture() -> void:
	for id in _furniture:
		_place_on_anchor(_furniture[id], _layout.placements.get(id, "oeste") if _layout != null else "oeste")


## A posição e o giro de um lugar pronto, em coordenadas da casa.
func get_anchor_transform(anchor: String) -> Transform3D:
	var info: Array = ANCHORS.get(anchor, ANCHORS["oeste"])
	var spot: Vector2 = info[0]
	return Transform3D(Basis(Vector3.UP, float(info[1])), Vector3(spot.x, 0.0, spot.y))


## O móvel de um id (estante, mural...), ou null.
func get_furniture(id: String) -> Node3D:
	return _furniture.get(id)


func _place_on_anchor(node: Node3D, anchor: String) -> void:
	node.transform = get_anchor_transform(anchor)


## A disposição de agora.
func get_layout() -> HomeLayout:
	return _layout


## Área "em casa": avisa o jogador quando ele entra e quando sai.
func _build_indoor_area() -> void:
	var area := Area3D.new()
	area.name = "IndoorArea"
	area.collision_layer = 0
	area.collision_mask = 2  # o jogador
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ROOM_SIZE
	shape.shape = box
	shape.position = Vector3(0.0, ROOM_SIZE.y / 2.0, 0.0)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("set_indoors"):
			body.set_indoors(_environment))
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.has_method("set_indoors"):
			body.set_indoors(null))


# --- Peças --------------------------------------------------------------------

## Caixa com material e, se "solid", colisão. O que é sólido na casa leva a
## marca de passos do tema (o jogador lê para escolher o som).
func _add_box(box_name: String, box_size: Vector3, center: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	return HomeDecor.make_box(self, box_name, box_size, center, material, solid, _profile.footstep)


## Tudo o que a casa desenha vai para a camada do interior (o sol do mundo
## não ilumina essa camada).
func _put_on_interior_layer(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = INTERIOR_LAYER_MASK
	for child in node.get_children():
		_put_on_interior_layer(child)

