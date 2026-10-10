extends SceneTree
## Teste do mural dos amigos (Fase 9.5), com amigos FALSOS:
##   - um cartão por amigo online, com quem joga primeiro;
##   - o cartão vazio sem amigos;
##   - E leva à porta do jogo (virado para ela) ou à praça, se o jogo não é da biblioteca.

const BALATRO := 2379780
const SUMMARIES_JSON := """{"response":{"players":[
 {"steamid":"76561190000000001","personaname":"Duda","personastate":1},
 {"steamid":"76561190000000002","personaname":"Ana","personastate":1,"gameid":"2379780","gameextrainfo":"Balatro"},
 {"steamid":"76561190000000003","personaname":"Carla","personastate":1,"gameid":"999999","gameextrainfo":"Jogo de fora"},
 {"steamid":"76561190000000004","personaname":"Beto","personastate":0}
]}}"""

var failures := 0


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
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var home = city.get_home()
	var wall = home.get_node("FriendsWall")
	var fs = root.get_node("FriendsService")
	var portal = city.get_node("Building_%d/GamePortal" % BALATRO)

	print("== Sem amigos ==")
	var none: Array[SteamFriend] = []
	fs._set_friends(none)
	_check("mostra o cartão vazio", wall.has_empty_card() and wall.get_friend_names().is_empty())

	print("== Com amigos ==")
	var friends: Array[SteamFriend] = []
	friends.assign(fs.parse_players(JSON.parse_string(SUMMARIES_JSON)))
	fs._set_friends(friends)
	_check("o cartão vazio sumiu", not wall.has_empty_card())
	var names: Array = wall.get_friend_names()
	print("   ordem: ", names)
	_check("um cartão por amigo online (o offline fica de fora)", names.size() == 3 and not names.has("Beto"))
	_check("quem joga vem primeiro, depois por nome", names == ["Ana", "Carla", "Duda"])

	print("== E num amigo que joga da biblioteca ==")
	player.teleport_to(Transform3D(Basis.IDENTITY, home.to_global(Vector3(0.0, 0.1, 0.0))))
	player.set_indoors(home.get_environment())
	_aim_at(player, wall, wall.get_card("Ana"))
	await _frames(4)
	_check("o cartão mostra o amigo", hud.get_look_text().begins_with("Ana"))
	_check("com a dica de ir até a porta", hud.get_look_action() == "E para ir até a porta")
	await _press_e()
	await create_timer(1.5).timeout
	var arrival: Transform3D = portal.get_arrival_transform()
	_check("chegou na frente da porta do jogo", player.global_position.distance_to(arrival.origin) < 0.5)
	var forward: Vector3 = -player.global_basis.z
	_check("virado para a porta", forward.dot(-portal.global_basis.z) > 0.95)
	_check("saiu de casa", not player.is_indoors())

	print("== E num amigo que joga fora da biblioteca ==")
	player.teleport_to(Transform3D(Basis.IDENTITY, home.to_global(Vector3(0.0, 0.1, 0.0))))
	player.set_indoors(home.get_environment())
	_aim_at(player, wall, wall.get_card("Carla"))
	await _frames(4)
	_check("a dica fala da praça", hud.get_look_action() == "E para ir até a praça")
	await _press_e()
	await create_timer(1.5).timeout
	_check("foi para a praça (onde a porta da rua leva)", player.global_position.distance_to(home.get_front_door().destination.origin) < 0.5)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Põe o jogador a 1,5 m do cartão, olhando para ele.
func _aim_at(player: Node3D, wall: Node3D, card: Node3D) -> void:
	var front: Vector3 = wall.global_basis.z
	player.global_position = Vector3(card.global_position.x, 0.1, card.global_position.z) + front * 1.5
	player.rotation = Vector3(0.0, atan2(front.x, front.z), 0.0)
	var head: Node3D = player.get_node("Head")
	head.rotation.x = atan2(card.global_position.y - head.global_position.y, 1.5)


func _press_e() -> void:
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
