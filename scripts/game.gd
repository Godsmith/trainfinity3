extends Node2D

class_name Game

const TILE := Vector2(Global.TILE_SIZE, Global.TILE_SIZE)
const SCALE_FACTOR := 2 # Don't remember where I set this
enum GuiState {NONE, TRACK, STATION, TRAIN1, TRAIN2, LIGHT, DESTROY}

const STATION = preload("res://scenes/station.tscn")
const PLATFORM = preload("res://scenes/platform.tscn")
const TRAIN = preload("res://scenes/train.tscn")
const TRACK = preload("res://scenes/track.tscn")
const LIGHT = preload("res://scenes/light.tscn")

@onready var terrain = $Terrain
@onready var ghost_track = $GhostTrack
@onready var ghost_station = $GhostStation
@onready var ghost_light = $GhostLight

var gui_state := GuiState.NONE
var is_left_mouse_button_held_down := false
var is_right_mouse_button_held_down := false

var start_track_location := Vector2i()
var ghost_tracks: Array[Track] = []
var ghost_track_tile_positions: Array[Vector2i] = []

var platforms: Dictionary[Vector2i, Node2D] = {}

var astar = AStar2D.new()
var astar_id_from_position: Dictionary[Vector2i, int] = {}

@onready var camera = $Camera2D
@onready var gui: Gui = $Gui
@onready var bank = Bank.new(gui)
@onready var track_set = TrackSet.new()

var selected_platform: Platform = null

class TrackSet:
# The keys are provided by Track.position_rotation()
	var _tracks: Dictionary[Vector3i, Track] = {}
	var _tracks_from_position: Dictionary[Vector2i, Array] = {}

	func add(track: Track):
		_tracks[track.position_rotation()] = track
		if not track.pos1 in _tracks_from_position:
			_tracks_from_position[track.pos1] = []
		if not track.pos2 in _tracks_from_position:
			_tracks_from_position[track.pos2] = []
		_tracks_from_position[track.pos1].append(track)
		_tracks_from_position[track.pos2].append(track)

	func exists(track: Track):
		return track.position_rotation() in _tracks

	func get_all_tracks():
		return _tracks.values()

	func get_track_count(position: Vector2i) -> int:
		if not position in _tracks_from_position:
			_tracks_from_position[position] = []
		return len(_tracks_from_position[position])

	func positions_with_track() -> Array[Vector2i]:
		return _tracks_from_position.keys()

	func positions_connected_to(position: Vector2i) -> Array[Vector2i]:
		var positions: Array[Vector2i] = []
		for track in _tracks_from_position[position]:
			positions.append(track.other_position(position))
		return positions

	func erase(track: Track):
		_tracks.erase(track.position_rotation())
		_tracks_from_position[track.pos1].erase(track)
		_tracks_from_position[track.pos2].erase(track)
		track.queue_free()


