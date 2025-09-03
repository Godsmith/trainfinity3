# In-game upgrades
# - range of stations (start with 1) - though it looks ugly when they are too far from ore
# - number of trains (start with 1)
# - map size

# Between-round upgrade
# - starting everything above
# - ore patch size

# TODO
# - trains, rails and stations should have a cost
# - train collisions
# - trains cannot turn so quickly
# - limit zoom in and out


extends Node2D

class_name Game

const HALF_GRID_SIZE := 32
const TILE := Vector2(Global.TILE_SIZE, Global.TILE_SIZE)
const SCALE_FACTOR := 2 # Don't remember where I set this
enum GUI_STATE {NONE, TRACK, STATION, TRAIN1, TRAIN2, LIGHT, DESTROY}

const FACTORY = preload("res://scenes/factory.tscn")
const STATION = preload("res://scenes/station.tscn")
const TRAIN = preload("res://scenes/train.tscn")
const TRACK = preload("res://scenes/track.tscn")
const LIGHT = preload("res://scenes/light.tscn")
const WALL = preload("res://scenes/wall.tscn")
const ORE = preload("res://scenes/ore.tscn")

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
@onready var gui: Gui = $Gui

var selected_station: Station = null

@export_range(0.0, 1.0) var wall_chance: float = 0.3
@export_range(0.0, 1.0) var ore_chance: float = 0.1

var money := 0

var wall_position_set: Dictionary[Vector2i, int] = {}

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
			x += Global.TILE_SIZE * dx_sign
		if y != stop.y:
			y += Global.TILE_SIZE * dy_sign
		out.append(Vector2(x, y))
	return out


func _ready():
	# TODO: do not expose Gui innards this way
	$Gui/HBoxContainer/TrackButton.connect("toggled", _on_trackbutton_toggled)
	$Gui/HBoxContainer/StationButton.connect("toggled", _on_stationbutton_toggled)
	$Gui/HBoxContainer/TrainButton.connect("toggled", _on_trainbutton_toggled)
	$Gui/HBoxContainer/LightButton.connect("toggled", _on_lightbutton_toggled)
	$Gui/HBoxContainer/DestroyButton.connect("toggled", _on_destroybutton_toggled)
	$Timer.connect("timeout", _on_timer_timeout)
	_generate_map()


func _generate_map():
	randomize()
	var factory = FACTORY.instantiate()
	factory.position = Vector2(0, 0)
	add_child(factory)
	
	for x in range(-HALF_GRID_SIZE, HALF_GRID_SIZE):
		for y in range(-HALF_GRID_SIZE, HALF_GRID_SIZE):
			if x >= -1 and x <= 1 and y >= -1 and y <= 1:
				# Do not place around starting factory
				continue
			if randf() < wall_chance:
				var wall = WALL.instantiate()
				var wall_position = Vector2i(x, y) * Global.TILE_SIZE
				wall.position = wall_position
				wall_position_set[wall_position] = 0
				add_child(wall)

				# maybe add ore inside this wall
				if randf() < ore_chance:
					var ore = ORE.instantiate()
					ore.position = Vector2.ZERO # relative to wall
					wall.add_child(ore)


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
			camera.zoom_camera(1 / 1.1)
	
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		match gui_state:
			GUI_STATE.TRACK:
				_try_create_tracks()
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
			camera.position -= event.get_relative() / camera.zoom.x
			

#######################################################################

func _show_ghost_track(positions: Array[Vector2]):
	ghost_track_tile_positions = positions
	for track in ghost_tracks:
		track.queue_free()
	ghost_tracks.clear()
	for i in len(ghost_track_tile_positions) - 1:
		var pos1 = ghost_track_tile_positions[i]
		var pos2 = ghost_track_tile_positions[i + 1]
		var track := Track.create(pos1, pos2)
		# TODO: add other stuff beside walls here
		var is_allowed = (Vector2i(pos1) not in wall_position_set and Vector2i(pos2) not in wall_position_set)
		track.set_color(true, is_allowed)
		var midway_position = Vector2(pos1).lerp(pos2, 0.5)
		track.position = midway_position
		ghost_tracks.append(track)
		$".".add_child(track)

