extends Node2D

class_name Game

const SCALE_FACTOR := 2 # Don't remember where I set this

const STATION = preload("res://scenes/station.tscn")
const TRAIN = preload("res://scenes/train.tscn")
const TRACK = preload("res://scenes/track.tscn")
const LIGHT = preload("res://scenes/light.tscn")
const POPUP = preload("res://scenes/popup.tscn")

@onready var terrain = $Terrain
@onready var ghost_track = $GhostTrack
@onready var ghost_station = $GhostStation
@onready var ghost_light = $GhostLight
@onready var track_creation_arrow = $TrackCreationArrow

var gui_state := Gui.State.NONE
var is_right_mouse_button_held_down := false

var start_track_location := Vector2i()
var ghost_tracks: Array[Track] = []
var ghost_track_tile_positions: Array[Vector2i] = []


var astar = AStar2D.new()
var astar_id_from_position: Dictionary[Vector2i, int] = {}

@onready var camera = $Camera2D
@onready var gui: Gui = $Gui
@onready var bank = Bank.new(gui)
@onready var track_set = TrackSet.new()
@onready var platform_set = PlatformSet.new(track_set)

var selected_platform: Platform = null

func _real_stations() -> Array[Station]:
	var stations: Array[Station] = []
	for station in get_tree().get_nodes_in_group("stations"):
		if station is Station and !station.is_ghost:
			stations.append(station)
	return stations


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


func _ready():
	# TODO: do not expose Gui innards this way
	$Gui/HBoxContainer/TrackButton.connect("toggled", _on_trackbutton_toggled)
	$Gui/HBoxContainer/StationButton.connect("toggled", _on_stationbutton_toggled)
	$Gui/HBoxContainer/TrainButton.connect("toggled", _on_trainbutton_toggled)
	$Gui/HBoxContainer/LightButton.connect("toggled", _on_lightbutton_toggled)
	$Gui/HBoxContainer/DestroyButton.connect("toggled", _on_destroybutton_toggled)
	$Timer.connect("timeout", _on_timer_timeout)
	track_creation_arrow.visible = false


