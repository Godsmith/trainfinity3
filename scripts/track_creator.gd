extends Node

class_name TrackCreator

var _candidate_ghost_track_tile_positions: Array[Vector2i] = []
var _placed_ghost_track_tile_positions: Array[Vector2i] = []
var _ghost_tracks: Array[Track] = []
var _create_tracks_method: Callable
var _add_child_method: Callable
var _illegal_track_positions_method: Callable
var astar_grid: AStarGrid2D


func _init(create_tracks_method: Callable, add_child_method: Callable, illegal_track_positions_method: Callable) -> void:
	_create_tracks_method = create_tracks_method
	_add_child_method = add_child_method
	_illegal_track_positions_method = illegal_track_positions_method


func mouse_move(snapped_mouse_position: Vector2i):
	if _placed_ghost_track_tile_positions:
		_candidate_ghost_track_tile_positions.assign(Array(astar_grid.get_point_path(_placed_ghost_track_tile_positions[-1] / Global.TILE_SIZE, snapped_mouse_position / Global.TILE_SIZE)).map(func(v): return Vector2i(v)))
		if _placed_ghost_track_tile_positions and snapped_mouse_position == _placed_ghost_track_tile_positions[-1]:
			# If at current end position, just show the placed ghost track
			show_ghost_track(_placed_ghost_track_tile_positions)
		elif snapped_mouse_position in _placed_ghost_track_tile_positions:
			# If somewhere else among placed ghost track, show them as red from
			# end back to that position, to show that they will be deleted on click
			show_ghost_track(_placed_ghost_track_tile_positions)
			var reverse_ghost_tracks = _ghost_tracks.duplicate()
			reverse_ghost_tracks.reverse()
			for track in reverse_ghost_tracks:
				track.set_allowed(false)
				if snapped_mouse_position in [track.pos1, track.pos2]:
					break
		else:
			# Else, show placed and candidate ghost track
			show_ghost_track(
					_placed_ghost_track_tile_positions + _candidate_ghost_track_tile_positions)


func show_ghost_track(ghost_track_tile_positions: Array[Vector2i]):
	var illegal_positions = _illegal_track_positions_method.call(ghost_track_tile_positions)
	for track in _ghost_tracks:
		track.queue_free()
	_ghost_tracks.clear()
	for i in len(ghost_track_tile_positions) - 1:
		var pos1 = ghost_track_tile_positions[i]
		var pos2 = ghost_track_tile_positions[i + 1]
		if pos1 == pos2:
			continue
		var track := Track.create(pos1, pos2)
		var is_allowed = (pos1 not in illegal_positions and
						  pos2 not in illegal_positions)
		track.set_allowed(is_allowed)
		track.set_ghostly(true)
		var midway_position = Vector2(pos1).lerp(pos2, 0.5)
		track.position = midway_position
		_ghost_tracks.append(track)
		_add_child_method.call(track)


## Returns where to show the confirm marker, or Vector2i.MAX otherwise
func click(snapped_mouse_position: Vector2i, boundaries: Rect2i) -> Vector2i:
	if not _placed_ghost_track_tile_positions and not _illegal_track_positions_method.call([snapped_mouse_position] as Array[Vector2i]):
		# Start track building mode
		_placed_ghost_track_tile_positions = [snapped_mouse_position] as Array[Vector2i]
		_update_astar(boundaries)
	elif _placed_ghost_track_tile_positions and snapped_mouse_position == _placed_ghost_track_tile_positions[-1]:
		# Click last position again: build
		if not GlobalBank.can_afford(Global.Asset.TRACK, len(_ghost_tracks)):
			Global.show_popup("Cannot afford!", snapped_mouse_position, self)
		else:
			create_tracks()
	elif _placed_ghost_track_tile_positions and snapped_mouse_position in _placed_ghost_track_tile_positions:
		# If clicking placed ghost track, revert to that position
		for i in len(_placed_ghost_track_tile_positions):
			if snapped_mouse_position == _placed_ghost_track_tile_positions[i]:
				_placed_ghost_track_tile_positions = _placed_ghost_track_tile_positions.slice(0, i + 1)
				break
		if len(_placed_ghost_track_tile_positions) == 1:
			# If we are back at the starting position, abort track laying mode
			reset_ghost_tracks()
	else:
		# Click other position: move candidate ghost track to placed ghost track
		if not GlobalBank.can_afford(Global.Asset.TRACK, len(_ghost_tracks)):
			Global.show_popup("Cannot afford!", snapped_mouse_position, self)
		elif _ghost_tracks.all(func(x): return x.is_allowed):
			_placed_ghost_track_tile_positions.append_array(_candidate_ghost_track_tile_positions)

	if len(_placed_ghost_track_tile_positions) >= 2:
		return _placed_ghost_track_tile_positions[-1]
	else:
		return Vector2i.MAX

func _update_astar(boundaries: Rect2i):
	astar_grid = AStarGrid2D.new()
	astar_grid.region = boundaries
	astar_grid.cell_size = Global.TILE
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.update()
	var positions: Array[Vector2i] = []
	# Set solid points
	# 1. Illegal positions
	for x in range(boundaries.position.x, boundaries.end.x + Global.TILE_SIZE, Global.TILE_SIZE):
		for y in range(boundaries.position.y, boundaries.end.y + Global.TILE_SIZE, Global.TILE_SIZE):
			positions.append(Vector2i(x, y))
	var illegal_positions = _illegal_track_positions_method.call(positions)
	for position in illegal_positions:
		astar_grid.set_point_solid(position / Global.TILE_SIZE)
	# 2. West and east edges
	for x in [boundaries.position.x - Global.TILE_SIZE, boundaries.end.x + Global.TILE_SIZE]:
		for y in range(boundaries.position.y - Global.TILE_SIZE, boundaries.end.y + Global.TILE_SIZE * 2, Global.TILE_SIZE):
			astar_grid.set_point_solid(Vector2i(x, y) / Global.TILE_SIZE)
	# 3. North and south edges
	for y in [boundaries.position.y - Global.TILE_SIZE, boundaries.end.y + Global.TILE_SIZE]:
		for x in range(boundaries.position.x - Global.TILE_SIZE, boundaries.end.x + Global.TILE_SIZE * 2, Global.TILE_SIZE):
			astar_grid.set_point_solid(Vector2i(x, y) / Global.TILE_SIZE)


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
