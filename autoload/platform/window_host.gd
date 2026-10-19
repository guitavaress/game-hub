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
## Janelas de APP (Fase 14.5): para saber quando um app aberto pelo hub
## fechou, alguns sistemas deixam achar e acompanhar a janela dele
## (can_track_windows). Esta versão base NÃO sabe: o AppLauncher cai no
## "sem acompanhar" (a sessão acaba quando o hub volta a ter foco).
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


## O jogo está rodando: põe a janela dele no lugar (game_monitor) e, se
## fullscreen = true, em tela cheia. game_pids: os processos do jogo (a janela
## é de um deles ou de um "filho"). A HubWindow chama isto várias vezes
## seguidas, porque a janela pode demorar a aparecer.
## Aqui: nada (no Windows, o próprio jogo decide onde e como abre).
func place_game_windows(_game_pids: Array[int], _game_monitor: String, _fullscreen: bool) -> void:
	pass


## Esconde o hub enquanto o jogo roda.
func hide_hub() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


## O hub já estava escondido, mas alguém o chamou de volta (o atalho do
## Omarchy) durante um JOGO: esconde de novo, sem mexer no jogo.
## Aqui: nada (no Windows, quem restaura a janela vê a tela "Jogando" e
## minimiza quando quiser, como sempre foi).
func hide_hub_again() -> void:
	pass


## Mostra o hub de novo (o jogo fechou). Aqui quem faz o trabalho é a
## HubWindow (posição guardada, trazer para a frente).
func show_hub() -> void:
	pass


# --- Atalhos do Omarchy sentado à mesa (Fase 14.30) ---------------------------
# O jogador sentado à mesa usa os atalhos do Omarchy (SUPER + Enter...) DENTRO
# do hub. Para o Hyprland de fora não agir sobre eles, o hub liga um "submap"
# quase vazio enquanto está sentado: as combinações chegam à Godot como teclas.

## true = este sistema sabe ligar o submap (só o Hyprland).
func supports_seat_shortcuts() -> bool:
	return false


## O jogador sentou: liga o submap. Devolve false se o sistema recusou.
func seat_begin() -> bool:
	return false


## Chamado a cada poucos segundos enquanto sentado: define o submap de novo
## (um "hyprctl reload" apaga as teclas dele) e renova o vigia que desliga o
## submap sozinho se o hub travar.
func seat_keepalive() -> void:
	pass


## O jogador levantou (ou o hub saiu): desliga o submap.
func seat_end() -> void:
	pass


# --- Janelas de app (Fase 14.5) -----------------------------------------------
# Estas quatro podem rodar numa thread (não mexem na árvore de nós).

## true = sabe achar a janela de um app e dizer quando ela fechou.
func can_track_windows() -> bool:
	return false


## Os endereços de TODAS as janelas abertas agora (a "foto" de antes de abrir
## um app). Aqui: nenhuma.
func list_window_addresses() -> PackedStringArray:
	return PackedStringArray()


## A janela do app que acabou de abrir: a primeira janela NOVA (que não estava
## em "before") do tiling, de preferência com a classe wm_class.
## "" = ainda não apareceu (ou este sistema não sabe).
func find_new_window(_before: PackedStringArray, _wm_class: String) -> String:
	return ""


## A janela ainda está aberta? Só vale com can_track_windows() = true.
func window_exists(_address: String) -> bool:
	return false
