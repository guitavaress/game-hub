extends RefCounted
## Captura só dados estáveis; nenhuma capa ou informação da biblioteca real.

static func capture(city: Node) -> Dictionary:
	var map: Node = city.get_node("CityMap")
	var data: Dictionary = map.get_map_data()
	var districts: Dictionary = {}
	var index: int = 0
	for area: Dictionary in data["areas"]:
		var id: String = area["id"]
		var cells: Array = []
		for cell: Vector2i in city._district_cells[id]:
			cells.append([cell.x, cell.y])
		var stations: Array = []
		for stop: Node in city.get_tree().get_nodes_in_group("transit_stop"):
			if city.is_ancestor_of(stop) and stop.order >= (index + 1) * 10 and stop.order < (index + 2) * 10:
				stations.append({"name": stop.stop_name, "transform": pose(stop)})
		districts[id] = {"blocks": cells, "games": area["games"],
			"gate": pose(city.get_node("DistrictGate_" + id)),
			"sign": pose(city.get_node("DistrictSign_" + id)), "stations": stations}
		index += 1
	var games: Dictionary = {}
	for child: Node in city.get_children():
		if not String(child.name).begins_with("Building_"):
			continue
		var wall: Texture2D = child._walls_material.get_shader_parameter("wall_albedo")
		games[str(child.game.app_id)] = {"district": child.category_id,
			"shell": child.get_script().resource_path, "floors": child.variant.floors,
			"wall": wall.resource_path, "transform": pose(child)}
	return {"half": (data["bounds"] as Rect2).size.x / 2.0, "districts": districts, "games": games}


static func pose(node: Node3D) -> Array:
	var result: Array = []
	for value: Vector3 in [node.global_position, node.global_basis.x, node.global_basis.y, node.global_basis.z]:
		for number: float in [value.x, value.y, value.z]:
			result.append(snappedf(number, 0.0001))
	return result
