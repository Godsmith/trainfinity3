extends Node2D

class_name Industry

@export var produces: Array[Global.ResourceType]
@export var consumes: Array[Global.ResourceType]
@export var requires_resources_to_produce: bool = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		Events.industry_clicked.emit(self)
