extends CanvasLayer
## ScreenFade: uma "cortina" preta por cima de tudo (autoload).
##
## - set_amount(0.0 .. 1.0): 0 = tela normal, 1 = tela toda preta.
## - fade_in(segundos): clareia a tela aos poucos, do valor atual até 0.
##
## Fica num autoload para funcionar em qualquer mundo, e com layer 100 para
## cobrir também o HUD.

var _curtain: ColorRect
var _tween: Tween


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


func set_amount(amount: float) -> void:
	_stop_tween()
	_curtain.modulate.a = clampf(amount, 0.0, 1.0)


func get_amount() -> float:
	return _curtain.modulate.a


## Clareia a tela (preto -> transparente) em "duration" segundos.
func fade_in(duration: float = 1.0) -> void:
	_stop_tween()
	_tween = create_tween()
	_tween.tween_property(_curtain, "modulate:a", 0.0, duration)


func _stop_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
