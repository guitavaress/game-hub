class_name ControlsHint
extends PanelContainer
## Cartão de controles da PRIMEIRA VEZ (Fase 10.7): uma faixa no pé da tela
## com as teclas principais (WASD andar · Shift correr · E usar · Tab buscar ·
## M mapa · Esc menu). Some sozinho depois de SHOW_SECONDS ou no primeiro E.
## Ao sumir, grava "já visto" no config.cfg (AppConfig) e avisa (closed).
##
## Quem decide mostrar é o jogador, no fim da abertura (Player.finish_intro),
## pelo HUD (Hud.show_controls_hint).

## O cartão sumiu (já gravou "visto").
signal closed

const SHOW_SECONDS: float = 15.0
const FADE_SECONDS: float = 0.4
## Acima do cartão do que se olha (que fica a 48 px do pé da tela).
const BOTTOM_MARGIN: float = 150.0
## As teclas, na ordem em que aparecem: [teclas, o que fazem].
const KEYS: Array[Array] = [
	[["W", "A", "S", "D"], "andar"],
	[["Shift"], "correr"],
	[["E"], "usar"],
	[["Tab"], "buscar"],
	[["M"], "mapa"],
	[["Esc"], "menu"],
]

var _time_left: float = SHOW_SECONDS
var _closing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = HubTheme.get_theme()
	theme_type_variation = &"HubPanel"
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -BOTTOM_MARGIN

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := _make_label("COMO JOGAR", &"HubSection")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	for entry in KEYS:
		var item := HBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", 4)
		for key_name: String in entry[0]:
			item.add_child(GameScreen.make_key_cap(key_name))
		var text := _make_label(entry[1], &"HubBody")
		item.add_child(text)
		row.add_child(item)


## Some sozinho com o tempo, ou no primeiro E (o E continua valendo para o
## jogo: não é "engolido").
func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0 or Input.is_action_just_pressed("interact"):
		close()


## Some (com um fade curto), grava "visto" e avisa.
func close() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	AppConfig.set_seen_controls_hint(true)
	closed.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func is_closing() -> bool:
	return _closing


func _make_label(text: String, variation: StringName) -> Label:
	var label := HubTheme.label(text, variation)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
