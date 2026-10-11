extends RefCounted
## AMIGOS QUIETOS para os testes: desliga a consulta de verdade à Steam (a que
## usa a chave do config.cfg) e tira todos os amigos da cidade. Sem isso, os
## amigos online de verdade aparecem na praça (no caminho de quem anda) e a
## consulta de 60 em 60 s troca os amigos falsos de um teste pelos de verdade.
##
## Uso (num script de teste, logo depois de "await process_frame"):
##   load("res://tests/quiet_friends.gd").install(root)
## Depois disso, o teste põe os amigos falsos que quiser com _set_friends.
## Nada é gravado: a chave e as opções continuam no config.cfg.


static func install(root: Node) -> void:
	var service := root.get_node("FriendsService")
	service._timer.stop()
	if not String(service._pending_kind).is_empty():
		service._http.cancel_request()
		service._pending_kind = ""
	service._enabled = false
	var none: Array[SteamFriend] = []
	service._set_friends(none)
