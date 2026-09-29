class_name StreetLight
extends Node3D
## Poste de rua moderno, feito por código: haste fina de metal escuro, braço
## reto e uma luminária de LED que acende à noite (um spot apontado para baixo,
## que desenha o "círculo de luz" no chão).
##
## O braço aponta para a frente (-Z deste nó): gire o nó para a luminária
## ficar sobre a rua. set_night(0..1) acende e apaga aos poucos.
##
## Lampião a gás (lantern = true, usado pelo bairro Aventura): no lugar do braço
## e da luminária de LED, uma haste de ferro com uma lanterna de vidro no topo.
## A luz é quente (~2200 K) e TREME como uma chama, só à noite: de dia o
## _process fica desligado. Sem o lampião, tudo funciona como sempre.

const POLE_HEIGHT: float = 5.6
const ARM_LENGTH: float = 1.7
const LIGHT_COLOR: Color = Color(1.0, 0.9, 0.76)
const LIGHT_ENERGY: float = 14.0
const LIGHT_RANGE: float = 12.0
const LIGHT_ANGLE: float = 62.0  # graus
const METAL_COLOR: Color = Color("1A1D22")

## Círculo de luz no chão: diâmetro (m) e força.
const POOL_DIAMETER: float = 6.0
const POOL_ENERGY: float = 0.35

## Lampião a gás: altura da haste (m), cor e força da luz, brilho do vidro.
const LANTERN_POLE_HEIGHT: float = 4.3
const LANTERN_COLOR: Color = Color(1.0, 0.66, 0.32)
const LANTERN_ENERGY: float = 11.0
const LANTERN_RANGE: float = 10.0
const LANTERN_ANGLE: float = 78.0  # graus
const LANTERN_GLOW: float = 4.0
const LANTERN_POOL_DIAMETER: float = 5.5
const LANTERN_POOL_ENERGY: float = 0.4
const IRON_COLOR: Color = Color("1F1C1A")
## Quanto a chama treme: a luz sobe e desce até essa fração do valor normal.
const FLICKER_AMOUNT: float = 0.2

## Poste queimado: não acende à noite (o bairro Terror tem um).
var broken: bool = false:
	set(value):
		broken = value
		if _light != null:
			set_night(_last_night)

## Lampião a gás em vez do poste de LED. Pode ser ligado depois que o poste já
## está na cena: a montagem é refeita do zero.
var lantern: bool = false:
	set(value):
		if lantern == value:
			return
		lantern = value
		if is_node_ready():
			_build()

var _light: SpotLight3D
var _led_material: StandardMaterial3D  # a lente de LED (ou o vidro do lampião)
var _pool: Decal
var _last_night: float = 0.0
## Tudo que o poste monta (para refazer a montagem sem deixar lixo na cena).
var _parts: Array[Node] = []
## Força de cada luz quando está totalmente acesa (muda com o lampião).
var _light_energy: float = LIGHT_ENERGY
var _glow_energy: float = 5.0
var _pool_energy: float = POOL_ENERGY
## Acendimento atual (0 a 1) e o "tremor" da chama (1 = sem tremer).
var _on: float = 0.0
var _flicker: float = 1.0
## Tempo da chama: cada lampião começa num ponto diferente do ruído (veja _ready).
var _time: float = 0.0

static var _shared_pool_texture: Texture2D
static var _shared_flicker_noise: FastNoiseLite
static var _shared_iron_mesh: ArrayMesh
static var _shared_iron_material: StandardMaterial3D


func _ready() -> void:
	# O relógio da cidade (DayNight) acende todo mundo nesse grupo.
	add_to_group("city_night")
	_time = float(absi(hash(position)) % 1000)
	_build()


## Monta (ou refaz) o poste: a haste, a luminária ou o lampião, e o círculo de luz.
func _build() -> void:
	for part in _parts:
		remove_child(part)  # sai já (senão as novas peças ganhariam outro nome)
		part.queue_free()
	_parts.clear()
	_light = null
	# Quem tem _process ganha ele ligado sozinho: só o lampião aceso precisa dele.
	set_process(false)
	_flicker = 1.0

	var pool_position: Vector3
	if lantern:
		_light_energy = LANTERN_ENERGY
		_glow_energy = LANTERN_GLOW
		_pool_energy = LANTERN_POOL_ENERGY
		pool_position = _build_lantern()
	else:
		_light_energy = LIGHT_ENERGY
		_glow_energy = 5.0
		_pool_energy = POOL_ENERGY
		pool_position = _build_led_arm()

	# Círculo de luz firme no chão (a luz de verdade é suave demais nas bordas).
	# É um Decal: uma "projeção" de cima para baixo, sem custo de luz extra.
	var diameter := LANTERN_POOL_DIAMETER if lantern else POOL_DIAMETER
	_pool = Decal.new()
	_pool.size = Vector3(diameter, 1.0, diameter)
	# Só no chão: superfícies em pé (o poste, as paredes) não recebem o círculo.
	_pool.normal_fade = 0.9
	_pool.texture_emission = _pool_texture()
	_pool.modulate = LANTERN_COLOR if lantern else LIGHT_COLOR
	_pool.cull_mask = 1  # só o mundo (não os hologramas)
	_pool.position = pool_position
	_add_part(_pool)
	set_night(_last_night)


