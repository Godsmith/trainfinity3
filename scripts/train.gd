extends Path2D

class_name Train

signal end_reached(train: Train)

var speed = 20
var last_progress = 0.0
@onready var path_follow := $PathFollow2D
@onready var polygon := $PathFollow2D/Polygon2D
var ore := 0
	
func _process(delta):
	loop_movement(delta)
	
func loop_movement(delta: Variant):
	path_follow.progress += delta * speed
	if path_follow.progress >= curve.get_baked_length() or path_follow.progress == 0.0 :
		speed *= -1
		polygon.rotate(PI)
		end_reached.emit(self)
		
func set_path(path: Array[Vector2]):
	curve = Curve2D.new()
	for p in path:
		curve.add_point(p)

func get_train_position() -> Vector2:
	return polygon.global_position
