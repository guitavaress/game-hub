extends RefCounted
## Ajudante do retrato da casa (Fase 13.1): descreve a casa montada como uma
## lista de linhas de texto, uma por peça, material, luz e o ambiente. Usado
## por tools/retrato_casa.gd (que grava o retrato) e pelo tests/check_home_profile.gd
## (que compara a casa nova com ele).
##
## A descrição usa a posição no mundo (relativa à casa) e não o caminho do nó,
## porque as peças mudam de pai quando a casa passa a ler o perfil. A lista sai
## ordenada: a ordem de criação não importa.
##
## Ficam de fora os móveis que dependem da biblioteca ou dos amigos (estante e
## mural) e a mesa do computador (tem teste próprio, check_computer_desk): não fazem parte do tema.

const SKIP_NODES: Array[String] = ["LibraryShelf", "ComputerDesk", "SystemPanel", "FriendsWall", "StatsWall", "HomeMirror"]


static func capture(home: Node3D) -> Array[String]:
	var lines: Array[String] = []
	_walk(home, home, lines)
	var env: Environment = home.get_environment()
	lines.append("ENV|%s" % _env(env))
	lines.sort()
	return lines


static func _walk(node: Node, home: Node3D, lines: Array[String]) -> void:
	for child in node.get_children():
		if SKIP_NODES.has(child.name):
			continue
		if child is Node3D and not (child is CollisionShape3D):
			lines.append(_describe(child as Node3D, home))
		elif child is CollisionShape3D:
			lines.append("COL|%s|%s" % [_pos(home, child as Node3D), _shape((child as CollisionShape3D).shape)])
		_walk(child, home, lines)


static func _describe(node: Node3D, home: Node3D) -> String:
	# Nome repetido vira "@Classe@N" (o N muda com a ordem de criação): fica só "auto".
	var node_name := "auto" if String(node.name).begins_with("@") else String(node.name)
	var text := "%s|%s|%s" % [node.get_class(), node_name, _pos(home, node)]
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		text += "|rot=%s|layers=%d|mesh=%s|mat=%s" % [_vec(node.global_basis.get_euler()), mesh_node.layers,
				_mesh(mesh_node.mesh), _material(mesh_node.material_override)]
	elif node is Light3D:
		var light := node as Light3D
		text += "|cor=%s|energia=%s" % [light.light_color.to_html(true), _num(light.light_energy)]
		if node is OmniLight3D:
			text += "|alcance=%s" % _num((node as OmniLight3D).omni_range)
		elif node is SpotLight3D:
			text += "|alcance=%s|angulo=%s" % [_num((node as SpotLight3D).spot_range), _num((node as SpotLight3D).spot_angle)]
	return text


static func _pos(home: Node3D, node: Node3D) -> String:
	return _vec(home.to_local(node.global_position))


static func _vec(v: Vector3) -> String:
	return "(%s,%s,%s)" % [_num(v.x), _num(v.y), _num(v.z)]


static func _num(x: float) -> String:
	var text := "%.3f" % x
	return "0.000" if text == "-0.000" else text


static func _mesh(mesh: Mesh) -> String:
	if mesh is BoxMesh:
		return "Box%s" % _vec((mesh as BoxMesh).size)
	if mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		return "Cil(%s,%s,%s,%s,%s)" % [_num(c.top_radius), _num(c.bottom_radius), _num(c.height), c.cap_top, c.cap_bottom]
	if mesh is SphereMesh:
		return "Esfera(%s,%s)" % [_num((mesh as SphereMesh).radius), _num((mesh as SphereMesh).height)]
	if mesh is PlaneMesh:
		return "Plano(%s)" % _num((mesh as PlaneMesh).size.x * 1000.0 + (mesh as PlaneMesh).size.y)
	if mesh is QuadMesh:
		return "Quad(%s,%s)" % [_num((mesh as QuadMesh).size.x), _num((mesh as QuadMesh).size.y)]
	return mesh.get_class() if mesh != null else "-"


static func _shape(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		return "Box%s" % _vec((shape as BoxShape3D).size)
	return shape.get_class() if shape != null else "-"


static func _material(material: Material) -> String:
	if material == null:
		return "-"
	if material is StandardMaterial3D:
		var m := material as StandardMaterial3D
		var text := "Std(%s,met=%s,asp=%s" % [m.albedo_color.to_html(true), _num(m.metallic), _num(m.roughness)]
		if m.albedo_texture != null:
			text += ",tex=%s,escala=%s" % [m.albedo_texture.resource_path, _vec(m.uv1_scale)]
		if m.emission_enabled:
			text += ",brilho=%s*%s" % [m.emission.to_html(true), _num(m.emission_energy_multiplier)]
		if m.cull_mode != BaseMaterial3D.CULL_BACK:
			text += ",cull=%d" % m.cull_mode
		return text + ")"
	if material is ShaderMaterial:
		var s := material as ShaderMaterial
		var params: Array[String] = []
		for param in s.shader.get_shader_uniform_list():
			var value: Variant = s.get_shader_parameter(param["name"])
			if value != null and not (value is Texture):
				params.append("%s=%s" % [param["name"], str(value)])
		params.sort()
		return "Shader(%s;%s)" % [s.shader.resource_path, ";".join(params)]
	return material.get_class()


static func _env(env: Environment) -> String:
	var keys: Array[String] = []
	for key in ["background_mode", "background_color", "ambient_light_source", "ambient_light_color",
			"ambient_light_energy", "reflected_light_source", "tonemap_mode", "glow_enabled",
			"glow_hdr_threshold", "ssao_enabled", "volumetric_fog_enabled"]:
		keys.append("%s=%s" % [key, str(env.get(key))])
	return ";".join(keys)
