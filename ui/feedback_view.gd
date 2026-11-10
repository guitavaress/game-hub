class_name FeedbackView
extends VBoxContainer
## Conteúdo para o menu de pausa. O hospedeiro cuida da pausa e do mouse.
## Crie com new(), adicione à árvore e chame open(); closed pede a volta.

signal closed

var _impression: LineEdit
var _difficulties: LineEdit
var _choices: Array[Button] = []
var _preview: Label
var _copy: Button
var _back: Button
var _return_answer: String = "Talvez"
var _technical_report: String = ""
var _focus_chain: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = HubTheme.get_theme()
	add_theme_constant_override("separation", 12)
	add_child(HubTheme.label("CONTAR O QUE ACHEI", &"HubTitle"))
	_impression = _field("O que você achou?")
	_difficulties = _field("O que travou ou confundiu?")
	add_child(HubTheme.label("Voltaria a abrir?"))
	var row := HBoxContainer.new()
	add_child(row)
	var group := ButtonGroup.new()
	for answer: String in ["Sim", "Talvez", "Não"]:
		var button := HubTheme.button(answer)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = answer == _return_answer
		button.pressed.connect(_choose.bind(answer))
		row.add_child(button)
		_choices.append(button)
		_focus_chain.append(button)
	add_child(HubTheme.line())
	add_child(HubTheme.label("RESUMO QUE SERÁ COPIADO", &"HubSection"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 180.0
	scroll.follow_focus = true
	add_child(scroll)
	_preview = HubTheme.label("", &"HubBodyLight")
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.focus_mode = Control.FOCUS_ALL
	_preview.gui_input.connect(_preview_input.bind(scroll))
	scroll.add_child(_preview)
	_focus_chain.append(_preview)
	add_child(HubTheme.label("Cole para quem te mandou o hub", &"HubCaption"))
	var footer := HBoxContainer.new()
	add_child(footer)
	_copy = HubTheme.button("Copiar", true)
	_copy.pressed.connect(_copy_report)
	footer.add_child(_copy)
	_back = HubTheme.button("Voltar")
	_back.pressed.connect(close)
	footer.add_child(_back)
	_focus_chain.append_array([_copy, _back])
	for i in _focus_chain.size():
		var control := _focus_chain[i]
		var previous := control.get_path_to(_focus_chain[posmod(i - 1, _focus_chain.size())])
		var next := control.get_path_to(_focus_chain[(i + 1) % _focus_chain.size()])
		control.focus_previous = previous
		control.focus_next = next
		control.focus_neighbor_top = previous
		control.focus_neighbor_bottom = next
	_refresh()
	visible = false


func _field(question: String) -> LineEdit:
	add_child(HubTheme.label(question))
	var field := LineEdit.new()
	field.max_length = 2000
	field.placeholder_text = "Escreva aqui (opcional)"
	field.text_changed.connect(func(_text: String) -> void: _refresh())
	add_child(field)
	_focus_chain.append(field)
	return field


func open() -> void:
	# Congela os dados técnicos ao abrir: o texto copiado é o que foi mostrado.
	_technical_report = FeedbackReport.build({})
	visible = true
	_refresh()
	_impression.grab_focus()


func close() -> void:
	if not visible:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and is_ancestor_of(owner):
		owner.release_focus()
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("release_mouse")):
		close()
		get_viewport().set_input_as_handled()


func _choose(answer: String) -> void:
	_return_answer = answer
	_refresh()


func _refresh() -> void:
	if _preview == null:
		return
	var report := FeedbackReport.build({"impressao": _impression.text,
		"dificuldades": _difficulties.text, "voltaria": _return_answer})
	# Mantém a amostra técnica inicial, atualizando apenas as respostas.
	if not _technical_report.is_empty():
		report = _technical_report.get_slice("\n\n", 0) + "\n\n" + report.substr(report.find("\n\n") + 2)
	_preview.text = report
	if _copy != null:
		_copy.text = "Copiar"


func _copy_report() -> void:
	DisplayServer.clipboard_set(_preview.text)
	_copy.text = "Copiado"


func _preview_input(event: InputEvent, scroll: ScrollContainer) -> void:
	# ←/→ rolam o resumo no controle; ↑/↓ continuam a ordem do formulário.
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		scroll.scroll_vertical += 60 if event.is_action_pressed("ui_right") else -60
		_preview.accept_event()
