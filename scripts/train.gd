extends Path2D

class_name Train

const WAGON = preload("res://scenes/wagon.tscn")

signal end_reached(train: Train)

@export var max_speed := 20.0
@export var target_speed := max_speed
@export var absolute_speed := 0.0
@export var acceleration := 6.0
@export var wagons: Array = []

var direction := 1
var last_progress := 0.0
var last_corner_checked = Vector2(0.0, 0.0)
var on_rails := true
# TODO: consider changing to "starting wagon count"
# and retrieving the number of wagons dynamically instead
var wagon_count = 3
var is_stopped = false

@onready var path_follow := $PathFollow2D
@onready var polygon := $RigidBody2D/LightOccluder2D
@onready var rigid_body := $RigidBody2D
@onready var timer := $Timer

func _ready() -> void:
	for i in wagon_count:
		var wagon = WAGON.instantiate()
		wagons.append(wagon)
		add_child(wagon)
	path_follow.progress = wagon_count * Global.TILE_SIZE

func get_linear_velocity(path_follow_: PathFollow2D, delta: float):
	var current_pos = path_follow_.global_position
	path_follow_.progress += delta * absolute_speed * direction
	var next_pos = path_follow_.global_position

	var velocity = (next_pos - current_pos) / delta
	return velocity


func _physics_process(_delta: float) -> void:
	if on_rails:
		rigid_body.global_position = path_follow.global_position
		rigid_body.rotation = path_follow.rotation if direction == 1 else path_follow.rotation + PI
	# if <collision>:
	#	derail(delta)

func derail(delta):
	on_rails = false
	rigid_body.linear_velocity = get_linear_velocity(path_follow, delta)
	for wagon in wagons:
		wagon.rigid_body.linear_velocity = get_linear_velocity(wagon, delta)
		wagon.collision_shape.disabled = false
		get_parent().add_child(wagon.rigid_body)


func _process(delta):
	if not on_rails:
		return

	if absolute_speed < target_speed:
		absolute_speed += acceleration * delta

	for i in curve.point_count:
		var point = curve.get_point_position(i)
		if point.distance_squared_to(path_follow.position) < 4.0:
			if not point == last_corner_checked:
				if i > 0 and i < curve.point_count - 1:
					var angle = angle_between_points(curve.get_point_position(i - 1), point, curve.get_point_position(i + 1))
					if angle < PI / 2 + 0.05: # 90 degrees or lower
						absolute_speed = 0.0
				last_corner_checked = point

	loop_movement(delta)

func angle_between_points(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ba = a - b
	var bc = c - b
	return abs(ba.angle_to(bc)) # signed angle in radians (-π..π)
	
func loop_movement(delta: Variant):
	path_follow.progress += delta * absolute_speed * direction
	for i in len(wagons):
		var wagon = wagons[i]
		var wagon_progress = path_follow.progress - direction * Global.TILE_SIZE * (i + 1)
		wagon.progress = clamp(wagon_progress, 0.0, curve.get_baked_length())
	if (path_follow.progress >= curve.get_baked_length() or path_follow.progress == 0.0) and target_speed > 0.0:
		target_speed = 0.0
		end_reached.emit(self, get_train_position().snapped(Global.TILE))
		absolute_speed = 0.0

func restart_after_station():
	direction *= -1
	if path_follow.progress >= curve.get_baked_length():
		path_follow.progress = curve.get_baked_length() - wagon_count * Global.TILE_SIZE
	if path_follow.progress == 0.0:
		path_follow.progress = wagon_count * Global.TILE_SIZE
	target_speed = max_speed
	

func set_path(path: Array[Vector2]):
	curve = Curve2D.new()
	for p in path:
		curve.add_point(p)

func get_train_position() -> Vector2:
	return rigid_body.global_position

func max_capacity() -> int:
	var out := 0
	for wagon in wagons:
		out += wagon.max_capacity
	return out

func add_ore(type: Ore.OreType):
	for wagon in wagons:
		if not wagon.ore == wagon.max_capacity:
			timer.start()
			await timer.timeout
			wagon.add_ore(type)
			break

func ore() -> int:
	var amount := 0
	for wagon in wagons:
		amount += wagon.ore
	return amount


func remove_all_ore():
	for i in len(wagons):
		var wagon = wagons[-i - 1]
		while wagon.ore > 0:
			timer.start()
			await timer.timeout
			wagon.remove_ore()
