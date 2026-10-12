extends SceneTree
## Grava o "retrato" da casa de hoje (o loft), ANTES de a Fase 13.2 fazer a casa
## ler o perfil do tema. O teste tests/check_home_profile.gd compara a casa nova
## com este retrato, para garantir que o loft continua idêntico, peça por peça.
##
## Foi rodado uma vez, sobre o código da Fase 12 (antes da 13.2), sem janela:
##   godot --headless --path . -s res://tools/retrato_casa.gd
## Saída: res://tests/fixtures/casa_atual.json
##
## Só faz sentido no código de ANTES da 13.2: depois dela, o retrato passaria a
## comparar a casa nova com ela mesma. Rodando duas vezes, o arquivo sai igual.
## Os scripts da casa são carregados com load() DEPOIS dos autoloads (veja
## tools/retrato_perfis.gd).

const OUTPUT: String = "res://tests/fixtures/casa_atual.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var snapshot: GDScript = load("res://tests/home_snapshot.gd")
	var home: Node3D = (load("res://worlds/home/home.gd") as GDScript).new()
	root.add_child(home)
	await process_frame
	var lines: Array[String] = snapshot.capture(home)
	var portrait := {
		"origem": "Fase 12, antes da 13.2 (a casa ainda não lê o perfil)",
		"noite": home.get_night(),
		"linhas": lines,
	}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(portrait, "\t") + "\n")
	file.close()
	print("Retrato gravado em %s: %d linhas." % [OUTPUT, lines.size()])
	quit()
