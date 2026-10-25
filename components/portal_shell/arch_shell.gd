class_name ArchShell
extends PortalShell
## Casca de ARCO (Fase 7.4): um arco de pedra simples na frente do espaço, com
## a porta do jogo na passagem. Prova de que o GamePortal não depende de prédio
## e semente para biomas (portão de vila, entrada de caverna...).
##
## Peças: dois pilares e uma viga, todos sólidos (o jogador não atravessa), um
## filete de néon do bairro embaixo da viga e o nome do jogo em cima.
## Nenhum bairro usa ainda: para experimentar, ponha shell = "arch" num perfil
## (profiles/districts/*.tres).

## Vão livre da passagem (largura e altura), em metros. A área de entrada do
## GamePortal (2,0 x 2,6) cabe com folga.
const OPENING: Vector2 = Vector2(2.4, 3.2)
const PILLAR_WIDTH: float = 0.9
const LINTEL_HEIGHT: float = 0.9
## Espessura do arco (de frente para trás).
const DEPTH: float = 1.6
const STONE_COLOR: Color = Color(0.42, 0.40, 0.37)
const NAME_HEIGHT: float = 0.45
## Brilho do néon de dia e de noite.
const NEON_DAY: float = 0.3
const NEON_NIGHT: float = 3.0
## Quanto o filete fica mais forte no fim da carga da porta (como a moldura do prédio).
const CHARGE_BOOST: float = 3.0
## Placa com a arte do jogo, em cima da viga (frente do arco). O hero (1920x620)
## ocupa a largura do arco; a capa em pé (600x900) fica limitada por esta altura.
const POSTER_GAP: float = 0.1
const POSTER_MAX_HEIGHT: float = 2.0
const POSTER_NAME_GAP: float = 0.3

var _neon_material: StandardMaterial3D
var _poster: MeshInstance3D
var _poster_material: StandardMaterial3D
var _name_label: Label3D
## true quando a placa mostra o hero (e não a capa).
var _hero_mode: bool = false
var _night: float = 0.0
var _charge: float = 0.0


func _ready() -> void:
	add_to_group("city_night")
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE_COLOR
	stone.roughness = 0.95
	var front := size.z / 2.0
	var middle_z := front - DEPTH / 2.0
	var outer_width := OPENING.x + 2.0 * PILLAR_WIDTH
	var pillar_x := OPENING.x / 2.0 + PILLAR_WIDTH / 2.0

	var body := StaticBody3D.new()
	body.name = "Stone"
	add_child(body)
	for side in [-1.0, 1.0]:
		_add_block(body, Vector3(side * pillar_x, OPENING.y / 2.0, middle_z),
				Vector3(PILLAR_WIDTH, OPENING.y, DEPTH), stone)
	_add_block(body, Vector3(0.0, OPENING.y + LINTEL_HEIGHT / 2.0, middle_z),
			Vector3(outer_width, LINTEL_HEIGHT, DEPTH), stone)

	# Filete de néon na borda de baixo da viga, na frente.
	_neon_material = StandardMaterial3D.new()
	_neon_material.albedo_color = neon_color()
	_neon_material.emission_enabled = true
	_neon_material.emission = neon_color()
	_neon_material.emission_energy_multiplier = NEON_DAY
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(OPENING.x, 0.06, 0.06)
	strip.mesh = strip_mesh
	strip.material_override = _neon_material
	strip.position = Vector3(0.0, OPENING.y - 0.03, front + 0.03)
	add_child(strip)

	var label := Label3D.new()
	label.name = "Name"
	label.text = game.name if game != null else ""
	label.modulate = neon_color()
	label.pixel_size = 0.01
	label.font_size = 48
	label.width = outer_width * 100.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector3(0.0, OPENING.y + LINTEL_HEIGHT + NAME_HEIGHT, front)
	add_child(label)
	_name_label = label

	_build_poster(front)
	build_portal()

	# Preferimos o hero; sem ele, a capa. As imagens podem chegar depois.
	if game != null:
		GameArt.hero_ready.connect(_on_hero_ready)
		GameArt.art_ready.connect(_on_art_ready)
		var hero := GameArt.get_hero(game.app_id)
		if hero != null:
			_show_hero(hero)
		else:
			var art := GameArt.get_art(game.app_id)
			if art != null:
				_show_art(art)


