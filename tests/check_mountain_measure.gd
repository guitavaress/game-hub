extends "res://tools/medir_desempenho.gd"
## Exercita a subida e o giro pelo contrato, mesmo antes da montanha ser integrada.

class FakeTrail extends Node3D:
	func trail_world_points() -> PackedVector3Array:
		# Inclui dois pontos iguais: não pode travar na emenda de dois trechos.
		return PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 1.0, -2.0)])

	func lookout_world() -> Vector3:
		return Vector3(0.0, 2.0, -4.0)


class FakePlayer extends Node3D:
	var outdoors: bool = false
	var visited_slope: bool = false
	var teleports: int = 0

	func set_indoors(environment: Environment) -> void:
		outdoors = environment == null

	func teleport_to(target: Transform3D) -> void:
		global_transform = target
		teleports += 1
		if target.origin.y > 0.1 and target.origin.y < 2.0:
			visited_slope = true


var failures: int = 0


func _run() -> void:
	await process_frame
	var city: Node3D = Node3D.new()
	root.add_child(city)
	var player: Node3D = FakePlayer.new()
	city.add_child(player)
	# Sem grupo, termina sem mover o jogador nem medir uma subida inexistente.
	await _measure_mountain(city, player, 7, "leve", 22.0, 0)
	_check("sem montanha, não move o jogador", player.get("teleports") == 0)
	var trail: Node3D = FakeTrail.new()
	city.add_child(trail)
	trail.add_to_group(&"mountain_trail")
	var started: int = Time.get_ticks_msec()
	await _measure_mountain(city, player, 7, "leve", 22.0, 0)
	_check("a subida devolve o ambiente externo", player.get("outdoors"))
	_check("percorre posições intermediárias na subida", player.get("visited_slope"))
	_check("termina no piso do mirante com folga de 0,1 m",
		player.global_position.is_equal_approx(Vector3(0.0, 2.1, -4.0)))
	_check("o giro dura pelo menos três segundos", Time.get_ticks_msec() - started >= 3000)
	_check("a volta completa retorna à direção final da trilha",
		(-player.global_basis.z).is_equal_approx(Vector3.FORWARD))
	city.free()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
