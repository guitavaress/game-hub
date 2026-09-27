class_name SteamGame
extends RefCounted
## Ficha de um jogo instalado, lida do appmanifest_<appid>.acf.

var app_id: int = 0
var name: String = ""
## Nome da pasta do jogo dentro de steamapps/common/.
var install_dir: String = ""
## Pasta da biblioteca Steam onde ele está (ex.: "D:/SteamLibrary").
var library_path: String = ""
## Última vez que foi jogado (segundos desde 1970; 0 = nunca).
var last_played: int = 0
## Tamanho no disco, em bytes.
var size_on_disk: int = 0


func _to_string() -> String:
	return "%s (%d)" % [name, app_id]
