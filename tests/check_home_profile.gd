extends SceneTree
## Teste do perfil do tema da casa (Fase 13.1): o catálogo (profiles/home_catalog.tres)
## e o loft (profiles/homes/loft.tres) contra o "retrato" da casa de antes da 13.2
## (tests/fixtures/casa_atual.json, gravado por tools/retrato_casa.gd).
## Fase 13.2: a casa montada pelo perfil do loft é igual ao retrato, peça por
## peça, e nenhum id de tema aparece entre aspas fora de profiles/, tests/ e tools/.
## Fase 13.12: a cabana carrega e monta sem erro (com a lareira, o fogo que
## tremula, as poltronas, os lampiões e o vaso), com paredes de tora e a vista
## de floresta. Guarda o config.cfg e devolve no fim.

const PORTRAIT: String = "res://tests/fixtures/casa_atual.json"
const CONFIG: String = "user://config.cfg"
const HOMES_FOLDER: String = "res://profiles/homes"
## Pastas que podem citar os ids dos temas (os dados, os testes e as ferramentas).
const SCAN_SKIP: Array[String] = ["res://profiles", "res://tests", "res://tools", "res://.godot", "res://assets"]

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app: Node = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	var original: Array = [app.get_home_theme(), app.get_home_layout(), app.get_home_wall_color(), app.get_home_neon_color(), app.get_quality()]
	app.set_home_theme("")
	app.set_home_layout("")
	app.set_home_wall_color("")
	app.set_home_neon_color("")
	app.set_quality("leve")  # o retrato original não tem SSAO
	var snapshot: GDScript = load("res://tests/home_snapshot.gd")
	var portrait: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PORTRAIT))
	var lines: Array = portrait["linhas"]
	var text := "\n".join(PackedStringArray(lines))

	print("== o catálogo ==")
	var catalog := Profiles.home_catalog()
	_check("o catálogo carrega, com pelo menos um tema", catalog != null and not catalog.homes.is_empty())
	_check("nenhum item vazio na lista de temas", not catalog.homes.has(null))
	var ids: Array[String] = []
	for profile in catalog.homes:
		ids.append(profile.id)
	var unique := {}
	for id in ids:
		unique[id] = true
	_check("ids únicos e válidos %s" % str(ids), unique.size() == ids.size()
			and ids.all(func(id: String) -> bool: return not id.is_empty() and id == id.to_lower() and not id.contains(" ")))
	var on_disk := Array(DirAccess.get_files_at(HOMES_FOLDER)).filter(func(f: String) -> bool: return f.ends_with(".tres"))
	_check("todo .tres de profiles/homes está no catálogo (%d arquivos)" % on_disk.size(), on_disk.size() == catalog.homes.size())
	_check("as paletas de cores têm cores (parede %d, néon %d)" % [catalog.wall_palette.size(), catalog.neon_palette.size()],
			catalog.wall_palette.size() >= 6 and catalog.neon_palette.size() >= 6)

	print("== o tema padrão e os ids ==")
	var loft := Profiles.home("loft")
	_check("o loft existe e é o primeiro (o padrão)", loft != null and catalog.homes[0] == loft)
	_check("id vazio devolve o loft", Profiles.home("") == loft)
	_check("id desconhecido devolve o loft", Profiles.home("nao_existe") == loft)
	_check("sem disposições no catálogo, home_layout devolve null sem erro",
			catalog.layouts.is_empty() == (Profiles.home_layout("") == null))

	print("== o loft é igual ao retrato ==")
	_check("nome e superfícies preenchidos", loft.display_name == "Loft" and loft.floor != null and loft.ceiling != null
			and loft.feature_wall != null and loft.walls != null and loft.skirting != null and loft.beams != null
			and loft.window_frame != null and loft.window_sill != null)
	_check("só as paredes comuns são pintáveis", loft.walls.paintable and not loft.floor.paintable
			and not loft.feature_wall.paintable and not loft.ceiling.paintable)
	var surfaces := {
		"piso": loft.floor, "teto": loft.ceiling, "parede da janela": loft.feature_wall, "paredes": loft.walls,
		"rodapé": loft.skirting, "vigas": loft.beams, "moldura da janela": loft.window_frame, "peitoril": loft.window_sill,
	}
	for label: String in surfaces:
		var material := _material(surfaces[label])
		var description: String = snapshot._material(material)
		_check("material de %-17s está na casa de antes" % label, text.contains("mat=" + description))
	_check("lâmpadas: cor e força",
			text.contains("OmniLight3D|Lamp|") and text.contains("|cor=%s|energia=%s|alcance=7.000" % [
					loft.lamp_color.to_html(true), snapshot._num(loft.lamp_energy)]))
	# O retrato foi gravado à noite: a luz do dia está com força 0 (só a cor vale).
	_check("luz do dia da janela: cor",
			text.contains("SpotLight3D|Daylight|") and text.contains("|cor=%s|energia=0.000|alcance=12.000" % loft.daylight_color.to_html(true)))
	_check("néon: cor, brilho e luz",
			text.contains("brilho=%s*%s" % [loft.neon_color.to_html(true), snapshot._num(loft.neon_energy)])
			and text.contains("NeonLight|") and text.contains("|cor=%s|energia=%s" % [loft.neon_color.to_html(true), snapshot._num(loft.neon_light_energy)]))
	_check("ambiente de noite e fundo", _env_matches(lines, loft))
	_check("o shader da janela existe", ResourceLoader.exists(loft.window_shader))
	_check("marca de passos de madeira", loft.footstep == "wood")

	print("== a casa montada pelo perfil é igual ao retrato (13.2) ==")
	var home: Node3D = (load("res://worlds/home/home.gd") as GDScript).new()
	root.add_child(home)
	await process_frame
	var now: Array[String] = snapshot.capture(home)
	var missing := lines.filter(func(line: String) -> bool: return not now.has(line))
	var extra := now.filter(func(line: String) -> bool: return not lines.has(line))
	for line: String in missing.slice(0, 5):
		print("    falta: %s" % line)
	for line: String in extra.slice(0, 5):
		print("    sobra: %s" % line)
	_check("mesmas peças, posições, materiais, luzes e ambiente (%d linhas)" % now.size(),
			missing.is_empty() and extra.is_empty() and now.size() == lines.size())
	_check("a casa usa o loft", home.get_profile() == loft)
	home.queue_free()

	await _check_cabin()

	print("== nenhum id de tema fora de profiles/ ==")
	var offenders: Array[String] = []
	var scripts := _scripts("res://")
	for path in scripts:
		var code_lines := FileAccess.get_file_as_string(path).split("\n")
		for i in code_lines.size():
			var code := code_lines[i].strip_edges()
			if code.begins_with("#"):
				continue
			for id in ids:
				if code.contains("\"%s\"" % id):
					offenders.append("%s:%d" % [path, i + 1])
	_check("nenhum dos %d scripts cita um id de tema %s" % [scripts.size(), str(offenders)],
			scripts.size() > 50 and offenders.is_empty())

	app.set_home_theme(original[0])
	app.set_home_layout(original[1])
	app.set_home_wall_color(original[2])
	app.set_home_neon_color(original[3])
	app.set_quality(original[4])
	var restored := FileAccess.open(CONFIG, FileAccess.WRITE)
	restored.store_string(backup)
	restored.close()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## A cabana: o perfil e a casa montada com ele.
