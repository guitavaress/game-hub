class_name SteamClient
extends RefCounted
## SteamClient: a ÚNICA porta para perguntar coisas à Steam deste computador.
##
## NÃO é um autoload: as funções são "static", então qualquer script chama
## SteamClient.steam_path() sem instanciar nada.
##
## Os sistemas (SteamLibrary, GameLauncher) perguntam "onde está a Steam?" e
## "qual jogo está rodando?", sem saber de onde vem a resposta. Quem sabe é o
## backend do sistema operacional, escolhido uma vez só, quando o script carrega:
##   Windows: SteamClientWindows (registro do Windows);
##   Linux:   SteamClientLinux (pasta da Steam e processos em /proc);
##   outros:  SteamClientBackend (ainda sem suporte: a Steam não é encontrada).
##
## Código de sistema operacional (registro, tasklist, /proc...) fica só em
## autoload/platform/. Fora dessa pasta, ninguém o usa.

static var _backend: SteamClientBackend = _create_backend()


## Nome do backend em uso ("windows", "nenhum"...).
static func platform_name() -> String:
	return _backend.platform_name()


## Pasta da Steam com barras "/" e sem "/" no fim, ou "" se não achar.
static func steam_path() -> String:
	return _backend.steam_path()


## "Account id" de quem está logado na Steam agora, ou 0 (ex.: Steam fechada).
static func active_account_id() -> int:
	return _backend.active_account_id()


## Os processos do jogo (no Linux, os reapers; no Windows, []).
static func game_process_ids(app_id: int) -> Array[int]:
	return _backend.game_process_ids(app_id)


## Estado da Steam agora (veja SteamClientBackend.read_state para as chaves).
## Pode rodar numa thread separada.
static func read_state(app_id: int, check_steam: bool) -> Dictionary:
	return _backend.read_state(app_id, check_steam)


static func _create_backend() -> SteamClientBackend:
	match OS.get_name():
		"Windows":
			return SteamClientWindows.new()
		"Linux":
			return SteamClientLinux.new()
	return SteamClientBackend.new()
