extends Path2D

class_name Train

const TRAIN = preload("res://scenes/train.tscn")
const WAGON = preload("res://scenes/wagon.tscn")

signal train_clicked(train: Train)
signal train_content_changed(train: Train)
signal train_state_changed(train: Train)

enum State {RUNNING, LOADING, WAITING_FOR_TRACK_RESERVATION_CHANGE, WAITING_FOR_MISSING_PLATFORM,
			WAITING_FOR_MISSING_STATION, STARTING_FROM_PLATFORM, WAITING_SINCE_DESTINATIONS_AT_SAME_PLATFORM}

var state: State = State.RUNNING
# Needed because paths will be different depending on if the train is waiting
# for reservation change at a station or not at a staton
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

# Set to true when train goes to LOADING and false when it goes to RUNNING.
# Checked when setting new path, to determine if the train is allowed to turn around.
var is_at_station := false

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

# Position of stations between which the train runs
var destinations: Array[Vector2i] = []
var destination_index := 0

var reservation_color: Color

static func try_create(name_: String,
				   station1: Station,
				   station2: Station,
				   platform_tile_set_: PlatformTileSet,
				   track_set_: TrackSet,
				   track_reservations_: TrackReservations,
				   astar_: Astar,
				   add_child_callback: Callable):
	if station1 == station2:
		return
	var positions = platform_tile_set_.get_connected_platform_positions_adjacent_to(station1, station2, astar_)
	if len(positions) == 0:
		return
	var pos1 = positions[0]
	var pos2 = positions[1]
	if not GlobalBank.can_afford(Global.Asset.TRAIN):
		return
	if track_reservations_.is_reserved(pos1):
		# TODO: test that globalbank can be used here
		Global.show_popup("Track reserved!", pos1, GlobalBank)
		Global.show_popup("Track reserved!", pos2, GlobalBank)
		return

	# Get path from the beginning of the first tile of the source platform
	# to the last tile of the target platform
	var point_path = _get_point_path_between_platforms(pos1, pos2, platform_tile_set_, track_set_, astar_)
	if not point_path:
		return

	var wagon_count_ = min(platform_tile_set_.platform_size(pos1, track_set_), platform_tile_set_.platform_size(pos2, track_set_)) - 1

	var train = TRAIN.instantiate()
	train.name = name_
	train.wagon_count = wagon_count_
	train.destinations = [Vector2i(station1.position), Vector2i(station2.position)] as Array[Vector2i]
	train.platform_tile_set = platform_tile_set_
	train.track_set = track_set_
	train.track_reservations = track_reservations_
	train.astar = astar_

	add_child_callback.call(train)

	train.set_initial_curve(point_path)

	return train


## Returns the point path between two platforms. [br]
## The path included includes the two platforms. [br]
## A previous variant returned the longest possible path between the ends of the
## stations. However, this does not work in the edge case of a circular track. [br]
## Instead, compute the shortest paths between any two platform endpoints, and then
## add the platforms at the ends. [br]
## Returns an empty path if there is no path.
static func _get_point_path_between_platforms(platform_pos1: Vector2i,
									   platform_pos2: Vector2i, platform_tile_set_: PlatformTileSet, track_set_: TrackSet, astar_: Astar) -> PackedVector2Array:
	var point_paths: Array[PackedVector2Array] = []
	var platform1_positions = platform_tile_set_.ordered_platform_tile_positions(platform_pos1, track_set_)
	var platform2_positions = platform_tile_set_.ordered_platform_tile_positions(platform_pos2, track_set_)
	var platform1_endpoints = [platform1_positions[0], platform1_positions[-1]]
	var platform2_endpoints = [platform2_positions[0], platform2_positions[-1]]

	for p1 in platform1_endpoints:
		for p2 in platform2_endpoints:
			point_paths.append(astar_.get_point_path(p1, p2))
	point_paths.sort_custom(func(a, b): return len(a) < len(b))
	var shortest_path = point_paths[0]

	if Vector2i(shortest_path[0]) == platform1_endpoints[0]:
		platform1_positions.reverse()
	if Vector2i(shortest_path[-1]) == platform2_endpoints[-1]:
		platform2_positions.reverse()

	var out = PackedVector2Array()
	for pos in platform1_positions:
		out.append(pos)
	# Remove ends so that we just have the positions between the platforms
	for pos in shortest_path.slice(1, -1):
		out.append(pos)
	for pos in platform2_positions:
		out.append(pos)
	return out


