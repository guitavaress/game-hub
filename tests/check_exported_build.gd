extends SceneTree
## Teste do build exportado do Windows (Fase 18.2).
##
## Roda em duas partes:
##   1. Fora (na bateria, com o projeto): procura build/windows/GameHub.pck. Sem
##      build, PULA (passa). Com build, abre outra Godot com "--main-pack" nesse
##      pck e este mesmo script, e confere o que ela respondeu.
##   2. Dentro (com "-- --dentro-do-pck"): o res:// é o pck. Confere que os
##      autoloads existem, que a cidade monta, que o ícone foi junto e que as
##      sobras do projeto (tests/, tools/, docs/...) ficaram de fora.
##
## O build sai de "bash tools/empacotar_windows.sh". Se a versão do pck for
## diferente da do project.godot, o build está velho: o teste avisa e falha.

const PCK := "res://build/windows/GameHub.pck"
const INSIDE_FLAG := "--dentro-do-pck"
## Pastas e arquivos do repositório que nunca podem ir para o pck.
const FORBIDDEN_DIRS: Array[String] = [
	"res://tests", "res://tools", "res://docs", "res://native", "res://painel",
	"res://game-hub-brand-kit", "res://build", "res://.claude", "res://.codex",
	"res://.vscode", "res://.agents", "res://.github",
]
const FORBIDDEN_FILES: Array[String] = [
	"res://opencode.json", "res://.mcp.json", "res://AGENTS.md", "res://CLAUDE.md",
	"res://README.md", "res://saida.txt",
]

var failures := 0


func _initialize() -> void:
	if INSIDE_FLAG in OS.get_cmdline_user_args():
		_run_inside()
	else:
		_run_outside()


# --- Parte 1: fora do pck ----------------------------------------------------

func _run_outside() -> void:
	await process_frame
	var pck := ProjectSettings.globalize_path(PCK)
	if not FileAccess.file_exists(pck):
		print("  [ok] sem build em build/windows/: pulado (gere com bash tools/empacotar_windows.sh)")
		_finish()
		return

	var me := ProjectSettings.globalize_path(get_script().resource_path)
	var args := PackedStringArray(["--headless", "--main-pack", pck, "-s", me, "--", INSIDE_FLAG])
	var output: Array = []
	OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(PackedStringArray(output))

	# Repete as conferências de dentro, para o log da bateria mostrar tudo.
	for line in text.split("\n"):
		if line.begins_with("  [") or line.begins_with("VERSAO="):
			# A saída chega em Latin-1 no Windows: volta para UTF-8 (os acentos).
			print(_latin1_to_utf8(line))
	_check("o pck abriu e respondeu (RESULTADO de dentro: TUDO OK)", text.contains("RESULTADO: TUDO OK"))

	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check("o build é da versão atual (%s); se não, refaça com tools/empacotar_windows.sh" % version,
		text.contains("VERSAO=%s\n" % version) or text.contains("VERSAO=%s\r" % version))
	_finish()


# --- Parte 2: dentro do pck --------------------------------------------------

func _run_inside() -> void:
	await process_frame
	print("VERSAO=%s" % ProjectSettings.get_setting("application/config/version", ""))
	# Atenção: com --main-pack, o FileAccess procura no disco (na pasta atual) o
	# que não acha no pck; por isso tudo aqui pergunta ao DirAccess, que só vê o pck.
	_check("o res:// é o pck (tem project.binary, não project.godot)",
		_in_pack("res://project.binary") and not _in_pack("res://project.godot"))
	_check("controle: res://autoload está no pck", DirAccess.dir_exists_absolute("res://autoload"))

	# Todos os autoloads do projeto foram criados.
	for property in ProjectSettings.get_property_list():
		var key: String = property.name
		if not key.begins_with("autoload/"):
			continue
		var autoload_name := key.get_slice("/", 1)
		_check("autoload %s existe" % autoload_name, root.get_node_or_null(autoload_name) != null)

	# O ícone vai cru no pck (a Godot lê assim para a janela).
	var icon := str(ProjectSettings.get_setting("application/config/icon", ""))
	_check("o ícone está no pck (%s)" % icon, icon != "" and _in_pack(icon))

	# Nenhuma sobra do repositório.
	for dir in FORBIDDEN_DIRS:
		_check("%s não está no pck" % dir, not DirAccess.dir_exists_absolute(dir))
	for file in FORBIDDEN_FILES:
		_check("%s não está no pck" % file, not _in_pack(file))
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".json") or file.ends_with(".md") or file.ends_with(".cfg"):
			_check("arquivo solto na raiz do pck: %s" % file, false)

	# A cena principal carrega e a cidade monta.
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var scene := load(main_path) as PackedScene
	_check("a cena principal carrega (%s)" % main_path, scene != null)
	if scene != null:
		var city: Node = scene.instantiate()
		city.play_intro = false  # sem janela: montagem direta
		root.add_child(city)
		var deadline := Time.get_ticks_msec() + 120000
		while not city.is_city_ready() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check("a cidade montou a partir do pck", city.is_city_ready())
	_finish()


## "nÃ£o" -> "não": cada letra vira um byte, e os bytes são lidos como UTF-8.
## Se a linha já estava certa (letra acima de 255), devolve como veio.
static func _latin1_to_utf8(line: String) -> String:
	var bytes := PackedByteArray()
	for i in line.length():
		var code := line.unicode_at(i)
		if code > 255:
			return line
		bytes.append(code)
	var fixed := bytes.get_string_from_utf8()
	return fixed if not fixed.is_empty() else line


## Se o arquivo está DENTRO do pck (sem cair no disco).
func _in_pack(path: String) -> bool:
	return path.get_file() in DirAccess.get_files_at(path.get_base_dir())


func _finish() -> void:
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
