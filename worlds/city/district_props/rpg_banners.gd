class_name RpgBanners
extends Node3D
## Bairro RPG e Fantasia: um estandarte de tecido escuro (1 x 3 m) preso em cada
## poste do quarteirão, como numa cidade medieval. O tecido balança ao vento
## (feito no shader, banner_wind.gdshader) e tem um símbolo na cor do bairro:
## espada, escudo ou losango, desenhado por código (sem imagens).
##
## Todos os estandartes do quarteirão são UMA MultiMesh (um só desenho), e os
## suportes de ferro são outra. De noite, o símbolo brilha e o tecido clareia
## perto da barra (uma luz "de baixo para cima" falsa, feita no shader).
##
## O estandarte fica virado para o mesmo lado do braço do poste: para fora do
## quarteirão, na diagonal, então as duas ruas da esquina enxergam ele.

const SHADER: Shader = preload("res://worlds/city/district_props/banner_wind.gdshader")

## Tamanho do estandarte (m) e onde fica no poste.
const BANNER_SIZE: Vector2 = Vector2(1.0, 3.0)
const BANNER_TOP: float = 4.9        # altura da barra (a lâmpada fica em 5,6)
const BANNER_OFFSET: float = 0.16    # distância do poste até o tecido
## Divisões do tecido na altura: o vento só entorta se houver vértices no meio.
const CLOTH_ROWS: int = 12
## O tecido é o tom do bairro bem escurecido (0 = preto, 1 = a cor inteira).
const CLOTH_DARKNESS: float = 0.3

## Atlas de símbolos: 3 células de 64 x 192 px, lado a lado.
const CELL_SIZE: Vector2i = Vector2i(64, 192)
const SYMBOL_COUNT: int = 3
const SYMBOL_SWORD: int = 0
const SYMBOL_SHIELD: int = 1
const SYMBOL_DIAMOND: int = 2

## Os prédios e o quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []
var cell: Vector2i = Vector2i.ZERO

var _material: ShaderMaterial
var _banners: MultiMeshInstance3D

## Atlas já desenhado (o mesmo para todos os estandartes), por cor.
static var _shared_atlas: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	add_to_group("city_night")
	var color := GameCategories.get_category_color("rpg")
	var neon := GameCategories.get_neon_color("rpg")

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("symbols", _symbol_atlas(neon))
	_material.set_shader_parameter("cloth_color", color * CLOTH_DARKNESS)
	_material.set_shader_parameter("trim_color", neon)

	var lights := DistrictProps.lights_in_block(get_parent(), cell)
	var cloth := QuadMesh.new()
	cloth.size = BANNER_SIZE
	cloth.subdivide_depth = CLOTH_ROWS
	var banners := MultiMesh.new()
	banners.transform_format = MultiMesh.TRANSFORM_3D
	banners.use_custom_data = true  # x = símbolo, y = fase do vento
	banners.mesh = cloth
	banners.instance_count = lights.size()

	# Cada suporte é uma barra de ferro no alto do tecido, presa ao poste.
	var bars := MultiMesh.new()
	bars.transform_format = MultiMesh.TRANSFORM_3D
	bars.mesh = _bracket_mesh()
	bars.instance_count = lights.size()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var first_symbol := posmod(cell.x + cell.y * 2, SYMBOL_COUNT)
	for i in lights.size():
		var light := lights[i]
		# O poste olha (-Z) para fora do quarteirão. Giramos 180° para a frente
		# do tecido (+Z) ficar do mesmo lado.
		var facing := light.transform.basis * Basis(Vector3.UP, PI)
		var pole := light.position
		var cloth_center := pole + light.transform.basis * Vector3(
				0.0, BANNER_TOP - BANNER_SIZE.y / 2.0, -BANNER_OFFSET)
		banners.set_instance_transform(i, Transform3D(facing, cloth_center))
		# Fase do vento: cada estandarte numa fatia do ciclo (com um sorteio dentro
		# dela), assim nunca dois balançam exatamente juntos.
		var phase := TAU * (i + rng.randf_range(0.0, 0.7)) / maxi(lights.size(), 1)
		banners.set_instance_custom_data(i, Color((first_symbol + i) % SYMBOL_COUNT, phase, 0.0, 0.0))
		var bar_spot := pole + light.transform.basis * Vector3(0.0, BANNER_TOP + 0.03, 0.0)
		bars.set_instance_transform(i, Transform3D(light.transform.basis, bar_spot))

	_banners = MultiMeshInstance3D.new()
	_banners.name = "Banners"
	_banners.multimesh = banners
	_banners.material_override = _material
	_banners.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_banners)

	var brackets := MultiMeshInstance3D.new()
	brackets.name = "Brackets"
	brackets.multimesh = bars
	var iron := StandardMaterial3D.new()
	iron.albedo_color = StreetLight.METAL_COLOR
	iron.metallic = 0.8
	iron.roughness = 0.35
	brackets.material_override = iron
	brackets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(brackets)
	set_night(0.0)


## Acende com os postes (o brilho e a luz "de baixo" só aparecem à noite).
func set_night(night: float) -> void:
	_material.set_shader_parameter("night", smoothstep(0.3, 0.8, night))


