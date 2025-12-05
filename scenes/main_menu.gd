extends MarginContainer


func _ready() -> void:
	if not FileAccess.file_exists(Global.SAVE_PATH):
		$HBoxContainer/VBoxContainer/VBoxContainer/Continue.disabled = true


func _on_continue_pressed() -> void:
	var game = _start_game()
	game.load_game()


func _on_new_game_pressed() -> void:
	if not FileAccess.file_exists(Global.SAVE_PATH):
		_start_new_game()
	var dialog = ConfirmationDialog.new()
	dialog.title = "Are you sure?"
	dialog.dialog_text = "This will overwrite the game in progress."

	dialog.canceled.connect(_on_cancel_pressed)
	dialog.confirmed.connect(_on_ok_pressed)
	
	add_child(dialog)
	dialog.popup_centered()
	dialog.show()


func _on_cancel_pressed(): pass


func _on_ok_pressed(): _start_new_game()


func _start_new_game():
	_start_game().start_new_game()


func _start_game() -> Game:
	var overground_scene = load("res://scenes/overground.tscn").instantiate()
	var current_scene = get_tree().current_scene
	var root = get_tree().get_root()
	current_scene.call_deferred("queue_free")
	current_scene.get_parent().remove_child(current_scene)
	root.add_child(overground_scene)
	return overground_scene