class Bank:
	const _start_price := {
		Global.Asset.TRACK: 1.0,
		Global.Asset.STATION: 5.0,
		Global.Asset.TRAIN: 10.0
	}
	var _current_price: Dictionary[Global.Asset, float] = {
		Global.Asset.TRACK: _start_price[Global.Asset.TRACK],
		Global.Asset.STATION: _start_price[Global.Asset.STATION],
		Global.Asset.TRAIN: _start_price[Global.Asset.TRAIN]
	}

	var _asset_count: Dictionary[Global.Asset, int] = {
		Global.Asset.TRACK: 0,
		Global.Asset.STATION: 0,
		Global.Asset.TRAIN: 0
	}

	const _INCREASE_FACTOR := 1.5

	var money := 30
	var gui: Gui

	func _init(gui_: Gui):
		gui = gui_
		gui.update_prices(_current_price)
		gui.show_money(money)


	func cost(asset: Global.Asset, amount := 1) -> int:
		return amount * floori(_current_price[asset])

	func can_afford(asset: Global.Asset, amount := 1) -> bool:
		return cost(asset, amount) <= money

	func buy(asset: Global.Asset, amount := 1):
		money -= cost(asset, amount)
		_asset_count[asset] += amount
		self._update_prices()
		gui.show_money(money)

	func _update_prices():
		for asset in Global.Asset.values():
			if asset == Global.Asset.TRACK:
				_current_price[asset] = _start_price[asset] * (1 + _asset_count[asset] / 10)
			else:
				_current_price[asset] = _start_price[asset] * _INCREASE_FACTOR ** _asset_count[asset]
		gui.update_prices(_current_price)

	func earn(amount: int):
		self.money += amount
		gui.show_money(money)

	func destroy(asset: Global.Asset):
		_asset_count[asset] -= 1
		self._update_prices()


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_left_mouse_button_held_down = event.is_pressed()
			if gui_state == GuiState.TRACK:
				start_track_location = Vector2i(get_local_mouse_position().snapped(TILE))
				ghost_track.visible = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_mouse_button_held_down = event.is_pressed()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and not event.is_echo():
			camera.zoom_camera(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not event.is_echo():
			camera.zoom_camera(1 / 1.1)
	
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		match gui_state:
			GuiState.TRACK:
				_try_create_tracks()
				ghost_track.visible = true
			GuiState.STATION:
				_try_create_station(Vector2i(get_local_mouse_position().snapped(TILE)))
			GuiState.LIGHT:
				_create_light(get_local_mouse_position().snapped(TILE))
	
	if event is InputEventMouseMotion:
		var mouse_position = Vector2i(get_local_mouse_position().snapped(TILE))
		ghost_track.position = mouse_position
		ghost_station.position = mouse_position
		ghost_light.position = mouse_position
		if is_left_mouse_button_held_down:
			if gui_state == GuiState.TRACK and is_left_mouse_button_held_down:
				var new_ghost_track_tile_positions = _positions_between(start_track_location, mouse_position)
				if new_ghost_track_tile_positions != ghost_track_tile_positions:
					_show_ghost_track(new_ghost_track_tile_positions)
					
		if is_right_mouse_button_held_down:
			camera.position -= event.get_relative() / camera.zoom.x

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
	_recreate_platforms(ghost_track_tile_positions)
	ghost_tracks.clear()

func _add_position_to_astar(new_position: Vector2i):
	if not new_position in astar_id_from_position:
		var id = astar.get_available_point_id()
		astar_id_from_position[new_position] = id
		astar.add_point(id, new_position)

func _track_clicked(track: Track):
	if gui_state == GuiState.DESTROY:
		astar.disconnect_points(astar_id_from_position[track.pos1], astar_id_from_position[track.pos2])
		track_set.erase(track)
		bank.destroy(Global.Asset.TRACK)

		_recreate_platforms([track.pos1, track.pos2])


##################################################################

func _on_trackbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GuiState.TRACK)

func _on_stationbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GuiState.STATION)

func _on_trainbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GuiState.TRAIN1)
	
func _on_lightbutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GuiState.LIGHT)

func _on_destroybutton_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_change_gui_state(GuiState.DESTROY)


func _change_gui_state(new_state: GuiState):
	ghost_track.visible = false
	ghost_station.visible = false
	ghost_light.visible = false

	# Set platform colors
	if new_state == GuiState.TRAIN1:
		for platform: Platform in get_tree().get_nodes_in_group("platforms"):
			platform.modulate = Color(0, 1, 0, 1)
	elif new_state == GuiState.TRAIN2:
		# Platform colors handled elsewhere
		pass
	else:
		for platform: Platform in get_tree().get_nodes_in_group("platforms"):
			platform.modulate = Color(1, 1, 1, 1)
		
	if new_state == GuiState.TRACK:
		ghost_track.visible = true
	elif new_state == GuiState.STATION:
		ghost_station.visible = true
	elif new_state == GuiState.LIGHT:
		ghost_light.visible = true
	
	if new_state == GuiState.NONE:
		gui.unpress_all()
	gui_state = new_state

