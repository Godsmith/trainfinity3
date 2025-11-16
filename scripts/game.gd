extends Node2D

class_name Game

const SCALE_FACTOR := 2 # Don't remember where I set this

const STATION = preload("res://scenes/station.tscn")
const TRACK = preload("res://scenes/track.tscn")
const LIGHT = preload("res://scenes/light.tscn")
const DESTROY_MARKER = preload("res://scenes/destroy_marker.tscn")

@onready var terrain = $Terrain
@onready var ghost_track = $GhostTrack
@onready var ghost_station = $GhostStation
@onready var ghost_light = $GhostLight

var gui_state := Gui.State.NONE
var is_right_mouse_button_held_down := false

var mouse_down_position := Vector2i()
var ghost_tracks: Array[Track] = []
# TODO: remove ghost_track_tile_positions and just use ghost_tracks
var ghost_track_tile_positions: Array[Vector2i] = []

var destroy_markers: Array[Polygon2D] = []
var trains_marked_for_destruction_set: Dictionary[Train, int] = {}

var astar = Astar.new()

@onready var camera = $Camera2D
@onready var gui: Gui = $Gui
@onready var track_set = TrackSet.new()
@onready var platform_tile_set = PlatformTileSet.new(track_set)
@onready var track_reservations = TrackReservations.new()

var selected_platform_tile: PlatformTile = null

var follow_train: Train = null

var reservation_markers: Array[Polygon2D] = []
var time_since_last_reservation_refresh := 0.0
var show_reservation_markers := false

var current_tile_marker: Line2D

func _process(delta: float) -> void:
	if follow_train:
		camera.position = follow_train.get_train_position()

	if gui_state == Gui.State.DESTROY2:
		_mark_trains_for_destruction()
	else:
		trains_marked_for_destruction_set.clear()

	_show_reservations(delta)


