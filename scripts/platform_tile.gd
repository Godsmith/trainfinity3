extends Node2D

class_name PlatformTile

signal platform_tile_clicked(station: Station)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		platform_tile_clicked.emit(self)

func mark_for_deletion(to_be_deleted: bool):
	self.modulate = Color(1, 0, 0, 1) if to_be_deleted else Color(1, 1, 1, 1)
