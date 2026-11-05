class_name LookoutDeck
extends Node3D
## O mirante (Fase 15.10; um destino desde a 17.8). No disco plano do alto da
## montanha:
##   - um deque redondo de tábuas (com colisão e footstep = "wood"), recortado
##     em volta da torre do bairro e onde a trilha chega (ali o chão desce);
##   - a plataforma que avança da beirada, virada para a praça, por cima da
##     encosta (quando ela cabe: com a biblioteca de verdade, a trilha pode
##     chegar justo pela frente e não sobrar lugar);
##   - o guarda-corpo de madeira na borda do disco e da plataforma, com as
##     lanternas no começo dele, dos dois lados de onde a trilha chega;
##   - o abrigo de madeira com lanternas, e a fogueira na frente dele, com dois
##     bancos (a luz principal: quente e com sombra);
##   - a luneta de latão (LookoutTelescope: E aproxima a vista da cidade);
##   - dentro do abrigo, a tapeçaria com a capa do seu RPG mais jogado
##     (set_highlight; sem jogos, o abrigo fica só com a parede).
## Os modelos são do Blender (tools/blender/: gerar_deque, gerar_abrigo,
## gerar_lanterna, gerar_luneta; em assets/models/lookout/); o lugar de cada
## peça depende do mirante (o raio, a torre, a trilha) e é calculado aqui.
##
## A direção da plataforma sai da linha do mirante até a praça e gira aos
## poucos, para um lado e para o outro, até achar um lugar que sirva:
##   - longe da trilha que chega (as paredes se cruzariam);
##   - por cima da encosta que desce: o chão nunca fura o piso, e na ponta
##     fica pelo menos MIN_DROP abaixo dele.
## Sem lugar, não há plataforma (direction() = ZERO): o anel fecha ali e o
## resto do mirante se arruma virado para a praça (Site.view).
##
## As contas são estáticas e puras (os testes conferem sem montar nada).
## Medidas a partir do jogador (cápsula de 0,4 m de raio, olho a 1,7 m).
## O espaço do nó ("frame"): a origem no centro do disco, na altura de cima do
## piso; o -Z aponta para a vista (a plataforma ou a praça); x é o lado.

## Largura do piso da plataforma e quanto ela avança além da beirada do disco (m).
const WIDTH: float = 4.0
const REACH: float = 4.5
## O piso da plataforma começa este tanto para dentro do disco.
const ROOT_INSET: float = 1.0
## O piso fica um pouco acima do disco, para a encosta logo depois da beirada
## (que oscila uns centímetros) não furar as tábuas. A cápsula (raio 0,4 m)
## sobe 6 cm como uma rampa de ~32°, abaixo dos 45° de piso: nem percebe.
const TOP_LIFT: float = 0.06
## A colisão do piso: uma laje desta espessura, com o topo no topo das tábuas.
const THICKNESS: float = 0.3
## O guarda-corpo (e a parede invisível) da plataforma fica este tanto para dentro da borda.
const RAIL_INSET: float = 0.15
const RAIL_HEIGHT: float = 1.0
const RAIL_POST_SPACING: float = 1.2
## Os pés da plataforma: da parte que fica no ar até a encosta, enterrados este tanto.
const LEG_SIZE: float = 0.18
const LEG_SINK: float = 0.3
## Pontos da linha da parede a cada meio metro (como o anel do mirante).
const OUTLINE_STEP: float = 0.5
## A plataforma fica a pelo menos isto além das paredes da trilha.
const TRAIL_CLEARANCE: float = 0.5
## Na ponta, o chão fica pelo menos isto abaixo do piso (m).
const MIN_DROP: float = 1.0
## Fora do disco, o chão fica pelo menos isto abaixo de cima do piso (m).
const FLOOR_GAP: float = 0.0
## O giro procurado, de TURN_STEP em TURN_STEP, até MAX_TURN de cada lado.
const TURN_STEP: float = deg_to_rad(5.0)
const MAX_TURN: float = deg_to_rad(75.0)
## O ponto da vista fica a isto dos guarda-corpos da ponta e do lado da praça.
const VIEW_INSET: float = 0.6
const FOOTSTEP: String = "wood"

# --- 17.8: o deque, os modelos e o lugar de cada coisa ---------------------------

const DECK_MODEL: String = "lookout/deck"
const SHELTER_MODEL: String = "lookout/shelter"
const LANTERN_MODEL: String = "lookout/lantern"
## O deque redondo vai até este raio (o disco plano tem 9 m; até 9,25 m a
## encosta mal começa a mudar) e cobre só o chão que fica até FLOOR_DROP
## abaixo do disco (a trilha, chegando, desce: ali o deque para).
const FLOOR_RADIUS: float = 9.25
const FLOOR_DROP: float = 0.04
## As tábuas do piso (deck.glb): 2,4 m de comprimento, esticadas para estes
## comprimentos; a última de cada fileira fecha a medida que sobrar.
const PLANK_WIDTH: float = 0.2
const PLANK_GAP: float = 0.008
const PLANK_LENGTH: float = 2.4
const PLANK_THICK: float = 0.045
const PLANK_VARIANTS: int = 4
const PLANK_LENGTHS: Array[float] = [1.6, 2.0, 2.4, 2.8]
const PLANK_JOINT: float = 0.006
const MIN_PIECE: float = 0.3
## A camada escura embaixo das tábuas (a fresta entre elas fica escura; de
## longe, quando as tábuas somem, é ela que se vê).
const UNDER_DEPTH: float = 0.03
const UNDER_COLOR: Color = Color(0.13, 0.1, 0.08)
const PLANKS_RANGE: float = 160.0
## O guarda-corpo da borda do disco (os postes a este raio).
const RAIL_RADIUS: float = 9.2
const POST_HEIGHT: float = 1.1
const HANDRAIL_Y: float = 1.02
const LOW_RAIL_Y: float = 0.22
const BRACE_LOW: float = 0.3
const BRACE_HIGH: float = 0.92
## O lugar da torre do bairro (o marco do mirante, BackdropTerrain.tower_spot):
## um quadrado desta meia largura, alinhado com a praça. O deque e as peças
## ficam fora dele (a torre do RPG tem 6 m).
const TOWER_ROOM_HALF: float = 3.2
## O piso entra um pouco embaixo da torre (a borda recortada das tábuas fica
## escondida dentro dela): o buraco do piso tem esta meia largura.
const TOWER_HOLE_HALF: float = 2.85
## A borda redonda do deque: uma fileira de tábuas deitadas em volta, por
## cima das pontas das tábuas do piso (a borda fica lisa, sem degraus).
const RIM_RADIUS: float = 9.13
const RIM_LIFT: float = 0.012
const RIM_PIECE: float = 0.75
## Os caminhos que ficam livres (do centro até onde a trilha chega, até a
## luneta e até a ponta da plataforma), com esta meia largura.
const LANE_HALF: float = 1.1
const TIP_LANE_HALF: float = 1.9
## O abrigo (shelter.glb): o meio dele a um destes raios, de frente para o
## centro. A parede e os pilares ocupam SHELTER_HALF; o telhado, ROOF_HALF.
const SHELTER_RINGS: Array[float] = [6.6, 6.2, 7.0]
const SHELTER_HALF: Vector2 = Vector2(1.75, 1.3)
const ROOF_HALF: Vector2 = Vector2(2.0, 1.65)
## A fogueira fica na frente do abrigo, a esta distância do meio dele, com os
## bancos dos dois lados (a CAMP_BENCH_RADIUS do fogo).
const FIRE_GAP: float = 2.6
const CAMP_RADIUS: float = 1.75
const CAMP_BENCH_RADIUS: float = 1.3
const FIRE_BODY_RADIUS: float = 0.75
## A luneta: na ponta da plataforma (a isto do guarda-corpo da ponta) ou, sem
## plataforma, na borda do disco (a este raio), virada para a praça. Quem olha
## fica STAND_BACK atrás dela.
const TELESCOPE_TIP_INSET: float = 0.95
const TELESCOPE_RING: float = 8.0
const TELESCOPE_CLEAR: float = 1.8
const STAND_BACK: float = 0.85
## Para onde a luneta olha: a praça, na altura do mostrador da torre do relógio.
const TELESCOPE_TARGET: Vector3 = Vector3(0.0, 12.0, 0.0)
## As lanternas: os ganchos do abrigo (no espaço dele, gerar_abrigo.py) e, em
## pé no topo dos postes, dos dois lados de onde a trilha chega.
const LANTERN_HOOKS: Array[Vector3] = [Vector3(-1.6, 1.97, 1.43), Vector3(1.6, 1.97, 1.43)]
const LANTERN_BASE: float = 0.435
const LANTERN_GLASS_Y: float = -0.275
const LANTERN_COLOR: Color = Color(1.0, 0.66, 0.34)
const LANTERN_ENERGY: float = 2.0
const LANTERN_RANGE: float = 7.0
const LANTERN_GLOW: float = 3.5
## A tapeçaria do RPG mais jogado: na vara do abrigo (no espaço dele).
const TAPESTRY_SIZE: Vector2 = Vector2(1.0, 1.5)
const TAPESTRY_TOP: Vector3 = Vector3(0.0, 2.52, -0.94)
const TAPESTRY_COLOR: Color = Color("654836")
const PLAQUE_Y: float = 0.86
const PLAQUE_WIDTH: float = 1.5
const PLAQUE_FONT: int = 64
## As madeiras (a Wood049 tingida): o piso gasto e acinzentado, o abrigo e os
## bancos mais escuros e quentes.
const DECK_WOOD: Color = Color(0.6, 0.55, 0.51)
## O piso ao relento, liso como madeira úmida: pega o brilho das luzes e do céu.
const DECK_ROUGHNESS: float = 0.62
const SHELTER_WOOD: Color = Color(0.53, 0.44, 0.38)
const RAIL_WOOD: Color = Color(0.44, 0.39, 0.36)
const IRON_COLOR: Color = Color(0.06, 0.06, 0.065)
const FADE_BEGIN: float = 60.0
const FADE_LENGTH: float = 20.0

