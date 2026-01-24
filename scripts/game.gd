extends Node2D

class_name Game

const SCALE_FACTOR := 2 # Don't remember where I set this

const STATION = preload("res://scenes/station.tscn")
const TRACK = preload("res://scenes/track.tscn")
const LIGHT = preload("res://scenes/light.tscn")
const DESTROY_MARKER = preload("res://scenes/destroy_marker.tscn")
const DEBUG_COORDINATES = preload("res://debug/debug_coordinates.tscn")

@onready var terrain := $Terrain
@onready var ghost_station := $GhostStation
@onready var ghost_light := $GhostLight

var randomizer_seed = randi()

var gui_state := Gui.State.SELECT
var is_right_mouse_button_held_down := false

var mouse_down_position := Vector2i()

var destroy_markers: Array[Polygon2D] = []
var trains_marked_for_destruction_set: Dictionary[Train, int] = {}

var astar_track = Astar.new()
var astar_terrain: AStarGrid2D

@onready var camera = $Camera2D
@onready var gui: Gui = $Gui
@onready var ore_timer := $OreTimer
@onready var track_marker_confirm := $TrackMarkerConfirm
@onready var track_set = TrackSet.new()
@onready var platform_tile_set = PlatformTileSet.new()
@onready var ghost_platform_tile_set = PlatformTileSet.new()
@onready var track_reservations = TrackReservations.new()
@onready var track_creator = TrackCreator.new(_create_tracks_from_ghost_tracks, _illegal_track_positions)

var train_start_station: Station
var selected_station: Station = null
var selected_train: Train = null

var follow_train: Train = null

var reservation_markers: Array[Polygon2D] = []
var time_since_last_reservation_refresh := 0.0
var show_reservation_markers := false

var current_tile_marker: Line2D

var destination_markers: Array[Line2D]

var previous_snapped_mouse_position := Vector2i(Global.MAX_INT, Global.MAX_INT)

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