func _ready() -> void:
	reservation_color = _random_color()
	max_speed = Upgrades.get_value(Upgrades.UpgradeType.TRAIN_MAX_SPEED)
	acceleration = Upgrades.get_value(Upgrades.UpgradeType.TRAIN_ACCELERATION)
	for i in wagon_count:
		var wagon = WAGON.instantiate()
		wagons.append(wagon)
		add_child(wagon)
		wagon.wagon_clicked.connect(func(): train_clicked.emit(self ))
		wagon.wagon_content_changed.connect(func(): train_content_changed.emit(self ))

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
		train_clicked.emit(self )

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
			is_at_station = false
			# Check if we are reaching the end of curve the NEXT frame, in order to not get
			# stop-start behavior. This makes the train jump forward slightly though, so it is
			# still not ideal.
			if path_follow.progress + delta * absolute_speed >= curve.get_baked_length():
				var new_state = _try_set_new_curve_and_return_new_state()
				if new_state != State.RUNNING:
					_change_state(new_state)
		State.WAITING_FOR_MISSING_PLATFORM, State.WAITING_FOR_MISSING_STATION:
			if no_route_timer.is_stopped():
				_change_state(_try_set_new_curve_and_return_new_state())
		State.WAITING_SINCE_DESTINATIONS_AT_SAME_PLATFORM:
			if no_route_timer.is_stopped():
				_change_state(State.RUNNING)
		State.LOADING:
			is_at_station = true
			if not ore_timer.is_stopped():
				return
			var has_loaded_or_unloaded = _load_and_unload()
			if has_loaded_or_unloaded:
				ore_timer.start()
			else:
				_change_state(_try_set_new_curve_and_return_new_state(true))
		State.WAITING_FOR_TRACK_RESERVATION_CHANGE:
			if track_reservations.reservation_number > last_known_reservation_number:
				last_known_reservation_number = track_reservations.reservation_number
				_change_state(_try_set_new_curve_and_return_new_state())


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
	match new_state:
		State.RUNNING:
			target_speed = max_speed
		State.LOADING:
			target_speed = 0.0
			absolute_speed = 0.0
			_get_money_for_cargo()
		State.WAITING_FOR_MISSING_PLATFORM:
			Global.show_popup("No platform adjacent to destination station!", _get_snapped_train_position(), self )
			no_route_timer.start()
			target_speed = 0.0
			absolute_speed = 0.0
		State.WAITING_FOR_MISSING_STATION:
			Global.show_popup("No station at destination!", _get_snapped_train_position(), self )
			no_route_timer.start()
			target_speed = 0.0
			absolute_speed = 0.0
		State.WAITING_FOR_TRACK_RESERVATION_CHANGE:
			if state != State.WAITING_FOR_TRACK_RESERVATION_CHANGE:
				_adjust_reservations_to_where_train_is()
				target_speed = 0.0
				absolute_speed = 0.0
				last_known_reservation_number = track_reservations.reservation_number
		State.WAITING_SINCE_DESTINATIONS_AT_SAME_PLATFORM:
			Global.show_popup("Both destinations at same platform!", _get_snapped_train_position(), self )
			no_route_timer.start()
			target_speed = 0.0
			absolute_speed = 0.0
	state = new_state
	print("%s %s" % [name, State.keys()[state]])
	train_state_changed.emit(self )


func _get_money_for_cargo():
	# TODO: this will give double the money if two stations adjacent to the platform
	# accepts the same goods.
	var train_position = get_train_position().snapped(Global.TILE)
	var money_earned = 0
	for station in platform_tile_set.stations_connected_to_platform(train_position, _get_stations(), track_set):
		for resource_type in station.accepts():
			for wagon in wagons:
				var resource_count = wagon.get_resource_count_not_picked_up_from(resource_type, Vector2i(station.position))
				money_earned += station.get_price(resource_type) * resource_count
	if money_earned > 0:
		Global.show_popup("$%s" % money_earned, train_position, self )
		AudioManager.play(AudioManager.COIN_SPLASH, global_position)
		GlobalBank.earn(money_earned)

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


