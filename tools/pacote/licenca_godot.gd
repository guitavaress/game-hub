extends SceneTree
## Gera a licença da Godot para o pacote do Windows (Fase 18.6).
##
## A Godot não deixa um LICENSE no disco: o texto vem do próprio motor. Saem a
## licença MIT da Godot, a lista das bibliotecas de terceiros que vão dentro do
## motor (com os direitos autorais) e o texto de cada licença dessas bibliotecas.
##
## Uso (o tools/empacotar_windows.sh chama sozinho):
##   godot --headless --path . -s res://tools/pacote/licenca_godot.gd -- <arquivo de saída>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Falta o arquivo de saída (depois de --).")
		quit(1)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		printerr("Não consegui escrever em %s." % args[0])
		quit(1)
		return
	file.store_string(build_text())
	file.close()
	print("licença da Godot gravada")
	quit(0)


## O texto inteiro: a licença da Godot, os componentes e as licenças deles.
static func build_text() -> String:
	var info := Engine.get_version_info()
	var lines := PackedStringArray()
	lines.append("Godot Engine %s (https://godotengine.org)" % info.get("string", ""))
	lines.append("O Game Hub roda sobre a Godot. Esta é a licença dela.")
	lines.append("")
	lines.append(Engine.get_license_text())
	lines.append("")
	lines.append("=".repeat(72))
	lines.append("Bibliotecas de terceiros dentro da Godot")
	lines.append("=".repeat(72))
	for component: Dictionary in Engine.get_copyright_info():
		lines.append("")
		lines.append(str(component.get("name", "")))
		for part: Dictionary in component.get("parts", []):
			for holder in part.get("copyright", []):
				lines.append("  Copyright %s" % holder)
			lines.append("  Licença: %s" % part.get("license", ""))
	lines.append("")
	lines.append("=".repeat(72))
	lines.append("Textos das licenças")
	lines.append("=".repeat(72))
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for license_name in names:
		lines.append("")
		lines.append("--- %s ---" % license_name)
		lines.append(str(licenses[license_name]))
	return "\n".join(lines) + "\n"