func _ready():
	seed(randomizer_seed)

	GlobalBank.gui = gui
	GlobalBank.update_gui()

	gui.select_button.connect("toggled", _on_selectbutton_toggled)
	gui.track_button.connect("toggled", _on_trackbutton_toggled)
	gui.one_way_track_button.connect("toggled", _on_onewaytrackbutton_toggled)
	gui.station_button.connect("toggled", _on_stationbutton_toggled)
	gui.train_button.connect("toggled", _on_trainbutton_toggled)
	gui.light_button.connect("toggled", _on_lightbutton_toggled)
	gui.destroy_button.connect("toggled", _on_destroybutton_toggled)
	gui.follow_train_button.connect("pressed", _on_followtrainbutton_pressed)
	gui.save_button.connect("pressed", _on_savebutton_pressed)

	ore_timer.connect("timeout", _on_ore_timer_timeout)

	# Remove ghost station from groups so that it does begin to gather resources etc
	ghost_station.remove_from_group("stations")
	ghost_station.remove_from_group("buildings")

	current_tile_marker = Line2D.new()
	current_tile_marker.width = 2
	current_tile_marker.default_color = Color(1.0, 1.0, 1.0, 1.0)
	current_tile_marker.visible = false
	add_child(current_tile_marker)

	Events.industry_clicked.connect(_on_industry_clicked)
	Events.station_clicked.connect(_on_station_clicked)
	Events.station_content_updated.connect(_on_station_content_updated)
	Events.mouse_enters_track.connect(_on_mouse_enters_track)
	Events.mouse_exits_track.connect(_on_mouse_exits_track)
	Events.expand_button_clicked.connect(_on_expand_button_clicked)
	Events.upgrade_bought.connect(_on_upgrade_bought)

	track_marker_confirm.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var snapped_mouse_position = _get_snapped_mouse_position(event)
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			match gui_state:
				Gui.State.TRACK:
					var track_marker_confirm_position = track_creator.click(snapped_mouse_position)
					if track_marker_confirm_position != Vector2i.MAX:
						track_marker_confirm.visible = true
						track_marker_confirm.position = track_marker_confirm_position
					else:
						track_marker_confirm.visible = false
						# This means that creating tracks has just begun, so create
						# astar_terrain, which is used later when calling track_creator.mouse_move
						astar_terrain = _create_astar_terrain()
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
			Gui.State.STATION:
				_try_create_station(snapped_mouse_position)
			Gui.State.LIGHT:
				_create_light(snapped_mouse_position)
			Gui.State.DESTROY2:
				_destroy_under_destroy_markers()
				_hide_destroy_markers()
				_change_gui_state(Gui.State.DESTROY1)
	
	elif event is InputEventMouseMotion:
		if is_right_mouse_button_held_down:
			follow_train = null
			camera.position -= event.get_relative() / camera.zoom.x
			_restrict_camera()

		var snapped_mouse_position = _get_snapped_mouse_position(event)
		if snapped_mouse_position == previous_snapped_mouse_position:
			return
		previous_snapped_mouse_position = snapped_mouse_position

		ghost_station.position = snapped_mouse_position
		ghost_light.position = snapped_mouse_position

		match gui_state:
			Gui.State.TRACK:
				current_tile_marker.visible = true
				_show_current_tile_marker(snapped_mouse_position)
				var ghost_tracks = track_creator.mouse_move(snapped_mouse_position, astar_terrain)
				var all_track_set = TrackSet.new()
				for track in track_set.get_all_tracks():
					all_track_set.add(track)
				for track in ghost_tracks:
					add_child(track)
					all_track_set.add(track)
				_show_ghost_platform_tiles(all_track_set, _get_stations())
			Gui.State.STATION:
				var is_legal_station_position = _is_legal_station_position(snapped_mouse_position)
				ghost_station.set_color(true, is_legal_station_position)
				var stations = _get_stations()
				if is_legal_station_position:
					stations.append(ghost_station)
				_show_ghost_platform_tiles(track_set, stations)
			Gui.State.DESTROY1:
				_show_destroy_markers(snapped_mouse_position, snapped_mouse_position)
			Gui.State.DESTROY2:
				_show_destroy_markers(mouse_down_position, snapped_mouse_position)

	elif event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_ESCAPE:
				_change_gui_state(Gui.State.SELECT)
			KEY_1:
				_change_gui_state(Gui.State.TRACK)
			KEY_2:
				_change_gui_state(Gui.State.ONE_WAY_TRACK)
			KEY_3:
				_change_gui_state(Gui.State.STATION)
			KEY_4:
				_change_gui_state(Gui.State.TRAIN1)
			KEY_5:
				_change_gui_state(Gui.State.DESTROY1)
			

	if OS.is_debug_build() and event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_X:
				GlobalBank.earn(10000)
			KEY_C:
				show_reservation_markers = !show_reservation_markers
				for track in track_set.get_all_tracks():
					for pos in [track.pos1, track.pos2]:
						var coordinates = DEBUG_COORDINATES.instantiate()
						coordinates.position = pos - Vector2i(Global.TILE) / 3
						coordinates.text = "%s,%s" % [pos.x, pos.y]
						add_child(coordinates)
			KEY_V:
				print(JSON.stringify(_get_save_data(), "  "))


func _create_astar_terrain():
	var astar = AStarGrid2D.new()
	astar.region = terrain.boundaries
	astar.cell_size = Global.TILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	var positions: Array[Vector2i] = []
	# Set solid points
	# 1. Illegal positions
	for x in range(terrain.boundaries.position.x, terrain.boundaries.end.x + Global.TILE_SIZE, Global.TILE_SIZE):
		for y in range(terrain.boundaries.position.y, terrain.boundaries.end.y + Global.TILE_SIZE, Global.TILE_SIZE):
			positions.append(Vector2i(x, y))
	var illegal_positions = _illegal_track_positions(positions)
	for pos in illegal_positions:
		astar.set_point_solid(pos / Global.TILE_SIZE)
	# 2. West and east edges
	for x in [terrain.boundaries.position.x - Global.TILE_SIZE, terrain.boundaries.end.x + Global.TILE_SIZE]:
		for y in range(terrain.boundaries.position.y - Global.TILE_SIZE, terrain.boundaries.end.y + Global.TILE_SIZE * 2, Global.TILE_SIZE):
			astar.set_point_solid(Vector2i(x, y) / Global.TILE_SIZE)
	# 3. North and south edges
	for y in [terrain.boundaries.position.y - Global.TILE_SIZE, terrain.boundaries.end.y + Global.TILE_SIZE]:
		for x in range(terrain.boundaries.position.x - Global.TILE_SIZE, terrain.boundaries.end.x + Global.TILE_SIZE * 2, Global.TILE_SIZE):
			astar.set_point_solid(Vector2i(x, y) / Global.TILE_SIZE)
	return astar

func _show_current_tile_marker(pos: Vector2i):
	_show_marker(current_tile_marker, pos)


