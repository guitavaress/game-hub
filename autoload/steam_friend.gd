class_name SteamFriend
extends RefCounted
## Ficha de um amigo da Steam, como a Web API descreve (GetPlayerSummaries).

## Estados da Steam ("personastate").
enum Status { OFFLINE, ONLINE, BUSY, AWAY, SNOOZE, LOOKING_TO_TRADE, LOOKING_TO_PLAY }

## SteamID64 em texto (17 dígitos).
var steam_id: String = ""
var name: String = ""
var status: int = Status.OFFLINE
## App ID do jogo que está jogando (0 = nenhum, ou um jogo fora da Steam).
var game_id: int = 0
## Nome do jogo que está jogando ("" = nenhum).
var game_name: String = ""
## Endereço do avatar (64x64).
var avatar_url: String = ""


func is_online() -> bool:
	return status != Status.OFFLINE


func is_playing() -> bool:
	return game_id > 0 or not game_name.is_empty()


## Texto curto para mostrar (ex.: "Jogando Balatro", "Ausente").
func status_text() -> String:
	if is_playing():
		return "Jogando %s" % game_name if not game_name.is_empty() else "Jogando"
	match status:
		Status.ONLINE:
			return "Online"
		Status.BUSY:
			return "Ocupado"
		Status.AWAY, Status.SNOOZE:
			return "Ausente"
		Status.LOOKING_TO_TRADE:
			return "Quer trocar itens"
		Status.LOOKING_TO_PLAY:
			return "Quer jogar"
	return "Offline"


func _to_string() -> String:
	return "%s (%s)" % [name, status_text()]
