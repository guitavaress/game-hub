class_name Heightfield
extends RefCounted
## As alturas da montanha de fundo (Fase 15.8): só contas, nenhum nó.
##
## Os pontos são Vector2(x, z) do mundo (norte = -Z). Os ângulos contam a
## partir do norte, no sentido horário, como no CityLayout.
##
## A montanha fica numa CUNHA (a fatia do bairro), fora do quadrado da cidade:
##
##   altura = máscara x pico x (forma + ruído "ridged")
##
##   máscara = ângulo dentro da cunha (degradê de ~10° nas beiradas)
##           x subida depois da faixa plana (apron) do lado de fora da borda
##           x queda antes do raio de fora (outer_radius)
##
## Depois que a trilha (MountainTrail) é traçada, ela molda a montanha: a
## faixa do zigue-zague vira uma rampa (veja MountainTrail.ramp_at) e a
## própria trilha é ESCAVADA: perto dela, o chão vai para a altura da trilha;
## no mirante, para um disco plano.
##
## A base da montanha fica 0,3 m abaixo do chão (some debaixo do chão escuro
## do Outskirts, sem brigar pelo mesmo plano) e escurece até a cor dele.

## Nomes dos campos que vêm do TerrainSpec (Fase 15.1). Os valores padrão
## abaixo são os do plano.
const SPEC_FIELDS: Array[String] = ["peak_height", "lookout_height", "max_grade", "trail_width",
		"apron", "outer_radius", "edge_fade_degrees", "lookout_radius", "noise_seed", "noise_frequency"]

## Parte do pico que vem do ruído (o resto é a forma lisa).
const NOISE_AMOUNT: float = 0.45
## A base da montanha fica este tanto abaixo do chão...
const SINK: float = 0.3
## ...e sobe até a altura de verdade nesta faixa de altura (em metros).
const SINK_BLEND: float = 1.0
## Até esta altura, a base escurece até a cor do chão de fora.
const FOOT_SHADE_HEIGHT: float = 4.0
## De cada lado da trilha (e em volta do mirante), a faixa em que o chão
## volta da altura da trilha para a altura da montanha.
const SHOULDER: float = 3.0
## Com menos espaço que isto entre a borda da cidade e o raio de fora, não há montanha.
const MIN_ROOM: float = 80.0
## A rampa da trilha some nestes metros antes da beirada da cunha e do raio de fora.
const RAMP_EDGE: float = 6.0
## Relevo miúdo da rampa (metros), para ela não parecer um plano liso.
const RAMP_DETAIL: float = 1.2

var peak_height: float = 90.0
var lookout_height: float = 32.0
var max_grade: float = 0.15
var trail_width: float = 3.0
var apron: float = 8.0
var outer_radius: float = 370.0
var edge_fade_degrees: float = 10.0
var lookout_radius: float = 9.0
var noise_seed: int = 1515
var noise_frequency: float = 0.006

## Metade do quadrado da cidade (do centro até a mureta).
var half: float = 0.0
## Meio da cunha e metade da abertura dela (radianos).
var wedge_center: float = 0.0
var wedge_half: float = PI
## Onde a grade da malha começa: um canto do quadrado, para que o lado por
## onde a trilha sai caia numa linha da grade (veja set_trail).
var grid_origin: Vector2 = Vector2.ZERO

var _fade: float = 0.0
var _rise_length: float = 1.0
var _fall_length: float = 1.0
var _noise: FastNoiseLite
var _trail: MountainTrail


## Copia os valores do TerrainSpec (só os campos que ele tiver).
func apply_spec(spec: Resource) -> void:
	for field in SPEC_FIELDS:
		if field in spec:
			set(field, spec.get(field))


## Prepara as contas para uma cidade com metade "city_half" e a cunha que vai
## de "wedge_from" até "wedge_to" (no sentido horário). Chame depois de
## apply_spec e antes de qualquer altura.
func configure(city_half: float, wedge_from: float, wedge_to: float) -> void:
	half = city_half
	var width := wedge_to - wedge_from
	if width <= 0.0:
		width += TAU
	wedge_half = minf(width, TAU) / 2.0
	wedge_center = fposmod(wedge_from + wedge_half, TAU)
	_fade = minf(deg_to_rad(edge_fade_degrees), wedge_half * 0.5)
	var room := outer_radius - half
	# O pico fica a ~3/4 do caminho até o raio de fora (atrás do mirante) e a
	# montanha cai no último quinto.
	_rise_length = maxf(20.0, (room - apron) * 0.75)
	_fall_length = maxf(15.0, room * 0.2)
	grid_origin = Vector2(-half, -half)
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.frequency = noise_frequency
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise.fractal_octaves = 5


## A montanha cabe entre a borda da cidade e o raio de fora?
func fits() -> bool:
	return outer_radius - half >= MIN_ROOM


## Liga a trilha: daqui em diante, as alturas já vêm escavadas.
func set_trail(trail: MountainTrail) -> void:
	_trail = trail
	if trail == null:
		return
	# A grade começa no canto do lado da saída da trilha: assim a linha da
	# borda tem vértices e a trilha encosta no chão da cidade sem degrau.
	grid_origin = Vector2(half if trail.outward.x > 0.5 else -half, half if trail.outward.y > 0.5 else -half)


func get_trail() -> MountainTrail:
	return _trail


# --- Geometria da cunha e do quadrado -----------------------------------------