## Alvo "olhável": o arco inteiro (e não o terreno todo, como num prédio).
func portal_look_size() -> Vector3:
	return Vector3(OPENING.x + 2.0 * PILLAR_WIDTH, OPENING.y + LINTEL_HEIGHT, 1.0)


## 0 = dia, 1 = noite: o néon fica mais forte à noite.
func set_night(night: float) -> void:
	_night = clampf(night, 0.0, 1.0)
	_apply_neon()


## Carregando a porta: o filete ganha força (soma-se ao dia/noite).
func _on_portal_charge(ratio: float) -> void:
	_charge = clampf(ratio, 0.0, 1.0)
	_apply_neon()


## O brilho do filete: o de dia/noite vezes até CHARGE_BOOST no fim da carga.
func _apply_neon() -> void:
	if _neon_material != null:
		var base := lerpf(NEON_DAY, NEON_NIGHT, _night)
		_neon_material.emission_energy_multiplier = base * (1.0 + (CHARGE_BOOST - 1.0) * _charge)


## A placa começa escondida; aparece quando chega a arte. Decoração: sem colisão.
func _build_poster(front: float) -> void:
	_poster_material = StandardMaterial3D.new()
	_poster_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_poster = MeshInstance3D.new()
	_poster.name = "Poster"
	_poster.mesh = QuadMesh.new()
	_poster.material_override = _poster_material
	_poster.visible = false
	_poster.position = Vector3(0.0, OPENING.y + LINTEL_HEIGHT + POSTER_GAP, front + 0.03)
	add_child(_poster)


## Hero: a faixa larga, na largura do arco.
func _show_hero(texture: Texture2D) -> void:
	_hero_mode = true
	_set_poster(texture, Vector2(OPENING.x + 2.0 * PILLAR_WIDTH, 0.0), texture.get_width(), texture.get_height())


## Capa em pé (só quando não há hero).
func _show_art(texture: Texture2D) -> void:
	if _hero_mode:
		return
	_set_poster(texture, Vector2(0.0, POSTER_MAX_HEIGHT), texture.get_width(), texture.get_height())


## Ajusta o tamanho (pela proporção da imagem) e põe o nome acima da placa.
## fixed: x > 0 fixa a largura; y > 0 fixa a altura.
func _set_poster(texture: Texture2D, fixed: Vector2, w: int, h: int) -> void:
	var aspect := float(w) / float(maxi(h, 1))
	var quad_size := Vector2(fixed.x, fixed.x / aspect) if fixed.x > 0.0 else Vector2(fixed.y * aspect, fixed.y)
	(_poster.mesh as QuadMesh).size = quad_size
	_poster.position.y = OPENING.y + LINTEL_HEIGHT + POSTER_GAP + quad_size.y / 2.0
	_poster_material.albedo_texture = texture
	_poster_material.albedo_color = Color.WHITE
	_poster.visible = true
	if _name_label != null:
		_name_label.position.y = OPENING.y + LINTEL_HEIGHT + POSTER_GAP + quad_size.y + POSTER_NAME_GAP


## A imagem da placa (null se ainda não há).
func get_art_texture() -> Texture2D:
	return _poster_material.albedo_texture if _poster_material != null else null


func _on_art_ready(app_id: int, texture: Texture2D) -> void:
	if game != null and app_id == game.app_id:
		_show_art(texture)


func _on_hero_ready(app_id: int, texture: Texture2D) -> void:
	if game != null and app_id == game.app_id:
		_show_hero(texture)


## Um bloco de pedra que se vê e que bloqueia o jogador.
func _add_block(body: StaticBody3D, center: Vector3, block_size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = block_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = center
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = block_size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
