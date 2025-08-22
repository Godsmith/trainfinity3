extends Camera2D

func zoom_camera(factor: float) -> void:
	var previous_mouse_position := get_local_mouse_position()
	zoom *= factor
	
	var diff = previous_mouse_position - get_local_mouse_position()
	offset += diff
