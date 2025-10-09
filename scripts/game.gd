extends Node2D

class_name Game

const SCALE_FACTOR := 2 # Don't remember where I set this

const STATION = preload("res://scenes/station.tscn")
const TRAIN = preload("res://scenes/train.tscn")
const TRACK = preload("res://scenes/track.tscn")
const LIGHT = preload("res://scenes/light.tscn")
const POPUP = preload("res://scenes/popup.tscn")
const DESTROY_MARKER = preload("res://scenes/destroy_marker.tscn")

@onready var terrain = $Terrain
@onready var ghost_track = $GhostTrack
@onready var ghost_station = $GhostStation
@onready var ghost_light = $GhostLight
@onready var track_creation_arrow = $TrackCreationArrow

var gui_state := Gui.State.NONE
var is_right_mouse_button_held_down := false

var mouse_down_position := Vector2i()
var ghost_tracks: Array[Track] = []
# TODO: remove ghost_track_tile_positions and just use ghost_tracks
var ghost_track_tile_positions: Array[Vector2i] = []

var destroy_markers: Array[Polygon2D] = []
var trains_marked_for_destruction_set: Dictionary[Train, int] = {}

var astar = AStar2D.new()
var astar_id_from_position: Dictionary[Vector2i, int] = {}

@onready var camera = $Camera2D
@onready var gui: Gui = $Gui
@onready var track_set = TrackSet.new()
@onready var platform_tile_set = PlatformTileSet.new(track_set)
@onready var track_reservations = TrackReservations.new()

var selected_platform_tile: PlatformTile = null

var follow_train: Train = null

func _process(_delta: float) -> void:
	if follow_train:
		camera.position = follow_train.get_train_position()

	if gui_state == Gui.State.DESTROY2:
		_mark_trains_for_destruction()
	else:
		trains_marked_for_destruction_set.clear()

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
	$Gui/HBoxContainer/StationButton.connect("toggled", _on_stationbutton_toggled)
	$Gui/HBoxContainer/TrainButton.connect("toggled", _on_trainbutton_toggled)
	$Gui/HBoxContainer/LightButton.connect("toggled", _on_lightbutton_toggled)
	$Gui/HBoxContainer/DestroyButton.connect("toggled", _on_destroybutton_toggled)
	$Gui/HBoxContainer/FollowTrainButton.connect("toggled", _on_followtrainbutton_toggled)
	$Timer.connect("timeout", _on_timer_timeout)
	# Remove ghost station from groups so that it does begin to gather ore etc
	ghost_station.remove_from_group("stations")
	ghost_station.remove_from_group("buildings")

	track_creation_arrow.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var snapped_mouse_position = _get_snapped_mouse_position(event)
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			match gui_state:
				Gui.State.TRACK1:
					_change_gui_state(Gui.State.TRACK2)
					mouse_down_position = snapped_mouse_position
					ghost_track.visible = false
					track_creation_arrow.position = snapped_mouse_position
					track_creation_arrow.visible = true
				Gui.State.TRACK2:
					if snapped_mouse_position == mouse_down_position:
						_change_gui_state(Gui.State.TRACK1)
					else:
						print("new one")
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
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not event.is_echo():
			camera.zoom_camera(1 / 1.1)
	
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		var snapped_mouse_position = _get_snapped_mouse_position(event)
		match gui_state:
			Gui.State.TRACK2:
				if snapped_mouse_position != mouse_down_position:
					print("old one")
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
			track_creation_arrow.visible = (len(new_ghost_track_tile_positions) == 1)
			if new_ghost_track_tile_positions != ghost_track_tile_positions:
				_show_ghost_track(new_ghost_track_tile_positions)
		if gui_state == Gui.State.STATION:
			ghost_station.set_color(true, _is_legal_station_position(snapped_mouse_position))
		if gui_state == Gui.State.DESTROY1:
			_show_destroy_markers(snapped_mouse_position, snapped_mouse_position)
		if gui_state == Gui.State.DESTROY2:
			_show_destroy_markers(mouse_down_position, snapped_mouse_position)
		if is_right_mouse_button_held_down:
			follow_train = null
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
				_change_gui_state(Gui.State.DESTROY1)
			

	if OS.is_debug_build() and event is InputEventKey and event.is_pressed() and event.keycode == KEY_X:
		GlobalBank.earn(10000)

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
	var ids = []
	for ghost_track_position in ghost_track_tile_positions:
		_add_position_to_astar(ghost_track_position)
		ids.append(astar_id_from_position[ghost_track_position])
	for i in range(1, len(ids)):
		astar.connect_points(ids[i - 1], ids[i])
	GlobalBank.buy(Global.Asset.TRACK, len(ghost_tracks))
	platform_tile_set.destroy_and_recreate_platform_tiles_orthogonally_linked_to(ghost_track_tile_positions, _get_stations(), _create_platform_tile)
	ghost_tracks.clear()

