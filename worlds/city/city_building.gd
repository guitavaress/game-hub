class_name CityBuilding
extends Node3D
## Prédio de um jogo na cidade:
##   - bloco com o vão da porta recortado (CSG), com fachada realista (concreto
##     ou tijolo), janelas de vidro e faixas de néon na cor do bairro
##     (building_facade.gdshader);
##   - LOGO do jogo como letreiro acima da porta (ou o nome, se não houver logo);
##   - a CAPA do jogo num painel grande na fachada (vem do GameArt);
##   - um GamePortal no vão da porta.
##
## A porta fica na face +Z (a "frente"). Para virar o prédio, gire este nó.
## Preencha "game", "size", "accent_color" e "category_id" ANTES de adicionar
## o prédio à cena.
##
## Isto é DECORAÇÃO da cidade: toda a lógica de abrir o jogo está no GamePortal.

const PORTAL_SCENE: PackedScene = preload("res://components/game_portal/game_portal.tscn")
const FACADE_SHADER: Shader = preload("res://worlds/city/building_facade.gdshader")

## Vão da porta (largura, altura, profundidade), em metros.
const DOOR_WIDTH: float = 2.4
const DOOR_HEIGHT: float = 3.0
const DOOR_DEPTH: float = 1.6
## Letreiro (logo) acima da porta: tamanho máximo.
const LOGO_MAX_SIZE: Vector2 = Vector2(6.5, 1.8)
const LOGO_BOTTOM: float = 3.9
## Onde a capa começa (acima do letreiro) e as margens até as bordas.
const POSTER_BOTTOM: float = 6.2
const POSTER_TOP_MARGIN: float = 1.2
const POSTER_SIDE_MARGIN: float = 1.2
## Proporção da capa "em pé" da Steam (600x900), usada no placeholder.
const PORTRAIT_ASPECT: float = 600.0 / 900.0
## Hero (banner 1920x620 da Steam, sem logo): faixa larga no alto da fachada,
## como um outdoor. Com ele, o logo aparece uma vez só: sobre a porta.
const HERO_SIZE: Vector2 = Vector2(9.0, 9.0 * 620.0 / 1920.0)
const HERO_TOP_MARGIN: float = 0.9
const DARK_METAL: Color = Color(0.07, 0.075, 0.08)

## Estilos de parede (materiais PBR da ambientCG): pasta, tamanho da repetição
## em metros e um tom. Cada jogo sorteia um (sempre o mesmo para o mesmo jogo).
const WALL_STYLES: Array[Dictionary] = [
	{"folder": "Concrete034", "meters": 3.0, "tint": Color(0.82, 0.83, 0.85)},
	{"folder": "Concrete048", "meters": 3.0, "tint": Color(0.95, 0.93, 0.9)},
	{"folder": "Bricks097", "meters": 2.2, "tint": Color(0.9, 0.88, 0.86)},
]

var game: SteamGame
var size: Vector3 = Vector3(10.0, 14.0, 10.0)
## Cor do bairro: vira o néon e um leve tom na parede.
var accent_color: Color = Color.GRAY
## Categoria do jogo (define o som ambiente da porta).
var category_id: String = ""

var _poster: MeshInstance3D
var _poster_frame: MeshInstance3D
var _poster_material: StandardMaterial3D
var _poster_label: Label3D
var _walls_material: ShaderMaterial
## Filete de néon da moldura da porta (acompanha o dia e a noite).
var _door_neon_material: StandardMaterial3D
var _logo: Sprite3D
## true quando a fachada mostra o hero (e não a capa).
var _hero_mode: bool = false