var _direction: Vector2 = Vector2.ZERO
var _layout: Dictionary = {}
var _campfire: Campfire
var _telescope: LookoutTelescope
var _shelter: Node3D
var _lantern_lights: Array[OmniLight3D] = []
var _glass: StandardMaterial3D
var _tapestry: MeshInstance3D
var _tapestry_material: StandardMaterial3D
var _plaque: Label3D
var _highlight_id: int = 0
var _game_art: Node
var _night: float = 0.0
## A montagem em pedaços (build_next): fileiras do piso por chamada.
const ROWS_PER_STEP: int = 30
var _site: Site
var _rows: Array[Dictionary] = []
var _next_row: int = 0
var _step: int = 0
var _floor_merge: TrailProps.Merge
var _under_merge: TrailProps.Merge
var _floor_body: StaticBody3D
var _random: RandomNumberGenerator


## Planeja o mirante (o lugar de cada coisa). Sempre dá true (o deque e o
## resto cabem no disco); a plataforma só entra se couber (get_direction()
## != ZERO). Depois, chamar build_next() até devolver false: cada chamada
## monta um pedaço, para a montagem não travar o quadro (como a montanha).
func setup(field: Heightfield, trail: MountainTrail) -> bool:
	name = "LookoutDeck"
	_site = site(field, trail)
	_direction = _site.along
	transform = _site.frame
	_layout = layout(_site)
	_rows = floor_rows(_site)
	# Os modelos começam a carregar em segundo plano enquanto o piso monta.
	TrailModels.prefetch([DECK_MODEL, SHELTER_MODEL, LANTERN_MODEL, LookoutTelescope.MODEL, "benches", Campfire.MODEL])
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.55, 0.38, 0.2)
	_glass.roughness = 0.2
	_glass.emission_enabled = true
	_glass.emission = LANTERN_COLOR
	return true


## Monta o próximo pedaço. Falso quando acabou.
func build_next() -> bool:
	if _site == null:
		return false
	var field := _site.field
	if _next_row < _rows.size():
		_add_floor_rows(mini(_next_row + ROWS_PER_STEP, _rows.size()))
		return true
	_step += 1
	match _step:
		1:
			_finish_floor(_site)
		2:
			# O guarda-corpo e os pés da plataforma: a mesma madeira, um desenho.
			var rails := TrailProps.Merge.new()
			if _direction != Vector2.ZERO:
				_add_legs(field, field.lookout_radius - ROOT_INSET, field.lookout_radius + REACH, rails)
			_add_railings(field, _site.trail, rails)
			rails.build(self, "Railing0", TrailModels.wood(RAIL_WOOD), PLANKS_RANGE)
		3:
			if _layout["has_camp"]:
				_add_shelter()
		4:
			if _layout["has_camp"]:
				_add_fire()
		_:
			_add_telescope()
			_add_lanterns()
			set_night(_night)
			_site = null
			return false
	return true


## Monta tudo de uma vez (os testes e as ferramentas).
func build_all() -> void:
	while build_next():
		pass


## Para onde a plataforma aponta (no chão, unitário), ou ZERO se não couber.
func get_direction() -> Vector2:
	return _direction


## O lugar de cada coisa (veja layout()).
func get_layout() -> Dictionary:
	return _layout


func get_telescope() -> LookoutTelescope:
	return _telescope


func get_campfire() -> Campfire:
	return _campfire


func get_shelter() -> Node3D:
	return _shelter


func get_lantern_lights() -> Array[OmniLight3D]:
	return _lantern_lights


## O jogo em destaque na tapeçaria (0 = nenhum).
func get_highlight_id() -> int:
	return _highlight_id


func get_plaque_text() -> String:
	return _plaque.text if _plaque != null else ""


## 0 = dia, 1 = noite: as lanternas e a fogueira acendem aos poucos (a regra dos lampiões).
func set_night(night: float) -> void:
	_night = night
	var on := smoothstep(0.3, 0.8, night)
	for light in _lantern_lights:
		light.light_energy = LANTERN_ENERGY * on
		light.visible = on > 0.01
	if _glass != null:
		_glass.emission_energy_multiplier = LANTERN_GLOW * on
	if _campfire != null:
		_campfire.set_night(night)
	if _plaque != null:
		var glow := lerpf(0.85, 1.25, on)
		_plaque.modulate = Color(LANTERN_COLOR.r * glow, LANTERN_COLOR.g * glow, LANTERN_COLOR.b * glow)


