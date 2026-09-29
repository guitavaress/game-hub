class_name SportsScoreboard
extends Node3D
## Bairro Esportes: um placar de LED (matriz de pontos) sobre a rua, com o
## total de HORAS JOGADAS nos jogos do quarteirão, e uma faixa quadriculada de
## largada no asfalto, embaixo dele. Fica na rua ao lado do quarteirão, do
## lado da praça (o mesmo lugar do letreiro flutuante do bairro), e tem seu
## próprio suporte: dois postes finos e uma viga (não depende do pórtico).
##
## O texto ("128 H") é desenhado pixel a pixel numa imagem de 64 x 16, com uma
## fonte de pontos de 5 x 7 escrita à mão aqui embaixo; o shader
## (dot_matrix.gdshader) transforma cada pixel num LED redondo. O placar mostra
## as duas faces (quem vem de cada ponta da rua lê certo). As horas vêm da
## Steam (SteamLibrary) e são relidas quando o hub acorda, depois de um jogo.

const SHADER: Shader = preload("res://worlds/city/district_props/dot_matrix.gdshader")

## Placar inteiro (moldura escura) e a área de LEDs dentro dele. A área tem a
## mesma proporção da imagem (4 : 1), para os LEDs ficarem redondos.
const BOARD_SIZE: Vector2 = Vector2(4.0, 1.2)
const BOARD_DEPTH: float = 0.25
const PANEL_SIZE: Vector2 = Vector2(3.8, 0.95)
const MATRIX_SIZE: Vector2i = Vector2i(64, 16)
## Plaquinha embaixo do placar, explicando o que é o número.
const CAPTION_HEIGHT: float = 0.35
const CAPTION_TEXT: String = "HORAS JOGADAS"
const CAPTION_FONT_SIZE: int = 128
const CAPTION_TEXT_HEIGHT: float = 0.24
## Suporte: dois postes e uma viga por cima. O placar fica entre os postes.
const POST_SIZE: float = 0.22
const POST_HEIGHT: float = 5.0
const CAPTION_BOTTOM: float = 3.0
const METAL_COLOR: Color = Color("1A1D22")
## Faixa de largada: 8 m de largura (atravessando a rua) por 2 m de fundo, com
## quadrados de meio metro. A textura tem 16 pixels por quadrado.
const LINE_SIZE: Vector2 = Vector2(8.0, 2.0)
const CHECKER_SQUARE_M: float = 0.5
const CHECKER_SQUARE_PIXELS: int = 16
const CHECKER_LIGHT: Color = Color(0.9, 0.9, 0.88)
const CHECKER_DARK: Color = Color(0.06, 0.06, 0.07)
## Mais que isto o número não cabe na imagem.
const MAX_HOURS: int = 99999

## Fonte de pontos 5 x 7: só o que o placar precisa (dígitos, H e traço).
const GLYPH_WIDTH: int = 5
const GLYPH_HEIGHT: int = 7
const GLYPHS: Dictionary = {
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
}

## Os prédios e o quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []
var cell: Vector2i = Vector2i.ZERO
## De onde vêm os minutos jogados de um jogo (recebe o App ID). Vazio = a
## Steam (SteamLibrary). Os testes trocam por números fixos.
var playtime_source: Callable = Callable()

var _material: ShaderMaterial
var _captions: Array[Label3D] = []
var _line: Decal
var _text: String = ""
var _neon: Color = Color.WHITE

static var _checker_texture: Texture2D


func _ready() -> void:
	add_to_group("city_night")
	_neon = GameCategories.get_neon_color("esportes")
	var pivot := Node3D.new()
	pivot.name = "Gantry"
	# Eixo Z do pivô = o sentido da rua; eixo X = de um lado ao outro dela.
	pivot.position = _street_spot()
	pivot.rotation.y = _street_yaw()
	add_child(pivot)
	_build_gantry(pivot)
	_build_start_line(pivot)
	refresh()
	# Depois de jogar, as horas mudam: o hub acorda e relemos.
	HubWindow.woke_up.connect(refresh)
	set_night(0.0)


## Relê as horas dos jogos e redesenha o placar.
func refresh() -> void:
	var minutes := get_total_minutes()
	if minutes < 0:
		_text = "--"  # a Steam ainda não disse (ou não há usuário logado)
	else:
		_text = "%d H" % mini(floori(minutes / 60.0), MAX_HOURS)
	var texture := ImageTexture.create_from_image(_render_text(_text))
	_material.set_shader_parameter("matrix", texture)


