class_name BuildingVariant
extends RefCounted
## O "jeito" de cada prédio da cidade, sorteado pelo App ID do jogo (o mesmo
## jogo tem sempre o mesmo prédio). Seis características:
##
##   andares       3 a 7 (os altos são mais raros), cada um com 3,5 m;
##   recuo         um andar a mais no topo, menor e mais para trás;
##   platibanda    mureta de 0,6 m em volta do telhado;
##   marquise      cobertura de 4 x 1,5 m sobre a porta, com LED embaixo;
##   janelas       grade, faixa contínua ou verticais;
##   telhado       caixa d'água e/ou condensadores de ar.
##
## O CityBuilding usa from_app_id() para saber a altura e build() para
## acrescentar as peças (caixas simples com os mesmos materiais do prédio).

enum WindowStyle { GRID, BAND, VERTICAL }

const GROUND_FLOOR_HEIGHT: float = 3.6
const FLOOR_HEIGHT: float = 3.5
## Espaço acima do último andar (onde fica a faixa de néon do topo).
const TOP_MARGIN: float = 0.9
## Chance de cada número de andares (3, 4, 5, 6 e 7).
const FLOOR_WEIGHTS: Array[float] = [0.2, 0.25, 0.25, 0.18, 0.12]
const SETBACK_INSET: float = 1.5      # quanto o recuo entra de cada lado (m)
const SETBACK_BACK: float = 1.0       # e quanto ele vai para trás
const SETBACK_HEIGHT: float = FLOOR_HEIGHT + 0.6
const PARAPET_HEIGHT: float = 0.6
const PARAPET_THICKNESS: float = 0.25
const CANOPY_SIZE: Vector3 = Vector3(4.0, 0.15, 1.5)
const CANOPY_HEIGHT: float = 3.45
## Parte da "célula" de cada janela que é vidro, por estilo.
const WINDOW_FRACTIONS: Dictionary[WindowStyle, Vector2] = {
	WindowStyle.GRID: Vector2(0.5, 0.56),
	WindowStyle.BAND: Vector2(0.94, 0.46),
	WindowStyle.VERTICAL: Vector2(0.28, 0.78),
}

var floors: int = 4
var setback: bool = false
var parapet: bool = false
var canopy: bool = false
var window_style: WindowStyle = WindowStyle.GRID
## "caixa" (caixa d'água) e/ou "condensador".
var roof_items: Array[String] = []

## Material da fachada do recuo (uma cópia da do corpo): o prédio também
## acende as janelas dele à noite.
var top_walls_material: ShaderMaterial

var _led_material: StandardMaterial3D


## O prédio de um jogo (sempre igual para o mesmo App ID). "floor_weights" são
## as chances de 3 a 7 andares do bairro (perfil); vazio = FLOOR_WEIGHTS.
static func from_app_id(app_id: int, floor_weights: PackedFloat32Array = PackedFloat32Array()) -> BuildingVariant:
	var rng := RandomNumberGenerator.new()
	rng.seed = app_id * 7919 + 13  # outra "semente", para não repetir os sorteios de cor e material
	var variant := BuildingVariant.new()
	variant.floors = 3 + rng.rand_weighted(floor_weights if floor_weights.size() == FLOOR_WEIGHTS.size() else PackedFloat32Array(FLOOR_WEIGHTS))
	variant.setback = rng.randf() < 0.4
	variant.parapet = rng.randf() < 0.6
	variant.canopy = rng.randf() < 0.5
	variant.window_style = rng.randi_range(0, WindowStyle.size() - 1) as WindowStyle
	var item_count := rng.randi_range(0, 2)
	for i in item_count:
		variant.roof_items.append("caixa" if i == 0 and rng.randf() < 0.6 else "condensador")
	return variant


## Altura do corpo do prédio (sem o recuo), do chão ao telhado.
func body_height() -> float:
	return GROUND_FLOOR_HEIGHT + floors * FLOOR_HEIGHT + TOP_MARGIN


## Altura total, com o recuo (se houver).
func total_height() -> float:
	return body_height() + (SETBACK_HEIGHT if setback else 0.0)


func window_fraction() -> Vector2:
	return WINDOW_FRACTIONS[window_style]


