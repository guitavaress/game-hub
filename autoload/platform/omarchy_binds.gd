class_name OmarchyBinds
extends RefCounted
## Os ATALHOS DO OMARCHY (Fase 14.30): o que o Hyprland faria com cada combinação
## de teclas, lido da config de verdade do usuário (~/.config/hypr/hyprland.lua).
## Quem lê é um script em Lua (omarchy_binds.lua, rodado pelo "lua" que o
## Hyprland já exige): ele roda a config com um "hl" de mentira que só anota os
## atalhos, e imprime uma linha JSON por atalho. Aqui as linhas viram uma
## TABELA: combinação -> lista de ações (o Hyprland deixa várias ações na mesma
## tecla, como ALT + TAB).
##
## Cada ação é um Dictionary:
##   {"kind": "exec", "cmd": "omarchy-launch-terminal"}     comando, aberto DENTRO do hub
##   {"kind": "desk", "name": "close"}                      ação do arranjo das janelas
##       nomes: close, fullscreen, focus_dir (dir: "l" "r" "u" "d"),
##              focus_output (output: 0, 1, 2) e move_output (output: 0, 1, 2)
##   {"kind": "ignore"}                                     o hub não faz nada (flutuar, grupos, arrastar...),
##                                                           mas a tecla é do atalho: não vai para o app.
## Código de sistema (o "lua", o caminho do script) só mora em autoload/platform/.

## As teclas só de modificador não viram atalho sozinhas.
const MODIFIERS: Array[Key] = [KEY_META, KEY_SHIFT, KEY_CTRL, KEY_ALT]

## Nomes das teclas que o Hyprland escreve de um jeito próprio.
const KEY_NAMES: Dictionary = {
	KEY_ENTER: "RETURN", KEY_KP_ENTER: "RETURN", KEY_SPACE: "SPACE", KEY_ESCAPE: "ESCAPE", KEY_TAB: "TAB",
	KEY_BACKSPACE: "BACKSPACE", KEY_DELETE: "DELETE", KEY_HOME: "HOME", KEY_END: "END",
	KEY_PAGEUP: "PRIOR", KEY_PAGEDOWN: "NEXT", KEY_INSERT: "INSERT",
	KEY_LEFT: "LEFT", KEY_RIGHT: "RIGHT", KEY_UP: "UP", KEY_DOWN: "DOWN",
	KEY_COMMA: "COMMA", KEY_PERIOD: "PERIOD", KEY_SLASH: "SLASH", KEY_MINUS: "MINUS",
	KEY_EQUAL: "EQUAL", KEY_PRINT: "PRINT", KEY_SEMICOLON: "SEMICOLON",
	KEY_BRACKETLEFT: "BRACKETLEFT", KEY_BRACKETRIGHT: "BRACKETRIGHT", KEY_BACKSLASH: "BACKSLASH",
	KEY_APOSTROPHE: "APOSTROPHE", KEY_QUOTELEFT: "GRAVE",
}


## Lê a config do usuário (ou o arquivo `config`, nos testes) e devolve a tabela.
## Vazia se o "lua" não existe ou a config não rodou.
static func read_table(config: String = "") -> Dictionary:
	var args := PackedStringArray([ProjectSettings.globalize_path("res://autoload/platform/omarchy_binds.lua")])
	if not config.is_empty():
		args.append(config)
	var output: Array = []
	if OS.execute("lua", args, output) != 0 or output.is_empty():
		return {}
	return parse(str(output[0]))


## As linhas JSON do leitor viram a tabela: combinação -> lista de ações.
static func parse(text: String) -> Dictionary:
	var table := {}
	for line in text.split("\n", false):
		if not line.begins_with("{"):
			continue  # aviso do leitor ("a config parou no meio") ou lixo: não é um atalho
		var bind: Variant = JSON.parse_string(line)
		if not bind is Dictionary or not (bind as Dictionary).has("keys"):
			continue
		var keys := str(bind["keys"])
		if not table.has(keys):
			table[keys] = []
		(table[keys] as Array).append(to_action(bind))
	return table


## Uma linha do leitor vira uma ação do hub.
static func to_action(bind: Dictionary) -> Dictionary:
	var action: Dictionary = bind.get("action", {})
	if bind.get("release", false):
		return {"kind": "ignore"}  # o "soltou" do Hyprland (ex.: F9) não tem o que fazer aqui
	match str(action.get("kind", "")):
		"exec":
			return {"kind": "exec", "cmd": str(action.get("cmd", ""))}
		"dsp":
			return _from_dispatcher(str(action.get("name", "")), action.get("args", []))
	return {"kind": "ignore"}


static func _from_dispatcher(name: String, args: Array) -> Dictionary:
	var first: Dictionary = args[0] if not args.is_empty() and args[0] is Dictionary else {}
	match name:
		"window.close":
			return {"kind": "desk", "name": "close"}
		"window.fullscreen":
			return {"kind": "desk", "name": "fullscreen"}
		"focus":
			if first.has("direction"):
				return {"kind": "desk", "name": "focus_dir", "dir": str(first["direction"])}
			if first.has("workspace") and str(first["workspace"]).is_valid_int():
				return {"kind": "desk", "name": "focus_output", "output": int(str(first["workspace"])) - 1}
		"window.move":
			if first.has("workspace") and str(first["workspace"]).is_valid_int():
				return {"kind": "desk", "name": "move_output", "output": int(str(first["workspace"])) - 1}
	return {"kind": "ignore"}


## A combinação de um evento de teclado no formato da tabela: modificadores em
## ordem alfabética e o nome da tecla como o Hyprland escreve ("SHIFT+SUPER+RETURN").
## "" para uma tecla só de modificador.
static func key_id(event: InputEventKey) -> String:
	var code := event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	if code in MODIFIERS or code == KEY_NONE:
		return ""
	var parts := PackedStringArray()
	if event.alt_pressed:
		parts.append("ALT")
	if event.ctrl_pressed:
		parts.append("CTRL")
	if event.shift_pressed:
		parts.append("SHIFT")
	if event.meta_pressed:
		parts.append("SUPER")
	parts.append(_key_name(code))
	return "+".join(parts)


static func _key_name(code: Key) -> String:
	# Números: o Omarchy usa o código da tecla (code:10 = 1 ... code:19 = 0).
	if code >= KEY_1 and code <= KEY_9:
		return "CODE:%d" % (code - KEY_1 + 10)
	if code == KEY_0:
		return "CODE:19"
	if KEY_NAMES.has(code):
		return KEY_NAMES[code]
	return OS.get_keycode_string(code).to_upper()