###################################################################

func _try_create_station(station_position: Vector2i):
	if not bank.can_afford(Global.Asset.STATION):
		return
	var station = STATION.instantiate()
	station.position = station_position
	station.station_clicked.connect(_station_clicked)
	add_child(station)
	bank.buy(Global.Asset.STATION)
	_create_platforms([station])

func _station_clicked(station: Station):
	if gui_state == GuiState.DESTROY:
		# Remove adjacent platforms and recreate them if they are close to other stations
		# Using dictionary as a set. List of stations adjacent to adjacent platforms.
		var station_set: Dictionary[Station, int] = {}
		for adjacent_position in Global.orthogonally_adjacent(station.position):
			if adjacent_position in platforms:
				for other_station in _stations_connected_to_platform(adjacent_position):
					if not other_station == station:
						station_set[other_station] = 0
				for pos in _connected_platform_positions(adjacent_position):
					platforms[pos].queue_free()
					platforms.erase(pos)
		_create_platforms(station_set.keys())

		station.queue_free()
		bank.destroy(Global.Asset.STATION)

func _platform_clicked(platform: Platform):
	if gui_state == GuiState.TRAIN1:
		var id1 = astar_id_from_position[Vector2i(platform.position)]
		for other_platform: Platform in get_tree().get_nodes_in_group("platforms"):
			other_platform.modulate = Color(1, 1, 1, 1)
			if not _are_connected(platform, other_platform):
				var id2 = astar_id_from_position[Vector2i(other_platform.position)]
				if astar.get_point_path(id1, id2):
					other_platform.modulate = Color(0, 1, 0, 1)
		selected_platform = platform
		_change_gui_state(GuiState.TRAIN2)
	elif gui_state == GuiState.TRAIN2:
		_try_create_train(selected_platform, platform)
		_change_gui_state(GuiState.TRAIN1)

func _try_create_train(platform1: Platform, platform2: Platform):
	if not bank.can_afford(Global.Asset.TRAIN):
		return
	if _are_connected(platform1, platform2):
		return

	# Get path from the beginning of the first platform to the end
	# of the target platform
	var point_paths: Array[PackedVector2Array] = []
	for p1 in _platform_endpoints(platform1.position):
		for p2 in _platform_endpoints(platform2.position):
			var id1 = astar_id_from_position[Vector2i(p1)]
			var id2 = astar_id_from_position[Vector2i(p2)]
			point_paths.append(astar.get_point_path(id1, id2))
	point_paths.sort_custom(func(a, b): return len(a) < len(b))

	var train = TRAIN.instantiate()
	train.set_path(point_paths[-1])
	train.end_reached.connect(_on_train_reaches_end)
	add_child(train)
	bank.buy(Global.Asset.TRAIN)

	
###################################################################

func _create_light(light_position: Vector2):
	var light = LIGHT.instantiate()
	light.position = light_position
	light.light_clicked.connect(_light_clicked)
	add_child(light)

func _light_clicked(light: Light):
	if gui_state == GuiState.DESTROY:
		light.queue_free()


######################################################################
	
func _on_timer_timeout():
	for station: Station in _real_stations():
		station.extract_ore()

######################################################################
	
func _on_train_reaches_end(train: Train):
	for station in _stations_connected_to_platform(train.get_train_position().snapped(TILE)):
		while station.ore > 0 and train.ore() < train.max_capacity():
			train.add_ore(Ore.OreType.COAL)
			station.remove_ore()
		for factory in get_tree().get_nodes_in_group("factories"):
			if Global.is_orthogonally_adjacent(factory.get_global_position(), station.position):
				bank.earn(train.ore())
				train.remove_all_ore()


######################################################################

