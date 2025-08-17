extends PathFollow2D

var speed = 0.2
var last_progress_ratio = 0.0

func _ready():
	pass
	
func _process(delta):
	loop_movement(delta)
	
func loop_movement(delta: Variant):
	progress_ratio += delta * speed
	if progress_ratio == last_progress_ratio:
		speed *= -1
		
	last_progress_ratio = progress_ratio
		
