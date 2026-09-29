class_name AddressTotem
extends Node3D
## Totem de endereço: o enfeite padrão de qualquer bairro que não tenha um
## enfeite próprio (inclusive "Outros"). É uma coluna de metal escuro de
## 1 x 3 m, com uma faixa fina de néon no alto e, nas duas faces largas, a LISTA
## dos jogos do quarteirão (um por linha, como o diretório de um prédio).
##
## Fica na quina do quarteirão mais perto da praça (a mesma quina da placa de
## rua, veja city.gd), um pouco afastado do poste, no calçadão do lado do
## quarteirão vizinho. A coluna é fina (30 cm) e deixa mais de 1 m de passagem
## entre ela e a parede do prédio.

const COLUMN_SIZE: Vector3 = Vector3(1.0, 3.0, 0.3)
const NEON_HEIGHT: float = 2.72
## Distância da coluna até o poste da quina, andando pela calçada (m).
const POLE_GAP: float = 1.9
## No máximo 8 linhas de texto (com a linha "+N mais", se faltar espaço).
const MAX_LINES: int = 8
const MAX_NAME_CHARS: int = 22
## Texto: fonte de letreiro (a mesma do pórtico), tamanho de linha em metros.
const FONT_SIZE: int = 96
const TEXT_HEIGHT: float = 0.2
const TEXT_MARGIN: float = 0.07
const TEXT_CENTER_HEIGHT: float = 1.65
const TEXT_COLOR: Color = Color("F2F3F5")
const METAL_COLOR: Color = Color("1A1D22")

## Os prédios e o quarteirão (a cidade preenche antes de adicionar).
var buildings: Array[CityBuilding] = []
var cell: Vector2i = Vector2i.ZERO

var _neon_material: StandardMaterial3D
var _labels: Array[Label3D] = []


func _ready() -> void:
	add_to_group("city_night")
	var center := CityLayout.block_center(cell)
	# A quina do quarteirão mais perto da praça (a mesma da placa de rua): sx e sz
	# dizem para que lado ela fica. A coluna fica de lado para a rua que liga o
	# quarteirão à praça, afastada do poste da quina.
	var sx := _toward_center(cell.x)
	var sz := _door_side(cell)
	var corner := CityLayout.BLOCK_SIZE / 2.0 - 0.7  # onde ficam os postes
	position = center + Vector3(sx * corner, 0.0, sz * (corner - POLE_GAP))
	rotation.y = PI / 2.0  # as faces largas olham para o lado da rua (±X)
	_build_column(_neon())
	_build_lists()
	set_night(0.0)


## O texto de cada face (a lista dos jogos, para os testes).
func get_text() -> String:
	return _labels[0].text if not _labels.is_empty() else ""


## 0 = dia, 1 = noite: o néon segue a regra da cidade (fraco de dia, forte à noite).
func set_night(night: float) -> void:
	if _neon_material != null:
		_neon_material.emission_energy_multiplier = CityDecor.neon_energy(night)


## Cor do néon do bairro (o "branco frio" de Outros, se não houver prédio).
func _neon() -> Color:
	var category_id := buildings[0].category_id if not buildings.is_empty() else GameCategories.OTHER_ID
	return GameCategories.get_neon_color(category_id)


## A coluna de metal, a faixa de néon (1 cm maior que a coluna, dá a volta) e a colisão.
func _build_column(neon: Color) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.8
	metal.roughness = 0.35
	var column := MeshInstance3D.new()
	var column_mesh := BoxMesh.new()
	column_mesh.size = COLUMN_SIZE
	column.mesh = column_mesh
	column.material_override = metal
	column.position = Vector3(0.0, COLUMN_SIZE.y / 2.0, 0.0)
	add_child(column)

	_neon_material = StandardMaterial3D.new()
	_neon_material.albedo_color = neon
	_neon_material.emission_enabled = true
	_neon_material.emission = neon
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(COLUMN_SIZE.x + 0.02, 0.05, COLUMN_SIZE.z + 0.02)
	strip.mesh = strip_mesh
	strip.material_override = _neon_material
	strip.position = Vector3(0.0, NEON_HEIGHT, 0.0)
	add_child(strip)

	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = COLUMN_SIZE
	shape.shape = box
	body.position = Vector3(0.0, COLUMN_SIZE.y / 2.0, 0.0)
	body.add_child(shape)
	add_child(body)


## A lista de jogos, uma vez em cada face larga.
func _build_lists() -> void:
	var lines := _game_lines()
	if lines.is_empty():
		return
	var text := "\n".join(lines)
	# Cabe na largura da coluna, diminuindo se o nome mais comprido não couber.
	var pixel_size := TEXT_HEIGHT / FONT_SIZE
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, HubFonts.SIGN.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	if widest * pixel_size > COLUMN_SIZE.x - TEXT_MARGIN * 2.0:
		pixel_size = (COLUMN_SIZE.x - TEXT_MARGIN * 2.0) / widest
	for side in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = text
		label.font = HubFonts.SIGN
		label.font_size = FONT_SIZE
		label.pixel_size = pixel_size
		label.outline_size = 0
		label.double_sided = false
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.modulate = TEXT_COLOR
		# Bloco de texto centrado na coluna (o texto começa na borda esquerda do nó).
		label.position = Vector3(-side * widest * pixel_size / 2.0, TEXT_CENTER_HEIGHT,
				side * (COLUMN_SIZE.z / 2.0 + 0.01))
		label.rotation.y = 0.0 if side > 0.0 else PI
		add_child(label)
		_labels.append(label)


## Uma linha por jogo (nome cortado em 22 letras); se passar de 8 linhas, as
## últimas viram "+N mais".
func _game_lines() -> Array[String]:
	var names: Array[String] = []
	for building in buildings:
		if building.game != null:
			names.append(_short_name(building.game.name))
	if names.size() <= MAX_LINES:
		return names
	var lines: Array[String] = names.slice(0, MAX_LINES - 1)
	lines.append("+%d mais" % (names.size() - lines.size()))
	return lines


static func _short_name(game_name: String) -> String:
	if game_name.length() <= MAX_NAME_CHARS:
		return game_name
	return game_name.substr(0, MAX_NAME_CHARS - 1).strip_edges() + "…"


## Para que lado (-1 ou +1) fica o centro da cidade nesse eixo (0 = oeste).
## Mesma regra do city.gd (_toward_center).
static func _toward_center(value: int) -> float:
	if value > 0:
		return -1.0
	return 1.0 if value < 0 else -1.0


## De que lado do quarteirão (-1 = norte, +1 = sul) fica a rua das portas mais
## perto do centro. Mesma regra do city.gd (_door_street_z; empate: norte).
static func _door_side(cell: Vector2i) -> float:
	var north := (cell.y - 0.5) * CityLayout.BLOCK_PITCH
	var south := (cell.y + 0.5) * CityLayout.BLOCK_PITCH
	return -1.0 if absf(north) <= absf(south) else 1.0