func _unhandled_input(event: InputEvent) -> void:
	var snapped_mouse_position = Vector2i(get_local_mouse_position().snapped(Global.TILE))
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			match gui_state:
				Gui.State.TRACK1:
					_change_gui_state(Gui.State.TRACK2)
					start_track_location = snapped_mouse_position
					ghost_track.visible = false
				Gui.State.TRACK2:
					if snapped_mouse_position == start_track_location:
						_change_gui_state(Gui.State.TRACK1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_mouse_button_held_down = event.is_pressed()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and not event.is_echo():
			camera.zoom_camera(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not event.is_echo():
			camera.zoom_camera(1 / 1.1)
	
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		match gui_state:
			Gui.State.TRACK2:
				if snapped_mouse_position != start_track_location:
					_try_create_tracks()
					ghost_track.visible = true
					_change_gui_state(Gui.State.TRACK1)
			Gui.State.STATION:
				_try_create_station(snapped_mouse_position)
			Gui.State.LIGHT:
				_create_light(snapped_mouse_position)
	
	elif event is InputEventMouseMotion:
		ghost_track.position = snapped_mouse_position
		ghost_station.position = snapped_mouse_position
		ghost_light.position = snapped_mouse_position

		if gui_state == Gui.State.TRACK2:
			var new_ghost_track_tile_positions = _positions_between(start_track_location, snapped_mouse_position)
			track_creation_arrow.position = start_track_location
			track_creation_arrow.visible = (len(new_ghost_track_tile_positions) == 1)
			if new_ghost_track_tile_positions != ghost_track_tile_positions:
				_show_ghost_track(new_ghost_track_tile_positions)

		if gui_state == Gui.State.STATION:
			ghost_station.set_color(true, _is_legal_station_position(snapped_mouse_position))
		if is_right_mouse_button_held_down:
			camera.position -= event.get_relative() / camera.zoom.x
		

	elif event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_1:
				_change_gui_state(Gui.State.TRACK1)
			KEY_2:
				_change_gui_state(Gui.State.STATION)
			KEY_3:
				_change_gui_state(Gui.State.TRAIN1)
			KEY_4:
				_change_gui_state(Gui.State.DESTROY)
			

	if OS.is_debug_build() and event is InputEventKey and event.is_pressed() and event.keycode == KEY_X:
		bank.earn(10000)
			

#######################################################################

func _show_ghost_track(positions: Array[Vector2i]):
	ghost_track_tile_positions = positions
	for track in ghost_tracks:
		track.queue_free()
	ghost_tracks.clear()
	for i in len(ghost_track_tile_positions) - 1:
		var pos1 = ghost_track_tile_positions[i]
		var pos2 = ghost_track_tile_positions[i + 1]
		var track := Track.create(pos1, pos2)
		# TODO: add other stuff beside walls here
		var is_allowed = (pos1 not in terrain.obstacle_position_set and pos2 not in terrain.obstacle_position_set)
		track.set_color(true, is_allowed)
		var midway_position = Vector2(pos1).lerp(pos2, 0.5)
		track.position = midway_position
		ghost_tracks.append(track)
		$".".add_child(track)

func _reset_ghost_tracks():
	for track in ghost_tracks:
		track.queue_free()
	ghost_tracks.clear()


func _try_create_tracks():
	if len(ghost_track_tile_positions) < 2:
		# Creating 0 tracks can have some strange consequences, for example an
		# astar point will be created at the position, and the position will be
		# evaluated for platforms, etc.
		return
	if not bank.can_afford(Global.Asset.TRACK, len(ghost_tracks)):
		_reset_ghost_tracks()
		return

	for ghost_track_tile_position in ghost_track_tile_positions:
		if Vector2i(ghost_track_tile_position) in terrain.obstacle_position_set:
			_reset_ghost_tracks()
			return
	
	for track in ghost_tracks:
		if track_set.exists(track):
			track.queue_free()
		else:
			track_set.add(track)
			track.set_color(false, true)
			track.track_clicked.connect(_track_clicked)
	var ids = []
	for ghost_track_position in ghost_track_tile_positions:
		_add_position_to_astar(ghost_track_position)
		ids.append(astar_id_from_position[ghost_track_position])
	for i in range(1, len(ids)):
		astar.connect_points(ids[i - 1], ids[i])
	bank.buy(Global.Asset.TRACK, len(ghost_tracks))
	platform_set.destroy_and_recreate_connected_platforms(ghost_track_tile_positions, _real_stations(), _create_platform)
	ghost_tracks.clear()

func _add_position_to_astar(new_position: Vector2i):
	if not new_position in astar_id_from_position:
		var id = astar.get_available_point_id()
		astar_id_from_position[new_position] = id
		astar.add_point(id, new_position)

func _track_clicked(track: Track):
	if gui_state == Gui.State.DESTROY:
		astar.disconnect_points(astar_id_from_position[track.pos1], astar_id_from_position[track.pos2])
		track_set.erase(track)
		bank.destroy(Global.Asset.TRACK)
		platform_set.destroy_and_recreate_connected_platforms([track.pos1, track.pos2], _real_stations(), _create_platform)
##################################################################

func _on_trackbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.TRACK1)

func _on_stationbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.STATION)

func _on_trainbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.TRAIN1)
	
func _on_lightbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.LIGHT)

func _on_destroybutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.DESTROY)


func _change_gui_state(new_state: Gui.State):
	ghost_track.visible = false
	ghost_station.visible = false
	ghost_light.visible = false

	# Set platform colors
	if new_state == Gui.State.TRAIN1:
		for platform: Platform in get_tree().get_nodes_in_group("platforms"):
			platform.modulate = Color(0, 1, 0, 1)
	elif new_state == Gui.State.TRAIN2:
		# Platform colors handled elsewhere
		pass
	else:
		for platform: Platform in get_tree().get_nodes_in_group("platforms"):
			platform.modulate = Color(1, 1, 1, 1)
		
	if new_state == Gui.State.TRACK1:
		ghost_track.visible = true
	elif new_state == Gui.State.STATION:
		ghost_station.visible = true
	elif new_state == Gui.State.LIGHT:
		ghost_light.visible = true

	if new_state != Gui.State.TRACK1:
		_reset_ghost_tracks()
	if new_state != Gui.State.TRACK2:
		track_creation_arrow.visible = false
	
	gui.set_pressed_no_signal(new_state)

	gui_state = new_state

