class_name PlazaClockTower
extends Node3D
## A torre do relógio da praça (Fase 11.5): o ponto alto que se vê de longe.
## Uma coluna de concreto sai do meio do chafariz; no alto, uma cabeça com
## quatro mostradores de néon (ponteiros de hora e minuto) e uma coroa que
## acende à noite. Marca a hora da CIDADE (DayNight.current_hour()), uma vez
## por segundo. Só a coluna tem colisão.
##
## A luz própria da noite (Fase 17.5): quatro holofotes baixos no chão, em
## volta do chafariz, iluminam a torre de baixo para cima (o marco se lê de
## longe), e uma luz no meio do chafariz acende a água e faz a poça de luz da
## praça. De dia ficam apagados (e invisíveis: não custam nada). Sem sombra.
##
## Uso: crie, ponha "day_night" e adicione à cena. set_hour() força uma hora
## (os testes usam).

## Altura total: a de um prédio de 3 andares (BuildingVariant) mais 3 m.
const HEIGHT: float = BuildingVariant.GROUND_FLOOR_HEIGHT + 3.0 * BuildingVariant.FLOOR_HEIGHT \
		+ BuildingVariant.TOP_MARGIN + 3.0
const COLUMN_SIZE: float = 1.2
## A cabeça (caixa que carrega os mostradores) e a altura do centro deles.
const HEAD_SIZE: float = 2.8
const DIAL_HEIGHT: float = 15.0
const DIAL_RADIUS: float = 1.15
const NEON_COLOR: Color = Color("DDEBFF")
const CROWN_HEIGHT: float = 0.7

## Os holofotes: luz âmbar (a "luz quente" do sistema visual), a que distância
## do centro ficam (o chafariz tem 2 m de raio) e para que altura apontam.
const UPLIGHT_COLOR: Color = Color("FFC48A")
const UPLIGHT_ENERGY: float = 16.0
const UPLIGHT_RANGE: float = 24.0
const UPLIGHT_ANGLE: float = 26.0  # graus
const UPLIGHT_DISTANCE: float = 3.4
const UPLIGHT_AIM_HEIGHT: float = 14.0
## A luz do chafariz: dentro da coluna, acima da água. Sem sombra, ela passa
## pela coluna e acende a bacia e o chão em volta (a coluna não: as faces dela
## olham para fora).
const FOUNTAIN_LIGHT_COLOR: Color = Color("FFD9AE")
const FOUNTAIN_LIGHT_ENERGY: float = 2.5
const FOUNTAIN_LIGHT_RANGE: float = 11.0
const FOUNTAIN_LIGHT_HEIGHT: float = 1.4
## As lâmpadas na água do chafariz (oito, em roda) e a força delas à noite.
const POOL_LAMPS: int = 8
const POOL_LAMP_RADIUS: float = 1.2
const POOL_LAMP_GLOW: float = 4.0

## O relógio da cidade (quem manda na hora). Sem ele, a torre fica na última hora.
var day_night: DayNight

var _hour_pivots: Array[Node3D] = []
var _minute_pivots: Array[Node3D] = []
var _neon_material: StandardMaterial3D
var _hour: float = 0.0
## As luzes da noite (holofotes e chafariz) e o vidro que brilha nelas.
var _night_lights: Array[Light3D] = []
var _night_energies: Array[float] = []
var _lamp_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("city_night")
	_neon_material = StandardMaterial3D.new()
	_neon_material.albedo_color = NEON_COLOR
	_neon_material.emission_enabled = true
	_neon_material.emission = NEON_COLOR
	_build_column()
	_build_head()
	_build_crown()
	_build_night_lights()
	set_night(0.0)

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()
	_tick()


## Topo da torre (y do mundo), para quem precisa ficar acima dela.
func get_top_y() -> float:
	return global_position.y + HEIGHT


## Põe os ponteiros numa hora (0.0 a 24.0).
func set_hour(hour: float) -> void:
	_hour = fposmod(hour, 24.0)
	var hour_angle := fposmod(_hour, 12.0) / 12.0 * TAU
	var minute_angle := fposmod(_hour, 1.0) * TAU
	# Visto de fora, o sentido horário é girar para -Z do próprio mostrador.
	for pivot in _hour_pivots:
		pivot.rotation.z = -hour_angle
	for pivot in _minute_pivots:
		pivot.rotation.z = -minute_angle


