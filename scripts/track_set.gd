extends Node


class_name TrackSet

# The keys are provided by str(track)
var _tracks: Dictionary[String, Track] = {}
## Dictionary[Vector2i, Dictionary[str, int]], where the inner Dictionary
## is used as a set of str(Track)
var _track_strings_from_position: Dictionary[Vector2i, Dictionary] = {}

func add(track: Track):
	_tracks[str(track)] = track
	if not track.pos1 in _track_strings_from_position:
		_track_strings_from_position[track.pos1] = {}
	if not track.pos2 in _track_strings_from_position:
		_track_strings_from_position[track.pos2] = {}
	_track_strings_from_position[track.pos1][str(track)] = 0
	_track_strings_from_position[track.pos2][str(track)] = 0

func exists(track: Track):
	return str(track) in _tracks

func get_all_tracks() -> Array[Track]:
	return _tracks.values()

func get_track_count(position: Vector2i) -> int:
	return len(tracks_at_position(position))

## Returns true if the position has a branching path, i.e. 3 or more rails
func is_intersection(position: Vector2i) -> bool:
	return get_track_count(position) >= 3

func positions_with_track() -> Array[Vector2i]:
	return _track_strings_from_position.keys()

## All positions adjacent and connected to [position]
func positions_connected_to(position: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for track_str in _track_strings_from_position[position]:
		positions.append(_tracks[track_str].other_position(position))
	return positions

## All positions adjacent and connected to [position] without one way track
func positions_bidirectionally_connected_to(position: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for track_str in _track_strings_from_position[position]:
		var track = _tracks[track_str]
		if track.direction == Track.Direction.BOTH:
			positions.append(track.other_position(position))
	return positions

func has_track(position: Vector2i) -> bool:
	return get_track_count(position) > 0

func tracks_at_position(position: Vector2i) -> Array:
	if not position in _track_strings_from_position:
		return []
	return _track_strings_from_position[position].keys().map(func(s): return _tracks[s])

func erase(track: Track):
	_tracks.erase(str(track))
	_track_strings_from_position[track.pos1].erase(str(track))
	_track_strings_from_position[track.pos2].erase(str(track))
	track.queue_free()

func get_segments_connected_to_positions(positions: Array[Vector2i]) -> Array[Vector2i]:
	var segment: Array[Vector2i] = positions
	var positions_to_check = positions.duplicate()
	while positions_to_check:
		var position_to_check = positions_to_check.pop_back()
		if len(tracks_at_position(position_to_check)) <= 2:
			segment.append(position_to_check)
			for connected_position in positions_bidirectionally_connected_to(position_to_check):
				if connected_position not in segment:
					positions_to_check.append(connected_position)
	return segment
