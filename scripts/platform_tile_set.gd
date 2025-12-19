extends Node


class_name PlatformTileSet

const PLATFORM_TILE = preload("res://scenes/platform_tile.tscn")

var _platform_tiles: Dictionary[Vector2i, Node2D] = {}
var track_set: TrackSet

func _init(track_set_: TrackSet):
	track_set = track_set_

func create_platform_tiles(stations: Array[Station]) -> Array[PlatformTile]:
	var positions_with_track_suitable_for_platform_tiles = _get_positions_with_track_suitable_for_platform_tiles()
	var evaluated_platform_tile_positions = []
	var platform_tiles: Array[PlatformTile] = []
	for station in stations:
		var potential_platform_tile_positions = Global.orthogonally_adjacent(Vector2i(station.position))
		while potential_platform_tile_positions:
			var pos = potential_platform_tile_positions.pop_back()
			if pos in evaluated_platform_tile_positions:
				continue
			if pos not in positions_with_track_suitable_for_platform_tiles:
				continue
			evaluated_platform_tile_positions.append(pos)
			if _would_platform_here_exceed_maximum_platform_size(pos):
				continue
			potential_platform_tile_positions.append_array(track_set.positions_connected_to(pos))
			# Need to check if there is already a platform tile here *after* adding 
			# potential_platform_positions in order to search "through" existing platforms
			if pos in _platform_tiles:
				continue
			var platform_tile = PLATFORM_TILE.instantiate()
			platform_tile.position = pos
			platform_tile.rotation = _get_platform_rotation(pos)
			_platform_tiles[pos] = platform_tile
			platform_tiles.append(platform_tile)
	return platform_tiles

func _would_platform_here_exceed_maximum_platform_size(pos: Vector2i):
	for neighbour in track_set.positions_connected_to(pos):
		if platform_size(neighbour) == Upgrades.get_value(Upgrades.UpgradeType.PLATFORM_LENGTH):
			return true
	return false

func _get_platform_rotation(track_position: Vector2i) -> float:
	# Vector2i must be a legal platform tile position
	var other_track_position = track_set.positions_connected_to(track_position)[0]
	return 0.0 if track_position.y == other_track_position.y else PI / 2

func _get_positions_with_track_suitable_for_platform_tiles() -> Array[Vector2i]:
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

func get_platform_tile_at(pos: Vector2i):
	return _platform_tiles[pos]

func stations_connected_to_platform(platform_tile_position: Vector2i, all_stations: Array[Station]) -> Array[Station]:
	var connected_positions = connected_platform_tile_positions(platform_tile_position)
	var stations: Array[Station] = []
	for station in all_stations:
		for neighbor in Global.orthogonally_adjacent(Vector2i(station.position)):
			if connected_positions.has(neighbor):
				stations.append(station)
	return stations

func are_connected(platform_tile1: PlatformTile, platform_tile2: PlatformTile) -> bool:
	return connected_platform_tile_positions(Vector2i(platform_tile1.position)).has(Vector2i(platform_tile2.position))

## Returns an [b]unordered[/b] list of platform tiles that are on the same platform as [pos].
## [br]Returns an empty array if the positions does not have a platform.
func connected_platform_tile_positions(pos: Vector2i) -> Array[Vector2i]:
	if pos not in _platform_tiles:
		return [] as Array[Vector2i]
	var connected_positions: Array[Vector2i] = [pos]
	var possible_connected_platform_tile_positions := track_set.positions_connected_to(pos)
	while possible_connected_platform_tile_positions:
		var new_pos = possible_connected_platform_tile_positions.pop_back()
		if new_pos not in connected_positions and new_pos in _platform_tiles:
			connected_positions.append(new_pos)
			possible_connected_platform_tile_positions.append_array(track_set.positions_connected_to(new_pos))
	return connected_positions

## Returns an [b]ordered[/b] list of platform tiles that are on the same platform as [pos],
## starting from [starting_at].
## [br]Returns an empty array if the positions does not have a platform.
func connected_ordered_platform_tile_positions(pos: Vector2i, starting_at: Vector2i) -> Array[Vector2i]:
	var positions = connected_platform_tile_positions(pos)
	if not positions:
		return []
	positions.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x if a.y == b.y else a.y < b.y)
	if not positions[0] == starting_at:
		positions.reverse()
	assert(positions[0] == starting_at)
	return positions

func platform_size(pos: Vector2i) -> int:
	return len(connected_platform_tile_positions(pos))

func platform_endpoints(pos: Vector2i) -> Array[Vector2i]:
	var platform_tile_positions = connected_platform_tile_positions(pos)
	# Sort by x if x are different else sort by y
	platform_tile_positions.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x if a.y == b.y else a.y < b.y)
	return [platform_tile_positions[0], platform_tile_positions[-1]]

func destroy_and_recreate_platform_tiles_orthogonally_linked_to(positions: Array[Vector2i], all_stations: Array[Station]) -> Array[PlatformTile]:
	var all_positions = _positions_orthogonally_linked_to(positions)
	for pos in all_positions:
		if pos not in _platform_tiles:
			continue
		_platform_tiles[pos].queue_free()
		_platform_tiles.erase(pos)
	var stations = _stations_adjacent_to(all_positions, all_stations)
	return create_platform_tiles(stations)

func _positions_orthogonally_linked_to(positions: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	var collected_positions: Dictionary[Vector2i, int] = {}
	var positions_to_evaluate := positions.duplicate()
	while positions_to_evaluate:
		var position = positions_to_evaluate.pop_back()
		collected_positions[position] = 0
		for other_position in track_set.positions_connected_to(position):
			if other_position in collected_positions:
				continue
			if other_position.x == position.x or other_position.y == position.y:
				positions_to_evaluate.append(other_position)
	return collected_positions

static func _stations_adjacent_to(positions: Dictionary[Vector2i, int], all_stations: Array[Station]) -> Array[Station]:
	var stations: Array[Station] = []
	for station in all_stations:
		for pos in Global.orthogonally_adjacent(station.position):
			if pos in positions:
				stations.append(station)
	return stations

func is_new_track_in_legal_position(track: Track):
	# Checks so that the new track is not at an odd angle into an existing platform
	var affected_platform_tiles: Array[PlatformTile] = []
	for pos in [track.pos1, track.pos2]:
		if pos in _platform_tiles:
			affected_platform_tiles.append(_platform_tiles[pos])
	for platform_tile in affected_platform_tiles:
		if platform_tile.rotation == 0.0: # Horizontal
			if track.pos1.y != track.pos2.y:
				return false
		else: # Vertical
			if track.pos1.x != track.pos2.x:
				return false
	return true

func has_platform(pos: Vector2i):
	return pos in _platform_tiles
