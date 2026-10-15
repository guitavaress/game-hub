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
## Convenção: a origem fica no chão, no meio da sala. O norte (-Z) é a parede
## da janela; a porta da rua fica na parede sul (+Z).

## Camada de render do interior (de 1 a 20) e a máscara dela (bit).
const INTERIOR_LAYER: int = 20
const INTERIOR_LAYER_MASK: int = 1 << (INTERIOR_LAYER - 1)
## Tamanho por dentro (largura x, altura, profundidade z), em metros.
const ROOM_SIZE: Vector3 = Vector3(12.0, 3.4, 9.0)
const WALL_THICKNESS: float = 0.3
## Onde o jogador nasce: um pouco ao sul do meio, olhando entre a janela
## (norte) e a estante (parede oeste): SPAWN_TURN_DEGREES girado do norte
## para o oeste. Ele vê a estante e o janelão logo de cara.
const SPAWN_SPOT: Vector3 = Vector3(0.0, 0.1, 1.5)
const SPAWN_TURN_DEGREES: float = 35.0

## O janelão na parede norte (largura, altura) e a altura do meio dele.
const WINDOW_SIZE: Vector2 = Vector2(5.2, 2.4)
const WINDOW_CENTER_Y: float = 1.65

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
var _window_material: ShaderMaterial
var _daylight: SpotLight3D
## 0 = dia, 1 = noite (a cidade avisa pelo grupo city_night).
var _night: float = 1.0


func _ready() -> void:
	add_to_group("home")
	# O mundo avisa a hora pelo grupo city_night (set_night): a janela e a luz
	# do dia acompanham.
	add_to_group("city_night")
	_read_choices()
	_build_environment()
	_build_front_door()
	_build_shell()
	_build_furniture()
	_build_indoor_area()
	_put_on_interior_layer(self)


## Onde (e para onde virado) o jogador aparece ao entrar em casa.
func get_spawn_transform() -> Transform3D:
	# Girar +Y leva a frente (-Z, o norte) para o oeste (-X).
	var degrees := _layout.spawn_turn_degrees if _layout != null else SPAWN_TURN_DEGREES
	var turn := Basis(Vector3.UP, deg_to_rad(degrees))
	return Transform3D(global_basis * turn, to_global(SPAWN_SPOT))


## A porta da rua (quem coloca a casa diz para onde ela leva).
func get_front_door() -> TravelDoor:
	return _front_door


## A luz e o fundo de dentro de casa (a câmera usa este no lugar do mundo).
func get_environment() -> Environment:
	return _environment


## A hora lá fora (0 = dia, 1 = noite): o horizonte da janela, a luz do dia que
## entra por ela e a luz ambiente mudam juntos.
func set_night(night: float) -> void:
	_night = clampf(night, 0.0, 1.0)
	if _window_material != null:
		_window_material.set_shader_parameter("night", _night)
	if _daylight != null:
		_daylight.light_energy = _profile.daylight_energy * (1.0 - _night)
		_daylight.visible = _night < 0.98
	if _environment != null:
		_environment.ambient_light_color = _profile.ambient_night_color.lerp(_profile.ambient_day_color, 1.0 - _night)
		_environment.ambient_light_energy = lerpf(_profile.ambient_day_energy, _profile.ambient_night_energy, _night)


func get_night() -> float:
	return _night


## O tema de agora.
func get_profile() -> HomeProfile:
	return _profile


# --- Montagem -------------------------------------------------------------------

## Luz de dentro: fundo escuro, luz ambiente quente e fraca (quem ilumina de
## verdade são as luminárias) e o mesmo "filme" de cor da cidade.
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
	_daylight = null
	_apply_profile_to_environment()
	_build_shell()
	for node in _shell_nodes:
		_put_on_interior_layer(node)
	_place_furniture()
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
## casa ela só deixa o ar enevoado (e custa caro).
func _apply_quality() -> void:
	GraphicsQuality.apply_to_environment(_environment, AppConfig.get_quality())
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
	_add_box("WallNorth", Vector3(w + t * 2.0, h, t), Vector3(0.0, h / 2.0, -d / 2.0 - t / 2.0), _material_of(_profile.feature_wall))
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
		for z in [-d / 3.0, 0.0, d / 3.0]:
			_add_box("Beam", Vector3(w, 0.22, 0.16), Vector3(0.0, h - 0.11, z), beams, false)


## O janelão da parede norte: o vidro mostra a vista (o shader do tema; no
## loft, o horizonte da cidade) e a moldura o divide em quadros. De dia, uma
## luz fria entra por ele.
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
	glass.position = Vector3(0.0, WINDOW_CENTER_Y, inner_z + 0.01)
	add_child(glass)

	var steel := _material_of(_profile.window_frame)
	var half := WINDOW_SIZE / 2.0
	var bar := 0.06
	var depth := 0.06
	var z := inner_z + depth / 2.0
	# Bordas e travessas (horizontais) e montantes (verticais).
	for y in [-half.y, half.y, half.y - 0.7]:
		_add_box("WindowBar", Vector3(WINDOW_SIZE.x + bar, bar, depth), Vector3(0.0, WINDOW_CENTER_Y + y, z), steel, false)
	for i in 5:
		var x := -half.x + i * WINDOW_SIZE.x / 4.0
		_add_box("WindowPost", Vector3(bar, WINDOW_SIZE.y, depth), Vector3(x, WINDOW_CENTER_Y, z), steel, false)
	# Peitoril embaixo.
	_add_box("WindowSill", Vector3(WINDOW_SIZE.x + 0.3, 0.06, 0.22),
			Vector3(0.0, WINDOW_CENTER_Y - half.y - 0.03, inner_z + 0.11), _material_of(_profile.window_sill))

	_daylight = SpotLight3D.new()
	_daylight.name = "Daylight"
	_daylight.light_color = _profile.daylight_color
	_daylight.spot_range = 12.0
	_daylight.spot_angle = 70.0
	_daylight.spot_attenuation = 0.8
	_daylight.position = Vector3(0.0, WINDOW_CENTER_Y + 0.6, inner_z + 0.2)
	_daylight.rotation = Vector3(deg_to_rad(-30.0), 0.0, 0.0)  # para dentro (sul) e para baixo
	add_child(_daylight)
	set_night(_night)


