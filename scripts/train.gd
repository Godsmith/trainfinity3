extends Path2D

class_name Train

const WAGON = preload("res://scenes/wagon.tscn")

signal end_reached(train: Train)
signal train_clicked(train: Train)

@export var max_speed := 20.0
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
@onready var ore_timer := $OreTimer
@onready var no_route_timer := $NoRouteTimer
@onready var red_marker := $RigidBody2D/RedMarker

var destinations: Array[Vector2i] = []
var destination_index := 0

var previous_positions: Array[Vector2] = []

func _ready() -> void:
	for i in wagon_count:
		var wagon = WAGON.instantiate()
		wagons.append(wagon)
		add_child(wagon)
	#path_follow.progress = wagon_count * Global.TILE_SIZE

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
		wagon.path_follow.progress -= delta * absolute_speed
		#wagon.path_follow.progress = path_follow.progress

	if path_follow.progress >= curve.get_baked_length():
		# TODO: rename to end_of_curve
		end_reached.emit(self)
	# print("=after==========")
	# print(wagons[0].path_follow.position)
	# print(wagons[0].rigid_body.position)
	# print(wagons[1].path_follow.position)
	# print(wagons[1].rigid_body.position)

func _is_in_sharp_corner():
	var vehicle_rotations = [path_follow.rotation]
	for wagon in wagons:
		var wagon_rotation = wagon.path_follow.rotation + PI
		vehicle_rotations.append(wagon_rotation)
	var vehicle_rotation_differences = []
	for i in len(vehicle_rotations) - 1:
		var rotation_difference = abs(vehicle_rotations[i] - vehicle_rotations[i + 1])
		rotation_difference = abs(rotation_difference - 2 * PI) if rotation_difference > PI else rotation_difference
		vehicle_rotation_differences.append(rotation_difference)
	# TODO: crashes the game if no wagons
	return vehicle_rotation_differences.max() > PI / 8 * 3


func set_new_curve_from_station(point_path: PackedVector2Array):
	print("============= START FROM STATION ==================== ")
	# Jump forwards a number of tiles equalling the number of wagons
	# TODO: consider if we should start at the furthest end of the station instead, that
	# is not the same if the station is longer than the train.
	var train_point_path = point_path.slice(len(wagons))

	# Set initial starting value form previous positions
	# TODO: investigate if this is correct when station is longer than the train
	previous_positions = []
	for point in point_path.slice(0, len(wagons)):
		previous_positions.append(point)

	set_new_curve(train_point_path, true)


func set_new_curve(point_path: PackedVector2Array, is_at_station: bool):
	var new_curve = Curve2D.new()
	new_curve.add_point(point_path[0])
	if len(point_path) > 1:
		new_curve.add_point(point_path[1])
	curve = new_curve
	path_follow.progress = 0.0

	_set_wagon_curves_and_progress(point_path, is_at_station)

	# Maintain a LIFO queue of previous train positions to use for creating 
	previous_positions.pop_front()
	previous_positions.append(point_path[0])


func _set_wagon_curves_and_progress(point_path: PackedVector2Array, is_at_station: bool):
	# TODO: keep these reversed so that we don't have to reverse them all the time
	var reversed_previous_positions = previous_positions.duplicate()
	reversed_previous_positions.reverse()
	# If the train is traveling diagonally, the distance from the train to the
	# first wagon is extra long
	var extra_slack := 0.0
	if not is_at_station:
		extra_slack = sqrt(2) - 1.0 if point_path[0].x != point_path[1].x and point_path[0].y != point_path[1].y else 0.0
	# The curve starts one tile ahead of the train, so that on diagonal tracks, the
	# first wagon can continue past where the train started
	var wagon_curve_positions = [] if is_at_station else [point_path[1]]
	wagon_curve_positions += [point_path[0]] + reversed_previous_positions
	var wagon_curve = Curve2D.new()
	for pos in wagon_curve_positions:
		wagon_curve.add_point(pos)
	for i in len(wagons):
		var wagon = wagons[i]
		wagon.curve = wagon_curve
		# Set the progress for each wagon so that it is a number of tiles after 
		# the train equal to the number of wagons
		# Example: wagon 0 starts at distance 2 on the curve, since the curve
		# starts one ahead of the train
		# Also add the extra slack as mentioned above
		wagon.path_follow.progress = (extra_slack + i + 2) * Global.TILE_SIZE

func get_train_position() -> Vector2:
	return path_follow.global_position

func max_capacity() -> int:
	var out := 0
	for wagon in wagons:
		out += wagon.max_capacity
	return out

func add_ore(type: Ore.OreType):
	for wagon in wagons:
		if not wagon.get_total_ore_count() == wagon.max_capacity:
			ore_timer.start()
			await ore_timer.timeout
			wagon.add_ore(type)
			break

func get_total_ore_count() -> int:
	var amount := 0
	for ore_type in Ore.OreType.values():
		amount += get_ore_count(ore_type)
	return amount

func get_ore_count(ore_type: Ore.OreType) -> int:
	var amount := 0
	for wagon in wagons:
		amount += wagon.get_ore_count(ore_type)
	return amount

func remove_all_ore(ore_type):
	for i in len(wagons):
		var wagon = wagons[-i - 1]
		while wagon.get_ore_count(ore_type) > 0:
			ore_timer.start()
			await ore_timer.timeout
			wagon.remove_ore(ore_type)

func mark_for_destruction(is_marked: bool):
	red_marker.visible = is_marked
	for wagon in wagons:
		wagon.mark_for_destruction(is_marked)
