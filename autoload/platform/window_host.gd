class_name WindowHost
extends RefCounted
## Quem esconde e mostra a JANELA do hub quando um jogo abre e fecha.
##
## Esta versão base é a janela "normal" da Godot (Windows, ou Linux fora do
## Hyprland): esconder = minimizar; para voltar, a HubWindow restaura monitor,
## posição e tamanho e traz a janela para a frente.
##
## No Hyprland não existe minimizar, e quem decide posição e tamanho é ele.
## Lá o WindowHostHyprland usa workspaces (veja window_host_hyprland.gd).
##
## Ninguém escolhe a versão na mão: a HubWindow chama WindowHost.create().


## A versão certa para este computador.
static func create() -> WindowHost:
	if OS.get_name() == "Linux" and not OS.get_environment("HYPRLAND_INSTANCE_SIGNATURE").is_empty():
		return WindowHostHyprland.new()
	return WindowHost.new()


## Nome curto (para testes e depuração).
func platform_name() -> String:
	return "godot"


## true = o sistema decide monitor, posição e tamanho da janela, então a
## HubWindow não guarda nem restaura isso.
func manages_placement() -> bool:
	return false


## Chamado logo depois de pedir o jogo à Steam, antes de a janela dele aparecer.
## game_monitor: onde o jogo deve abrir ("" = onde estiver). Aqui: nada a fazer.
func make_room_for_game(_game_monitor: String) -> void:
	pass


## Esconde o hub enquanto o jogo roda.
func hide_hub() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


## Mostra o hub de novo (o jogo fechou). Aqui quem faz o trabalho é a
## HubWindow (posição guardada, trazer para a frente).
func show_hub() -> void:
	pass
