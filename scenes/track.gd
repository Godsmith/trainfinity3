extends Node2D

class_name Track

signal track_clicked(station: Track)

const TRACK = preload("res://scenes/track.tscn")

var pos1: Vector2i
var pos2: Vector2i

var is_ghostly := false
var is_allowed := true

enum Direction {BOTH, POS1_TO_POS2, POS2_TO_POS1}

@onready var traffic_light_green_west = $TrafficLightGreenWest
@onready var traffic_light_red_west = $TrafficLightRedWest
@onready var traffic_light_green_east = $TrafficLightGreenEast
@onready var traffic_light_red_east = $TrafficLightRedEast

var direction = Direction.BOTH

## Create a new instance of Track. pos1 and pos2 will always be sorted.
static func create(p1: Vector2i, p2: Vector2i) -> Track:
	var track: Track = TRACK.instantiate()
	var positions = [p1, p2]
	positions.sort()
	track.pos1 = positions[0]
	track.pos2 = positions[1]
	track.rotation = atan2(p2.y - p1.y, p2.x - p1.x)
	if positions == [p2, p1]:
		track.rotation += PI
	# If diagonal, extend length
	if is_equal_approx(fposmod(track.rotation, PI / 2), PI / 4):
		track._set_length_extended()
	else:
		track._set_length_normal()
	return track

func _to_string() -> String:
	return "Track(%s, %s)" % [pos1, pos2]

func _set_length_normal():
	$CanvasGroupSleeper/Sleeper1/Sleeper5.visible = false
	$CanvasGroupSleeper/Sleeper1/Sleeper6.visible = false
	$CanvasGroupRail/Rail1/LongRail1.visible = false
	$CanvasGroupRail/Rail1/LongRail2.visible = false

func _set_length_extended():
	$CanvasGroupSleeper/Sleeper1/Sleeper5.visible = true
	$CanvasGroupSleeper/Sleeper1/Sleeper6.visible = true
	$CanvasGroupRail/Rail1/LongRail1.visible = true
	$CanvasGroupRail/Rail1/LongRail2.visible = true

func set_ghostly(is_ghostly_: bool):
	is_ghostly = is_ghostly_
	_set_color()

func set_allowed(is_allowed_: bool):
	is_allowed = is_allowed_
	_set_color()

func _set_color():
	var r = 1.0
	var g = 1.0 if is_allowed else 0.6
	var b = 1.0 if is_allowed else 0.6
	var a = 0.8 if is_ghostly else 1.0
	modulate = Color(r, g, b, a)
		
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		track_clicked.emit(self )

func _on_mouse_entered() -> void:
	Events.mouse_enters_track.emit(self )

func _on_mouse_exited() -> void:
	Events.mouse_exits_track.emit(self )

func other_position(pos: Vector2i) -> Vector2i:
	if pos == pos1:
		return pos2
	elif pos == pos2:
		return pos1
	else:
		assert(false, "pos neither pos1 nor pos2")
		return pos1

func rotate_one_way_direction():
	match direction:
		Direction.BOTH:
			direction = Direction.POS1_TO_POS2
			traffic_light_green_west.visible = true
			traffic_light_red_west.visible = false
			traffic_light_green_east.visible = false
			traffic_light_red_east.visible = true
		Direction.POS1_TO_POS2:
			direction = Direction.POS2_TO_POS1
			traffic_light_green_west.visible = false
			traffic_light_red_west.visible = true
			traffic_light_green_east.visible = true
			traffic_light_red_east.visible = false
		Direction.POS2_TO_POS1:
			direction = Direction.BOTH
			traffic_light_green_west.visible = false
			traffic_light_red_west.visible = false
			traffic_light_green_east.visible = false
			traffic_light_red_east.visible = false

func set_highlight(is_highlighted: bool):
	for canvas_group in [$CanvasGroupSleeper, $CanvasGroupRail]:
		canvas_group.get_material().set_shader_parameter("line_thickness", 3.0 if is_highlighted else 0.0)
