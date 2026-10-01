extends SceneTree
## Regressão da Fase 2 dentro da cidade gerada (sem abrir jogo).

var _frames := 0
var _city: Node
var _player
var _portal
var _fade

func _initialize() -> void:
	physics_frame.connect(_on_physics_frame)

func _on_physics_frame() -> void:
	_frames += 1
	match _frames:
		1:
			_city = load("res://worlds/city/city.tscn").instantiate()
			root.add_child(_city)
		30:
			_player = _city.get_node("Player")
			_portal = _city.get_node("Building_2379780/GamePortal")  # Balatro
			_fade = root.get_node("ScreenFade")
			print("portal Balatro em ", _portal.global_position, " | nome: ", _portal.get_look_label())
			_portal.enter_time = 1000.0  # não deixa abrir o jogo de verdade
			# Entra na porta: 0,8 m "para dentro" (-Z local do portal).
			_player.global_position = _portal.global_transform * Vector3(0, 0.1, -0.8)
		60:
			print("na porta, charge = %.2f s (esperado ~0.5)" % _portal._charge)
			_portal._waiting_for_game = true
			_fade.set_amount(1.0)
			root.get_node("GameLauncher").session_ended.emit(2379780, _portal, true, "")
		70:
			var expected: Vector3 = _portal.get_return_transform().origin
			print("jogador voltou para ", _player.global_position, " | esperado ", expected,
				" | ok: ", _player.global_position.distance_to(expected) < 0.2)
			# O retorno fica fora da área de entrada?
			print("dentro da porta depois de voltar? ", _portal._player != null)
			quit()
