extends SceneTree
## Teste da mesa do computador (Fase 14.25): três monitores "Sem sinal", o do
## meio de frente e os dos lados virados para dentro, sem móvel dentro de
## nenhum deles em nenhuma das 3 disposições, e sem foco (não há o que usar).

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var home_script: GDScript = load("res://worlds/home/home.gd")
	var home: Node3D = home_script.new()
	root.add_child(home)
	await process_frame

	print("== Os três monitores ==")
	var desk: ComputerDesk = home.get_node("ComputerDesk")
	var screens := desk.get_screens()
	_check("são três telas", screens.size() == 3)
	_check("get_screen() é a do meio", desk.get_screen() == screens[1])
	var front: Vector3 = screens[1].global_basis.z
	_check("o do meio olha para a frente da mesa", front.dot(desk.global_basis.z) > 0.999)
	_check("o da esquerda vira para dentro (para a direita)", screens[0].global_basis.z.dot(desk.global_basis.x) > 0.2)
	_check("o da direita vira para dentro (para a esquerda)", screens[2].global_basis.z.dot(desk.global_basis.x) < -0.2)
	_check("na ordem: esquerda, meio, direita", screens[0].global_position.x < screens[1].global_position.x
			and screens[1].global_position.x < screens[2].global_position.x)
	var sem_sinal := true
	for screen in screens:
		var info: Dictionary = screen.get_look_info()
		sem_sinal = sem_sinal and info["detail"] == "Sem sinal" and info["action"] == ""
		screen.interact(null)
		sem_sinal = sem_sinal and not screen.is_focused()
	_check("os três mostram Sem sinal e não aceitam foco", sem_sinal)

	print("== Dentro da mesa e da sala ==")
	var catalog := Profiles.home_catalog()
	var desk_box := _bounds(desk, home)
	var screen_boxes: Array[AABB] = []
	for screen in screens:
		screen_boxes.append(_bounds(screen, home))
	var half: Vector3 = home_script.ROOM_SIZE / 2.0
	_check("a mesa cabe na sala", absf(desk_box.position.x) < half.x and absf(desk_box.end.x) < half.x
			and desk_box.position.z > -half.z)
	var apart := true
	for layout in catalog.layouts:
		for id in layout.placements:
			var piece: Node3D = home.get_furniture(id)
			if piece == null:
				continue
			piece.transform = home.get_anchor_transform(layout.placements[id])
			var box := _bounds(piece, home)
			for screen_box in screen_boxes:
				if box.intersects(screen_box):
					apart = false
					print("  [%s] %s toca um monitor" % [layout.id, id])
	_check("nenhum móvel entra num monitor, nas %d disposições" % catalog.layouts.size(), apart)

	home.queue_free()
	await process_frame
	print("")
	if failures == 0:
		print("RESULTADO: TUDO OK")
	else:
		print("RESULTADO: %d FALHA(S)" % failures)
	quit(1 if failures > 0 else 0)


## A caixa de um nó e dos filhos, em coordenadas da casa.
func _bounds(node: Node3D, home: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var inverse := home.global_transform.affine_inverse()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		stack.append_array(current.get_children())
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var box: AABB = (inverse * (current as MeshInstance3D).global_transform) * (current as MeshInstance3D).mesh.get_aabb()
			result = box if first else result.merge(box)
			first = false
	return result


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok  %s" % label)
	else:
		print("  FALHOU  %s" % label)
		failures += 1
