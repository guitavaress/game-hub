extends CanvasLayer
## ScreenFade: uma "cortina" preta por cima de tudo (autoload).
##
## - set_amount(0.0 .. 1.0): 0 = tela normal, 1 = tela toda preta.
## - fade_in(segundos): clareia a tela aos poucos, do valor atual até 0.
## - set_message(texto): texto no meio da cortina (ex.: "Carregando...").
##
## Por cima da cortina fica a TELA DO JOGO (GameScreen): "Abrindo X…" quando um
## jogo é pedido e "Jogando X…" quando ele aparece. Ela é "filha" da cortina,
## então some junto quando a cortina clareia, e escuta o GameLauncher sozinha.
##
## Fica num autoload para funcionar em qualquer mundo, e com layer 100 para
## cobrir também o HUD.

var _curtain: ColorRect
var _message: Label
var _tween: Tween
var game_screen: GameScreen


func _ready() -> void:
	layer = 100
	# Continua funcionando mesmo com o jogo pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.modulate.a = 0.0
	add_child(_curtain)

	# O texto é "filho" da cortina, então aparece e some junto com ela.
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 28)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.add_child(_message)

	game_screen = GameScreen.new()
	_curtain.add_child(game_screen)
	GameLauncher.launch_started.connect(func(app_id: int, _source: Node) -> void:
		game_screen.show_opening(app_id))
	GameLauncher.game_started.connect(func(app_id: int, _source: Node) -> void:
		game_screen.show_playing(app_id))


## Mostra um texto no meio da cortina ("" apaga).
func set_message(text: String) -> void:
	_message.text = text


func set_amount(amount: float) -> void:
	_stop_tween()
	_curtain.modulate.a = clampf(amount, 0.0, 1.0)
	# Escurecendo na porta (hub acordado): a tela do jogo anterior não aparece.
	if not HubWindow.is_sleeping:
		game_screen.visible = false


func get_amount() -> float:
	return _curtain.modulate.a


## Clareia a tela (preto -> transparente) em "duration" segundos. No fim, a tela
## do jogo (se estava aparecendo) é escondida.
func fade_in(duration: float = 1.0) -> void:
	_stop_tween()
	_tween = create_tween()
	_tween.tween_property(_curtain, "modulate:a", 0.0, duration)
	_tween.finished.connect(func() -> void: game_screen.visible = false)


func _stop_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
