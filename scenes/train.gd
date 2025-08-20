extends PathFollow2D

class_name Train

var speed = 20
var last_progress = 0.0

func _ready():
	print("hello from train")
	pass
	
func _process(delta):
	loop_movement(delta)
	
func loop_movement(delta: Variant):
	progress
	progress += delta * speed
	if progress == last_progress:
		speed *= -1
		
	last_progress = progress_ratio
		