## Ângulo dos ponteiros em graus, de 0 (para cima) a 360, no sentido horário.
func get_hour_angle() -> float:
	return fposmod(_hour, 12.0) / 12.0 * 360.0


func get_minute_angle() -> float:
	return fposmod(_hour, 1.0) * 360.0


## 0 = dia, 1 = noite (mesma regra de todo o néon da cidade).
func set_night(night: float) -> void:
	if _neon_material != null:
		_neon_material.emission_energy_multiplier = CityDecor.neon_energy(night)
	for i in _night_lights.size():
		_night_lights[i].light_energy = _night_energies[i] * night
		_night_lights[i].visible = night > 0.01
	if _lamp_material != null:
		_lamp_material.emission_energy_multiplier = POOL_LAMP_GLOW * night


## As luzes da noite que estão acesas agora (os testes usam).
func get_night_lights() -> Array[Light3D]:
	return _night_lights


func _tick() -> void:
	if day_night != null:
		set_hour(day_night.current_hour())
	else:
		set_hour(_hour)


# --- Montagem ------------------------------------------------------------------

func _build_column() -> void:
	var concrete := CityDecor.pbr_material("Concrete034", 2.0, Color(0.72, 0.72, 0.72))
	var body := StaticBody3D.new()
	body.name = "Column"
	body.position = Vector3(0.0, HEIGHT / 2.0, 0.0)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(COLUMN_SIZE, HEIGHT, COLUMN_SIZE)
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)
	# A coluna visível vai só até a cabeça (o resto é a cabeça e a coroa).
	_add_box(Vector3(0.0, (DIAL_HEIGHT - HEAD_SIZE / 2.0) / 2.0, 0.0),
			Vector3(COLUMN_SIZE, DIAL_HEIGHT - HEAD_SIZE / 2.0, COLUMN_SIZE), concrete)


func _build_head() -> void:
	var concrete := CityDecor.pbr_material("Concrete034", 2.0, Color(0.62, 0.62, 0.64))
	_add_box(Vector3(0.0, DIAL_HEIGHT, 0.0), Vector3(HEAD_SIZE, HEAD_SIZE, HEAD_SIZE), concrete)
	var dial_material := CityDecor.make_material(Color(0.04, 0.05, 0.07))
	for i in 4:
		var face := Node3D.new()
		face.name = "Dial%d" % i
		face.position = Vector3(0.0, DIAL_HEIGHT, 0.0)
		face.rotation.y = i * PI / 2.0  # cada mostrador olha para um lado
		add_child(face)
		var z := HEAD_SIZE / 2.0 + 0.02
		# Fundo escuro, aro de néon e os dois ponteiros.
		var disk := MeshInstance3D.new()
		var disk_mesh := CylinderMesh.new()
		disk_mesh.top_radius = DIAL_RADIUS
		disk_mesh.bottom_radius = DIAL_RADIUS
		disk_mesh.height = 0.04
		disk.mesh = disk_mesh
		disk.rotation.x = PI / 2.0
		disk.position = Vector3(0.0, 0.0, z)
		disk.material_override = dial_material
		face.add_child(disk)
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = DIAL_RADIUS - 0.08
		ring_mesh.outer_radius = DIAL_RADIUS
		ring.mesh = ring_mesh
		ring.rotation.x = PI / 2.0
		ring.position = Vector3(0.0, 0.0, z + 0.03)
		ring.material_override = _neon_material
		face.add_child(ring)
		# As doze marcas das horas (quatro maiores).
		for mark in 12:
			var length := 0.22 if mark % 3 == 0 else 0.12
			var angle := mark * TAU / 12.0
			var tick := _hand(length, 0.06, z + 0.03)
			tick.position = Vector3(sin(angle), cos(angle), 0.0) * (DIAL_RADIUS - 0.18 - length / 2.0)
			tick.rotation.z = -angle
			face.add_child(tick)
		_hour_pivots.append(_add_hand(face, DIAL_RADIUS * 0.5, 0.1, z + 0.05))
		_minute_pivots.append(_add_hand(face, DIAL_RADIUS * 0.82, 0.06, z + 0.07))


