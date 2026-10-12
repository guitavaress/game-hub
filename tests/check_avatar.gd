extends SceneTree
## Teste do avatar como dado e corpo (Fase 13.6):
##   - AvatarSpec: to_dict -> from_dict devolve o mesmo, e dado ruim não quebra;
##   - a seção [avatar] do config.cfg grava e lê o mesmo;
##   - AvatarBody: ~1,7 m, olhando para +Z, Idle e Walk em loop;
##   - cada parte (faixa do UV) é a parte certa do corpo e recebe a cor certa;
##   - FriendNpc com e sem avatar.
## Guarda o config.cfg antes e devolve no fim (arquivo e memória do AppConfig).

const CONFIG := "user://config.cfg"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_check_spec()
	_check_config()
	await _check_body()
	_check_zones()
	await _check_friend_npc()

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _sample_spec() -> AvatarSpec:
	var spec := AvatarSpec.new()
	spec.set_color("skin", Color("8d5524"))
	spec.set_color("eyes", Color("1a3c6e"))
	spec.set_color("hair", Color("d4a017"))
	spec.set_color("shirt", Color("c0392b"))
	spec.set_color("pants", Color("27ae60"))
	return spec


func _check_spec() -> void:
	print("== AvatarSpec ==")
	var spec := _sample_spec()
	var data := spec.to_dict()
	print("   ", data)
	_check("formato: version 1, body human e as 5 cores", data["version"] == 1 and data["body"] == "human"
			and data["colors"].keys() == ["skin", "eyes", "hair", "shirt", "pants"])
	_check("cor como \"#rrggbb\"", data["colors"]["skin"] == "#8d5524")
	var back := AvatarSpec.from_dict(data)
	_check("to_dict -> from_dict devolve o mesmo", back.to_dict() == data)
	_check("passa também por JSON (como na rede)",
			AvatarSpec.from_dict(JSON.parse_string(JSON.stringify(data))).to_dict() == data)

	var messy := AvatarSpec.from_dict({"body": "dragao", "colors": {"skin": "azul", "hair": "#ABCDEF", "asa": "#ffffff"}})
	var defaults := AvatarSpec.new()
	_check("corpo desconhecido vira human", messy.body == "human")
	_check("cor inválida fica a padrão", messy.skin_color == defaults.skin_color)
	_check("cor em maiúsculas é aceita", messy.to_dict()["colors"]["hair"] == "#abcdef")
	_check("parte que falta fica a padrão", messy.pants_color == defaults.pants_color)
	_check("dicionário vazio = o avatar padrão", AvatarSpec.from_dict({}).to_dict() == defaults.to_dict())


func _check_config() -> void:
	print("== seção [avatar] do config.cfg ==")
	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	var original: Dictionary = app.get_avatar()
	print("   antes: ", original)
	_check("a seção [avatar] está no arquivo", "[avatar]" in backup)

	var spec := _sample_spec()
	var signals: Array[String] = []
	var on_changed := func(section: String, key: String) -> void: signals.append(section + "/" + key)
	app.settings_changed.connect(on_changed)
	app.set_avatar(spec.to_dict())
	app.settings_changed.disconnect(on_changed)
	_check("avisa uma vez só (avatar/colors)", signals == ["avatar/colors"])
	var text := FileAccess.get_file_as_string(CONFIG)
	_check("uma cor por linha no arquivo", 'skin="#8d5524"' in text and 'pants="#27ae60"' in text and 'body="human"' in text)
	_check("ler da memória devolve o mesmo", AvatarSpec.from_dict(app.get_avatar()).to_dict() == spec.to_dict())

	# Um AppConfig novo, lendo só o arquivo (como ao abrir o hub de novo).
	var fresh = load("res://autoload/app_config.gd").new()
	fresh._config.load(CONFIG)
	_check("ler do arquivo devolve o mesmo", AvatarSpec.from_dict(fresh.get_avatar()).to_dict() == spec.to_dict())
	fresh.free()

	# Devolve a memória (pelos setters) e o arquivo.
	app.set_avatar(original)
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	_check("memória do AppConfig restaurada", app.get_avatar() == original)
	_check("config.cfg restaurado", FileAccess.get_file_as_string(CONFIG) == backup)


func _check_body() -> void:
	print("== AvatarBody ==")
	# Um pai girado e fora da origem, para provar que o ajuste é relativo a ele.
	var holder := Node3D.new()
	holder.position = Vector3(3.0, 0.5, -2.0)
	holder.rotation.y = 0.7
	root.add_child(holder)
	var body := AvatarBody.new()
	body.spec = _sample_spec()
	holder.add_child(body)
	await process_frame

	var skeleton := body.get_skeleton()
	var top := _bone(skeleton, "HeadTop_End")
	var height := top.y - body.global_position.y
	print("   altura %.3f m" % height)
	_check("~1,7 m de altura", absf(height - 1.7) < 0.08)
	var forward := (_bone(skeleton, "LeftArm") - _bone(skeleton, "RightArm")).cross(Vector3.UP).normalized()
	_check("olhando para +Z do pai", forward.dot(holder.global_basis.z.normalized()) > 0.95)

	var player := body.get_animation_player()
	body.play_idle(0.5)
	_check("Idle em loop", player.current_animation == AvatarBody.IDLE_ANIMATION
			and player.get_animation(player.current_animation).loop_mode == Animation.LOOP_LINEAR)
	body.play_walk()
	_check("Walk em loop", player.current_animation == AvatarBody.WALK_ANIMATION
			and player.get_animation(player.current_animation).loop_mode == Animation.LOOP_LINEAR)

	var meshes := body.find_children("*", "MeshInstance3D", true, false)
	var palette := body.get_palette()
	_check("a malha usa a paleta", meshes.all(func(m: MeshInstance3D) -> bool: return m.material_override == palette))
	for zone in AvatarSpec.ZONES:
		var shown: Color = palette.get_shader_parameter(zone + "_color")
		_check("%s recebe a cor do spec" % zone, shown.is_equal_approx(body.spec.get_color(zone)))
	var limits: Vector4 = palette.get_shader_parameter("zone_limits")
	_check("o shader usa os limites do AvatarBody", is_equal_approx(limits.x, AvatarBody.ZONE_LIMITS[0])
			and is_equal_approx(limits.w, AvatarBody.ZONE_LIMITS[3]))

	var other := AvatarSpec.new()
	other.shirt_color = Color("ffcc00")
	body.apply_spec(other)
	_check("trocar as cores na hora", Color(palette.get_shader_parameter("shirt_color")).is_equal_approx(Color("ffcc00")))

	_check("REFLECTION_LAYER = 19", AvatarBody.REFLECTION_LAYER == 19 and AvatarBody.reflection_layers() == 1 << 18)
	body.set_render_layers(AvatarBody.reflection_layers())
	_check("corpo só na camada do reflexo", meshes.all(func(m: MeshInstance3D) -> bool: return m.layers == 1 << 18))
	holder.queue_free()