func _reset_ghost_tracks():
	for track in ghost_tracks:
		track.queue_free()
	ghost_tracks.clear()

func _add_position_to_astar(new_position: Vector2i):
	if not new_position in astar_id_from_position:
		var id = astar.get_available_point_id()
		astar_id_from_position[new_position] = id
		astar.add_point(id, new_position)

func _destroy_track(positions: Array[Vector2i]):
	var track_positions: Dictionary[Vector2i, int] = {}
	for pos in positions:
		for track in track_set.tracks_at_position(pos).duplicate():
			astar.disconnect_points(astar_id_from_position[track.pos1], astar_id_from_position[track.pos2])
			GlobalBank.destroy(Global.Asset.TRACK)
			track_positions[track.pos1] = 0
			track_positions[track.pos2] = 0
			track_set.erase(track)
	# Might not work, since we have already removed the tracks?
	platform_tile_set.destroy_and_recreate_platform_tiles_orthogonally_linked_to(track_positions.keys(), _get_stations(), _create_platform_tile)

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
		_change_gui_state(Gui.State.DESTROY1)

func _on_followtrainbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.FOLLOW_TRAIN)


func _change_gui_state(new_state: Gui.State):
	ghost_track.visible = false
	ghost_station.visible = false
	ghost_light.visible = false

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
	elif new_state == Gui.State.STATION:
		ghost_station.visible = true
	elif new_state == Gui.State.LIGHT:
		ghost_light.visible = true

	if new_state != Gui.State.TRACK1:
		_reset_ghost_tracks()
	if new_state != Gui.State.TRACK2:
		track_creation_arrow.visible = false
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
	GlobalBank.buy(Global.Asset.STATION)
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
		var id1 = astar_id_from_position[Vector2i(platform_tile.position)]
		for other_platform: PlatformTile in get_tree().get_nodes_in_group("platforms"):
			other_platform.modulate = Color(1, 1, 1, 1)
			if not platform_tile_set.are_connected(platform_tile, other_platform):
				var id2 = astar_id_from_position[Vector2i(other_platform.position)]
				if astar.get_point_path(id1, id2):
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
	GlobalBank.buy(Global.Asset.TRAIN)

	var train = TRAIN.instantiate()
	train.wagon_count = min(platform_tile_set.platform_size(platform1.position), platform_tile_set.platform_size(platform2.position)) - 1

	# Get path from the beginning of the first tile of the source platform
	# to the last tile of the target platform
	# TODO: change to between platforms instead
	# TODO: this does not take reserved spaces into account, so will likely lead to crash
	var point_path = _get_point_path_between_platforms(platform1.position, platform2.position)

	if not point_path:
		return

	train.end_of_curve_reached.connect(_on_train_reaches_end_of_curve)
	train.train_clicked.connect(_on_train_clicked)
	add_child(train)

	train.destinations = [point_path[0], point_path[-1]] as Array[Vector2i]
	train.set_new_curve_from_platform(point_path, platform_tile_set.connected_ordered_platform_tile_positions(point_path[0], point_path[0]))
	_on_train_reaches_end_of_curve(train)

func _on_train_reaches_end_of_curve(train: Train):
	var tile_position = Vector2i(train.get_train_position().snapped(Global.TILE))
	var is_at_target_platform = is_furthest_in_at_target_platform(train)

	if is_at_target_platform:
		train.target_speed = 0.0
		train.absolute_speed = 0.0
		train.is_stopped = true
		await _load_and_unload(train)
		train.destination_index += 1
		train.destination_index %= len(train.destinations)

	var target_position = train.destinations[train.destination_index]

	var point_path: PackedVector2Array
	while true:
		var new_astar = clone_astar(astar)
		# Set wagon positions to disabled to prevent turnaround.
		var is_turnaround_allowed = is_at_target_platform
		if not is_turnaround_allowed:
			for wagon_position in train.get_wagon_positions():
				new_astar.set_point_disabled(astar_id_from_position[Vector2i(wagon_position)])

		point_path = _get_point_path(tile_position, target_position, new_astar)
		# If we are close to the station we will skip this
		if point_path and len(point_path) > 2:
			# If the tile after the next is reserved, choose another path
			while track_reservations.is_reserved_by_another_train(point_path[2], train):
				var reserved_position := astar_id_from_position[Vector2i(point_path[2])]
				new_astar = clone_astar(new_astar)
				new_astar.set_point_disabled(reserved_position, true)
				point_path = _get_point_path(tile_position, target_position, new_astar)
				if not point_path:
					break
		if point_path:
			break
		_show_popup("Cannot find route!", train.get_train_position())
		train.no_route_timer.start()
		train.target_speed = 0.0
		train.absolute_speed = 0.0
		train.is_stopped = true
		await train.no_route_timer.timeout

	var positions_to_reserve: Array[Vector2i] = []
	for pos in train.get_wagon_positions():
		positions_to_reserve.append(Vector2i(pos))
	positions_to_reserve.append(Vector2i(point_path[0]))
	if len(point_path) > 1:
		positions_to_reserve.append(Vector2i(point_path[1]))
	var segments_to_reserve = track_set.get_segments_connected_to_positions(positions_to_reserve)
	var is_reservation_successful = track_reservations.reserve_train_positions(segments_to_reserve, train)
	while not is_reservation_successful:
		_show_popup("Blocked!", train.get_train_position())
		train.no_route_timer.start()
		train.target_speed = 0.0
		train.absolute_speed = 0.0
		train.is_stopped = true
		await train.no_route_timer.timeout
		is_reservation_successful = track_reservations.reserve_train_positions(positions_to_reserve, train)

	if is_at_target_platform:
		# TODO: break out add_next_point_to_curve from this
		train.set_new_curve_from_platform(point_path, platform_tile_set.connected_ordered_platform_tile_positions(tile_position, tile_position))
	else:
		train.add_next_point_to_curve(point_path)
	if train.is_stopped:
		train.is_stopped = false
		train.target_speed = train.max_speed

