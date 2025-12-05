extends MarginContainer


func _on_new_game_pressed() -> void:
	var game = _start_game()
	game.terrain.add_starting_chunks()


func _on_continue_pressed() -> void:
	var game = _start_game()
	game.load_game()


func _start_game() -> Game:
	var overground_scene = load("res://scenes/overground.tscn").instantiate()
	var current_scene = get_tree().current_scene
	var root = get_tree().get_root()
	current_scene.call_deferred("queue_free")
	current_scene.get_parent().remove_child(current_scene)
	root.add_child(overground_scene)
	return overground_scene