func _build_crown() -> void:
	var concrete := CityDecor.pbr_material("Concrete034", 2.0, Color(0.62, 0.62, 0.64))
	var base_y := DIAL_HEIGHT + HEAD_SIZE / 2.0
	_add_box(Vector3(0.0, base_y + 0.15, 0.0), Vector3(HEAD_SIZE + 0.3, 0.3, HEAD_SIZE + 0.3), concrete)
	# A coroa de néon: uma faixa em volta e uma ponta no topo (que chega em HEIGHT).
	var strip := _add_box(Vector3(0.0, base_y + 0.3 + CROWN_HEIGHT / 2.0, 0.0),
			Vector3(HEAD_SIZE - 0.4, CROWN_HEIGHT, HEAD_SIZE - 0.4), _neon_material)
	strip.name = "Crown"
	var top_y := base_y + 0.3 + CROWN_HEIGHT
	var spire_height := HEIGHT - top_y
	_add_box(Vector3(0.0, top_y + spire_height / 2.0, 0.0), Vector3(0.18, spire_height, 0.18), _neon_material)


func _build_night_lights() -> void:
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = Color(0.1, 0.09, 0.08)
	_lamp_material.emission_enabled = true
	_lamp_material.emission = UPLIGHT_COLOR
	var metal := CityDecor.make_material(Color("1A1D22"))
	# Holofotes: um de frente para cada mostrador, num pé baixo de metal.
	for i in 4:
		var side := Vector3(sin(i * PI / 2.0), 0.0, cos(i * PI / 2.0))
		var base := side * UPLIGHT_DISTANCE
		var housing := _add_box(base + Vector3(0.0, 0.1, 0.0), Vector3(0.36, 0.2, 0.36), metal)
		housing.name = "UplightBase%d" % i
		housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lens := _add_box(base + Vector3(0.0, 0.205, 0.0), Vector3(0.28, 0.01, 0.28), _lamp_material)
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var spot := SpotLight3D.new()
		spot.name = "Uplight%d" % i
		spot.light_color = UPLIGHT_COLOR
		spot.spot_range = UPLIGHT_RANGE
		spot.spot_angle = UPLIGHT_ANGLE
		spot.spot_attenuation = 0.6
		spot.shadow_enabled = false
		# O spot ilumina para o -Z dele: aponta do pé para a torre, lá em cima.
		spot.transform = Transform3D(Basis.IDENTITY, base + Vector3(0.0, 0.25, 0.0)) \
				.looking_at(Vector3(0.0, UPLIGHT_AIM_HEIGHT, 0.0), -side)
		add_child(spot)
		_add_night_light(spot, UPLIGHT_ENERGY)
	# A luz do chafariz e as lâmpadas na água, em roda da coluna.
	var glow := OmniLight3D.new()
	glow.name = "FountainLight"
	glow.light_color = FOUNTAIN_LIGHT_COLOR
	glow.omni_range = FOUNTAIN_LIGHT_RANGE
	glow.omni_attenuation = 1.2
	glow.shadow_enabled = false
	glow.position = Vector3(0.0, FOUNTAIN_LIGHT_HEIGHT, 0.0)
	add_child(glow)
	_add_night_light(glow, FOUNTAIN_LIGHT_ENERGY)
	for i in POOL_LAMPS:
		var angle := (i + 0.5) * TAU / POOL_LAMPS
		var lamp := MeshInstance3D.new()
		var lamp_mesh := CylinderMesh.new()
		lamp_mesh.top_radius = 0.09
		lamp_mesh.bottom_radius = 0.09
		lamp_mesh.height = 0.02
		lamp.mesh = lamp_mesh
		lamp.position = Vector3(sin(angle), 0.0, cos(angle)) * POOL_LAMP_RADIUS + Vector3(0.0, 0.5, 0.0)
		lamp.material_override = _lamp_material
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)


func _add_night_light(light: Light3D, energy: float) -> void:
	light.light_cull_mask &= ~Home.INTERIOR_LAYER_MASK
	_night_lights.append(light)
	_night_energies.append(energy)


# --- Peças ---------------------------------------------------------------------

func _add_box(center: Vector3, box_size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	add_child(instance)
	return instance


## Uma peça fina de néon (ponteiro ou marca), de comprimento "length" para cima.
func _hand(length: float, width: float, z: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, length, 0.03)
	instance.mesh = mesh
	instance.position = Vector3(0.0, length / 2.0, z)
	instance.material_override = _neon_material
	return instance


## Um ponteiro que gira no centro do mostrador; devolve o pivô (rotation.z).
func _add_hand(face: Node3D, length: float, width: float, z: float) -> Node3D:
	var pivot := Node3D.new()
	face.add_child(pivot)
	pivot.add_child(_hand(length, width, z))
	return pivot
