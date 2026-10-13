extends SceneTree
## Gera as duas imagens do céu noturno usadas pelo Sky3D, no lugar da Via
## Láctea original (que é CC BY 4.0, e o projeto só usa CC0):
##
##   assets/generated/sky_starfield.png  estrelas soltas (panorama 2:1)
##   assets/generated/sky_starmap.png    fundo do espaço (quase preto)
##
##   godot --headless --path . -s res://tools/gerar_estrelas.gd
##
## As estrelas são sorteadas com semente fixa: rodar de novo dá a mesma imagem.
## Uma faixa inclinada recebe mais estrelas, lembrando a Via Láctea.

const STARFIELD_PATH: String = "res://assets/generated/sky_starfield.png"
const STARMAP_PATH: String = "res://assets/generated/sky_starmap.png"
const WIDTH: int = 4096
const HEIGHT: int = 2048
const STAR_COUNT: int = 9000
## Estrelas extras dentro da faixa da "galáxia".
const BAND_STAR_COUNT: int = 6000
const SEED: int = 20261013


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var stars := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
	stars.fill(Color.BLACK)
	for i in STAR_COUNT:
		# Ponto sorteado por igual na esfera (senão os polos ficam lotados).
		var direction := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		_draw_star(stars, direction, rng)
	# A faixa: um grande círculo inclinado, com as estrelas espalhadas em volta.
	var band_axis := Vector3(0.3, 1.0, 0.45).normalized()
	for i in BAND_STAR_COUNT:
		var direction := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var distance := direction.dot(band_axis)
		direction = (direction - band_axis * distance * 0.85).normalized()
		_draw_star(stars, direction, rng, 0.6)
	stars.save_png(STARFIELD_PATH)

	# O fundo do espaço: preto com um brilho azulado muito fraco na faixa.
	var space := Image.create(WIDTH / 4, HEIGHT / 4, false, Image.FORMAT_RGB8)
	for y in space.get_height():
		for x in space.get_width():
			var direction := _direction(Vector2(x + 0.5, y + 0.5) / Vector2(space.get_size()))
			var glow := pow(1.0 - absf(direction.dot(band_axis)), 8.0) * 0.06
			space.set_pixel(x, y, Color(glow * 0.8, glow * 0.85, glow))
	space.save_png(STARMAP_PATH)
	print("gerados: %s e %s" % [STARFIELD_PATH, STARMAP_PATH])
	quit()


## Pinta uma estrela: quase todas fracas e de 1 pixel; poucas fortes, maiores.
func _draw_star(image: Image, direction: Vector3, rng: RandomNumberGenerator, scale: float = 1.0) -> void:
	var uv := _uv(direction)
	var x := int(uv.x * WIDTH) % WIDTH
	var y := clampi(int(uv.y * HEIGHT), 0, HEIGHT - 1)
	var brightness := pow(rng.randf(), 4.0) * scale
	var tint := Color(1.0, 0.92, 0.8).lerp(Color(0.75, 0.85, 1.0), rng.randf())
	var color := tint * (0.35 + brightness * 0.65)
	_add(image, x, y, color)
	if brightness > 0.3:
		# As mais fortes ganham uma "cruz" de brilho em volta.
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_add(image, (x + offset.x + WIDTH) % WIDTH, clampi(y + offset.y, 0, HEIGHT - 1), color * 0.4)


func _add(image: Image, x: int, y: int, color: Color) -> void:
	var old := image.get_pixel(x, y)
	image.set_pixel(x, y, Color(minf(old.r + color.r, 1.0), minf(old.g + color.g, 1.0), minf(old.b + color.b, 1.0)))


## Direção (esfera) → posição no panorama (0 a 1), no formato equiretangular.
func _uv(direction: Vector3) -> Vector2:
	var u := 0.5 + atan2(direction.x, -direction.z) / TAU
	var v := acos(clampf(direction.y, -1.0, 1.0)) / PI
	return Vector2(u, v)


## O caminho inverso de _uv().
func _direction(uv: Vector2) -> Vector3:
	var longitude := (uv.x - 0.5) * TAU
	var latitude := uv.y * PI
	return Vector3(sin(latitude) * sin(longitude), cos(latitude), -sin(latitude) * cos(longitude))