func _show_reservations(delta):
	time_since_last_reservation_refresh += delta
	if time_since_last_reservation_refresh > 1.0:
		time_since_last_reservation_refresh = 0.0
		for marker in reservation_markers:
			marker.queue_free()
		reservation_markers.clear()
		if show_reservation_markers:
			for pos in track_reservations.reservations:
				var marker = DESTROY_MARKER.instantiate()
				marker.color = track_reservations.reservations[pos].reservation_color
				marker.position = pos
				reservation_markers.append(marker)
				add_child(marker)


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
	GlobalBank.gui = gui
	GlobalBank.update_gui()
	# TODO: do not expose Gui innards this way
	$Gui/HBoxContainer/TrackButton.connect("toggled", _on_trackbutton_toggled)
	$Gui/HBoxContainer/OneWayTrackButton.connect("toggled", _on_onewaytrackbutton_toggled)
	$Gui/HBoxContainer/StationButton.connect("toggled", _on_stationbutton_toggled)
	$Gui/HBoxContainer/TrainButton.connect("toggled", _on_trainbutton_toggled)
	$Gui/HBoxContainer/LightButton.connect("toggled", _on_lightbutton_toggled)
	$Gui/HBoxContainer/DestroyButton.connect("toggled", _on_destroybutton_toggled)
	$Gui/HBoxContainer/FollowTrainButton.connect("toggled", _on_followtrainbutton_toggled)
	$Gui/HBoxContainer/SaveButton.connect("pressed", _on_savebutton_pressed)
	$Gui/HBoxContainer/LoadButton.connect("pressed", _on_loadbutton_pressed)
	$Timer.connect("timeout", _on_timer_timeout)
	# Remove ghost station from groups so that it does begin to gather ore etc
	ghost_station.remove_from_group("stations")
	ghost_station.remove_from_group("buildings")

	current_tile_marker = Line2D.new()
	current_tile_marker.width = 2
	current_tile_marker.default_color = Color(0, 0, 0, 0.2)
	current_tile_marker.visible = false
	add_child(current_tile_marker)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var snapped_mouse_position = _get_snapped_mouse_position(event)
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			match gui_state:
				Gui.State.TRACK1:
					_change_gui_state(Gui.State.TRACK2)
					mouse_down_position = snapped_mouse_position
					ghost_track.visible = false
					_show_current_tile_marker(snapped_mouse_position)
					current_tile_marker.visible = true
				Gui.State.TRACK2:
					if snapped_mouse_position == mouse_down_position:
						_change_gui_state(Gui.State.TRACK1)
					else:
						_try_create_tracks()
						ghost_track.visible = true
						_change_gui_state(Gui.State.TRACK1)
				Gui.State.DESTROY1:
					mouse_down_position = snapped_mouse_position
					_change_gui_state(Gui.State.DESTROY2)
					_show_destroy_markers(mouse_down_position, snapped_mouse_position)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_mouse_button_held_down = event.is_pressed()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and not event.is_echo():
			camera.zoom_camera(1.1)
			_restrict_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not event.is_echo():
			camera.zoom_camera(1 / 1.1)
			_restrict_camera()
	
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		var snapped_mouse_position = _get_snapped_mouse_position(event)
		match gui_state:
			Gui.State.TRACK2:
				if snapped_mouse_position != mouse_down_position:
					_try_create_tracks()
					ghost_track.visible = true
					_change_gui_state(Gui.State.TRACK1)
			Gui.State.STATION:
				_try_create_station(snapped_mouse_position)
			Gui.State.LIGHT:
				_create_light(snapped_mouse_position)
			Gui.State.DESTROY2:
				_destroy_under_destroy_markers()
				_hide_destroy_markers()
				_change_gui_state(Gui.State.DESTROY1)
	
	elif event is InputEventMouseMotion:
		var snapped_mouse_position = _get_snapped_mouse_position(event)
		ghost_track.position = snapped_mouse_position
		ghost_station.position = snapped_mouse_position
		ghost_light.position = snapped_mouse_position

		if gui_state == Gui.State.TRACK2:
			var new_ghost_track_tile_positions = _positions_between(mouse_down_position, snapped_mouse_position)
			if new_ghost_track_tile_positions != ghost_track_tile_positions:
				_show_ghost_track(new_ghost_track_tile_positions)
			_show_current_tile_marker(snapped_mouse_position)

		if gui_state == Gui.State.STATION:
			ghost_station.set_color(true, _is_legal_station_position(snapped_mouse_position))
		if gui_state == Gui.State.DESTROY1:
			_show_destroy_markers(snapped_mouse_position, snapped_mouse_position)
		if gui_state == Gui.State.DESTROY2:
			_show_destroy_markers(mouse_down_position, snapped_mouse_position)
		if is_right_mouse_button_held_down:
			follow_train = null
			camera.position -= event.get_relative() / camera.zoom.x
			_restrict_camera()

	elif event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_1:
				_change_gui_state(Gui.State.TRACK1)
			KEY_2:
				_change_gui_state(Gui.State.STATION)
			KEY_3:
				_change_gui_state(Gui.State.TRAIN1)
			KEY_4:
				_change_gui_state(Gui.State.DESTROY1)
			

	if OS.is_debug_build() and event is InputEventKey and event.is_pressed() and event.keycode == KEY_X:
		GlobalBank.earn(10000)

	if OS.is_debug_build() and event is InputEventKey and event.is_pressed() and event.keycode == KEY_C:
		show_reservation_markers = !show_reservation_markers

func _show_current_tile_marker(pos: Vector2i):
	current_tile_marker.clear_points()
	var x = pos.x - Global.TILE_SIZE / 2
	var y = pos.y - Global.TILE_SIZE / 2
	current_tile_marker.add_point(Vector2(x, y))
	current_tile_marker.add_point(Vector2(x + Global.TILE_SIZE, y))
	current_tile_marker.add_point(Vector2(x + Global.TILE_SIZE, y + Global.TILE_SIZE))
	current_tile_marker.add_point(Vector2(x, y + Global.TILE_SIZE))
	current_tile_marker.add_point(Vector2(x, y))


