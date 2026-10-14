extends SceneTree
## Teste de abrir o hub ao entrar (Fase 14.10): Autostart e a aba "Sistema".
##
## Usa uma pasta temporária no lugar de ~/.config/autostart (nunca mexe na de
## verdade), então roda igual no Linux e no Windows.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var dir := ProjectSettings.globalize_path("user://teste_autostart")
	DirAccess.remove_absolute(dir + "/game-hub.desktop")
	DirAccess.remove_absolute(dir)

	print("== autostart (Linux simulado) ==")
	var auto := Autostart.new(dir, true, "/opt/godot/godot", "/home/eu/meu hub")
	_check("este sistema sabe fazer autostart", auto.supported())
	_check("começa desligado", not auto.is_enabled() and not FileAccess.file_exists(dir + "/game-hub.desktop"))
	_check("ligar cria a pasta e o arquivo", auto.set_enabled(true) and FileAccess.file_exists(dir + "/game-hub.desktop"))
	var text := FileAccess.get_file_as_string(dir + "/game-hub.desktop")
	print("   ", text.replace("\n", "\n    "))
	_check("é um .desktop de aplicativo", text.begins_with("[Desktop Entry]\n") and text.contains("Type=Application\n"))
	_check("o Exec abre o godot no projeto (com aspas, por causa do espaço)",
			text.contains('Exec="/opt/godot/godot" --path "/home/eu/meu hub"\n'))
	_check("conta como ligado", auto.is_enabled())
	_check("ligar de novo não quebra", auto.set_enabled(true) and auto.is_enabled())
	_check("desligar apaga o arquivo", auto.set_enabled(false) and not FileAccess.file_exists(dir + "/game-hub.desktop") and not auto.is_enabled())
	_check("desligar o que já está desligado dá certo", auto.set_enabled(false))
	auto.set_enabled(true)
	var file := FileAccess.open(dir + "/game-hub.desktop", FileAccess.WRITE)
	file.store_string("[Desktop Entry]\nHidden=true\n")
	file = null
	_check("Hidden=true conta como desligado", not auto.is_enabled())
	auto.set_enabled(false)

	print("== aspas e a linha do atalho ==")
	_check("Exec: $ e % ganham escape", Autostart._desktop_quote("/a b/$x%y") == '"/a b/\\$x%%y"')
	_check("shell: aspa simples é escapada", Autostart._shell_quote("a'b") == "'a'\\''b'")
	_check("shell: caminho simples não ganha aspas", Autostart._shell_quote("/opt/x-1/godot") == "/opt/x-1/godot")
	var simple := Autostart.new(dir, true, "/opt/godot/godot", "/home/eu/hub")
	_check("a linha do atalho chama o launch-or-focus com o nome da janela",
			simple.shortcut_line() == 'o.bind("SUPER + H", "Game Hub", "omarchy-launch-or-focus \'Game Hub\' \'/opt/godot/godot --path /home/eu/hub\'")')
	_check("caminho com espaço fica entre aspas dentro do comando", auto.shortcut_line().contains("meu hub"))
	var exported := Autostart.new(dir, true, "/opt/hub/hub", "")
	_check("sem pasta de projeto (hub exportado), sem --path", not exported.exec_line().contains("--path") and not exported.shortcut_line().contains("--path"))

	print("== sistema sem suporte ==")
	var other := Autostart.new(dir, false)
	_check("não dá: supported falso, nada é escrito",
			not other.supported() and not other.set_enabled(true) and not other.is_enabled() and not FileAccess.file_exists(dir + "/game-hub.desktop"))

	print("== a aba Sistema ==")
	var view := SystemSettingsView.new()
	view.autostart = Autostart.new(dir, true, "/opt/godot/godot", "/proj")
	root.add_child(view)
	await process_frame
	var check: CheckButton = view.get_node("AutostartCheck") if view.has_node("AutostartCheck") else view.find_child("AutostartCheck", true, false)
	_check("o interruptor começa desligado", check != null and not check.button_pressed)
	check.button_pressed = true
	_check("ligar o interruptor cria o arquivo", view.autostart.is_enabled())
	check.button_pressed = false
	_check("desligar o interruptor apaga o arquivo", not view.autostart.is_enabled())
	view.autostart.set_enabled(true)
	view.refresh()
	_check("refresh marca o que está no disco", check.button_pressed)
	view.autostart.set_enabled(false)
	view._on_copy()
	_check("copiar põe a linha na área de transferência", DisplayServer.clipboard_get() == view.autostart.shortcut_line()
			or DisplayServer.get_name() == "headless")
	_check("e avisa", view.find_child("Status", true, false).text == SystemSettingsView.COPIED_TEXT)

	DirAccess.remove_absolute(dir)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
