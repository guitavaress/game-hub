class_name AppScreens
extends Node3D
## OS TELÕES DA CASA (Fase 14.20): três telões fixos (AppWindow3D) no alto das
## paredes, onde as janelas dos apps vão aparecer. Ficam no grupo "app_screen".
##
## Aqui só há os telões e a ideia de "livre / ocupado". Quem decide qual app
## vai para qual telão é o AppSessions (14.21), que usa:
##   offer(source)   : põe a janela no primeiro telão livre (ou null se cheio);
##   release(screen) : o app fechou, o telão volta a ficar livre.
##
## Livre, o telão mostra "Livre" e olhar para ele só explica como usar; não dá
## para focar. Ocupado, o cartão mostra o título da janela e "Segure Esc para
## sair" (o Esc longo é do AppWindow3D).
##
## Lugares (coordenadas da casa): o alto da parede norte, sobre a estante de
## apps, e o fundo das paredes oeste e leste. O alto de cada um fica acima dos
## móveis de qualquer disposição (o teste confere).

## Tamanho de cada telão (m); a proporção é a da resolução 1280×720.
const SCREEN_SIZE: Vector2 = Vector2(1.28, 0.72)
## Altura do centro, e quanto o telão fica afastado da parede.
const CENTER_Y: float = 2.8
const WALL_GAP: float = 0.03
## [posição (x, z) da parede, giro em Y]; a frente (+Z) aponta para dentro.
const SPOTS: Array[Array] = [
	[Vector2(-4.5, -4.5), 0.0],
	[Vector2(-6.0, 3.0), PI / 2.0],
	[Vector2(6.0, 3.0), -PI / 2.0],
]

## Sinal para quem acompanha (o AppSessions): um telão ficou livre ou ocupado.
signal screen_changed(screen: AppWindow3D)

var _screens: Array[AppWindow3D] = []


## O telão de verdade: livre, não aceita foco.
class AppScreen extends AppWindow3D:
	func get_look_info() -> Dictionary:
		if get_source() != null:
			return super.get_look_info()
		return {"title": "Telão livre", "detail": "Abra um app pela estante de apps", "action": ""}

	func interact(player: Node) -> void:
		if get_source() != null:
			super.interact(player)


func _ready() -> void:
	for i in SPOTS.size():
		var screen := AppScreen.new()
		screen.name = "AppScreen%d" % (i + 1)
		screen.screen_size = SCREEN_SIZE
		screen.add_to_group("app_screen")
		var spot: Vector2 = SPOTS[i][0]
		var turn: float = SPOTS[i][1]
		var wall_normal := Basis(Vector3.UP, turn) * Vector3.BACK
		screen.transform = Transform3D(Basis(Vector3.UP, turn),
				Vector3(spot.x, CENTER_Y, spot.y) + wall_normal * WALL_GAP)
		add_child(screen)
		_screens.append(screen)


func get_screens() -> Array[AppWindow3D]:
	return _screens


## Quantos telões estão livres.
func free_count() -> int:
	var count := 0
	for screen in _screens:
		if screen.get_source() == null:
			count += 1
	return count


## Põe a janela no primeiro telão livre. Devolve o telão, ou null se todos
## estiverem ocupados.
func offer(source: AppWindowSource) -> AppWindow3D:
	for screen in _screens:
		if screen.get_source() == null:
			screen.set_source(source)
			screen_changed.emit(screen)
			return screen
	return null


## O app fechou: o telão fica livre (e solta o jogador, se ele estava nele).
func release(screen: AppWindow3D) -> void:
	if screen == null or screen.get_source() == null:
		return
	if screen.is_focused():
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("leave_focus"):
			player.leave_focus()
	screen.set_source(null)
	screen_changed.emit(screen)


## O telão que mostra esta janela, ou null.
func screen_of(source: AppWindowSource) -> AppWindow3D:
	for screen in _screens:
		if screen.get_source() == source:
			return screen
	return null