func _restrict_camera():
	var viewport_size := get_viewport_rect().size
	var center = camera.get_screen_center_position()
	var zoom = camera.zoom

	var half_width = (viewport_size.x * 0.5) / zoom.x
	var half_height = (viewport_size.y * 0.5) / zoom.y

	var left = center.x - half_width
	var right = center.x + half_width
	var top = center.y - half_height
	var bottom = center.y + half_height

	var margin = Terrain.CHUNK_WIDTH * Global.TILE_SIZE
	var min_x = terrain.boundaries.position.x - margin
	var max_x = terrain.boundaries.end.x + margin
	var min_y = terrain.boundaries.position.y - margin
	var max_y = terrain.boundaries.end.y + margin

	# If we have zoomed out so far that we spill over both edges, zoom in again
	if (left < min_x and right > max_x) or (top < min_y and bottom > max_y):
		camera.zoom_camera(1.1)
		return

	# Otherwise, bounce camera position back in-bound
	var dx = 0
	var dy = 0
	if left < min_x:
		dx += min_x - left
	if right > max_x:
		dx += max_x - right
	if top < min_y:
		dy += min_y - top
	if bottom > max_y:
		dy += max_y - bottom
	camera.global_position.x += dx
	camera.global_position.y += dy


func _get_snapped_mouse_position(event: InputEventMouse):
	# This is equivalent to doing get_local_mouse_position(), but I wanted to use the
	# mouse position from the InputEventMouse object
	return Vector2i((camera.get_canvas_transform().affine_inverse() * event.position).snapped(Global.TILE))

#######################################################################

func _show_ghost_track(positions: Array[Vector2i]):
	ghost_track_tile_positions = positions
	for track in ghost_tracks:
		track.queue_free()
	ghost_tracks.clear()
	var illegal_positions = _illegal_track_positions(positions)
	for i in len(ghost_track_tile_positions) - 1:
		var pos1 = ghost_track_tile_positions[i]
		var pos2 = ghost_track_tile_positions[i + 1]
		var track := Track.create(pos1, pos2)
		var is_allowed = (pos1 not in illegal_positions and
						  pos2 not in illegal_positions)
		track.set_allowed(is_allowed)
		track.set_ghostly(true)
		var midway_position = Vector2(pos1).lerp(pos2, 0.5)
		track.position = midway_position
		ghost_tracks.append(track)
		$".".add_child(track)

func _illegal_track_positions(positions: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos in positions:
		if pos in terrain.obstacle_position_set:
			out.append(pos)
	for node in get_tree().get_nodes_in_group("buildings"):
		if Vector2i(node.position) in positions:
			out.append(Vector2i(node.position))
	return out

func _try_create_tracks():
	if len(ghost_track_tile_positions) < 2:
		# Creating 0 tracks can have some strange consequences, for example an
		# astar point will be created at the position, and the position will be
		# evaluated for platforms, etc.
		return
	if not GlobalBank.can_afford(Global.Asset.TRACK, len(ghost_tracks)):
		_reset_ghost_tracks()
		return

	if ghost_tracks.any(func(x): return not x.is_allowed):
		_reset_ghost_tracks()
		return
	
	for track in ghost_tracks:
		if track_set.exists(track):
			track.queue_free()
		else:
			track_set.add(track)
			track.set_ghostly(false)
		track.track_clicked.connect(_on_track_clicked)
	for ghost_track_position in ghost_track_tile_positions:
		astar.add_position(ghost_track_position)
	for i in range(1, len(ghost_track_tile_positions)):
		astar.connect_positions(ghost_track_tile_positions[i - 1], ghost_track_tile_positions[i])
	GlobalBank.buy(Global.Asset.TRACK, len(ghost_tracks), ghost_tracks[-1].global_position)
	platform_tile_set.destroy_and_recreate_platform_tiles_orthogonally_linked_to(ghost_track_tile_positions, _get_stations(), _create_platform_tile)
	Events.track_reservations_updated.emit()
	ghost_tracks.clear()

func _reset_ghost_tracks():
	for track in ghost_tracks:
		track.queue_free()
	ghost_tracks.clear()

func _destroy_track(positions: Array[Vector2i]):
	var track_positions: Dictionary[Vector2i, int] = {}
	for pos in positions:
		for track in track_set.tracks_at_position(pos).duplicate():
			astar.disconnect_positions(track.pos1, track.pos2)
			GlobalBank.destroy(Global.Asset.TRACK)
			track_positions[track.pos1] = 0
			track_positions[track.pos2] = 0
			track_set.erase(track)
	# Might not work, since we have already removed the tracks?
	platform_tile_set.destroy_and_recreate_platform_tiles_orthogonally_linked_to(track_positions.keys(), _get_stations(), _create_platform_tile)
	Events.track_reservations_updated.emit()

##################################################################

func _on_track_clicked(track: Track):
	if gui_state == Gui.State.ONE_WAY_TRACK:
		track.rotate_one_way_direction()
		astar.disconnect_positions(track.pos1, track.pos2)
		match track.direction:
			track.Direction.BOTH:
				astar.connect_positions(track.pos1, track.pos2)
			track.Direction.POS1_TO_POS2:
				astar.connect_positions(track.pos1, track.pos2, false)
			track.Direction.POS2_TO_POS1:
				astar.connect_positions(track.pos2, track.pos1, false)
		Events.track_reservations_updated.emit()

##################################################################

func _on_trackbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.TRACK1)

