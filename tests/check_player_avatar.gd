extends SceneTree
## Teste do seu corpo em primeira pessoa (Fase 20.3). Guarda o config.cfg e
## devolve no fim.
##   - o rig tem dois corpos: o de primeira pessoa (sem cabeça, sem sombra) e o
##     inteiro (com cabeça), com a sombra numa cópia "só sombra";
##   - a câmera do jogador vê o de primeira pessoa e a sombra do inteiro, mas
##     não o inteiro; a do espelho vê o inteiro e não o de primeira pessoa; a da
##     janela não vê nenhum;
##   - as camadas trocam ao entrar e ao sair de casa; o sol do mundo não acende
##     o corpo em casa, e as luzes da casa acendem;
##   - o corpo anda (e corre) quando o jogador anda, e para quando ele para;
##   - na viagem e na abertura, o de primeira pessoa some e volta;
##   - o provador põe o inteiro no lugar, visto pela câmera, e o devolve;
##   - a terceira pessoa (o jogador manda no set_view, 20.4) mostra o inteiro;
##   - trocar as cores no config.cfg pinta os dois corpos.

const CONFIG := "user://config.cfg"
const INSIDE := 1 << 15    # AvatarBody.INDOOR_VIEW_LAYER (16)
const OUTSIDE := 1 << 16   # AvatarBody.VIEW_LAYER (17)
const REFLECTION := 1 << 18
const INTERIOR := 1 << 19

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app = root.get_node("AppConfig")
	var backup := FileAccess.get_file_as_string(CONFIG)
	for setter in ["set_home_theme", "set_home_layout", "set_home_wall_color", "set_home_neon_color"]:
		app.call(setter, "")
	app.set_view("first")
	load("res://tests/quiet_friends.gd").install(root)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await create_timer(1.0).timeout
	root.get_node("GameLauncher")._poll_timer.paused = true
	var player = city.get_node("Player")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var home = city.get_home()
	var mirror = home.get_furniture("espelho")
	var avatar = player.get_avatar()
	var first = avatar.get_first_person_body()
	var full = avatar.get_full_body()

	print("== os dois corpos ==")
	_check("o jogador tem o corpo (filho dele)", avatar != null and avatar.get_parent() == player)
	_check("o de primeira pessoa está sem cabeça; o inteiro, com", first.is_head_hidden() and not full.is_head_hidden())
	_check("o de primeira pessoa não faz sombra", _all_cast(first.get_meshes(), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	_check("a sombra é do inteiro, numa cópia só sombra", not full.get_shadow_twins().is_empty()
			and _all_cast(full.get_shadow_twins(), GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
			and full.get_shadow_twins().all(func(t: MeshInstance3D) -> bool: return t.visible))
	_check("o corpo fica um pouco atrás da câmera (%.2f m)" % avatar.FIRST_PERSON_BACK,
			first.position.is_equal_approx(Vector3(0.0, 0.0, avatar.FIRST_PERSON_BACK))
			and full.position.is_equal_approx(first.position))
	var forward: Vector3 = -player.global_basis.z
	_check("os dois olham para onde o jogador olha", first.global_basis.z.normalized().dot(forward) > 0.999
			and full.global_basis.z.normalized().dot(forward) > 0.999)

	print("== na rua ==")
	player.set_indoors(null)
	await _frames(2)
	_check("a câmera do jogador vê o de primeira pessoa", _layers(first) & camera.cull_mask != 0)
	_check("e não vê o inteiro", _layers(full) & camera.cull_mask == 0)
	_check("mas vê a sombra dele (a Godot só faz sombra do que a câmera vê)",
			full.get_shadow_twin_layers() & camera.cull_mask != 0)
	_check("de primeira pessoa e sombra na camada de fora (17)", _layers(first) == OUTSIDE and full.get_shadow_twin_layers() == OUTSIDE)
	_check("o inteiro na camada do reflexo", _layers(full) == REFLECTION)
	var sky_masks := _sky_masks(city)
	_check("o sol (e a lua) do mundo acendem o corpo na rua", not sky_masks.is_empty()
			and sky_masks.all(func(mask: int) -> bool: return mask & OUTSIDE != 0))
	_check("a câmera do espelho não vê o de primeira pessoa nem a sombra",
			mirror.get_mirror_camera().cull_mask & (INSIDE | OUTSIDE) == 0)
	var window_hidden: int = home.get_window_view().hidden_layers
	_check("a janela da casa não retrata nenhum corpo", window_hidden & (INSIDE | OUTSIDE | REFLECTION) == INSIDE | OUTSIDE | REFLECTION)

	print("== andar ==")
	var animation: AnimationPlayer = first.get_animation_player()
	_check("parado: Idle", animation.current_animation == AvatarBody.IDLE_ANIMATION)
	Input.action_press("move_forward")
	await create_timer(0.8).timeout
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	_check("andando (%.1f m/s): o corpo anda" % speed, speed > 3.0 and animation.current_animation != AvatarBody.IDLE_ANIMATION
			and animation.speed_scale > 1.0)
	_check("o inteiro anda junto", full.get_animation_player().current_animation == animation.current_animation)
	Input.action_release("move_forward")
	await create_timer(1.0).timeout
	_check("parou: Idle de novo", animation.current_animation == AvatarBody.IDLE_ANIMATION
			and is_equal_approx(animation.speed_scale, 1.0))

	print("== em casa ==")
	player.teleport_to(home.get_spawn_transform())
	player.set_indoors(home.get_environment())
	await _frames(3)
	_check("em casa", player.is_indoors() and avatar.is_indoors())
	_check("de primeira pessoa e sombra na camada de dentro (16)", _layers(first) == INSIDE and full.get_shadow_twin_layers() == INSIDE)
	_check("a câmera do jogador vê o de primeira pessoa e não o inteiro",
			_layers(first) & camera.cull_mask != 0 and _layers(full) & camera.cull_mask == 0)
	_check("a câmera do espelho vê o inteiro e não o de primeira pessoa",
			_layers(full) & mirror.get_mirror_camera().cull_mask != 0 and _layers(first) & mirror.get_mirror_camera().cull_mask == 0)
	_check("o sol do mundo não acende o corpo em casa",
			sky_masks.all(func(mask: int) -> bool: return mask & (INSIDE | REFLECTION | INTERIOR) == 0))
	var sunlight: Light3D = home.get_sunlight()
	_check("o sol da janela acende o corpo em casa", sunlight.light_cull_mask & (INSIDE | REFLECTION) == INSIDE | REFLECTION)
	var lamps_ok := true
	for lamp: Light3D in home.get_lamps():
		lamps_ok = lamps_ok and lamp.light_cull_mask & (INSIDE | REFLECTION) == INSIDE | REFLECTION
	_check("as luminárias acendem o corpo em casa", lamps_ok and not home.get_lamps().is_empty())
	player.set_indoors(null)
	await _frames(2)
	_check("ao sair, volta à camada de fora", _layers(first) == OUTSIDE and full.get_shadow_twin_layers() == OUTSIDE)
	player.set_indoors(home.get_environment())
	await _frames(2)

	print("== provador ==")
	_stand_in_front(player, home, mirror, 1.6)
	await _frames(4)
	player.focus_on(mirror)
	await create_timer(0.6).timeout
	var spot: Vector3 = mirror.to_global(Vector3(0.0, 0.0, mirror.FITTING_SPOT))
	_check("o foco no espelho pede a pose", player.is_focused() and avatar.is_posed())
	_check("o inteiro está no lugar, de frente para o vidro", full.global_position.distance_to(spot) < 0.01
			and full.global_basis.z.normalized().dot(-mirror.get_normal()) > 0.999)
	_check("e a câmera do jogador o vê, com sombra", _layers(full) & camera.cull_mask != 0
			and _all_cast(full.get_meshes(), GeometryInstance3D.SHADOW_CASTING_SETTING_ON) and full.get_shadow_twin_layers() == 0)
	_check("o de primeira pessoa some", not first.visible)
	player.leave_focus(true)
	await _settle()
	_check("ao sair, o inteiro volta para o jogador", not avatar.is_posed()
			and full.global_position.distance_to(player.to_global(Vector3(0.0, 0.0, avatar.FIRST_PERSON_BACK))) < 0.01)
	_check("e some da câmera do jogador de novo", _layers(full) & camera.cull_mask == 0 and first.visible)

	print("== viagem e abertura ==")
	var there := Transform3D(player.global_basis, player.global_position + player.global_basis.x * 0.5)
	player.travel_to(there, "", 0.1, 0.05)
	await _settle()
	_check("na viagem, o de primeira pessoa some", not first.visible)
	await create_timer(0.6).timeout
	_check("depois da viagem, volta", first.visible and not player.is_traveling())
	player.start_intro()
	await _settle()
	_check("na abertura, some", not first.visible)
	player.finish_intro()
	await _settle()
	_check("depois da abertura, volta", first.visible)

	print("== a visão (a terceira pessoa da 20.4 chama o set_view) ==")
	player.toggle_view()
	await create_timer(0.6).timeout
	await _frames(1)
	_check("o jogador passou o corpo para a terceira pessoa", avatar.get_view() == "third")
	_check("terceira pessoa: o de primeira pessoa some", not first.visible)
	_check("e a câmera do jogador vê o inteiro, que faz a própria sombra", _layers(full) & camera.cull_mask != 0
			and _all_cast(full.get_meshes(), GeometryInstance3D.SHADOW_CASTING_SETTING_ON) and full.get_shadow_twin_layers() == 0)
	_check("em casa, o espelho também o vê", _layers(full) & mirror.get_mirror_camera().cull_mask != 0)
	_check("o inteiro fica no meio do jogador (sem o recuo)", full.position.is_equal_approx(Vector3.ZERO))
	# 20.3.1: escondido (viagem, foco), a terceira pessoa também tira o inteiro
	# da câmera; a sombra fica na cópia. E o provador o mostra mesmo escondido.
	var near := Transform3D(player.global_basis, player.global_position + player.global_basis.x * 0.3)
	player.travel_to(near, "", 0.1, 0.05)
	await _settle()
	_check("terceira pessoa + viagem: o inteiro sai da câmera, a sombra fica", avatar.is_hidden()
			and _layers(full) & camera.cull_mask == 0 and full.get_shadow_twin_layers() == INSIDE)
	await create_timer(0.6).timeout
	_check("depois da viagem, o inteiro volta para a câmera", not avatar.is_hidden()
			and _layers(full) & camera.cull_mask != 0 and full.get_shadow_twin_layers() == 0)
	_stand_in_front(player, home, mirror, 1.6)
	await _frames(4)
	player.focus_on(mirror)
	await create_timer(0.6).timeout
	_check("terceira pessoa + provador (escondido): o inteiro posado, visto e com sombra",
			avatar.is_hidden() and avatar.is_posed() and _layers(full) & camera.cull_mask != 0
			and _all_cast(full.get_meshes(), GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
	_check("no provador, o inteiro está parado (Idle)",
			full.get_animation_player().current_animation == AvatarBody.IDLE_ANIMATION)
	player.leave_focus(true)
	await _settle()
	_check("saindo do provador na terceira pessoa, o inteiro segue visto", not avatar.is_posed()
			and _layers(full) & camera.cull_mask != 0)
	avatar.set_view("lado")
	_check("visão inválida é ignorada", avatar.get_view() == "third")
	player.toggle_view()
	await create_timer(0.6).timeout
	await _frames(1)
	_check("de volta à primeira pessoa", first.visible and _layers(full) & camera.cull_mask == 0
			and full.get_shadow_twin_layers() == INSIDE)

	print("== andar de ré (20.4) ==")
	avatar.animate(5.0, true, true)
	_check("de ré, o passo dos dois toca ao contrário", full.get_animation_player().speed_scale < 0.0
			and first.get_animation_player().speed_scale < 0.0)
	avatar.animate(5.0, true, false)
	_check("para a frente, normal", full.get_animation_player().speed_scale > 0.0)
	avatar.animate(0.0, true, true)
	_check("parado, de ré não muda nada (Idle a 1,0)", is_equal_approx(full.get_animation_player().speed_scale, 1.0))
	await _frames(2)

	print("== cores ==")
	var data: Dictionary = app.get_avatar().duplicate(true)
	data["colors"] = (data.get("colors", {}) as Dictionary).duplicate()
	data["colors"]["shirt"] = "#c0392b"
	app.set_avatar(data)
	await _frames(1)
	_check("os dois corpos trocam de camiseta na hora",
			(first.get_palette().get_shader_parameter("shirt_color") as Color).to_html(false) == "c0392b"
			and (full.get_palette().get_shader_parameter("shirt_color") as Color).to_html(false) == "c0392b")

	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string(backup)
	file.close()
	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


## As camadas das malhas desenhadas de um corpo (-1 se forem diferentes).
func _layers(body: Node) -> int:
	var layers := -1
	for mesh: MeshInstance3D in body.get_meshes():
		layers = mesh.layers if layers == -1 or layers == mesh.layers else -2
	return layers if layers >= 0 else -1


func _all_cast(meshes: Array, setting: int) -> bool:
	return not meshes.is_empty() and meshes.all(func(m: MeshInstance3D) -> bool: return m.cast_shadow == setting)


## As máscaras de luz do céu (o sol e a lua: os DirectionalLight3D da cidade).
func _sky_masks(city: Node) -> Array[int]:
	var masks: Array[int] = []
	for node in city.find_children("*", "DirectionalLight3D", true, false):
		masks.append((node as DirectionalLight3D).light_cull_mask)
	return masks


## O jogador a "meters" do vidro, olhando para ele.
func _stand_in_front(player: Node3D, home: Node3D, mirror: Node3D, meters: float) -> void:
	var normal: Vector3 = mirror.get_normal()
	var feet: Vector3 = mirror.global_position + normal * meters
	feet.y = home.global_position.y + 0.1
	player.teleport_to(Transform3D(Basis.looking_at(-normal), feet))
	player.get_node("Head").rotation.x = 0.0


## Espera o _process do jogador rodar (sem janela, vários quadros de física
## cabem numa volta só, e o _process ainda não rodou).
func _settle() -> void:
	for i in 3:
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
