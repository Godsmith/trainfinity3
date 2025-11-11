extends Path2D

class_name Train

const TRAIN = preload("res://scenes/train.tscn")
const WAGON = preload("res://scenes/wagon.tscn")

signal train_clicked(train: Train)

var platform_tile_set: PlatformTileSet
var track_set: TrackSet
var track_reservations: TrackReservations
var astar: Astar

var max_speed := 20.0
@export var target_speed := 0.0
@export var absolute_speed := 0.0
@export var acceleration := 6.0
@export var wagons: Array = []
@export var is_stopped = false

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

var destinations: Array[Vector2i] = []
var destination_index := 0

var reservation_color: Color

static func create(wagon_count_: int,
				   point_path: PackedVector2Array,
				   platform_tile_set_: PlatformTileSet,
				   track_set_: TrackSet,
				   track_reservations_: TrackReservations,
				   astar_: Astar) -> Train:
	var train = TRAIN.instantiate()
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

func derail():
	on_rails = false
	rigid_body.linear_velocity = _get_linear_velocity(path_follow)
	for wagon in wagons:
		wagon.rigid_body.linear_velocity = _get_linear_velocity(wagon)
		wagon.collision_shape.disabled = false
		var global_pos = wagon.rigid_body.global_position
		get_parent().add_child(wagon.rigid_body)
		# Global position changes after reparenting, so need to restore it
		wagon.rigid_body.global_position = global_pos

func _process(delta):
	# print("=before==========")
	# print(wagons[0].path_follow.position)
	# print(wagons[0].rigid_body.position)
	# print(wagons[1].path_follow.position)
	# print(wagons[1].rigid_body.position)
	last_delta = delta
	if not on_rails:
		return

	if is_stopped:
		return

	if _is_in_sharp_corner():
		target_speed = 5.0
		absolute_speed = target_speed
	else:
		target_speed = max_speed

	if absolute_speed < target_speed:
		absolute_speed += acceleration * delta

	path_follow.progress += delta * absolute_speed
	for wagon in wagons:
		wagon.path_follow.progress += delta * absolute_speed

	# Check if we are reaching the end of curve the NEXT frame, in order to not get
	# stop-start behavior. This makes the train jump forward slightly though, so it is
	# still not ideal.
	if path_follow.progress + delta * absolute_speed >= curve.get_baked_length():
		_on_train_reaches_end_of_curve()
	# print("=after==========")
	# print(wagons[0].path_follow.position)
	# print(wagons[0].rigid_body.position)
	# print(wagons[1].path_follow.position)
	# print(wagons[1].rigid_body.position)

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
	var new_point_path = point_path.slice(len(platform_tile_positions) - 1)
	add_next_point_to_curve(new_point_path)
	return new_point_path

## Adds the next point in a path to the current curve.
## [br] the first point of [train_point_path] shall be at the train engine.
## [br] assumes that [wagon_positions] has been previously populated.
func add_next_point_to_curve(train_point_path: PackedVector2Array):
	if len(train_point_path) > 1:
		curve.add_point(train_point_path[1])

func get_train_position() -> Vector2:
	return path_follow.global_position

func _get_wagon_positions() -> Array[Vector2i]:
	return Array(wagons.map(func(w): return Vector2i(w.path_follow.global_position.snapped(Global.TILE))), TYPE_VECTOR2I, "", null)

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


func _on_train_reaches_end_of_curve():
	_adjust_reservations_to_where_train_is()
	var destination_tile = destinations[destination_index]
	var current_tile = Vector2i(get_train_position().snapped(Global.TILE))

	var target_tile
	if current_tile in platform_tile_set.connected_platform_tile_positions(destination_tile):
		target_tile = _furthest_in_at_platform(destination_tile)
		if current_tile == target_tile:
			target_speed = 0.0
			absolute_speed = 0.0
			is_stopped = true
			# Store this into a variable now in case platform is removed when waiting
			var platform_tile_positions = platform_tile_set.connected_ordered_platform_tile_positions(current_tile, current_tile)
			await _load_and_unload()
			destination_index += 1
			destination_index %= len(destinations)
			target_tile = destinations[destination_index]
			var point_path = await _get_shortest_unblocked_path(target_tile, true)
			# Must check if the train has been deleted while we waited
			if is_instance_valid(self):
				set_new_curve_from_platform(point_path, platform_tile_positions)
				is_stopped = false
				target_speed = max_speed
			return
	else:
		target_tile = destination_tile

	while not platform_tile_set.has_platform(target_tile):
		Global.show_popup("No platform at destination!", current_tile, self)
		no_route_timer.start()
		target_speed = 0.0
		absolute_speed = 0.0
		is_stopped = true
		await no_route_timer.timeout
	var point_path = await _get_shortest_unblocked_path(target_tile, false)
	# Must check if the train has been deleted while we waited
	if not is_instance_valid(self):
		return
	add_next_point_to_curve(point_path)
	is_stopped = false
	target_speed = max_speed


