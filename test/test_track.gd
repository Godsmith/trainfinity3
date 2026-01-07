extends GutTest

var _game: Game


func press(keycode):
	var press_event = InputEventKey.new()
	press_event.keycode = keycode
	press_event.pressed = true
	_game._unhandled_input(press_event)

func mouse_move(x: float, y: float):
	var move_event = InputEventMouseMotion.new()
	move_event.position = Vector2(x, y)
	_game._unhandled_input(move_event)

func click(x: float, y: float):
	mouse_move(x, y)

	var click_event = InputEventMouseButton.new()
	click_event.pressed = true
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.position = Vector2(x, y)
	_game._unhandled_input(click_event)


func before_each():
	_game = load("res://scenes/overground.tscn").instantiate()
	get_tree().get_root().add_child(_game)
	_game.terrain.set_seed_and_add_chunks(0, {Vector2i(0, 0): Terrain.ChunkType.DEBUG_GRASS_ONLY} as Dictionary[Vector2i, Terrain.ChunkType])

func after_each():
	get_tree().get_root().remove_child(_game)
	_game.queue_free()


func test_create_rail():
	press(KEY_1) # Switch to track mode
	click(200, 200)
	click(400, 200)
	click(400, 200)

	assert_eq(len(_game.track_set.get_all_tracks()), 4)


func test_show_ghost_rail_before_building():
	press(KEY_1) # Switch to track mode
	click(200, 200)
	mouse_move(400, 200)

	assert_eq(get_tree().get_node_count_in_group("track"), 4)
	for track in get_tree().get_nodes_in_group("track"):
		assert_true(track.is_ghostly)


func test_hovered_over_ghost_rail_is_red():
	press(KEY_1) # Switch to track mode
	click(200, 200)
	click(400, 200)
	mouse_move(300, 200)

	assert_eq(get_tree().get_node_count_in_group("track"), 4)

	var allow_count := 0
	for track in get_tree().get_nodes_in_group("track"):
		if track.is_allowed:
			allow_count += 1
	assert_eq(allow_count, 2)
