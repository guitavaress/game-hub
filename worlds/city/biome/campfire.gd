class_name Campfire
extends Node3D
## Uma fogueira de pedra e lenha (Fase 17.7; o modelo é do Blender desde a
## 17.7.1: tools/blender/gerar_fogueira.py): o anel de pedras com fuligem, a
## cama de cinza e terra queimada, a lenha rachada em pirâmide, a brasa que
## brilha nas rachas, as chamas animadas (campfire_flame.gdshader, planos
## cruzados que somam luz) e uma luz quente com sombra. Acende à noite (grupo
## city_night) e fica apagada de dia. O chão da fogueira é o y = 0 deste nó.

const FLAME_SHADER: Shader = preload("res://worlds/city/biome/campfire_flame.gdshader")
const MODEL: String = "campfire"
## Mais laranja que o lampião: o fogo é a poça mais quente da trilha.
const LIGHT_COLOR: Color = Color(1.0, 0.56, 0.24)
const LIGHT_ENERGY: float = 3.2
const LIGHT_RANGE: float = 9.0
const LIGHT_HEIGHT: float = 0.75
## A sombra some antes da luz (economia: só quem está perto vê os bancos fazendo sombra).
const SHADOW_FADE: float = 30.0
const EMBER_ENERGY: float = 2.6
## A cinza (17.10): a cama de cinza do modelo lia como areia clara em cima das
## tábuas do mirante. Aqui ela escurece e esfria (a terra queimada de verdade),
## e o disco encolhe para ficar por baixo das pedras: o raio cai de 0,84 m (do
## gerar_fogueira.py) para 0,66 m, e o anel de pedras, a 0,55 m do meio com
## pedras de 0,2 a 0,28 m, cobre a borda.
const ASH_TINT: Color = Color(0.3, 0.29, 0.28)
const ASH_SCALE: float = 0.78

var light: OmniLight3D
var embers: StandardMaterial3D
var flames: Node3D
var _flame_material: ShaderMaterial


## Monta a fogueira. "stone": o material das pedras (que usa a cor dos
## vértices do modelo); "fade_begin" e "fade_length": de onde a luz começa a
## sumir de longe (as mesmas dos lampiões da trilha).
func build(stone: Material, fade_begin: float, fade_length: float) -> void:
	name = "Campfire"
	add_to_group("city_night")
	var batch := TrailProps.Batch.new()
	var ash := TrailModels.stretched(TrailModels.mesh(MODEL, "ash"), Vector3(ASH_SCALE, 1.0, ASH_SCALE))
	batch.add(ash, Transform3D.IDENTITY, TrailModels.vertex_only(1.0, ASH_TINT))
	batch.add(TrailModels.mesh(MODEL, "stone"), Transform3D.IDENTITY, stone)
	batch.add(TrailModels.mesh(MODEL, "wood"), Transform3D.IDENTITY, TrailModels.own_material(MODEL, "wood"))
	# A brasa: a textura do modelo, com o brilho das rachas aceso à noite.
	embers = (TrailModels.own_material(MODEL, "embers") as StandardMaterial3D).duplicate()
	embers.emission_enabled = true
	embers.emission = Color.WHITE
	batch.add(TrailModels.mesh(MODEL, "embers"), Transform3D.IDENTITY, embers)
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
