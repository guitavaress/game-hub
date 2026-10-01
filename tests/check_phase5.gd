extends SceneTree
## Teste da Fase 5 com amigos FALSOS (não usa a chave de ninguém).

const FAKE_KEY := "CHAVE_FALSA_TESTE_123"
const DEFAULT_AVATAR := "https://avatars.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_medium.jpg"

const FRIEND_LIST_JSON := """{"friendslist":{"friends":[
 {"steamid":"76561190000000001","relationship":"friend","friend_since":1},
 {"steamid":"76561190000000002","relationship":"friend","friend_since":1},
 {"steamid":"76561190000000003","relationship":"friend","friend_since":1}]}}"""

const SUMMARIES_JSON := """{"response":{"players":[
 {"steamid":"76561190000000001","personaname":"Ana","personastate":1,"gameid":"2379780","gameextrainfo":"Balatro","avatarmedium":"%s"},
 {"steamid":"76561190000000002","personaname":"Bruno","personastate":1,"gameid":"2379780","gameextrainfo":"Balatro"},
 {"steamid":"76561190000000003","personaname":"Carla","personastate":1,"gameid":"2379780","gameextrainfo":"Balatro"},
 {"steamid":"76561190000000004","personaname":"Duda","personastate":1},
 {"steamid":"76561190000000005","personaname":"Edu","personastate":3},
 {"steamid":"76561190000000006","personaname":"Fer","personastate":1,"gameid":"730","gameextrainfo":"Counter-Strike 2"},
 {"steamid":"76561190000000007","personaname":"Gabi","personastate":1,"gameid":"12884902733007126528","gameextrainfo":"Minecraft (fora da Steam)"},
 {"steamid":"76561190000000008","personaname":"Hugo","personastate":0},
 {"steamid":"76561190000000009","personaname":"Iris","personastate":6,"gameid":"489830","gameextrainfo":"The Elder Scrolls V: Skyrim Special Edition"}
]}}"""

