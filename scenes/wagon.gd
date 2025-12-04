extends Path2D

class_name Wagon

signal wagon_clicked
signal wagon_content_changed

@onready var _chunks := find_children("Chunk*")
@onready var max_capacity := len(_chunks)
@onready var path_follow := $PathFollow2D
@onready var red_marker := $PathFollow2D/RedMarker
@onready var canvas_group := $PathFollow2D/CanvasGroup

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for chunk in _chunks:
		chunk.visible = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		wagon_clicked.emit()

func add_resource(type: Global.ResourceType):
	var reversed_chunks = _chunks.duplicate()
	reversed_chunks.reverse()
	for chunk in reversed_chunks:
		if not chunk.visible:
			chunk.resource_type = type
			chunk.color = Global.RESOURCE_COLOR[type]
			chunk.visible = true
			wagon_content_changed.emit()
			return
	assert(false, "Trying to add chunk to full wagon")

func get_wagon_position() -> Vector2:
	return path_follow.global_position

func get_total_resource_count() -> int:
	var count := 0
	for chunk in _chunks:
		if chunk.visible:
			count += 1
	return count

func get_resource_count(resource_type: Global.ResourceType) -> int:
	var count := 0
	for chunk in _chunks:
		if chunk.visible and chunk.resource_type == resource_type:
			count += 1
	return count

func unload_to_station(resource_type: Global.ResourceType, station: Station):
	if get_resource_count(resource_type) == 0:
		assert(false, "Trying to remove ore type that did not exist")
	station.add_resource(resource_type, false)
	remove_resource(resource_type)

func remove_resource(resource_type):
	for chunk in _chunks:
		if chunk.visible and chunk.resource_type == resource_type:
			chunk.visible = false
			wagon_content_changed.emit()
			return
	assert(false, "Trying to remove ore type that did not exist")

func mark_for_destruction(is_marked: bool):
	red_marker.visible = is_marked

func select(is_selected: bool):
	canvas_group.get_material().set_shader_parameter("line_thickness", 3.0 if is_selected else 0.0)
