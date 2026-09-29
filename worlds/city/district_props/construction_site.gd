class_name ConstructionSite
extends Node3D
## Bairro Simulação e Construção: uma OBRA. No prédio mais alto do quarteirão
## sobe um guindaste amarelo (torre, lança e contrapeso) que gira devagar em
## cima do telhado, e uma tela de andaime (listras diagonais escuras, com
## vãos por onde se vê a fachada) cobre um andar da frente do mesmo prédio.
## No alto da lança pisca uma luz vermelha de obstrução (1 vez por segundo);
## à noite ela também acende uma OmniLight3D pequena (só uma por quarteirão).
##
## As peças ficam penduradas no próprio prédio (como os telões do bairro
## Ação); a geometria do prédio não muda.

const YELLOW: Color = Color("E0B12A")
const DARK_METAL: Color = Color("1A1D22")
const BEACON_COLOR: Color = Color(1.0, 0.12, 0.06)
## Torre: 1 x 1 m, sobe TOWER_HEIGHT metros acima do telhado.
const TOWER_SIZE: float = 1.0
const TOWER_HEIGHT: float = 12.0
## Lança (para o lado que a grua olha), braço do contrapeso e o peso.
const JIB_LENGTH: float = 12.0
const COUNTER_ARM_LENGTH: float = 4.0
const COUNTERWEIGHT_SIZE: Vector3 = Vector3(1.6, 1.5, 1.2)
## A grua dá uma volta completa em 90 s.
const SPIN_DEGREES_PER_SECOND: float = 4.0
## A luz de obstrução: um ciclo por segundo, metade do tempo acesa.
const BLINK_PERIOD: float = 1.0
const BEACON_RADIUS: float = 0.25
const BEACON_ENERGY_DAY: float = 2.5
const BEACON_ENERGY_NIGHT: float = 6.0
const BEACON_ENERGY_OFF: float = 0.05
const OMNI_RANGE: float = 6.0
const OMNI_ENERGY: float = 0.8
## Onde a torre fica no telhado (fração do tamanho, a partir do centro): o
## canto que os objetos do telhado (caixa d'água, condensador) não usam.
const TOWER_SPOT: Vector2 = Vector2(0.3, -0.3)
## Tela de andaime: uma tela na frente da fachada, a este recuo da parede.
const NET_OFFSET: float = 0.4
const NET_TILE_PIXELS: int = 64        # um ladrilho de 1 m x 1 m
const NET_STRIPE_PERIOD_PIXELS: int = 32
const NET_STRIPE_COLOR: Color = Color(0.07, 0.07, 0.08, 0.88)
const NET_GAP_COLOR: Color = Color(0.07, 0.07, 0.08, 0.1)

## Os prédios do quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []

var _target: CityBuilding
var _crane: Node3D
var _net: MeshInstance3D
var _beacon_material: StandardMaterial3D
var _omni: OmniLight3D
var _blink_time: float = 0.0
var _beacon_on: bool = true
var _night: float = 0.0

static var _net_texture: Texture2D


func _ready() -> void:
	add_to_group("city_night")
	_target = _tallest_building()
	if _target == null:
		set_process(false)
		return
	var site := Node3D.new()
	site.name = "Obra"
	_target.add_child(site)
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = YELLOW
	yellow.metallic = 0.5
	yellow.roughness = 0.7  # metal fosco
	_build_crane(site, yellow)
	_build_scaffold(site, yellow)
	set_night(0.0)
	_apply_beacon()


func _process(delta: float) -> void:
	# A grua gira devagar (a torre fica parada; gira a lança com o contrapeso).
	_crane.rotation.y += deg_to_rad(SPIN_DEGREES_PER_SECOND) * delta
	_blink_time = fmod(_blink_time + delta, BLINK_PERIOD)
	var on := _blink_time < BLINK_PERIOD / 2.0
	if on != _beacon_on:
		_beacon_on = on
		_apply_beacon()


