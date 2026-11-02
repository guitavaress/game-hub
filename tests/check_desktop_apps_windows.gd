extends SceneTree
## Teste da lista de apps do Windows (Fase 14.4): os atalhos do Menu Iniciar.
##
## Usa as pastas de exemplo de tests/fixtures/start_menu/ (user = AppData,
## common = ProgramData), então roda igual no Linux e no Windows. No Windows,
## também lê o Menu Iniciar de verdade (sem exigir nenhum app).

const FIXTURES: String = "res://tests/fixtures/start_menu"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var user := ProjectSettings.globalize_path(FIXTURES + "/user/Programs")
	var common := ProjectSettings.globalize_path(FIXTURES + "/common/Programs")
	var backend := DesktopAppsWindows.new(PackedStringArray([user, common]))

	print("== atalhos de exemplo ==")
	var apps := backend.list_apps()
	var by_id := {}
	for app in apps:
		by_id[app.id] = app
	print("   achou: ", by_id.keys())
	_check("backend é o 'windows'", backend.platform_name() == "windows")
	_check("atalho normal entra (Brave)", by_id.has("Brave") and by_id["Brave"].name == "Brave")
	_check("o mesmo atalho nas duas pastas aparece uma vez só, o do usuário",
			apps.filter(func(a: DesktopApp) -> bool: return a.id == "Brave").size() == 1
			and by_id["Brave"].source_path.begins_with(user))
	_check("subpasta entra, com id de caminho relativo", by_id.has("Utilitários/Bloco de Notas"))
	_check("o nome é só o nome do arquivo", by_id["Utilitários/Bloco de Notas"].name == "Bloco de Notas")
	_check("o comando de abrir é o próprio atalho", by_id["Brave"].exec_line == by_id["Brave"].source_path
			and by_id["Brave"].source_path.ends_with("Brave.lnk"))
	_check("subpasta de ProgramData entra (Steam)", by_id.has("Steam/Steam"))
	_check("'Desinstalar' fica fora", not by_id.has("Utilitários/Desinstalar Brave"))
	_check("'Uninstall' fica fora", not by_id.has("Brave/Uninstall Brave"))
	_check("atalho .url (jogo da Steam) fica fora", not by_id.has("Steam/Balatro"))
	_check("arquivo que não é atalho fica fora", not by_id.has("Leia-me"))
	_check("sem ícone: a caixa mostra a inicial", by_id["Brave"].icon_name == "" and backend.find_icon("Brave") == "")
	_check("pasta que não existe não quebra", DesktopAppsWindows.new(PackedStringArray(["C:/nao/existe"])).list_apps().is_empty())

	print("== esta máquina ==")
	_check("DesktopApps responde", DesktopApps.platform_name() != "" and DesktopApps.list_apps() is Array)
	if OS.get_name() == "Windows":
		var real := DesktopAppsWindows.new().list_apps()
		print("   Menu Iniciar de verdade: %d atalhos" % real.size())
		var ok := true
		for app in real:
			ok = ok and app.id != "" and app.name != "" and app.source_path.ends_with(".lnk")
		_check("Windows: cada atalho tem id, nome e caminho", ok)
		_check("Windows: DesktopApps usa o backend 'windows'", DesktopApps.platform_name() == "windows")
	else:
		print("   (não é Windows: a pasta de verdade fica para o GitHub Actions)")

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
