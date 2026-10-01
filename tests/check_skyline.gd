extends SceneTree
## Teste da skyline e da borda da cidade (P2.14).

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame
	var skyline = city.get_node("Skyline")
	var ring: MeshInstance3D = skyline.get_node("Ring")
	var mesh: CylinderMesh = ring.mesh
	_check("anel de 400 m, sem tampas", is_equal_approx(mesh.top_radius, 400.0) and not mesh.cap_top and not mesh.cap_bottom)
	_check("sem sombra", ring.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var material: ShaderMaterial = ring.material_override
	var texture: Texture2D = material.get_shader_parameter("silhouettes")
	var image := texture.get_image()
	var ground_row := int(70.0 / (120.0 / 256.0))
	var filled := 0
	for x in range(0, 2048, 8):
		if image.get_pixel(x, ground_row - 20).r > 0.5:  # ~9 m acima do chão
			filled += 1
	print("   colunas com prédio a ~9 m: %d de 256" % filled)
	_check("skyline quase contínua perto do chão", filled > 200)

	city._on_night_changed(1.0)
	_check("à noite escurece", material.get_shader_parameter("night") > 0.99)
	city._on_night_changed(0.0)
	_check("de dia, cor da neblina", material.get_shader_parameter("night") < 0.01)

	var barriers := 0
	var walls_low := true
	for child in city.get_children():
		if child.name.begins_with("Barrier"):
			barriers += 1
			var box: BoxShape3D = child.get_child(0).shape
			if box.size.y < 2.9:
				walls_low = false
		elif child.name.begins_with("Wall") and child is CSGBox3D:
			if child.size.y > 1.01:
				walls_low = false
	_check("mureta de 1 m + 4 barreiras de 3 m", barriers == 4 and walls_low)
	_check("grade (MultiMesh)", city.has_node("Railing") and city.get_node("Railing").multimesh.instance_count > 1000)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
