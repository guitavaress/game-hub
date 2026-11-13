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
		# 18.2: o .mcp.json e o opencode.json entravam no pck (são .json na raiz);
		# as pastas com ponto e a build/ ficam de fora por garantia.
		for wanted in ["tests/*", "docs/*", "tools/*", "*.md", "game-hub-brand-kit/*", ".agents/*",
				".mcp.json", "opencode.json", ".claude/*", ".codex/*", ".vscode/*", "build/*"]:
			_check("%s: exclude_filter contém '%s'" % [preset_name, wanted], wanted in filters)

	# O ícone (18.2): o da janela vem do project.godot; o do .exe no Explorer, do
	# preset Windows (a Godot troca sozinha, sem rcedit, com modify_resources).
	var icon := str(ProjectSettings.get_setting("application/config/icon", ""))
	_check("application/config/icon aponta para um arquivo que existe",
		icon != "" and FileAccess.file_exists(icon))
	_check("Windows: modify_resources = true (ícone do .exe)",
		cfg.get_value(windows_section + ".options", "application/modify_resources", false) == true)
	_check("Windows: application/icon = o mesmo ícone da janela",
		icon != "" and cfg.get_value(windows_section + ".options", "application/icon", "") == icon)

	# A versão do hub vive só no project.godot.
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check("application/config/version existe e não está vazio", version != "")

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