func _show_marker(marker: Line2D, pos: Vector2i):
	marker.clear_points()
	var x = pos.x - Global.TILE_SIZE / 2
	var y = pos.y - Global.TILE_SIZE / 2
	marker.add_point(Vector2(x, y))
	marker.add_point(Vector2(x + Global.TILE_SIZE, y))
	marker.add_point(Vector2(x + Global.TILE_SIZE, y + Global.TILE_SIZE))
	marker.add_point(Vector2(x, y + Global.TILE_SIZE))
	marker.add_point(Vector2(x, y))


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


func _get_snapped_mouse_position(event: InputEventMouse) -> Vector2i:
	# This is equivalent to doing get_local_mouse_position(), but I wanted to use the
	# mouse position from the InputEventMouse object
	return Vector2i((camera.get_canvas_transform().affine_inverse() * event.position).snapped(Global.TILE))

#######################################################################


func _illegal_track_positions(positions: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos in positions:
		if pos not in terrain.buildable_positions:
			out.append(pos)
	for node in get_tree().get_nodes_in_group("buildings"):
		if Vector2i(node.position) in positions:
			out.append(Vector2i(node.position))
	return out

func _create_tracks_from_ghost_tracks(ghost_tracks: Array[Track]):
	if len(ghost_tracks) == 0:
		# Creating 0 tracks can have some strange consequences, for example an
		# astar_track point will be created at the position, and the position will be
		# evaluated for platforms, etc.
		return
	
	var new_track_count = 0
	for track in ghost_tracks:
		if track_set.exists(track):
			track.queue_free()
		else:
			track_set.add(track)
			track.set_ghostly(false)
			new_track_count += 1
			astar_track.add_position(track.pos1)
			astar_track.add_position(track.pos2)
			astar_track.connect_positions(track.pos1, track.pos2)
		track.track_clicked.connect(_on_track_clicked)
	GlobalBank.buy(Global.Asset.TRACK, new_track_count, ghost_tracks[-1].global_position)
	_recreate_platform_tiles()
	# Makes trains waiting for reservations to change find new paths
	# TODO: Find a more elegant way to do this, or at least better naming.
	track_reservations.reservation_number += 1

func _destroy_track(positions: Array[Vector2i]):
	for pos in positions:
		for track in track_set.tracks_at_position(pos).duplicate():
			astar_track.disconnect_positions(track.pos1, track.pos2)
			GlobalBank.destroy(Global.Asset.TRACK)
			track_set.erase(track)
	_recreate_platform_tiles()
	# Makes trains waiting for reservations to change find new paths
	# TODO: Find a more elegant way to do this, or at least better naming.
	track_reservations.reservation_number += 1

##################################################################

func _on_track_clicked(track: Track):
	if gui_state == Gui.State.ONE_WAY_TRACK:
		_rotate_one_way_direction(track)


func _rotate_one_way_direction(track: Track):
	track.rotate_one_way_direction()
	astar_track.disconnect_positions(track.pos1, track.pos2)
	match track.direction:
		track.Direction.BOTH:
			astar_track.connect_positions(track.pos1, track.pos2)
		track.Direction.POS1_TO_POS2:
			astar_track.connect_positions(track.pos1, track.pos2, false)
		track.Direction.POS2_TO_POS1:
			astar_track.connect_positions(track.pos2, track.pos1, false)
	# Makes trains waiting for reservations to change find new paths
	# TODO: Find a more elegant way to do this, or at least better naming.
	track_reservations.reservation_number += 1

##################################################################

func _on_selectbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.SELECT)

func _on_trackbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(Gui.State.TRACK)

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

func _on_followtrainbutton_pressed() -> void:
	follow_train = selected_train

func _on_savebutton_pressed() -> void:
	gui.show_saved_visual_feedback()
	_save_game()

func _change_gui_state(new_state: Gui.State):
	ghost_station.visible = false
	ghost_light.visible = false
	track_creator.reset_ghost_tracks()
	track_marker_confirm.visible = false
	current_tile_marker.visible = false
	gui.selection_description_label.text = ""
	selected_station = null
	_deselect_all_trains()

	# Set station colors
	if new_state == Gui.State.TRAIN1:
		for station: Station in get_tree().get_nodes_in_group("stations"):
			station.modulate = Color(0, 1, 0, 1)
	elif new_state == Gui.State.TRAIN2:
		# Station colors handled elsewhere
		pass
	else:
		for station: Station in get_tree().get_nodes_in_group("stations"):
			station.modulate = Color(1, 1, 1, 1)
		
	if new_state == Gui.State.STATION:
		ghost_station.visible = true
	elif new_state == Gui.State.LIGHT:
		ghost_light.visible = true

	if new_state != Gui.State.DESTROY1:
		_hide_destroy_markers()
	if gui_state in [Gui.State.TRACK, Gui.State.STATION]:
		# Remove any ghost platforms that existed in track or station creation mode
		_recreate_platform_tiles()

	gui_state = new_state
	gui.set_pressed_no_signal(new_state)

