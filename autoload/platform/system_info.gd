class_name SystemInfo
extends RefCounted
## SystemInfo: a ÚNICA porta para perguntar "como está o computador?"
## (bateria, rede, volume).
##
## Igual ao SteamClient: não é autoload, as funções são "static", e o backend
## do sistema é escolhido uma vez só, quando o script carrega.
##   Linux: SystemInfoLinux;
##   outros: SystemInfoBackend (sempre "não sei").
##
## Pastas do /sys e comandos do sistema (nmcli, wpctl) ficam só em
## autoload/platform/ (o tests/check_platform.gd confere).

static var _backend: SystemInfoBackend = _create_backend()


static func platform_name() -> String:
	return _backend.platform_name()


## O estado de agora (formato em system_info_backend.gd). Pode rodar numa thread.
static func read() -> Dictionary:
	return _backend.read()


static func _create_backend() -> SystemInfoBackend:
	if OS.get_name() == "Linux":
		return SystemInfoLinux.new()
	return SystemInfoBackend.new()
