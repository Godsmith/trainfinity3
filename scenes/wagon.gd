extends Path2D

class_name Wagon

signal wagon_clicked
signal wagon_content_changed

@onready var _chunks := find_children("Chunk*")
@onready var max_capacity := len(_chunks)
@onready var path_follow := $PathFollow2D
@onready var red_marker := $PathFollow2D/RedMarker
@onready var ore_timer := $OreTimer
@onready var canvas_group := $PathFollow2D/CanvasGroup

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for chunk in _chunks:
		chunk.visible = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		wagon_clicked.emit()

func add_ore(type: Ore.OreType):
	ore_timer.start()
	await ore_timer.timeout
	var reversed_chunks = _chunks.duplicate()
	reversed_chunks.reverse()
	for chunk in reversed_chunks:
		if not chunk.visible:
			chunk.ore_type = type
			chunk.color = Ore.ORE_COLOR[type]
			chunk.visible = true
			wagon_content_changed.emit()
			return
	assert(false, "Trying to add chunk to full wagon")

func get_wagon_position() -> Vector2:
	return path_follow.global_position

func get_total_ore_count() -> int:
	var count := 0
	for chunk in _chunks:
		if chunk.visible:
			count += 1
	return count

func get_ore_count(ore_type: Ore.OreType) -> int:
	var count := 0
	for chunk in _chunks:
		if chunk.visible and chunk.ore_type == ore_type:
			count += 1
	return count

func unload_to_station(ore_type: Ore.OreType, station: Station):
	while get_ore_count(ore_type) > 0:
		await remove_ore(ore_type)
		station.add_ore(ore_type, false)

func remove_ore(ore_type):
	ore_timer.start()
	await ore_timer.timeout
	for chunk in _chunks:
		if chunk.visible and chunk.ore_type == ore_type:
			chunk.visible = false
			wagon_content_changed.emit()
			return
	assert(false, "Trying to remove ore type that did not exist")

func mark_for_destruction(is_marked: bool):
	red_marker.visible = is_marked

func select(is_selected: bool):
	canvas_group.get_material().set_shader_parameter("line_thickness", 3.0 if is_selected else 0.0)
