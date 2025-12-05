extends Path2D

class_name Train

const TRAIN = preload("res://scenes/train.tscn")
const WAGON = preload("res://scenes/wagon.tscn")

signal train_clicked(train: Train)
signal train_content_changed(train: Train)

enum State {RUNNING, LOADING, WAITING_FOR_TRACK_RESERVATION_CHANGE, WAITING_FOR_MISSING_PLATFORM, STARTING_FROM_PLATFORM}

var state: State = State.RUNNING
var last_known_reservation_number = 0
var platform_tile_set: PlatformTileSet
var track_set: TrackSet
var track_reservations: TrackReservations
var astar: Astar

var max_speed := 20.0
@export var target_speed := 0.0
@export var absolute_speed := 0.0
@export var acceleration := 6.0
@export var wagons: Array = []

var on_rails := true
# TODO: consider changing to "starting wagon count"
# and retrieving the number of wagons dynamically instead
var wagon_count = 3
var last_delta = 0.0

@onready var path_follow := $PathFollow2D
@onready var polygon := $RigidBody2D/LightOccluder2D
@onready var rigid_body := $RigidBody2D
@onready var no_route_timer := $NoRouteTimer
@onready var red_marker := $RigidBody2D/RedMarker
@onready var canvas_group := $RigidBody2D/CanvasGroup
@onready var ore_timer := $OreTimer

var destinations: Array[Vector2i] = []
var destination_index := 0

var reservation_color: Color

static func create(name_: String,
				   wagon_count_: int,
				   point_path: PackedVector2Array,
				   platform_tile_set_: PlatformTileSet,
				   track_set_: TrackSet,
				   track_reservations_: TrackReservations,
				   astar_: Astar) -> Train:
	var train = TRAIN.instantiate()
	train.name = name_
	train.wagon_count = wagon_count_
	train.destinations = [point_path[0], point_path[-1]] as Array[Vector2i]
	train.platform_tile_set = platform_tile_set_
	train.track_set = track_set_
	train.track_reservations = track_reservations_
	train.astar = astar_
	return train

func _ready() -> void:
	reservation_color = _random_color()
	max_speed = Upgrades.get_value(Upgrades.UpgradeType.TRAIN_MAX_SPEED)
	acceleration = Upgrades.get_value(Upgrades.UpgradeType.TRAIN_ACCELERATION)
	for i in wagon_count:
		var wagon = WAGON.instantiate()
		wagons.append(wagon)
		add_child(wagon)
		wagon.wagon_clicked.connect(func(): train_clicked.emit(self))
		wagon.wagon_content_changed.connect(func(): train_content_changed.emit(self))

func _random_color() -> Color:
	var r = 0.0
	var g = 0.0
	var b = 0.0
	while r + g + b < 0.6:
		r = randf()
		g = randf()
		b = randf()
	return Color(r, g, b, 0.5)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		train_clicked.emit(self)

func _get_linear_velocity(path_follow_: PathFollow2D):
	var current_pos = path_follow_.global_position
	path_follow_.progress += last_delta * absolute_speed
	var next_pos = path_follow_.global_position

	var velocity = (next_pos - current_pos) / last_delta
	return velocity


func _physics_process(_delta: float) -> void:
	if on_rails:
		rigid_body.global_position = path_follow.global_position
		rigid_body.rotation = path_follow.rotation
	# TODO; should not be needed
	# for wagon in wagons:
	# 	wagon.rigid_body.position = Vector2(0.0, 0.0)

func _process(delta):
	# print("=before==========")
	# print(wagons[0].path_follow.position)
	# print(wagons[0].rigid_body.position)
	# print(wagons[1].path_follow.position)
	# print(wagons[1].rigid_body.position)
	last_delta = delta
	if not on_rails:
		return

	var is_in_sharp_corner = _is_in_sharp_corner()
	var allowed_target_speed = min(target_speed, 5.0) if is_in_sharp_corner else target_speed
	absolute_speed = min(absolute_speed, 5.0) if is_in_sharp_corner else absolute_speed

	if absolute_speed < allowed_target_speed:
		absolute_speed += acceleration * delta

	path_follow.progress += delta * absolute_speed
	for wagon in wagons:
		wagon.path_follow.progress += delta * absolute_speed

	match state:
		State.RUNNING:
			# Check if we are reaching the end of curve the NEXT frame, in order to not get
			# stop-start behavior. This makes the train jump forward slightly though, so it is
			# still not ideal.
			if path_follow.progress + delta * absolute_speed >= curve.get_baked_length():
				var new_state = _get_new_state_at_end_of_curve()
				if new_state != State.RUNNING:
					_change_state(new_state)
		State.WAITING_FOR_MISSING_PLATFORM:
			if no_route_timer.is_stopped():
				var target_tile = destinations[destination_index]
				if platform_tile_set.has_platform(target_tile):
					_change_state(State.RUNNING)
				else:
					_change_state(State.WAITING_FOR_MISSING_PLATFORM)
		State.LOADING:
			if not ore_timer.is_stopped():
				return
			var has_loaded_or_unloaded = _load_and_unload()
			if has_loaded_or_unloaded:
				ore_timer.start()
			else:
				destination_index += 1
				destination_index %= len(destinations)
				_change_state(_try_set_new_curve_and_return_new_state(destinations[destination_index], true))
		State.WAITING_FOR_TRACK_RESERVATION_CHANGE:
			if track_reservations.reservation_number > last_known_reservation_number:
				last_known_reservation_number = track_reservations.reservation_number
				_change_state(_try_set_new_curve_and_return_new_state(destinations[destination_index], false))


