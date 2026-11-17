extends SceneTree
## A VISÃO NA BATERIA (Fase 20.5). O jogador nasce na visão gravada no
## config.cfg ([controls] view). Os testes foram escritos para a primeira
## pessoa (os da terceira a pedem); se o usuário deixou a terceira gravada,
## vários quebrariam. O tests/run_tests.sh chama este script:
##
##   -- guardar   antes dos testes: guarda a visão do usuário num arquivo à
##                parte (user://visao_antes_da_bateria.txt) e grava "first";
##   -- devolver  no fim (também em erro e Ctrl+C): devolve a visão guardada
##                e apaga o arquivo.
##
## Se uma bateria anterior morreu sem devolver, o arquivo ainda existe: o
## "guardar" não o sobrescreve (senão o "first" da bateria viraria o do
## usuário).

const BACKUP := "user://visao_antes_da_bateria.txt"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app := root.get_node("AppConfig")
	var args := OS.get_cmdline_user_args()
	var mode := String(args[0]) if not args.is_empty() else ""
	if mode == "guardar":
		if not FileAccess.file_exists(BACKUP):
			var file := FileAccess.open(BACKUP, FileAccess.WRITE)
			file.store_string(String(app.get_view()))
			file.close()
		app.set_view(app.VIEW_FIRST)
		print("visão da bateria: first (a do usuário guardada)")
	elif mode == "devolver":
		if FileAccess.file_exists(BACKUP):
			var saved := FileAccess.get_file_as_string(BACKUP).strip_edges()
			app.set_view(saved)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
			print("visão do usuário devolvida: ", app.get_view())
	else:
		push_error("Uso: -s tests/visao_da_bateria.gd -- guardar|devolver")
		quit(1)
		return
	quit(0)
