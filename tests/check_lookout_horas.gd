extends "res://tests/check_lookout.gd"
## O mesmo teste do mirante (17.8), com as horas falsas (revisão de risco da
## 19.9): com o RPG no nível 3, o mirante continua com a plataforma, o deque,
## a luneta virada para a praça e a tapeçaria do RPG mais jogado.


func _initialize() -> void:
	fake_hours = true
	super()