var FS
var city: Node
var player
var failures := 0
var problems: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	city = load("res://worlds/city/city.tscn").instantiate()
	root.add_child(city)
	for i in 30:
		await process_frame
	FS = root.get_node("FriendsService")
	player = city.get_node("Player")
	FS.problem.connect(func(m): problems.append(m))

	print("== SteamID detectado: ", root.get_node("SteamLibrary").get_current_steam_id())
	print("== config: amigos ligados? ", root.get_node("AppConfig").are_friends_enabled(),
		" | chave configurada? ", not root.get_node("AppConfig").get_web_api_key().is_empty())

	print("\n== leitura das respostas da API ==")
	var ids: PackedStringArray = FS.parse_friend_ids(JSON.parse_string(FRIEND_LIST_JSON))
	_check("3 amigos na lista", ids.size() == 3)
	var friends: Array = FS.parse_players(JSON.parse_string(SUMMARIES_JSON % DEFAULT_AVATAR))
	_check("9 fichas", friends.size() == 9)
	for f in friends:
		print("   %-5s status=%d game_id=%-8d | %s" % [f.name, f.status, f.game_id, f.status_text()])
	_check("gameid gigante (fora da Steam) vira 0, mas o nome fica", friends[6].game_id == 0 and friends[6].is_playing())

	print("\n== amigos na cidade ==")
	var typed: Array[SteamFriend] = []
	typed.assign(friends)
	FS._set_friends(typed)
	await process_frame
	var balatro := _portal(2379780)
	var skyrim := _portal(489830)
	var at_balatro := _npcs(balatro)
	var at_skyrim := _npcs(skyrim)
	var at_plaza: Array = city._plaza_friends
	print("   Balatro: ", at_balatro.map(func(n): return "%s@(%.1f,%.1f)" % [n.friend.name, n.position.x, n.position.z]))
	print("   Skyrim:  ", at_skyrim.map(func(n): return n.friend.name))
	print("   praça:   ", at_plaza.map(func(n): return "%s@(%.1f,%.1f)" % [n.friend.name, n.position.x, n.position.z]))
	_check("3 amigos na porta do Balatro", at_balatro.size() == 3)
	_check("Iris na porta do Skyrim", at_skyrim.size() == 1 and at_skyrim[0].friend.name == "Iris")
	var plaza_names := at_plaza.map(func(n): return n.friend.name)
	_check("praça: Duda, Edu, Fer (CS2), Gabi (fora da Steam)", plaza_names == ["Duda", "Edu", "Fer", "Gabi"])
	_check("Hugo (offline) não aparece", not "Hugo" in plaza_names)
	var door_clear := true
	for n in at_balatro:
		if absf(n.position.x) < 1.9:
			door_clear = false
	_check("ninguém bloqueia a porta (|x| >= 1,9 m)", door_clear)

	print("\n== olhar para um amigo ==")
	var ana = at_balatro[0]
	var ana_pos: Vector3 = ana.global_position
	var portal_forward: Vector3 = balatro.global_transform.basis.z
	player.global_position = ana_pos + portal_forward * 3.0
	player.rotation.y = atan2(portal_forward.x, portal_forward.z)  # vira para a Ana
	player.get_node("Head").rotation.x = 0.0
	for i in 5:
		await physics_frame
	var look: String = player.get_hud().get_look_text()
	print("   HUD: '", look, "'")
	_check("HUD mostra 'Ana — Jogando Balatro'", look == "Ana — Jogando Balatro")

	print("\n== atualização: Ana, Bruno e Carla saíram do jogo ==")
	for f in typed:
		if f.game_id == 2379780:
			f.game_id = 0
			f.game_name = ""
	FS._set_friends(typed)
	await process_frame
	_check("porta do Balatro vazia", _npcs(balatro).size() == 0)
	_check("praça agora com 7", city._plaza_friends.size() == 7)

	print("\n== avatar (baixa o avatar padrão público da Steam) ==")
	var test_friend = typed[0]
	var avatar_path := "user://cache/avatars/%s.jpg" % test_friend.steam_id
	DirAccess.remove_absolute(ProjectSettings.globalize_path(avatar_path))
	FS._avatars.erase(test_friend.steam_id)
	var arrived := []
	FS.avatar_ready.connect(func(id, tex): arrived.append("%s %dx%d" % [id, tex.get_width(), tex.get_height()]))
	var immediate = FS.get_avatar(test_friend)
	var waited := 0
	while arrived.is_empty() and waited < 300:
		await process_frame
		waited += 1
	_check("baixou o avatar", not arrived.is_empty() and immediate == null)
	print("   ", arrived)
	# limpa os avatares falsos do cache
	for f in typed:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://cache/avatars/%s.jpg" % f.steam_id))

	print("\n== chave falsa -> erro 403, sem vazar a chave ==")
	problems.clear()
	FS._api_key = FAKE_KEY
	FS._steam_id = "76561197960435530"
	FS._enabled = true
	FS._friend_list_ms = -1
	FS._problem = ""
	# Se a consulta "de verdade" (com a sua chave do config.cfg) ainda estiver em
	# andamento, o refresh() seria ignorado: espera ela terminar primeiro.
	waited = 0
	while not FS._pending_kind.is_empty() and waited < 900:
		await process_frame
		waited += 1
	problems.clear()
	FS._problem = ""
	FS.refresh()
	waited = 0
	while problems.is_empty() and waited < 900:
		await process_frame
		waited += 1
	print("   aviso: ", problems)
	_check("avisou chave inválida", not problems.is_empty() and "inválida" in problems[0])
	_check("parou de consultar", not FS._enabled)
	_check("a chave não aparece no aviso", not problems.is_empty() and not FAKE_KEY in problems[0])

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _portal(app_id: int) -> Node:
	return city.get_node("Building_%d/GamePortal" % app_id)


func _npcs(portal: Node) -> Array:
	return portal._friend_npcs.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
