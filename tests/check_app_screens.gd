extends SceneTree
## Teste dos telões da casa (Fase 14.20): três telões no grupo app_screen, a
## oferta de uma janela, a liberação ao fechar, e nenhum telão dentro de móvel,
## do painel, da janela ou da porta em nenhuma das 3 disposições.

const CONFIG := "user://config.cfg"
const DOOR_ZONE := AABB(Vector3(-0.7, 0.0, 3.9), Vector3(1.4, 2.4, 0.8))
const WINDOW_ZONE := AABB(Vector3(-2.7, 0.0, -4.6), Vector3(5.4, 3.4, 0.6))

var failures := 0


class FakeSource extends AppWindowSource:
	var sizes: Array[Vector2i] = []

	func resize(size: Vector2i) -> void:
		sizes.append(size)

	func get_title() -> String:
		return "Terminal"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var backup := FileAccess.get_file_as_string(CONFIG)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame
	var home = city.get_home()
	var screens = home.get_node("AppScreens")

	print("== Os telões ==")
	var nodes := get_nodes_in_group("app_screen")
	_check("são três telões no grupo app_screen", nodes.size() == 3 and screens.get_screens().size() == 3)
	_check("todos livres no começo", screens.free_count() == 3)
	var first: AppWindow3D = screens.get_screens()[0]
	_check("telão livre: o cartão diz livre e não oferece ação", first.get_look_info()["title"] == "Telão livre" and first.get_look_info()["action"] == "")
	_check("a imagem do telão está na camada do interior", first.get_node("Surface").layers == home.INTERIOR_LAYER_MASK)
	var all_face_in := true
	for s2 in screens.get_screens():
		var to_center: Vector3 = home.global_position + Vector3(0.0, AppScreens.CENTER_Y, 0.0) - s2.global_position
		all_face_in = all_face_in and s2.global_basis.z.dot(to_center) > 0.0 \
				and absf(s2.global_position.y - home.global_position.y - AppScreens.CENTER_Y) < 0.01
	_check("a frente de cada telão aponta para dentro da sala, no alto", all_face_in)

	print("== Oferta e liberação ==")
	var source_a := FakeSource.new()
	var source_b := FakeSource.new()
	var source_c := FakeSource.new()
	var source_d := FakeSource.new()
	var got: AppWindow3D = screens.offer(source_a)
	_check("a primeira oferta vai para o primeiro telão", got == first and screens.screen_of(source_a) == first)
	_check("o telão recebeu o tamanho", source_a.sizes.size() > 0 and source_a.sizes.back() == Vector2i(1280, 720))
	_check("ocupado, o cartão mostra o título", first.get_look_info()["title"] == "Terminal" and first.get_look_info()["action"] != "")
	var second = screens.offer(source_b)
	_check("a segunda vai para outro telão", second != null and second != first)
	_check("a terceira ocupa o último", screens.offer(source_c) != null and screens.free_count() == 0)
	_check("telões cheios recusam", screens.offer(source_d) == null)
	var changes: Array = []
	screens.screen_changed.connect(func(s: AppWindow3D) -> void: changes.append(s))
	screens.release(second)
	_check("o telão libera ao fechar e avisa", second.get_source() == null and screens.free_count() == 1 and changes == [second])
	_check("a vaga liberada é a da próxima oferta", screens.offer(source_d) == second)
	screens.release(second)
	screens.release(second)  # soltar de novo não quebra
	_check("soltar um telão livre não faz nada", screens.free_count() == 1)

	print("== Posição nas 3 disposições ==")
	for s in screens.get_screens():
		screens.release(s)
	var app = root.get_node("AppConfig")
	var room: Vector3 = home.ROOM_SIZE
	var inner := AABB(Vector3(-room.x / 2.0, 0.0, -room.z / 2.0), room).grow(0.03)
	for layout in Profiles.home_catalog().layouts:
		app.set_home_layout(layout.id)
		await process_frame
		for s in screens.get_screens():
			var box := _bounds_of(s.get_node("Surface"), home).grow(0.02)
			var name := "[%s] %s" % [layout.id, s.name]
			_check(name + " fica dentro da sala", inner.encloses(box))
			_check(name + " não cobre a porta nem a janela", not box.intersects(DOOR_ZONE) and not box.intersects(WINDOW_ZONE))
			var hit := ""
			var others: Array[Node3D] = [home.get_node("ComputerDesk"), home.get_system_panel()]
			for id in ["estante", "apps", "mural", "estatisticas", "espelho"]:
				others.append(home.get_furniture(id))
			for other in others:
				if _bounds(other, home).intersects(box):
					hit = other.name
			_check(name + " não toca em nenhum móvel (%s)" % hit, hit == "")

	app.set_home_layout("")
	if backup != "":
		var file := FileAccess.open(CONFIG, FileAccess.WRITE)
		file.store_string(backup)
		file.close()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _bounds_of(mesh: MeshInstance3D, home: Node3D) -> AABB:
	var box: AABB = mesh.global_transform * mesh.get_aabb()
	box.position -= home.global_position
	return box


func _bounds(piece: Node3D, home: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in piece.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var box := _bounds_of(mesh, home)
		result = box if first else result.merge(box)
		first = false
	return result


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