func _on_onewaytrackbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.ONE_WAY_TRACK)

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
		_change_gui_state(Gui.State.DESTROY1)

func _on_followtrainbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.FOLLOW_TRAIN)

func _on_savebutton_pressed() -> void:
	_save_game()

func _on_loadbutton_pressed() -> void:
	_load_game()

func _change_gui_state(new_state: Gui.State):
	ghost_track.visible = false
	ghost_station.visible = false
	ghost_light.visible = false
	current_tile_marker.visible = false

	# Set platform colors
	if new_state == Gui.State.TRAIN1:
		for platform: PlatformTile in get_tree().get_nodes_in_group("platforms"):
			platform.modulate = Color(0, 1, 0, 1)
	elif new_state == Gui.State.TRAIN2:
		# PlatformTile colors handled elsewhere
		pass
	else:
		for platform: PlatformTile in get_tree().get_nodes_in_group("platforms"):
			platform.modulate = Color(1, 1, 1, 1)
		
	if new_state == Gui.State.TRACK1:
		ghost_track.visible = true
	elif new_state == Gui.State.TRACK2:
		current_tile_marker.visible = true
	elif new_state == Gui.State.STATION:
		ghost_station.visible = true
	elif new_state == Gui.State.LIGHT:
		ghost_light.visible = true

	if new_state != Gui.State.TRACK1:
		_reset_ghost_tracks()
	if new_state != Gui.State.DESTROY1:
		_hide_destroy_markers()
	
	gui.set_pressed_no_signal(new_state)

	gui_state = new_state

###################################################################

func _is_legal_station_position(station_position: Vector2i):
	for node in get_tree().get_nodes_in_group("buildings"):
		if Vector2i(node.position) == station_position:
			return false
	if station_position in terrain.obstacle_position_set:
		return false
	if track_set.has_track(station_position):
		return false
	return true
			
func _try_create_station(station_position: Vector2i):
	if not _is_legal_station_position(station_position):
		return
	if not GlobalBank.can_afford(Global.Asset.STATION):
		return
	var station = STATION.instantiate()
	station.position = station_position
	add_child(station)
	GlobalBank.buy(Global.Asset.STATION, 1, station.global_position)
	platform_tile_set.create_platform_tiles([station], _create_platform_tile)

func _destroy_stations(positions: Array[Vector2i]):
	var stations: Array[Station] = _get_stations()
	for station in stations:
		if Vector2i(station.position) in positions:
			for adjacent_position in Global.orthogonally_adjacent(station.position):
				if not track_set.has_track(adjacent_position):
					continue
				platform_tile_set.destroy_and_recreate_platform_tiles_orthogonally_linked_to(
					[adjacent_position], stations, _create_platform_tile)
			station.queue_free()
			GlobalBank.destroy(Global.Asset.STATION)

func _get_stations() -> Array[Station]:
	var stations: Array[Station] = []
	for node in get_tree().get_nodes_in_group("stations"):
		if node is Station:
			stations.append(node)
	return stations

