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
