extends RefCounted

class_name Astar

var astar = AStar2D.new()
var astar_id_from_position: Dictionary[Vector2i, int] = {}

func add_position(new_position: Vector2i):
	if not new_position in astar_id_from_position:
		var id = astar.get_available_point_id()
		astar_id_from_position[new_position] = id
		astar.add_point(id, new_position)

func disconnect_positions(pos1: Vector2i, pos2: Vector2i):
	astar.disconnect_points(astar_id_from_position[pos1], astar_id_from_position[pos2])

func connect_positions(pos1: Vector2i, pos2: Vector2i, bidirectional: bool = true):
	astar.connect_points(astar_id_from_position[pos1], astar_id_from_position[pos2], bidirectional)

func get_point_path(pos1: Vector2i, pos2: Vector2i):
	return astar.get_point_path(astar_id_from_position[pos1], astar_id_from_position[pos2])

func set_position_disabled(pos: Vector2i, disabled: bool = true):
	astar.set_point_disabled(astar_id_from_position[pos], disabled)

func clone() -> Astar:
	var original = astar
	var astar2d = AStar2D.new()

	# Copy all points
	for id in original.get_point_ids():
		var pos = original.get_point_position(id)
		var weight = original.get_point_weight_scale(id)
		astar2d.add_point(id, pos, weight)

	# Copy all connections
	for id in original.get_point_ids():
		for neighbor in original.get_point_connections(id):
			astar2d.connect_points(id, neighbor, false)

	# Copy disabled status
	for id in original.get_point_ids():
		if original.is_point_disabled(id):
			astar2d.set_point_disabled(id, true)

	var new_astar = Astar.new()
	new_astar.astar = astar2d
	new_astar.astar_id_from_position = astar_id_from_position.duplicate()

	return new_astar
