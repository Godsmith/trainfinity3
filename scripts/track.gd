extends Node2D

class_name Track

signal track_clicked(station: Track)

const TRACK = preload("res://scenes/track.tscn")

var pos1: Vector2i
var pos2: Vector2i

static func create(p1: Vector2i, p2: Vector2i) -> Track:
	var track: Track = TRACK.instantiate()
	track.pos1 = p1
	track.pos2 = p2
	if p2.y == p1.y:
		pass
	elif p2.x == p1.x:
		track.set_rotation_and_adjust_length(PI / 2)
	elif p2.y > p1.y and p2.x > p1.x:
		track.set_rotation_and_adjust_length(PI / 4)
	elif p2.y < p1.y and p2.x < p1.x:
		track.set_rotation_and_adjust_length(PI / 4)
	else:
		track.set_rotation_and_adjust_length(PI * 3 / 4)
	return track

func set_rotation_and_adjust_length(radians: float):
	if is_equal_approx(radians, PI / 4) or is_equal_approx(radians, PI * 3 / 4):
		_set_length_extended()
	else:
		_set_length_normal()
	rotation = radians

func _set_length_normal():
	$Sleeper5.visible = false
	$Sleeper6.visible = false
	$LongRail1.visible = false
	$LongRail2.visible = false

func _set_length_extended():
	$Sleeper5.visible = true
	$Sleeper6.visible = true
	$LongRail1.visible = true
	$LongRail2.visible = true

func set_color(is_ghostly: bool, is_allowed: bool):
	var r = 1.0
	var g = 1.0 if is_allowed else 0.5
	var b = 1.0 if is_allowed else 0.5
	var a = 0.5 if is_ghostly else 1.0
	modulate = Color(r, g, b, a)
		
func position_rotation() -> Vector3i:
	# makes a direction of 45 degrees equal to a direction of 225 degrees
	return Vector3i(roundi(position.x), roundi(position.y), roundi(rotation_degrees) % 180)
	
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		track_clicked.emit(self)