## Porta da rua, na parede sul, com a frente para dentro da sala (de onde o
## jogador vem). Para onde ela leva quem decide é o mundo. Esta é a porta que
## funciona (não é refeita ao trocar de tema); a aparência é da casca.
func _build_front_door() -> void:
	_front_door = TravelDoor.new()
	_front_door.name = "FrontDoor"
	_front_door.door_name = "Porta da rua"
	_front_door.action_text = "{interact} para sair"  # vista de dentro, ela leva para fora
	_front_door.position = Vector3(0.0, 0.0, ROOM_SIZE.z / 2.0 - 0.1)
	_front_door.rotation.y = PI  # a frente (+Z) da porta aponta para dentro da sala
	add_child(_front_door)


## A aparência da porta da rua: folha, batente, maçaneta e uma arandela
## quente em cima (a saída fica fácil de achar).
func _build_door_look() -> void:
	var z := ROOM_SIZE.z / 2.0
	_add_box("DoorPanel", Vector3(1.1, 2.2, 0.06), Vector3(0.0, 1.1, z - 0.03), _material_of(_profile.door), false)
	var frame := _material_of(_profile.door_frame)
	for x in [-0.6, 0.6]:
		_add_box("DoorJamb", Vector3(0.1, 2.3, 0.1), Vector3(x, 1.15, z - 0.05), frame, false)
	_add_box("DoorHead", Vector3(1.3, 0.1, 0.1), Vector3(0.0, 2.3, z - 0.05), frame, false)
	_add_box("DoorHandle", Vector3(0.12, 0.03, 0.05), Vector3(-0.4, 1.0, z - 0.09), _material_of(_profile.door_handle), false)
	_add_box("DoorSconce", Vector3(0.36, 0.08, 0.1), Vector3(0.0, 2.55, z - 0.05), HomeMaterials.glow(_profile.lamp_color, 4.0), false)
	var sconce := OmniLight3D.new()
	sconce.name = "DoorLight"
	sconce.light_color = _profile.lamp_color
	sconce.light_energy = 0.9
	sconce.omni_range = 3.5
	sconce.position = Vector3(0.0, 2.4, z - 0.35)
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


## Faixa de néon perto do teto, nas paredes oeste e leste (por cima da
## estante e do mural), com uma luz fraca da mesma cor. Brilho 0 = sem néon.
func _add_neon() -> void:
	if _profile.neon_energy <= 0.0:
		return
	var y := ROOM_SIZE.y - 0.32
	for side in [-1.0, 1.0]:
		var x: float = side * (ROOM_SIZE.x / 2.0 - 0.04)
		_add_box("NeonStrip", Vector3(0.03, 0.03, ROOM_SIZE.z - 1.0), Vector3(x, y, 0.0), HomeMaterials.glow(_neon_color(), _profile.neon_energy), false)
		var light := OmniLight3D.new()
		light.name = "NeonLight"
		light.light_color = _neon_color()
		light.light_energy = _profile.neon_light_energy
		light.omni_range = 4.5
		light.position = Vector3(x - side * 0.4, y - 0.2, 0.0)
		add_child(light)


## Os lugares prontos da sala (Fase 13.4): onde o móvel encosta na parede.
## [posição (x, z), giro em Y]. A frente (+Z) do móvel aponta para dentro da
## sala. Os nomes são os de HomeLayout.ANCHORS.
const ANCHORS: Dictionary[String, Array] = {
	"oeste": [Vector2(-6.0, -0.5), PI / 2.0],
	"leste": [Vector2(6.0, -0.5), -PI / 2.0],
	"sul_esquerda": [Vector2(-3.5, 4.5), PI],
	"sul_direita": [Vector2(3.5, 4.5), PI],
	"norte_esquerda": [Vector2(-4.5, -4.5), 0.0],
	"norte_direita": [Vector2(3.6, -4.1), 0.0],
}
## Os móveis que mudam de lugar com a disposição: id (o mesmo de
## HomeLayout.placements) → [script, nome do nó]. Um móvel que a disposição cita
## e que ainda não está aqui é ignorado.
const MOVABLE: Dictionary[String, Array] = {
	"estante": [preload("res://worlds/home/library_shelf.gd"), "LibraryShelf"],
	"apps": [preload("res://worlds/home/app_shelf.gd"), "AppShelf"],
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
	_system_panel.position = Vector3(get_anchor_transform(COMPUTER_ANCHOR).origin.x, 0.0, -ROOM_SIZE.z / 2.0)
	add_child(_system_panel)
	_system_panel.set_accent(_neon_color())
	var screens := AppScreens.new()  # os telões das janelas dos apps (Fase 14.20)
	screens.name = "AppScreens"
	add_child(screens)
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