###################################################################

func _is_legal_station_position(station_position: Vector2i):
	for node in get_tree().get_nodes_in_group("buildings"):
		if Vector2i(node.position) == station_position:
			return false
	if station_position not in terrain.buildable_positions:
		return false
	if track_set.has_track(station_position):
		return false
	return true
			
func _try_create_station(station_position: Vector2i):
	if not _is_legal_station_position(station_position):
		return
	if not GlobalBank.can_afford(Global.Asset.STATION):
		Global.show_popup("Cannot afford!", station_position, self)
		return
	var station = STATION.instantiate()
	station.position = station_position
	add_child(station)
	GlobalBank.buy(Global.Asset.STATION, 1, station.global_position)
	_recreate_platform_tiles()

func _destroy_stations(positions: Array[Vector2i]):
	var stations_to_create_platforms_for: Array[Station] = []
	for station in _get_stations():
		if Vector2i(station.position) in positions:
			station.queue_free()
			GlobalBank.destroy(Global.Asset.STATION)
		else:
			stations_to_create_platforms_for.append(station)
	_recreate_platform_tiles(track_set, stations_to_create_platforms_for)

func _get_stations() -> Array[Station]:
	var stations: Array[Station] = []
	for node in get_tree().get_nodes_in_group("stations"):
		if node is Station:
			stations.append(node)
	return stations

############################################################################

func _recreate_platform_tiles(track_set_: TrackSet = track_set, stations = _get_stations()):
	ghost_platform_tile_set.clear()
	var platform_tiles = platform_tile_set.recreate_all_platform_tiles(stations, track_set_)
	for platform_tile in platform_tiles:
		add_child(platform_tile)


func _show_ghost_platform_tiles(track_set_: TrackSet, stations: Array[Station]):
	var platform_tiles = ghost_platform_tile_set.recreate_all_platform_tiles(stations, track_set_)
	platform_tile_set.mark_platform_tiles_for_deletion(platform_tile_set.difference(ghost_platform_tile_set))
	for platform_tile in platform_tiles:
		add_child(platform_tile)

############################################################################

func _try_create_train(station1: Station, station2: Station):
	var train_number = len(get_tree().get_nodes_in_group("trains")) + 1
	var train = Train.try_create("Train %s" % train_number, station1, station2, platform_tile_set, track_set, track_reservations, astar_track, add_child)
	if train == null:
		return

	train.train_clicked.connect(_on_train_clicked)
	train.train_content_changed.connect(_on_train_content_changed)
	train.train_state_changed.connect(_on_train_state_changed)

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
	if gui_state == Gui.State.SELECT:
		current_tile_marker.visible = false
		selected_station = null
		_deselect_all_trains()
		_show_destination_markers(train)
		selected_train = train
		train.select(true)
		_update_selected_train_info()
		gui.set_follow_train_button_visibility(true)


func _show_destination_markers(train: Train):
	for destination in train.destinations:
		var marker = Line2D.new()
		marker.width = 2
		marker.default_color = Color(1.0, 1.0, 1.0, 1.0)
		_show_marker(marker, destination)
		destination_markers.append(marker)
		add_child(marker)


func _deselect_all_trains():
	selected_train = null
	gui.set_follow_train_button_visibility(false)
	for train in get_tree().get_nodes_in_group("trains"):
		train.select(false)
	while destination_markers:
		var destination_marker = destination_markers.pop_back()
		destination_marker.queue_free()

func _on_train_content_changed(train: Train):
	if train == selected_train:
		_update_selected_train_info()

func _on_train_state_changed(train: Train):
	if train == selected_train:
		_update_selected_train_info()

	
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
		track_reservations.clear_reservations(train)
		train.queue_free()
		# Remove it from the tree, or _update might get triggered even though the
		# train will be removed
		train.get_parent().remove_child(train)
		GlobalBank.destroy(Global.Asset.TRAIN)
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
	
