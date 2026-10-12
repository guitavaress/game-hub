class_name SteamClientBackend
extends RefCounted
## O "contrato" que cada sistema operacional cumpre para falar com a Steam.
##
## Cada sistema tem o seu arquivo, que estende este:
##   SteamClientWindows: registro do Windows (reg query) e tasklist.
##   SteamClientLinux:   pasta da Steam e processos em /proc.
##
## Esta versão base é a de um sistema ainda sem suporte: ela nunca acha a Steam.
## Ninguém usa os backends direto; todo mundo passa pelo SteamClient.


## Nome curto do backend (para testes e mensagens de depuração).
func platform_name() -> String:
	return "nenhum"


## Pasta da Steam com barras "/" e sem "/" no fim, ou "" se não achar.
func steam_path() -> String:
	return ""


## "Account id" (número curto da conta) de quem está logado agora, ou 0.
func active_account_id() -> int:
	return 0


## Os processos que a Steam abriu para esse jogo, se o sistema souber dizer
## (no Linux, os "reaper"; a janela do jogo é de um processo "filho" deles).
## Aqui: [] (no Windows não precisamos disso).
func game_process_ids(_app_id: int) -> Array[int]:
	return [] as Array[int]


## Estado da Steam agora. Roda numa thread separada (não mexa em nós aqui!).
##   running_app_id: o jogo que a Steam diz estar rodando (0 = nenhum);
##   steam_running:  a Steam está aberta? (só é conferido com check_steam = true);
##   app_running / app_updating: o jogo "app_id" está rodando / atualizando?
func read_state(_app_id: int, _check_steam: bool) -> Dictionary:
	return {
		"running_app_id": 0,
		"steam_running": false,
		"app_running": false,
		"app_updating": false,
	}