func _is_in_sharp_corner():
	if len(wagons) == 0:
		return false
	var vehicle_rotations = [path_follow.rotation]
	for wagon in wagons:
		vehicle_rotations.append(wagon.path_follow.rotation)
	var vehicle_rotation_differences = []
	for i in len(vehicle_rotations) - 1:
		var rotation_difference = abs(vehicle_rotations[i] - vehicle_rotations[i + 1])
		rotation_difference = abs(rotation_difference - 2 * PI) if rotation_difference > PI else rotation_difference
		vehicle_rotation_differences.append(rotation_difference)
	# TODO: crashes the game if no wagons
	return vehicle_rotation_differences.max() > PI / 8 * 3


func _change_state(new_state: State):
	print("%s %s" % [name, State.keys()[state]])
	match new_state:
		State.RUNNING:
			target_speed = max_speed
		State.LOADING:
			target_speed = 0.0
			absolute_speed = 0.0
			_get_money_for_cargo()
		State.WAITING_FOR_MISSING_PLATFORM:
			var current_tile = Vector2i(get_train_position().snapped(Global.TILE))
			Global.show_popup("No platform at destination!", current_tile, self)
			no_route_timer.start()
			target_speed = 0.0
			absolute_speed = 0.0
		State.WAITING_FOR_TRACK_RESERVATION_CHANGE:
			if state != State.WAITING_FOR_TRACK_RESERVATION_CHANGE:
				_adjust_reservations_to_where_train_is()
				target_speed = 0.0
				absolute_speed = 0.0
				last_known_reservation_number = track_reservations.reservation_number
	state = new_state


func _get_money_for_cargo():
	var resource_counts: Dictionary[Global.ResourceType, int] = {}
	for resource_type in Global.ResourceType.values():
		for wagon in wagons:
			var resource_count = wagon.get_resource_count(resource_type)
			if resource_count > 0:
				if resource_type not in resource_counts:
					resource_counts[resource_type] = 0
				resource_counts[resource_type] += resource_count
	var train_position = get_train_position().snapped(Global.TILE)
	var money_earned = 0
	for resource_type in resource_counts:
		money_earned += resource_counts[resource_type] * _get_price_at_adjacent_stations(resource_type, train_position)
	if money_earned > 0:
		Global.show_popup("$%s" % money_earned, train_position, self)
		AudioManager.play(AudioManager.COIN_SPLASH, global_position)
		GlobalBank.earn(money_earned)


func _get_price_at_adjacent_stations(resource_type: Global.ResourceType, train_position: Vector2i) -> int:
	for station in platform_tile_set.stations_connected_to_platform(train_position, _get_stations()):
		if resource_type in station.accepts():
			return station.get_price(resource_type)
	return 0

func get_train_position() -> Vector2:
	# If the curve only has one point (for example when a train without wagons has just
	# been created at a one-platform station), the PathFollow2D will not be at that location,
	# but instead at (0, 0) instead, which will cause issues. To combat this, set the
	# position to the curve position instead.
	# This is a bit hacky, but since we might disallow trains without wagons later 
	# anyway, there is no point in spending much time on this.
	# This at least avoids the crash.
	# However, this does not solve the problem completely, since a single-length train
	# that just spawned but cannot move will be invisible.
	return path_follow.global_position if curve.point_count > 1 else curve.get_point_position(0)


func _get_wagon_positions() -> Array[Vector2i]:
	return Array(wagons.map(func(w): return Vector2i(w.path_follow.global_position.snapped(Global.TILE))), TYPE_VECTOR2I, "", null)


func select(is_selected: bool):
	canvas_group.get_material().set_shader_parameter("line_thickness", 3.0 if is_selected else 0.0)
	for wagon in wagons:
		wagon.select(is_selected)


