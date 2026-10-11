extends SceneTree
## Teste do tema do hub (Fase 12.1):
##   - o tema tem as variações e só os 5 tamanhos de letra;
##   - o SettingsView sozinho, o menu de pausa e a tela do computador não têm
##     estilo solto (nenhuma cor, fonte, tamanho ou caixa escrita no nó);
##   - dentro do SubViewport do computador, o texto usa o mesmo tema.
## Os espaçamentos ("separation") podem ficar no nó: são arrumação, não estilo.

const SIZES: Array[int] = [14, 16, 20, 28, 46]
const VARIATIONS: Dictionary = {
	&"HubCaption": &"Label", &"HubBody": &"Label", &"HubBodyLight": &"Label", &"HubValue": &"Label",
	&"HubLead": &"Label", &"HubTitle": &"Label", &"HubSection": &"Label", &"HubBrand": &"Label",
	&"HubKeyLabel": &"Label", &"HubStatusOk": &"Label", &"HubStatusError": &"Label",
	&"HubButtonPrimary": &"Button", &"HubTab": &"Button", &"HubSegment": &"Button",
	&"HubPanel": &"PanelContainer", &"HubPanelStrong": &"PanelContainer",
	&"HubSidePanel": &"PanelContainer", &"HubScreen": &"PanelContainer", &"HubKeyCap": &"PanelContainer",
}

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var theme_script: GDScript = load("res://ui/hub_theme.gd")
	var theme: Theme = theme_script.get_theme()

	print("== O tema ==")
	_check("é sempre o mesmo objeto", theme == theme_script.get_theme())
	var missing: Array[String] = []
	for variation in VARIATIONS:
		if theme.get_type_variation_base(variation) != VARIATIONS[variation]:
			missing.append(String(variation))
	_check("as %d variações existem, cada uma com a base certa (faltando: %s)" % [VARIATIONS.size(), missing],
			missing.is_empty())
	var sizes := {}
	sizes[theme.default_font_size] = true
	for type in theme.get_font_size_type_list():
		for item in theme.get_font_size_list(type):
			sizes[theme.get_font_size(item, type)] = true
	var extra := sizes.keys().filter(func(size: int) -> bool: return not SIZES.has(size))
	print("   tamanhos usados: ", sizes.keys())
	_check("só os 5 tamanhos de letra (fora da lista: %s)" % str(extra), extra.is_empty())
	_check("um raio só nos botões e painéis", _radii(theme).size() <= 2)  # o raio e o 0 (sem canto)
	_check("o foco tem uma borda visível", theme.get_stylebox("focus", "Button") is StyleBoxFlat
			and (theme.get_stylebox("focus", "Button") as StyleBoxFlat).border_width_left >= 2)

	print("== SettingsView sozinho ==")
	var view = load("res://ui/settings_view.gd").new()  # sem tipo: usa autoloads
	root.add_child(view)
	await process_frame
	view.refresh()
	_check("usa o tema do hub", view.theme == theme)
	_check_clean("o SettingsView", view)
	_check("a aba escolhida usa a variação de aba", view._tab_buttons[0].theme_type_variation == &"HubTab")
	_check("o texto do deslizador resolve para 16 px", view._volume_values["Master"].get_theme_font_size("font_size") == 16)
	view.queue_free()

	print("== Menu de pausa ==")
	var menu = load("res://ui/pause_menu.gd").new()
	root.add_child(menu)
	await process_frame
	_check_clean("o menu de pausa", menu)
	var title := _find_label(menu, "PAUSA")
	_check("o título PAUSA usa o tamanho de título (28)", title != null
			and title.get_theme_font_size("font_size") == theme_script.SIZE_TITLE)
	menu.queue_free()

	print("== Tela do computador ==")
	var desk = load("res://worlds/home/computer_desk.gd").new()
	root.add_child(desk)
	await process_frame
	var content: Control = desk.get_screen()._content
	_check("o conteúdo da tela 3D usa o tema", content.theme == theme)
	_check_clean("a tela do computador", content)
	var heading := _find_label(content, "CONFIGURAÇÕES")
	_check("dentro do SubViewport, o título resolve para 28 px", heading != null
			and heading.get_theme_font_size("font_size") == theme_script.SIZE_TITLE)
	_check("as configurações da tela usam o mesmo tema", desk.get_settings().theme == theme)
	desk.queue_free()

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Nenhum Control debaixo de "node" tem cor, fonte, tamanho ou caixa própria.
func _check_clean(what: String, node: Node) -> void:
	var dirty: Array[String] = []
	_collect_overrides(node, dirty)
	if not dirty.is_empty():
		print("   estilo solto: ", dirty.slice(0, 12))
	_check("%s não tem estilo solto (%d)" % [what, dirty.size()], dirty.is_empty())


func _collect_overrides(node: Node, dirty: Array[String]) -> void:
	var control := node as Control
	if control != null:
		var defaults := ThemeDB.get_default_theme()
		var type := control.get_class()
		while type != "":
			for item in defaults.get_color_list(type):
				if control.has_theme_color_override(item):
					dirty.append("%s.color.%s" % [control.name, item])
			for item in defaults.get_font_list(type):
				if control.has_theme_font_override(item):
					dirty.append("%s.font.%s" % [control.name, item])
			for item in defaults.get_font_size_list(type):
				if control.has_theme_font_size_override(item):
					dirty.append("%s.font_size.%s" % [control.name, item])
			for item in defaults.get_stylebox_list(type):
				if control.has_theme_stylebox_override(item):
					dirty.append("%s.stylebox.%s" % [control.name, item])
			type = ClassDB.get_parent_class(type)
	for child in node.get_children():
		_collect_overrides(child, dirty)


func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


## Os raios de canto das caixas do tema.
func _radii(theme: Theme) -> Dictionary:
	var radii := {}
	for type in ["Button", "HubButtonPrimary", "HubSegment", "LineEdit", "HubPanel", "HubPanelStrong", "HubKeyCap"]:
		for item in theme.get_stylebox_list(type):
			var style := theme.get_stylebox(item, type) as StyleBoxFlat
			if style != null and style.draw_center:
				radii[style.corner_radius_top_left] = true
	return radii


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