func _ready() -> void:
	# O relógio da cidade (DayNight) acende as janelas de todo mundo nesse grupo.
	add_to_group("city_night")
	_build_body()
	_build_door_decoration()
	_build_sign()
	_build_poster()
	_build_portal()

	# Preferimos o hero; sem ele, a capa. Continuamos ouvindo o GameArt porque
	# as imagens podem chegar depois (download), ou chegar uma capa melhor (HD).
	GameArt.hero_ready.connect(_on_hero_ready)
	GameArt.art_ready.connect(_on_art_ready)
	var hero := GameArt.get_hero(game.app_id)
	if hero != null:
		_show_hero(hero)
	else:
		var texture := GameArt.get_art(game.app_id)
		if texture != null:
			_show_art(texture)


## Cor viva do néon, a partir da cor do bairro.
func neon_color() -> Color:
	return Color.from_hsv(accent_color.h, 0.7, 1.0)


func _build_body() -> void:
	# CSG = "somar e subtrair formas": caixa grande MENOS uma caixa no lugar da porta.
	var body := CSGCombiner3D.new()
	body.name = "Body"
	body.use_collision = true
	add_child(body)

	var walls := CSGBox3D.new()
	walls.size = size
	walls.position = Vector3(0.0, size.y / 2.0, 0.0)
	walls.material = _make_walls_material()
	body.add_child(walls)

	var doorway := CSGBox3D.new()
	doorway.operation = CSGShape3D.OPERATION_SUBTRACTION
	# 10 cm maior para baixo e para fora, para o recorte ficar limpo.
	doorway.size = Vector3(DOOR_WIDTH, DOOR_HEIGHT + 0.1, DOOR_DEPTH + 0.1)
	doorway.position = Vector3(0.0, (DOOR_HEIGHT - 0.1) / 2.0, _front_z() - DOOR_DEPTH / 2.0 + 0.05)
	doorway.material = CityDecor.pbr_material("Concrete034", 2.0, Color(0.35, 0.36, 0.38))
	body.add_child(doorway)


func _build_door_decoration() -> void:
	# "Porta" de luz no fundo do vão, na cor do bairro.
	var door_glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(DOOR_WIDTH, DOOR_HEIGHT)
	door_glow.mesh = quad
	door_glow.position = Vector3(0.0, DOOR_HEIGHT / 2.0, _front_z() - DOOR_DEPTH + 0.01)
	door_glow.material_override = _make_glow_material(neon_color().lerp(Color.WHITE, 0.35), 1.6)
	add_child(door_glow)

	# Moldura de metal escuro, com um filete de néon por dentro.
	var metal := _make_metal_material()
	var neon := _make_glow_material(neon_color(), CityDecor.NEON_DAY)
	_door_neon_material = neon
	var post_size := Vector3(0.22, DOOR_HEIGHT + 0.22, 0.25)
	var post_x := DOOR_WIDTH / 2.0 + 0.11
	var z := _front_z() + 0.08
	_add_box(Vector3(-post_x, post_size.y / 2.0, z), post_size, metal)
	_add_box(Vector3(post_x, post_size.y / 2.0, z), post_size, metal)
	_add_box(Vector3(0.0, DOOR_HEIGHT + 0.11, z), Vector3(DOOR_WIDTH + 0.66, 0.22, 0.25), metal)
	_add_box(Vector3(-DOOR_WIDTH / 2.0 + 0.02, DOOR_HEIGHT / 2.0, z + 0.02), Vector3(0.04, DOOR_HEIGHT, 0.04), neon)
	_add_box(Vector3(DOOR_WIDTH / 2.0 - 0.02, DOOR_HEIGHT / 2.0, z + 0.02), Vector3(0.04, DOOR_HEIGHT, 0.04), neon)
	_add_box(Vector3(0.0, DOOR_HEIGHT - 0.02, z + 0.02), Vector3(DOOR_WIDTH, 0.04, 0.04), neon)