func mark_for_destruction(is_marked: bool):
	red_marker.visible = is_marked
	for wagon in wagons:
		wagon.mark_for_destruction(is_marked)


func is_train_or_wagon_at_position(pos: Vector2i):
	var train_position = Vector2i(get_train_position().snapped(Global.TILE))
	if train_position == pos:
		return true
	for wagon_position in _get_wagon_positions():
		if wagon_position == pos:
			return true
	return false


func _get_new_state_at_end_of_curve() -> State:
	var destination_tile = destinations[destination_index]
	var current_tile = Vector2i(get_train_position().snapped(Global.TILE))
	var target_tile = (
		_furthest_in_at_platform(destination_tile)
		if current_tile in platform_tile_set.connected_platform_tile_positions(destination_tile)
		else destination_tile)
	if current_tile == target_tile:
		return State.LOADING
	elif not platform_tile_set.has_platform(target_tile):
		return State.WAITING_FOR_MISSING_PLATFORM
	else:
		return _try_set_new_curve_and_return_new_state(target_tile, false)


func _furthest_in_at_platform(tile: Vector2i) -> Vector2i:
	var endpoints = platform_tile_set.platform_endpoints(tile)
	var degrees = posmod(path_follow.rotation_degrees, 360)
	match degrees:
		0:
			return endpoints[0] if endpoints[0].x > endpoints[1].x else endpoints[1]
		90:
			return endpoints[0] if endpoints[0].y > endpoints[1].y else endpoints[1]
		180:
			return endpoints[0] if endpoints[0].x < endpoints[1].x else endpoints[1]
		270:
			return endpoints[0] if endpoints[0].y < endpoints[1].y else endpoints[1]
		_:
			assert(false, "strange amount of degrees")
	return Vector2i() # never hit


## Sets a new path from the station, possibly turning train around
## [br][point_path] is a path that goes from either end of the platform.
## [br][platform_tile_positions] is always ordered and starting at the train position
## [br]Returns the chopped-off point_path, so it can be used for other purposes
func set_new_curve_from_platform(point_path: PackedVector2Array, platform_tile_positions: Array[Vector2i]):
	# Two cases: either the next stop lies forward, or the next stop lies backwards.
	var vector2i_point_path = Array(point_path).map(func(x): return Vector2i(x))
	var path_indices = [vector2i_point_path.find(platform_tile_positions[0]),
						vector2i_point_path.find(platform_tile_positions[-1])]
	path_indices.sort()
	# Next stop lies forward
	if path_indices[0] == -1:
		platform_tile_positions.reverse()
		point_path = PackedVector2Array(platform_tile_positions) + point_path.slice(1)
	# Next stop lies backwards
	# do nothing, we have entire path already

	curve = Curve2D.new()
	for pos in point_path:
		if Vector2i(pos) in platform_tile_positions:
			curve.add_point(pos)

	path_follow.progress = (len(platform_tile_positions) - 1) * Global.TILE_SIZE
	for i in len(wagons):
		var wagon = wagons[i]
		wagon.curve = curve
		# Set the progress for each wagon so that it is a number of tiles after
		# the train equal to the number of wagons
		# Example: wagon 0 starts at distance 2 on the curve, since the curve
		# starts one ahead of the train
		wagon.path_follow.progress = path_follow.progress - (i + 1) * Global.TILE_SIZE
	# The below code seems to be unnecesary?
	# var new_point_path = point_path.slice(len(platform_tile_positions) - 1)
	# add_next_point_to_curve(new_point_path)
	# return new_point_path


func _adjust_reservations_to_where_train_is():
	var positions_to_reserve: Array[Vector2i] = [Vector2i(get_train_position().snapped(Global.TILE))]
	for pos in _get_wagon_positions():
		positions_to_reserve.append(pos)
	positions_to_reserve = track_set.get_segments_connected_to_positions(positions_to_reserve)
	track_reservations.reserve_train_positions(positions_to_reserve, self)


func _load_and_unload() -> bool:
	var train_position = get_train_position().snapped(Global.TILE)
	var reversed_wagons_at_platform: Array[Wagon] = []
	for i in wagon_count:
		var wagon = wagons[-i - 1]
		if Vector2i(wagon.get_wagon_position().snapped(Global.TILE)) in platform_tile_set.connected_platform_tile_positions(train_position):
			reversed_wagons_at_platform.append(wagon)
	for station in platform_tile_set.stations_connected_to_platform(train_position, _get_stations()):
		for wagon in reversed_wagons_at_platform:
			for resource_type in station.accepts():
				var resource_count = wagon.get_resource_count(resource_type)
				if resource_count > 0:
					wagon.unload_to_station(resource_type, station)
					return true
		for wagon in reversed_wagons_at_platform:
			for resource_type in _resources_accepted_at_other_destinations(destination_index):
				if station.get_resource_count(resource_type) > 0 and wagon.get_total_resource_count() < wagon.max_capacity:
					station.remove_resource(resource_type)
					wagon.add_resource(resource_type)
					return true
	return false