## Poste moderno: haste, braço horizontal e luminária de LED. Devolve onde fica
## o círculo de luz no chão.
func _build_led_arm() -> Vector3:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.8
	metal.roughness = 0.35

	# Haste (um pouco mais fina em cima).
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = POLE_HEIGHT
	pole_mesh.radial_segments = 12
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, POLE_HEIGHT / 2.0, 0.0)
	pole.material_override = metal
	_add_part(pole)

	# Braço horizontal e a luminária na ponta.
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.08, 0.08, ARM_LENGTH)
	arm.mesh = arm_mesh
	arm.position = Vector3(0.0, POLE_HEIGHT - 0.05, -ARM_LENGTH / 2.0)
	arm.material_override = metal
	_add_part(arm)

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.32, 0.07, 0.8)
	head.mesh = head_mesh
	head.position = Vector3(0.0, POLE_HEIGHT - 0.06, -ARM_LENGTH + 0.2)
	head.material_override = metal
	_add_part(head)

	# A "lente" de LED embaixo da luminária (brilha à noite).
	_led_material = StandardMaterial3D.new()
	_led_material.albedo_color = LIGHT_COLOR
	_led_material.emission_enabled = true
	_led_material.emission = LIGHT_COLOR
	var led := MeshInstance3D.new()
	var led_mesh := BoxMesh.new()
	led_mesh.size = Vector3(0.24, 0.01, 0.68)
	led.mesh = led_mesh
	led.position = head.position - Vector3(0.0, 0.04, 0.0)
	led.material_override = _led_material
	_add_part(led)

	# Spot apontado para baixo (por padrão ele aponta para -Z; giramos -90° em X).
	_light = SpotLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.spot_range = LIGHT_RANGE
	_light.spot_angle = LIGHT_ANGLE
	_light.spot_attenuation = 0.8
	_light.position = led.position - Vector3(0.0, 0.05, 0.0)
	_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_add_part(_light)
	return Vector3(_light.position.x, 0.3, _light.position.z)


## Lampião a gás: a haste de ferro (uma malha só, igual para todos) e, no topo,
## uma caixinha de vidro que brilha, com a luz quente dentro. Devolve onde fica
## o círculo de luz no chão.
func _build_lantern() -> Vector3:
	var iron := MeshInstance3D.new()
	iron.mesh = _lantern_iron_mesh()
	iron.material_override = _lantern_iron_material()
	_add_part(iron)

	# O vidro é um material só deste poste, para cada chama tremer sozinha.
	_led_material = StandardMaterial3D.new()
	_led_material.albedo_color = LANTERN_COLOR.darkened(0.35)
	_led_material.roughness = 0.2
	_led_material.emission_enabled = true
	_led_material.emission = LANTERN_COLOR
	var glass_center := Vector3(0.0, LANTERN_POLE_HEIGHT + 0.31, 0.0)
	var glass := MeshInstance3D.new()
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(0.19, 0.4, 0.19)
	glass.mesh = glass_mesh
	glass.position = glass_center
	glass.material_override = _led_material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_part(glass)

	# A luz sai de dentro do vidro, para baixo (mais aberta que a do LED).
	_light = SpotLight3D.new()
	_light.light_color = LANTERN_COLOR
	_light.spot_range = LANTERN_RANGE
	_light.spot_angle = LANTERN_ANGLE
	_light.spot_attenuation = 0.8
	_light.position = glass_center
	_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_add_part(_light)
	return Vector3(0.0, 0.3, 0.0)


## 0 = dia (apagado), 1 = noite (aceso).
func set_night(night: float) -> void:
	_last_night = night
	_on = 0.0 if broken else smoothstep(0.3, 0.8, night)
	# O lampião só treme aceso; de dia (ou apagado) o _process fica desligado.
	var flickers := lantern and _on > 0.01
	if not flickers:
		_flicker = 1.0
	set_process(flickers)
	_apply_light()