## Letreiro acima da porta: o LOGO do jogo (PNG transparente); se o jogo não
## tiver logo, o nome escrito com a fonte de letreiro.
func _build_sign() -> void:
	var logo_texture := GameArt.get_logo(game.app_id)
	if logo_texture != null:
		_logo = Sprite3D.new()
		_logo.name = "Sign"
		_logo.texture = logo_texture
		# Cabe dentro de LOGO_MAX_SIZE sem distorcer.
		var width := float(logo_texture.get_width())
		var height := float(logo_texture.get_height())
		_logo.pixel_size = minf(LOGO_MAX_SIZE.x / width, LOGO_MAX_SIZE.y / height)
		_logo.position = Vector3(0.0, LOGO_BOTTOM + height * _logo.pixel_size / 2.0, _front_z() + 0.06)
		_logo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		add_child(_logo)
		return

	var name_sign := Label3D.new()
	name_sign.name = "Sign"
	name_sign.text = game.name.to_upper()
	name_sign.font = HubFonts.SIGN
	name_sign.font_size = 128
	name_sign.pixel_size = 0.006
	name_sign.outline_size = 0
	name_sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_sign.width = LOGO_MAX_SIZE.x / name_sign.pixel_size
	name_sign.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_sign.position = Vector3(0.0, LOGO_BOTTOM, _front_z() + 0.06)
	add_child(name_sign)


func _build_poster() -> void:
	# Moldura de metal escuro atrás da capa.
	_poster_frame = MeshInstance3D.new()
	_poster_frame.mesh = QuadMesh.new()
	_poster_frame.material_override = _make_metal_material()
	add_child(_poster_frame)

	# A capa em si. "Unshaded" = não é afetada por luz e sombra, como um painel
	# iluminado por dentro.
	_poster_material = StandardMaterial3D.new()
	_poster_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_poster_material.albedo_color = Color(0.1, 0.1, 0.12)
	_poster = MeshInstance3D.new()
	_poster.name = "Poster"
	_poster.mesh = QuadMesh.new()
	_poster.material_override = _poster_material
	add_child(_poster)

	# Placeholder: o nome do jogo escrito no painel, até a capa chegar.
	_poster_label = Label3D.new()
	_poster_label.text = game.name
	_poster_label.font = HubFonts.SIGN
	_poster_label.font_size = 128
	_poster_label.pixel_size = 0.006
	_poster_label.outline_size = 0
	_poster_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_poster_label.modulate = Color(0.85, 0.87, 0.9)
	_poster.add_child(_poster_label)

	_resize_poster(PORTRAIT_ASPECT)


## Ajusta o painel da capa para a proporção da imagem (largura / altura),
## ocupando o máximo do espaço livre da fachada.
func _resize_poster(aspect: float) -> void:
	var free_width := size.x - POSTER_SIDE_MARGIN * 2.0
	var free_height := size.y - POSTER_TOP_MARGIN - POSTER_BOTTOM
	var poster_size := Vector2(free_width, free_width / aspect)
	if poster_size.y > free_height:
		poster_size = Vector2(free_height * aspect, free_height)

	var center := Vector3(0.0, POSTER_BOTTOM + free_height / 2.0, _front_z() + 0.05)
	(_poster.mesh as QuadMesh).size = poster_size
	_poster.position = center
	(_poster_frame.mesh as QuadMesh).size = poster_size + Vector2(0.3, 0.3)
	_poster_frame.position = center - Vector3(0.0, 0.0, 0.01)

	_poster_label.width = (poster_size.x - 0.6) / _poster_label.pixel_size
	_poster_label.position = Vector3(0.0, 0.0, 0.01)


## Capa em pé (quando não há hero). A capa já traz o logo do jogo, então o
## letreiro de logo sobre a porta some, para não repetir.
func _show_art(texture: Texture2D) -> void:
	if _hero_mode:
		return
	_poster_material.albedo_texture = texture
	_poster_material.albedo_color = Color.WHITE
	_poster_label.visible = false
	if _logo != null:
		_logo.visible = false
	_resize_poster(float(texture.get_width()) / float(texture.get_height()))