func _adjust_reservations_to_where_train_is():
	var positions_to_reserve: Array[Vector2i] = [Vector2i(get_train_position().snapped(Global.TILE))]
	for pos in _get_wagon_positions():
		positions_to_reserve.append(pos)
	positions_to_reserve = track_set.get_segments_connected_to_positions(positions_to_reserve)
	track_reservations.reserve_train_positions(positions_to_reserve, self)


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


func _load_and_unload():
	var train_position = get_train_position().snapped(Global.TILE)
	var reversed_wagons_at_platform: Array[Wagon] = []
	for i in wagon_count:
		var wagon = wagons[-i - 1]
		if Vector2i(wagon.get_wagon_position().snapped(Global.TILE)) in platform_tile_set.connected_platform_tile_positions(train_position):
			reversed_wagons_at_platform.append(wagon)
	for station in platform_tile_set.stations_connected_to_platform(train_position, _get_stations()):
		for wagon in reversed_wagons_at_platform:
			for ore_type in station.accepts():
				var ore_count = wagon.get_ore_count(ore_type)
				if ore_count > 0:
					Global.show_popup("$%s" % ore_count, train_position, self)
					AudioManager.play(AudioManager.COIN_SPLASH, global_position)
				GlobalBank.earn(ore_count)
				await wagon.unload_to_station(ore_type, station)
				if not is_instance_valid(station):
					return
		for wagon in reversed_wagons_at_platform:
			for ore_type in _ores_accepted_at_other_destinations(destination_index):
				while station.get_ore_count(ore_type) > 0 and wagon.get_total_ore_count() < wagon.max_capacity:
					station.remove_ore(ore_type)
					await wagon.add_ore(ore_type)
					if not is_instance_valid(station):
						return


func _ores_accepted_at_other_destinations(this_destination_index: int) -> Array[Ore.OreType]:
	var ore_types_dict: Dictionary[Ore.OreType, int] = {}
	for i in len(destinations):
		if i == this_destination_index:
			continue
		for station in platform_tile_set.stations_connected_to_platform(destinations[i], _get_stations()):
			for ore_type in station.accepts():
				ore_types_dict[ore_type] = 0
	return ore_types_dict.keys()


func _get_stations() -> Array[Station]:
	var stations: Array[Station] = []
	for node in get_tree().get_nodes_in_group("stations"):
		if node is Station:
			stations.append(node)
	return stations


func _get_shortest_unblocked_path(target_position: Vector2i, is_at_station: bool) -> PackedVector2Array:
	var current_position = Vector2i(get_train_position().snapped(Global.TILE))
	var new_astar = astar.clone()
	# Set wagon positions to disabled to prevent turnaround.
	var is_turnaround_allowed = is_at_station
	if not is_turnaround_allowed:
		for wagon_position in _get_wagon_positions():
			new_astar.set_position_disabled(wagon_position)
	var is_reservation_successful = true
	while true:
		var point_path = new_astar.get_point_path(current_position, target_position)
		# If either there is no path, or there is a path but reservation was
		# unsuccesful, pause until track reservations are updated, after which we try to
		# reserve again
		if not point_path or not is_reservation_successful:
			_adjust_reservations_to_where_train_is()
			target_speed = 0.0
			absolute_speed = 0.0
			is_stopped = true
			var train_emitting_signal = await Events.track_reservations_updated
			if train_emitting_signal == self:
				return PackedVector2Array()
			# Must check if the train has been deleted while we waited
			if not is_instance_valid(self):
				return PackedVector2Array()
			# clone astar anew, removing all blocks
			new_astar = astar.clone()
			is_reservation_successful = true
			continue


		var reservation_point_path = point_path.slice(1)
		# When starting from a platform, the point_path goes from the end of the platform,
		# so we have to skip all the platform tiles before we can start reserving tiles
		if is_at_station:
			while platform_tile_set.has_platform(reservation_point_path[0]):
				reservation_point_path = reservation_point_path.slice(1)

		var upcoming_positions_until_next_non_intersection := _get_positions_until_next_non_intersection(reservation_point_path)
		var pos_reserved_by_other_train_or_none = _get_first_position_reserved_by_other_train(upcoming_positions_until_next_non_intersection)
		if pos_reserved_by_other_train_or_none.has_value:
			# Current shortest route is blocked by another train, go back and try to find another route
			new_astar.set_position_disabled(pos_reserved_by_other_train_or_none.value)
		else:
			# No intersections or reserved track directly ahead, reserve and continue
			var position_that_could_not_be_reserved_or_none = _reserve_forward_positions(upcoming_positions_until_next_non_intersection)
			if not position_that_could_not_be_reserved_or_none.has_value:
				return point_path
			is_reservation_successful = false
			
	# Just to appease syntax checker; this is never hit
	return PackedVector2Array()


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
