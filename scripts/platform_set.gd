extends Node


class_name PlatformSet

const PLATFORM = preload("res://scenes/platform.tscn")

var _platforms: Dictionary[Vector2i, Node2D] = {}
var track_set: TrackSet

func _init(track_set_: TrackSet):
	track_set = track_set_

func create_platforms(stations: Array[Station], create_platform: Callable):
	var legal_platform_positions = _get_legal_platform_positions()
	var evaluated_platform_positions = []
	for station in stations:
		var potential_platform_positions = Global.orthogonally_adjacent(Vector2i(station.position))
		while potential_platform_positions:
			var pos = potential_platform_positions.pop_back()
			if pos in evaluated_platform_positions:
				continue
			if pos not in legal_platform_positions:
				continue
			evaluated_platform_positions.append(pos)
			potential_platform_positions.append_array(track_set.positions_connected_to(pos))
			# Need to check if there is already a platform here *after* adding 
			# potential_platform_positions in order to search "through" existing platforms
			if pos in _platforms:
				continue
			var platform = PLATFORM.instantiate()
			platform.position = pos
			platform.rotation = _get_platform_rotation(pos)
			create_platform.call(platform)
			_platforms[pos] = platform

func remove_adjacent_platforms(station: Station, all_stations: Array[Station]):
	# Remove adjacent platforms that are not connected to any other station
	for adjacent_position in Global.orthogonally_adjacent(station.position):
		if not adjacent_position in _platforms:
			# Only look at positions with platforms
			continue
		if len(stations_connected_to_platform(adjacent_position, all_stations)) > 1:
			# Skip platforms used by other stations
			continue
		for pos in _connected_platform_positions(adjacent_position):
			_platforms[pos].queue_free()
			_platforms.erase(pos)

func _get_platform_rotation(track_position: Vector2i) -> float:
	# Vector2i must be a legal platform position
	var other_track_position = track_set.positions_connected_to(track_position)[0]
	return 0.0 if track_position.y == other_track_position.y else PI / 2

func _get_legal_platform_positions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for track_position in track_set.positions_with_track():
		match track_set.get_track_count(track_position):
			1:
				var other_track_position = track_set.positions_connected_to(track_position)[0]
				if Global.is_orthogonally_adjacent(track_position, other_track_position):
					out.append(track_position)
			2:
				var connected_positions = track_set.positions_connected_to(track_position)
				var are_on_horizontal_line = (track_position.y == connected_positions[0].y and track_position.y == connected_positions[1].y)
				var are_on_vertical_line = (track_position.x == connected_positions[0].x and track_position.x == connected_positions[1].x)
				if are_on_horizontal_line or are_on_vertical_line:
					out.append(track_position)
	return out

func stations_connected_to_platform(platform_position: Vector2i, all_stations: Array[Station]) -> Array[Station]:
	var connected_positions = _connected_platform_positions(platform_position)
	var stations: Array[Station] = []
	for station in all_stations:
		for neighbor in Global.orthogonally_adjacent(Vector2i(station.position)):
			if connected_positions.has(neighbor):
				stations.append(station)
	return stations

func are_connected(platform1: Platform, platform2: Platform) -> bool:
	return _connected_platform_positions(Vector2i(platform1.position)).has(Vector2i(platform2.position))

func _connected_platform_positions(pos: Vector2i) -> Array[Vector2i]:
	var connected_positions: Array[Vector2i] = [pos]
	var possible_connected_platforms := track_set.positions_connected_to(pos)
	while possible_connected_platforms:
		var new_pos = possible_connected_platforms.pop_back()
		if new_pos not in connected_positions and new_pos in _platforms:
			connected_positions.append(new_pos)
			possible_connected_platforms.append_array(track_set.positions_connected_to(new_pos))
	return connected_positions

func platform_endpoints(pos: Vector2i) -> Array[Vector2i]:
	var platform_positions = _connected_platform_positions(pos)
	# Sort by x if x are different else sort by y
	platform_positions.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x if a.y == b.y else a.y < b.y)
	return [platform_positions[0], platform_positions[-1]]


func destroy_and_recreate_connected_platforms(positions: Array[Vector2i], all_stations: Array[Station], create_platform: Callable):
	# 1. Extend the given positions with all adjacent connected positions.
	var all_positions = _positions_connected_to(positions)
	# 2. Collect stations adjacent to these positions
	var stations = _stations_adjacent_to(all_positions, all_stations)
	# 3. Narrow it down to only platform positions
	var platform_positions = all_positions.keys().filter(func(p): return p in _platforms)
	# 4. Add stations connected to any positions that are platforms
	for platform_position in platform_positions:
		for station in stations_connected_to_platform(platform_position, all_stations):
			stations.append(station)
	# 5. Destroy platforms
	for pos in platform_positions:
		_platforms[pos].queue_free()
		_platforms.erase(pos)
	# 6. Recreate platforms
	create_platforms(stations, create_platform)

func _positions_connected_to(positions: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	var all_positions: Dictionary[Vector2i, int] = {}
	for position in positions:
		all_positions[position] = 0
		for other_position in track_set.positions_connected_to(position):
			all_positions[other_position] = 0
	return all_positions

static func _stations_adjacent_to(positions: Dictionary[Vector2i, int], all_stations: Array[Station]) -> Array[Station]:
	var stations: Array[Station] = []
	for station in all_stations:
		for pos in Global.orthogonally_adjacent(station.position):
			if pos in positions:
				stations.append(station)
	return stations
