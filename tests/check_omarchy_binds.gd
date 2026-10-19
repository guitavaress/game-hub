extends SceneTree
## Teste dos atalhos do Omarchy (Fase 14.30): o leitor em Lua com um arquivo de
## exemplo, a tabela, a tradução das teclas da Godot e o submap do Hyprland
## (com um hyprctl falso). Nada é executado de verdade.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("== O texto do leitor vira a tabela ==")
	var table := OmarchyBinds.parse("""{"action":{"cmd":"omarchy-launch-terminal","kind":"exec"},"keys":"SUPER+RETURN","release":false}
isto não é json
{"action":{"args":[],"kind":"dsp","name":"window.close"},"keys":"SUPER+W","release":false}
{"action":{"args":[{"workspace":"3"}],"kind":"dsp","name":"window.move"},"keys":"SHIFT+SUPER+CODE:12","release":false}
{"action":{"args":[{"direction":"l"}],"kind":"dsp","name":"focus"},"keys":"SUPER+LEFT","release":false}
{"action":{"cmd":"so-ao-soltar","kind":"exec"},"keys":"F9","release":true}""")
	_check("comando vira exec", table["SUPER+RETURN"] == [{"kind": "exec", "cmd": "omarchy-launch-terminal"}])
	_check("window.close vira a ação fechar", table["SUPER+W"] == [{"kind": "desk", "name": "close"}])
	_check("mover para o workspace 3 vira o monitor de índice 2", table["SHIFT+SUPER+CODE:12"] == [{"kind": "desk", "name": "move_output", "output": 2}])
	_check("foco para a esquerda", table["SUPER+LEFT"] == [{"kind": "desk", "name": "focus_dir", "dir": "l"}])
	_check("o 'soltou' é ignorado", table["F9"] == [{"kind": "ignore"}])
	_check("linha que não é JSON não quebra", table.size() == 5)

	print("== O leitor de verdade, com a config de exemplo ==")
	var example := ProjectSettings.globalize_path("res://tests/fixtures/omarchy_binds_exemplo.lua")
	var read := OmarchyBinds.read_table(example)
	if read.is_empty():
		print("   pulado: o 'lua' não está instalado")
	else:
		_check("texto: SUPER + Enter abre o terminal", read.get("SUPER+RETURN", []) == [{"kind": "exec", "cmd": "omarchy-launch-terminal"}])
		_check("omarchy-menu: SUPER + Space", read.get("SUPER+SPACE", []) == [{"kind": "exec", "cmd": "omarchy-menu toggle"}])
		_check("webapp: SHIFT + SUPER + B", read.get("SHIFT+SUPER+B", []) == [{"kind": "exec", "cmd": "omarchy-launch-webapp https://exemplo.org"}])
		_check("hl.dsp.window.close() é fechar", read.get("SUPER+W", []) == [{"kind": "desk", "name": "close"}])
		_check("tela cheia", read.get("SUPER+F", []) == [{"kind": "desk", "name": "fullscreen"}])
		_check("code:10 é a tecla 1: SUPER + 1 foca o monitor 1", read.get("SUPER+CODE:10", []) == [{"kind": "desk", "name": "focus_output", "output": 0}])
		_check("o laço vai até o 3: SHIFT + SUPER + 3 manda a janela para o monitor 3", read.get("SHIFT+SUPER+CODE:12", []) == [{"kind": "desk", "name": "move_output", "output": 2}])
		_check("duas ações na mesma tecla (ALT + TAB)", (read.get("ALT+TAB", []) as Array).size() == 2)
		_check("hl.unbind tira o atalho", not read.has("SUPER+X"))
		_check("o 'soltou' (F9) não vira ação", read.get("F9", []) == [{"kind": "ignore"}])
		_check("flutuar e função Lua não viram ação, mas a tecla é do atalho",
				read.get("SUPER+T", []) == [{"kind": "ignore"}] and read.get("SUPER+C", []) == [{"kind": "ignore"}])
		var real := OmarchyBinds.read_table()
		print("   atalhos da config de verdade deste computador: ", real.size())
		_check("a config de verdade também lê (se existe)", real.is_empty() or real.has("SUPER+RETURN"))

	print("== A tecla da Godot vira a combinação ==")
	_check("SUPER + Enter", OmarchyBinds.key_id(_key(KEY_ENTER, {"meta": true})) == "SUPER+RETURN")
	_check("os modificadores ficam em ordem (ALT, CTRL, SHIFT, SUPER)",
			OmarchyBinds.key_id(_key(KEY_B, {"meta": true, "shift": true, "alt": true, "ctrl": true})) == "ALT+CTRL+SHIFT+SUPER+B")
	_check("as setas", OmarchyBinds.key_id(_key(KEY_LEFT, {"meta": true})) == "SUPER+LEFT")
	_check("o número 1 é o code:10, e o 3 é o code:12", OmarchyBinds.key_id(_key(KEY_1, {"meta": true})) == "SUPER+CODE:10"
			and OmarchyBinds.key_id(_key(KEY_3, {"meta": true, "shift": true})) == "SHIFT+SUPER+CODE:12")
	_check("o 0 é o code:19", OmarchyBinds.key_id(_key(KEY_0, {"meta": true})) == "SUPER+CODE:19")
	_check("Space e Tab", OmarchyBinds.key_id(_key(KEY_SPACE, {"meta": true})) == "SUPER+SPACE" and OmarchyBinds.key_id(_key(KEY_TAB, {"alt": true})) == "ALT+TAB")
	_check("a tecla de função", OmarchyBinds.key_id(_key(KEY_F9, {})) == "F9")
	_check("uma tecla só de modificador não é atalho", OmarchyBinds.key_id(_key(KEY_META, {"meta": true})) == "")

	print("== O submap do Hyprland (hyprctl falso) ==")
	var host := WindowHostHyprland.new()
	var sent: Array[String] = []
	var accept: Array[bool] = [true]
	host.run_eval = func(lua: String) -> bool:
		sent.append(lua)
		return accept[0]
	_check("o Hyprland sabe do assento", host.supports_seat_shortcuts() and not WindowHost.new().supports_seat_shortcuts())
	_check("sentar liga o submap", host.seat_begin() and sent.size() == 1)
	var lua := sent[0]
	_check("o Lua só tem aspas simples (o OS.execute come as duplas)", not lua.contains("\""))
	_check("define o submap e entra nele", lua.contains("hl.define_submap('gamehub_seat'") and lua.contains("hl.dsp.submap('gamehub_seat')"))
	_check("a tecla de emergência fica dentro do submap", lua.contains("SUPER + SHIFT + ESCAPE") and lua.contains("hl.dsp.submap('reset')"))
	_check("o vigia desliga sozinho se ninguém renovar", lua.contains("hl.timer(") and lua.contains("timeout = %d" % WindowHostHyprland.SEAT_WATCHDOG_MS))
	host.seat_keepalive()
	_check("renovar define de novo, com outra geração (o vigia velho não faz nada)", sent.size() == 2 and sent[1] != sent[0]
			and sent[1].contains("gamehub_seat_gen == 2") and sent[0].contains("gamehub_seat_gen == 1"))
	host.seat_end()
	_check("levantar desliga o submap e invalida o vigia", sent.size() == 3 and sent[2].contains("submap('reset')")
			and sent[2].contains("gamehub_seat_gen = 3"))
	accept[0] = false
	_check("se o Hyprland recusa, o hub sabe (os atalhos ficam desligados)", not host.seat_begin())
	_check("a linha de emergência do bindings.lua vale em qualquer submap", Autostart.emergency_line().contains("submap_universal = true")
			and Autostart.emergency_line().contains("SUPER + SHIFT + ESCAPE"))

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _key(code: Key, mods: Dictionary) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	e.meta_pressed = mods.get("meta", false)
	e.shift_pressed = mods.get("shift", false)
	e.alt_pressed = mods.get("alt", false)
	e.ctrl_pressed = mods.get("ctrl", false)
	return e


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
