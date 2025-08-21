extends Node2D

class_name Track

func align(pos1: Vector2, pos2: Vector2):
	if pos2.y == pos1.y:
		pass
	elif pos2.x == pos1.x:
		rotate(PI/2)
	elif pos2.y > pos1.y and pos2.x > pos1.x:
		rotate(PI/4)
		_extend_length()
	elif pos2.y < pos1.y and pos2.x < pos1.x:
		rotate(PI/4)
		_extend_length()
	else:
		rotate(PI*3/4)
		_extend_length()

func _extend_length():
	$Sleeper5.visible = true
	$Sleeper6.visible = true
	$LongRail1.visible = true
	$LongRail2.visible = true

func set_ghost_status(is_ghostly: bool):
	modulate = Color(1,1,1,0.5) if is_ghostly else Color(1,1,1,1)