func _on_ore_timer_timeout():
	var stations = _get_stations()
	for industry: Industry in get_tree().get_nodes_in_group("industries"):
		var adjacent_stations = _adjacent_stations(industry, stations)
		if not adjacent_stations:
			continue

		if industry.requires_resources_to_produce:
			# See so that each type of required resource exists at at least one station
			var station_from_resource_type: Dictionary[Global.ResourceType, Station] = {}
			for resource_type in industry.consumes:
				for station: Station in adjacent_stations:
					if station.get_resource_not_created_here_count(resource_type) > 0:
						station_from_resource_type[resource_type] = station
						break

			# If all material is available, produce.
			# Note that is is also true if 0 material is needed
			if len(station_from_resource_type) == len(industry.consumes):
				for resource_type in station_from_resource_type:
					station_from_resource_type[resource_type].remove_resource(resource_type)
				for resource_type in industry.produces:
					_produce_at_first_station_with_space(resource_type, adjacent_stations)
		else:
			for resource_type in industry.produces:
				_produce_at_first_station_with_space(resource_type, adjacent_stations)
			
######################################################################

func _adjacent_stations(node: Node, stations: Array[Station]) -> Array[Station]:
	var adjacent_stations: Array[Station]
	adjacent_stations.assign(stations.filter(func(station): return Global.is_orthogonally_adjacent(
			Vector2i(station.global_position), Vector2i(node.global_position))))
	return adjacent_stations

func _produce_at_first_station_with_space(resource_type: Global.ResourceType, stations: Array[Station]):
	for station in stations:
		if not station.is_at_max_capacity(resource_type):
			station.add_resource(resource_type, true)
			break

######################################################################

func _on_industry_clicked(industry: Industry):
	if gui_state != Gui.State.SELECT:
		return
	selected_station = null
	_deselect_all_trains()
	current_tile_marker.visible = true
	_show_current_tile_marker(industry.global_position)
	var description = industry.get_script().get_global_name()
	var get_resource_description = func(resource_type):
		return "%s ($%s)" % [Global.get_resource_name(resource_type), industry.get_price(resource_type)]
	if industry.consumes:
		description += "\nAccepts: "
		description += ", ".join(industry.consumes.map(get_resource_description))
	if industry.produces:
		description += "\nProduces: "
		description += ", ".join(industry.produces.map(Global.get_resource_name))
	gui.selection_description_label.text = description

func _on_station_clicked(station: Station):
	if gui_state == Gui.State.TRAIN1:
		for other_station: Station in get_tree().get_nodes_in_group("stations"):
			if other_station == station:
				other_station.modulate = Color(1, 1, 1, 1)
			elif _are_stations_connected(station, other_station):
				other_station.modulate = Color(0, 1, 0, 1)
			else:
				other_station.modulate = Color(1, 1, 1, 1)
		train_start_station = station
		_change_gui_state(Gui.State.TRAIN2)
	elif gui_state == Gui.State.TRAIN2:
		_try_create_train(train_start_station, station)
		_change_gui_state(Gui.State.TRAIN1)
	elif gui_state == Gui.State.SELECT:
		_deselect_all_trains()
		selected_station = station
		current_tile_marker.visible = true
		_show_current_tile_marker(station.global_position)
		_update_selected_station_info()

func _are_stations_connected(station1: Station, station2: Station):
	return len(platform_tile_set.get_connected_platform_positions_adjacent_to(station1, station2, astar_track)) > 0

func _on_station_content_updated(station: Station):
	if station == selected_station:
		_update_selected_station_info()

func _update_selected_station_info():
	if not selected_station:
		return
	var description = "Station\nAccepts: "
	var get_resource_description = func(resource_type):
		return "%s ($%s)" % [Global.get_resource_name(resource_type), selected_station.get_price(resource_type)]
	description += ", ".join(selected_station.accepts().map(get_resource_description))
	var resource_strings = []
	for resource_type in Global.ResourceType.values():
		var count = selected_station.get_resource_count(resource_type)
		if count > 0:
			resource_strings.append("%s: %s" % [Global.get_resource_name(resource_type), count])
	if resource_strings:
		description += "\nContains: " + ", ".join(resource_strings)
	gui.selection_description_label.text = description
	