## Hero: faixa larga no alto da fachada, e o logo (uma vez só) sobre a porta.
func _show_hero(texture: Texture2D) -> void:
	_hero_mode = true
	_poster_material.albedo_texture = texture
	_poster_material.albedo_color = Color.WHITE
	_poster_label.visible = false
	if _logo != null:
		_logo.visible = true
	var center := Vector3(0.0, size.y - HERO_TOP_MARGIN - HERO_SIZE.y / 2.0, _front_z() + 0.05)
	(_poster.mesh as QuadMesh).size = HERO_SIZE
	_poster.position = center
	(_poster_frame.mesh as QuadMesh).size = HERO_SIZE + Vector2(0.3, 0.3)
	_poster_frame.position = center - Vector3(0.0, 0.0, 0.01)


func _on_art_ready(app_id: int, texture: Texture2D) -> void:
	if app_id == game.app_id:
		_show_art(texture)


func _on_hero_ready(app_id: int, texture: Texture2D) -> void:
	if app_id == game.app_id:
		_show_hero(texture)


func _build_portal() -> void:
	var portal := PORTAL_SCENE.instantiate() as GamePortal
	portal.name = "GamePortal"
	portal.app_id = game.app_id
	portal.display_name = game.name
	portal.look_size = Vector3(size.x, size.y, 1.0)  # olhar para a fachada inteira mostra o nome
	portal.position = Vector3(0.0, 0.0, _front_z())
	add_child(portal)

	# Som ambiente do bairro, saindo da porta.
	for emitter in CategoryAmbience.create(category_id):
		emitter.position = Vector3(0.0, 2.0, 0.5)
		portal.add_child(emitter)


## 0 = dia, 1 = noite: à noite, parte das janelas acende, o néon fica mais
## forte e o logo brilha um pouco.
func set_night(night: float) -> void:
	var smooth_night := smoothstep(0.15, 0.85, night)
	_walls_material.set_shader_parameter("night", smooth_night)
	# Néon: mesma regra das fachadas e dos letreiros (0,15 de dia, 3,2 à noite).
	if _door_neon_material != null:
		_door_neon_material.emission_energy_multiplier = CityDecor.neon_energy(smooth_night)
	if _logo != null:
		var glow := 1.0 + 0.6 * night
		_logo.modulate = Color(glow, glow, glow)


## Fachada: material realista sorteado (sempre o mesmo para o mesmo jogo),
## janelas e néon (tudo no building_facade.gdshader).
func _make_walls_material() -> ShaderMaterial:
	var rng := RandomNumberGenerator.new()
	rng.seed = game.app_id
	var style: Dictionary = WALL_STYLES[rng.randi_range(0, WALL_STYLES.size() - 1)]
	var textures := CityDecor.pbr_textures(style["folder"])

	_walls_material = ShaderMaterial.new()
	_walls_material.shader = FACADE_SHADER
	_walls_material.set_shader_parameter("wall_albedo", textures["albedo"])
	_walls_material.set_shader_parameter("wall_normal", textures["normal"])
	_walls_material.set_shader_parameter("wall_roughness", textures["roughness"])
	_walls_material.set_shader_parameter("texture_size", style["meters"])
	# Um toque da cor do bairro na parede (bem de leve).
	var tint: Color = (style["tint"] as Color).lerp(accent_color, 0.1)
	_walls_material.set_shader_parameter("wall_tint", tint)
	_walls_material.set_shader_parameter("neon_color", neon_color())
	_walls_material.set_shader_parameter("building_height", size.y)
	_walls_material.set_shader_parameter("seed", float(game.app_id % 997))
	return _walls_material


## A fachada (face da frente) fica em z = metade da profundidade.
func _front_z() -> float:
	return size.z / 2.0


## Caixa só visual (sem colisão).
func _add_box(center: Vector3, box_size: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	box.mesh = mesh
	box.position = center
	box.material_override = material
	add_child(box)


func _make_metal_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = DARK_METAL
	material.metallic = 0.8
	material.roughness = 0.35
	return material


## Material que "brilha" (emite luz própria).
func _make_glow_material(glow_color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = glow_color
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = energy
	return material