## O RPG mais jogado (o dicionário do TrailDressing: app_id, name, minutes)
## na tapeçaria do abrigo, com o nome e as horas embaixo. Vazio = sem
## destaque (o abrigo fica só com a parede).
func set_highlight(game: Dictionary) -> void:
	var id := int(game.get("app_id", 0))
	if id == _highlight_id:
		return
	_highlight_id = id
	if _tapestry != null:
		_tapestry.queue_free()
		_tapestry = null
	if _plaque != null:
		_plaque.queue_free()
		_plaque = null
	if id <= 0 or _shelter == null:
		return
	_tapestry_material = StandardMaterial3D.new()
	_tapestry_material.albedo_color = TAPESTRY_COLOR
	_tapestry_material.roughness = 0.95
	_tapestry_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_tapestry = MeshInstance3D.new()
	_tapestry.name = "Tapestry"
	_tapestry.mesh = _tapestry_mesh()
	_tapestry.material_override = _tapestry_material
	_tapestry.position = TAPESTRY_TOP
	_tapestry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	_shelter.add_child(_tapestry)
	_plaque = Label3D.new()
	_plaque.name = "Plaque"
	_plaque.text = plaque_text(game)
	_plaque.font = HubFonts.SIGN
	_plaque.font_size = PLAQUE_FONT
	_plaque.outline_size = 0
	_plaque.double_sided = false
	_plaque.position = Vector3(0.0, PLAQUE_Y, TAPESTRY_TOP.z - 0.12)
	var pixel_size := 0.085 / PLAQUE_FONT
	var text_width := HubFonts.SIGN.get_string_size(_plaque.text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLAQUE_FONT).x * pixel_size
	if text_width > PLAQUE_WIDTH:
		pixel_size *= PLAQUE_WIDTH / text_width
	_plaque.pixel_size = pixel_size
	_shelter.add_child(_plaque)
	set_night(_night)
	if _game_art == null and is_inside_tree():
		_game_art = get_tree().root.get_node_or_null("GameArt")
	if _game_art != null:
		if not _game_art.art_ready.is_connected(_on_art_ready):
			_game_art.art_ready.connect(_on_art_ready)
		_on_art_ready(id, _game_art.get_art(id))


## O texto embaixo da tapeçaria: o nome e as horas (sem horas conhecidas, só o nome).
static func plaque_text(game: Dictionary) -> String:
	var text := String(game.get("name", ""))
	var minutes := int(game.get("minutes", -1))
	if minutes >= 60:
		text += "  ·  %d h" % roundi(minutes / 60.0)
	return text


func _on_art_ready(id: int, texture: Texture2D) -> void:
	if id != _highlight_id or texture == null or _tapestry_material == null:
		return
	_tapestry_material.albedo_texture = texture
	_tapestry_material.albedo_color = Color.WHITE


func _exit_tree() -> void:
	if is_instance_valid(_game_art) and _game_art.art_ready.is_connected(_on_art_ready):
		_game_art.art_ready.disconnect(_on_art_ready)


# --- As contas (estáticas e puras) ---------------------------------------------

## A direção da plataforma: a da praça (o centro da cidade), girada o mínimo
## para ficar longe da trilha e por cima da encosta. ZERO se nenhuma servir.
static func direction(field: Heightfield, trail: MountainTrail) -> Vector2:
	var toward := -trail.lookout_center.normalized()
	var steps := roundi(MAX_TURN / TURN_STEP)
	for k in steps + 1:
		for side: float in [1.0, -1.0]:
			if k == 0 and side < 0.0:
				continue
			var candidate := toward.rotated(side * k * TURN_STEP)
			if _clear_of_trail(field, trail, candidate) and _over_slope(field, trail, candidate):
				return candidate
	return Vector2.ZERO


## O piso inteiro (com folga) fica longe das paredes da trilha?
static func _clear_of_trail(field: Heightfield, trail: MountainTrail, along_dir: Vector2) -> bool:
	var side_dir := Vector2(-along_dir.y, along_dir.x)
	var limit := TrailDressing.WALL_OFFSET + TRAIL_CLEARANCE
	var along := field.lookout_radius - ROOT_INSET
	while along <= field.lookout_radius + REACH + 0.001:
		var lateral := -WIDTH / 2.0
		while lateral <= WIDTH / 2.0 + 0.001:
			var p := trail.lookout_center + along_dir * along + side_dir * lateral
			if trail.closest(p).x < limit:
				return false
			lateral += 0.5
		along += 0.5
	return true


## A encosta desce embaixo do piso? Fora do disco, o chão fica abaixo do
## piso em toda a largura, e na ponta, pelo menos MIN_DROP abaixo.
static func _over_slope(field: Heightfield, trail: MountainTrail, along_dir: Vector2) -> bool:
	var side_dir := Vector2(-along_dir.y, along_dir.x)
	var top := deck_top(field)
	var along := field.lookout_radius
	while along <= field.lookout_radius + REACH + 0.001:
		for lateral: float in [-WIDTH / 2.0, 0.0, WIDTH / 2.0]:
			var p := trail.lookout_center + along_dir * along + side_dir * lateral
			if field.surface_at(p) > top - FLOOR_GAP:
				return false
		along += 0.5
	var tip := trail.lookout_center + along_dir * (field.lookout_radius + REACH)
	return field.surface_at(tip) <= top - MIN_DROP


## A altura de cima do piso (y do mundo).
static func deck_top(field: Heightfield) -> float:
	return field.lookout_height + TOP_LIFT


## Metade da abertura do anel (e da distância entre os guarda-corpos dos lados).
static func opening_half() -> float:
	return WIDTH / 2.0 - RAIL_INSET


## Um ponto (no chão) do anel do mirante fica na abertura da plataforma?
static func is_in_opening(trail: MountainTrail, along_dir: Vector2, p: Vector2) -> bool:
	if along_dir == Vector2.ZERO:
		return false
	var local := p - trail.lookout_center
	return local.dot(along_dir) > 0.0 and absf(local.dot(Vector2(-along_dir.y, along_dir.x))) < opening_half()


## A linha da parede invisível em volta da plataforma (x e z do mundo; y, a
## altura do piso): do anel, por um lado até a ponta, a ponta, e o outro lado
## de volta ao anel. Vazia se não houver plataforma.
static func outline(field: Heightfield, trail: MountainTrail, along_dir: Vector2) -> PackedVector3Array:
	var line := PackedVector3Array()
	if along_dir == Vector2.ZERO:
		return line
	var side_dir := Vector2(-along_dir.y, along_dir.x)
	var y := deck_top(field)
	var corners := _outline_corners(field)
	for i in corners.size():
		var a := corners[i]
		line.append(_to_world(trail, along_dir, side_dir, a, y))
		if i == corners.size() - 1:
			break
		var b := corners[i + 1]
		var pieces := ceili(a.distance_to(b) / OUTLINE_STEP)
		for k in range(1, pieces):
			line.append(_to_world(trail, along_dir, side_dir, a.lerp(b, float(k) / pieces), y))
	return line


## Os cantos do guarda-corpo da plataforma (x = ao longo, y = de lado).
static func _outline_corners(field: Heightfield) -> Array[Vector2]:
	var s := opening_half()
	var ring := field.lookout_radius + TrailDressing.RING_GAP
	var root := sqrt(ring * ring - s * s)  # onde o lado encontra o anel
	var tip := field.lookout_radius + REACH - RAIL_INSET
	return [Vector2(root, -s), Vector2(tip, -s), Vector2(tip, s), Vector2(root, s)]