func _update_selected_train_info():
	if not selected_train:
		return
	var description = selected_train.name
	description += "\n%s" % Train.State.keys()[selected_train.state].capitalize()
	var resource_strings = []
	for resource_type in Global.ResourceType.values():
		var count = 0
		for wagon in selected_train.wagons:
			count += wagon.get_resource_count(resource_type)
		if count > 0:
			resource_strings.append("%s: %s" % [Global.get_resource_name(resource_type), count])
	if resource_strings:
		description += "\nContains: " + ", ".join(resource_strings)
	gui.selection_description_label.text = description

######################################################################

func _on_mouse_enters_track(track: Track):
	if gui_state == gui.State.ONE_WAY_TRACK:
		track.set_highlight(true)


func _on_mouse_exits_track(track: Track):
	track.set_highlight(false)

######################################################################

func _on_expand_button_clicked():
	# The main purpose of this is to exit Track state,
	# since boundaries will need to be recalculated
	_change_gui_state(Gui.State.SELECT)


func _on_upgrade_bought(upgrade: UpgradeManager.UpgradeType):
	if upgrade == UpgradeManager.UpgradeType.PLATFORM_LENGTH:
		_recreate_platform_tiles()

######################################################################

func start_new_game():
	terrain.set_seed_and_add_starting_chunks(randomizer_seed)
	$Gui/Help.visible = true


func _save_game():
	var save_file = FileAccess.open(Global.SAVE_PATH, FileAccess.WRITE)
	save_file.store_var(_get_save_data())
	save_file.close()
	print("Saved game to %s" % Global.SAVE_PATH)


func _save_game_to_project_dir():
	# get_datetime_string_from_system gives strings on the form "2025-11-14 20:51:33"
	var timestamp = Time.get_datetime_string_from_system(true, true).replace(" ", "_").replace(":", "-")
	var file_path = "res://savegames/" + timestamp + ".save"
	var save_file = FileAccess.open(file_path, FileAccess.WRITE)
	save_file.store_var(_get_save_data())
	save_file.close()
	print("Saved game to %s" % file_path)


func _get_save_data() -> Dictionary:
	var data = {}
	data["randomizer_seed"] = randomizer_seed
	data["tracks"] = track_set._tracks.values().map(func(t): return {"pos1": t.pos1, "pos2": t.pos2, "direction": t.direction})
	data["stations"] = _get_stations().map(func(s): return {"position": s.position})
	data["trains"] = get_tree().get_nodes_in_group("trains").map(func(t): return {"destinations": t.destinations})
	data["chunks"] = terrain.chunks
	data["money"] = GlobalBank.money
	data["upgrades"] = Upgrades.save()
	return data


func load_game():
	_load_game_from_path(Global.SAVE_PATH)


func _load_game_from_path(file_path: String):
	# file_path is typically on the form"res://savegames/foo.save"
	#var file_path = "res://savegames/2025-11-16_19-35-32.save"
	var save_file = FileAccess.open(file_path, FileAccess.READ)
	var data = save_file.get_var()
	_load_game_from_data(data)


func _load_game_from_data(data: Dictionary):
	randomizer_seed = data.randomizer_seed
	seed(randomizer_seed)
	# Remember that water, sand and mountain level also have to be the same
	terrain.set_seed_and_add_chunks(randomizer_seed, data.chunks)

	# This must be loaded before creating tracks etc, or platforms
	# will not be created correctly
	Upgrades.load(data.upgrades)
	# Disable popups and sound effect when buying, and
	# ensure that the bank has enough money to recreate everything
	GlobalBank.is_effects_enabled = false
	GlobalBank.set_money(Global.MAX_INT)
	for track_dict in data.tracks:
		var tracks = track_creator.create_ghost_track([track_dict.pos1, track_dict.pos2])
		for track in tracks:
			add_child(track)
		track_creator.create_tracks()
	var direction_from_track_positions: Dictionary[String, Track.Direction] = {}
	for track_dict in data.tracks:
		direction_from_track_positions[str(track_dict["pos1"]) + "," + str(track_dict["pos2"])] = track_dict["direction"]
	for track in track_set.get_all_tracks():
		for _i in direction_from_track_positions[str(track.pos1) + "," + str(track.pos2)]:
			_rotate_one_way_direction(track)
	for station_dict in data.stations:
		_try_create_station(station_dict["position"])
	for train_dict in data.trains:
		_try_create_train(train_dict.destinations[0], train_dict.destinations[1])
	GlobalBank.set_money(data.money)
	GlobalBank.is_effects_enabled = true
	_change_gui_state(Gui.State.SELECT) # To clear track creating mode
