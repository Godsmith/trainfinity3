extends Node2D

class_name Game

const TILE := Vector2(Global.TILE_SIZE, Global.TILE_SIZE)
const SCALE_FACTOR := 2 # Don't remember where I set this
enum GUI_STATE {NONE, TRACK, STATION, TRAIN1, TRAIN2, LIGHT, DESTROY}

const STATION = preload("res://scenes/station.tscn")
const PLATFORM = preload("res://scenes/platform.tscn")
const TRAIN = preload("res://scenes/train.tscn")
const TRACK = preload("res://scenes/track.tscn")
const LIGHT = preload("res://scenes/light.tscn")

@onready var terrain = $Terrain
@onready var ghost_track = $GhostTrack
@onready var ghost_station = $GhostStation
@onready var ghost_light = $GhostLight

var gui_state := GUI_STATE.NONE
var is_left_mouse_button_held_down := false
var is_right_mouse_button_held_down := false

var start_track_location := Vector2i()
var ghost_tracks: Array[Track] = []
# The keys are provided by Track.position_rotation()
var tracks: Dictionary[Vector3i, Track] = {}
var ghost_track_tile_positions: Array[Vector2i] = []

var astar = AStar2D.new()
var astar_id_from_position: Dictionary[Vector2i, int] = {}

@onready var camera = $Camera2D
@onready var gui: Gui = $Gui
@onready var bank = Bank.new(gui)

var selected_station: Station = null


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


func _real_stations() -> Array:
	return get_tree().get_nodes_in_group("stations").filter(func(station): return !station.is_ghost)


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
			if gui_state == GUI_STATE.TRACK:
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
			GUI_STATE.TRACK:
				_try_create_tracks()
				ghost_track.visible = true
			GUI_STATE.STATION:
				_try_create_station(Vector2i(get_local_mouse_position().snapped(TILE)))
			GUI_STATE.LIGHT:
				_create_light(get_local_mouse_position().snapped(TILE))
	
	if event is InputEventMouseMotion:
		var mouse_position = Vector2i(get_local_mouse_position().snapped(TILE))
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
	bank.buy(Global.Asset.TRACK, len(ghost_tracks))
	ghost_tracks.clear()

func _add_position_to_astar(new_position: Vector2i):
	if not new_position in astar_id_from_position:
		var id = astar.get_available_point_id()
		astar_id_from_position[new_position] = id
		astar.add_point(id, new_position)

func _track_clicked(track: Track):
	if gui_state == GUI_STATE.DESTROY:
		astar.disconnect_points(astar_id_from_position[track.pos1], astar_id_from_position[track.pos2])
		tracks.erase(track.position_rotation())
		track.queue_free()
		bank.destroy(Global.Asset.TRACK)
	
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

func _try_create_station(station_position: Vector2i):
	if not bank.can_afford(Global.Asset.STATION):
		return
	var station = STATION.instantiate()
	station.position = station_position
	_add_position_to_astar(station_position)
	station.station_clicked.connect(_station_clicked)
	add_child(station)
	bank.buy(Global.Asset.STATION)
	_create_platforms(station_position)
	
func _station_clicked(station: Station):
	if gui_state == GUI_STATE.TRAIN1:
		var id1 = astar_id_from_position[Vector2i(station.position)]
		for other_station: Station in _real_stations():
			station.modulate = Color(1, 1, 1, 1)
			if other_station != station:
				var id2 = astar_id_from_position[Vector2i(other_station.position)]
				if astar.get_point_path(id1, id2):
					other_station.modulate = Color(0, 1, 0, 1)
		selected_station = station
		gui_state = GUI_STATE.TRAIN2
	elif gui_state == GUI_STATE.TRAIN2:
		_try_create_train(selected_station, station)
		_change_gui_state(GUI_STATE.TRAIN1)
	elif gui_state == GUI_STATE.DESTROY:
		station.queue_free()
		bank.destroy(Global.Asset.STATION)

func _try_create_train(station1: Station, station2: Station):
	if not bank.can_afford(Global.Asset.TRAIN):
		return
	var id1 = astar_id_from_position[Vector2i(station1.position)]
	var id2 = astar_id_from_position[Vector2i(station2.position)]
	if id1 != id2:
		var point_path = astar.get_point_path(id1, id2)
		if point_path:
			var train = TRAIN.instantiate()
			train.set_path(point_path)
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
			bank.earn(train.ore())
			train.remove_all_ore()
			
	for station in _real_stations():
		if station.global_position.snapped(TILE) == train.get_train_position().snapped(TILE):
			while station.ore > 0 and train.ore() < train.max_capacity():
				train.add_ore(Ore.ORE_TYPE.COAL)
				station.remove_ore()

######################################################################

func _create_platforms(station_position: Vector2i):
	var legal_platform_positions = _get_legal_platform_positions()
	var platform_positions = []
	var potential_platform_positions = Global.orthogonally_adjacent(station_position)
	while potential_platform_positions:
		var pos = potential_platform_positions.pop_back()
		if pos not in platform_positions and pos in legal_platform_positions:
			platform_positions.append(pos)
			potential_platform_positions.append_array(Global.orthogonally_adjacent(pos))
	for pos in platform_positions:
		var platform = PLATFORM.instantiate()
		platform.position = pos
		add_child(platform)
		

func _get_legal_platform_positions() -> Array[Vector2i]:
	var tracks_from_position: Dictionary[Vector2i, Array] = {}
	for track in tracks.values():
		if not track.pos1 in tracks_from_position:
			tracks_from_position[track.pos1] = []
		if not track.pos2 in tracks_from_position:
			tracks_from_position[track.pos2] = []
		tracks_from_position[track.pos1].append(track)
		tracks_from_position[track.pos2].append(track)

	var legal_platform_positions: Array[Vector2i] = []
	for track_position in tracks_from_position:
		if len(tracks_from_position[track_position]) == 1:
			var other_track_position = tracks_from_position[track_position][0].other_position(track_position)
			if Global.is_orthogonally_adjacent(track_position, other_track_position):
				legal_platform_positions.append(track_position)
		elif len(tracks_from_position[track_position]) == 2:
			var other_track_position1 = tracks_from_position[track_position][0].other_position(track_position)
			var other_track_position2 = tracks_from_position[track_position][1].other_position(track_position)
			if other_track_position1.x == other_track_position2.x or other_track_position1.y == other_track_position2.y:
				legal_platform_positions.append(track_position)
	return legal_platform_positions

	# for adjacent_positions in Global.orthogonally_adjacent(station.global_position.snapped(TILE)):
	# 	pass
