class_name AvatarPanel
extends CanvasLayer
## O PAINEL DO PROVADOR (Fase 13.11): aparece à direita da tela quando o jogador
## foca no espelho. Visuais prontos em cima e, embaixo, as cores prontas de cada
## parte do avatar. Cada clique grava no config.cfg ([avatar], pelo
## AppConfig.set_avatar) e o corpo do espelho muda na hora.
##
## Navegação pelo mouse, pelo teclado e pelo controle: ↑/↓ mudam de linha, ←/→
## andam na linha e Enter (ou A) escolhe. Esc volta (quem trata é o espelho).
## As opções vêm do AvatarCatalog (profiles/avatar_catalog.tres).

const CATALOG_PATH: String = "res://profiles/avatar_catalog.tres"
const SWATCH_SIZE: Vector2 = Vector2(36.0, 30.0)
const PANEL_WIDTH: float = 420.0

var _catalog: AvatarCatalog
var _panel: PanelContainer
var _preset_buttons: Array[Button] = []
## parte (AvatarSpec.ZONES) → botões de cor, na ordem da paleta.
var _swatches: Dictionary[String, Array] = {}
## true enquanto as marcações estão sendo refeitas (não é o usuário clicando).
var _refreshing: bool = false


func _ready() -> void:
	layer = 20
	visible = false
	_catalog = load(CATALOG_PATH) as AvatarCatalog
	_build()
	AppConfig.settings_changed.connect(_on_settings_changed)
	refresh()


## Mostra ou esconde o painel (o espelho chama ao focar e ao sair).
func show_panel(on: bool) -> void:
	visible = on
	if on:
		refresh()
		_link_focus()
		if not _preset_buttons.is_empty():
			_preset_buttons[0].grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		if focused != null and _panel.is_ancestor_of(focused):
			focused.release_focus()


func get_preset_buttons() -> Array[Button]:
	return _preset_buttons


func get_swatches(zone: String) -> Array:
	return _swatches.get(zone, [])


## Marca o que está valendo agora.
func refresh() -> void:
	_refreshing = true
	var spec := AvatarSpec.from_dict(AppConfig.get_avatar())
	for i in _preset_buttons.size():
		_preset_buttons[i].set_pressed_no_signal(_same(spec, _catalog.presets[i]))
	for zone in _swatches:
		var palette := _catalog.palette_of(zone)
		for i in _swatches[zone].size():
			(_swatches[zone][i] as Button).set_pressed_no_signal(palette[i].to_html(false) == spec.get_color(zone).to_html(false))
	_refreshing = false


func _on_settings_changed(section: String, _key: String) -> void:
	if section == "avatar":
		refresh()


func _same(a: AvatarSpec, b: AvatarSpec) -> bool:
	for zone in AvatarSpec.ZONES:
		if a.get_color(zone).to_html(false) != b.get_color(zone).to_html(false):
			return false
	return true


func _choose_preset(index: int) -> void:
	if not _refreshing:
		AppConfig.set_avatar(_catalog.presets[index].to_dict())


func _choose_color(zone: String, color: Color) -> void:
	if _refreshing:
		return
	var spec := AvatarSpec.from_dict(AppConfig.get_avatar())
	spec.set_color(zone, color)
	AppConfig.set_avatar(spec.to_dict())


# --- Montagem -------------------------------------------------------------------

func _build() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE  # o resto da tela é do espelho
	add_child(holder)
	_panel = PanelContainer.new()
	_panel.theme = HubTheme.get_theme()
	_panel.theme_type_variation = &"HubPanelStrong"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -PANEL_WIDTH - 32.0
	_panel.offset_right = -32.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	holder.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	box.add_child(HubTheme.label("PROVADOR", &"HubTitle"))
	box.add_child(HubTheme.label("VISUAIS", &"HubSection"))
	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 4)
	presets.add_theme_constant_override("v_separation", 4)
	var group := ButtonGroup.new()
	for i in _catalog.presets.size():
		var button := Button.new()
		button.text = _catalog.preset_names[i]
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"HubSegment"
		button.pressed.connect(_choose_preset.bind(i))
		presets.add_child(button)
		_preset_buttons.append(button)
	box.add_child(presets)
	for zone in AvatarSpec.ZONES:
		box.add_child(HubTheme.label(AvatarSpec.ZONE_NAMES[zone].to_upper(), &"HubSection"))
		box.add_child(_swatch_row(zone))
	box.add_child(HubTheme.line())
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 10)
	hint.add_child(KeyHint.create("back"))
	hint.add_child(HubTheme.label("voltar para a sala", &"HubBodyLight"))
	box.add_child(hint)


func _swatch_row(zone: String) -> Control:
	var row := HFlowContainer.new()
	row.name = "Row_" + zone
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var group := ButtonGroup.new()
	var buttons: Array = []
	for color in _catalog.palette_of(zone):
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.button_group = group
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.tooltip_text = "#" + color.to_html(false)
		swatch.set_meta("hub_data_color", true)  # a cor vem da paleta (dado), não é estilo solto
		swatch.add_theme_stylebox_override("normal", HubTheme.box(color, 6, Color(0, 0, 0, 0.35), 2, Vector4(0, 0, 0, 0)))
		swatch.add_theme_stylebox_override("hover", HubTheme.box(color.lightened(0.15), 6, Color(1, 1, 1, 0.6), 2, Vector4(0, 0, 0, 0)))
		swatch.add_theme_stylebox_override("pressed", HubTheme.box(color, 6, Color.WHITE, 4, Vector4(0, 0, 0, 0)))
		swatch.add_theme_stylebox_override("focus", HubTheme.box(color, 6, Color(1.0, 0.8, 0.3), 4, Vector4(0, 0, 0, 0)))
		swatch.pressed.connect(_choose_color.bind(zone, color))
		row.add_child(swatch)
		buttons.append(swatch)
	_swatches[zone] = buttons
	return row


## A ordem do foco, montada à mão (como no SettingsView): ↑/↓ andam de linha em
## linha (para a primeira peça), ←/→ andam dentro da linha e param nas pontas.
func _link_focus() -> void:
	var rows: Array[Array] = [_preset_buttons]
	for zone in AvatarSpec.ZONES:
		rows.append(_swatches[zone])
	for i in rows.size():
		var above: Control = rows[(i - 1 + rows.size()) % rows.size()][0]
		var below: Control = rows[(i + 1) % rows.size()][0]
		var line: Array = rows[i]
		for j in line.size():
			var control: Control = line[j]
			control.focus_neighbor_top = control.get_path_to(above)
			control.focus_neighbor_bottom = control.get_path_to(below)
			control.focus_neighbor_left = control.get_path_to(line[maxi(j - 1, 0)])
			control.focus_neighbor_right = control.get_path_to(line[mini(j + 1, line.size() - 1)])
