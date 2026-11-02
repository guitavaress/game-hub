class_name DesktopApp
extends RefCounted
## Ficha de um programa instalado (um app comum, não um jogo da Steam).
## No Linux vem de um arquivo .desktop; no Windows, de um atalho do Menu Iniciar.

## Identificador estável: no Linux, o nome do .desktop sem a extensão ("foot").
var id: String = ""
var name: String = ""
## Frase curta que o app diz de si mesmo (pode ser vazia).
var comment: String = ""
## Nome do ícone no tema do sistema (ou um caminho). A 14.3 acha a imagem.
var icon_name: String = ""
## As categorias do XDG, como estão no arquivo (ex.: ["Network", "WebBrowser"]).
var categories: PackedStringArray = PackedStringArray()
## Classe da janela do app, se o arquivo disser (ajuda a achar a janela dele).
var wm_class: String = ""
## Comando do arquivo, sem os %f/%u (o último recurso para abrir o app).
var exec_line: String = ""
## Onde o arquivo está (para depuração).
var source_path: String = ""


func _to_string() -> String:
	return "%s (%s)" % [name, id]
