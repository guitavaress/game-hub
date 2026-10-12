class_name KeyHint
extends HBoxContainer
## TECLAS DESENHADAS QUE TROCAM (Fase 12.7): uma dica como "back" mostra "Esc"
## no teclado e "B" (vermelho) no controle, e troca sozinha quando o jogador
## muda de aparelho (InputDevice.device_changed). Os nomes das dicas estão na
## tabela InputDevice.HINTS.
##
## Uso: `row.add_child(KeyHint.create("interact"))`.

var hint_name: String = ""


static func create(name_of_hint: String) -> KeyHint:
	var hint := KeyHint.new()
	hint.hint_name = name_of_hint
	return hint


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	InputDevice.device_changed.connect(func(_gamepad: bool) -> void: _rebuild())
	_rebuild()


## O texto de cada tecla desenhada agora (para os testes).
func get_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for cap in get_children():
		texts.append(cap.get_child(0).text)
	return texts


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for key_label in InputDevice.labels(hint_name):
		var cap := GameScreen.make_key_cap(key_label)
		var color := InputDevice.pad_color(key_label)
		if color.a > 0.0:
			HubTheme.tint(cap.get_child(0), color)  # os botões A, B, X e Y têm a cor do controle Xbox
		add_child(cap)
