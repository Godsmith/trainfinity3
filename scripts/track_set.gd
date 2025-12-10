extends Node


class_name TrackSet

# The keys are provided by Track.position_rotation()
var _tracks: Dictionary[Vector3i, Track] = {}
var _tracks_from_position: Dictionary[Vector2i, Array] = {}

func add(track: Track):
	_tracks[track.position_rotation()] = track
	if not track.pos1 in _tracks_from_position:
		_tracks_from_position[track.pos1] = []
	if not track.pos2 in _tracks_from_position:
		_tracks_from_position[track.pos2] = []
	_tracks_from_position[track.pos1].append(track)
	_tracks_from_position[track.pos2].append(track)

func exists(track: Track):
	return track.position_rotation() in _tracks

func get_all_tracks() -> Array[Track]:
	return _tracks.values()

func get_track_count(position: Vector2i) -> int:
	return len(tracks_at_position(position))

## Returns true if the position has a branching path, i.e. 3 or more rails
func is_intersection(position: Vector2i) -> bool:
	return get_track_count(position) >= 3

func positions_with_track() -> Array[Vector2i]:
	return _tracks_from_position.keys()

## All positions adjacent and connected to [position]
func positions_connected_to(position: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for track in _tracks_from_position[position]:
		positions.append(track.other_position(position))
	return positions

## All positions adjacent and connected to [position] without one way track
func positions_bidirectionally_connected_to(position: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for track in _tracks_from_position[position]:
		if track.direction == Track.Direction.BOTH:
			positions.append(track.other_position(position))
	return positions

func has_track(position: Vector2i) -> bool:
	return get_track_count(position) > 0

func tracks_at_position(position: Vector2i) -> Array:
	if not position in _tracks_from_position:
		_tracks_from_position[position] = []
	return _tracks_from_position[position]

func erase(track: Track):
	_tracks.erase(track.position_rotation())
	_tracks_from_position[track.pos1].erase(track)
	_tracks_from_position[track.pos2].erase(track)
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
