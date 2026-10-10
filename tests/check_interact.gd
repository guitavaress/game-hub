extends SceneTree
## Teste de interagir com E (Fase 9.1): toque, segurar, travas e dica no cartão.

var failures := 0


## Alvo falso: uma "tela" olhável que responde ao E.
class FakeTarget extends Area3D:
	var hold_seconds: float = 0.0
	var interacts: int = 0
	var last_hold: float = -1.0

	func interact(_player: Node) -> void:
		interacts += 1

	func get_hold_seconds() -> float:
		return hold_seconds

	func set_hold(ratio: float) -> void:
		last_hold = ratio

	func get_look_info() -> Dictionary:
		return {"title": "Alvo falso", "action": "Segure E para testar"}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	var launcher = root.get_node("GameLauncher")
	launcher._poll_timer.paused = true
	var player = city.get_node("Player")

	# Alvo falso 3 m à frente do jogador (olhando para -Z, camada 3 = olhável).
	var target := FakeTarget.new()
	target.collision_layer = 4
	target.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, 0.5)
	shape.shape = box
	target.add_child(shape)
	city.add_child(target)
	player.global_position = Vector3(30.0, 0.1, 30.0)
	player.rotation = Vector3.ZERO
	target.global_position = player.global_position + Vector3(0.0, 1.6, -3.0)
	await _frames(3)

	print("== Toque ==")
	_check("o cartão mostra a dica do alvo", player.get_hud().get_look_action() == "Segure E para testar")
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)
	_check("um toque chama interact uma vez", target.interacts == 1)
	Input.action_press("interact")
	await _frames(20)
	Input.action_release("interact")
	await _frames(2)
	_check("segurar sem hold continua sendo um toque só", target.interacts == 2)

	print("== Segurar ==")
	target.hold_seconds = 0.5
	target.interacts = 0
	Input.action_press("interact")
	await create_timer(0.25).timeout
	_check("no meio da segurada o progresso sobe", target.last_hold > 0.1 and target.last_hold < 0.95)
	_check("e ainda não disparou", target.interacts == 0)
	await create_timer(0.6).timeout
	_check("ao encher dispara uma vez só", target.interacts == 1)
	await create_timer(0.4).timeout
	_check("continuar segurando não dispara de novo", target.interacts == 1)
	Input.action_release("interact")
	await _frames(3)
	target.interacts = 0
	Input.action_press("interact")
	await create_timer(0.2).timeout
	Input.action_release("interact")
	await _frames(3)
	_check("soltar antes de encher zera o progresso", target.last_hold == 0.0 and target.interacts == 0)
	Input.action_press("interact")
	await create_timer(0.2).timeout
	player.rotation.y = PI  # olha para outro lado
	await _frames(3)
	_check("desviar o olhar zera o progresso", target.last_hold == 0.0)
	Input.action_release("interact")
	player.rotation.y = 0.0
	await _frames(3)

	print("== Travas ==")
	target.hold_seconds = 0.0
	target.interacts = 0
	player.get_pause_menu().open()
	await process_frame
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	player.get_pause_menu().close()
	await _frames(3)
	_check("com painel aberto o E não faz nada", target.interacts == 0)
	player._traveling = true
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	player._traveling = false
	await _frames(3)
	_check("em viagem o E não faz nada", target.interacts == 0)
	launcher.state = launcher.State.LAUNCHING
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	launcher.state = launcher.State.IDLE
	await _frames(3)
	_check("com jogo abrindo o E não faz nada", target.interacts == 0)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
