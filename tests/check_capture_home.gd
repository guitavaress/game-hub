extends "res://tools/capturar_casa.gd"
## Confere os enquadramentos sem janela e devolve as escolhas do usuário.

var failures: int = 0


func _initialize() -> void:
	_check_home.call_deferred()


func _check_home() -> void:
	var config_path: String = "user://config.cfg"
	var had_config: bool = FileAccess.file_exists(config_path)
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(config_path) if had_config else PackedByteArray()
	var config: Node = root.get_node("AppConfig")
	var original_quality: String = config.call("get_quality")
	var original_theme: String = config.call("get_home_theme")
	var original_layout: String = config.call("get_home_layout")
	var original_wall: String = config.call("get_home_wall_color")
	var original_neon: String = config.call("get_home_neon_color")
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 200)
	for setter: String in ["set_home_layout", "set_home_wall_color", "set_home_neon_color"]:
		config.call(setter, "")
	var catalog: Resource = load("res://profiles/home_catalog.tres")
	for theme: String in ["loft", "cabana"]:
		_choose_settings("leve", theme)
		_check("tema da captura aplicado", config.call("get_home_theme") == theme)
		_check("qualidade da captura aplicada", config.call("get_quality") == "leve")
		for layout: Resource in catalog.get("layouts"):
			config.call("set_home_layout", layout.get("id"))
			var home: Node3D = load("res://worlds/home/home.gd").new()
			# Posição e giro também exercitam a conversão para o mundo.
			home.position = Vector3(50.0, 0.0, -70.0)
			home.rotation.y = 0.3
			root.add_child(home)
			var points: Array[Dictionary] = _points(home)
			var names: Array[String] = []
			var room: Vector3 = home.get("ROOM_SIZE")
			var bounds: AABB = AABB(Vector3(-room.x / 2.0, 0.0, -room.z / 2.0), room)
			for point: Dictionary in points:
				var label: String = "%s/%s/%s" % [theme, layout.get("id"), point["name"]]
				names.append(point["name"])
				var eye: Vector3 = home.to_local(point["eye"])
				var target: Vector3 = home.to_local(point["target"])
				_check(label + ": olho dentro da sala", bounds.has_point(eye))
				_check(label + ": olha para dentro da sala", bounds.has_point(target) and eye.distance_to(target) > 0.01)
			var expected: Array[String] = ["nascer", "janela", "sofa", "estante"]
			_check("quatro pontos com nomes únicos", names == expected)
			var spawn: Transform3D = home.call("get_spawn_transform")
			_check("nascer preserva o giro da disposição",
				Vector3(points[0]["eye"] - points[0]["target"]).normalized().is_equal_approx(spawn.basis.z))
			home.free()
		_restore_settings()
		_check("qualidade original restaurada", config.call("get_quality") == original_quality)
		_check("tema original restaurado", config.call("get_home_theme") == original_theme)
	_check("recusa a raiz do repositório", not _folder_allowed("res://"))
	_check("recusa pasta relativa dentro do repositório", not _folder_allowed("capturas"))
	_check("recusa a raiz relativa", not _folder_allowed("."))
	_check("recusa subpasta do repositório", not _folder_allowed("res://capturas"))
	_check("recusa caminho com volta por ../", not _folder_allowed("res://tools/../capturas"))
	_check("recusa caminho absoluto interno", not _folder_allowed(ProjectSettings.globalize_path("res://tests")))
	_check("aceita pasta temporária externa", _folder_allowed(OS.get_environment("TEMP") if OS.get_name() == "Windows" else "/tmp"))
	_check("aceita pasta irmã com mesmo prefixo", _folder_allowed(ProjectSettings.globalize_path("res://").trim_suffix("/") + "-capturas"))
	if OS.get_name() == "Windows":
		_check("recusa variação de caixa no Windows", not _folder_allowed(ProjectSettings.globalize_path("res://tools").to_upper()))
	config.call("set_home_layout", original_layout)
	config.call("set_home_wall_color", original_wall)
	config.call("set_home_neon_color", original_neon)
	# O conteúdo exato volta também: não se perde nenhuma outra escolha.
	if had_config:
		var file: FileAccess = FileAccess.open(config_path, FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
		_check("config.cfg devolvido byte a byte", FileAccess.get_file_as_bytes(config_path) == backup)
	else:
		DirAccess.remove_absolute(config_path)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