###################################################################

func _is_legal_station_position(station_position: Vector2i):
	return (station_position not in terrain.obstacle_position_set and
			station_position not in _real_stations() and
			track_set.get_track_count(station_position) == 0)
			
func _try_create_station(station_position: Vector2i):
	if not _is_legal_station_position(station_position):
		return
	if not bank.can_afford(Global.Asset.STATION):
		return
	var station = STATION.instantiate()
	station.position = station_position
	station.station_clicked.connect(_station_clicked)
	add_child(station)
	bank.buy(Global.Asset.STATION)
	platform_set.create_platforms([station], _create_platform)

func _station_clicked(station: Station):
	if gui_state == Gui.State.DESTROY:
		platform_set.remove_adjacent_platforms(station, _real_stations())

		station.queue_free()
		bank.destroy(Global.Asset.STATION)

func _platform_clicked(platform: Platform):
	if gui_state == Gui.State.TRAIN1:
		var id1 = astar_id_from_position[Vector2i(platform.position)]
		for other_platform: Platform in get_tree().get_nodes_in_group("platforms"):
			other_platform.modulate = Color(1, 1, 1, 1)
			if not platform_set.are_connected(platform, other_platform):
				var id2 = astar_id_from_position[Vector2i(other_platform.position)]
				if astar.get_point_path(id1, id2):
					other_platform.modulate = Color(0, 1, 0, 1)
		selected_platform = platform
		_change_gui_state(Gui.State.TRAIN2)
	elif gui_state == Gui.State.TRAIN2:
		_try_create_train(selected_platform, platform)
		_change_gui_state(Gui.State.TRAIN1)

func _try_create_train(platform1: Platform, platform2: Platform):
	if not bank.can_afford(Global.Asset.TRAIN):
		return
	if platform_set.are_connected(platform1, platform2):
		return

	# Get path from the beginning of the first platform to the end
	# of the target platform
	var point_paths: Array[PackedVector2Array] = []
	for p1 in platform_set.platform_endpoints(platform1.position):
		for p2 in platform_set.platform_endpoints(platform2.position):
			var id1 = astar_id_from_position[Vector2i(p1)]
			var id2 = astar_id_from_position[Vector2i(p2)]
			point_paths.append(astar.get_point_path(id1, id2))
	point_paths.sort_custom(func(a, b): return len(a) < len(b))

	var train = TRAIN.instantiate()
	train.set_path(point_paths[-1])
	train.wagon_count = min(platform_set.platform_size(platform1.position), platform_set.platform_size(platform2.position)) - 1
	train.end_reached.connect(_on_train_reaches_end)
	add_child(train)
	bank.buy(Global.Asset.TRAIN)
	_on_train_reaches_end(train, platform1.position, false)

	
###################################################################

func _create_light(light_position: Vector2):
	var light = LIGHT.instantiate()
	light.position = light_position
	light.light_clicked.connect(_light_clicked)
	add_child(light)

func _light_clicked(light: Light):
	if gui_state == Gui.State.DESTROY:
		light.queue_free()


######################################################################
	
func _on_timer_timeout():
	for station: Station in _real_stations():
		station.extract_ore()

######################################################################
	
func _on_train_reaches_end(train: Train, platform_position: Vector2i, turn_around: bool):
	# turn_around needed if the train has arrived at a terminus station
	for station in platform_set.stations_connected_to_platform(platform_position, _real_stations()):
		while station.ore > 0 and train.ore() < train.max_capacity():
			station.remove_ore()
			await train.add_ore(Ore.OreType.COAL)
		for factory in get_tree().get_nodes_in_group("factories"):
			if Global.is_orthogonally_adjacent(factory.get_global_position(), station.position):
				if train.ore() > 0:
					_show_popup("$%s" % train.ore(), train.get_train_position())
				bank.earn(train.ore())
				await train.remove_all_ore()
	train.start_from_station(turn_around)

func _show_popup(text: String, pos: Vector2):
	var popup = POPUP.instantiate()
	popup.position = pos
	add_child(popup)
	popup.show_popup(text)


######################################################################

# Called by PlatformSet
func _create_platform(platform: Platform):
	platform.platform_clicked.connect(_platform_clicked)
	add_child(platform)