## O ponto do piso de onde se olha a vista (no mundo): o canto da ponta do
## lado da praça, a VIEW_INSET dos dois guarda-corpos (onde uma pessoa se
## debruça; o guarda-corpo fica abaixo do quadro). Sem plataforma, o centro
## do disco.
static func view_spot(field: Heightfield, trail: MountainTrail, along_dir: Vector2) -> Vector3:
	if along_dir == Vector2.ZERO:
		return Vector3(trail.lookout_center.x, field.lookout_height, trail.lookout_center.y)
	var side_dir := Vector2(-along_dir.y, along_dir.x)
	var plaza_side := signf(side_dir.dot(-trail.lookout_center))
	var tip := field.lookout_radius + REACH - RAIL_INSET - VIEW_INSET
	var p := trail.lookout_center + along_dir * tip + side_dir * plaza_side * (opening_half() - VIEW_INSET)
	return Vector3(p.x, deck_top(field), p.y)


static func _to_world(trail: MountainTrail, along_dir: Vector2, side_dir: Vector2, local: Vector2, y: float) -> Vector3:
	var p := trail.lookout_center + along_dir * local.x + side_dir * local.y
	return Vector3(p.x, y, p.y)


## Tudo o que as contas do mirante precisam, calculado uma vez (a busca da
## plataforma e os contornos custam): a plataforma, a vista, o espaço do nó,
## o contorno do deque e os buracos dele (a torre e a chegada da trilha).
class Site:
	var field: Heightfield
	var trail: MountainTrail
	## A direção da plataforma (ZERO sem ela) e a da vista.
	var along: Vector2
	var view: Vector2
	var frame: Transform3D
	var inverse: Transform3D
	## No espaço do nó (x = de lado, y = o z do nó).
	var outline: PackedVector2Array
	var holes: Array[PackedVector2Array] = []
	## O lugar da torre com folga, para as peças.
	var room: PackedVector2Array

	## Um ponto do chão (x e z do mundo) no espaço do nó.
	func local(p: Vector2) -> Vector2:
		var v := inverse * Vector3(p.x, frame.origin.y, p.y)
		return Vector2(v.x, v.z)

	## O deque cobre este ponto do chão (x e z do mundo)?
	func covers(p: Vector2) -> bool:
		var l := local(p)
		for run in LookoutDeck._covered(outline, holes, l.y):
			if l.x >= run.x and l.x <= run.y:
				return true
		return false


static func site(field: Heightfield, trail: MountainTrail) -> Site:
	var result := Site.new()
	result.field = field
	result.trail = trail
	result.along = direction(field, trail)
	result.view = result.along if result.along != Vector2.ZERO else -trail.lookout_center.normalized()
	var center := trail.lookout_center
	result.frame = Transform3D(Basis.looking_at(Vector3(result.view.x, 0.0, result.view.y)),
			Vector3(center.x, deck_top(field), center.y))
	result.inverse = result.frame.affine_inverse()
	result.outline = _floor_outline(result)
	result.holes.append(_tower_room(result, TOWER_HOLE_HALF - TOWER_ROOM_HALF))
	result.holes.append_array(_arrival_cut(result))
	result.room = _tower_room(result, 0.3)
	return result


## O lugar da torre (no espaço do nó): o quadrado alinhado com a praça, atrás
## do meio do disco (BackdropTerrain.tower_spot), com "margin" de folga.
static func _tower_room(where: Site, margin: float) -> PackedVector2Array:
	var center := where.trail.lookout_center
	var away := center.normalized()
	var spot := center + away * where.field.lookout_radius * BackdropTerrain.TOWER_BACK_SHARE
	var across := Vector2(-away.y, away.x)
	var half := TOWER_ROOM_HALF + margin
	var room := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		room.append(where.local(spot + away * corner.x * half + across * corner.y * half))
	return room


## O contorno do deque (no espaço do nó): o círculo e, se houver, a plataforma.
static func _floor_outline(where: Site) -> PackedVector2Array:
	var circle := PackedVector2Array()
	for k in 96:
		var angle := TAU * k / 96.0
		circle.append(Vector2(cos(angle), sin(angle)) * FLOOR_RADIUS)
	if where.along == Vector2.ZERO:
		return circle
	var half := WIDTH / 2.0
	var near := where.field.lookout_radius - ROOT_INSET
	var far := where.field.lookout_radius + REACH
	var platform := PackedVector2Array([Vector2(-half, -near), Vector2(half, -near),
			Vector2(half, -far), Vector2(-half, -far)])
	var merged := Geometry2D.merge_polygons(circle, platform)
	for polygon in merged:
		if not Geometry2D.is_polygon_clockwise(polygon):
			return polygon
	return merged[0]


## Onde a trilha chega (no espaço do nó): a faixa em volta dos pontos da trilha
## que ficam mais baixos que o deque. Ali o deque para, para não virar degrau.
static func _arrival_cut(where: Site) -> Array[PackedVector2Array]:
	var low := PackedVector2Array()
	var trail := where.trail
	var limit := where.field.lookout_height - FLOOR_DROP
	for i in trail.points.size():
		var p := trail.points[i]
		if p.distance_to(trail.lookout_center) < FLOOR_RADIUS + 3.0 and trail.heights[i] < limit:
			low.append(where.local(p))
	var result: Array[PackedVector2Array] = []
	if low.size() == 1:
		low.append(low[0] + Vector2(0.01, 0.0))
	if low.size() >= 2:
		for polygon in Geometry2D.offset_polyline(low, where.field.trail_width / 2.0 + 0.1):
			result.append(polygon)
	return result


## As fileiras de tábuas: cada uma tem "z" (o meio dela, no espaço do nó) e
## "runs" (os trechos de x em que ela é piso: o contorno menos a torre e a
## chegada da trilha, nas duas beiradas da tábua).
static func floor_rows(where: Site) -> Array[Dictionary]:
	var z_min := INF
	var z_max := -INF
	for p in where.outline:
		z_min = minf(z_min, p.y)
		z_max = maxf(z_max, p.y)
	var rows: Array[Dictionary] = []
	var pitch := PLANK_WIDTH + PLANK_GAP
	var z := z_min + 0.01
	while z + PLANK_WIDTH <= z_max - 0.01:
		var runs := _covered(where.outline, where.holes, z + 0.002)
		runs = _intersect(runs, _covered(where.outline, where.holes, z + PLANK_WIDTH - 0.002))
		var kept: Array[Vector2] = []
		for run in runs:
			if run.y - run.x >= MIN_PIECE:
				kept.append(run)
		if not kept.is_empty():
			rows.append({"z": z + PLANK_WIDTH / 2.0, "runs": kept})
		z += pitch
	return rows


static func _covered(outline_local: PackedVector2Array, holes: Array[PackedVector2Array], z: float) -> Array[Vector2]:
	var runs := _line_intervals(outline_local, z)
	for hole in holes:
		runs = _subtract(runs, _line_intervals(hole, z))
	return runs