## Ângulo de um ponto a partir do norte, no sentido horário (0 a 2π).
static func angle_of(p: Vector2) -> float:
	return fposmod(atan2(p.x, -p.y), TAU)


## Direção (no chão) de um ângulo contado a partir do norte.
static func direction_of(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))


## Quanto o ponto está fora do quadrado da cidade (negativo = dentro).
func square_distance(p: Vector2) -> float:
	return maxf(absf(p.x), absf(p.y)) - half


## Distância (em metros) até a beirada mais perto da cunha. Negativa = fora.
func edge_distance(p: Vector2) -> float:
	var inside := wedge_half - absf(wrapf(angle_of(p) - wedge_center, -PI, PI))
	if inside >= PI / 2.0:
		return p.length()
	return p.length() * sin(inside)


# --- Alturas -----------------------------------------------------------------

## A máscara da montanha (0 a 1), sem ruído e sem trilha.
func mountain_mask(p: Vector2) -> float:
	var d := square_distance(p)
	if d <= apron:
		return 0.0
	var r := p.length()
	if r >= outer_radius:
		return 0.0
	var inside := wedge_half - absf(wrapf(angle_of(p) - wedge_center, -PI, PI))
	if inside <= 0.0:
		return 0.0
	var mask := smoothstep(0.0, _fade, inside)
	mask *= smoothstep(apron, apron + _rise_length, d)
	mask *= 1.0 - smoothstep(outer_radius - _fall_length, outer_radius, r)
	return mask


## Altura da montanha com o ruído, sem a trilha.
func mountain_height(p: Vector2) -> float:
	return _height_from_mask(p, mountain_mask(p))


## Quanto a trilha (ou o mirante) manda neste ponto: x = peso (0 a 1),
## y = a altura dela. Sem trilha, (0, 0).
func carve_at(p: Vector2) -> Vector2:
	if _trail == null:
		return Vector2.ZERO
	var half_width := trail_width / 2.0
	var weight := 0.0
	var height := 0.0
	var closest := _trail.closest(p)
	if closest.x < half_width + SHOULDER:
		weight = 1.0 - smoothstep(half_width, half_width + SHOULDER, closest.x)
		height = closest.y
	var to_lookout := p.distance_to(_trail.lookout_center)
	var lookout_weight := 1.0 - smoothstep(lookout_radius, lookout_radius + SHOULDER, to_lookout)
	if lookout_weight > weight:
		weight = lookout_weight
		height = lookout_height
	return Vector2(weight, height)


## A altura do chão, já com a rampa e a trilha (0 dentro do quadrado e
## depois do raio de fora).
func height_at(p: Vector2) -> float:
	if square_distance(p) <= 0.0:
		return 0.0
	return _evaluate(p).x


## Tudo o que a malha precisa de um ponto:
##   x = a altura desenhada (com a base afundada 0,3 m);
##   y = quanto é trilha ou mirante (0 a 1);
##   z = quanto escurece no pé da montanha (0 a 1);
##   w = cobertura: 0 quer dizer que aqui não há montanha, rampa nem trilha.
func sample(p: Vector2) -> Vector4:
	if square_distance(p) <= 0.0:
		# Dentro da cidade: não há malha; só a beirada da trilha encosta em y = 0.
		var path := carve_at(p).x
		return Vector4(-SINK * (1.0 - path), path, 0.0, 0.0)
	var result := _evaluate(p)
	var height := result.x
	var sink := SINK * (1.0 - smoothstep(0.0, SINK_BLEND, height)) * (1.0 - result.y)
	var foot := (1.0 - smoothstep(0.0, FOOT_SHADE_HEIGHT, result.z)) * (1.0 - result.y)
	return Vector4(height - sink, result.y, foot, result.w)


## A altura sem escavar a trilha (a montanha com a rampa): o que fica dos
## lados da trilha.
func uncarved_height(p: Vector2) -> float:
	if square_distance(p) <= 0.0:
		return 0.0
	return _evaluate(p).z


## A altura desenhada (a de sample().x).
func surface_at(p: Vector2) -> float:
	return sample(p).x


## x = a altura (montanha, rampa e trilha), y = peso da trilha, z = a altura
## antes de escavar a trilha, w = a cobertura.
func _evaluate(p: Vector2) -> Vector4:
	var mask := mountain_mask(p)
	var height := _height_from_mask(p, mask)
	if _trail == null:
		return Vector4(height, 0.0, height, mask)
	var coverage := mask
	var ramp := _trail.ramp_at(p)
	if ramp.x > 0.0:
		var weight := ramp.x * clampf(edge_distance(p) / RAMP_EDGE, 0.0, 1.0)
		weight *= 1.0 - smoothstep(outer_radius - RAMP_EDGE, outer_radius, p.length())
		var detail := RAMP_DETAIL * _noise.get_noise_2d(p.x * 4.0, p.y * 4.0) * smoothstep(0.0, 3.0, ramp.y)
		height = lerpf(height, ramp.y + detail, weight)
		coverage = maxf(coverage, weight)
	var natural := height
	var carve := carve_at(p)
	height = lerpf(height, carve.y, carve.x)
	return Vector4(height, carve.x, natural, maxf(coverage, carve.x))


func _height_from_mask(p: Vector2, mask: float) -> float:
	if mask <= 0.0:
		return 0.0
	var ridged := clampf(0.5 + 0.5 * _noise.get_noise_2d(p.x, p.y), 0.0, 1.0)
	return mask * peak_height * (1.0 - NOISE_AMOUNT + NOISE_AMOUNT * ridged)
