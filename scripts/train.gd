extends Path2D

class_name Train

const WAGON = preload("res://scenes/wagon.tscn")

signal end_of_curve_reached(train: Train)
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
@onready var no_route_timer := $NoRouteTimer
@onready var red_marker := $RigidBody2D/RedMarker

var destinations: Array[Vector2i] = []
var destination_index := 0

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
		wagon.path_follow.progress += delta * absolute_speed

	# Check if we are reaching the end of curve the NEXT frame, in order to not get
	# stop-start behavior. This makes the train jump forward slightly though, so it is
	# still not ideal.
	if path_follow.progress + delta * absolute_speed >= curve.get_baked_length():
		end_of_curve_reached.emit(self)
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
	add_next_point_to_curve(point_path.slice(len(platform_tile_positions) - 1))

## Adds the next point in a path to the current curve.
## [br] the first point of [train_point_path] shall be at the train engine.
## [br] assumes that [wagon_positions] has been previously populated.
func add_next_point_to_curve(train_point_path: PackedVector2Array):
	if len(train_point_path) > 1:
		curve.add_point(train_point_path[1])

func get_train_position() -> Vector2:
	return path_follow.global_position

func get_wagon_positions() -> Array:
	return wagons.map(func(w): return w.path_follow.global_position.snapped(Global.TILE))

func mark_for_destruction(is_marked: bool):
	red_marker.visible = is_marked
	for wagon in wagons:
		wagon.mark_for_destruction(is_marked)