func _get_snapped_train_position() -> Vector2i:
	return Vector2i(get_train_position().snapped(Global.TILE))


func _get_wagon_positions() -> Array[Vector2i]:
	return Array(wagons.map(func(w): return Vector2i(w.path_follow.global_position.snapped(Global.TILE))), TYPE_VECTOR2I, "", null)


func _get_snapped_train_and_wagon_positions() -> Array[Vector2i]:
	return [_get_snapped_train_position()] as Array[Vector2i] + _get_wagon_positions()


func select(is_selected: bool):
	canvas_group.get_material().set_shader_parameter("line_thickness", 3.0 if is_selected else 0.0)
	for wagon in wagons:
		wagon.select(is_selected)


func mark_for_destruction(is_marked: bool):
	red_marker.visible = is_marked
	for wagon in wagons:
		wagon.mark_for_destruction(is_marked)


func is_train_or_wagon_at_position(pos: Vector2i):
	if _get_snapped_train_position() == pos:
		return true
	for wagon_position in _get_wagon_positions():
		if wagon_position == pos:
			return true
	return false


## Returns the tile furthest in at the platform the train currently is on. [br]
## Returns [Vector2i.MAX] if [tile] is not in a platform_tile
func _furthest_in_at_platform(tile: Vector2i) -> Vector2i:
	var endpoints = platform_tile_set.platform_endpoints(tile, track_set)
	if not endpoints:
		return Vector2i.MAX
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


## point_path:              - - - - - - - >
## Train, platform, track: [T W W . .] . . .
## curve:                   < - -
## The output of this method must be a curve that places the train engine at the end of
## a platform, otherwise the train will get stuck in RUNNING
func set_initial_curve(point_path: PackedVector2Array):
	var path_covering_train = point_path.slice(0, len(wagons) + 1)
	path_covering_train.reverse()
	curve = Curve2D.new()
	for pos in path_covering_train:
		curve.add_point(pos)
	_set_progress_from_platform()


## Sets a new curve from the station, possibly turning train around
## [br][point_path] is a path that goes from either end of the platform to the next destination.
## [br][train_position] is the current train engine position
func _set_new_curve_from_platform(point_path: PackedVector2Array):
	# Two cases: either the next stop lies forward, or the next stop lies backwards.
	# 1. point_path:               - - - - - - - >
	#    Train, platform, track: [T W W . .] . . .
	#    returned curve:          - - >
	# 2. point_path:        < - - -
	#    Train, platform, track: [T W W . .]
	#    returned curve:          < - -
	var vector2i_point_path = Array(point_path).map(func(x): return Vector2i(x))
	var train_and_wagon_positions = _get_snapped_train_and_wagon_positions()
	var last_wagon_position = train_and_wagon_positions[-1]
	if last_wagon_position not in vector2i_point_path:
		train_and_wagon_positions.reverse()
	curve = Curve2D.new()
	for pos in train_and_wagon_positions:
		curve.add_point(pos)
	_set_progress_from_platform()


func _set_progress_from_platform():
	# Set the initial position of the train so far forward so that the wagons fit
	path_follow.progress = len(wagons) * Global.TILE_SIZE
	for i in len(wagons):
		var wagon = wagons[i]
		wagon.curve = curve
		# Set the progress for each wagon so that it is a number of tiles after
		# the train equal to the number of wagons
		# Example: wagon 0 starts at distance 2 on the curve, since the curve
		# starts one ahead of the train
		wagon.path_follow.progress = path_follow.progress - (i + 1) * Global.TILE_SIZE


func _adjust_reservations_to_where_train_is():
	var positions_to_reserve = track_set.get_segments_connected_to_positions(_get_snapped_train_and_wagon_positions())
	track_reservations.try_reserve_train_positions(positions_to_reserve, self )