## Os trechos de x em que a linha "y = z" fica dentro do polígono (par-ímpar).
static func _line_intervals(polygon: PackedVector2Array, z: float) -> Array[Vector2]:
	var xs: Array[float] = []
	var count := polygon.size()
	for i in count:
		var a := polygon[i]
		var b := polygon[(i + 1) % count]
		if (a.y <= z) != (b.y <= z):
			xs.append(a.x + (z - a.y) / (b.y - a.y) * (b.x - a.x))
	xs.sort()
	var result: Array[Vector2] = []
	for k in range(0, xs.size() - 1, 2):
		result.append(Vector2(xs[k], xs[k + 1]))
	return result


static func _intersect(a: Array[Vector2], b: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for p in a:
		for q in b:
			var from := maxf(p.x, q.x)
			var to := minf(p.y, q.y)
			if to > from:
				result.append(Vector2(from, to))
	result.sort_custom(func(m: Vector2, n: Vector2) -> bool: return m.x < n.x)
	return result


static func _subtract(a: Array[Vector2], b: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = a.duplicate()
	for cut in b:
		var next: Array[Vector2] = []
		for run: Vector2 in result:
			if cut.y <= run.x or cut.x >= run.y:
				next.append(run)
				continue
			if cut.x > run.x:
				next.append(Vector2(run.x, cut.x))
			if cut.y < run.y:
				next.append(Vector2(cut.y, run.y))
		result = next
	return result


## Os postes do guarda-corpo da borda do disco (no mundo, na altura do piso):
## um trecho para cada arco do anel das paredes (TrailDressing.wall_lines), a
## RAIL_RADIUS, um poste a cada até RAIL_POST_SPACING.
static func ring_rails(field: Heightfield, trail: MountainTrail) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	var center := trail.lookout_center
	var y := deck_top(field)
	for line in TrailDressing.wall_lines(field, trail):
		if not TrailDressing.is_ring_line(field, trail, line):
			continue
		# O ângulo de cada ponto do arco, sem o salto de -PI a PI.
		var angles: Array[float] = []
		for p in line:
			var angle := Heightfield.angle_of(Vector2(p.x, p.z) - center)
			if not angles.is_empty():
				angle = angles[-1] + wrapf(angle - angles[-1], -PI, PI)
			angles.append(angle)
		var span := angles[-1] - angles[0]
		var pieces := maxi(1, ceili(absf(span) * RAIL_RADIUS / RAIL_POST_SPACING))
		var posts := PackedVector3Array()
		for k in pieces + 1:
			var p := center + Heightfield.direction_of(angles[0] + span * k / pieces) * RAIL_RADIUS
			posts.append(Vector3(p.x, y, p.y))
		result.append(posts)
	return result


## Os postes do guarda-corpo da plataforma (no mundo): os três lados de fora,
## na linha da parede invisível (outline). Vazio sem plataforma.
static func platform_rail(field: Heightfield, trail: MountainTrail, along_dir: Vector2) -> PackedVector3Array:
	var posts := PackedVector3Array()
	if along_dir == Vector2.ZERO:
		return posts
	var side_dir := Vector2(-along_dir.y, along_dir.x)
	var y := deck_top(field)
	var corners := _outline_corners(field)
	for i in 3:
		var a := corners[i]
		var b := corners[i + 1]
		var pieces := maxi(1, ceili(a.distance_to(b) / RAIL_POST_SPACING))
		for k in pieces + 1:
			if i > 0 and k == 0:
				continue  # o canto já tem poste
			posts.append(_to_world(trail, along_dir, side_dir, a.lerp(b, float(k) / pieces), y))
	return posts


## O lugar de cada coisa no mirante (no mundo):
##   "telescope" (Transform3D: o -Z para a praça), "stand" (onde quem olha
##   fica), "has_camp", "shelter" (Transform3D: a frente, +Z, para o centro),
##   "fire" (Vector3, o chão da fogueira), "benches" (Array de Transform3D: o
##   assento, +Z, para o fogo), "lanes" (os caminhos livres: de 2 em 2, os
##   pontos das pontas em Vector3(x, z, meia largura)) e "lanterns" (os topos
##   dos postes onde ficam as lanternas em pé).
static func layout(where: Site) -> Dictionary:
	var field := where.field
	var trail := where.trail
	var center := trail.lookout_center
	var y := deck_top(field)
	var entry := trail.points[trail.points.size() - 1]
	var lanes: Array[Vector3] = [Vector3(center.x, center.y, LANE_HALF), Vector3(entry.x, entry.y, LANE_HALF)]
	var result := {"has_camp": false}

	# A luneta.
	var spot := Vector2.INF
	if where.along != Vector2.ZERO:
		spot = center + where.along * (field.lookout_radius + REACH - RAIL_INSET - TELESCOPE_TIP_INSET)
		var tip := center + where.along * (field.lookout_radius + REACH - RAIL_INSET)
		lanes.append_array([Vector3(center.x, center.y, TIP_LANE_HALF), Vector3(tip.x, tip.y, TIP_LANE_HALF)])
	else:
		# Na borda do disco, o mais de frente para a praça possível, com piso
		# em volta dela e onde quem olha fica (a chegada da trilha corta o piso).
		for ring: float in [TELESCOPE_RING, TELESCOPE_RING - 0.8, TELESCOPE_RING - 1.6]:
			for k in 21:
				var turn := deg_to_rad(8.0) * ceili(k / 2.0) * (1.0 if k % 2 == 1 else -1.0)
				var candidate := center + where.view.rotated(turn) * ring
				if _segment_distance(candidate, center, entry) >= TELESCOPE_CLEAR 						and _telescope_fits(where, candidate):
					spot = candidate
					break
			if spot != Vector2.INF:
				break
		if spot == Vector2.INF:
			spot = center + where.view * TELESCOPE_RING
	var aim := (Vector2(TELESCOPE_TARGET.x, TELESCOPE_TARGET.z) - spot).normalized()
	result["telescope"] = Transform3D(Basis.looking_at(Vector3(aim.x, 0.0, aim.y)), Vector3(spot.x, y, spot.y))
	var stand := spot - aim * STAND_BACK
	result["stand"] = stand
	lanes.append_array([Vector3(center.x, center.y, LANE_HALF), Vector3(stand.x, stand.y, LANE_HALF)])
	result["lanes"] = lanes

	# O abrigo e a fogueira: o lugar mais longe de onde a trilha chega, de
	# preferência de lado (a frente fica para a vista), que caiba no deque
	# fora da torre e dos caminhos.
	var entry_angle := Heightfield.angle_of(entry - center)
	var view_angle := Heightfield.angle_of(where.view)
	# Os lugares, do melhor para o pior: o primeiro que couber é o escolhido.
	var candidates: Array[Vector3] = []  # (ângulo, raio, nota)
	for ring_index in SHELTER_RINGS.size():
		for k in 72:
			var angle := TAU * k / 72.0
			var score := absf(wrapf(angle - entry_angle, -PI, PI)) + 0.6 * absf(sin(angle - view_angle)) \
					- 0.3 * ring_index
			candidates.append(Vector3(angle, SHELTER_RINGS[ring_index], score))
	candidates.sort_custom(func(m: Vector3, n: Vector3) -> bool: return m.z > n.z)
	for candidate in candidates:
		var outward := Heightfield.direction_of(candidate.x)
		var shelter := center + outward * candidate.y
		var fire := shelter - outward * FIRE_GAP
		if _camp_fits(where, shelter, -outward, fire, lanes):
			var front := -outward  # a frente do abrigo olha para o centro
			result["has_camp"] = true
			result["shelter"] = Transform3D(Basis.looking_at(Vector3(-front.x, 0.0, -front.y)),
					Vector3(shelter.x, y, shelter.y))
			result["fire"] = Vector3(fire.x, y, fire.y)
			var benches: Array[Transform3D] = []
			var across := Vector2(-front.y, front.x)
			for side: float in [-1.0, 1.0]:
				var away := across * side
				var place := fire + away * CAMP_BENCH_RADIUS
				benches.append(Transform3D(Basis.looking_at(Vector3(away.x, 0.0, away.y)), Vector3(place.x, y, place.y)))
			result["benches"] = benches
			break

	# As lanternas em pé: nos postes do guarda-corpo mais perto de onde a trilha
	# chega e no poste mais perto da luneta (ela fica longe do fogo).
	var ends: Array[Vector3] = []
	var posts: Array[Vector3] = []
	var rails := ring_rails(field, trail)
	for line in rails:
		ends.append(line[0])
		ends.append(line[line.size() - 1])
		posts.append_array(Array(line))
	posts.append_array(Array(platform_rail(field, trail, where.along)))
	ends.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x, a.z).distance_to(entry) < Vector2(b.x, b.z).distance_to(entry))
	var lanterns: Array[Vector3] = []
	for k in mini(2, ends.size()):
		lanterns.append(ends[k] + Vector3.UP * (POST_HEIGHT + 0.03 + LANTERN_BASE))
	var nearest := Vector3.INF
	for post in posts:
		var distance := Vector2(post.x, post.z).distance_to(spot)
		if distance > 0.9 and (nearest == Vector3.INF or distance < Vector2(nearest.x, nearest.z).distance_to(spot)) 				and not lanterns.has(post + Vector3.UP * (POST_HEIGHT + 0.03 + LANTERN_BASE)):
			nearest = post
	if nearest != Vector3.INF:
		lanterns.append(nearest + Vector3.UP * (POST_HEIGHT + 0.03 + LANTERN_BASE))
	result["lanterns"] = lanterns
	return result


