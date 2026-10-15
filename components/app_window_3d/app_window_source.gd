class_name AppWindowSource
extends RefCounted
## FONTE DE JANELA (Fase 14.19): o que o telão (AppWindow3D) precisa de uma
## janela de app. O telão só conhece esta interface; quem traduz para o
## compositor é a fonte de verdade (o AppSessions, na 14.21). Nos testes, uma
## fonte falsa herda desta classe.
##
## Esta classe é o "contrato": cada função aqui não faz nada. Quem herda
## sobrescreve o que precisa.


## A imagem atual da janela. Pode ser null (ainda sem quadro).
func get_texture() -> Texture2D:
	return null


## O telão avisa o tamanho dele em pixels (ex.: 1280×720); a janela do app
## deve ficar desse tamanho.
func resize(_size: Vector2i) -> void:
	pass


## Uma tecla da Godot, para entregar ao app.
func send_key(_event: InputEventKey) -> void:
	pass


## O ponteiro, em pixels da janela: (0, 0) é o canto de cima à esquerda.
func send_pointer(_pixel: Vector2) -> void:
	pass


## Botão do mouse apertado ou solto.
func send_button(_button: MouseButton, _pressed: bool) -> void:
	pass


## Rolagem: x para os lados, y para cima (positivo) ou para baixo (negativo).
func send_scroll(_delta: Vector2) -> void:
	pass


## O título da janela ("" se não houver).
func get_title() -> String:
	return ""
