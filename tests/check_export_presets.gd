extends SceneTree
## Teste do preset de export do Windows (fase "Mostrar para amigos").
## Só lê res://export_presets.cfg: não monta a cidade e não usa user://.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	_check("export_presets.cfg carregou", err == OK)
	if err == OK:
		var windows_section: String = ""
		for section in cfg.get_sections():
			var name: String = cfg.get_value(section, "name", "")
			if name == "Windows":
				windows_section = section
				break
		
		if windows_section != "":
			# Check 2: preset exists
			_check("preset 'Windows' existe", true)
			# Check 3: platform
			_check("platform = 'Windows Desktop'", cfg.get_value(windows_section, "platform", "") == "Windows Desktop")
			# Check 4: runnable
			_check("runnable = true", cfg.get_value(windows_section, "runnable", false) == true)
			# Check 5: export_path
			_check("export_path = 'build/windows/GameHub.exe'", cfg.get_value(windows_section, "export_path", "") == "build/windows/GameHub.exe")
			# Check 6: exclude_filter contains required items
			var exclude_filter: String = cfg.get_value(windows_section, "exclude_filter", "")
			var filters := exclude_filter.split(",")
			var trimmed_filters := []
			for filter in filters:
				trimmed_filters.append(filter.strip_edges())
			
			_check("exclude_filter contém 'tests/*'", "tests/*" in trimmed_filters)
			_check("exclude_filter contém 'docs/*'", "docs/*" in trimmed_filters)
			_check("exclude_filter contém 'tools/*'", "tools/*" in trimmed_filters)
			_check("exclude_filter contém '*.md'", "*.md" in trimmed_filters)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1