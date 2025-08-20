extends Node2D

class_name Station

signal station_clicked(station: Station)

@export var is_ghost := false

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		station_clicked.emit(self)
