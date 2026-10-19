class_name DesktopAppsBackend
extends RefCounted
## O "contrato" de cada sistema para listar os programas instalados.
##
##   DesktopAppsLinux: arquivos .desktop (padrão XDG).
##   DesktopAppsWindows: atalhos (.lnk) do Menu Iniciar.
##
## Esta versão base é a de um sistema sem suporte: a lista é vazia.
## Ninguém usa os backends direto; todo mundo passa pelo DesktopApps.


func platform_name() -> String:
	return "nenhum"


## Os apps instalados e visíveis (sem ordem definida). Pode rodar numa thread.
func list_apps() -> Array[DesktopApp]:
	return []


## Caminho do arquivo de imagem do ícone ("" = não achei). Pode rodar numa thread.
func find_icon(_icon_name: String) -> String:
	return ""


## Abre o app (sem esperar ele fechar). true = o sistema aceitou o pedido.
func launch(_app: DesktopApp) -> bool:
	return false


## Abre o app DENTRO do compositor do hub (Fase 14.21): "env" é o ambiente
## ("NOME=valor") e "profile_dir" a pasta do perfil próprio dos navegadores.
## Só o Linux sabe; os outros devolvem false e o hub abre o app fora.
func launch_in_compositor(_app: DesktopApp, _env: PackedStringArray, _profile_dir: String) -> bool:
	return false