## A chama do lampião: um ruído suave em duas velocidades (uma oscilação lenta
## e um tremelique rápido) muda a força da luz a cada quadro.
func _process(delta: float) -> void:
	_time += delta
	var noise := _flicker_noise()
	var wobble := noise.get_noise_1d(_time * 2.0) * 0.6 + noise.get_noise_1d(_time * 9.0 + 50.0) * 0.4
	_flicker = 1.0 + wobble * FLICKER_AMOUNT
	_apply_light()


## Aplica o acendimento (e o tremor) na luz, no brilho do vidro e no círculo do chão.
func _apply_light() -> void:
	_light.visible = _on > 0.01
	_light.light_energy = _light_energy * _on * _flicker
	_led_material.emission_energy_multiplier = _glow_energy * _on * _flicker
	_pool.visible = _on > 0.01
	_pool.emission_energy = _pool_energy * _on * _flicker


func _add_part(part: Node) -> void:
	add_child(part)
	_parts.append(part)


## Textura do círculo (a mesma para todos os postes): claro no meio, uma
## borda firme e nada fora dele.
static func _pool_texture() -> Texture2D:
	if _shared_pool_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.7, 0.86, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.7, 0.7, 0.7, 1),
				Color(0.45, 0.45, 0.45, 1), Color(0, 0, 0, 1)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 128
		_shared_pool_texture = texture
	return _shared_pool_texture


## Ruído da chama (um só para todos os lampiões; cada um começa num ponto).
static func _flicker_noise() -> FastNoiseLite:
	if _shared_flicker_noise == null:
		_shared_flicker_noise = FastNoiseLite.new()
		_shared_flicker_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_shared_flicker_noise.frequency = 1.0
		_shared_flicker_noise.seed = 2200
	return _shared_flicker_noise


static func _lantern_iron_material() -> StandardMaterial3D:
	if _shared_iron_material == null:
		_shared_iron_material = StandardMaterial3D.new()
		_shared_iron_material.albedo_color = IRON_COLOR
		_shared_iron_material.metallic = 0.5
		_shared_iron_material.roughness = 0.5
	return _shared_iron_material


## Todo o ferro do lampião numa malha só (feita uma vez): base larga, haste,
## barra da escada do acendedor, prato, quatro cantoneiras do vidro, chapéu
## em cone e uma bolinha no alto.
static func _lantern_iron_mesh() -> ArrayMesh:
	if _shared_iron_mesh != null:
		return _shared_iron_mesh
	var top := LANTERN_POLE_HEIGHT
	var builder := SurfaceTool.new()
	# Base larga e um anel logo acima dela.
	_append_cylinder(builder, 0.09, 0.17, 0.6, Vector3(0.0, 0.3, 0.0))
	_append_cylinder(builder, 0.13, 0.13, 0.06, Vector3(0.0, 0.63, 0.0))
	# A haste, de cima do anel até o prato.
	_append_cylinder(builder, 0.045, 0.065, top - 0.66, Vector3(0.0, 0.66 + (top - 0.66) / 2.0, 0.0))
	# Barra da escada do acendedor de lampiões.
	var bar := BoxMesh.new()
	bar.size = Vector3(0.5, 0.035, 0.035)
	builder.append_from(bar, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, top - 0.75, 0.0)))
	# Anel sob o prato e o prato onde o vidro se apoia (largo em cima).
	_append_cylinder(builder, 0.09, 0.09, 0.08, Vector3(0.0, top - 0.05, 0.0))
	_append_cylinder(builder, 0.2, 0.07, 0.1, Vector3(0.0, top + 0.05, 0.0))
	# Cantoneiras nos quatro cantos do vidro (o vidro é um pouco mais estreito).
	var post := BoxMesh.new()
	post.size = Vector3(0.025, 0.42, 0.025)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			builder.append_from(post, 0, Transform3D(Basis.IDENTITY, Vector3(sx * 0.1, top + 0.31, sz * 0.1)))
	# Chapéu em cone e a bolinha no alto.
	_append_cylinder(builder, 0.03, 0.24, 0.16, Vector3(0.0, top + 0.6, 0.0))
	var ball := SphereMesh.new()
	ball.radius = 0.04
	ball.height = 0.08
	ball.radial_segments = 8
	ball.rings = 4
	builder.append_from(ball, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, top + 0.72, 0.0)))
	_shared_iron_mesh = builder.commit()
	return _shared_iron_mesh


## Acrescenta um cilindro (ou cone) à malha que está sendo montada.
static func _append_cylinder(builder: SurfaceTool, top_radius: float, bottom_radius: float,
		height: float, center: Vector3) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.rings = 1
	builder.append_from(cylinder, 0, Transform3D(Basis.IDENTITY, center))
