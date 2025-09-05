extends Path2D

class_name Train

const WAGON = preload("res://scenes/wagon.tscn")

signal end_reached(train: Train)

@export var max_speed := 20
@export var absolute_speed := 0.0
@export var acceleration := 0.1
@export var wagons: Array = []

var direction := 1
var last_progress := 0.0
@onready var path_follow := $PathFollow2D
@onready var polygon := $PathFollow2D/LightOccluder2D

func _ready() -> void:
	for i in 3:
		var wagon = WAGON.instantiate()
		wagons.append(wagon)
		add_child(wagon)

func _process(delta):
	if absolute_speed < max_speed:
		absolute_speed += acceleration
	loop_movement(delta)
	
func loop_movement(delta: Variant):
	path_follow.progress += delta * absolute_speed * direction
	for i in len(wagons):
		var wagon = wagons[i]
		var wagon_progress = path_follow.progress - direction * Global.TILE_SIZE * (i + 1)
		wagon.progress = clamp(wagon_progress, 0.0, curve.get_baked_length())
	if path_follow.progress >= curve.get_baked_length() or path_follow.progress == 0.0:
		absolute_speed = 0
		direction *= -1
		polygon.rotate(PI)
		end_reached.emit(self)
		
func set_path(path: Array[Vector2]):
	curve = Curve2D.new()
	for p in path:
		curve.add_point(p)

func get_train_position() -> Vector2:
	return polygon.global_position

func max_capacity() -> int:
	var out := 0
	for wagon in wagons:
		out += wagon.max_capacity
	return out

func add_ore(type: Ore.ORE_TYPE):
	for wagon in wagons:
		if not wagon.ore == wagon.max_capacity:
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
			wagon.remove_ore()