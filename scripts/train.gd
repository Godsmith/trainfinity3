extends Path2D

class_name Train

const WAGON = preload("res://scenes/wagon.tscn")

signal end_reached(train: Train)

@export var max_speed := 20.0
@export var target_speed := 0.0
@export var absolute_speed := 0.0
@export var acceleration := 6.0
@export var wagons: Array = []

var last_progress := 0.0
var last_corner_checked = Vector2(0.0, 0.0)
var on_rails := true
# TODO: consider changing to "starting wagon count"
# and retrieving the number of wagons dynamically instead
var wagon_count = 3
var is_stopped_at_station = false
var is_in_sharp_corner = false

# A progress position where, when the train passes here, it has passed the last
# sharp corner and can accelerate up to max speed again
var progress_point_past_sharp_corner = 0.0

@onready var path_follow := $PathFollow2D
@onready var polygon := $RigidBody2D/LightOccluder2D
@onready var rigid_body := $RigidBody2D
@onready var ore_timer := $OreTimer
@onready var no_route_timer := $NoRouteTimer

var target_positions: Array[Vector2i] = []

func _ready() -> void:
	for i in wagon_count:
		var wagon = WAGON.instantiate()
		wagons.append(wagon)
		add_child(wagon)
	path_follow.progress = wagon_count * Global.TILE_SIZE

func get_linear_velocity(path_follow_: PathFollow2D, delta: float):
	var current_pos = path_follow_.global_position
	path_follow_.progress += delta * absolute_speed
	var next_pos = path_follow_.global_position

	var velocity = (next_pos - current_pos) / delta
	return velocity


func _physics_process(_delta: float) -> void:
	if on_rails:
		rigid_body.global_position = path_follow.global_position
		rigid_body.rotation = path_follow.rotation
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

	if _approaching_sharp_corner():
		target_speed = 5.0
		absolute_speed = target_speed
		progress_point_past_sharp_corner = path_follow.progress + Global.TILE_SIZE * wagon_count
		is_in_sharp_corner = true

	if is_in_sharp_corner:
		if path_follow.progress > progress_point_past_sharp_corner:
			target_speed = max_speed
			is_in_sharp_corner = false

	loop_movement(delta)

func _approaching_sharp_corner() -> bool:
	for i in curve.point_count:
		var point = curve.get_point_position(i)
		if point.distance_squared_to(path_follow.position) < 4.0:
			if not point == last_corner_checked:
				if i > 0 and i < curve.point_count - 1:
					var angle = _angle_between_points(curve.get_point_position(i - 1), point, curve.get_point_position(i + 1))
					if angle < PI / 2 + 0.05: # 90 degrees or lower
						return true
				last_corner_checked = point
	return false

static func _angle_between_points(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ba = a - b
	var bc = c - b
	return abs(ba.angle_to(bc)) # signed angle in radians (-π..π)
	
func loop_movement(delta: Variant):
	path_follow.progress += delta * absolute_speed
	_fix_wagon_location()
	if path_follow.progress >= curve.get_baked_length() and target_speed > 0.0 and not is_stopped_at_station:
		target_speed = 0.0
		absolute_speed = 0.0
		is_stopped_at_station = true
		end_reached.emit(self, get_train_position().snapped(Global.TILE))

func _fix_wagon_location():
	for i in len(wagons):
		var wagon = wagons[i]
		var wagon_progress = path_follow.progress - Global.TILE_SIZE * (i + 1)
		wagon.progress = clamp(wagon_progress, 0.0, curve.get_baked_length())

func start_from_station():
	path_follow.progress = wagon_count * Global.TILE_SIZE
	# Need to fix wagon location here; if we are waiting for when it is done in the
	# main loop the wagons will visibly jump because the path was changed before
	# it is corrected.
	_fix_wagon_location()
	target_speed = max_speed
	is_stopped_at_station = false
	
func get_new_curve(position1: Vector2i,
				   position2: Vector2i,
				   platform_set: PlatformSet,
				   astar_id_from_position: Dictionary[Vector2i, int],
				   astar: AStar2D) -> Curve2D:
	var point_paths: Array[PackedVector2Array] = []
	for p1 in platform_set.platform_endpoints(position1):
		for p2 in platform_set.platform_endpoints(position2):
			var id1 = astar_id_from_position[Vector2i(p1)]
			var id2 = astar_id_from_position[Vector2i(p2)]
			var point_path = astar.get_point_path(id1, id2)
			if not point_path:
				return Curve2D.new()
			point_paths.append(point_path)
	point_paths.sort_custom(func(a, b): return len(a) < len(b))
	# TODO: handle when all point_paths are empty (no path)
	var target1 = Vector2i(point_paths[-1][0])
	var target2 = Vector2i(point_paths[-1][-1])
	target_positions = [target1, target2] as Array[Vector2i]

	var new_curve = Curve2D.new()
	for p in point_paths[-1]:
		new_curve.add_point(p)
	return new_curve


func next_target(pos: Vector2i) -> Vector2i:
	for i in len(target_positions):
		if target_positions[i] == pos:
			return target_positions[(i + 1) % len(target_positions)]
	assert(false, "pos sent to next_target is not in list")
	return Vector2i()

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
			ore_timer.start()
			await ore_timer.timeout
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
			ore_timer.start()
			await ore_timer.timeout
			wagon.remove_ore()
