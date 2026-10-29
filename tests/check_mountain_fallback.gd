extends SceneTree
## Teste da cidade grande demais para a montanha (Fase 15.9.3). Com 1000 jogos
## falsos, a borda da cidade fica a ~328 m do centro, e a montanha (raio de
## fora de 370 m) não cabe. A cidade monta inteira, sem erro e sem montanha:
##   - nenhum terreno nem trilha (grupo "mountain_trail");
##   - a mureta sem vão (4 trechos de barreira, um por lado);
##   - nenhuma zona do RPG fora da mureta e nenhum marco da trilha no mapa;
##   - o clima do RPG continua valendo nos quarteirões dele.
## (Com 600 falsos a montanha ainda cabe: a borda fica a 252 m.)
var failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	load("res://tests/quiet_friends.gd").install(root)
	load("res://tests/fake_library.gd").install(root, 1000, false, true)
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false
	var started := Time.get_ticks_msec()
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	var bounds: Rect2 = city._map.get_map_data()["bounds"]
	var half := bounds.size.x / 2.0
	print("cidade montada em %d ms; borda a %.0f m" % [Time.get_ticks_msec() - started, half])

	print("\n== sem montanha ==")
	var spec: TerrainSpec = Profiles.district("rpg").biome.backdrop
	_check("a cidade é grande demais para a montanha", spec.outer_radius - half < Heightfield.MIN_ROOM)
	_check("nenhuma trilha", get_nodes_in_group("mountain_trail").is_empty())
	_check("nenhum terreno", city.get_node_or_null("BackdropTerrain_rpg") == null)
	var barriers := 0
	for child: Node in city.get_children():
		if String(child.name).begins_with("Barrier"):
			barriers += 1
	_check("a mureta fica inteira (4 barreiras)", barriers == 4)
	var outside := 0
	for zone: Rect2 in city._map.zone_rects("rpg"):
		if not bounds.encloses(zone):
			outside += 1
	_check("o RPG não tem zona fora da mureta", not city._map.zone_rects("rpg").is_empty() and outside == 0)
	var trails: Array = city._map.get_map_data()["landmarks"].filter(
			func(l: Dictionary) -> bool: return l["kind"] == "trilha")
	_check("o mapa não tem marco da trilha", trails.is_empty())
	_check("o clima do RPG continua na cidade", city.get_node_or_null("DistrictWeather_rpg") != null)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