## 0 = dia, 1 = noite: a luz vermelha brilha mais, e a OmniLight acende.
func set_night(night: float) -> void:
	_night = night
	if _target != null:
		_apply_beacon()


## O prédio mais alto do quarteirão (o de maior size.y; no empate, o de
## telhado mais alto, contando o recuo).
func _tallest_building() -> CityBuilding:
	var best: CityBuilding = null
	for building in buildings:
		if best == null or building.size.y > best.size.y \
				or (is_equal_approx(building.size.y, best.size.y)
				and building.variant.total_height() > best.variant.total_height()):
			best = building
	return best


# --- Guindaste ---------------------------------------------------------------

func _build_crane(site: Node3D, yellow: Material) -> void:
	# Telhado do prédio: o recuo (se houver) é o telhado de cima.
	var variant := _target.variant
	var roof_y := _target.size.y
	var roof_center := Vector2.ZERO
	var roof_size := Vector2(_target.size.x, _target.size.z)
	if variant.setback:
		roof_y += BuildingVariant.SETBACK_HEIGHT
		roof_center = Vector2(0.0, -BuildingVariant.SETBACK_BACK)
		roof_size -= Vector2.ONE * BuildingVariant.SETBACK_INSET * 2.0
	var base := Vector3(roof_center.x + TOWER_SPOT.x * roof_size.x, roof_y,
			roof_center.y + TOWER_SPOT.y * roof_size.y)

	# Torre fina, parada.
	_add_box(site, base + Vector3(0.0, TOWER_HEIGHT / 2.0, 0.0),
			Vector3(TOWER_SIZE, TOWER_HEIGHT, TOWER_SIZE), yellow)

	# Tudo que gira fica num nó só, no alto da torre. Cada obra começa virada
	# para um lado (sorteado pelo App ID), para as gruas não girarem iguais.
	_crane = Node3D.new()
	_crane.name = "Crane"
	_crane.position = base + Vector3(0.0, TOWER_HEIGHT + 0.3, 0.0)
	_crane.rotation.y = deg_to_rad(float(_target.game.app_id % 360))
	site.add_child(_crane)

	_add_box(_crane, Vector3(0.0, -0.3, 0.0), Vector3(1.4, 0.5, 1.4), yellow)  # mesa giratória
	_add_box(_crane, Vector3(JIB_LENGTH / 2.0, 0.0, 0.0), Vector3(JIB_LENGTH, 0.6, 0.6), yellow)  # lança
	_add_box(_crane, Vector3(-COUNTER_ARM_LENGTH / 2.0, 0.0, 0.0), Vector3(COUNTER_ARM_LENGTH, 0.5, 0.5), yellow)
	_add_box(_crane, Vector3(-COUNTER_ARM_LENGTH + 0.2, -0.5, 0.0), COUNTERWEIGHT_SIZE, yellow)  # contrapeso
	_add_box(_crane, Vector3(1.3, -1.0, 0.0), Vector3(1.3, 1.3, 1.5), yellow)  # cabine

	# Cabo e gancho pendurados na lança.
	var dark := StandardMaterial3D.new()
	dark.albedo_color = DARK_METAL
	dark.metallic = 0.8
	dark.roughness = 0.35
	_add_box(_crane, Vector3(JIB_LENGTH * 0.7, -3.3, 0.0), Vector3(0.05, 6.0, 0.05), dark)
	_add_box(_crane, Vector3(JIB_LENGTH * 0.7, -6.4, 0.0), Vector3(0.5, 0.5, 0.4), dark)

	# Luz de obstrução no alto da ponta da lança: esfera emissiva que pisca.
	_beacon_material = StandardMaterial3D.new()
	_beacon_material.albedo_color = BEACON_COLOR
	_beacon_material.emission_enabled = true
	_beacon_material.emission = BEACON_COLOR
	var sphere := SphereMesh.new()
	sphere.radius = BEACON_RADIUS
	sphere.height = BEACON_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	beacon.mesh = sphere
	beacon.material_override = _beacon_material
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.position = Vector3(JIB_LENGTH - 0.3, 0.3 + BEACON_RADIUS, 0.0)
	_crane.add_child(beacon)

	# A única luz de verdade da obra, só à noite e pequena.
	_omni = OmniLight3D.new()
	_omni.name = "BeaconLight"
	_omni.light_color = BEACON_COLOR
	_omni.omni_range = OMNI_RANGE
	_omni.shadow_enabled = false
	_omni.position = beacon.position
	_crane.add_child(_omni)