## Only load and unload from wagons that are actually at the platform
func _load_and_unload() -> bool:
	var train_position = get_train_position().snapped(Global.TILE)
	var wagons_at_platform: Array[Wagon] = []
	for wagon in wagons:
		if Vector2i(wagon.get_wagon_position().snapped(Global.TILE)) in platform_tile_set.connected_platform_tile_positions(train_position, track_set):
			wagons_at_platform.append(wagon)
	var reversed_wagons_at_platform: Array[Wagon] = []
	for i in wagon_count:
		var wagon = wagons[-i - 1]
		if Vector2i(wagon.get_wagon_position().snapped(Global.TILE)) in platform_tile_set.connected_platform_tile_positions(train_position, track_set):
			reversed_wagons_at_platform.append(wagon)
	for station in platform_tile_set.stations_connected_to_platform(train_position, _get_stations(), track_set):
		for wagon in reversed_wagons_at_platform:
			for resource_type in station.accepts():
				var resource_count = wagon.get_resource_count_not_picked_up_from(resource_type, Vector2i(station.position))
				if resource_count > 0:
					wagon.unload_to_station(resource_type, station)
					return true
		for wagon in wagons_at_platform:
			for resource_type in _resources_accepted_at_other_destinations(destination_index):
				if station.get_resource_count(resource_type) > 0 and wagon.get_total_resource_count() < wagon.max_capacity:
					station.remove_resource(resource_type)
					wagon.add_resource(resource_type, Vector2i(station.position))
					return true
	return false


func _resources_accepted_at_other_destinations(this_destination_index: int) -> Array[Global.ResourceType]:
	var resource_types_dict: Dictionary[Global.ResourceType, int] = {}
	var stations_from_position: Dictionary[Vector2i, Station] = {}
	for station in _get_stations():
		stations_from_position[Vector2i(station.position)] = station
	for i in len(destinations):
		if i == this_destination_index:
			continue
		# Check so that destination station has not been removed in the middle of loading
		if destinations[i] not in stations_from_position:
			continue
		for resource_type in stations_from_position[destinations[i]].accepts():
			resource_types_dict[resource_type] = 0
	return resource_types_dict.keys()


func _get_stations() -> Array[Station]:
	var stations: Array[Station] = []
	for node in get_tree().get_nodes_in_group("stations"):
		if node is Station:
			stations.append(node)
	return stations


func _try_set_new_curve_and_return_new_state(go_to_next_destination := false) -> State:
	if go_to_next_destination:
		destination_index += 1
		destination_index %= len(destinations)

	# 1. Validate target station
	var target_station_position = destinations[destination_index]
	if not _is_station_at_position(target_station_position):
		return State.WAITING_FOR_MISSING_STATION

	var platform_positions_adjacent_to_target_station = platform_tile_set.adjacent_platform_positions(target_station_position)
	if not platform_positions_adjacent_to_target_station:
		return State.WAITING_FOR_MISSING_PLATFORM

	# 2. Check for "same platform" conflict
	if _is_at_destination_platform() and go_to_next_destination:
		# We are already at the destination platform, but we have just
		# switched destination. This means that both destinations are on
		# the same platform.
		# Having the train go from a station to itself violates a lot of assumptions in
		# other parts of the code, so explicitly disallow this
		return State.WAITING_SINCE_DESTINATIONS_AT_SAME_PLATFORM

	# 3. Check if arrived
	var point_furthest_in_at_platform = _furthest_in_at_platform(_get_snapped_train_position())
	if _is_at_destination_platform() and _get_snapped_train_position() == point_furthest_in_at_platform:
		return State.LOADING

	# 4. Create initial astar for pathfinding
	var new_astar = astar.clone()
	# If not at a station, set wagon positions to disabled to prevent turnaround
	if not is_at_station:
		for wagon_position in _get_wagon_positions():
			new_astar.set_position_disabled(wagon_position)

	# 5. Try to find a path to the destination. If the first segment of the path is
	#    reserved, find a new path. If no new path can be found, abort.
	var point_path: PackedVector2Array
	while true:
		point_path = _get_point_path_to_destination(new_astar, point_furthest_in_at_platform, platform_positions_adjacent_to_target_station)

		if not point_path:
			return State.WAITING_FOR_TRACK_RESERVATION_CHANGE
		
		var segment := _get_positions_until_next_non_intersection(point_path)

		# Try to reserve first segment of shortest route
		var blocked_position = _try_reserve_forward_positions(segment)
		if not blocked_position.has_value:
			break

		# First segment of shortest route is blocked by another train, go back and try to find another route
		new_astar.set_position_disabled(blocked_position.value)

	if is_at_station:
		_set_new_curve_from_platform(point_path)
		# Remove points from the path as necessary until the first point in
		# point_path is the train engine
		while Vector2i(point_path[0]) != _get_snapped_train_position():
			point_path = point_path.slice(1)
	curve.add_point(point_path[1])

	return State.RUNNING


