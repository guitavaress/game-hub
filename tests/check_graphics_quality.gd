extends SceneTree
## Teste do anti-aliasing e da sombra por qualidade (Fase 10.2).
##
## Aplica cada qualidade pelo AppConfig (como o menu faz) e confere, na
## janela, o MSAA, o SMAA/FXAA e a escala do 3D; num sol de teste
## (DirectionalLight3D), a distância da sombra. A qualidade do usuário é
## devolvida no fim.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app := root.get_node("AppConfig")
	var original_quality: String = app.get_quality()
	var helper: GDScript = load("res://autoload/graphics_quality.gd")
	var sun := DirectionalLight3D.new()
	root.add_child(sun)

	var expected := {
		"alta": [Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_SMAA, 1.0, 120.0],
		"media": [Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_SMAA, 1.0, 120.0],
		"leve": [Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_FXAA, 0.5, 70.0],
	}
	for level: String in expected:
		print("== %s ==" % level)
		app.set_quality(level)
		helper.apply_to_sun(sun, level)
		var want: Array = expected[level]
		_check("MSAA %d" % want[0], root.msaa_3d == want[0])
		_check("anti-aliasing de tela %d (1 = FXAA, 2 = SMAA)" % want[1], root.screen_space_aa == want[1])
		_check("3D em %d%%" % roundi(want[2] * 100.0), is_equal_approx(root.scaling_3d_scale, want[2]))
		_check("sombra do sol até %d m" % roundi(want[3]), is_equal_approx(sun.directional_shadow_max_distance, want[3]))
		_check("a dica explica o anti-aliasing", helper.describe(level).contains("AA"))

	# A cidade usa o mesmo ajudante no sol dela e troca junto com o menu.
	print("== sol da cidade ==")
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	var city_sun: DirectionalLight3D = city.get_node("Sun")
	app.set_quality("leve")
	_check("Leve: sombra do sol da cidade curta", is_equal_approx(city_sun.directional_shadow_max_distance, 70.0))
	app.set_quality("alta")
	_check("Alta: sombra do sol da cidade longa", is_equal_approx(city_sun.directional_shadow_max_distance, 120.0))

	app.set_quality(original_quality)
	_check("qualidade do usuário devolvida (%s)" % original_quality, app.get_quality() == original_quality)
	sun.queue_free()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
