extends SceneTree
## Rodar uma vez ANTES da refatoração 15.2. Nunca atualizar para esconder regressões.
const OUTPUT: String = "res://tests/fixtures/planta_atual.json"

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if FileAccess.file_exists(OUTPUT):
		push_error("O retrato histórico já existe; não será sobrescrito.")
		quit(1)
		return
	load("res://tests/quiet_friends.gd").install(root)
	var cases: Dictionary = {}
	for count: int in [6, 40, 200]:
		load("res://tests/fake_library.gd").install(root, count, false, true)
		var city: Node = load("res://worlds/city/city.tscn").instantiate()
		city.play_intro = false
		root.add_child(city)
		while not city.is_city_ready():
			await process_frame
		cases[str(count)] = load("res://tests/planta_snapshot.gd").capture(city)
		city.queue_free()
		await process_frame
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"origem": "158aec0, antes da refatoração 15.2; IDs fixos", "cases": cases}, "\t") + "\n")
	file.close()
	print("Retrato gravado: 6, 40 e 200 jogos.")
	quit()
