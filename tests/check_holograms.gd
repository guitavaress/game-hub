extends SceneTree
## Teste dos hologramas com forma humana (P2.19).

const SUMMARIES_JSON := """{"response":{"players":[
 {"steamid":"76561190000000001","personaname":"Ana","personastate":1,"gameid":"2379780","avatarmedium":"https://avatars.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_medium.jpg"},
 {"steamid":"76561190000000009","personaname":"Caio","personastate":1,"avatarmedium":"https://avatars.steamstatic.com/0123456789abcdef0123456789abcdef01234567_medium.jpg"}
]}}"""

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	var fs = root.get_node("FriendsService")
	var typed: Array[SteamFriend] = []
	typed.assign(fs.parse_players(JSON.parse_string(SUMMARIES_JSON)))
	fs._set_friends(typed)
	for i in 10:
		await process_frame

	var npcs := root.find_children("*", "FriendNpc", true, false)
	print("   hologramas: ", npcs.size())
	_check("dois hologramas (porta do Balatro e praça)", npcs.size() == 2)
	for npc in npcs:
		var skeleton: Skeleton3D = npc._skeleton
		var top: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("HeadTop_End"))).origin
		var height: float = top.y - npc._figure.global_position.y
		var player: AnimationPlayer = npc.find_children("*", "AnimationPlayer", true, false)[0]
		print("   %s: altura %.2f m | animação '%s' | avatar visível %s" % [npc.friend.name, height,
			player.current_animation, npc._avatar.visible])
		_check("%s com ~1,7 m" % npc.friend.name, absf(height - 1.7) < 0.08)
		_check("%s respirando (Idle em loop)" % npc.friend.name, player.is_playing()
			and player.current_animation.ends_with("Idle")
			and player.get_animation(player.current_animation).loop_mode == Animation.LOOP_LINEAR)
		# Olhando para +Z do nó: o braço esquerdo fica à esquerda de quem olha de frente.
		var left: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("LeftArm"))).origin
		var right: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("RightArm"))).origin
		var forward: Vector3 = (left - right).cross(Vector3.UP).normalized()
		_check("%s de frente para o +Z do projetor" % npc.friend.name, forward.dot(npc.global_basis.z.normalized()) > 0.95)
		var labels := npc.find_children("*", "Label3D", true, false)
		_check("%s: nome sem contorno e some a 20 m" % npc.friend.name, labels.all(func(l) -> bool:
			return l.outline_size == 0 and is_equal_approx(l.visibility_range_end, 20.0)))
	var ana = npcs.filter(func(n) -> bool: return n.friend.name == "Ana")[0]
	_check("avatar padrão ('?') não aparece", not ana._avatar.visible and not ana.friend.has_custom_avatar())
	var caio = npcs.filter(func(n) -> bool: return n.friend.name == "Caio")[0]
	_check("avatar próprio é reconhecido", caio.friend.has_custom_avatar())

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
