extends SceneTree
## Teste dos perfis de bairro (Fase 7.1).
##
## Compara os perfis (profiles/) e o GameCategories com o "retrato" do
## comportamento de antes da Fase 7 (tests/fixtures/profiles_atuais.json,
## gravado por tools/retrato_perfis.gd). Tudo tem de continuar igual: mesma
## ordem dos bairros, mesmos nomes, cores, néons e tags.

const PORTRAIT: String = "res://tests/fixtures/profiles_atuais.json"
const DISTRICTS_FOLDER: String = "res://profiles/districts"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var portrait: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PORTRAIT))
	var old_categories: Array = portrait["categorias"]
	var old_ids: Array[String] = []
	for category: Dictionary in old_categories:
		old_ids.append(category["id"])
	var profiles: GDScript = load("res://profiles/profiles.gd")
	var categories := root.get_node("GameCategories")

	print("== o mundo e os perfis ==")
	var world = profiles.world()
	_check("o mundo carrega, com 10 bairros", world != null and world.districts.size() == 10)
	_check("nenhum item vazio na lista do mundo", not world.districts.has(null))
	_check("mesma ordem de antes %s" % str(profiles.district_ids()), profiles.district_ids() == old_ids)
	var on_disk := Array(DirAccess.get_files_at(DISTRICTS_FOLDER)).filter(func(f: String) -> bool: return f.ends_with(".tres"))
	_check("todo .tres de profiles/districts está na lista do mundo (%d arquivos)" % on_disk.size(),
			on_disk.size() == world.districts.size())

	print("== cada bairro igual ao retrato ==")
	for old: Dictionary in old_categories:
		var id: String = old["id"]
		var profile = profiles.district(id)
		if profile == null:
			_check("perfil \"%s\" existe" % id, false)
			continue
		var same: bool = profile.display_name == old["nome"] \
				and profile.color.to_html(true) == old["cor"]["html"] \
				and profile.neon_color().to_html(true) == old["neon"]["html"] \
				and Array(profile.tags) == _ints(old["tags"])
		_check("%-14s nome, cor, néon e tags iguais" % id, same)
		_check("%-14s um nome para cada tag" % id,
				profile.tag_names.size() == profile.tags.size() and not profile.tag_names.has("?"))
		_check("%-14s id válido e campos reservados no padrão" % id,
				id == id.to_lower() and not id.contains(" ") and profile.shell == "building"
				and profile.density == 4 and profile.landmark_script.is_empty())

	print("== GameCategories (a API de sempre) ==")
	_check("get_category_ids na ordem de antes", categories.get_category_ids() == old_ids)
	var api_ok := true
	for old: Dictionary in old_categories:
		var id: String = old["id"]
		if not (categories.has_category(id)
				and categories.get_category_name(id) == old["nome"]
				and categories.get_category_color(id).to_html(true) == old["cor"]["html"]
				and categories.get_neon_color(id).to_html(true) == old["neon"]["html"]):
			api_ok = false
			print("   diferente: ", id)
	_check("has_category, nome, cor e néon iguais para os 10", api_ok)
	_check("bairro que não existe: nome = o próprio id, cor cinza",
			not categories.has_category("nao_existe")
			and categories.get_category_name("nao_existe") == "nao_existe"
			and categories.get_category_color("nao_existe") == Color.GRAY)
	_check("OTHER_ID continua \"outros\"", categories.OTHER_ID == "outros" and categories.has_category("outros"))

	var tags_ok := true
	var tag_count := 0
	for old: Dictionary in old_categories:
		for tag in old["tags"]:
			tag_count += 1
			if categories._category_by_tag.get(int(tag), "") != old["id"]:
				tags_ok = false
				print("   tag %d não leva a %s" % [tag, old["id"]])
	_check("cada uma das %d tags leva ao mesmo bairro de antes" % tag_count, tags_ok)

	print("== som ambiente: cada bairro igual ao retrato ==")
	var ambience: GDScript = load("res://components/ambient_emitter/category_ambience.gd")
	for old: Dictionary in old_categories:
		var emitters: Array = ambience.create(old["id"])
		var expected: Array = old["som"]
		var sounds_ok := emitters.size() == expected.size()
		for i in mini(emitters.size(), expected.size()):
			sounds_ok = sounds_ok and _same_sound(emitters[i], expected[i])
		_check("%-14s %d som(ns), na mesma ordem e com os mesmos números" % [old["id"], expected.size()], sounds_ok)
		for emitter in emitters:
			emitter.free()
	_check("bairro que não existe: sem som", ambience.create("nao_existe").is_empty())

	print("== config.cfg ==")
	var config_text: String = root.get_node("AppConfig").DEFAULT_CONFIG_TEXT
	var missing := old_ids.filter(func(id: String) -> bool: return id != "outros" and not config_text.contains(id))
	_check("o texto do config.cfg lista todos os bairros (faltando: %s)" % str(missing),
			missing.is_empty() and config_text.contains("outros"))

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## O emissor tem os mesmos números do retrato? (floats com folga, por causa do JSON)
func _same_sound(emitter: AmbientEmitter, old: Dictionary) -> bool:
	var files: Array = []
	if emitter.loop_stream != null:
		files.append(emitter.loop_stream.resource_path)
	for stream in emitter.one_shots:
		files.append(stream.resource_path)
	var interval: Array = old["intervalo"]
	var pitch: Array = old["tom"]
	return ("loop" if emitter.loop_stream != null else "avulsos") == old["tipo"] \
			and files == old["arquivos"] \
			and is_equal_approx(emitter.volume_db, old["volume_db"]) \
			and is_equal_approx(emitter.max_distance, old["distancia_max"]) \
			and is_equal_approx(emitter.unit_size, old["unit_size"]) \
			and is_equal_approx(emitter.interval.x, interval[0]) and is_equal_approx(emitter.interval.y, interval[1]) \
			and is_equal_approx(emitter.pitch_range.x, pitch[0]) and is_equal_approx(emitter.pitch_range.y, pitch[1])


## O JSON devolve números como decimais (701.0); a comparação é com inteiros.
func _ints(values: Array) -> Array:
	return values.map(func(v) -> int: return int(v))


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
