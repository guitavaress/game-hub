extends SceneTree
## SPIKE 14.24 (só na branch do spike): os atalhos SUPER chegam à Godot com o
## submap ligado?
##
## Com a janela em foco, o Hyprland entra num submap quase vazio
## ("gamehub_spike"): os atalhos do Omarchy param, e as teclas vêm para cá. A
## tela mostra cada tecla e o atalho do Omarchy que ela acionaria (lido pelo
## tools/linux/spike/spike_binds.lua). Nada é executado.
##
## Saídas (qualquer uma volta os atalhos ao normal):
##   - SUPER + SHIFT + ESC (a tecla de emergência, dentro do submap);
##   - tirar o foco da janela (clicar fora, trocar de workspace);
##   - fechar a janela (Shift + Esc);
##   - 120 s sem nada (trava de segurança do próprio Hyprland).
##
## Uso, da raiz do projeto:
##   godot --path . -s res://tools/linux/spike/spike_submap.gd

const SUBMAP := "gamehub_spike"
const SAFETY_MS := 120000

var label: Label
var lines: PackedStringArray = []
## "SHIFT+SUPER+RETURN" → ["Browser (omarchy-launch-browser)", ...]
var binds := {}
var generation := 0
var poll_left := 0.0
var submap_now := "?"


func _initialize() -> void:
	root.size = Vector2i(1100, 650)
	root.title = "Spike 14.24: submap"
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 18)
	root.add_child(label)
	_load_binds()
	root.focus_entered.connect(_enter)
	root.focus_exited.connect(func() -> void: _leave("perdeu o foco"))
	root.window_input.connect(_on_input)
	_log("%d atalhos do Omarchy lidos. Clique na janela para ligar o submap." % _count_binds())


func _finalize() -> void:
	_leave("fechou")


func _count_binds() -> int:
	var n := 0
	for k: String in binds:
		n += (binds[k] as Array).size()
	return n


func _load_binds() -> void:
	var out: Array = []
	OS.execute("lua", [ProjectSettings.globalize_path("res://tools/linux/spike/spike_binds.lua")], out)
	for line in str(out[0]).split("\n", false):
		var b: Variant = JSON.parse_string(line)
		if b is Dictionary:
			var action: Dictionary = b.action
			var what := str(action.get("cmd", action.get("name", action.kind)))
			if not binds.has(b.keys):
				binds[b.keys] = []
			binds[b.keys].append("%s  [%s: %s]%s" % [b.description, action.kind, what, " (ao soltar)" if b.release else ""])


## Roda Lua dentro do Hyprland. Cuidado: o OS.execute da Godot come as aspas
## duplas dos argumentos, então o Lua daqui usa só aspas simples.
func _hypr(lua: String) -> void:
	var out: Array = []
	if OS.execute("hyprctl", ["eval", lua], out, true) != 0:
		_log("ERRO no hyprctl eval: " + str(out[0]).strip_edges())


func _enter() -> void:
	generation += 1
	# O submap é definido de novo a cada entrada: um "hyprctl reload" apaga as
	# teclas dele (mas deixa o Hyprland dentro do submap!).
	_hypr("hl.define_submap('%s', function() hl.bind('SUPER + SHIFT + ESCAPE', hl.dsp.submap('reset'), {description = 'Game Hub: sair do submap'}) end)" % SUBMAP)
	_hypr("gamehub_spike_gen = %d; hl.dispatch(hl.dsp.submap('%s')); hl.timer(function() if gamehub_spike_gen == %d then hl.dispatch(hl.dsp.submap('reset')) end end, {timeout = %d, type = 'oneshot'})" % [generation, SUBMAP, generation, SAFETY_MS])
	_log("== ganhou o foco: submap ligado (trava de %d s)" % (SAFETY_MS / 1000))


func _leave(why: String) -> void:
	generation += 1
	_hypr("gamehub_spike_gen = %d; hl.dispatch(hl.dsp.submap('reset'))" % generation)
	_log("== %s: submap desligado" % why)


func _process(delta: float) -> bool:
	poll_left -= delta
	if poll_left <= 0.0:
		poll_left = 0.5
		var out: Array = []
		OS.execute("hyprctl", ["submap"], out)
		submap_now = str(out[0]).strip_edges()
	label.text = "submap agora: %s    (SUPER+SHIFT+ESC sai · Shift+Esc fecha)\n\n%s" % [submap_now, "\n".join(lines)]
	return false


func _log(text: String) -> void:
	print(text)
	lines.append(text)
	while lines.size() > 24:
		lines.remove_at(0)


func _on_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE and key.shift_pressed and not key.meta_pressed:
		quit()
		return
	if key.echo or not key.pressed or _is_modifier(key.keycode):
		return
	var id := _hypr_keys(key)
	var found: Array = binds.get(id, [])
	_log("%s  →  %s" % [id, " | ".join(found) if not found.is_empty() else "(nenhum atalho)"])


func _is_modifier(code: Key) -> bool:
	return code in [KEY_META, KEY_SHIFT, KEY_CTRL, KEY_ALT]


## A tecla no formato do leitor ("SHIFT+SUPER+RETURN"): modificadores em ordem
## alfabética e o nome da tecla como o Hyprland escreve.
func _hypr_keys(key: InputEventKey) -> String:
	var mods: PackedStringArray = []
	if key.alt_pressed: mods.append("ALT")
	if key.ctrl_pressed: mods.append("CTRL")
	if key.shift_pressed: mods.append("SHIFT")
	if key.meta_pressed: mods.append("SUPER")
	mods.append(_key_name(key))
	return "+".join(mods)


func _key_name(key: InputEventKey) -> String:
	# A tecla lógica (o wtype, que simula teclas, inventa os códigos físicos).
	var physical := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	# Números: o Omarchy usa o código da tecla (code:10 = 1 ... code:19 = 0).
	if physical >= KEY_1 and physical <= KEY_9:
		return "CODE:%d" % (physical - KEY_1 + 10)
	if physical == KEY_0:
		return "CODE:19"
	var names := {
		KEY_ENTER: "RETURN", KEY_SPACE: "SPACE", KEY_ESCAPE: "ESCAPE", KEY_TAB: "TAB",
		KEY_BACKSPACE: "BACKSPACE", KEY_DELETE: "DELETE", KEY_HOME: "HOME", KEY_END: "END",
		KEY_LEFT: "LEFT", KEY_RIGHT: "RIGHT", KEY_UP: "UP", KEY_DOWN: "DOWN",
		KEY_COMMA: "COMMA", KEY_PERIOD: "PERIOD", KEY_SLASH: "SLASH", KEY_MINUS: "MINUS",
		KEY_EQUAL: "EQUAL", KEY_PRINT: "PRINT", KEY_SEMICOLON: "SEMICOLON",
		KEY_BRACKETLEFT: "BRACKETLEFT", KEY_BRACKETRIGHT: "BRACKETRIGHT", KEY_BACKSLASH: "BACKSLASH",
	}
	if names.has(physical):
		return names[physical]
	return OS.get_keycode_string(physical).to_upper()