## Quantos estandartes tem o quarteirão (para os testes).
func get_banner_count() -> int:
	return _banners.multimesh.instance_count if _banners != null else 0


## Suporte de ferro: uma barra no alto do tecido e uma haste até o poste.
## Fica no espaço do poste (a frente dele é -Z).
func _bracket_mesh() -> ArrayMesh:
	var bar := BoxMesh.new()
	bar.size = Vector3(BANNER_SIZE.x + 0.14, 0.05, 0.05)
	var stub := BoxMesh.new()
	stub.size = Vector3(0.05, 0.05, BANNER_OFFSET + 0.06)
	var builder := SurfaceTool.new()
	builder.append_from(bar, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -BANNER_OFFSET)))
	builder.append_from(stub, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -(BANNER_OFFSET + 0.06) / 2.0)))
	return builder.commit()


# --- Símbolos ----------------------------------------------------------------


## Atlas com os três símbolos (espada, escudo e losango) na cor do bairro.
## Desenhado uma vez só e dividido entre todos os estandartes.
static func _symbol_atlas(symbol_color: Color) -> Texture2D:
	var key := symbol_color.to_html()
	if _shared_atlas.has(key):
		return _shared_atlas[key]
	var image := Image.create(CELL_SIZE.x * SYMBOL_COUNT, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	# Fundo transparente já na cor do símbolo (a borda suave não fica escura).
	image.fill(Color(symbol_color, 0.0))
	for symbol in SYMBOL_COUNT:
		# Os símbolos ficam no meio das células, de y = 20 a y = 145.
		for y in range(16, 150):
			for x in range(4, CELL_SIZE.x - 4):
				var alpha := clampf(0.5 - _symbol_distance(symbol, float(x) + 0.5, float(y) + 0.5), 0.0, 1.0)
				if alpha > 0.0:
					image.set_pixel(symbol * CELL_SIZE.x + x, y, Color(symbol_color, alpha))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_shared_atlas[key] = texture
	return texture


## Distância (em pixels) do ponto até a borda do símbolo: negativa dentro dele.
## O centro da célula é x = 32.
static func _symbol_distance(symbol: int, x: float, y: float) -> float:
	match symbol:
		SYMBOL_SWORD:
			return _sword_distance(x - 32.0, y)
		SYMBOL_SHIELD:
			return _shield_distance(x - 32.0, y)
	return _diamond_distance(x - 32.0, y)


## Espada em pé: lâmina com ponta, guarda, cabo e pomo.
static func _sword_distance(x: float, y: float) -> float:
	# Lâmina: 10 px de largura, com a ponta afinando nos primeiros 16 px.
	var blade_half := 5.0 * clampf((y - 22.0) / 16.0, 0.0, 1.0)
	var blade := maxf(absf(x) - blade_half, maxf(22.0 - y, y - 104.0))
	var guard := _box_distance(x, y - 108.0, 19.0, 4.0)
	var grip := _box_distance(x, y - 122.0, 3.0, 11.0)
	var pommel := Vector2(x, y - 138.0).length() - 6.0
	return minf(minf(blade, guard), minf(grip, pommel))


## Escudo: contorno grosso, com uma cruz dentro.
static func _shield_distance(x: float, y: float) -> float:
	var outer := _shield_outline(x, y)
	var ring := maxf(outer, -outer - 5.0)
	var cross := minf(_box_distance(x, y - 62.0, 2.5, 34.0), _box_distance(x, y - 56.0, 15.0, 2.5))
	# A cruz só vale dentro do escudo.
	return minf(ring, maxf(cross, outer + 4.0))


## Contorno de um escudo de brasão: topo reto, lados retos e a base em ponta.
static func _shield_outline(x: float, y: float) -> float:
	var half_width := 24.0
	if y > 70.0:
		half_width = 24.0 * (1.0 - pow((y - 70.0) / 62.0, 1.7))
	return maxf(absf(x) - half_width, maxf(30.0 - y, (y - 132.0) * 0.8))


## Losango com um losango menor dentro (só o contorno + miolo cheio).
static func _diamond_distance(x: float, y: float) -> float:
	var outer := _diamond_shape(x, y - 82.0, 24.0, 52.0)
	var ring := maxf(outer, -outer - 5.0)
	var core := _diamond_shape(x, y - 82.0, 10.0, 22.0)
	return minf(ring, core)


## Distância aproximada até a borda de um losango (metade da largura a, da altura b).
static func _diamond_shape(x: float, y: float, a: float, b: float) -> float:
	return (absf(x) / a + absf(y) / b - 1.0) / sqrt(1.0 / (a * a) + 1.0 / (b * b))


## Distância até a borda de um retângulo centrado na origem (metades hx, hy).
static func _box_distance(x: float, y: float, hx: float, hy: float) -> float:
	var outside := Vector2(maxf(absf(x) - hx, 0.0), maxf(absf(y) - hy, 0.0)).length()
	return outside + minf(maxf(absf(x) - hx, absf(y) - hy), 0.0)
