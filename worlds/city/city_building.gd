class_name CityBuilding
extends Node3D
## Prédio de um jogo na cidade:
##   - bloco com o vão da porta recortado (CSG), moldura e "porta" brilhante;
##   - placa com o nome logo acima da porta;
##   - a CAPA do jogo num painel grande na fachada (vem do GameArt);
##   - um GamePortal no vão da porta.
##
## A porta fica na face +Z (a "frente"). Para virar o prédio, gire este nó.
## Preencha "game", "size" e "color" ANTES de adicionar o prédio à cena.
##
## Isto é DECORAÇÃO da cidade: toda a lógica de abrir o jogo está no GamePortal.

const PORTAL_SCENE: PackedScene = preload("res://components/game_portal/game_portal.tscn")

## Vão da porta (largura, altura, profundidade), em metros.
const DOOR_WIDTH: float = 2.4
const DOOR_HEIGHT: float = 3.0
const DOOR_DEPTH: float = 1.6
## Onde a capa começa (acima da placa com o nome) e as margens até as bordas.
const POSTER_BOTTOM: float = 6.0
const POSTER_TOP_MARGIN: float = 0.8
const POSTER_SIDE_MARGIN: float = 1.0
## Proporção da capa "em pé" da Steam (600x900), usada no placeholder.
const PORTRAIT_ASPECT: float = 600.0 / 900.0

var game: SteamGame
var size: Vector3 = Vector3(10.0, 14.0, 10.0)
var color: Color = Color.GRAY

var _poster: MeshInstance3D
var _poster_frame: MeshInstance3D
var _poster_material: StandardMaterial3D
var _poster_label: Label3D


func _ready() -> void:
	_build_body()
	_build_door_decoration()
	_build_name_sign()
	_build_poster()
	_build_portal()

	var texture := GameArt.get_art(game.app_id)
	if texture != null:
		_show_art(texture)
	else:
		# Ainda não temos a capa: fica o placeholder até o download terminar.
		GameArt.art_ready.connect(_on_art_ready)


func _build_body() -> void:
	# CSG = "somar e subtrair formas": caixa grande MENOS uma caixa no lugar da porta.
	var body := CSGCombiner3D.new()
	body.name = "Body"
	body.use_collision = true
	add_child(body)

	var walls := CSGBox3D.new()
	walls.size = size
	walls.position = Vector3(0.0, size.y / 2.0, 0.0)
	walls.material = _make_material(color)
	body.add_child(walls)

	var doorway := CSGBox3D.new()
	doorway.operation = CSGShape3D.OPERATION_SUBTRACTION
	# 10 cm maior para baixo e para fora, para o recorte ficar limpo.
	doorway.size = Vector3(DOOR_WIDTH, DOOR_HEIGHT + 0.1, DOOR_DEPTH + 0.1)
	doorway.position = Vector3(0.0, (DOOR_HEIGHT - 0.1) / 2.0, _front_z() - DOOR_DEPTH / 2.0 + 0.05)
	doorway.material = _make_material(color.darkened(0.35))  # paredes internas do vão
	body.add_child(doorway)


func _build_door_decoration() -> void:
	# "Porta" brilhante no fundo do vão.
	var door_glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(DOOR_WIDTH, DOOR_HEIGHT)
	door_glow.mesh = quad
	door_glow.position = Vector3(0.0, DOOR_HEIGHT / 2.0, _front_z() - DOOR_DEPTH + 0.01)
	door_glow.material_override = _make_glow_material(Color("3fa9f5"), 1.5)
	add_child(door_glow)

	# Moldura: dois pilares e uma viga.
	var frame_material := _make_glow_material(Color("ffb347"), 0.8)
	var post_size := Vector3(0.3, DOOR_HEIGHT + 0.3, 0.3)
	var post_x := DOOR_WIDTH / 2.0 + 0.15
	var z := _front_z() + 0.1
	_add_box(Vector3(-post_x, post_size.y / 2.0, z), post_size, frame_material)
	_add_box(Vector3(post_x, post_size.y / 2.0, z), post_size, frame_material)
	_add_box(Vector3(0.0, DOOR_HEIGHT + 0.15, z), Vector3(DOOR_WIDTH + 0.9, 0.3, 0.3), frame_material)


func _build_name_sign() -> void:
	var name_sign := Label3D.new()
	name_sign.name = "Sign"
	name_sign.text = game.name
	name_sign.font_size = 128      # resolução do texto (mais alto = mais nítido)
	name_sign.pixel_size = 0.0055  # metros por pixel: 128 x 0,0055 = ~0,7 m de altura
	name_sign.outline_size = 24
	name_sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_sign.width = (size.x - 1.0) / name_sign.pixel_size  # largura máxima, em pixels
	name_sign.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_sign.position = Vector3(0.0, DOOR_HEIGHT + 0.6, _front_z() + 0.05)
	add_child(name_sign)


func _build_poster() -> void:
	# Moldura escura atrás da capa.
	_poster_frame = MeshInstance3D.new()
	_poster_frame.mesh = QuadMesh.new()
	_poster_frame.material_override = _make_material(Color(0.08, 0.08, 0.1))
	add_child(_poster_frame)

	# A capa em si. "Unshaded" = não é afetada por luz e sombra, como um letreiro.
	_poster_material = StandardMaterial3D.new()
	_poster_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_poster_material.albedo_color = color.darkened(0.55)
	_poster = MeshInstance3D.new()
	_poster.name = "Poster"
	_poster.mesh = QuadMesh.new()
	_poster.material_override = _poster_material
	add_child(_poster)

	# Placeholder: o nome do jogo escrito no painel, até a capa chegar.
	_poster_label = Label3D.new()
	_poster_label.text = game.name
	_poster_label.font_size = 128
	_poster_label.pixel_size = 0.006
	_poster_label.outline_size = 0
	_poster_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_poster_label.modulate = color.lightened(0.6)
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

	var center := Vector3(0.0, POSTER_BOTTOM + free_height / 2.0, _front_z() + 0.03)
	(_poster.mesh as QuadMesh).size = poster_size
	_poster.position = center
	(_poster_frame.mesh as QuadMesh).size = poster_size + Vector2(0.4, 0.4)
	_poster_frame.position = center - Vector3(0.0, 0.0, 0.01)

	_poster_label.width = (poster_size.x - 0.6) / _poster_label.pixel_size
	_poster_label.position = Vector3(0.0, 0.0, 0.01)


func _show_art(texture: Texture2D) -> void:
	_poster_material.albedo_texture = texture
	_poster_material.albedo_color = Color.WHITE
	_poster_label.visible = false
	_resize_poster(float(texture.get_width()) / float(texture.get_height()))


func _on_art_ready(app_id: int, texture: Texture2D) -> void:
	if app_id == game.app_id:
		_show_art(texture)
		GameArt.art_ready.disconnect(_on_art_ready)


func _build_portal() -> void:
	var portal := PORTAL_SCENE.instantiate() as GamePortal
	portal.name = "GamePortal"
	portal.app_id = game.app_id
	portal.display_name = game.name
	portal.look_size = Vector3(size.x, size.y, 1.0)  # olhar para a fachada inteira mostra o nome
	portal.position = Vector3(0.0, 0.0, _front_z())
	add_child(portal)


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


func _make_material(material_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = material_color
	material.roughness = 0.9
	return material


## Material que "brilha" (emite luz própria).
func _make_glow_material(glow_color: Color, energy: float) -> StandardMaterial3D:
	var material := _make_material(glow_color)
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = energy
	return material
