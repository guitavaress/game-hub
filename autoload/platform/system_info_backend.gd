class_name SystemInfoBackend
extends RefCounted
## O "contrato" de cada sistema para contar o estado do computador:
## bateria, rede e volume.
##
##   SystemInfoLinux: /sys/class/power_supply, nmcli e wpctl.
##
## Esta versão base é a de um sistema sem suporte: responde "não sei".
## Ninguém usa os backends direto; todo mundo passa pelo SystemInfo.
##
## A resposta de read() é sempre um Dictionary com estas chaves:
##   "battery": {"present": bool, "percent": int, "charging": bool}
##   "network": {"known": bool, "type": "wifi"|"ethernet"|"other"|"none",
##               "connected": bool, "name": String}
##   "volume":  {"known": bool, "percent": int, "muted": bool}


func platform_name() -> String:
	return "nenhum"


## O estado de agora. Pode rodar numa thread.
func read() -> Dictionary:
	return unknown()


## A resposta de "não sei" (também serve de molde para os backends).
static func unknown() -> Dictionary:
	return {
		"battery": {"present": false, "percent": 0, "charging": false},
		"network": {"known": false, "type": "none", "connected": false, "name": ""},
		"volume": {"known": false, "percent": 0, "muted": false},
	}
