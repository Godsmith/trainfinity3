extends RefCounted

class_name TrackCreator

var _candidate_ghost_track_tile_positions: Array[Vector2i] = []
var _placed_ghost_track_tile_positions: Array[Vector2i] = []
var _ghost_tracks: Array[Track] = []
var _create_tracks_method: Callable
var _illegal_track_positions_method: Callable


func _init(create_tracks_method: Callable, illegal_track_positions_method: Callable) -> void:
	_create_tracks_method = create_tracks_method
	_illegal_track_positions_method = illegal_track_positions_method


func mouse_move(snapped_mouse_position: Vector2i, astar_grid: AStarGrid2D, existing_track_set: TrackSet) -> Array[Track]:
	if _placed_ghost_track_tile_positions:
		_candidate_ghost_track_tile_positions.assign(Array(astar_grid.get_point_path(_placed_ghost_track_tile_positions[-1] / Global.TILE_SIZE, snapped_mouse_position / Global.TILE_SIZE)).map(func(v): return Vector2i(v)))
		if _placed_ghost_track_tile_positions and snapped_mouse_position == _placed_ghost_track_tile_positions[-1]:
			# If at current end position, just show the placed ghost track
			return create_ghost_track(_placed_ghost_track_tile_positions, existing_track_set)
		elif snapped_mouse_position in _placed_ghost_track_tile_positions:
			# If somewhere else among placed ghost track, show them as red from
			# end back to that position, to show that they will be deleted on click
			var ghost_tracks := create_ghost_track(_placed_ghost_track_tile_positions, existing_track_set)
			var reverse_ghost_tracks = _ghost_tracks.duplicate()
			reverse_ghost_tracks.reverse()
			for track in reverse_ghost_tracks:
				track.set_allowed(false)
				if snapped_mouse_position in [track.pos1, track.pos2]:
					break
			return ghost_tracks
		else:
			# Else, show placed and candidate ghost track
			return create_ghost_track(
					_placed_ghost_track_tile_positions + _candidate_ghost_track_tile_positions, existing_track_set)
	return [] as Array[Track]


func create_ghost_track(ghost_track_tile_positions: Array[Vector2i], existing_track_set: TrackSet) -> Array[Track]:
	var illegal_positions = _illegal_track_positions_method.call(ghost_track_tile_positions)
	# TODO: I believe the ghost track is freed elsewhere as well, so probably not needed
	# here. Perhaps have the ghost track under this node and delete the entire node
	# to make sure they are removed?
	for track in _ghost_tracks:
		track.queue_free()
	_ghost_tracks.clear()

	# Calculate how many tracks can be built within limit
	var tracks_remaining = Upgrades.get_remaining_assets(Global.Asset.TRACK)
	# How many new tracks that will be created
	var new_track_count = 0

	for i in len(ghost_track_tile_positions) - 1:
		var pos1 = ghost_track_tile_positions[i]
		var pos2 = ghost_track_tile_positions[i + 1]
		if pos1 == pos2:
			continue
		var track := Track.create(pos1, pos2)

		if not existing_track_set.exists(track):
			new_track_count += 1

		var is_legal_position = (pos1 not in illegal_positions and
						  pos2 not in illegal_positions)
		# Only count new ghost tracks (not existing ones) against the limit
		var is_within_limit = new_track_count <= tracks_remaining
		var is_allowed = is_legal_position and is_within_limit
		track.set_allowed(is_allowed)
		track.set_ghostly(true)
		var midway_position = Vector2(pos1).lerp(pos2, 0.5)
		track.position = midway_position
		_ghost_tracks.append(track)
	return _ghost_tracks


## Returns where to show the confirm marker, or Vector2i.MAX otherwise
func click(snapped_mouse_position: Vector2i, track_set: TrackSet) -> Vector2i:
	if not _placed_ghost_track_tile_positions and not _illegal_track_positions_method.call([snapped_mouse_position] as Array[Vector2i]):
		# Start track building mode
		_placed_ghost_track_tile_positions = [snapped_mouse_position] as Array[Vector2i]
	elif _placed_ghost_track_tile_positions and snapped_mouse_position == _placed_ghost_track_tile_positions[-1]:
		var new_track_count = 0
		for track in _ghost_tracks:
			if not track_set.exists(track):
				new_track_count += 1
		# Click last position again: build
		if not Upgrades.can_build_asset(Global.Asset.TRACK, new_track_count):
			# TrackCreator is not part of the tree, so we need to have some global object
			# as the parent, such as GlobalBank.
			Global.show_popup("Limit reached!", snapped_mouse_position, GlobalBank)
		else:
			create_tracks()
	elif _placed_ghost_track_tile_positions and snapped_mouse_position in _placed_ghost_track_tile_positions:
		# If clicking placed ghost track, revert to that position
		for i in len(_placed_ghost_track_tile_positions):
			if snapped_mouse_position == _placed_ghost_track_tile_positions[i]:
				_placed_ghost_track_tile_positions = _placed_ghost_track_tile_positions.slice(0, i + 1)
				break
		for track in _ghost_tracks.duplicate():
			if track.pos1 not in _placed_ghost_track_tile_positions or track.pos2 not in _placed_ghost_track_tile_positions:
				track.queue_free()
				_ghost_tracks.erase(track)
		if len(_placed_ghost_track_tile_positions) == 1:
			# If we are back at the starting position, abort track laying mode
			reset_ghost_tracks()
	else:
		var new_track_count = 0
		for track in _ghost_tracks:
			if not track_set.exists(track):
				new_track_count += 1

		# Click other position: move candidate ghost track to placed ghost track
		if not Upgrades.can_build_asset(Global.Asset.TRACK, new_track_count):
			# TrackCreator is not part of the tree, so we need to have some global object
			# as the parent, such as GlobalBank.
			Global.show_popup("Limit reached!", snapped_mouse_position, GlobalBank)
		elif _ghost_tracks.all(func(x): return x.is_allowed):
			_placed_ghost_track_tile_positions.append_array(_candidate_ghost_track_tile_positions)

	if len(_placed_ghost_track_tile_positions) >= 2:
		return _placed_ghost_track_tile_positions[-1]
	else:
		return Vector2i.MAX

func create_tracks():
	_create_tracks_method.call(_ghost_tracks)
	reset()


func reset_ghost_tracks():
	for track in _ghost_tracks:
		track.queue_free()
	reset()


func reset():
	_ghost_tracks.clear()
	_placed_ghost_track_tile_positions.clear()
	_candidate_ghost_track_tile_positions.clear()
