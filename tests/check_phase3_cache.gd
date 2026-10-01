extends SceneTree
## Cenários da Fase 3: "segunda abertura" (com cache) e "sem internet".
## Uso: -- --mode=cached   ou   -- --mode=offline

const CACHE := "user://cache/store_info.json"
const BACKUP := "user://cache/store_info.json.bak"

var _frames := 0
var _started_ms := 0
var _city: Node
var _mode := ""
var _saw_message := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.substr(7)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		print("--- modo: ", _mode, " ---")
		if _mode == "offline":
			# Esconde o cache e manda os pedidos para um "proxy" que não existe.
			DirAccess.rename_absolute(CACHE, BACKUP)
			root.get_node("StoreInfo")._cache = {}
			root.get_node("StoreInfo")._http.set_https_proxy("127.0.0.1", 9)
		_started_ms = Time.get_ticks_msec()
		_city = load("res://worlds/city/city.tscn").instantiate()
		root.add_child(_city)
		print("buscando na loja logo após carregar? ", root.get_node("StoreInfo").is_fetching())
	elif _frames > 2:
		if root.get_node("ScreenFade")._message.text != "":
			_saw_message = true
		if _city.is_city_ready():
			var seconds := (Time.get_ticks_msec() - _started_ms) / 1000.0
			var cats = root.get_node("GameCategories")
			var count := {}
			for child in _city.get_children():
				if child.name.begins_with("Building_"):
					var c: String = cats.get_category_id(child.game.app_id)
					count[c] = count.get(c, 0) + 1
			print("pronta em %.2f s | mostrou 'Organizando'? %s | bairros: %s" % [seconds, _saw_message, count])
			print("hud: '", _city.get_node("Player").get_hud().get_messages(), "'")
			if _mode == "offline":
				DirAccess.remove_absolute(CACHE)
				DirAccess.rename_absolute(BACKUP, CACHE)
				print("cache restaurado: ", FileAccess.file_exists(CACHE))
			quit()
