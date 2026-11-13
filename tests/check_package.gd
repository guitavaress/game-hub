extends SceneTree
## Teste do pacote do Windows (Fase 18.6). Só lê arquivos do projeto: não monta
## a cidade, não exporta e não usa user://.
##
## Confere que:
##   - toda licença de assets/ e addons/ (LICENSE*, License*, OFL*, COPYING*,
##     em qualquer pasta) está na lista tools/pacote/licencas.txt, que é o que o
##     tools/empacotar_windows.sh copia para licencas/;
##   - a lista não aponta para arquivo que não existe nem repete um nome;
##   - a licença da Godot sai do motor (tools/pacote/licenca_godot.gd);
##   - o LEIA-ME tem o que o amigo precisa (requisitos, aviso do Windows, dados).

const LIST := "res://tools/pacote/licencas.txt"
const README := "res://tools/pacote/LEIA-ME.txt"
const GODOT_LICENSE_SCRIPT := "res://tools/pacote/licenca_godot.gd"
## Onde procurar licenças de terceiros (e as nossas, de assets).
const SEARCH_ROOTS: Array[String] = ["res://assets", "res://addons"]
## "godot.txt" é gerado pelo script, não vem da lista.
const RESERVED := "godot.txt"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var entries := _read_list()
	_check("a lista de licenças tem itens", entries.size() > 0)

	var sources: Array[String] = []
	var targets: Array[String] = []
	for entry: PackedStringArray in entries:
		var source := entry[0]
		var target := entry[1] if entry.size() > 1 else ""
		_check("%s existe" % source, FileAccess.file_exists("res://" + source))
		_check("%s tem nome de destino .txt sem pasta (%s)" % [source, target],
			target.ends_with(".txt") and not target.contains("/") and not target.contains("\\"))
		_check("destino %s não repete" % target, not (target in targets))
		_check("destino %s não é o reservado da Godot" % target, target != RESERVED)
		sources.append(source)
		targets.append(target)

	_check("o LICENSE do projeto está na lista", "LICENSE" in sources)
	_check("a OFL da Barlow está na lista", "assets/fonts/barlow/OFL.txt" in sources)

	# Nenhuma licença do disco pode ficar de fora.
	var found: Array[String] = []
	for root_dir in SEARCH_ROOTS:
		_collect_licenses(root_dir, found)
	_check("achou licenças em assets/ e addons/ (%d)" % found.size(), found.size() >= 10)
	for path in found:
		_check("%s está em tools/pacote/licencas.txt" % path, path in sources)

	# A licença da Godot vem do motor.
	var godot_script: GDScript = load(GODOT_LICENSE_SCRIPT)
	_check("o gerador da licença da Godot carrega", godot_script != null)
	if godot_script != null:
		var text: String = godot_script.build_text()
		_check("a licença gerada tem o texto MIT da Godot", text.contains(Engine.get_license_text()))
		_check("a licença gerada lista as bibliotecas de terceiros",
			text.contains("Bibliotecas de terceiros") and text.length() > 20000)

	# O LEIA-ME.
	var readme := FileAccess.get_file_as_string(README)
	_check("o LEIA-ME existe", not readme.is_empty())
	_check("o LEIA-ME recebe a versão ({VERSAO})", readme.contains("{VERSAO}"))
	var data_dir := "%%APPDATA%%\\Godot\\app_userdata\\%s" % ProjectSettings.get_setting("application/config/name")
	for needed: String in ["Windows 10", "Steam", "Vulkan", "Mais informações", "Executar assim mesmo",
			"Esc", "Amigos", "Contar o que achei", data_dir, "licencas"]:
		_check("o LEIA-ME fala de \"%s\"" % needed, readme.contains(needed))
	var key_like := RegEx.create_from_string("[0-9A-Fa-f]{32}")
	_check("o LEIA-ME não tem nada com cara de chave", key_like.search(readme) == null)
	_finish()


## Cada linha útil da lista vira [origem, destino].
func _read_list() -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var text := FileAccess.get_file_as_string(LIST)
	_check("tools/pacote/licencas.txt existe", not text.is_empty())
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		_check("linha com origem e destino: %s" % line, parts.size() == 2)
		result.append(parts)
	return result


## Procura, em todas as subpastas, arquivos com nome de licença.
## Guarda o caminho sem "res://", igual ao da lista.
func _collect_licenses(path: String, found: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		var lower := file.to_lower()
		if lower.ends_with(".import") or lower.ends_with(".uid"):
			continue
		if lower.begins_with("license") or lower.begins_with("licence") \
				or lower.begins_with("ofl") or lower.begins_with("copying"):
			found.append(path.path_join(file).trim_prefix("res://"))
	for sub in dir.get_directories():
		_collect_licenses(path.path_join(sub), found)


func _finish() -> void:
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
