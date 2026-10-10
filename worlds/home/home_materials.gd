class_name HomeMaterials
extends RefCounted
## Os materiais da casa (Fase 9.9), num lugar só: a casa e os móveis usam os
## mesmos, e cada um é criado uma vez.
##   - madeira: shader feito por código (home_wood.gdshader), sem textura;
##   - tijolo e concreto: texturas da ambientCG (CC0) que o projeto já tem;
##   - tecido e metal: cores com um relevo de ruído.
## Nada daqui conhece a cidade.

const AMBIENTCG: String = "res://assets/ambientcg/"
const WOOD_SHADER: Shader = preload("res://worlds/home/home_wood.gdshader")

static var _cache: Dictionary[String, Material] = {}


## Madeira: "planks" = tábuas com fresta (o piso); sem fresta para móveis.
static func wood(color: Color, planks: bool = false, roughness: float = 0.5) -> ShaderMaterial:
	var key := "wood|%s|%s|%.2f" % [color.to_html(), planks, roughness]
	if not _cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = WOOD_SHADER
		material.set_shader_parameter("base_color", color)
		material.set_shader_parameter("planks", planks)
		material.set_shader_parameter("rough", roughness)
		if not planks:
			# Móvel: veio mais comprido e quase sem diferença entre "tábuas".
			material.set_shader_parameter("plank_width", 0.5)
			material.set_shader_parameter("plank_length", 4.0)
			material.set_shader_parameter("variation", 0.05)
		_cache[key] = material
	return _cache[key]


## Textura da ambientCG projetada pela posição no mundo (triplanar):
## "meters" = tamanho de uma repetição.
static func pbr(folder: String, meters: float, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "pbr|%s|%.2f|%s" % [folder, meters, tint.to_html()]
	if not _cache.has(key):
		var base := "%s%s/%s_1K-JPG_" % [AMBIENTCG, folder, folder]
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(base + "Color.jpg")
		material.albedo_color = tint
		material.normal_enabled = true
		material.normal_texture = load(base + "NormalGL.jpg")
		material.roughness_texture = load(base + "Roughness.jpg")
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE / meters
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_cache[key] = material
	return _cache[key]


## Tecido (sofá, almofadas): cor fosca com uma trama de ruído no relevo.
static func fabric(color: Color) -> StandardMaterial3D:
	var key := "fabric|%s" % color.to_html()
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		material.normal_enabled = true
		material.normal_texture = _weave_normal()
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 6.0
		_cache[key] = material
	return _cache[key]


## Metal escuro (luminárias, pés, vigas).
static func metal(color: Color, roughness: float = 0.45) -> StandardMaterial3D:
	var key := "metal|%s|%.2f" % [color.to_html(), roughness]
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = 0.7
		material.roughness = roughness
		_cache[key] = material
	return _cache[key]


## Cor fosca simples.
static func matte(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var key := "matte|%s|%.2f" % [color.to_html(), roughness]
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_cache[key] = material
	return _cache[key]


## Algo que brilha (lâmpada, néon). "energy" > 1 acende o brilho (glow).
static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var key := "glow|%s|%.2f" % [color.to_html(), energy]
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		_cache[key] = material
	return _cache[key]


static func _weave_normal() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.08
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = 4.0
	texture.noise = noise
	return texture
