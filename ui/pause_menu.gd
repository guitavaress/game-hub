class_name PauseMenu
extends CanvasLayer
## Menu de pausa (Esc): um painel de 460 px à esquerda, com a cidade atrás
## desfocada e escurecida. O título "PAUSA" e o rodapé são daqui; as abas (Som e
## vídeo, Controles, Amigos) são do SettingsView, que fica no meio.
##
## Com o menu aberto o mundo fica pausado. Ele não abre durante a espera na
## porta nem com um jogo abrindo ou rodando (aí o Esc é de outra coisa).
## Montado por código; medidas pensadas para 1280x720 (escala junto). Cores,
## fontes e caixas vêm do tema do hub (HubTheme).

signal opened
signal closed

const PANEL_WIDTH: float = 460.0
const BACKDROP_SHADER: Shader = preload("res://ui/pause_backdrop.gdshader")

var _settings: SettingsView


func _ready() -> void:
	layer = 50
	# Continua funcionando com o mundo pausado (que é justamente quando aparece).
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = BACKDROP_SHADER
	backdrop.material = backdrop_material
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.theme = HubTheme.get_theme()
	panel.theme_type_variation = &"HubSidePanel"  # encostado na borda, sem cantos
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = PANEL_WIDTH
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	column.add_child(HubTheme.label("PAUSA", &"HubTitle"))
	_settings = SettingsView.new()
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_settings)
	column.add_child(HubTheme.line())
	column.add_child(_build_bottom_row())

	GameLauncher.game_started.connect(_on_game_started)


func _input(event: InputEvent) -> void:
	# Aberto: Esc ou B (ui_cancel) fecham. Fechado: só o Esc abre.
	if visible and (event.is_action_pressed("release_mouse") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
	elif not visible and event.is_action_pressed("release_mouse") and can_open():
		open()
		get_viewport().set_input_as_handled()


## Dá para abrir agora? Não durante a espera na porta, nem com o hub dormindo
## ou um jogo abrindo/rodando, nem durante a abertura.
func can_open() -> bool:
	var player := get_parent() as Player
	return not GameLauncher.is_busy() and not HubWindow.is_sleeping \
			and not ScreenFade.door_charge.visible and ScreenFade.get_amount() < 0.5 \
			and not (player != null and (player.in_intro or player.is_traveling() or player.is_overlay_open()))


func open() -> void:
	_settings.refresh()
	visible = true
	_settings.grab_tab_focus()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()


func close() -> void:
	if not visible:
		return
	_settings.save_pending()
	_settings.drop_focus()
	visible = false
	# Se o hub foi dormir com o menu aberto (jogo aberto por fora), quem cuida
	# da pausa e do mouse é o HubWindow.
	if not HubWindow.is_sleeping:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return visible


func get_settings() -> SettingsView:
	return _settings


func _on_game_started(_app_id: int, _source: Node) -> void:
	close()


# --- Rodapé --------------------------------------------------------------------

func _build_bottom_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var resume := HubTheme.button("Continuar", true)
	resume.pressed.connect(close)
	row.add_child(resume)
	row.add_child(KeyHint.create("back"))
	row.add_child(HubTheme.expander())
	var quit := HubTheme.button("Sair do hub")
	quit.pressed.connect(HubWindow.quit_hub)
	row.add_child(quit)
	# O rodapé entra na ordem do foco, logo depois da última linha das abas.
	_settings.set_footer_controls([resume, quit] as Array[Control])
	return row

