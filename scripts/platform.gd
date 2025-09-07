extends Node2D

class_name Platform

signal platform_clicked(station: Station)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		platform_clicked.emit(self)
