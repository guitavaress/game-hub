extends "res://tests/check_mountain_trail.gd"
## O mesmo teste da montanha, com as horas falsas (revisão de risco da 19.9).
## Com elas, o RPG fica no nível 3 e ganha território na cidade, mas a fatia
## dele na borda é a mesma: a montanha, a trilha e o mirante (a plataforma, a
## ponta sobre a encosta e o ponto da vista) têm que sair iguais aos de sem horas.


func _initialize() -> void:
	fake_hours = true
	super()