## A luneta cabe aqui? Piso em volta dela (0,5 m) e onde quem olha fica.
static func _telescope_fits(where: Site, spot: Vector2) -> bool:
	var aim := (Vector2(TELESCOPE_TARGET.x, TELESCOPE_TARGET.z) - spot).normalized()
	if not where.covers(spot - aim * STAND_BACK):
		return false
	for k in 8:
		if not where.covers(spot + Heightfield.direction_of(TAU * k / 8.0) * 0.5):
			return false
	return not Geometry2D.is_point_in_polygon(where.local(spot), where.room)


## O abrigo (de frente para "front") e a fogueira cabem aqui? Dentro do
## deque, fora da torre, longe dos caminhos; o telhado, dentro do guarda-corpo.
static func _camp_fits(where: Site, shelter: Vector2, front: Vector2, fire: Vector2, lanes: Array[Vector3]) -> bool:
	var center := where.trail.lookout_center
	var across := Vector2(-front.y, front.x)
	var checks: Array[Array] = []  # [ponto, é o telhado?]
	for i in 5:
		for j in 5:
			var u := -1.0 + i * 0.5
			var v := -1.0 + j * 0.5
			checks.append([shelter + across * u * ROOF_HALF.x + front * v * ROOF_HALF.y, true])
			checks.append([shelter + across * u * SHELTER_HALF.x + front * v * SHELTER_HALF.y, false])
	for k in 12:
		checks.append([fire + Heightfield.direction_of(TAU * k / 12.0) * CAMP_RADIUS, false])
	checks.append([fire, false])
	for check in checks:
		var p: Vector2 = check[0]
		if Geometry2D.is_point_in_polygon(where.local(p), where.room):
			return false
		if check[1]:
			if p.distance_to(center) > RAIL_RADIUS - 0.15:
				return false
			continue
		if p.distance_to(center) > FLOOR_RADIUS - 0.2 or not where.covers(p):
			return false
		for i in range(0, lanes.size(), 2):
			var a := Vector2(lanes[i].x, lanes[i].y)
			var b := Vector2(lanes[i + 1].x, lanes[i + 1].y)
			if _segment_distance(p, a, b) < lanes[i].z:
				return false
	return true


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Peças (no espaço do nó: -Z para a vista, origem no centro do disco) ---------

## O piso: as tábuas atravessadas (uma malha, um desenho), a camada escura
## embaixo e a colisão (uma laje por trecho de fileira, footstep "wood").
## As fileiras entram aos poucos (ROWS_PER_STEP por chamada). As peças vão
## direto para arrays (TrailProps.Merge), cada tábua com o seu pedaço de
## veio e o seu tom.
func _add_floor_rows(until: int) -> void:
	if _floor_merge == null:
		_floor_merge = TrailProps.Merge.new()
		_under_merge = TrailProps.Merge.new()
		_random = RandomNumberGenerator.new()
		_random.seed = 1708
		_floor_body = StaticBody3D.new()
		_floor_body.name = "Deck"
		_floor_body.set_meta("footstep", FOOTSTEP)
	var box := _unit_box()
	while _next_row < until:
		var row: Dictionary = _rows[_next_row]
		_next_row += 1
		var z: float = row["z"]
		for run: Vector2 in row["runs"]:
			var x := run.x
			# A primeira tábua de cada fileira começa num comprimento diferente
			# (as emendas não se alinham de uma fileira para a outra).
			var first := true
			while x < run.y - 0.001:
				var left := run.y - x
				var length: float = PLANK_LENGTHS[_random.randi() % PLANK_LENGTHS.size()]
				if first:
					length *= _random.randf_range(0.35, 1.0)
					first = false
				if left - length < MIN_PIECE:
					length = left
				length = maxf(length, minf(left, MIN_PIECE))
				var variant := _random.randi() % PLANK_VARIANTS
				_floor_merge.add(TrailModels.arrays(DECK_MODEL, "plank_%d" % variant),
						Transform3D(Basis.IDENTITY, Vector3(x + length / 2.0, 0.0, z)),
						Vector3((length - PLANK_JOINT) / PLANK_LENGTH, 1.0, 1.0),
						Vector2(_random.randf_range(0.0, 3.0), _random.randf_range(-0.3, 0.3)),
						_random.randf_range(0.8, 1.08))
				x += length
			var span := run.y - run.x
			_under_merge.add(box, Transform3D(Basis.IDENTITY, Vector3((run.x + run.y) / 2.0,
					-PLANK_THICK - UNDER_DEPTH / 2.0 + 0.004, z)), Vector3(span, UNDER_DEPTH, PLANK_WIDTH + PLANK_GAP))
			var shape := BoxShape3D.new()
			shape.size = Vector3(span, THICKNESS, PLANK_WIDTH + PLANK_GAP)
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = Vector3((run.x + run.y) / 2.0, -THICKNESS / 2.0, z)
			_floor_body.add_child(collision)


