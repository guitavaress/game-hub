extends SceneTree
## Teste da lista de apps (Fase 14.2): o leitor de .desktop do Linux e o AppLibrary.
##
## Usa as pastas de exemplo de tests/fixtures/applications/ (user = ~/.local,
## system = /usr/share), então roda igual no Linux e no Windows.

const FIXTURES: String = "res://tests/fixtures/applications"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var user := ProjectSettings.globalize_path(FIXTURES + "/user")
	var system := ProjectSettings.globalize_path(FIXTURES + "/system")
	var lib: GDScript = load("res://autoload/app_library.gd")
	var config: Node = root.get_node("AppConfig")
	var linux := DesktopAppsLinux.new(PackedStringArray([user, system]), "Hyprland:wlroots", "pt_BR.UTF-8")

	print("== leitor de .desktop ==")
	var apps := linux.list_apps()
	var by_id := {}
	for app in apps:
		by_id[app.id] = app
	print("   achou: ", by_id.keys())
	_check("backend é o 'linux'", linux.platform_name() == "linux")
	_check("app normal entra (foot)", by_id.has("foot"))
	_check("nome em pt_BR vence o padrão", by_id.has("foot") and by_id["foot"].name == "Terminal Foot")
	_check("lê comentário, ícone e classe da janela",
			by_id.has("foot") and by_id["foot"].comment == "Terminal rápido"
			and by_id["foot"].icon_name == "foot" and by_id["foot"].wm_class == "foot")
	_check("categorias viram lista", by_id.has("foot") and by_id["foot"].categories == PackedStringArray(["System", "TerminalEmulator"]))
	_check("[Desktop Action] não vira o Exec do app", by_id.has("foot") and by_id["foot"].exec_line == "foot")
	_check("NoDisplay fica fora", not by_id.has("escondido"))
	_check("Hidden fica fora", not by_id.has("hidden"))
	_check("jogo da Steam fica fora", not by_id.has("jogo-steam"))
	_check("OnlyShowIn=KDE fica fora no Hyprland", not by_id.has("so-kde"))
	_check("NotShowIn=Hyprland fica fora", not by_id.has("menos-hyprland"))
	_check("TryExec inexistente fica fora", not by_id.has("sem-programa"))
	_check("Type=Link fica fora", not by_id.has("link"))
	_check("o de ~/.local vence o de /usr/share",
			by_id.has("duplicado") and by_id["duplicado"].name == "Duplicado do usuário")
	_check("o mesmo id aparece uma vez só", apps.filter(func(a: DesktopApp) -> bool: return a.id == "duplicado").size() == 1)
	_check("subpasta vira 'pasta-nome' e TryExec existente passa", by_id.has("sub-editor"))
	_check("Exec perde o %U", by_id.has("navegador") and by_id["navegador"].exec_line == "navegador")

	var kde := DesktopAppsLinux.new(PackedStringArray([user, system]), "KDE", "")
	var kde_ids := kde.list_apps().map(func(a: DesktopApp) -> String: return a.id)
	_check("no KDE o OnlyShowIn=KDE entra", "so-kde" in kde_ids)
	_check("sem idioma, o nome é o padrão", kde.list_apps().filter(func(a: DesktopApp) -> bool: return a.id == "foot")[0].name == "Foot")
	_check("clean_exec: '%%' vira '%' e %f some", DesktopAppsLinux.clean_exec("x --a=100%% %f  %U") == "x --a=100%")
	_check("pasta que não existe não quebra", DesktopAppsLinux.new(PackedStringArray(["/nao/existe"]), "", "").list_apps().is_empty())
	_check("DesktopApps responde nesta máquina", DesktopApps.platform_name() != "" and DesktopApps.list_apps() is Array)

	print("== categorias ==")
	_check("foot é Sistema", lib.category_of(by_id["foot"]) == "sistema")
	_check("navegador é Internet", lib.category_of(by_id["navegador"]) == "internet")
	_check("Utility;Development é Programação", lib.category_of(by_id["sub-editor"]) == "programacao")
	_check("sem categoria conhecida é Outros", lib.category_of(by_id["duplicado"]) == "diversos")

	print("== ordem e ocultos ==")
	var all: Array[DesktopApp] = [by_id["navegador"], by_id["foot"], by_id["duplicado"], by_id["sub-editor"]]
	var order := func(list: Array[DesktopApp]) -> Array: return list.map(func(a: DesktopApp) -> String: return a.id)
	var hidden: Array[String] = []
	var recent: Array[String] = []
	_check("sem recentes: por nome", order.call(lib.sorted_apps(all, hidden, recent)) == ["duplicado", "sub-editor", "navegador", "foot"])
	recent = ["foot", "navegador"]
	_check("recentes primeiro, na ordem deles, depois por nome",
			order.call(lib.sorted_apps(all, hidden, recent)) == ["foot", "navegador", "duplicado", "sub-editor"])
	hidden = ["foot"]
	_check("ocultos saem", not "foot" in order.call(lib.sorted_apps(all, hidden, recent)))
	_check("a lista de entrada não muda", all.size() == 4 and all[0].id == "navegador")

	print("== config.cfg ==")
	var backup := _backup_config()
	config._config.set_value("apps", "ocultos", " a, b ,a,,c")
	_check("get_hidden_apps limpa espaços e repetidos", config.get_hidden_apps() == ["a", "b", "c"])
	var ids: Array[String] = ["x", "y"]
	config.set_recent_apps(ids)
	_check("set_recent_apps grava e lê de volta", config.get_recent_apps() == ids)
	_check("o arquivo ganhou a seção [apps]", FileAccess.get_file_as_string(config.CONFIG_PATH).contains("[apps]"))
	_restore_config(backup)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _backup_config() -> String:
	return FileAccess.get_file_as_string(root.get_node("AppConfig").CONFIG_PATH)


func _restore_config(text: String) -> void:
	var config: Node = root.get_node("AppConfig")
	var file := FileAccess.open(config.CONFIG_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	config._config.load(config.CONFIG_PATH)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