func clone_astar(original: AStar2D) -> AStar2D:
	var clone = AStar2D.new()

	# Copy all points
	for id in original.get_point_ids():
		var pos = original.get_point_position(id)
		var weight = original.get_point_weight_scale(id)
		clone.add_point(id, pos, weight)

	# Copy all connections
	for id in original.get_point_ids():
		for neighbor in original.get_point_connections(id):
			if not clone.are_points_connected(id, neighbor):
				clone.connect_points(id, neighbor)

	# Copy disabled status
	for id in original.get_point_ids():
		if original.is_point_disabled(id):
			clone.set_point_disabled(id, true)

	return clone
	
## This method assumes the train has wagons, otherwise it will never stop
func is_furthest_in_at_target_platform(train: Train) -> bool:
	var tile_position = Vector2i(train.get_train_position().snapped(Global.TILE))
	var target_position = train.destinations[train.destination_index]
	var connected_platform_positions = platform_tile_set.connected_platform_tile_positions(tile_position)
	if not target_position in connected_platform_positions:
		return false
	if not tile_position in platform_tile_set.platform_endpoints(tile_position):
		return false
	for wagon_position in train.get_wagon_positions():
		if Vector2i(wagon_position) in connected_platform_positions:
			return true
	return false


func _load_and_unload(train: Train):
	var train_position = train.get_train_position().snapped(Global.TILE)
	var reversed_wagons_at_platform: Array[Wagon] = []
	for i in train.wagon_count:
		var wagon = train.wagons[-i - 1]
		if Vector2i(wagon.get_wagon_position().snapped(Global.TILE)) in platform_tile_set.connected_platform_tile_positions(train_position):
			reversed_wagons_at_platform.append(wagon)
	for station in platform_tile_set.stations_connected_to_platform(train_position, _get_stations()):
		for consumer in get_tree().get_nodes_in_group("resource_consumers"):
			if not Global.is_orthogonally_adjacent(consumer.get_global_position(), station.position):
				continue
			for wagon in reversed_wagons_at_platform:
				for ore_type in consumer.consumes:
					var ore_count = wagon.get_ore_count(ore_type)
					if ore_count > 0:
						_show_popup("$%s" % ore_count, train.get_train_position())
					GlobalBank.earn(ore_count)
					await wagon.remove_all_ore(ore_type)
		for wagon in reversed_wagons_at_platform:
			while station.get_total_ore_count() > 0 and wagon.get_total_ore_count() < wagon.max_capacity:
				var ore_type = station.remove_ore()
				await wagon.add_ore(ore_type)


func _mark_trains_for_destruction():
	for train in get_tree().get_nodes_in_group("trains"):
		var train_marked_for_destruction = false
		var train_position = Vector2i(train.get_train_position().snapped(Global.TILE))
		for marker in destroy_markers:
			if Vector2i(marker.position) == train_position:
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
			point_paths.append(_get_point_path(p1, p2))
	point_paths.sort_custom(func(a, b): return len(a) < len(b))
	return point_paths[-1]

func _get_point_path(pos1: Vector2i, pos2: Vector2i, astar_: AStar2D = astar) -> PackedVector2Array:
	# print("_get_point_path(%s, %s)" % [pos1, pos2])
	var id1 = astar_id_from_position[Vector2i(pos1)]
	var id2 = astar_id_from_position[Vector2i(pos2)]
	return astar_.get_point_path(id1, id2)


###################################################################################

func _show_popup(text: String, pos: Vector2):
	var popup = POPUP.instantiate()
	popup.position = pos
	add_child(popup)
	popup.show_popup(text)

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
	for station: Station in _get_stations():
		station.extract_ore()

######################################################################
