extends "res://tools/capturar_pontos.gd"
## Confere o contrato do mirante e horas sucessivas sem montar a cidade nem abrir janela.

class FakeTrail extends Node3D:
	func trail_world_points() -> PackedVector3Array:
		return PackedVector3Array([Vector3.ZERO, lookout_world()])

	func lookout_world() -> Vector3:
		return Vector3(30.0, 42.0, -70.0)


class FakeClock extends Node:
	var hour_offset: float = 5.0
	var updates: int = 0

	func current_hour() -> float:
		return fposmod(8.0 + hour_offset, 24.0)

	func update_now() -> void:
		updates += 1


var failures: int = 0


func _initialize() -> void:
	_check_points.call_deferred()


func _check_points() -> void:
	var rects: Array[Rect2] = [Rect2(-10.0, -50.0, 20.0, 20.0)]
	var area: Dictionary = {"rects": rects, "gate": Vector2.INF}
	var original: Array[Dictionary] = _points(area)
	_check("sem montanha, o mirante não entra", original.size() == 2)
	var trail: Node3D = FakeTrail.new()
	root.add_child(trail)
	trail.add_to_group(&"mountain_trail")
	var points: Array[Dictionary] = _points(area)
	_check("com o contrato, entra só mais um ponto", points.size() == original.size() + 1)
	var lookout: Dictionary = points.back()
	_check("o ponto se chama mirante", lookout["name"] == "mirante")
	_check("o olho fica EYE_HEIGHT acima do piso no mundo",
		Vector3(lookout["eye"]).is_equal_approx(trail.call("lookout_world") + Vector3.UP * EYE_HEIGHT))
	_check("a vista aponta para a praça acima do chão", lookout["target"] == Vector3(0.0, EYE_HEIGHT, 0.0))
	trail.free()
	_check("ao remover a montanha, o ponto deixa de entrar", _points(area).size() == original.size())

	var clock: Node = FakeClock.new()
	for hour: float in [13.0, 22.0, 0.0, 24.0, 13.0]:
		_set_hour(clock, hour)
		_check("hora pedida %.0f sem acumular o deslocamento anterior" % hour,
			is_equal_approx(float(clock.call("current_hour")), fposmod(hour, 24.0)))
	_check("cada troca atualiza a iluminação", clock.get("updates") == 5)
	clock.free()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