############################################################################

func _platform_tile_clicked(platform_tile: PlatformTile):
	if gui_state == Gui.State.TRAIN1:
		for other_platform: PlatformTile in get_tree().get_nodes_in_group("platforms"):
			other_platform.modulate = Color(1, 1, 1, 1)
			if not platform_tile_set.are_connected(platform_tile, other_platform):
				if astar.get_point_path(Vector2i(platform_tile.position), Vector2i(other_platform.position)):
					other_platform.modulate = Color(0, 1, 0, 1)
		selected_platform_tile = platform_tile
		_change_gui_state(Gui.State.TRAIN2)
	elif gui_state == Gui.State.TRAIN2:
		_try_create_train(selected_platform_tile, platform_tile)
		_change_gui_state(Gui.State.TRAIN1)

############################################################################

func _try_create_train(platform1: PlatformTile, platform2: PlatformTile):
	if not GlobalBank.can_afford(Global.Asset.TRAIN):
		return
	if platform_tile_set.are_connected(platform1, platform2):
		return
	if track_reservations.is_reserved(Vector2i(platform1.position)):
		Global.show_popup("Track reserved!", platform1.position, self)
		Global.show_popup("Track reserved!", platform2.position, self)
		return

	# Get path from the beginning of the first tile of the source platform
	# to the last tile of the target platform
	var point_path = _get_point_path_between_platforms(platform1.position, platform2.position)
	if not point_path:
		return

	var wagon_count = min(platform_tile_set.platform_size(platform1.position), platform_tile_set.platform_size(platform2.position)) - 1
	var train = Train.create(wagon_count, point_path, platform_tile_set, track_set, track_reservations, astar)

	train.train_clicked.connect(_on_train_clicked)
	add_child(train)


	train.set_new_curve_from_platform(point_path, platform_tile_set.connected_ordered_platform_tile_positions(point_path[0], point_path[0]))
	train._on_train_reaches_end_of_curve()

	# Need to do this after curve has been set, or it will be in the wrong position
	GlobalBank.buy(Global.Asset.TRAIN, 1, train.get_train_position())


func _mark_trains_for_destruction():
	for train in get_tree().get_nodes_in_group("trains"):
		var train_marked_for_destruction = false
		for marker in destroy_markers:
			if train.is_train_or_wagon_at_position(Vector2i(marker.position)):
				train_marked_for_destruction = true
				break
		train.mark_for_destruction(train_marked_for_destruction)
		if train_marked_for_destruction:
			trains_marked_for_destruction_set[train as Train] = 0
		else:
			trains_marked_for_destruction_set.erase(train)


func _on_train_clicked(train: Train):
	if gui_state == Gui.State.FOLLOW_TRAIN:
		follow_train = train

###################################################################################

## Returns the point path between two platforms.
## The path returned will be the longest possible, i.e. between the opposite ends
## of the stations.
## Returns an empty path if there is no path.
func _get_point_path_between_platforms(platform_pos1: Vector2i,
									   platform_pos2: Vector2i) -> PackedVector2Array:
	var point_paths: Array[PackedVector2Array] = []
	for p1 in platform_tile_set.platform_endpoints(platform_pos1):
		for p2 in platform_tile_set.platform_endpoints(platform_pos2):
			point_paths.append(astar.get_point_path(p1, p2))
	point_paths.sort_custom(func(a, b): return len(a) < len(b))
	return point_paths[-1]

######################################################################

# Called by PlatformTileSet
func _create_platform_tile(platform_tile: PlatformTile):
	platform_tile.platform_tile_clicked.connect(_platform_tile_clicked)
	add_child(platform_tile)

######################################################################

func _show_destroy_markers(start_pos: Vector2i, end_pos: Vector2i):
	_hide_destroy_markers()
	var xs = [start_pos.x, end_pos.x]
	var ys = [start_pos.y, end_pos.y]
	xs.sort()
	ys.sort()
	for x in range(xs[0], xs[1] + 1, Global.TILE_SIZE):
		for y in range(ys[0], ys[1] + 1, Global.TILE_SIZE):
			var marker = DESTROY_MARKER.instantiate()
			marker.position = Vector2i(x, y)
			add_child(marker)
			destroy_markers.append(marker)