func _add_box(parent: Node3D, center: Vector3, box_size: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	box.mesh = mesh
	box.material_override = material
	box.position = center
	parent.add_child(box)


## Acende ou apaga a luz vermelha (esfera e OmniLight) conforme o ciclo e a hora.
func _apply_beacon() -> void:
	var lit_energy := lerpf(BEACON_ENERGY_DAY, BEACON_ENERGY_NIGHT, _night)
	_beacon_material.emission_energy_multiplier = lit_energy if _beacon_on else BEACON_ENERGY_OFF
	# A OmniLight só existe à noite (de dia fica apagada, sem custo).
	var light_on := _beacon_on and _night > 0.3
	_omni.visible = light_on
	_omni.light_energy = OMNI_ENERGY if light_on else 0.0


# --- Tela de andaime ---------------------------------------------------------

## Uma tela com listras diagonais cobrindo um andar da fachada da frente, com
## barras de andaime em cima, embaixo e nas pontas.
func _build_scaffold(site: Node3D, yellow: Material) -> void:
	var width := _target.size.x
	var height := BuildingVariant.FLOOR_HEIGHT
	# Um andar do meio do prédio (sobe do térreo, passa da marquise da porta).
	var floor_index := floori(_target.variant.floors / 2.0)
	var bottom := BuildingVariant.GROUND_FLOOR_HEIGHT + floor_index * BuildingVariant.FLOOR_HEIGHT
	var z := _target.size.z / 2.0 + NET_OFFSET

	var material := StandardMaterial3D.new()
	material.albedo_texture = _get_net_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.uv1_scale = Vector3(width, height, 1.0)  # um ladrilho por metro
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	_net = MeshInstance3D.new()
	_net.name = "ScaffoldNet"
	_net.mesh = quad
	_net.material_override = material
	_net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_net.position = Vector3(0.0, bottom + height / 2.0, z)
	site.add_child(_net)

	for y in [bottom, bottom + height]:
		_add_box(site, Vector3(0.0, y, z + 0.05), Vector3(width + 0.3, 0.08, 0.08), yellow)
	for x in [-width / 2.0 - 0.1, 0.0, width / 2.0 + 0.1]:
		_add_box(site, Vector3(x, bottom + height / 2.0, z + 0.05), Vector3(0.08, height, 0.08), yellow)


## Listras diagonais escuras, com vãos quase transparentes (uma vez só).
static func _get_net_texture() -> Texture2D:
	if _net_texture == null:
		var image := Image.create(NET_TILE_PIXELS, NET_TILE_PIXELS, false, Image.FORMAT_RGBA8)
		for y in NET_TILE_PIXELS:
			for x in NET_TILE_PIXELS:
				var stripe := float((x + y) % NET_STRIPE_PERIOD_PIXELS) < NET_STRIPE_PERIOD_PIXELS / 2.0
				image.set_pixel(x, y, NET_STRIPE_COLOR if stripe else NET_GAP_COLOR)
		image.generate_mipmaps()
		_net_texture = ImageTexture.create_from_image(image)
	return _net_texture


# --- Para os testes ----------------------------------------------------------

func get_target_building() -> CityBuilding:
	return _target


func get_crane() -> Node3D:
	return _crane


func get_scaffold() -> MeshInstance3D:
	return _net


func get_beacon_light() -> OmniLight3D:
	return _omni


## A luz vermelha está acesa neste instante?
func is_beacon_on() -> bool:
	return _beacon_on
