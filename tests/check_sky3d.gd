extends SceneTree
## Teste do céu Sky3D (spike de 2026-10, opção Céu do menu):
##   - "fotos" (padrão): WorldEnvironment, o sol "Sun" e o céu de fotos;
##   - "sky3d": troca na hora, com um céu só na cena e o mesmo Environment;
##   - o sol e a lua do Sky3D não entram em casa nem no corpo do espelho, e a
##     sombra segue a qualidade;
##   - a hora vem do DayNight (menu "Hora" e F8), e a noite continua avisada;
##   - as estrelas são as nossas (CC0): a Via Láctea CC BY ficou de fora;
##   - voltar para "fotos" devolve o céu de antes.
## Guarda o config.cfg e devolve no fim.

const INTERIOR_MASK := 1 << 19  # camada 20 (Home.INTERIOR_LAYER)
const REFLECTION_MASK := 1 << 18  # camada 19 (AvatarBody.REFLECTION_LAYER)
const CONFIG := "user://config.cfg"
const MILKYWAY_DIR := "res://addons/sky_3d/assets/thirdparty/textures/milkyway"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var backup := FileAccess.get_file_as_string(CONFIG)
	var app := root.get_node("AppConfig")
	var original_sky: String = app.get_sky()
	var original_time: String = app.get_time_of_day()
	var original_quality: String = app.get_quality()
	app.set_sky("fotos")
	app.set_time_of_day("relogio")

	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	var day_night: Node = city._day_night
	# Carregado aqui (e não pelo nome da classe): o script usa o AppConfig.
	var clock: GDScript = load("res://worlds/city/day_night.gd")
	var environment: Environment = city._environment

	print("== Céu de fotos (padrão) ==")
	_check("tem o sol \"Sun\"", city.get_node_or_null("Sun") is DirectionalLight3D)
	_check("não tem Sky3D", city.get_node_or_null("Sky3D") == null)
	_check("um céu só na cena", _world_environments(city) == 1)
	_check("o céu é o das fotos", environment.sky != null
			and environment.sky.sky_material.shader.resource_path.ends_with("sky_blend.gdshader"))

	print("== Trocando para o Sky3D ==")
	app.set_sky("sky3d")
	await process_frame
	var sky3d: Node = city.get_node_or_null("Sky3D")
	_check("o Sky3D entrou", sky3d != null)
	if sky3d == null:
		_finish(backup)
		return
	_check("o sol \"Sun\" saiu", city.get_node_or_null("Sun") == null)
	_check("um céu só na cena", _world_environments(city) == 1)
	_check("o Sky3D usa o mesmo Environment da cidade", sky3d.environment == environment)
	_check("o céu agora é o do Sky3D", environment.sky.sky_material == sky3d.sky_material
			and sky3d.sky_material.shader.resource_path.begins_with("res://addons/sky_3d/"))
	_check("a neblina do Sky3D fica desligada (vale a do DayNight)", not sky3d.fog_enabled)
	_check("o DayNight aponta para o Sky3D", day_night.sky3d == sky3d and day_night.sun == null)
	_check("a hora do Sky3D não anda sozinha", not sky3d.game_time_enabled)
	for light: DirectionalLight3D in [sky3d.sun, sky3d.moon]:
		_check("%s não ilumina a casa" % light.name, light.light_cull_mask & INTERIOR_MASK == 0)
		_check("%s não ilumina o corpo do espelho" % light.name, light.light_cull_mask & REFLECTION_MASK == 0)
		_check("%s ilumina a cidade (camada 1)" % light.name, light.light_cull_mask & 1 == 1)
	app.set_quality("leve")
	_check("Leve: sombra do sol curta", is_equal_approx(sky3d.sun.directional_shadow_max_distance, 70.0))
	app.set_quality("alta")
	_check("Alta: sombra da lua longa", is_equal_approx(sky3d.moon.directional_shadow_max_distance, 120.0))

	print("== A hora vem do DayNight ==")
	app.set_time_of_day("noite")
	await process_frame
	_check("Hora = noite: Sky3D às 22h (veio %.2f)" % sky3d.current_time,
			is_equal_approx(sky3d.current_time, clock.FIXED_NIGHT_HOUR))
	_check("Hora = noite: o Sky3D está de noite", sky3d.is_night())
	_check("Hora = noite: a cidade foi avisada", day_night.get_night() > 0.99)
	app.set_time_of_day("dia")
	await process_frame
	_check("Hora = dia: Sky3D às 14h (veio %.2f)" % sky3d.current_time,
			is_equal_approx(sky3d.current_time, clock.FIXED_DAY_HOUR))
	_check("Hora = dia: o Sky3D está de dia", sky3d.is_day())
	_check("Hora = dia: o sol está acima do horizonte", sky3d.sun.global_basis.z.y > 0.0)
	var advance := InputEventAction.new()
	advance.action = &"advance_time"
	advance.pressed = true
	day_night._unhandled_input(advance)
	_check("F8: o Sky3D anda 3 horas (veio %.2f)" % sky3d.current_time,
			is_equal_approx(sky3d.current_time, clock.FIXED_DAY_HOUR + clock.HOURS_PER_F8))

	print("== Estrelas CC0 ==")
	_check("o mapa de estrelas é o nosso", sky3d.sky.starmap_texture.resource_path == "res://assets/generated/sky_starmap.png")
	_check("as estrelas soltas são as nossas", sky3d.sky.star_field_texture.resource_path == "res://assets/generated/sky_starfield.png")
	_check("a Via Láctea (CC BY 4.0) não está no projeto", not DirAccess.dir_exists_absolute(MILKYWAY_DIR))

	print("== De volta às fotos ==")
	app.set_sky("fotos")
	await process_frame
	_check("o Sky3D saiu", city.get_node_or_null("Sky3D") == null)
	_check("o sol \"Sun\" voltou", city.get_node_or_null("Sun") is DirectionalLight3D)
	_check("um céu só na cena", _world_environments(city) == 1)
	_check("o céu voltou a ser o das fotos",
			environment.sky.sky_material.shader.resource_path.ends_with("sky_blend.gdshader"))
	_check("o DayNight voltou ao sol de fotos", day_night.sky3d == null and day_night.sun != null)

	app.set_quality(original_quality)
	app.set_time_of_day(original_time)
	app.set_sky(original_sky)
	_finish(backup)


func _finish(backup: String) -> void:
	var restore := FileAccess.open(CONFIG, FileAccess.WRITE)
	restore.store_string(backup)
	restore.close()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## Quantos WorldEnvironment há na cidade (o Sky3D também é um).
func _world_environments(city: Node) -> int:
	return city.find_children("*", "WorldEnvironment", true, false).size()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