func _check_cabin() -> void:
	print("== a cabana (13.12) ==")
	var catalog := Profiles.home_catalog()
	var cabin := Profiles.home("cabana")
	_check("a cabana existe e vem depois do loft", cabin != null and cabin.id == "cabana"
			and catalog.homes.find(cabin) > 0 and catalog.homes[0] == Profiles.home("loft"))
	_check("nome, superfícies e enfeite preenchidos", cabin.display_name == "Cabana" and cabin.floor != null
			and cabin.ceiling != null and cabin.beams != null and cabin.window_frame != null
			and load(cabin.decor_script) is GDScript)
	_check("paredes de tora, e só as comuns são pintáveis", cabin.walls.logs and cabin.feature_wall.logs
			and cabin.walls.paintable and not cabin.feature_wall.paintable and not cabin.floor.logs)
	_check("piso, teto e vigas de madeira", cabin.floor.kind == "wood" and cabin.floor.planks
			and cabin.ceiling.kind == "wood" and cabin.beams.kind == "wood")
	var window_shader: Shader = load(cabin.window_shader)
	_check("a vista de floresta tem o \"night\"", window_shader != null
			and window_shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u["name"] == "night"))
	_check("néon âmbar mais fraco que o do loft", cabin.neon_energy > 0.0
			and cabin.neon_energy < Profiles.home("loft").neon_energy and cabin.neon_color.r > cabin.neon_color.b)

	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	var original_theme: String = app.get_home_theme()
	app.set_home_theme("cabana")
	var home: Node3D = (load("res://worlds/home/home.gd") as GDScript).new()
	root.add_child(home)
	await process_frame
	_check("a casa monta com a cabana", home.get_profile() == cabin)
	var kinds := {}
	for child in home.get_children():
		if child.has_meta("cabin_piece"):
			var kind: String = child.get_meta("cabin_piece")
			kinds[kind] = int(kinds.get(kind, 0)) + 1
	print("    peças: ", kinds)
	_check("lareira, 2 poltronas, tapete, 3 lampiões e o vaso", kinds == {"lareira": 1, "tapete": 1, "poltrona": 2, "lampiao": 3, "vaso": 1})
	var walls: MeshInstance3D = home.get_node("WallWest")
	var wall_material := walls.material_override as ShaderMaterial
	_check("as paredes são toras (log_round = 1)", wall_material != null and wall_material.get_shader_parameter("log_round") == 1.0)
	var glass: MeshInstance3D = home.get_node("WindowView")
	_check("a janela mostra a floresta", (glass.material_override as ShaderMaterial).shader == window_shader)
	var fire: OmniLight3D = home.find_child("FireLight", true, false)
	var energies := {}
	for i in 8:
		await process_frame
		energies[snappedf(fire.light_energy, 0.001)] = true
	_check("a luz do fogo é laranja e tremula (%d valores em 8 quadros)" % energies.size(),
			fire.light_color.r > fire.light_color.b * 2.0 and energies.size() > 3)
	var crackle: AudioStreamPlayer3D = home.find_child("FireCrackle", true, false)
	_check("a lenha estala baixinho, no canal Ambiente", crackle != null and crackle.stream != null and crackle.bus == &"Ambiente")
	_check("o arbusto do vaso entrou", home.find_child("PlantBush", true, false) != null)
	home.queue_free()
	await process_frame

	app.set_home_theme(original_theme)
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	_check("config.cfg devolvido", FileAccess.get_file_as_string(CONFIG) == backup)