## Soma dos minutos jogados nos prédios do quarteirão (-1 = ninguém sabe).
func get_total_minutes() -> int:
	var total := 0
	var known := false
	for building in buildings:
		var minutes: int = playtime_source.call(building.game.app_id) if playtime_source.is_valid() \
				else SteamLibrary.get_playtime_minutes(building.game.app_id)
		if minutes >= 0:
			total += minutes
			known = true
	return total if known else -1


## O que está escrito no placar agora ("128 H" ou "--").
func get_text() -> String:
	return _text


## A faixa quadriculada no asfalto (para os testes).
func get_start_line() -> Decal:
	return _line


## 0 = dia, 1 = noite: os LEDs brilham mais à noite.
func set_night(night: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("brightness", lerpf(1.0, 2.6, night))
	var glow := lerpf(1.0, 1.8, night)
	for caption in _captions:
		caption.modulate = Color(_neon.r * glow, _neon.g * glow, _neon.b * glow)


# --- Lugar -------------------------------------------------------------------

## Meio da rua ao lado do quarteirão, do lado da praça, na altura do meio do
## quarteirão (a mesma conta do letreiro flutuante do bairro, na cidade).
func _street_spot() -> Vector3:
	var reach := CityLayout.BLOCK_SIZE / 2.0 + CityLayout.STREET_WIDTH / 2.0
	var toward_plaza := Vector3(0.0, 0.0, _toward_center(cell.y)) if cell.x == 0 \
			else Vector3(_toward_center(cell.x), 0.0, 0.0)
	return CityLayout.block_center(cell) + toward_plaza * reach


## Quarteirões da coluna do meio usam a rua leste-oeste; os outros, a norte-sul.
func _street_yaw() -> float:
	return PI / 2.0 if cell.x == 0 else 0.0


## Para que lado (-1 ou +1) fica o centro da cidade nesse eixo.
static func _toward_center(value: int) -> float:
	if value > 0:
		return -1.0
	return 1.0 if value < 0 else -1.0


# --- Suporte e placar --------------------------------------------------------

func _build_gantry(pivot: Node3D) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.8
	metal.roughness = 0.35

	# Dois postes finos (com colisão, como os pilares do pórtico) e uma viga.
	var post_x := BOARD_SIZE.x / 2.0 + POST_SIZE / 2.0
	for side in [-1.0, 1.0]:
		var post := CSGBox3D.new()
		post.name = "Post"
		post.size = Vector3(POST_SIZE, POST_HEIGHT, POST_SIZE)
		post.position = Vector3(side * post_x, POST_HEIGHT / 2.0, 0.0)
		post.material = metal
		post.use_collision = true
		pivot.add_child(post, true)
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(post_x * 2.0 + POST_SIZE, 0.18, POST_SIZE)
	beam.mesh = beam_mesh
	beam.material_override = metal
	beam.position = Vector3(0.0, POST_HEIGHT - 0.09, 0.0)
	pivot.add_child(beam)

	# Plaquinha da legenda, e em cima dela o placar (moldura escura).
	var board_center_y := CAPTION_BOTTOM + CAPTION_HEIGHT + BOARD_SIZE.y / 2.0
	_add_box(pivot, Vector3(0.0, CAPTION_BOTTOM + CAPTION_HEIGHT / 2.0, 0.0),
			Vector3(BOARD_SIZE.x, CAPTION_HEIGHT, BOARD_DEPTH), metal)
	_add_box(pivot, Vector3(0.0, board_center_y, 0.0), Vector3(BOARD_SIZE.x, BOARD_SIZE.y, BOARD_DEPTH), metal)

	# A tela de LEDs, nas duas faces (a de trás gira 180° e continua legível).
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("grid", Vector2(MATRIX_SIZE))
	_material.set_shader_parameter("led_color", _neon)
	var caption_pixel_size := CAPTION_TEXT_HEIGHT / CAPTION_FONT_SIZE
	for side in [1.0, -1.0]:
		var face := Node3D.new()
		face.rotation.y = 0.0 if side > 0.0 else PI
		pivot.add_child(face)
		var screen := MeshInstance3D.new()
		screen.name = "Screen"
		var quad := QuadMesh.new()
		quad.size = PANEL_SIZE
		screen.mesh = quad
		screen.material_override = _material
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		screen.position = Vector3(0.0, board_center_y, BOARD_DEPTH / 2.0 + 0.005)
		face.add_child(screen)

		var caption := Label3D.new()
		caption.text = CAPTION_TEXT
		caption.font = HubFonts.SIGN
		caption.font_size = CAPTION_FONT_SIZE
		caption.pixel_size = caption_pixel_size
		caption.outline_size = 0
		caption.double_sided = false
		caption.position = Vector3(0.0, CAPTION_BOTTOM + CAPTION_HEIGHT / 2.0, BOARD_DEPTH / 2.0 + 0.01)
		face.add_child(caption)
		_captions.append(caption)


static func _add_box(parent: Node3D, center: Vector3, box_size: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	box.mesh = mesh
	box.material_override = material
	box.position = center
	parent.add_child(box)


# --- Faixa de largada --------------------------------------------------------

## Um Decal (projeção no chão) com a textura quadriculada, atravessando a rua
## embaixo do placar. Opaco: pinta por cima do asfalto e da faixa tracejada.
func _build_start_line(pivot: Node3D) -> void:
	_line = Decal.new()
	_line.name = "StartLine"
	_line.texture_albedo = _get_checker_texture()
	_line.size = Vector3(LINE_SIZE.x, 1.0, LINE_SIZE.y)
	_line.albedo_mix = 1.0
	_line.normal_fade = 0.9  # só no chão (os postes não ganham xadrez)
	_line.cull_mask = 1      # só o mundo (não os hologramas)
	_line.position = Vector3(0.0, 0.3, 0.0)
	pivot.add_child(_line)


## Xadrez de 16 x 4 quadrados (uma vez só para todos os quarteirões).
static func _get_checker_texture() -> Texture2D:
	if _checker_texture == null:
		var width := roundi(LINE_SIZE.x / CHECKER_SQUARE_M) * CHECKER_SQUARE_PIXELS
		var height := roundi(LINE_SIZE.y / CHECKER_SQUARE_M) * CHECKER_SQUARE_PIXELS
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		for py in height:
			for px in width:
				var square := floori(px / float(CHECKER_SQUARE_PIXELS)) + floori(py / float(CHECKER_SQUARE_PIXELS))
				image.set_pixel(px, py, CHECKER_LIGHT if square % 2 == 0 else CHECKER_DARK)
		_checker_texture = ImageTexture.create_from_image(image)
	return _checker_texture


# --- Texto em pontos ---------------------------------------------------------

## Desenha o texto na imagem de LEDs (1 = aceso). Letras grandes (2 x) quando
## cabem; senão, no tamanho normal.
static func _render_text(text: String) -> Image:
	var image := Image.create(MATRIX_SIZE.x, MATRIX_SIZE.y, false, Image.FORMAT_L8)
	var zoom := 2
	if _text_width(text, zoom) > MATRIX_SIZE.x:
		zoom = 1
	var x := floori((MATRIX_SIZE.x - _text_width(text, zoom)) / 2.0)
	var y := floori((MATRIX_SIZE.y - GLYPH_HEIGHT * zoom) / 2.0)
	for letter in text:
		if GLYPHS.has(letter):
			_draw_glyph(image, letter, x, y, zoom)
		x += _advance(letter, zoom)
	return image


## Largura do texto em LEDs (sem o espaço depois da última letra).
static func _text_width(text: String, zoom: int) -> int:
	var width := 0
	for letter in text:
		width += _advance(letter, zoom)
	return width - zoom  # tira o espaço depois da última letra


## Quanto o cursor anda depois de uma letra: a letra + 1 LED de espaço (x zoom).
static func _advance(letter: String, zoom: int) -> int:
	if letter == " ":
		return 2 * zoom
	return (GLYPH_WIDTH + 1) * zoom


static func _draw_glyph(image: Image, letter: String, x: int, y: int, zoom: int) -> void:
	var rows: Array = GLYPHS[letter]
	for row in GLYPH_HEIGHT:
		var line: String = rows[row]
		for col in GLYPH_WIDTH:
			if line[col] == "#":
				image.fill_rect(Rect2i(x + col * zoom, y + row * zoom, zoom, zoom), Color.WHITE)