## Fecha o piso: a borda e as malhas (as tábuas só recebem sombra).
func _finish_floor(where: Site) -> void:
	if _floor_merge == null:
		return
	_add_rim(where, _floor_merge)
	var planks := _floor_merge.build(self, "Planks0", TrailModels.wood(DECK_WOOD, DECK_ROUGHNESS), PLANKS_RANGE)
	if planks != null:
		planks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var under := _under_merge.build(self, "Under0", _under_material(), 0.0)
	if under != null:
		under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor_body)
	_floor_merge = null
	_under_merge = null


static var _under: StandardMaterial3D
static var _box: Array = []

static func _under_material() -> StandardMaterial3D:
	if _under == null:
		_under = StandardMaterial3D.new()
		_under.albedo_color = UNDER_COLOR
		_under.roughness = 1.0
	return _under


## Os arrays de uma caixa de 1 m (a camada de baixo, esticada por trecho).
static func _unit_box() -> Array:
	if _box.is_empty():
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_box = mesh.surface_get_arrays(0)
	return _box


## A borda redonda: tábuas curtas deitadas em volta, a RIM_RADIUS, só onde
## há piso embaixo (não na chegada da trilha nem na raiz da plataforma). E,
## onde a trilha chega, tábuas ao longo do corte, um pouco para dentro do
## piso, cobrindo as pontas das tábuas (a beira também fica lisa).
func _add_rim(where: Site, planks: TrailProps.Merge) -> void:
	var count := ceili(TAU * RIM_RADIUS / RIM_PIECE)
	var chord := 2.0 * RIM_RADIUS * sin(PI / count)
	var rim := TrailModels.arrays(DECK_MODEL, "plank_1")
	var center := where.trail.lookout_center
	for k in count:
		var angle := TAU * (k + 0.5) / count
		var p := center + Heightfield.direction_of(angle) * RIM_RADIUS
		var inner := center + Heightfield.direction_of(angle) * (RIM_RADIUS - 0.25)
		var local := where.local(p)
		if not where.covers(inner) or where.along != Vector2.ZERO and local.y < 0.0 \
				and absf(local.x) < WIDTH / 2.0 + 0.3:
			continue
		var tangent := Vector2(-local.y, local.x).normalized()
		var along := Vector3(tangent.x, 0.0, tangent.y)
		planks.add(rim, Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), Vector3(local.x, RIM_LIFT, local.y)),
				Vector3((chord - PLANK_JOINT) / PLANK_LENGTH, 1.0, 1.0), Vector2(fposmod(k * 0.53, 3.0), 0.1), 0.92)
	var board := TrailModels.arrays(DECK_MODEL, "plank_2")
	for hole_index in range(1, where.holes.size()):
		var hole := where.holes[hole_index]
		for i in hole.size():
			var a := hole[i]
			var b := hole[(i + 1) % hole.size()]
			var middle := (a + b) / 2.0
			var length := a.distance_to(b)
			if length < 0.05 or middle.length() > RIM_RADIUS - 0.1:
				continue
			var edge := (b - a) / length
			var inward := Vector2(-edge.y, edge.x)
			if Geometry2D.is_point_in_polygon(middle + inward * 0.05, hole):
				inward = -inward
			var spot := middle + inward * (PLANK_WIDTH / 2.0 - 0.02)
			var world := where.frame * Vector3(spot.x, 0.0, spot.y)
			if not where.covers(Vector2(world.x, world.z)):
				continue
			var along := Vector3(edge.x, 0.0, edge.y)
			planks.add(board, Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), Vector3(spot.x, RIM_LIFT, spot.y)),
					Vector3((length + 0.04) / PLANK_LENGTH, 1.0, 1.0), Vector2(fposmod(i * 0.37, 2.0), 0.0), 0.9)


## Os pés e as vigas da plataforma: os pés nos cantos e no meio dos lados
## da parte que fica no ar, da viga até a encosta; três vigas ao comprido
## embaixo das tábuas e uma atravessada na ponta.
func _add_legs(field: Heightfield, near: float, far: float, merge: TrailProps.Merge) -> void:
	var beam := TrailModels.arrays(DECK_MODEL, "beam")
	var bottom := -PLANK_THICK - LEG_SIZE
	var joist_y := -PLANK_THICK - LEG_SIZE / 2.0
	var length := far - near - 0.1
	for x: float in [-(WIDTH / 2.0 - LEG_SIZE), 0.0, WIDTH / 2.0 - LEG_SIZE]:
		# A viga deitada: o y do modelo (o veio) vira o -Z.
		merge.add(beam, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(x, joist_y, -near - 0.05)),
				Vector3(1.0, length, 1.0))
	merge.add(beam, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(WIDTH / 2.0 - 0.05, joist_y, -far + LEG_SIZE / 2.0)),
			Vector3(1.0, WIDTH - 0.1, 1.0))
	var edge := field.lookout_radius + 1.0
	for along: float in [edge, (edge + far) / 2.0, far - LEG_SIZE]:
		if along < near:
			continue
		for side: float in [-1.0, 1.0]:
			var local := Vector3(side * (WIDTH / 2.0 - LEG_SIZE), 0.0, -along)
			var world := transform * local  # a montanha fica na origem da cidade
			var ground := field.surface_at(Vector2(world.x, world.z)) - position.y
			if ground >= bottom - 0.05:
				continue
			var height := bottom - ground + LEG_SINK
			merge.add(beam, Transform3D(Basis.IDENTITY, Vector3(local.x, bottom - height, local.z)), Vector3(1.0, height, 1.0))


## O guarda-corpo: os arcos da borda do disco e os três lados da plataforma.
## Em cada vão, o corrimão, a régua de baixo e um X; os postes que ficam
## sobre o chão mais baixo que o piso ganham um pé (a viga) até o chão.
func _add_railings(field: Heightfield, trail: MountainTrail, merge: TrailProps.Merge) -> void:
	var lines := ring_rails(field, trail)
	var platform := platform_rail(field, trail, _direction)
	if platform.size() >= 2:
		lines.append(platform)
	var post := TrailModels.arrays(DECK_MODEL, "post")
	var beam := TrailModels.arrays(DECK_MODEL, "beam")
	var handrail := TrailModels.arrays(DECK_MODEL, "handrail")
	var board := TrailModels.arrays(DECK_MODEL, "board")
	var inverse := transform.affine_inverse()
	for line in lines:
		for i in line.size():
			var here := inverse * line[i]
			var ground := field.surface_at(Vector2(line[i].x, line[i].z)) - position.y
			# O poste acompanha o guarda-corpo (alinhado com o vão de antes ou o de depois).
			var neighbor := inverse * line[i - 1 if i > 0 else mini(1, line.size() - 1)]
			var yaw := atan2(-(here - neighbor).z, (here - neighbor).x) if neighbor != here else 0.0
			merge.add(post, Transform3D(Basis(Vector3.UP, yaw), here))
			if ground < -0.08:
				var height := -ground + LEG_SINK
				merge.add(beam, Transform3D(Basis.IDENTITY, Vector3(here.x, -height, here.z)), Vector3(0.7, height, 0.7))
			if i == 0:
				continue
			var before := inverse * line[i - 1]
			var span := here - before
			var bay := span.length()
			var along := span / bay
			var normal := along.cross(Vector3.UP).normalized()
			var flat := Basis(along, Vector3.UP, along.cross(Vector3.UP))
			var middle := (here + before) / 2.0
			var shift := Vector2(fposmod(bay * 7.3 + i, 3.0), 0.0)
			merge.add(handrail, Transform3D(flat, middle + Vector3.UP * HANDRAIL_Y), Vector3(bay + 0.1, 1.0, 1.0), shift)
			merge.add(board, Transform3D(flat, middle + Vector3.UP * LOW_RAIL_Y), Vector3(bay - 0.1, 1.0, 1.0), shift)
			# O X: duas réguas na diagonal, uma de cada lado do meio.
			for k in 2:
				var low := before if k == 0 else here
				var high := here if k == 0 else before
				var a := low + (high - low).normalized() * 0.07 + Vector3.UP * BRACE_LOW
				var b := high - (high - low).normalized() * 0.07 + Vector3.UP * BRACE_HIGH
				var direction := (b - a).normalized()
				# A régua de pé no plano do guarda-corpo: a largura nele, a espessura para fora.
				var brace := Basis(direction, normal, direction.cross(normal))
				var offset := normal * (0.018 if k == 0 else -0.018)
				merge.add(board, Transform3D(brace, (a + b) / 2.0 + offset), Vector3(a.distance_to(b), 1.0, 1.0),
						shift + Vector2(0.7 * k, 0.0))


