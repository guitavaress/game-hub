class_name Campfire
extends Node3D
## Uma fogueira de pedra e lenha (Fase 17.7): o anel de pedras, a terra
## queimada, a lenha em pirâmide, a brasa que brilha, as chamas animadas
## (campfire_flame.gdshader, planos cruzados que somam luz) e uma luz quente
## com sombra. Acende à noite (grupo city_night) e fica apagada de dia.
## O chão da fogueira é o y = 0 deste nó.

const FLAME_SHADER: Shader = preload("res://worlds/city/biome/campfire_flame.gdshader")
## Mais laranja que o lampião: o fogo é a poça mais quente da trilha.
const LIGHT_COLOR: Color = Color(1.0, 0.56, 0.24)
const LIGHT_ENERGY: float = 3.2
const LIGHT_RANGE: float = 9.0
const LIGHT_HEIGHT: float = 0.75
## A sombra some antes da luz (economia: só quem está perto vê os bancos fazendo sombra).
const SHADOW_FADE: float = 30.0
const RING_RADIUS: float = 0.52
const RING_STONES: int = 11
const LOGS: int = 6
const EMBER_ENERGY: float = 2.6

var light: OmniLight3D
var embers: StandardMaterial3D
var flames: Node3D
var _flame_material: ShaderMaterial


## Monta a fogueira. "fade_begin" e "fade_length": de onde a luz começa a
## sumir de longe (as mesmas dos lampiões da trilha).
func build(stone: Material, wood: Material, fade_begin: float, fade_length: float) -> void:
	name = "Campfire"
	add_to_group("city_night")
	var batch := TrailProps.Batch.new()
	# A terra queimada: a neve derreteu em volta do fogo.
	var ash := StandardMaterial3D.new()
	ash.albedo_color = Color("2B241F")
	ash.roughness = 1.0
	batch.add(TrailProps.cylinder(RING_RADIUS + 0.22, RING_RADIUS + 0.26, 0.05, 20),
			Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0)), ash)
	# O anel de pedras, cada uma de um jeito.
	for k in RING_STONES:
		var angle := TAU * k / RING_STONES + 0.15 * sin(k * 1.7)
		var size := Vector3(0.25 + 0.06 * sin(k * 2.3), 0.17 + 0.05 * cos(k * 1.1), 0.21)
		var place := Vector3(cos(angle), 0.0, sin(angle)) * RING_RADIUS + Vector3.UP * (size.y * 0.25)
		batch.add(TrailProps.rock(size, 40 + k), Transform3D(Basis(Vector3.UP, -angle), place), stone)
	# Duas toras deitadas, cruzadas, embaixo da pirâmide.
	for k in 2:
		var direction := Vector3(cos(k * PI / 2.0 + 0.4), 0.0, sin(k * PI / 2.0 + 0.4))
		batch.add(TrailProps.cylinder(0.055, 0.05, 0.7, 10),
				TrailProps.log_transform(-direction * 0.35 + Vector3.UP * (0.06 + k * 0.09),
				direction * 0.35 + Vector3.UP * (0.06 + k * 0.09)), wood)
	# A lenha em pirâmide, encostando no alto.
	var apex := Vector3(0.02, 0.62, -0.01)
	for k in LOGS:
		var angle := TAU * k / LOGS + 0.3
		var base := Vector3(cos(angle), 0.0, sin(angle)) * (0.33 + 0.03 * sin(k * 2.9)) + Vector3.UP * 0.04
		var top := apex + Vector3(cos(angle), 0.0, sin(angle)) * 0.05
		batch.add(TrailProps.cylinder(0.05, 0.04, base.distance_to(top) + 0.08, 10),
				TrailProps.log_transform(base, top), wood)
	# A brasa: um monte baixo e uns pedaços em volta, que brilham por dentro.
	embers = StandardMaterial3D.new()
	embers.albedo_color = Color("2A150C")
	embers.roughness = 0.9
	embers.emission_enabled = true
	embers.emission = Color("E8641E")
	batch.add(TrailProps.rock(Vector3(0.48, 0.13, 0.46), 60, 0.5), Transform3D(Basis.IDENTITY, Vector3.UP * 0.03), embers)
	for k in 5:
		var angle := TAU * k / 5.0 + 0.6
		batch.add(TrailProps.rock(Vector3(0.11, 0.07, 0.09), 70 + k, 0.6),
				Transform3D(Basis.IDENTITY, Vector3(cos(angle) * 0.27, 0.05, sin(angle) * 0.27)), embers)
	for instance in batch.build(self, "Fire", 140.0):
		if instance.material_override == embers:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a brasa fica dentro da luz

	flames = Node3D.new()
	flames.name = "Flames"
	add_child(flames)
	_flame_material = ShaderMaterial.new()
	_flame_material.shader = FLAME_SHADER
	var fire := MeshInstance3D.new()
	fire.name = "Fire"
	fire.mesh = _flame_mesh()
	fire.material_override = _flame_material
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.visibility_range_end = 140.0
	flames.add_child(fire)

	light = OmniLight3D.new()
	light.name = "Firelight"
	light.position.y = LIGHT_HEIGHT
	light.light_color = LIGHT_COLOR
	light.omni_range = LIGHT_RANGE
	light.light_size = 0.2
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = fade_begin
	light.distance_fade_length = fade_length
	light.distance_fade_shadow = SHADOW_FADE
	add_child(light)
	set_night(0.0)


## 0 = dia (apagada), 1 = noite (acesa); acende aos poucos, como os lampiões.
func set_night(night: float) -> void:
	var on := smoothstep(0.3, 0.8, night)
	light.light_energy = LIGHT_ENERGY * on
	light.visible = on > 0.01
	embers.emission_energy_multiplier = EMBER_ENERGY * on
	_flame_material.set_shader_parameter("strength", on)
	flames.visible = on > 0.01


## As chamas: três planos grandes e três pequenos, cruzados em estrela, para
## terem volume de qualquer lado. UV2.x dá a cada plano o seu desenho.
static func _flame_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers: Array[Vector3] = [Vector3(1.0, 1.1, 0.0), Vector3(0.6, 0.75, 0.5)]  # largura, altura, giro
	for layer in layers.size():
		for plane in 3:
			var angle := plane * PI / 3.0 + layers[layer].z
			var across := Vector3(cos(angle), 0.0, sin(angle)) * layers[layer].x / 2.0
			var bottom := 0.05
			var top := bottom + layers[layer].y
			var seed := float(layer * 3 + plane) * 0.137
			var corners: Array[Vector3] = [-across + Vector3.UP * bottom, across + Vector3.UP * bottom,
					across + Vector3.UP * top, -across + Vector3.UP * top]
			var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for i: int in [0, 1, 2, 0, 2, 3]:
				surface.set_uv(uvs[i])
				surface.set_uv2(Vector2(seed, 0.0))
				surface.set_normal(Vector3.UP)
				surface.add_vertex(corners[i])
	return surface.commit()
