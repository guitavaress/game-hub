extends SceneTree
## Modelos da cabana (17.9.1b): contrato geométrico, materiais e orçamento.
## Mede os GLB importados de verdade, sem montar a casa nem mudar config.cfg.
## As medidas são de cabin_decor.gd, _add_armchair e _add_fireplace.

const FOLDER: String = "res://assets/models/home/"
const TOLERANCE: float = 0.005
var failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	var chair: Dictionary = _model("armchair", ["wood", "fabric"], 300 * 1024,
			AABB(Vector3(-0.35, 0.0, -0.35), Vector3(0.7, 0.99, 0.7)))
	var fireplace: Dictionary = _model("fireplace", ["stone", "wood", "soot", "iron"], 800 * 1024,
			AABB(Vector3(0.0, 0.0, -1.0), Vector3(1.06, 1.57, 2.0)))
	if chair.has("fabric"):
		var cloth: Mesh = chair["fabric"]
		var seat: Variant = _hit(cloth, Vector3(0, 1.2, -0.08), Vector3(0, 0.1, -0.08))
		_check("assento livre pela frente (-Z), com topo a 49 cm",
				seat != null and absf(seat.y - 0.49) < 0.015)
		var back: Variant = _hit(cloth, Vector3(0, 0.80, -1), Vector3(0, 0.80, 1))
		_check("encosto atrás do assento (+Z), de frente para -Z",
				back != null and back.z > 0.14 and back.z < 0.24)
		var upper: Variant = _hit(cloth, Vector3(0, 1.2, 0.26), Vector3(0, 0.4, 0.26))
		_check("o topo de 99 cm pertence ao encosto, não à frente",
				upper != null and absf(upper.y - 0.99) < 0.015)
	if fireplace.has("stone") and fireplace.has("soot") and fireplace.has("iron"):
		var stone: Mesh = fireplace["stone"]
		var soot: Mesh = fireplace["soot"]
		var opening_clear: bool = true
		# A boca mantém 1 m de largura e 0,87 m de altura acima do degrau.
		# Raios no interior pegam só o fundo, nunca uma tampa de pedra.
		for y: float in [0.38, 0.8, 1.13]:
			for z: float in [-0.47, 0.0, 0.47]:
				var a := Vector3(1.2, y, z)
				var b := Vector3(-0.1, y, z)
				var back: Variant = _hit(soot, a, b)
				opening_clear = opening_clear and _hit(stone, a, b) == null
				opening_clear = opening_clear and back != null and absf(back.x - 0.1) < TOLERANCE
		_check("boca aberta para +X; fundo de fuligem junto da parede X=0", opening_clear)
		var pillar: Variant = _hit(stone, Vector3(1.2, 0.70, 0.70), Vector3(-0.1, 0.70, 0.70))
		_check("pilares avançam 70 cm, ao lado da abertura",
				pillar != null and pillar.x > 0.66 and pillar.x < 0.705)
		var floor_hit: Variant = _hit(soot, Vector3(0.32, 1.0, 0), Vector3(0.32, 0, 0))
		_check("fogo de código em (0,32; 0,32; 0) pousa no piso da boca",
				floor_hit != null and absf(floor_hit.y - 0.32) < TOLERANCE)
		var iron: Mesh = fireplace["iron"]
		_check("grade à frente do fogo (+X), abaixo do alto da boca",
				iron.get_aabb().position.x > 0.60 and iron.get_aabb().end.x < 0.76
				and iron.get_aabb().end.y < 0.68)
		var mantel: Mesh = fireplace["wood"]
		var top: Variant = _hit(mantel, Vector3(0.3, 2, -0.65), Vector3(0.3, 1, -0.65))
		_check("consolo a 1,57 m recebe o lampião e a chaminé de código",
				top != null and absf(top.y - 1.57) < TOLERANCE)
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


func _model(file: String, names: Array[String], budget: int, expected: AABB) -> Dictionary:
	print("\n== %s ==" % file)
	var path: String = FOLDER + file + ".glb"
	var packed: PackedScene = load(path) as PackedScene
	_check("%s.glb carrega" % file, packed != null)
	if packed == null:
		return {}
	var instance: Node3D = packed.instantiate() as Node3D
	var meshes: Dictionary = {}
	var bounds := AABB()
	var first: bool = true
	var valid: bool = true
	for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var mesh: Mesh = mesh_node.mesh
		var key: String = String(node.name)
		var transform: Transform3D = mesh_node.transform
		var parent: Node = mesh_node.get_parent()
		while parent != instance:
			if parent is Node3D:
				transform = (parent as Node3D).transform * transform
			parent = parent.get_parent()
		# O leitor pode extrair a malha sem aplicar transformação oculta.
		_check("%s: vértices no referencial da raiz" % key, transform.is_equal_approx(Transform3D.IDENTITY))
		valid = valid and key in names and not meshes.has(key) and mesh != null
		if mesh == null:
			continue
		meshes[key] = mesh
		valid = valid and mesh.get_surface_count() == 1
		if mesh.get_surface_count() != 1:
			continue
		var material: Material = mesh.surface_get_material(0)
		valid = valid and material != null and material.resource_name == key
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var attributes_ok: bool = vertices.size() > 0 and normals.size() == vertices.size() and colors.size() == vertices.size()
		for v: Vector3 in vertices:
			attributes_ok = attributes_ok and v.is_finite()
		for n: Vector3 in normals:
			attributes_ok = attributes_ok and n.is_finite() and absf(n.length() - 1.0) < 0.02
		_check("%s: geometria finita, normais unitárias e cor/AO por vértice" % key, attributes_ok)
		if key == "wood":
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			_check("Wood049: UV do veio disponível", uv.size() == vertices.size() and uv.size() > 0)
		var box: AABB = transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	_check("uma malha e um material por nome combinado", valid and meshes.size() == names.size())
	_check("raiz sem deslocamento, rotação ou escala", instance.transform.is_equal_approx(Transform3D.IDENTITY))
	_check("AABB preserva pegada, chão e altura (tolerância 5 mm)",
			bounds.position.distance_to(expected.position) < TOLERANCE
			and bounds.size.distance_to(expected.size) < TOLERANCE)
	print("   AABB: origem=%s tamanho=%s" % [bounds.position, bounds.size])
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	var bytes: int = handle.get_length()
	_check("arquivo dentro do orçamento (%d / %d bytes)" % [bytes, budget], bytes <= budget)
	# O GLB é só malha: nenhuma imagem duplicada, câmera, luz ou animação.
	handle.seek(12)
	var json_length: int = handle.get_32()
	var chunk_type: int = handle.get_32()
	var gltf: Dictionary = JSON.parse_string(handle.get_buffer(json_length).get_string_from_utf8())
	_check("texturas compartilhadas, sem imagens/luzes/câmeras/animações embutidas",
			chunk_type == 0x4e4f534a and not gltf.has("images") and not gltf.has("cameras")
			and not gltf.has("animations") and not gltf.get("extensions", {}).has("KHR_lights_punctual"))
	instance.free()
	return meshes


## Primeiro encontro do segmento com os triângulos da malha (sem física).
func _hit(mesh: Mesh, from: Vector3, to: Vector3) -> Variant:
	var faces: PackedVector3Array = mesh.get_faces()
	var result: Variant = null
	var nearest: float = INF
	for i: int in range(0, faces.size(), 3):
		var point: Variant = Geometry3D.segment_intersects_triangle(from, to, faces[i], faces[i + 1], faces[i + 2])
		if point != null:
			var distance: float = from.distance_squared_to(point)
			if distance < nearest:
				nearest = distance
				result = point
	return result


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