## O abrigo e os bancos da fogueira (com colisão: os pilares, as paredes, o
## banco de dentro e os bancos de fora). O abrigo usa as malhas do modelo como
## vieram (uma por material); os bancos vão juntos numa só.
func _add_shelter() -> void:
	var inverse := transform.affine_inverse()
	_shelter = Node3D.new()
	_shelter.name = "Shelter"
	_shelter.transform = inverse * (_layout["shelter"] as Transform3D)
	add_child(_shelter)
	var wood := TrailModels.wood(SHELTER_WOOD)
	var parts: Array[Array] = [["wood", wood],
			["snow", TrailModels.vertex_tinted("Snow010A", 0.6, Color("C0CCD6"))],
			["iron", TrailModels.metal(IRON_COLOR, 0.6, 0.6)]]
	for part in parts:
		var instance := MeshInstance3D.new()
		instance.name = "Shelter_%s" % part[0]
		instance.mesh = TrailModels.mesh(SHELTER_MODEL, part[0])
		instance.material_override = part[1]
		instance.visibility_range_end = 160.0
		_shelter.add_child(instance)
	var to_shelter := _shelter.transform.affine_inverse()
	var benches := TrailProps.Merge.new()
	var bench := TrailModels.arrays("benches", "bench_camp")
	for place: Transform3D in _layout["benches"]:
		benches.add(bench, to_shelter * inverse * place)
	benches.build(_shelter, "Benches", wood, 160.0)
	var body := StaticBody3D.new()
	body.name = "ShelterBody"
	body.set_meta("footstep", FOOTSTEP)
	# [tamanho, meio] no espaço do abrigo.
	var boxes: Array[Array] = [[Vector3(3.5, 2.4, 0.12), Vector3(0.0, 1.2, -1.2)],
			[Vector3(0.14, 1.2, 2.5), Vector3(-1.69, 0.6, -0.05)], [Vector3(0.14, 1.2, 2.5), Vector3(1.69, 0.6, -0.05)],
			[Vector3(0.18, 2.3, 0.18), Vector3(-1.6, 1.15, 1.1)], [Vector3(0.18, 2.3, 0.18), Vector3(1.6, 1.15, 1.1)],
			[Vector3(2.75, 0.5, 0.42), Vector3(0.0, 0.25, -0.77)]]
	for place: Transform3D in _layout["benches"]:
		var local := to_shelter * inverse * place
		boxes.append([Vector3(1.25, 0.9, 0.5), local.origin + Vector3.UP * 0.45, local.basis])
	for item in boxes:
		var shape := BoxShape3D.new()
		shape.size = item[0]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = item[1]
		if item.size() > 2:
			collision.basis = item[2]
		body.add_child(collision)
	_shelter.add_child(body)


## A fogueira na frente do abrigo, com colisão (ninguém fica dentro do fogo).
func _add_fire() -> void:
	var inverse := transform.affine_inverse()
	_campfire = Campfire.new()
	_campfire.position = inverse * (_layout["fire"] as Vector3)
	add_child(_campfire)
	_campfire.build(TrailModels.vertex_tinted("Rock058", 1.1, Color("7E8892")), FADE_BEGIN, FADE_LENGTH)
	var fire_body := StaticBody3D.new()
	fire_body.name = "FireBody"
	var ring := CylinderShape3D.new()
	ring.radius = FIRE_BODY_RADIUS
	ring.height = 0.6
	var fire_shape := CollisionShape3D.new()
	fire_shape.shape = ring
	fire_shape.position.y = 0.3
	fire_body.add_child(fire_shape)
	_campfire.add_child(fire_body)


func _add_telescope() -> void:
	_telescope = LookoutTelescope.new()
	_telescope.transform = transform.affine_inverse() * (_layout["telescope"] as Transform3D)
	_telescope.target = TELESCOPE_TARGET
	add_child(_telescope)
	_telescope.build()


## As lanternas: as duas do abrigo, penduradas, e as em pé nos postes de onde
## a trilha chega e perto da luneta. Cada uma com uma luz pequena, sem sombra.
func _add_lanterns() -> void:
	var places: Array[Transform3D] = []
	if _shelter != null:
		for hook in LANTERN_HOOKS:
			places.append(_shelter.transform * Transform3D(Basis.IDENTITY, hook))
	var inverse := transform.affine_inverse()
	for top: Vector3 in _layout["lanterns"]:
		places.append(Transform3D(Basis.IDENTITY, inverse * top))
	var iron := TrailProps.Merge.new()
	var glass := TrailProps.Merge.new()
	for k in places.size():
		var place := places[k]
		var turned := Transform3D(Basis(Vector3.UP, 0.4 + 0.9 * k), place.origin)
		iron.add(TrailModels.arrays(LANTERN_MODEL, "iron"), turned)
		glass.add(TrailModels.arrays(LANTERN_MODEL, "glass"), turned)
		var light := OmniLight3D.new()
		light.name = "Lantern%d" % k
		light.light_color = LANTERN_COLOR
		light.omni_range = LANTERN_RANGE
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = FADE_BEGIN
		light.distance_fade_length = FADE_LENGTH
		light.position = place.origin + Vector3.UP * LANTERN_GLASS_Y
		add_child(light)
		_lantern_lights.append(light)
	iron.build(self, "Lanterns0", TrailModels.metal(IRON_COLOR, 0.6, 0.6), 160.0)
	var lit := glass.build(self, "Lanterns1", _glass, 160.0)
	if lit != null:
		lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # o vidro fica dentro da luz


## A tapeçaria: um pano com dobras leves (a capa na frente), pendurado pela
## borda de cima (a origem), descendo TAPESTRY_SIZE.y.
static func _tapestry_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const COLUMNS: int = 14
	const ROWS: int = 10
	for row in ROWS:
		for column in COLUMNS:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var u := float(column + corner.x) / COLUMNS
				var v := float(row + corner.y) / ROWS
				var fold := sin(u * TAU * 3.0) * 0.018 * (0.4 + 0.6 * v)
				surface.set_uv(Vector2(u, v))
				surface.add_vertex(Vector3((u - 0.5) * TAPESTRY_SIZE.x, -v * TAPESTRY_SIZE.y, fold))
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()
