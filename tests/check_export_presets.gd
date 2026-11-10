extends SceneTree
## Teste do preset de export do Windows (fase "Mostrar para amigos").
## Só lê res://export_presets.cfg: não monta a cidade e não usa user://.
## Sem o preset "Windows", todas as conferências dele contam como falha.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	_check("export_presets.cfg carregou", err == OK)

	var windows_section := ""
	for section in cfg.get_sections():
		if cfg.get_value(section, "name", "") == "Windows":
			windows_section = section
			break
	_check("preset 'Windows' existe", windows_section != "")

	# Sem a seção, o get_value devolve o padrão e a conferência falha sozinha.
	_check("platform = 'Windows Desktop'",
		cfg.get_value(windows_section, "platform", "") == "Windows Desktop")
	_check("runnable = true", cfg.get_value(windows_section, "runnable", false) == true)
	_check("export_path = 'build/windows/GameHub.exe'",
		cfg.get_value(windows_section, "export_path", "") == "build/windows/GameHub.exe")

	# Os dois presets (Windows e Linux) têm que deixar de fora as sobras do projeto.
	for preset_name in ["Windows", "Linux"]:
		var section := ""
		for candidate in cfg.get_sections():
			if cfg.get_value(candidate, "name", "") == preset_name:
				section = candidate
				break
		_check("preset '%s' existe" % preset_name, section != "")
		var filters: Array[String] = []
		for item in str(cfg.get_value(section, "exclude_filter", "")).split(","):
			filters.append(item.strip_edges())
		for wanted in ["tests/*", "docs/*", "tools/*", "*.md", "game-hub-brand-kit/*", ".agents/*"]:
			_check("%s: exclude_filter contém '%s'" % [preset_name, wanted], wanted in filters)

	# A versão do hub vive só no project.godot.
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check("application/config/version existe e não está vazio", version != "")

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
