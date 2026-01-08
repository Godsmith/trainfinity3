extends BaseTest


func before_each():
	_game = load("res://scenes/overground.tscn").instantiate()
	add_child_autofree(_game)
	_game.terrain.set_seed_and_add_chunks(0, {Vector2i(0, 0): Terrain.ChunkType.DEBUG_GRASS_ONLY} as Dictionary[Vector2i, Terrain.ChunkType])


func test_create_track():
	press(KEY_1) # Switch to track mode
	click(200, 200)
	click(400, 200)
	click(400, 200)

	assert_eq(len(_game.track_set.get_all_tracks()), 4)


func test_show_ghost_track_before_building():
	press(KEY_1) # Switch to track mode
	click(200, 200)
	mouse_move(400, 200)

	assert_eq(get_tree().get_node_count_in_group("track"), 4)
	for track in get_tree().get_nodes_in_group("track"):
		assert_true(track.is_ghostly)


func test_hovered_over_ghost_track_is_red():
	press(KEY_1) # Switch to track mode
	click(200, 200)
	click(400, 200) # Construct a length of ghost track
	mouse_move(300, 200)
	await wait_idle_frames(1) # Wait for queue_free()

	var allow_count := 0
	for track in get_tree().get_nodes_in_group("track"):
		if track.is_allowed:
			allow_count += 1
	assert_eq(allow_count, 2)


func test_undo_ghost_track_removes_red_rail_immediately():
	press(KEY_1) # Switch to track mode
	click(200, 200)
	click(400, 200) # Construct a length of ghost track
	click(300, 200) # Click halfway back, to remove half of the ghost track
	await wait_idle_frames(1) # Wait for queue_free()

	assert_eq(get_tree().get_node_count_in_group("track"), 2)
