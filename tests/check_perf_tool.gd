extends SceneTree
## Teste da ferramenta de desempenho (Fase 13.9): roda tools/medir_desempenho.gd
## sem janela, com 7 jogos falsos, e confere que saem as três linhas
## (MEDIDA, MEDIDA_CASA e MEDIDA_ESPELHO) no formato de sempre. Os números
## sem janela não valem nada: só o formato e a presença das linhas.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string("user://config.cfg")
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"-s", "res://tools/medir_desempenho.gd", "--", "7", "leve", "22"], output, true)
	var text := "\n".join(PackedStringArray(output))
	_check("a ferramenta terminou sem erro (código %d)" % code, code == 0 and not text.contains("SCRIPT ERROR"))
	var pattern := RegEx.create_from_string("(MEDIDA(?:_CASA|_ESPELHO)?) jogos=\\d+ qualidade=leve hora=22 \\| montagem=\\d+ ms \\| fps_medio=[\\d.]+ \\| quadro_p99=\\d+ ms \\| pior=\\d+ ms \\| desenhos=\\d+ \\| textura=\\d+ MB \\| memoria=\\d+ MB \\| quadros=\\d+")
	var found := {}
	for match in pattern.search_all(text):
		found[match.get_string(1)] = true
	for label in ["MEDIDA", "MEDIDA_CASA", "MEDIDA_ESPELHO"]:
		_check("sai a linha %s" % label, found.has(label))
	_check("a qualidade do usuário foi devolvida", FileAccess.get_file_as_string("user://config.cfg").contains('quality="%s"' % app.get_quality()))
	var file := FileAccess.open("user://config.cfg", FileAccess.WRITE)
	file.store_string(backup)
	file.close()

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
