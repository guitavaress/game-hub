class_name DistrictTitle
extends Control
## Título ao entrar num BAIRRO (Fase 11.11): o nome grande, na cor néon, e
## "12 jogos" embaixo, no alto da tela (abaixo dos avisos). Entra com fade e
## desliza, fica ~2,5 s e sai (curvas cúbicas, como o resto da UI).
##
## Quem decide quando mostrar é ele mesmo: a cada POLL_SECONDS ele pergunta ao
## mapa do mundo (grupo "world_map", CityMap.area_id_at) em que bairro o
## jogador está. Mudou para um bairro -> mostra. Na praça, na rua de fora e em
## casa, nada. O mesmo bairro não repete antes de REPEAT_SECONDS (na divisa a
## pessoa pode ir e voltar sem o título piscar).
##
## LUGAR PRÓPRIO (Fase 16.2): o HUD põe o título numa faixa abaixo do espaço
## de 2 avisos (set_band), para os dois nunca se cruzarem. O título
## CEDE A VEZ (não aparece, ou some rápido se já estiver na tela) quando:
## - a carga de uma porta está na tela (ScreenFade.door_charge), que fica no
##   meio da tela e é mais importante;
## - os avisos passaram da conta e invadiram a faixa (quem diz é o HUD).

const POLL_SECONDS: float = 0.25
const REPEAT_SECONDS: float = 20.0
const HOLD_SECONDS: float = 2.5
const FADE_IN_SECONDS: float = 0.4
const FADE_OUT_SECONDS: float = 0.5
const SLIDE_PIXELS: float = 14.0
## Quanto dura o sumiço rápido quando o título cede a vez (s).
const YIELD_SECONDS: float = 0.15
## Distância do alto da tela até o título quando ninguém dá uma faixa (sem HUD).
const TOP_MARGIN: float = 76.0
const SOUND: AudioStream = preload("res://assets/kenney/interface-sounds/glass_001.ogg")

var _title: Label
var _subtitle: Label
var _column: VBoxContainer
var _sound: AudioStreamPlayer
var _tween: Tween
var _elapsed: float = 0.0
## O bairro em que o jogador estava na última olhada ("" = nenhum).
var _current_area: String = ""
## Quando (ms) cada bairro mostrou o título pela última vez.
var _last_shown_ms: Dictionary[String, int] = {}
var _showing: bool = false
## Alto da faixa do título (px, do alto da tela); veja set_band.
var _top: float = TOP_MARGIN
## Pergunta se a faixa está ocupada por outra coisa (vazia = nunca está).
var _band_taken: Callable = Callable()


func _ready() -> void:
	theme = HubTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 0)
	_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_column.offset_top = _top
	_column.modulate.a = 0.0
	_column.visible = false
	add_child(_column)

	_title = _make_label(&"HubDisplay")
	_column.add_child(_title)
	_subtitle = _make_label(&"HubDisplaySub")
	_column.add_child(_subtitle)

	_sound = AudioStreamPlayer.new()
	_sound.stream = SOUND
	_sound.bus = &"Efeitos"
	_sound.volume_db = -18.0
	add_child(_sound)


func _process(delta: float) -> void:
	if _showing and must_yield():
		_yield_now()
	_elapsed += delta
	if _elapsed >= POLL_SECONDS:
		_elapsed = 0.0
		poll()


## Confere em que bairro o jogador está e mostra o título se entrou em um.
func poll() -> void:
	var map := get_tree().get_first_node_in_group("world_map")
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var area := ""
	if map != null and player != null and not (player.has_method("is_indoors") and player.is_indoors()):
		area = map.area_id_at(player.global_position)
	if area == _current_area:
		return
	_current_area = area
	if area.is_empty():
		return
	var now := Time.get_ticks_msec()
	if _last_shown_ms.has(area) and now - _last_shown_ms[area] < int(REPEAT_SECONDS * 1000.0):
		return
	_last_shown_ms[area] = now
	var data: Dictionary = map.get_map_data()
	for entry: Dictionary in data["areas"]:
		if entry["id"] == area:
			show_title(entry["name"], int(entry["games"]), entry["neon"])
			return


## A faixa do título: o alto dela (px) e quem diz se ela está ocupada.
func set_band(top: float, band_taken: Callable = Callable()) -> void:
	_top = top
	_band_taken = band_taken
	if not _showing:
		_column.offset_top = _top


func get_band_top() -> float:
	return _top


## O título tem que ceder a vez agora? (carga da porta ou faixa ocupada)
func must_yield() -> bool:
	if ScreenFade.door_charge.visible:
		return true
	return _band_taken.is_valid() and bool(_band_taken.call())


## Mostra o título: nome do bairro, contagem de jogos e a cor néon. Se ele
## tiver que ceder a vez (veja must_yield), não aparece.
func show_title(district_name: String, games: int, color: Color) -> void:
	if must_yield():
		return
	_title.text = district_name.to_upper()
	HubTheme.tint(_title, color)  # o neon do bairro é dado
	_subtitle.text = "%d %s" % [games, "jogo" if games == 1 else "jogos"]
	_showing = true
	_sound.play()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_column.visible = true
	_column.modulate.a = 0.0
	_column.offset_top = _top - SLIDE_PIXELS
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(_column, "modulate:a", 1.0, FADE_IN_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_column, "offset_top", _top, FADE_IN_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(_column, "modulate:a", 0.0, FADE_OUT_SECONDS) \
			.set_delay(HOLD_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_hide)


## Some rápido, sem esperar o tempo na tela.
func _yield_now() -> void:
	_showing = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_column, "modulate:a", 0.0, YIELD_SECONDS) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_hide)


func _hide() -> void:
	_showing = false
	_column.visible = false


func is_showing() -> bool:
	return _showing


func get_title() -> String:
	return _title.text


func get_subtitle() -> String:
	return _subtitle.text


func _make_label(variation: StringName) -> Label:
	var label := HubTheme.label("", variation)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
