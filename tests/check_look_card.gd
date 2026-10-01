extends SceneTree
## Teste do cartão de "olhar" (P1.5): categoria, amigos, anel da mira, clique.

const BALATRO := 2379780
const SUMMARIES_JSON := """{"response":{"players":[
 {"steamid":"76561190000000001","personaname":"Ana","personastate":1,"gameid":"2379780"},
 {"steamid":"76561190000000002","personaname":"Bruno","personastate":1,"gameid":"2379780"},
 {"steamid":"76561190000000003","personaname":"Duda","personastate":1}
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
	for i in 30:
		await process_frame
	var player = city.get_node("Player")
	var hud = player.get_hud()
	var fs = root.get_node("FriendsService")
	var typed: Array[SteamFriend] = []
	typed.assign(fs.parse_players(JSON.parse_string(SUMMARIES_JSON)))
	fs._set_friends(typed)

	print("\n== nomes em texto corrido ==")
	_check("1, 2, 3+ nomes", SteamFriend.join_names(typed.slice(0, 1)) == "Ana"
		and SteamFriend.join_names(typed.slice(0, 2)) == "Ana e Bruno"
		and SteamFriend.join_names(typed) == "Ana, Bruno e mais 1"
		and SteamFriend.join_names(typed, 3) == "Ana, Bruno e Duda")

	print("\n== olhando o Balatro ==")
	var portal = city.get_node("Building_%d/GamePortal" % BALATRO)
	_look_at(player, portal, 6.0)
	for i in 6:
		await physics_frame
	await process_frame
	print("   texto: ", hud.get_look_text(), " | extras: ", hud.get_look_extras())
	_check("título + detalhes", hud.get_look_text().begins_with("Balatro — "))
	_check("rótulo da categoria", hud.get_look_extras()[0] == "CARTAS E TABULEIRO")
	_check("amigos jogando", hud.get_look_extras()[1] == "●  Ana e Bruno jogando agora")
	var neon: Color = root.get_node("GameCategories").get_neon_color("cartas")
	_check("anel na cor do bairro", hud.is_crosshair_ring() and hud._crosshair_ring.color.is_equal_approx(neon)
		and not hud._crosshair_dot.visible)
	hud._click.stop()
	hud.set_look_info({"title": "Outro alvo"})
	_check("clique toca quando o alvo muda", hud._click.playing)
	hud._click.stop()
	hud.set_look_info({"title": "Outro alvo", "detail": "mudou só o detalhe"})
	_check("mesmo alvo: sem clique", not hud._click.playing)

	print("\n== olhando para o céu ==")
	player.get_node("Head").rotation.x = deg_to_rad(80.0)
	for i in 4:
		await physics_frame
	await process_frame
	_check("cartão some, volta o ponto", not hud._look_card.visible and not hud.is_crosshair_ring()
		and hud._crosshair_dot.visible)

	print("\n== contrato antigo (só get_look_label) ==")
	hud.set_look_text("Ana — Online")
	_check("vira título + detalhes, sem anel", hud.get_look_text() == "Ana — Online" and not hud.is_crosshair_ring()
		and hud.get_look_extras()[0] == "" and not hud._look_label.visible)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Coloca o jogador a "distance" m da porta, olhando para ela.
func _look_at(player, portal, distance: float) -> void:
	var fwd: Vector3 = portal.global_transform.basis.z
	player.global_position = portal.global_position + fwd * distance
	player.rotation.y = atan2(fwd.x, fwd.z)
	player.get_node("Head").rotation.x = deg_to_rad(-8.0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