func _is_station_at_position(station_position: Vector2i):
	var station_positions = _get_stations().map(func(station): return Vector2i(station.position))
	return station_position in station_positions


func _is_at_destination_platform():
	var target_station_position = destinations[destination_index]
	var platform_positions_adjacent_to_target_station = platform_tile_set.adjacent_platform_positions(target_station_position)
	var platforms = platform_positions_adjacent_to_target_station.map(func(pos): return platform_tile_set.ordered_platform_tile_positions(pos, track_set))
	var train_position = _get_snapped_train_position()
	for platform in platforms:
		if train_position in platform:
			return true
	return false


func _get_point_path_to_destination(new_astar: Astar, point_furthest_in_at_platform: Vector2i,
									platform_positions_adjacent_to_target_station: Array[Vector2i]) -> PackedVector2Array:
	var point_paths: Array[PackedVector2Array]
	if _is_at_destination_platform():
		point_paths = [new_astar.get_point_path(_get_snapped_train_position(), point_furthest_in_at_platform)]
	else:
		point_paths.assign(platform_positions_adjacent_to_target_station.map(func(pos): return new_astar.get_point_path(_get_snapped_train_position(), pos)))

	point_paths = point_paths.filter(func(path): return len(path) > 0)
	if not point_paths:
		return PackedVector2Array()

	point_paths.sort_custom(func(path1, path2): return len(path1) < len(path2))
	return point_paths[0]


func _get_positions_until_next_non_intersection(point_path: PackedVector2Array) -> Array[Vector2i]:
	# point_path goes from the position of the train engine, but we want to start
	# reserving at the position ahead of the train.
	var reservation_point_path = point_path.slice(1)
	# When starting from a platform, point_path starts at the far end of the platform,
	# so we have to skip all the platform tiles before we can start reserving tiles,
	# otherwise if there is an intersection just after the platform we will only reserve
	# the tiles on the platform and nothing more.
	# However (and this might be a bug) this was triggered when the train was
	# just created, and crashing since the path was just until the end of the current
	# station. So to avoid this, do not skip the platform tiles if the path does
	# not extend beyond the platform tiles.
	if is_at_station:
		while len(reservation_point_path) > 1 and platform_tile_set.has_platform(reservation_point_path[0]):
			reservation_point_path = reservation_point_path.slice(1)
	var segment: Array[Vector2i] = []
	for pos in reservation_point_path:
		segment.append(Vector2i(pos))
		if not track_set.is_intersection(Vector2i(pos)):
			return segment
	#assert(false, "train path ends at intersection, this should not happen")
	return []


func _get_first_position_reserved_by_other_train(positions: Array[Vector2i]) -> Global.Vector2iOrNone:
	for pos in positions:
		if track_reservations.is_reserved_by_another_train(pos, self ):
			return Global.Vector2iOrNone.new(true, pos)
	return Global.Vector2iOrNone.new(false)


func _try_reserve_forward_positions(forward_positions: Array[Vector2i]) -> Global.Vector2iOrNone:
	var positions_to_reserve = forward_positions.duplicate()
	positions_to_reserve.append_array(_get_snapped_train_and_wagon_positions())
	var segments_to_reserve = track_set.get_segments_connected_to_positions(positions_to_reserve)
	return track_reservations.try_reserve_train_positions(segments_to_reserve, self )
