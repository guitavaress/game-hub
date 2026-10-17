class_name DeskMonitorSource
extends RefCounted
## FONTE DE MONITOR (Fase 14.28): o que um monitor da mesa (DeskMonitor3D)
## precisa de uma SAÍDA do compositor. O monitor só conhece esta interface;
## quem traduz para o compositor é o AppSessions. Nos testes, uma fonte falsa
## herda desta classe.
##
## Esta classe é o "contrato": cada função aqui não faz nada. Quem herda
## sobrescreve o que precisa. Todos os pixels são da saída (o mesmo tamanho
## da resolução do monitor): (0, 0) é o canto de cima à esquerda.


## A imagem atual da saída (as janelas e a barra, já juntas). Pode ser null.
func get_texture() -> Texture2D:
	return null


## Uma tecla da Godot, para quem está com o teclado lá dentro (o menu, a barra
## ou a janela em foco).
func send_key(_event: InputEventKey) -> void:
	pass


## O ponteiro, em pixels da saída.
func send_pointer(_pixel: Vector2) -> void:
	pass


## Botão do mouse apertado ou solto (vale onde o ponteiro está).
func send_button(_button: MouseButton, _pressed: bool) -> void:
	pass


## Rolagem: x para os lados, y para cima (positivo) ou para baixo (negativo).
func send_scroll(_delta: Vector2) -> void:
	pass


## O título da janela em foco ("" se não houver).
func get_title() -> String:
	return ""


## O jogador sentou à mesa (true) ou levantou (false): o teclado lá dentro
## segue isso.
func set_focused(_on: bool) -> void:
	pass


## A mira saiu deste monitor: os apps não devem mais achar que o mouse está aqui.
func pointer_leave() -> void:
	pass
