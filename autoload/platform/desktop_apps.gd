class_name DesktopApps
extends RefCounted
## DesktopApps: a ÚNICA porta para perguntar "quais programas estão instalados?".
##
## Igual ao SteamClient: não é autoload, as funções são "static", e o backend
## do sistema é escolhido uma vez só, quando o script carrega.
##   Linux: DesktopAppsLinux (arquivos .desktop);
##   Windows: DesktopAppsWindows (atalhos do Menu Iniciar);
##   outros: DesktopAppsBackend (lista vazia).
##
## Arquivos .desktop, caminhos do XDG e comandos de abrir app ficam só em
## autoload/platform/ (o tests/check_platform.gd confere).

static var _backend: DesktopAppsBackend = _create_backend()


static func platform_name() -> String:
	return _backend.platform_name()


## Os apps instalados e visíveis. Pode rodar numa thread separada.
static func list_apps() -> Array[DesktopApp]:
	return _backend.list_apps()


## Caminho do arquivo de imagem do ícone de um app ("" = não achei).
## Pode rodar numa thread separada.
static func find_icon(icon_name: String) -> String:
	return _backend.find_icon(icon_name)


static func _create_backend() -> DesktopAppsBackend:
	if OS.get_name() == "Linux":
		return DesktopAppsLinux.new()
	if OS.get_name() == "Windows":
		return DesktopAppsWindows.new()
	return DesktopAppsBackend.new()