## Cada faixa do UV é a parte do corpo do nome: confere pelos ossos dos vértices.
func _check_zones() -> void:
	print("== as 5 partes do modelo ==")
	var model: Node = AvatarBody.BODY_SCENES["human"].instantiate()
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var arrays := mesh.mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var bone_step := bones.size() / uv.size()  # 4 ou 8 ossos por vértice
	var counts: Array[Dictionary] = []
	var height_sum: Array[float] = []
	var total: Array[int] = []
	for i in AvatarSpec.ZONES.size():
		counts.append({})
		height_sum.append(0.0)
		total.append(0)
	for i in uv.size():
		var zone := AvatarBody.zone_index(uv[i].y)
		var bone_name := skeleton.get_bone_name(bones[i * bone_step])
		counts[zone][bone_name] = int(counts[zone].get(bone_name, 0)) + 1
		height_sum[zone] += vertices[i].y
		total[zone] += 1
	model.free()

	_check("as 5 partes têm vértices %s" % str(total), total.all(func(n: int) -> bool: return n > 0))
	var skin: Dictionary = counts[0]
	_check("pele: cabeça, mãos e pés", skin.has("Head") and skin.has("LeftHand") and skin.has("RightToeBase"))
	_check("olhos: só na cabeça", counts[1].keys() == ["Head"])
	_check("cabelo: só na cabeça", counts[2].keys() == ["Head"])
	_check("cabelo fica acima dos olhos", height_sum[2] / total[2] > height_sum[1] / total[1])
	_check("camiseta: tronco e ombros", _share(counts[3], ["Spine", "Hips", "Shoulder", "Arm"]) > 0.9)
	_check("calça: pernas", _share(counts[4], ["UpLeg", "Leg", "Hips", "Foot"]) > 0.9)
	_check("a camiseta não tem perna nem cabeça", _share(counts[3], ["Head", "Leg"]) < 0.1)


## Quanto dos vértices tem um osso cujo nome contém alguma das palavras.
func _share(count: Dictionary, words: Array) -> float:
	var hit := 0
	var all := 0
	for bone_name: String in count:
		all += count[bone_name]
		if words.any(func(w: String) -> bool: return w in bone_name):
			hit += count[bone_name]
	return float(hit) / maxf(all, 1)


func _check_friend_npc() -> void:
	print("== FriendNpc ==")
	var npc_script = load("res://components/friend_npc/friend_npc.gd")
	var plain = npc_script.new()
	plain.friend = _fake_friend("76561190000000003", "Bia")
	root.add_child(plain)
	var colored = npc_script.new()
	colored.friend = _fake_friend("76561190000000004", "Davi")
	colored.avatar = _sample_spec()
	colored.position = Vector3(3.0, 0.0, 0.0)
	root.add_child(colored)
	await process_frame

	var plain_mesh: MeshInstance3D = plain._body.find_children("*", "MeshInstance3D", true, false)[0]
	_check("sem avatar: só o holograma, sem sombra",
			(plain_mesh.material_override as ShaderMaterial).shader == npc_script.HOLOGRAM_SHADER
			and plain_mesh.material_overlay == null
			and plain_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var colored_mesh: MeshInstance3D = colored._body.find_children("*", "MeshInstance3D", true, false)[0]
	_check("com avatar: as cores com o holograma por cima",
			colored_mesh.material_override == colored._body.get_palette()
			and (colored_mesh.material_overlay as ShaderMaterial).shader == npc_script.HOLOGRAM_SHADER)
	_check("com avatar: a cor do amigo", Color(colored._body.get_palette().get_shader_parameter("hair_color"))
			.is_equal_approx(Color("d4a017")))
	var top: Vector3 = _bone(plain._skeleton, "HeadTop_End")
	_check("o holograma continua com ~1,7 m", absf(top.y - plain._figure.global_position.y - 1.7) < 0.08)
	plain.queue_free()
	colored.queue_free()
	await process_frame


func _fake_friend(steam_id: String, friend_name: String) -> SteamFriend:
	var friend := SteamFriend.new()
	friend.steam_id = steam_id
	friend.name = friend_name
	friend.status = SteamFriend.Status.ONLINE
	return friend


func _bone(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone(bone_name))).origin


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