func _create_platforms(stations: Array[Station]):
	var legal_platform_positions_and_rotations = _get_legal_platform_positions_and_rotations()
	var evaluated_platform_positions = []
	for station in stations:
		var potential_platform_positions = Global.orthogonally_adjacent(Vector2i(station.position))
		while potential_platform_positions:
			var pos = potential_platform_positions.pop_back()
			if pos not in evaluated_platform_positions and pos in legal_platform_positions_and_rotations:
				evaluated_platform_positions.append(pos)
				potential_platform_positions.append_array(track_set.positions_connected_to(pos))
				if pos in platforms:
					continue
				var platform = PLATFORM.instantiate()
				platform.position = pos
				platform.rotation = legal_platform_positions_and_rotations[pos]
				platform.platform_clicked.connect(_platform_clicked)
				add_child(platform)
				platforms[pos] = platform

	
func _get_legal_platform_positions_and_rotations() -> Dictionary[Vector2i, float]:
	var legal_platform_positions_and_rotations: Dictionary[Vector2i, float] = {}
	for track_position in track_set.positions_with_track():
		match track_set.get_track_count(track_position):
			1:
				var other_track_position = track_set.positions_connected_to(track_position)[0]
				if Global.is_orthogonally_adjacent(track_position, other_track_position):
					var rotation_ = 0.0 if track_position.y == other_track_position.y else PI / 2
					legal_platform_positions_and_rotations[track_position] = rotation_
			2:
				var connected_positions = track_set.positions_connected_to(track_position)
				var are_on_horizontal_line = (track_position.y == connected_positions[0].y and track_position.y == connected_positions[1].y)
				var are_on_vertical_line = (track_position.x == connected_positions[0].x and track_position.x == connected_positions[1].x)
				if are_on_horizontal_line or are_on_vertical_line:
					var rotation_ = 0.0 if are_on_horizontal_line else PI / 2
					legal_platform_positions_and_rotations[track_position] = rotation_
	return legal_platform_positions_and_rotations

func _are_connected(platform1: Platform, platform2: Platform) -> bool:
	return _connected_platform_positions(Vector2i(platform1.position)).has(Vector2i(platform2.position))

func _connected_platform_positions(pos: Vector2i) -> Array[Vector2i]:
	var connected_positions: Array[Vector2i] = [pos]
	var possible_connected_platforms := track_set.positions_connected_to(pos)
	while possible_connected_platforms:
		var new_pos = possible_connected_platforms.pop_back()
		if new_pos not in connected_positions and new_pos in platforms:
			connected_positions.append(new_pos)
			possible_connected_platforms.append_array(track_set.positions_connected_to(new_pos))
	return connected_positions

func _platform_endpoints(pos: Vector2i) -> Array[Vector2i]:
	var platform_positions = _connected_platform_positions(pos)
	# Sort by x if x are different else sort by y
	platform_positions.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x if a.y == b.y else a.y < b.y)
	return [platform_positions[0], platform_positions[-1]]


func _stations_connected_to_platform(pos: Vector2i) -> Array[Station]:
	var connected_positions = _connected_platform_positions(pos)
	var stations: Array[Station] = []
	for station in _real_stations():
		for neighbor in Global.orthogonally_adjacent(Vector2i(station.position)):
			if connected_positions.has(neighbor):
				stations.append(station)
	return stations

func _recreate_platforms(platform_positions: Array[Vector2i]):
	# 1. Collect stations:
	#    - adjacent to the new positions
	#    - connected to platform at the new positions
	# 2. Remove platforms connected to the new position
	# 3. Create new platforms adjacent to the stations
	# The stations Dictionary is used as a set
	var stations: Dictionary[Station, int] = {}
	for station in _real_stations():
		for pos in Global.orthogonally_adjacent(station.position):
			if platform_positions.has(pos):
				stations[station] = 0
	for platform_position in platform_positions:
		if platform_position in platforms:
			for station in _stations_connected_to_platform(platform_position):
				stations[station] = 0
			for pos in _connected_platform_positions(platform_position):
				platforms[pos].queue_free()
				platforms.erase(pos)
	_create_platforms(stations.keys())