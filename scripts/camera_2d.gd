extends Camera2D

const MAX_ZOOM = 6.0
const MIN_ZOOM = 0.5

func zoom_camera(factor: float) -> void:
	var new_zoom = zoom * factor
	if new_zoom.x > MIN_ZOOM and new_zoom.x < MAX_ZOOM:
		zoom = new_zoom
		var previous_mouse_position := get_local_mouse_position()
		var diff = previous_mouse_position - get_local_mouse_position()
		offset += diff
