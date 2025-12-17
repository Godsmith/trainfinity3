extends Node

class_name TrackCreator

var candidate_ghost_track_tile_positions: Array[Vector2i] = []
var placed_ghost_track_tile_positions: Array[Vector2i] = []
var ghost_tracks: Array[Track] = []
var create_tracks_method: Callable
var add_child_method: Callable
var illegal_track_positions_method: Callable


func _init(create_tracks_method_: Callable, add_child_method_: Callable, illegal_track_positions_method_: Callable) -> void:
	create_tracks_method = create_tracks_method_
	add_child_method = add_child_method_
	illegal_track_positions_method = illegal_track_positions_method_


func mouse_move(snapped_mouse_position: Vector2i):
	if placed_ghost_track_tile_positions:
		candidate_ghost_track_tile_positions = _positions_between(placed_ghost_track_tile_positions[-1], snapped_mouse_position)
		if placed_ghost_track_tile_positions and snapped_mouse_position == placed_ghost_track_tile_positions[-1]:
			# If at current end position, just show the placed ghost track
			show_ghost_track(placed_ghost_track_tile_positions)
		elif snapped_mouse_position in placed_ghost_track_tile_positions:
			# If somewhere else among placed ghost track, show them as red from
			# end back to that position, to show that they will be deleted on click
			show_ghost_track(placed_ghost_track_tile_positions)
			var reverse_ghost_tracks = ghost_tracks.duplicate()
			reverse_ghost_tracks.reverse()
			for track in reverse_ghost_tracks:
				track.set_allowed(false)
				if snapped_mouse_position in [track.pos1, track.pos2]:
					break
		else:
			# Else, show placed and candidate ghost track
			show_ghost_track(
					placed_ghost_track_tile_positions + candidate_ghost_track_tile_positions)


func show_ghost_track(ghost_track_tile_positions: Array[Vector2i]):
	var illegal_positions = illegal_track_positions_method.call(ghost_track_tile_positions)
	for track in ghost_tracks:
		track.queue_free()
	ghost_tracks.clear()
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
		ghost_tracks.append(track)
		add_child_method.call(track)


## Returns where to show the confirm marker, or Vector2i.MAX otherwise
func click(snapped_mouse_position: Vector2i) -> Vector2i:
	if not placed_ghost_track_tile_positions:
		# Start track building mode
		placed_ghost_track_tile_positions = [snapped_mouse_position] as Array[Vector2i]
	elif placed_ghost_track_tile_positions and snapped_mouse_position == placed_ghost_track_tile_positions[-1]:
		# Click last position again: build
		if not GlobalBank.can_afford(Global.Asset.TRACK, len(ghost_tracks)):
			Global.show_popup("Cannot afford!", snapped_mouse_position, self)
		else:
			create_tracks()
	elif placed_ghost_track_tile_positions and snapped_mouse_position in placed_ghost_track_tile_positions:
		# If clicking placed ghost track, revert to that position
		for i in len(placed_ghost_track_tile_positions):
			if snapped_mouse_position == placed_ghost_track_tile_positions[i]:
				placed_ghost_track_tile_positions = placed_ghost_track_tile_positions.slice(0, i + 1)
				break
		if len(placed_ghost_track_tile_positions) == 1:
			# If we are back at the starting position, abort track laying mode
			reset_ghost_tracks()
	else:
		# Click other position: move candidate ghost track to placed ghost track
		if not GlobalBank.can_afford(Global.Asset.TRACK, len(ghost_tracks)):
			Global.show_popup("Cannot afford!", snapped_mouse_position, self)
		elif ghost_tracks.all(func(x): return x.is_allowed):
			placed_ghost_track_tile_positions.append_array(candidate_ghost_track_tile_positions)

	if len(placed_ghost_track_tile_positions) >= 2:
		return placed_ghost_track_tile_positions[-1]
	else:
		return Vector2i.MAX


func create_tracks():
	create_tracks_method.call(ghost_tracks)
	reset()


func reset_ghost_tracks():
	for track in ghost_tracks:
		track.queue_free()
	reset()


func reset():
	ghost_tracks.clear()
	placed_ghost_track_tile_positions.clear()
	candidate_ghost_track_tile_positions.clear()


func _positions_between(start: Vector2i, stop: Vector2i) -> Array[Vector2i]:
	# start and stop must be on the grid.
	var out: Array[Vector2i] = []
	var x = start.x
	var y = start.y
	var dx_sign = signi(stop.x - start.x)
	var dy_sign = signi(stop.y - start.y)
	out.append(start)
	while x != stop.x or y != stop.y:
		if x != stop.x:
			x += Global.TILE_SIZE * dx_sign
		if y != stop.y:
			y += Global.TILE_SIZE * dy_sign
		out.append(Vector2i(x, y))
	return out
