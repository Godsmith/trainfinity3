extends Path2D

class_name Train

const WAGON = preload("res://scenes/wagon.tscn")

signal end_reached(train: Train)
signal tile_reached(train: Train, position: Vector2i)
signal train_clicked(train: Train)

@export var max_speed := 20.0
@export var target_speed := 0.0
@export var absolute_speed := 0.0
@export var acceleration := 6.0
@export var wagons: Array = []

var last_corner_checked = Vector2(0.0, 0.0)
var on_rails := true
# TODO: consider changing to "starting wagon count"
# and retrieving the number of wagons dynamically instead
var wagon_count = 3
var is_stopped_at_station = false
var is_in_sharp_corner = false
var last_delta = 0.0

# A progress position where, when the train passes here, it has passed the last
# sharp corner and can accelerate up to max speed again
var progress_point_past_sharp_corner = 0.0

@onready var path_follow := $PathFollow2D
@onready var polygon := $RigidBody2D/LightOccluder2D
@onready var rigid_body := $RigidBody2D
@onready var ore_timer := $OreTimer
@onready var no_route_timer := $NoRouteTimer
@onready var red_marker := $RigidBody2D/RedMarker

var destinations: Array[Vector2i] = []
var destination_index := 0

func _ready() -> void:
	for i in wagon_count:
		var wagon = WAGON.instantiate()
		wagons.append(wagon)
		add_child(wagon)
	path_follow.progress = wagon_count * Global.TILE_SIZE

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
	last_delta = delta
	if not on_rails:
		return

	if absolute_speed < target_speed:
		absolute_speed += acceleration * delta

	var curve_point_index = _approaching_curve_point()

	if curve_point_index > 0 and curve_point_index < curve.point_count - 1:
		var angle = _angle_between_points(curve.get_point_position(curve_point_index - 1),
										  curve.get_point_position(curve_point_index),
										  curve.get_point_position(curve_point_index + 1))
		if angle < PI / 2 + 0.05: # 90 degrees or lower
			target_speed = 5.0
			absolute_speed = target_speed
			progress_point_past_sharp_corner = path_follow.progress + Global.TILE_SIZE * wagon_count
			is_in_sharp_corner = true

	if is_in_sharp_corner:
		if path_follow.progress > progress_point_past_sharp_corner:
			target_speed = max_speed
			is_in_sharp_corner = false

	path_follow.progress += delta * absolute_speed
	for wagon in wagons:
		wagon.path_follow.progress = path_follow.progress

	if path_follow.progress >= curve.get_baked_length() and target_speed > 0.0 and not is_stopped_at_station:
		end_reached.emit(self)
	
	# Need to do this at the end of the method, so that we don't adjust wagons etc 
	# after on_rails is set to false
	if curve_point_index != -1:
		tile_reached.emit(self, Vector2i(curve.get_point_position(curve_point_index)))

func _approaching_curve_point() -> int:
	for i in curve.point_count:
		var point = curve.get_point_position(i)
		if point.distance_squared_to(path_follow.position) < 4.0:
			if not point == last_corner_checked:
				last_corner_checked = point
				return i
	return -1

static func _angle_between_points(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ba = a - b
	var bc = c - b
	return abs(ba.angle_to(bc)) # signed angle in radians (-π..π)

func start_from_station(point_path: PackedVector2Array):
	# Set wagon starting locations
	for i in len(wagons):
		var wagon = wagons[i]
		var wagon_curve = Curve2D.new()
		wagon_curve.add_point(point_path[wagons.size() - i - 1])
		wagon_curve.add_point(point_path[wagons.size() - i])
		wagon.curve = wagon_curve
		wagon.path_follow.progress = 0.0

	target_speed = max_speed
	is_stopped_at_station = false

func set_new_curve(point_path: PackedVector2Array):
	var new_curve = Curve2D.new()
	new_curve.add_point(point_path[0])
	new_curve.add_point(point_path[1])
	curve = new_curve
	#print("new curve set: %s" % curve.get_baked_points())
	path_follow.progress = 0.0

	# set wagon curves
	var wagon_ahead_position = point_path[0]
	for wagon in wagons:
		var wagon_curve = Curve2D.new()
		var last_point_of_previous_curve = last(wagon.curve.get_baked_points())
		wagon_curve.add_point(last_point_of_previous_curve)
		wagon_curve.add_point(wagon_ahead_position)
		wagon.curve = wagon_curve
		wagon.path_follow.progress = 0.0
		wagon_ahead_position = last_point_of_previous_curve

static func last(array: PackedVector2Array):
	return array.get(len(array) - 1)
	
func get_train_position() -> Vector2:
	return rigid_body.global_position

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
