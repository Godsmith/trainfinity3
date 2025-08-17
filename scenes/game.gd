extends Node2D

const TILE_SIZE := 16
const SCALE_FACTOR := 2  # Don't remember where I set this
var is_left_mouse_button_held_down := false
var is_right_mouse_button_held_down := false
var start_track_location := Vector2()
enum GUI_STATE {NONE, TRACK}
var gui_state := GUI_STATE.NONE
var ghost_tracks: Array[Track] = []
var tracks: Array[Track] = []
var ghost_track_positions: Array[Vector2] = []

var track_scene = preload("res://scenes/track.tscn")

func snap_to_grid(position: Vector2) -> Vector2:
	return Vector2(round(position.x/TILE_SIZE)*TILE_SIZE, round(position.y/TILE_SIZE)*TILE_SIZE)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_left_mouse_button_held_down = event.is_pressed()
			if gui_state == GUI_STATE.TRACK:
				start_track_location = snap_to_grid(get_local_mouse_position())
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_mouse_button_held_down = event.is_pressed()
	
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		for ghost_track in ghost_tracks:
			tracks.append(ghost_track)
			ghost_track.modulate = Color(1,1,1,1)
		ghost_tracks.clear()
	
	if event is InputEventMouseMotion:
		$GhostTrack.position = snap_to_grid(get_local_mouse_position())
		if is_left_mouse_button_held_down:
			if gui_state == GUI_STATE.TRACK and is_left_mouse_button_held_down:
				var new_ghost_track_positions = _positions_between(start_track_location, snap_to_grid(get_local_mouse_position()))
				if new_ghost_track_positions != ghost_track_positions:
					_show_ghost_track(new_ghost_track_positions)
					
		if is_right_mouse_button_held_down:
			var camera = get_viewport().get_camera_2d()
			camera.position -= event.get_relative() / SCALE_FACTOR

func _show_ghost_track(positions: Array[Vector2]):
	ghost_track_positions = positions
	for ghost_track in ghost_tracks:
		ghost_track.queue_free()
	ghost_tracks.clear()
	for position in ghost_track_positions:
		var ghost_track = $GhostTrack.duplicate()
		ghost_track.position = position
		ghost_tracks.append(ghost_track)
		$".".add_child(ghost_track)
	
		
func _positions_between(start: Vector2, stop: Vector2) -> Array[Vector2]:
	# start and stop must be on the grid.
	var out: Array[Vector2] = []
	var x = start.x
	var y = start.y
	var dx_sign = sign(stop.x - start.x)
	var dy_sign = sign(stop.y - start.y)
	out.append(start)
	while x != stop.x or y != stop.y:
		if x != stop.x:
			x += TILE_SIZE * dx_sign
		if y != stop.y:
			y += TILE_SIZE * dy_sign
		out.append(Vector2(x,y))
	return out
		
	

func _on_railbutton_toggled(toggled_on: bool) -> void:
	if toggled_on: 
		gui_state = GUI_STATE.TRACK
	else:
		gui_state = GUI_STATE.NONE
	$GhostTrack.visible = toggled_on
		
	