func _hide_destroy_markers():
	for marker in destroy_markers:
		marker.queue_free()
	destroy_markers.clear()

func _destroy_under_destroy_markers():
	var positions: Array[Vector2i] = []
	for marker in destroy_markers:
		positions.append(Vector2i(marker.position))

	var have_trains_been_destroyed = false
	for train in trains_marked_for_destruction_set:
		train.queue_free()
		GlobalBank.destroy(Global.Asset.TRAIN)
		track_reservations.clear_reservations(train)
		have_trains_been_destroyed = true
	trains_marked_for_destruction_set.clear()
	if have_trains_been_destroyed:
		# Just destroy trains first
		return

	_destroy_track(positions)
	_destroy_stations(positions)

###################################################################

func _create_light(light_position: Vector2):
	var light = LIGHT.instantiate()
	light.position = light_position
	light.light_clicked.connect(_light_clicked)
	add_child(light)

func _light_clicked(light: Light):
	# TODO: this does not work anymore
	if gui_state == Gui.State.DESTROY1:
		light.queue_free()


######################################################################
	
func _on_timer_timeout():
	var stations = _get_stations()
	for node: Node in get_tree().get_nodes_in_group("resource_producers"):
		for station: Station in _adjacent_stations(node, stations):
			# All nodes in the resource_producers group must have a property ore_type,
			# or this will crash. Would be good with a trait here.
			if not station.is_at_max_capacity():
				station.add_ore(node.ore_type, true)
	for node: Node in get_tree().get_nodes_in_group("resource_consumers"):
		for station: Station in _adjacent_stations(node, stations):
			# All nodes in the resource_consumers group must have a property consumes
			for ore_type in node.consumes:
				if station.get_ore_not_created_here_count(ore_type) > 0:
					station.remove_ore(ore_type)
	for node: Node in get_tree().get_nodes_in_group("resource_exchangers"):
		var adjacent_stations = _adjacent_stations(node, stations)
		var station_from_ore_type: Dictionary[Ore.OreType, Station] = {}
		# All nodes in the resource_exchangers group must have a property consumes
		# and a property ore_type
		for ore_type in node.consumes:
			for station: Station in adjacent_stations:
				if station.get_ore_count(ore_type) > 0:
					station_from_ore_type[ore_type] = station
					break
		# If all material is available, produce
		if len(station_from_ore_type) == len(node.consumes):
			for ore_type in station_from_ore_type:
				station_from_ore_type[ore_type].remove_ore(ore_type)
			adjacent_stations.pick_random().add_ore(node.ore_type, true)
			
######################################################################

func _adjacent_stations(node: Node, stations: Array[Station]) -> Array[Station]:
	var adjacent_stations: Array[Station]
	adjacent_stations.assign(stations.filter(func(station): return Global.is_orthogonally_adjacent(
			Vector2i(station.global_position), Vector2i(node.global_position))))
	return adjacent_stations

func _save_game():
	# Currently only saving tracks
	var data = {}
	data["tracks"] = track_set._tracks.values().map(func(t): return {"pos1": t.pos1, "pos2": t.pos2})
	#var data = JSON.stringify({"tracks": tracks.map()})

	# get_datetime_string_from_system gives strings on the form "2025-11-14 20:51:33"
	var timestamp = Time.get_datetime_string_from_system(true, true).replace(" ", "_").replace(":", "-")
	var file_path = "res://savegames/" + timestamp + ".save"
	var save_file = FileAccess.open(file_path, FileAccess.WRITE)
	save_file.store_var(data)
	save_file.close()
	print("Saved game to %s" % file_path)

func _load_game():
	# file_path is typically on the form"res://savegames/foo.save"
	var file_path = "res://savegames/2025-11-16_17-47-30.save"

	var save_file = FileAccess.open(file_path, FileAccess.READ)
	var data = save_file.get_var()
	for track_dict in data.tracks:
		_show_ghost_track([track_dict["pos1"], track_dict["pos2"]])
		_try_create_tracks()