func _resources_accepted_at_other_destinations(this_destination_index: int) -> Array[Global.ResourceType]:
	var resource_types_dict: Dictionary[Global.ResourceType, int] = {}
	for i in len(destinations):
		if i == this_destination_index:
			continue
		for station in platform_tile_set.stations_connected_to_platform(destinations[i], _get_stations()):
			for resource_type in station.accepts():
				resource_types_dict[resource_type] = 0
	return resource_types_dict.keys()


func _get_stations() -> Array[Station]:
	var stations: Array[Station] = []
	for node in get_tree().get_nodes_in_group("stations"):
		if node is Station:
			stations.append(node)
	return stations


func _try_set_new_curve_and_return_new_state(target_position: Vector2i, is_at_station: bool) -> State:
	var current_position = Vector2i(get_train_position().snapped(Global.TILE))
	var new_astar = astar.clone()
	# Set wagon positions to disabled to prevent turnaround.
	var is_turnaround_allowed = is_at_station
	while true:
		if not is_turnaround_allowed:
			for wagon_position in _get_wagon_positions():
				new_astar.set_position_disabled(wagon_position)

		var point_path = new_astar.get_point_path(current_position, target_position)

		if not point_path:
			return State.WAITING_FOR_TRACK_RESERVATION_CHANGE

		# point_path goes from the position of the train engine, but we want to start
		# reserving at the position ahead of the train.
		var reservation_point_path = point_path.slice(1)
		# When starting from a platform, the point_path goes from the end of the platform,
		# so we have to skip all the platform tiles before we can start reserving tiles.
		# However (and this might be a bug) this was triggered when the train was
		# just created, and crashing since the path was just until the end of the current
		# station. So to avoid this, do not skip the platform tiles if the path does
		# not extend beyond the platform tiles.
		if is_at_station:
			while len(reservation_point_path) > 1 and platform_tile_set.has_platform(reservation_point_path[0]):
				reservation_point_path = reservation_point_path.slice(1)

		var upcoming_positions_until_next_non_intersection := _get_positions_until_next_non_intersection(reservation_point_path)
		var pos_reserved_by_other_train_or_none = _get_first_position_reserved_by_other_train(upcoming_positions_until_next_non_intersection)
		if pos_reserved_by_other_train_or_none.has_value:
			# Current shortest route is blocked by another train, go back and try to find another route
			new_astar.set_position_disabled(pos_reserved_by_other_train_or_none.value)
			continue
		# No intersections or reserved track directly ahead, reserve and continue
		var position_that_could_not_be_reserved_or_none = _reserve_forward_positions(upcoming_positions_until_next_non_intersection)
		if not position_that_could_not_be_reserved_or_none.has_value:
			if is_at_station:
				var platform_tile_positions = platform_tile_set.connected_ordered_platform_tile_positions(current_position, current_position)
				set_new_curve_from_platform(point_path, platform_tile_positions)
			else:
				curve.add_point(point_path[1])
			return State.RUNNING
		else:
			# I think: the train is before an intersection and the next position after intersection is reserved by a train
			# TODO: if this is true, it can probably be made clearer.
			return State.WAITING_FOR_TRACK_RESERVATION_CHANGE
	# Just to appease the type checker
	return State.RUNNING


func _get_positions_until_next_non_intersection(positions: PackedVector2Array) -> Array[Vector2i]:
	var return_value: Array[Vector2i] = []
	for pos in positions:
		return_value.append(Vector2i(pos))
		if not track_set.is_intersection(Vector2i(pos)):
			return return_value
	assert(false, "train path ends at intersection, this should not happen")
	return []


func _get_first_position_reserved_by_other_train(positions: Array[Vector2i]) -> Global.Vector2iOrNone:
	for pos in positions:
		if track_reservations.is_reserved_by_another_train(pos, self):
			return Global.Vector2iOrNone.new(true, pos)
	return Global.Vector2iOrNone.new(false)


func _reserve_forward_positions(forward_positions: Array[Vector2i]) -> Global.Vector2iOrNone:
	var positions_to_reserve = forward_positions.duplicate()
	positions_to_reserve.append(Vector2i(get_train_position().snapped(Global.TILE)))
	for pos in _get_wagon_positions():
		positions_to_reserve.append(pos)
	var segments_to_reserve = track_set.get_segments_connected_to_positions(positions_to_reserve)
	return track_reservations.reserve_train_positions(segments_to_reserve, self)
