class_name RadioTower
extends DistrictLandmark
## Bairro Ação: uma torre de rádio. Mastro fino que afina para o alto, com faixas
## de néon, uma luz no topo e dois faróis que varrem o céu à noite (só faixas de
## luz, sem luz de verdade).

const BASE_SIZE: float = 1.8
const TOP_SIZE: float = 0.3
const BEAM_LENGTH: float = 14.0
const BEAM_WIDTH: float = 0.5
const BEAM_TILT_DEGREES: float = 20.0
const BEAM_SPEED: float = 0.6


func _build(height: float) -> void:
	var mast_height := height - 1.0
	# O mastro afina: troncos de quatro lados empilhados (cada um mais fino).
	var steps := 5
	for i in steps:
		var y0 := mast_height * i / steps
		var w0 := lerpf(BASE_SIZE, TOP_SIZE, float(i) / steps)
		var w1 := lerpf(BASE_SIZE, TOP_SIZE, float(i + 1) / steps)
		var piece := _add_cylinder(Vector3(0.0, y0, 0.0), w1 * 0.7, w0 * 0.7, mast_height / steps,
				_concrete_material, null, 4)
		piece.rotation.y = PI / 4.0
		# Faixa de néon na emenda de cada tronco.
		_add_box(Vector3(0.0, y0 + 0.1, 0.0), Vector3(w0 * 1.05, 0.2, w0 * 1.05), _neon_material)
	_add_box(Vector3(0.0, height - 0.5, 0.0), Vector3(0.35, 0.7, 0.35), _neon_material)
	_add_sweeping_beams(Vector3(0.0, mast_height - 0.5, 0.0), 2, BEAM_LENGTH, BEAM_WIDTH,
			BEAM_TILT_DEGREES, BEAM_SPEED)
