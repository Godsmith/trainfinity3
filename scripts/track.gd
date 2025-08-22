extends Node2D

class_name Track

func align(pos1: Vector2, pos2: Vector2):
	if pos2.y == pos1.y:
		pass
	elif pos2.x == pos1.x:
		rotate(PI/2)
	elif pos2.y > pos1.y and pos2.x > pos1.x:
		rotate(PI/4)
	elif pos2.y < pos1.y and pos2.x < pos1.x:
		rotate(PI/4)
	else:
		rotate(PI*3/4)
