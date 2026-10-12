class_name CategoryAmbience
extends RefCounted
## "Categoria de jogo -> som ambiente".
##
## Na cidade, cada portal ganha o som do bairro dele. Num mundo futuro, a mesma
## lista pode dar som a um bioma (por isso ela não fica dentro da cidade).
##
## Os sons de cada bairro moram no PERFIL dele (Fase 7: profiles/districts/,
## campo "Ambience"), e não mais aqui. Esta classe só transforma o perfil em
## emissores de som.
##
## Uso:  for emissor in CategoryAmbience.create("cartas"): portal.add_child(emissor)
##
## Sons: pacotes CC0 da Kenney (assets/kenney) e sons gerados por
## assets/generated/make_sounds.py (vento e passarinhos).


## Cria os emissores de som de uma categoria ([] = categoria sem som).
static func create(category_id: String) -> Array[AmbientEmitter]:
	var emitters: Array[AmbientEmitter] = []
	var profile := Profiles.district(category_id)
	if profile == null:
		return emitters
	for spec in profile.ambience:
		if spec != null:
			emitters.append(from_spec(spec))
	return emitters


## Um emissor a partir de um AmbienceSpec do perfil.
static func from_spec(spec: AmbienceSpec) -> AmbientEmitter:
	var emitter := AmbientEmitter.new()
	if spec.kind == "loop":
		if not spec.files.is_empty():
			emitter.loop_stream = load(spec.files[0])
	else:
		for path in spec.files:
			emitter.one_shots.append(load(path))
		emitter.interval = spec.interval
		emitter.pitch_range = spec.pitch_range
	emitter.volume_db = spec.volume_db
	emitter.max_distance = spec.max_distance
	emitter.unit_size = spec.unit_size
	return emitter
