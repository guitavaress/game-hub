extends SceneTree
## Teste da primeira vez guiada (Fase 10.7). Guarda o config.cfg antes e
## devolve no fim (o cartão grava "visto").
##   - sem "visto", o fim da abertura (finish_intro) mostra o cartão de
##     controles, e um aviso que chegou antes (o dos amigos, por exemplo)
##     espera ele sair;
##   - o primeiro E fecha o cartão, grava "visto" e o aviso aparece;
##   - na segunda vez, o cartão não aparece.

const CONFIG := "user://config.cfg"
const FRIENDS_TITLE := "Aviso de teste dos amigos"

var failures := 0
var backup := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	backup = FileAccess.get_file_as_string(CONFIG)
	await process_frame
	var app = root.get_node("AppConfig")
	app.set_seen_controls_hint(false)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false  # monta direto; a abertura é simulada abaixo
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	var player = city.get_node("Player")
	var hud = player.get_hud()
	hud.clear_messages()
	_check("sem a abertura, o cartão não aparece", not hud.is_controls_hint_open())

	print("== primeira vez ==")
	player.start_intro()
	hud.show_message(FRIENDS_TITLE, "Coloque a chave da Steam Web API.")
	player.finish_intro()
	await _frames(3)
	_check("o cartão de controles aparece", hud.is_controls_hint_open() and hud.get_controls_hint().visible)
	_check("o HUD aparece junto", hud.visible)
	_check("o aviso dos amigos espera o cartão sair", not _has_message(hud, FRIENDS_TITLE))
	var keys := _texts(hud.get_controls_hint())
	for key in ["W", "Shift", "E", "Tab", "M", "Esc", "andar", "correr", "usar", "buscar", "mapa", "menu"]:
		if not key in keys:
			_check("o cartão mostra \"%s\"" % key, false)
	_check("o cartão mostra as teclas e o que fazem", ["W", "Shift", "E", "Tab", "M", "Esc"].all(func(k: String) -> bool: return k in keys))
	_check("ainda não gravou \"visto\"", not app.get_seen_controls_hint())

	print("== o primeiro E fecha ==")
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)
	_check("o cartão fechou", not hud.is_controls_hint_open())
	_check("gravou \"visto\" na memória", app.get_seen_controls_hint())
	_check("e no config.cfg", "seen_controls_hint=true" in FileAccess.get_file_as_string(CONFIG))
	_check("o aviso dos amigos aparece", _has_message(hud, FRIENDS_TITLE))

	print("== segunda vez ==")
	hud.clear_messages()
	player.start_intro()
	player.finish_intro()
	await _frames(3)
	_check("o cartão não aparece de novo", not hud.is_controls_hint_open())

	print("== o cartão some sozinho ==")
	app.set_seen_controls_hint(false)
	player.start_intro()
	player.finish_intro()
	await _frames(2)
	var hint = hud.get_controls_hint()
	hint._time_left = 0.05  # sem esperar os 15 s
	await create_timer(0.2).timeout
	_check("sumiu sozinho e gravou \"visto\"", not hud.is_controls_hint_open() and app.get_seen_controls_hint())

	root.remove_child(city)
	city.free()
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	_check("config.cfg restaurado", FileAccess.get_file_as_string(CONFIG) == backup)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _has_message(hud: Node, title: String) -> bool:
	for message: String in hud.get_messages():
		if message.begins_with(title):
			return true
	return false


## Todos os textos (Label) dentro de um nó.
func _texts(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for label in node.find_children("*", "Label", true, false):
		result.append(label.text)
	return result


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