## Acrescenta as peças ao prédio. "walls" é o material da fachada (o recuo
## usa uma cópia dele), "metal" o das molduras e "neon" a cor do bairro.
func build(building: Node3D, size: Vector3, walls: ShaderMaterial, metal: Material, neon: Color) -> void:
	var roof_y := size.y
	var roof_center := Vector3.ZERO
	var roof_size := Vector2(size.x, size.z)

	if setback:
		var top_size := Vector3(size.x - SETBACK_INSET * 2.0, SETBACK_HEIGHT, size.z - SETBACK_INSET * 2.0)
		var top_walls := walls.duplicate() as ShaderMaterial
		# Para o shader, o "térreo" do recuo é o telhado do corpo: as janelas
		# começam ali, e a faixa de néon fica no topo do recuo.
		top_walls.set_shader_parameter("ground_floor_height", size.y)
		top_walls.set_shader_parameter("building_height", size.y + SETBACK_HEIGHT)
		top_walls_material = top_walls
		var top_center := Vector3(0.0, size.y + SETBACK_HEIGHT / 2.0, -SETBACK_BACK)
		_add_box(building, top_center, top_size, top_walls, true)
		roof_y = size.y + SETBACK_HEIGHT
		roof_center = Vector3(0.0, 0.0, -SETBACK_BACK)
		roof_size = Vector2(top_size.x, top_size.z)

	if parapet:
		# Mureta em volta do telhado do corpo (o recuo fica dentro dela).
		var half := Vector2(size.x, size.z) / 2.0
		var y := size.y + PARAPET_HEIGHT / 2.0
		var t := PARAPET_THICKNESS
		_add_box(building, Vector3(0.0, y, half.y - t / 2.0), Vector3(size.x, PARAPET_HEIGHT, t), walls, false)
		_add_box(building, Vector3(0.0, y, -half.y + t / 2.0), Vector3(size.x, PARAPET_HEIGHT, t), walls, false)
		_add_box(building, Vector3(half.x - t / 2.0, y, 0.0), Vector3(t, PARAPET_HEIGHT, size.z - t * 2.0), walls, false)
		_add_box(building, Vector3(-half.x + t / 2.0, y, 0.0), Vector3(t, PARAPET_HEIGHT, size.z - t * 2.0), walls, false)

	if canopy:
		var front := size.z / 2.0
		_add_box(building, Vector3(0.0, CANOPY_HEIGHT, front + CANOPY_SIZE.z / 2.0), CANOPY_SIZE, metal, false)
		# LED embaixo da marquise.
		_led_material = StandardMaterial3D.new()
		_led_material.albedo_color = neon.lerp(Color.WHITE, 0.5)
		_led_material.emission_enabled = true
		_led_material.emission = neon.lerp(Color.WHITE, 0.5)
		_add_box(building, Vector3(0.0, CANOPY_HEIGHT - CANOPY_SIZE.y / 2.0 - 0.01, front + CANOPY_SIZE.z / 2.0),
				Vector3(CANOPY_SIZE.x - 0.3, 0.02, CANOPY_SIZE.z - 0.3), _led_material, false)

	# Objetos no telhado, em cantos diferentes.
	var spots: Array[Vector2] = [Vector2(-0.3, -0.3), Vector2(0.3, 0.25), Vector2(-0.3, 0.3)]
	for i in roof_items.size():
		var spot := Vector3(roof_center.x + spots[i].x * roof_size.x, roof_y,
				roof_center.z + spots[i].y * roof_size.y)
		if roof_items[i] == "caixa":
			_add_water_tank(building, spot, metal)
		else:
			_add_condenser(building, spot, metal)
	set_night(0.0)


## LED da marquise: fraco de dia, forte à noite.
func set_night(night: float) -> void:
	if _led_material != null:
		_led_material.emission_energy_multiplier = lerpf(0.3, 2.2, night)


static func _add_box(parent: Node3D, center: Vector3, box_size: Vector3, material: Material,
		collision: bool) -> void:
	var box := CSGBox3D.new()
	box.size = box_size
	box.position = center
	box.material = material
	box.use_collision = collision
	parent.add_child(box)


## Caixa d'água: um cilindro sobre quatro pernas.
static func _add_water_tank(parent: Node3D, base: Vector3, metal: Material) -> void:
	for corner in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(-0.6, 0.6), Vector2(0.6, 0.6)]:
		_add_box(parent, base + Vector3(corner.x, 0.5, corner.y), Vector3(0.12, 1.0, 0.12), metal, false)
	var tank := CSGCylinder3D.new()
	tank.radius = 1.0
	tank.height = 1.6
	tank.sides = 20
	tank.position = base + Vector3(0.0, 1.0 + 0.8, 0.0)
	tank.material = CityDecor.pbr_material("Concrete034", 2.0, Color(0.55, 0.56, 0.58))
	parent.add_child(tank)


## Condensador de ar: uma caixa com a "grade" do ventilador em cima.
static func _add_condenser(parent: Node3D, base: Vector3, metal: Material) -> void:
	_add_box(parent, base + Vector3(0.0, 0.45, 0.0), Vector3(1.3, 0.9, 0.9), metal, false)
	var fan := CSGCylinder3D.new()
	fan.radius = 0.35
	fan.height = 0.05
	fan.sides = 16
	fan.position = base + Vector3(0.0, 0.92, 0.0)
	fan.material = CityDecor.make_material(Color(0.05, 0.05, 0.06))
	parent.add_child(fan)
