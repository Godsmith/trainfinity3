extends Node2D

const TILE_SIZE := 16
const TILE := Vector2(TILE_SIZE, TILE_SIZE)
const SCALE_FACTOR := 2  # Don't remember where I set this
enum GUI_STATE {NONE, TRACK, STATION, TRAIN1, TRAIN2, LIGHT, DESTROY}

const STATION = preload("res://scenes/station.tscn")
const TRAIN = preload("res://scenes/train.tscn")
const TRACK = preload("res://scenes/track.tscn")
const LIGHT = preload("res://scenes/light.tscn")

@onready var ghost_track = $GhostTrack
@onready var ghost_station = $GhostStation
@onready var ghost_light = $GhostLight

var gui_state := GUI_STATE.NONE
var is_left_mouse_button_held_down := false
var is_right_mouse_button_held_down := false

var start_track_location := Vector2()
var ghost_tracks: Array[Track] = []
# The keys are provided by Track.position_rotation()
var tracks: Dictionary[Vector3i, Track] = {}
var ghost_track_tile_positions: Array[Vector2] = []

var astar = AStar2D.new()
var astar_id_from_position = {}

@onready var camera = $Camera2D

var selected_station: Station = null


func _real_stations() -> Array:
	return get_tree().get_nodes_in_group("stations").filter(func(station): return !station.is_ghost)


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_left_mouse_button_held_down = event.is_pressed()
			if gui_state == GUI_STATE.TRACK:
				start_track_location = get_local_mouse_position().snapped(TILE)
				ghost_track.visible = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_mouse_button_held_down = event.is_pressed()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and not event.is_echo():
			camera.zoom_camera(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not event.is_echo():
			camera.zoom_camera(1/1.1)
	
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		match gui_state:
			GUI_STATE.TRACK:
				_create_track()
				ghost_track.visible = true
			GUI_STATE.STATION:
				_create_station(get_local_mouse_position().snapped(TILE))
			GUI_STATE.LIGHT:
				_create_light(get_local_mouse_position().snapped(TILE))
	
	if event is InputEventMouseMotion:
		var mouse_position = get_local_mouse_position().snapped(TILE)
		ghost_track.position = mouse_position
		ghost_station.position = mouse_position
		ghost_light.position = mouse_position
		if is_left_mouse_button_held_down:
			if gui_state == GUI_STATE.TRACK and is_left_mouse_button_held_down:
				var new_ghost_track_tile_positions = _positions_between(start_track_location, mouse_position)
				if new_ghost_track_tile_positions != ghost_track_tile_positions:
					_show_ghost_track(new_ghost_track_tile_positions)
					
		if is_right_mouse_button_held_down:
			var camera = get_viewport().get_camera_2d()
			camera.position -= event.get_relative() / camera.zoom.x
			

#######################################################################

func _show_ghost_track(positions: Array[Vector2]):
	ghost_track_tile_positions = positions
	for ghost_track in ghost_tracks:
		ghost_track.queue_free()
	ghost_tracks.clear()
	for i in len(ghost_track_tile_positions) - 1:
		var pos1 = ghost_track_tile_positions[i]
		var pos2 = ghost_track_tile_positions[i+1]
		var position = pos1.lerp(pos2, 0.5)
		var ghost_track := Track.create(pos1, pos2)
		ghost_track.set_ghost_status(true)
		ghost_track.position = position
		ghost_tracks.append(ghost_track)
		$".".add_child(ghost_track)

func _create_track():
	for ghost_track in ghost_tracks:
		var position = ghost_track.position.snapped(TILE)
		if ghost_track.position_rotation() in tracks:
			ghost_track.queue_free()
		else:
			tracks[ghost_track.position_rotation()] = ghost_track
			ghost_track.set_ghost_status(false)
			ghost_track.track_clicked.connect(_track_clicked)
	var ids = []
	for position in ghost_track_tile_positions:
		_add_position_to_astar(position)
		ids.append(astar_id_from_position[position])
	for i in range(1, len(ids)):
		astar.connect_points(ids[i-1], ids[i])
	ghost_tracks.clear()

func _add_position_to_astar(position):
	if not position in astar_id_from_position:
		var id = astar.get_available_point_id()
		astar_id_from_position[position] = id
		astar.add_point(id, position)

func _track_clicked(track: Track):
	if gui_state == GUI_STATE.DESTROY:
		astar.disconnect_points(astar_id_from_position[track.pos1], astar_id_from_position[track.pos2])
		tracks.erase(track.position_rotation())
		track.queue_free()
	
##################################################################

func _on_trackbutton_toggled(toggled_on: bool) -> void:
	_change_gui_state(GUI_STATE.TRACK if toggled_on else GUI_STATE.NONE)

func _on_stationbutton_toggled(toggled_on: bool) -> void:
	_change_gui_state(GUI_STATE.STATION if toggled_on else GUI_STATE.NONE)

func _on_trainbutton_toggled(toggled_on: bool) -> void:
	_change_gui_state(GUI_STATE.TRAIN1 if toggled_on else GUI_STATE.NONE)
	
func _on_light_button_toggled(toggled_on: bool) -> void:
	_change_gui_state(GUI_STATE.LIGHT if toggled_on else GUI_STATE.NONE)

func _on_destroybutton_toggled(toggled_on: bool) -> void:
	_change_gui_state(GUI_STATE.DESTROY if toggled_on else GUI_STATE.NONE)


func _change_gui_state(new_state: GUI_STATE):
	ghost_track.visible = false
	ghost_station.visible = false
	ghost_light.visible = false
	for station: Station in _real_stations():
		station.modulate = Color(1,1,1,1)
		
	if new_state == GUI_STATE.TRACK:
		ghost_track.visible = true
	elif new_state == GUI_STATE.STATION:
		ghost_station.visible = true
	elif new_state == GUI_STATE.LIGHT:
		ghost_light.visible = true
		
	gui_state = new_state

###################################################################

func _create_station(position: Vector2):
	var station = STATION.instantiate()
	station.position = position
	_add_position_to_astar(position)
	station.station_clicked.connect(_station_clicked)
	add_child(station)
	
func _station_clicked(station: Station):
	if gui_state == GUI_STATE.TRAIN1:
		var id1 = astar_id_from_position[station.position.round()]
		for other_station: Station in _real_stations():
			station.modulate = Color(1,1,1,1)
			if other_station != station:
				var id2 = astar_id_from_position[other_station.position.round()]
				if astar.get_point_path(id1, id2):
					other_station.modulate = Color(0,1,0,1)
		selected_station = station
		gui_state = GUI_STATE.TRAIN2
	elif gui_state == GUI_STATE.TRAIN2:
		var id1 = astar_id_from_position[selected_station.position.round()]
		var id2 = astar_id_from_position[station.position.round()]
		var point_path = astar.get_point_path(id1, id2)
		if point_path:
			var train = TRAIN.instantiate()
			train.set_path(point_path)
			add_child(train)
			gui_state == GUI_STATE.NONE
	elif gui_state == GUI_STATE.DESTROY:
		station.queue_free()
	
###################################################################

func _create_light(position: Vector2):
	var light = LIGHT.instantiate()
	light.position = position
	light.light_clicked.connect(_light_clicked)
	add_child(light)

func _light_clicked(light: Light):
	if gui_state == GUI_STATE.DESTROY:
		light.queue_free()