func _try_create_tracks():
	# Check if illegal positions, and if so abort and reset everything
	for ghost_track_tile_position in ghost_track_tile_positions:
		if Vector2i(ghost_track_tile_position) in wall_position_set:
			for track in ghost_tracks:
				track.queue_free()
			ghost_tracks.clear()
			return
	
	for track in ghost_tracks:
		if track.position_rotation() in tracks:
			track.queue_free()
		else:
			tracks[track.position_rotation()] = track
			track.set_color(false, true)
			track.track_clicked.connect(_track_clicked)
	var ids = []
	for ghost_track_position in ghost_track_tile_positions:
		_add_position_to_astar(ghost_track_position)
		ids.append(astar_id_from_position[ghost_track_position])
	for i in range(1, len(ids)):
		astar.connect_points(ids[i - 1], ids[i])
	ghost_tracks.clear()

func _add_position_to_astar(new_position: Vector2):
	if not new_position in astar_id_from_position:
		var id = astar.get_available_point_id()
		astar_id_from_position[new_position] = id
		astar.add_point(id, new_position)

func _track_clicked(track: Track):
	if gui_state == GUI_STATE.DESTROY:
		astar.disconnect_points(astar_id_from_position[track.pos1], astar_id_from_position[track.pos2])
		tracks.erase(track.position_rotation())
		track.queue_free()
	
##################################################################

func _on_trackbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GUI_STATE.TRACK)

func _on_stationbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GUI_STATE.STATION)

func _on_trainbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GUI_STATE.TRAIN1)
	
func _on_lightbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GUI_STATE.LIGHT)

func _on_destroybutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GUI_STATE.DESTROY)


func _change_gui_state(new_state: GUI_STATE):
	ghost_track.visible = false
	ghost_station.visible = false
	ghost_light.visible = false
	for station: Station in _real_stations():
		station.modulate = Color(1, 1, 1, 1)
		
	if new_state == GUI_STATE.TRACK:
		ghost_track.visible = true
	elif new_state == GUI_STATE.STATION:
		ghost_station.visible = true
	elif new_state == GUI_STATE.LIGHT:
		ghost_light.visible = true
	
	if new_state == GUI_STATE.NONE:
		gui.unpress_all()
	gui_state = new_state

###################################################################

func _create_station(station_position: Vector2):
	var station = STATION.instantiate()
	station.position = station_position
	_add_position_to_astar(station_position)
	station.station_clicked.connect(_station_clicked)
	add_child(station)
	
func _station_clicked(station: Station):
	if gui_state == GUI_STATE.TRAIN1:
		var id1 = astar_id_from_position[station.position.round()]
		for other_station: Station in _real_stations():
			station.modulate = Color(1, 1, 1, 1)
			if other_station != station:
				var id2 = astar_id_from_position[other_station.position.round()]
				if astar.get_point_path(id1, id2):
					other_station.modulate = Color(0, 1, 0, 1)
		selected_station = station
		gui_state = GUI_STATE.TRAIN2
	elif gui_state == GUI_STATE.TRAIN2:
		var id1 = astar_id_from_position[selected_station.position.round()]
		var id2 = astar_id_from_position[station.position.round()]
		if id1 != id2:
			var point_path = astar.get_point_path(id1, id2)
			if point_path:
				var train = TRAIN.instantiate()
				train.set_path(point_path)
				train.end_reached.connect(_on_train_reaches_end)
				add_child(train)
		_change_gui_state(GUI_STATE.TRAIN1)
	elif gui_state == GUI_STATE.DESTROY:
		station.queue_free()
	
###################################################################

func _create_light(light_position: Vector2):
	var light = LIGHT.instantiate()
	light.position = light_position
	light.light_clicked.connect(_light_clicked)
	add_child(light)

func _light_clicked(light: Light):
	if gui_state == GUI_STATE.DESTROY:
		light.queue_free()


######################################################################
	
func _on_timer_timeout():
	for station: Station in _real_stations():
		station.extract_ore()

######################################################################
	
func _on_train_reaches_end(train: Train):
	for factory in get_tree().get_nodes_in_group("factories"):
		if Global.is_orthogonally_adjacent(factory.get_global_position(),
										   Vector2i(train.get_train_position())):
			money += train.ore
			gui.show_money(money)
			train.ore = 0
			
	for station in _real_stations():
		if Vector2i(station.global_position) == Vector2i(train.get_train_position()):
			train.ore += station.ore
			station.remove_all_ore()
