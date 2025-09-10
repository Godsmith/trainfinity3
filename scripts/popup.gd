extends Label

@export var float_distance := 25.0 # how far it moves up
@export var duration := 1.0 # how long it lasts (seconds)

func show_popup(text_: String) -> void:
	text = text_
	# Start tween animation
	var tween := get_tree().create_tween()
	tween.tween_property(self, "position:y", position.y - float_distance, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.finished.connect(queue_free) # remove after animation