func _material(surface: HomeSurface) -> Material:
	return HomeMaterials.from_surface(surface)


## Todos os .gd do projeto, menos as pastas de SCAN_SKIP.
func _scripts(folder: String) -> Array[String]:
	var result: Array[String] = []
	for sub in DirAccess.get_directories_at(folder):
		var path := folder.path_join(sub)
		if not SCAN_SKIP.has(path) and not sub.begins_with("."):
			result.append_array(_scripts(path))
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			result.append(folder.path_join(file))
	return result


## O ambiente do retrato foi gravado à noite: cor e força de noite do perfil.
func _env_matches(lines: Array, loft: HomeProfile) -> bool:
	for line: String in lines:
		if line.begins_with("ENV|"):
			return line.contains("ambient_light_color=%s;" % _color_text(loft.ambient_night_color)) \
					and line.contains("ambient_light_energy=%s" % str(snappedf(loft.ambient_night_energy, 0.01))) \
					and line.contains("background_color=%s;" % _color_text(loft.background_color))
	return false


## Cor como a Godot imprime, sem o ruído de float32: "(0.45, 0.4, 0.36, 1.0)".
func _color_text(color: Color) -> String:
	return "(%s, %s, %s, %s)" % [_short(color.r), _short(color.g), _short(color.b), _short(color.a)]


func _short(x: float) -> String:
	var text := str(snappedf(x, 0.0001))
	return text if text.contains(".") else text + ".0"


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
